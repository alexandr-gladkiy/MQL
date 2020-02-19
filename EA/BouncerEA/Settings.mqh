


//===================== Inputs =============================
  input int      InpMagic = 190220;                       // ID EA
  
 input string   STR1="---------- Volume ----------";  //.
  input double   InpLot=0.1;                          // Lot
  input double   InpBalance=1000.0;                   // Balance ( if zero then Lot - fixed )
  
  input string   STR2="---------- Open order settings ----------";  //.
  input int      InpDistanceToSL=25;                  // Distance to stop loss (%)
  input int      InpSlippage= 20;                     // Max slippage
  
  input string   STR5="---------- Notification ----------";  //.
  input bool     InpMail = false;                     // Mail
  input bool     InpPush = false;                     // Push
  input bool     InpAlert = false;                    // Alert
  
   
   
//-------- Структура INPUTS ----------
  struct INPUTS
    {
      int Magic,
          DistanceToSL,
          Slippage;
        
        double Lot,
               Balance;
               
        bool onMail,
             onPush,
             onAlert;
    };
    
    
   
//====================== Класс с настройками ========================  
  class ClassSettings
    {
      public:
        INPUTS Input;
        
        string Symbol;
        int Timeframe;
    }; 

 
 //--- Инициализация класса с настройками ( в OnInit нужно вызвать функцию InitSettings )
  ClassSettings Settings;
  
 void SettingsInit()
  {
    Settings.Input.Balance      = InpBalance;
    Settings.Input.DistanceToSL = InpDistanceToSL;
    Settings.Input.Lot          = InpLot;
    Settings.Input.Magic        = InpMagic;
    Settings.Input.Slippage     = InpSlippage;
    Settings.Input.onAlert      = InpAlert;
    Settings.Input.onMail       = InpMail;
    Settings.Input.onPush       = InpPush;
    
    Settings.Symbol    = _Symbol;
    Settings.Timeframe = PERIOD_CURRENT;
  }