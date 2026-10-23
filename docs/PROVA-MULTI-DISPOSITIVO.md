# Prova su più dispositivi: un locale simulato

Questa guida mette in piedi un locale "finto ma vero": un PC fa da server
e cassa, gli altri fanno da totem, cucina e schermo ritiro, tutti collegati
in rete. Si resta in **modalità demo** (pagamenti e scontrini simulati), PIN
staff **1234**.

## Di cosa hai bisogno

- **2-4 PC Windows** (portatili, mini PC o tablet Windows) sulla **stessa
  rete** Wi-Fi o via cavo. Le app sono programmi Windows: tablet Android o
  iPad oggi non sono supportati.
- L'installer **FoodKiosk-Windows-installer** (da GitHub → Actions → ultima
  esecuzione verde di CI → Artifacts), copiato su ogni PC.
- Su ogni PC la rete deve essere impostata come **Privata** (Impostazioni
  di Windows → Rete e Internet → la tua rete → Tipo di profilo di rete:
  Privato). Su una rete "Pubblica" il firewall blocca il server.

Con un solo PC si può fare quasi tutto lo stesso: vedi in fondo
[Con un solo PC](#con-un-solo-pc).

## Chi fa cosa

| Dispositivo | Cosa installare | Cosa apri |
|---|---|---|
| **PC 1: server + cassa** | *Tutto su questo PC*, con *Avvia il server all'accesso a Windows* spuntato | Food Kiosk Staff → **Cassa** |
| **PC 2: totem** (meglio con schermo touch verticale) | *Totem self-service con server* | Food Kiosk Totem |
| **PC 3: cucina** | *Postazione staff* | Food Kiosk Staff → **Cucina** a schermo intero |
| **PC 4 o TV: ritiro** (anche lo stesso PC della cucina con un secondo monitor) | *Postazione staff* | Food Kiosk Staff → **Schermo ritiro** |

C'è **un solo server**: quello del PC 1. Menu, ordini e impostazioni
vivono lì; gli altri dispositivi sono solo schermi collegati a lui.

## 1. Il PC server (PC 1)

1. Installa con **Tutto su questo PC** e spunta *Avvia il server
   all'accesso a Windows*. Se Windows chiede di consentire FoodKioskServer
   nel firewall, scegli **Consenti**.
2. Apri **Food Kiosk Staff**, PIN **1234**.
3. Vai in **Impostazioni → Rete**. In alto c'è l'**indirizzo del server**,
   per esempio `http://192.168.1.20:8080`: annotalo, serve su tutti gli
   altri dispositivi (c'è anche il tasto per copiarlo).
4. Sotto, *Collegati ora* elenca i dispositivi collegati: per ora solo
   questo PC.

Consiglio: per non vedere l'indirizzo cambiare dopo un riavvio del router,
dai al PC 1 un IP fisso (prenotazione DHCP nel router).

## 2. Il totem (PC 2)

1. Installa con **Totem self-service con server** e apri **Food Kiosk
   Totem** (o *Totem in finestra* se lo schermo non è verticale).
2. Al primo avvio il totem usa un server suo, su quel PC: va puntato al
   PC 1. Tieni premuto per **3 secondi l'angolo in alto a sinistra**,
   inserisci il PIN **1234** e scegli **Indirizzo server**.
3. Scrivi l'indirizzo del PC 1 (es. `http://192.168.1.20:8080`) e OK. Il
   totem si ricarica con il menu del PC 1. L'indirizzo resta salvato.
4. Sul PC 1, in *Impostazioni → Rete*, compare **Totem** con l'IP del PC 2.

Se l'indirizzo è sbagliato il totem mostra "Fuori servizio" con
l'indirizzo sotto: l'angolo in alto a sinistra funziona anche così (con
l'ultimo PIN che il server aveva accettato), quindi puoi correggerlo.

Il server locale avviato al primo avvio sul PC 2 resta acceso ma non
serve: puoi chiuderlo da Gestione attività → FoodKioskServer, e dal
riavvio successivo non parte più perché il totem punta al PC 1.

### Stampante della ricevuta collegata al totem (USB)

Se il totem ha una stampante termica collegata via USB (o comunque
installata in Windows su quel PC), la ricevuta con il numero d'ordine può
uscire lì:

1. Sul PC 1, in **Food Kiosk Staff → Impostazioni → Dispositivi →
   Stampante scontrini cliente**, scegli **Stampante del totem (USB o
   Windows)** e la larghezza della carta (80 mm o 58 mm), poi salva.
2. Sul totem: angolo in alto a sinistra 3 secondi → PIN → **Stampante
   ricevute**. Scegli la stampante dall'elenco (o lascia la predefinita di
   Windows), tocca **Stampa di prova** e controlla che esca e venga
   tagliata, poi **Salva**.

Da quel momento ogni totem stampa le ricevute dei suoi ordini: quella con
"Paga in cassa" quando il cliente va alla cassa, quella "Pagato" quando
paga con il POS al totem e va direttamente al ritiro. Le ristampe chieste
dallo staff e gli ordini fatti al banco escono dalla stampante cassa. Se la
stampa non riesce l'ordine passa lo stesso: l'errore si vede nella stessa
schermata *Stampante ricevute* del totem.

La stampa è diretta (RAW, comandi ESC/POS): funziona con i driver delle
stampanti termiche (Epson TM, Custom, POS-80 generiche) e con il driver
"Generic / Text Only" di Windows.

## 3. La cucina (PC 3)

1. Installa con **Postazione staff** e apri **Food Kiosk Staff**.
2. Nella schermata di accesso tocca **Server**, scrivi l'indirizzo del PC 1,
   inserisci il PIN e **Entra**.
3. Apri **Cucina** e mettila a schermo intero. Al prossimo avvio l'app
   ricorda server e PIN ed entra da sola: riapri solo la sezione Cucina.

## 4. Lo schermo ritiro (PC 4, o TV collegata al PC della cucina)

Apri **Food Kiosk Staff** → **Server** → indirizzo del PC 1 → **Schermo
ritiro**. Non serve il PIN: mostra solo i numeri. In alternativa, da una
postazione staff già entrata: **Ritiro** → schermo intero.

A questo punto *Impostazioni → Rete* sul PC 1 deve mostrare tutti i
dispositivi: **Totem**, **Postazione staff** (cassa e cucina) e **Schermo
ritiro**. Se uno manca, vedi [Se qualcosa non si collega](#se-qualcosa-non-si-collega).

## 5. Clienti simulati

Per avere un flusso continuo di ordini senza qualcuno fisso al totem c'è il
**Simulatore clienti** (menu Start → Food Kiosk → *Simulatore clienti
(ordini di prova)*, su qualunque PC dove è installato il server).

All'avvio chiede:
- **Indirizzo del server**: Invio per `http://localhost:8080` se sei sul
  PC 1, altrimenti l'indirizzo del PC 1;
- **Ordini al minuto**: 2 è un pranzo tranquillo, 6-8 un'ora di punta.

Ogni "cliente" ordina come dal totem, con il menu e il flusso attuali: da 1
a 4 prodotti con contorni e bibite validi, mangio qui o da asporto, e se il
flusso lo prevede paga al totem con il POS simulato. Gli arrivi sono
casuali attorno alla media, come clienti veri. Nella finestra vedi ogni
ordine (numero, totale, come paga). Per fermarlo chiudi la finestra o
premi Ctrl+C.

Da riga di comando: `FoodKioskSimulatore.exe --server http://192.168.1.20:8080 --rate 6 --count 30`.

## 6. Scenario di prova (circa 30 minuti)

Fallo con almeno una persona alla cassa e una in cucina; se sei da solo,
passa da un PC all'altro.

**A. Un ordine vero, dall'inizio alla fine** (flusso iniziale *Cassa, poi
cucina*)
1. Totem: *Mangio qui*, un menu con contorno e bibita, un dolce → *Ordina*
   → conferma. Annota il numero.
2. Cassa: l'ordine compare in *Da incassare* entro un secondo. Incassa in
   contanti dando 20 € e controlla il resto.
3. Cucina: l'ordine compare appena pagato. *Inizia*.
4. Ritiro: il numero è in *In preparazione*. In cucina *Pronto*: il numero
   passa in *Pronto! Ritira qui*. *Consegnato*: sparisce.

**B. Ora di punta** (10 minuti)
1. Avvia il simulatore a **6 ordini al minuto**.
2. Cassa: incassa man mano, alternando contanti, carta e pagamento misto;
   ogni tanto apri un ordine e aggiungi un prodotto prima di incassare.
3. Cassa: fai anche 2-3 ordini al banco con **Nuovo ordine**.
4. Cucina: lavora gli ordini in ordine di arrivo.
5. Cosa controllare: nessun ordine perso o doppio, numeri progressivi,
   cucina e ritiro che si aggiornano da soli senza toccare nulla, nessun
   rallentamento del totem mentre lo usi in parallelo.

**C. Modifiche dal vivo** (con il simulatore acceso)
1. Staff → Menu: segna un panino come **esaurito**. Sul totem appare
   esaurito subito e il simulatore smette di ordinarlo.
2. Cambia un prezzo: il totem lo mostra subito; gli ordini già fatti
   tengono il prezzo vecchio.

**D. Un altro modo di lavorare**
1. Impostazioni → Flusso ordine → **Servizio completo** → Salva.
2. Totem: ora fa pagare con il POS simulato e la cucina riceve l'ordine
   subito dopo il pagamento, senza passare dalla cassa. Il simulatore
   paga al totem.
3. Prova anche *Cassa e cucina subito* (la cucina parte prima
   dell'incasso) e *Solo ordine* (Cucina e Ritiro spariscono dallo staff).
4. Alla fine torna su *Cassa, poi cucina*.

**E. Guasti**
1. Stacca la rete del totem a metà di un ordine e conferma: il totem
   avvisa che il servizio non è raggiungibile e tiene il carrello.
   Riattacca la rete e conferma di nuovo: l'ordine passa.
2. Spegni il server sul PC 1 (Gestione attività → FoodKioskServer →
   Termina attività): cucina e ritiro smettono di aggiornarsi, il totem
   non accetta ordini. Riavvialo (menu Start → *Avvia solo il server*):
   tutti riprendono da soli e gli ordini di prima ci sono ancora.
3. Con il server spento, sul totem l'angolo in alto a sinistra + PIN deve
   comunque aprire il menu staff.
4. Chiudi e riapri il totem con il server spento: mostra "Fuori servizio"
   e riparte da solo, entro circa 5 secondi, quando il server torna.

**F. Fine servizio**
Staff → **Riepilogo**: ordini, incasso e prodotti più venduti. In demo gli
ordini sono segnati come tali.

Annota per ogni punto cosa non torna (con l'ora e il numero d'ordine): è
il modo più veloce per sistemarlo.

## Con un solo PC

Installa *Tutto su questo PC* e apri insieme:
- **Food Kiosk Totem in finestra**;
- **Food Kiosk Staff** per la cassa e, se Windows te lo lascia aprire una
  seconda volta, un'altra finestra di Food Kiosk Staff per la cucina o lo
  schermo ritiro (altrimenti passa da una sezione all'altra);
- il **Simulatore clienti** con l'indirizzo proposto.

Così vedi tutto il giro dell'ordine, ma non provi la rete: appena puoi
aggiungi almeno un secondo PC come totem.

## Se qualcosa non si collega

- **Stessa rete?** I dispositivi devono essere sulla stessa rete del PC 1
  (non sulla rete ospiti del Wi-Fi, che spesso isola i dispositivi).
- **Rete Privata e firewall:** sul PC 1 la rete deve essere *Privata*;
  l'installer apre la porta solo sulle reti private. Se hai cliccato
  *Annulla* sull'avviso del firewall, reinstalla oppure consenti
  FoodKioskServer in *Windows Defender Firewall → Consenti app*.
- **Indirizzo:** dal PC che non si collega apri il prompt dei comandi e
  scrivi `ping 192.168.1.20` (l'IP del PC 1). Se non risponde è un problema
  di rete, non dell'app.
- **Ripartire da zero:** sul PC 1 ferma il server e cancella
  `%ProgramData%\FoodKiosk\data`. Gli altri dispositivi non hanno dati da
  cancellare.
