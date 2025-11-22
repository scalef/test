# Session Manager EA per MetaTrader 4

Expert Advisor per MT4 che gestisce sessioni di trading con controllo manuale delle posizioni.

## Funzionalità

1. **Bottone di chiusura rapida**: Un bottone rosso sul grafico che chiude **tutte le posizioni aperte su MT4** (tutti i simboli) con un solo click
2. **Timer di sessione**: Visualizza il tempo trascorso dall'attivazione dell'EA in formato HH:MM:SS
3. **Chiusura automatica grafici**: Dopo aver chiuso tutte le posizioni, **tutti i grafici aperti su MT4 vengono chiusi automaticamente**

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
- L'EA chiuderà sia le posizioni LONG che SHORT, oltre agli ordini pendenti
- Dopo la chiusura delle posizioni, **tutti i grafici aperti verranno chiusi automaticamente** (dopo 2 secondi)
- Riceverai un alert prima della chiusura dei grafici

### Timer di sessione
- Il timer mostra il tempo trascorso dall'attivazione dell'EA
- Formato: HH:MM:SS (ore:minuti:secondi)
- Si aggiorna automaticamente ad ogni tick

## Parametri personalizzabili

L'EA offre diversi parametri che puoi modificare durante l'attivazione:

- `Button_X`: Posizione orizzontale del bottone (default: 20)
- `Button_Y`: Posizione verticale del bottone (default: 50)
- `Button_Width`: Larghezza del bottone (default: 150)
- `Button_Height`: Altezza del bottone (default: 30)
- `Button_Color`: Colore di sfondo del bottone (default: rosso)
- `Text_Color`: Colore del testo (default: bianco)

## Note importanti

- ⚠️ **L'EA chiude TUTTE le posizioni su MT4** (non solo quelle del simbolo corrente) - usare con cautela!
- ⚠️ **Tutti i grafici aperti su MT4 verranno chiusi** dopo la chiusura delle posizioni
- **IMPORTANTE**: Per motivi di sicurezza, MT4 non permette agli EA di disattivare il pulsante "AutoTrading" via codice. Dopo la chiusura, **dovrai disattivare manualmente** il pulsante "AutoTrading" nella toolbar di MT4
- Il timer si ferma quando vengono chiuse le posizioni
- Hai 2 secondi dopo l'alert per vedere il messaggio prima che i grafici vengano chiusi
- Il bottone diventa grigio e mostra "Chiusura in corso..." durante l'operazione

## Requisiti

- MetaTrader 4
- Trading automatico abilitato

## Licenza

Open source - usa e modifica liberamente
