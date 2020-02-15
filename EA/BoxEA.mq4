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
#include "../Classes/ClassNotification.mqh"
#include "../Classes/ClassLot.mqh"
#include "../Classes/ClassTrender.mqh"
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
  input int        InpMagic     = 2201;                       // ID EA;
  input TRADE_MODE InpTradeMode = TRADE_MODE::MODE_TWO_ORDER; // Mode trade
  
 input string   STR1=".";   //---------- Volume ----------
  input double   InpLot             = 0.5;             // Lot
  input double   InpBalance         = 0;               // Balance ( if zero, then Lot - fixed )
  input bool     InpNotReduce       = false;            // Do not reduce
  
 input string   STR2=".";  //---------- Open order settings ----------
  input double   InpDistanceToOrder = 2;               // Distance to order (%)
  input double   InpDistanceToSL    = 2;               // Distance to stoploss (%)
  input int      InpSlippage        = 20;              // Max slippage (pips)
  input double   InpMaxLoadDeposit  = 0;               // Max load deposit (%) If zero, then this check is not used 
   TYPE_CALC_SL InpTypeStoploss = TYPE_CALC_SL::SL_INDICATOR; // Type calculation stoploss
  
 
 input string   STR6=".";  //---------- Indicator settings ----------  
  input int      InpTrenderPeriod_fast = 12;        // Period for signal
  input int      InpTrenderPeriod_slow = 50;        // Period for trend
  
  
 input string   STR8=".";  //---------- Targets ----------
  input double   InpTarget1 = 61.8;                      // Target 1 (%)
  input double   InpTarget2 = 161.8;                     // Target 2 (%)
  input double   InpTarget3 = 223.6;                     // Target 3 (%)
  input double   InpTarget4 = 300;                       // Target 4 (%)
  
 input string   STR9=".";  //---------- Close All Orders ----------
  input string sss = "If zero, then this check is not used"; //.
  input double InpProfitForClose = 0;            // Profit for close all orders (%)
  input double InpMaxDD          = 0;            // Max drawdown (%)
   
//====================== Класс с настройками ========================  
  
  class ClassSettings
    {
      public:
        int Magic,
            Slippage,
            TrenderPeriodFast,
            TrenderPeriodSlow,
            MaxChanelWidth,
            TrallDistance,
            TrallStep,
            MaxStoplossSize,
            Timeframe;
            
        double Lot,
               Balance,
               TargetBuy[],
               TargetSell[],
               DistanceToOrder,
               DistanceToSL,
               ProfitForClose,
               MaxDrawdown,
               MaxLoadDeposit;
             
        string Symbol; 
        bool Lot_NotReduce;
        
        TRADE_MODE TradeMode;
             
    }; 
  
  ClassSettings Settings; 
  
//====================== Глобальные переменные =======================

 ClassAccountingOrders Orders;
 ClassOrder            OrderBuy, OrderSell;
 
 ClassLot              Lot;
 
 ClassTrender TrenderSlow, TrenderFast;
 ClassInfoPanelProfit  PanelProfit;
 
 ClassTargets Targets;
 
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
    NameEA = "Trender EA";
  
    OrderBuy.Clear();
    OrderSell.Clear();
  
   //----- Перегрузка входных параметров -----
    Settings.Balance               = InpBalance;
    Settings.Magic                 = InpMagic;
    Settings.DistanceToOrder       = InpDistanceToOrder;
    Settings.DistanceToSL          = InpDistanceToSL;
    Settings.Lot                   = InpLot;
    Settings.Slippage              = InpSlippage; 
    Settings.TrenderPeriodSlow     = InpTrenderPeriod_slow;
    Settings.TrenderPeriodFast     = InpTrenderPeriod_fast;
    Settings.ProfitForClose        = InpProfitForClose;
    Settings.MaxDrawdown           = InpMaxDD;
    Settings.MaxLoadDeposit        = InpMaxLoadDeposit;
    Settings.Lot_NotReduce         = InpNotReduce;
    Settings.TradeMode             = InpTradeMode;
    
    
   //--- Настройка Символа и периода 
    Settings.Symbol    = Symbol();
    Settings.Timeframe = PERIOD_CURRENT;
    
    
   //--- Настройки промежуточных целей 
    Targets.Set( InpTarget1/100 );
    Targets.Set( InpTarget2/100 );
    Targets.Set( InpTarget3/100 );
    Targets.Set( InpTarget4/100 );
    
    Targets.GetToArray( Settings.TargetBuy );
    Targets.GetToArray( Settings.TargetSell );
    
    
   //--- Тип расчёта лота 
    Lot.SetType_LotForBalance(Settings.Lot, Settings.Balance, Settings.Lot_NotReduce );
    
    TrenderFast.Init( Settings.Symbol, Settings.Timeframe, Settings.TrenderPeriodFast );
    TrenderSlow.Init( Settings.Symbol, Settings.Timeframe, Settings.TrenderPeriodSlow );
    
    
    
   //--- Создание инфо панели
    if( IsVisualMode() || !IsTesting() ) 
      PanelProfit.Create( NameEA ); 
      
   
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
    
   //--- Проверка загрузки депозита
    if( Settings.MaxLoadDeposit > 0 )
      fine_load_depo = ( AccountMargin()/AccountEquity()*100 ) < Settings.MaxLoadDeposit; 
    
    
   //---------- OPEN ORDERS ----------
    if( newCandle && fine_load_depo )
      {         
      
       //--- Открытие ордеров 
        Orders.Init( Settings.Symbol, Settings.Magic);
        
       //--- Получение разрешения для формирования сделок 
        onTradeBuy = (
             ( Settings.TradeMode == TRADE_MODE::MODE_ONE_ORDER && Orders.market == 0 )
          || ( Settings.TradeMode == TRADE_MODE::MODE_TWO_ORDER && Orders.buy == 0 )  
          || ( Settings.TradeMode == TRADE_MODE::MODE_GRID )  
        );
        
        onTradeSell = (
             ( Settings.TradeMode == TRADE_MODE::MODE_ONE_ORDER && Orders.market == 0 )
          || ( Settings.TradeMode == TRADE_MODE::MODE_TWO_ORDER && Orders.sell == 0 )  
          || ( Settings.TradeMode == TRADE_MODE::MODE_GRID )  
        );
        
        
        
        if( onTradeBuy )
          OpenOrder( OrderBuy,  OP_BUY );
                   
        if( onTradeSell ) 
          OpenOrder( OrderSell, OP_SELL ); 
            
       }
     
    
  //------- TRECK ORDERS -------  
   TrackOrder( OrderBuy );
   TrackOrder( OrderSell );
   
  //------ TRECK TARGETS 
   if( Settings.TradeMode == TRADE_MODE::MODE_GRID )
     Targets.TrackTargetsForGrid( Settings.Symbol, Settings.Magic ); 
   else
      Targets.TrackTargets( Settings.Symbol, Settings.Magic );
   
         
  
                     
  //--- UPDATE DATA FOR PANEL
   if( IsVisualMode() || !IsTesting() )  
     PanelProfit.Update(NULL);         
     
  }


//+------------------------------------------------------------------+
 void OpenOrder( ClassOrder &order, int type )
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
    
    double border_h = High[ iHighest( Settings.Symbol, Settings.Timeframe, MODE_HIGH, 5, 1 ) ],
           border_l = Low[ iLowest( Settings.Symbol, Settings.Timeframe, MODE_LOW, 5, 1 ) ],
           center   = (border_h + border_l) / 2;
    
    switch( type )
      {
       //-----
        case OP_BUY: 
          {
            onTrade = ( 
              (
                   candle[1].close > TrenderFast.line[1]
                && candle[1].open  < TrenderFast.line[1]   
                && candle[1].close > TrenderSlow.line[1]
                //&& candle[2].direction == CANDLE_UP
                && !( 
                         candle[1].high > TrenderFast.line[1] 
                      && candle[1].high > TrenderSlow.line[1]
                      && candle[1].low < TrenderFast.line[1]
                      && candle[1].low < TrenderSlow.line[1]
                    )
              )     
             
            );
            
            if( !onTrade ) return;
            
            double open_price = candle[1].high,
                   sl         = TrenderSlow.line[1],
                   dist       = MathAbs( open_price - sl );
                   
            if( open_price < sl )
              sl = Low[ iLowest( Settings.Symbol, Settings.Timeframe, MODE_LOW, 5, 1 ) ];
              
            
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
              (
                   candle[1].close < TrenderFast.line[1]
                && candle[1].open  > TrenderFast.line[1]
                && candle[1].close < TrenderSlow.line[1]
                //&& candle[2].direction == CANDLE_DOWN
                && !( 
                         candle[1].high > TrenderFast.line[1] 
                      && candle[1].high > TrenderSlow.line[1]
                      && candle[1].low < TrenderFast.line[1]
                      && candle[1].low < TrenderSlow.line[1]
                    )
              )
            );
            
            if( !onTrade ) return;
            
            double open_price = candle[1].low,
                   sl         = TrenderSlow.line[1],
                   dist       = MathAbs( open_price - sl );
                   
            if( open_price > sl )
              sl = High[ iHighest( Settings.Symbol, Settings.Timeframe, MODE_HIGH, 5, 1 ) ];
              
              
            
            order.Type      = OP_SELLSTOP;
            order.OpenPrice = open_price - dist * Settings.DistanceToOrder/100;
            order.StopLoss  = sl + dist * Settings.DistanceToSL/100;
            order.TakeProfit = order.OpenPrice - ( MathAbs( order.OpenPrice - order.StopLoss ) * Settings.TargetSell[ ArrayMaximum( Settings.TargetSell ) ] );
            
            break;  
          }
          
      }
      
    
     /*     
     if( order.OpenPrice > 0 )
       {
         order.Clear();
         return;
       }  
     */
       
     if( Settings.TradeMode == TRADE_MODE::MODE_GRID )
      order.StopLoss = 0;  
    
  }

//+------------------------------------------------------------------+
 bool TrackOrder( ClassOrder &order )
   {
    //-----
     if(order.Type == OP_BUYSTOP)
       {
        //---
         if( Ask > order.OpenPrice )
           {
             order.Type = OP_BUY;
             order.Lot  = Lot.GetLot();
             order.Send();
             order.Clear();
             
             return true;
           }
           
        //--- Trailling open order   
       }
       
    //-----   
     if(order.Type == OP_SELLSTOP)
       {
        //---
         if( Bid < order.OpenPrice )
           {
             order.Type = OP_SELL;
             order.Lot  = Lot.GetLot();
             order.Send();
             order.Clear();
             
             return true;
           }
        
        //--- Trailling open order   
       }
         
     //-----
     if(order.Type == OP_BUYLIMIT)
       {
        //---
         if( Ask < order.OpenPrice )
           {
             order.Type = OP_BUY;
             order.Lot  = Lot.GetLot();
             order.Send();
             order.Clear();
             
             return true;
           }
       }
       
    //-----   
     if(order.Type == OP_SELLLIMIT)
       {
        //---
         if( Bid > order.OpenPrice )
           {
             order.Type = OP_SELL;
             order.Lot  = Lot.GetLot();
             order.Send();
             order.Clear();
             
             return true;
           }
       }  
       
     return false;  
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