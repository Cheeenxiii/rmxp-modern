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
- Démarrage headless des kits sous mkxp-z : le moteur s'initialise et charge les scripts,
  puis le jeu reste bloqué avant le titre sous Xvfb, **avec les données d'origine comme
  avec celles reconstruites** (donc pas une régression de l'aller-retour). À reprendre
  avec un affichage réel ou une config mkxp-z dédiée. Timeboxé.
- Shim `Array#sample(n)` : exact pour n <= 10 ; au-delà, repli sur un Fisher-Yates partiel
  qui peut différer de CRuby. Aucun usage connu dans les scénarios visés.
- Table/Color/Tone/Rect conservés en blob Marshal (voir ci-dessus).
