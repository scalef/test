//+------------------------------------------------------------------+
//|                                            SessionManagerEA.mq4 |
//|                                                                  |
//|                                Expert Advisor per gestione       |
//|                                sessioni e chiusura posizioni     |
//+------------------------------------------------------------------+
#property copyright "Session Manager EA"
#property version   "1.00"
#property strict

// Parametri input - Risk Management
input double DailyTakeProfit = 500;  // Daily Take Profit in $ (0 = disabled)
input double DailyStopLoss = 500;    // Daily Stop Loss in $ (0 = disabled)
input double DailyTakeProfitPercent = 0;  // Daily Take Profit in % (0 = disabled)
input double DailyStopLossPercent = 0;    // Daily Stop Loss in % (0 = disabled)

// Parametri input - Trailing Stop Levels
input double TP1 = 100;   // TP1 - Primo livello breakeven (0 = disabled)
input double TP2 = 150;  // TP2 - Secondo livello breakeven (0 = disabled)
input double TP3 = 200;  // TP3 - Terzo livello breakeven (0 = disabled)
input double TP4 = 300;  // TP4 - Quarto livello breakeven (0 = disabled)
input double TP5 = 500;  // TP5 - Quinto livello breakeven (0 = disabled)
input double ActivationOffset = 100;  // Offset attivazione: raggiungi TP+N per attivare SL a TP

// Parametri interfaccia - Valori fissi
#define BUTTON_X 170          // Posizione X del bottone (dal bordo destro)
#define BUTTON_Y 50           // Posizione Y del bottone
#define BUTTON_WIDTH 150      // Larghezza del bottone
#define BUTTON_HEIGHT 30      // Altezza del bottone
#define BUTTON_COLOR clrRed   // Colore del bottone
#define TEXT_COLOR clrWhite   // Colore del testo

// Variabili globali - Sessione
datetime sessionStartTime = 0;     // Tempo di inizio sessione
bool sessionActive = false;        // Stato della sessione
double sessionStartBalance = 0;    // Balance all'inizio della sessione
double sessionStartEquity = 0;     // Equity all'inizio della sessione
double sessionPeakEquity = 0;      // Picco massimo di equity raggiunto
double sessionMaxDrawdown = 0;     // Max drawdown in valore assoluto
double sessionMaxDrawdownPercent = 0; // Max drawdown in percentuale
int trailingStopLevel = 0;         // Livello trailing stop raggiunto (0-5)

// Variabili globali - Oggetti grafici
string buttonName = "CloseAllBtn"; // Nome del bottone principale
string buttonStopName = "CloseAllStopBtn"; // Nome del bottone STOP
string buttonResetName = "ResetStatsBtn"; // Nome del bottone RESET
string buttonResetTSName = "ResetTrailingStopBtn"; // Nome del bottone RESET TRAILING STOP
string timerLabel = "SessionTimer"; // Nome label timer
string startingBalanceLabel = "StartingBalanceLabel"; // Label starting balance
string balanceLabel = "BalanceLabel"; // Label balance
string equityLabel = "EquityLabel";   // Label equity
string profitLabel = "ProfitLabel";   // Label profitto
string profitPctLabel = "ProfitPctLabel"; // Label profitto %
string lossLabel = "LossLabel";       // Label perdita
string lossPctLabel = "LossPctLabel"; // Label perdita %
string maxDDLabel = "MaxDDLabel";     // Label max drawdown $
string maxDDPctLabel = "MaxDDPctLabel"; // Label max drawdown %
string trailingStopActiveLabel = "TrailingStopActiveLabel"; // Label trailing stop attivo

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
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
      sessionStartTime = (datetime)GlobalVariableGet("SM_SessionStartTime");
      sessionStartBalance = GlobalVariableGet("SM_SessionStartBalance");
      sessionStartEquity = GlobalVariableGet("SM_SessionStartEquity");
      sessionPeakEquity = GlobalVariableGet("SM_SessionPeakEquity");
      sessionMaxDrawdown = GlobalVariableGet("SM_SessionMaxDrawdown");
      sessionMaxDrawdownPercent = GlobalVariableGet("SM_SessionMaxDrawdownPercent");
      trailingStopLevel = (int)GlobalVariableGet("SM_TrailingStopLevel");
      sessionActive = true;

      Print("========================================");
      Print("Session Manager EA inizializzato");
      Print("SESSIONE ESISTENTE RIPRISTINATA");
      Print("Sessione avviata alle: ", TimeToString(sessionStartTime, TIME_DATE|TIME_MINUTES));
      Print("Balance iniziale: ", DoubleToString(sessionStartBalance, 2));
      Print("Equity iniziale: ", DoubleToString(sessionStartEquity, 2));
      Print("Peak Equity: ", DoubleToString(sessionPeakEquity, 2));
      Print("Max Drawdown: ", DoubleToString(sessionMaxDrawdown, 2));
      Print("========================================");
   }
   else
   {
      // Avvia nuova sessione
      sessionStartTime = TimeCurrent();
      sessionStartBalance = AccountBalance();
      sessionStartEquity = AccountEquity();
      sessionPeakEquity = sessionStartEquity;
      sessionMaxDrawdown = 0;
      sessionMaxDrawdownPercent = 0;
      trailingStopLevel = 0;
      sessionActive = true;

      // Salva i dati iniziali
      SaveSessionData();

      Print("========================================");
      Print("Session Manager EA inizializzato");
      Print("NUOVA SESSIONE AVVIATA");
      Print("Sessione avviata alle: ", TimeToString(sessionStartTime, TIME_DATE|TIME_MINUTES));
      Print("Balance iniziale: ", DoubleToString(sessionStartBalance, 2));
      Print("Equity iniziale: ", DoubleToString(sessionStartEquity, 2));
      Print("========================================");
   }

   if(DailyTakeProfit > 0)
      Print("Take Profit giornaliero: ", DoubleToString(DailyTakeProfit, 2));
   if(DailyStopLoss > 0)
      Print("Stop Loss giornaliero: ", DoubleToString(DailyStopLoss, 2));
   Print("========================================");

   // Inizializza il pannello informativo con i valori iniziali
   double currentEquity = AccountEquity();
   double sessionPL = currentEquity - sessionStartEquity;
   double sessionPLPercent = (sessionStartEquity > 0) ? (sessionPL / sessionStartEquity * 100.0) : 0;
   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   // Imposta timer per aggiornare il pannello ogni secondo
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Salva i dati della sessione se è attiva (per ripristino dopo cambio parametri)
   if(sessionActive)
   {
      SaveSessionData();
      Print("Dati sessione salvati per ripristino");
   }
   else
   {
      // Sessione terminata - pulisci le variabili globali
      CleanupSessionData();
      Print("Dati sessione rimossi (sessione terminata)");
   }

   // Ferma il timer
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

   Print("Session Manager EA disattivato");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Se la sessione non è attiva, non fare nulla
   if(!sessionActive)
      return;

   // Aggiorna il timer
   UpdateSessionTimer();

   // Calcola il P&L di sessione
   double currentEquity = AccountEquity();
   double sessionPL = currentEquity - sessionStartEquity;
   double sessionPLPercent = (sessionStartEquity > 0) ? (sessionPL / sessionStartEquity * 100.0) : 0;

   // Aggiorna picco equity e calcola drawdown
   if(currentEquity > sessionPeakEquity)
      sessionPeakEquity = currentEquity;

   double currentDrawdown = sessionPeakEquity - currentEquity;
   double currentDrawdownPercent = (sessionPeakEquity > 0) ? (currentDrawdown / sessionPeakEquity * 100.0) : 0;

   // Aggiorna max drawdown se necessario
   if(currentDrawdown > sessionMaxDrawdown)
   {
      sessionMaxDrawdown = currentDrawdown;
      sessionMaxDrawdownPercent = currentDrawdownPercent;

      // Salva i dati aggiornati
      SaveSessionData();
   }

   // Aggiorna il pannello informativo
   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   // Controlla i livelli di trailing stop
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

      // Simula il click del bottone
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

      // Simula il click del bottone
      CloseAllPositions();
      DisableAutoTrading();
      return;
   }
}

//+------------------------------------------------------------------+
//| Timer function - si esegue ogni secondo                          |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Se la sessione non è attiva, non fare nulla
   if(!sessionActive)
      return;

   // Aggiorna il timer (ogni secondo)
   UpdateSessionTimer();

   // Calcola e aggiorna il pannello informativo
   double currentEquity = AccountEquity();
   double sessionPL = currentEquity - sessionStartEquity;
   double sessionPLPercent = (sessionStartEquity > 0) ? (sessionPL / sessionStartEquity * 100.0) : 0;

   // Aggiorna picco equity e calcola drawdown
   if(currentEquity > sessionPeakEquity)
      sessionPeakEquity = currentEquity;

   double currentDrawdown = sessionPeakEquity - currentEquity;
   double currentDrawdownPercent = (sessionPeakEquity > 0) ? (currentDrawdown / sessionPeakEquity * 100.0) : 0;

   // Aggiorna max drawdown se necessario
   if(currentDrawdown > sessionMaxDrawdown)
   {
      sessionMaxDrawdown = currentDrawdown;
      sessionMaxDrawdownPercent = currentDrawdownPercent;

      // Salva i dati aggiornati
      SaveSessionData();
   }

   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   // Controlla i livelli di trailing stop
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

      // Simula il click del bottone
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

      // Simula il click del bottone
      CloseAllPositions();
      DisableAutoTrading();
      return;
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Controlla se è stato cliccato un bottone
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == buttonName)
      {
         // Bottone "Close All" - chiude solo posizioni
         Print("Bottone Close All premuto - Chiusura solo posizioni...");
         ClosePositionsOnly();

         // Reset del bottone
         ObjectSetInteger(0, buttonName, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == buttonStopName)
      {
         // Bottone "Close All & STOP" - chiude tutto
         Print("Bottone Close All & STOP premuto - Chiusura totale...");
         CloseAllPositions();
         DisableAutoTrading();

         // Reset del bottone
         ObjectSetInteger(0, buttonStopName, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == buttonResetName)
      {
         // Bottone "Reset Stats" - resetta statistiche
         Print("Bottone Reset Stats premuto - Reset statistiche...");
         ResetSessionStats();

         // Reset del bottone
         ObjectSetInteger(0, buttonResetName, OBJPROP_STATE, false);
         ChartRedraw();
      }
      else if(sparam == buttonResetTSName)
      {
         // Bottone "Reset Trailing Stop" - resetta solo trailing stop
         Print("Bottone Reset Trailing Stop premuto - Reset livello trailing stop...");
         ResetTrailingStop();

         // Reset del bottone
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
   // Elimina il bottone se esiste già
   ObjectDelete(0, buttonName);

   // Crea il bottone
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
   ObjectSetInteger(0, buttonName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, buttonName, OBJPROP_SELECTABLE, false);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per creare il bottone Close All & STOP                  |
//+------------------------------------------------------------------+
void CreateCloseStopButton()
{
   // Elimina il bottone se esiste già
   ObjectDelete(0, buttonStopName);

   // Crea il bottone
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
   // Elimina il bottone se esiste già
   ObjectDelete(0, buttonResetName);

   // Crea il bottone
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
   // Elimina il bottone se esiste già
   ObjectDelete(0, buttonResetTSName);

   // Crea il bottone
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
   // Elimina la label se esiste già
   ObjectDelete(0, timerLabel);

   // Crea la label - allineata al lato destro del bottone
   ObjectCreate(0, timerLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, timerLabel, OBJPROP_XDISTANCE, BUTTON_X - 150);
   ObjectSetInteger(0, timerLabel, OBJPROP_YDISTANCE, BUTTON_Y + (BUTTON_HEIGHT * 4) + 25); // Sotto i quattro bottoni
   ObjectSetInteger(0, timerLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, timerLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, timerLabel, OBJPROP_COLOR, clrYellow);
   ObjectSetString(0, timerLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, timerLabel, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, timerLabel, OBJPROP_TEXT, "Session: 00:00:00");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per aggiornare il timer della sessione                  |
//+------------------------------------------------------------------+
void UpdateSessionTimer()
{
   datetime currentTime = TimeCurrent();
   int elapsedSeconds = (int)(currentTime - sessionStartTime);

   int hours = elapsedSeconds / 3600;
   int minutes = (elapsedSeconds % 3600) / 60;
   int seconds = elapsedSeconds % 60;

   string timeStr = StringFormat("Session: %02d:%02d:%02d", hours, minutes, seconds);
   ObjectSetString(0, timerLabel, OBJPROP_TEXT, timeStr);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per creare le label del pannello informativo            |
//+------------------------------------------------------------------+
void CreateInfoLabels()
{
   int yPos = BUTTON_Y + (BUTTON_HEIGHT * 4) + 50; // Posizione iniziale sotto il timer
   int lineHeight = 15; // Spaziatura tra le righe
   int labelX = BUTTON_X - 150; // Offset per allineamento perfetto

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
   yPos += lineHeight + 5; // Spazio extra

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
   yPos += lineHeight + 5; // Spazio extra

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
   yPos += lineHeight + 5; // Spazio extra

   // Max Drawdown $
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

   // Max Drawdown %
   ObjectDelete(0, maxDDPctLabel);
   ObjectCreate(0, maxDDPctLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_XDISTANCE, labelX);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_COLOR, clrOrangeRed);
   ObjectSetString(0, maxDDPctLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, maxDDPctLabel, OBJPROP_FONTSIZE, 9);
   yPos += lineHeight + 5; // Spazio extra

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
//| Funzione per aggiornare il pannello informativo                  |
//+------------------------------------------------------------------+
void UpdateInfoPanel(double currentEquity, double sessionPL, double sessionPLPercent)
{
   // Aggiorna Starting Balance
   string startingBalanceText = StringFormat("Starting Balance: %.2f", sessionStartBalance);
   ObjectSetString(0, startingBalanceLabel, OBJPROP_TEXT, startingBalanceText);

   // Aggiorna Balance
   string balanceText = StringFormat("Balance: %.2f", AccountBalance());
   ObjectSetString(0, balanceLabel, OBJPROP_TEXT, balanceText);

   // Aggiorna Equity
   string equityText = StringFormat("Equity: %.2f", currentEquity);
   ObjectSetString(0, equityLabel, OBJPROP_TEXT, equityText);

   // Aggiorna Profit/Loss - mostra sempre entrambi
   if(sessionPL >= 0)
   {
      // Mostra profitto reale
      string profitText = StringFormat("Profit: +%.2f", sessionPL);
      string profitPctText = StringFormat("(+%.2f%%)", sessionPLPercent);

      ObjectSetString(0, profitLabel, OBJPROP_TEXT, profitText);
      ObjectSetString(0, profitPctLabel, OBJPROP_TEXT, profitPctText);
      ObjectSetInteger(0, profitLabel, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, profitPctLabel, OBJPROP_COLOR, clrLime);

      // Mostra perdita a zero
      ObjectSetString(0, lossLabel, OBJPROP_TEXT, "Loss: -0.00");
      ObjectSetString(0, lossPctLabel, OBJPROP_TEXT, "(-0.00%)");
      ObjectSetInteger(0, lossLabel, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, lossPctLabel, OBJPROP_COLOR, clrGray);
   }
   else
   {
      // Mostra profitto a zero
      ObjectSetString(0, profitLabel, OBJPROP_TEXT, "Profit: +0.00");
      ObjectSetString(0, profitPctLabel, OBJPROP_TEXT, "(+0.00%)");
      ObjectSetInteger(0, profitLabel, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, profitPctLabel, OBJPROP_COLOR, clrGray);

      // Mostra perdita reale
      string lossText = StringFormat("Loss: %.2f", sessionPL);
      string lossPctText = StringFormat("(%.2f%%)", sessionPLPercent);

      ObjectSetString(0, lossLabel, OBJPROP_TEXT, lossText);
      ObjectSetString(0, lossPctLabel, OBJPROP_TEXT, lossPctText);
      ObjectSetInteger(0, lossLabel, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, lossPctLabel, OBJPROP_COLOR, clrRed);
   }

   // Aggiorna Max Drawdown - sempre visibile
   string maxDDText = StringFormat("Max DD: -%.2f", sessionMaxDrawdown);
   string maxDDPctText = StringFormat("(-%.2f%%)", sessionMaxDrawdownPercent);

   ObjectSetString(0, maxDDLabel, OBJPROP_TEXT, maxDDText);
   ObjectSetString(0, maxDDPctLabel, OBJPROP_TEXT, maxDDPctText);

   // Aggiorna Trailing Stop Active
   string trailingStopText;
   if(trailingStopLevel == 0)
   {
      trailingStopText = "Trailing Stop: None";
      ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_COLOR, clrGray);
   }
   else
   {
      // Array dei livelli per ottenere il valore
      double tpLevels[5];
      tpLevels[0] = TP1;
      tpLevels[1] = TP2;
      tpLevels[2] = TP3;
      tpLevels[3] = TP4;
      tpLevels[4] = TP5;

      double protectedLevel = tpLevels[trailingStopLevel - 1];
      trailingStopText = StringFormat("Trailing Stop: TP%d (%.2f)", trailingStopLevel, protectedLevel);
      ObjectSetInteger(0, trailingStopActiveLabel, OBJPROP_COLOR, clrYellow);
   }
   ObjectSetString(0, trailingStopActiveLabel, OBJPROP_TEXT, trailingStopText);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per salvare i dati della sessione                       |
//+------------------------------------------------------------------+
void SaveSessionData()
{
   GlobalVariableSet("SM_SessionStartTime", (double)sessionStartTime);
   GlobalVariableSet("SM_SessionStartBalance", sessionStartBalance);
   GlobalVariableSet("SM_SessionStartEquity", sessionStartEquity);
   GlobalVariableSet("SM_SessionPeakEquity", sessionPeakEquity);
   GlobalVariableSet("SM_SessionMaxDrawdown", sessionMaxDrawdown);
   GlobalVariableSet("SM_SessionMaxDrawdownPercent", sessionMaxDrawdownPercent);
   GlobalVariableSet("SM_TrailingStopLevel", (double)trailingStopLevel);
   GlobalVariableSet("SM_SessionActive", sessionActive ? 1.0 : 0.0);
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

   // Resetta tutti i valori della sessione
   sessionStartTime = TimeCurrent();
   sessionStartBalance = AccountBalance();
   sessionStartEquity = AccountEquity();
   sessionPeakEquity = sessionStartEquity;
   sessionMaxDrawdown = 0;
   sessionMaxDrawdownPercent = 0;
   trailingStopLevel = 0;
   sessionActive = true;

   // Salva i nuovi valori iniziali
   SaveSessionData();

   Print("Nuova sessione avviata alle: ", TimeToString(sessionStartTime, TIME_DATE|TIME_MINUTES));
   Print("Balance iniziale: ", DoubleToString(sessionStartBalance, 2));
   Print("Equity iniziale: ", DoubleToString(sessionStartEquity, 2));
   Print("========================================");

   // Aggiorna il pannello
   double currentEquity = AccountEquity();
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

   // Resetta solo il livello di trailing stop
   trailingStopLevel = 0;

   // Salva il nuovo valore
   SaveSessionData();

   Print("Livello trailing stop resettato a 0");
   Print("Tutte le altre statistiche rimangono invariate");
   Print("========================================");

   // Aggiorna il pannello per mostrare "Trailing Stop: None"
   double currentEquity = AccountEquity();
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
   // Array dei livelli TP in ordine
   double tpLevels[5];
   tpLevels[0] = TP1;
   tpLevels[1] = TP2;
   tpLevels[2] = TP3;
   tpLevels[3] = TP4;
   tpLevels[4] = TP5;

   // Controlla se abbiamo raggiunto un nuovo livello (solo se in profitto)
   if(sessionPL > 0)
   {
      for(int i = 4; i >= 0; i--)  // Controlla dal più alto al più basso
      {
         // Attiva il trailing stop quando raggiungi TP + ActivationOffset
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
                  "Livello: TP", IntegerToString(trailingStopLevel), "\n" +
                  "Profit: ", DoubleToString(sessionPL, 2), "\n" +
                  "Attivato a: ", DoubleToString(tpLevels[i] + ActivationOffset, 2), "\n" +
                  "Stop Loss protetto: ", DoubleToString(tpLevels[i], 2), "\n\n" +
                  "Le tue posizioni sono ora protette!");

            break;  // Esci dopo aver trovato il livello più alto raggiunto
         }
      }
   }

   // Controlla se il profit è sceso sotto il livello protetto
   if(trailingStopLevel > 0)
   {
      double protectedLevel = tpLevels[trailingStopLevel - 1];

      // Quando il profit scende sotto il livello protetto → CHIUSURA TOTALE (bottone rosso)
      if(sessionPL < protectedLevel)
      {
         // Controlla se ci sono posizioni aperte prima di triggerare
         int totalOrders = 0;
         for(int j = 0; j < OrdersTotal(); j++)
         {
            if(OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
            {
               if(OrderType() == OP_BUY || OrderType() == OP_SELL)
                  totalOrders++;
            }
         }

         // Triggera solo se ci sono posizioni da chiudere
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
                  "Profit sceso sotto ", DoubleToString(protectedLevel, 2), "\n" +
                  "CHIUSURA TOTALE in corso...\n" +
                  "Posizioni + Grafici + Fine Sessione");

            // Chiusura totale come bottone ROSSO (Close All & STOP)
            CloseAllPositions();
            DisableAutoTrading();
            return; // Esci dalla funzione
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
   int maxAttempts = 5;

   for(int attempt = 1; attempt <= maxAttempts; attempt++)
   {
      RefreshRates();

      int total = OrdersTotal();
      if(total == 0) break;

      int closed = 0;

      for(int i = total - 1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

         bool result = false;
         string orderSymbol = OrderSymbol();
         int orderType = OrderType();
         int ticket = OrderTicket();
         double lots = OrderLots();

         if(orderType == OP_BUY)
         {
            double closePrice = SymbolInfoDouble(orderSymbol, SYMBOL_BID);
            if(closePrice <= 0) closePrice = MarketInfo(orderSymbol, MODE_BID);

            if(closePrice > 0)
            {
               int digits = (int)MarketInfo(orderSymbol, MODE_DIGITS);
               closePrice = NormalizeDouble(closePrice, digits);
               result = OrderClose(ticket, lots, closePrice, 50, clrNONE);
            }
         }
         else if(orderType == OP_SELL)
         {
            double closePrice = SymbolInfoDouble(orderSymbol, SYMBOL_ASK);
            if(closePrice <= 0) closePrice = MarketInfo(orderSymbol, MODE_ASK);

            if(closePrice > 0)
            {
               int digits = (int)MarketInfo(orderSymbol, MODE_DIGITS);
               closePrice = NormalizeDouble(closePrice, digits);
               result = OrderClose(ticket, lots, closePrice, 50, clrNONE);
            }
         }
         else
         {
            result = OrderDelete(ticket);
         }

         if(result)
         {
            closed++;
            totalClosed++;
         }
      }

      if(closed > 0)
         Print("Tentativo ", attempt, ": chiusi ", closed, " ordini");
   }

   Print("========================================");
   Print("CHIUSURA POSIZIONI COMPLETATA");
   Print("Totale ordini chiusi: ", totalClosed);
   Print("Ordini rimanenti: ", OrdersTotal());
   Print("Sessione continua...");
   Print("========================================");

   // La sessione NON viene fermata - continua a tracciare
   Alert("Posizioni chiuse!\n\n" +
         "Ordini chiusi: " + IntegerToString(totalClosed) + "\n" +
         "La sessione continua...");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per chiudere tutti i grafici tranne quello corrente     |
//+------------------------------------------------------------------+
void CloseAllOtherCharts()
{
   Print("========================================");
   Print("CHIUSURA DI TUTTI I GRAFICI (tranne corrente)");
   Print("========================================");

   int closedCharts = 0;
   long myChartID = ChartID(); // ID del grafico corrente (Session Manager)
   long currentChartID = ChartFirst();

   while(currentChartID >= 0)
   {
      // Salva l'ID del prossimo grafico PRIMA di chiudere quello corrente
      long nextChartID = ChartNext(currentChartID);

      // Chiudi tutti i grafici TRANNE quello corrente
      if(currentChartID != myChartID)
      {
         string symbol = ChartSymbol(currentChartID);
         Print("Chiusura grafico ID ", currentChartID, " (", symbol, ")...");

         if(ChartClose(currentChartID))
         {
            closedCharts++;
            Print("✓ Grafico ", symbol, " chiuso con successo");
         }
         else
         {
            Print("✗ Impossibile chiudere grafico ", symbol);
         }
      }

      currentChartID = nextChartID;
   }

   Print("========================================");
   Print("Grafici chiusi: ", closedCharts);
   Print("Grafico Session Manager rimane aperto");
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Funzione per chiudere tutte le posizioni aperte                  |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   // PASSO 1: Chiudi tutti i grafici tranne quello corrente (elimina Thanos)
   CloseAllOtherCharts();

   // PASSO 2: Chiudi tutte le posizioni
   Print("========================================");
   Print("INIZIO CHIUSURA IMMEDIATA DI TUTTE LE POSIZIONI");
   Print("========================================");

   int totalClosed = 0;
   int maxAttempts = 5; // Ora solo 5 tentativi dato che Thanos è stato rimosso

   for(int attempt = 1; attempt <= maxAttempts; attempt++)
   {
      RefreshRates();

      int total = OrdersTotal();
      if(total == 0) break;

      int closed = 0;

      for(int i = total - 1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

         bool result = false;
         string orderSymbol = OrderSymbol();
         int orderType = OrderType();
         int ticket = OrderTicket();
         double lots = OrderLots();

         if(orderType == OP_BUY)
         {
            double closePrice = SymbolInfoDouble(orderSymbol, SYMBOL_BID);
            if(closePrice <= 0) closePrice = MarketInfo(orderSymbol, MODE_BID);

            if(closePrice > 0)
            {
               int digits = (int)MarketInfo(orderSymbol, MODE_DIGITS);
               closePrice = NormalizeDouble(closePrice, digits);
               result = OrderClose(ticket, lots, closePrice, 50, clrNONE);
            }
         }
         else if(orderType == OP_SELL)
         {
            double closePrice = SymbolInfoDouble(orderSymbol, SYMBOL_ASK);
            if(closePrice <= 0) closePrice = MarketInfo(orderSymbol, MODE_ASK);

            if(closePrice > 0)
            {
               int digits = (int)MarketInfo(orderSymbol, MODE_DIGITS);
               closePrice = NormalizeDouble(closePrice, digits);
               result = OrderClose(ticket, lots, closePrice, 50, clrNONE);
            }
         }
         else
         {
            result = OrderDelete(ticket);
         }

         if(result)
         {
            closed++;
            totalClosed++;
         }
      }

      if(closed > 0)
         Print("Tentativo ", attempt, ": chiusi ", closed, " ordini");
   }

   Print("========================================");
   Print("CHIUSURA COMPLETATA");
   Print("Totale ordini chiusi: ", totalClosed);
   Print("Ordini rimanenti: ", OrdersTotal());
   Print("========================================");

   // Ferma la sessione (il timer rimane con il tempo finale)
   sessionActive = false;

   // Pulisci i dati salvati (sessione terminata)
   CleanupSessionData();

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per ottenere la descrizione degli errori                |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code)
{
   switch(error_code)
   {
      case 0:   return "Nessun errore";
      case 1:   return "Nessun errore, ma risultato sconosciuto";
      case 2:   return "Errore comune";
      case 3:   return "Parametri invalidi";
      case 4:   return "Server di trading occupato";
      case 5:   return "Vecchia versione del terminale client";
      case 6:   return "Nessuna connessione con il server di trading";
      case 7:   return "Non abbastanza diritti";
      case 8:   return "Richieste troppo frequenti";
      case 9:   return "Operazione non autorizzata";
      case 64:  return "Account disabilitato";
      case 65:  return "Numero di account invalido";
      case 128: return "Timeout dell'ordine";
      case 129: return "Prezzo invalido";
      case 130: return "Stop invalidi";
      case 131: return "Volume invalido";
      case 132: return "Mercato chiuso";
      case 133: return "Trading disabilitato";
      case 134: return "Fondi insufficienti";
      case 135: return "Prezzo cambiato";
      case 136: return "Nessun prezzo";
      case 137: return "Broker occupato";
      case 138: return "Nuovi prezzi";
      case 139: return "Ordine bloccato";
      case 140: return "Trading consentito solo per posizioni lunghe";
      case 141: return "Troppe richieste";
      case 145: return "Modifica negata perché troppo vicino al mercato";
      case 146: return "Sottosistema di trading occupato";
      case 147: return "Uso della data di scadenza negato dal broker";
      case 148: return "Numero di ordini aperti e pending raggiunto";
      default:  return "Errore sconosciuto";
   }
}

//+------------------------------------------------------------------+
//| Funzione per chiudere tutti i grafici aperti su MT4              |
//+------------------------------------------------------------------+
void CloseAllCharts()
{
   Print("Inizio chiusura di tutti i grafici...");

   // Conta quanti grafici ci sono
   int chartCount = 0;
   long currentChartID = ChartFirst();

   while(currentChartID >= 0)
   {
      chartCount++;
      currentChartID = ChartNext(currentChartID);
   }

   Print("Trovati ", chartCount, " grafici aperti");

   // Chiudi tutti i grafici tranne l'ultimo (altrimenti MT4 potrebbe crashare)
   // Partiamo dal primo grafico
   currentChartID = ChartFirst();
   int closed = 0;

   while(currentChartID >= 0)
   {
      long nextChartID = ChartNext(currentChartID);

      // Chiudi il grafico corrente
      if(ChartClose(currentChartID))
      {
         closed++;
         Print("Grafico ID ", currentChartID, " chiuso");
      }
      else
      {
         Print("Impossibile chiudere grafico ID ", currentChartID);
      }

      currentChartID = nextChartID;
   }

   Print("Chiusura grafici completata. Grafici chiusi: ", closed, " su ", chartCount);
}

//+------------------------------------------------------------------+
//| Funzione per disattivare il trading automatico                   |
//+------------------------------------------------------------------+
void DisableAutoTrading()
{
   Print("========================================");
   Print("OPERAZIONE COMPLETATA");
   Print("========================================");

   // Mostra un alert all'utente
   Alert("OPERAZIONE COMPLETATA!\n\n" +
         "✓ Tutti i grafici chiusi (tranne Session Manager)\n" +
         "✓ Tutte le posizioni chiuse\n\n" +
         "EA Thanos rimosso!");

   // Cambia il colore del bottone per indicare che l'azione è completata
   ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, clrGreen);
   ObjectSetString(0, buttonName, OBJPROP_TEXT, "DONE!");
   ObjectSetInteger(0, buttonName, OBJPROP_FONTSIZE, 10);
   ChartRedraw();

   Print("Operazione completata con successo!");
}

//+------------------------------------------------------------------+
