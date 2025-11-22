//+------------------------------------------------------------------+
//|                                            SessionManagerEA.mq4 |
//|                                                                  |
//|                                Expert Advisor per gestione       |
//|                                sessioni e chiusura posizioni     |
//+------------------------------------------------------------------+
#property copyright "Session Manager EA"
#property version   "1.00"
#property strict

// Parametri input
input int Button_X = 20;           // Posizione X del bottone
input int Button_Y = 50;           // Posizione Y del bottone
input int Button_Width = 150;      // Larghezza del bottone
input int Button_Height = 30;      // Altezza del bottone
input color Button_Color = clrRed; // Colore del bottone
input color Text_Color = clrWhite; // Colore del testo

// Variabili globali
datetime sessionStartTime = 0;     // Tempo di inizio sessione
bool sessionActive = false;        // Stato della sessione
string buttonName = "CloseAllBtn"; // Nome del bottone
string timerLabel = "SessionTimer"; // Nome label timer

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Crea il bottone per chiudere tutte le posizioni
   CreateCloseButton();

   // Crea la label per il timer
   CreateTimerLabel();

   // Avvia la sessione
   sessionStartTime = TimeCurrent();
   sessionActive = true;

   Print("Session Manager EA inizializzato - Sessione avviata");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Rimuovi gli oggetti grafici
   ObjectDelete(0, buttonName);
   ObjectDelete(0, timerLabel);

   Print("Session Manager EA disattivato");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Aggiorna il timer se la sessione è attiva
   if(sessionActive)
   {
      UpdateSessionTimer();
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
   // Controlla se è stato cliccato il bottone
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == buttonName)
      {
         Print("Bottone premuto - Chiusura di tutte le posizioni...");
         CloseAllPositions();

         // Disattiva il trading automatico
         DisableAutoTrading();

         // Reset del bottone
         ObjectSetInteger(0, buttonName, OBJPROP_STATE, false);
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| Funzione per creare il bottone                                   |
//+------------------------------------------------------------------+
void CreateCloseButton()
{
   // Elimina il bottone se esiste già
   ObjectDelete(0, buttonName);

   // Crea il bottone
   ObjectCreate(0, buttonName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, buttonName, OBJPROP_XDISTANCE, Button_X);
   ObjectSetInteger(0, buttonName, OBJPROP_YDISTANCE, Button_Y);
   ObjectSetInteger(0, buttonName, OBJPROP_XSIZE, Button_Width);
   ObjectSetInteger(0, buttonName, OBJPROP_YSIZE, Button_Height);
   ObjectSetInteger(0, buttonName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, Button_Color);
   ObjectSetInteger(0, buttonName, OBJPROP_COLOR, Text_Color);
   ObjectSetString(0, buttonName, OBJPROP_TEXT, "Chiudi Tutte");
   ObjectSetString(0, buttonName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, buttonName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, buttonName, OBJPROP_SELECTABLE, false);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per creare la label del timer                           |
//+------------------------------------------------------------------+
void CreateTimerLabel()
{
   // Elimina la label se esiste già
   ObjectDelete(0, timerLabel);

   // Crea la label
   ObjectCreate(0, timerLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, timerLabel, OBJPROP_XDISTANCE, Button_X);
   ObjectSetInteger(0, timerLabel, OBJPROP_YDISTANCE, Button_Y + Button_Height + 10);
   ObjectSetInteger(0, timerLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, timerLabel, OBJPROP_COLOR, clrYellow);
   ObjectSetString(0, timerLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, timerLabel, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, timerLabel, OBJPROP_TEXT, "Sessione: 00:00:00");

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

   string timeStr = StringFormat("Sessione: %02d:%02d:%02d", hours, minutes, seconds);
   ObjectSetString(0, timerLabel, OBJPROP_TEXT, timeStr);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per chiudere tutte le posizioni aperte                  |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   int total = OrdersTotal();
   int closed = 0;

   Print("Totale ordini aperti: ", total);

   // Cicla attraverso tutti gli ordini aperti (dal più recente al più vecchio)
   for(int i = total - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         // Verifica che l'ordine appartenga al simbolo corrente
         if(OrderSymbol() == Symbol())
         {
            bool result = false;

            if(OrderType() == OP_BUY)
            {
               // Chiudi posizione LONG
               result = OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrNONE);
            }
            else if(OrderType() == OP_SELL)
            {
               // Chiudi posizione SHORT
               result = OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrNONE);
            }
            else
            {
               // Elimina ordini pendenti
               result = OrderDelete(OrderTicket());
            }

            if(result)
            {
               closed++;
               Print("Ordine #", OrderTicket(), " chiuso con successo");
            }
            else
            {
               Print("Errore nella chiusura dell'ordine #", OrderTicket(), " - Errore: ", GetLastError());
            }
         }
      }
   }

   Print("Chiusura completata. Ordini chiusi: ", closed, " su ", total);

   // Ferma la sessione
   sessionActive = false;
   ObjectSetString(0, timerLabel, OBJPROP_TEXT, "Sessione terminata");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Funzione per disattivare il trading automatico                   |
//+------------------------------------------------------------------+
void DisableAutoTrading()
{
   // Nota: In MQL4, non è possibile disattivare direttamente il pulsante
   // "AutoTrading" dal codice per motivi di sicurezza.
   // L'EA rimane sul grafico e l'utente deve disattivare manualmente l'AutoTrading.

   Print("Tutte le posizioni chiuse - Ricorda di disattivare l'AutoTrading manualmente");

   // Mostra un alert all'utente con le istruzioni
   Alert("Tutte le posizioni sono state chiuse!\n\n" +
         "IMPORTANTE: Disattiva manualmente il pulsante 'AutoTrading' nella toolbar di MT4\n" +
         "per fermare completamente il trading automatico.");

   // Cambia il colore del bottone per indicare che l'azione è completata
   ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, clrGray);
   ObjectSetString(0, buttonName, OBJPROP_TEXT, "Posizioni Chiuse");

   // Aggiungi una label di promemoria
   string reminderLabel = "AutoTradingReminder";
   ObjectDelete(0, reminderLabel);
   ObjectCreate(0, reminderLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, reminderLabel, OBJPROP_XDISTANCE, Button_X);
   ObjectSetInteger(0, reminderLabel, OBJPROP_YDISTANCE, Button_Y + Button_Height + 40);
   ObjectSetInteger(0, reminderLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, reminderLabel, OBJPROP_COLOR, clrOrange);
   ObjectSetString(0, reminderLabel, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, reminderLabel, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, reminderLabel, OBJPROP_TEXT, "⚠ Disattiva AutoTrading manualmente!");

   ChartRedraw();
}

//+------------------------------------------------------------------+
