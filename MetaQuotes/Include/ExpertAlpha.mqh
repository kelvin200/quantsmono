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
 private:
  int handlerATR;
  int handlerATRSlow;
  int m_long;
  int m_short;

 protected:
  int                 m_atr_range;
  int                 m_atr_range_slow;
  CArrayList<string> *m_func;
  double              m_adjustment;
  double              m_thresold;
  double              m_thresold_top;
  double              m_sl;
  double              m_tp;
  bool                m_trailing;
  bool                m_alpha_lot;
  int                 m_4;
  int                 m_24;
  int                 m_48;
  int                 m_120;
  int                 m_480;

 public:
  CExpertAlpha();
  ~CExpertAlpha();
  void Adjustment(double v) { m_adjustment = v; }
  void Thresold(double v) { m_thresold = v; }
  void ThresoldTop(double v) { m_thresold_top = v; }
  void StopLoss(double v) { m_sl = v; }
  void TakeProfit(double v) { m_tp = v; }
  void Range(int v) { m_atr_range = v; }
  void RangeSlow(int v) { m_atr_range_slow = v; }
  void Trailing(bool v) { m_trailing = v; }
  void AlphaLot(bool v) { m_alpha_lot = v; }
  void M_4(bool v) { m_4 = v; }
  void M_24(bool v) { m_24 = v; }
  void M_48(bool v) { m_48 = v; }
  void M_120(bool v) { m_120 = v; }
  void M_480(bool v) { m_480 = v; }

  virtual void Alpha(string value);
  virtual bool MyIn();

 protected:
  double Return(int i) { return Open(1) / Open(i) - 1.0; }
  double Height(int i) { return m_close.GetData(i) - m_open.GetData(i); }
  double ClosePip(int i) { return m_close.GetData(i) / m_symbol.TickSize(); }
  double OpenPip(int i) { return Open(i) / m_symbol.TickSize(); }
  double HighPip(int i) { return High(i) / m_symbol.TickSize(); }
  double LowPip(int i) { return Low(i) / m_symbol.TickSize(); }
  double ReturnPip(int i) { return Return(i) / m_symbol.TickSize(); }
  double Long(int i) { return m_long; }
  double Short(int i) { return m_short; }
  double Atr(int hlr, int i) {
    double atr[1];
    if (CopyBuffer(hlr, 0, i, 1, atr) != 1) {
      Print("CopyBuffer from iATR failed, no data");
      return false;
    }
    return atr[0];
  }

  virtual bool   Processing();
  virtual bool   CheckOpenBS(int b, int s);
  virtual double CalculateAlpha();
  virtual double CalculateAlpha2();
};

CExpertAlpha::CExpertAlpha()
    : handlerATR(0),
      m_trailing(false),
      m_atr_range(12),
      m_atr_range_slow(120),
      m_adjustment(1),
      m_thresold(0),
      m_thresold_top(0),
      m_sl(1),
      m_tp(1),
      m_alpha_lot(true) {
  m_used_series = USE_SERIES_TIME | USE_SERIES_OPEN | USE_SERIES_CLOSE | USE_SERIES_HIGH | USE_SERIES_LOW;
}

CExpertAlpha::~CExpertAlpha() {}

void CExpertAlpha::Alpha(string value) { ParseExp(value, m_func); }

bool CExpertAlpha::MyIn() {
  handlerATR     = iATR(m_symbol.Name(), m_period, m_atr_range);
  handlerATRSlow = iATR(m_symbol.Name(), m_period, m_atr_range_slow);

  if (handlerATR == INVALID_HANDLE || handlerATRSlow == INVALID_HANDLE) {
    printf("Error creating ATR indicator");
    return false;
  }

  return true;
}

bool CExpertAlpha::Processing() {
  int b = 0;
  int s = 0;
  if (m_trailing) {
    int t = PositionsTotal();
    for (int i = 0; i < t; ++i) {
      string symbol = PositionGetSymbol(i);

      if (_Symbol != symbol) continue;

      ulong ticket = PositionGetTicket(i);

      m_position.SelectByTicket(ticket);

      CheckTrailingStop();
    }
  }

  if (CheckOpenBS(b, s)) return true;
  return false;
}

bool CExpertAlpha::CheckOpenBS(int b, int s) {
  // Calculate alpha
  // double a = CalculateAlpha();
  double a = CalculateAlpha2();
  double l = m_alpha_lot ? MathAbs(MathRound(a * m_adjustment, 2)) : 0.01;
  // double l2 = m_alpha_lot ? MathAbs(MathRound(a * m_adjustment, 2)) : 0.01;

  Print("Alpha ", a);

  if (l >= 0.01 && MathAbs(a) <= m_thresold_top) {
    double atr = Atr(handlerATRSlow, 1);
    double ask = m_symbol.Ask();
    double bid = m_symbol.Bid();
    double sl  = atr * m_sl;
    double tp  = atr * m_tp;

    // if (a > m_thresold_top)
    //   return m_trade.Sell(l2, bid, bid - sl, bid + tp);
    // else if (a > m_thresold)
    //   return m_trade.Buy(l, ask, ask - sl, ask + tp);
    // else if (a < -m_thresold_top)
    //   return m_trade.Buy(l2, ask, ask + sl, ask - tp);
    // else if (a < -m_thresold)
    //   return m_trade.Sell(l, bid, bid + sl, bid - tp);

    if (a > m_thresold) return m_trade.Buy(l, ask, ask - sl, ask + tp);
    if (a < -m_thresold) return m_trade.Sell(l, bid, bid + sl, bid - tp);
  }
  return false;
}

double CExpertAlpha::CalculateAlpha2() {
  return Return(4) * m_4 + Return(24) * m_24 + Return(48) * m_48 + Return(120) * m_120 + Return(480) * m_480;
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
