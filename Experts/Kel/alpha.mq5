//+------------------------------------------------------------------+
//|                                                        alpha.mq5 |
//|                                                           Kelvin |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Kelvin"
#property link ""
#property version "1.00"

#include <Math\Stat\Math.mqh>
#include <Trade\Trade.mqh>

//--- input parameters
input int    m_atr_range      = 12;    //
input int    m_atr_range_slow = 120;   //
input double m_thresold       = 0.01;  //
input double m_sl             = 5;     //
input double m_max_sl         = 10;
input double m_tp             = 5;  //
input double m_max_tp         = 10;
input int    m_4              = 2;    //
input int    m_24             = 2;    //
input int    m_48             = 2;    //
input int    m_120            = 2;    //
input int    m_480            = 2;    //
input double m_bias_pos       = 1.0;  // Bias Positive
input double m_bias_neg       = 0.8;  // Bias Negative
input bool   m_draw_trailing  = false;
input color  m_color_sell     = clrRed;
input color  m_color_buy      = clrRoyalBlue;

datetime latest_candle_time_checked_trailing = 0;
int      handlerATR;
int      handlerATRSlow;
long     m_digits = 0;
MqlRates rt[501];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
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
void OnDeinit(const int reason) {}

// +------------------------------------------------------------------+
// | Expert tick function                                             |
// +------------------------------------------------------------------+
void OnTick() {
  if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;

  if (CopyRates(_Symbol, _Period, 0, 501, rt) != 501) {
    Print("CopyRates of ", _Symbol, " failed, no history");
    return;
  }

  if (latest_candle_time_checked_trailing == Time(0)) return;
  latest_candle_time_checked_trailing = Time(0);

  UpdateAllTrailingStops();
  CheckOpen();
}

double Atr(int hlr, int i) {
  double atr[1];
  if (CopyBuffer(hlr, 0, i, 1, atr) != 1) {
    Print("CopyBuffer from iATR failed, no data");
    return 0.0;
  }
  return atr[0];
}

void UpdateAllTrailingStops() {
  // Print("Dynamic Trailing Stop ATR - Start updating stoploss");

  double atr           = Atr(handlerATR, 1);
  double atrSlow       = Atr(handlerATRSlow, 1);
  double currentHeight = Height(0);
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
  double bias           = followingTrend ? m_bias_pos : m_bias_neg;
  double base_sl        = pos_sl == 0.0 ? priceOpen : pos_sl;
  double base_tp        = pos_tp == 0.0 ? priceOpen : pos_tp;
  double mod_sl         = pos_sl == 0.0 ? atrSlow * m_max_sl : MathSqrt(atr * MathAbs(height)) * bias;
  double mod_tp         = pos_tp == 0.0 ? atrSlow * m_max_tp : MathSqrt(atr * MathAbs(height)) * bias;

  sl = MathRound(MathMin(base_sl + direction * mod_sl, priceOpen + m_max_sl), m_digits);
  tp = MathRound(MathMin(base_tp + direction * mod_tp, priceOpen + m_max_sl), m_digits);

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

bool CheckOpen() {
  double a = CalculateAlpha2();
  double l = 0.01;

  Print("Alpha ", a);

  if (l >= 0.01) {
    CTrade m_trade;

    double atr = Atr(handlerATRSlow, 1);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl  = atr * m_sl;
    double tp  = atr * m_tp;

    if (a > m_thresold) return m_trade.Buy(l, _Symbol, ask, ask - sl, ask + tp);
    if (a < -m_thresold) return m_trade.Sell(l, _Symbol, bid, bid + sl, bid - tp);
  }
  return false;
}

double Return(int i) { return Open(0) / Open(i) - 1.0; }
double Height(int i) { return Close(i) - Open(i); }
double Time(int i) { return rt[500 - i].time; }
double Open(int i) { return rt[500 - i].open; }
double Close(int i) { return rt[500 - i].close; }
double High(int i) { return rt[500 - i].high; }
double Low(int i) { return rt[500 - i].low; }

double CalculateAlpha2() {
  return Return(4) * m_4 + Return(24) * m_24 + Return(48) * m_48 + Return(120) * m_120 + Return(480) * m_480;
}
