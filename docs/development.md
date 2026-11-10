# Development

## Tests

The tests that matter run on real games, which are not in the repository.
Pass their paths on the command line.

```bash
ruby test/roundtrip_test.rb path/to/game [another/game ...]
```

Unpacks, rebuilds and compares each game; exits non-zero on the first
mismatch. `bin/rmxp roundtrip`, `bin/rmxp check` and `bin/rmxp audit` are
useful on a single game too.

These two don't need a game:

```bash
ruby test/mt19937_test.rb    # our RNG against CRuby, 2 million draws
ruby test/migrate_test.rb    # migrate's source transformations
```

## Headless runs

`test/headless_test.rb` runs a game in mkxp-z under Xvfb, with the
deterministic RNG and a probe that measures frames and writes a state dump.
Two runs with the same seed must produce the same dump. It needs an mkxp-z
binary (`MKXP_BIN`, default `vendor/mkxp-z/build/mkxp-z.x86_64`, see
[setup.md](setup.md)) and `xvfb-run`.

```bash
ruby test/headless_test.rb GAME REBUILT_DATA [SECONDS] [SEED]
```

The probe can also drive a scenario and profile it:

```bash
RMXP_JOURNEY=map RMXP_UNCAPPED=1 RMXP_PROFILE=1 RMXP_PROFILE_SCENE=map \
  RMXP_WARMUP=1 RMXP_SECONDS=4 RMXP_WATCHDOG=60 \
  ruby test/headless_test.rb tmp/kit-rebuilt tmp/kit-rebuilt/Data 4 1
```

| Variable | Effect |
|---|---|
| `RMXP_JOURNEY` | `map` walks on the map, `battle` starts automatic battles |
| `RMXP_UNCAPPED` | disables the frame rate limit |
| `RMXP_PROFILE` | per-method self time and allocations, through TracePoint |
| `RMXP_PROFILE_SCENE` | only profile while this scene is active |
| `RMXP_WARMUP` | seconds to skip before measuring (default 1.5) |
| `RMXP_SECONDS` | length of the measurement window (default 2.0) |
| `RMXP_WATCHDOG` | write the dump after this many seconds even if the game hangs |
| `RMXP_SEED` | RNG seed (default 1) |

## Battle harness

An experiment towards native compilation: Essentials battles running in plain
CRuby, without mkxp-z. `test/battle/run_battles.rb` extracts the scripts of the
Essentials v21.1 kit (`RMXP_KIT`, path to the kit), loads them with RGSS stubs
and runs battles with `Battle::DebugSceneNoVisuals`.

```bash
RMXP_KIT=path/to/kit RMXP_BATTLES=30 RMXP_SEED=7 RMXP_LOG=tmp/battle/log.txt \
  ruby test/battle/run_battles.rb
```

Two runs with the same seed must write the same log.

Battle data as Ruby literals instead of Marshal (rerun after a data change):

```bash
ruby test/battle/gen_battle_data.rb
RMXP_SUBSET=1 ruby test/battle/gen_battle_data.rb   # reduced data, for RMXP_SMALL_DATA
RMXP_USE_LITERAL_DATA=1 RMXP_BATTLES=50 ruby test/battle/run_battles.rb
```

The rest compiles parts of the engine ahead of time with Spinel, built in
`vendor/spinel/`. A CRuby extension for the damage formula:

```bash
ruby test/battle/build_hybrid_extension.rb
RMXP_USE_LITERAL_DATA=1 RMXP_SMALL_DATA=1 \
  RMXP_HYBRID_SO=tmp/battle/hybrid/damage.so \
  RMXP_BATTLES=1000 RMXP_SEED=42 ruby test/battle/run_battles.rb
```

The log must stay identical to the run without the extension. A whole program
for Spinel (this does not compile yet, see [TODO.md](../TODO.md)):

```bash
ruby test/battle/build_spinel.rb
vendor/spinel/bin/spinel tmp/battle/spinel_battle.rb -o tmp/battle/spinel_battle
```

## Supporting a new data format

1. Reproduce the failure on a real file and read the exact `Marshal.load`
   error.
2. Unknown class: add it to `Codec` as a blob, or to the class resolution in
   `lib/rmxp/codec.rb`.
3. Type with its own `_dump`: implement it in `lib/rmxp/rgss.rb` if it should
   be readable, or keep it as a blob if its bytes are enough.
4. Not Marshal at all: the file must come out `opaque`, never crash.
5. Rerun `test/roundtrip_test.rb` on every game you have, not only the one you
   fixed.

## Conventions

- Document a behavior in the commit that adds it.
- Small commits with a one-line message, plus a few lines when the why isn't
  obvious.
- No game-specific fixes in the code: either the change is generic, or it goes
  to `TODO.md`.
- Round-trip fidelity matters more than test coverage.

## Virtual gamepad

`script/virtual-pad` creates an Xbox-like pad through Linux `/dev/uinput`, so
SDL (mkxp-z, the emulators) sees a real controller instead of simulated keys.
It needs write access to `/dev/uinput` (root or a udev rule; in a container,
`--privileged` with `/dev` available). It reads one command per line on stdin:

```bash
mkfifo /tmp/pad
script/virtual-pad </tmp/pad &
printf 'a down\nsleep 80\na up\n' > /tmp/pad
printf 'hat down\nsleep 80\nhat center\n' > /tmp/pad
```

SDL only enumerates uinput devices when udev tags them as joysticks
(`ID_INPUT_JOYSTICK`); on a normal desktop that happens automatically. Where
that is not possible (sandboxed or container test runs), build a test-only
mkxp-z with an SDL virtual controller (`SDL_JoystickAttachVirtual`) fed from a
FIFO instead.
