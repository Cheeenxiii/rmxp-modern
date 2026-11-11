# TODO

## Formats

- Decode the custom binary `.dat` files of Essentials v16/v17 (`items.dat`,
  `moves.dat`, `dexdata.dat`, ...), Reborn's `mons.dat` and the `Table` blobs.
  They are `opaque` today: the round trip is exact, but they are not text.
- Pokémon SDK: VD formats and `Scripts.dat`/YARB; scope still to be decided.

## Switch

- Second console session: A/B, naming, battles and saves on hardware, with the
  fps per scene (language screen is CPU-bound, title should be 40 fps).
- The libnx "Installing ..." screen sometimes leaves the display on the console
  after the copy while the engine runs (seen under Eden): confirm on hardware
  and restore the display or use an SDL progress window.
- Confirm the PC to Switch factor with the session's fps; the console Ruby has
  no CPU clock (`cpu=na`), so it stays an order of magnitude.
- Games without a `.sf2` soundfont (Uranium) keep their MIDI silent on the
  Switch: decide whether to ship a fallback soundfont.
- Screen readers (Tolk/NVDA) are not implemented; the other Win32API losses
  are listed in docs/compatibility.md.

## Performance

- Generic text/`AnimatedBitmap` cache (milestone 7): Uranium's language screen
  spends ~4-5 ms on PC and ~70 ms on the console per frame (4 text shadow
  passes, 7 fresh AnimatedBitmaps). Validate on kit and Reborn before/after.
- Candidate: avoid `map.data` per tile. Engine-side "bitmap changed" flag for
  the anti-redraw idea (prototype rejected for now, in tmp/antiredraw).

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
