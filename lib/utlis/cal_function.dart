String formatNum(dynamic value, int decimals) {
  return (value as num).toStringAsFixed(decimals);
}

double calculateInvestmentAmount(double balance, double investment) {
  if (balance <= 0 || investment <= 0) {
    return 0;
  }
  return balance * investment / 100;
}

double calculateMarginCost(
  double balance,
  double investment,
  double leverage,
  double stopLoss,
) {
  if (balance <= 0 || investment <= 0 || leverage <= 0 || stopLoss <= 0) {
    return 0;
  }
  final investmentPercent = investment / 100;
  final stopLossPercent = stopLoss / 100;

  return (balance * investmentPercent) / (stopLossPercent * leverage);
}

double calculateStopLossPrice(double entryPrice, double stopLoss, bool isLong) {
  if (entryPrice <= 0 || stopLoss <= 0) {
    return 0;
  }
  final stopLossPercent = stopLoss / 100;
  return isLong
      ? entryPrice * (1 - stopLossPercent)
      : entryPrice * (1 + stopLossPercent);
}

String calculateRiskRewardRatio(
  double entryPrice,
  double takeProfitPrice,
  double stopLossPrice,
  bool isLong,
) {
  if (entryPrice <= 0 || stopLossPrice <= 0 || takeProfitPrice <= 0) {
    return '0';
  }

  final double riskDistance = isLong
      ? entryPrice - stopLossPrice
      : stopLossPrice - entryPrice;

  final double rewardDistance = isLong
      ? takeProfitPrice - entryPrice
      : entryPrice - takeProfitPrice;

  print('Risk Distance: $riskDistance, Reward Distance: $rewardDistance');
  print('isLong: $isLong');

  if (riskDistance <= 0 || rewardDistance <= 0) {
    return '0';
  }

  final double normalizedReward = rewardDistance / riskDistance;
  return '1 : ${normalizedReward.toStringAsFixed(2)}';
}

double calculatePotentialProfit(
  double entryPrice,
  double targetPrice,
  double marginCost,
  double leverage,
  bool isLong,
) {
  if (entryPrice <= 0 || targetPrice <= 0 || marginCost <= 0 || leverage <= 0) {
    return 0;
  }

  final double positionValue = marginCost * leverage;
  final double quantity = positionValue / entryPrice;

  final double priceMove = isLong
      ? targetPrice - entryPrice
      : entryPrice - targetPrice;

  if (priceMove <= 0) {
    return 0;
  }

  return priceMove * quantity;
}

double calculatePotentialLoss(
  double entryPrice,
  double stopLossPrice,
  double marginCost,
  double leverage,
  bool isLong,
) {
  if (entryPrice <= 0 ||
      stopLossPrice <= 0 ||
      marginCost <= 0 ||
      leverage <= 0) {
    return 0;
  }

  final double positionValue = marginCost * leverage;
  final double quantity = positionValue / entryPrice;

  final double priceMove = isLong
      ? entryPrice - stopLossPrice
      : stopLossPrice - entryPrice;

  if (priceMove <= 0) {
    return 0;
  }

  return priceMove * quantity;
}
