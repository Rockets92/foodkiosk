# Documenti fiscali e Agenzia delle Entrate

Come Food Kiosk emette il **documento commerciale** (lo "scontrino
elettronico") e invia i corrispettivi all'Agenzia delle Entrate, cosa va
configurato e cosa resta da fare al locale.

> Questa guida descrive come funziona il programma, non sostituisce il
> commercialista. Prima di emettere documenti veri fai verificare la
> configurazione a chi segue la contabilità del locale.

## Cosa chiede la legge

Bar, ristoranti e fast food (commercio al minuto, art. 22 DPR 633/72) devono
**memorizzare ogni vendita e trasmettere ogni giorno i corrispettivi**
all'Agenzia delle Entrate (D.Lgs. 127/2015, art. 2). Al cliente si consegna il
**documento commerciale**, che ha sostituito scontrino e ricevuta fiscale.
Gli strumenti ammessi sono:

1. **Registratore telematico (RT)**: la stampante fiscale certificata stampa
   il documento e invia da sé i corrispettivi.
2. **Procedura web "Documento commerciale online"** dell'Agenzia, nel portale
   *Fatture e Corrispettivi*: ogni vendita si registra online, l'Agenzia
   assegna il numero e trasmette i corrispettivi, senza hardware fiscale.
3. **Soluzioni software certificate** (provvedimento AdE n. 111204 del 7 marzo
   2025): programmi che sostituiscono l'RT, oggi in fase di certificazione
   presso i fornitori.

Il documento commerciale deve riportare (DM 7 dicembre 2016, art. 2, e
specifiche tecniche dell'Agenzia):

- ditta, denominazione o ragione sociale, oppure nome e cognome;
- indirizzo del punto vendita;
- partita IVA dell'esercente;
- la dicitura "DOCUMENTO COMMERCIALE di vendita o prestazione";
- descrizione, aliquota IVA e prezzo di ogni bene;
- eventuali sconti, il totale e l'IVA compresa;
- la forma di pagamento (contanti, elettronico) e il resto;
- data, ora e numero del documento (`zzzz-nnnn`);
- se il cliente lo chiede, il suo codice fiscale o partita IVA (documento
  valido ai fini delle detrazioni) e il codice lotteria (solo con pagamento
  elettronico).

Per annullare una vendita si emette un **documento commerciale di
annullo** che riporta numero e data del documento originale.

Dal 2026 ogni POS va inoltre **abbinato** allo strumento di memorizzazione
(RT o procedura web) dal servizio "Gestisci collegamenti" del portale
Fatture e Corrispettivi (Legge di Bilancio 2025); il documento deve
distinguere pagamento contante ed elettronico.

## Le tre scelte in Food Kiosk

In **Impostazioni → Agenzia Entrate** si sceglie come emettere i documenti:

| Scelta | Quando | Chi stampa il documento |
| --- | --- | --- |
| Nessuno | Lo scontrino lo emette la cassa del locale con il suo registratore | Il totem stampa solo un promemoria dell'ordine ("non è un documento commerciale") |
| Registratore telematico | C'è un Epson RT in rete (FP-81 II RT, FP-90 III RT e compatibili) | Il registratore; il totem stampa il promemoria con il numero del documento |
| Documento commerciale online | Nessun registratore: si usa la procedura web dell'Agenzia | La stampante termica del totem o della cassa, con tutti i dati di legge |

Per emettere il documento all'incasso, nel **Flusso ordine** l'azione
"Documento fiscale" deve stare nell'evento *Pagato*: la sezione lo segnala e
la aggiunge con un tocco. Il documento viene sempre emesso **prima** della
stampa dello scontrino: con la procedura online è il documento stesso lo
scontrino del cliente (con il numero d'ordine in fondo), quindi non escono
due foglietti.

Gli ordini pagati in cassa stampano il documento sulla **stampante cassa**
(Impostazioni → Dispositivi); se non è impostata, su quella del totem.

## Documento commerciale online: come funziona

L'Agenzia non offre un'interfaccia pubblica (API) per far parlare un
programma con la procedura web: i gestionali passano da un **intermediario**
che si collega al portale con le **credenziali Fisconline** dell'esercente.
Food Kiosk è costruito per questo:

- nella sezione si inseriscono **codice fiscale dell'utente, password e PIN
  Fisconline** del titolare (o del gestore incaricato);
- le credenziali sono **cifrate** (AES-256-GCM) nel database del server; la
  chiave sta in un file separato (`secret.key` nella cartella dati) che su
  Windows è a sua volta protetto con DPAPI e si apre solo su quel PC. Una
  copia del database da sola non rivela niente;
- l'app non le mostra mai più: si vede solo lo stato (collegato, utente
  mascherato `RSS************U`, scadenza della password) e si possono
  aggiornare o scollegare;
- non viaggiano con le impostazioni e non arrivano mai ai totem; il server
  rifiuta password e chiavi messe nelle opzioni dei dispositivi;
- **"Verifica collegamento"** prova l'accesso con l'intermediario.

La password Fisconline **scade ogni 90 giorni**: l'app avvisa dal 60° giorno
(la data parte da quando la password è stata inserita qui). Prima di usarla
la prima volta bisogna entrare una volta nel portale, cambiare la password
iniziale e accettare le condizioni del servizio.

Le credenziali vanno inserite dal PC del server o da una cassa della rete
del locale: la rete tra cassa e server non è cifrata.

### Intermediario

Ogni intermediario è un componente (`DcOnlineProvider` in
`server/lib/src/adapters/ade_online.dart`) scelto con l'opzione `provider`.
Oggi c'è:

- `sandbox`: **ambiente di prova** che simula l'Agenzia (stessi controlli su
  dati e credenziali, numerazione, annulli) senza inviare nulla. I documenti
  escono marcati "DOCUMENTO DI PROVA - NON VALIDO AI FINI FISCALI".

Per emettere documenti veri serve un contratto con un intermediario
(per esempio fiskaly SIGN IT, A-Cube, Invopop): il suo collegamento è una
classe sola da aggiungere e registrare in `AdapterRegistry.dcOnline`, senza
toccare il resto. Le chiavi API dell'intermediario si salvano cifrate con le
credenziali.

## In cassa

- **Incassa**: con il documento attivo compare "Codice lotteria o codice
  fiscale del cliente". Il codice lotteria si accetta solo con carta o
  pagamento misto (il server rifiuta il contrario); il codice fiscale solo
  se il cliente lo chiede.
- Nel **dettaglio ordine** si vedono numero del documento, eventuale codice
  lotteria e annullo.
- Se il documento non si emette (account scaduto, rete assente) l'ordine
  prosegue comunque e compare "Operazioni non riuscite → Riprova".
- **Ristampa**: lo scontrino ristampato dalla cassa riporta "COPIA -
  RISTAMPA".
- **Annullare** un ordine pagato emette e stampa il documento di annullo.
  Se non riesce, il dettaglio mostra "Riprova annullo". Con il registratore
  telematico l'annullo si fa dal registratore.

## Modalità demo

In demo i documenti sono simulati e marcati "DEMO": hanno lo stesso
aspetto di quelli del sistema scelto (documento completo con la procedura
online, promemoria con il registratore), così si provano stampe e annulli
prima di andare in produzione.

## API

| Metodo | Percorso | |
| --- | --- | --- |
| GET | `/api/admin/fiscal/account` | Stato dell'account (mai le credenziali) |
| PUT | `/api/admin/fiscal/account` | `{taxCode, password, pin, providerKeys?}`; i campi vuoti restano invariati |
| DELETE | `/api/admin/fiscal/account` | Scollega e cancella le credenziali |
| POST | `/api/admin/fiscal/check` | Verifica il collegamento con il dispositivo configurato |
| POST | `/api/staff/orders/<id>/fiscal-void` | Riprova l'annullo del documento di un ordine annullato |

`mark-paid` e `POST /api/staff/orders` accettano `fiscalCustomer:
{lotteryCode, taxCode}`.

## Fonti

- [Documento commerciale online, l'alternativa al registratore telematico](https://www.investireoggi.it/documento-commerciale-on-line-lalternativa-al-registratore-telematico/)
- [Provvedimento AdE n. 111204 del 7 marzo 2025 (soluzioni software)](https://www.studiocerbone.com/?p=496491)
- [Contenuto del documento commerciale (DM 7 dicembre 2016)](https://www.studiocerbone.com/?p=30887)
- [Collegamento POS - registratore telematico dal 2026](https://fiscomania.com/collegamento-pos-registratore-cassa/)
- [Credenziali Fisconline negli intermediari (fiskaly SIGN IT)](https://workspace.fiskaly.com/sign-it/2026-06-01/credentials/)
