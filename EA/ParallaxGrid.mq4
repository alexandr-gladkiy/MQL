//+------------------------------------------------------------------+
//|                                                 ParallaxGrid.mq4 |
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
#include "../Classes/ClassProfit.mqh"
#include "../Classes/ClassZigZagLevels.mqh"

#include "../Classes/ClassBasketOrders.mqh"
#include "../Classes/ClassInfoPanelProfit.mqh"


#define TREND_UP 1
#define TREND_DOWN 2
#define TREND_UNDEFINED 0

#define  Magic 12322211

input int TakeProfit = 200; // Take profit
    
input double Lot     = 0.01; // Volume  
input double Balance = 30; // For balance
       
input int CountOrdersForBasket = 3; // Count orders for group

//input double MaxDrawdown = 25;  // Maximum drawdown (%)

//------- Multi Curency ---------    
double MaxLoadDepositToPercent = 30;
double MaxPercentProfitPerDay = 10;
    
int Slippage = 10;
double MinLot = 1;

string LockOrderComment = "Locked Order";
    
    
//------------------------------------------
string symbol = Symbol();
int timeframe = PERIOD_CURRENT;

double ask, bid, spread, digits;

bool newCandle = false;
datetime dt_last = 0,
         dt_curr = 0;
         
ClassOrder order_buy,
           order_sell;
           
ClassBasketOrders BasketBuy[],
                  BasketSell[];

ClassAccountingOrders Orders;

ClassInfoPanelProfit InfoPanel;

bool Validate = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- create timer
     EventSetTimer(1);
     
     InitBaskets( BasketBuy, OP_BUY, CountOrdersForBasket, symbol, Magic ); 
     InitBaskets( BasketSell, OP_SELL, CountOrdersForBasket, symbol, Magic );
     
     InfoPanel.Create();
   
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   InfoPanel.Delete();
      
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
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
    {
      InitBaskets( BasketBuy, OP_BUY, CountOrdersForBasket, symbol, Magic ); 
      InitBaskets( BasketSell, OP_SELL, CountOrdersForBasket, symbol, Magic ); 
    }
   
  //------- Открытие ордеров / Инициализация корзин / Установка стопов   
   if( newCandle && GetPermissionTrade( OP_BUY ) )
     {
       order_buy.Type        = OP_BUY;
       order_buy.Lot         = GetLot( Lot, Balance );
       order_buy.OpenPrice   = MarketInfo( symbol, MODE_ASK );
       order_buy.Slippage    = Slippage;
       order_buy.MagicNumber = Magic;
       
       if( order_buy.Send() > 0 )
         InitBaskets( BasketBuy, OP_BUY, CountOrdersForBasket, symbol, Magic );
           
     } 
     
   if( newCandle && GetPermissionTrade( OP_SELL ) )
     {
       order_sell.Type        = OP_SELL;
       order_sell.Lot         = GetLot( Lot, Balance );
       order_sell.OpenPrice   = MarketInfo( symbol, MODE_BID );
       order_sell.Slippage    = Slippage;
       order_sell.MagicNumber = Magic;
       
       if( order_sell.Send() > 0 )
         InitBaskets( BasketSell, OP_SELL, CountOrdersForBasket, symbol, Magic );
     }  
     
   
   //--------- Проверка стопов в корзинах ----------
    for( int i=0; i<ArraySize( BasketBuy ); i++ )
      if( CheckBasketStop( BasketBuy[i] ) )
        {
          InitBaskets( BasketBuy, OP_BUY, CountOrdersForBasket, symbol, Magic );
          break;
        }
    
    for( int i=0; i<ArraySize( BasketSell ); i++ )
      if( CheckBasketStop( BasketSell[i] ) )
        {
          InitBaskets( BasketSell, OP_SELL, CountOrdersForBasket, symbol, Magic );
          break;
        }
    
    if( ArraySize( BasketBuy ) > 2 || ArraySize( BasketSell ) > 2 )  
      CloseMultidirectionOrders( 0 );
    
    //CloseDrawdown( MaxDrawdown );
    //LockDrawdown(MaxDrawdown);
    //TrackLockOrder();
    
     //InfoPanel.Update( symbol, Magic );
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
    
    InfoPanel.Update( symbol, Magic );
       
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {

   
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
      if( OrderClose( t, OrderLots(), MarketInfo( Symbol(), MODE_BID ), 10 ) )
          return true; 
        
    return false;
  }  
  
//+------------------------------------------------------------------+
bool CheckBasketStop( ClassBasketOrders &BO )
  { 
    if( ArraySize( BO.Tickets ) == 0 )
      return false;
   
     datetime open_time  = TimeCurrent();
     double   open_price = 0;
     ClassOrder Order;
     int cnt_orders = 0;
     
   //-------- Поиск цены ориентира для закрытия по Take Profit и установки безубытка
     for( int i=0; i<ArraySize(BO.Tickets); i++ )
       {
         if( OrderSelect( BO.Tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
           { 
             cnt_orders ++;
             open_price += OrderOpenPrice();
           
           /*
             if( OrderOpenTime() < open_time  )
               open_price = OrderOpenPrice();
               open_time  = OrderOpenTime();
           */
           }
       } 
      open_price /= cnt_orders;
      
   //-------- Проверка достижения уровня Take Profit 
    if( (open_price > 0) && (BO.type == OP_BUY) )
      if( Bid > open_price + TakeProfit * Point )
        {
          BO.Close();
          return true;
        }
        
    //---    
    if( (open_price > 0) && (BO.type == OP_SELL) )
      if( Ask < open_price - TakeProfit * Point )
        {
          BO.Close();
          return true;
        }
   //-------- Проверка условий для установки безубытка
    if( (open_price > 0) && (BO.type == OP_BUY) )
      if( Bid > open_price + TakeProfit/2 * Point )
        {
          for( int i=0; i<ArraySize(BO.Tickets); i++ )
            {
              Order.Init( BO.Tickets[i] );
              
              if( Order.StopLoss == 0 )
                {
                  Order.StopLoss = open_price;
                  Order.Modify();
                }
            }
            
          
          //CloseLossBasket( BO, 50 );
          BO.Close(50, MinLot);
             
          return true;
        }
        
    //---    
    if( (open_price > 0) && (BO.type == OP_SELL) )
      if( Ask < open_price - TakeProfit/2 * Point )
        {
          for( int i=0; i<ArraySize(BO.Tickets); i++ )
            {
              Order.Init( BO.Tickets[i] );
              
              if( Order.StopLoss == 0 )
                {
                  Order.StopLoss = open_price;
                  Order.Modify();
                }
            }
            
          
          //CloseLossBasket( BO, 50 );
          BO.Close(50, MinLot);
            
          return true;
        }
        
    return false;
  }

  
//+------------------------------------------------------------------+
void CloseLossBasket( ClassBasketOrders &BO, double max_loss_percent = 0 )
  {
    ClassAccountingOrders orders;
    Orders.Init( symbol, Magic );
    
    int Tickets[];
    Orders.GetTickets( Tickets, BO.type );
    
    if( ArraySize( Tickets ) == 0 )
      return;
      
    ArrayReverse( Tickets );
    
   //---- 
    double basket_profit = BO.GetProfit()/ 100 * max_loss_percent; //--- Сразу добавляем погрешность;
    
    for( int i=0; i<ArraySize( Tickets ); i++ )
      {
        if( basket_profit <= 0 )
          return;
          
        if(ArrayFind( BO.Tickets, Tickets[i] ))
          continue;
          
        if( OrderSelect( Tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
          {
            double lot = 0;
            double profit = OrderProfit() + OrderSwap() + OrderCommission();
            
            if( basket_profit - profit >= 0 )
              lot = OrderLots();
              
            if( basket_profit - profit < 0 )
              {
                lot = NormalizeDouble( OrderLots() * ( basket_profit / profit ), 2 );
                if( OrderLots() - lot < MinLot )
                  lot = OrderLots();
              }
              
            if( lot > 0 )
              {
                double close_price = 0;
                if( BO.type == OP_BUY )
                  close_price = Bid;
                if( BO.type == OP_SELL )
                  close_price = Ask;
                  
                if( !OrderClose( OrderTicket(), lot, close_price, Slippage,clrNONE ) )
                  Print( "Do not close order!" );
                else
                  basket_profit -= profit;
              }
          }
        
      }
      
  }  


//+------------------------------------------------------------------+  
int ArrayFind( int &arr[], int vol )
  {
    for( int i=0; i<ArraySize( arr ); i++ )
      if( vol == arr[i] )
        return i;
    
    return -1;
  }
  
//+------------------------------------------------------------------+  
double GetProfitInBasket( ClassBasketOrders &BO )
  {
    double profit = 0;
    for( int i=0; i<ArraySize( BO.Tickets ); i++ )
      {
        if( OrderSelect( BO.Tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
          profit += OrderProfit() + OrderSwap() + OrderCommission(); 
      }
    
    return profit;
  }


//+------------------------------------------------------------------+
void InitBaskets( ClassBasketOrders &BO[], int type, int count_orders_in_basket, string symbol_, int magic_ )
  { 
    ArrayFree( BO );
    int Tickets[];
    
    ClassAccountingOrders orders;
    orders.Init( symbol_, magic_ );
    
    orders.GetTickets( Tickets, type );
    
    if( ArraySize( Tickets ) == 0 )
      return;
    
    ArrayReverse( Tickets );
    
    int b = AddBasket( BO );
    int order_cnt = 0;
    for( int i=0; i<ArraySize( Tickets ); i++ )
      {
        if( !OrderSelect( Tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
          continue;
          
        if( OrderComment() == LockOrderComment )
          continue;
            
        if( order_cnt == CountOrdersForBasket )
          {
            b = AddBasket(BO);
            order_cnt = 0;
          }
          
        BO[b].Add( Tickets[i] ); 
        BO[b].type = type; 
        BO[b].ID   = b;
        
        order_cnt ++;
      }
    
  }
  
  
//+-------------------------------------------------------+  
 int AddBasket( ClassBasketOrders &BO[] )
   {
     int size = ArraySize( BO );
     ArrayResize( BO, size + 1 );
     
     return size;
   }
   
   
//+-------------------------------------------------------+
  bool GetPermissionTrade( int type )
    {
      bool AllowTrade = false;
      
      ClassCandle candle_1, candle_2, candle_3;
      candle_1.Init( symbol, timeframe, 1 );
      candle_2.Init( symbol, timeframe, 2 );
      candle_3.Init( symbol, timeframe, 3 );
      
      //ClassZigZagLevels ZZ_Levels;
      //ZZ_Levels.Init( symbol, 100, 12, timeframe );
      
       double MA_slow_1, MA_slow_2, MA_fast_1, MA_fast_2, CCI_1;
       
       HideTestIndicators( true );
        MA_slow_1 = iMA( symbol, timeframe, 24, 0, MODE_EMA, PRICE_CLOSE, 1 );
        MA_slow_2 = iMA( symbol, timeframe, 24, 0, MODE_EMA, PRICE_CLOSE, 2 );
        
        //MA_fast_1 = iMA( symbol, timeframe, 24, 0, MODE_EMA, PRICE_CLOSE, 1 );
        //MA_fast_2 = iMA( symbol, timeframe, 24, 0, MODE_EMA, PRICE_CLOSE, 2 );
        //CCI_1 = iCCI( symbol, timeframe, 36, PRICE_CLOSE, 1 );
       HideTestIndicators(false);  
       
       if( type == OP_BUY ) 
         {
           AllowTrade = ( //Divergence( OP_BUY )
                           // ZZ_Levels.ZZLevels[0].type == ZZ_LOW
                          //candle_1.close > MA_slow_1
                         //&& candle_1.open < MA_slow_1
                         //&& 
                         (
                           (   
                               candle_3.direction == CANDLE_DOWN
                            && candle_2.direction == CANDLE_UP
                            && candle_1.direction == CANDLE_UP
                            && candle_1.close >= candle_3.open 
                            && ( candle_1.shadow_bottom_percent > 70 || candle_2.shadow_bottom_percent > 70 )
                            && ( candle_1.shadow_top_percent < 5 || candle_2.shadow_top_percent < 5 )
                            //&& GetTrand() == TREND_UP
                           )/*
                           ||
                           (
                               candle_1.direction == CANDLE_UP
                            && candle_2.direction == CANDLE_DOWN
                            && candle_1.open  <= candle_2.close
                            && candle_1.close >= candle_2.open
                            && candle_1.body_percent > 80
                            && candle_2.body_percent > 70
                            && GetTrand() == TREND_DOWN 
                           )*/
                         )
                        );
         }
           
        if( type == OP_SELL ) 
          {
            AllowTrade = ( //Divergence( OP_SELL )
                             //ZZ_Levels.ZZLevels[0].type == ZZ_HIGH
                           //candle_1.close < MA_slow_1
                          //&& candle_1.open > MA_slow_1
                          //&&
                          (
                            (
                                candle_3.direction == CANDLE_UP
                             && candle_2.direction == CANDLE_DOWN
                             && candle_1.direction == CANDLE_DOWN
                             && candle_1.close <= candle_3.open
                             && ( candle_1.shadow_top_percent > 70 || candle_2.shadow_top_percent > 70 )
                             && ( candle_1.shadow_bottom_percent < 5 || candle_2.shadow_bottom_percent < 5 )
                             //&& GetTrand() == TREND_DOWN
                            )/*
                            ||
                            (
                                candle_1.direction == CANDLE_DOWN
                             && candle_2.direction == CANDLE_UP
                             && candle_1.open  >= candle_2.close
                             && candle_1.close <= candle_2.open 
                             && candle_1.body_percent > 80
                             && candle_2.body_percent > 80
                             && GetTrand() == TREND_UP
                            )*/
                          )
                         );
                                     
          }
         
         
      return AllowTrade;     
    }
    
//+------------------------------------------------+
  double GetLot( double lot, double balance )
    {
      double new_lot;
    
      if( balance > 0 && lot > 0 )
        new_lot = NormalizeDouble( AccountBalance()/balance*lot, 2 );
      else
        new_lot = lot;
    
      if( lot  < MinLot )
        new_lot = MinLot;
      
      if( lot > 99)
       new_lot = 99;
      
     
      return new_lot;
    }
    
//------------- Определение дивергенций и конвергенций ----------------
 bool Divergence( int type )
   {
     ClassZigZagLevels ZZ_Levels;
     ZZ_Levels.Init( symbol, 300, 6, timeframe );
     
     int candle_index_1 = ZZ_Levels.ZZLevels[0].index_bar,
         candle_index_2 = ZZ_Levels.ZZLevels[2].index_bar;
     
     ClassCandle candle_1, candle_2, candle_0;
     
     candle_1.Init(symbol, timeframe, candle_index_1);
     candle_2.Init(symbol, timeframe, candle_index_2);
     candle_0.Init(symbol, timeframe, 1);
         
     double MACD_1, MACD_2;
     
     HideTestIndicators( true );
       MACD_1 = iMACD( symbol, timeframe, 12, 26, 9, PRICE_CLOSE, 0, candle_index_1);
       MACD_2 = iMACD( symbol, timeframe, 12, 26, 9, PRICE_CLOSE, 0, candle_index_2 );
     HideTestIndicators(false); 
     
    //----- 
     if( type == OP_SELL )
       {
         return(
         
              MACD_1 > 0 && MACD_2 > 0
           && MACD_1 <= MACD_2
           && candle_1.high > candle_2.high  
           && candle_0.high < candle_1.high
           && candle_0.direction == CANDLE_DOWN
         
         );
       }  
    
    //-----   
     if( type == OP_BUY )
       {
         return(
         
              MACD_1 < 0 && MACD_2 < 0
           && MACD_1 >= MACD_2
           && candle_1.low < candle_2.low  
           && candle_0.low < candle_1.low
           && candle_0.direction == CANDLE_UP
           
         
         );
       }  
     
     return false;
   }
    

//+---------------- Закрытие разнонаправленных ордеров по достижении профита 0 - погрешность ------------
 void CloseMultidirectionOrders( double loss_percent )
   {
     ClassAccountingOrders orders;
     orders.Init( symbol, Magic );
     
     if( orders.buy > 0 && orders.sell > 0 )
       {
         int Tickets[];
         
         orders.GetTickets( Tickets, OP_MARKET );
         double profit = 0;
         
         for( int i=0; i<ArraySize( Tickets ); i++ )
           {
             if( OrderSelect( Tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
               profit += OrderProfit() + OrderSwap() + OrderCommission();
           }
           
         if( profit > profit + profit/100*loss_percent )
           {
             ClassOrder order;
             for( int i=0; i<ArraySize( Tickets ); i++ )
               {
                 if( OrderSelect( Tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
                   {
                     order.Init( OrderTicket() );
                     order.Close();
                   }
               }
           }
       }
   }    
   
//+---------------- Закрытие ордеров при привышении максимально-допустимой просадке ------------
 void CloseDrawdown( double max_drawdown )
   {
     double drawdown = AccountEquity() / AccountBalance() * 100 - 100;      
     if(drawdown > 0)
       return;
       
     if( MathAbs( drawdown ) < max_drawdown )
       return;
   
    //---- Если остались, то закрываем ордера
     ClassAccountingOrders orders;
     orders.Init( symbol, Magic );
     
     int Tickets[];
         
     orders.GetTickets( Tickets, OP_MARKET );
     
    //--- 
     ClassOrder order;
     for( int i=0; i<ArraySize( Tickets ); i++ )
       {
         if( OrderSelect( Tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
           {
             order.Init( OrderTicket() );
             order.Close();
           }
       }
   } 
   
//+-------------------- Локирование ордеров --------------------------- 
  void LockDrawdown( double max_drawdown )
   {
     double drawdown = AccountEquity() / AccountBalance() * 100 - 100;      
     if(drawdown > 0)
       return;
       
     if( MathAbs( drawdown ) < max_drawdown )
       return;
   
   
    //---- Если остались, то проверяем ордера на профитность
     ClassAccountingOrders orders;
     orders.Init( symbol, Magic );
     
     int type[2];
     type[0] = OP_BUY;
     type[1] = OP_SELL;
     
     for( int x=0; x<ArraySize( type ); x++ )
       {
         bool LockedGroup = false;
         
         int Tickets[];
         
         orders.GetTickets( Tickets, type[x] );
         
         if( ArraySize( Tickets ) == 0 )
           continue;
          
         double Lots   = 0,
                Profit = 0;
        
        //--- Считаем профит и заодно общий лот        
         for( int i=0; i<ArraySize( Tickets ); i++ )
           {
             if( !OrderSelect( Tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
               continue;
               
             if( OrderMagicNumber() == Magic + 10 )
               {
                 LockedGroup = true;
                 break;
               }  
               
             Lots += OrderLots();
             Profit += OrderProfit() + OrderSwap() + OrderCommission();
           }
           
        //--- Пропускаем, если уже есть лок   
         if( LockedGroup )
           continue;   
         
        //--- Пропускаем, если профит положительный или равен нулю   
         if( Profit >=0 )
           continue;
         
         ClassOrder order;
         
         double open_price = 0;
         int    open_type = -1;
         
         if( type[x] == OP_BUY )
           {
             open_type  = OP_SELL;
             open_price = Bid;
           }
           
         if( type[x] == OP_SELL )
           {
             open_type  = OP_BUY;
             open_price = Ask;
           }  
           
         order.OpenPrice   = NormalizeDouble( open_price, Digits );
         order.Type        = open_type;
         order.Lot         = NormalizeDouble( Lots, 2 );
         order.Symbol      = symbol;
         order.MagicNumber = Magic + 10;
         order.Slippage    = Slippage;
         order.Comment     = LockOrderComment;
         
         if( !LockedGroup )
           order.Send();
         
           
       }
     //--------------  
       
   }  
   
//+--------------- Отслеживание локирующего ордера -------------------+ 
  void TrackLockOrder()
    {
      ClassAccountingOrders orders;
      
      int Tickets[];
      
      orders.GetTickets( Tickets, OP_MARKET );
      
      for( int i=0; i<ArraySize( Tickets ); i++ )
        {
          if( !OrderSelect( Tickets[i], SELECT_BY_TICKET, MODE_TRADES ) )
            continue;
            
          if( OrderMagicNumber() != Magic + 10 )
            continue;
            
            
          double close_price = 0;  
          bool Closed = false;
          bool Modifyed = false;
          
         //--- 
          if( OrderType() == OP_BUY )
            {
              close_price = Bid;
              Closed = ( Bid >= OrderOpenPrice() + TakeProfit*Point );
              Modifyed = ( Bid >= OrderOpenPrice() + TakeProfit/2*Point );
            }
          
         //---   
          if( OrderType() == OP_SELL )
            {
              close_price = Ask;
              Closed = ( Bid <= OrderOpenPrice() - TakeProfit*Point );
              Modifyed = ( Bid <= OrderOpenPrice() - TakeProfit/2*Point );
            }
            
            
          if( Closed )
            {
              ClassOrder order;
              order.Init( Tickets[i] );
              
              order.Close();
            }  
            
          if( Modifyed )
            {
              ClassOrder order;
              order.Init( Tickets[i] );
              
              order.Close(50);
              
              order.TakeProfit = OrderOpenPrice();
              order.Modify();
              
            }
          
        }
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
    
    
    
    
    