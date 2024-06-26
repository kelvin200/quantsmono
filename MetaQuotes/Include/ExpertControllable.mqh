//+------------------------------------------------------------------+
//|                                           ExpertControllable.mqh |
//|                   Copyright 2009-2017, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>

//+------------------------------------------------------------------+
//| Class CExpertControllable.                                       |
//| Purpose: Expert advisor giving more controls to users            |
//| Derives from class CExpert.                                      |
//+------------------------------------------------------------------+
class CExpertControllable : public CExpert {
 protected:
  bool m_auto_close_positions;  // Allow expert to close positions

 public:
  CExpertControllable();
  ~CExpertControllable();

  //--- methods of setting adjustable parameters
  void AutoClosePositions(bool value) { m_auto_close_positions = value; }

 protected:
//   virtual bool Processing();
};
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExpertControllable::CExpertControllable() : m_auto_close_positions(false) {}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CExpertControllable::~CExpertControllable() {}

// bool CExpertControllable::Processing() {
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
