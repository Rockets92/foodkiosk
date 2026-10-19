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
| `apps/` | Schermo cucina e pannello di gestione: in arrivo nel passo 3. |

## Avvio rapido

Serve il [Dart SDK](https://dart.dev/get-dart) 3.8 o superiore.

```sh
dart pub get
cd server
dart run bin/server.dart            # http://localhost:8080
```

Al primo avvio il server crea `server/data/foodkiosk.db`, carica un menu demo
(panini, menu, contorni, bibite, dolci con allergeni, calorie e foto
segnaposto) e parte in **modalità demo**. PIN staff/admin predefinito: `1234`.

Opzioni: `--port`, `--host`, `--data-dir`, `--no-demo-menu`.

## App kiosk

Serve [Flutter](https://docs.flutter.dev/get-started/install) (stable).

Il flusso per il cliente: schermata di attesa → lingua e "mangio qui / porto
via" → menu per categorie → dettaglio prodotto (foto, descrizione,
calorie, allergeni, varianti obbligatorie ed extra, quantità) → carrello →
pagamento sul totem, in cassa o a scelta del cliente, secondo il flusso
configurato → numero d'ordine. Se il cliente si allontana, dopo il tempo di
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

Logo e colori sono segnaposto: i colori stanno in
`apps/kiosk/lib/src/ui/theme.dart`, il logo è servito dal server. Le
traduzioni dell'interfaccia sono in `apps/kiosk/lib/src/i18n.dart`: per
aggiungere una lingua basta un nuovo blocco di testi e abilitarla nelle
impostazioni.

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
| Fiscale | `none`, `demo` |
| Stampante | `none`, `demo` (solo registro stampe), `escposNetwork` (stampante termica ESC/POS in rete, porta 9100) |

Esempio di stampante termica di rete:

```json
{ "customerPrinter": { "type": "escposNetwork", "options": { "host": "192.168.1.50", "port": 9100, "width": 42 } } }
```

L'integrazione con un POS reale, con le stampanti USB su Windows e con il
registratore telematico è prevista nel passo 4.

## API

Pubbliche (usate dal totem):

| Metodo | Percorso | |
| --- | --- | --- |
| GET | `/api/settings` | Impostazioni pubbliche (lingue, modalità, flusso) |
| GET | `/api/menu` | Menu visibile sul totem |
| GET | `/api/allergens` | Elenco allergeni e etichette dietetiche tradotte |
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
| POST | `/api/staff/orders/<id>/mark-paid` | Pagato in cassa |
| POST | `/api/staff/orders/<id>/cancel` | Annulla |
| POST | `/api/staff/orders/<id>/actions/<azione>` | Ristampa / riprova un'azione |
| GET | `/api/staff/print-jobs` | Registro stampe (anche quelle demo) |
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
```

## Piano di lavoro

1. **Fondamenta e backend** ✓
2. **App kiosk Windows (Flutter)** ✓
3. Schermo cucina e pannello di gestione
4. Installazione nel locale: modalità kiosk Windows, installer, POS reale, registratore telematico
