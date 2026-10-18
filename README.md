# Summgarten 2.0.0

Kinderspiel (3–6 Jahre) in Godot 4.7: Die Stimme des Kindes lässt Pflanzen und Wesen wachsen, die den Klang pentatonisch korrigiert im Takt vorsingen. Konzept: [Summgarten – Spielkonzept.md](Summgarten%20–%20Spielkonzept.md).

## Umfang v1
- 1 Garten mit 8 Beeten, Samen antippen → 2,5 s Aufnahme → Wesen wächst
- 9 Wesen: Tonhöhe bestimmt die Form (tief = Pilz, mittel = Krabbler, hoch = Blume), Lautstärke Größe und Farbe; Wachs-, Sing- und Schlafanimation
- Leise Begleitmusik im Takt (Bass + Spieluhr), pausiert während der Aufnahme und nachts
- Konzert (Dirigentenstab ab 3 Wesen): Melodie, dann Zweiklänge, Finale mit allen, Feuerwerk und Verbeugung; 90 BPM, pentatonische Korrektur, Hall
- Persönlichkeit: Wesen blinzeln, schauen umher und zum singenden Nachbarn, wippen mit
- Gemalter Look per Papier-/Aquarell-Shader (`shaders/paper.gdshader`)
- Geräuschkulisse: Vögel tagsüber, Grillen nachts, Regenrauschen, Gähnen beim Einschlafen
- Sofortige Rückmeldung: Tipp-Geräusch, Knöpfe federn, der Samen zappelt mit der Stimme
- Wetter: Sonne = höher/schneller (116 BPM), Regen = tiefer/langsamer (68 BPM)
- 12 eingebaute Klänge, wenn kein Mikrofon da/erlaubt ist oder nur Stille kam – kein Scheitern
- Nach 6 Minuten wird es Abend, alle schlafen ein; die Sonne weckt den Garten
- Garten und Aufnahmen werden lokal gespeichert (`user://`), Begrüßung beim Start
- Elternbereich (kleiner Kreis oben rechts) hinter Rechenaufgabe: Mikrofon an/aus, Lautstärke, Tageslänge (4/6/10 min), Konzert als WAV in „Dokumente“ speichern, Aufnahmen löschen, Garten leeren
- Keine Texte im Kinderbereich, nur Klicken (kein Ziehen), Touch funktioniert

## Studio-Intro
`addons/minh_studio_intro` (aus Kontor übernommen), Preset `presets/klanggarten.tres`. Läuft beim ersten Start in voller Länge, danach kurz; überspringbar mit jeder Taste, Berührung oder Pad-Taste.

## Schriften
Noto Sans SC/JP (OFL, `fonts/OFL-NotoSansCJK.txt`) auf die genutzten Zeichen reduziert (~150 KB). Bei neuen Übersetzungen neu reduzieren (siehe Commit-Historie, `fontTools.subset`).

## Inhalte (seit 2.0)
- **Nachsing-Spiel** (Sprechblasen-Knopf): Wesen singen eine Folge vor, das Kind singt nach (Mikrofon) oder tippt die Wesen in der richtigen Reihenfolge an. 3 Runden, ohne Scheitern
- **Vier Jahreszeiten**: Landschaft, Bäume, Blüten, Laub oder Schnee, Accessoires der Wesen. Wechselt jeden Tag oder fest im Elternbereich
- **9 Sprachen** (de, en, zh_CN, fr, es, pt_BR, ja, ru, pl) in `i18n/strings.csv`, automatisch nach Systemsprache oder im Elternbereich. Store-Texte in `STORE.md`
- Wachstumsstufen Keimling → Knospe → Wesen, Freude- und Gähn-Gesicht, Wippen im Takt

## Grafik (2.0)
- 9 eigene Figuren (Pilz, Kürbis, Schnecke, Käfer, Vogel, Frosch, Blume, Glockenblume, Sonnenblume) mit farbigen Konturen, Schatten und Glanzlichtern
- 6 Beete organisch auf drei Tiefen, Weg, Baum, Zaun, Steine, Gießkanne, Blattrahmen im Vordergrund
- Farbige, dicke Icons; Elternbereich mit eigenem Theme; Regenbogen nach dem Regenkonzert
- Store-Bilder: `tools/store_shots.tscn -- shots <ordner> <sprache>` (7 Screenshots 1920×1080 mit übersetzten Überschriften) und `-- capsule <ordner>` → erst zum finalen Release rendern
- Tests: `tests/run_tests.gd`, `tests/smoke.tscn`, `tests/seasons.tscn`, `tests/echo.tscn`

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

## macOS signieren und notarisieren
`bash tools/release_macos.sh` → `build/macos-signed/Summgarten-macOS.zip` (Developer ID, Hardened Runtime, notarisiert, Ticket angeheftet).

## Offen vor Steam-Veröffentlichung
- Windows: Icon/Metadaten per rcedit, optional Code-Signatur
- Steamworks: App-ID, Depots, Store-Seite (Texte siehe `STORE.md`), Steam-Deck-Test mit Headset
- Test mit echten Kindern; pädagogische Begründung mit Literatur belegen
