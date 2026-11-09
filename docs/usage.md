# Utilisation

## Prérequis

Ruby 3.3+ (Marshal et YAML sont fournis avec Ruby). Rien d'autre à installer.

## Extraire un jeu

```bash
bin/rmxp unpack chemin/vers/le/jeu sortie/
```

Le jeu est lu depuis `jeu/Data/` et `jeu/Scripts/` (s'il existe). La sortie contient :

```
sortie/
  manifest.yml        liste des fichiers, formats et ordre des scripts
  data/               un fichier YAML par fichier de données
  scripts/            un fichier .rb par section de Scripts.rxdata
  scripts.yml         ordre, identifiants et noms des scripts
  scripts_tree/       copie de Scripts/ si le jeu en a un (Reborn)
```

`data/<fichier>.yaml` correspond à `Data/<fichier>` ; le nom d'origine est conservé
(par exemple `data/Actors.rxdata.yaml`). Les fichiers dont le format n'est pas
reconstituable (anciens `.dat` binaires d'Essentials v16/v17, données propres à un jeu)
sont conservés en l'état dans `data/<fichier>.bin` et signalés `opaque` dans le manifeste.

## Reconstruire un jeu

```bash
bin/rmxp build sortie/ jeu_reconstruit/
```

Écrit `jeu_reconstruit/Data/` (et `Scripts/` si présent). Les ressources graphiques et
audio ne sont pas concernées : pour rejouer le jeu, copiez-les à côté ou reconstituez
l'arborescence complète.

## Vérifier l'aller-retour

```bash
bin/rmxp roundtrip chemin/vers/le/jeu
```

Extrait, reconstruit et compare avec l'original, sans modifier le jeu. Le rapport donne :

- `fichiers` : nombre de fichiers de données traités ;
- `octet` : fichiers reconstruits à l'identique, octet pour octet ;
- `sémantique` : fichiers équivalents mais dont l'encodage Marshal diffère (Ruby 1.8
  écrivait les flottants avec plus de chiffres, par exemple) ;
- `opaque` : fichiers conservés en binaire (voir plus haut) ;
- `scripts` : `ok` si les sources et l'ordre des scripts sont identiques.

Code de sortie non nul au premier écart.

## Vérifier que le code compile

```bash
bin/rmxp check chemin/vers/le/jeu
```

Extrait le jeu, parse chaque script avec Prism et chaque fragment de script
d'événement (les commandes 355/655 consécutives sont recollées comme le fait
l'interpréteur). Rapport :

```
scripts: 402 (+0 erreur(s)), événements: 1112 fragment(s) (+0 erreur(s))
```

Code de sortie non nul s'il reste une erreur de syntaxe.

## Jeux en archive RGSSAD

`rmxp` ne déchiffre pas les archives (ce n'est pas dans le périmètre du projet).
Utiliser `RPGMakerDecrypter` (déjà cloné dans `vendor/` si vous suivez AGENTS.md) :

```bash
vendor/tools/rpgmakerdecrypter-cli jeu/Game.rgssad --output=jeu_dechiffre/
bin/rmxp roundtrip jeu_dechiffre/
```

## Jeux déjà en texte

Pour les jeux dont les scripts sont des fichiers `.rb` (Reborn, projets Essentials
v19+ issus du dépôt officiel), `unpack` conserve `Scripts/` tel quel et
`build` le recopie. `Scripts.rxdata` n'est réécrit que s'il existe.

## Limites connues

- Formats d'archives non gérés : RGSSAD, RGSS2A, RGSS3A (outil externe requis).
- Les `.dat` binaires d'Essentials avant v19 ne sont pas convertis en texte (voir
  [compatibility.md](compatibility.md)).
- PSDK n'est pas encore traité.
