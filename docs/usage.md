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
- `read(1)[0]`, which returned a byte in Ruby 1.8;
- `StringInput#getc`, for the same reason.

It also installs preload scripts in `OUT/preload/` and registers them in
`mkxp.json`: Win32API and Ruby 1.8 shims (`Thread.critical`, `ENV["TEMP"]`,
...), and a cache for `System.power_state`. Essentials checks the battery every
frame, which is slow on platforms where `SDL_GetPowerInfo` is expensive. The
cache refreshes every 5 seconds; set `RMXP_POWER_CACHE_SECONDS=0` to disable
it.

`migrate` copies the whole game directory, so run it on a complete game
(with Graphics, Audio and Fonts), not on a directory that only has `Data/`.

## Encrypted games

`rmxp` does not read `Game.rgssad` (or `.rgss2a`/`.rgss3a`) archives. Extract
them first, for example with
[RPGMakerDecrypter](https://github.com/uuksu/RPGMakerDecrypter), then run
`rmxp` on the extracted directory.
