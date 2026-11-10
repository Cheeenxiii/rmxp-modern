# Setup

`bin/rmxp` itself only needs Ruby 3.3 or later. This page is for running
games: building mkxp-z for the desktop or for the Nintendo Switch.

## Fetching mkxp-z

mkxp-z and its Switch port are git submodules in `vendor/`, pinned to the
commits our patches apply to:

| Submodule | Upstream |
|---|---|
| `vendor/mkxp-z` | [mkxp-z/mkxp-z](https://github.com/mkxp-z/mkxp-z), branch `dev` |
| `vendor/mkxp-z-switch` | [GQster/mkxp-zSwitchPort](https://github.com/GQster/mkxp-zSwitchPort), branch `switch-port` |

```bash
script/setup            # both
script/setup desktop    # vendor/mkxp-z only
script/setup switch     # vendor/mkxp-z-switch only
```

`script/setup` fetches the submodules and applies the patches from
[`patches/`](../patches/). For the Switch port, it also copies our Ruby
preloads into the port's RomFS. Running it again on a patched checkout does
nothing. To start over, reset the submodule:

```bash
git -C vendor/mkxp-z checkout .
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

The port builds with devkitPro's devkitA64 toolchain and libnx. The simplest
way is devkitPro's Docker image:

```bash
# from the root of this repository, so git works inside the submodule
docker run --rm -it -v "$PWD":/src -w /src/vendor/mkxp-z-switch devkitpro/devkita64:20251117 bash
apt update && apt install -y bison git ruby python3-pip g++ libsdl2-dev pkg-config
pip3 install --break-system-packages meson
meson setup --cross-file switch/switch.ini --buildtype release build
ninja -C build
```

This produces `vendor/mkxp-z-switch/build/switch/nro/mkxp-z.nro`. See
`vendor/mkxp-z-switch/switch/README.md` for installing it on the console and
for debugging.

To play a game:

1. Migrate it if it predates Essentials v19 (`bin/rmxp migrate`).
2. Copy the `.nro` to the SD card as `/switch/mkxp-z.nro`.
3. Copy the game folder to `/switch/mkxp-z/Games/<name>/`.
4. Start the Homebrew Menu by holding R while launching a title, not from the
   Album, which gives homebrew too little memory.

Our Switch results come from the Eden emulator, not from hardware; see
[compatibility.md](compatibility.md#nintendo-switch).

## Spinel

Only the battle harness experiments in `test/battle/` use Spinel. It is not a
submodule: build it in `vendor/spinel/` if you want to run them (see
[development.md](development.md#battle-harness)).

## Encrypted games

Games shipped as `Game.rgssad` must be extracted first, for example with
[RPGMakerDecrypter](https://github.com/uuksu/RPGMakerDecrypter).
