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