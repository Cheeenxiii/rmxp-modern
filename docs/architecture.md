# Architecture

## Code layout

| Path | Role |
|---|---|
| `bin/rmxp` | command line |
| `lib/rmxp/project.rb` | game directory to text project and back: `unpack`, `build`, `roundtrip` |
| `lib/rmxp/codec.rb` | Marshal to YAML tree and back, unknown classes, shared references |
| `lib/rmxp/scripts.rb` | `Scripts.rxdata` to one `.rb` file per section, with order and ids |
| `lib/rmxp/rgss.rb` | RGSS types with their own Marshal format (Table, Color, Tone, Rect, Font) |
| `lib/rmxp/check.rb` | parses scripts and event script fragments with Prism |
| `lib/rmxp/audit.rb` | counts dynamic Ruby constructs and calls to compatibility shims |
| `lib/rmxp/migrate.rb` | ports pre-v19 games to Ruby 3 |
| `lib/rmxp/mt19937.rb` | CRuby's random number generator, in Ruby |
| `lib/rmxp/preload/compat/` | shims that `migrate` installs into games |
| `lib/rmxp/preload/` | RNG shim and scenario probe, loaded by mkxp-z in tests |
| `patches/` | mkxp-z patches, desktop and Switch |
| `test/` | tests, plus the battle and headless harnesses (see [development.md](development.md)) |

## Text format

A project is a `manifest.yml`, a `scripts.yml` and two directories: `data/`
and `scripts/`.

### Data files

Each Marshal file becomes a YAML document:

```yaml
format: 1
value: ...
```

`value` is a tree of plain YAML values. `nil`, booleans, integers, floats,
arrays and UTF-8 strings are written as they are. Everything else is a mapping
with tagged keys:

| Node | Meaning |
|---|---|
| `__class__`, `__ivars__` | object of a class, with its instance variables in declaration order |
| `__builtin__` + `__array__` / `__hash__` / `__str__` | subclass of Array, Hash or String |
| `__hash__`, `__default__` | Hash, as a list of `[key, value]` pairs, and its default value |
| `__str__`, `__enc__` | ASCII string in another encoding than UTF-8 (often `ASCII-8BIT`) |
| `__b64__`, `__enc__` | non-ASCII string that isn't valid UTF-8, in Base64 |
| `__sym__` | Symbol |
| `__float__` | `NaN`, `Infinity` or `-Infinity` |
| `__blob__` | Marshal payload of a class with its own `_dump` (Table, Color, ...), in Base64 |
| `__time__` | Time, as its Marshal dump in Base64 |
| `__id__`, `__ref__` | an object that appears more than once gets an `__id__`; other occurrences are `__ref__` |

The rule that `unpack` enforces is that the tree is stable:
`to_tree(from_tree(tree)) == tree`. Byte-identical output is the goal and
usually holds, but it can't be guaranteed: Ruby 1.8 wrote floats with more
digits than Ruby 3.

### Unknown classes

Game data references classes that `rmxp` doesn't define (`RPG::Actor`, and
many game-specific ones). `Codec.load_bytes` reads the class name from
Marshal's error, defines an empty class and retries. When Marshal reports that
a class should be a subclass of Array, Hash or String without saying which,
it tries each candidate. Classes with their own Marshal format (Essentials'
`OrderedHash` and `WordArray`, Reborn's `MonDataHash`) are kept as blobs.

Files from the same game don't always agree on a class's shape: two builds of
the game may have dumped it differently. Stub classes are therefore removed
after each file.

### Opaque files

A file that can't be loaded is copied byte for byte to `data/<file>.bin` and
marked `opaque` in the manifest. `build` copies it back, so the round trip is
still exact.

### Scripts

`Scripts.rxdata` is a Marshal array of `[id, name, zlib source]`. Each section
becomes `scripts/NNNN_<name>.rb`, and `scripts.yml` keeps the order, ids and
names. Games with an external `Scripts/` directory (Reborn) get it copied to
`scripts_tree/`.

## Determinism

Battles and many events call `rand`. To compare a game before and after a
transformation, both runs must draw the same numbers. `lib/rmxp/mt19937.rb`
reimplements CRuby's generator and its conversions (`Kernel#rand`,
`Random#rand`, integer and float ranges); `test/mt19937_test.rb` checks it
against CRuby over millions of draws. `lib/rmxp/preload/deterministic_random.rb`
installs it in mkxp-z in place of `rand`, `srand`, `Random` and Array's
`sample`/`shuffle`.

## Not handled

- Decrypting archives: out of scope, use an external tool.
- Pokémon SDK formats (VD, YARB): not yet.
