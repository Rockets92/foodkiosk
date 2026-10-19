# Guida rapida: provare Food Kiosk sul proprio PC

Tutto parte in **modalità demo**: pagamenti e scontrini sono simulati, non
serve nessun POS né stampante. PIN dell'area staff: **1234**.

## Strada 1: pacchetto pronto (consigliata, Windows)

1. Su GitHub apri il repository **foodkiosk** → scheda **Actions** → l'ultima
   esecuzione verde di **CI** sul ramo del lavoro (o su `main`).
2. In fondo alla pagina, sotto **Artifacts**, scarica
   **FoodKiosk-Windows-portatile** (serve essere collegati a GitHub).
3. Estrai lo zip in una cartella, per esempio `C:\FoodKiosk`.
4. Doppio clic su **`Avvia demo.bat`**. Si apre una finestra del server
   (lasciala aperta) e nel browser compaiono:
   - il **totem**: `http://localhost:8080/kiosk/`
   - l'**area staff**: `http://localhost:8080/staff/` (PIN 1234)

Al primo avvio Windows può mostrare due avvisi:
- **"Windows ha protetto il PC"** (il programma non è ancora firmato):
  *Ulteriori informazioni* → *Esegui comunque*;
- **Firewall**: *Consenti* se vuoi collegare tablet o altri PC della rete,
  altrimenti va bene anche *Annulla*.

Altri avvii nella stessa cartella:

| File | Cosa fa |
| --- | --- |
| `Avvia totem in finestra.bat` | Il totem come programma Windows, in una finestra verticale |
| `Avvia totem.bat` | Il totem a schermo intero, come sul chiosco |
| `Avvia staff.bat` | L'app staff come programma Windows |
| `Avvia server.bat` | Solo il server, con il registro delle attività |

Per uscire dal totem a schermo intero: tieni premuto per 3 secondi l'angolo
in alto a sinistra, inserisci il PIN e tocca **Chiudi applicazione**.

C'è anche **FoodKiosk-Windows-installer** (`FoodKiosk-Setup.exe`): installa
tutto con le icone nel menu Start, ed è quello da usare sul totem vero.

## Strada 2: dal codice (Windows, macOS o Linux)

Serve [Flutter](https://docs.flutter.dev/get-started/install) (contiene già
Dart) e [Git](https://git-scm.com/downloads).

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

Suggerimento: il totem è pensato per uno schermo verticale. Nel browser
puoi vederlo così con **F12** → icona dei dispositivi → dimensione
1080 × 1920, oppure usa `Avvia totem in finestra.bat`.

## Ripartire da zero

Chiudi il server e cancella la cartella `%ProgramData%\FoodKiosk\data`
(su macOS e Linux, avviando dal codice: `server/data`). Al prossimo avvio torna il menu demo.
