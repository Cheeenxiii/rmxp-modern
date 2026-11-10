# Patches

Changes to [mkxp-z](https://github.com/mkxp-z/mkxp-z) needed to run converted
games, on top of `vendor/mkxp-z`.

- `mkxp-z/`: fixes for every platform.
- `mkxp-z-switch/`: the Nintendo Switch port, applied after `mkxp-z/`, and
  the Ruby preload scripts that go in the `.nro`'s RomFS. Engine changes are
  behind `__SWITCH__` or `host_system == 'switch'`.

`script/setup` applies both series in order; see
[docs/setup.md](../docs/setup.md). They must apply cleanly to the commit the
submodule is pinned to: when you move it, check that `script/setup` and the
Switch CI still work.

The Switch series keeps only what a game needs to run: the libnx platform
layer, Ruby and PhysFS for libnx, the cross file and the `.nro` packaging.
Much of it comes from
[GQster's mkxp-z Switch port](https://github.com/GQster/mkxp-zSwitchPort);
each patch says so in its header.

## License

The `.patch` files modify mkxp-z and are licensed under the same terms as
mkxp-z, GPL-2.0-or-later (see `LICENSES/GPL-2.0-or-later.txt`), so they can
be sent upstream as is.

The Ruby files in `mkxp-z-switch/` carry their own license header:

- our stubs (`stdlib_*_stub.rb`, `switch_paths.rb`, `stdout_sync.rb`) are MIT;
- `win32api_stub.rb` comes from GQster's port and is GPL-2.0-or-later;
- `win32_wrap.rb` comes from mkxp and is CC0;
- `stdlib_delegate.rb`, `stdlib_timeout.rb` and `stdlib_weakref.rb` are copies
  of Ruby standard library gems, under Ruby's license or BSD-2-Clause.
