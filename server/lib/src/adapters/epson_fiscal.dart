import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kiosk_core/kiosk_core.dart';

import 'fiscal.dart';

/// Italian "registratore telematico" (RT) by Epson (FP-81 II RT, FP-90 III
/// RT and compatibles), driven through its built-in web service
/// (`/cgi-bin/fpmate.cgi`, Epson fiscal XML protocol).
///
/// Options:
/// - `host` (required) and `port` (default 80);
/// - `devid` (default `local_printer`), `timeoutMs` (default 15000);
/// - `operator` (default `1`);
/// - `departments`: VAT rate to RT department, e.g. `{"10": 1, "22": 2}`;
///   rates not listed use `defaultDepartment` (default 1);
/// - `paymentTypes`: payment method to RT payment type, merged over
///   `{"cash": 0, "counter": 0, "card": 2, "kiosk": 2}`.
///
/// The device itself must be configured (departments, VAT, header) by the
/// installer as usual; this adapter only sends the sale.
class EpsonFiscalPrinter extends FiscalDevice {
  final String host;
  final int port;
  final String devid;
  final Duration timeout;
  final String operator;
  final Map<String, int> departments;
  final int defaultDepartment;
  final Map<String, int> paymentTypes;

  EpsonFiscalPrinter({
    required this.host,
    this.port = 80,
    this.devid = 'local_printer',
    this.timeout = const Duration(seconds: 15),
    this.operator = '1',
    this.departments = const {},
    this.defaultDepartment = 1,
    Map<String, int> paymentTypes = const {},
  }) : paymentTypes = {..._defaultPaymentTypes, ...paymentTypes};

  static const _defaultPaymentTypes = {
    'cash': 0,
    'counter': 0,
    'card': 2,
    'kiosk': 2,
  };

  factory EpsonFiscalPrinter.fromOptions(Map<String, Object?> o) {
    final host = o['host'] as String?;
    if (host == null || host.isEmpty) {
      throw ArgumentError('The Epson RT printer needs a "host" option.');
    }
    Map<String, int> ints(Object? m) => {
      for (final e in (m as Map? ?? const {}).entries)
        '${e.key}': (e.value as num).toInt(),
    };
    return EpsonFiscalPrinter(
      host: host,
      port: (o['port'] as num?)?.toInt() ?? 80,
      devid: o['devid'] as String? ?? 'local_printer',
      timeout: Duration(
        milliseconds: (o['timeoutMs'] as num?)?.toInt() ?? 15000,
      ),
      operator: '${o['operator'] ?? 1}',
      departments: ints(o['departments']),
      defaultDepartment: (o['defaultDepartment'] as num?)?.toInt() ?? 1,
      paymentTypes: ints(o['paymentTypes']),
    );
  }

  @override
  String get type => 'epsonRt';

  @override
  Future<FiscalDocument> issue(Order order) async {
    final xml = buildReceipt(order);
    final uri = Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '/cgi-bin/fpmate.cgi',
      queryParameters: {'devid': devid, 'timeout': '${timeout.inMilliseconds}'},
    );
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.postUrl(uri).timeout(timeout);
      req.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
      req.add(utf8.encode(xml));
      final res = await req.close().timeout(timeout);
      final body = await utf8.decodeStream(res).timeout(timeout);
      if (res.statusCode != 200) {
        throw FiscalException('Stampante fiscale: HTTP ${res.statusCode}');
      }
      return parseResponse(body);
    } on TimeoutException {
      throw FiscalException('Stampante fiscale non risponde ($host)');
    } on SocketException catch (e) {
      throw FiscalException(
        'Stampante fiscale non raggiungibile: ${e.message}',
      );
    } finally {
      client.close(force: true);
    }
  }

  int _department(double vatRate) {
    final key = vatRate == vatRate.roundToDouble()
        ? vatRate.toInt().toString()
        : vatRate.toString();
    return departments[key] ?? defaultDepartment;
  }

  /// The SOAP request for a sale: one item per line, priced extras as
  /// their own items, then the total with the payment type.
  String buildReceipt(Order order) {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="utf-8"?>')
      ..write(
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">',
      )
      ..write('<s:Body><printerFiscalReceipt>')
      ..write('<beginFiscalReceipt operator="$operator" />');
    for (final l in order.lines) {
      final dept = _department(l.vatRate);
      b.write(
        _item(
          l.name.resolve(order.language),
          l.quantity,
          l.unitPriceCents,
          dept,
        ),
      );
      for (final o in l.options) {
        if (o.priceDeltaCents == 0) continue;
        b.write(
          _item(
            '  + ${o.name.resolve(order.language)}',
            l.quantity,
            o.priceDeltaCents,
            dept,
          ),
        );
      }
    }
    final method = order.payment?.provider ?? 'cash';
    final paymentType =
        paymentTypes[method] ??
        (order.paymentMode == PaymentMode.kiosk ? 2 : 0);
    b
      ..write(
        '<printRecTotal operator="$operator" description="PAGAMENTO" '
        'payment="${_amount(order.totalCents)}" paymentType="$paymentType" '
        'index="1" justification="1" />',
      )
      ..write(
        '<printRecMessage operator="$operator" messageType="3" index="1" '
        'font="1" message="${_escape('ORDINE N. ${order.number}')}" />',
      )
      ..write('<endFiscalReceipt operator="$operator" />')
      ..write('</printerFiscalReceipt></s:Body></s:Envelope>');
    return b.toString();
  }

  String _item(String description, int qty, Cents unit, int dept) =>
      '<printRecItem operator="$operator" '
      'description="${_escape(_truncate(description, 38))}" '
      'quantity="$qty" unitPrice="${_amount(unit)}" '
      'department="$dept" justification="1" />';

  /// Reads `success` and the receipt numbers from the device answer.
  FiscalDocument parseResponse(String body) {
    final ok = RegExp(r'success="(true|false)"').firstMatch(body)?.group(1);
    if (ok != 'true') {
      final code = RegExp(r'code="([^"]*)"').firstMatch(body)?.group(1);
      throw FiscalException(
        'Stampante fiscale: scontrino rifiutato'
        '${code == null || code.isEmpty ? '' : ' ($code)'}',
      );
    }
    String? tag(String name) =>
        RegExp('<$name>([^<]*)</$name>').firstMatch(body)?.group(1)?.trim();
    final receipt = tag('fiscalReceiptNumber');
    final z = int.tryParse(tag('zRepNumber') ?? '');
    final number = receipt == null
        ? 'RT-${DateTime.now().millisecondsSinceEpoch}'
        : z == null
        ? receipt.padLeft(4, '0')
        : '${(z + 1).toString().padLeft(4, '0')}-${receipt.padLeft(4, '0')}';
    return FiscalDocument(
      provider: type,
      number: number,
      issuedAt: DateTime.now(),
    );
  }

  static String _amount(Cents c) =>
      '${c ~/ 100},${(c % 100).toString().padLeft(2, '0')}';

  static String _truncate(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
