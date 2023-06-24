//+------------------------------------------------------------------+
//|                                                   LotManager.mq4 |
//|                                                       Yuta Miura |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Yuta Miura"
#property link      "https://www.mql5.com"
#property version   "1.10"
#property strict

#include <stdlib.mqh>  //Error ErrorDescription

enum BalanceType {
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
string trade_button = "trade-button";
string tp_button = "TP-button";
string hide_button = "hide-button";
string lot_size_label = "Lot-size";
string risk_reward_label = "risk-reward";
double risk_reward_ratio = 0.00;
double sl_price = Ask;
double tp_price = 0;
double lot;

double balance;
bool TPstatus = false;

double getChartCenterPrice () {
    int      window_no;
    datetime get_time;
    double   get_price;
    
    int chart_width = ChartGetInteger(chart_id, CHART_WIDTH_IN_PIXELS, 0);
    int chart_height = ChartGetInteger(chart_id, CHART_HEIGHT_IN_PIXELS, 0);                                              // オブジェクト全削除
    ChartXYToTimePrice(chart_id,chart_width,chart_height/2,window_no,get_time,get_price);
    return get_price;
}

void createSLLine () {
    ObjectCreate(chart_id,sl_line,                                     // オブジェクト作成
                 OBJ_HLINE,                                             // オブジェクトタイプ
                 0,                                                       // サブウインドウ番号
                 0,                                                       // 1番目の時間のアンカーポイント
                 getChartCenterPrice()                                            // 1番目の価格のアンカーポイント
                 );
    //---HLine
    ObjectSetInteger(chart_id,sl_line,OBJPROP_COLOR,clrRed);    // ラインの色設定
    ObjectSetInteger(chart_id,sl_line,OBJPROP_STYLE,STYLE_SOLID);  // ラインのスタイル設定
    ObjectSetInteger(chart_id,sl_line,OBJPROP_WIDTH,2);              // ラインの幅設定
    ObjectSetInteger(chart_id,sl_line,OBJPROP_BACK,false);           // オブジェクトの背景表示設定
    ObjectSetInteger(chart_id,sl_line,OBJPROP_SELECTABLE,true);     // オブジェクトの選択可否設定
    ObjectSetInteger(chart_id,sl_line,OBJPROP_SELECTED,true);      // オブジェクトの選択状態
    ObjectSetInteger(chart_id,sl_line,OBJPROP_HIDDEN,true);         // オブジェクトリスト表示設定
    ObjectSetInteger(chart_id,sl_line,OBJPROP_ZORDER,0);      // オブジェクトのチャートクリックイベント優先順位
    ObjectSetText(sl_line,"SL",8,"Roboto",clrRed); //Object discription
    
}

void createTPLine () {
    ObjectCreate(chart_id,tp_line,                                     // オブジェクト作成
                 OBJ_HLINE,                                             // オブジェクトタイプ
                 0,                                                       // サブウインドウ番号
                 0,                                                       // 1番目の時間のアンカーポイント
                 getChartCenterPrice()                                           // 1番目の価格のアンカーポイント
                 );
    //---HLine
    ObjectSetInteger(chart_id,tp_line,OBJPROP_COLOR,clrBlue);    // ラインの色設定
    ObjectSetInteger(chart_id,tp_line,OBJPROP_STYLE,STYLE_SOLID);  // ラインのスタイル設定
    ObjectSetInteger(chart_id,tp_line,OBJPROP_WIDTH,2);              // ラインの幅設定
    ObjectSetInteger(chart_id,tp_line,OBJPROP_BACK,false);           // オブジェクトの背景表示設定
    ObjectSetInteger(chart_id,tp_line,OBJPROP_SELECTABLE,true);     // オブジェクトの選択可否設定
    ObjectSetInteger(chart_id,tp_line,OBJPROP_SELECTED,true);      // オブジェクトの選択状態
    ObjectSetInteger(chart_id,tp_line,OBJPROP_HIDDEN,true);         // オブジェクトリスト表示設定
    ObjectSetInteger(chart_id,tp_line,OBJPROP_ZORDER,0);      // オブジェクトのチャートクリックイベント優先順位
    ObjectSetText(tp_line,"TP",8,"Roboto",clrBlue); //Object discription
}

void createRiskRewardLabel () {
   ObjectCreate(chart_id,risk_reward_label,                                     // オブジェクト作成
                 OBJ_LABEL,                                             // オブジェクトタイプ
                 0,                                                       // サブウインドウ番号
                 0,                                                       // 1番目の時間のアンカーポイント
                 0                                                        // 1番目の価格のアンカーポイント
                 );
                 
    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_COLOR,clrWhite);    // 色設定

    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_BACK,false);           // オブジェクトの背景表示設定
    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_SELECTABLE,false);     // オブジェクトの選択可否設定
    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_SELECTED,false);      // オブジェクトの選択状態
    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_HIDDEN,true);         // オブジェクトリスト表示設定
    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_ZORDER,0);     // オブジェクトのチャートクリックイベント優先順位


    ObjectSetString(chart_id, risk_reward_label, OBJPROP_TEXT, "RR: " + DoubleToString(risk_reward_ratio, 2));    // 表示するテキスト
    ObjectSetString(chart_id,risk_reward_label,OBJPROP_FONT,"Roboto");  // フォント

    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_FONTSIZE,14);                   // フォントサイズ
    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_CORNER,CORNER_RIGHT_LOWER);  // コーナーアンカー設定
    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_XDISTANCE,160);                // X座標
    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_YDISTANCE,160);                 // Y座標

    // オブジェクトバインディングのアンカーポイント設定
    ObjectSetInteger(chart_id,risk_reward_label,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER); 
    
}

void createLotSizeLabel() {
    ObjectCreate(chart_id, lot_size_label, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_BACK, false);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_SELECTED, false);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_HIDDEN, true);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_ZORDER, 0);
    ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: ");
    ObjectSetString(chart_id, lot_size_label, OBJPROP_FONT, "Roboto");
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_FONTSIZE, 14);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_XDISTANCE, 160);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_YDISTANCE, 130);
    ObjectSetInteger(chart_id, lot_size_label, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
}

double calculateLotSize(){
   double SL = MathAbs(sl_price - Ask);
   double SL_pips = SL / Point;

   // We get the value of a tick.
   double nTickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(b_type == 0) {
      balance = AccountBalance();
   } else {
      balance = AccountEquity();
   }
   // We apply the formula to calculate the position size and assign the value to the variable.
   double lot_size = (balance * risk / 100) / (SL_pips * nTickValue);
   lot_size = MathRound(lot_size / MarketInfo(Symbol(), MODE_LOTSTEP)) * MarketInfo(Symbol(), MODE_LOTSTEP);
   return lot_size;
}

bool spreadFilter () {
   if (MarketInfo(Symbol(), MODE_SPREAD) < max_spread){
      return true;
   } else {
      return false;
   }
}

void executeOrder () {
   for(int order_resend_num = 0; order_resend_num < 10; order_resend_num++ ) {  // エントリー試行回数上限:10回
    
        int ea_ticket_res = 0;
        
        if ( spreadFilter()) {
            lot = calculateLotSize();
            if(Ask - sl_price > 0) {
               ea_ticket_res = OrderSend(   // 新規エントリー注文
                Symbol(),                // 通貨ペア
                OP_BUY,                  // オーダータイプ[OP_BUY / OP_SELL]
                lot,                     // ロット[0.01単位]
                Ask,     // オーダープライスレート
                max_slippage,                       // スリップ上限    (int)[分解能 0.1pips]
                0,                        // ストップレート
                0,                        // リミットレート
                "LotManager: BUY",         // オーダーコメント
                magic_number,                      // マジックナンバー(識別用)
                0,                        // オーダーリミット時間
                clrNONE                   // オーダーアイコンカラー
                );
            } else if (Bid - sl_price < 0) {
               ea_ticket_res = OrderSend(   // 新規エントリー注文
                Symbol(),                // 通貨ペア
                OP_SELL,                  // オーダータイプ[OP_BUY / OP_SELL]
                lot,                     // ロット[0.01単位]
                Bid,     // オーダープライスレート
                max_slippage,                       // スリップ上限    (int)[分解能 0.1pips]
                0,                        // ストップレート
                0,                        // リミットレート
                "LotManager: SELL",         // オーダーコメント
                magic_number,                      // マジックナンバー(識別用)
                0,                        // オーダーリミット時間
                clrNONE                  // オーダーアイコンカラー
                );
            } else {
               MessageBox("Stop Limit too close");
            }
        }
        
        if ( ea_ticket_res == -1 || !spreadFilter()) {            // オーダーエラー
            int errorcode = GetLastError();      // エラーコード取得

            if( errorcode != ERR_NO_ERROR ) { // エラー発生
                printf("errorcode:%d , details:%s ",errorcode , ErrorDescription(errorcode));

                if ( errorcode == ERR_TRADE_NOT_ALLOWED ) { // 自動売買が許可されていない
                    MessageBox(ErrorDescription(errorcode),"Autotrade Disabled",MB_ICONEXCLAMATION);
                    return;
                }
            }

            Sleep(1000);                                           // 1000msec待ち
            RefreshRates();                                        // レート更新
            printf("Re-entry count:%d",order_resend_num+1);

        } else {    // 注文約定
            Print("Order Complete Ticket No:" + IntegerToString(ea_ticket_res));
            Sleep(300);                        //Avoid order error
            bool modify_ret;
            int errorcode;
            for(int modify_resend_num = 0; modify_resend_num < 20; modify_resend_num++ ) {
               if(tp_price == 0){
                  modify_ret = OrderModify(ea_ticket_res, OrderOpenPrice(),sl_price,0, 0, clrGreen);
               } else {
                  modify_ret = OrderModify(ea_ticket_res, OrderOpenPrice(),sl_price,tp_price, 0, clrGreen);
               }
               if (modify_ret == false) {
                  Sleep(300);
                  errorcode = GetLastError();
                  printf("Order modify count:%d errorcode:%d details:%s", modify_resend_num+1, errorcode, ErrorDescription(errorcode));
               } else {
                  Print("Order Modify Complete Tiket No:" + IntegerToString(ea_ticket_res));
                  break; //break from order modify loop
               }
            }
            
            
            break; //break from order loop
        }
    }
}

double calculateRiskReward () {
    if((Ask - sl_price > 0 && Ask - tp_price < 0) || (Ask - sl_price < 0 && Ask - tp_price > 0)){
        double SL = MathAbs(sl_price - Ask);
        double TP = MathAbs(tp_price - Ask);
        risk_reward_ratio = TP / SL;
    } else {
        risk_reward_ratio = 0.00;
    }
    return risk_reward_ratio;
}

void setTPstatus (bool state) {
   TPstatus = state;
}



void OnInit() {


    
    ObjectsDeleteAll(); 
    createSLLine();
    
            
    ObjectCreate(chart_id,trade_button,                                     // オブジェクト作成
                 OBJ_BUTTON,                                             // オブジェクトタイプ
                 0,                                                       // サブウインドウ番号
                 0,                                                       // 1番目の時間のアンカーポイント
                 0                                                        // 1番目の価格のアンカーポイント
                 );
    ObjectCreate(chart_id,tp_button,                                     // オブジェクト作成
                 OBJ_BUTTON,                                             // オブジェクトタイプ
                 0,                                                       // サブウインドウ番号
                 0,                                                       // 1番目の時間のアンカーポイント
                 0                                                        // 1番目の価格のアンカーポイント
                 );
                 
    ObjectCreate(chart_id,hide_button,                                     // オブジェクト作成
                 OBJ_BUTTON,                                             // オブジェクトタイプ
                 0,                                                       // サブウインドウ番号
                 0,                                                       // 1番目の時間のアンカーポイント
                 0                                                        // 1番目の価格のアンカーポイント
                 );
    

    
    //---Button
    
    ObjectSetInteger(chart_id,trade_button,OBJPROP_COLOR,clrWhite);    // 色設定

    ObjectSetInteger(chart_id,trade_button,OBJPROP_BACK,false);           // オブジェクトの背景表示設定
    ObjectSetInteger(chart_id,trade_button,OBJPROP_SELECTABLE,false);     // オブジェクトの選択可否設定
    ObjectSetInteger(chart_id,trade_button,OBJPROP_SELECTED,false);      // オブジェクトの選択状態
    ObjectSetInteger(chart_id,trade_button,OBJPROP_HIDDEN,true);         // オブジェクトリスト表示設定
    ObjectSetInteger(chart_id,trade_button,OBJPROP_ZORDER,0);     // オブジェクトのチャートクリックイベント優先順位


    ObjectSetString(chart_id,trade_button,OBJPROP_TEXT,"TRADE");            // 表示するテキスト
    ObjectSetString(chart_id,trade_button,OBJPROP_FONT,"Roboto");          // フォント

    ObjectSetInteger(chart_id,trade_button,OBJPROP_FONTSIZE,8);                   // フォントサイズ
    ObjectSetInteger(chart_id,trade_button,OBJPROP_CORNER,CORNER_RIGHT_LOWER);  // コーナーアンカー設定
    ObjectSetInteger(chart_id,trade_button,OBJPROP_XDISTANCE,160);                // X座標
    ObjectSetInteger(chart_id,trade_button,OBJPROP_YDISTANCE,40);                 // Y座標
    ObjectSetInteger(chart_id,trade_button,OBJPROP_XSIZE,150);                    // ボタンサイズ幅
    ObjectSetInteger(chart_id,trade_button,OBJPROP_YSIZE,30);                     // ボタンサイズ高さ
    ObjectSetInteger(chart_id,trade_button,OBJPROP_BGCOLOR,clrRed);              // ボタン色
    ObjectSetInteger(chart_id,trade_button,OBJPROP_STATE,false);                  // ボタン押下状態
    
    ObjectSetInteger(chart_id,tp_button,OBJPROP_COLOR,clrWhite);    // 色設定

    ObjectSetInteger(chart_id,tp_button,OBJPROP_BACK,false);           // オブジェクトの背景表示設定
    ObjectSetInteger(chart_id,tp_button,OBJPROP_SELECTABLE,false);     // オブジェクトの選択可否設定
    ObjectSetInteger(chart_id,tp_button,OBJPROP_SELECTED,false);      // オブジェクトの選択状態
    ObjectSetInteger(chart_id,tp_button,OBJPROP_HIDDEN,true);         // オブジェクトリスト表示設定
    ObjectSetInteger(chart_id,tp_button,OBJPROP_ZORDER,0);     // オブジェクトのチャートクリックイベント優先順位


    ObjectSetString(chart_id,tp_button,OBJPROP_TEXT,"TP");            // 表示するテキスト
    ObjectSetString(chart_id,tp_button,OBJPROP_FONT,"Roboto");          // フォント

    ObjectSetInteger(chart_id,tp_button,OBJPROP_FONTSIZE,8);                   // フォントサイズ
    ObjectSetInteger(chart_id,tp_button,OBJPROP_CORNER,CORNER_RIGHT_LOWER);  // コーナーアンカー設定
    ObjectSetInteger(chart_id,tp_button,OBJPROP_XDISTANCE,160);                // X座標
    ObjectSetInteger(chart_id,tp_button,OBJPROP_YDISTANCE,80);                 // Y座標
    ObjectSetInteger(chart_id,tp_button,OBJPROP_XSIZE,150);                    // ボタンサイズ幅
    ObjectSetInteger(chart_id,tp_button,OBJPROP_YSIZE,30);                     // ボタンサイズ高さ
    ObjectSetInteger(chart_id,tp_button,OBJPROP_BGCOLOR,clrBlue);              // ボタン色
    ObjectSetInteger(chart_id,tp_button,OBJPROP_STATE,false);                  // ボタン押下状態
    
    ObjectSetInteger(chart_id,hide_button,OBJPROP_COLOR,clrWhite);    // 色設定

    ObjectSetInteger(chart_id,hide_button,OBJPROP_BACK,false);           // オブジェクトの背景表示設定
    ObjectSetInteger(chart_id,hide_button,OBJPROP_SELECTABLE,false);     // オブジェクトの選択可否設定
    ObjectSetInteger(chart_id,hide_button,OBJPROP_SELECTED,false);      // オブジェクトの選択状態
    ObjectSetInteger(chart_id,hide_button,OBJPROP_HIDDEN,true);         // オブジェクトリスト表示設定
    ObjectSetInteger(chart_id,hide_button,OBJPROP_ZORDER,0);     // オブジェクトのチャートクリックイベント優先順位


    ObjectSetString(chart_id,hide_button,OBJPROP_TEXT,"HIDE");            // 表示するテキスト
    ObjectSetString(chart_id,hide_button,OBJPROP_FONT,"Roboto");          // フォント

    ObjectSetInteger(chart_id,hide_button,OBJPROP_FONTSIZE,8);                   // フォントサイズ
    ObjectSetInteger(chart_id,hide_button,OBJPROP_CORNER,CORNER_RIGHT_LOWER);  // コーナーアンカー設定
    ObjectSetInteger(chart_id,hide_button,OBJPROP_XDISTANCE,160);                // X座標
    ObjectSetInteger(chart_id,hide_button,OBJPROP_YDISTANCE,120);                 // Y座標
    ObjectSetInteger(chart_id,hide_button,OBJPROP_XSIZE,150);                    // ボタンサイズ幅
    ObjectSetInteger(chart_id,hide_button,OBJPROP_YSIZE,30);                     // ボタンサイズ高さ
    ObjectSetInteger(chart_id,hide_button,OBJPROP_BGCOLOR,clrGreen);              // ボタン色
    ObjectSetInteger(chart_id,hide_button,OBJPROP_STATE,false);                  // ボタン押下状態
    
    
    
    if(b_type == 0) {
       balance = AccountBalance();
    } else {
       balance = AccountEquity();
    }    
    sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
    createLotSizeLabel();
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
//---
   //double nTickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   //Print(nTickValue);
   //double SL_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
   //Print(SL_price);

   /*risk_reward_ratio = calculateRiskReward();
   lot = calculateLotSize();
   ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
   ObjectSetString(chart_id, risk_reward_label, OBJPROP_TEXT, "RR: " + DoubleToString(risk_reward_ratio, 2));*/
   tp_price = ObjectGetDouble(0,tp_line,OBJPROP_PRICE,0);
   sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
   lot = calculateLotSize();
   risk_reward_ratio = calculateRiskReward();
   ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
   ObjectSetString(chart_id, risk_reward_label, OBJPROP_TEXT, "RR: " + DoubleToString(risk_reward_ratio, 2));
   
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
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == hide_button) {
         if(ObjectGetInteger(chart_id, hide_button, OBJPROP_STATE)) {
            ObjectSetString(chart_id,hide_button,OBJPROP_TEXT,"SHOW");
            //ObjectSetInteger(chart_id,sl_line,OBJPROP_COLOR,clrNONE);
            ObjectDelete(chart_id, sl_line);
            ObjectDelete(chart_id, tp_line);
            ObjectDelete(chart_id, risk_reward_label);
            ObjectDelete(chart_id, lot_size_label);
            ObjectSetInteger(chart_id,tp_button,OBJPROP_STATE,false);
            tp_price = 0;
            
         } else {
            ObjectSetString(chart_id,hide_button,OBJPROP_TEXT,"HIDE");
            //ObjectSetInteger(chart_id,sl_line,OBJPROP_COLOR,clrYellow);
            createSLLine();
            createLotSizeLabel();
            sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
            lot = calculateLotSize();
            ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
         }
      }
      if(sparam == tp_button) {
         if(ObjectGetInteger(chart_id, tp_button, OBJPROP_STATE)) {
            createTPLine();
            tp_price = ObjectGetDouble(0,tp_line,OBJPROP_PRICE,0);
            sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
            risk_reward_ratio = calculateRiskReward();
            createRiskRewardLabel();
            ObjectSetString(chart_id, risk_reward_label, OBJPROP_TEXT, "RR: " + DoubleToString(risk_reward_ratio, 2));
            setTPstatus(true);
            
         } else {
            ObjectDelete(chart_id, tp_line);
            ObjectDelete(chart_id, risk_reward_label);
            tp_price = 0;
            setTPstatus(false);
            
         }
      }
      if(sparam == trade_button) {
         if(TPstatus) {
            if((Ask - sl_price > 0 && Ask - tp_price < 0) || (Ask - sl_price < 0 && Ask - tp_price > 0)) {
               executeOrder();
            } else {
               MessageBox("Order Faild Invalid TP","Order Faild",MB_OK);
            }
         }else {
            executeOrder();
         }
         ObjectSetInteger(chart_id,trade_button,OBJPROP_STATE,false);
         
      }
      
    
   }
   if(id == CHARTEVENT_OBJECT_DRAG) {
      if(sparam == sl_line) {
         sl_price = ObjectGetDouble(0,sl_line,OBJPROP_PRICE,0);
         lot = calculateLotSize();
         ObjectSetString(chart_id, lot_size_label, OBJPROP_TEXT, "Lot: " + DoubleToString(lot, 2));
         //Print(lot);
      }
      if(sparam == tp_line) {
         tp_price = ObjectGetDouble(0,tp_line,OBJPROP_PRICE,0);
         
         //Print(tp_price);
      }
      risk_reward_ratio = calculateRiskReward();
      ObjectSetString(chart_id, risk_reward_label, OBJPROP_TEXT, "RR: " + DoubleToString(risk_reward_ratio, 2));
   }

}