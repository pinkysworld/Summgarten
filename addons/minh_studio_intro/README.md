# Minh Studio Intro (Godot 4 addon)

Studio intro of **Minh Nguyen Studios** ("minh.studios"), about 3 s: the accent dot appears, "minh" types itself in
front of it, "minh.systems" is typed and corrected to "minh.studios" while the loop in the round sign runs one loader
round (segment gradient deep green -> bronze), then "MINH NGUYEN STUDIOS" fades in with closing tracking, then a fade.
Everything is drawn live as vectors (Inter fonts, antialiased polylines): sharp at 1280x800 and at 4K, in Forward+,
Mobile and Compatibility. No autoloads, no dependencies, Godot 4.3+ (made with 4.7).

## In a new project in 3 steps

1. Copy the folder `addons/minh_studio_intro/` into the new project's `addons/` (enabling the plugin is optional).
2. Pick or make a theme: `presets/neutral_hell.tres`, `presets/neutral_dunkel.tres`, `presets/germ_theory.tres`, or a
   copy of one (`MinhIntroTheme`: colours, paper / texture, ink tooth, frame, fonts, duration, sounds, bus, caption).
3. Play it from the first scene and continue when it ends:

```gdscript
func _ready() -> void:
    var intro := MinhStudioIntro.play(self, preload("res://addons/minh_studio_intro/presets/neutral_dunkel.tres"))
    await intro.finished
    # show the title / main menu
```

Or instance `minh_studio_intro.tscn` and set `theme`, `mode`, `show_caption` in the inspector.

## API

| | |
|---|---|
| `MinhStudioIntro.play(parent, theme = null, mode = Mode.FULL, caption = false)` | creates and starts it, returns the node |
| `mode` | `FULL` (animation), `SHORT` (static logo, ~1.3 s, e.g. from the second start), `STATIC` (reduced motion: static logo, fades only) |
| `show_caption` | shows `theme.caption_text` at the bottom while it runs (pass your game's captions switch) |
| signal `fade_started` | the fade-out begins: put the next screen underneath |
| signal `skipped` | the player skipped (any key, mouse button, touch or pad button) |
| signal `finished` | gone; the node frees itself |
| `skip()`, `seek(t)`, `length()`, `is_showing()` | skipping from code, screenshots / tests |

The addon never reads your settings. The host decides mode (first / later start, reduced motion), the caption
switch, the audio bus (`theme.audio_bus`, falls back to `Master` if missing) and the caption language
(`theme.caption_text`, `theme.presents_text`; duplicate the theme and set them at runtime).

## Demo

`demo/demo.tscn` plays the three presets in turn. Headless check in an empty project:

```
godot --headless --path <project> --import
godot --headless --path <project> res://addons/minh_studio_intro/demo/demo.tscn -- --preset=germ_theory --quit
```

prints `DEMO OK`. Arguments: `--preset=…`, `--mode=full|short|static`, `--caption`, `--quit`.

## Contents and licences

- `fonts/`: Inter 4.1 (Inter Display SemiBold, Inter SemiBold, Inter Medium), SIL OFL 1.1, `fonts/OFL_Inter.txt`.
- `audio/`: key strokes and the warm close, synthesised (no samples, no AI); see `PROVENANCE.md`.
- `brand/`: brand kit (logo variants as SVG + high-res PNG, sign, favicon, app icons) and `brand/BRAND.md`.
- Code, shaders, logo: © 2026 Minh Nguyen Studios.
