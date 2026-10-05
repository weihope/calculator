import 'package:flutter/material.dart';
import 'package:calculator/utlis/cal_function.dart';
import 'package:calculator/utlis/method_shared_preferences.dart';
import 'package:calculator/utlis/trade_record_db.dart';

class FirstScreen extends StatefulWidget {
  const FirstScreen({super.key});

  @override
  State<FirstScreen> createState() => _FirstScreenState();
}

const String marginCostLabel = 'Margin Cost';
const String balanceLabel = 'Balance';
const String investmentLabel = 'Investment';
const String leverageLabel = 'Leverage';

class _FirstScreenState extends State<FirstScreen> {
  bool isLongPressed = true;

  final TextEditingController _balanceInputController = TextEditingController();
  final TextEditingController _investmentInputController =
      TextEditingController();
  final TextEditingController _leverageInputController =
      TextEditingController();
  final TextEditingController _entryPriceInputController =
      TextEditingController();
  final TextEditingController _stopLossInputController =
      TextEditingController();
  final TextEditingController _investmentAmountController =
      TextEditingController();
  final TextEditingController _marginCostController = TextEditingController();
  final TextEditingController _targetPriceInputController =
      TextEditingController();
  final TextEditingController _stopLossPriceController =
      TextEditingController();
  final TextEditingController _riskRewardsRatioController =
      TextEditingController();
  final TextEditingController _potentialProfitController =
      TextEditingController();
  final TextEditingController _potentialLossController =
      TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  @override
  void dispose() {
    _balanceInputController.dispose();
    _investmentInputController.dispose();
    _leverageInputController.dispose();
    _entryPriceInputController.dispose();
    _stopLossInputController.dispose();
    _marginCostController.dispose();
    _stopLossPriceController.dispose();
    _targetPriceInputController.dispose();
    _riskRewardsRatioController.dispose();
    _potentialProfitController.dispose();
    _potentialLossController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSharedPreferences(balanceLabel);
    _loadSharedPreferences(investmentLabel);
    _loadSharedPreferences(leverageLabel);

    _balanceInputController.addListener(_calculateValues);
    _investmentInputController.addListener(_calculateValues);
    _leverageInputController.addListener(_calculateValues);
    _investmentAmountController.addListener(_calculateValues);
    _entryPriceInputController.addListener(_calculateValues);
    _targetPriceInputController.addListener(_calculateValues);
    _stopLossInputController.addListener(_calculateValues);
    _riskRewardsRatioController.addListener(_calculateValues);
    _potentialProfitController.addListener(_calculateValues);
    _potentialLossController.addListener(_calculateValues);
  }

  void _calculateValues() {
    final double balance = double.tryParse(_balanceInputController.text) ?? 0;
    final double investment =
        double.tryParse(_investmentInputController.text) ?? 0;
    final double leverage = double.tryParse(_leverageInputController.text) ?? 0;
    final double entryPrice =
        double.tryParse(_entryPriceInputController.text) ?? 0;
    final double stopLoss = double.tryParse(_stopLossInputController.text) ?? 0;
    final double takeProfitPrice =
        double.tryParse(_targetPriceInputController.text) ?? 0;

    if (balance > 0 && investment > 0) {
      final double investmentAmount = calculateInvestmentAmount(
        balance,
        investment,
      );
      _investmentAmountController.text = investmentAmount.toStringAsFixed(2);
    } else {
      _investmentAmountController.clear();
    }

    if (balance > 0 && investment > 0 && leverage > 0 && stopLoss > 0) {
      final double marginCost = calculateMarginCost(
        balance,
        investment,
        leverage,
        stopLoss,
      );
      _marginCostController.text = marginCost.toStringAsFixed(7);
    } else {
      _marginCostController.clear();
    }

    if (entryPrice > 0 && stopLoss > 0) {
      final double stopLossPrice = calculateStopLossPrice(
        entryPrice,
        stopLoss,
        isLongPressed,
      );

      _stopLossPriceController.text = stopLossPrice.toStringAsFixed(2);
    } else {
      _stopLossPriceController.clear();
    }

    if (entryPrice > 0 && stopLoss > 0 && takeProfitPrice > 0) {
      final double stopLossPrice = calculateStopLossPrice(
        entryPrice,
        stopLoss,
        isLongPressed,
      );

      final String riskRewardRatio = calculateRiskRewardRatio(
        entryPrice,
        takeProfitPrice,
        stopLossPrice,
        isLongPressed,
      );

      _riskRewardsRatioController.text = riskRewardRatio;
    } else {
      _riskRewardsRatioController.clear();
    }

    if (entryPrice > 0 &&
        balance > 0 &&
        investment > 0 &&
        stopLoss > 0 &&
        takeProfitPrice > 0 &&
        leverage > 0) {
      final double marginCost = calculateMarginCost(
        balance,
        investment,
        leverage,
        stopLoss,
      );
      final double stopLossPrice = calculateStopLossPrice(
        entryPrice,
        stopLoss,
        isLongPressed,
      );

      final double potentialLoss = calculatePotentialLoss(
        entryPrice,
        stopLossPrice,
        marginCost,
        leverage,
        isLongPressed,
      );

      final double potentialProfit = calculatePotentialProfit(
        entryPrice,
        takeProfitPrice,
        marginCost,
        leverage,
        isLongPressed,
      );
      _potentialProfitController.text = potentialProfit.toStringAsFixed(2);

      _potentialLossController.text = potentialLoss.toStringAsFixed(2);
    } else {
      _potentialProfitController.clear();
      _potentialLossController.clear();
    }
  }

  Future<void> _save(key) async {
    switch (key) {
      case balanceLabel:
        await saveValue(key, _balanceInputController.text);
        break;
      case investmentLabel:
        await saveValue(key, _investmentInputController.text);
        break;
      case leverageLabel:
        await saveValue(key, _leverageInputController.text);
        break;
      default:
        break;
    }
  }

  Future<void> _loadSharedPreferences(key) async {
    final value = await loadValue(key);

    switch (key) {
      case balanceLabel:
        _balanceInputController.text = value ?? '';
        break;
      case investmentLabel:
        _investmentInputController.text = value ?? '';
        break;
      case leverageLabel:
        _leverageInputController.text = value ?? '';
        break;
      default:
        break;
    }
  }

  Future<void> _saveTradeRecord() async {
    final double? balance = double.tryParse(_balanceInputController.text);
    final double? investment = double.tryParse(_investmentInputController.text);
    final double? leverage = double.tryParse(_leverageInputController.text);
    final double? entryPrice = double.tryParse(_entryPriceInputController.text);
    final double? targetPrice = double.tryParse(
      _targetPriceInputController.text,
    );
    final double? stopLoss = double.tryParse(_stopLossInputController.text);
    final String remark = _remarkController.text.trim();

    if (balance == null ||
        investment == null ||
        leverage == null ||
        entryPrice == null ||
        stopLoss == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields with valid numbers'),
        ),
      );
      return;
    }

    await TradeRecordDb.instance.insertTradeRecord(
      balance: balance,
      investment: investment,
      leverage: leverage,
      entryPrice: entryPrice,
      targetPrice: targetPrice,
      stopLoss: stopLoss,
      isLong: isLongPressed,
      remark: remark.isEmpty ? null : remark,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Record saved')));
  }

  Widget _buildModeButton({
    required String text,
    required bool selected,
    required Color activeColor,
    required BorderRadius borderRadius,
    required double width,
    required double height,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.grey[400],
          border: Border.all(color: Colors.grey),
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required double width,
    required TextEditingController controller,
    String labelText = 'Input',
    String hintText = '',
    String? prefixText,
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool clickable = true,
    int maxLines = 1,
    Color borderColor = Colors.grey,
    Color textColor = Colors.black,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textAlignVertical: TextAlignVertical.center,
        readOnly: readOnly,
        enabled: clickable,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          prefixText: prefixText,
          suffix: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(suffixText ?? '')],
          ),
          labelText: labelText,
          hintText: hintText,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          suffixIcon:
              labelText == balanceLabel ||
                  labelText == investmentLabel ||
                  labelText == leverageLabel
              ? TextButton(
                  onPressed: () async {
                    await _save(labelText);
                  },
                  child: const Text("Save"),
                )
              : null,
          disabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    const Radius buttonRadius = Radius.circular(10);
    final double buttonHeight = screenHeight * 0.06;
    final double buttonWidth = screenWidth * 0.45;
    final double textFieldWidth = screenWidth * 0.9;
    final double halfTextFieldWidth = (textFieldWidth - 12) / 2;

    return ColoredBox(
      color: Colors.transparent,
      child: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              spacing: screenHeight * 0.03,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildModeButton(
                      text: 'Long',
                      selected: isLongPressed,
                      activeColor: const Color(0xFF16C784),
                      borderRadius: const BorderRadius.only(
                        topLeft: buttonRadius,
                        bottomLeft: buttonRadius,
                      ),
                      width: buttonWidth,
                      height: buttonHeight,
                      onTap: () {
                        setState(() {
                          isLongPressed = true;
                        });
                        _calculateValues();
                      },
                    ),
                    _buildModeButton(
                      text: 'Short',
                      selected: !isLongPressed,
                      activeColor: const Color(0xFFEA3943),
                      borderRadius: const BorderRadius.only(
                        topRight: buttonRadius,
                        bottomRight: buttonRadius,
                      ),
                      width: buttonWidth,
                      height: buttonHeight,
                      onTap: () {
                        setState(() {
                          isLongPressed = false;
                        });
                        _calculateValues();
                      },
                    ),
                  ],
                ),
                _buildCustomTextField(
                  width: textFieldWidth,
                  controller: _balanceInputController,
                  keyboardType: TextInputType.number,
                  labelText: balanceLabel,
                  hintText: 'Enter balance',
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCustomTextField(
                      width: halfTextFieldWidth,
                      keyboardType: TextInputType.number,
                      controller: _investmentInputController,
                      suffixText: '%',
                      labelText: investmentLabel,
                      hintText: 'Enter investment amount',
                    ),
                    const SizedBox(width: 12),
                    _buildCustomTextField(
                      width: halfTextFieldWidth,
                      keyboardType: TextInputType.number,
                      controller: _investmentAmountController,
                      labelText: 'Investment Amount',
                      hintText: '',
                      suffixText: 'USDT',
                      readOnly: true,
                      clickable: false,
                    ),
                  ],
                ),
                _buildCustomTextField(
                  width: textFieldWidth,
                  keyboardType: TextInputType.number,
                  controller: _leverageInputController,
                  suffixText: 'X',
                  labelText: leverageLabel,
                  hintText: 'Enter leverage',
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCustomTextField(
                      width: halfTextFieldWidth,
                      keyboardType: TextInputType.number,
                      controller: _entryPriceInputController,
                      labelText: 'Entry Price',
                      hintText: 'Enter Entry Price',
                    ),
                    const SizedBox(width: 12),
                    _buildCustomTextField(
                      width: halfTextFieldWidth,
                      keyboardType: TextInputType.number,
                      controller: _targetPriceInputController,
                      labelText: 'Take Profit',
                      hintText: 'Enter Take Profit',
                      borderColor: Colors.green,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCustomTextField(
                      width: halfTextFieldWidth,
                      keyboardType: TextInputType.number,
                      controller: _stopLossInputController,
                      labelText: 'Stop Loss',
                      hintText: 'Enter Stop Loss',
                      suffixText: '%',
                    ),
                    const SizedBox(width: 12),
                    _buildCustomTextField(
                      width: halfTextFieldWidth,
                      keyboardType: TextInputType.number,
                      controller: _stopLossPriceController,
                      labelText: 'Stop Loss Price',
                      hintText: '',
                      readOnly: true,
                      clickable: false,
                      borderColor: Colors.red,
                    ),
                  ],
                ),
                _buildCustomTextField(
                  width: textFieldWidth,
                  keyboardType: TextInputType.number,
                  controller: _marginCostController,
                  labelText: marginCostLabel,
                  hintText: '',
                  readOnly: true,
                  clickable: false,
                ),
                _buildCustomTextField(
                  width: textFieldWidth,
                  keyboardType: TextInputType.number,
                  controller: _riskRewardsRatioController,
                  labelText: 'Risk : Reward',
                  hintText: '',
                  readOnly: true,
                  clickable: false,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCustomTextField(
                      width: halfTextFieldWidth,
                      keyboardType: TextInputType.number,
                      controller: _potentialProfitController,
                      labelText: 'Potential Profit',
                      hintText: '',
                      suffixText: 'USDT',
                      readOnly: true,
                      clickable: false,
                      borderColor: const Color(0xFF16C784),
                      textColor: const Color(0xFF16C784),
                    ),
                    const SizedBox(width: 12),
                    _buildCustomTextField(
                      width: halfTextFieldWidth,
                      keyboardType: TextInputType.number,
                      controller: _potentialLossController,
                      labelText: 'Potential Loss',
                      hintText: '',
                      suffixText: 'USDT',
                      readOnly: true,
                      clickable: false,
                      borderColor: Colors.red,
                      textColor: Colors.red,
                    ),
                  ],
                ),
                _buildCustomTextField(
                  width: textFieldWidth,
                  controller: _remarkController,
                  labelText: 'Remark',
                  hintText: 'Optional note for this record',
                  maxLines: 3,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _balanceInputController.clear();
                          _investmentInputController.clear();
                          _leverageInputController.clear();
                          _entryPriceInputController.clear();
                          _targetPriceInputController.clear();
                          _stopLossInputController.clear();
                          _investmentAmountController.clear();
                          _marginCostController.clear();
                          _stopLossPriceController.clear();
                          _riskRewardsRatioController.clear();
                          _potentialProfitController.clear();
                          _potentialLossController.clear();
                          _remarkController.clear();
                        });
                        FocusScope.of(context).unfocus();
                      },
                      child: Container(
                        width: halfTextFieldWidth,
                        height: buttonHeight * 0.9,
                        decoration: BoxDecoration(
                          color: Colors.red[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'Clear',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        await _saveTradeRecord();
                      },
                      child: Container(
                        width: halfTextFieldWidth,
                        height: buttonHeight * 0.9,
                        decoration: BoxDecoration(
                          color: Colors.blue[500],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'Save',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
