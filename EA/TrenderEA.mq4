//+------------------------------------------------------------------+
//|                                                    TrenderEA.mq4 |
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
#include "../Classes/ClassLevel.mqh"
#include "../Classes/ClassNotification.mqh"
#include "../Lib/Lot.mqh"


enum TRADE_MODE
  {
    HAND,       // Hand
    AUTO,       // Auto 
    HAND_AUTO   // Hand and Auto
  };
  
enum DIRECTION_TRADE
  {
    
  };

//--- input parameters
  input TRADE_MODE InpMethodTrade = TRADE_MODE::AUTO; // Trade mode
  
  input string   STR1="---------- Volume ----------";  //.
  input double   InpLot=0.1;                          // Lot
  input double   InpBalance=1000.0;                   // Balance ( if zero then Lot - fixed )
  
  input string   STR2="---------- Open order settings ----------";  //.
  input int      InpDistanceToOrder=25;               // Distance to order
  input int      InpDistanceToSL=25;                  // Distance to stop loss
  input int      InpSlippage= 20;                     // Max slippage
  
  input string   STR3="---------- Targets ----------";  //.
  input double   InpTarget1=61.8;                     // Target 1
  input double   InpTarget2=161.8;                    // Target 2
  input double   InpTarget3=223.6;                    // Target 3
  input double   InpTarget4=385.4;                    // Target 4
  
  input string   STR4="---------- Support ----------";  //.
  input bool     InpClosedTargetsOrder=true;          // Partial closing of order
  input bool     InpTraillingStop=false;              // Trailling stop
  
  input string   STR5="---------- Notification ----------";  //.
  input bool     InpMail = false;                     // Mail
  input bool     InpPush = false;                     // Push
  input bool     InpAlert = false;                    // Alert
  
  input string   STR6="---------- Colors map ----------";  //.
  input color    InpNewLevelColor = clrBlue;          // New level
  input color    InpTradeLevelColor = clrGreenYellow; // Trade level
  input color    InpCloseLevelColor = clrOrangeRed;   // Close level
  

  string BotName = "Level Trader";

//--------------------------
  string symbol = Symbol();
  int timeframe = Period();
  
  bool newCandle = false;
  datetime dt_last = 0,
           dt_curr = 0;
  
 //--- Hand Trading       
  int InpMagic=211119;
  ClassOrder OrderBuy, OrderSell;
  ClassAccountingOrders Orders;
  ClassLevel CustomLevels[];
  string prefix_level = "Level_";
  
  
 //--- Auto Trading   
  int MagicAuto = 201119;
  ClassOrder OrderBuyAuto, OrderSellAuto;
  ClassAccountingOrders OrdersAuto;
  ClassLevel LevelAuto;
  
  ClassNotification Notify;
  
  double LastLot = 0;   
  int ActiveOrderTicketBuy = 0;      
  int ActiveOrderTicketSell = 0;
//+------------------------------------------------------------------+
int OnInit()
  {
    ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
    //ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
    
    CustomLevelsInit( CustomLevels );
  
    OrderBuy.Init( symbol, InpMagic, NULL, OP_BUY );
    OrderSell.Init( symbol, InpMagic, NULL, OP_SELL );
    
    Notify.alert = InpAlert;
    Notify.push  = InpPush;
    Notify.mail  = InpMail;
      
  
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
    dt_curr = iTime( symbol, timeframe, 0 );
   
    newCandle = dt_last != dt_curr; 
                     
    if( newCandle )
      dt_last = dt_curr;
         
   
   //---- Если используется автоматический режим определения торговых уровней
    if( InpMethodTrade == TRADE_MODE::AUTO || InpMethodTrade == TRADE_MODE::HAND_AUTO )
      {
        OrdersAuto.Init( symbol, MagicAuto );
        
        if( OrdersAuto.market == 0 )
          if( TrackLevel( LevelAuto ) )
            OpenOrdersForLevel( LevelAuto, OrderBuyAuto, OrderSellAuto, MagicAuto );
      
          
       //-----   
       if( OrdersAuto.market == 0 )
        {
          if( TrackOrder( OrderBuyAuto ) )
            {
              //OrderSellAuto.Clear();
              LevelAuto.Clear();
            }
            
          if( TrackOrder( OrderSellAuto ) )
            {
              //OrderBuyAuto.Clear();
              LevelAuto.Clear();
            }
         }
        
       //---  
        if( OrdersAuto.buy > 0 )   
          TrackTargetsOrder( OP_BUY, MagicAuto );
          
        if( OrdersAuto.sell > 0 )
          TrackTargetsOrder( OP_SELL, MagicAuto );
        
         
         if( InpTraillingStop )
           TraillingStop( symbol, MagicAuto, NULL, InpDistanceToSL, true );  
          
          
      }
    
       
      
   //--- Если используется ручной режим определения уровней   
    if( InpMethodTrade == TRADE_MODE::HAND || InpMethodTrade == TRADE_MODE::HAND_AUTO )
      {
        Orders.Init( symbol, InpMagic );
        
        int curr_level = GetIndexLevelForCurrPrice( CustomLevels );
        
        if( curr_level > -1 && Orders.market == 0 )
          if( OpenOrdersForLevel( CustomLevels[curr_level], OrderBuy, OrderSell, MagicAuto ) )
            CustomLevels[ curr_level ].Trade_ = true;          
      
            
        //-------------------------------
         TrackOrder( OrderBuy );
         TrackOrder( OrderSell );
         
         TrackTargetsOrder( OP_BUY, InpMagic );
         TrackTargetsOrder( OP_SELL, InpMagic );
       
         
         
        //------- Рисование стоп-уровней ------- 
         if( OrderBuy.Type == OP_BUYSTOP )
           DrawStopLevels( OrderBuy );
         else
           DrawStopLevels( OP_BUY );
           
         if( OrderSell.Type == OP_SELLSTOP )
           DrawStopLevels( OrderSell );
         else
           DrawStopLevels( OP_SELL );
        //--------------------------------------
        
        //--- Рисование Уровней
        RedrawLevels( CustomLevels ); 
         
         
         if( InpTraillingStop )
           TraillingStop( symbol, InpMagic, NULL, InpDistanceToSL, true );
     }  
  }
  
  
//+------------------------------------------------------------------+
 bool OpenOrdersForLevel( ClassLevel &level, ClassOrder &OrdBuy, ClassOrder &OrdSell, int magic )
   {
     if( level.Trade_ || level.Close_ )
       return false;
       
     if( (Ask > level.low && Ask < level.high) || (Bid > level.low && Bid < level.high) )
       {
        //--- Шаблон сообщения   
         string ConstMsg = StringConcatenate(
                                              "%s: Trade mode - %s; \r\n" + 
                                              "Open virtual order BuyStop for %s \r\n:",
                                              "Open price: %s \r\n",
                                              "Stop loss: %s \r\n",
                                              "Take profit: %s"
                                            );
        //--- Оптеделение режима торговли                                    
         string trade_mode = "";
         if( magic == InpMagic )
           trade_mode = "HAND";
         if( magic == MagicAuto )
           trade_mode = "AUTO";
           
         
         double Targets[];
         GetTargetsToArray( Targets );
         
         //--- Установка отложенного ордера на покупку
            OrdBuy.Type = OP_BUYSTOP;
            OrdBuy.MagicNumber = magic;
            OrdBuy.Lot = GetLotMax( InpLot, InpBalance, LastLot );
            OrdBuy.OpenPrice = level.high + InpDistanceToOrder*Point;
            OrdBuy.Slippage = Normalize(InpSlippage);
            
            OrdBuy.StopLoss   = level.low - InpDistanceToSL*Point;
            OrdBuy.TakeProfit = OrdBuy.OpenPrice + MathAbs( OrdBuy.StopLoss - OrdBuy.OpenPrice ) * Targets[ ArrayMaximum( Targets ) ];
            
            //--- Отправка уведомления
            Notify.Send
              ( 
                StringFormat( 
                  ConstMsg, 
                  BotName, 
                  trade_mode,
                  symbol, 
                  DoubleToString( OrdBuy.OpenPrice, Digits ), 
                  DoubleToString( OrdBuy.StopLoss, Digits ), 
                  DoubleToString( OrdBuy.TakeProfit, Digits ) )
              );
            
            
           //--- Установка отложенного ордера на продажу 
            OrdSell.Type = OP_SELLSTOP;
            OrdSell.MagicNumber = magic;
            OrdSell.Lot = GetLotMax( InpLot, InpBalance, LastLot );
            OrdSell.OpenPrice = level.low - InpDistanceToOrder*Point;
            OrdSell.Slippage = Normalize(InpSlippage);
            
            OrdSell.StopLoss   = level.high + InpDistanceToSL*Point;
            OrdSell.TakeProfit = OrdSell.OpenPrice - MathAbs( OrdSell.StopLoss - OrdSell.OpenPrice ) * Targets[ ArrayMaximum( Targets ) ];
            
           //--- Отправка уведомления
            Notify.Send
              ( 
                StringFormat( 
                  ConstMsg, 
                  BotName, 
                  symbol, 
                  DoubleToString( OrdSell.OpenPrice, Digits ), 
                  DoubleToString( OrdSell.StopLoss, Digits ), 
                  DoubleToString( OrdSell.TakeProfit, Digits ) )
              );
              
           return true;
           
       }
     return false;  
   }
  
//+------------------------------------------------------------------+
 void RedrawLevels( ClassLevel &levels[] )
  {
    if( ArraySize( levels ) == 0 )
      return;
      
    string name;
      
    for( int i=0; i<ArraySize(levels); i++ )
      {
       //--- определение имени 
        name = prefix_level + IntegerToString( levels[i].ID );
        
       //--- Перерисовка уровней  
        if( ( levels[i].New_ || levels[i].Trade_ ) && !levels[i].Close_ )
          {
            levels[i].time_end = TimeCurrent();
            ObjectSetInteger(0, name, OBJPROP_TIME2, levels[i].time_end);
          }
        
        if( levels[i].New_ )
          ObjectSetInteger(0, name, OBJPROP_COLOR, InpNewLevelColor);
          
        if( levels[i].Trade_ )
          ObjectSetInteger(0, name, OBJPROP_COLOR, InpTradeLevelColor);
          
        if( levels[i].Close_ )
          ObjectSetInteger(0, name, OBJPROP_COLOR, InpCloseLevelColor);
        
      }
      
    ChartRedraw();
  }

  
  
//+------------------------------------------------------------------+
 int GetIndexLevelForCurrPrice( ClassLevel &levels[] )
  {
    if( ArraySize(levels) == 0 )
      return -1;
      
    for( int i=0; i<ArraySize(levels); i++ )
      {
        if( levels[i].Trade_ || levels[i].Close_ )
          continue;
          
        if(    Low[0] < levels[i].low
            && High[0] > levels[i].low )
          return( i );
          
        if(    Low[0] > levels[i].high
            && High[0] < levels[i].high )
          return( i );
          
        if(    Low[0] > levels[i].low
            && High[0] < levels[i].high )
          return( i );  
          
        if(    Low[0] < levels[i].low
            && High[0] > levels[i].high )
          return( i );  
      }
        
    return -1;
  }
  
//+------------------------------------------------------------------+
 int GetIndexLevelForLastOrder( ClassLevel &levels[], int type )
  {
    ClassOrder order;
    order.Init( symbol, InpMagic, NULL, type );
    if( !OrderSelect( order.Ticket, SELECT_BY_TICKET, MODE_TRADES ) )
      return -1;
    
    double targets[];
    GetTargetsToArray(targets);
    
    //if( targets[ ArrayMaximum( targets ) ] )
    //  return -1;
    
    double sl_size = MathAbs( (order.OpenPrice - order.TakeProfit) / targets[ ArrayMaximum( targets ) ] ); //-- Размер стоп-лосса
    
    
   //--- Если ордер есть, но уровней в массиве нет 
    if( ArraySize( levels ) == 0 && order.Ticket > 0  )
      {
        double high = 0, low = 0;
        int x = AddLevel(levels);
       
        if( type == OP_BUY )
          {
            high = order.OpenPrice - InpDistanceToOrder*Point;
            low  = order.OpenPrice - sl_size + InpDistanceToSL * Point;
          }
          
        if( type == OP_SELL )
          {
            high = order.OpenPrice + sl_size - InpDistanceToSL*Point;
            low  = order.OpenPrice + InpDistanceToOrder * Point;
          }
          
        levels[x].SetLevel( high, low, OrderOpenTime(), Time[0] );  
        levels[x].New_ = true;
        levels[x].Trade_ = true;
        
        
        return x;
      }
      
    //--- Если массив с уровнями заполнен и есть ордер
     if( ArraySize( levels ) > 0 && order.Ticket > 0  )
      {
        for( int i=0; i<ArraySize(levels); i++ )
          {
            if( type == OP_BUY )
              if( order.OpenPrice >= levels[i].high && order.OpenPrice - sl_size <= levels[i].low)
                return i;
            
            if( type == OP_SELL )
              if( order.OpenPrice <= levels[i].low && order.OpenPrice - sl_size >= levels[i].high)
                return i;
          }
      }
        
    return -1;
  }  



//+------------------------------------------------------------------+
 void TrackTargetsOrder( int type, int magic )
   {
     double targets[];
     GetTargetsToArray( targets );
     
     if( ArraySize(targets) < 2 )
       return;
     
     ClassAccountingOrders orders;
     ClassOrder order;
     
     orders.Init( symbol, magic );
     order.Init( symbol, magic, NULL, type );
     
     double sl_size = MathAbs( (order.OpenPrice - order.TakeProfit) / targets[ ArraySize(targets) - 1 ] ); //-- Размер стоп-лосса
     
    //------- 
     if( type == OP_BUY )
       {   
       
        //---    
         if( ArraySize( targets ) == 4 )
           {
             if( order.StopLoss < order.OpenPrice + sl_size * targets[1] && Bid > order.OpenPrice + sl_size * targets[2] )
               {
                 order.StopLoss = order.OpenPrice + sl_size * targets[1];
                 if( order.Modify() )
                   if( InpClosedTargetsOrder )
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
                   if( InpClosedTargetsOrder )
                     order.Close(50);
               }  
           }
       
        //---
         if( order.StopLoss < order.OpenPrice && Bid > order.OpenPrice + sl_size * targets[0] )
           {
             order.StopLoss = order.OpenPrice;
             if( order.Modify() )
               if( InpClosedTargetsOrder )
                 order.Close(50);
           }
           
       }
           
    //-----   
     if( type == OP_SELL )
       {     
       
        //---    
         if( ArraySize( targets ) == 4 )
           {
             if( order.StopLoss > order.OpenPrice - sl_size * targets[1] && Ask < order.OpenPrice - sl_size * targets[2] )
               {
                 order.StopLoss = order.OpenPrice - sl_size * targets[1];
                 if( order.Modify() )
                   if( InpClosedTargetsOrder )
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
                   if( InpClosedTargetsOrder )
                     order.Close(50);
               }  
           }
          
        //---  
         if( order.StopLoss > order.OpenPrice && Ask < order.OpenPrice - sl_size * targets[0] )
           {
             order.StopLoss = order.OpenPrice;
             if( order.Modify() )
               if( InpClosedTargetsOrder )
                 order.Close(50);
           }
     }     
     
   }

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
   
 void ArrayPush( double &array[], double value )
   {
     int size = ArraySize(array);
     ArrayResize(array, size + 1);
     
     array[size] = value;
   }

  
//+------------------------------------------------------------------+
  bool TrackLevel( ClassLevel &level )
    {
      level.Clear();
      
     //--- Ищем первую стартовую точку отчёта
      GetLevelBars( 1, level );
      int StartIndex = level.end_index + 1;
      
     //--- Ищем первое пересечение с ценой 
      GetLevelBars( StartIndex, level );
      StartIndex = level.end_index + 1;
      
     //--- Ищем пересечение со вторым уровнем, если ценапересекла импульсное движение 
      if( (level.end_index - 1) - (level.start_index + 1) < 0 )
        GetLevelBars( StartIndex, level ); 
        
     //--- Теперь можно и уровень анализировать
      /**
        * Считаем, что крайние бары уровня - импульсные бары входа и выхода. Анализируем скорость этих импульсов
        * Уровнем считаем бары обрамлённые этими импульсами.
        * Размер уровня расчитываем от low до high диапазона.
        * Сила импульсов, время на уровне, ретест, соотношение риска/возможность
      */
     
     //---- Settings find level ---- 
      double min_power       = 1.5;
      int    max_cnt_bars    = 5;
      double min_risk_profit = 2;
      int    max_cnt_retest  = 2;
     //-----------------------------
      
      ClassCandle candle[];
      
      ArrayResize( candle, level.end_index+1 );
      for( int i=0; i<level.end_index+1; i++ )
        candle[i].Init( symbol, timeframe, i);
            
      if( ArraySize( candle ) == 0 )
        return false;
      
          
        
     //--- Время на уровне       
      int cnt_bars = level.end_index - level.start_index - 2;  //--- Крайние бары не учитываем
       
     double power = 0;
      
     //--- Сила импульса в уровень\из уровня  
         power =   ( candle[ level.start_index ].size + candle[ level.end_index ].size) / 2
                   /
                   (
                    High[ iHighest( symbol, timeframe, MODE_HIGH, cnt_bars, level.start_index + 1 ) ] 
                    -
                    Low[ iLowest( symbol, timeframe, MODE_LOW, cnt_bars, level.start_index + 1 ) ]
                   );
    
     //--- Соотношение риск\прибыль
      double move_to_up =   (
                             High[ iHighest( symbol, timeframe, MODE_HIGH, level.end_index, 1 ) ] 
                             -
                             High[ iHighest( symbol, timeframe, MODE_HIGH, cnt_bars, level.start_index + 1 ) ]
                            );
                            
      double move_to_down = (
                             Low[ iLowest( symbol, timeframe, MODE_LOW, cnt_bars, level.start_index + 1 ) ]
                             -
                             Low[ iLowest( symbol, timeframe, MODE_LOW, level.end_index, 1 ) ] 
                            );                    
                       
      double risk_profit =  ( move_to_up + move_to_down ) / 2
                           / 
                            (
                             High[ iHighest( symbol, timeframe, MODE_HIGH, cnt_bars, level.start_index + 1 ) ] 
                             -
                             Low[ iLowest( symbol, timeframe, MODE_LOW, cnt_bars, level.start_index + 1 ) ]
                            );
                            
                            
                            
      double cnt_retest = 1;
      
      
      if(    cnt_bars < max_cnt_bars
          && power > min_power
          && risk_profit > min_risk_profit 
        )
        {
          level.SetLevel( High[ iHighest( symbol, timeframe, MODE_HIGH, cnt_bars, level.start_index + 1 ) ],
                          Low[ iLowest( symbol, timeframe, MODE_LOW, cnt_bars, level.start_index + 1 ) ], 0, 0 );
          return true;                
        }
      
      
      
      return false;
    }
    

//-----------------------------------------------
 void GetLevelBars( int start_index, ClassLevel &level )
   {     
      int StartIndexBar = start_index; 
          
      double avg_price = (Ask + Bid) / 2;
          
      while( avg_price > High[StartIndexBar] || avg_price < Low[StartIndexBar] )
        StartIndexBar ++;  
         
      int cnt_analyze_bars = 10;
      int EndIndexBar = StartIndexBar;
      for( int i=0; i<cnt_analyze_bars; i++ )
        {
          if( 
                ( 
                     High[ EndIndexBar ] > Low[ StartIndexBar ] 
                  && High[ EndIndexBar ] < High[ StartIndexBar ] 
                )
              ||
                (
                     Low[ EndIndexBar ] > Low[ StartIndexBar ]
                  && Low[ EndIndexBar ] < High[ StartIndexBar ]
                )
              ||  
                ( 
                     Open[ EndIndexBar ] > Low[ StartIndexBar ] 
                  && Open[ EndIndexBar ] < High[ StartIndexBar ] 
                )
              ||
                (
                     Close[ EndIndexBar ] > Low[ StartIndexBar ]
                  && Close[ EndIndexBar ] < High[ StartIndexBar ]
                )    
            )
            EndIndexBar ++;
          else
            break;
        } 
           
      level.start_index = StartIndexBar;
      level.end_index   = EndIndexBar;
    
   }    
    
    
//+-------------------------------------------------------------------+
 int Normalize( int param )
   {
     int new_param = param;
   
     if( Digits == 4 || Digits == 2 )
       new_param = (int)(param / 10);
   
     return new_param;
   }



//+------------------------------------------------------------------+
 bool TrackOrder( ClassOrder &order )
   {
    if( order.Type == ( OP_BUY || OP_SELL ) )
      {
        if( !OrderSelect( order.Ticket, SELECT_BY_TICKET, MODE_TRADES ) )
          {
            order.Clear();
            return false;
          }
      }
    //-----
     if(order.Type == OP_BUYSTOP)
       {
        //---
         if( Ask > order.OpenPrice )
           {
             order.Type = OP_BUY;
             order.Send();
             order.Clear();
             return true;
           }
           
       }
       
    //-----   
     if(order.Type == OP_SELLSTOP)
       {
        //---
         if( Bid < order.OpenPrice )
           {
             order.Type = OP_SELL;
             order.Send();
             order.Clear();
             return true;
           }
           
       }
       
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


//=================================== Levels ============================================

//+--------------------------------------------------------------------+
 int AddLevel( ClassLevel &levels[] )
  {
    int size = ArraySize( levels );
    ArrayResize( levels, size+1 );
  
    return size;
  }


 
  
//=============================== Events Action =========================================  
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
    double price1, price2;
    datetime dt1, dt2;   
    string name; 
     
   if( id == CHARTEVENT_OBJECT_CLICK )
     {
     }  
    
   //----- Создание объекта
    if( id == CHARTEVENT_OBJECT_CREATE )
      {
        if( StringFind( sparam, prefix_level )==-1 && ObjectType( sparam ) == OBJ_RECTANGLE )
          {
            //--- Доработать коррекность присвоения идентификаторов уровней. Проверка уникальности...
            int last_id = GetLastLevelID( CustomLevels );
            
            int i = AddLevel( CustomLevels );
            CustomLevels[i].ID = last_id + 1;
             
             name = prefix_level + IntegerToString( CustomLevels[i].ID );
            ObjectSetString(0, sparam, OBJPROP_NAME, name);
            
            //----- информация о ценовом уровне, добавление уровня
             price1 = ObjectGetDouble( 0, name, OBJPROP_PRICE1 );
             price2 = ObjectGetDouble( 0, name, OBJPROP_PRICE2 );
            
             dt1 = (datetime)(ObjectGetInteger( 0, name, OBJPROP_TIME1 ) );
             dt2 = (datetime)( ObjectGetInteger( 0, name, OBJPROP_TIME2 ) );
            
            CustomLevels[i].SetLevel( price1, price2, dt1, dt2 ); 
            ObjectSetInteger( 0, name, OBJPROP_TIME1, CustomLevels[i].time_begin );
            ObjectSetInteger( 0, name, OBJPROP_TIME1, CustomLevels[i].time_end );
            
            Print( "Create Level: ID = ", CustomLevels[i].ID );
          }
      }
      
   //----- Изменение объекта  
    if( id == ( CHARTEVENT_OBJECT_CHANGE || CHARTEVENT_OBJECT_DRAG ) )
      {
        if( StringFind( sparam, prefix_level )>-1 && ObjectType( sparam ) == OBJ_RECTANGLE )
          {
            name = sparam;
            StringReplace( name, prefix_level, "" );
            
            int LevelID =(int) StringToInteger( name );
            
            
            for( int i=0; i<ArraySize( CustomLevels ); i++ )
              {
                if(CustomLevels[i].ID == LevelID)
                  {
                     price1 = ObjectGetDouble( 0, sparam, OBJPROP_PRICE1 );
                     price2 = ObjectGetDouble( 0, sparam, OBJPROP_PRICE2 );
                           
                     dt1 = StringToTime( TimeToString( ObjectGetInteger( 0, name, OBJPROP_TIME1 ) ) );
                     dt2 = StringToTime( TimeToString( ObjectGetInteger( 0, name, OBJPROP_TIME2 ) ) );
                           
                    CustomLevels[i].SetLevel( price1, price2, dt1, dt2 );      
                    Print( "Update Level: ", CustomLevels[i].ID );
                    break;
                  }
              }
          }      
      }
      
      
   //----- Изменение объекта  
    if( id == CHARTEVENT_OBJECT_DELETE )
      {
        if( StringFind( sparam, prefix_level )>-1 )
          {
            name = sparam;
            StringReplace( name, prefix_level, "" );
            
            int LevelID =(int) StringToInteger( name );
            
            Print( "Delete Level: ", LevelID );
                
            CustomLevelsInit( CustomLevels );
            
          }      
      }
   
   ChartRedraw();   
    
        
   
  }
  
 //+-------------------------------------------------------------------+
  int GetLastLevelID( ClassLevel &levels[] )
    {
      int lastID = 0;
      for( int i=0; i<ArraySize(levels); i++ )
        {
          if( levels[i].ID > lastID )
            lastID = levels[i].ID;
        }
      return lastID;
    }
    
 //+------------------------------------------------------------------+
  int CustomLevelsInit( ClassLevel &levels[] )
    {
      ArrayFree( levels );
    
      double price1, price2;
      datetime dt1, dt2;  
      
      if( ObjectsTotal() == 0)
        return 0;
        
      for( int i=0; i<ObjectsTotal(); i++ )
        {
          string name = ObjectName( 0, i );
          if( StringFind( name, prefix_level ) == -1 || ObjectType( name ) != OBJ_RECTANGLE )
            continue;
          
          //--- Доработать коррекность присвоения идентификаторов уровней. Проверка уникальности...
            int x = AddLevel( CustomLevels );
            
            string id_name = name;
            StringReplace( id_name, prefix_level, "" );
            
            int LevelID =(int) StringToInteger( id_name );
            
            CustomLevels[x].ID = LevelID;
             
            
            //----- информация о ценовом уровне, добавление уровня
             price1 = ObjectGetDouble( 0, name, OBJPROP_PRICE1 );
             price2 = ObjectGetDouble( 0, name, OBJPROP_PRICE2 );
            
             dt1 = (datetime)(ObjectGetInteger( 0, name, OBJPROP_TIME1 ));
             dt2 = (datetime)( ObjectGetInteger( 0, name, OBJPROP_TIME2 ));
            
            CustomLevels[x].SetLevel( price1, price2, dt1, dt2 ); 
            
            ObjectSetInteger( 0, name, OBJPROP_TIME1, CustomLevels[x].time_begin );
            ObjectSetInteger( 0, name, OBJPROP_TIME2, CustomLevels[x].time_end );
            
            
           //--- Определение проторгованности уровня
            color ColorLevel = (color)(ObjectGetInteger( 0, name, OBJPROP_COLOR ));
            if(  ColorLevel == InpCloseLevelColor)
              {
                CustomLevels[x].Close_ = true;
                CustomLevels[x].Trade_ = true;
                CustomLevels[x].New_ = true;
              } 
              
            if(  ColorLevel == InpTradeLevelColor)
              {
                CustomLevels[x].Trade_ = true;
                CustomLevels[x].New_ = true;
              }
              
            if(  ColorLevel == InpNewLevelColor)
              CustomLevels[x].New_ = true;
               
        }
      
      
      //--- Рисуем уровень для открытого ордера
       ClassAccountingOrders orders;
       orders.Init( symbol, InpMagic );
       if( orders.market == 0 )
         return ArraySize( levels );     
        
       int tickets[];
       orders.GetTickets( tickets, OP_MARKET );
       
       ClassOrder order;
       order.Init( tickets[0] );
       
       double targets[];
       GetTargetsToArray( targets );
       
       double sl_size = MathAbs( order.TakeProfit - order.OpenPrice ) / targets[ ArrayMaximum( targets ) ];
       double border_h = 0,
              border_l = 0;
              
       if( order.Type == OP_BUY )
         {
           border_h = order.OpenPrice;
           border_l = order.OpenPrice - sl_size;
         }
         
       if( order.Type == OP_SELL )
         {
           border_l = order.OpenPrice;
           border_h = order.OpenPrice - sl_size;
         }  
         
       
       bool IsLevelForOrder = false,
            LevelForOrderStopBuy = false,
            LevelForOrderStopSell = false;
       for( int i=0; i<ArraySize( levels ); i++ )
         {
          if( levels[i].high < border_h && levels[i].low > border_l )
            {
              levels[i].high = border_h - InpDistanceToOrder*Point;
              levels[i].low  = border_l + InpDistanceToSL*Point;
              levels[i].Trade_ = true;
              levels[i].New_   = true;
              
              
              DrawLevel(levels[i]);
              IsLevelForOrder = true;
            }
            
           //---- Проверка наличия уровня для виртуальных отложенных ордеров
            if( OrderBuy.Type == OP_BUYSTOP && levels[i].high < OrderBuy.OpenPrice && levels[i].low > OrderBuy.OpenPrice - sl_size * Point ) 
              LevelForOrderStopBuy = true;
              
            if( OrderSell.Type == OP_SELLSTOP && levels[i].high < OrderSell.OpenPrice + sl_size*Point && levels[i].low > OrderSell.OpenPrice ) 
              LevelForOrderStopSell = true;
         }  
       
       //--- DrawLevel
       if( !IsLevelForOrder ) 
         {
          int new_l = AddLevel( levels );
          levels[new_l].SetLevel( border_h - InpDistanceToOrder*Point, 
                                  border_l + InpDistanceToSL*Point, 
                                  0, 
                                  0 );
          levels[new_l].New_ = true;
          levels[new_l].Trade_ = true;
          
          DrawLevel(levels[new_l]);
         }
         
       if( !LevelForOrderStopBuy )
         OrderBuy.Clear();
       if( !LevelForOrderStopSell )
         OrderSell.Clear();  
       
      return ArraySize(levels);
    }  
    
//+------------------------------------------------------------------------------+
 void DrawLevel( ClassLevel &level )
  {
    string name_level = prefix_level + IntegerToString( level.ID ); 
    ObjectDelete( name_level );
    
    ObjectCreate( name_level, OBJ_RECTANGLE, 0, level.time_begin, level.high, level.time_end, level.low);
    
    if( level.New_ )
      ObjectSetInteger(0, name_level, OBJPROP_COLOR, InpNewLevelColor);
          
    if( level.Trade_ )
      ObjectSetInteger(0, name_level, OBJPROP_COLOR, InpTradeLevelColor);
          
    if( level.Close_ )
      ObjectSetInteger(0, name_level, OBJPROP_COLOR, InpCloseLevelColor);
        
      
    ChartRedraw();
  }    
    
//=========================== Draw Orders Params =================================    
    
//+------------------------------------------------------------------------------+    
 void DrawStopLevels( ClassOrder &order )
   {
     double targets_value[];
     string targets_string[];
     
     GetTargetsToArray( targets_value );
     ArrayResize( targets_string, ArraySize( targets_value ) );
     
     double sl_size = MathAbs( order.OpenPrice - order.StopLoss );
     
     for( int i=0; i<ArraySize( targets_value ); i++ )
      {
        targets_value[i] *= sl_size;
        targets_string[i] = "";
      }
        
     string order_stop_name = "",
            tp_name = "",
            sl_name = "";
            
    //--- Формирование названий объектов для отрисовки        
     if( order.Type == OP_BUY || order.Type == OP_BUYSTOP )
       {
         order_stop_name = "BuyStop";
         tp_name = "BuyTP";
         sl_name = "BuySL";
         
         for( int i=0; i<ArraySize(targets_string); i++ )
           targets_string[i] = "BuyTarget" + IntegerToString(i+1);
       }
       
     if( order.Type == OP_SELLSTOP || order.Type == OP_SELL )
       {
         order_stop_name = "SellStop";
         tp_name = "SellTP";
         sl_name = "SellSL";
         
         for( int i=0; i<ArraySize(targets_string); i++ )
           targets_string[i] = "SellTarget" + IntegerToString(i+1);
       }  
       
    //--- Удаление линий стопов и цены открытия  
     if( order.Type == OP_BUY || order.Type == OP_SELL )
       {
         ObjectDelete( order_stop_name );
         ObjectDelete( tp_name );
         ObjectDelete( sl_name );
       }
       
    //--- Отрисовка стопов и цены открытия   
     if( order.Type == OP_BUYSTOP || order.Type == OP_SELLSTOP )
       {
         DrawPriceLevel( order_stop_name, order.OpenPrice, clrGreen );
         DrawPriceLevel( tp_name, order.TakeProfit, clrRed );
         DrawPriceLevel( sl_name, order.StopLoss, clrRed );
       }
       
       
    //--- Отрисовка целей   
     if( order.Type == OP_BUYSTOP || order.Type == OP_BUY )
       for( int i=0; i<ArraySize(targets_value)-1; i++ )
         DrawPriceLevel( targets_string[i], order.OpenPrice + targets_value[i], clrRed );
         
     if( order.Type == OP_SELLSTOP || order.Type == OP_SELL )
       for( int i=0; i<ArraySize(targets_value)-1; i++ )
         DrawPriceLevel( targets_string[i], order.OpenPrice - targets_value[i], clrRed );
         
         
    //--- Удаление объектов, ордер не идентифицирован  
     if( order.Type == -1 )
       {
         ObjectDelete( "BuyStop" );
         ObjectDelete( "BuyTP" );
         ObjectDelete( "BuySL" );
         ObjectDelete( "BuyTarget1" );
         ObjectDelete( "BuyTarget2" );
         ObjectDelete( "BuyTarget3" );
         
         ObjectDelete( "SellStop" );
         ObjectDelete( "SellTP" );
         ObjectDelete( "SellSL" );
         ObjectDelete( "SellTarget1" );
         ObjectDelete( "SellTarget2" );
         ObjectDelete( "SellTarget3" );
       }  
   }
   
//+------------------------------------------------------------------+
 void DrawStopLevels(int type)
  {
    ClassOrder order;
    order.Init( symbol, InpMagic, NULL, type );
    
    DrawStopLevels( order );
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