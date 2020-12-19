//+------------------------------------------------------------------+
//|                                         classificationPython.mq5 |
//|                                                           Kelvin |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Kelvin"
#property link ""
#property version "1.00"

#include <Math\Stat\Math.mqh>
#include <Trade\Trade.mqh>

#import "C:\MetaQuotes\MQL5\Libraries\Kel\tfbridge.dll"
int TB_Init();
int TB_Deinit();
int TB_Predict(char &[], MqlRates &[], int, MqlRates &[], int, MqlRates &[], int, MqlRates &[], int, MqlRates &[], int);
#import

input double TRADE_VOLUME      = 0.02;
input double BASERATE          = 0.0008;
input int    max_position_buy  = 2;
input int    max_position_sell = 2;
input int    m_atr_range       = 12;   // ATR
input int    m_atr_range_slow  = 120;  // ATR Slow
input double m_max_sl          = 10;
input double m_max_tp          = 10;
input double m_bias_sl_pos     = 1.0;  // Bias Positive SL
input double m_bias_sl_neg     = 0.7;  // Bias Negative SL
input double m_bias_tp_pos     = 0.8;  // Bias Positive TP
input double m_bias_tp_neg     = 0.9;  // Bias Negative TP
input bool   m_draw_trailing   = false;
input color  m_color_sell      = clrRed;
input color  m_color_buy       = clrRoyalBlue;

int      handlerATR;
int      handlerATRSlow;
long     m_digits = 0;
MqlRates rt[2];

int IMAGE_LENGTH_M15 = 24 + 5;
int IMAGE_LENGTH_H1  = 24 + 5;
int IMAGE_LENGTH_H4  = 12 + 5;
int IMAGE_LENGTH_M5  = 12 + 5;
int IMAGE_LENGTH_D1  = 10 + 5;

int RT_SIZE_INDEX = 1;

double Return(int i) { return Open(0) / Open(i) - 1.0; }
double Height(int i) { return Close(i) - Open(i); }
double Time(int i) { return rt[RT_SIZE_INDEX - i].time; }
double Open(int i) { return rt[RT_SIZE_INDEX - i].open; }
double Close(int i) { return rt[RT_SIZE_INDEX - i].close; }
double High(int i) { return rt[RT_SIZE_INDEX - i].high; }
double Low(int i) { return rt[RT_SIZE_INDEX - i].low; }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  Print("INIT DLL START");
  int init_result = TB_Init();

  if (init_result != 0) {
    Print("INIT DLL FAILED ", init_result);
    return INIT_FAILED;
  }

  Print("INIT DLL SUCCESS");

  handlerATR     = iATR(_Symbol, _Period, m_atr_range);
  handlerATRSlow = iATR(_Symbol, _Period, m_atr_range_slow);

  if (handlerATR == INVALID_HANDLE || handlerATRSlow == INVALID_HANDLE) {
    printf("Error creating ATR indicator");
    return INIT_FAILED;
  }

  m_digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

  return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { TB_Deinit(); }

datetime latest_candle_time_checked_trailing = 0;
// +------------------------------------------------------------------+
// | Expert tick function                                             |
// +------------------------------------------------------------------+
void OnTick() {
  if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;

  if (CopyRates(_Symbol, _Period, 0, 2, rt) != 2) {
    Print("CopyRates of ", _Symbol, " failed, no history");
    return;
  }

  datetime currentTime = Time(0);
  if (latest_candle_time_checked_trailing == currentTime) return;
  latest_candle_time_checked_trailing = currentTime;

  UpdateAllTrailingStops();
  CheckForOpen(currentTime);
}

double Atr(int hlr, int i) {
  double atr[1];
  if (CopyBuffer(hlr, 0, i, 1, atr) != 1) {
    Print("CopyBuffer from iATR failed, no data");
    return 0.0;
  }
  return atr[0];
}

int day_seconds = 86400;

//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen(datetime currentTime) {
  int t          = PositionsTotal();
  int count_buy  = 0;
  int count_sell = 0;

  MqlDateTime dt_current, dt_position;
  TimeToStruct(currentTime, dt_current);

  for (int i = 0; i < t; ++i) {
    string symbol = PositionGetSymbol(i);

    if (_Symbol != symbol) continue;

    ulong ticket = PositionGetTicket(i);

    ENUM_POSITION_TYPE position_type = PositionGetInteger(POSITION_TYPE);
    datetime           position_time = PositionGetInteger(POSITION_TIME);

    TimeToStruct(position_time, dt_current);
    if (position_type == POSITION_TYPE_BUY && dt_current.sec + day_seconds >= dt_current.sec) ++count_buy;
    if (position_type == POSITION_TYPE_SELL && dt_current.sec + day_seconds >= dt_current.sec) ++count_sell;
  }

  bool should_not_buy  = count_buy >= max_position_buy;
  bool should_not_sell = count_sell >= max_position_sell;

  if (should_not_buy && should_not_sell) return;

  MqlRates rt_m5[30];
  if (CopyRates(_Symbol, PERIOD_M5, 1, IMAGE_LENGTH_M5, rt_m5) != IMAGE_LENGTH_M5) {
    Print("CopyRates of M5 failed, no history");
    return;
  }

  MqlRates rt_m15[60];
  if (CopyRates(_Symbol, PERIOD_M15, 1, IMAGE_LENGTH_M15, rt_m15) != IMAGE_LENGTH_M15) {
    Print("CopyRates of M15 failed, no history");
    return;
  }

  MqlRates rt_h1[60];
  if (CopyRates(_Symbol, PERIOD_H1, 1, IMAGE_LENGTH_H1, rt_h1) != IMAGE_LENGTH_H1) {
    Print("CopyRates of H1 failed, no history");
    return;
  }

  MqlRates rt_h4[30];
  if (CopyRates(_Symbol, PERIOD_H4, 1, IMAGE_LENGTH_H4, rt_h4) != IMAGE_LENGTH_H4) {
    Print("CopyRates of H4 failed, no history");
    return;
  }

  MqlRates rt_d1[15];
  if (CopyRates(_Symbol, PERIOD_D1, 1, IMAGE_LENGTH_D1, rt_d1) != IMAGE_LENGTH_D1) {
    Print("CopyRates of D1 failed, no history");
    return;
  }

  // Print(rt_m15[0].time, " ", rt_m15[52].time);

  ENUM_ORDER_TYPE signal = WRONG_VALUE;

  char buffer[10240];
  int  predict_result = TB_Predict(buffer, rt_m5, IMAGE_LENGTH_M5, rt_m15, IMAGE_LENGTH_M15, rt_h1, IMAGE_LENGTH_H1,
                                  rt_h4, IMAGE_LENGTH_H4, rt_d1, IMAGE_LENGTH_D1);

  Print("PREDICT RESULT ", predict_result, " ", CharArrayToString(buffer));

  if (predict_result <= 0) return;

  if (predict_result == 1)
    signal = ORDER_TYPE_BUY;
  else if (predict_result == 2)
    signal = ORDER_TYPE_SELL;

  // signal = ORDER_TYPE_BUY;

  //--- additional checks
  if (signal == WRONG_VALUE) return;
  if (signal == ORDER_TYPE_BUY && should_not_buy) return;
  if (signal == ORDER_TYPE_SELL && should_not_sell) return;

  CTrade trade;
  double tp    = 0;
  double sl    = 0;
  double price = 0;
  double aaa   = StringToInteger(CharArrayToString(buffer));

  if (signal == ORDER_TYPE_SELL) {
    price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    tp    = NormalizeDouble((1 - BASERATE * aaa) * price, _Digits);
    // tp    = NormalizeDouble((1 - RATE_TP) * price, _Digits);
    sl = NormalizeDouble((1 + BASERATE * aaa) * price, _Digits);
  } else {
    price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    tp    = NormalizeDouble((1 + BASERATE * aaa) * price, _Digits);
    // tp    = NormalizeDouble((1 + RATE_TP) * price, _Digits);
    sl = NormalizeDouble((1 - BASERATE * aaa) * price, _Digits);
  }

  trade.PositionOpen(_Symbol, signal, TRADE_VOLUME, price, sl, tp);
}

void UpdateAllTrailingStops() {
  // Print("Dynamic Trailing Stop ATR - Start updating stoploss");

  double atr           = Atr(handlerATR, 1);
  double atrSlow       = Atr(handlerATRSlow, 1);
  double currentHeight = Height(1);
  int    t             = PositionsTotal();

  if (currentHeight == 0.0 || t == 0) {
    // Print("Dynamic Trailing Stop ATR - Stop - CurrentHeight: ", currentHeight, ", PositionsTotal: ", t,
    //       ", Current ATR: ", atr[0]);
    return;
  }

  for (int i = 0; i < t; ++i) {
    string symbol = PositionGetSymbol(i);

    if (_Symbol != symbol) continue;

    ulong ticket = PositionGetTicket(i);
    CheckForTrailingStop(ticket, atr, atrSlow, currentHeight);
  }
}

bool NewStopLoss(double atr, double atrSlow, ulong ticket, double height, double &sl, double &tp) {
  ENUM_POSITION_TYPE position_type = PositionGetInteger(POSITION_TYPE);
  bool               isLong        = position_type == POSITION_TYPE_BUY;
  double             pos_sl        = PositionGetDouble(POSITION_SL);
  double             pos_tp        = PositionGetDouble(POSITION_TP);

  if (height == 0) {
    if (m_draw_trailing && pos_sl > 0.0) {
      string name = "sl" + Time(1);
      ObjectCreate(0, name, OBJ_TREND, 0, Time(0), pos_sl, Time(1), pos_sl);
      ObjectSetInteger(0, name, OBJPROP_COLOR, isLong ? m_color_buy : m_color_sell);
    }
    return false;
  }

  double priceOpen      = PositionGetDouble(POSITION_PRICE_OPEN);
  double direction      = height > 0 ? 1 : -1;
  bool   followingTrend = isLong ? direction > 0 : direction < 0;
  double bias_sl        = followingTrend ? m_bias_sl_pos : m_bias_sl_neg;
  double bias_tp        = followingTrend ? m_bias_tp_pos : m_bias_tp_neg;
  double base_sl        = pos_sl == 0.0 ? priceOpen : pos_sl;
  double base_tp        = pos_tp == 0.0 ? priceOpen : pos_tp;
  double mod_sl         = pos_sl == 0.0 ? atrSlow * m_max_sl : MathSqrt(atr * MathAbs(height)) * bias_sl;
  double mod_tp         = pos_tp == 0.0 ? atrSlow * m_max_tp : MathSqrt(atr * MathAbs(height)) * bias_tp;

  sl = MathRound(MathMin(base_sl + direction * mod_sl, priceOpen + atrSlow * m_max_sl), m_digits);
  tp = MathRound(base_tp + direction * mod_tp, m_digits);

  if (m_draw_trailing && pos_sl > 0.0) {
    string name = "sl" + ticket + Time(1);
    ObjectCreate(0, name, OBJ_TREND, 0, Time(0), sl, Time(1), pos_sl);
    ObjectSetInteger(0, name, OBJPROP_COLOR, isLong ? m_color_buy : m_color_sell);
    string name1 = "tp" + ticket + Time(1);
    ObjectCreate(0, name1, OBJ_TREND, 0, Time(0), tp, Time(1), pos_tp);
    ObjectSetInteger(0, name1, OBJPROP_COLOR, isLong ? m_color_sell : m_color_buy);
  }

  return sl != EMPTY_VALUE;
}

bool CheckForTrailingStop(ulong ticket, double atr, double atrSlow, double height) {
  // Print("Dynamic Trailing Stop ATR - Ticket: ", ticket);

  double sl = EMPTY_VALUE;
  double tp = EMPTY_VALUE;
  NewStopLoss(atr, atrSlow, ticket, height, sl, tp);

  if (sl == EMPTY_VALUE || tp == EMPTY_VALUE) {
    return false;
  }

  CTrade trade;
  bool   result = trade.PositionModify(ticket, sl, tp);

  return result;
}
