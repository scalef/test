# Session Manager EA per MetaTrader 4

Expert Advisor per MT4 che gestisce sessioni di trading con controllo manuale delle posizioni.

## Funzionalità

1. **Bottone di chiusura rapida**: Un bottone rosso sul grafico che chiude tutte le posizioni aperte con un solo click
2. **Timer di sessione**: Visualizza il tempo trascorso dall'attivazione dell'EA in formato HH:MM:SS
3. **Disattivazione automatica**: Dopo aver chiuso tutte le posizioni, l'EA si disattiva automaticamente

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
- Clicca sul bottone "Chiudi Tutte" per chiudere immediatamente tutte le posizioni aperte sul simbolo corrente
- L'EA chiuderà sia le posizioni LONG che SHORT, oltre agli ordini pendenti
- Dopo la chiusura, l'EA si disattiverà automaticamente

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

- L'EA chiude solo le posizioni del simbolo corrente (il grafico su cui è attivo)
- **IMPORTANTE**: Per motivi di sicurezza, MT4 non permette agli EA di disattivare il pulsante "AutoTrading" via codice. Dopo aver cliccato "Chiudi Tutte", **dovrai disattivare manualmente** il pulsante "AutoTrading" nella toolbar di MT4
- L'EA rimane sul grafico dopo la chiusura delle posizioni e mostra un promemoria visivo
- Il timer si ferma quando vengono chiuse le posizioni
- Il bottone diventa grigio e cambia testo in "Posizioni Chiuse" dopo l'operazione

## Requisiti

- MetaTrader 4
- Trading automatico abilitato

## Licenza

Open source - usa e modifica liberamente
