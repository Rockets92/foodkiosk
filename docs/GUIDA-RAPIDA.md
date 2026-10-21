# Guida rapida: provare Food Kiosk sul proprio PC

Tutto parte in **modalità demo**: pagamenti e scontrini sono simulati, non
serve nessun POS né stampante. PIN dell'area staff: **1234**.

## Strada 1: installer (consigliata, Windows)

Totem e app staff sono programmi Windows: niente browser, e il server parte
da solo in background quando li apri.

1. Su GitHub apri il repository **foodkiosk** → scheda **Actions** → l'ultima
   esecuzione verde di **CI** sul ramo del lavoro (o su `main`).
2. In fondo alla pagina, sotto **Artifacts**, scarica
   **FoodKiosk-Windows-installer** (serve essere collegati a GitHub) ed
   estrai `FoodKiosk-Setup.exe` dallo zip.
3. Avvia `FoodKiosk-Setup.exe` e scegli **Tutto su questo PC**. Alla fine
   lascia spuntato *Apri subito il totem in una finestra*.
4. Da menu Start o desktop:
   - **Food Kiosk Totem in finestra**: il totem in una finestra verticale,
     comodo per provarlo sul PC;
   - **Food Kiosk Totem**: il totem a schermo intero, come sul chiosco;
   - **Food Kiosk Staff**: cassa, cucina, ritiro, menu e impostazioni
     (PIN **1234**).

Al primo avvio Windows può mostrare due avvisi:
- **"Windows ha protetto il PC"** (il programma non è ancora firmato):
  *Ulteriori informazioni* → *Esegui comunque*;
- **Firewall** per FoodKioskServer: *Consenti* se vuoi collegare altri PC o
  tablet della rete, altrimenti va bene anche *Annulla*.

Per uscire dal totem a schermo intero: tieni premuto per 3 secondi l'angolo
in alto a sinistra, inserisci il PIN e tocca **Chiudi applicazione**.

Senza installare: scarica **FoodKiosk-Windows-portatile**, estrai lo zip e
fai doppio clic su `totem\FoodKioskTotem.exe` o `staff\FoodKioskStaff.exe`.

Il server resta acceso in background anche dopo aver chiuso il totem, così
cucina e cassa continuano a ricevere gli ordini. Per spegnerlo: Gestione
attività → FoodKioskServer → Termina attività.

## Strada 2: dal codice, nel browser (per sviluppo)

Serve [Flutter](https://docs.flutter.dev/get-started/install) (contiene già
Dart) e [Git](https://git-scm.com/downloads). Funziona anche su macOS e
Linux; la versione per il locale resta quella Windows della Strada 1.

```sh
git clone https://github.com/Rockets92/foodkiosk.git
cd foodkiosk
dart pub get

cd apps/kiosk
flutter build web --base-href /kiosk/ --no-web-resources-cdn
cd ../staff
flutter build web --base-href /staff/ --no-web-resources-cdn
cd ../../server
dart run bin/server.dart --kiosk-web ../apps/kiosk/build/web --staff-web ../apps/staff/build/web
```

Poi apri `http://localhost:8080/kiosk/` e `http://localhost:8080/staff/`.
Finché il lavoro non è unito a `main`, dopo il `git clone` esegui
`git checkout claude/project-thread-bmkcru`.

## Cosa provare in 5 minuti

1. **Totem**: tocca lo schermo, scegli *Mangio qui*, aggiungi un panino col
   **+** (vola nel carrello), apri un menu e scegli contorno e bibita,
   poi *Ordina* → *Conferma ordine*. Compare il numero d'ordine.
2. **Staff → Cassa**: l'ordine è tra quelli *Da incassare*; aprilo e tocca
   *Incassato in contanti*.
3. **Staff → Cucina**: l'ordine compare da solo; *Inizia* → *Pronto*.
4. **Staff → Ritiro**: il numero è nella colonna *Pronto! Ritira qui*.
   In cucina tocca *Consegnato* e sparisce.
5. **Staff → Impostazioni → Flusso ordine**: scegli *Servizio completo* e
   salva. Ora il totem fa pagare con il POS simulato e "emette" il
   documento fiscale; con *Solo ordine* stampa solo lo scontrino da portare
   in cassa.
6. **Staff → Menu**: cambia un prezzo, carica una foto o segna un prodotto
   come esaurito: il totem si aggiorna subito.
7. **Staff → Riepilogo**: incasso, ordini e prodotti più venduti del giorno.

Suggerimento: il totem è pensato per uno schermo verticale. Su un PC
normale usa **Food Kiosk Totem in finestra**; nel browser (Strada 2) puoi
simularlo con **F12** → icona dei dispositivi → dimensione 1080 × 1920.

## Ripartire da zero

Ferma il server (Gestione attività → FoodKioskServer) e cancella la
cartella `%ProgramData%\FoodKiosk\data` (avviando dal codice su macOS e
Linux: `server/data`). Al prossimo avvio torna il menu demo.
