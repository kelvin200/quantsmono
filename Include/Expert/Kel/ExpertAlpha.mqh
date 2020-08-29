//+------------------------------------------------------------------+
//|                                           ExpertControllable.mqh |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
#include <Generic\Queue.mqh>
#include <Generic\Stack.mqh>
#include <Strings\String.mqh>

//+------------------------------------------------------------------+
//| Class CExpertAlpha.                                              |
//| Purpose: Expert advisor giving more controls to users            |
//| Derives from class CExpert.                                      |
//+------------------------------------------------------------------+
class CExpertAlpha : public CExpert {
 private:
  CStack<string> *_alpha1_token;
  CStack<string> *_alpha1_val;
  CQueue<string> *_alpha1_func;

 protected:
  string m_alpha1;

 public:
  CExpertAlpha();
  ~CExpertAlpha();

  //--- methods of setting adjustable parameters
  virtual void Alpha1(string value);

  //  protected:
  //   virtual bool Processing();
};
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExpertAlpha::CExpertAlpha() : m_alpha1("") {}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CExpertAlpha::~CExpertAlpha() {}

int rank(char c) {
  switch (c) {
    case '+':
    case '-':
      return 1;
    case '*':
    case '/':
      return 2;
    default:
      return 0;
  }
}

void CExpertAlpha::Alpha1(string value) {
  m_alpha1      = value;
  _alpha1_token = new CStack<string>(100);
  _alpha1_val   = new CStack<string>(100);
  _alpha1_func  = new CQueue<string>(100);

  int l = StringLen(m_alpha1);
  for (int i = 0; i < l; ++i) {
    char c = m_alpha1[i];

    switch (c) {
      case '+':
      case '-':
      case '*':
      case '/':
        if (_alpha1_token.Count() > 0) {
          char p = _alpha1_token.Peek()[0];
          if (p != '(' && rank(p) > rank(c)) {
            // if new token is less rank, do the old token
            string t = _alpha1_token.Pop();
            string a = _alpha1_val.Pop();
            string b = _alpha1_val.Pop();
            if (b != "X") _alpha1_func.Enqueue(b);
            if (a != "X") _alpha1_func.Enqueue(a);
            _alpha1_func.Enqueue(t);
            _alpha1_val.Push("X");
          }
        }
        _alpha1_token.Push(StringSubstr(m_alpha1, i, 1));
        break;
      case '(':
        _alpha1_token.Push(StringSubstr(m_alpha1, i, 1));
        break;
      case ')': {
        string p = _alpha1_token.Pop();
        while (p != "(") {
          string a = _alpha1_val.Pop();
          string b = _alpha1_val.Pop();
          if (b != "X") _alpha1_func.Enqueue(b);
          if (a != "X") _alpha1_func.Enqueue(a);
          _alpha1_func.Enqueue(p);
          _alpha1_val.Push("X");
          p = _alpha1_token.Pop();
        }
        break;
      }
      case 'R':
      case 'C':
      case 'O':
      case 'H':
      case 'L':
      //  {
      //   int j = i;
      //   while (++i < l && m_alpha1[i] >= '0' && m_alpha1[i] <= '9')
      //     ;
      //   _alpha1_val.Push(StringSubstr(m_alpha1, j, i - j));
      //   break;
      // }
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9': {
        int j = i++;
        while (i < l && m_alpha1[i] >= '0' && m_alpha1[i] <= '9') ++i;
        _alpha1_val.Push(StringSubstr(m_alpha1, j, i - j));
        --i;
        break;
      }
      default:
        break;
    }
  }

  while (_alpha1_token.Count() > 0) {
    string p = _alpha1_token.Pop();
    string a = _alpha1_val.Pop();
    if (a != "X") _alpha1_func.Enqueue(a);
    _alpha1_func.Enqueue(p);
  }

  Print("TOK ", _alpha1_token.Log());
  Print("VAL ", _alpha1_val.Log());
  Print("FUNC ", _alpha1_func.Log());
  // Print(m_alpha1);
  // Print(_alpha1_func.Count());
  // Print(_alpha1_token.Count());
  // Print(_alpha1_val.Count());
  // while (_alpha1_val.Count() > 0) Print(_alpha1_val.Pop());
  // while (_alpha1_token.Count() > 0) Print(_alpha1_token.Pop());
  // while (_alpha1_func.Count() > 0) Print(_alpha1_func.Dequeue());
}

// bool CExpertAlpha::Processing() {
//   //--- calculate signal direction once
//   m_signal.SetDirection();
//   //--- check if open positions
//   if (SelectPosition()) {
//     //--- open position is available
//     //--- check the possibility of modifying the position
//     if (CheckTrailingStop()) return true;

//     return false;
//   }

//   //--- check if plased pending orders
//   int total = OrdersTotal();
//   if (total != 0) {
//     for (int i = total - 1; i >= 0; i--) {
//       m_order.SelectByIndex(i);
//       if (m_order.Symbol() != m_symbol.Name()) continue;
//       if (m_order.OrderType() == ORDER_TYPE_BUY_LIMIT ||
//           m_order.OrderType() == ORDER_TYPE_BUY_STOP) {
//         //--- check the ability to delete a pending order to buy
//         if (CheckDeleteOrderLong()) return true;
//         //--- check the possibility of modifying a pending order to buy
//         if (CheckTrailingOrderLong()) return true;
//       } else {
//         //--- check the ability to delete a pending order to sell
//         if (CheckDeleteOrderShort()) return true;
//         //--- check the possibility of modifying a pending order to sell
//         if (CheckTrailingOrderShort()) return true;
//       }
//       //--- return without operations
//       return false;
//     }
//   }
//   //--- check the possibility of opening a position/setting pending order
//   if (CheckOpen()) return true;
//   //--- return without operations
//   return false;
// }
