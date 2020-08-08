//+------------------------------------------------------------------+
//|                                                  TrailingATR.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include <Expert\ExpertTrailing.mqh>
// wizard description start
//+------------------------------------------------------------------+
//| Description of the class                                         |
//| Title=Trailing Stop based on ATR                                 |
//| Type=Trailing                                                    |
//| Name=ATR                                                         |
//| Class=CTrailingATR                                               |
//| Page=                                                            |
//| Parameter=Period,int,12,Period of ATR                            |
//| Parameter=Shift,int,0,Shift of ATR                               |
//| Parameter=Method,ENUM_ATR_METHOD,MODE_SATR,Method of averaging   |
//| Parameter=Applied,ENUM_APPLIED_PRICE,PRICE_CLOSE,Prices series   |
//+------------------------------------------------------------------+
// wizard description end
//+------------------------------------------------------------------+
//| Class CTrailingATR.                                              |
//| Purpose: Class of trailing stops based on ATR.                   |
//|              Derives from class CExpertTrailing.                 |
//+------------------------------------------------------------------+
class CTrailingATR : public CExpertTrailing {
 protected:
  CiATR *m_ATR;
  int    m_atr_range;
  double m_bias_pos;
  double m_bias_neg;
  double m_max_sl;

 public:
  CTrailingATR(void);
  ~CTrailingATR(void);

  void Range(int range) { m_atr_range = range; }
  void BiasPositive(double bias) { m_bias_pos = bias; }
  void BiasNegative(double bias) { m_bias_neg = bias; }
  void MaxStopLoss(int sl) { m_max_sl = sl * m_symbol.TickSize(); }

  virtual bool InitIndicators(CIndicators *indicators);
  virtual bool ValidationSettings(void);
  virtual bool CheckTrailingStopLong(CPositionInfo *position,
                                     double &       sl,
                                     double &       tp);
  virtual bool CheckTrailingStopShort(CPositionInfo *position,
                                      double &       sl,
                                      double &       tp);

 protected:
  double CandleHeight(int ind) { return (Close(ind) - Open(ind)); }
  int    CandleDirection(int ind) {
    double height = CandleHeight(ind);
    return height > 0 ? 1 : height < 0 ? -1 : 0;
  }

  virtual bool NewStopLoss(bool           isLong,
                           CPositionInfo *position,
                           double &       sl,
                           double &       tp);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrailingATR::CTrailingATR(void) : m_ATR(NULL), m_atr_range(9) {}
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrailingATR::~CTrailingATR(void) {}
//+------------------------------------------------------------------+
//| Validation settings protected data.                              |
//+------------------------------------------------------------------+
bool CTrailingATR::ValidationSettings(void) {
  if (!CExpertTrailing::ValidationSettings()) return false;
  //--- initial data checks
  if (m_atr_range <= 0) {
    printf(__FUNCTION__ + ": range of ATR must be greater than 0");
    return false;
  }
  //--- ok
  return true;
}
//+------------------------------------------------------------------+
//| Checking for input parameters and setting protected data.        |
//+------------------------------------------------------------------+
bool CTrailingATR::InitIndicators(CIndicators *indicators) {
  //--- check
  if (indicators == NULL) return false;
  //--- create ATR indicator
  if (m_ATR == NULL)
    if ((m_ATR = new CiATR) == NULL) {
      printf(__FUNCTION__ + ": error creating object");
      return false;
    }
  //--- add ATR indicator to collection
  if (!indicators.Add(m_ATR)) {
    printf(__FUNCTION__ + ": error adding object");
    delete m_ATR;
    return false;
  }
  //--- initialize ATR indicator
  if (!m_ATR.Create(m_symbol.Name(), m_period, m_atr_range)) {
    printf(__FUNCTION__ + ": error initializing object");
    return false;
  }
  m_ATR.BufferResize(2);
  //--- ok
  return true;
}

bool CTrailingATR::NewStopLoss(bool           isLong,
                               CPositionInfo *position,
                               double &       sl,
                               double &       tp) {
  double height;

  if (position == NULL) return false;
  if ((height = CandleHeight(1)) == 0) return false;

  double direction      = height > 0 ? 1 : -1;
  bool   followingTrend = isLong ? direction > 0 : direction < 0;
  double bias           = followingTrend ? m_bias_pos : m_bias_neg;
  double pos_sl         = position.StopLoss();
  double priceOpen      = position.PriceOpen();
  double base           = pos_sl == 0.0 ? priceOpen : pos_sl;
  double mod            = pos_sl == 0.0 ? m_max_sl * 0.5
                             : MathSqrt(m_ATR.Main(1) * MathAbs(height)) * bias;

  sl = NormalizeDouble(MathMin(base + direction * mod, priceOpen + m_max_sl),
                       m_symbol.Digits());
  tp = EMPTY_VALUE;

  return sl != EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Checking trailing stop and/or profit for long position.          |
//+------------------------------------------------------------------+
bool CTrailingATR::CheckTrailingStopLong(CPositionInfo *position,
                                         double &       sl,
                                         double &       tp) {
  return NewStopLoss(true, position, sl, tp);
}

//+------------------------------------------------------------------+
//| Checking trailing stop and/or profit for short position.         |
//+------------------------------------------------------------------+
bool CTrailingATR::CheckTrailingStopShort(CPositionInfo *position,
                                          double &       sl,
                                          double &       tp) {
  return NewStopLoss(false, position, sl, tp);
}
//+------------------------------------------------------------------+
