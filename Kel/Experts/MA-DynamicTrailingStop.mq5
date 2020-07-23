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

int ExtHandleFast = 0;
int ExtHandleSlow = 0;
int handlerATR = 0;
double tick_size = 0;

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

// +------------------------------------------------------------------+
// | Expert tick function                                             |
// +------------------------------------------------------------------+
void OnTick(void)
{
  if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    return;

  // Update all existing positions
  UpdateAllTrailingStops();
  // // Check if we should open another position $$$
  CheckForOpen();
}

datetime latest_candle_time_checked_open = 0;

//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen(void)
{
  MqlRates rt[3];
  //--- copy the price values
  if (CopyRates(_Symbol, _Period, 0, 3, rt) != 3)
  {
    Print("CopyRates of ", _Symbol, " failed, no history");
    return;
  }

  if (latest_candle_time_checked_open == rt[2].time)
    return;

  latest_candle_time_checked_open = rt[2].time;

  //--- Get the current value of the Moving Average indicator
  double maFast[5];
  if (CopyBuffer(ExtHandleFast, 0, 0, 5, maFast) != 5)
  {
    Print("CopyBuffer from iMA fast failed, no data");
    return;
  }
  double maSlow[5];
  if (CopyBuffer(ExtHandleSlow, 0, 0, 5, maSlow) != 5)
  {
    Print("CopyBuffer from iMA slow failed, no data");
    return;
  }

  //--- check the signals
  ENUM_ORDER_TYPE signal = WRONG_VALUE;

  if (maFast[4] > maSlow[4] && maFast[3] < maSlow[3])
    // maFast > maSlow => Buy
    signal = ORDER_TYPE_BUY;

  else if (maFast[4] < maSlow[4] && maFast[3] > maSlow[3])
    // maFast < maSlow => Sell
    signal = ORDER_TYPE_SELL;

  //--- additional checks
  if (signal == WRONG_VALUE || Bars(_Symbol, _Period) <= 100)
    return;

  //--- Get the current value of the ATR indicator
  double atr[1];
  if (CopyBuffer(handlerATR, 0, 1, 1, atr) != 1)
  {
    Print("CopyBuffer from iATR failed, no data");
    return;
  }

  double stoplosspip = stop_loss_atr * atr[0];

  double trade_volume = GetTradeVolume(_Symbol, stoplosspip);
  if (trade_volume <= 0.0)
    return;

  CTrade trade;

  if (signal == ORDER_TYPE_SELL)
  {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = price + stoplosspip;
    trade.PositionOpen(_Symbol, signal, trade_volume, price, sl, 0);
  }
  else
  {
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = price - stoplosspip;
    trade.PositionOpen(_Symbol, signal, trade_volume, price, sl, 0);
  }
}

datetime latest_candle_time_checked_trailing = 0;
void UpdateAllTrailingStops()
{
  // Get 2 last candles
  MqlRates rt[5];
  //--- copy the price values
  if (CopyRates(_Symbol, _Period, 0, 5, rt) != 5)
  {
    Print("CopyRates of ", _Symbol, " failed, no history");
    return;
  }

  if (latest_candle_time_checked_trailing == rt[4].time)
    return;

  latest_candle_time_checked_trailing = rt[4].time;

  //--- Get the current value of the ATR indicator
  double atr[1];
  if (CopyBuffer(handlerATR, 0, 1, 1, atr) != 1)
  {
    Print("CopyBuffer from iATR failed, no data");
    return;
  }

  double currentHeight = rt[3].close - rt[3].open;

  if (currentHeight == 0.0)
    return;

  /*
SL = previous SL + (ATR * 3) * this candle height / last candle
*/

  double sqrtatr = MathSqrt(MathAbs(atr[0] * currentHeight));
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
    CheckForTrailingStop(ticket, atr, modBuying, modSelling, rt);
  }
}

// void CheckForTrailingStop(ulong ticket)
void CheckForTrailingStop(ulong ticket, double &atr[], double modBuying, double modSelling, MqlRates &rt[])
{
  ENUM_POSITION_TYPE position_type = PositionGetInteger(POSITION_TYPE);
  double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
  double current_stop_loss = PositionGetDouble(POSITION_SL);
  double current_take_profit = PositionGetDouble(POSITION_TP);
  double local_stop_loss;
  double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  if (position_type == POSITION_TYPE_BUY)
  {
    double sss = MathMax(current_stop_loss + modBuying, open_price - stop_loss_atr * 2 * atr[0]);

    // while (sss > bid_price)
    //   sss = (sss + current_stop_loss) / 2.0;

    CTrade trade;
    bool result = trade.PositionModify(ticket, sss, current_take_profit);

    double time0 = rt[4].time, time1 = rt[3].time;
    string name = "slbuy" + ticket + time0;

    ObjectCreate(0, name, OBJ_TREND, 0, time0, sss, time1, current_stop_loss);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
  }
  else if (position_type == POSITION_TYPE_SELL)
  {
    double sss = MathMin(current_stop_loss - modSelling, open_price + stop_loss_atr * 2 * atr[0]);

    // while (sss < ask_price)
    //   sss = (sss + current_stop_loss) / 2.0;

    CTrade trade;
    bool result = trade.PositionModify(ticket, sss, current_take_profit);

    double time0 = rt[4].time,
           time1 = rt[3].time;
    string name = "slsell" + ticket + time0;

    ObjectCreate(0, name, OBJ_TREND, 0, time0, sss, time1, current_stop_loss);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
  }
}
