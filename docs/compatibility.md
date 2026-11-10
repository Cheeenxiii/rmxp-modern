# Compatibilité

Aller-retour testé : `unpack` puis `build`, comparaison avec l'original. « Octet » =
fichiers reconstruits à l'identique ; « sémantique » = mêmes données, encodage Marshal
différent (Ruby 1.8 écrivait les flottants avec plus de chiffres) ; « opaque » = fichier
conservé tel quel car son format binaire n'est pas décodé.

| Jeu | Famille / version | Aller-retour |
|---|---|---|
| Pokémon Uranium 1.4.1 | Essentials v16.2 | 327 fichiers : 315 octet, 12 sémantique, 10 opaque ; scripts ok |
| Pokémon Insurgence 1.2.7.1 | Essentials v16.2 | 881 fichiers : 878 octet, 3 sémantique, 8 opaque ; scripts ok |
| Pokémon Reborn 19.5 | Essentials v19.1/v20.1 | 931 fichiers : 930 octet, 1 sémantique, 1 opaque ; scripts ok |
| Kit Essentials v16.2 | Essentials v16.2 | 110 fichiers : 107 octet, 3 sémantique, 8 opaque ; scripts ok |
| Kit Essentials v17.2 | Essentials v17.2 | 111 fichiers : 108 octet, 3 sémantique, 8 opaque ; scripts ok |
| Kit Essentials v19.1 | Essentials v19.1 | 105 fichiers : 104 octet, 1 sémantique ; scripts ok |
| Kit Essentials v20.1 | Essentials v20.1 | 107 fichiers : 105 octet, 2 sémantique ; scripts ok |
| Kit Essentials v21.1 | Essentials v21.1 | 109 fichiers : 109 octet ; scripts ok |

Uranium et Insurgence sont lus depuis leur archive RGSSAD déchiffrée au préalable
(`corpus/essentials/*/decrypted/`).

Audit du Ruby dynamique (détail reproductible avec `bin/rmxp audit JEU`) :

- **Uranium** : alias et fragments d'événements supprimables ; reste 21 `eval`, 12 `send`
  calculés et 42 `Marshal.dump` dynamiques.
- **Insurgence** : 21 `eval`, 33 `send` calculés et 76 `Marshal.dump` dynamiques ; 3
  erreurs de syntaxe d'origine (ancienne syntaxe, événements invalides).
- **Reborn** : 85 `eval` et 23 `send` calculés dynamiques ; alias, ivars et fragments
  supprimables.
- **Kit v21.1** : 9 `eval`, 5 `send` calculés et 25 `Marshal.dump` dynamiques ; le reste
  (alias, fragments, `Marshal.load`) est supprimable.
- **PSDK** : audit de code seulement ; 364 alias et 196 accès d'ivars supprimables,
  166 `send` calculés dynamiques.

## Migration pré-v19

`bin/rmxp migrate` applique les transformations génériques de compatibilité
(syntaxe 1.8 → 3, regex à octets, `when valeur:`, `break`/`next` hors boucle,
shims Win32API/Ruby 1.8) puis reconstruit les scripts :

- **Uranium** : sélection de langue, titre, options, nouvelle partie et **première
  carte** atteints sur mkxp-z standard ;
- **Insurgence** : titre, menu, nouvelle partie, intro et **première carte** rendue,
  sans correctif spécifique au jeu. Au premier lancement d'une copie fraîche,
  Essentials v16 propose d'installer ses polices ; c'est cosmétique après redémarrage.

## Switch (émulateur Eden)

Le port Switch est vérifié sous Eden (Vulkan/lavapipe), sans carte physique et
sans mesure de fps représentative :

- kit v21.1 reconstruit et kit original : écran titre, menu, carte de départ ;
- Reborn : écran titre puis menu (New Game/Other Save Files/Options/Save Directory/
  Controls), 40 fps sous émulateur ;
- Uranium (port warmwinter) : sélection de langue.

Le Ruby du port Switch n'embarque pas toute la stdlib : `timeout`, `weakref`,
`delegate`, RubyGems, `net/http` et la gem Discord sont fournis par les préloads
du port, sinon Reborn s'arrête au chargement de ses scripts.

## Fichiers opaques connus

Essentials v16.2/v17.2 utilisent un format `.dat` binaire maison (table d'offsets, pas du
Marshal) que l'outil ne décode pas encore : `items.dat`, `moves.dat`, `evolutions.dat`,
`dexdata.dat`, `eggEmerald.dat`, `regionals.dat`, `attacksRS.dat`, `rsattacks.dat`,
`tutor.dat`, `tmpbs.dat`, `BackupSave.dat` selon le jeu.

Reborn : `mons.dat` est du Marshal mais référence des classes internes
(`MonDataHash`, `MonWrapper`, `MonData`) dont le chargement n'est pas encore résolu.

Ces fichiers sont copiés octet pour octet : le jeu reconstruit est fidèle, mais ils ne
sont pas lisibles en texte.

## Non traité

- Pokémon SDK (formats VD `.dat`, scripts YARB) : reconnaissance seulement.
- Archives chiffrées RGSSAD/RGSS2A/RGSS3A : outil externe requis (voir `docs/usage.md`).
- Démarrage des jeux reconstruits : kit v21.1 et Reborn vérifiés sous mkxp-z ; Uranium
  passe par le portage warmwinter et les assets d'origine.
- Les captures Switch sont faites sous Eden ; les fps de l'émulateur ne sont pas
  représentatifs de la console.
