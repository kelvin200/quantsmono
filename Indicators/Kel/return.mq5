//+------------------------------------------------------------------+
//|                                               Demo_iFractals.mq5 |
//|                        Copyright 2011, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2011, MetaQuotes Software Corp."
#property link "https://www.mql5.com"
#property version "1.00"
#property description "The indicator demonstrates how to obtain data"
#property description "of indicator buffers for the iFractals technical indicator."
#property description "A symbol and timeframe used for calculation of the indicator,"
#property description "are set by the symbol and period parameters."
#property description "The method of creation of the handle is set through the 'type' parameter (function type)."

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots 4

#property indicator_label1 "12"
#property indicator_type1  DRAW_LINE
#property indicator_color1 DodgerBlue

#property indicator_label2 "48"
#property indicator_type2  DRAW_LINE
#property indicator_color2 Yellow

#property indicator_label3 "120"
#property indicator_type3  DRAW_LINE
#property indicator_color3 Orange

#property indicator_label4 "alpha"
#property indicator_type4  DRAW_LINE
#property indicator_color4 Purple

input int            range      = 5;
input int            fastPeriod = 2;
input ENUM_MA_METHOD fastMethod = MODE_SMA;

//--- indicator buffers
double Buffer0[];
double Buffer1[];
double Buffer2[];
double Buffer3[];

double BufferATR[];
double BufferFast[];
int    handleATR;
int    handleFast;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
  //--- assignment of arrays to indicator buffers
  SetIndexBuffer(0, Buffer0, INDICATOR_DATA);
  SetIndexBuffer(1, Buffer1, INDICATOR_DATA);
  SetIndexBuffer(2, Buffer2, INDICATOR_DATA);
  SetIndexBuffer(3, Buffer3, INDICATOR_DATA);

  handleFast = iMA(_Symbol, PERIOD_H4, fastPeriod, 0, fastMethod, PRICE_OPEN);
  handleATR  = iATR(_Symbol, _Period, range);

  //--- normal initialization of the indicator
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int       rates_total,
                const int       prev_calculated,
                const datetime &time[],
                const double &  open[],
                const double &  high[],
                const double &  low[],
                const double &  close[],
                const long &    tick_volume[],
                const long &    volume[],
                const int &     spread[]) {
  if (rates_total < range + 1) return 0;

  int calculated = BarsCalculated(handleATR);
  if (calculated <= 0) {
    PrintFormat("BarsCalculated() returned %d, error code %d", calculated, GetLastError());
    return (0);
  }
  if (CopyBuffer(handleATR, 0, 0, rates_total, BufferATR) < 0) {
    //--- if the copying fails, tell the error code
    PrintFormat("Failed to copy data from the iATR indicator, error code %d", GetLastError());
    //--- quit with zero result - it means that the indicator is considered as not calculated
    return (false);
  }
  if (CopyBuffer(handleFast, 0, 0, rates_total, BufferFast) < 0) {
    //--- if the copying fails, tell the error code
    PrintFormat("Failed to copy data from the fast indicator, error code %d", GetLastError());
    //--- quit with zero result - it means that the indicator is considered as not calculated
    return (false);
  }

  int start = prev_calculated + range;

  for (int i = prev_calculated + 24; i < rates_total; ++i) {
    Buffer0[i] = (open[i] / open[i - 4] - 1) * 4 + (open[i] / open[i - 24] - 1) * 8;
    // Buffer1[i] = Buffer0[i] * MathLog(tick_volume[i]) / 10;
    // Buffer2[i] = Buffer0[i] * volume[i];
  }
  for (int i = prev_calculated + 120; i < rates_total; ++i) {
    // Buffer0[i] = (open[i] / open[i - range] - 1) * 100;
    // Buffer1[i] = 0;
    Buffer1[i] = (open[i] / open[i - 120] - 1) * 4;
    // Buffer2[i] = Buffer0[i] * volume[i];
  }
  for (int i = prev_calculated + 480; i < rates_total; ++i) {
    // Buffer0[i] = (open[i] / open[i - range] - 1) * 100;
    // Buffer2[i] = 0;
    Buffer2[i] = (open[i] / open[i - 480] - 1) * 4;
    // Buffer3[i] = -Buffer0[i] + Buffer1[i] + Buffer2[i];
    Buffer3[i] = Buffer0[i] + Buffer1[i] + Buffer2[i];
    // Buffer2[i] = Buffer0[i] * volume[i];
  }

  //--- return the prev_calculated value for the next call
  return (rates_total);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}