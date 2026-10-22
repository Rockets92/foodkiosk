# Food Kiosk

Suite per totem di ordinazione self-service (stile fast food): kiosk touch per
il cliente, schermo cucina, pannello di gestione e un server locale che li
collega. Pensata per girare su totem Windows, ma tutto funziona anche da un
normale PC in **modalità demo**, senza POS né registratore telematico.

## Struttura

| Cartella | Contenuto |
| --- | --- |
| `packages/kiosk_core` | Modelli condivisi (menu, allergeni, ordini, impostazioni, flusso ordine). Usati dal server e da tutte le app. |
| `server` | Server locale Dart: database SQLite, API REST, WebSocket per gli aggiornamenti in tempo reale, adattatori per POS, stampanti e dispositivo fiscale. |
| `apps/kiosk` | App Flutter del totem (Windows, e web per provarla da PC). |
| `apps/staff` | App Flutter per il personale: cassa, schermo cucina, schermo ritiro, gestione menu, impostazioni, riepilogo della giornata (Windows e web). |
| `packaging/windows` | Script di build del pacchetto Windows, avvii rapidi `.bat` e installer (Inno Setup). |

**Per provarlo sul proprio PC** senza installare niente di tecnico c'è la
[guida rapida](docs/GUIDA-RAPIDA.md).

## Avvio rapido

Serve il [Dart SDK](https://dart.dev/get-dart) 3.8 o superiore.

```sh
dart pub get
cd server
dart run bin/server.dart            # http://localhost:8080
```

Al primo avvio il server crea `server/data/foodkiosk.db` (su Windows
`%ProgramData%\FoodKiosk\data`), carica un menu demo
(panini, menu, contorni, bibite, dolci con allergeni, calorie e foto
segnaposto) e parte in **modalità demo**. PIN staff/admin predefinito: `1234`.

Opzioni: `--port`, `--host`, `--data-dir`, `--no-demo-menu`, `--kiosk-web`,
`--staff-web` (cartelle delle build web da servire su `/kiosk/` e `/staff/`,
per sviluppo e demo da browser), `--log-file`, `--background` (riparte
senza finestra con il registro in `server.log` nella cartella dati: è
così che lo avviano le app Windows).

## App kiosk

Serve [Flutter](https://docs.flutter.dev/get-started/install) (stable).

Il flusso per il cliente: schermata di attesa → lingua e "mangio qui / porto
via" → menu per categorie → dettaglio prodotto (foto, descrizione,
calorie, allergeni, varianti obbligatorie ed extra, quantità) → carrello →
pagamento sul totem, in cassa o a scelta del cliente, secondo il flusso
configurato → numero d'ordine. L'interfaccia è animata come nei totem delle
grandi catene: sfondo a raggi che ruota con i prodotti in evidenza, schede
che entrano in sequenza, il prodotto che "vola" nel carrello con l'aggiunta
rapida (+), banner promozionale per i prodotti con etichetta ("Novità", "Il
più amato"), suggerimenti "Completa il tuo pasto" nel carrello e coriandoli
alla conferma. Se il cliente si allontana, dopo il tempo di
inattività il totem chiede "Sei ancora lì?" e poi ricomincia, annullando
l'eventuale ordine non pagato.

**Provarla da PC nel browser**, servita dallo stesso server:

```sh
cd apps/kiosk
flutter build web --base-href /kiosk/ --no-web-resources-cdn
cd ../../server
dart run bin/server.dart --kiosk-web ../apps/kiosk/build/web
# apri http://localhost:8080/kiosk/
```

**Sul totem Windows**:

```sh
cd apps/kiosk
flutter run -d windows                    # sviluppo
flutter build windows                     # build da installare
```

L'app cerca il server su `http://localhost:8080/`. Per un server su un altro
PC: `--dart-define=SERVER_URL=http://192.168.1.10:8080/` in compilazione,
oppure dal **menu staff**: tieni premuto 3 secondi l'angolo in alto a
sinistra, inserisci il PIN staff e imposta l'indirizzo. Dallo stesso menu si
ricarica il menu o si chiude l'app.

**Colori**: si sceglie una palette da **Staff > Impostazioni > Aspetto**
(Classico rosso e giallo, Fiamma, Steakhouse, Notte, Fresco, Oceano, Frutti
di bosco, Trattoria). Il server la invia a totem, app staff e schermo
ritiro, che cambiano colore subito senza riavvio e senza far perdere la
schermata al cliente; anche il logo segnaposto e le illustrazioni "mangio
qui / porto via" si ricolorano. Errori, annullamenti e ordini in ritardo
restano sempre rossi. Le palette sono in
`packages/kiosk_core/lib/src/palette.dart`: per aggiungerne una basta un
nuovo blocco nella lista `presets`.

Logo e immagini sono segnaposto: il logo e le illustrazioni dei prodotti
demo sono serviti dal server (`server/lib/src/illustrations.dart`) finché il
locale non carica le proprie foto. Il font è Poppins (licenza OFL, incluso). Le
traduzioni dell'interfaccia sono in `apps/kiosk/lib/src/i18n.dart`: per
aggiungere una lingua basta un nuovo blocco di testi e abilitarla nelle
impostazioni.

## App staff

Un'unica app (nel browser su `http://<server>:8080/staff/` o come
programma Windows) con accesso tramite PIN staff e una barra laterale:

- **Riepilogo**: incasso, ordini, scontrino medio, ordini da incassare,
  andamento per ora e prodotti più venduti, per qualsiasi giorno.
- **Cassa**: ordini del giorno con filtri e ricerca per numero; dettaglio
  con righe, IVA, storico; incasso in contanti o con carta (con o senza
  documento fiscale), annullamento, ristampa e nuovo tentativo delle azioni
  fallite (per esempio stampante spenta). **Nuovo ordine**: il cassiere
  compone l'ordine per un cliente al banco (varianti comprese) e lo incassa
  subito o lo salva da incassare dopo; segue lo stesso flusso degli ordini
  dal totem. Finché un ordine non è pagato né in cucina si possono
  aggiungere o togliere prodotti. **Incasso**: contanti con importo
  ricevuto e resto, carta (POS della cassa) o misto contanti + carta; il
  riepilogo divide l'incasso tra contanti e carta.
- **Cucina**: scontrini in tre colonne (da preparare, in preparazione,
  pronti) con tempi di attesa colorati, allergeni evidenziati, a schermo
  intero per il monitor della cucina; interruttori rapidi "esaurito".
- **Ritiro**: schermo per i clienti con i numeri in preparazione e pronti.
  Si apre anche senza PIN dalla schermata di accesso ("Schermo ritiro"),
  per un monitor dedicato.
- **Menu**: prodotti (foto caricabili, prezzi, IVA, allergeni, etichette
  "Novità", varianti, disponibilità), categorie e gruppi di varianti.
- **Impostazioni**: modalità demo, lingue, "mangio qui / porto via",
  palette colori con anteprima del totem, flusso dell'ordine con verifica
  immediata delle combinazioni, dispositivi (POS, registratore telematico,
  stampanti) e PIN.

```sh
cd apps/staff
flutter build web --base-href /staff/ --no-web-resources-cdn
cd ../../server
dart run bin/server.dart --kiosk-web ../apps/kiosk/build/web --staff-web ../apps/staff/build/web
# apri http://localhost:8080/staff/ (PIN 1234)
```

## Pacchetto Windows

Ogni esecuzione della CI produce, tra gli *Artifacts* della run su GitHub
Actions:

- **FoodKiosk-Windows-installer**: `FoodKiosk-Setup.exe`, con scelta dei
  componenti (tutto, solo totem, solo postazione staff), icone nel menu
  Start e sul desktop, avvio automatico del totem (e, sui PC che servono
  altri dispositivi, del server) all'accesso a Windows, e regola del
  firewall per la rete locale;
- **FoodKiosk-Windows-portatile**: la stessa cartella senza installazione
  (`totem\FoodKioskTotem.exe`, `staff\FoodKioskStaff.exe`, `server\`,
  `LEGGIMI.txt`).

Totem e app staff sono **programmi Windows nativi**, senza browser: se il
server configurato è `localhost` e non risponde, lo avviano da soli senza
finestre (`FoodKioskServer.exe --background`, registro in
`%ProgramData%\FoodKiosk\data\server.log`) e il server resta attivo per
gli altri dispositivi anche dopo la chiusura dell'app. Le versioni web
restano solo per lo sviluppo e la demo da browser (`--kiosk-web`,
`--staff-web`).

Per crearli in locale su Windows (Flutter con il carico di lavoro "Sviluppo
di applicazioni desktop con C++" di Visual Studio, e Inno Setup 6 per
l'installer):

```powershell
./packaging/windows/build.ps1 -Installer
```

Il totem Windows parte a **schermo intero senza bordi e sempre in primo
piano** (`--windowed` per una finestra normale, `--hide-cursor` per
nascondere il puntatore). Per un totem chiuso come nei fast food conviene
usare un account Windows dedicato con l'avvio automatico del totem
(opzione dell'installer) oppure la funzione di Windows "Accesso assegnato"
(chiosco); per uscire dal totem: angolo in alto a sinistra per 3 secondi,
PIN staff, "Chiudi applicazione".

## Modalità demo

Con `demoMode: true`:

- i pagamenti sono **simulati** (nessun POS necessario), anche se un POS reale è configurato;
- il documento fiscale è simulato (numero `DEMO-...`);
- le scorte non vengono controllate né scalate;
- gli ordini sono marcati `isDemo` e i ticket riportano "DEMO - NON VALIDO";
- le stampanti restano quelle configurate, così una demo sul totem vero stampa davvero.

Il POS demo accetta opzioni utili in presentazione: `delayMs` (attesa
simulata), `failureRate` (0..1) e `declineCentsSuffix` (es. `"13"` rifiuta
gli importi che finiscono in ,13 per mostrare il caso di pagamento rifiutato).

## Flusso dell'ordine configurabile

Ogni locale lavora in modo diverso, quindi il ciclo dell'ordine non è fisso.
Si configura con due cose:

1. **`paymentMode`**: come si paga
   - `none`: il sistema non gestisce il pagamento;
   - `counter`: si paga in cassa, lo staff segna l'ordine come pagato;
   - `kiosk`: si paga sul totem con il POS integrato;
   - `customerChoice`: il cliente sceglie tra totem e cassa.
2. **`rules`**: cosa fare quando succede qualcosa. Eventi: `submitted`
   (ordine confermato), `paid` (pagato), `ready` (pronto in cucina). Azioni:
   `printCustomerTicket`, `printKitchenTicket`, `sendToKitchenDisplay`,
   `issueFiscalDocument`, `announceOnPickupScreen`.

Configurazioni pronte (`GET /api/admin/flow/presets`):

| Preset | Comportamento |
| --- | --- |
| `orderOnly` | Il totem stampa lo scontrino d'ordine, il cliente paga in cassa. |
| `payAtCounterKitchenAfterPayment` | Scontrino per la cassa; la cucina riceve l'ordine quando la cassa lo segna pagato. *(predefinito)* |
| `payAtCounterKitchenImmediately` | Scontrino per la cassa e ordine subito in cucina. |
| `fullService` | Pagamento con POS sul totem, documento fiscale, scontrino, cucina, schermo ritiro. |

Si sceglie dall'app staff in **Impostazioni → Flusso ordine**, partendo da
un modello pronto o impostando ogni passaggio. L'app staff mostra solo i
moduli che il flusso usa: senza schermo cucina (per esempio con *Solo
ordine*, quando la cucina lavora con un altro sistema) le sezioni Cucina e
Ritiro non compaiono.

Le combinazioni che lascerebbero ordini bloccati vengono rifiutate o
segnalate (`POST /api/admin/flow/validate`): per esempio il documento fiscale
prima del pagamento, o azioni su `paid` quando il pagamento è disattivato.

Nessun vicolo cieco:

- se la stampante o il dispositivo fiscale non risponde, l'ordine prosegue
  comunque; l'errore finisce nello storico dell'ordine e lo staff può
  ripetere l'azione (`POST /api/staff/orders/<id>/actions/<azione>`);
- se il pagamento sul totem viene rifiutato, il cliente può riprovare o
  passare al pagamento in cassa (`counterFallback`);
- in cassa si può segnare pagato senza emettere il documento fiscale
  (`issueFiscal: false`) quando lo ha già emesso il registratore di cassa.

## Adattatori

POS, stampanti e dispositivo fiscale sono componenti intercambiabili
registrati in `server/lib/src/adapters/registry.dart`. Aggiungere un modello
nuovo significa scrivere una classe e registrarla, senza toccare il resto.

| Tipo | Disponibili ora |
| --- | --- |
| Pagamento | `none`, `demo` |
| Fiscale | `none`, `demo`, `epsonRt` (registratore telematico Epson FP-81 II RT, FP-90 III RT e compatibili, via rete) |
| Stampante | `none`, `demo` (solo registro stampe), `escposNetwork` (stampante termica ESC/POS in rete, porta 9100) |

Esempio di stampante termica di rete:

```json
{ "customerPrinter": { "type": "escposNetwork", "options": { "host": "192.168.1.50", "port": 9100, "width": 42 } } }
```

Esempio di registratore telematico Epson (reparti per aliquota IVA come
configurati sulla stampante):

```json
{ "fiscal": { "type": "epsonRt", "options": { "host": "192.168.1.60", "departments": { "10": 1, "22": 2, "4": 3 } } } }
```

Il registratore riceve ogni vendita pagata (righe, varianti a pagamento,
pagamento in contanti o elettronico) tramite il suo servizio web
`fpmate.cgi`; il numero del documento commerciale finisce nell'ordine.
L'adattatore è verificato contro un dispositivo simulato: prima dell'uso in
produzione va provato sul modello reale del locale.

**POS reale**: ogni circuito (Nexi, SumUp, Ingenico, Worldline, ...) ha il
suo protocollo o SDK, quindi l'adattatore si scrive quando il locale ha
scelto il fornitore. Basta implementare `PaymentTerminal` in
`server/lib/src/adapters/payment.dart` e registrarlo; nel frattempo il totem
funziona in modalità demo, oppure con pagamento in cassa (dove si usa il
POS già presente). Le stampanti termiche USB su Windows si collegano come
stampanti di rete condivise o tramite il loro driver di rete ESC/POS.

## API

Pubbliche (usate dal totem):

| Metodo | Percorso | |
| --- | --- | --- |
| GET | `/api/settings` | Impostazioni pubbliche (lingue, modalità, flusso) |
| GET | `/api/menu` | Menu visibile sul totem |
| GET | `/api/allergens` | Elenco allergeni e etichette dietetiche tradotte |
| GET | `/api/pickup` | Numeri in preparazione e pronti (schermo ritiro) |
| POST | `/api/orders` | Crea un ordine (i prezzi li calcola sempre il server) |
| GET | `/api/orders/<id>` | Stato dell'ordine |
| POST | `/api/orders/<id>/pay` | Pagamento sul totem |
| POST | `/api/orders/<id>/switch-to-counter` | Dopo un pagamento rifiutato, paga in cassa |
| POST | `/api/orders/<id>/cancel` | Annulla un ordine non pagato |

Staff e gestione (header `X-Staff-Pin`):

| Metodo | Percorso | |
| --- | --- | --- |
| GET | `/api/kitchen/orders` | Coda cucina |
| POST | `/api/kitchen/orders/<id>/status` | `queued`, `preparing`, `ready`, `collected` |
| PATCH | `/api/kitchen/products/<id>` | Segna esaurito (`soldOut`) |
| GET | `/api/staff/orders` | Ordini del giorno (filtri `number`, `status`, `payment`, `day`) |
| POST | `/api/staff/orders` | Ordine fatto in cassa (`payment`: `cash`/`card`/`mixed` per incassarlo subito) |
| PUT | `/api/staff/orders/<id>/lines` | Cambia i prodotti di un ordine non pagato e non in cucina |
| POST | `/api/staff/orders/<id>/mark-paid` | Pagato in cassa (`method`, e `cashCents`/`cardCents`/`receivedCents` per misto e resto) |
| POST | `/api/staff/orders/<id>/cancel` | Annulla |
| POST | `/api/staff/orders/<id>/actions/<azione>` | Ristampa / riprova un'azione |
| GET | `/api/staff/print-jobs` | Registro stampe (anche quelle demo) |
| GET | `/api/staff/summary` | Riepilogo del giorno (`day=AAAA-MM-GG`) |
| POST | `/api/admin/media?name=foto.jpg` | Carica una foto (corpo: il file), restituisce l'URL |
| GET/PUT | `/api/admin/settings` | Impostazioni complete |
| GET | `/api/admin/flow/presets`, `/api/admin/adapters` | Preset e adattatori disponibili |
| POST | `/api/admin/flow/validate` | Verifica un flusso |
| GET | `/api/admin/menu` | Menu completo, anche gli elementi disattivati |
| POST/PUT/DELETE | `/api/admin/categories`, `/api/admin/products`, `/api/admin/modifier-groups` | Gestione menu |

WebSocket `/ws` (con `?pin=` per ricevere anche gli ordini): eventi
`order.created`, `order.updated`, `menu.updated`, `settings.updated`,
`print.job`, `pickup.announce`.

## Sviluppo

```sh
dart format packages server && dart analyze packages server
(cd packages/kiosk_core && dart test)
(cd server && dart test)
(cd apps/kiosk && flutter analyze && flutter test)
(cd apps/staff && flutter analyze && flutter test)
```

## Piano di lavoro

1. **Fondamenta e backend** ✓
2. **App kiosk Windows (Flutter)** ✓
3. **Schermo cucina, schermo ritiro e pannello di gestione** ✓
4. **Installazione nel locale**: totem a schermo intero, pacchetto e installer Windows, registratore telematico Epson ✓; adattatore del POS reale da scrivere quando il locale sceglie il fornitore
