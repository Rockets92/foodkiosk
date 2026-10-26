/// Italian fiscal data: the seller's details printed on the "documento
/// commerciale", what the customer may ask to have on it, and the
/// checks on tax ids.
library;

/// The business that issues the fiscal documents. Every "documento
/// commerciale" must show its name, the address of the premises and its
/// VAT number (DM 7 dicembre 2016, art. 2).
class MerchantProfile {
  /// Company name, or first and last name of a sole trader.
  final String legalName;

  /// Partita IVA, 11 digits.
  final String vatNumber;

  /// Codice fiscale of the business, when it differs from the VAT number.
  final String taxCode;
  final String address;
  final String zip;
  final String city;

  /// Two-letter province code (MI, RM...).
  final String province;

  const MerchantProfile({
    this.legalName = '',
    this.vatNumber = '',
    this.taxCode = '',
    this.address = '',
    this.zip = '',
    this.city = '',
    this.province = '',
  });

  bool get isEmpty =>
      legalName.isEmpty && vatNumber.isEmpty && address.isEmpty && city.isEmpty;

  /// "Via Roma 1, 20100 Milano (MI)".
  String get fullAddress {
    final place = [
      if (zip.isNotEmpty) zip,
      if (city.isNotEmpty) city,
      if (province.isNotEmpty) '($province)',
    ].join(' ');
    return [
      if (address.isNotEmpty) address,
      if (place.isNotEmpty) place,
    ].join(', ');
  }

  /// What is missing or wrong to issue valid documents.
  List<String> validate() => [
    if (legalName.trim().isEmpty) 'The business name is required.',
    if (!TaxId.isValidVatNumber(vatNumber))
      'The VAT number (partita IVA) is not valid.',
    if (taxCode.isNotEmpty && !TaxId.isValidTaxCode(taxCode))
      'The tax code (codice fiscale) of the business is not valid.',
    if (address.trim().isEmpty || city.trim().isEmpty)
      'The address of the premises is required.',
  ];

  factory MerchantProfile.fromJson(Object? json) {
    if (json is! Map) return const MerchantProfile();
    String s(String k) => (json[k] as String? ?? '').trim();
    return MerchantProfile(
      legalName: s('legalName'),
      vatNumber: s('vatNumber').replaceAll(' ', ''),
      taxCode: s('taxCode').replaceAll(' ', '').toUpperCase(),
      address: s('address'),
      zip: s('zip'),
      city: s('city'),
      province: s('province').toUpperCase(),
    );
  }

  Map<String, Object?> toJson() => {
    'legalName': legalName,
    'vatNumber': vatNumber,
    'taxCode': taxCode,
    'address': address,
    'zip': zip,
    'city': city,
    'province': province,
  };
}

/// What the customer may ask to have on the document at the till.
class FiscalCustomer {
  /// "Codice lotteria" of the receipts lottery: 8 letters and digits.
  /// Only valid for payments made, even in part, by card.
  final String? lotteryCode;

  /// Codice fiscale or partita IVA of the buyer, for a document "valido ai
  /// fini fiscali" (deductible expenses).
  final String? taxCode;

  const FiscalCustomer({this.lotteryCode, this.taxCode});

  bool get isEmpty => (lotteryCode ?? '').isEmpty && (taxCode ?? '').isEmpty;

  /// Normalized (upper case, no spaces); empty values become null.
  factory FiscalCustomer.fromJson(Object? json) {
    if (json is! Map) return const FiscalCustomer();
    String? clean(Object? v) {
      final s = (v as String? ?? '').replaceAll(' ', '').toUpperCase();
      return s.isEmpty ? null : s;
    }

    return FiscalCustomer(
      lotteryCode: clean(json['lotteryCode']),
      taxCode: clean(json['taxCode']),
    );
  }

  List<String> validate() => [
    if (lotteryCode case final c? when !TaxId.isValidLotteryCode(c))
      'The lottery code must be 8 letters or digits.',
    if (taxCode case final c?
        when !TaxId.isValidTaxCode(c) && !TaxId.isValidVatNumber(c))
      'The customer tax code is not valid.',
  ];

  Map<String, Object?> toJson() => {
    'lotteryCode': ?lotteryCode,
    'taxCode': ?taxCode,
  };
}

/// Checks on Italian tax identifiers.
abstract final class TaxId {
  /// Partita IVA: 11 digits, the last one a check digit.
  static bool isValidVatNumber(String value) {
    final v = value.replaceAll(' ', '');
    if (!RegExp(r'^\d{11}$').hasMatch(v)) return false;
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      var d = v.codeUnitAt(i) - 48;
      if (i.isOdd) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
    }
    return (10 - sum % 10) % 10 == v.codeUnitAt(10) - 48;
  }

  static const _odd = [
    1, 0, 5, 7, 9, 13, 15, 17, 19, 21, 2, 4, 18, 20, 11, 3, 6, 8, 12, 14, //
    16, 10, 22, 25, 24, 23,
  ];

  /// Codice fiscale of a person: 16 characters (omocodia included) with
  /// the check letter; a company's is its 11-digit number.
  static bool isValidTaxCode(String value) {
    final v = value.replaceAll(' ', '').toUpperCase();
    if (RegExp(r'^\d{11}$').hasMatch(v)) return isValidVatNumber(v);
    if (!RegExp(
      r'^[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-Z][0-9LMNPQRSTUV]{2}[A-Z]'
      r'[0-9LMNPQRSTUV]{3}[A-Z]$',
    ).hasMatch(v)) {
      return false;
    }
    var sum = 0;
    for (var i = 0; i < 15; i++) {
      final c = v.codeUnitAt(i);
      // Digits count like the letter in the same position (0 = A).
      final n = c <= 57 ? c - 48 : c - 65;
      sum += i.isEven ? _odd[n] : n;
    }
    return String.fromCharCode(65 + sum % 26) == v[15];
  }

  static bool isValidLotteryCode(String value) =>
      RegExp(r'^[A-Z0-9]{8}$').hasMatch(value.toUpperCase());
}
