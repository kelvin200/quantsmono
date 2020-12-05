//+------------------------------------------------------------------+
//|                                                        test1.mq5 |
//|                                                           Kelvin |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Kelvin"
#property link ""
#property version "1.00"

#include <Trade\Trade.mqh>

//--- input parameters
input double RiskPerTrade = 0.01; // Maximum Risk in percentage
input double trade_volume = 0.01;
// input double DecreaseFactor = 3; // Descrease factor
input int MovingPeriodFast = 6;
input int MovingPeriodSlow = 24;

input double stop_loss_atr = 3;
input double atr_range = 14;

input double biasTrending = 0.5;
input double biasCounterTrending = 0.3;

input bool dynamicTrailing = true;

int ExtHandleFast = 0;
int ExtHandleSlow = 0;
int handlerATR = 0;
double tick_size = 0;

double maFast[200];
double maSlow[200];

datetime lastCrossUp;
datetime lastCrossDown;
int trend = 0; // 1, 0, -1

double GetTradeVolume(string pair, double stoploss)
{
  double lot = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPerTrade *
               SymbolInfoDouble(pair, SYMBOL_TRADE_TICK_SIZE) *
               SymbolInfoDouble(pair, SYMBOL_TRADE_TICK_VALUE) /
               stoploss;

  double stepvol = SymbolInfoDouble(pair, SYMBOL_VOLUME_STEP);
  lot = stepvol * NormalizeDouble(lot / stepvol, 0);

  double minvol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  if (lot < minvol)
    return 0.0;

  double maxvol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  if (lot > maxvol)
    return maxvol;

  return lot;
}

double GetMaxLossInPoint(string pair = "")
{
  if (pair == "")
    pair = _Symbol;

  return AccountInfoDouble(ACCOUNT_BALANCE) * RiskPerTrade *
         SymbolInfoDouble(pair, SYMBOL_TRADE_TICK_SIZE) /
         SymbolInfoDouble(pair, SYMBOL_TRADE_TICK_VALUE) /
         trade_volume;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(void)
{
  tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

  ExtHandleFast = iMA(_Symbol, _Period, MovingPeriodFast, 0, MODE_EMA, PRICE_CLOSE);
  ExtHandleSlow = iMA(_Symbol, _Period, MovingPeriodSlow, 0, MODE_EMA, PRICE_CLOSE);
  handlerATR = iATR(_Symbol, _Period, atr_range);

  if (ExtHandleFast == INVALID_HANDLE || ExtHandleSlow == INVALID_HANDLE)
  {
    printf("Error creating MA indicator");
    return (INIT_FAILED);
  }
  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

datetime latest_candle_time_checked = 0;
MqlRates rt[200];
double atr[200];
CTrade trade;
int historyCount = 100;

bool PrepareOnTick()
{
  if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    return false;

  //--- copy the price values
  if (CopyRates(_Symbol, _Period, 0, historyCount + 1, rt) != historyCount + 1)
  {
    Print("CopyRates of ", _Symbol, " failed, no history");
    return false;
  }

  if (latest_candle_time_checked == rt[historyCount].time)
    return false;

  latest_candle_time_checked = rt[historyCount].time;

  //--- Get the current value of the Moving Average indicator
  if (CopyBuffer(ExtHandleFast, 0, 0, historyCount + 1, maFast) != historyCount + 1)
  {
    Print("CopyBuffer from iMA fast failed, no data");
    return false;
  }
  if (CopyBuffer(ExtHandleSlow, 0, 0, historyCount + 1, maSlow) != historyCount + 1)
  {
    Print("CopyBuffer from iMA slow failed, no data");
    return false;
  }

  //--- Get the current value of the ATR indicator
  if (CopyBuffer(handlerATR, 0, 0, historyCount + 1, atr) != historyCount + 1)
  {
    Print("CopyBuffer from iATR failed, no data");
    return false;
  }

  return true;
}

bool CheckMACross()
{
  int i = historyCount - 1;
  while (maFast[i] <= maSlow[i] && i > 0)
  {
    lastCrossDown = rt[i - 1].time;
    --i;
  }

  if (i == 0)
    return false;

  i = historyCount - 1;
  while (maFast[i] >= maSlow[i] && i > 0)
  {
    lastCrossUp = rt[i - 1].time;
    --i;
  }

  if (i == 0)
    return false;

  int newTrend = lastCrossUp > lastCrossDown ? 1 : -1;

  if (newTrend != trend)
  {
    countB = 0;
    countS = 0;
    trend = newTrend;
  }

  return true;
}

// +------------------------------------------------------------------+
// | Expert tick function                                             |
// +------------------------------------------------------------------+
void OnTick(void)
{
  if (!PrepareOnTick())
    return;

  if (!CheckMACross())
    return;

  // Update all existing positions
  if (dynamicTrailing)
    UpdateAllTrailingStops();

  // // Check if we should open another position $$$
  CheckForOpen();
}

int countB = 0;
int countS = 0;

ENUM_ORDER_TYPE WhatToTrade()
{
  int i = historyCount - 1;

  if (countB == 0 && rt[i].close >= rt[i].open &&
      rt[i - 1].close >= rt[i - 1].open &&
      rt[i - 2].close >= rt[i - 2].open &&
      trend == 1)
  {
    ++countB;
    return ORDER_TYPE_BUY;
  }

  if (countS == 0 && rt[i].close <= rt[i].open &&
      rt[i - 1].close <= rt[i - 1].open &&
      rt[i - 2].close <= rt[i - 2].open &&
      trend == -1)
  {
    ++countS;
    return ORDER_TYPE_SELL;
  }

  return WRONG_VALUE;
}

//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen(void)
{
  //--- check the signals
  ENUM_ORDER_TYPE signal = WhatToTrade();

  //--- additional checks
  if (signal == WRONG_VALUE)
    return;

  double stoplosspip = stop_loss_atr * atr[historyCount - 1];

  // double trade_volume = GetTradeVolume(_Symbol, stoplosspip);
  // if (trade_volume <= 0.0)
  //   return;

  CTrade trade;

  if (signal == ORDER_TYPE_SELL)
  {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    double sl = price + stoplosspip * (dynamicTrailing + 1);
    double tp = dynamicTrailing ? 0 : price - stoplosspip;
    trade.PositionOpen(_Symbol, signal, trade_volume, price, sl, tp);
  }
  else
  {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = price - stoplosspip * (dynamicTrailing + 1);
    double tp = dynamicTrailing ? 0 : price + stoplosspip;
    trade.PositionOpen(_Symbol, signal, trade_volume, price, sl, tp);
  }
}

void UpdateAllTrailingStops()
{
  double currentHeight = rt[historyCount - 1].close - rt[historyCount - 1].open;
  // double lastHeight = rt[historyCount - 1].close - rt[historyCount - 1].open;

  // if (currentHeight == 0.0 || lastHeight == 0.0)
  if (currentHeight == 0.0)
    return;

  /*
SL = previous SL + (ATR * 3) * this candle height / last candle
*/

  // double sqrtatr = MathAbs(atr[historyCount] * currentHeight / lastHeight);
  double sqrtatr = MathSqrt(MathAbs(atr[historyCount - 1] * currentHeight));
  double modWithTrend = sqrtatr * biasTrending;
  double modCounterTrend = -sqrtatr * biasCounterTrending;
  double modBuying = currentHeight > 0 ? modWithTrend : modCounterTrend;
  double modSelling = currentHeight < 0 ? modWithTrend : modCounterTrend;

  int t = PositionsTotal();

  for (int i = 0; i < t; ++i)
  {
    string symbol = PositionGetSymbol(i);

    if (_Symbol != symbol)
      continue;

    ulong ticket = PositionGetTicket(i);
    // CheckForTrailingStop(ticket);
    CheckForTrailingStop(ticket, modBuying, modSelling);
  }
}

// void CheckForTrailingStop(ulong ticket)
void CheckForTrailingStop(ulong ticket, double modBuying, double modSelling)
{
  ENUM_POSITION_TYPE position_type = PositionGetInteger(POSITION_TYPE);
  double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
  double current_stop_loss = PositionGetDouble(POSITION_SL);
  double current_take_profit = PositionGetDouble(POSITION_TP);
  double local_stop_loss;
  double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  CTrade trade;
  double time0 = rt[historyCount].time,
         time1 = rt[historyCount - 1].time;

  if (position_type == POSITION_TYPE_BUY)
  {
    double sss = MathMax(current_stop_loss + modBuying, open_price - stop_loss_atr * 2 * atr[historyCount - 1]);

    // while (sss > bid_price)
    //   sss = (sss + current_stop_loss) / 2.0;

    bool result = trade.PositionModify(ticket, sss, current_take_profit);

    string name = "slbuy" + ticket + time0;

    ObjectCreate(0, name, OBJ_TREND, 0, time0, sss, time1, current_stop_loss);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
  }
  else if (position_type == POSITION_TYPE_SELL)
  {
    double sss = MathMin(current_stop_loss - modSelling, open_price + stop_loss_atr * 2 * atr[historyCount - 1]);

    // while (sss < ask_price)
    //   sss = (sss + current_stop_loss) / 2.0;

    bool result = trade.PositionModify(ticket, sss, current_take_profit);

    string name = "slsell" + ticket + time0;

    ObjectCreate(0, name, OBJ_TREND, 0, time0, sss, time1, current_stop_loss);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
  }
}
