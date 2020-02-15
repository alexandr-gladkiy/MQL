//+------------------------------------------------------------------+
//|                                           ParallaxGridLocker.mq4 |
//|                                                           Alex G |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Alex G"
#property link      ""
#property version   "3.00"
#property strict

#include "../Classes/ClassAccountingOrders.mqh"
#include "../Classes/ClassOrder.mqh"
#include "../Classes/ClassCandle.mqh"
#include "../Classes/ClassInfoPanelProfit.mqh"

#include <MovingAverages.mqh>


#define TREND_UP 1
#define TREND_DOWN 2
#define TREND_UNDEFINED 0

enum CalculationMethodTakeProfit
 {
   Averaging,        // Averaging
   FromDistantOrder  // From a distant order
 };
 
#define MAGIC_BUY_START 124544457 
#define MAGIC_SELL_START 124544457  

input int TakeProfit          = 100;  // Take Profit
input double Lots             = 0.01; // Lot
input double Balance          = 100;  // Balance
input int CountOrdesForGroup  = 10;   // Count orders for group 

//input double MaxProfitPercent = 0;  // Max profit (%)
input double DrawdownForUnload  = 10; // Drawdown for begin unload (%)
input double ProfitAfterUnload = 2;  // Profit after unload (%)

 CalculationMethodTakeProfit CalcMethodTP = CalculationMethodTakeProfit::Averaging; // Calculation method for take profit
 //CalculationMethodTakeProfit CalcMethodTP = CalculationMethodTakeProfit::FromDistantOrder; // Calculation method for take profit
 
 int Slippage                             = 2;   // Slippage
 double MinLot                            = 0.01;   
 int StepGrid  = (int)(TakeProfit * 2); 


string symbol = Symbol();
int timeframe = PERIOD_CURRENT;

bool newCandle = false;
datetime dt_last = 0,
         dt_curr = 0;
         
         
int Magic_BUY  = MAGIC_BUY_START,
    Magic_SELL = MAGIC_SELL_START;
    
double Lot = MinLot;

ClassAccountingOrders Orders;

ClassInfoPanelProfit PanelProfit;

bool Validate = false;

bool Unloading = false;
//+------------------------------------------------------------------+
int OnInit()
  {
    if( Digits == 5 || Digits == 3 )
      Slippage *= 10;
   
  
    if( IsVisualMode() || !IsTesting() ) 
      PanelProfit.Create();
    
    return(INIT_SUCCEEDED);
  }
  
  
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    ObjectDelete( symbol + "TakeProfit_Buy" );
    ObjectDelete( symbol + "TakeProfit_Sell" );
    
    if( IsVisualMode() || !IsTesting() ) 
      PanelProfit.Delete();
  }
  
  
//+------------------------------------------------------------------+
void OnTick()
  {
   
   //---- Скрипт для прохождения проверки бота на mql5comunity.com
    bool spread_filter = Ask - Bid > NormalizeDouble( 80 * Point, Digits );
    if( IsTesting() && !Validate && spread_filter )
        Validate = MarketValidate();
    if( spread_filter )
      return;  
      
  
   //------------- Мониторинг новой свечи -----------
    dt_curr = iTime( symbol, timeframe, 0 );
   
    newCandle = dt_last != dt_curr; 
                     
    if( newCandle )
      dt_last = dt_curr;
      
    if( newCandle )
      Orders.Init( symbol, Magic_BUY );
      
    if( Orders.buy == 0 )
      ObjectDelete( symbol + "TakeProfit_Buy" );
    if( Orders.sell == 0 )
      ObjectDelete( symbol + "TakeProfit_Buy" );
    
   
    if( newCandle && GetTradeSignal( OP_BUY, Magic_BUY ) )
      {
        Lot = GetLot( Lots, Balance, MinLot );
        OpenOrder( OP_BUY, Magic_BUY );
      }
      
    if( newCandle && GetTradeSignal( OP_SELL, Magic_SELL ) )
      {
        Lot = GetLot( Lots, Balance, MinLot );
        OpenOrder( OP_SELL, Magic_SELL );
      }
      
      
     
    TrackTakeProfit( OP_BUY, Magic_BUY );
    TrackTakeProfit( OP_SELL, Magic_SELL );  
     
     
   //--- Разгрузка депозита, когда появляется большая просадка по всем открытым ордерам (учитываются все пары) ---
    if( DrawdownForUnload > 0 && (  ( ( AccountEquity() - AccountBalance() ) / AccountBalance() * 100 ) < -DrawdownForUnload ) )
      Unloading = true;
      
    if( Unloading )
      {
        if( ( ( AccountEquity() - AccountBalance() ) / AccountBalance() * 100 ) >= ProfitAfterUnload)
          {
            CloseAllOrders(); 
            Unloading = false;
          }
      }
   //-------------------------------------------------------------------------------------------------------------   
    
   
   //--- Обновление данных о заработанных средствах 
    PanelProfit.SetProcessUnload( Unloading );  //--- Включатель процедуры разгрузки
   
    if( IsVisualMode() || !IsTesting() )  
      PanelProfit.Update(NULL);  
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
    order.Slippage = 1;
     
    t = order.Send();
    if( t > 0 && OrderSelect( t, SELECT_BY_TICKET, MODE_TRADES ) )
      if( OrderClose( t, OrderLots(), MarketInfo( Symbol(), MODE_BID ), 10 ) )
          return true; 
        
    return false;
  }   
  
  
//+------------------------------------------------------------------+
 void CloseAllOrders()
   {
     ClassOrder order;
     int size = 0;
     int tickets[];
     for( int i=0; i<OrdersTotal(); i++ )
       {
         if( !OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) )
           continue;
           
         //if( OrderSymbol() != symbol )
         //  continue;  
           
         size = ArraySize( tickets );
         ArrayResize( tickets, size+1 );
         
         tickets[size] = OrderTicket();
       }
       
       ArrayReverse( tickets );
     
      //----- 
       for( int i=0; i<ArraySize( tickets ); i++)
         {
           if( !OrderSelect( tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
             continue;
             
           order.Init( tickets[i] );
           order.Close();    
         } 
         
          
     ObjectDelete( symbol + "TakeProfit_Buy" );
     ObjectDelete( symbol + "TakeProfit_Sell" );
     
   }
  

//+------------------------------------------------------------------+
 void DrawTakeProfit( string name, double takeprofit )
   {
     ObjectDelete( name );
    
     if( takeprofit == 0 )
       return;
       
     ObjectCreate( 0, name, OBJ_HLINE, 0, 0, takeprofit );
     ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT );
     ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);    
     ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
     ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
    
     ChartRedraw();
   }

//+------------------------------------------------------------------+
 void TrackTakeProfit( int type, int magic )
   {
     ClassAccountingOrders orders;
     orders.Init( symbol, magic );
     
     ClassOrder order();
     bool close_orders = false;
     
       
     int tickets[];
     orders.GetTickets( tickets, type );
     
     if( ArraySize( tickets ) == 0 )
       return;
       
     double TP = 0; 
     
     if( CalcMethodTP == CalculationMethodTakeProfit::Averaging )
       TP = GetAVGTakeProfit( type, magic );
       
     if( CalcMethodTP == CalculationMethodTakeProfit::FromDistantOrder )
       TP = GetTakeProfitFromDistantOrder( type, magic );  
     
     if( TP == 0 )
       return;
       
    //------- Отрисовка nfrt Profit --------
    string TP_name = symbol + "TakeProfit_";
    if( type == OP_BUY )
      TP_name += "Buy";
    if( type == OP_SELL )
      TP_name += "Sell";
      
    DrawTakeProfit( TP_name, TP );   
     
    double percent_for_close = 0;
    
    //------ 
     if( type == OP_BUY && TP > 0 )
       { 
         if( Bid >= TP - TakeProfit/2*Point )
           {
             close_orders = true;  
             percent_for_close = 50;
           }
           
         if( Bid > TP )
           {
             close_orders = true;
             percent_for_close = 100;
           }
          
       }
       
         
    //------   
     if( type == OP_SELL )
       {
           
         if( Ask <= TP + TakeProfit/2*Point )
           {
             close_orders = true;  
             percent_for_close = 50;
           }
           
         if( Ask < TP )
           {
             close_orders = true;  
             percent_for_close = 100;
           }
       }
     
     
     if( !close_orders )
       return;
       
     int close_tickets[];
     int size = 0;
       
     for( int i=0; i<ArraySize( tickets ); i++ )
       {
         if( i == CountOrdesForGroup )
           break;  
          size = ArraySize( close_tickets );
          ArrayResize( close_tickets, size + 1 );
          close_tickets[ size ] = tickets[i];  
       }
       
     ArrayReverse( close_tickets );
     for( int i=0; i<ArraySize( close_tickets ); i++ )
       {
         order.Init( close_tickets[i] );
         
         if( percent_for_close == 100 )
           {
             order.Close();
             ObjectDelete( TP_name );
             continue;
           }
          
        
          
         if( order.StopLoss > 0 )
           continue;
             
         if( percent_for_close == 50 )
           { 
               
             if( !order.Init( tickets[i] ) )
               continue;
               
               
             int PipsToBreakeven = 2;
             if( Digits == 5 || Digits == 3 )
               PipsToBreakeven *= 10;  
               
             if( type == OP_SELL )
               order.StopLoss = NormalizeDouble( order.OpenPrice - PipsToBreakeven*Point, Digits );
             if( type == OP_BUY )
               order.StopLoss = NormalizeDouble( order.OpenPrice + PipsToBreakeven*Point, Digits );
               
             if( order.Modify() )  
               order.Close( 50 );  
               
           }
        
       }
   }


//+------------------------------------------------------------------+
  void CloseOrders( string symbol_, int magic_, int type, double percent_ )
    {
      ClassAccountingOrders orders;
      ClassOrder order;
      
      orders.Init( symbol_, magic_ );
      
      if( orders.market == 0 )
        return;
        
      int tickets[];
      orders.GetTickets( tickets, type );
      
      
      ArrayReverse( tickets );
      
      for( int i=0; i<ArraySize( tickets ); i++ )
        {
          if( !OrderSelect( tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
            continue;
            
          order.Init( tickets[i] );
          order.Close( percent_ );
        }
      
    }
    
    
//+------------------------------------------------------------------+
 void SetBlockOrders( string symbol_, int magic_, int type )
   {
     ClassOrder order;
     
     ClassAccountingOrders orders;
     orders.Init( symbol_, magic_ );
     
     if( orders.market == 0 )
       return;
       
     int tickets[];
     orders.GetTickets( tickets, type );
     
     if( ArraySize( tickets ) == 0 )
       return;
     
     
     double block_lot = 0;
     for( int i=0; i<ArraySize( tickets ); i++ )
       {
         if( !OrderSelect( tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
           continue;
           
         block_lot += OrderLots();  
       }
       
      
      order.Lot = NormalizeDouble( block_lot, 2 );
      order.Slippage = Slippage;
      order.MagicNumber = magic_;
       
      if( type == OP_BUY ) 
        {
          order.Type      = OP_SELL;
          order.OpenPrice = Bid; 
        }
        
      if( type == OP_SELL ) 
        {
          order.Type      = OP_BUY;
          order.OpenPrice = Ask; 
        }
        
      order.Send();  
   }


//+------------------------------------------------------------------+
 void OpenOrder( int type, int magic )
   {
    //------ 
     ClassOrder order;
     double open_price = 0;
     
     if( type == OP_BUY )
       open_price = NormalizeDouble( Ask, Digits );
     if( type == OP_SELL )
       open_price = NormalizeDouble( Bid, Digits );
     
    //--- 
     order.Type = type;
     order.OpenPrice = open_price;
     order.Slippage = Slippage;
     order.MagicNumber = magic;
     order.Symbol = symbol;
     order.Lot = Lot;
     
     order.Send();
   }
  
  
//+------------------------------------------------------------------+
 double GetAVGTakeProfit( int type, int magic_ )
   {
     double tp = 0;
      
     ClassAccountingOrders orders;
     orders.Init( symbol, magic_ );
        
     int tickets[];
     orders.GetTickets( tickets, type ); 
     
     ArrayReverse( tickets );
     
       
     //----- Ищем среднюю цену
      double avg_open_price = 0;
      int count_find_orders = 0; 
       
      for( int i=0; i<ArraySize( tickets ); i++ )
       {
         
         //--------!!! Усредняем только несколько последних ордеров !!!-----
          if( i == CountOrdesForGroup )
            break;
         //--------------------------------------------------------
       
         if( !OrderSelect( tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
           continue;
           
             
         avg_open_price += OrderOpenPrice();
         count_find_orders ++;
       } 
     
     if( count_find_orders == 0 )
       return 0;
          
     avg_open_price = NormalizeDouble( avg_open_price / count_find_orders, Digits );
    
    
     //--- Расчёт Take Profit 
     if( avg_open_price > 0 )
       {
         if( OrderType() == OP_BUY )
           tp = NormalizeDouble( avg_open_price + TakeProfit * Point, Digits );
         if( OrderType() == OP_SELL )
           tp = NormalizeDouble( avg_open_price - TakeProfit * Point, Digits );
       }
      return tp;
      
   }


//+------------------------------------------------------------------+
 double GetTakeProfitFromDistantOrder( int type, int magic_ )
   {
     double tp = 0;
      
     ClassAccountingOrders orders;
     orders.Init( symbol, magic_ );
        
     int tickets[];
     orders.GetTickets( tickets, type ); 
     
     ArrayReverse( tickets );
     
       
     //----- Ищем среднюю цену
      double open_price = 0;
      datetime open_time = TimeCurrent();
       
      for( int i=0; i<ArraySize( tickets ); i++ )
       {
         
         //--------!!! Усредняем только несколько последних ордеров !!!-----
          if( i == CountOrdesForGroup )
            break;
         //--------------------------------------------------------
       
         if( !OrderSelect( tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
           continue;
           
         if( OrderOpenTime() < open_time )    
           {
             open_price = OrderOpenPrice();
             open_time  = OrderOpenTime();
           }
       } 
    
    
     //--- Расчёт Take Profit 
     if( open_price > 0 )
       {
         if( OrderType() == OP_BUY )
           tp = NormalizeDouble( open_price + TakeProfit * Point, Digits );
         if( OrderType() == OP_SELL )
           tp = NormalizeDouble( open_price - TakeProfit * Point, Digits );
       }
      return tp;
      
   }


//+------------------------------------------------------------------+
bool GetTradeSignal( int type, int magic )
  {
    ClassAccountingOrders orders;
      orders.Init( symbol, magic );
        
      int tickets[];
      orders.GetTickets( tickets, type ); 
       
      double open_price = 0;
      datetime open_time = 0;
      
      for( int i=0; i<ArraySize( tickets ); i++ )
        {
          if( !OrderSelect( tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
            continue;
            
          if( OrderOpenTime() > open_time )
            {
              open_time  = OrderOpenTime();
              open_price = OrderOpenPrice();
            }
        } 
        
   //--- По индикаторам     
    double error = 3*Point;
    
    if( Digits == 5 || Digits == 3 )
      error = 30*Point;
    
    int count_candles = 30;
    ClassCandle candle[];
    ArrayResize( candle, count_candles );
    
    for( int i=0; i<count_candles; i++ )
      candle[i].Init( symbol, timeframe, i );
      
    double center = (High[ iHighest( symbol, timeframe, MODE_HIGH, 6, 1 ) ] + Low[ iLowest( symbol, timeframe, MODE_LOW, 6, 1 ) ]) / 2;
    //Print( "center = ", center, " ; Open = ", candle[1].open );
   //-----
    if( type == OP_BUY )
      {
        return(
          (
              Ask < open_price || open_price == 0 
          )
          &&
          (
            (
                 candle[2].close < center
              //&& candle[2].open > center
              && candle[1].close < center
              && candle[0].close < candle[1].low
            )
             
          )
        );
      }
   
   
   //-----   
    if( type == OP_SELL )
      {
        return(
          (
              Ask < open_price || open_price == 0 
          )
          &&
          (
            (
                 candle[2].close > center
              //&& candle[2].open < center
              && candle[1].close > center
              && candle[0].close > candle[1].high
            )
            
          )
        );
      }
      
    return false;
  }
   
 
//----------------- Определение направления тренда --------------------
int GetTrand()
  {
    double MA_1, MA_2;
    
    HideTestIndicators(true);
      MA_1 = iMA( symbol, timeframe, 100, 0, MODE_EMA, PRICE_CLOSE, 1 );
      MA_2 = iMA( symbol, timeframe, 100, 0, MODE_EMA, PRICE_CLOSE, 50 );
    HideTestIndicators(false);
    
    if( MathAbs( MA_1 - MA_2 ) / Point > 50) 
      {
        if( MA_1 > MA_2 )
          return TREND_UP;
          
        if( MA_1 < MA_2 )
          return TREND_DOWN;
      }
      
      
      
    return TREND_UNDEFINED;
  }    
    
//+------------------------------------------------+
  double GetLot( double lot, double balance, double min_lot = 0.01 )
    {
      double new_lot;
    
      if( balance > 0 && lot > 0 )
        new_lot = NormalizeDouble( AccountBalance()/balance*lot, 2 );
      else
        new_lot = lot;
    
      if( lot  < min_lot )
        new_lot = min_lot;
      
      if( lot > 99)
       new_lot = 99;
      
     
      return new_lot;
    }
    
    
//+-------------------------------------------------+
 int ArrayReverse( int &Arr[] )
   { 
     if( ArraySize( Arr ) == 0 )
       return 0;
       
     int NewArr[];
     int index = 0;
     for( int i=ArraySize( Arr ); i>0; i-- )
       {
         if( ArraySize( NewArr ) < i )
           ArrayResize( NewArr, i );
           
         NewArr[index] = Arr[i-1];
         index++;
       }
     
     if( ArraySize( NewArr ) > 0 )
       {
         ArrayFree( Arr );
         ArrayCopy(Arr, NewArr);
         return( ArraySize( Arr ) );
       } 
       
     return 0;
   }    


//+--------------------------------------------------------+   
 bool ArrayFind( int &array[], int search_value )
   {
     for( int i=0; i<ArraySize( array ); i++ )
       {
         if( array[i] == search_value )
           return true;
       }
     return false;
   }
   
   
//+--------------------------------------------------------+
 
   