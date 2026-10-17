# Klanggarten – Spielkonzept

Oct 15, 2026 · @Michél Nguyen

## Idee, Zielgruppe, Plattformen

Im Klanggarten wird die eigene Stimme des Kindes zum Baumaterial: Jedes aufgenommene Geräusch lässt eine Pflanze oder ein Tierchen wachsen, das den Klang im Takt wieder vorsingt, bis ein kleines Orchester entsteht.

**Pitch für Eltern:** Dein Kind komponiert mit seiner eigenen Stimme. Ohne Text, ohne Scheitern, ohne Werbung.

**Zielgruppe:** Kinder von 3 bis 6 Jahren, gekauft und oft gemeinsam gespielt mit Eltern.

**Gestaltungsregeln für diese Altersgruppe:**

- Keine Texte im Spiel, alles über Symbole, Animation und Klang
- Kein Scheitern, keine Punkte, kein Zeitdruck – jede Eingabe erzeugt eine freundliche Reaktion
- Große Berührflächen, sofortiges Feedback auf jede Berührung
- Kurze Einheiten von 5–10 Minuten mit natürlichem Ende (der Garten geht schlafen)

**Plattformen in dieser Reihenfolge:**

1. **Steam (PC) als erster Release** – Test des Konzepts und Lernen des Steam-Ablaufs. Ehrliche Einschätzung: Steam ist für Kleinkinder ein schwacher Markt, und eine Maus ist für 3-Jährige schwer zu bedienen. Darum muss das Spiel mit Touchscreen-Laptops, Steam Deck und einfacher Maussteuerung (nur Klicken, kein Ziehen) funktionieren.
2. **iPad und iOS als Hauptmarkt danach** – Hier suchen Eltern gezielt nach werbefreien Apps für Kleinkinder, und Touch ist die natürliche Bedienung.

## Kern-Interaktionen und Spielablauf

Eine Runde folgt immer demselben ruhigen Ablauf: Samen pflanzen, Geräusch aufnehmen, zusehen, wie es wächst, und am Ende gemeinsam das Garten-Konzert hören.

**Ablauf einer Runde:**

1. **Samen antippen:** Ein leuchtender Samen liegt im Beet. Das Kind tippt darauf, ein großes Mikrofon-Symbol pulsiert.
2. **Geräusch machen:** Das Kind summt, lacht, klatscht oder macht ein Tiergeräusch. Eine Welle zeigt live, dass zugehört wird. Nach 2–3 Sekunden ist die Aufnahme fertig.
3. **Wachsen sehen:** Aus dem Samen wächst eine Pflanze oder ein Tierchen. Form und Farbe hängen vom Klang ab: hohe Töne werden zu zarten Blumen, tiefe zu dicken Pilzen, laute zu großen, leise zu kleinen Wesen.
4. **Antippen zum Abspielen:** Jedes Wesen singt beim Antippen den eigenen Klang des Kindes, leicht musikalisch bearbeitet.
5. **Konzert:** Ab drei Wesen kann das Kind den Dirigentenstab antippen. Alle Wesen spielen ihre Klänge nacheinander im Takt, als kleine Melodie.
6. **Schlafenszeit:** Nach einigen Minuten wird es Abend, die Wesen gähnen und schlafen ein. Ein sanftes Ende, das Eltern beim Aufhören hilft.

**Weitere Spielelemente:**

- **Wetter-Knöpfe:** Sonne macht alle Klänge heller und schneller, Regen tiefer und langsamer. So entdeckt das Kind Tonhöhe und Tempo ohne Erklärung.
- **Garten bleibt bestehen:** Der Garten wird gespeichert, beim nächsten Mal sind die Wesen wieder da und begrüßen das Kind mit seinen eigenen Klängen.
- **Ohne Mikrofon spielbar:** Wenn kein Mikrofon da ist oder die Eltern es nicht erlauben, gibt es vorgefertigte Klänge (Tierlaute, Instrumente), damit das Spiel trotzdem funktioniert.

**Pädagogischer Hintergrund (für Store-Text und Eltern):** Fördert Selbstwirksamkeit (meine Stimme bewirkt etwas), auditive Wahrnehmung (hoch–tief, laut–leise, schnell–langsam) und Ursache-Wirkung-Verständnis. Diese Begründung sollte vor dem Release fachlich mit Literatur aus der frühkindlichen Bildung belegt werden.

## Technik in Godot

Alles Nötige bringt Godot 4 mit: Mikrofon-Aufnahme, Klanganalyse und Tonhöhen-Bearbeitung laufen über das eingebaute Audio-System, ohne externe Plugins.

**Aufnahme:**

- In den Projekteinstellungen die Audio-Eingabe aktivieren (`audio/driver/enable_input`).
- Ein `AudioStreamPlayer` mit `AudioStreamMicrophone` speist einen eigenen Audio-Bus, auf dem ein `AudioEffectRecord` liegt.
- Aufnahme starten und nach 2–3 Sekunden stoppen; das Ergebnis ist ein `AudioStreamWAV`, das direkt abgespielt und in `user://` gespeichert werden kann.

**Klang-Analyse (bestimmt, welches Wesen wächst):**

- Lautstärke: Spitzen- und Durchschnittspegel aus den Samples der Aufnahme.
- Tonhöhe: grobe Schätzung über `AudioEffectSpectrumAnalyzer` während der Aufnahme oder eine einfache Grundfrequenz-Schätzung auf den Samples. Drei Stufen (tief, mittel, hoch) genügen völlig.

**Musikalisch machen (der Trick, damit es nach Orchester klingt):**

- Jeden Klang beim Abspielen über `pitch_scale` auf den nächsten Ton einer pentatonischen Tonleiter ziehen. In der Pentatonik klingt jede Kombination harmonisch.
- Alle Wiedergaben auf einen festen Takt legen (z. B. 90 BPM), damit das Konzert rhythmisch wirkt.
- Leichter Hall auf dem Bus (`AudioEffectReverb`) für einen weichen, märchenhaften Klang.

**Plattform-Details:**

| Plattform | Was zu beachten ist |
| --- | --- |
| Steam unter Windows | Mikrofon-Zugriff funktioniert direkt; Windows kann einmalig nach Erlaubnis fragen |
| Steam unter macOS | Mikrofon-Berechtigungstext im Export setzen, sonst verweigert macOS den Zugriff |
| Steam Deck | Touchscreen vorhanden, gut für Kinder; Mikrofon nur mit Headset zuverlässig |
| iPad und iOS | Mikrofon-Berechtigungstext im iOS-Export Pflicht; Touch ist die natürliche Bedienung |

**Datenschutz:** Aufnahmen bleiben ausschließlich auf dem Gerät. Kein Upload, keine Analyse-Dienste, kein Online-Zwang. Das ist bei Kinder-Apps nicht nur ein Verkaufsargument, sondern im App Store Voraussetzung.

## Scope v1, Kinderschutz, Preis, Fahrplan

Version 1 ist bewusst klein: ein Garten, eine Handvoll Wesen und das Konzert. Realistisch sind 6–10 Wochen nebenberuflich bis zur ersten spielbaren Fassung.

**Scope v1:**

- 1 Garten mit 8 Beeten
- 9 Wesen (3 Tonhöhen × 3 Lautstärken), jeweils mit Wachstums-, Sing- und Schlafanimation
- Konzert-Modus mit festem Takt und pentatonischer Korrektur
- 2 Wetter-Knöpfe (Sonne, Regen)
- 12 vorgefertigte Klänge für Spielen ohne Mikrofon
- Elternbereich hinter einer Elternsperre: Aufnahmen löschen, Mikrofon an/aus, Lautstärke

**Bewusst nicht in v1:** mehrere Gärten, Jahreszeiten, Teilen von Aufnahmen, Online-Funktionen.

**Kinderschutz und Store-Regeln:**

- Keine Werbung, keine In-App-Käufe, keine Drittanbieter-Analytics
- Links nach außen und Einstellungen nur hinter einer Elternsperre (z. B. eine Rechenaufgabe für Erwachsene)
- Aufnahmen nur lokal, mit Löschfunktion für Eltern
- Für iOS die Vorgaben der Kids-Kategorie im App Store vor der Einreichung genau prüfen

**Preis:**

- Steam: 4,99 € – kleiner Preis passend zum kleinen Umfang
- iOS: 3,99–5,99 € einmalig, ohne In-App-Käufe; Eltern schätzen genau das

**Fahrplan:**

1. Prototyp: Aufnahme, ein Wesen wächst, Wiedergabe mit Pentatonik (1–2 Wochen)
2. Test mit echten Kindern: Verstehen 3-Jährige den Ablauf ohne Erklärung? (früh und oft)
3. Alle 9 Wesen, Konzert, Wetter, Elternbereich (4–6 Wochen)
4. Steam-Seite live, Release auf Steam
5. iOS-Export, Touch-Feinschliff, App-Store-Einreichung

**Ehrliche Erwartung:** Auf Steam eher kleine Verkaufszahlen. Der eigentliche Markt ist das iPad. Der Steam-Release lohnt sich vor allem als Übung und als zusätzliche Präsenz.

**Einordnung in die Gesamtplanung:** Kontor bleibt Priorität. Der Klanggarten passt als kleines Projekt in Wartezeiten, z. B. während der Steam-Prüfungen.
