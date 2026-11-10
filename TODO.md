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
  launch installs the game to the SD card because the RomFS is read-only, with
  an "Installing ..." progress screen and a version marker so later launches
  skip the copy. MIDI is rendered to OGG at build time, so the port is not
  silent on games that ship `.mid` music.
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
- Console probe (`script/switch-build --perf-probe`): `frames` is per 5 s
  window (fps = frames / 5), `avg` is wall time inside `Graphics.update` with
  the engine's waiting/vsync **included**, `cpu` is process CPU per frame (the
  work measure), `worst` is wall. Compare PC and Switch on `cpu`, never `avg`.
- PC to Switch factor: the first console session's `avg` (kit map 12-15 ms
  against PC 3.7 ms) suggested 3-4x, but `avg` includes waiting; confirm the
  factor with `cpu` from the second session and update this line.
- Candidate transformations: avoid `map.data` per tile, cache text.
- Anti-redraw: prototype measured (language screen 4.1 -> 0.5 ms of Ruby per
  frame, oracle intact) but rejected for now: too much code for two screens
  and the calibration does not need it. Idea noted for later: an engine-side
  "bitmap changed" flag.
- Uranium's 14 fps on the language screen is CPU-bound, not waiting: 4
  `draw_text` shadow passes per string and 7 fresh `AnimatedBitmap` objects per
  frame (PC 4-5 ms, console ~70 ms). It is a one-off setup screen; the title
  runs at 40 fps. The real fix is the generic text/AnimatedBitmap cache
  (milestone 7), validated on kit and Reborn, not a Switch timing hack.

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
- `MGC_Hmode7` (Insurgence): when the DLL is not loadable, `preload/mkxp_wrap.rb`
  swaps the plugin's renderer aliases back to the normal `Spriteset_Map` and
  keeps `$game_system.hm7` as the game set it, so the 7 HM7 maps (intro 689,
  world map 676, ...) and the Soar HUD/logic work with a normal `Tilemap`.
  Only the heightmap/3D effect is lost. A real mode-7 is 1-2 weeks if wanted.
- Screen readers (Tolk/NVDA) are not implemented; see docs/compatibility.md.
- Uranium draws at 512x384 in a 640x480 window (black bands); the reference
  port upscales the picture. A compat preload could set the surface to the
  game size and pin the window at 640x480 (resize_window after the game's
  resize), matching the reference within a pixel.
