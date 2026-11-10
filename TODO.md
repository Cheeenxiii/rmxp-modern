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
  own mkxp-z it needs the game-side input shim (`Input::E/F/D`,
  `Controller.axes_trigger`); its updater needs `net/http` and openssl, so it
  fails without blocking.
- The Uranium port (warmwinter) has no assets in its repository: they must be
  copied from the original release, and the port expects a `Patches/`
  directory. Automate this if Uranium builds need it.
- Deep validation (menus, a full battle, save and reload) is done for Uranium
  and Insurgence; it is still to do for Reborn and the v21.1 kit.

## Switch

- Merge the minimal port (patches on stock mkxp-z, CI builds the `.nro`) after
  the owner's test. Hardware test and PC-to-Switch calibration are still to do.
- The `.nro` needs to know the game folder: it uses the first argument or the
  working directory. Eden starts homebrew in the SD root with neither, so a
  direct launch under Eden exits before loading a game. Test with a forwarder,
  or add a fallback (for example a game folder file next to the `.nro`).
- Once the folder is known, the v21.1 kit reaches its title screen under Eden
  and writes `mkxp-z.log`. A/B, naming and gameplay still need one interactive
  test (the emulator harness used here could not inject keys into the game).
- Unsupported Win32API functions return 0. The visible losses are listed in
  [docs/compatibility.md](docs/compatibility.md): Uranium's GIF cutscenes,
  Insurgence's H-Mode7 maps, screen readers and window resizing.
- `Input::Controller.axes_trigger` (Reborn) returns zero, so trigger-based
  turbo is off; the ZL, ZR and minus bindings still reach the games as E, F
  and D.
- Reborn still needs its game-side `preload/input_ext.rb`: the engine patch
  only binds ZL, ZR and minus to F5, F6 and F7, it does not define the Ruby
  constants the game reads.

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

## Known gaps

- The `Array#sample(n)` shim matches CRuby for n <= 10. Above that it falls
  back to a partial Fisher-Yates that may differ from CRuby. No known use in
  the games we target.
- `gif.dll` (Uranium) and `MGC_Hmode7` (Insurgence) have no non-Windows
  implementation.
- Uranium's options screen is clipped: the game draws it at 640x480 while its
  surface is 512x384.
