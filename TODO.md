# The Memory Lane Journalist - Task List

Questo file tiene traccia dello stato di avanzamento del progetto.

## Fase 1: Struttura di Base e Dati

- [x] Creare il modello dati per `Moment` (`lib/models/moment.dart`)
- [x] Creare il modello dati per `Trip` (`lib/models/trip.dart`)
- [x] Impostare la struttura iniziale dell'app (`lib/main.dart`)
- [x] Creare la `HomePage` per visualizzare i viaggi
- [x] Implementare la finestra di dialogo per l'aggiunta di un nuovo viaggio (`lib/widgets/add_trip_dialog.dart`)
- [x] Creare la `TripDetailPage` per i dettagli del viaggio (`lib/screens/trip_detail_page.dart`)
- [x] Implementare la navigazione dalla `HomePage` alla `TripDetailPage`

## Fase 2: GPS e Registrazione dei Momenti

- [x] Aggiungere le dipendenze per la geolocalizzazione (es. `location`)
- [x] Creare un service per gestire la logica del GPS (`lib/services/location_service.dart`)
- [x] Avviare e interrompere la registrazione del percorso dalla `TripDetailPage`
- [x] Salvare le coordinate GPS nel database locale
- [x] Implementare la funzionalità per aggiungere 'Momenti' di tipo 'Nota'
- [x] Implementare la funzionalità per aggiungere 'Momenti' di tipo 'Foto' (con `image_picker`)
- [x] Collegare ogni `Moment` alla sua posizione e timestamp

## Fase 3: Funzionalità Avanzate e Notifiche

- [x] Implementare il Geofencing per i "Luoghi del Cuore"
- [x] Inviare notifiche quando si entra in un'area geofenced
- [x] Implementare le notifiche periodiche per i "Missing Memory" vicino a POI

## Fase 4: Visualizzazioni e Analisi

- [ ] Creare la `Timeline Narrativa` nella `TripDetailPage`
- [ ] Visualizzare i chilometri percorsi (per i multi-day trips)
- [ ] Mostrare le anteprime di foto e note nella timeline
- [ ] Implementare la `Photo Heat Map` sulla mappa
- [x] Visualizzare il tracciato GPS del viaggio sulla mappa

## Fase 5: Gestione dei Periodi "No Travel"

- [ ] Progettare come visualizzare i periodi senza viaggi nella timeline principale
- [ ] Incoraggiare l'utente a iniziare un nuovo logging se rileva movimento

## Fase 6: Persistenza dei Dati

- [x] Scegliere e implementare una soluzione di database locale (es. `hive`)
- [x] Adattare i modelli per Hive (`Moment`, `Trip`)
- [x] Generare gli adapter di Hive
- [x] Creare un `DatabaseService` per centralizzare l'accesso ai dati
- [x] Salvare e caricare viaggi e momenti dal database
