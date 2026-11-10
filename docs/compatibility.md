# Compatibility

What works after `unpack` and `build`, and — for games older than Essentials
v19 — after `bin/rmxp migrate`. v0.1 targets Linux; Windows packages and the
Switch builds are experimental.

## Games

| Game | Status |
|---|---|
| Pokémon Uranium 1.4.1 (Essentials v16.2) | Playable: title, menus, first map, battles, save and reload. |
| Pokémon Insurgence 1.2.7.1 (Essentials v16.2) | Playable: title, menus, intro, maps, battles, save and reload; H-Mode7 maps render as normal maps. |
| Pokémon Reborn 19.5 | Boots to its title screen and main menu. |
| Essentials kits v19.1, v20.1, v21.1 | Boot and play; the round trip is byte-identical on v21.1. |
| Pokémon SDK games | Not supported yet. |

The `unpack`/`build` round trip gives back the original files; a few binary data
formats (the `.dat` files of Essentials v16/v17, Reborn's `mons.dat`) are kept
as opaque blobs and copied byte for byte, so the rebuilt game is correct even
though those files are not text. `bin/rmxp roundtrip GAME` prints the numbers.

`bin/rmxp audit GAME` counts the dynamic Ruby left in a game (eval, send,
aliases, Marshal and the engine API calls our shims cover).

## Known limitations

- Uranium's picture is not upscaled to fill the window: the game draws at
  512x384 in a 640x480 window, so there are black bands on the right and
  bottom, where the reference port scales the picture up.
- Insurgence's H-Mode7 maps (7 maps, including the intro and the world map)
  lose their heightmap effect and are drawn as normal maps instead: their
  Windows DLL is absent, so only the normal renderer is used.
- Online features (updates, GTS, trades, Discord Rich Presence) are off: the
  Windows network APIs return nothing.
- Screen readers (Tolk/NVDA) are not implemented.
- Reborn needs its game-side `Input::E/F/D` shim on stock mkxp-z.

## Nintendo Switch

Runs under the Eden emulator, not on hardware yet. The controls are the Switch
ones (A confirms, B cancels); the game folder lookup, standalone `.nro` builds,
SD card install and log location are described in [setup.md](setup.md#nintendo-switch).
The limitations above apply, and the port's Ruby has no RubyGems, no HTTP and
no Discord gem.

## Not supported

- Encrypted games (`Game.rgssad`, `.rgss2a`, `.rgss3a`): extract them first.
- Pokémon SDK data (`.dat` files, YARB scripts).
