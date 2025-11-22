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
   int failed = 0;

   Print("========================================");
   Print("INIZIO CHIUSURA POSIZIONI");
   Print("Totale ordini aperti su TUTTA MT4: ", total);
   Print("========================================");

   // Aggiorna i dati di mercato
   RefreshRates();

   // Cicla attraverso tutti gli ordini aperti (dal più recente al più vecchio)
   for(int i = total - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         bool result = false;
         string orderSymbol = OrderSymbol();
         int orderType = OrderType();
         int ticket = OrderTicket();
         double lots = OrderLots();

         Print("---");
         Print("Ordine #", ticket, " - Simbolo: ", orderSymbol, " - Tipo: ", orderType, " - Lotti: ", lots);

         if(orderType == OP_BUY)
         {
            // Chiudi posizione LONG - usa il Bid del simbolo dell'ordine
            double closePrice = SymbolInfoDouble(orderSymbol, SYMBOL_BID);

            // Verifica che il prezzo sia valido
            if(closePrice <= 0)
            {
               closePrice = MarketInfo(orderSymbol, MODE_BID);
               Print("SymbolInfoDouble fallito, uso MarketInfo. Prezzo: ", closePrice);
            }

            if(closePrice > 0)
            {
               // Normalizza il prezzo
               int digits = (int)MarketInfo(orderSymbol, MODE_DIGITS);
               closePrice = NormalizeDouble(closePrice, digits);

               Print("Tentativo chiusura BUY - Prezzo: ", closePrice, " - Digits: ", digits);
               result = OrderClose(ticket, lots, closePrice, 50, clrNONE);
            }
            else
            {
               Print("ERRORE: Prezzo non valido per ", orderSymbol);
            }
         }
         else if(orderType == OP_SELL)
         {
            // Chiudi posizione SHORT - usa l'Ask del simbolo dell'ordine
            double closePrice = SymbolInfoDouble(orderSymbol, SYMBOL_ASK);

            // Verifica che il prezzo sia valido
            if(closePrice <= 0)
            {
               closePrice = MarketInfo(orderSymbol, MODE_ASK);
               Print("SymbolInfoDouble fallito, uso MarketInfo. Prezzo: ", closePrice);
            }

            if(closePrice > 0)
            {
               // Normalizza il prezzo
               int digits = (int)MarketInfo(orderSymbol, MODE_DIGITS);
               closePrice = NormalizeDouble(closePrice, digits);

               Print("Tentativo chiusura SELL - Prezzo: ", closePrice, " - Digits: ", digits);
               result = OrderClose(ticket, lots, closePrice, 50, clrNONE);
            }
            else
            {
               Print("ERRORE: Prezzo non valido per ", orderSymbol);
            }
         }
         else
         {
            // Elimina ordini pendenti (OP_BUYLIMIT, OP_SELLLIMIT, OP_BUYSTOP, OP_SELLSTOP)
            Print("Tentativo eliminazione ordine pending tipo: ", orderType);
            result = OrderDelete(ticket);
         }

         if(result)
         {
            closed++;
            Print("✓ Ordine #", ticket, " (", orderSymbol, ") chiuso con successo");
         }
         else
         {
            failed++;
            int error = GetLastError();
            Print("✗ ERRORE chiusura ordine #", ticket, " (", orderSymbol, ") - Codice errore: ", error);
            Print("  Descrizione errore: ", ErrorDescription(error));
         }
      }
   }

   Print("========================================");
   Print("CHIUSURA COMPLETATA");
   Print("Ordini chiusi: ", closed, " su ", total);
   Print("Ordini falliti: ", failed);
   Print("========================================");

   // Ferma la sessione
   sessionActive = false;
   ObjectSetString(0, timerLabel, OBJPROP_TEXT, "Sessione terminata - Chiusura grafici...");
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
   // Nota: In MQL4, non è possibile disattivare direttamente il pulsante
   // "AutoTrading" dal codice per motivi di sicurezza.

   Print("Tutte le posizioni chiuse - Chiusura grafici in corso...");

   // Mostra un alert all'utente
   Alert("Tutte le posizioni sono state chiuse!\n" +
         "Chiusura immediata di tutti i grafici in corso.\n\n" +
         "IMPORTANTE: Disattiva manualmente il pulsante 'AutoTrading' nella toolbar di MT4.");

   // Cambia il colore del bottone per indicare che l'azione è completata
   ObjectSetInteger(0, buttonName, OBJPROP_BGCOLOR, clrGray);
   ObjectSetString(0, buttonName, OBJPROP_TEXT, "Chiusura in corso...");
   ChartRedraw();

   // Chiudi tutti i grafici immediatamente
   CloseAllCharts();
}

//+------------------------------------------------------------------+
