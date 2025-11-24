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
input double DailyTakeProfit = 100;  // Daily Take Profit (0 = disabled)
input double DailyStopLoss = 75;    // Daily Stop Loss (0 = disabled)

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

// Variabili globali - Oggetti grafici
string buttonName = "CloseAllBtn"; // Nome del bottone principale
string buttonStopName = "CloseAllStopBtn"; // Nome del bottone STOP
string timerLabel = "SessionTimer"; // Nome label timer
string balanceLabel = "BalanceLabel"; // Label balance
string equityLabel = "EquityLabel";   // Label equity
string profitLabel = "ProfitLabel";   // Label profitto
string profitPctLabel = "ProfitPctLabel"; // Label profitto %
string lossLabel = "LossLabel";       // Label perdita
string lossPctLabel = "LossPctLabel"; // Label perdita %
string maxDDLabel = "MaxDDLabel";     // Label max drawdown $
string maxDDPctLabel = "MaxDDPctLabel"; // Label max drawdown %

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Crea i bottoni
   CreateCloseButton();
   CreateCloseStopButton();

   // Crea le label del pannello informativo
   CreateTimerLabel();
   CreateInfoLabels();

   // Avvia la sessione e salva i valori iniziali
   sessionStartTime = TimeCurrent();
   sessionStartBalance = AccountBalance();
   sessionStartEquity = AccountEquity();
   sessionPeakEquity = sessionStartEquity; // Inizia dal valore iniziale
   sessionMaxDrawdown = 0;
   sessionMaxDrawdownPercent = 0;
   sessionActive = true;

   Print("========================================");
   Print("Session Manager EA inizializzato");
   Print("Sessione avviata alle: ", TimeToString(sessionStartTime, TIME_DATE|TIME_MINUTES));
   Print("Balance iniziale: ", DoubleToString(sessionStartBalance, 2));
   Print("Equity iniziale: ", DoubleToString(sessionStartEquity, 2));
   if(DailyTakeProfit > 0)
      Print("Take Profit giornaliero: ", DoubleToString(DailyTakeProfit, 2));
   if(DailyStopLoss > 0)
      Print("Stop Loss giornaliero: ", DoubleToString(DailyStopLoss, 2));
   Print("========================================");

   // Inizializza il pannello informativo con i valori iniziali
   UpdateInfoPanel(sessionStartEquity, 0, 0);

   // Imposta timer per aggiornare il pannello ogni secondo
   EventSetTimer(1);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Ferma il timer
   EventKillTimer();

   // Rimuovi gli oggetti grafici
   ObjectDelete(0, buttonName);
   ObjectDelete(0, buttonStopName);
   ObjectDelete(0, timerLabel);
   ObjectDelete(0, balanceLabel);
   ObjectDelete(0, equityLabel);
   ObjectDelete(0, profitLabel);
   ObjectDelete(0, profitPctLabel);
   ObjectDelete(0, lossLabel);
   ObjectDelete(0, lossPctLabel);
   ObjectDelete(0, maxDDLabel);
   ObjectDelete(0, maxDDPctLabel);

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
   }

   // Aggiorna il pannello informativo
   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   // Verifica Take Profit giornaliero
   if(DailyTakeProfit > 0 && sessionPL >= DailyTakeProfit)
   {
      Print("========================================");
      Print("TAKE PROFIT GIORNALIERO RAGGIUNTO!");
      Print("Profitto: ", DoubleToString(sessionPL, 2), " (", DoubleToString(sessionPLPercent, 2), "%)");
      Print("Target TP: ", DoubleToString(DailyTakeProfit, 2));
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

   // Verifica Stop Loss giornaliero
   if(DailyStopLoss > 0 && sessionPL <= -DailyStopLoss)
   {
      Print("========================================");
      Print("STOP LOSS GIORNALIERO RAGGIUNTO!");
      Print("Perdita: ", DoubleToString(sessionPL, 2), " (", DoubleToString(sessionPLPercent, 2), "%)");
      Print("Target SL: -", DoubleToString(DailyStopLoss, 2));
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
   }

   UpdateInfoPanel(currentEquity, sessionPL, sessionPLPercent);

   // Verifica Take Profit giornaliero
   if(DailyTakeProfit > 0 && sessionPL >= DailyTakeProfit)
   {
      Print("========================================");
      Print("TAKE PROFIT GIORNALIERO RAGGIUNTO!");
      Print("Profitto: ", DoubleToString(sessionPL, 2), " (", DoubleToString(sessionPLPercent, 2), "%)");
      Print("Target TP: ", DoubleToString(DailyTakeProfit, 2));
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

   // Verifica Stop Loss giornaliero
   if(DailyStopLoss > 0 && sessionPL <= -DailyStopLoss)
   {
      Print("========================================");
      Print("STOP LOSS GIORNALIERO RAGGIUNTO!");
      Print("Perdita: ", DoubleToString(sessionPL, 2), " (", DoubleToString(sessionPLPercent, 2), "%)");
      Print("Target SL: -", DoubleToString(DailyStopLoss, 2));
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
//| Funzione per creare la label del timer                           |
//+------------------------------------------------------------------+
void CreateTimerLabel()
{
   // Elimina la label se esiste già
   ObjectDelete(0, timerLabel);

   // Crea la label - allineata al lato destro del bottone
   ObjectCreate(0, timerLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, timerLabel, OBJPROP_XDISTANCE, BUTTON_X - 150);
   ObjectSetInteger(0, timerLabel, OBJPROP_YDISTANCE, BUTTON_Y + (BUTTON_HEIGHT * 2) + 15); // Sotto i due bottoni
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
   int yPos = BUTTON_Y + (BUTTON_HEIGHT * 2) + 40; // Posizione iniziale sotto il timer
   int lineHeight = 15; // Spaziatura tra le righe
   int labelX = BUTTON_X - 150; // Offset per allineamento perfetto

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

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per aggiornare il pannello informativo                  |
//+------------------------------------------------------------------+
void UpdateInfoPanel(double currentEquity, double sessionPL, double sessionPLPercent)
{
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

   ChartRedraw();
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
