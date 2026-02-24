//+------------------------------------------------------------------+
//|                                            SessionManagerEA.mq5 |
//|                                                                  |
//|                                Expert Advisor per gestione       |
//|                                sessioni e chiusura posizioni     |
//+------------------------------------------------------------------+
#property copyright "Session Manager EA"
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade trade;

// Parametri input - Risk Management
input double DailyTakeProfit = 500;         // Daily Take Profit in $ (0 = disabled)
input double DailyStopLoss = 500;           // Daily Stop Loss in $ (0 = disabled)
input double DailyTakeProfitPercent = 0;    // Daily Take Profit in % (0 = disabled)
input double DailyStopLossPercent = 0;      // Daily Stop Loss in % (0 = disabled)

// Parametri input - Trailing Stop Levels
input double TP1 = 100;              // TP1 - Primo livello breakeven (0 = disabled)
input double TP2 = 150;              // TP2 - Secondo livello breakeven (0 = disabled)
input double TP3 = 200;              // TP3 - Terzo livello breakeven (0 = disabled)
input double TP4 = 300;              // TP4 - Quarto livello breakeven (0 = disabled)
input double TP5 = 500;              // TP5 - Quinto livello breakeven (0 = disabled)
input double ActivationOffset = 100; // Offset attivazione: raggiungi TP+N per attivare SL a TP

// Parametri interfaccia - Valori fissi
#define BUTTON_X      170
#define BUTTON_Y      50
#define BUTTON_WIDTH  150
#define BUTTON_HEIGHT 30
#define BUTTON_COLOR  clrRed
#define TEXT_COLOR    clrWhite

// Variabili globali - Sessione
datetime sessionStartTime = 0;
bool     sessionActive = false;
double   sessionStartBalance = 0;
double   sessionStartEquity = 0;
double   sessionPeakEquity = 0;
double   sessionMaxDrawdown = 0;
double   sessionMaxDrawdownPercent = 0;
int      trailingStopLevel = 0;

// Variabili globali - Oggetti grafici
string buttonName             = "CloseAllBtn";
string buttonStopName         = "CloseAllStopBtn";
string buttonResetName        = "ResetStatsBtn";
string buttonResetTSName      = "ResetTrailingStopBtn";
string timerLabel             = "SessionTimer";
string startingBalanceLabel   = "StartingBalanceLabel";
string balanceLabel           = "BalanceLabel";
string equityLabel            = "EquityLabel";
string profitLabel            = "ProfitLabel";
string profitPctLabel         = "ProfitPctLabel";
string lossLabel              = "LossLabel";
string lossPctLabel           = "LossPctLabel";
string maxDDLabel             = "MaxDDLabel";
string maxDDPctLabel          = "MaxDDPctLabel";
string trailingStopActiveLabel = "TrailingStopActiveLabel";

// Prototipi forward declaration
void ClosePositionsOnly();
void CloseAllPositions();
void DisableAutoTrading();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Imposta deviazione (slippage) per le chiusure
   trade.SetDeviationInPoints(50);

   // Crea i bottoni
   CreateCloseButton();
   CreateCloseStopButton();
   CreateResetButton();
   CreateResetTSButton();

   // Crea le label del pannello informativo
   CreateTimerLabel();
   CreateInfoLabels();

   // Controlla se esistono dati di sessione salvati (cambio parametri)
   if(GlobalVariableCheck("SM_SessionActive") && GlobalVariableGet("SM_SessionActive") > 0)
   {
      // Ripristina sessione esistente
      sessionStartTime         = (datetime)GlobalVariableGet("SM_SessionStartTime");
      sessionStartBalance      = GlobalVariableGet("SM_SessionStartBalance");
      sessionStartEquity       = GlobalVariableGet("SM_SessionStartEquity");
      sessionPeakEquity        = GlobalVariableGet("SM_SessionPeakEquity");
      sessionMaxDrawdown       = GlobalVariableGet("SM_SessionMaxDrawdown");
      sessionMaxDrawdownPercent= GlobalVariableGet("SM_SessionMaxDrawdownPercent");
      trailingStopLevel        = (int)GlobalVariableGet("SM_TrailingStopLevel");
      sessionActive = true;

      Print("========================================");
      Print("Session Manager EA MT5 inizializzato");
      Print("SESSIONE ESISTENTE RIPRISTINATA");
      Print("Sessione avviata alle: ", TimeToString(sessionStartTime, TIME_DATE|TIME_MINUTES));
      Print("Balance iniziale: ", DoubleToString(sessionStartBalance, 2));
      Print("Equity iniziale: ", DoubleToString(sessionStartEquity, 2));
      Print("Peak Equity: ", DoubleToString(sessionPeakEquity, 2));
      Print("Max Drawdown: ", DoubleToString(sessionMaxDrawdown, 2));
      Print("Trailing Stop Level: ", trailingStopLevel);
      Print("========================================");
   }
   else
   {
      // Avvia nuova sessione
      sessionStartTime      = TimeCurrent();
      sessionStartBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
      sessionStartEquity    = AccountInfoDouble(ACCOUNT_EQUITY);
      sessionPeakEquity     = sessionStartEquity;
      sessionMaxDrawdown    = 0;
      sessionMaxDrawdownPercent = 0;
      trailingStopLevel     = 0;
      sessionActive         = true;

      SaveSessionData();

      Print("========================================");
      Print("Session Manager EA MT5 inizializzato");
      Print("NUOVA SESSIONE AVVIATA");
      Print("Sessione avviata alle: ", TimeToString(sessionStartTime, TIME_DATE|TIME_MINUTES));
      Print("Balance iniziale: ", DoubleToString(sessionStartBalance, 2));
      Print("Equity iniziale: ", DoubleToString(sessionStartEquity, 2));
      Print("========================================");
   }

   // Avvia il timer per aggiornamenti ogni secondo
   EventSetTimer(1);

   // Aggiornamento iniziale del pannello
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double sessionPL = currentEquity - sessionStartEquity;
   double sessionPLPercent = (sessionStartEquity > 0) ? (sessionPL / sessionStartEquity * 100.0) : 0;
   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(reason == REASON_PARAMETERS || reason == REASON_CHARTCHANGE)
   {
      SaveSessionData();
      Print("Parametri cambiati - dati sessione salvati, sessione mantenuta");
   }
   else
   {
      CleanupSessionData();
      Print("Dati sessione rimossi (sessione terminata)");
   }

   EventKillTimer();

   // Rimuovi gli oggetti grafici
   ObjectDelete(0, buttonName);
   ObjectDelete(0, buttonStopName);
   ObjectDelete(0, buttonResetName);
   ObjectDelete(0, buttonResetTSName);
   ObjectDelete(0, timerLabel);
   ObjectDelete(0, startingBalanceLabel);
   ObjectDelete(0, balanceLabel);
   ObjectDelete(0, equityLabel);
   ObjectDelete(0, profitLabel);
   ObjectDelete(0, profitPctLabel);
   ObjectDelete(0, lossLabel);
   ObjectDelete(0, lossPctLabel);
   ObjectDelete(0, maxDDLabel);
   ObjectDelete(0, maxDDPctLabel);
   ObjectDelete(0, trailingStopActiveLabel);

   Print("Session Manager EA MT5 disattivato");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!sessionActive) return;

   UpdateSessionTimer();

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double sessionPL = currentEquity - sessionStartEquity;
   double sessionPLPercent = (sessionStartEquity > 0) ? (sessionPL / sessionStartEquity * 100.0) : 0;

   // Aggiorna picco equity e calcola drawdown
   if(currentEquity > sessionPeakEquity)
      sessionPeakEquity = currentEquity;

   double currentDrawdown = sessionPeakEquity - currentEquity;
   double currentDrawdownPercent = (sessionPeakEquity > 0) ? (currentDrawdown / sessionPeakEquity * 100.0) : 0;

   if(currentDrawdown > sessionMaxDrawdown)
   {
      sessionMaxDrawdown = currentDrawdown;
      sessionMaxDrawdownPercent = currentDrawdownPercent;
      SaveSessionData();
   }

   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   CheckTrailingStop(sessionPL);

   // Verifica Take Profit giornaliero ($ o %)
   if((DailyTakeProfit > 0 && sessionPL >= DailyTakeProfit) ||
      (DailyTakeProfitPercent > 0 && sessionPLPercent >= DailyTakeProfitPercent))
   {
      Print("========================================");
      Print("TAKE PROFIT GIORNALIERO RAGGIUNTO!");
      Print("Profitto: ", DoubleToString(sessionPL, 2), " (", DoubleToString(sessionPLPercent, 2), "%)");
      if(DailyTakeProfit > 0) Print("Target TP $: ", DoubleToString(DailyTakeProfit, 2));
      if(DailyTakeProfitPercent > 0) Print("Target TP %: ", DoubleToString(DailyTakeProfitPercent, 2), "%");
      Print("Chiusura automatica in corso...");
      Print("========================================");

      Alert("TAKE PROFIT RAGGIUNTO!\n" +
            "Profitto: " + DoubleToString(sessionPL, 2) + " (" + DoubleToString(sessionPLPercent, 2) + "%)\n" +
            "Chiusura automatica di tutte le posizioni e grafici...");

      CloseAllPositions();
      DisableAutoTrading();
      return;
   }

   // Verifica Stop Loss giornaliero ($ o %)
   if((DailyStopLoss > 0 && sessionPL <= -DailyStopLoss) ||
      (DailyStopLossPercent > 0 && sessionPLPercent <= -DailyStopLossPercent))
   {
      Print("========================================");
      Print("STOP LOSS GIORNALIERO RAGGIUNTO!");
      Print("Perdita: ", DoubleToString(sessionPL, 2), " (", DoubleToString(sessionPLPercent, 2), "%)");
      if(DailyStopLoss > 0) Print("Target SL $: -", DoubleToString(DailyStopLoss, 2));
      if(DailyStopLossPercent > 0) Print("Target SL %: -", DoubleToString(DailyStopLossPercent, 2), "%");
      Print("Chiusura automatica in corso...");
      Print("========================================");

      Alert("STOP LOSS RAGGIUNTO!\n" +
            "Perdita: " + DoubleToString(sessionPL, 2) + " (" + DoubleToString(sessionPLPercent, 2) + "%)\n" +
            "Chiusura automatica di tutte le posizioni e grafici...");

      CloseAllPositions();
      DisableAutoTrading();
      return;
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!sessionActive) return;

   UpdateSessionTimer();

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double sessionPL = currentEquity - sessionStartEquity;
   double sessionPLPercent = (sessionStartEquity > 0) ? (sessionPL / sessionStartEquity * 100.0) : 0;

   if(currentEquity > sessionPeakEquity)
      sessionPeakEquity = currentEquity;

   double currentDrawdown = sessionPeakEquity - currentEquity;
   double currentDrawdownPercent = (sessionPeakEquity > 0) ? (currentDrawdown / sessionPeakEquity * 100.0) : 0;

   if(currentDrawdown > sessionMaxDrawdown)
   {
      sessionMaxDrawdown = currentDrawdown;
      sessionMaxDrawdownPercent = currentDrawdownPercent;
      SaveSessionData();
   }

   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   CheckTrailingStop(sessionPL);

   // Verifica Take Profit giornaliero ($ o %)
   if((DailyTakeProfit > 0 && sessionPL >= DailyTakeProfit) ||
      (DailyTakeProfitPercent > 0 && sessionPLPercent >= DailyTakeProfitPercent))
   {
      Print("========================================");
      Print("TAKE PROFIT GIORNALIERO RAGGIUNTO! (Timer)");
      Print("Profitto: ", DoubleToString(sessionPL, 2), " (", DoubleToString(sessionPLPercent, 2), "%)");
      if(DailyTakeProfit > 0) Print("Target TP $: ", DoubleToString(DailyTakeProfit, 2));
      if(DailyTakeProfitPercent > 0) Print("Target TP %: ", DoubleToString(DailyTakeProfitPercent, 2), "%");
      Print("Chiusura automatica in corso...");
      Print("========================================");

      Alert("TAKE PROFIT RAGGIUNTO!\n" +
            "Profitto: " + DoubleToString(sessionPL, 2) + " (" + DoubleToString(sessionPLPercent, 2) + "%)\n" +
            "Chiusura automatica di tutte le posizioni e grafici...");

      CloseAllPositions();
      DisableAutoTrading();
      return;
   }

   // Verifica Stop Loss giornaliero ($ o %)
   if((DailyStopLoss > 0 && sessionPL <= -DailyStopLoss) ||
      (DailyStopLossPercent > 0 && sessionPLPercent <= -DailyStopLossPercent))
   {
      Print("========================================");
      Print("STOP LOSS GIORNALIERO RAGGIUNTO! (Timer)");
      Print("Perdita: ", DoubleToString(sessionPL, 2), " (", DoubleToString(sessionPLPercent, 2), "%)");
      if(DailyStopLoss > 0) Print("Target SL $: -", DoubleToString(DailyStopLoss, 2));
      if(DailyStopLossPercent > 0) Print("Target SL %: -", DoubleToString(DailyStopLossPercent, 2), "%");
      Print("Chiusura automatica in corso...");
      Print("========================================");

      Alert("STOP LOSS RAGGIUNTO!\n" +
            "Perdita: " + DoubleToString(sessionPL, 2) + " (" + DoubleToString(sessionPLPercent, 2) + "%)\n" +
            "Chiusura automatica di tutte le posizioni e grafici...");

      CloseAllPositions();
      DisableAutoTrading();
      return;
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == buttonName)
      {
         Print("Bottone Close All premuto - Chiusura solo posizioni...");
         ClosePositionsOnly();
         ObjectSetInteger(0, buttonName, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == buttonStopName)
      {
         Print("Bottone Close All & STOP premuto - Chiusura totale...");
         CloseAllPositions();
         DisableAutoTrading();
         ObjectSetInteger(0, buttonStopName, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == buttonResetName)
      {
         Print("Bottone Reset Stats premuto - Reset statistiche...");
         ResetSessionStats();
         ObjectSetInteger(0, buttonResetName, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == buttonResetTSName)
      {
         Print("Bottone Reset Trailing Stop premuto...");
         ResetTrailingStop();
         ObjectSetInteger(0, buttonResetTSName, OBJPROP_STATE, false);
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| Funzione per creare il bottone Close All (solo posizioni)        |
//+------------------------------------------------------------------+
void CreateCloseButton()
{
   ObjectDelete(0, buttonName);
   ObjectCreate(0, buttonName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, buttonName, OBJPROP_XDISTANCE, BUTTON_X);
   ObjectSetInteger(0, buttonName, OBJPROP_YDISTANCE, BUTTON_Y);
   ObjectSetInteger(0, buttonName, OBJPROP_XSIZE, BUTTON_WIDTH);
   ObjectSetInteger(0, buttonName, OBJPROP_YSIZE, BUTTON_HEIGHT);
   ObjectSetInteger(0, buttonName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, clrOrange);
   ObjectSetInteger(0, buttonName, OBJPROP_COLOR, TEXT_COLOR);
   ObjectSetString(0, buttonName, OBJPROP_TEXT, "Close All");
   ObjectSetString(0, buttonName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, buttonName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, buttonName, OBJPROP_SELECTABLE, false);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per creare il bottone Close All & STOP                  |
//+------------------------------------------------------------------+
void CreateCloseStopButton()
{
   ObjectDelete(0, buttonStopName);
   ObjectCreate(0, buttonStopName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, buttonStopName, OBJPROP_XDISTANCE, BUTTON_X);
   ObjectSetInteger(0, buttonStopName, OBJPROP_YDISTANCE, BUTTON_Y + BUTTON_HEIGHT + 5);
   ObjectSetInteger(0, buttonStopName, OBJPROP_XSIZE, BUTTON_WIDTH);
   ObjectSetInteger(0, buttonStopName, OBJPROP_YSIZE, BUTTON_HEIGHT);
   ObjectSetInteger(0, buttonStopName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, buttonStopName, OBJPROP_BGCOLOR, BUTTON_COLOR);
   ObjectSetInteger(0, buttonStopName, OBJPROP_COLOR, TEXT_COLOR);
   ObjectSetString(0, buttonStopName, OBJPROP_TEXT, "Close All & STOP");
   ObjectSetString(0, buttonStopName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, buttonStopName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, buttonStopName, OBJPROP_SELECTABLE, false);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per creare il bottone Reset Stats                       |
//+------------------------------------------------------------------+
void CreateResetButton()
{
   ObjectDelete(0, buttonResetName);
   ObjectCreate(0, buttonResetName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, buttonResetName, OBJPROP_XDISTANCE, BUTTON_X);
   ObjectSetInteger(0, buttonResetName, OBJPROP_YDISTANCE, BUTTON_Y + (BUTTON_HEIGHT * 2) + 10);
   ObjectSetInteger(0, buttonResetName, OBJPROP_XSIZE, BUTTON_WIDTH);
   ObjectSetInteger(0, buttonResetName, OBJPROP_YSIZE, BUTTON_HEIGHT);
   ObjectSetInteger(0, buttonResetName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, buttonResetName, OBJPROP_BGCOLOR, clrDodgerBlue);
   ObjectSetInteger(0, buttonResetName, OBJPROP_COLOR, TEXT_COLOR);
   ObjectSetString(0, buttonResetName, OBJPROP_TEXT, "Reset Stats");
   ObjectSetString(0, buttonResetName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, buttonResetName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, buttonResetName, OBJPROP_SELECTABLE, false);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per creare il bottone Reset Trailing Stop               |
//+------------------------------------------------------------------+
void CreateResetTSButton()
{
   ObjectDelete(0, buttonResetTSName);
   ObjectCreate(0, buttonResetTSName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, buttonResetTSName, OBJPROP_XDISTANCE, BUTTON_X);
   ObjectSetInteger(0, buttonResetTSName, OBJPROP_YDISTANCE, BUTTON_Y + (BUTTON_HEIGHT * 3) + 15);
   ObjectSetInteger(0, buttonResetTSName, OBJPROP_XSIZE, BUTTON_WIDTH);
   ObjectSetInteger(0, buttonResetTSName, OBJPROP_YSIZE, BUTTON_HEIGHT);
   ObjectSetInteger(0, buttonResetTSName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, buttonResetTSName, OBJPROP_BGCOLOR, clrMediumPurple);
   ObjectSetInteger(0, buttonResetTSName, OBJPROP_COLOR, TEXT_COLOR);
   ObjectSetString(0, buttonResetTSName, OBJPROP_TEXT, "Reset Trailing");
   ObjectSetString(0, buttonResetTSName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, buttonResetTSName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, buttonResetTSName, OBJPROP_SELECTABLE, false);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per creare la label del timer                           |
//+------------------------------------------------------------------+
void CreateTimerLabel()
{
   ObjectDelete(0, timerLabel);
   ObjectCreate(0, timerLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, timerLabel, OBJPROP_XDISTANCE, BUTTON_X - 150);
   ObjectSetInteger(0, timerLabel, OBJPROP_YDISTANCE, BUTTON_Y + (BUTTON_HEIGHT * 4) + 25);
   ObjectSetInteger(0, timerLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, timerLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, timerLabel, OBJPROP_COLOR, clrYellow);
   ObjectSetString(0, timerLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, timerLabel, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, timerLabel, OBJPROP_TEXT, "Session: 00:00:00");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per creare le label del pannello informativo            |
//+------------------------------------------------------------------+
void CreateInfoLabels()
{
   int yPos = BUTTON_Y + (BUTTON_HEIGHT * 4) + 50;
   int lineHeight = 15;
   int labelX = BUTTON_X - 150;

   // Starting Balance
   ObjectDelete(0, startingBalanceLabel);
   ObjectCreate(0, startingBalanceLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, startingBalanceLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, startingBalanceLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, startingBalanceLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, startingBalanceLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, startingBalanceLabel, OBJPROP_COLOR, clrGold);
   ObjectSetString(0, startingBalanceLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, startingBalanceLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight;

   // Balance
   ObjectDelete(0, balanceLabel);
   ObjectCreate(0, balanceLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, balanceLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, balanceLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, balanceLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, balanceLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, balanceLabel, OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, balanceLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, balanceLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight;

   // Equity
   ObjectDelete(0, equityLabel);
   ObjectCreate(0, equityLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, equityLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, equityLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, equityLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, equityLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, equityLabel, OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, equityLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, equityLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight + 5;

   // Profit $
   ObjectDelete(0, profitLabel);
   ObjectCreate(0, profitLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, profitLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, profitLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, profitLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, profitLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, profitLabel, OBJPROP_COLOR, clrLime);
   ObjectSetString(0, profitLabel, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, profitLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight;

   // Profit %
   ObjectDelete(0, profitPctLabel);
   ObjectCreate(0, profitPctLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, profitPctLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, profitPctLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, profitPctLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, profitPctLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, profitPctLabel, OBJPROP_COLOR, clrLime);
   ObjectSetString(0, profitPctLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, profitPctLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight + 5;

   // Loss $
   ObjectDelete(0, lossLabel);
   ObjectCreate(0, lossLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lossLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, lossLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, lossLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, lossLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, lossLabel, OBJPROP_COLOR, clrRed);
   ObjectSetString(0, lossLabel, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, lossLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight;

   // Loss %
   ObjectDelete(0, lossPctLabel);
   ObjectCreate(0, lossPctLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lossPctLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, lossPctLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, lossPctLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, lossPctLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, lossPctLabel, OBJPROP_COLOR, clrRed);
   ObjectSetString(0, lossPctLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, lossPctLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight + 5;

   // Max DD $
   ObjectDelete(0, maxDDLabel);
   ObjectCreate(0, maxDDLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, maxDDLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, maxDDLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, maxDDLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, maxDDLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, maxDDLabel, OBJPROP_COLOR, clrOrangeRed);
   ObjectSetString(0, maxDDLabel, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, maxDDLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight;

   // Max DD %
   ObjectDelete(0, maxDDPctLabel);
   ObjectCreate(0, maxDDPctLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_COLOR, clrOrangeRed);
   ObjectSetString(0, maxDDPctLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight + 5;

   // Trailing Stop Active
   ObjectDelete(0, trailingStopActiveLabel);
   ObjectCreate(0, trailingStopActiveLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_COLOR, clrYellow);
   ObjectSetString(0, trailingStopActiveLabel, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_FONTSIZE, 9);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per aggiornare il timer di sessione                     |
//+------------------------------------------------------------------+
void UpdateSessionTimer()
{
   int elapsed = (int)(TimeCurrent() - sessionStartTime);
   int hours   = elapsed / 3600;
   int minutes = (elapsed % 3600) / 60;
   int seconds = elapsed % 60;

   string timerText = StringFormat("Session: %02d:%02d:%02d", hours, minutes, seconds);
   ObjectSetString(0, timerLabel, OBJPROP_TEXT, timerText);
}

//+------------------------------------------------------------------+
//| Funzione per aggiornare il pannello informativo                  |
//+------------------------------------------------------------------+
void UpdateInfoPanel(double currentEquity, double sessionPL, double sessionPLPercent)
{
   // Starting Balance
   ObjectSetString(0, startingBalanceLabel, OBJPROP_TEXT,
                   StringFormat("Starting Balance: %.2f", sessionStartBalance));

   // Balance
   ObjectSetString(0, balanceLabel, OBJPROP_TEXT,
                   StringFormat("Balance: %.2f", AccountInfoDouble(ACCOUNT_BALANCE)));

   // Equity
   ObjectSetString(0, equityLabel, OBJPROP_TEXT,
                   StringFormat("Equity: %.2f", currentEquity));

   // Profit / Loss
   if(sessionPL >= 0)
   {
      ObjectSetString(0, profitLabel, OBJPROP_TEXT,
                      StringFormat("Profit: +%.2f", sessionPL));
      ObjectSetString(0, profitPctLabel, OBJPROP_TEXT,
                      StringFormat("(+%.2f%%)", sessionPLPercent));
      ObjectSetInteger(0, profitLabel, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, profitPctLabel, OBJPROP_COLOR, clrLime);

      ObjectSetString(0, lossLabel, OBJPROP_TEXT, "Loss: -0.00");
      ObjectSetString(0, lossPctLabel, OBJPROP_TEXT, "(-0.00%)");
      ObjectSetInteger(0, lossLabel, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, lossPctLabel, OBJPROP_COLOR, clrGray);
   }
   else
   {
      ObjectSetString(0, profitLabel, OBJPROP_TEXT, "Profit: +0.00");
      ObjectSetString(0, profitPctLabel, OBJPROP_TEXT, "(+0.00%)");
      ObjectSetInteger(0, profitLabel, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, profitPctLabel, OBJPROP_COLOR, clrGray);

      ObjectSetString(0, lossLabel, OBJPROP_TEXT,
                      StringFormat("Loss: %.2f", sessionPL));
      ObjectSetString(0, lossPctLabel, OBJPROP_TEXT,
                      StringFormat("(%.2f%%)", sessionPLPercent));
      ObjectSetInteger(0, lossLabel, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, lossPctLabel, OBJPROP_COLOR, clrRed);
   }

   // Max Drawdown
   ObjectSetString(0, maxDDLabel, OBJPROP_TEXT,
                   StringFormat("Max DD: -%.2f", sessionMaxDrawdown));
   ObjectSetString(0, maxDDPctLabel, OBJPROP_TEXT,
                   StringFormat("(-%.2f%%)", sessionMaxDrawdownPercent));

   // Trailing Stop Active
   string tsText;
   if(trailingStopLevel == 0)
   {
      tsText = "Trailing Stop: None";
      ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_COLOR, clrGray);
   }
   else
   {
      double tpLevels[5] = {TP1, TP2, TP3, TP4, TP5};
      double protectedLevel = tpLevels[trailingStopLevel - 1];
      tsText = StringFormat("Trailing Stop: TP%d (%.2f)", trailingStopLevel, protectedLevel);
      ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_COLOR, clrYellow);
   }
   ObjectSetString(0, trailingStopActiveLabel, OBJPROP_TEXT, tsText);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per salvare i dati della sessione                       |
//+------------------------------------------------------------------+
void SaveSessionData()
{
   GlobalVariableSet("SM_SessionStartTime",         (double)sessionStartTime);
   GlobalVariableSet("SM_SessionStartBalance",      sessionStartBalance);
   GlobalVariableSet("SM_SessionStartEquity",       sessionStartEquity);
   GlobalVariableSet("SM_SessionPeakEquity",        sessionPeakEquity);
   GlobalVariableSet("SM_SessionMaxDrawdown",       sessionMaxDrawdown);
   GlobalVariableSet("SM_SessionMaxDrawdownPercent",sessionMaxDrawdownPercent);
   GlobalVariableSet("SM_TrailingStopLevel",        (double)trailingStopLevel);
   GlobalVariableSet("SM_SessionActive",            sessionActive ? 1.0 : 0.0);
}

//+------------------------------------------------------------------+
//| Funzione per pulire i dati della sessione                        |
//+------------------------------------------------------------------+
void CleanupSessionData()
{
   GlobalVariableDel("SM_SessionStartTime");
   GlobalVariableDel("SM_SessionStartBalance");
   GlobalVariableDel("SM_SessionStartEquity");
   GlobalVariableDel("SM_SessionPeakEquity");
   GlobalVariableDel("SM_SessionMaxDrawdown");
   GlobalVariableDel("SM_SessionMaxDrawdownPercent");
   GlobalVariableDel("SM_TrailingStopLevel");
   GlobalVariableDel("SM_SessionActive");
}

//+------------------------------------------------------------------+
//| Funzione per resettare le statistiche della sessione             |
//+------------------------------------------------------------------+
void ResetSessionStats()
{
   Print("========================================");
   Print("RESET STATISTICHE SESSIONE");
   Print("========================================");

   sessionStartTime      = TimeCurrent();
   sessionStartBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
   sessionStartEquity    = AccountInfoDouble(ACCOUNT_EQUITY);
   sessionPeakEquity     = sessionStartEquity;
   sessionMaxDrawdown    = 0;
   sessionMaxDrawdownPercent = 0;
   trailingStopLevel     = 0;
   sessionActive         = true;

   SaveSessionData();

   Print("Nuova sessione avviata alle: ", TimeToString(sessionStartTime, TIME_DATE|TIME_MINUTES));
   Print("========================================");

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double sessionPL = currentEquity - sessionStartEquity;
   double sessionPLPercent = (sessionStartEquity > 0) ? (sessionPL / sessionStartEquity * 100.0) : 0;
   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   Alert("Statistiche resettate!\n\n" +
         "Timer: 00:00:00\n" +
         "Max DD: 0.00\n" +
         "Profit/Loss: 0.00\n\n" +
         "Nuova sessione iniziata!");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per resettare solo il trailing stop                     |
//+------------------------------------------------------------------+
void ResetTrailingStop()
{
   Print("========================================");
   Print("RESET TRAILING STOP");
   Print("========================================");

   trailingStopLevel = 0;
   SaveSessionData();

   Print("Livello trailing stop resettato a 0");
   Print("Tutte le altre statistiche rimangono invariate");
   Print("========================================");

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double sessionPL = currentEquity - sessionStartEquity;
   double sessionPLPercent = (sessionStartEquity > 0) ? (sessionPL / sessionStartEquity * 100.0) : 0;
   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   Alert("Trailing Stop Resettato!\n\n" +
         "Livello trailing stop: None\n\n" +
         "Tutte le altre statistiche\n" +
         "rimangono invariate");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per controllare i livelli di trailing stop              |
//+------------------------------------------------------------------+
void CheckTrailingStop(double sessionPL)
{
   double tpLevels[5] = {TP1, TP2, TP3, TP4, TP5};

   // Controlla se abbiamo raggiunto un nuovo livello (solo se in profitto)
   if(sessionPL > 0)
   {
      for(int i = 4; i >= 0; i--)
      {
         if(tpLevels[i] > 0 && sessionPL >= (tpLevels[i] + ActivationOffset) && trailingStopLevel < (i + 1))
         {
            trailingStopLevel = i + 1;
            SaveSessionData();

            Print("========================================");
            Print("TRAILING STOP ATTIVATO - Livello ", trailingStopLevel);
            Print("Profit corrente: ", DoubleToString(sessionPL, 2));
            Print("Soglia attivazione: ", DoubleToString(tpLevels[i] + ActivationOffset, 2));
            Print("Stop Loss protetto: ", DoubleToString(tpLevels[i], 2));
            Print("========================================");

            Alert("Trailing Stop Attivato!\n\n" +
                  "Livello: TP" + IntegerToString(trailingStopLevel) + "\n" +
                  "Profit: " + DoubleToString(sessionPL, 2) + "\n" +
                  "Attivato a: " + DoubleToString(tpLevels[i] + ActivationOffset, 2) + "\n" +
                  "Stop Loss protetto: " + DoubleToString(tpLevels[i], 2) + "\n\n" +
                  "Le tue posizioni sono ora protette!");

            break;
         }
      }
   }

   // Controlla se il profit è sceso sotto il livello protetto → CHIUSURA TOTALE
   if(trailingStopLevel > 0)
   {
      double protectedLevel = tpLevels[trailingStopLevel - 1];

      if(sessionPL < protectedLevel)
      {
         // Conta posizioni aperte (mercato)
         int totalOrders = 0;
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            ulong ticket = PositionGetTicket(j);
            if(ticket > 0) totalOrders++;
         }
         // Conta ordini pendenti
         for(int j = OrdersTotal() - 1; j >= 0; j--)
         {
            ulong ticket = OrderGetTicket(j);
            if(ticket > 0) totalOrders++;
         }

         if(totalOrders > 0)
         {
            Print("========================================");
            Print("TRAILING STOP TRIGGERED - CHIUSURA TOTALE!");
            Print("Profit corrente: ", DoubleToString(sessionPL, 2));
            Print("Stop Loss protetto: ", DoubleToString(protectedLevel, 2));
            Print("Posizioni aperte: ", totalOrders);
            Print("Simula pressione bottone ROSSO...");
            Print("========================================");

            Alert("Trailing Stop Triggered!\n\n" +
                  "Profit sceso sotto " + DoubleToString(protectedLevel, 2) + "\n" +
                  "CHIUSURA TOTALE in corso...\n" +
                  "Posizioni + Grafici + Fine Sessione");

            CloseAllPositions();
            DisableAutoTrading();
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Funzione per chiudere solo le posizioni (senza fermare sessione) |
//+------------------------------------------------------------------+
void ClosePositionsOnly()
{
   Print("========================================");
   Print("CHIUSURA SOLO POSIZIONI (sessione continua)");
   Print("========================================");

   int totalClosed = 0;

   // Chiudi tutte le posizioni di mercato
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(trade.PositionClose(ticket))
         {
            totalClosed++;
            Print("Posizione chiusa - Ticket: ", ticket);
         }
         else
         {
            Print("Errore chiusura ticket ", ticket, " - Codice: ", trade.ResultRetcode());
         }
      }
   }

   // Elimina tutti gli ordini pendenti
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(trade.OrderDelete(ticket))
         {
            totalClosed++;
            Print("Ordine pendente eliminato - Ticket: ", ticket);
         }
         else
         {
            Print("Errore eliminazione ordine ", ticket, " - Codice: ", trade.ResultRetcode());
         }
      }
   }

   Print("Totale posizioni/ordini chiusi: ", totalClosed);
   Print("Sessione continua...");
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Funzione per chiudere tutti i grafici eccetto il corrente        |
//+------------------------------------------------------------------+
void CloseAllOtherCharts()
{
   long myChartID = ChartID();
   long currentChartID = ChartFirst();

   while(currentChartID >= 0)
   {
      long nextChartID = ChartNext(currentChartID);
      if(currentChartID != myChartID)
      {
         ChartClose(currentChartID);
         Print("Grafico chiuso: ", currentChartID);
      }
      currentChartID = nextChartID;
   }
}

//+------------------------------------------------------------------+
//| Funzione per chiudere tutto (posizioni + grafici + sessione)     |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   Print("========================================");
   Print("CHIUSURA TOTALE - Sessione terminata");
   Print("========================================");

   // 1. Prima chiudi tutti gli altri grafici (rimuove altri EA)
   CloseAllOtherCharts();

   int totalClosed = 0;

   // 2. Chiudi tutte le posizioni di mercato
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(trade.PositionClose(ticket))
         {
            totalClosed++;
            Print("Posizione chiusa - Ticket: ", ticket);
         }
         else
         {
            Print("Errore chiusura ticket ", ticket, " - Codice: ", trade.ResultRetcode());
         }
      }
   }

   // 3. Elimina tutti gli ordini pendenti
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(trade.OrderDelete(ticket))
         {
            totalClosed++;
            Print("Ordine pendente eliminato - Ticket: ", ticket);
         }
         else
         {
            Print("Errore eliminazione ordine ", ticket, " - Codice: ", trade.ResultRetcode());
         }
      }
   }

   Print("Totale posizioni/ordini chiusi: ", totalClosed);

   // 4. Termina la sessione
   sessionActive = false;
   CleanupSessionData();

   Print("Sessione terminata");
   Print("========================================");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per disabilitare il trading automatico                  |
//+------------------------------------------------------------------+
void DisableAutoTrading()
{
   Print("========================================");
   Print("IMPORTANTE: Disattiva manualmente");
   Print("il pulsante 'Algo Trading' nella toolbar MT5!");
   Print("========================================");
}
//+------------------------------------------------------------------+
