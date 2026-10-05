import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:calculator/utlis/gold_calculator.dart';

void main() {
  GoldResult calculate({
    bool lot = false,
    bool long = true,
    GoldContract contract = const GoldContract(),
    Map<String, String> extra = const {},
  }) => calculateGold(
    contract: contract,
    lotMode: lot,
    isLong: long,
    percentRisk: false,
    inputs: {
      'Entry price': '2000',
      'Exit price': '2001',
      'Lot': '0.10',
      'Risk amount': '100',
      'Stop loss': '1990',
      ...extra,
    },
  );
  test('0.1 lot and one dollar price change gives 10 USD and 100 pips', () {
    final result = calculate();
    expect(result.rows['Gross P&L (USD)'], '10.00');
    expect(result.rows['Signed pips'], '100.00');
    expect(result.rows['Pip value (USD)'], '0.1000');
    expect(calculate(long: false).rows['Gross P&L (USD)'], '-10.00');
    expect(
      calculate(
        long: false,
        extra: {'Exit price': '1999'},
      ).rows['Gross P&L (USD)'],
      '10.00',
    );
    expect(
      calculate(
        extra: {'Exit price': '2000', 'Total fees': '2'},
      ).rows['Net P&L (USD)'],
      '-2.00',
    );
  });
  test('fees included before rounding lots down and snapshot roundtrip', () {
    final result = calculate(
      lot: true,
      extra: {'Total fees': '5', 'Take profit': '2020'},
    );
    expect(result.rows['Lot'], '0.09');
    expect(result.rows['Stop loss incl. entered fees (USD)'], '95.00');
    expect(result.rows['Expected gross profit (USD)'], '180.00');
    expect(result.rows['Expected net profit (USD)'], '175.00');
    expect(result.rows['Risk : reward (before fees)'], '1 : 2.00');
    expect(
      GoldResult.decode(jsonEncode(result.payload)).shareText,
      result.shareText,
    );
    calculate(contract: const GoldContract(size: '50'));
    expect(result.rows['Contract (oz/lot)'], '100');
  });
  test('exact budget boundary and nonzero minimum grid', () {
    expect(
      calculate(lot: true, extra: {'Risk amount': '30'}).rows['Lot'],
      '0.03',
    );
    expect(
      calculate(lot: true, extra: {'Risk amount': '29.9999999999'}).rows['Lot'],
      '0.02',
    );
    expect(
      calculate(
        lot: true,
        contract: const GoldContract(minimum: '0.03', step: '0.02'),
      ).rows['Lot'],
      '0.09',
    );
    expect(
      () => calculate(
        contract: const GoldContract(minimum: '0.03', step: '0.02'),
      ),
      throwsFormatException,
    );
  });
  test('invalid inputs never generate savable results', () {
    for (final extra in <Map<String, String>>[
      {'Risk amount': '9'},
      {'Total fees': '100'},
      {'Total fees': '-1'},
      {'Stop loss': '2000'},
      {'Stop loss': '2001'},
      {'Take profit': '1999'},
      {'Entry price': 'NaN'},
      {'Entry price': 'Infinity'},
      {'Entry price': ''},
      {'Entry price': '0'},
    ]) {
      expect(
        () => calculate(lot: true, extra: extra),
        throwsFormatException,
        reason: '$extra',
      );
    }
    expect(() => calculate(extra: {'Lot': '0.015'}), throwsFormatException);
    expect(
      () => calculate(contract: const GoldContract(pip: '0')),
      throwsFormatException,
    );
  });
  test('percentage budget, short stop and empty versus explicit zero fees', () {
    final result = calculateGold(
      contract: const GoldContract(),
      lotMode: true,
      isLong: false,
      inputs: {
        'Balance': '10000',
        'Risk percent': '1',
        'Entry price': '2000',
        'Stop loss': '2010',
        'Take profit': '1980',
      },
    );
    expect(result.rows['Lot'], '0.10');
    expect(result.rows['Expected gross profit (USD)'], '200.00');
    expect(result.payload['feesEntered'], false);
    expect(calculate(extra: {'Total fees': '0'}).payload['feesEntered'], true);
    expect(
      () => calculateGold(
        contract: const GoldContract(),
        lotMode: true,
        isLong: true,
        inputs: {
          'Balance': '100',
          'Risk percent': '101',
          'Entry price': '2000',
        },
      ),
      throwsFormatException,
    );
  });
}
