# Setup

`bin/rmxp` itself only needs Ruby 3.3 or later. This page is for running
games: building mkxp-z for the desktop or for the Nintendo Switch.

## Fetching mkxp-z

mkxp-z is a git submodule in `vendor/mkxp-z`, pinned to the commit of
[mkxp-z/mkxp-z](https://github.com/mkxp-z/mkxp-z) (branch `dev`) that our
patches apply to.

```bash
script/setup
```

`script/setup` fetches the submodule, applies the desktop and Switch patches
from [`patches/`](../patches/) and copies the Switch preload scripts to
`vendor/mkxp-z/switch/romfs-root/`. The Switch changes only take effect in a
Switch build. Running it again on a patched checkout does nothing. To start
over:

```bash
git -C vendor/mkxp-z reset --hard
```

## Desktop (Linux)

mkxp-z builds with Meson and downloads most of its dependencies itself. On
Debian or Ubuntu:

```bash
sudo apt install bison cmake gcc g++ git make ninja-build python3-pip ruby
pip3 install meson    # the distribution's Meson is often too old
```

Then:

```bash
cd vendor/mkxp-z
meson setup build
ninja -C build
```

`bin/rmxp package` also offers Windows folders; it needs a Windows mkxp-z,
which `script/fetch-mkxp-z windows` downloads (a pinned mkxp-z Actions
artifact, sha256-checked, in `vendor/mkxp-z-windows/`). See
[usage.md](usage.md#package).

`test/headless_test.rb` looks for the binary at
`vendor/mkxp-z/build/mkxp-z.x86_64`; set `MKXP_BIN` if yours is elsewhere. It
also needs `xvfb-run` (package `xvfb`).

For other platforms, see mkxp-z's own documentation and CI
(`vendor/mkxp-z/.github/workflows/autobuild.yml`).

## Nintendo Switch

The same patched `vendor/mkxp-z` builds for the Switch with devkitPro's
devkitA64 toolchain and libnx. The simplest way is devkitPro's Docker image,
which is also what CI uses (`.github/workflows/switch.yml`, which uploads the
`.nro` as an artifact):

```bash
# from the root of this repository, after script/setup
docker run --rm -it -v "$PWD":/src -w /src/vendor/mkxp-z devkitpro/devkita64:20251117 bash
apt-get update && apt-get install -y bison git ruby python3-pip
pip3 install --break-system-packages meson
meson setup --cross-file switch/switch.ini --buildtype release build
ninja -C build
```

This produces `vendor/mkxp-z/build/switch/nro/mkxp-z.nro`.

The `.nro` looks for the game folder in this order:

1. a game inside the `.nro`'s RomFS, as built by `script/switch-build` below;
2. the folder given as its first argument (a forwarder can pass one);
3. the folder the `.nro` is in (the Homebrew Menu starts homebrew there);
4. the fixed folder `sdmc:/switch/mkxp-z/game/`.

To play a game from the Homebrew Menu:

1. Migrate it if it predates Essentials v19 (`bin/rmxp migrate`).
2. Copy the game folder to the SD card, for example `/switch/<name>/`, and
   `mkxp-z.nro` into that folder, or build the game into the `.nro` (below).
3. Start the Homebrew Menu by holding R while launching a title, not from the
   Album, which gives homebrew too little memory.

### Standalone `.nro` (game inside the RomFS)

`script/switch-build` puts a game inside the `.nro`'s RomFS, so one file is
enough to play. The game's `Title` from `Game.ini` becomes the application
name, and the game's title picture becomes the icon:

```bash
bin/rmxp migrate path/to/game out/game     # pre-v19 games only
script/switch-build out/game               # -> tmp/switch-build/<name>.nro
script/switch-build out/game Uranium.nro --name "Pokémon Uranium" --icon cover.png
```

The RomFS is read-only, so the first launch copies the game once to
`sdmc:/switch/mkxp-z/<name>/` and runs it from there; a rebuild of the `.nro`
reinstalls the game when its `Game.ini` or `Scripts.rxdata` changes. The
engines' log is written in that installed folder (or `sdmc:/switch/mkxp-z/`
when the game runs from the RomFS). A large game makes a large `.nro` (the
whole game is embedded), which may exceed what the Homebrew Menu can load; a
small kit is the safe case.

The script needs `script/setup` to have run once, and either devkitPro in the
environment or Docker with the `devkitpro/devkita64:20251117` image.

Game-side preloads travel with the game: if a game needs one (Reborn's
`Input::E/F/D` shim, for instance), put it in the game's `preload/` folder and
list it in the game's `mkxp.json` before running `script/switch-build`.

Controls go through mkxp-z's usual bindings, following the Nintendo labels:
A confirms and B cancels. ZL, ZR and minus are bound to F5, F6 and F7, which
some games read as `Input::E`, `F` and `D`. MIDI music is skipped, and HTTP
requests return nothing.

Each launch writes the engine's and the game's output to `mkxp-z.log` in the
game folder (or on the SD card when the game runs from a read-only RomFS),
replacing the previous log. When a game crashes, look there first.

The Switch support is based on
[GQster's mkxp-z Switch port](https://github.com/GQster/mkxp-zSwitchPort).
It has not been tested on hardware; see
[compatibility.md](compatibility.md#nintendo-switch) for what was tested under
the Eden emulator with that port.

## Spinel

Only the battle harness experiments in `test/battle/` use Spinel. It is not a
submodule: build it in `vendor/spinel/` if you want to run them (see
[development.md](development.md#battle-harness)).

## Encrypted games

Games shipped as `Game.rgssad` must be extracted first, for example with
[RPGMakerDecrypter](https://github.com/uuksu/RPGMakerDecrypter).
