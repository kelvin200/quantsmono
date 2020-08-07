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
#property indicator_buffers 2
#property indicator_plots 2

#property indicator_label1 "Up"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 Green

#property indicator_label2 "Down"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 Red

//--- indicator buffers
double BufferUp[];
double BufferDown[];

input int fastPeriod = 6;
input int slowPeriod = 30;

input ENUM_MA_METHOD fastMethod = MODE_SMA;
input ENUM_MA_METHOD slowMethod = MODE_SMA;

// MA buffer
double BufferFast[];
double BufferSlow[];

int handleFast;
int handleSlow;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
  // Init MA
  handleFast = iMA(_Symbol, _Period, fastPeriod, 0, fastMethod, PRICE_CLOSE);
  handleSlow = iMA(_Symbol, _Period, slowPeriod, 0, slowMethod, PRICE_CLOSE);

  //--- indicator buffers mapping
  SetIndexBuffer(0, BufferUp, INDICATOR_DATA);
  SetIndexBuffer(1, BufferDown, INDICATOR_DATA);
  //--- Define the symbol code for drawing in PLOT_ARROW
  PlotIndexSetInteger(0, PLOT_ARROW, 241);
  PlotIndexSetInteger(1, PLOT_ARROW, 242);
  //--- Set the vertical shift of arrows in pixels
  // PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 5);
  //--- Set as an empty value 0
  PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
  PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
  //---
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
  if (rates_total < 2)
    return 0;

  int calculated = BarsCalculated(handleFast);
  if (calculated <= 0)
  {
    PrintFormat("BarsCalculated() returned %d, error code %d", calculated, GetLastError());
    return (0);
  }
  if (CopyBuffer(handleFast, 0, 0, rates_total, BufferFast) < 0)
  {
    //--- if the copying fails, tell the error code
    PrintFormat("Failed to copy data from the fast indicator, error code %d", GetLastError());
    //--- quit with zero result - it means that the indicator is considered as not calculated
    return (false);
  }
  if (CopyBuffer(handleSlow, 0, 0, rates_total, BufferSlow) < 0)
  {
    //--- if the copying fails, tell the error code
    PrintFormat("Failed to copy data from the slow indicator, error code %d", GetLastError());
    //--- quit with zero result - it means that the indicator is considered as not calculated
    return (false);
  }

  int i = 2;
  int end = prev_calculated == 0 ? rates_total : rates_total - prev_calculated;

  for (; i < end; ++i)
  {
    if (BufferFast[i - 2] > BufferSlow[i - 2] && BufferFast[i - 1] <= BufferSlow[i - 1])
      BufferDown[i - 1] = 1;
    else
      BufferDown[i - 1] = 0;
    if (BufferFast[i - 2] < BufferSlow[i - 2] && BufferFast[i - 1] >= BufferSlow[i - 1])
      BufferUp[i - 1] = 1;
    else
      BufferUp[i - 1] = 0;
  }
  BufferDown[i - 1] = 0;
  BufferUp[i - 1] = 0;

  //--- return the prev_calculated value for the next call
  return (rates_total);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  if (handleFast != INVALID_HANDLE)
    IndicatorRelease(handleFast);
  if (handleSlow != INVALID_HANDLE)
    IndicatorRelease(handleSlow);
}