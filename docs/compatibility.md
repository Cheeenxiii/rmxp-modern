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

## Compilation statique (`rmxp check`)

| Jeu | Scripts | Fragments d'événements | Erreurs |
|---|---|---|---|
| Kit Essentials v21.1 | 402 | 1 112 | 0 |
| Uranium 1.4.1 | 261 | 11 284 | 0 |
| Reborn 19.5 | 194 | 17 726 | 0 |
| Insurgence 1.2.7.1 | 215 | 17 578 | 3 |

Les commandes 355/655 consécutives sont recollées avant le parsing, comme le fait
l'interpréteur. Les 3 signalements d'Insurgence sont un `when` à l'ancienne syntaxe
(`AudioUtilities`) et deux fragments d'événements invalides dans le jeu d'origine
(dont une virgule finale `:SNOREBALL:`), pas des erreurs de reconstruction.

## Fichiers opaques connus

Essentials v16.2/v17.2 utilisent un format `.dat` binaire maison (table d'offsets, pas du
Marshal) que l'outil ne décode pas encore : `items.dat`, `moves.dat`, `evolutions.dat`,
`dexdata.dat`, `eggEmerald.dat`, `regionals.dat`, `attacksRS.dat`, `rsattacks.dat`,
`tutor.dat`, `tmpbs.dat`, `BackupSave.dat` selon le jeu.

Reborn : `mons.dat` est du Marshal mais référence des classes internes
(`MonDataHash`, `MonWrapper`, `MonData`) dont le chargement n'est pas encore résolu.

Ces fichiers sont copiés octet pour octet : le jeu reconstruit est fidèle, mais ils ne
sont pas lisibles en texte.

## Scénario headless (mkxp-z sous Xvfb)

Kit v21.1 **reconstruit** : démarre sur `Scene_Intro`. Fenêtre de mesure : 81 frames en
2,001 s, soit 40,5 fps ; médiane 25,0 ms par frame. Deux exécutions avec la même graine
donnent un dump identique (état + tirages RNG) ; une autre graine change les tirages.

## Audit du Ruby dynamique (`rmxp audit`)

S = supprimable par transformation (cible connue au build), D = vraiment dynamique.
Sources = scripts + fragments d'événements (commandes 355/655 recollées).

| Jeu | Sources | eval S/D | send S/D | alias S/D | define_method S/D | Marshal.load/dump | const S/D | ivar S/D | method_missing | ObjectSpace | fragments |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Kit v21.1 | 1 514 | 11/9 | 0/5 | 85/0 | 0/1 | 14/25 | 3/42 | 0/1 | 0 | 0/5 | 1 112 |
| Uranium | 11 545 | 0/21 | 6/13 | 176/0 | 0/0 | 57/42 | 0/37 | 0/0 | 0 | 0/13 | 11 284 |
| Insurgence | 17 793 | 0/21 | 42/35 | 106/0 | 0/0 | 59/76 | 0/40 | 1/1 | 0 | 0/12 | 17 578 |
| Reborn 19.5 | 17 920 | 1/85 | 17/23 | 119/0 | 0/0 | 39/38 | 0/13 | 55/1 | 0 | 0/4 | 17 726 |
| PSDK (scripts) | 1 634 | 2/14 | 31/175 | 364/0 | 17/0 | 22/23 | 23/15 | 196/52 | 0 | 0/4 | — |

Les fragments d'événements sont du code connu au build (génération de méthodes), donc
supprimables par transformation. Les `Marshal.load` de données de jeu le sont aussi
(données générées au build) ; les `Marshal.dump` restent dynamiques (sauvegardes).
Les alias sur `Graphics.update` (mesurés par l'audit précédent) : 5 dans le kit v21.1,
16 dans Uranium, 16 dans Insurgence, 10 dans Reborn.

## Mesures headless (mkxp-z sous Xvfb)

Mesure sans limite de fréquence (`fixedFramerate: -1`) : « logique » = temps entre la fin
d'un `Graphics.update` et le début du suivant (entrées + mise à jour de scène), « rendu »
= durée de `Graphics.update` sans attente de fréquence. p50/p95/p99 sur une fenêtre de
2 s. Rendu en **llvmpipe** (OpenGL logiciel), donc non représentatif d'un GPU réel.

| Cible | Scène | fps | logique p50/p95/p99 (ms) | rendu p50/p95/p99 (ms) | total p50/p95/p99 (ms) | GC |
|---|---|---|---|---|---|---|
| Kit v21.1 reconstruit | Scene_Intro | 2 315 | 0,019 / 0,032 / 0,057 | 0,395 / 0,499 / 0,804 | 0,415 / 0,522 / 0,821 | 0 |
| Reborn 19.5 reconstruit (mkxp-z de Reborn) | Scene_Intro | 1 749 | 0,037 / 0,049 / 0,083 | 0,506 / 0,609 / 1,292 | 0,544 / 0,657 / 1,324 | 0 |
| Uranium (port warmwinter + assets d'origine) | sélection de langue | 154 | 5,11 / 6,14 / 7,80 | 1,22 / 1,57 / 2,17 | 6,36 / 7,59 / 9,21 | 6 GC, 8 ms |

Déterminisme : même graine → mêmes tirages et même état ; graine différente → tirages
différents (kit v21.1 et Uranium vérifiés).

## Non traité

- Pokémon SDK (formats VD `.dat`, scripts YARB) : hors périmètre de cette étape.
- Archives chiffrées RGSSAD/RGSS2A/RGSS3A : outil externe requis (voir `docs/usage.md`).
- Démarrage des jeux reconstruits sous mkxp-z : dépend de la compilation du moteur.
