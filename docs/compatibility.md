# Compatibility

## Round trip

`unpack` then `build`, compared with the original files. See
[usage.md](usage.md#roundtrip) for what the columns mean.

| Game | Based on | Files | Identical | Equivalent | Opaque | Scripts |
|---|---|---:|---:|---:|---:|---|
| Pokémon Uranium 1.4.1 | Essentials v16.2 | 327 | 315 | 12 | 10 | ok |
| Pokémon Insurgence 1.2.7.1 | Essentials v16.2 | 881 | 878 | 3 | 8 | ok |
| Pokémon Reborn 19.5 | Essentials v19.1/v20.1 | 931 | 930 | 1 | 1 | ok |
| Essentials kit v16.2 | | 110 | 107 | 3 | 8 | ok |
| Essentials kit v17.2 | | 111 | 108 | 3 | 8 | ok |
| Essentials kit v19.1 | | 105 | 104 | 1 | 0 | ok |
| Essentials kit v20.1 | | 107 | 105 | 2 | 0 | ok |
| Essentials kit v21.1 | | 109 | 109 | 0 | 0 | ok |

Uranium and Insurgence ship as RGSSAD archives and were extracted first.

### Opaque files

Essentials v16.2 and v17.2 store some data in a custom binary `.dat` format
(an offset table, not Marshal) that `rmxp` does not decode yet: `items.dat`,
`moves.dat`, `evolutions.dat`, `dexdata.dat`, `eggEmerald.dat`,
`regionals.dat`, `attacksRS.dat`, `rsattacks.dat`, `tutor.dat`, `tmpbs.dat` and
`BackupSave.dat`, depending on the game.

Reborn's `mons.dat` is Marshal, but it references internal classes
(`MonDataHash`, `MonWrapper`, `MonData`) that can't be loaded yet.

These files are copied byte for byte: the rebuilt game is correct, they are
just not readable as text.

## Migration to Ruby 3

Pre-v19 games after `bin/rmxp migrate`, on stock mkxp-z:

- **Uranium**: language selection, title screen, options, new game and first
  map.
- **Insurgence**: title screen, menu, new game, intro and first map, with no
  game-specific fix. On the first run of a fresh copy, Essentials v16 offers to
  install its fonts; this is cosmetic and goes away after a restart.

Both were also checked beyond the first map: pause menu, party, bag, Pokédex,
options, a complete wild battle and a save reloaded through the real Continue
menu. The reloaded state is the same as before saving, apart from the frame
counter and the save count.

Rebuilt v19+ games need no migration; the v21.1 kit and Reborn were checked
to boot on mkxp-z.

Known limitations of the compatibility shims:

- Windows-only native libraries are stubbed to 0: Insurgence's H-Mode7 maps
  (`MGC_Hmode7`), the Tolk/NVDA screen readers, and window geometry calls
  (cosmetic). Uranium's GIF cutscenes are converted to PNG frames at migration
  and no longer need `gif.dll`.
- Insurgence's H-Mode7 plugin calls a 32-bit Windows DLL with internal RGSS
  pointers, so it cannot work on mkxp-z: the 7 tagged maps render their normal
  tilemap instead of the heightmap view. The intro fly-over (`System` starts on
  map 214 and transfers to 689) and the world map (676) are among them.
- Screen readers (Tolk for NVDA/SAPI, and the NVDA controller DLL) are not
  implemented: the accessibility speech of Reborn and Insurgence is off.
- Registry reads fall back to their defaults (music and sound stay on, the
  suggested trainer name is random); saves go to the game folder when the
  Windows known-folder API is missing.
- Online features (GTS, trades, updates) need Windows sockets and are off.
- `Thread.critical` is a no-op: the games use it around audio and bitmap
  caches only, and no visible race was seen.
- The games' `Win32API.SetWindowPos` calls are translated to mkxp-z's
  `Graphics.resize_screen`, so the window and the drawing surface stay in
  sync. Uranium's options screen and menus are no longer clipped.
- A save written before the intro sets the player identity carries `metaID -1`
  and crashes the Continue screen. The game does this itself, not the
  migration; play through the intro (or use the debug mode) before saving.

## Nintendo Switch

Tested under the Eden emulator (Vulkan/lavapipe), not on hardware. Frame rates
under the emulator say nothing about the console.

- Essentials v21.1 kit: title screen with the minimal port built from
  `patches/mkxp-z-switch/`, if the game folder is passed to the `.nro`
  (see below).
- Reborn: title screen and main menu (tested with the earlier port).
- Uranium (warmwinter's mkxp-z port): language selection (tested with the
  earlier port).

The minimal port finds its game folder from the first argument or from the
current directory. The Eden emulator starts the homebrew in the SD root with
no arguments, so a direct launch exits before loading anything; use a forwarder
that passes the folder (or the hardware Homebrew Menu, which starts the `.nro`
from its own folder). Once the folder is known, the kit reaches its title
screen under Eden.

The Ruby in the Switch port does not ship the full standard library.
`timeout`, `weakref` and `delegate` are provided as preload scripts. RubyGems,
`net/http` and the Discord gem are replaced with stubs, so these features are
off:

- online updates and version checks (Reborn's updater shows a non-blocking
  `URI` error);
- GTS, trades and other online features;
- Discord Rich Presence;
- loading gems: scripts that call `gem` at startup keep going, but nothing is
  loaded.

Reborn also needs `Input::E/F/D`: mkxp-z does not define those constants,
and the port binds ZL, ZR and minus to the F5, F6 and F7 keys behind them.
`Input::Controller.axes_trigger` is provided by mkxp-z itself, so the analog
triggers keep working; only the constants come from a game-side shim.

## Dynamic Ruby

What `bin/rmxp audit` reports as `dynamic`, the constructs a native compiler
would have to support as is:

| Game | `eval` | computed `send` | `Marshal.dump` |
|---|---:|---:|---:|
| Uranium | 21 | 12 | 42 |
| Insurgence | 21 | 33 | 76 |
| Reborn | 85 | 23 | – |
| Essentials kit v21.1 | 9 | 5 | 25 |
| Pokémon SDK (code only) | – | 166 | – |

A dash means the count was not recorded. Most other uses (aliases, event
fragments, `Marshal.load`, ...) are `static`; run `bin/rmxp audit` for the
full breakdown. Insurgence also has 3 syntax errors in its original
scripts (old syntax, broken events). Pokémon SDK has 364 aliases and 196 ivar
accesses, all `static`.

## Not supported

- Pokémon SDK data (VD `.dat` files, YARB scripts).
- Encrypted archives (RGSSAD, RGSS2A, RGSS3A): extract them first.
