//+------------------------------------------------------------------+
//|                                         static-trailing-stop.mq5 |
//|                                                           Kelvin |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Kelvin"
#property link ""
#property version "1.00"

#include <Trade\Trade.mqh>

//--- input parameters
input double MaximumRisk = 0.01; // Maximum Risk in percentage
// input double DecreaseFactor = 3; // Descrease factor
input int MovingPeriodFast = 6;
input int MovingPeriodSlow = 30;

input double trailing_stop_value = 16;
input double stop_loss = 8;

int ExtHandleFast = 0;
int ExtHandleSlow = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(void)
{
  // ExtHandleFractals = iFractals(_Symbol, _Period);
  ExtHandleFast = iMA(_Symbol, _Period, MovingPeriodFast, 0, MODE_SMA, PRICE_CLOSE);
  ExtHandleSlow = iMA(_Symbol, _Period, MovingPeriodSlow, 0, MODE_SMA, PRICE_CLOSE);

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

//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
double TradeSizeOptimized(void)
{
  double price = 0.0;
  double margin = 0.0;
  //--- Calculate the lot size
  if (!SymbolInfoDouble(_Symbol, SYMBOL_ASK, price))
    return 0.0;
  if (!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, price, margin))
    return 0.0;
  if (margin <= 0.0)
    return 0.0;

  double lot = NormalizeDouble(AccountInfoDouble(ACCOUNT_FREEMARGIN) * MaximumRisk / margin, 2);

  //--- normalizing and checking the allowed values of the trade volume
  double stepvol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
  lot = stepvol * NormalizeDouble(lot / stepvol, 0);

  double minvol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  if (lot < minvol)
    return 0.0;

  double maxvol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  if (lot > maxvol)
    return maxvol;

  //--- return the value of the trade volume
  return lot;
}

//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen(void)
{
  MqlRates rt[1];
  //--- copy the price values
  if (CopyRates(_Symbol, _Period, 0, 1, rt) != 1)
  {
    Print("CopyRates of ", _Symbol, " failed, no history");
    return;
  }
  //--- Trade only on the first tick of the new bar
  if (rt[0].tick_volume > 1)
    return;

  //--- Get the current value of the Moving Average indicator
  double maFast[3];
  if (CopyBuffer(ExtHandleFast, 0, 0, 3, maFast) != 3)
  {
    Print("CopyBuffer from iMA fast failed, no data");
    return;
  }
  double maSlow[3];
  if (CopyBuffer(ExtHandleSlow, 0, 0, 3, maSlow) != 3)
  {
    Print("CopyBuffer from iMA slow failed, no data");
    return;
  }
  //--- check the signals
  ENUM_ORDER_TYPE signal = WRONG_VALUE;

  if (maFast[0] < maSlow[0] && maFast[1] > maSlow[1])
    // maFast > maSlow => Buy
    signal = ORDER_TYPE_BUY;
  else if (maFast[0] > maSlow[0] && maFast[1] < maSlow[1])
    // maFast < maSlow => Sell
    signal = ORDER_TYPE_SELL;

  //--- additional checks
  if (signal == WRONG_VALUE || Bars(_Symbol, _Period) <= 100)
    return;

  CTrade trade;

  double trade_volume = TradeSizeOptimized(), price, sl;
  if (trade_volume <= 0.0)
    return;

  if (signal == ORDER_TYPE_SELL)
  {
    price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    sl = price + stop_loss;
  }
  else
  {
    price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    sl = price - stop_loss;
  }

  trade.PositionOpen(_Symbol, signal, trade_volume, price, sl, 0);
}

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

  if (rt[4].tick_volume > 1)
    return;

  int t = PositionsTotal();
  for (int i = 0; i < t; ++i)
  {
    string symbol = PositionGetSymbol(i);

    if (_Symbol != symbol)
      continue;

    ulong ticket = PositionGetTicket(i);
    CheckForTrailingStop(ticket);
  }
}

void CheckForTrailingStop(ulong ticket)
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
    if (bid_price - open_price > trailing_stop_value)
    {
      local_stop_loss = NormalizeDouble(bid_price - trailing_stop_value, Digits());
      if (current_stop_loss < local_stop_loss)
      {
        CTrade trade;
        trade.PositionModify(ticket, local_stop_loss, current_take_profit);
      }
    }
  }
  else if (position_type == POSITION_TYPE_SELL)
  {
    if (open_price - ask_price > trailing_stop_value)
    {
      local_stop_loss = NormalizeDouble(ask_price + trailing_stop_value, Digits());
      if (current_stop_loss > local_stop_loss)
      {
        CTrade trade;
        trade.PositionModify(ticket, local_stop_loss, current_take_profit);
      }
    }
  }
}
