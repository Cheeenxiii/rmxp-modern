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

The `.nro` runs the game whose folder is given as its first argument, as a
forwarder does, or else the game in the folder the `.nro` is in. To play a
game from the Homebrew Menu:

1. Migrate it if it predates Essentials v19 (`bin/rmxp migrate`).
2. Copy the game folder to the SD card, for example `/switch/<name>/`, and
   `mkxp-z.nro` into that folder.
3. Start the Homebrew Menu by holding R while launching a title, not from the
   Album, which gives homebrew too little memory.

Controls go through mkxp-z's usual bindings. ZL, ZR and minus are bound to
F5, F6 and F7, which some games read as `Input::E`, `F` and `D`. MIDI music is
skipped, and HTTP requests return nothing.

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
