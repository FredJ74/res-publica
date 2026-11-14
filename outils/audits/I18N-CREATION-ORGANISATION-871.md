# #871 — choix et formulaire de création d’organisation

PR #934, deux fenêtres : `ouvrirCreerOrga` et `ouvrirFormulaireOrga`. 22 clés / 176
traductions étrangères ajoutées à `organizationCreation`. Quatre types déjà traduits
sont réutilisés dans le parcours normal (32 traductions). Les deux autres types
restent exclus du choix ; leurs appels directs existants conservent les libellés
déjà disponibles et sont testés séparément (16 traductions, pas de nouvel accès).
Les trois appellations propres au local loué (Secrète / presse / commerciale)
restent distinctes des types généraux. Les exemples Loge du Grand Nord / Parti du
Progrès gardent leurs noms. La notification du maximum n’est pas refaite (#924).

Le français entier, la casse, les espaces, montants, unités et variables restent
identiques. Les quatre conditions de blocage et leur priorité restent les mêmes ;
les valeurs affichées sont les mêmes, sans conversion monétaire. Le formateur de
prérequis, les filtres de types, les identifiants des options et la confirmation
métier ne changent pas. Les cinq aides nouvelles ne produisent que des marqueurs
pour le moteur commun. Aucun autre moteur, callback métier, RPC ou sauvegarde.
Les classes mobiles existantes sont réutilisées ; pas de CSS nouveau.

119 tests Node ciblés passent ; 116 tests existants correspondants sont verts sur
main. Le fichier entier est comparé par AST après retrait des seules adaptations
de présentation ; confirmation et autres fonctions intactes. Neuf langues et
variables complètes, français de référence exact, exemples et six types vérifiés.

Chromium : 756 bascules / 28 états / neuf langues / 320/390/1280. Français,
conditions, contrôles et appels comparés à main ; nom, description, corps de métier,
curseur/focus/position préservés ; pas de dépense, requête ou événement de saisie
supplémentaire. Les boutons bloqués le restent ; clic et clavier transmettent une
seule fois le même type. Types exclus toujours absents. Cas décimaux FR/PSK,
priorité des quatre blocages, repli français, libellés source modifiés, fermeture
et fenêtre voisine vérifiés. Ancien tableau : 999 bascules également vertes.

## Raccordement des bancs à la CI

Une substitution de préfixe dans les commandes avait laissé les homologues Node à
la place de certains nouveaux bancs navigateur. Ceux-ci avaient passé les essais
locaux et publics des lots précédents, mais n’étaient pas exécutés automatiquement.
Les commandes des workflows comptes et organisations sont corrigées ; un test
vérifie les fichiers effectivement présents dans `run: node --test`.

Mesures, CI finale et production à terminer. Aucune donnée réelle lue ou modifiée,
aucune organisation créée réellement, aucune migration ou fonction serveur changée.
Pas de session PJ authentifiée, téléphone physique ni relecture native.
