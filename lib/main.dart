import 'dart:async';
import 'dart:convert';

import 'package:calculator/screen/first_screen.dart';
import 'package:calculator/screen/second_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _index = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<String> _fetchBinancePrice(String symbol) async {
    final uri = Uri.parse(
      'https://data-api.binance.vision/api/v3/ticker/price?symbol=$symbol',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Binance request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected Binance response');
    }

    final priceText = decoded['price']?.toString();
    if (priceText == null || priceText.isEmpty) {
      throw Exception('Price is missing');
    }

    return priceText;
  }

  Future<String> _fetchFearAndGreedIndex() async {
    final uri = Uri.parse('https://api.alternative.me/fng/?limit=1');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Fear & Greed request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected Fear & Greed response');
    }

    final data = decoded['data'];
    if (data is! List || data.isEmpty) {
      throw Exception('Fear & Greed data is missing');
    }

    final latest = data.first;
    if (latest is! Map<String, dynamic>) {
      throw Exception('Fear & Greed item is invalid');
    }

    final value = latest['value']?.toString();
    final classification = latest['value_classification']?.toString();

    if (value == null || value.isEmpty) {
      throw Exception('Fear & Greed value is missing');
    }

    if (classification == null || classification.isEmpty) {
      return value;
    }

    return '$value  $classification';
  }

  Future<void> _showPriceDialog() async {
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null) {
      return;
    }

    await showDialog<void>(
      context: dialogContext,
      builder: (context) => _MarketPriceDialog(
        quotes: [
          _QuoteConfig(
            label: 'BTC/USDT',
            fetchPrice: () => _fetchBinancePrice('BTCUSDT'),
          ),
          _QuoteConfig(
            label: 'ETH/USDT',
            fetchPrice: () => _fetchBinancePrice('ETHUSDT'),
          ),
          _QuoteConfig(
            label: 'PAXG/USDT',
            fetchPrice: () => _fetchBinancePrice('PAXGUSDT'),
          ),
          _QuoteConfig(
            label: 'Fear & Greed',
            fetchPrice: _fetchFearAndGreedIndex,
            formatAsNumber: false,
            fetchOnce: true,
          ),
        ],
        scaffoldMessengerKey: _scaffoldMessengerKey,
      ),
    );
  }

  final List<Widget> _pages = const [FirstScreen(), SecondScreen()];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Scaffold(
        body: SafeArea(child: _pages[_index]),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) {
            setState(() {
              _index = i;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt),
              label: 'Records',
            ),
          ],
        ),
        floatingActionButton: _index == 0
            ? FloatingActionButton(
                onPressed: () async {
                  await _showPriceDialog();
                },
                child: const Icon(Icons.currency_bitcoin),
              )
            : null,
      ),
    );
  }
}

class _QuoteConfig {
  const _QuoteConfig({
    required this.label,
    required this.fetchPrice,
    this.formatAsNumber = true,
    this.fetchOnce = false,
  });

  final String label;
  final Future<String> Function() fetchPrice;
  final bool formatAsNumber;
  final bool fetchOnce;
}

class _MarketPriceDialog extends StatefulWidget {
  const _MarketPriceDialog({
    required this.quotes,
    required this.scaffoldMessengerKey,
  });

  final List<_QuoteConfig> quotes;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<_MarketPriceDialog> createState() => _MarketPriceDialogState();
}

class _MarketPriceDialogState extends State<_MarketPriceDialog> {
  Timer? _refreshTimer;
  bool _isFetching = false;
  String _statusText = 'Fetching...';
  late final Map<String, String> _priceMap;
  final int _refreshIntervalSeconds = 5;

  @override
  void initState() {
    super.initState();
    _priceMap = {for (final quote in widget.quotes) quote.label: '--'};
    _refreshPrice();
    _refreshTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (
      _,
    ) {
      _refreshPrice();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPrice() async {
    if (_isFetching) {
      return;
    }

    _isFetching = true;
    if (mounted) {
      setState(() {
        _statusText = 'Fetching...';
      });
    }

    try {
      final entries = await Future.wait(
        widget.quotes.map((quote) async {
          if (quote.fetchOnce && _priceMap[quote.label] != '--') {
            return MapEntry(quote.label, _priceMap[quote.label] ?? '--');
          }

          final latestPrice = await quote.fetchPrice();
          final formattedPrice = quote.formatAsNumber
              ? (double.tryParse(latestPrice) ?? 0).toStringAsFixed(2)
              : latestPrice;
          return MapEntry(quote.label, formattedPrice);
        }),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        for (final entry in entries) {
          _priceMap[entry.key] = entry.value;
        }
        _statusText = 'Auto refresh every $_refreshIntervalSeconds seconds';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Fetch failed: $error';
      });
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _copyPrice(String label, String value) async {
    if (value == '--') {
      return;
    }

    await Clipboard.setData(ClipboardData(text: value));
    widget.scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Color _valueColor(_QuoteConfig quote, String value) {
    if (quote.label != 'Fear & Greed') {
      return Colors.white;
    }

    final normalized = value.toLowerCase();
    if (normalized.contains('extreme fear')) {
      return const Color(0xFFFF5B5B);
    }
    if (normalized.contains('fear')) {
      return const Color(0xFFFF8F43);
    }
    if (normalized.contains('neutral')) {
      return const Color(0xFFF0B90B);
    }
    if (normalized.contains('extreme greed')) {
      return const Color(0xFF2EBD85);
    }
    if (normalized.contains('greed')) {
      return const Color(0xFF5CD67A);
    }

    return Colors.white;
  }

  int? _fearAndGreedScore() {
    final rawValue = _priceMap['Fear & Greed'];
    if (rawValue == null || rawValue == '--') {
      return null;
    }

    final match = RegExp(r'\d+').firstMatch(rawValue);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(0) ?? '');
  }

  String _fearAndGreedAssetPath() {
    final score = _fearAndGreedScore();
    if (score == null) {
      return 'assets/images/fear_greed/Fear_Greed_Index_3.jpeg';
    }

    if (score <= 20) {
      return 'assets/images/fear_greed/Fear_Greed_Index_4.jpeg';
    }
    if (score <= 40) {
      return 'assets/images/fear_greed/Fear_Greed_Index_1.jpeg';
    }
    if (score <= 60) {
      return 'assets/images/fear_greed/Fear_Greed_Index_3.jpeg';
    }
    if (score <= 80) {
      return 'assets/images/fear_greed/Fear_Greed_Index_2.jpeg';
    }

    return 'assets/images/fear_greed/Fear_Greed_Index_5.jpeg';
  }

  @override
  Widget build(BuildContext context) {
    const Color binanceYellow = Color(0xFFF0B90B);
    const Color binanceBackground = Color(0xFF181A20);
    const Color binanceSurface = Color(0xFF1E2329);
    const Color binanceBorder = Color(0xFF2B3139);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: binanceBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: binanceBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: binanceYellow.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.candlestick_chart,
                    color: binanceYellow,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Market Prices',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Data from Binance and Alternative.me',
                        style: TextStyle(
                          color: Color(0xFF848E9C),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close, color: Color(0xFF848E9C)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...widget.quotes.map((quote) {
              final value = _priceMap[quote.label] ?? '--';
              final bool isFearAndGreedCard = quote.label == 'Fear & Greed';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isFearAndGreedCard ? null : binanceSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: binanceBorder),
                  image: isFearAndGreedCard
                      ? DecorationImage(
                          image: AssetImage(_fearAndGreedAssetPath()),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isFearAndGreedCard
                        ? binanceBackground.withValues(alpha: 0.72)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quote.label,
                              style: const TextStyle(
                                color: Color(0xFFB7BDC6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              value,
                              style: TextStyle(
                                color: _valueColor(quote, value),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isFearAndGreedCard)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: binanceYellow.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: value == '--'
                                ? null
                                : () => _copyPrice(quote.label, value),
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: binanceYellow,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.sync_outlined,
                  size: 16,
                  color: Color(0xFF848E9C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusText,
                    style: const TextStyle(
                      color: Color(0xFF848E9C),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
