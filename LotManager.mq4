//+------------------------------------------------------------------+
//|                                                   LotManager.mq4 |
//|                                                       Yuta Miura |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Yuta Miura"
#property link      "https://www.mql5.com"
#property version   "2.30"
#property strict

#include <stdlib.mqh>  //Error ErrorDescription

enum BalanceType
  {
   account_balance, //Account Balance
   account_equity, //Account Equity
  };

extern BalanceType b_type = account_balance; //Balance Type
extern double risk = 1.00; //Risk (%)
extern int max_spread = 20; //Max Spread (Points)
extern int max_slippage = 20; // Max slippage (Points)
extern int magic_number = 99999; //Magic Number

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int    chart_id = 0;
string sl_line = "SL-hline";
string tp_line = "TP-hline";
string lo_line = "LO-hline";
string trade_button = "trade-button";
string tp_button = "TP-button";
string lo_button = "limit-order-button";
string hide_button = "hide-button";
string lot_size_label = "lot-size-label";
string risk_reward_label = "risk-reward-label";
double risk_reward_ratio = 0.00;
double sl_price = Ask;
double tp_price = 0;
double lo_price = Ask;
double lot = 0;
double balance = 0;
bool TPstatus = false;
bool LOstatus = false;
int price_decimal_digits = (int)MarketInfo(Symbol(),MODE_DIGITS);
double lastCalculatedPrice = 0.0;
int priceChangeThresholdInPips = 5; //Pips

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getChartCenterPrice()
  {
   int      window_no;
   datetime get_time;
   double   get_price;

   int chart_width = ChartGetInteger(chart_id, CHART_WIDTH_IN_PIXELS, 0);
   int chart_height = ChartGetInteger(chart_id, CHART_HEIGHT_IN_PIXELS, 0);                                              // オブジェクト全削除
   ChartXYToTimePrice(chart_id,chart_width,chart_height/2,window_no,get_time,get_price);
   return get_price;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class LineCreator
  {
private:
   int               chart_id;

public:
                     LineCreator(int _chart_id)
     {
      chart_id = _chart_id;
     }

   void              createLine(string line_id, color line_color, string line_text)
     {
      ObjectCreate(chart_id, line_id, OBJ_HLINE, 0, 0, getChartCenterPrice());

      ObjectSetInteger(chart_id, line_id, OBJPROP_COLOR, line_color);
      ObjectSetInteger(chart_id, line_id, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(chart_id, line_id, OBJPROP_WIDTH, 2);
      ObjectSetInteger(chart_id, line_id, OBJPROP_BACK, false);
      ObjectSetInteger(chart_id, line_id, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(chart_id, line_id, OBJPROP_SELECTED, true);
      ObjectSetInteger(chart_id, line_id, OBJPROP_HIDDEN, true);
      ObjectSetInteger(chart_id, line_id, OBJPROP_ZORDER, 0);
      ObjectSetText(line_id, line_text, 8, "Roboto", line_color);
     }

   void              createSLLine()
     {
      createLine(sl_line, clrRed, "SL");
     }

   void              createTPLine()
     {
      createLine(tp_line, clrBlue, "TP");
     }

   void              createLOLine()
     {
      createLine(lo_line, clrViolet, "LO");
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class LabelCreator
  {
public:
   void              createRiskRewardLabel()
     {
      createLabel(risk_reward_label, "RR: ", 160);
     }

   void              createLotSizeLabel()
     {
      createLabel(lot_size_label, "Lot: " + DoubleToString(lot, 2), 130);
     }

private:
   void              createLabel(string label_id, string label_text, int y_distance)
     {
      ObjectCreate(chart_id, label_id, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(chart_id, label_id, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(chart_id, label_id, OBJPROP_BACK, false);
      ObjectSetInteger(chart_id, label_id, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chart_id, label_id, OBJPROP_SELECTED, false);
      ObjectSetInteger(chart_id, label_id, OBJPROP_HIDDEN, true);
      ObjectSetInteger(chart_id, label_id, OBJPROP_ZORDER, 0);

      ObjectSetString(chart_id, label_id, OBJPROP_TEXT, label_text);
      ObjectSetString(chart_id, label_id, OBJPROP_FONT, "Roboto");
      ObjectSetInteger(chart_id, label_id, OBJPROP_FONTSIZE, 14);
      ObjectSetInteger(chart_id, label_id, OBJPROP_CORNER, CORNER_RIGHT_LOWER);

      ObjectSetInteger(chart_id, label_id, OBJPROP_XDISTANCE, 160);
      ObjectSetInteger(chart_id, label_id, OBJPROP_YDISTANCE, y_distance);
      ObjectSetInteger(chart_id, label_id, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ButtonCreator
  {
public:
   void              createTradeButton()
     {
      createButton(trade_button, "TRADE", clrRed, 160, 80, 150, 30);
     }

   void              createTPButton()
     {
      createButton(tp_button, "TP", clrBlue, 80, 120, 70, 30);
     }

   void              createLOButton()
     {
      createButton(lo_button, "Limit Order", clrViolet, 160, 120, 70, 30);
     }

   void              createHideButton()
     {
      createButton(hide_button, "HIDE", clrGreen, 160, 40, 150, 30);
     }

private:
   void              createButton(string button_id, string button_text, color button_color, int x_distance, int y_distance, int x_size, int y_size)
     {
      ObjectCreate(chart_id,button_id,OBJ_BUTTON,0,0,0);

      ObjectSetInteger(chart_id,button_id,OBJPROP_COLOR,clrWhite);
      ObjectSetInteger(chart_id,button_id,OBJPROP_BACK,false);
      ObjectSetInteger(chart_id,button_id,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(chart_id,button_id,OBJPROP_SELECTED,false);
      ObjectSetInteger(chart_id,button_id,OBJPROP_HIDDEN,true);
      ObjectSetInteger(chart_id,button_id,OBJPROP_ZORDER,0);

      ObjectSetString(chart_id,button_id,OBJPROP_TEXT,button_text);
      ObjectSetString(chart_id,button_id,OBJPROP_FONT,"Roboto");
      ObjectSetInteger(chart_id,button_id,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(chart_id,button_id,OBJPROP_CORNER,CORNER_RIGHT_LOWER);

      ObjectSetInteger(chart_id,button_id,OBJPROP_XDISTANCE,x_distance);
      ObjectSetInteger(chart_id,button_id,OBJPROP_YDISTANCE,y_distance);
      ObjectSetInteger(chart_id,button_id,OBJPROP_XSIZE,x_size);
      ObjectSetInteger(chart_id,button_id,OBJPROP_YSIZE,y_size);

      ObjectSetInteger(chart_id,button_id,OBJPROP_BGCOLOR,button_color);
      ObjectSetInteger(chart_id,button_id,OBJPROP_STATE,false);
     }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateLotSize()
  {
   double criterion_price = LOstatus ? ObjectGetDouble(0, lo_line, OBJPROP_PRICE, 0) : Ask;
   double SL = MathAbs(sl_price - criterion_price);
   double SL_pips = SL / Point;

// We get the value of a tick.
   double nTickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(b_type == 0)
     {
      balance = AccountBalance();
     }
   else
     {
      balance = AccountEquity();
     }
// We apply the formula to calculate the position size and assign the value to the variable.
   double lot_size = (balance * risk / 100) / (SL_pips * nTickValue);
   lot_size = NormalizeDouble(lot_size, MarketInfo(Symbol(), MODE_DIGITS));

// Fetch the minimum, maximum and step volume for the symbol
   double minVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double stepVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

// Make sure the calculated lot_size is within the valid range
   if(lot_size < minVolume)
      lot_size = minVolume;
   if(lot_size > maxVolume)
      lot_size = maxVolume;

   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   int digits = -(int)MathRound(MathLog(lotStep) / MathLog(10.0));



// Make sure the lot_size is a multiple of stepVolume
   lot_size = NormalizeDouble(MathRound(lot_size / stepVolume) * stepVolume, digits);

   return lot_size;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool spreadFilter()
  {
   int spread = MarketInfo(Symbol(), MODE_SPREAD);
   return spread < max_spread;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void executeOrder()
  {
   for(int order_resend_num = 0; order_resend_num < 10; order_resend_num++)
     {
      int ea_ticket_res = 0;

      if(spreadFilter())
        {
         lot = calculateLotSize();
         if(!LOstatus)
           {
            if(Ask - sl_price > 0)
              {
               ea_ticket_res = OrderSend(
                                  Symbol(),
                                  OP_BUY,
                                  lot,
                                  Ask,
                                  max_slippage,
                                  0,
                                  0,
                                  "LotManager: BUY",
                                  magic_number,
                                  0,
                                  clrNONE
                               );
              }
            else
               if(Bid - sl_price < 0)
                 {
                  ea_ticket_res = OrderSend(
                                     Symbol(),
                                     OP_SELL,
                                     lot,
                                     Bid,
                                     max_slippage,
                                     0,
                                     0,
                                     "LotManager: SELL",
                                     magic_number,
                                     0,
                                     clrNONE
                                  );
                 }
               else
                 {
                  MessageBox("Stop Limit too close", "Order Failed", MB_OK);
                 }
           }
         if(LOstatus)
           {


            //int buy_order_type = lo_price > Ask ? OP_BUYSTOP : OP_BUYLIMIT;
            //int sell_order_type = lo_price < Bid ? OP_SELLSTOP : OP_SELLLIMIT;


            if(lo_price - sl_price > 0)
              {
               ea_ticket_res = OrderSend(
                                  Symbol(),
                                  lo_price > Ask ? OP_BUYSTOP : OP_BUYLIMIT,
                                  lot,
                                  NormalizeDouble(lo_price, price_decimal_digits),
                                  max_slippage,
                                  NormalizeDouble(sl_price, price_decimal_digits),
                                  NormalizeDouble(tp_price, price_decimal_digits),
                                  "LotManager: BUY",
                                  magic_number,
                                  0,
                                  clrNONE
                               );
              }
            else
               if(lo_price - sl_price < 0)
                 {
                  ea_ticket_res = OrderSend(
                                     Symbol(),
                                     lo_price < Bid ? OP_SELLSTOP : OP_SELLLIMIT,
                                     lot,
                                     NormalizeDouble(lo_price, price_decimal_digits),
                                     max_slippage,
                                     NormalizeDouble(sl_price, price_decimal_digits),
                                     NormalizeDouble(tp_price, price_decimal_digits),
                                     "LotManager: SELL",
                                     magic_number,
                                     0,
                                     clrNONE
                                  );
                 }
               else
                 {
                  MessageBox("Stop Limit too close", "Order Failed", MB_OK);
                 }


           }
        }


      if(ea_ticket_res == -1 || !spreadFilter())
        {
         int errorcode = GetLastError();
         if(!spreadFilter())
           {
            printf("errorcode:%d, details:Spread too high", errorcode);
           }

         if(errorcode != ERR_NO_ERROR)
           {
            printf("errorcode:%d, details:%s", errorcode, ErrorDescription(errorcode));

            if(errorcode == ERR_TRADE_NOT_ALLOWED)
              {
               MessageBox(ErrorDescription(errorcode), "Autotrade Disabled", MB_ICONEXCLAMATION);
               return;
              }
           }

         while(!IsTradeContextBusy() && !OrderSelect(ea_ticket_res, SELECT_BY_TICKET))
           {
            Sleep(10);
           }

         if(OrderSelect(ea_ticket_res, SELECT_BY_TICKET))
           {
            if(OrderCloseTime() > 0)
              {
               break; // Order has been closed, break from the loop
              }
            else
              {
               continue; // Order is still open, continue waiting
              }
           }

         RefreshRates();
         printf("Re-entry count: %d", order_resend_num + 1);
        }
      else
        {
         Print("Order Complete Ticket No: " + IntegerToString(ea_ticket_res));
         Sleep(300); // Avoid order error

         bool modify_ret;
         int errorcode;
         if(!LOstatus)
           {
            for(int modify_resend_num = 0; modify_resend_num < 20; modify_resend_num++)
              {
               if(tp_price == 0)
                 {
                  modify_ret = OrderModify(ea_ticket_res, OrderOpenPrice(), NormalizeDouble(sl_price, price_decimal_digits), 0, 0, clrGreen);
                 }
               else
                 {
                  modify_ret = OrderModify(ea_ticket_res, OrderOpenPrice(), NormalizeDouble(sl_price, price_decimal_digits), NormalizeDouble(tp_price, price_decimal_digits), 0, clrGreen);
                 }

               if(modify_ret == false)
                 {
                  Sleep(300);
                  errorcode = GetLastError();
                  printf("Order modify count: %d, errorcode: %d, details: %s", modify_resend_num + 1, errorcode, ErrorDescription(errorcode));
                 }
               else
                 {
                  Print("Order Modify Complete Ticket No: " + IntegerToString(ea_ticket_res));
                  break; // Break from the order modify loop
                 }
              }
           }

         break; // Break from the order loop
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculateRiskReward()
  {
   double criterion_price = LOstatus ? ObjectGetDouble(0, lo_line, OBJPROP_PRICE, 0) : Ask;
   if((criterion_price - sl_price > 0 && criterion_price - tp_price < 0) || (criterion_price - sl_price < 0 && criterion_price - tp_price > 0))
     {
      double SL = MathAbs(sl_price - criterion_price);
      double TP = MathAbs(tp_price - criterion_price);
      risk_reward_ratio = TP / SL;
     }
   else
     {
      risk_reward_ratio = 0.00;
     }
   return risk_reward_ratio;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setTPstatus(bool state)
  {
   TPstatus = state;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setLOstatus(bool state)
  {
   LOstatus = state;
  }




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
LineCreator linecreator(0);
ButtonCreator buttoncreator;
LabelCreator labelcreator;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
  {



   ObjectsDeleteAll();

   linecreator.createSLLine();
   buttoncreator.createTradeButton();
   buttoncreator.createTPButton();
   buttoncreator.createLOButton();
   buttoncreator.createHideButton();

   if(b_type == 0)
     {
      balance = AccountBalance();
     }
   else
     {
      balance = AccountEquity();
     }
   sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
   labelcreator.createLotSizeLabel();
   lot = calculateLotSize();
   ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));

  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   ObjectsDeleteAll();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
// Calculate price difference from the last calculated price
   double currentPrice = LOstatus ? ObjectGetDouble(0, lo_line, OBJPROP_PRICE, 0) : Ask;
   double priceDifference = MathAbs(currentPrice - lastCalculatedPrice);

// Get the price change threshold in terms of price, not pips
   double priceChangeThreshold = priceChangeThresholdInPips * MarketInfo(Symbol(), MODE_POINT);

// If the price difference is greater than the threshold, recalculate
   if(priceDifference >= priceChangeThreshold)
     {
      sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
      //lo_price = ObjectGetDouble(0,lo_line,OBJPROP_PRICE,0);
      lot = calculateLotSize();
      if(TPstatus)
        {
         tp_price = ObjectGetDouble(0,tp_line,OBJPROP_PRICE,0);
         risk_reward_ratio = calculateRiskReward();
        }
      ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
      ObjectSetString(chart_id, risk_reward_label, OBJPROP_TEXT, "RR: " + DoubleToString(risk_reward_ratio, 2));

      // Update the last calculated price
      lastCalculatedPrice = currentPrice;
     }

  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| event function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(
   const int     id,      // イベントID
   const long&   lparam,  // long型イベント
   const double& dparam,  // double型イベント
   const string& sparam)  // string型イベント
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == hide_button)
        {
         if(ObjectGetInteger(chart_id, hide_button, OBJPROP_STATE))
           {
            ObjectSetString(chart_id,hide_button,OBJPROP_TEXT,"SHOW");
            //ObjectSetInteger(chart_id,sl_line,OBJPROP_COLOR,clrNONE);
            ObjectDelete(chart_id, sl_line);
            ObjectDelete(chart_id, tp_line);
            ObjectDelete(chart_id, lo_line);
            ObjectDelete(chart_id, risk_reward_label);
            ObjectDelete(chart_id, lot_size_label);

            ObjectSetInteger(chart_id,tp_button,OBJPROP_STATE,false);
            ObjectDelete(chart_id, tp_button);
            ObjectDelete(chart_id, trade_button);
            ObjectDelete(chart_id, lo_button);
            tp_price = 0;

           }
         else
           {
            ObjectSetString(chart_id,hide_button,OBJPROP_TEXT,"HIDE");
            //ObjectSetInteger(chart_id,sl_line,OBJPROP_COLOR,clrYellow);
            linecreator.createSLLine();
            labelcreator.createLotSizeLabel();
            buttoncreator.createTPButton();
            buttoncreator.createTradeButton();
            buttoncreator.createLOButton();
            sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
            lot = calculateLotSize();
            ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
           }
        }
      if(sparam == tp_button)
        {
         if(ObjectGetInteger(chart_id, tp_button, OBJPROP_STATE))
           {
            linecreator.createTPLine();
            tp_price = ObjectGetDouble(0,tp_line,OBJPROP_PRICE,0);
            sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
            risk_reward_ratio = calculateRiskReward();
            labelcreator.createRiskRewardLabel();
            ObjectSetString(chart_id, risk_reward_label, OBJPROP_TEXT, "RR: " + DoubleToString(risk_reward_ratio, 2));
            setTPstatus(true);

           }
         else
           {
            ObjectDelete(chart_id, tp_line);
            ObjectDelete(chart_id, risk_reward_label);
            tp_price = 0;
            setTPstatus(false);

           }
        }
      if(sparam == trade_button)
        {
         double criterion_price = LOstatus ? ObjectGetDouble(0, lo_line, OBJPROP_PRICE, 0) : Ask;
         if(TPstatus)
           {
            if((criterion_price - sl_price > 0 && criterion_price - tp_price < 0) || (criterion_price - sl_price < 0 && criterion_price - tp_price > 0))
              {
               executeOrder();
              }
            else
              {
               MessageBox("Order Faild Invalid TP","Order Faild",MB_OK);
               return;
              }
           }
         else
           {
            executeOrder();
           }
         ObjectSetInteger(chart_id,trade_button,OBJPROP_STATE,false);

        }
      if(sparam == lo_button)
        {
         if(ObjectGetInteger(chart_id, lo_button, OBJPROP_STATE))
           {
            linecreator.createLOLine();
            lo_price = ObjectGetDouble(0,lo_line,OBJPROP_PRICE,0);
            tp_price = ObjectGetDouble(0,tp_line,OBJPROP_PRICE,0);
            sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
            lot = calculateLotSize();
            ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
            setLOstatus(true);

           }
         else
           {
            ObjectDelete(chart_id, lo_line);
            setLOstatus(false);
            sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
            lot = calculateLotSize();
            ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));

           }
        }


     }
   if(id == CHARTEVENT_OBJECT_DRAG)
     {
      if(sparam == sl_line)
        {
         sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
         lot = calculateLotSize();
         ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
         //Print(lot);
        }
      if(sparam == tp_line)
        {
         tp_price = ObjectGetDouble(0,tp_line,OBJPROP_PRICE,0);

         //Print(tp_price);
        }
      if(sparam == lo_line)
        {
         lo_price = ObjectGetDouble(0,lo_line,OBJPROP_PRICE,0);
         lot = calculateLotSize();
         ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
        }
      risk_reward_ratio = calculateRiskReward();
      ObjectSetString(chart_id, risk_reward_label, OBJPROP_TEXT, "RR: " + DoubleToString(risk_reward_ratio, 2));
     }

  }
//+------------------------------------------------------------------+
