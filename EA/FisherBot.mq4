
//   FISHERBOT - Name

#property copyright "AlexG"   // 
#property link      ""        // Создать Email чтобы не давать личную почту
#property version   "1.20"
#property strict
 
 enum PERIODS
   {
     M1, // M1
     M5, // M5
     M15 // M15
   };

 enum DIRECTION_TRADES
   {
	 AllDirrection,  // All Directions
	 UpStream,       // Up Stream
	 DownStream,     // Down Stream
    OnlyBuy,        // Only Buy
	 OnlySell        // Only Sell
   };
   
  
 enum LANGUAGE
  {
    ENG,  // English
    RUS   // Русский
  };
  
 enum STRATEGY
  {
    ALL,       // Use all strategies
    FISH_ROB,  // Fish-rod
    TAIL       // Tail
  };
  
 enum MM_TYPES
  {
    FIX_LOT,      // Fix lot
    PERCENT,      // Percent
    LOT_FOR_1000 // Lot for $1000 
  };
   
 struct ACCOUNTING_ORDERS
   {
     int market,
         deferrend,
         buy,
         sell,
         buystop,
         sellstop,
         buylimit,
         selllimit,
         all;
   };
 
 extern STRATEGY strategy = STRATEGY::ALL;    // Strategy selection
 extern MM_TYPES mm_type = MM_TYPES::FIX_LOT; // Lot calculation type
 extern double mm_data   = 1;                 // MM Data
       
 double FixLot;
 double lot_for_1000;
 double Risk; 
 
 extern int    PipsForEntry = 25;    // Distance to order
 extern int    TP           = 300;   // Take Profit
 extern int    SL           = 20;    // Stop Loss
 extern int    MaxSpread    = 20;    // Max Spread
 extern int    magic = 34512;        // ID Orders
 
 extern string str1  ="";  //------ Extended settings ---------
 extern int    SizeBar      = 220;    // Bar size to start trading
 extern int    SizeVolume   = 200;    // Volume size to start trading
 extern bool   UseTrall     = true;   // Use Trailing Stop
 extern PERIODS periods     = PERIODS::M1; // Timeframe
 
  bool   VirtualTrall = false;        // Virtual Trailling Stop
  bool   DeleteOrdersStop = false;    // Delete Orders Stop
  DIRECTION_TRADES dir_trades = DIRECTION_TRADES::UpStream; // Direction Trades
 
 
 double MaxLot = 99;            // Max Lot
 
 int period; 
 int slippage = 30,
     account;
  
 //------------------- 
 enum DIRECTION
  {
    UP,
    DOWN,
    UNDEFINED,
    NONE
  }; 
 
  
  
 //--------------------- 
 struct CANDLE
  {
    datetime time;
    double open, close, high, low, size;
    long volume;
    double body, 
           top_shadow,
           bottom_shadow,
           
           body_percent,
           top_shadow_percent,
           bottom_shadow_percent;
    
    DIRECTION direction;
  };
  
  
 //-------------------------- 
 struct ORDER
  {
    string symbol;
    
    int Ticket,
        Type,
        Magic,
        Slippage;
    
    double OpenPrice,
           ClosePrice,
           StopLoss,
           TakeProfit,
           Lot;
           
    double distance;
           
  };  
  
  
 //---------------------------- 
  datetime time = 0;
  
  double sl,
         tp,
         size_bar,
         spread,
         max_spread,
         pips_for_entry,
         LastLot;
        
 int ticket,
     time_minute_start_trading = 0,
     TrallStepStr2 = 0;   
              
 bool res,
      onTrading_fishrob,
      onTrading_tail,
      allowed_account,
      HistoryDataFind = true,
		trading_sell = false,
		trading_buy = false,
		SendInfoTrade = false,
		TestValidate = false;
		  
 datetime dt = iTime(Symbol(), period, 0); 
  
  CANDLE candle;
  ORDER  order_sell,
         order_buy;
         
  ACCOUNTING_ORDERS orders_fishrob, 
                    orders_tail;
//+------------------------------------------------------------------+

int OnInit()
  {    
   // Инициализация рабочего периода    
    switch(periods)
      {
        case PERIODS::M1:  { period = PERIOD_M1; break;}
        case PERIODS::M5:  { period = PERIOD_M5; break;}
        case PERIODS::M15: { period = PERIOD_M15; break;}
      }
      
   // Инициализация типа расчёта лота
    switch(mm_type)
      {
        case MM_TYPES::FIX_LOT: { FixLot = mm_data; break; }
        case MM_TYPES::PERCENT: { Risk   = mm_data; break; }
        case MM_TYPES::LOT_FOR_1000: { lot_for_1000 = mm_data; break; }
      }
    
    
    int stop = getFindStopLevel(SL);
    int take = getFindStopLevel(TP);
  
    sl             = NormalizeDouble(stop*Point, Digits);
    tp             = NormalizeDouble(take*Point, Digits);
    size_bar       = NormalizeDouble(SizeBar*Point, Digits);
    pips_for_entry = NormalizeDouble(PipsForEntry*Point, Digits);
    max_spread     = NormalizeDouble(MaxSpread*Point, Digits);
        
    order_buy.Type  = -1;
    order_sell.Type = -1;
    
    if(MaxLot > 99)
      MaxLot = 99;
         
    //allowed_account = (AccountNumber() == 2090243274); //tickmil 2090243274
    //allowed_account = (AccountNumber() == 60234992); // alpari 
	 allowed_account = true;         
     
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
  {
   
  }
//+------------------------------------------------------------------+

void OnTick()
  {
    
    if(IsTesting())
      {
          {
            if( !TestValidate )
             { 
               order_buy.Lot = GetStartLotPercent();
               
               if( CheckMoneyForTrade(Symbol(), order_buy.Lot, OP_SELL) )
                 ticket = OrderSend(Symbol(), OP_SELL, order_buy.Lot, Bid, 25, 0, 0);
                 
               if(ticket > 0)
                 res = OrderClose(ticket, order_buy.Lot, Ask, 25);
                 
               TestValidate = true;
             } 
          } 
      }
      
    
   spread = Ask - Bid;
  
   if( spread > max_spread )
     {
       Print("Big spread: ", spread);
       return;
     }
   
  //==================== Использование разных стратегий ==================
   
   UseStrategy_FishRob(true); //--- Fish-Rob Strategy
   UseStrategy_Tail(true);    //--- Tail Strategy
   
      
  }
//+------------------------------------------------------------------+

void UseStrategy_FishRob( bool enable )
  {
     if(!enable)
       return;
       
     AccountingOrders(orders_fishrob, Symbol(), magic, "Fish-Rob");
     
     //--- Получение разрешения на торговлю
       
       onTrading_fishrob = (orders_fishrob.all == 0 
                         && allowed_account 
                         && (   strategy == STRATEGY::ALL 
                             || strategy == STRATEGY::FISH_ROB)
         );
         
      
        if(onTrading_fishrob)
          {
            CandleInit(candle, Symbol(), period, 0);
            
            if(candle.size > size_bar && candle.volume > SizeVolume)
              {         
              //-- Разрешение торговли в Buy			 
   			   trading_buy = (
   			    orders_fishrob.buystop == 0 &&
   				 orders_fishrob.buy == 0 &&
   				 order_buy.Type == -1 &&
   			     (
   				   (dir_trades == DIRECTION_TRADES::OnlyBuy) ||
   				   (dir_trades == DIRECTION_TRADES::AllDirrection) ||
   				   ((dir_trades == DIRECTION_TRADES::DownStream) && (candle.direction == DIRECTION::UP)) ||
   				   ((dir_trades == DIRECTION_TRADES::UpStream) && (candle.direction == DIRECTION::DOWN))
   			     )
   			   );
   			   
   			  //-- Разрешение торговли в Sell
   			   trading_sell = (
   			    orders_fishrob.sellstop == 0 &&
   				 orders_fishrob.sell == 0 &&
   				 order_sell.Type == -1 &&
   			     (
   				   (dir_trades == DIRECTION_TRADES::OnlySell) ||
   				   (dir_trades == DIRECTION_TRADES::AllDirrection) ||
   				   ((dir_trades == DIRECTION_TRADES::DownStream) && (candle.direction == DIRECTION::DOWN)) ||
   				   ((dir_trades == DIRECTION_TRADES::UpStream) && (candle.direction == DIRECTION::UP))
   			     )
   			   );
   			 
   			 
                if( trading_sell )
                  {
                    order_sell.OpenPrice  = NormalizeDouble(Bid - pips_for_entry - spread, Digits);
                    order_sell.StopLoss   = NormalizeDouble(Ask + sl, Digits);
                    order_sell.TakeProfit = NormalizeDouble(Bid - tp, Digits);
                    order_sell.Type       = OP_SELLSTOP;
                    order_sell.Lot        = GetStartLotPercent();                 
                   
                  }
                  
                  
                if( trading_buy )
                  {
                    order_buy.OpenPrice  = NormalizeDouble(Ask + pips_for_entry + spread, Digits);
                    order_buy.StopLoss   = NormalizeDouble(Bid - sl, Digits);
                    order_buy.TakeProfit = NormalizeDouble(Ask + tp, Digits);
                    order_buy.Type       = OP_BUYSTOP;
                    order_buy.Lot        = GetStartLotPercent();
                    
                  }
              }
          } 
       
       
      //-- Удаляем виртуальные ордера после закрытия свечи
      if( dt != Time[0] && DeleteOrdersStop)
        {
          order_buy.Type = -1;
          order_sell.Type = -1;
          dt = Time[0];
        }
      
       
   	//-- Удаляем виртуальный отложенный ордер, если спред превышает максимально допустимый
   	if(spread > MaxSpread)
   	   {
   	     order_sell.Type = -1;
   		  order_buy.Type  = -1;
   	   }
   	
    
      //--- Траллим виртуальные отложенники
      if(order_buy.Type > -1)
        {
          if( Ask >= order_buy.OpenPrice )
   			{
   			  double take = order_sell.TakeProfit - spread;
   			  
   			  if( CheckMoneyForTrade(Symbol(), order_buy.Lot, OP_BUY) )
   			    {
   			      ticket = OrderSend(Symbol(), OP_BUY, order_buy.Lot, Ask, slippage, 0, 0, "Fish-Rob", magic, 0, clrBlue);
   			      
   			      
   			      order_buy.StopLoss   = NormalizeDouble(Bid - sl, Digits) - spread;
                  order_buy.TakeProfit = NormalizeDouble(Ask + tp, Digits) + spread;
   			      if(ticket > 0)
   			        res = OrderModify(ticket, 0, order_buy.StopLoss, order_buy.TakeProfit, 0, clrNONE);
   			         
   			        
   			    }
   			  order_buy.Type = -1;
   			  order_sell.Type = -1;
   			}
   			
   	    if( order_buy.OpenPrice - Ask > pips_for_entry )
            {
              order_buy.OpenPrice  = NormalizeDouble(Ask + pips_for_entry, Digits);
              order_buy.StopLoss   = NormalizeDouble(Bid - sl, Digits);
              order_buy.TakeProfit = NormalizeDouble(Ask + tp, Digits);
            }
        }
        	 
   		 
   	 
   	//--- Траллим виртуальные отложки
        if(order_sell.Type > -1)
        {
          if( Bid <=  order_sell.OpenPrice )
   			{
   			  double stop = order_sell.StopLoss + spread;
   			  double take = order_sell.TakeProfit - spread;
   			  
   			  if( CheckMoneyForTrade(Symbol(), order_sell.Lot, OP_SELL) )
   			    {
   			      ticket = OrderSend(Symbol(), OP_SELL, order_sell.Lot, Bid, slippage, 0, 0, "Fish-Rob", magic, 0, clrRed);
   			    
   			      order_sell.StopLoss   = NormalizeDouble(Ask + sl, Digits) + spread;
                  order_sell.TakeProfit = NormalizeDouble(Bid - tp, Digits) - spread;
   			      if(ticket > 0)
   			        res = OrderModify(ticket, 0, order_sell.StopLoss, order_sell.TakeProfit, 0, clrNONE);
   			    }
   			        
   			  order_sell.Type = -1;
   			  order_buy.Type = -1;
   			    
   			}
   			
   	    if( Bid - order_sell.OpenPrice > pips_for_entry )
            {
              order_sell.OpenPrice  = NormalizeDouble(Bid - pips_for_entry, Digits);
              order_sell.StopLoss   = NormalizeDouble(Ask + sl, Digits);
              order_sell.TakeProfit = NormalizeDouble(Bid - tp, Digits);
            }
        }
      
      
         
      //--- Траллим стопы при наличии рыночных ордеров
      TraillingStop(Symbol(), magic, "Fish-Rob", PipsForEntry); 
  
  }
//+------------------------------------------------------------------+
void UseStrategy_Tail(bool enable)
  {
      if(!enable)
        return;
      
      onTrading_tail = (
         allowed_account 
      && orders_tail.all == 0
      && ( strategy == STRATEGY::ALL || strategy == STRATEGY::TAIL )
      );
      
      if(onTrading_tail)
        {
          CandleInit(candle, Symbol(), period, 1);
          
          if( candle.size > size_bar && candle.volume > SizeVolume )
            {
             //--- Проверка сигналов на продажу
              if((candle.direction == DIRECTION::UP && candle.top_shadow_percent >= 15) || 
                 (candle.direction == DIRECTION::DOWN && candle.top_shadow_percent >= 70) )
                 {
                   if( Bid < candle.high )
                     {
                       double stop = candle.high + pips_for_entry,
                              take = Ask - tp;
                       ticket = OrderSend(Symbol(), OP_SELL, GetStartLotPercent(), Bid, slippage, 0, 0, "Tail", magic, 0, clrRed );
                       
                       if( ticket > 0 )
                         res = OrderModify(ticket, 0, stop + spread, tp - spread, 0 );
                         
                       TrallStepStr2 = (int)MathRound( candle.top_shadow/Point );  // Шаг трейлинга приравниваем размеру верхней тени
                     }
                 }
              
             //--- Проверка сигналов на покупку
              if((candle.direction == DIRECTION::DOWN && candle.bottom_shadow_percent > 15) || 
                 (candle.direction == DIRECTION::UP && candle.bottom_shadow_percent > 70) )
                 {
                   if( Ask > candle.low )
                     {
                       double stop = candle.low - pips_for_entry,
                              take = Bid + tp;
                       ticket = OrderSend(Symbol(), OP_BUY, GetStartLotPercent(), Ask, slippage, 0, 0, "Tail", magic, 0, clrBlue );
                       
                       if( ticket > 0 )
                         res = OrderModify(ticket, 0, stop - spread, tp + spread, 0 );
                         
                       TrallStepStr2 = (int)MathRound( candle.bottom_shadow/Point ); // Шаг трейлинга приравниваем размеру нижней тени
                     }
                 }   
            }
        }
        
        
        //--- Организовать тралл
        if(orders_tail.all > 0 && UseTrall)
          TraillingStop(Symbol(), magic, "Tail", TrallStepStr2, false);
  
  }


//+------------------------------------------------------------------+
void CandleInit( CANDLE &c, string symbol_, int period_, int shift_)
  {
    c.open   = iOpen(symbol_, period_, shift_);
    c.close  = iClose(symbol_, period_, shift_);
    c.high   = iHigh(symbol_, period_, shift_);
    c.low    = iLow(symbol_, period_, shift_);
    c.volume = iVolume(symbol_, period_, shift_);
    c.time = iTime(symbol_, period_, shift_);
    
    c.size  = MathAbs(c.high - c.low);
               
    c.body = MathAbs(c.close - c.open);
        
    if(c.open > c.close)
      {
        c.top_shadow = c.high - c.open;
        c.bottom_shadow = c.close - c.low;
      }
    else if(c.open < c.close)
      {
        c.top_shadow = c.high - c.close;
        c.bottom_shadow = c.open - c.low;
      }
    else
      {
        c.top_shadow = c.high - c.open;
        c.bottom_shadow = c.open - c.low;
      }
    
    if(c.size !=0)
      {      
        c.body_percent           = c.body/c.size*100;
        c.top_shadow_percent     = c.top_shadow/c.size*100;
        c.bottom_shadow_percent  = c.bottom_shadow/c.size*100;
      }
    
    if(c.open > c.close)
      c.direction = DIRECTION::DOWN;
      
    else if(c.open < c.close)
      c.direction = DIRECTION::UP;
      
    else
      c.direction = DIRECTION::NONE;
      
      
  }  
//-----------------------------------------------------  


double GetStartLotPercent()               //включено управление деньгами но отключен марнингейл     
     
     {     
      
      double marginRequired=MarketInfo(Symbol(),MODE_MARGINREQUIRED);
      double freeMargin=AccountFreeMargin();   
      double resLot = 0.01; //инициализируем умолчанием 
      double percent=Risk;
      double LotStep=0.01;

      
      if (percent > 100) percent=100;  //процентов не более 100, т.е. максимально допустимый лот
      
      if (percent==0)
         resLot=0.01;  // Если Риск= 0 то лот минимальный
                
      else
      {                                   
         
         resLot=NormalizeDouble( MathFloor(freeMargin* percent/100.0/marginRequired/0.01)*0.01, 2 ); //Расчет лота в зависимости от риска                                   
         
         
         if ((LastLot!=0) && (LastLot>resLot)) // лот не уменьшаем
           if(CheckVolumeValue(LastLot))
             resLot = LastLot;
         
         
          
         if(resLot > MaxLot)
          resLot = MaxLot;   
      }     
      
      LastLot = resLot;
      
      if(FixLot > 0)
        resLot = FixLot;
        
      if(mm_type == MM_TYPES::LOT_FOR_1000)
        return(GetStartLot_1000( lot_for_1000 ));
      
      return(resLot);    
     
     } 
//+------------------------------------------------------------------+

double GetStartLot_1000(double lots_for_1000 )
  {
    double resLot;
    
    double balance = AccountBalance();
    resLot = NormalizeDouble( balance/1000*lots_for_1000, 2 );
    
    return(resLot);
  }     
     
     
//+------------------------------------------------------------------+
//|  Проверяет объем ордера на корректность                          |
//+------------------------------------------------------------------+
bool CheckVolumeValue(double volume)
  {
  string description;
  
  //--- минимально допустимый объем для торговых операций
   double min_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(volume<min_volume)
     {
      description=StringFormat("Объем меньше минимально допустимого SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }

//--- максимально допустимый объем для торговых операций
   double max_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(volume>max_volume)
     {
      description=StringFormat("Объем больше максимально допустимого SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }

//--- получим минимальную градацию объема
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);

   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      description=StringFormat("Объем не является кратным минимальной градации SYMBOL_VOLUME_STEP=%.2f, ближайший корректный объем %.2f",
                               volume_step,ratio*volume_step);
      return(false);
     }
   description="Корректное значение объема";
   return(true);
  }
  
  
//-----------------------------------------------------  
bool CheckMoneyForTrade(string symb, double lots,int type)
  {
   double free_margin=AccountFreeMarginCheck(symb,type,lots);
   //-- если денег не хватает
   if(free_margin<0)
     {
      string oper=(type==OP_BUY)? "Buy":"Sell";
      Print(DoubleToStr(free_margin)+" lots "+DoubleToStr(lots)+" type "+IntegerToString(type)+" Not enough money for ", oper," ",lots, " ", symb, " Error code=",GetLastError());
      return(false);
     }
   //-- проверка прошла успешно
   return(true);
  }
     
     
//--------------------------------------------------------------------------------------------------------
//                                        УЧЁТ ОРДЕРОВ
//--------------------------------------------------------------------------------------------------------
void AccountingOrders(ACCOUNTING_ORDERS &ord, string symbol_, int magic_, string comment_ = "ALL_ORDERS" )
  {
    ord.all       = 0;
    ord.market    = 0;
    ord.deferrend = 0;
    ord.sell      = 0;
    ord.selllimit = 0;
    ord.sellstop  = 0;
    ord.buy       = 0;
    ord.buylimit  = 0;
    ord.buystop   = 0;
    
    if(OrdersTotal() == 0)
      return;
      
    
    for(int i=0; i<OrdersTotal(); i++)
      {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
          {
          
           //--- Проверка выбранного ордера исходя из условий
            bool selected;
            if( comment_ == "ALL_ORDERS" )
              selected = ( OrderMagicNumber() == magic_ && OrderSymbol() == symbol_ );
              
            if( comment_ != "ALL_ORDERS" )
              selected = ( OrderMagicNumber() == magic_ && OrderSymbol() == symbol_ && OrderComment() == comment_ );
              
              
            if( selected )
              {
                switch( OrderType() )
                  {
                    case OP_BUY:       {ord.all++; ord.market++;    ord.buy++;      break;}
                    case OP_SELL:      {ord.all++; ord.market++;    ord.sell++;     break;}
                    case OP_BUYSTOP:   {ord.all++; ord.deferrend++; ord.buystop++;  break;}
                    case OP_SELLSTOP:  {ord.all++; ord.deferrend++; ord.sellstop++; break;}
                    case OP_BUYLIMIT:  {ord.all++; ord.deferrend++; ord.buylimit++; break;}
                    case OP_SELLLIMIT: {ord.all++; ord.deferrend++; ord.selllimit++;break;}
                  }
              }
          }
      }
        
    /*  
    Comment ("Покупки ",ord.buy,"\n",
              "Продажи ",ord.sell,"\n",
              "BuyLimit ",ord.buylimit,"\n",
              "SellLimit ",ord.selllimit,"\n",
              "BuyStop ",ord.buystop,"\n",
              "SellStop ",ord.sellstop,"\n",
              "Сделки ",ord.market,"\n",
              "Отложки ",ord.deferrend,"\n",
              "Всего ",ord.all);  
    */
  }
  
//----------------------------------------------------------------------------------------------------------------    

int getFindStopLevel(int stop_size )
  {
    if(SYMBOL_TRADE_STOPS_LEVEL > stop_size)
      return(SYMBOL_TRADE_STOPS_LEVEL);
      
    return(stop_size);
    
  }
  
//+---------------------------------------------------------------------------+
void TraillingStop( string symbol_, int magic_, string comment_, int step_ = 0, bool breakeven_ = false )
  {
    if(OrdersTotal() == 0)
      return;
    
    bool result;  
    double spr = Ask-Bid,
           step = NormalizeDouble(step_*Point, Digits),
           stoploss = 0;
           
    for(int i=0; i<OrdersTotal(); i++)
      {
        if( OrderSelect( i, SELECT_BY_POS ) )
          {
            if(OrderSymbol() == symbol_ && OrderMagicNumber() == magic_ && OrderComment() == comment_)
              {
                if(breakeven_ && OrderStopLoss()==OrderOpenPrice())
                  return;
                stoploss = MathAbs(OrderOpenPrice() - OrderStopLoss());  
                  
                if(OrderType() == OP_BUY)
                  {
                    if(OrderStopLoss() <= Bid - stoploss - step)
                      result = OrderModify(OrderTicket(), 0, Bid - stoploss, OrderTakeProfit(), 0, clrNONE);
                  }
                  
                if(OrderType() == OP_SELL)
                  {
                    if(OrderStopLoss() >= Ask + stoploss + step)
                      result = OrderModify(OrderTicket(), 0, Ask + stoploss, OrderTakeProfit(), 0, clrNONE);
                  }
              }
          }
      }
  }
  

  
