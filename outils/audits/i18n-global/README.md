# Audit internationalisation — mode d’emploi

Cet outil ne traduit rien et ne modifie ni le jeu, ni les catalogues, ni Supabase.
Il inventorie les sources suivies par Git, les analyse avec Acorn/parse5 et ne
charge dans un VM isolé que les ressources déclaratives et `data.js`. Aucun ordre,
module métier ou endpoint serveur n’est exécuté. Aucun secret n’est nécessaire.

## Reproduire

Node 22 ou supérieur ; dépendances verrouillées dans ce dossier :

```sh
npm ci --ignore-scripts --prefix outils/audits/i18n-global
node --test outils/bancs/banc-audit-i18n-global.cjs
node outils/audits/audit-i18n-global.cjs --output /tmp/hg-i18n-apres
node outils/audits/audit-i18n-global.cjs --output /tmp/hg-i18n-suivant --previous /tmp/hg-i18n-apres/tableau-de-bord.json
```

Le premier audit publié est dans ce dossier. `--output` empêche d’écraser ce témoin.
Les fichiers JSON volumineux sont compressés en gzip déterministe, lisibles par
`gzip -dc`, `zlib.gunzipSync` ou Python. Pas de date variable dans les résultats.
Le SHA de HEAD et les empreintes du contenu analysé sont distincts : un commit de
documentation change le premier, pas l’empreinte du corpus.

- `tableau-de-bord.json` et `TABLEAU-DE-BORD.md` : synthèse, neuf langues et domaines.
- `inventaire.json.gz` : texte unique, mots, occurrences, fichier/ligne, pays,
  pièce et ordre quand connus, niveau de certitude, ressources et raccordements.
- `ressources.json.gz` : clés centrales, matrices de neuf colonnes, tables locales,
  français et traductions exactes, problèmes de variables, copies françaises.
- `priorites.json.gz` : langue manquante ou raccordement à vérifier, priorité et justification.
- `sources.json.gz` : fichiers et SHA-256, SQL et sites de templates dynamiques.
- `exclusions-appliquees.json.gz` : motifs, références de littéraux techniques écartés.
- `variation.json` : différences lorsque `--previous` est fourni.

## Interpréter sans surestimer

**Aucun taux n’est un pourcentage certifié de tout le jeu.** Le corpus de rendu
statique est identifié, pas validé par visite exhaustive en session. Ses textes
représentent des unités d’extraction (y compris fragments et templates), pas
nécessairement des phrases complètes. Les autres candidats ne sont pas dissimulés :
leurs textes et leurs volumes restent dans les classes séparées du rapport.

Le dénominateur contient les textes uniques ayant au moins un chemin de rendu
statique. Le taux « raccordé » est un **plancher de preuves reconnues par cet
extracteur** : clé explicite avec même français, traducteur exporté ou wrapper
transparent, guide accepté par son garde d’intégrité, ou description d’ordre
reconnue dans les huit langues par le résolveur existant dans son pays. Il sous-estime notamment les annotateurs
DOM, les clés construites et les adaptateurs narratifs. On ne peut donc pas déduire
que son complément est entièrement à traduire. Une ressource disponible ne suffit
jamais à compter un écran comme traduit. Les mots « à traiter/vérifier » regroupent
traduction, vérification du branchement et cas non reconnus par l’analyse statique.

Les correspondances de ressources ignorent uniquement les espaces et la forme
Unicode NFC, pas la ponctuation, les accents ou les variables. Les variables
`{{nom}}`, `{nom}`, `%s` et `%d` sont contrôlées. Une copie du français n’est pas
une traduction prouvée, sauf sigles neutres justifiés dans `exclusions.json`.
Cette règle conservative signale aussi certains vrais noms propres : à relire.
La présence d’une traduction différente ne démontre ni fidélité ni qualité native.

Les domaines sont attribués heuristiquement aux fichiers/contexte et se recoupent.
Le total global est dédupliqué par texte (SHA-256 du texte normalisé), pas par clé.
Les occurrences gardent les conditions géographiques, mais ne sont **pas** un
nombre d’apparitions observées en session. Le compteur de mots utilise une règle
Unicode documentée dans le script : apostrophes/tirets internes unissent un mot,
variables ignorées. Les volumes serveur utilisent les espaces, donc restent séparés.

## Sources serveur et confidentialité

`serveur-agregats.json` provient d’un SELECT daté en production, limité aux
agrégats de sept champs de référence statiques. Sa requête est conservée et
rejouable en lecture seule par une personne autorisée ; l’audit hors ligne ne la
relance jamais. Les sommes ne sont pas ajoutées au corpus : doublons possibles,
langue et affichage non certifiés. Pas de noms de joueurs, de contenu de messages,
de progression ou de mémoire conversationnelle exportés. Les tables de données
libres et privées sont décrites comme périmètre dynamique non dénombrable, sans
supposer que leur langue est le français. Les textes SQL sont des candidats du
dépôt, pas la preuve d’une définition encore déployée.

## Étendre les preuves et préparer les chantiers

1. Examiner les priorités 1 (ordres/refus/entrée dans le jeu), puis 2 (interfaces),
   3 (enquêtes/récits), 4 (descriptions secondaires). Confirmer l’usage en jeu.
2. Corriger la classification par une preuve et un test, sans supprimer les cas
   difficiles. Toute exclusion manuelle exige identifiant, motif et source.
3. Lors d’un lot de traduction, comparer les deux exécutions : textes ajoutés ou
   retirés, raccordements changés, mots non confirmés et évolution des exclusions.
   `sameMethod` signale aussi toute modification de l’extracteur ou de ses dépendances :
   ne pas confondre un progrès de détection avec un nouveau lot de traductions.
4. Enrichir les adaptateurs de preuve pour les annotateurs DOM et appels de clés
   dynamiques avant de présenter un taux comme une mesure utilisateur réelle.
5. Faire relire les traductions dans chaque langue ; c’est un contrôle distinct.

La CI vérifie l’extracteur sur des contre-exemples, régénère l’inventaire et garde
les artefacts. Elle ne doit pas échouer parce qu’un texte français manque encore
de traduction : son rôle est de rendre cette dette visible. Une erreur de parsing
ou de chargement est en revanche bloquante et n’est jamais silencieusement ignorée.
