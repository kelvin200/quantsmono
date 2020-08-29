//+------------------------------------------------------------------+
//|                                                           t2.mq5 |
//|                                                           Kelvin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Kelvin"
#property link "https://www.mql5.com"
#property version "1.00"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
// #include <Expert\Expert.mqh>
#include <Expert\Kel\ExpertAlpha.mqh>
//--- available signals
#include <Expert\Signal\SignalMACD.mqh>
#include <Expert\Signal\SignalRSI.mqh>

//--- available trailing
#include <Expert\Trailing\Kel\TrailingATR.mqh>
//--- available money management
#include <Expert\Money\MoneyFixedLot.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
//--- inputs for expert
input string Expert_Title       = "t2";     // Document name
input string Expert_Alpha1      = "+(R5)";  //
ulong        Expert_MagicNumber = 17475;    //
bool         Expert_EveryTick   = false;    //
//--- inputs for main signal
input int                Signal_ThresholdOpen     = 10;    // Signal threshold value to open [0...100]
input int                Signal_ThresholdClose    = 10;    // Signal threshold value to close [0...100]
input double             Signal_PriceLevel        = 0.0;   // Price level to execute a deal
input double             Signal_StopLevel         = 50.0;  // Stop Loss level (in points)
input double             Signal_TakeLevel         = 50.0;  // Take Profit level (in points)
input int                Signal_Expiration        = 4;     // Expiration of pending orders (in bars)
input int                Signal_RSI_PeriodRSI     = 8;     // Relative Strength Index(8,...) Period of calculation
input ENUM_APPLIED_PRICE Signal_RSI_Applied       = PRICE_CLOSE;  // Relative Strength Index(8,...) Prices series
input double             Signal_RSI_Weight        = 1.0;          // Relative Strength Index(8,...) Weight [0...1.0]
input int                Signal_MACD_PeriodFast   = 12;           // MACD(12,24,9,PRICE_CLOSE) Period of fast EMA
input int                Signal_MACD_PeriodSlow   = 24;           // MACD(12,24,9,PRICE_CLOSE) Period of slow EMA
input int                Signal_MACD_PeriodSignal = 9;  // MACD(12,24,9,PRICE_CLOSE) Period of averaging of difference
input ENUM_APPLIED_PRICE Signal_MACD_Applied      = PRICE_CLOSE;  // MACD(12,24,9,PRICE_CLOSE) Prices series
input double             Signal_MACD_Weight       = 1.0;          // MACD(12,24,9,PRICE_CLOSE) Weight [0...1.0]
//--- inputs for trailing
input int    Trailing_ATR_Range        = 9;         // Period of ATR
input double Trailing_ATR_BiasPositive = 1.0;       // Bias Positive
input double Trailing_ATR_BiasNegative = 1.0;       // Bias Negative
input int    Trailing_ATR_MaxStopLoss  = 500;       // Max StopLoss in points
input bool   Trailing_ATR_DrawTrailing = true;      // Draw StopLoss history
input color  Trailing_ATR_ColorBuy     = 16760576;  // Color of Long StopLoss
input color  Trailing_ATR_ColorSell    = 17919;     // Color of Short StopLoss
//--- inputs for money
input double Money_FixLot_Percent = 10.0;  // Percent
input double Money_FixLot_Lots    = 0.1;   // Fixed volume
//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+
// CExpert ExtExpert;
CExpertAlpha ExtExpert;
// +------------------------------------------------------------------+
//| Initialization function of the expert                            |
//+------------------------------------------------------------------+
int OnInit() {
  //--- Initializing expert
  if (!ExtExpert.Init(Symbol(), Period(), Expert_EveryTick, Expert_MagicNumber)) {
    //--- failed
    printf(__FUNCTION__ + ": error initializing expert");
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  ExtExpert.Alpha1(Expert_Alpha1);
  //--- Creating signal
  CExpertSignal *signal = new CExpertSignal;
  if (signal == NULL) {
    //--- failed
    printf(__FUNCTION__ + ": error creating signal");
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  //---
  ExtExpert.InitSignal(signal);
  signal.ThresholdOpen(Signal_ThresholdOpen);
  signal.ThresholdClose(Signal_ThresholdClose);
  signal.PriceLevel(Signal_PriceLevel);
  signal.StopLevel(Signal_StopLevel);
  //  signal.TakeLevel(Signal_TakeLevel);
  signal.Expiration(Signal_Expiration);
  //--- Creating filter CSignalRSI
  CSignalRSI *filter0 = new CSignalRSI;
  if (filter0 == NULL) {
    //--- failed
    printf(__FUNCTION__ + ": error creating filter0");
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  signal.AddFilter(filter0);
  //--- Set filter parameters
  filter0.PeriodRSI(Signal_RSI_PeriodRSI);
  filter0.Applied(Signal_RSI_Applied);
  filter0.Weight(Signal_RSI_Weight);
  //--- Creating filter CSignalMACD
  CSignalMACD *filter1 = new CSignalMACD;
  if (filter1 == NULL) {
    //--- failed
    printf(__FUNCTION__ + ": error creating filter1");
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  signal.AddFilter(filter1);
  //--- Set filter parameters
  filter1.PeriodFast(Signal_MACD_PeriodFast);
  filter1.PeriodSlow(Signal_MACD_PeriodSlow);
  filter1.PeriodSignal(Signal_MACD_PeriodSignal);
  filter1.Applied(Signal_MACD_Applied);
  filter1.Weight(Signal_MACD_Weight);
  //--- Creation of trailing object
  CTrailingATR *trailing = new CTrailingATR;
  if (trailing == NULL) {
    //--- failed
    printf(__FUNCTION__ + ": error creating trailing");
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  //--- Add trailing to expert (will be deleted automatically))
  if (!ExtExpert.InitTrailing(trailing)) {
    //--- failed
    printf(__FUNCTION__ + ": error initializing trailing");
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  //--- Set trailing parameters
  trailing.Range(Trailing_ATR_Range);
  trailing.BiasPositive(Trailing_ATR_BiasPositive);
  trailing.BiasNegative(Trailing_ATR_BiasNegative);
  trailing.MaxStopLoss(Trailing_ATR_MaxStopLoss);
  trailing.DrawTrailing(Trailing_ATR_DrawTrailing);
  trailing.ColorBuy(Trailing_ATR_ColorBuy);
  trailing.ColorSell(Trailing_ATR_ColorSell);
  //--- Creation of money object
  CMoneyFixedLot *money = new CMoneyFixedLot;
  if (money == NULL) {
    //--- failed
    printf(__FUNCTION__ + ": error creating money");
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  //--- Add money to expert (will be deleted automatically))
  if (!ExtExpert.InitMoney(money)) {
    //--- failed
    printf(__FUNCTION__ + ": error initializing money");
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  //--- Set money parameters
  money.Percent(Money_FixLot_Percent);
  money.Lots(Money_FixLot_Lots);
  //--- Check all trading objects parameters
  if (!ExtExpert.ValidationSettings()) {
    //--- failed
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  //--- Tuning of all necessary indicators
  if (!ExtExpert.InitIndicators()) {
    //--- failed
    printf(__FUNCTION__ + ": error initializing indicators");
    ExtExpert.Deinit();
    return (INIT_FAILED);
  }
  //--- ok
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { ExtExpert.Deinit(); }
//+------------------------------------------------------------------+
//| "Tick" event handler function                                    |
//+------------------------------------------------------------------+
void OnTick() { ExtExpert.OnTick(); }
//+------------------------------------------------------------------+
//| "Trade" event handler function                                   |
//+------------------------------------------------------------------+
void OnTrade() { ExtExpert.OnTrade(); }
//+------------------------------------------------------------------+
//| "Timer" event handler function                                   |
//+------------------------------------------------------------------+
void OnTimer() { ExtExpert.OnTimer(); }
//+------------------------------------------------------------------+
