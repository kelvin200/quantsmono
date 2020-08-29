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
    case '|':
      return 6;
    default:
      return 0;
  }
}

void addValToFunc(string a, CQueue<string> *func) {
  if (a != "X") func.Enqueue(a);
}

void moveOperator(string op, CStack<string> &tok, CStack<string> &val, CQueue<string> *func) {
  string a         = val.Pop();
  bool   negWithOp = op == "|" && (tok.Count() > 0 && tok.Peek() != "(");
  if (op != "|" || negWithOp) addValToFunc(val.Pop(), func);
  addValToFunc(a, func);
  func.Enqueue(op);
  if (negWithOp) func.Enqueue(tok.Pop());
  val.Push("X");
}

void parseExp(string value, string &alpha, CQueue<string> *&func) {
  alpha = value;
  func  = new CQueue<string>(100);

  if (value == "") return;

  CStack<string> tok(100);
  CStack<string> val(100);

  StringReplace(alpha, " ", "");
  // Print("T ", alpha);

  int l = StringLen(alpha);
  for (int i = 0; i < l; ++i) {
    char   c  = alpha[i];
    string cs = StringSubstr(alpha, i, 1);

    switch (c) {
      case '+':
        if (i == 0 || alpha[i - 1] == '+' || alpha[i - 1] == '-' || alpha[i - 1] == '*' || alpha[i - 1] == '/' ||
            alpha[i - 1] == '(')
          continue;
      case '-':
        if (i == 0 || alpha[i - 1] == '+' || alpha[i - 1] == '-' || alpha[i - 1] == '*' || alpha[i - 1] == '/' ||
            alpha[i - 1] == '(') {
          cs = "|";
          c  = '|';
        }
      case '*':
      case '/':
        if (tok.Count() > 0) {
          char p = tok.Peek()[0];
          if (p != '(' && rank(p) > rank(c)) {
            string t = tok.Pop();
            moveOperator(t, tok, val, func);
          }
        }
      case '(':
        tok.Push(cs);
        break;
      case ')': {
        string t = tok.Pop();
        while (t != "(") {
          moveOperator(t, tok, val, func);
          t = tok.Pop();
        }
        break;
      }
      case 'R':
      case 'C':
      case 'O':
      case 'H':
      case 'L':
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
        while (i < l && alpha[i] >= '0' && alpha[i] <= '9') ++i;
        val.Push(StringSubstr(alpha, j, i - j));
        --i;
        break;
      }
      default:
        break;
    }
  }

  while (tok.Count() > 0) {
    addValToFunc(val.Pop(), func);
    func.Enqueue(tok.Pop());
  }

  // Print("TOK ", tok.Log());
  // Print("VAL ", val.Log());
  // Print("FUNC ", func.Log());
}

void CExpertAlpha::Alpha1(string value) { parseExp(value, m_alpha1, _alpha1_func); }

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
