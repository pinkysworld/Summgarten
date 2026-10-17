@tool
class_name MinhIntroTheme
extends Resource
## Look, timing and sound of the Minh Nguyen Studios intro (MinhStudioIntro). Self-contained: no game code.
## Presets: presets/neutral_hell.tres, presets/neutral_dunkel.tres, presets/germ_theory.tres.

@export_group("Colours")
## Background (flat, or the base tone of the paper shader).
@export var background := Color("f4f2ed")
## Wordmark "minh" / "studios" and the sub line.
@export var ink := Color("17211f")
## Sub line "MINH NGUYEN STUDIOS" (slightly softer than the wordmark).
@export var sub_ink := Color("78817e")
## The dot between "minh" and "studios" and the resting segment of the loop.
@export var accent := Color("b98746")
## Round sign: disc, loop on the disc.
@export var sign_fill := Color("193f37")
@export var sign_loop := Color("f4f2ed")
## Loader segment while it runs one round: tail colour -> head colour.
@export var segment_from := Color("193f37")
@export var segment_to := Color("b98746")
## Typing caret.
@export var caret := Color("b98746")

@export_group("Surface")
## Laid paper (grain, mottling, chain lines, vignette) instead of a flat background.
@export var paper := false
@export var paper_edge := Color("c7b89c")
## Optional texture over the whole screen (stretched, drawn under the logo).
@export var background_texture: Texture2D
## Ink "tooth": the marks print slightly broken like ink on rough paper (0 = clean vector).
@export_range(0.0, 1.0) var ink_tooth := 0.0
## Double frame rule around the page (engraving look).
@export var frame := false
@export var frame_color := Color("3a2818")

@export_group("Type")
## Wordmark face (default Inter Display SemiBold, OFL).
@export var wordmark_font: Font
## Sub line face (default Inter SemiBold, OFL).
@export var sub_font: Font
## Caption face (default: sub_font). Hosts with non-Latin captions pass a font that has the glyphs.
@export var caption_font: Font
## Optional small line under the logo (e.g. "presents"); "" = none. Set by the host game per language.
@export var presents_text := ""

@export_group("Timing")
## Length of the full animation including the fade-out (seconds, 2.5 - 3.5; the timeline scales).
@export_range(2.0, 4.0, 0.05) var duration := 2.95
## Short version (e.g. from the second start on): static logo, fade in / hold / out.
@export_range(0.6, 2.0, 0.05) var short_duration := 1.3
## Full version: extra seconds the complete wordmark stays fully visible before the fade-out (Kontor: 2.2).
@export_range(0.0, 4.0, 0.05) var hold := 0.0

@export_group("Sound")
@export var sound := true
## Key strokes (played at "minh", "systems", "tudios"); cycled when fewer than three.
@export var key_sounds: Array[AudioStream] = []
## Warm close when the sub line appears.
@export var close_sound: AudioStream
@export var audio_bus := &"Master"
@export_range(-40.0, 6.0) var key_volume_db := -15.0
@export_range(-40.0, 6.0) var close_volume_db := -9.0
## Caption for the sound (shown only when the host passes captions = true); "" = none.
@export var caption_text := "[soft key strokes, a warm tone]"
