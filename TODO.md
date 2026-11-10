# TODO

## Formats

- Decode the binary `.dat` files of Essentials before v19 (`items.dat`,
  `moves.dat`, `evolutions.dat`, `dexdata.dat`, `eggEmerald.dat`,
  `regionals.dat`, `attacksRS.dat`, `rsattacks.dat`, `tutor.dat`, `tmpbs.dat`,
  `BackupSave.dat`). They are copied as `opaque` today: the round trip is
  exact, but they aren't text.
- Reborn's `Data/mons.dat`: Marshal with internal classes that aren't resolved
  (`MonDataHash`, `MonWrapper`, `MonData`), so it's `opaque`.
- `Table`, `Color`, `Tone` and `Rect` are kept as Marshal blobs. Decode `Table`
  at least, so maps are readable as text.
- Pokémon SDK: VD formats and `Scripts.dat`/YARB. Scope to be decided.

## Running games

- Reborn under Xvfb takes longer to boot than the time limit (large data, or
  something Reborn-specific). Retry with a real display; the v21.1 kit boots.
- Our mkxp-z build has no Ruby `openssl` extension, so Reborn's updater
  (`net/http`) fails with it. Use the mkxp-z that ships with Reborn, or fix the
  Ruby build.
- The Uranium port (warmwinter) has no assets in its repository: they must be
  copied from the original release, and the port expects a `Patches/`
  directory. Automate this if Uranium builds need it.

## Native compilation

- The battle harness works in plain CRuby, and the literal battle data matches
  the Marshal data. 1000 battles take 31.4 s (reduced data).
- Spinel refuses 94 constructs in the core, 371 at 50% of the engine, and fails
  to generate code at 100% (`@color` is typed differently in `CommandMenu` and
  `MenuBase`). With `--defer-refusals` the generated C doesn't compile (type
  errors). No Spinel binary yet.
- Decision pending between native, hybrid and a fallback plan. Current leaning:
  the fallback plan for now, Spinel only for purely numeric subsystems.
- Treat alias chains on `Graphics.update` (5 to 16 per game) as plain aliases,
  and event `eval`s as generated methods.

## Performance

- v21.1 kit on a map: about 7.4 ms of logic and 1.2 ms of rendering per frame
  (PC, llvmpipe). Dominated by `TilemapRenderer#update`, `pbBatteryLow?` (a
  native `System.power_state` call every frame; `migrate` now installs a cache
  for it) and `Game_Map#data`. GC: 59 collections, 327 ms over 4 s. In battle:
  about 0.07 ms of logic and 1.1 ms of rendering.
- Candidate transformations: avoid `map.data` per tile, avoid redrawing
  unchanged content.
- Uranium's language menu redraws everything every frame (`pbDrawShadowText`,
  `BitmapWrapper#initialize`, bitmap cache, path `canonicalize`). Diagnosed, no
  fix decided.

## Known gaps

- The `Array#sample(n)` shim matches CRuby for n <= 10. Above that it falls
  back to a partial Fisher-Yates that may differ from CRuby. No known use in
  the games we target.
