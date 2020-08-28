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
input double trailing_stop_value = 16;
input double stop_loss           = 32;
input double atr_range           = 20;

input double biasTrending        = 0.4;
input double biasCounterTrending = 0.3;

input color color_trailing_sell = clrRed;
input color color_trailing_buy  = clrRoyalBlue;

int handlerATR = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(void) {
  handlerATR = iATR(_Symbol, _Period, atr_range);

  if (handlerATR == INVALID_HANDLE) {
    printf("Error creating ATR indicator");
    return (INIT_FAILED);
  }

  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

// +------------------------------------------------------------------+
// | Expert tick function                                             |
// +------------------------------------------------------------------+
void OnTick(void) {
  if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;

  // Update all existing positions
  UpdateAllTrailingStops();
}

datetime latest_candle_time_checked_trailing = 0;
void     UpdateAllTrailingStops() {
  // Get 2 last candles
  MqlRates rt[5];
  //--- copy the price values
  if (CopyRates(_Symbol, _Period, 0, 5, rt) != 5) {
    Print("CopyRates of ", _Symbol, " failed, no history");
    return;
  }

  if (latest_candle_time_checked_trailing == rt[4].time) return;

  Print("Dynamic Trailing Stop ATR - Start updating stoploss");

  //--- Get the current value of the ATR indicator
  double atr[1];
  if (CopyBuffer(handlerATR, 0, 1, 1, atr) != 1) {
    Print("CopyBuffer from iATR failed, no data");
    return;
  }

  double currentHeight = rt[3].close - rt[3].open;

  int t = PositionsTotal();

  if (currentHeight == 0.0 || t == 0) {
    Print("Dynamic Trailing Stop ATR - Stop - CurrentHeight: ", currentHeight, ", PositionsTotal: ", t,
          ", Current ATR: ", atr[0]);
    latest_candle_time_checked_trailing = rt[4].time;
    return;
  }

  int error_count = 0;
  for (int i = 0; i < t; ++i) {
    string symbol = PositionGetSymbol(i);

    if (_Symbol != symbol) continue;

    ulong ticket = PositionGetTicket(i);
    bool  ret    = CheckForTrailingStop(ticket, atr, currentHeight, rt);

    if (!ret) ++error_count;
  }

  if (error_count < t)
    // Less error than total, do not retry
    latest_candle_time_checked_trailing = rt[4].time;
}

bool CheckForTrailingStop(ulong ticket, double &atr[], double currentHeight, MqlRates &rt[]) {
  Print("Dynamic Trailing Stop ATR - Ticket: ", ticket);
  ENUM_POSITION_TYPE position_type       = PositionGetInteger(POSITION_TYPE);
  double             open_price          = PositionGetDouble(POSITION_PRICE_OPEN);
  double             current_stop_loss   = PositionGetDouble(POSITION_SL);
  double             current_take_profit = PositionGetDouble(POSITION_TP);

  double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  double sqrtatr         = MathSqrt(atr[0]);
  double modWithTrend    = sqrtatr * biasTrending * MathAbs(currentHeight);
  double modCounterTrend = -sqrtatr * biasCounterTrending * MathAbs(currentHeight);

  if (position_type == POSITION_TYPE_BUY) {
    double mod = currentHeight > 0 ? modWithTrend : modCounterTrend;

    double sss = MathMax(current_stop_loss + mod, open_price - stop_loss);

    while (sss > bid_price) sss = (sss + current_stop_loss) / 2.0;

    CTrade trade;
    bool   result = trade.PositionModify(ticket, sss, current_take_profit);

    Print("Should modify stoploss of #", ticket, " from ", current_stop_loss, " to ", sss);

    if (!result) {
      Print("Something wrong happened. Last error ", GetLastError());
      Print("ResultRetcode", trade.ResultRetcode());
    }

    double time0 = rt[4].time, time1 = rt[3].time;
    string name = "slbuy" + ticket + time0;

    ObjectCreate(0, name, OBJ_TREND, 0, time0, sss, time1, current_stop_loss);
    ObjectSetInteger(0, name, OBJPROP_COLOR, color_trailing_buy);

    return result;
  }

  if (position_type == POSITION_TYPE_SELL) {
    double mod = currentHeight < 0 ? modWithTrend : modCounterTrend;

    double sss = MathMin(current_stop_loss - mod, open_price + stop_loss);

    while (sss < ask_price) sss = (sss + current_stop_loss) / 2.0;

    CTrade trade;
    bool   result = trade.PositionModify(ticket, sss, current_take_profit);

    Print("Should modify stoploss of #", ticket, " from ", current_stop_loss, " to ", sss);

    if (!result) {
      Print("Something wrong happened. Last error ", GetLastError());
      Print("ResultRetcode", trade.ResultRetcode());
    }

    double time0 = rt[4].time, time1 = rt[3].time;
    string name = "slsell" + ticket + time0;

    ObjectCreate(0, name, OBJ_TREND, 0, time0, sss, time1, current_stop_loss);
    ObjectSetInteger(0, name, OBJPROP_COLOR, color_trailing_sell);

    return result;
  }

  return false;
}
