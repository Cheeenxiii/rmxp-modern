# Patches

Changes to [mkxp-z](https://github.com/mkxp-z/mkxp-z) needed to run converted
games.

- `mkxp-z/`: patches for the desktop build.
- `mkxp-z-switch/`: patches and preload scripts for the Nintendo Switch port.

## License

The `.patch` files modify mkxp-z and are licensed under the same terms as
mkxp-z, GPL-2.0-or-later (see `LICENSES/GPL-2.0-or-later.txt`), so they can
be sent upstream as is.

The Ruby files in `mkxp-z-switch/` ship inside games and carry their own
license header:

- our stubs (`stdlib_*_stub.rb`, `switch_paths.rb`) are MIT;
- `win32_wrap.rb` comes from mkxp and is CC0;
- `stdlib_delegate.rb`, `stdlib_timeout.rb` and `stdlib_weakref.rb` are copies
  of Ruby standard library gems, under Ruby's license or BSD-2-Clause.
