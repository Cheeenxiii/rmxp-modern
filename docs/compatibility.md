# Compatibilité

Aller-retour testé : `unpack` puis `build`, comparaison avec l'original. « Octet » =
fichiers reconstruits à l'identique ; « sémantique » = mêmes données, encodage Marshal
différent (Ruby 1.8 écrivait les flottants avec plus de chiffres) ; « opaque » = fichier
conservé tel quel car son format binaire n'est pas décodé.

## Jeux

| Jeu | Famille / version | Scripts | Données | Résultat |
|---|---|---|---|---|
| Pokémon Uranium 1.4.1 | Essentials v16.2 | `Scripts.rxdata` (261 sections) | 327 fichiers | 315 octet, 12 sémantique, 10 opaque |
| Pokémon Insurgence 1.2.7.1 | Essentials v16.2 | `Scripts.rxdata` (215 sections) | 881 fichiers | 878 octet, 3 sémantique, 8 opaque |
| Pokémon Reborn 19.5 | Essentials v19.1/v20.1 | `Scripts/` externe + `Scripts.rxdata` | 931 fichiers | 930 octet, 1 sémantique, 1 opaque |
| Kit Essentials v16.2 | Essentials v16.2 | 179 sections | 110 fichiers | 107 octet, 3 sémantique, 8 opaque |
| Kit Essentials v17.2 | Essentials v17.2 | 206 sections | 111 fichiers | 108 octet, 3 sémantique, 8 opaque |
| Kit Essentials v19.1 | Essentials v19.1 | 373 sections | 105 fichiers | 104 octet, 1 sémantique |
| Kit Essentials v20.1 | Essentials v20.1 | 387 sections | 107 fichiers | 105 octet, 2 sémantique |
| Kit Essentials v21.1 | Essentials v21.1 | 402 sections | 109 fichiers | 109 octet |

Uranium et Insurgence sont lus depuis leur archive RGSSAD déchiffrée au préalable
(`corpus/essentials/*/decrypted/`).

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

- Pokémon SDK (formats VD `.dat`, scripts YARB) : hors périmètre de cette étape.
- Archives chiffrées RGSSAD/RGSS2A/RGSS3A : outil externe requis (voir `docs/usage.md`).
- Démarrage des jeux reconstruits sous mkxp-z : dépend de la compilation du moteur.
