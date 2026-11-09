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
- Audit du dynamisme : Essentials et PSDK sont audités et classés.
- Jalon 4 (cœur des combats, kit v21.1) : harnais CRuby pur opérationnel, données
  littérales identiques aux données Marshal, 1000 combats CRuby = 31,4 s (données
  réduites). Spinel : 94 refus (noyau), 371 refus (50 %), échec de génération au palier
  100 % (`@color` typé différemment entre CommandMenu et MenuBase) ; avec
  `--defer-refusals` le C généré ne compile pas (erreur de types). Aucun binaire Spinel
  produit. Décision native/hybride/plan B à prendre (recommandation : plan B court
  terme, Spinel réservé aux sous-systèmes numériques purs).
- Uranium : le menu de langue redessine tout à chaque frame (`pbDrawShadowText`,
  `BitmapWrapper#initialize`, cache de bitmaps, `canonicalize` des chemins) ; diagnostic
  fait, pas d'optimisation décidée.
- Transformations : traiter les chaînes d'alias sur `Graphics.update` (5 à 16 par jeu)
  comme des alias normaux, et les `eval` des événements comme des méthodes générées.
- Shim `Array#sample(n)` : exact pour n <= 10 ; au-delà, repli sur un Fisher-Yates partiel
  qui peut différer de CRuby. Aucun usage connu dans les scénarios visés.
- Table/Color/Tone/Rect conservés en blob Marshal (voir ci-dessus).
