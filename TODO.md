# TODO

## Formats

- Decode the custom binary `.dat` files of Essentials v16/v17 (`items.dat`,
  `moves.dat`, `dexdata.dat`, ...), Reborn's `mons.dat` and the `Table` blobs.
  They are `opaque` today: the round trip is exact, but they are not text.
- Pokémon SDK: VD formats and `Scripts.dat`/YARB; scope still to be decided.

## Switch

- Uranium's intro hangs on the console (Scene_Intro steady at 40 fps, waiting
  forever) while it passes on PC: Ruby thread scheduling under libnx is the
  main suspect; fix the port's Ruby timer threads.
- Text input: Return is now synthesized after the Switch keyboard returns a
  string (patch 0017); still to check on hardware that cancelling types
  nothing, A reopens the keyboard and B sends Escape.
- Uranium's language screen flickered on the console; the repeated
  `Graphics.resize_screen` calls are now ignored when the surface is already
  the requested size. Confirm on hardware.
- Third console session: kit/Reborn/Uranium/Insurgence .nro, a 10-minute
  playthrough each, and before/after measurements where the performance lever
  applies.
- A/B and X/Y are mapped to the Switch labels on Switch in the XInput shim;
  confirm on hardware (second session reported B validating instead of A).
- Games without a `.sf2` soundfont (Uranium) keep their MIDI silent on the
  Switch: decide whether to ship a fallback soundfont.
- Screen readers (Tolk/NVDA) are not implemented; the other Win32API losses
  are listed in docs/compatibility.md.

## Performance

- Uranium/Insurgence main lever to find and quantify (text cache, bitmap
  recreation, per-tile map access, GC): rank levers by measured gain, cost and
  risk before implementing.
- Kit map 66 drops to ~48 fps on console while other maps hold 58-60: profile
  it and apply the same lever if it fits.
- Console reference so far: kit maps 58-60 fps (map 66 ~48), Reborn map 51
  40 fps, Uranium language screen CPU-bound (~14 fps), title/intro 40 fps.
  The PC to Switch factor stays an order of magnitude because the console Ruby
  has no CPU clock.

## Native compilation

- Spinel is paused (CRuby + transformations); hybrid modules are not started.
  Revisit if the console measurements demand it.

## Packaging

- Windows package is experimental: needs a test on a Windows machine.
- Android, Web and Switch packages are not written.

## Known gaps

- Reborn's native Discord extension (`gems/discord.so`) cannot load against
  our Ruby; it is disabled by the game-side shim. Rebuild it if wanted.
- `Array#sample(n)` matches CRuby for n <= 10; above that it may differ.
- H-Mode7 maps render as normal maps (heightmap/3D effect lost, not planned).
