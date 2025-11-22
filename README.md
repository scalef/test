# Session Manager EA per MetaTrader 4

Expert Advisor per MT4 che gestisce sessioni di trading con controllo manuale delle posizioni.

## Funzionalità

### 🎯 Controllo Manuale
1. **Bottone di chiusura rapida**: Un bottone rosso sul grafico che chiude **tutte le posizioni aperte su MT4** (tutti i simboli) con un solo click
2. **Chiusura automatica grafici**: Dopo aver chiuso tutte le posizioni, **tutti i grafici aperti su MT4 vengono chiusi automaticamente**

### 📊 Pannello Informativo in Tempo Reale
- **Timer di sessione**: Tempo trascorso dall'attivazione (HH:MM:SS)
- **Balance**: Saldo del conto
- **Equity**: Capitale corrente
- **Profitto di sessione**: In € e in % (verde quando positivo)
- **Perdita di sessione**: In € e in % (rosso quando negativo)

### 🛡️ Risk Management Automatico
- **Take Profit giornaliero**: Chiusura automatica quando il profitto di sessione raggiunge il target impostato
- **Stop Loss giornaliero**: Chiusura automatica quando la perdita di sessione raggiunge il limite impostato
- Entrambi i parametri sono opzionali (0 = disabilitato)

## Installazione

1. Copia il file `SessionManagerEA.mq4` nella cartella `MQL4/Experts` del tuo MetaTrader 4
2. Riavvia MT4 o aggiorna la lista degli Expert Advisors dal Navigator
3. Trascina l'EA sul grafico desiderato
4. Assicurati che il trading automatico sia abilitato (pulsante "AutoTrading" attivo)

## Utilizzo

### Attivazione
- Quando attivi l'EA, il timer di sessione parte automaticamente
- Vedrai apparire un bottone rosso "Chiudi Tutte" nell'angolo superiore sinistro del grafico
- Sotto il bottone apparirà il timer della sessione

### Chiusura delle posizioni
- Clicca sul bottone "Chiudi Tutte" per chiudere immediatamente **TUTTE le posizioni aperte su MT4** (tutti i simboli/asset)
- L'EA chiuderà sia le posizioni running (in corso) che quelle pending (ordini pendenti)
- Dopo la chiusura delle posizioni, **tutti i grafici aperti verranno chiusi istantaneamente**
- Riceverai un alert al momento della chiusura

### Pannello informativo
Il pannello mostra in tempo reale:
- **Sessione**: Timer HH:MM:SS dall'attivazione
- **Balance**: Saldo del conto
- **Equity**: Capitale corrente
- **Profitto/Perdita**: Calcolato dalla differenza tra equity corrente ed equity iniziale
  - In verde se in profitto (con +)
  - In rosso se in perdita
  - Visualizzato sia in valore assoluto che in percentuale

### Risk Management automatico
- Imposta **Take Profit giornaliero** per chiudere automaticamente quando raggiungi il profitto target
- Imposta **Stop Loss giornaliero** per chiudere automaticamente quando raggiungi la perdita massima
- Esempio: TP = 100 → chiude automaticamente a +100€ di profitto
- Esempio: SL = 50 → chiude automaticamente a -50€ di perdita
- Se raggiunti, l'EA chiude tutte le posizioni e tutti i grafici automaticamente

## Parametri personalizzabili

### Interfaccia
- `Button_X`: Posizione orizzontale del bottone (default: 20)
- `Button_Y`: Posizione verticale del bottone (default: 50)
- `Button_Width`: Larghezza del bottone (default: 150)
- `Button_Height`: Altezza del bottone (default: 30)
- `Button_Color`: Colore di sfondo del bottone (default: rosso)
- `Text_Color`: Colore del testo (default: bianco)

### Risk Management
- `DailyTakeProfit`: Take profit giornaliero in valuta del conto (default: 0 = disabilitato)
- `DailyStopLoss`: Stop loss giornaliero in valuta del conto (default: 0 = disabilitato)

## Note importanti

### ⚠️ Avvisi Generali
- **L'EA chiude TUTTE le posizioni su MT4** (non solo quelle del simbolo corrente) - usare con cautela!
- **Tutti i grafici aperti su MT4 verranno chiusi istantaneamente** dopo la chiusura delle posizioni
- **IMPORTANTE**: Per motivi di sicurezza, MT4 non permette agli EA di disattivare il pulsante "AutoTrading" via codice. Dopo la chiusura, **dovrai disattivare manualmente** il pulsante "AutoTrading" nella toolbar di MT4
- Chiude sia posizioni running (BUY/SELL) che pending (ordini in attesa)
- La chiusura è istantanea e irreversibile

### 📊 Risk Management
- Il P&L di sessione è calcolato come: **Equity corrente - Equity iniziale**
- Il calcolo è indipendente da Balance (include floating P&L)
- Take Profit e Stop Loss vengono controllati ad ogni tick
- Quando TP o SL vengono raggiunti, la chiusura è automatica e immediata
- Imposta i valori in base alla valuta del tuo conto (EUR, USD, ecc.)

### 💡 Suggerimenti
- Testa prima su un conto demo
- Imposta TP/SL realistici in base al tuo capitale
- Il pannello si aggiorna ad ogni tick del mercato
- Monitora sempre il profitto/perdita in tempo reale

## Requisiti

- MetaTrader 4
- Trading automatico abilitato

## Licenza

Open source - usa e modifica liberamente
