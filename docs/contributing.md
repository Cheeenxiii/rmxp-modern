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

Compilation statique :

```bash
bin/rmxp check chemin/vers/jeu
```

Audit du Ruby dynamique :

```bash
bin/rmxp audit chemin/vers/jeu
```

Harnais de combat headless (CRuby pur, sans mkxp-z) : il extrait les scripts du kit
v21.1 dans `tmp/battle/scripts`, charge Essentials avec des stubs RGSS et lance N combats
avec `Battle::DebugSceneNoVisuals`.

```bash
RMXP_BATTLES=30 RMXP_SEED=7 RMXP_LOG=tmp/battle/log.txt ruby test/battle/run_battles.rb
```

Scénario « vraie scène » (carte ou combat) avec mesure par frame :

```bash
RMXP_JOURNEY=map RMXP_UNCAPPED=1 RMXP_PROFILE=1 RMXP_PROFILE_SCENE=map \
  RMXP_WARMUP=1 RMXP_SECONDS=4 RMXP_WATCHDOG=60 \
  ruby test/headless_test.rb tmp/manual/kit-rebuilt tmp/manual/kit-rebuilt/Data 4 1
RMXP_JOURNEY=battle RMXP_UNCAPPED=1 RMXP_PROFILE=1 RMXP_PROFILE_SCENE=battle \
  RMXP_WARMUP=1 RMXP_SECONDS=4 RMXP_WATCHDOG=60 \
  ruby test/headless_test.rb tmp/manual/kit-rebuilt tmp/manual/kit-rebuilt/Data 4 1
```

Le scénario démarre une partie, marche sur la carte ou déclenche des combats
automatiques ; `RMXP_PROFILE_SCENE` limite le profil à la scène mesurée.

Deux exécutions avec la même graine doivent produire le même journal.

Données de combat en littéraux Ruby (à relancer après un changement de données) :

```bash
ruby test/battle/gen_battle_data.rb
RMXP_USE_LITERAL_DATA=1 RMXP_BATTLES=50 ruby test/battle/run_battles.rb
```

Extension CRuby Spinel (hybride expérimental, noyau de dégâts) :

```bash
ruby test/battle/build_hybrid_extension.rb
RMXP_USE_LITERAL_DATA=1 RMXP_SMALL_DATA=1 \
  RMXP_HYBRID_SO=tmp/battle/hybrid/damage.so \
  RMXP_BATTLES=1000 RMXP_SEED=42 ruby test/battle/run_battles.rb
```

Le journal doit rester identique à celui sans extension.

Assemblage pour Spinel (à faire évoluer vers un sous-ensemble plus petit) :

```bash
ruby test/battle/build_spinel.rb
vendor/spinel/bin/spinel tmp/battle/spinel_battle.rb -o tmp/battle/spinel_battle
```

Scénario headless (mkxp-z compilé dans `vendor/`, Xvfb installé) :

```bash
ruby test/headless_test.rb JEU DATA_RECONSTRUITE 2.0 1
```

Le script copie le jeu, injecte le preload RNG et la sonde, lance mkxp-z sous Xvfb avec
`SRCDIR`, et imprime le dump (scène, fps, médiane par frame, tirages RNG).

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
