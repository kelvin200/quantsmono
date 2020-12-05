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
#property indicator_buffers 1
#property indicator_plots 1

#property indicator_label1 "Reversal"
#property indicator_type1 DRAW_LINE
#property indicator_color1 DodgerBlue

//--- indicator buffers
double Buffer[];

// ATR buffer
double BufferATR[];
double BufferRSI[];

int handleATR;
int handleRSI;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
  //--- assignment of arrays to indicator buffers
  SetIndexBuffer(0, Buffer, INDICATOR_DATA);

  // Init ATR
  handleATR = iATR(_Symbol, _Period, 14);
  handleRSI = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);

  //--- normal initialization of the indicator
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
  if (rates_total < 15)
    return 0;

  int calculated = BarsCalculated(handleATR);
  if (calculated <= 0)
  {
    PrintFormat("BarsCalculated() returned %d, error code %d", calculated, GetLastError());
    return (0);
  }
  if (CopyBuffer(handleATR, 0, 0, rates_total, BufferATR) < 0)
  {
    //--- if the copying fails, tell the error code
    PrintFormat("Failed to copy data from the iATR indicator, error code %d", GetLastError());
    //--- quit with zero result - it means that the indicator is considered as not calculated
    return (false);
  }
  if (CopyBuffer(handleRSI, 0, 0, rates_total, BufferRSI) < 0)
  {
    //--- if the copying fails, tell the error code
    PrintFormat("Failed to copy data from the iRSI indicator, error code %d", GetLastError());
    //--- quit with zero result - it means that the indicator is considered as not calculated
    return (false);
  }

  int start = prev_calculated == 0 ? 14 : prev_calculated + 14;

  for (int i = start; i < rates_total; ++i)
  {
    Buffer[i] = (BufferRSI[i] - 50) * MathSqrt(BufferATR[i]);
  }

  //--- return the prev_calculated value for the next call
  return (rates_total);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  if (handleATR != INVALID_HANDLE)
    IndicatorRelease(handleATR);
}