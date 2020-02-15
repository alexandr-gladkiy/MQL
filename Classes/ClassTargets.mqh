//+------------------------------------------------------------------+
//|                                                 ClassTargets.mqh |
//|                                                           Alex G |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Alex G"
#property link      ""
#property version   "1.00"
#property strict

#include "../Classes/ClassAccountingOrders.mqh"
#include "../Classes/ClassOrder.mqh"
#include "../Lib/Array.mqh"


#define TARGETS_GRID_STOPLOSS_NO  10000
#define TARGETS_GRID_STOPLOSS_YES 11000
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ClassTargets
  {
    private:
      //--- PROPERTYES ---
       double targets[];
      
      //--- METHODS --- 
       void   DrawTarget( string name, datetime time, double price, string prefix_ = NULL );
       void   TrackTargetsForGrid( ClassOrder &order[] );
       string GetObjNameTarget();
      
      
      
    public:  
      //--- PROPERTYES ---
       int  ErrorSL;
       
       bool DrawTargets,
            CloseOrder;
            
       int  PercentForClose;
      
      //--- METHODS --- 
       void  ClassTargets();
       void ~ClassTargets();
       void  Set( double value );
       void  Set( int value );
       void  SetFromArray( double &values[] );
       bool  TrackTargets( ClassOrder &order, bool modify = true );
       bool  TrackTargets( int ticket );
       void  TrackTargets( ClassOrder &orders[] );
       void  TrackTargets( int &tickets[] );
       void  TrackTargets( string symbol_, int magic_, int type_ );
       void  TrackTargetsForGrid( int &tickets[], int use_stop_orders = TARGETS_GRID_STOPLOSS_NO );
       void  TrackTargetsForGrid( string symbol_, int magic_, int type_, int use_stop_orders = TARGETS_GRID_STOPLOSS_NO );
       void  GetToArray( double &targets[] );
       void  Delete();
       void  Clear();
                   
  };
  
  
  
//+------------------------------------------------------------------+
void ClassTargets::ClassTargets()
  {
    ArrayFree( this.targets );
    ArrayPush( this.targets, 0 );
    
    this.ErrorSL         = 10;
    this.PercentForClose = 50;
    this.DrawTargets     = false;
    this.CloseOrder      = true;
  }
  
  
  
//+------------------------------------------------------------------+
void ClassTargets::~ClassTargets()
  {
  }
  
  
//+------------------------------------------------------------------+
  void ClassTargets::Set( double value )
    {
      if(value <= 0)
        return;
        
      ArrayPush( this.targets, value );
      ArraySort( this.targets );
    }
    
//+------------------------------------------------------------------+
  void ClassTargets::Set( int value )
    {
      if(value <= 0)
        return;
        
      ArrayPush( this.targets, value / 100 );
      ArraySort( this.targets );
    }


//+------------------------------------------------------------------+
  void ClassTargets::SetFromArray( double &values[] )
    {
      ArrayFree( this.targets );
      ArrayPush(this.targets, 0);
      
      for( int i=0; i<ArraySize(values); i++ )
        if( values[i] > 0 )
          ArrayPush( this.targets, values[i] );
          
      ArraySort( this.targets );
    }
    
    
//+------------------------------------------------------------------+
  bool ClassTargets::TrackTargets( ClassOrder &order, bool modify = true )
    {
      if( ArraySize( this.targets ) < 3 )
        return false;
        
      if( order.TakeProfit <= 0 )
        return false;
        
      if( order.Type != OP_BUY )
        if( order.Type != OP_SELL )
          return false;  
          
              
      double sl_size = MathAbs( order.OpenPrice - order.TakeProfit ) / this.targets[ ArrayMaximum(this.targets) ];
      double target_price, target_price_old;
      string name   = NULL,
             prefix = "_Closed";
      
      for( int i=1; i<ArraySize( this.targets )-2; i++ )
        {
          switch( order.Type )
            {
             //---
              case OP_BUY:
                {
                  target_price     = order.OpenPrice + sl_size * this.targets[i];
                  target_price_old = order.OpenPrice + sl_size * this.targets[i-1];
                  
                  if( this.DrawTargets )
                    {
                      name = StringConcatenate( order.Ticket, "_Target", i);  
                      this.DrawTarget( name, TimeCurrent(), target_price );
                    }
                  
                  if( MarketInfo( order.Symbol, MODE_BID ) > target_price && order.StopLoss < target_price_old )
                    {
                      order.StopLoss = target_price_old + this.ErrorSL*MarketInfo( order.Symbol, MODE_POINT );
                      
                      if( modify )
                        {
                          order.Modify();
                          
                          if( this.CloseOrder )
                            order.Close( this.PercentForClose );
                        }
                      
                     //--- Этот блок под большим вопросом. Возможно, что префикс вообще не нужен
                      if(this.DrawTargets)
                        this.DrawTarget( name, TimeCurrent(), target_price, prefix );
                     //---------------------------------------------------------------
                        
                      return true;
                    }
                   
                    
                  break;
                }
              
             //---   
              case OP_SELL:
                {
                  target_price = order.OpenPrice - sl_size * this.targets[i];
                  target_price_old = order.OpenPrice - sl_size * this.targets[i-1];
                  
                  if( this.DrawTargets )
                    {
                      name = StringConcatenate( order.Ticket, "_Target", i);  
                      this.DrawTarget( name, TimeCurrent(), target_price );
                    }
                  
                  if( MarketInfo( order.Symbol, MODE_ASK ) < target_price && order.StopLoss > target_price_old )
                    {
                      order.StopLoss = target_price_old - this.ErrorSL*MarketInfo( order.Symbol, MODE_POINT );
                      
                      if( modify )
                        {
                          order.Modify();
                          
                          if( this.CloseOrder )
                            order.Close( this.PercentForClose );
                        }
                      
                     //--- Этот блок под большим вопросом. Возможно, что префикс вообще не нужен
                      if( this.DrawTargets )
                        this.DrawTarget( name, TimeCurrent(), target_price, prefix );
                     //-------------------------------------------------------------------------   
                        
                      return true;
                    }
                    
                  break;
                }
            }
            
        }
      
      return false;
    }
    
//+------------------------------------------------------------------+
  void ClassTargets::TrackTargets( ClassOrder &orders[] )
    {
      for( int i=0; i<ArraySize( orders ); i++ )
        this.TrackTargets( orders[i] );
    }
    
    
//+------------------------------------------------------------------+
  bool ClassTargets::TrackTargets( int ticket )
    {
      ClassOrder order;
      order.Init( ticket );
      return this.TrackTargets( order );
    }
      
//+------------------------------------------------------------------+
  void ClassTargets::TrackTargets( int &tickets[] )
    {
      ClassOrder order;
      for( int i=0; i<ArraySize(tickets); i++ )
        {
          order.Init( tickets[i] );
          this.TrackTargets( order );
        }
    }
    
    
//+------------------------------------------------------------------+
  void ClassTargets::TrackTargets( string symbol_, int magic_, int type_ = OP_MARKET )
    {
      int tickets[];
    
      ClassAccountingOrders orders;
      orders.Init( symbol_, magic_ );
      
      orders.GetTickets( tickets, type_ );
      TrackTargets( tickets );
    }    
    
//+------------------------------------------------------------------+
  void ClassTargets::GetToArray( double &targets_[] )
    {
      ArrayCopy( targets_, this.targets );
    }
    
 
//+------------------------------------------------------------------+
  void ClassTargets::DrawTarget( string name, datetime time, double price, string prefix_ = NULL )
    {
      if( ObjectFind( name ) < 0 )
        {
          ObjectCreate(0, name, OBJ_ARROW_RIGHT_PRICE, 0, time, price);
          ObjectSetInteger( 0, name, OBJPROP_HIDDEN, false );
          ObjectSetInteger( 0, name, OBJPROP_SELECTABLE, false );
          ObjectSetInteger( 0, name, OBJPROP_SELECTED, false );
          return;
        }
        
      ObjectSetInteger( 0, name, OBJPROP_TIME, time );  
      
      if( prefix_ != NULL )
        ObjectSetString(0, name, OBJPROP_NAME, name + prefix_);
        
      
    }


//+------------------------------------------------------------------+
  void ClassTargets::TrackTargetsForGrid( ClassOrder &order[] )
    {
     /*
        Метод модифицирует сетки ордеров, переданные в виде массива.
        Передавать можно сетки, сразу по нескольким символам.
     */
    
     //--- Собираем символы в массив
      string symbols[];
      for( int i=0; i<ArraySize( order ); i++ )
        if( ArraySearch( symbols, order[i].Symbol ) == -1 )
          ArrayPush( symbols, order[i].Symbol );
          
     //--- Теперь посимвольно модифицируем сетку 
      for( int s=0; s<ArraySize( symbols ); s++ )
        {
         //--
          int types[];
          for( int i=0; i<ArraySize( order ); i++ )
            if( order[i].Symbol == symbols[s] )
              if( ArraySearch( types, order[i].Type) == -1 )
                ArrayPush( types, order[i].Type );
                
                
          //--
           for( int t=0; t<ArraySize( types ); t++ )
            {
             //--- Средние цена открытия и тейк профит
              ClassOrder avg_order;
              int cnt = 0;
              for( int i=0; i<ArraySize( order ); i++ )
                {
                  if( order[i].Symbol == symbols[s] && order[i].Type == types[t] )
                    {
                      cnt++;
                      avg_order.OpenPrice  += order[i].OpenPrice;
                      avg_order.TakeProfit += order[i].TakeProfit;
                    }
                }
                
              avg_order.OpenPrice  /= cnt;  
              avg_order.TakeProfit /= cnt;
              avg_order.Type        = types[t];
              avg_order.Symbol      = symbols[s];
              
              double avg_sl_size = MathAbs( avg_order.OpenPrice - avg_order.TakeProfit ) / this.targets[ ArrayMaximum( this.targets ) ];
              
              switch( avg_order.Type )
                {
                 //--
                  case OP_BUY: 
                    {
                      avg_order.StopLoss = avg_order.OpenPrice + avg_sl_size;
                      break;
                    }
                 
                 //-- 
                  case OP_SELL:
                    {
                      avg_order.StopLoss = avg_order.OpenPrice - avg_sl_size;
                      break;
                    }
                }
              
              
             //--- Выходим, если ничего не изменилось
              if( !this.TrackTargets( avg_order, false ) )
                return;
              
             //--- Модификация ордеров, если есть изменения по целям
              for( int i=0; i<ArraySize( order ); i++ )
                {
                  if( order[i].Symbol == symbols[s] && order[i].Type == types[t] )
                    {
                      order[i].StopLoss = avg_order.StopLoss;
                      order[i].Modify();
                      
                      if( this.CloseOrder )
                        order[i].Close(this.PercentForClose);
                    }
                }
                
            }    
        }
      
    }

//+------------------------------------------------------------------+
  void ClassTargets::TrackTargetsForGrid( int &tickets[], int use_stop_orders = TARGETS_GRID_STOPLOSS_NO )
    {
      
      ClassOrder orders[];
      ClassOrder order;
      
      for( int i=0; i<ArraySize( tickets ); i++ )
       {
         order.Init( tickets[i] );
         if( use_stop_orders == TARGETS_GRID_STOPLOSS_NO && order.StopLoss > 0 )
            continue;
            
         int size = ArraySize( orders );
         ArrayResize( orders, size+1 );
         orders[ size ].Init( tickets[i] );
       }
        
      this.TrackTargetsForGrid( orders );  
      
    }
    
    
//+------------------------------------------------------------------+
  void ClassTargets::TrackTargetsForGrid( string symbol_, int magic_, int type_ = OP_MARKET, int use_stop_orders = TARGETS_GRID_STOPLOSS_NO )    
    {
      int tickets[];
    
      ClassAccountingOrders orders;
      orders.Init( symbol_, magic_ );
      
      orders.GetTickets( tickets, type_ );
      this.TrackTargetsForGrid( tickets );
    }
    
    
//+-------------------------------------------------------------+   
 void ClassTargets::Delete()
   {
     string name_ = "WWW";
     while( name_ != "" )
       {
         name_ = this.GetObjNameTarget();
         ObjectDelete(ChartID(), name_ );
       }
       
     ChartRedraw();
   }
   
//+--------------------------------------------------------------+   
  string ClassTargets::GetObjNameTarget()
    {
      string name_;
      
      for( int i=0; i<ObjectsTotal(); i++ )
       {
         name_ = ObjectName( i );
         if( StringFind( name_, "_Target" ) > -1 )
           return name_;
       }
       
      return "";  
      
    }    
    
    
    
  void ClassTargets::Clear()
   {
      ArrayFree( this.targets );
   }