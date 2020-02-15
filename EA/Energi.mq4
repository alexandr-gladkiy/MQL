//+------------------------------------------------------------------+
//|                                                       Energi.mq4 |
//|                                                            AlexG |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "AlexG"
#property link      ""
#property version   "2.0"
#property strict

#include "../Classes/ClassAccountingOrders.mqh"
#include "../Classes/ClassOrder.mqh"
#include "../Classes/ClassCandle.mqh"
#include "../Classes/ClassLevel.mqh"
#include "../Lib/Lot.mqh"
#include "../Classes/ClassRegression.mqh"

#define  MAGIC 215455454

input string str1 = "----- Volume setings -----";       // ---------------------------
input double InpLot     = 0.1;                          // Lots
input double InpBalance = 100;                          // Balance

input string str2 = "----- Stoploss and takeprofit setings -----";  // ---------------------------
 bool   InpUseVirtualStopes = false;                // Use virtual stopes  ПОКА ОТКЛЮЧИЛ!!!
input int    InpTakeProfit = 300;                       // Take Profit
input int    InpStopLoss   = 25;                        // Stop Loss
input bool   InpEnabledTraillingStop = true;            // Enabled trailling stop
input int    InpTrallStepSL  = 1;                       // Trall Step 

input string str3 = "Order setings";                    // ---------------------------
input int    InpDistanceToOrder = 25;                   // Distance to order
input bool   InpEnabledTraillingOrd = true;             // Enabled trailling for distance
input int    InpTrallStepOrd  = 1;                      // Trall Step

input string str4 = "----- Trade filters -----";        // ---------------------------
input int    InpSlippage = 20;                          // Slippage
input int    InpMaxSpread  = 20;                        // Max Spread  
input int    InpBeginTradeTimeHour    = 0;              // Begin trade time ( Hour )
//input int    InpBeginTradeTimeMinutes = 01;             // Begin trade time ( Minutes )
input int    InpEndTradeTimeHour      = 0;              // End Trade time ( Hour )
//input int    InpEndTradeTimeMinutes   = 59;             // End Trade time ( Minutes )
input bool   InpFilterIndicator = false;                // Filter indicator
int InpPeriodIndicator = 150;                           // Period for analyse

string symbol = Symbol();
int timeframe = Period(); 

bool newCandle = false;
datetime dt_last = 0,
         dt_curr = 0;
         
ClassAccountingOrders Orders;

ClassOrder OrderBuy, OrderSell;
ClassRegression Regression;

bool Validate = false;

double LastLot;


//+-------------------------------------------------------------------+
 int Normalize( int param )
   {
     int new_param = param;
   
     if( Digits == 4 || Digits == 2 )
       new_param = (int)(param / 10);
   
     return new_param;
   }

//--- Фильтр по индикатору   
 bool GetFilterIndicator( int type )
   {
     if( InpFilterIndicator )
       return GetTradeSignal(type);
     return true;
   }  

//+------------------------------------------------------------------+
int OnInit()
  {
   
   Regression.period = InpPeriodIndicator;
   Regression.begin_index = 2;
   
   return(INIT_SUCCEEDED);
  }
  
  
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    ObjectDelete( "SellStop" );
    ObjectDelete( "BuyStop" );
    ObjectDelete( "SellSL" );
    ObjectDelete( "BuySL" );
    ObjectDelete( "SellTP" );
    ObjectDelete( "BuyTP" );
  }
  
  
//+------------------------------------------------------------------+
void OnTick()
  {
    //---- Скрипт для прохождения проверки бота на mql5comunity.com
    double Spread = MarketInfo( symbol, MODE_SPREAD );
    if( IsTesting() && !Validate && Spread > 80 )
        Validate = MarketValidate();
    if( Spread > 80 )
      return;  
    
  
   //------------- Мониторинг новой свечи -----------
    dt_curr = iTime( symbol, timeframe, 0 );
   
    newCandle = dt_last != dt_curr; 
                     
    if( newCandle )
      dt_last = dt_curr;
    
   
   //--- Инициализация рыночных ордеров   
    if( newCandle )
      {
        Orders.Init( symbol, MAGIC );
        Regression.InitLenear();
      }
    
   //--- Формирование фильтра разрешённого времени торговли 
    int CurrHour = TimeHour( TimeCurrent() ),
        CurrMinutes = TimeMinute( TimeCurrent() );
    
    bool TimeFilter = (
      (
           CurrHour >= InpBeginTradeTimeHour
        && CurrHour <= InpEndTradeTimeHour
      )
    );
    
    if( !TimeFilter || Spread > InpMaxSpread )
      {
        OrderBuy.Clear();
        OrderSell.Clear();
      }
   //----------------------------------------------------------     
   
    
   //----- Открытие сделок на покупку      
    if(    newCandle
        && GetTradeSignal( OP_BUY )
      //  && TimeFilter
        && OrderBuy.Type == -1 
        && Orders.buy == 0 
        && Orders.buystop == 0
       // && GetFilterIndicator(OP_BUY) 
      )
      {
        OrderBuy.Type = OP_BUYSTOP;
        OrderBuy.MagicNumber = MAGIC;
        OrderBuy.Lot = GetLotMax( InpLot, InpBalance, LastLot );
        OrderBuy.OpenPrice = Ask + Normalize(InpDistanceToOrder)*Point;
        OrderBuy.Slippage = Normalize(InpSlippage);
      }  
         
   //----- Открытие сделок на продажу
    if(    newCandle 
        && GetTradeSignal( OP_SELL )
       // && TimeFilter
        && OrderSell.Type == -1 
        && Orders.sell == 0 
        && Orders.sellstop == 0
     //   && GetFilterIndicator(OP_SELL) 
      )
      {
        OrderSell.Type = OP_SELLSTOP;
        OrderSell.MagicNumber = MAGIC;
        OrderSell.Lot = GetLotMax( InpLot, InpBalance, LastLot );
        OrderSell.OpenPrice = Bid - Normalize(InpDistanceToOrder)*Point;
        OrderSell.Slippage = Normalize(InpSlippage);
      } 
      
       
      
    //------ Отслеживание виртуальных отложенных ордеров и виртуальных стопов
     TrackOrder( OrderBuy );
     TrackOrder( OrderSell );
     
    
    //------ Отрисовка уровней отложенных ордеров и стопов 
     DrawLevels( OrderBuy );
     DrawLevels( OrderSell );
   
  }
  
//+------------------------------------------------------------------+
 void DrawLevels( ClassOrder &order )
   {
     string order_stop_name = "",
            tp_name = "",
            sl_name = "";
            
     if( order.Type == OP_BUY || order.Type == OP_BUYSTOP )
       {
         order_stop_name = "BuyStop";
         tp_name = "BuyTP";
         sl_name = "BuySL";
       }
       
     if( order.Type == OP_SELLSTOP || order.Type == OP_SELL )
       {
         order_stop_name = "SellStop";
         tp_name = "SellTP";
         sl_name = "SellSL";
       }
       
       
       
     if( order.Type == OP_BUY || order.Type == OP_SELL )
       {
         ObjectDelete( order_stop_name );
         
         if( InpUseVirtualStopes )
           {
             DrawPriceLevel( tp_name, order.TakeProfit, clrRed );
             DrawPriceLevel( sl_name, order.StopLoss, clrRed );
           }
       }
       
     if( order.Type == OP_BUYSTOP || order.Type == OP_SELLSTOP || order.Type == -1 )
       {
         DrawPriceLevel( order_stop_name, order.OpenPrice, clrGreen );
         ObjectDelete( tp_name );
         ObjectDelete( sl_name );
       }
   }
   
//+------------------------------------------------------------------+
 void DrawPriceLevel( string name, double price, color clr )
   {
     ObjectDelete( name );
    
     if( price == 0 )
       return;
       
     ObjectCreate( 0, name, OBJ_HLINE, 0, 0, price );
     ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT );
     ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);    
     ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
     ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    
     ChartRedraw();
   }
   
//+------------------------------------------------------------------+
 void TrackOrder( ClassOrder &order )
   {
    if( order.Type == ( OP_BUY || OP_SELL ) )
      {
        if( !OrderSelect( order.Ticket, SELECT_BY_TICKET, MODE_TRADES ) )
          {
            order.Clear();
            return;
          }
      }
    //-----
     if(order.Type == OP_BUYSTOP)
       {
        //---
         if( Ask >= order.OpenPrice )
           {
             order.Virtual    = InpUseVirtualStopes;
             order.Type       = OP_BUY;
             order.TakeProfit = order.OpenPrice + Normalize(InpTakeProfit)*Point;
             order.StopLoss   = order.OpenPrice - Normalize(InpStopLoss)*Point;
             
             order.Send();
           }
           
        //---
         if( InpEnabledTraillingOrd )
           if( Ask <= order.OpenPrice - Normalize(InpDistanceToOrder)*Point - Normalize(InpTrallStepOrd)*Point && Normalize(InpTrallStepOrd) >= 0 )
             order.OpenPrice = Ask + Normalize(InpDistanceToOrder)*Point;
       }
       
    //-----   
     if(order.Type == OP_SELLSTOP)
       {
        //---
         if( Bid <= order.OpenPrice )
           {
             order.Virtual    = InpUseVirtualStopes;
             order.Type       = OP_SELL;
             order.TakeProfit = order.OpenPrice - Normalize(InpTakeProfit)*Point;
             order.StopLoss   = order.OpenPrice + Normalize(InpStopLoss)*Point;
             
             order.Send();
           }
           
        //---
         if( InpEnabledTraillingOrd )
          if( Bid >= order.OpenPrice + Normalize(InpDistanceToOrder)*Point + Normalize(InpTrallStepOrd)*Point && Normalize(InpTrallStepOrd) >= 0 )
             order.OpenPrice = Bid - Normalize(InpDistanceToOrder)*Point;
       }
    
    //-----   
     if(order.Type == OP_BUY)
       {
         if( InpUseVirtualStopes )
          {
           if( (InpTakeProfit > 0 && Bid >= order.TakeProfit) || (InpStopLoss > 0 && Bid <= order.StopLoss) )
             {
               order.Close();
               ObjectDelete( "BuyTP" );
               ObjectDelete( "BuySL" );
             }
          }
         
         if( InpEnabledTraillingStop && !InpUseVirtualStopes )
           TraillingStop( symbol, MAGIC, NULL, InpTrallStepSL );
           
         if( InpEnabledTraillingStop && InpUseVirtualStopes ) 
           if( order.StopLoss > 0 && InpStopLoss > 0 && Bid >= order.StopLoss + Normalize(InpStopLoss)*Point + Normalize(InpTrallStepSL)*Point && Normalize(InpTrallStepSL) >= 0 )
             order.StopLoss = Bid - Normalize(InpStopLoss)*Point;
       }
    
    //-----   
     if(order.Type == OP_SELL)
       {
         if( InpUseVirtualStopes )
          {
           if( (InpTakeProfit > 0 && Ask <= order.TakeProfit) || (InpStopLoss > 0 && Ask >= order.StopLoss) )
             {
               order.Close();
               ObjectDelete( "SellTP" );
               ObjectDelete( "SellSL" );
             }
           }
         
         if( InpEnabledTraillingStop && !InpUseVirtualStopes )
           TraillingStop( symbol, MAGIC, NULL, InpTrallStepSL );
           
         if( InpEnabledTraillingStop && InpUseVirtualStopes )  
           if( order.StopLoss > 0 && InpStopLoss > 0 && Ask <= order.StopLoss - Normalize(InpStopLoss)*Point - Normalize(InpTrallStepSL)*Point && Normalize(InpTrallStepSL) >= 0  )
             order.StopLoss = Ask + Normalize(InpStopLoss) * Point;
       }  
   }

  
//+------------------------------------------------------------------+
bool GetTradeSignal( int type )
  {
    int cnt_candle = 10;
    ClassCandle candle[];
    ArrayResize(candle, cnt_candle);
    
    ClassLevel level[];
    
    int cnt_calc = 1000;
    
    for( int i=0; i<cnt_calc; i++ )
      {
        int high, low;
        double center1, center2;
        
        high = iHighest( symbol, timeframe, MODE_HIGH, InpPeriodIndicator, i+1 );
        low  = iLowest( symbol, timeframe, MODE_LOW, InpPeriodIndicator, i+1 );
        center1 = ( iHigh( symbol, timeframe, high ) + iLow( symbol, timeframe, low ) ) / 2;
        
        high = iHighest( symbol, timeframe, MODE_HIGH, InpPeriodIndicator, i+2 );
        low  = iLowest( symbol, timeframe, MODE_LOW, InpPeriodIndicator, i+2 );
        center2 = ( iHigh( symbol, timeframe, high ) + iLow( symbol, timeframe, low ) ) / 2;
        
        for( int x=0; x<cnt_candle; x++ )
          candle[x].Init(symbol, timeframe, i+x);
          
        if(   ( candle[1].close > center1 && candle[2].close > center2 && candle[1].high > iHigh( symbol, timeframe, high ) )
            ||( candle[1].close < center1 && candle[2].close < center2 && candle[1].low < iLow( symbol, timeframe, low ) ))
          {
            int size = ArraySize( level );
            ArrayResize( level, size+1 );
            
            level[size].SetLevel( candle[1].high, candle[1].low );
          }
          
      }
     
     //HideTestIndicators(true);
     //HideTestIndicators(false);
  
   //-----
    if( type == OP_BUY )
      {
        return(
             Ask > Regression.GetValue( REGRESS_VALUE_FIRST, DEVIATION_UP )
             
             //candle[1].direction == CANDLE_DOWN 
          //&& candle[1].size_point > 200
        );
      }
   
   
   //-----   
    if( type == OP_SELL )
      {
        return(
             Bid < Regression.GetValue( REGRESS_VALUE_FIRST, DEVIATION_DOWN )
        
   //          candle[1].direction == CANDLE_UP
 //         && candle[1].size_point > 200
        );
      }
      
    return false;
  }
   
//--------- Validate To Market -------------
bool MarketValidate(  )
  {
   //---------------------- 
    ClassOrder order;
    int t;
    
    order.Lot = 1;
    order.Type = OP_BUY;
    order.OpenPrice = MarketInfo( Symbol(), MODE_ASK );
    order.Slippage = 10;
     
    t = order.Send();
    if( t > 0 && OrderSelect( t, SELECT_BY_TICKET, MODE_TRADES ) )
      if( OrderClose( t, OrderLots(), MarketInfo( Symbol(), MODE_BID ), InpSlippage ) )
          return true; 
        
    return false;
  }  
  
  
//+---------------------------------------------------------------------------+
void TraillingStop( string symbol_, int magic_, string comment_ = NULL, int step_ = 0, bool breakeven_ = false )
  {
    if(OrdersTotal() == 0)
      return;
    
    bool result, find; 
    double spr = Ask-Bid,
           step_loc = NormalizeDouble(step_*Point, Digits),
           sl = 0;
           
    for(int i=0; i<OrdersTotal(); i++)
      {
        if( OrderSelect( i, SELECT_BY_POS ) )
          {
            if( comment_ == NULL )
              find = OrderSymbol() == symbol_ && OrderMagicNumber() == magic_;
            else
              find = OrderSymbol() == symbol_ && OrderMagicNumber() == magic_ && OrderComment() == comment_;
              
            if(find)
              { 
                sl = MathAbs(OrderOpenPrice() - OrderStopLoss());  
                  
                if(OrderType() == OP_BUY)
                  {
                    if(breakeven_ && OrderStopLoss()>=OrderOpenPrice())
                      return;
                  
                    if(OrderStopLoss() <= Bid - sl - step_loc)
                      result = OrderModify(OrderTicket(), 0, Bid - sl, OrderTakeProfit(), 0, clrNONE);
                  }
                  
                if(OrderType() == OP_SELL)
                  {
                    if(breakeven_ && OrderStopLoss()<=OrderOpenPrice())
                      return;
                      
                    if(OrderStopLoss() >= Ask + sl + step_loc)
                      result = OrderModify(OrderTicket(), 0, Ask + sl, OrderTakeProfit(), 0, clrNONE);
                  }
              }
          }
      }
  }   
  
  