# rmxp-modern

Transformer des fangames Pokémon basés sur RGSS (Pokémon Essentials, puis Pokémon SDK)
en dépôts modernes, puis en jeux recompilés en natif.

État actuel : **aller-retour des données Essentials** et **compilation statique**.
`rmxp unpack` extrait les données et les scripts d'un jeu en texte (YAML + `.rb`),
`rmxp build` les reconstruit, `rmxp check` vérifie que scripts et événements compilent.
Testé sur les kits Essentials v16.2 à v21.1, Uranium, Insurgence et Reborn.
Le générateur aléatoire déterministe (MT19937 compatible CRuby) est fourni dans
`lib/rmxp/mt19937.rb` pour l'oracle.

## Installation

Ruby 3.3 ou plus récent, aucune gem à installer (Marshal et YAML sont dans la stdlib).

```bash
git clone <dépôt> && cd rmxp-modern
bin/rmxp help
```

## Exemple

Avec un jeu Essentials dont le dossier `Data/` est accessible (jeu extrait, ou archive
RGSSAD déchiffrée au préalable) :

```bash
bin/rmxp roundtrip chemin/vers/le/jeu
```

Sortie typique :

```
Pokemon Essentials v21.1 2023-07-30      fichiers=109  octet=109 sémantique=0 opaque=0 scripts=ok
```

`roundtrip` extrait le jeu dans `tmp/`, le reconstruit et compare chaque fichier avec
l'original. Un jeu en archive RGSSAD doit d'abord être déchiffré (voir
[docs/usage.md](docs/usage.md)).

## Documentation

- [docs/usage.md](docs/usage.md) — porter un jeu pas à pas
- [docs/compatibility.md](docs/compatibility.md) — jeux testés et limites connues
- [docs/architecture.md](docs/architecture.md) — structure du code
- [docs/contributing.md](docs/contributing.md) — tests et ajout d'un format
- [TODO.md](TODO.md) — ce qui reste à faire
