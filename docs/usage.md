# Usage

All commands take a game directory, the one that contains `Data/` (and
`Scripts/` for games with external scripts, such as Reborn). Commands that
need scratch space write it under `tmp/` unless you pass a work directory.

## unpack

```bash
bin/rmxp unpack GAME OUT
```

Writes a text project to `OUT`:

```
OUT/
  manifest.yml        files, formats and script order
  data/               one YAML file per Data/ file
  scripts/            one .rb file per Scripts.rxdata section
  scripts.yml         script order, ids and names
  scripts_tree/       copy of Scripts/, if the game has one
```

`data/<file>.yaml` holds `Data/<file>`, keeping the original name
(`data/Actors.rxdata.yaml`). Files that can't be decoded, such as the custom
binary `.dat` files of Essentials v16/v17, are copied as is to
`data/<file>.bin` and marked `opaque` in the manifest. The YAML format is
described in [architecture.md](architecture.md#text-format).

## build

```bash
bin/rmxp build PROJECT OUT
```

Writes `OUT/Data/` (and `OUT/Scripts/` if the project has one). Graphics and
audio are not part of the project: to play the result, copy the game's other
directories next to it.

## roundtrip

```bash
bin/rmxp roundtrip GAME [WORKDIR]
```

Unpacks, rebuilds and compares with the original, without touching the game.

```
Pokemon Essentials v21.1 2023-07-30      files=109  identical=109 equivalent=0 opaque=0 scripts=ok
```

- `identical`: rebuilt byte for byte;
- `equivalent`: same data, different Marshal bytes. RMXP's Ruby 1.8 wrote
  floats with more digits than Ruby 3 does;
- `opaque`: copied as is (see above);
- `scripts`: `ok` if script sources and order are unchanged.

Exits with a non-zero status on the first mismatch.

## check

```bash
bin/rmxp check GAME [WORKDIR]
```

Parses every script with Prism, and every script fragment in events. Event
commands 355/655 that follow each other are joined into one script, as the
interpreter does.

```
scripts: 402 (0 error(s)), events: 1112 fragment(s) (0 error(s))
```

Exits with a non-zero status if any syntax error is left.

## audit

```bash
bin/rmxp audit GAME [WORKDIR]
bin/rmxp audit --scripts DIR
```

Counts the Ruby constructs that get in the way of ahead-of-time compilation:
`eval`, computed `send`, `define_method`, `method_missing`, `alias`, `Marshal`,
`const_get`/`const_set`, `instance_variable_get`/`set`, `ObjectSpace`. Event
script fragments are included. Each use is classed as:

- `static`: the target is known at build time and can be replaced with a
  direct call or generated code;
- `enumerable`: the target is computed but comes from a finite set known at
  build time;
- `dynamic`: anything else.

`--scripts` audits a directory of `.rb` files directly (Pokémon SDK, for
instance).

It also reports the compatibility-shim functions the game actually calls, with
the category of each shim:

- `real`: the original behaviour is reproduced by another means;
- `neutral`: the operation has no equivalent outside Windows, and doing nothing
  is correct;
- `disabled`: the shim answers so that the game doesn't crash, but the feature
  is lost. `win32api` lists the DLL and function of every `Win32API.new` call;
  a function without a shim is marked as returning 0.

The categories are written at the functions in `lib/rmxp/preload/compat/` and
`patches/mkxp-z-switch/`; see [compatibility.md](compatibility.md#nintendo-switch)
for the player-facing limitations.

## migrate

```bash
bin/rmxp migrate GAME OUT
```

Copies a pre-v19 Essentials game to `OUT` and ports its scripts to Ruby 3, for
[mkxp-z](https://github.com/mkxp-z/mkxp-z). The source game is not modified.

The transformations are generic, never specific to one game:

- regexps with byte escapes, and the `/n` flag on interpolated regexps;
- Ruby 1.8's `when value:` syntax;
- `break`/`next` outside a loop;
- `return` inside a proc defined at the top level, which aborted only that
  callback in Ruby 1.8 and raises `LocalJumpError` in Ruby 3;
- `read(1)[0]`, which returned a byte in Ruby 1.8;
- `StringInput#getc`, for the same reason;
- `alias getbyte []` and similar aliases that made Ruby 3's String methods
  return strings again;
- scripts that load the Windows RGSS Linker/FmodEx audio DLLs are dropped: they
  only work on Windows, and mkxp-z provides the audio;
- animated GIFs are converted to PNG frames when `ffmpeg` and `ffprobe` are
  available, and a Ruby reader replaces the game's `gif.dll` calls.

It also installs preload scripts in `OUT/preload/` and registers them in
`mkxp.json`: Win32API and Ruby 1.8 shims (`Thread.critical`, `ENV["TEMP"]`,
...), and a cache for `System.power_state`. Essentials checks the battery every
frame, which is slow on platforms where `SDL_GetPowerInfo` is expensive. The
cache refreshes every 5 seconds; set `RMXP_POWER_CACHE_SECONDS=0` to disable
it.

`migrate` copies the whole game directory, so run it on a complete game
(with Graphics, Audio and Fonts), not on a directory that only has `Data/`.
It refuses a game that still ships its `Game.rgssad` (or `.rgss2a`/`.rgss3a`):
mkxp-z loads that archive before the loose files, so the migrated scripts would
be ignored. Extract the archive first.

## package

```bash
bin/rmxp package GAME OUT [--platforms linux,windows]
bin/rmxp package GAME OUT --mkxp-z-linux PATH --mkxp-z-windows DIR
```

Turns a migrated game into folders that can be handed to someone without any
other installation: `OUT/linux/` and `OUT/windows/`, each with the game, the
mkxp-z engine and a launcher.

```
OUT/linux/    mkxp-z, lib/, run.sh, the game files
OUT/windows/  mkxp-z.x86_64.exe, stdlib/, scripts/preload/, run.bat, the game files
```

The game's `Data/`, `Graphics/`, `Audio/`, `Fonts/`, `mkxp.json` and game-side
`preload/` are copied. The text project (`scripts/`, `scripts.yml`), the
Windows DLLs of the original game and save files are left out. The Linux engine
is `vendor/mkxp-z/build/mkxp-z.x86_64` by default (see [setup.md](setup.md)),
and the few libraries it links (OpenSSL, libffi, libyaml, zstd, zlib) are
bundled in `lib/`; `run.sh` uses them. For Windows, fetch mkxp-z once:

```bash
script/fetch-mkxp-z windows
```

That downloads the pinned mkxp-z Actions artifact (about 51 MB, GPL-2.0-or-later,
sha256-checked) into `vendor/mkxp-z-windows/`; it is not committed. Pass
`--mkxp-z-windows DIR` to use another unpacked build.

Start a package with `./run.sh` (Linux) or `run.bat` (Windows).

## Encrypted games

`rmxp` does not read `Game.rgssad` (or `.rgss2a`/`.rgss3a`) archives. Extract
them first, for example with
[RPGMakerDecrypter](https://github.com/uuksu/RPGMakerDecrypter), then run
`rmxp` on the extracted directory.
