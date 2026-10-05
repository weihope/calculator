import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utlis/gold_calculator.dart';
import '../utlis/trade_record_db.dart';

class GoldScreen extends StatefulWidget {
  const GoldScreen({super.key});
  @override
  State<GoldScreen> createState() => _GoldScreenState();
}

class _GoldScreenState extends State<GoldScreen> {
  static const preferenceKey = 'xauusd.settings.v1';
  final _fields = <String, TextEditingController>{
    for (final key in [
      'Balance',
      'Risk percent',
      'Risk amount',
      'Entry price',
      'Stop loss',
      'Take profit',
      'Lot',
      'Exit price',
      'Total fees',
      'Remark',
    ])
      key: TextEditingController(),
  };
  GoldContract _contract = const GoldContract();
  bool _lotMode = true,
      _long = true,
      _percent = true,
      _loading = true,
      _saving = false;
  Future<void> _preferenceWrite = Future.value();
  String? _storageError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(preferenceKey);
      if (!mounted) return;
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        final contract = GoldContract.fromJson(
          Map<String, dynamic>.from(data['contract'] as Map),
        );
        contract.validate();
        _contract = contract;
        _percent = data['percentRisk'] != false;
        for (final key in ['Balance', 'Risk percent', 'Risk amount']) {
          _fields[key]!.text = data[key] as String? ?? '';
        }
      }
    } catch (_) {
      _storageError =
          'Saved settings could not be loaded. Please check contract settings.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _persist() {
    final snapshot = jsonEncode({
      'contract': _contract.toJson(),
      'percentRisk': _percent,
      for (final key in ['Balance', 'Risk percent', 'Risk amount'])
        key: _fields[key]!.text,
    });
    _preferenceWrite = _preferenceWrite
        .then((_) async {
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString(preferenceKey, snapshot))
            throw StateError('Settings write failed');
        })
        .catchError((Object error) {
          if (mounted)
            setState(() => _storageError = 'Settings could not be saved.');
        });
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  GoldResult _calculate() => calculateGold(
    contract: _contract,
    lotMode: _lotMode,
    isLong: _long,
    percentRisk: _percent,
    inputs: {
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
    },
  );
  Future<void> _save() async {
    if (_saving) return;
    final result = _calculate();
    setState(() => _saving = true);
    try {
      await TradeRecordDb.instance.insertGoldRecord(result);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('XAUUSD record saved')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _settings() async {
    final values = [
      _contract.size,
      _contract.pip,
      _contract.minimum,
      _contract.step,
    ];
    final controls = values.map((v) => TextEditingController(text: v)).toList();
    var confirmed = _contract.confirmed;
    String? error;
    final result = await showDialog<GoldContract>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('XAUUSD contract'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Example specifications. Check your broker before marking confirmed.',
                ),
                for (var i = 0; i < controls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: controls[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: [
                          'Contract size (troy oz/lot)',
                          'Pip size (USD/oz)',
                          'Minimum lot',
                          'Lot step',
                        ][i],
                      ),
                      onChanged: (_) => update(() {
                        confirmed = false;
                        error = null;
                      }),
                    ),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Verified against my broker'),
                  value: confirmed,
                  onChanged: (v) => update(() => confirmed = v ?? false),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final next = GoldContract(
                  size: controls[0].text.trim(),
                  pip: controls[1].text.trim(),
                  minimum: controls[2].text.trim(),
                  step: controls[3].text.trim(),
                  confirmed: confirmed,
                );
                try {
                  next.validate();
                  Navigator.pop(dialogContext, next);
                } on FormatException catch (e) {
                  update(() => error = e.message);
                }
              },
              child: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
    // The dialog route keeps its fields alive during its reverse transition.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in controls) {
      controller.dispose();
    }
    if (!mounted || result == null) return;
    setState(() => _contract = result);
    _persist();
  }

  Widget _input(String label, {String? unit, bool optional = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      key: ValueKey('gold-$label'),
      controller: _fields[label],
      keyboardType: label == 'Remark'
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      maxLines: label == 'Remark' ? 2 : 1,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: '$label${optional ? ' (optional)' : ''}',
        suffixText: unit,
      ),
      onChanged: (_) {
        setState(() {});
        if (['Balance', 'Risk percent', 'Risk amount'].contains(label))
          _persist();
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    GoldResult? result;
    String? error;
    try {
      result = _calculate();
    } on FormatException catch (e) {
      error = e.message;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'XAUUSD',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Contract settings',
              onPressed: _settings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        Text(
          _contract.confirmed
              ? 'Contract specifications confirmed · USD account'
              : 'Example contract · Specifications unconfirmed',
          style: TextStyle(
            color: _contract.confirmed
                ? Colors.green.shade800
                : Colors.orange.shade900,
          ),
        ),
        Text(
          '${_contract.size} oz/lot · Pip ${_contract.pip} USD/oz · Min ${_contract.minimum} · Step ${_contract.step}',
        ),
        if (_storageError != null)
          Text(
            _storageError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Lot Size')),
            ButtonSegment(value: false, label: Text('P&L')),
          ],
          selected: {_lotMode},
          onSelectionChanged: (v) => setState(() => _lotMode = v.single),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Long')),
            ButtonSegment(value: false, label: Text('Short')),
          ],
          selected: {_long},
          onSelectionChanged: (v) => setState(() => _long = v.single),
        ),
        const SizedBox(height: 20),
        if (_lotMode) ...[
          DropdownButtonFormField<bool>(
            initialValue: _percent,
            decoration: const InputDecoration(
              labelText: 'Risk budget',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: true, child: Text('Balance × risk %')),
              DropdownMenuItem(value: false, child: Text('Fixed USD amount')),
            ],
            onChanged: (v) {
              setState(() => _percent = v!);
              _persist();
            },
          ),
          const SizedBox(height: 14),
          if (_percent) ...[
            _input('Balance', unit: 'USD'),
            _input('Risk percent', unit: '%'),
          ] else
            _input('Risk amount', unit: 'USD'),
        ] else
          _input('Lot', unit: 'lot'),
        _input('Entry price', unit: 'USD/oz'),
        if (_lotMode) ...[
          _input('Stop loss', unit: 'USD/oz'),
          _input('Take profit', unit: 'USD/oz', optional: true),
        ] else
          _input('Exit price', unit: 'USD/oz'),
        _input('Total fees', unit: 'USD', optional: true),
        const Text(
          'Total fees for the entire trade, not per lot. Blank means fees are not included. Use actual fill prices for P&L; spread is not deducted again.',
        ),
        const SizedBox(height: 14),
        _input('Remark', optional: true),
        if (result != null)
          GoldResultCard(result: result)
        else
          Text(
            error ?? 'Enter trade details.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: result == null || _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save to Records'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class GoldResultCard extends StatelessWidget {
  const GoldResultCard({super.key, required this.result});
  final GoldResult result;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(result.payload['isLong'] == true ? 'Long' : 'Short'),
          Text(
            result.confirmed
                ? 'Contract confirmed'
                : 'Contract specifications unconfirmed',
            style: TextStyle(
              color: result.confirmed
                  ? Colors.green.shade800
                  : Colors.orange.shade900,
            ),
          ),
          const Divider(),
          for (final row in result.rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(row.key)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          if ((result.payload['remark'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Remark: ${result.payload['remark']}'),
            ),
        ],
      ),
    ),
  );
}
