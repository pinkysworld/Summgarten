# Steam Deck

## Im Spiel umgesetzt
- **Auflösung 1280×800 (16:10):** Das Layout dehnt sich (`stretch/aspect=expand`), und die Rahmung hängt am echten unteren Rand. Geprüft mit `tests/deck.tscn`.
- **Touchscreen:** Er funktioniert direkt, Berührungen werden als Klicks ausgewertet. Für Kinder ist das die natürlichste Bedienung.
- **Gamepad:** Steuerkreuz oder linker Stick wählen Knöpfe und Beete (gelber Fokus-Ring), **A** tippt an, **Start** öffnet die Elternsperre, **B** schließt den Elternbereich. Im Elternbereich lassen sich alle Bedienelemente per Pad erreichen.
- **Vollbild** ist Standard. F11 oder Alt+Enter schaltet am PC zwischen Fenster und Vollbild um.
- **Mikrofon:** Das Deck hat eingebaute Mikrofone. Ohne Mikrofon funktioniert das Spiel mit eingebauten Klängen.
- **Text:** Im Kinderbereich steht keiner. Im Elternbereich ist die Schrift mindestens 14 px groß (Valve verlangt mindestens 9 px bei 1280×800).
- **Offline**, kein Launcher, keine Konten. Pausieren und Fortsetzen ist unkritisch, der Garten wird nach jeder Änderung gespeichert.

## In Steamworks einstellen
1. Depot „Linux“ mit `build/linux/Klanggarten.x86_64` (Startoption: diese Datei, Betriebssystem Linux + SteamOS).
2. **Steam Input:** Als Standard-Controllerkonfiguration „Gamepad“ wählen. Für den Touchscreen „Touchscreen als Maus“ aktiv lassen.
3. **Deck-Kompatibilität** unter „Steam Deck Compatibility Review“ anfordern. Angaben dazu:
   - Controller: volle Unterstützung
   - Bildschirm: 1280×800
   - Schriftgröße: ok
   - Kein Launcher
   - Offline spielbar
4. Store-Seite: Hinweis „Mit Touchscreen spielbar, ideal für kleine Hände“.

## Vor der Einreichung auf echtem Gerät testen
- Starten aus dem Gaming-Modus, Vollbild und Ton
- Mikrofon: Erlaubnis, Aufnahme, Pegel
- Touch, Pad und Elternsperre per Pad
- Standby während einer Aufnahme
- Chinesisch und Japanisch im Elternbereich: Dafür muss die mitgelieferte CJK-Schrift im Spiel sein, sonst fehlen Zeichen.
