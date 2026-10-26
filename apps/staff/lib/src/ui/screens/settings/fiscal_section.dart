import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../../../api.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'devices_section.dart';
import 'discounts_section.dart';
import 'fields.dart';

const dcProviderNames = {
  'sandbox': 'Ambiente di prova (simulato, nessun invio)',
};

/// Fiscal documents: how the "documento commerciale" is issued (nothing,
/// a registratore telematico, or the Agenzia delle Entrate's online
/// procedure through a provider), the business details printed on it and
/// the Fisconline account.
class FiscalSection extends StatelessWidget {
  final KioskSettings s;
  final Map<String, List<String>> adapters;
  final StaffApi api;
  final void Function(String key, Object? value) set;

  const FiscalSection({
    super.key,
    required this.s,
    required this.adapters,
    required this.api,
    required this.set,
  });

  void _type(String type) {
    if (type == s.fiscal.type) return;
    set(
      'fiscal',
      AdapterConfig(type, switch (type) {
        'epsonRt' => {
          'host': '',
          'port': 80,
          'departments': {'10': 1, '22': 2},
        },
        'adeOnline' => {'provider': 'sandbox'},
        _ => <String, Object?>{},
      }).toJson(),
    );
  }

  bool get _issuedOnPayment => s.flow
      .actionsFor(FlowEvent.paid)
      .contains(FlowAction.issueFiscalDocument);

  void _addToFlow() {
    final rules = {
      for (final e in s.flow.rules.entries) e.key: [...e.value],
    };
    rules[FlowEvent.paid] = [
      FlowAction.issueFiscalDocument,
      ...?rules[FlowEvent.paid],
    ];
    set(
      'flow',
      FlowConfig(paymentMode: s.flow.paymentMode, rules: rules).toJson(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = s.fiscal.type;
    final known = adapters['fiscal'] ?? const [];
    final modes = [
      (
        'none',
        Icons.receipt_outlined,
        'Nessuno',
        'Il totem stampa solo il promemoria dell\'ordine. Lo scontrino lo '
            'emette la cassa del locale, con il suo registratore.',
      ),
      (
        'epsonRt',
        Icons.print_rounded,
        'Registratore telematico',
        'Il registratore (Epson RT) stampa il documento commerciale e invia '
            'i corrispettivi all\'Agenzia. Collegato in rete.',
      ),
      (
        'adeOnline',
        Icons.cloud_done_rounded,
        'Documento commerciale online',
        'Senza registratore: ogni vendita è registrata nella procedura web '
            'dell\'Agenzia con le tue credenziali; il documento lo stampa la '
            'stampante termica.',
      ),
    ];
    return SectionCard(
      icon: Icons.account_balance_rounded,
      title: 'Agenzia delle Entrate',
      subtitle:
          'Documento commerciale di vendita e invio dei corrispettivi '
          'giornalieri',
      accent: S.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final cards = [
                for (final (id, icon, title, text) in modes)
                  if (id == 'none' || known.contains(id) || id == type)
                    ModeCard(
                      key: ValueKey('fiscal-mode-$id'),
                      icon: icon,
                      title: title,
                      text: text,
                      selected: type == id,
                      onTap: () => _type(id),
                    ),
              ];
              if (box.maxWidth < 760) {
                return Column(
                  children: [
                    for (final c in cards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: c,
                      ),
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, c) in cards.indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: c),
                    ],
                  ],
                ),
              );
            },
          ),
          if (type != 'none' && !_issuedOnPayment)
            _Notice(
              key: const ValueKey('fiscal-not-in-flow'),
              color: S.warning,
              icon: Icons.alt_route_rounded,
              text:
                  'Il flusso ordine non emette ancora il documento: aggiungilo '
                  'all\'incasso, prima della stampa dello scontrino.',
              action: ('Emetti all\'incasso', _addToFlow),
            ),
          if (s.demoMode && type != 'none')
            const _Notice(
              color: S.info,
              icon: Icons.science_rounded,
              text:
                  'In modalità demo i documenti sono simulati e marcati "DEMO": '
                  'puoi provare stampe e annulli senza inviare niente.',
            ),
          if (type == 'epsonRt') ...[
            const SizedBox(height: 16),
            DeviceCard(
              key: const ValueKey('device-fiscal'),
              id: 'fiscal',
              title: 'Registratore telematico Epson (RT)',
              icon: Icons.print_rounded,
              types: [type],
              config: s.fiscal,
              typePicker: false,
              onChanged: (c) => set('fiscal', c.toJson()),
            ),
            const Text(
              'Il registratore stampa da sé intestazione, partita IVA e '
              'numero del documento: lo scontrino del totem diventa un '
              'promemoria con il numero dell\'ordine.',
              style: ST.small,
            ),
          ],
          if (type == 'adeOnline') ...[
            const SizedBox(height: 16),
            _ProviderPicker(
              config: s.fiscal,
              providers: adapters['dcOnline'] ?? const ['sandbox'],
              onChanged: (c) => set('fiscal', c.toJson()),
            ),
            const SizedBox(height: 20),
            _MerchantForm(
              merchant: s.merchant,
              onChanged: (m) => set('merchant', m.toJson()),
            ),
            const SizedBox(height: 20),
            FiscalAccountPanel(api: api),
            const SizedBox(height: 16),
            const _Requirements(),
          ],
        ],
      ),
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  final AdapterConfig config;
  final List<String> providers;
  final ValueChanged<AdapterConfig> onChanged;
  const _ProviderPicker({
    required this.config,
    required this.providers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = '${config.options['provider'] ?? 'sandbox'}';
    return SettingRow(
      label: 'Collegamento con l\'Agenzia',
      help:
          'L\'Agenzia non offre un accesso diretto per i programmi: si passa '
          'da un intermediario certificato che usa le tue credenziali.',
      child: SizedBox(
        width: 420,
        child: DropdownButtonFormField<String>(
          key: ValueKey('dc-provider:$current'),
          initialValue: current,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            for (final p in {...providers, current})
              DropdownMenuItem(
                value: p,
                child: Text(
                  dcProviderNames[p] ?? p,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (p) {
            if (p == null) return;
            onChanged(
              AdapterConfig(config.type, {...config.options, 'provider': p}),
            );
          },
        ),
      ),
    );
  }
}

/// Business details printed on every documento commerciale.
class _MerchantForm extends StatelessWidget {
  final MerchantProfile merchant;
  final ValueChanged<MerchantProfile> onChanged;
  const _MerchantForm({required this.merchant, required this.onChanged});

  MerchantProfile _with(String key, String value) =>
      MerchantProfile.fromJson({...merchant.toJson(), key: value});

  @override
  Widget build(BuildContext context) {
    final m = merchant;
    Widget field(
      String key,
      String label, {
      double width = 260,
      String? hint,
    }) => SyncedTextField(
      key: ValueKey('merchant-$key'),
      label: label,
      hint: hint,
      value: '${m.toJson()[key] ?? ''}',
      width: width,
      onChanged: (v) => onChanged(_with(key, v)),
    );
    final problems = [
      if (m.legalName.isEmpty) 'la ragione sociale',
      if (!TaxId.isValidVatNumber(m.vatNumber))
        m.vatNumber.isEmpty ? 'la partita IVA' : 'una partita IVA valida',
      if (m.taxCode.isNotEmpty && !TaxId.isValidTaxCode(m.taxCode))
        'un codice fiscale valido',
      if (m.address.isEmpty || m.city.isEmpty) 'l\'indirizzo del locale',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Dati dell\'esercente', style: ST.h3),
        const Text(
          'Stampati in testa a ogni documento commerciale, come richiede '
          'la legge (ragione sociale, sede del locale e partita IVA).',
          style: ST.small,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            field('legalName', 'Ragione sociale', width: 400),
            field('vatNumber', 'Partita IVA', width: 200),
            field('taxCode', 'Codice fiscale (se diverso)', width: 240),
            field('address', 'Indirizzo del locale', width: 400),
            field('zip', 'CAP', width: 110),
            field('city', 'Comune', width: 220),
            field('province', 'Provincia', width: 110, hint: 'MI'),
          ],
        ),
        if (problems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Per emettere documenti validi manca ${problems.join(', ')}.',
              key: const ValueKey('merchant-problems'),
              style: ST.small.copyWith(color: S.danger),
            ),
          ),
      ],
    );
  }
}

/// The Fisconline account: entered here, stored encrypted on the server,
/// never shown again. Saved on its own, not with the other settings.
class FiscalAccountPanel extends StatefulWidget {
  final StaffApi api;
  const FiscalAccountPanel({super.key, required this.api});

  @override
  State<FiscalAccountPanel> createState() => _FiscalAccountPanelState();
}

class _FiscalAccountPanelState extends State<FiscalAccountPanel> {
  FiscalAccountStatus? _status;
  final _taxCode = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  bool _editing = false;
  bool _showPassword = false;
  String? _check;
  bool? _checkOk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _taxCode.dispose();
    _password.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await widget.api.fiscalAccount();
      if (mounted) setState(() => _status = s);
    } on ApiError {
      if (mounted) setState(() => _status = const FiscalAccountStatus());
    }
  }

  static String _italian(ApiError e) => switch (e.code) {
    'invalidTaxCode' =>
      'Il codice fiscale dell\'utente Fisconline non è valido',
    'invalidPassword' => 'La password Fisconline ha almeno 8 caratteri',
    'invalidPin' => 'Il PIN Fisconline è il codice completo di 10 cifre',
    _ => e.message,
  };

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final s = await widget.api.saveFiscalAccount(
        taxCode: _taxCode.text,
        password: _password.text,
        pin: _pin.text,
      );
      _taxCode.clear();
      _password.clear();
      _pin.clear();
      if (!mounted) return;
      setState(() {
        _status = s;
        _editing = false;
        _check = null;
      });
      showMessage(context, 'Credenziali salvate in modo cifrato');
    } on ApiError catch (e) {
      if (mounted) showMessage(context, _italian(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final result = await guard(context, widget.api.checkFiscal);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result != null) {
        final (ok, message, status) = result;
        _checkOk = ok;
        _check = message;
        _status = status;
      }
    });
  }

  Future<void> _disconnect() async {
    final ok = await confirm(
      context,
      title: 'Scollegare l\'account?',
      message:
          'Le credenziali vengono cancellate da questo PC. Finché non le '
          'inserisci di nuovo non si possono emettere documenti.',
      confirmLabel: 'Scollega',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final s = await guard(context, widget.api.disconnectFiscalAccount);
    if (s != null && mounted) {
      setState(() {
        _status = s;
        _check = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final connected = s?.connected ?? false;
    final showForm = !connected || _editing;
    final (statusText, statusColor) = switch (s) {
      null => ('Verifica in corso…', S.muted),
      FiscalAccountStatus(unreadable: true) => (
        'Credenziali da reinserire (chiave di cifratura cambiata)',
        S.danger,
      ),
      FiscalAccountStatus(connected: false) => ('Non collegato', S.danger),
      FiscalAccountStatus(expired: true) => (
        'Password Fisconline scaduta: rinnovala',
        S.danger,
      ),
      FiscalAccountStatus(renewSoon: true, :final daysLeft) => (
        'Collegato · rinnova la password (scade tra $daysLeft giorni)',
        S.warning,
      ),
      FiscalAccountStatus(:final daysLeft) => (
        'Collegato · password valida ancora $daysLeft giorni',
        S.success,
      ),
    };
    return Container(
      key: const ValueKey('fiscal-account'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: S.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: S.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: statusColor),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Account Agenzia delle Entrate (Fisconline)',
                  style: ST.h3,
                ),
              ),
              Pill(statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Le credenziali sono cifrate sul PC del server e non vengono mai '
            'mostrate né inviate ai totem. Inseriscile dal PC del server o '
            'da una cassa della rete del locale.',
            style: ST.small,
          ),
          if (connected && !_editing) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _Fact('Utente', s!.taxCode ?? '—'),
                if (s.updatedAt case final d?)
                  _Fact('Password inserita il', _day(d)),
                if (s.passwordExpiresAt case final d?)
                  _Fact('Scadenza password', _day(d)),
                if (s.lastCheckAt case final d?)
                  _Fact(
                    'Ultima operazione',
                    '${_day(d)} · ${s.lastCheckOk == true ? 'riuscita' : 'non riuscita'}',
                  ),
              ],
            ),
          ],
          if (showForm) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    key: const ValueKey('ade-taxcode'),
                    controller: _taxCode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Codice fiscale utente',
                      hintText: connected ? 'Invariato' : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    key: const ValueKey('ade-password'),
                    controller: _password,
                    obscureText: !_showPassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: connected ? 'Nuova password' : 'Password',
                      suffixIcon: IconButton(
                        tooltip: _showPassword ? 'Nascondi' : 'Mostra',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    key: const ValueKey('ade-pin'),
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      labelText: 'PIN (10 cifre)',
                      hintText: connected ? 'Invariato' : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (showForm)
                FilledButton.icon(
                  key: const ValueKey('ade-save'),
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.lock_rounded),
                  label: Text(connected ? 'Salva' : 'Collega account'),
                ),
              if (showForm && connected)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _editing = false),
                  child: const Text('Annulla'),
                ),
              if (connected && !_editing) ...[
                FilledButton.icon(
                  key: const ValueKey('ade-check'),
                  onPressed: _busy ? null : _verify,
                  icon: const Icon(Icons.wifi_tethering_rounded),
                  label: const Text('Verifica collegamento'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('ade-renew'),
                  onPressed: _busy
                      ? null
                      : () => setState(() => _editing = true),
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Aggiorna password'),
                ),
                TextButton.icon(
                  key: const ValueKey('ade-disconnect'),
                  style: TextButton.styleFrom(foregroundColor: S.danger),
                  onPressed: _busy ? null : _disconnect,
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Scollega'),
                ),
              ],
            ],
          ),
          if (_check case final message?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    _checkOk == true
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: _checkOk == true ? S.success : S.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      key: const ValueKey('ade-check-result'),
                      style: ST.body,
                    ),
                  ),
                ],
              ).animate().fadeIn().slideY(begin: 0.2),
            ),
        ],
      ),
    );
  }

  static String _day(DateTime d) {
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/${l.year}';
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: ST.small),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}

/// What the venue does once, outside the app.
class _Requirements extends StatelessWidget {
  const _Requirements();

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Credenziali Fisconline intestate al titolare o al gestore incaricato: '
          'al primo accesso al portale cambia la password iniziale e accetta '
          'le condizioni del servizio, poi inseriscile qui.',
      'La password Fisconline scade ogni 90 giorni: rinnovala sul portale e '
          'aggiornala qui (ti avvisiamo dal 60° giorno).',
      'Dal 2026 ogni POS va abbinato alla procedura di memorizzazione dal '
          'servizio "Gestisci collegamenti" del portale Fatture e '
          'Corrispettivi.',
      'Il codice lotteria si accetta solo con pagamento elettronico; il '
          'codice fiscale del cliente solo se lo chiede.',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: S.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: S.info),
              SizedBox(width: 8),
              Text('Da fare una volta sul portale', style: ST.h3),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, t) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}.', style: ST.small),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: ST.small)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final (String, VoidCallback)? action;
  const _Notice({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: ST.body)),
        if (action case (final label, final onPressed))
          TextButton(onPressed: onPressed, child: Text(label)),
      ],
    ),
  );
}
