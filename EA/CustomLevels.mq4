//+------------------------------------------------------------------+
//|                                                 CustomLevels.mq4 |
//|                                                            AlexG |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "AlexG"
#property link      ""
#property version   "1.00"
#property strict


#include "../Classes/ClassCustomLevels.mqh"

ClassCustomLevels Levels;
//+------------------------------------------------------------------+
int OnInit()
  {
    ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
    
    
    Levels.Init();
   
   return(INIT_SUCCEEDED);
  }
  
  
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
  }
  
  
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
     
   if( id == CHARTEVENT_OBJECT_CLICK )
     {
       
     }  
    
   //----- Создание объекта
    if( id == CHARTEVENT_OBJECT_CREATE )
      {
       Levels.Create( sparam );
      }
      
   //----- Изменение объекта  
    if( id == ( CHARTEVENT_OBJECT_CHANGE || CHARTEVENT_OBJECT_DRAG ) )
      {
        Levels.Modify( sparam );
      }
      
      
   //----- Изменение объекта  
    if( id == CHARTEVENT_OBJECT_DELETE )
      {
        Levels.Delete( sparam );
      }  
   
  }
//+------------------------------------------------------------------+
