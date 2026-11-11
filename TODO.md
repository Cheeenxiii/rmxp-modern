# TODO

## Switch

- Validate on hardware: Uranium intro animates to the title with no
  `errorlog.txt` (WeakRef/BitmapCache fix, verified under Eden).
- Validate on hardware: libnx swkbd text input (patch 0018) sends text +
  Return; cancelled sends Escape, nothing typed. A-reopen is game-dependent.
- Validate on hardware: Switch face-button A/B/X/Y mapping and the repeated
  `Graphics.resize_screen` fix.
- Games without a `.sf2` soundfont (Uranium) keep their MIDI silent.
- Screen readers (Tolk/NVDA) are not implemented.
- Ruby finalizers are delayed on Switch because no timer thread can be created
  (libnx has no pipe); only `GC.start(full_mark:, immediate_sweep:)` flushes
  them. Fix the Ruby timer/wakeup in the port if it can be done safely; the
  weakref shim stays as the safety net.

## Performance

- EliteBattle System (plugin, widespread in v16/v17 games): optimise its
  per-frame battle UI generically, conditioned on the plugin being present.
  A prototype is on branch wip-elitebattle (unmeasured); finish, measure PC
  gain, estimate Switch, verify pixels and oracle.
- Frame pacing: measure frame-time distribution and hitches (PC + console
  probe), evaluate map resource preloading, and prototype 60 Hz rendering
  interpolation at 40 logic updates/s with a before/after video.
- Rendered-text cache is a secondary lever (~2 ms on text-heavy screens).
- Kit map 66 profiling is unfinished.

## Robustness

- Rerun the endurance suite from tmp/endurance/common (first pass failed: fix
  the save-file lookup and the Reborn stall heuristic).
- The v17.2 kit's own Input layer ignores the gamepad bridge; finish its
  validation.

## Console session

- Rebuild the Uranium and Reborn .nro with the intro and keyboard fixes, then
  prepare a one-hour checklist: Uranium intro to title, A/B, naming in both
  games, a short play with one battle, plus the regularity probe if ready.

## Packaging

- Windows package needs a test on Windows.
- Android, Web and Switch packages are not written. Android estimate:
  30-45 h from the existing Android mkxp-z ports.

## Known gaps

- In the Eden emulator the "Installing ..." screen stays on top after the
  copy; on the console the install screen works and the game starts normally
  (emulator limitation, no port fix planned).
- Reborn's native Discord extension stays disabled.
- `Array#sample(n)` may differ from CRuby above n = 10.
- H-Mode7 maps lose the heightmap/3D effect.
