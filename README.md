# Klanggarten 1.0.0

Kinderspiel (3–6 Jahre) in Godot 4.7: Die Stimme des Kindes lässt Pflanzen und Wesen wachsen, die den Klang pentatonisch korrigiert im Takt vorsingen. Konzept: [Klanggarten – Spielkonzept.md](Klanggarten%20–%20Spielkonzept.md).

## Umfang v1
- 1 Garten mit 8 Beeten, Samen antippen → 2,5 s Aufnahme → Wesen wächst
- 9 Wesen: Tonhöhe bestimmt die Form (tief = Pilz, mittel = Krabbler, hoch = Blume), Lautstärke Größe und Farbe; Wachs-, Sing- und Schlafanimation
- Konzert (Dirigentenstab ab 3 Wesen), 90 BPM, pentatonische Korrektur, Hall
- Wetter: Sonne = höher/schneller (116 BPM), Regen = tiefer/langsamer (68 BPM)
- 12 eingebaute Klänge, wenn kein Mikrofon da/erlaubt ist oder nur Stille kam – kein Scheitern
- Nach 6 Minuten wird es Abend, alle schlafen ein; die Sonne weckt den Garten
- Garten und Aufnahmen werden lokal gespeichert (`user://`), Begrüßung beim Start
- Elternbereich (kleiner Kreis oben rechts) hinter Rechenaufgabe: Mikrofon an/aus, Lautstärke, Aufnahmen löschen, Garten leeren
- Keine Texte im Kinderbereich, nur Klicken (kein Ziehen), Touch funktioniert

## Bauen und testen
```bash
"/Applications/Godot 4.7.app/Contents/MacOS/Godot" --headless --path . -s tests/run_tests.gd
```
```bash
"/Applications/Godot 4.7.app/Contents/MacOS/Godot" --path . res://tests/smoke.tscn -- /tmp
```
```bash
for p in macOS Windows Linux; do "/Applications/Godot 4.7.app/Contents/MacOS/Godot" --headless --path . --export-release $p; done
```
Ergebnisse in `build/` (macOS universal, ad-hoc signiert, mit Mikrofon-Berechtigungstext; Windows x86_64; Linux/Steam Deck x86_64).

## Offen vor Steam-Veröffentlichung
- macOS: mit Developer-ID signieren und notarisieren (aktuell nur ad-hoc)
- Windows: Icon/Metadaten per rcedit, optional Code-Signatur
- Steamworks: App-ID, Depots, Store-Seite (Texte siehe `STORE.md`), Steam-Deck-Test mit Headset
- Test mit echten Kindern; pädagogische Begründung mit Literatur belegen
