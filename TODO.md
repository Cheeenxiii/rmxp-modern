# TODO

- Rendus lisibles des `.dat` binaires d'Essentials avant v19 : `items.dat`, `moves.dat`,
  `evolutions.dat`, `dexdata.dat`, `eggEmerald.dat`, `regionals.dat`, `attacksRS.dat`,
  `rsattacks.dat`, `tutor.dat`, `tmpbs.dat`, `BackupSave.dat`. Aujourd'hui copiés en
  `opaque` (aller-retour fidèle, pas de texte).
- Reborn `Data/mons.dat` : Marshal avec classes internes non résolues
  (`MonDataHash`, `MonWrapper`, `MonData`) → `opaque`.
- `Table`/`Color`/`Tone`/`Rect` conservés en blob Marshal : décoder `Table` au moins,
  pour que les cartes soient lisibles en texte.
- PSDK : formats VD, `Scripts.dat`/YARB. Après accord sur le périmètre.
- Compiler mkxp-z (paquets système à installer) et vérifier que les jeux reconstruits
  des kits v19+ et Reborn démarrent.
- Oracle déterministe : rediriger `rand`/`Random` du jeu vers notre générateur, appliqué
  à la référence comme aux versions transformées. Condition du jalon 2 et du jalon 4.
