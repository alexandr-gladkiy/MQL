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
#include "../Classes/ClassNotification.mqh"
#include "../Classes/ClassInfoPanelProfit.mqh"
#include "../Classes/ClassTargets.mqh"

enum TYPE_CALC_SL
  {
    SL_INDICATOR, // Indicator Slow
    SL_EXT        // Extremum
    
  };
  
enum TRADE_MODE
  {
    MODE_GRID,      // Grid
    MODE_ONE_ORDER, // One order
    MODE_TWO_ORDER  // Two orders
    
  };  


//===================== Inputs =============================
  input int      InpMagic     = 0;                       // ID orders;
  
 input string   STR1=".";  //---------- Fixed Stopes ----------
  input int      InpFixedSL         = 0;               // Fixed stoploss
  input int      InpFixedTP         = 0;               // Fixed takeprofit
  
 input string   STR2=".";  //---------- Stoploss settings ----------
  input int      InpCountBarsForSL  = 25;              // Count bars for calculation stoploss
  input double   InpDistanceToSL    = 5;               // Error (%)
  
 input string   STR8=".";  //---------- Targets ----------
  input double   InpTarget1 = 61.8;                      // Target 1 (%)
  input double   InpTarget2 = 161.8;                     // Target 2 (%)
  input double   InpTarget3 = 223.6;                     // Target 3 (%)
  input double   InpTarget4 = 300;                       // Target 4 (%)
  input bool     InpPartialClosing = true;               // Partial closing of orders
  
 input string   STR9=".";  //---------- Close All Orders ----------
  //input string sss = "If zero, then this check is not used"; //.
  input double InpProfitForClose = 0;            // Profit for close all orders (%)
  input double InpMaxDD          = 0;            // Max drawdown (%)
   
//====================== Класс с настройками ========================  
  
  class ClassSettings
    {
      public:
        int Magic,
            Timeframe,
            CountBarsForSL,
            FixedSL,
            FixedTP;
           
            
        double TargetBuy[],
               TargetSell[],
               DistanceToSL,
               ProfitForClose,
               MaxDrawdown;
             
        string Symbol; 
        bool Lot_NotReduce,
             PartialClosing;
        
        TRADE_MODE TradeMode;
             
    }; 
  
  ClassSettings Settings; 
  
//====================== Глобальные переменные =======================

 ClassInfoPanelProfit  PanelProfit;
 ClassTargets Targets;
 ClassNotification Notify;
 
 bool newCandle = false;
 datetime dt_last = 0,
          dt_curr = 0;
          
 bool fine_load_depo = true;
 
 string NameEA, Email, AuthorNameFull, AuthorNik;
 
 bool onTradeBuy = false,
      onTradeSell = false;
      
 string ch = "zxcvbnm,.asdfghjkl;'qwertyuiop[]1234 567890-=ZXCVBNM<>?ASDFGHJKL:QWERTYUIOP{}!@#$%^&*()_+";     
      
 bool Validate = false; 
 
//+------------------------------------------------------------------+
int OnInit()
  {
    NameEA = "Stop controller";
  
   //----- Перегрузка входных параметров -----
    Settings.Magic                 = InpMagic;
    Settings.DistanceToSL          = InpDistanceToSL;
    Settings.ProfitForClose        = InpProfitForClose;
    Settings.MaxDrawdown           = InpMaxDD;
    Settings.CountBarsForSL        = InpCountBarsForSL;
    Settings.FixedSL               = InpFixedSL;
    Settings.FixedTP               = InpFixedTP;
    Settings.PartialClosing        = InpPartialClosing;
    
    
   //--- Настройка Символа и периода 
    Settings.Symbol    = NULL;
    Settings.Timeframe = PERIOD_CURRENT;
    
    
   //--- Настройки промежуточных целей 
    Targets.Clear();
    Targets.Set( InpTarget1 );
    Targets.Set( InpTarget2 );
    Targets.Set( InpTarget3 );
    Targets.Set( InpTarget4 );
    Targets.CloseOrder = Settings.PartialClosing;
    
    Targets.GetToArray( Settings.TargetBuy );
    Targets.GetToArray( Settings.TargetSell );
    
    
   //--- Создание инфо панели
    if( IsVisualMode() || !IsTesting() ) 
      {
        PanelProfit.Create( NameEA ); 
        //Targets.DrawTargets = true;
      }
      
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Удаление инфо панели
    if( IsVisualMode() || !IsTesting() ) 
      PanelProfit.Delete();
  }
//+------------------------------------------------------------------+
void OnTick()
  {
    bool spread_filter = Ask - Bid > NormalizeDouble( 80 * Point, Digits );
    if( IsTesting() && !Validate && spread_filter )
        Validate = MarketValidate();
    if( spread_filter )
      return;  
  
  
   //--- AUTO_CLOSE mode
    // Profit percent
    if( Settings.ProfitForClose > 0 )
      if( ( ( AccountEquity() - AccountBalance() ) / AccountBalance() * 100 ) >= Settings.ProfitForClose)
        CloseAllOrders();
    
    // Drawdown percent 
    if( Settings.MaxDrawdown > 0 )
      if( ( ( AccountEquity() - AccountBalance() ) / AccountBalance() * 100 ) <= -Settings.MaxDrawdown)
        CloseAllOrders();
  
  
   //------------- TRECK FOR OPEN NEW CANDLE -----------
    dt_curr = iTime( Settings.Symbol, Settings.Timeframe, 0 );
   
    newCandle = dt_last != dt_curr; 
                     
    if( newCandle )
      dt_last = dt_curr;
    
 
  //------- TRECK ORDERS -------  
   TrackOrders();
   
  //------ TRECK TARGETS    
   Targets.TrackTargets( Settings.Symbol, Settings.Magic, OP_MARKET );     
         
  
                     
  //--- UPDATE DATA FOR PANEL
   if( IsVisualMode() || !IsTesting() )  
     PanelProfit.Update(NULL);         
     
  }

//+------------------------------------------------------------------+
 void TrackOrders()
   {
     ClassAccountingOrders orders;
     ClassOrder order;
     
     int tickets[];
     orders.Init( NULL, Settings.Magic );
     orders.GetTickets( tickets, OP_MARKET );
     
     double sl_size = 0,
            sl = 0,
            tp = 0;
     
     for( int i=0; i<ArraySize(tickets); i++ )
      {
        order.Init( tickets[i] );
        if( order.StopLoss > 0 && order.TakeProfit > 0 )
         continue;
        
         
        switch( order.Type )
         {
           //---
            case OP_BUY:
              {
               if( order.StopLoss == 0 )
                  {
                   if( Settings.FixedSL <= 0 )
                     {
                        sl_size = MathAbs( order.OpenPrice - iLow( order.Symbol, Settings.Timeframe, iLowest( order.Symbol, Settings.Timeframe, MODE_LOW, Settings.CountBarsForSL, 1 ) ) );
                        order.StopLoss = order.OpenPrice - ( sl_size + sl_size*Settings.DistanceToSL/100 );
                     }
                   else
                     order.StopLoss = order.OpenPrice - Settings.FixedSL * MarketInfo( order.Symbol, MODE_POINT );
                  }
                  
               if( order.TakeProfit == 0 )
                  {
                     if( Settings.FixedTP <= 0 )
                        order.TakeProfit = order.OpenPrice + ( MathAbs( order.OpenPrice - order.StopLoss ) * Settings.TargetBuy[ ArrayMaximum( Settings.TargetBuy ) ] );
                     else
                        order.TakeProfit = order.OpenPrice + Settings.FixedTP * MarketInfo( order.Symbol, MODE_POINT );
                  } 
                  
               
               if( order.StopLoss > 0 && order.TakeProfit > 0 )
                  order.Modify();   
               return;   
              }
            
           //---
            case OP_SELL:
              {
               if( order.StopLoss == 0 )
                  {
                   if( Settings.FixedSL <= 0 )
                     {
                        sl_size = MathAbs( order.OpenPrice - iHigh( order.Symbol, Settings.Timeframe, iHighest( order.Symbol, Settings.Timeframe, MODE_HIGH, Settings.CountBarsForSL, 1 ) ) );
                        order.StopLoss = order.OpenPrice + ( sl_size + sl_size*Settings.DistanceToSL/100 );
                     }
                   else
                      order.StopLoss = order.OpenPrice + Settings.FixedSL * MarketInfo( order.Symbol, MODE_POINT );
                  }
                  
               if( order.TakeProfit == 0 )
                  {
                     if( Settings.FixedTP <= 0 )
                        order.TakeProfit = order.OpenPrice - ( MathAbs( order.OpenPrice - order.StopLoss ) * Settings.TargetBuy[ ArrayMaximum( Settings.TargetBuy ) ] );
                     else 
                        order.TakeProfit = order.OpenPrice - Settings.FixedTP * MarketInfo( order.Symbol, MODE_POINT );  
                  }
                  
                  
               if( order.StopLoss > 0 && order.TakeProfit > 0 )
                  order.Modify();
                  return;
              }
            
           //---
            default: return;
         }
      }
       
   }
 
 
   
  
//+----------------------------------------------------+
 void CloseAllOrders()
  {
    int tickets[];
    ClassAccountingOrders orders;
    orders.Init();
    
    ClassOrder order;
    
    orders.GetTickets( tickets, OP_MARKET );
    for( int i=0; i<ArraySize( tickets ); i++ )
      {
        order.Init( tickets[i] );
        order.Close();
      }
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
    order.StopLoss  = order.OpenPrice - 200*_Point;
    order.TakeProfit = order.OpenPrice + 200*_Point;
    order.Slippage = 1;
     
    t = order.Send();
    if( t > 0 && OrderSelect( t, SELECT_BY_TICKET, MODE_TRADES ) )
      if( OrderClose( t, OrderLots(), MarketInfo( Symbol(), MODE_BID ), 10 ) )
          return true; 
        
    return false;
  }     