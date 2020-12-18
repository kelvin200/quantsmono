//+------------------------------------------------------------------+
//|                                         classificationPython.mq5 |
//|                                                           Kelvin |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Kelvin"
#property link ""
#property version "1.00"

#include <Trade\Trade.mqh>

#import "C:\MetaQuotes\MQL5\Libraries\Kel\tfbridge.dll"
int TB_Init();
int TB_Deinit();
int TB_Predict(char&[], MqlRates&[], int, MqlRates&[], int, MqlRates&[], int, MqlRates&[], int, MqlRates&[], int);
#import

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

  return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { TB_Deinit(); }

// +------------------------------------------------------------------+
// | Expert tick function                                             |
// +------------------------------------------------------------------+
void OnTick() {
  if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;

  CheckForOpen();
}

input double TRADE_VOLUME = 0.02;
input double BASERATE     = 0.0008;
input double TARGET_TP    = 3;
input double TARGET_SL    = 2;
double       RATE_TP      = BASERATE * TARGET_TP;
double       RATE_SL      = BASERATE * TARGET_SL;

int IMAGE_LENGTH_M15 = 24 + 5;
int IMAGE_LENGTH_H1  = 24 + 5;
int IMAGE_LENGTH_H4  = 12 + 5;
int IMAGE_LENGTH_M5  = 12 + 5;
int IMAGE_LENGTH_D1  = 10 + 5;

datetime latest_candle_time_checked_open = 0;
//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen(void) {
  MqlRates rt[1];
  //--- copy the price values
  if (CopyRates(_Symbol, _Period, 0, 1, rt) != 1) {
    Print("CopyRates of ", _Symbol, " failed, no history");
    return;
  }

  if (latest_candle_time_checked_open == rt[0].time) return;
  latest_candle_time_checked_open = rt[0].time;

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

  if (predict_result <= 0) {
    return;
  }

  // if (predict_result == 1)
  //   signal = ORDER_TYPE_BUY;
  // else if (predict_result == 2)
  //   signal = ORDER_TYPE_SELL;

  signal = ORDER_TYPE_BUY;

  //--- additional checks
  if (signal == WRONG_VALUE) return;

  CTrade trade;
  double tp    = 0;
  double sl    = 0;
  double price = 0;

  if (signal == ORDER_TYPE_SELL) {
    price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    tp    = NormalizeDouble((1 - BASERATE * predict_result) * price, _Digits);
    // tp    = NormalizeDouble((1 - RATE_TP) * price, _Digits);
    sl    = NormalizeDouble((1 + RATE_SL) * price, _Digits);
  } else {
    price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    tp    = NormalizeDouble((1 + BASERATE * predict_result) * price, _Digits);
    // tp    = NormalizeDouble((1 + RATE_TP) * price, _Digits);
    sl    = NormalizeDouble((1 - RATE_SL) * price, _Digits);
  }

  trade.PositionOpen(_Symbol, signal, TRADE_VOLUME, price, sl, tp);
}
