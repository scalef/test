# Session Manager EA per MetaTrader 4

Expert Advisor avanzato per MT4 che gestisce sessioni di trading con controllo manuale e automatico delle posizioni, tracking completo delle statistiche e risk management integrato.

## Funzionalità

### 🎯 Sistema a Tre Bottoni

1. **Close All** (Arancione)
   - Chiude **solo** tutte le posizioni aperte su MT4 (tutti i simboli)
   - La sessione continua e il timer resta attivo
   - Utile per chiusure rapide mantenendo il monitoraggio attivo

2. **Close All & STOP** (Rosso)
   - Chiude **tutti i grafici MT4** (eccetto il Session Manager)
   - Chiude **tutte le posizioni aperte**
   - Termina la sessione corrente
   - Chiusura totale e definitiva

3. **Reset Stats** (Blu)
   - Resetta tutte le statistiche (Timer, Max DD, P/L)
   - **NON** chiude le posizioni (trades rimangono aperti)
   - **NON** modifica i parametri TP/SL
   - Inizia una nuova sessione di tracking

### 📊 Pannello Informativo Completo

Posizionato nell'angolo **superiore destro** del grafico, mostra in tempo reale:

- **Session Timer**: Tempo trascorso dall'inizio della sessione (HH:MM:SS)
- **Starting Balance**: Balance iniziale della sessione (in oro)
- **Balance**: Saldo corrente del conto
- **Equity**: Capitale corrente incluso floating P/L
- **Profit**: Profitto di sessione in € e % (verde quando positivo)
- **Loss**: Perdita di sessione in € e % (rosso quando negativo)
- **Max DD**: Massimo drawdown raggiunto nella sessione
  - In valore assoluto ($)
  - In percentuale (%)
  - Colore arancione rosso (OrangeRed)

### 🛡️ Risk Management Automatico

- **Take Profit giornaliero**: Chiusura automatica quando il profitto di sessione raggiunge il target
- **Stop Loss giornaliero**: Chiusura automatica quando la perdita di sessione raggiunge il limite
- Controlli attivi sia sui tick che su timer (ogni secondo)
- Quando TP/SL vengono raggiunti → chiusura automatica completa (posizioni + grafici + fine sessione)

### 💾 Persistenza Dati

- **Le statistiche NON si resettano** quando modifichi i parametri TP/SL
- I dati di sessione vengono salvati automaticamente usando GlobalVariables
- Se cambi i parametri di input, la sessione continua con le stesse statistiche
- Per resettare le statistiche manualmente, usa il bottone "Reset Stats"

### 🎯 Protezione EA Multipli

- Gestisce automaticamente conflitti con altri EA (es. EA Thanos)
- Quando premi "Close All & STOP", chiude **tutti i grafici eccetto il Session Manager**
- Questo evita che altri EA riaprono posizioni durante la chiusura
- Completamente automatico, nessuna configurazione necessaria

### ⚡ Esecuzione Istantanea

- **Zero ritardi** in tutte le operazioni
- Nessun Sleep() o attese - tutto avviene immediatamente
- Chiusura posizioni istantanea con slippage ottimizzato (50 pips)
- Utilizzo di RefreshRates() e NormalizeDouble() per massima precisione

## Installazione

1. Copia il file `SessionManagerEA.mq4` nella cartella `MQL4/Experts` del tuo MetaTrader 4
2. Riavvia MT4 o aggiorna la lista degli Expert Advisors dal Navigator
3. Trascina l'EA sul grafico desiderato
4. Assicurati che il trading automatico sia abilitato (pulsante "AutoTrading" attivo)

## Utilizzo

### Attivazione

- Quando attivi l'EA, il timer di sessione parte automaticamente
- Vedrai apparire tre bottoni colorati nell'angolo superiore destro del grafico:
  - 🟠 **Close All** (Arancione)
  - 🔴 **Close All & STOP** (Rosso)
  - 🔵 **Reset Stats** (Blu)
- Sotto i bottoni apparirà il pannello informativo con tutte le statistiche

### Uso dei Bottoni

**Close All (Arancione)** - Chiusura parziale
- Chiude immediatamente TUTTE le posizioni su MT4 (tutti i simboli/asset)
- Il timer continua a correre
- Le statistiche continuano ad aggiornarsi
- I grafici rimangono aperti
- Utile per chiusure rapide senza terminare la sessione

**Close All & STOP (Rosso)** - Chiusura totale
- Chiude TUTTI i grafici MT4 (eccetto quello con il Session Manager)
- Chiude TUTTE le posizioni aperte
- Termina la sessione
- Cancella i dati di sessione salvati
- Il timer mostra il tempo finale raggiunto
- Chiusura completa e definitiva

**Reset Stats (Blu)** - Reset statistiche
- Resetta il timer a 00:00:00
- Resetta Max DD a 0.00
- Resetta Profit/Loss a 0.00
- Imposta Starting Balance al balance corrente
- Le posizioni aperte NON vengono toccate
- I parametri TP/SL NON vengono modificati
- Inizia una nuova sessione di tracking

### Pannello Informativo

Il pannello si aggiorna automaticamente ogni secondo (via timer) e ad ogni tick del mercato:

- **Session**: Timer che mostra il tempo trascorso (rimane visibile anche dopo chiusura)
- **Starting Balance**: Balance di inizio sessione (colore oro)
- **Balance**: Saldo corrente del conto
- **Equity**: Capitale corrente con floating P/L incluso
- **Profit/Loss**:
  - Calcolato come: Equity corrente - Starting Equity
  - Verde se positivo, rosso se negativo
  - Mostrato in valore assoluto e percentuale
  - Entrambi i valori sempre visibili (anche a zero)
- **Max DD**: Drawdown massimo raggiunto nella sessione
  - Tracciato dal picco di equity più alto
  - Mostrato in $ e in %
  - Colore arancione rosso per alta visibilità

### Risk Management Automatico

- Imposta **DailyTakeProfit** (default: 100) per chiusura automatica al target
- Imposta **DailyStopLoss** (default: 75) per chiusura automatica alla perdita massima
- Esempio: TP = 100 → chiude automaticamente a +100€ di profitto
- Esempio: SL = 75 → chiude automaticamente a -75€ di perdita
- Quando raggiunti → chiusura totale automatica (posizioni + grafici + fine sessione)
- I controlli avvengono sia sui tick che ogni secondo (timer)
- Imposta a 0 per disabilitare

### Modifica Parametri durante la Sessione

- Puoi modificare TP e SL in qualsiasi momento
- **Le statistiche NON si resettano** quando modifichi i parametri
- Il timer continua a correre
- Max DD e Starting Balance rimangono invariati
- La sessione continua senza interruzioni
- I dati vengono salvati automaticamente

## Parametri Personalizzabili

### Risk Management (Input Parameters)

- `DailyTakeProfit`: Take profit giornaliero (default: 100, 0 = disabilitato)
- `DailyStopLoss`: Stop loss giornaliero (default: 75, 0 = disabilitato)
- Valori in valuta del conto (EUR, USD, ecc.)

### Interfaccia (Fissi nel codice)

I parametri dell'interfaccia sono definiti nel codice (#define) e ottimizzati:
- `BUTTON_X`: 170 (posizione dal bordo destro)
- `BUTTON_Y`: 50 (posizione dall'alto)
- `BUTTON_WIDTH`: 150 (larghezza bottoni)
- `BUTTON_HEIGHT`: 30 (altezza bottoni)
- Pannello posizionato a destra con allineamento perfetto

## Note Importanti

### ⚠️ Avvisi Critici

- **L'EA chiude TUTTE le posizioni su MT4** (non solo quelle del simbolo corrente)
- **"Close All & STOP" chiude TUTTI i grafici** (eccetto Session Manager) e tutte le posizioni
- **Le chiusure sono istantanee e irreversibili**
- **IMPORTANTE**: MT4 non permette di disattivare AutoTrading via codice. Dopo "Close All & STOP", **disattiva manualmente** il pulsante "AutoTrading" nella toolbar
- Chiude sia posizioni running (BUY/SELL) che pending (ordini in attesa)
- Gestisce automaticamente conflitti con altri EA multipli

### 📊 Calcoli e Statistiche

- **P&L di sessione**: Equity corrente - Starting Equity (indipendente da Balance)
- **Max Drawdown**: Tracciato dal picco di equity più alto raggiunto
- **Starting Balance**: Salvato all'inizio sessione o al reset
- Tutti i valori vengono salvati e persistono tra modifiche parametri
- Timer aggiornato ogni secondo (indipendente dai tick di mercato)

### 🎨 Interfaccia

- Pannello posizionato nell'**angolo superiore destro** (CORNER_RIGHT_UPPER)
- Labels in **inglese** per maggiore compatibilità
- Colori distintivi per ogni tipo di informazione:
  - Oro: Starting Balance
  - Bianco: Balance, Equity
  - Verde: Profit
  - Rosso: Loss
  - Arancione rosso: Max Drawdown
- Allineamento perfetto (offset -150 dal bottone)

### 💡 Suggerimenti d'Uso

- **Testa sempre su conto demo prima** di usare su reale
- Usa **Close All** per chiusure rapide mantenendo monitoraggio attivo
- Usa **Close All & STOP** per chiusura totale a fine giornata
- Usa **Reset Stats** per iniziare nuovo tracking senza chiudere posizioni
- Imposta TP/SL realistici in base al tuo capitale e risk management
- Monitora il Max DD per valutare il rischio della tua strategia
- Le statistiche persistono tra modifiche parametri - non serve chiudere l'EA
- Il pannello si aggiorna ogni secondo anche quando il mercato è fermo

### 🔧 Compatibilità EA Multipli

- Se usi altri EA (es. EA Thanos) che aprono posizioni automaticamente:
- **"Close All & STOP" risolve automaticamente** chiudendo tutti i grafici
- Questo rimuove gli altri EA prima di chiudere le posizioni
- Evita che posizioni vengano riaperte durante la chiusura
- Il grafico Session Manager rimane aperto per mostrare i risultati finali

## Requisiti Tecnici

- MetaTrader 4
- Trading automatico abilitato
- Compilatore MQL4 (per modifiche al codice)

## Versione e Aggiornamenti

- **Versione**: 1.00
- **Ultima modifica**: Implementato sistema a tre bottoni, Max DD tracking, persistenza dati, Starting Balance label
- **Linguaggio**: MQL4 Strict Mode

## Licenza

Open source - usa e modifica liberamente

## Supporto

Per bug report o richieste di nuove funzionalità, contatta lo sviluppatore.

---

**Nota finale**: Questo EA è stato progettato per massima affidabilità e flessibilità. Ogni operazione è istantanea (zero ritardi), le statistiche persistono automaticamente, e il sistema a tre bottoni permette controllo granulare delle operazioni. Ideale sia per trader discrezionali che automatici.
