//+------------------------------------------------------------------+
//|                                                        BoxEA.mq4 |
//|                                                           Alex G |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Alex G"
#property link      ""
#property version   "1.00"
#property strict

#include "../Classes/ClassAccountingOrders.mqh"
#include "../Classes/ClassOrder.mqh"
#include "../Classes/ClassCandle.mqh"
#include "../Classes/ClassCandlePatterns.mqh"
#include "../Classes/ClassNotification.mqh"
#include "../Classes/ClassLot.mqh"
#include "../Classes/ClassTrenderPatterns.mqh"
#include "../Classes/ClassTrender.mqh"
#include "../Lib/TraillingStop.mqh"
#include "../Lib/Array.mqh"

//===================== Inputs =============================
  input int InpMagic                = 0312;            // ID EA
  
 input string   STR1="---------- Volume ----------";   //.
  input double   InpLot             = 0.1;             // Lot
  input double   InpBalance         = 1000.0;          // Balance ( if zero then Lot - fixed )
  
 input string   STR2="---------- Open order settings ----------";  //.
  input double   InpDistanceToOrder = 2;               // Distance to order (%)
  input double   InpDistanceToSL    = 2;               // Distance to stoploss (%)
  input int      InpSlippage        = 20;              // Max slippage
 
 input string   STR3="---------- Indicator settings ----------";  //. 
   int      InpIndicatorPeriod = 50;              // Period
  input int      InpTrenderPeriod_fast       = 12;        // Period Fast
  input int      InpTrenderPeriod_slow       = 50;        // Period Slow
  
 input string   STR4="---------- Trailling settings ----------";  //. 
  input bool     InpUseTrall        = false;            // Use trailling stop
  input int      InpTrallDistance   = 10;              // Distance
  input int      InpTrallStep       = 10;              // Step
  input bool     InpTrallBreakeven  = false;           // Trsll to breakeven
  
 input string   STR5="---------- Targets ----------";  //.
  input double   InpTarget1=50;                     // Target 1 (%)
  input double   InpTarget2=100;                    // Target 2 (%)
  input double   InpTarget3=200;                    // Target 3 (%)
  input double   InpTarget4=300;                    // Target 4 (%)
  
   
//====================== Класс с настройками ========================  
  
  class ClassSettings
    {
      public:
        int Magic,
            Slippage,
            IndicatorPeriod,
            TrallDistance,
            TrallStep,
            TrenderPeriodFast,
            TrenderPeriodSlow,
            Timeframe;
            
        double Lot,
               Balance,
               TargetBuy[],
               TargetSell[],
               DistanceToOrder,
               DistanceToSL;
               
        bool TrallBreackeven,
             TrallUse;
             
        string Symbol; 
             
    }; 
  
  ClassSettings Settings; 
  
//====================== Глобальные переменные =======================

 ClassTrenderPatterns  TrendPattern;
 ClassTrender TrenderFast, TrenderSlow;
 
 ClassAccountingOrders Orders;
 ClassOrder Order[];
 
 bool newCandle = false;
  datetime dt_last = 0,
           dt_curr = 0;
 
 double LastLot = 0;
 
 string indicator_path = "MyInduks/Trender";
 
 ClassLot Lot;
 //ClassCandlePatterns Pattern;
//+------------------------------------------------------------------+
int OnInit()
  {
   //----- Перегрузка настроек -----
    Settings.Balance         = InpBalance;
    Settings.Magic           = InpMagic;
    Settings.DistanceToOrder = InpDistanceToOrder;
    Settings.DistanceToSL    = InpDistanceToSL;
    Settings.Lot             = InpLot;
    Settings.Slippage        = InpSlippage; 
    Settings.IndicatorPeriod = InpIndicatorPeriod;
    Settings.TrallUse        = InpUseTrall;
    Settings.TrallDistance   = InpTrallDistance;
    Settings.TrallStep       = InpTrallStep;
    Settings.TrallBreackeven = InpTrallBreakeven;
    Settings.TrenderPeriodSlow     = InpTrenderPeriod_slow;
    Settings.TrenderPeriodFast     = InpTrenderPeriod_fast;
    
    GetTargetsToArray( Settings.TargetBuy );
    GetTargetsToArray( Settings.TargetSell );
    
    Settings.Symbol    = Symbol();
    Settings.Timeframe = PERIOD_CURRENT;
    
    Lot.SetType_LotForBalance( Settings.Lot, Settings.Balance, true );
    TrendPattern.Init( Settings.IndicatorPeriod, Settings.Symbol, Settings.Timeframe );
    
    TrenderFast.Init( Settings.Symbol, Settings.Timeframe, Settings.TrenderPeriodFast );
    TrenderSlow.Init( Settings.Symbol, Settings.Timeframe, Settings.TrenderPeriodSlow );
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   //------------- Мониторинг новой свечи -----------
    dt_curr = iTime( Settings.Symbol, Settings.Timeframe, 0 );
   
    newCandle = dt_last != dt_curr; 
                     
    if( newCandle )
      dt_last = dt_curr;
      
    
    if( newCandle )
      OpenOrder(Order);
     
     
   //--- Отслеживание виртуальных отложенников  
    TrackOrders( Order );
      
   //--- Отслеживание целей   
    TrackTargets();
    
      
    
  //----- Трейлинг стоп    
    if( Settings.TrallUse )
      TraillingStop( Settings.Symbol, 
                     Settings.Magic, 
                     NULL, 
                     Settings.TrallStep, 
                     Settings.TrallDistance, 
                     Settings.TrallBreackeven );  
        
   
  }
  
  
  
//+------------------------------------------------------------------+
 void OpenOrder( ClassOrder &order[] )
  {
    //ArrayFree( order );
  //--- Переменная, для хранения индекса выбранного ордера  
    int select_order = -1;  
    
  //--- Перебираем все ордера в массиве и ищем свободный объект, если находим, то выходим из цикла     
   for( int i=0; i<ArraySize( order ); i++ )
     {
      if( order[i].Type == -1 )
       {
         select_order = i;
         break;
       }
     }
     
  //--- Если пустых ордеров не осталось, то создаем ещё один в конце массива   
    if( select_order == -1 )
      {
       int size = ArraySize( order );
       ArrayResize( order, size + 1 );
       select_order = size;
      }
    
    OpenOrderForDoubleTrender( order[select_order], OP_BUY );
    OpenOrderForDoubleTrender( order[select_order], OP_SELL );
    
  }


//+------------------------------------------------------------------+
 void OpenOrderForDoubleTrender( ClassOrder &order, int type )
  { 
    
    order.Clear();
    
    order.MagicNumber = Settings.Magic;
    order.Symbol      = Settings.Symbol;
    order.Slippage    = Settings.Slippage;
    
    ClassCandle candle[];
    ArrayResize( candle, 5 );
    for( int i=0; i<ArraySize( candle ); i++ )
      candle[i].Init( Settings.Symbol, Settings.Timeframe, i );
    
    bool onTrade = false;
    TrenderFast.GetCurrTrend();
    TrenderSlow.GetCurrTrend();
    
    switch( type )
      {
       //-----
        case OP_BUY: 
          {
            onTrade = ( 
              //   TrenderFast.GetCurrTrend() == TREND_UP 
              //&& TrenderSlow.GetCurrTrend() == TREND_UP 
              //&& candle[1].direction == CANDLE_UP
                 candle[1].close > TrenderFast.line[1]
              && candle[1].open  < TrenderFast.line[1]   
              && candle[1].close > TrenderSlow.line[1]
              && !( 
                       candle[1].high > TrenderFast.line[1] 
                    && candle[1].high > TrenderSlow.line[1]
                    && candle[1].low < TrenderFast.line[1]
                    && candle[1].low < TrenderSlow.line[1]
                  )
            );
            
            if( !onTrade ) return;
            
            double open_price = candle[1].high,
                   sl         = TrenderSlow.line[1],
                   dist       = MathAbs( open_price - sl );
                   
            //if( InpTypeStoploss == TYPE_CALC_SL::SL_EXT )
            //  sl = Low[ iLowest( Settings.Symbol, Settings.Timeframe, MODE_LOW, 5, 1 ) ];
              
            
            order.Type      = OP_BUYSTOP;
            order.OpenPrice = open_price + dist * Settings.DistanceToOrder/100;
            order.StopLoss  = sl - dist * Settings.DistanceToSL/100;
            order.TakeProfit = order.OpenPrice + ( MathAbs( order.OpenPrice - order.StopLoss ) * Settings.TargetBuy[ ArrayMaximum( Settings.TargetBuy ) ] );
            
            break;  
          }
          
          
       //-----   
        case OP_SELL:
          {
            onTrade = ( 
              //   TrenderFast.GetCurrTrend() == TREND_DOWN 
              //&& TrenderSlow.GetCurrTrend() == TREND_DOWN 
              //&& candle[1].direction == CANDLE_DOWN
                 candle[1].close < TrenderFast.line[1]
              && candle[1].open  > TrenderFast.line[1]
              && candle[1].close < TrenderSlow.line[1]
              && !( 
                       candle[1].high > TrenderFast.line[1] 
                    && candle[1].high > TrenderSlow.line[1]
                    && candle[1].low < TrenderFast.line[1]
                    && candle[1].low < TrenderSlow.line[1]
                  )
            );
            
            if( !onTrade ) return;
            
            double open_price = candle[1].low,
                   sl         = TrenderSlow.line[1],
                   dist       = MathAbs( open_price - sl );
                   
            //if( InpTypeStoploss == TYPE_CALC_SL::SL_EXT )
            //  sl = High[ iHighest( Settings.Symbol, Settings.Timeframe, MODE_HIGH, 5, 1 ) ];
            
            order.Type      = OP_SELLSTOP;
            order.OpenPrice = open_price - dist * Settings.DistanceToOrder/100;
            order.StopLoss  = sl + dist * Settings.DistanceToSL/100;
            order.TakeProfit = order.OpenPrice - ( MathAbs( order.OpenPrice - order.StopLoss ) * Settings.TargetSell[ ArrayMaximum( Settings.TargetSell ) ] );
            
            break;  
          }
          
          if( order.OpenPrice == 0 )
            {
              //order.Lot = Lot.GetLot();
              //order.Send();
              
              order.Clear();
              return;
            }
          
      }
    
  }
//+------------------------------------------------------------------+
 void TrackOrders( ClassOrder &order[] )
   {
     for(int i=0; i<ArraySize( order ); i++)
       {
         switch( order[i].Type )
          {
           case OP_BUYSTOP:  { if( Ask > order[i].OpenPrice ) order[i].Type = OP_BUY; break; }
           case OP_SELLSTOP: { if( Bid < order[i].OpenPrice ) order[i].Type = OP_SELL; break; }
           case OP_BUYLIMIT: { if( Ask < order[i].OpenPrice ) order[i].Type = OP_BUY; break; }
           case OP_SELLLIMIT:{ if( Bid > order[i].OpenPrice ) order[i].Type = OP_SELL; break; }
          }    
              
              
         if( order[i].Type == OP_BUY || order[i].Type == OP_SELL )
          {
            order[i].Lot = Lot.GetLot();
            order[i].Send();
            order[i].Clear();
          } 
          
       } 
    }
    
 //+---------------------------------------------------------------------------+
  void TrackTargets()
    {
      ClassOrder order;
    
      ClassAccountingOrders orders;
      int tickets[];
      
      orders.Init( Settings.Symbol, Settings.Magic );
      orders.GetTickets( tickets, OP_MARKET );
      
      for( int i=0; i<ArraySize( tickets ); i++ )
        {
          order.Init( tickets[i] );
          TrackTargetsOrder( order );
        }
      
    }
 
 //+------------------------------------------------------------------+
 void TrackTargetsOrder( ClassOrder &order )
   {
     double targets[];
     GetTargetsToArray( targets );
     
     if( ArraySize(targets) < 2 )
       return;
     
     ClassAccountingOrders orders;
     orders.Init( Settings.Symbol, Settings.Magic );
     
     double sl_size = MathAbs( (order.OpenPrice - order.TakeProfit) / targets[ ArraySize(targets) - 1 ] ); //-- Размер стоп-лосса
     
    //------- 
     if( order.Type == OP_BUY )
       {   
       
        //---    
         if( ArraySize( targets ) == 4 )
           {
             if( order.StopLoss < order.OpenPrice + sl_size * targets[1] && Bid > order.OpenPrice + sl_size * targets[2] )
               {
                 order.StopLoss = order.OpenPrice + sl_size * targets[1];
                 if( order.Modify() )
                     order.Close(50);
               }  
           }  
       
        //---    
         if( ArraySize( targets ) == 3 )
           {
             if( order.StopLoss < order.OpenPrice + sl_size * targets[0] && Bid > order.OpenPrice + sl_size * targets[1] )
               {
                 order.StopLoss = order.OpenPrice + sl_size * targets[0];
                 if( order.Modify() )
                     order.Close(50);
               }  
           }
       
        //---
         if( order.StopLoss < order.OpenPrice && Bid > order.OpenPrice + sl_size * targets[0] )
           {
             order.StopLoss = order.OpenPrice;
             if( order.Modify() )
                 order.Close(50);
           }
           
       }
           
    //-----   
     if( order.Type == OP_SELL )
       {     
       
        //---    
         if( ArraySize( targets ) == 4 )
           {
             if( order.StopLoss > order.OpenPrice - sl_size * targets[1] && Ask < order.OpenPrice - sl_size * targets[2] )
               {
                 order.StopLoss = order.OpenPrice - sl_size * targets[1];
                 if( order.Modify() )
                     order.Close(50);
               }  
           }  
       
        //---    
         if( ArraySize( targets ) == 3 )
           {
             if( order.StopLoss > order.OpenPrice - sl_size * targets[0] && Ask < order.OpenPrice - sl_size * targets[1] )
               {
                 order.StopLoss = order.OpenPrice - sl_size * targets[0];
                 if( order.Modify() )
                     order.Close(50);
               }  
           }
          
        //---  
         if( order.StopLoss > order.OpenPrice && Ask < order.OpenPrice - sl_size * targets[0] )
           {
             order.StopLoss = order.OpenPrice;
             if( order.Modify() )
                 order.Close(50);
           }
     }     
     
   }


//+----------------------------------------------------+
 void GetTargetsToArray( double &targets[] )
   {
     ArrayFree( targets );
     if( InpTarget1 > 0 )
       ArrayPush( targets, InpTarget1/100 );
     if( InpTarget2 > 0 )
       ArrayPush( targets, InpTarget2/100 );
     if( InpTarget3 > 0 )
       ArrayPush( targets, InpTarget3/100 );
     if( InpTarget4 > 0 )
       ArrayPush( targets, InpTarget4/100 );
       
     ArraySort( targets );
   }
  