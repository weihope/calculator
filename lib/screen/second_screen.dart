import 'dart:io';

import 'package:calculator/screen/third_screen.dart';
import 'package:calculator/utlis/cal_function.dart';
import 'package:calculator/utlis/trade_record_db.dart';
import 'package:calculator/utlis/gold_calculator.dart';
import 'package:calculator/screen/gold_screen.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class SecondScreen extends StatefulWidget {
  const SecondScreen({super.key});

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> {
  late Future<List<Map<String, dynamic>>> _recordsFuture;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final ScreenshotController _screenshotController = ScreenshotController();
  final Set<int> _selectedRecordIds = <int>{};
  bool _isFilterAnimating = false;
  _RecordFilter _recordFilter = _RecordFilter.all;

  String _formatRiskRewardRatio(
    double entryPrice,
    double? targetPrice,
    double stopLossPrice,
    bool isLong,
  ) {
    if (targetPrice == null || targetPrice <= 0) {
      return '--';
    }

    return calculateRiskRewardRatio(
      entryPrice,
      targetPrice,
      stopLossPrice,
      isLong,
    );
  }

  @override
  void initState() {
    super.initState();
    _recordsFuture = TradeRecordDb.instance.getTradeRecords();
    TradeRecordDb.instance.changes.addListener(_reloadRecords);
  }

  @override
  void dispose() {
    TradeRecordDb.instance.changes.removeListener(_reloadRecords);
    super.dispose();
  }

  Widget _goldRecord(Map<String, dynamic> record) {
    final id = (record['id'] as num).toInt();
    Widget content;
    try {
      content = GoldResultCard(
        result: GoldResult.decode(record['payload_json'] as String),
      );
    } catch (_) {
      content = const Text('XAUUSD record cannot be read.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(
              value: _selectedRecordIds.contains(id),
              onChanged: (v) => _toggleRecordSelection(id, v ?? false),
            ),
            Expanded(child: Text(_formatCreatedAt(record['created_at']))),
            TextButton.icon(
              onPressed: () => _openSharePreview(record),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
        content,
      ],
    );
  }

  void _reloadRecords() {
    setState(() {
      _recordsFuture = TradeRecordDb.instance.getTradeRecords();
      _selectedRecordIds.clear();
    });
  }

  void _toggleRecordSelection(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedRecordIds.add(id);
      } else {
        _selectedRecordIds.remove(id);
      }
    });
  }

  Future<void> _unlockSavedRecords() async {
    try {
      final bool isSupported = await _localAuth.isDeviceSupported();
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;

      if (!isSupported || !canCheckBiometrics) {
        if (!mounted) {
          return;
        }
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ThirdScreen()));
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock saved records',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!mounted) {
        return;
      }

      if (!didAuthenticate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication cancelled.')),
        );
        return;
      }

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ThirdScreen()));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Authentication failed: $error')));
    }
  }

  Future<void> _clearRecords() async {
    await TradeRecordDb.instance.clearTradeRecords();
    _reloadRecords();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All records cleared')));
  }

  Future<bool> _confirmDeleteAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return shouldDelete ?? false;
  }

  Future<void> _deleteSelectedRecords() async {
    if (_selectedRecordIds.isEmpty) {
      return;
    }

    final shouldDelete = await _confirmDeleteAction(
      title: 'Delete selected records?',
      message:
          'This will permanently delete ${_selectedRecordIds.length} selected record(s).',
      confirmLabel: 'Delete',
    );
    if (!shouldDelete) {
      return;
    }

    final deletedCount = await TradeRecordDb.instance.deleteTradeRecordsByIds(
      _selectedRecordIds.toList(),
    );
    _reloadRecords();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$deletedCount selected record(s) deleted')),
    );
  }

  Widget _buildRecordRow(String label, String value, {Color? fontColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(color: fontColor ?? Colors.black),
        ),
      ],
    );
  }

  Widget _buildActionContainer({
    required Widget child,
    required VoidCallback onTap,
    Color borderColor = const Color(0xFFE5E7EB),
    Color backgroundColor = Colors.white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildOutcomeCard({
    required String amount,
    required String label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyPriceRow(
    String label,
    String value, {
    Color? valueColor,
    bool showBottomBorder = true,
    Color labelColor = const Color(0xFF6B7280),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: showBottomBorder
                ? const Color(0xFFE5E7EB)
                : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: labelColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatWithThousandsSeparator(num value, int decimals) {
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final integerPart = parts.first;
    final decimalPart = parts.length > 1 ? parts[1] : '';

    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      final reverseIndex = integerPart.length - i;
      buffer.write(integerPart[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }

    if (decimalPart.isEmpty) {
      return buffer.toString();
    }

    return '${buffer.toString()}.$decimalPart';
  }

  LinearGradient _recordBorderGradient(bool isLong) {
    return isLong
        ? const LinearGradient(
            colors: [Color(0xFF16C784), Color(0xFF8FE3BE), Color(0xFFE5E7EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFEA3943), Color(0xFFF4A0A5), Color(0xFFE5E7EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> records) {
    switch (_recordFilter) {
      case _RecordFilter.long:
        return records
            .where((record) => ((record['is_long'] ?? 1) as num) == 1)
            .toList();
      case _RecordFilter.short:
        return records
            .where((record) => ((record['is_long'] ?? 1) as num) == 0)
            .toList();
      case _RecordFilter.all:
        return records;
    }
  }

  Future<void> _selectFilter(_RecordFilter filter) async {
    if (_recordFilter == filter || _isFilterAnimating) {
      return;
    }

    setState(() {
      _isFilterAnimating = true;
      _recordFilter = filter;
    });

    await Future<void>.delayed(const Duration(milliseconds: 220));

    if (!mounted) {
      return;
    }

    setState(() {
      _isFilterAnimating = false;
    });
  }

  Widget _buildFilterSegment(_RecordFilter filter, String label) {
    final isSelected = _recordFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: _isFilterAnimating
            ? null
            : () async {
                await _selectFilter(filter);
              },
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: _isFilterAnimating && !isSelected ? 0.82 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF453B66)
                        : const Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Alignment _filterHighlightAlignment() {
    switch (_recordFilter) {
      case _RecordFilter.all:
        return Alignment.centerLeft;
      case _RecordFilter.long:
        return Alignment.center;
      case _RecordFilter.short:
        return Alignment.centerRight;
    }
  }

  String _formatCreatedAt(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) {
      return '$value';
    }

    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');

    return '${parsed.year}-$month-$day $hour:$minute';
  }

  Future<void> _showRemarkBottomSheet(String remark) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final sheetHeight = MediaQuery.of(sheetContext).size.height * 0.62;
        return SafeArea(
          top: false,
          child: Container(
            height: sheetHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 24,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 64,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color(0xFFD9D9DE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Remark',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF20222B),
                          ),
                        ),
                      ),
                      Material(
                        color: const Color(0xFFF3F3F5),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.close_rounded,
                              size: 28,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFFE7E7EC)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: SingleChildScrollView(
                          child: Text(
                            remark,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.55,
                              color: Color(0xFF2B2E38),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _shareImageAssetPath(bool isLong) {
    return isLong
        ? 'assets/images/share_up.jpeg'
        : 'assets/images/share_down.jpeg';
  }

  Widget _buildShareCard(Map<String, dynamic> record) {
    if (record['record_type'] == 'xauusd') {
      try {
        return SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GoldResultCard(
                result: GoldResult.decode(record['payload_json'] as String),
              ),
              Text('Created ${_formatCreatedAt(record['created_at'])}'),
            ],
          ),
        );
      } catch (_) {
        return const SizedBox(
          width: 420,
          child: Text('XAUUSD record cannot be read.'),
        );
      }
    }
    final double balance = (record['balance'] as num).toDouble();
    final double investment = (record['investment'] as num).toDouble();
    final double leverage = (record['leverage'] as num).toDouble();
    final double entryPrice = (record['entry_price'] as num).toDouble();
    final double? targetPrice = (record['target_price'] as num?)?.toDouble();
    final double stopLoss = (record['stop_loss'] as num).toDouble();
    final bool isLong = ((record['is_long'] ?? 1) as num) == 1;

    final double investmentAmount = calculateInvestmentAmount(
      balance,
      investment,
    );
    final double marginCost = calculateMarginCost(
      balance,
      investment,
      leverage,
      stopLoss,
    );
    final double stopLossPrice = calculateStopLossPrice(
      entryPrice,
      stopLoss,
      isLong,
    );
    final String riskRewardRatio = _formatRiskRewardRatio(
      entryPrice,
      targetPrice,
      stopLossPrice,
      isLong,
    );
    final Color directionColor = isLong
        ? const Color(0xFF2FE38A)
        : const Color(0xFFFF6B6B);
    final String assetPath = _shareImageAssetPath(isLong);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 420,
        height: 640,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(assetPath, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.36),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: directionColor.withValues(alpha: 0.75),
                      ),
                    ),
                    child: Text(
                      isLong ? 'LONG POSITION' : 'SHORT POSITION',
                      style: TextStyle(
                        color: directionColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Trading Record',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatNum(leverage, 0)}x ${isLong ? 'Long' : 'Short'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      spacing: 10,
                      children: [
                        _buildShareInfoRow(
                          'Balance',
                          '${formatNum(balance, 2)} USDT',
                        ),
                        _buildShareInfoRow(
                          'Investment',
                          '${formatNum(investment, 2)} %',
                        ),
                        _buildShareInfoRow(
                          'Entry Price',
                          formatNum(entryPrice, 2),
                        ),
                        _buildShareInfoRow(
                          'Take Profit',
                          targetPrice == null
                              ? '--'
                              : formatNum(targetPrice, 2),
                        ),
                        _buildShareInfoRow(
                          'Stop Loss',
                          '${formatNum(stopLoss, 2)} %',
                          valueColor: const Color(0xFFFFB4B4),
                        ),
                        _buildShareInfoRow(
                          'Stop Loss Price',
                          stopLossPrice.toStringAsFixed(2),
                          valueColor: const Color(0xFFFF8E8E),
                        ),
                        _buildShareInfoRow(
                          'Investment Amount',
                          '${investmentAmount.toStringAsFixed(2)} USDT',
                        ),
                        _buildShareInfoRow(
                          'Margin Cost',
                          marginCost.toStringAsFixed(4),
                          valueColor: const Color(0xFF8AE6FF),
                        ),
                        _buildShareInfoRow('Risk : Reward', riskRewardRatio),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Created ${_formatCreatedAt(record['created_at'])}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareRecord(Map<String, dynamic> record) async {
    try {
      final bool isLong = ((record['is_long'] ?? 1) as num) == 1;
      await precacheImage(AssetImage(_shareImageAssetPath(isLong)), context);
      final directory = await getTemporaryDirectory();
      if (!mounted) return;
      final bytes = await _screenshotController.captureFromWidget(
        InheritedTheme.captureAll(
          context,
          Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: Colors.transparent,
              child: _buildShareCard(record),
            ),
          ),
        ),
        pixelRatio: 3,
      );
      final createdAt = _formatCreatedAt(
        record['created_at'],
      ).replaceAll(RegExp(r'[^0-9A-Za-z]+'), '_');
      final file = File('${directory.path}/trade_share_$createdAt.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          text: record['record_type'] == 'xauusd'
              ? GoldResult.decode(record['payload_json'] as String).shareText
              : 'Trade setup ${((record['is_long'] ?? 1) as num) == 1 ? 'LONG' : 'SHORT'}\nEntry: ${formatNum(record['entry_price'], 4)}\nLeverage: ${formatNum(record['leverage'], 2)}x',
          files: [XFile(file.path)],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Share failed: $error')));
    }
  }

  Future<void> _openSharePreview(Map<String, dynamic> record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final previewHeight = MediaQuery.of(context).size.height * 0.72;
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Share Preview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: previewHeight,
                  child: SingleChildScrollView(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _buildShareCard(record),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _shareRecord(record);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share Now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _unlockSavedRecords,
                  child: Text(
                    'Saved Records',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _selectedRecordIds.isNotEmpty
                      ? () async {
                          await _deleteSelectedRecords();
                        }
                      : () async {
                          final shouldClear = await _confirmDeleteAction(
                            title: 'Clear all records?',
                            message:
                                'This will permanently delete all saved records.',
                            confirmLabel: 'Clear All',
                          );
                          if (!shouldClear) {
                            return;
                          }
                          await _clearRecords();
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedRecordIds.isNotEmpty
                              ? Icons.delete_outline
                              : Icons.delete_forever,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedRecordIds.isNotEmpty
                              ? 'Delete Selected (${_selectedRecordIds.length})'
                              : 'Clear All Records',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.7,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6FC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE6E0F4)),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      alignment: _filterHighlightAlignment(),
                      child: FractionallySizedBox(
                        widthFactor: 1 / 3,
                        child: Container(
                          height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1ECFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD7CBF8)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _buildFilterSegment(_RecordFilter.all, 'All'),
                        const SizedBox(width: 4),
                        _buildFilterSegment(_RecordFilter.long, 'Long'),
                        const SizedBox(width: 4),
                        _buildFilterSegment(_RecordFilter.short, 'Short'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _recordsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final records = _applyFilter(snapshot.data ?? []);
              if (records.isEmpty) {
                return const Center(child: Text('No records yet'));
              }

              return ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemBuilder: (context, index) {
                  final record = records[index];
                  if (record['record_type'] == 'xauusd')
                    return _goldRecord(record);
                  final double balance = (record['balance'] as num).toDouble();
                  final double investment = (record['investment'] as num)
                      .toDouble();
                  final double leverage = (record['leverage'] as num)
                      .toDouble();
                  final double entryPrice = (record['entry_price'] as num)
                      .toDouble();
                  final double? targetPrice = (record['target_price'] as num?)
                      ?.toDouble();
                  final double stopLoss = (record['stop_loss'] as num)
                      .toDouble();
                  final bool isLong = ((record['is_long'] ?? 1) as num) == 1;
                  final int recordId = (record['id'] as num).toInt();
                  final bool isSelected = _selectedRecordIds.contains(recordId);
                  final String remark = (record['remark'] ?? '').toString();

                  final double investmentAmount = calculateInvestmentAmount(
                    balance,
                    investment,
                  );
                  final double marginCost = calculateMarginCost(
                    balance,
                    investment,
                    leverage,
                    stopLoss,
                  );
                  final double stopLossPrice = calculateStopLossPrice(
                    entryPrice,
                    stopLoss,
                    isLong,
                  );
                  final String riskRewardRatio = _formatRiskRewardRatio(
                    entryPrice,
                    targetPrice,
                    stopLossPrice,
                    isLong,
                  );
                  final double potentialLoss = calculatePotentialLoss(
                    entryPrice,
                    stopLossPrice,
                    marginCost,
                    leverage,
                    isLong,
                  );
                  final String potentialProfitText = targetPrice == null
                      ? '--'
                      : calculatePotentialProfit(
                          entryPrice,
                          targetPrice,
                          marginCost,
                          leverage,
                          isLong,
                        ).toStringAsFixed(2);

                  return Container(
                    decoration: BoxDecoration(
                      gradient: _recordBorderGradient(isLong),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isLong
                                      ? const Color(0xFF16C784)
                                      : const Color(0xFFEA3943))
                                  .withValues(alpha: 0.14),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(1.4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLong
                                        ? const Color(0xFF16C784)
                                        : const Color(0xFFEA3943),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLong
                                            ? Icons.trending_up
                                            : Icons.trending_down,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isLong ? 'Long' : 'Short',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'RR  $riskRewardRatio',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatCreatedAt(record['created_at']),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color.fromARGB(255, 116, 115, 115),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            _buildKeyPriceRow(
                              'Entry',
                              _formatWithThousandsSeparator(entryPrice, 2),
                              labelColor: Colors.black87,
                            ),
                            _buildKeyPriceRow(
                              'Take Profit',
                              targetPrice == null
                                  ? '--'
                                  : _formatWithThousandsSeparator(
                                      targetPrice,
                                      2,
                                    ),
                              valueColor: const Color(0xFF2E8B57),
                              labelColor: Colors.black87,
                            ),
                            _buildKeyPriceRow(
                              'Stop Loss',
                              _formatWithThousandsSeparator(stopLossPrice, 2),
                              valueColor: const Color(0xFFEA3943),
                              showBottomBorder: false,
                              labelColor: Colors.black87,
                            ),
                            Row(
                              children: [
                                _buildOutcomeCard(
                                  amount: targetPrice == null
                                      ? '--'
                                      : '+$potentialProfitText USDT',
                                  label: 'Profit',
                                  color: const Color(0xFF2E8B57),
                                  backgroundColor: const Color(0xFFF1FBF5),
                                ),
                                const SizedBox(width: 10),
                                _buildOutcomeCard(
                                  amount:
                                      '-${potentialLoss.toStringAsFixed(2)} USDT',
                                  label: 'Loss',
                                  color: const Color(0xFFEA3943),
                                  backgroundColor: const Color(0xFFFFF2F2),
                                ),
                              ],
                            ),
                            _buildKeyPriceRow(
                              'Balance',
                              formatNum(record['balance'], 2),
                            ),
                            _buildKeyPriceRow(
                              'Investment',
                              '${formatNum(record['investment'], 2)} %',
                            ),
                            _buildKeyPriceRow(
                              'Stop Loss',
                              '${formatNum(record['stop_loss'], 2)} %',
                            ),
                            _buildKeyPriceRow(
                              'Investment Amount',
                              '${investmentAmount.toStringAsFixed(2)} USDT',
                            ),
                            _buildKeyPriceRow(
                              'Leverage',
                              '${formatNum(record['leverage'], 2)} x',
                            ),
                            _buildKeyPriceRow(
                              'Margin Cost',
                              marginCost.toStringAsFixed(7),
                              showBottomBorder: false,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildActionContainer(
                                  onTap: () {
                                    _toggleRecordSelection(
                                      recordId,
                                      !isSelected,
                                    );
                                  },
                                  borderColor: isSelected
                                      ? const Color(0xFFEA3943)
                                      : const Color(0xFFE5E7EB),
                                  backgroundColor: isSelected
                                      ? const Color(0xFFFFF1F2)
                                      : Colors.white,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        size: 18,
                                        color: isSelected
                                            ? const Color(0xFFEA3943)
                                            : Colors.black54,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFFEA3943)
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (remark.trim().isNotEmpty)
                                  _buildActionContainer(
                                    onTap: () async {
                                      await _showRemarkBottomSheet(
                                        remark.trim(),
                                      );
                                    },
                                    borderColor: const Color(0xFFF59E0B),
                                    backgroundColor: const Color(0xFFFFFBEB),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.sticky_note_2_outlined,
                                          size: 18,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Remark',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const SizedBox(width: 1),
                                _buildActionContainer(
                                  onTap: () async {
                                    await _openSharePreview(record);
                                  },
                                  borderColor: const Color(0xFF93C5FD),
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.share,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Share',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _RecordFilter { all, long, short }
