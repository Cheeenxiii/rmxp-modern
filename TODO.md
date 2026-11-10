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

- Reborn boots on the desktop and under the Switch emulator (Eden). With our
  own mkxp-z it needs the game-side `Input::E/F/D` shim; its updater needs
  `net/http` and openssl, so it fails without blocking.
- The Uranium port (warmwinter) has no assets in its repository: they must be
  copied from the original release, and the port expects a `Patches/`
  directory. Automate this if Uranium builds need it.
- Deep validation (menus, a full battle, save and reload) is done for Uranium
  and Insurgence; it is still to do for Reborn and the v21.1 kit.

## Switch

- The minimal port branch (`switch-minimal-port`, pushed) now finds the game in
  the `.nro`'s RomFS, then in the first argument, then in the `.nro`'s folder,
  then in `sdmc:/switch/mkxp-z/game/`. `script/switch-build` builds a standalone
  `.nro` with the game inside the RomFS and the game's name and icon; the first
  launch installs the game to the SD card because the RomFS is read-only.
- Standalone `.nro` builds of the kit, Reborn (with its game-side input shim)
  and Uranium reach their title/language screen under Eden. Remaining: A/B,
  naming and gameplay (synthetic keys did not reach the emulator's controller
  layer in the harness), then the owner's hardware session and the
  PC-to-Switch calibration.
- Unsupported Win32API functions return 0. The visible losses are listed in
  [docs/compatibility.md](docs/compatibility.md): Insurgence's H-Mode7 maps,
  screen readers and window geometry calls; window resizing is translated to
  `Graphics.resize_screen`.
- Reborn still needs its game-side `preload/input_ext.rb` for `Input::E/F/D`
  (the engine binds ZL, ZR and minus to F5/F6/F7 but does not define the Ruby
  constants). `Input::Controller.axes_trigger` comes from mkxp-z itself.

## Native compilation

- Spinel is paused: the plan is CRuby plus transformations. The battle harness
  and the hybrid extension experiments stay in the tree, but compiling the
  whole game with Spinel is not pursued.
- Transformations that pay off: remove redundant menu redraws, cache rendered
  text, native tilemap, replace event `eval`s with generated methods, flatten
  alias chains.
- Known Spinel limits (refused constructs, invalid C with `--defer-refusals`)
  are in the commit history; revisit if a future release changes the picture.

## Performance

- On a real map: 3.66 ms per frame, 1.91 ms with the `System.power_state` cache
  that `migrate` installs.
- Candidate transformations: avoid `map.data` per tile, avoid redrawing
  unchanged content, cache text.
- Uranium's language menu redraws everything every frame (diagnosed, no fix
  decided).

## Packaging

- `bin/rmxp package` builds ready-to-play Linux and Windows folders with
  mkxp-z included. Linux was tested with Uranium; the Windows binary is a
  pinned mkxp-z Actions artifact (`script/fetch-mkxp-z windows`) and still
  needs a test on a Windows machine. Android, Web and Switch packages are not
  written yet.

## Known gaps

- The `Array#sample(n)` shim matches CRuby for n <= 10. Above that it falls
  back to a partial Fisher-Yates that may differ from CRuby. No known use in
  the games we target.
- `MGC_Hmode7` (Insurgence) has no non-Windows implementation and no fallback:
  its 7 maps (intro 689, world map 676, ...) draw their tilemap only through the
  DLL, so they show only a panorama and are not playable. The intro and the
  map transfers still run, and Soar's logic works, but nothing is visible.
  Minimal fix: force `$game_system.hm7 = false` after `Game_Map#setup` (or build
  the normal `Tilemap` when the DLL is absent) in the migration/compat shim.
  A real mode-7 is 1-2 weeks; nothing is implemented.
- Screen readers (Tolk/NVDA) are not implemented; see docs/compatibility.md.
- Uranium draws at 512x384 in a 640x480 window (black bands); the reference
  port upscales the picture. A compat preload could set the surface to the
  game size and pin the window at 640x480 (resize_window after the game's
  resize), matching the reference within a pixel.
