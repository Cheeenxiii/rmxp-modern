# TODO

## Switch

- Validate the WeakRef/BitmapCache fix on hardware: Uranium's intro must
  animate and reach the title, with no `errorlog.txt`.
- Text input through libnx swkbd: validated path (text + Enter), cancelled
  path (nothing typed, A reopens, B sends Escape).
- Confirm the Switch face-button A/B/X/Y mapping and the repeated
  `Graphics.resize_screen` fix on hardware.
- The libnx "Installing ..." screen can leave the display on the console after
  the copy: restore the display or use an SDL progress window.
- Games without a `.sf2` soundfont (Uranium) keep their MIDI silent.
- Screen readers (Tolk/NVDA) are not implemented.

## Performance

- Uranium/Insurgence: the per-frame battle UI work (EliteBattle plugin) is the
  main cost; no clean generic lever found yet. Rendered-text cache is a
  secondary lever (~2 ms on text-heavy screens).
- Kit map 66 profiling is unfinished.

## Robustness

- Rerun the endurance suite from tmp/endurance/common (first pass failed: fix
  the save-file lookup and the Reborn stall heuristic).
- The v17.2 kit's own Input layer ignores the gamepad bridge; finish its
  validation.

## Packaging

- Windows package needs a test on Windows.
- Android, Web and Switch packages are not written. Android estimate:
  30-45 h from the existing Android mkxp-z ports.

## Known gaps

- Reborn's native Discord extension stays disabled.
- `Array#sample(n)` may differ from CRuby above n = 10.
- H-Mode7 maps lose the heightmap/3D effect.
