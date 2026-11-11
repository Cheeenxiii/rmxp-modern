# TODO

## Formats

- Decode the custom binary `.dat` files of Essentials v16/v17 (`items.dat`,
  `moves.dat`, `dexdata.dat`, ...), Reborn's `mons.dat` and the `Table` blobs.
  They are `opaque` today: the round trip is exact, but they are not text.
- Pokémon SDK: VD formats and `Scripts.dat`/YARB; scope still to be decided.

## Switch

- Uranium's intro is a fixed ~2 minute sequence (it leaves the sky at ~115 s and
  accepts input at ~122 s); the second-session log covered 110 s, so it was not
  a hang. The libnx `pipe creation failed` timer warning is real but does not
  block Ruby threads. Ask the next session to watch 150-200 s and fetch
  errorlog.txt if it still looks stuck.
- Text input: Return is now synthesized after the Switch keyboard returns a
  string (patch 0017); still to check on hardware that cancelling types
  nothing, A reopens the keyboard and B sends Escape.
- Uranium's language screen flickered on the console; the repeated
  `Graphics.resize_screen` calls are now ignored when the surface is already
  the requested size. Confirm on hardware.
- Third console session: kit/Reborn/Uranium/Insurgence .nro, a 10-minute
  playthrough each, and before/after measurements where the performance lever
  applies. The install marker now fingerprints preloads too, so rebuilt .nro
  reinstall their shims (old test installs kept stale preloads).
- A/B and X/Y are mapped to the Switch labels on Switch in the XInput shim;
  confirm on hardware (second session reported B validating instead of A).
- Games without a `.sf2` soundfont (Uranium) keep their MIDI silent on the
  Switch: decide whether to ship a fallback soundfont.
- Screen readers (Tolk/NVDA) are not implemented; the other Win32API losses
  are listed in docs/compatibility.md.

## Performance

- Uranium/Insurgence main cost is game-side, not generic: the battle scene's
  per-frame UI work is 6.4 ms of Ruby on PC (EliteBattle_UI scene update,
  ~446 Bitmap#blt per frame) and roughly 20-30 ms on the console; overworld
  update is 2-3 ms. That lever requires game-specific work, so it is not
  implemented.
- A rendered-text cache (compat preload prototype in tmp/perf-uranium) halves
  the text-heavy screens (language 3.9 -> 2.0 ms Ruby, pause menu 3.2 -> 1.6,
  bag 4.2 -> 3.0) with pixel-identical output; no gain in battle/overworld.
  Secondary lever only, not shipped.
- GC is 0.6-0.7% of CPU: allocation reduction is not the lever.
- Kit map 66 profiling was not finished (timebox); the harness is in
  tmp/perf-uranium and can be pointed at the kit.
- Console reference: kit maps 58-60 fps (map 66 ~48), Reborn map 51 40 fps,
  Uranium language screen CPU-bound (~14 fps), title/intro 40 fps. `avg`
  includes waiting; the console Ruby has no CPU clock (`cpu=na`), so the PC to
  Switch factor stays an order of magnitude.

## Native compilation

- Spinel is paused (CRuby + transformations); hybrid modules are not started.
  Revisit if the console measurements demand it.

## Packaging

- Windows package is experimental: needs a test on a Windows machine.
- Android, Web and Switch packages are not written.

## Known gaps

- Reborn's native Discord extension (`gems/discord.so`) cannot load against
  our Ruby; it is disabled by the game-side shim. Rebuild it if wanted.
- The Essentials v17.2 kit does not see the virtual pad through its own Input
  layer (it polls Win32 keyboard state; the engine pad is present but its bridge
  is not consulted). Everything else passes; find the generic bridge.
- The endurance tests did not produce a consolidated report: the first pass ran
  the kit/insurgence/reborn drivers (logs in tmp/endurance, one save-file
  FileNotFoundError, stall heuristic false positives) before the run failed.
  Rerun them from tmp/endurance/common.
- `Array#sample(n)` matches CRuby for n <= 10; above that it may differ.
- H-Mode7 maps render as normal maps (heightmap/3D effect lost, not planned).
