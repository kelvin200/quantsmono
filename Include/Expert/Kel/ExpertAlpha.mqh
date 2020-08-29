//+------------------------------------------------------------------+
//|                                           ExpertControllable.mqh |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
#include <Kel\MathExpression.mqh>

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
