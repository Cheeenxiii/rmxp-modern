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

Rebuilt v19+ games need no migration; the v21.1 kit and Reborn were checked
to boot on mkxp-z.

## Nintendo Switch

Tested under the Eden emulator (Vulkan/lavapipe), not on hardware. Frame rates
under the emulator say nothing about the console.

- Essentials v21.1 kit, original and rebuilt: title screen, menu, starting map.
- Reborn: title screen and main menu, 40 fps under the emulator.
- Uranium (warmwinter's mkxp-z port): language selection.

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

Reborn also needs `Input::E/F/D` and `Controller.axes_trigger`, which come from
a compatibility shim installed with the game rather than from the engine.

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
