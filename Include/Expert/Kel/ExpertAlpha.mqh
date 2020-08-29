//+------------------------------------------------------------------+
//|                                           ExpertControllable.mqh |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
#include <Generic\ArrayList.mqh>
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
  CArrayList<string> *_func;
  double              _thresold;
  double              _sl;
  double              _tp;

 public:
  CExpertAlpha();
  ~CExpertAlpha();
  void Thresold(string value) { _thresold = value; }
  void StopLoss(string value) { _sl = value; }
  void TakeProfit(string value) { _tp = value; }

  virtual void Alpha(string value);

 protected:
  double Return(int i) { return Close(1) - Close(i); }

  virtual bool   Processing();
  virtual bool   CheckOpen();
  virtual double CalculateAlpha();
};

CExpertAlpha::CExpertAlpha() : _thresold(0), _sl(0.01), _tp(0.01) {
  m_used_series = USE_SERIES_TIME | USE_SERIES_OPEN | USE_SERIES_CLOSE | USE_SERIES_HIGH | USE_SERIES_LOW;
}

CExpertAlpha::~CExpertAlpha() {}

void CExpertAlpha::Alpha(string value) { ParseExp(value, _func); }

bool CExpertAlpha::Processing() {
  if (CheckOpen()) return true;
  return false;
}

bool CExpertAlpha::CheckOpen() {
  // Calculate alpha
  double a = MathRound(CalculateAlpha(), 2);

  Print("Alpha ", a);
  double ask = m_symbol.Ask();
  double bid = m_symbol.Bid();

  if (a > _thresold) {
    return m_trade.Buy(a, ask, ask - _sl, ask + _tp);
  }

  if (a < -_thresold) {
    return m_trade.Sell(-a, bid, bid + _sl, bid - _tp);
  }

  return false;
}

double CExpertAlpha::CalculateAlpha() {
  int c = _func.Count();

  if (c == 0) return 0.0;

  CStack<double> _resolved(c);

  for (int i = 0; i < c; ++i) {
    string s;
    _func.TryGetValue(i, s);

    if (s[0] >= 'A' && s[0] <= 'Z') {
      int l  = StringLen(s);
      int id = l == 1 ? 0 : StringToInteger(StringSubstr(s, 1, l - 1));
      switch (s[0]) {
        case 'R':
          _resolved.Add(Return(id));
          break;
        case 'C':
          _resolved.Add(Close(id));
          break;
        case 'O':
          _resolved.Add(Open(id));
          break;
        case 'H':
          _resolved.Add(High(id));
          break;
        case 'L':
          _resolved.Add(Low(id));
          break;
        default:
          break;
      }
      continue;
    }

    if (s[0] >= '0' && s[0] <= '9') {
      // Number
      _resolved.Add(StringToDouble(s));
      continue;
    }

    if (s[0] == '|') {
      // Negative sign
      _resolved.Add(-_resolved.Pop());
      continue;
    }

    // Operators
    double a = _resolved.Pop();
    double b = _resolved.Pop();

    switch (s[0]) {
      case '+':
        _resolved.Add(b + a);
        break;
      case '-':
        _resolved.Add(b - a);
        break;
      case '*':
        _resolved.Add(b * a);
        break;
      case '/':
        _resolved.Add(b / a);
        break;
      default:
        break;
    }
  }

  return _resolved.Pop();
}
