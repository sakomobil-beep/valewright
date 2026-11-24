# Valewright – Baue. Wirtschafte. Herrsche.

Ein Aufbauspiel im Odenwälder Fachwerkstil – von **Odenforge**.

Dies ist die **Godot-4-Version** (Godot 4.7.2). Die bisherige Browser-Version liegt unter
[sakomobil-beep/odenwaldsiedler](https://github.com/sakomobil-beep/odenwaldsiedler).

- **Web-Version zum Testen:** https://sakomobil-beep.github.io/valewright/
- **Auf dem PC:** Projektordner in Godot 4.7 öffnen (`project.godot`) und ▶ drücken.

## Umzug in Etappen
1. ✅ Welt & Kamera (Gelände, Fluss, Seen, Berge, Wald, Haupthaus-Platzhalter) + Sprachen Deutsch/Englisch
2. 🔨 Bauen: Gebäude wählen, Platz zeigen, bestätigen (läuft) – Warenkette folgt
   Modelle werden aus der Browser-Version als GLB exportiert (`models/`)
3. ⏳ Siedler, Wegfindung, Träger
4. ⏳ Alle Gebäude & Warenketten
5. ⏳ Gebiet, Wachtürme, Kampf, KI-Gegner
6. ⏳ Menüs, Speichern/Laden, Tutorial, Kampagne „Die Chronik von Valewright“
7. ⏳ Grafik-Feinschliff, Geräusche, Windows-Version

## Sprachen
Alle Texte stehen in `translations/texts.tsv` (Tab-getrennt: `key`, `de`, `en`).
Neue Sprache = neue Spalte anhängen. Im Code werden nur die Schlüssel verwendet (z. B. `UI_TITLE`).
