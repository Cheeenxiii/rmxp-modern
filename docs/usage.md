# Usage

All commands take a game directory, the one that contains `Data/` (and
`Scripts/` for games with external scripts, such as Reborn). Scratch files go
under `tmp/` unless a work directory is passed.

## unpack

```bash
bin/rmxp unpack GAME OUT
```

Writes a text project to `OUT`: `manifest.yml` (files, formats, script
order), `data/` (one YAML file per `Data/` file, keeping the original name),
`scripts/` (one `.rb` per `Scripts.rxdata` section) and `scripts.yml`. Data
formats `rmxp` cannot decode (the custom `.dat` files of Essentials v16/v17)
are copied as `data/<file>.bin` and marked `opaque` in the manifest. The YAML
format is described in [architecture.md](architecture.md#text-format).

## build

```bash
bin/rmxp build PROJECT OUT
```

Writes `OUT/Data/` (and `OUT/Scripts/` if the project has one). Graphics and
audio are not part of a project: copy the game's other directories next to the
result to play it.

## roundtrip

```bash
bin/rmxp roundtrip GAME [WORKDIR]
```

Unpacks, rebuilds and compares with the original, without touching the game:

```
Pokemon Essentials v21.1 2023-07-30   files=109  identical=109 equivalent=0 opaque=0 scripts=ok
```

- `identical`: rebuilt byte for byte;
- `equivalent`: same data, different Marshal bytes (Ruby 1.8 wrote floats with
  more digits than Ruby 3);
- `opaque`: copied as is (see above);
- `scripts`: `ok` if script sources and order are unchanged.

Exits non-zero on the first mismatch.

## check

```bash
bin/rmxp check GAME [WORKDIR]
```

Parses every script and every event script fragment with Prism. Event commands
355/655 that follow each other are joined into one script, as the interpreter
does. Exits non-zero if a syntax error is left.

## audit

```bash
bin/rmxp audit GAME [WORKDIR]
bin/rmxp audit --scripts DIR
```

Counts the Ruby constructs that get in the way of ahead-of-time compilation:
`eval`, computed `send`, `define_method`, `method_missing`, `alias`, `Marshal`,
`const_get`/`const_set`, `instance_variable_get`/`set`, `ObjectSpace`; event
fragments included. Each use is classed `static` (target known at build time),
`enumerable` (computed but from a finite known set) or `dynamic` (anything
else). `--scripts` audits a directory of `.rb` files directly (Pokémon SDK,
for instance).

It also reports the compatibility-shim functions the game calls, by category
(`real`, `neutral`, `disabled`; see the comments in
`lib/rmxp/preload/compat/`), and the DLL/function of every `Win32API.new`
call. Unknown Win32API functions return 0. The player-facing limitations are in
[compatibility.md](compatibility.md).

## migrate

```bash
bin/rmxp migrate GAME OUT
```

Copies a pre-v19 Essentials game to `OUT` and ports its scripts to Ruby 3, for
[mkxp-z](https://github.com/mkxp-z/mkxp-z). The source game is not modified.
The transformations are generic, never specific to one game:

- regexps with byte escapes and the `/n` flag on interpolated regexps;
- Ruby 1.8's `when value:` syntax;
- `break`/`next` outside a loop, and `return` inside a top-level proc (which
  aborted only that callback in Ruby 1.8 and raises `LocalJumpError` in Ruby 3);
- `read(1)[0]` and `StringInput#getc`, which returned a byte in Ruby 1.8;
- `alias getbyte []` and similar aliases that made Ruby 3's String methods
  return strings again;
- scripts that load the Windows RGSS Linker/FmodEx DLLs are dropped (they only
  work on Windows; mkxp-z provides the audio).

It converts animated GIFs to PNG frames when `ffmpeg` and `ffprobe` are
available (a Ruby reader replaces the game's `gif.dll` calls), and renders MIDI
music to OGG when `fluidsynth` (or `timidity`), `ffmpeg` and the game's
soundfont (`soundfont.sf2` at the game root or under `Audio/`) are available.
The `.mid` files are kept; missing tools give one warning and leave the files
alone. The same MIDI conversion runs from `bin/rmxp package` and
`script/switch-build`.

It also installs preload scripts in `OUT/preload/`, registered in `mkxp.json`:
the Win32API and Ruby 1.8 shims (`Thread.critical`, `ENV["TEMP"]`, ...), the
H-Mode7 fallback, the game's-resolution window scaling, and a cache for
`System.power_state` (Essentials checks the battery every frame; it is slow
where `SDL_GetPowerInfo` is expensive; refreshed every 5 s, disable with
`RMXP_POWER_CACHE_SECONDS=0`).

`migrate` copies the whole game directory: run it on a complete game, not on a
`Data/`-only folder. It refuses a game that still ships `Game.rgssad` (or
`.rgss2a`/`.rgss3a`): mkxp-z loads the archive before the loose files, so the
migrated scripts would be ignored. Extract it first.

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
`preload/` are copied; the text project (`scripts/`, `scripts.yml`), the
original game's Windows DLLs, save files and console test probes are left out.
MIDI is converted to OGG when a renderer is available (see above). The Linux
engine is `vendor/mkxp-z/build/mkxp-z.x86_64` by default (see
[setup.md](setup.md)); the few libraries it links (OpenSSL, libffi, libyaml,
zstd, zlib) are bundled in `lib/` and `run.sh` uses them. For Windows, fetch
mkxp-z once:

```bash
script/fetch-mkxp-z windows
```

That downloads the pinned mkxp-z Actions artifact (about 51 MB,
GPL-2.0-or-later, sha256-checked) into `vendor/mkxp-z-windows/`; it is not
committed. `--mkxp-z-windows DIR` uses another unpacked build. Start a package
with `./run.sh` (Linux) or `run.bat` (Windows).

## Encrypted games

`rmxp` does not read `Game.rgssad` (or `.rgss2a`/`.rgss3a`) archives. Extract
them first, for example with
[RPGMakerDecrypter](https://github.com/uuksu/RPGMakerDecrypter), then run
`rmxp` on the extracted directory.
