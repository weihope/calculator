import 'dart:convert';

/// Exact rational arithmetic; decimal input never passes through binary doubles.
class GoldNumber implements Comparable<GoldNumber> {
  GoldNumber(BigInt numerator, [BigInt? denominator])
    : n = numerator,
      d = denominator ?? BigInt.one;
  factory GoldNumber.parse(String text) {
    final value = text.trim();
    if (value.length > 40 || !RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
      throw const FormatException('Enter a finite decimal number.');
    }
    final parts = value.split('.');
    return GoldNumber(
      BigInt.parse(parts.join()),
      BigInt.from(10).pow(parts.length == 2 ? parts[1].length : 0),
    );
  }
  final BigInt n;
  final BigInt d;
  static final zero = GoldNumber(BigInt.zero);
  GoldNumber operator +(GoldNumber b) => GoldNumber(n * b.d + b.n * d, d * b.d);
  GoldNumber operator -(GoldNumber b) => GoldNumber(n * b.d - b.n * d, d * b.d);
  GoldNumber operator *(GoldNumber b) => GoldNumber(n * b.n, d * b.d);
  GoldNumber operator /(GoldNumber b) {
    if (b.n == BigInt.zero)
      throw const FormatException('Cannot divide by zero.');
    return GoldNumber(n * b.d, d * b.n);
  }

  GoldNumber get abs => GoldNumber(n.abs(), d.abs());
  BigInt get floor => n ~/ d;
  bool get isInteger => n % d == BigInt.zero;
  @override
  int compareTo(GoldNumber other) => (n * other.d).compareTo(other.n * d);
  String fixed([int places = 2]) {
    final scale = BigInt.from(10).pow(places);
    final rounded =
        (n.abs() * scale * BigInt.two + d.abs()) ~/ (d.abs() * BigInt.two);
    final digits = rounded.toString().padLeft(places + 1, '0');
    return '${n.sign * d.sign < 0 ? '-' : ''}${places == 0 ? digits : '${digits.substring(0, digits.length - places)}.${digits.substring(digits.length - places)}'}';
  }

  String exact() {
    // Inputs and lot-grid results terminate; ratios are stored as fractions.
    return '$n/$d';
  }
}

class GoldContract {
  const GoldContract({
    this.size = '100',
    this.pip = '0.01',
    this.minimum = '0.01',
    this.step = '0.01',
    this.confirmed = false,
  });
  final String size, pip, minimum, step;
  final bool confirmed;
  Map<String, dynamic> toJson() => {
    'size': size,
    'pip': pip,
    'minimum': minimum,
    'step': step,
    'confirmed': confirmed,
  };
  factory GoldContract.fromJson(Map<String, dynamic> json) => GoldContract(
    size: json['size'] as String,
    pip: json['pip'] as String,
    minimum: json['minimum'] as String,
    step: json['step'] as String,
    confirmed: json['confirmed'] == true,
  );
  void validate() {
    for (final value in [size, pip, minimum, step]) {
      positive(value, 'Contract parameter');
    }
  }

  int get lotPlaces => [minimum, step]
      .map((v) => v.contains('.') ? v.split('.').last.length : 0)
      .reduce((a, b) => a > b ? a : b);
}

GoldNumber positive(String text, String label) {
  final value = GoldNumber.parse(text);
  if (value.compareTo(GoldNumber.zero) <= 0)
    throw FormatException('$label must be greater than zero.');
  return value;
}

class GoldResult {
  GoldResult(this.payload);
  final Map<String, dynamic> payload;
  factory GoldResult.decode(String json) {
    final payload = jsonDecode(json) as Map<String, dynamic>;
    if (payload['version'] != 1)
      throw const FormatException('Unsupported gold record version.');
    return GoldResult(payload);
  }
  String get title =>
      'XAUUSD · ${payload['mode'] == 'lot' ? 'Lot Size' : 'P&L'}';
  bool get confirmed => (payload['contract'] as Map)['confirmed'] == true;
  Map<String, String> get rows =>
      Map<String, String>.from(payload['display'] as Map);
  String get shareText => [
    title,
    payload['isLong'] == true ? 'Long' : 'Short',
    confirmed ? 'Contract confirmed' : 'Contract specifications unconfirmed',
    ...rows.entries.map((e) => '${e.key}: ${e.value}'),
    if ((payload['remark'] as String).isNotEmpty)
      'Remark: ${payload['remark']}',
  ].join('\n');
}

GoldResult calculateGold({
  required GoldContract contract,
  required bool lotMode,
  required bool isLong,
  required Map<String, String> inputs,
  bool percentRisk = true,
}) {
  contract.validate();
  GoldNumber read(String key) => positive(inputs[key] ?? '', key);
  final c = GoldNumber.parse(contract.size), p = GoldNumber.parse(contract.pip);
  final min = GoldNumber.parse(contract.minimum),
      step = GoldNumber.parse(contract.step);
  final entry = read('Entry price');
  final feeText = (inputs['Total fees'] ?? '').trim();
  final fee = feeText.isEmpty ? GoldNumber.zero : GoldNumber.parse(feeText);
  final exact = <String, String>{};
  final rows = <String, String>{'Entry price (USD/oz)': inputs['Entry price']!};
  void output(String label, GoldNumber number, [int places = 2]) {
    rows[label] = number.fixed(places);
    exact[label] = number.exact();
  }

  late GoldNumber lots;
  if (lotMode) {
    late GoldNumber risk;
    if (percentRisk) {
      final percent = read('Risk percent');
      if (percent.compareTo(GoldNumber.parse('100')) > 0)
        throw const FormatException('Risk percent must not exceed 100.');
      risk = read('Balance') * percent / GoldNumber.parse('100');
    } else {
      risk = read('Risk amount');
    }
    if (risk.compareTo(fee) <= 0)
      throw const FormatException('Fees exhaust the risk budget.');
    final stop = read('Stop loss');
    final distance = isLong ? entry - stop : stop - entry;
    if (distance.compareTo(GoldNumber.zero) <= 0)
      throw FormatException(
        isLong
            ? 'Long stop loss must be below entry.'
            : 'Short stop loss must be above entry.',
      );
    final raw = (risk - fee) / (distance * c);
    if (raw.compareTo(min) < 0)
      throw const FormatException('Risk budget is below the minimum lot.');
    lots = min + GoldNumber(((raw - min) / step).floor) * step;
    output('Lot', lots, contract.lotPlaces);
    output('Risk budget (USD)', risk);
    rows['Stop loss (USD/oz)'] = inputs['Stop loss']!;
    output('Stop distance (pips)', distance / p);
    output('Stop loss incl. entered fees (USD)', distance * c * lots + fee);
    final targetText = (inputs['Take profit'] ?? '').trim();
    if (targetText.isNotEmpty) {
      final target = positive(targetText, 'Take profit');
      final reward = isLong ? target - entry : entry - target;
      if (reward.compareTo(GoldNumber.zero) <= 0)
        throw FormatException(
          isLong
              ? 'Long take profit must be above entry.'
              : 'Short take profit must be below entry.',
        );
      rows['Take profit (USD/oz)'] = targetText;
      output('Expected gross profit (USD)', reward * c * lots);
      output('Expected net profit (USD)', reward * c * lots - fee);
      rows['Risk : reward (before fees)'] =
          '1 : ${(reward / distance).fixed()}';
      exact['rewardRatio'] = (reward / distance).exact();
    }
  } else {
    lots = read('Lot');
    if (lots.compareTo(min) < 0 || !((lots - min) / step).isInteger)
      throw const FormatException(
        'Lot must match the contract minimum and step.',
      );
    final exit = read('Exit price');
    final movement = isLong ? exit - entry : entry - exit;
    output('Lot', lots, contract.lotPlaces);
    rows['Exit price (USD/oz)'] = inputs['Exit price']!;
    output('Signed pips', movement / p);
    output('Gross P&L (USD)', movement * c * lots);
    output('Net P&L (USD)', movement * c * lots - fee);
  }
  output('Pip value (USD)', lots * c * p, 4);
  rows['Total fees (USD)'] = feeText.isEmpty ? 'Not included' : fee.fixed();
  rows['Contract (oz/lot)'] = contract.size;
  rows['Pip size (USD/oz)'] = contract.pip;
  rows['Minimum / step (lot)'] = '${contract.minimum} / ${contract.step}';
  return GoldResult({
    'version': 1,
    'mode': lotMode ? 'lot' : 'pnl',
    'isLong': isLong,
    'percentRisk': percentRisk,
    'inputs': Map<String, String>.from(inputs),
    'feesEntered': feeText.isNotEmpty,
    'contract': contract.toJson(),
    'exact': exact,
    'display': rows,
    'remark': inputs['Remark'] ?? '',
  });
}
