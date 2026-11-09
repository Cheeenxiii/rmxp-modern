# Architecture

## Pipeline

```
unpack  jeu (Data/, Scripts/) ──► projet texte (YAML + .rb)
build   projet texte ─────────► jeu (Data/, Scripts/)
```

Chaque étape est une commande de `bin/rmxp` ; `lib/` est découpé pour qu'une famille de
jeux puisse avoir ses formats sans contaminer le reste.

## Fichiers

| Fichier | Rôle |
|---|---|
| `bin/rmxp` | interface en ligne de commande |
| `lib/rmxp/project.rb` | arborescence d'un jeu : `Data/`, `Scripts/`, manifeste, commandes `unpack`/`build`/`roundtrip` |
| `lib/rmxp/codec.rb` | conversion Marshal ↔ arbre YAML, classes inconnues, références partagées |
| `lib/rmxp/scripts.rb` | `Scripts.rxdata` ↔ un `.rb` par section, avec l'ordre et les identifiants |
| `lib/rmxp/rgss.rb` | types RGSS à format Marshal propre (Table, Color, Tone, Rect, Font) |
| `lib/rmxp/check.rb` | compilation statique des scripts et des fragments d'événements (Prism) |
| `lib/rmxp/mt19937.rb` | MT19937 et conversions CRuby (`rand`, `rand(n)`, `rand(range)`, flottants) |
| `lib/rmxp/preload/` | shim RNG et sonde de scénario chargés par mkxp-z |

## Représentation texte

`Codec` transforme un graphe Marshal en un arbre de Hash/Array/String/nombres, puis en
YAML. Il préserve :

- la classe de chaque objet et tous ses ivars, dans l'ordre de déclaration ;
- les références partagées et les cycles (`__id__` / `__ref__`) ;
- l'encodage des chaînes (`__str__` + `__enc__`, ou `__b64__` pour le binaire) ;
- les types RGSS à payload binaire, conservés tels quels (`__blob__`) ;
- les `Time` (via leur Marshal interne, `__time__`).

La règle de vérification est la stabilité de l'arbre : `to_tree(from_tree(tree)) == tree`.
L'égalité octet pour octet est mesurée et visée, mais pas garantie : Ruby 1.8 (RMXP)
sérialisait les flottants avec plus de chiffres que Ruby 3.

### Classes inconnues

Les données RMXP référencent des classes que l'outil n'implémente pas. `load_bytes`
relit l'erreur de Marshal pour définir des classes vides, puis essaie les superclasses
possibles quand Marshal signale un sous-type de `Array`, `Hash` ou `String` (il ne dit pas
laquelle). Les classes à format Marshal propre (ex. `OrderedHash`, `WordArray`
d'Essentials, `MonDataHash` de Reborn) sont conservées comme blobs opaques.

Les fichiers d'un même jeu ne s'accordent pas toujours sur la forme d'une classe (deux
builds ont pu la sérialiser différemment). Les classes créées sont donc oubliées entre
deux fichiers : chaque fichier obtient la forme dont il a besoin.

### Fichiers non reconstituables

Quand un fichier ne peut pas être chargé, `unpack` le copie octet pour octet dans
`data/<fichier>.bin` et le marque `opaque` dans le manifeste. Cela couvre les `.dat`
binaires maison d'Essentials v16/v17. Le build les recopie tels quels : l'aller-retour
reste fidèle, ils ne sont simplement pas lisibles.

## Scripts

`Scripts.rxdata` est un tableau Marshal `[identifiant, nom, source zlib]`. `scripts.rb`
extrait chaque source en `.rb` et `scripts.yml` garde l'ordre et les identifiants.
Pour les jeux à scripts externes (Reborn), `Scripts/` est copié sous
`scripts_tree/` et recopié par le build ; `Scripts.rxdata` suit le chemin normal.

## Déterminisme

`mt19937.rb` reproduit le générateur de CRuby (bits bruts, `Kernel#rand`,
`Random#rand`, plages entières et flottantes) : vérifié sur des millions de tirages
contre CRuby. `preload/deterministic_random.rb` remplace `Kernel#rand`, `srand`,
les méthodes de classe de `Random` et `sample`/`shuffle` dans mkxp-z.
`preload/scenario.rb` mesure les frames et écrit un dump d'état ; il est chargé par
`test/headless_test.rb` (mkxp-z sous Xvfb, `SRCDIR` = dossier du jeu).

## Ce qui n'est pas ici

- Déchiffrement d'archives : outil externe (`RPGMakerDecrypter`).
- Formats proprement dits (lecture RGSSAD, VD/YARB de PSDK).
- Migration de syntaxe et exécution des jeux reconstruits.
