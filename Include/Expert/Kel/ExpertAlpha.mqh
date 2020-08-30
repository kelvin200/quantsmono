//+------------------------------------------------------------------+
//|                                           ExpertControllable.mqh |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
#include <Generic\ArrayList.mqh>
#include <Indicators\Oscilators.mqh>
#include <Kel\MathExpression.mqh>
#include <Math\Stat\Math.mqh>
#include <Strings\String.mqh>

//+------------------------------------------------------------------+
//| Class CExpertAlpha.                                              |
//| Purpose: Expert advisor giving more controls to users            |
//| Derives from class CExpert.                                      |
//+------------------------------------------------------------------+
class CExpertAlpha : public CExpert {
 protected:
  int                 handlerATR;
  CiATR *             m_ATR;
  int                 m_atr_range;
  CArrayList<string> *m_func;
  double              m_adjustment;
  double              m_thresold;
  double              m_sl;
  double              m_tp;

 public:
  CExpertAlpha();
  ~CExpertAlpha();
  void Adjustment(double value) { m_adjustment = value; }
  void Thresold(double value) { m_thresold = value; }
  void StopLoss(double value) { m_sl = value; }
  void TakeProfit(double value) { m_tp = value; }
  void Range(int range) { m_atr_range = range; }

  virtual void Alpha(string value);
  virtual bool MyIn();

 protected:
  double Return(int i) { return m_close.GetData(1) / m_close.GetData(i) - 1.0; }
  double ClosePip(int i) { return m_close.GetData(i) / m_symbol.TickSize(); }
  double OpenPip(int i) { return Open(i) / m_symbol.TickSize(); }
  double HighPip(int i) { return High(i) / m_symbol.TickSize(); }
  double LowPip(int i) { return Low(i) / m_symbol.TickSize(); }
  double ReturnPip(int i) { return Return(i) / m_symbol.TickSize(); }

  virtual bool   Processing();
  virtual bool   CheckOpen();
  virtual double CalculateAlpha();
};

CExpertAlpha::CExpertAlpha()
    : handlerATR(0), m_ATR(NULL), m_atr_range(9), m_adjustment(1), m_thresold(0), m_sl(1), m_tp(1) {
  m_used_series = USE_SERIES_TIME | USE_SERIES_OPEN | USE_SERIES_CLOSE | USE_SERIES_HIGH | USE_SERIES_LOW;
}

CExpertAlpha::~CExpertAlpha() {}

void CExpertAlpha::Alpha(string value) { ParseExp(value, m_func); }

bool CExpertAlpha::MyIn() {
  handlerATR = iATR(m_symbol.Name(), m_period, m_atr_range);

  if (handlerATR == INVALID_HANDLE) {
    printf("Error creating ATR indicator");
    return false;
  }

  return true;
  // //--- create ATR indicator
  // if (m_ATR == NULL)
  //   if ((m_ATR = new CiATR) == NULL) {
  //     printf(__FUNCTION__ + ": error creating object");
  //     return false;
  //   }
  // //--- initialize ATR indicator
  // if (!m_ATR.Create(m_symbol.Name(), m_period, m_atr_range)) {
  //   printf(__FUNCTION__ + ": error initializing object");
  //   return false;
  // }
  // m_ATR.BufferResize(2);
  // //--- ok
  // return true;
}

bool CExpertAlpha::Processing() {
  if (CheckOpen()) return true;
  return false;
}

bool CExpertAlpha::CheckOpen() {
  // Calculate alpha
  double a = MathRound(CalculateAlpha() * m_adjustment, 2);

  // Print("Alpha ", a);
  double ask = m_symbol.Ask();
  double bid = m_symbol.Bid();

  double atr[1];
  if (CopyBuffer(handlerATR, 0, 1, 1, atr) != 1) {
    Print("CopyBuffer from iATR failed, no data");
    return false;
  }

  double sl = atr[0] * m_sl;
  double tp = atr[0] * m_tp;

  if (a > m_thresold) {
    return m_trade.Buy(a, ask, ask - sl, ask + tp);
  }

  if (a < -m_thresold) {
    return m_trade.Sell(-a, bid, bid + sl, bid - tp);
  }

  return false;
}

double CExpertAlpha::CalculateAlpha() {
  int c = m_func.Count();

  if (c == 0) return 0.0;

  CStack<double> m_resolved(c);

  for (int i = 0; i < c; ++i) {
    string s;
    m_func.TryGetValue(i, s);

    if (s[0] >= 'A' && s[0] <= 'Z') {
      int l  = StringLen(s);
      int id = l == 1 ? 0 : StringToInteger(StringSubstr(s, 1, l - 1));
      switch (s[0]) {
        case 'R':
          m_resolved.Add(Return(id));
          break;
        case 'C':
          m_resolved.Add(m_close.GetData(i));
          break;
        case 'O':
          m_resolved.Add(Open(id));
          break;
        case 'H':
          m_resolved.Add(High(id));
          break;
        case 'L':
          m_resolved.Add(Low(id));
          break;
        // case 'R':
        //   m_resolved.Add(ReturnPip(id));
        //   break;
        // case 'C':
        //   m_resolved.Add(ClosePip(id));
        //   break;
        // case 'O':
        //   m_resolved.Add(OpenPip(id));
        //   break;
        // case 'H':
        //   m_resolved.Add(HighPip(id));
        //   break;
        // case 'L':
        //   m_resolved.Add(LowPip(id));
        //   break;
        default:
          break;
      }
      continue;
    }

    if (s[0] >= '0' && s[0] <= '9') {
      // Number
      m_resolved.Add(StringToDouble(s));
      continue;
    }

    if (s[0] == '|') {
      // Negative sign
      m_resolved.Add(-m_resolved.Pop());
      continue;
    }

    // Operators
    double a = m_resolved.Pop();
    double b = m_resolved.Pop();

    switch (s[0]) {
      case '+':
        m_resolved.Add(b + a);
        break;
      case '-':
        m_resolved.Add(b - a);
        break;
      case '*':
        m_resolved.Add(b * a);
        break;
      case '/':
        m_resolved.Add(b / a);
        break;
      default:
        break;
    }
  }

  return m_resolved.Pop();
}
