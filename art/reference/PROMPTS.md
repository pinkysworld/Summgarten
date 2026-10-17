# Bild-Prompts für die Figuren-Vorlagen

**Ablauf**
- Zuerst Prompt 0 ausführen. Es zeigt die ganze Familie und legt den Stil fest.
- Das Familienbild bei den Figuren-Prompts als Stil-Referenz mitgeben. So bleiben alle 9 Figuren im selben Stil. Die beschriebenen Farben und anatomischen Merkmale haben Vorrang vor Abweichungen der Referenz.
- Speichere die Bilder hier im Ordner, zum Beispiel `00_family.png`, `01_mushroom.png` usw.

**Erstellt am 17.10.2026**

Mit dem eingebauten `image_gen`-Werkzeug erstellt und visuell geprüft. Alle zehn PNGs liegen direkt in diesem Ordner (2172 × 724 Pixel, cremefarbener Hintergrund). Die Einzelblätter zeigen von links nach rechts: fröhlich, singend, schläfrig, durstig; die Blumen welken im letzten Zustand. Es sind Figuren-Vorlagen, keine freigestellten Spiel-Sprites. Farbwerte dienen als Zielpalette und sind keine Garantie für pixelgenaue Hex-Farben.

| Vorlage | Bild |
| --- | --- |
| Familie | [00_family.png](00_family.png) |
| Pilz | [01_mushroom.png](01_mushroom.png) |
| Kürbis | [02_pumpkin.png](02_pumpkin.png) |
| Schnecke | [03_snail.png](03_snail.png) |
| Käfer | [04_beetle.png](04_beetle.png) |
| Vogel | [05_bird.png](05_bird.png) |
| Frosch | [06_frog.png](06_frog.png) |
| Gänseblümchen | [07_daisy.png](07_daisy.png) |
| Glockenblume | [08_bellflower.png](08_bellflower.png) |
| Sonnenblume | [09_sunflower.png](09_sunflower.png) |

Die tatsächlich verwendeten Prompts und Referenzbeziehungen stehen in [GENERATION.json](GENERATION.json). Nach Erstellung der Einzelblätter wurde das Familienbild an die mintgrüne Schnecke, die gelben Käfer-Fühlerspitzen und den grünen Stielkörper der Glockenblume angeglichen.

**Gemeinsamer Stil**
Der folgende Block steckt schon in jedem Prompt unten. Du musst ihn nicht extra einfügen, er steht hier nur zur Übersicht.

```
children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline (#2b2340), simple bold shapes, soft paper texture, warm pastel palette, plain cream background (#fbf6ee), front view, no text, no shading gradients, no 3D, no photorealism
```

---

## 0 – Familienbild (Stil festlegen)
```
Lineup of nine cute singing garden creatures standing side by side: a lilac mushroom, an orange pumpkin, a snail with a mustard shell, a round turquoise beetle, a sky-blue bird, a leaf-green frog, a pink daisy flower, a violet bellflower, a yellow sunflower. Each has a distinct, slightly odd silhouette and unusual eye shapes (no two alike), asymmetric charming details. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, front view, no text, no 3D, no photorealism
```

## 1 – Pilz (Lila)
```
Character model sheet of a cute singing mushroom creature, lilac (#9b6bd6) cap with uneven cream spots, slightly lopsided cap, short chubby stem with a face, unusual eye shape. Four expressions in a row: happy, singing with round open mouth, sleepy with closed eyes, thirsty and droopy with tired half-closed eyes. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, front view, no text, no 3D, no photorealism
```

## 2 – Kürbis (Orange)
```
Character model sheet of a cute singing pumpkin creature, orange (#ff9a3c), plump and a bit squashed, curly green stem with one leaf like a hair tuft, face on the front, unusual eye shape. Four expressions in a row: happy, singing with round open mouth, sleepy with closed eyes, thirsty and droopy with tired half-closed eyes. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, front view, no text, no 3D, no photorealism
```

## 3 – Schnecke (Senfgelbes Haus)
```
Character model sheet of a cute shy singing snail, big mustard-yellow (#ffc93c) spiral shell, soft mint-green body, two eye stalks of slightly different length, timid sweet face, unusual eye shape. Four expressions in a row: happy, singing with round open mouth, sleepy with closed eyes, thirsty and droopy with tired half-closed eyes. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, side-front view, no text, no 3D, no photorealism
```

## 4 – Käfer (Türkis)
```
Character model sheet of a cute round singing beetle, turquoise (#4cc3b5) shiny round body like a jelly bean, two antennae with little yellow balls, tiny legs, big friendly face, unusual eye shape. Four expressions in a row: happy, singing with round open mouth, sleepy with closed eyes, thirsty and droopy with tired half-closed eyes. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, front view, no text, no 3D, no photorealism
```

## 5 – Vogel (Himmelblau)
```
Character model sheet of a cute round singing bird, sky blue (#6fa8e8) egg-shaped body, cream belly, small orange beak, a funny feather tuft on the head, tiny wing, unusual eye shape. Four expressions in a row: happy, singing with open beak, sleepy with closed eyes, thirsty and droopy with tired half-closed eyes. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, front view, no text, no 3D, no photorealism
```

## 6 – Frosch (Blattgrün)
```
Character model sheet of a cute cheeky singing frog, leaf green (#7cc86a), wide squat body, big bulging eyes on top of the head, very wide smile, light green belly, unusual eye shape. Four expressions in a row: happy, singing with big open mouth, sleepy with closed eyes, thirsty and droopy with tired half-closed eyes. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, front view, no text, no 3D, no photorealism
```

## 7 – Gänseblümchen (Rosa)
```
Character model sheet of a cute singing daisy flower, pink (#ff8fb8) uneven petals around a yellow round face, thin green stem with two leaves like arms, unusual eye shape. Four expressions in a row: happy, singing with round open mouth, sleepy with closed eyes, thirsty and wilted droopy with tired half-closed eyes and drooping petals. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, front view, no text, no 3D, no photorealism
```

## 8 – Glockenblume (Violett)
```
Character model sheet of a cute singing bellflower, violet (#b58cf0) bell-shaped flower head hanging slightly, wavy petal rim like a little skirt, face inside the bell, curved green stem, unusual eye shape. Four expressions in a row: happy, singing with round open mouth, sleepy with closed eyes, thirsty and wilted droopy with tired half-closed eyes. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, front view, no text, no 3D, no photorealism
```

## 9 – Sonnenblume (Senfgelb)
```
Character model sheet of a cute tall singing sunflower, mustard-yellow (#ffc93c) pointed petals, big brown seed face with freckle dots, tall green stem with two big leaves, unusual eye shape. Four expressions in a row: happy, singing with round open mouth, sleepy with closed eyes, thirsty and wilted droopy with tired half-closed eyes and hanging head. Children's picture book character model sheet, flat gouache painting, thick slightly wobbly dark plum outline, simple bold shapes, soft paper texture, warm pastel palette, plain cream background, front view, no text, no 3D, no photorealism
```

---

**Tipps**
- Wenn die Figuren zu detailreich werden, hänge an den Prompt an: `very simple, minimal details, toddler-friendly`.
- Wenn das Bildmodell Text ins Bild schreibt, hänge `no letters, no labels` an.
- Lieber 3–4 Varianten pro Figur erzeugen und die beste behalten. Ich brauche nur ein gutes Bild pro Figur.
