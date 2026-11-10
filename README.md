# rmxp-modern

Tools to turn RPG Maker XP Pokémon fangames into plain-text projects, and to
get them running on modern Ruby and new platforms.

> **Status: experimental.** The project format, the commands and their output
> will change without notice. Nothing here is meant for players yet.

## Why

Most Pokémon fangames are built on RPG Maker XP, usually with Pokémon
Essentials. Their data lives in Ruby Marshal dumps (`Data/*.rxdata`) and their
code in a single compressed `Scripts.rxdata`. You can't diff them, review them
or merge them, and the engine they target runs Ruby 1.8 on Windows.

rmxp-modern extracts all of it into YAML and `.rb` files that work with git,
rebuilds the exact same binary files from that text, and patches old games so
they run on [mkxp-z](https://github.com/mkxp-z/mkxp-z) with Ruby 3. The longer
term goal is to compile games to native code.

## What works

- **Round trip**: `unpack` then `build` gives back the original data, byte for
  byte in most cases. Tested on the Essentials kits v16.2 to v21.1, Pokémon
  Uranium, Pokémon Insurgence and Pokémon Reborn.
- **Static checks**: every script and every event script fragment is parsed
  with Prism, and dynamic Ruby (`eval`, computed `send`, ...) is inventoried.
- **Migration of pre-v19 games** to Ruby 3: Uranium and Insurgence reach their
  first map on mkxp-z without game-specific fixes.
- **Nintendo Switch**: the Essentials v21.1 kit and Reborn boot to their menus
  under an emulator, using the patches in [`patches/`](patches/).

Not supported: encrypted archives (`Game.rgssad`, decrypt them first with
another tool), Pokémon SDK, and the custom binary `.dat` files of Essentials
before v19 (copied as is).

## Usage

You need Ruby 3.3 or later. There are no gems to install.

```bash
git clone https://github.com/Cheeenxiii/rmxp-modern.git
cd rmxp-modern
bin/rmxp unpack path/to/game project/
```

This gives:

```
project/
  manifest.yml          files, formats and options
  data/                 one YAML file per Data/ file
  scripts/              one .rb file per script section
  scripts.yml           script order, ids and names
```

with data files like `data/Actors.rxdata.yaml`:

```yaml
- __class__: RPG::Actor
  __ivars__:
    "@id": 1
    "@name":
      __str__: Red
      __enc__: ASCII-8BIT
    "@class_id": 1
    "@initial_level": 5
    "@final_level": 100
```

Edit, commit, then rebuild the binary files:

```bash
bin/rmxp build project/ rebuilt_game/
```

Other commands: `roundtrip` (unpack, build and compare with the original),
`check`, `audit` and `migrate`. See [docs/usage.md](docs/usage.md) for details
and [docs/compatibility.md](docs/compatibility.md) for per-game results.

To run games, you need a patched mkxp-z, for the desktop or the Switch:
[docs/setup.md](docs/setup.md) explains how to build it.

## License

The tool is licensed under the [GNU GPL v3 or later](LICENSE).

Code that `rmxp` copies into the games it converts is under permissive
licenses, so a converted game does not inherit any GPL obligation:
the compatibility shims in `lib/rmxp/preload/compat/` and the RNG
(`lib/rmxp/mt19937.rb`, `lib/rmxp/preload/deterministic_random.rb`) are MIT or
CC0. The patches to mkxp-z follow mkxp-z's license (GPL-2.0-or-later), see
[patches/README.md](patches/README.md). Every file states its license in an
[SPDX](https://spdx.dev/) header; full texts are in [LICENSES/](LICENSES/).

This project is not affiliated with Nintendo, Game Freak, The Pokémon Company
or the makers of RPG Maker. It contains no game data. Game data and scripts
that `rmxp` extracts, converts or rebuilds remain the property of the game's
authors.
