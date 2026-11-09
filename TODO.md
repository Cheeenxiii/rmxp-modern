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
- Reborn sous Xvfb : le boot dépasse le timebox (données volumineuses, ou blocage
  spécifique à Reborn). À reprendre avec un affichage réel ; le kit v21.1, lui, démarre.
- mkxp-z compilé sans extension Ruby `openssl` (`--with-out-ext=openssl...`) : Reborn
  (Updater/net/http) échoue avec notre binaire ; utiliser le mkxp-z fourni par Reborn
  pour Reborn, ou corriger le build Ruby (jalon 6).
- Portage Uranium warmwinter : le dépôt ne contient pas les assets ; il faut les copier
  depuis l'archive d'origine et créer `Patches/` (le port attend ce dossier). À
  automatiser si les builds Uranium en ont besoin.
- Audit du dynamisme : compter les chaînes d'alias sur `Graphics.update` (Essentials et
  Reborn en ont) comme cas à traiter par les transformations.
- Shim `Array#sample(n)` : exact pour n <= 10 ; au-delà, repli sur un Fisher-Yates partiel
  qui peut différer de CRuby. Aucun usage connu dans les scénarios visés.
- Table/Color/Tone/Rect conservés en blob Marshal (voir ci-dessus).
