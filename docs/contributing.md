# Contribuer

## Lancer les tests

Le test d'acceptation est l'aller-retour sur chaque jeu du corpus :

```bash
ruby test/roundtrip_test.rb chemin/vers/jeu [autre/jeu ...]
```

Chaque jeu est extrait, reconstruit et comparé. Sortie non nulle au premier écart.
Le corpus n'étant pas dans le dépôt, les chemins dépendent de votre installation locale
(voir `corpus/` dans AGENTS.md).

Pour un seul jeu, `bin/rmxp roundtrip chemin/vers/jeu` donne le même rapport.

## Ajouter un format

1. Reproduire le problème sur un fichier du corpus et regarder le message exact de
   `Marshal.load`.
2. Si c'est une classe inconnue : ajouter la classe à `Codec` (blob) ou au mécanisme de
   résolution dans `lib/rmxp/codec.rb`.
3. Si c'est un type à `_dump` propre : soit l'implémenter dans `lib/rmxp/rgss.rb` quand il
   doit être lisible, soit le laisser en blob quand ses octets suffisent.
4. Si le fichier n'est pas du Marshal : il doit ressortir `opaque`, jamais planter.
5. Relancer `roundtrip_test.rb` sur tous les jeux, pas seulement celui corrigé.

## Conventions

- Un comportement = sa doc dans le même commit.
- Petits commits, message d'une ligne, deux ou trois lignes si le pourquoi n'est pas
  évident.
- Pas de correction propre à un jeu dans le code : soit le format est générique, soit il
  va dans `TODO.md`.
- Le test qui compte est l'aller-retour (puis l'oracle), pas la couverture.
