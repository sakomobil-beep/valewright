# Valewright – Baue. Wirtschafte. Herrsche.

Ein Aufbauspiel im Odenwälder Fachwerkstil – von **Odenforge**.

Dies ist die **Godot-4-Version** (Godot 4.7.2). Die bisherige Browser-Version liegt unter
[sakomobil-beep/odenwaldsiedler](https://github.com/sakomobil-beep/odenwaldsiedler).

- **Web-Version zum Testen:** https://sakomobil-beep.github.io/valewright/
- **Auf dem PC:** Projektordner in Godot 4.7 öffnen (`project.godot`) und ▶ drücken.

## Umzug in Etappen
1. ✅ Welt & Kamera (Gelände, Fluss, Seen, Berge, Wald, Haupthaus-Platzhalter) + Sprachen Deutsch/Englisch
2. ✅ Bauen (wählen, Platz zeigen, bestätigen), Baukosten, Bauzeit, Lageranzeige, erste Warenkette Holzfäller → Sägewerk, Steinmetz, Förster
   Modelle werden aus der Browser-Version als GLB exportiert (`models/`)
3. ✅ Siedler: Bauarbeiter, Holzfäller, Steinmetz, Förster, Sägewerker, Träger · Wegfindung um Wasser, Steilhänge und Gebäude · mehr Träger bei Wachstum
4. ✅ Alle 50 Gebäude, 43 Waren, alle Warenketten, Baumenü nach Kategorien, Wohnhäuser mit 5 Stufen + Bedürfnissen + Steuern, Freischalten Brücke über Fluss und Seen, Werkzeug für neue Arbeiter Felder wachsen sichtbar, Tiere bei den Zuchten, Emoji-Schrift für die Web-Version, Rutengänger findet Bodenschätze, Bergwerke nur an gefundenen Vorkommen
5. ✅ Gebiet mit Grenzpfählen, Wachstube/Wachturm/Wehrturm/Burg mit Wächtern (Kampfstock), Kaserne (Schwertkämpfer/Bogenschützen), Angreifen, Erobern, KI-Gegner (wachsen, bauen Türme, greifen an), Sieg/Niederlage
6. ✅ Hauptmenü, Neues Spiel (Spielziel: Eroberung/Wirtschaftssieg/Gebietssieg/Endlosspiel, Gegner, Schwierigkeit, Karte; nach dem Sieg weiterspielen), Speichern/Laden (3 Plätze + automatisch), Pausenmenü, Tutorial, Kampagne „Die Chronik von Valewright – Buch I“ mit 4 Kapiteln
7. ⏳ Grafik-Feinschliff, Geräusche, Windows-Version

## Sprachen
Alle Texte stehen in `translations/texts.tsv` (Tab-getrennt: `key`, `de`, `en`).
Neue Sprache = neue Spalte anhängen. Im Code werden nur die Schlüssel verwendet (z. B. `UI_TITLE`).
