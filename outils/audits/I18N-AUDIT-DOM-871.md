# #871 — reconnaître les annotations DOM sans gonfler les traductions

Le rendu #909 est traduit et vérifié dans Chromium, mais l’extracteur ne
reconnaissait que les clés HTML et notifications annotées. Ce lot reconnaît la
convention DOM commune, sans modifier les fichiers du jeu ni les ressources.

Preuve requise : affectation à `textContent`, clé littérale sur le même élément,
français symbolique identique au catalogue, variables JSON exactement égales aux
expressions du texte, puis application du moteur et du catalogue chargés sur la même page. Le moteur doit
transmettre le résultat d’i18next au texte ; un nom local qui le masque est refusé.

Pas de propagation entre appels métier, entre éléments ou entre branches
conditionnelles. Les clauses non reconnues restent explicitement non confirmées.
Le texte source symbolique et ses identifiants restent intacts, même lorsque les
noms des placeholders du catalogue diffèrent de la notation générique du corpus.

26 tests d’extracteur verts, dont deux nouveaux bancs : cas positifs fixes et
variables, conservation du dénominateur, et **18 contre-exemples** (cible, français,
clé ou valeurs erronés, variables absentes/extra, appel intercalé, clé conditionnelle,
moteur absent/non traduisant/masqué). Les 24 tests existants sont conservés.
Suite ciblée de 35 tests Node verte. Les deux bancs de recherche/confirmation sont
rejoués sur les fichiers publics de #909 : 324 bascules + 108 arrivées/972 bascules,
verts. Aucun fichier de jeu n’est modifié par ce lot d’analyse.

La mesure distinguera l’ancien et le nouvel extracteur sur le **même arbre source**,
ainsi que le même nouvel extracteur avant/après : aucune nouvelle traduction ne
sera attribuée à la méthode. Production de #909 consignée séparément.
Mesures, contrôles distants et livraison de l’outil à compléter.
