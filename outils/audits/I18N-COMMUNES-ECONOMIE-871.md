# #871 — descriptions partagées : banque, démarches civiles et services municipaux

Référence : main `651448e`, après les PR #879, #880, #882, #883 et #884.

## Manque confirmé, traductions réutilisées

La fusion réelle des ordres révèle 254 descriptions communes affichées, dont 54
absentes du catalogue commun. Ces textes ne sont pas tous dépourvus de traduction :
53 sont dans le catalogue Républia, un dans le catalogue propre à Sovarka.
Ils restaient français dans les autres pays malgré une traduction déjà disponible.

Ce lot déplace **18 lignes complètes et inchangées** du catalogue Républia au
catalogue commun : banque, virements, coffre autorisé, état civil, objets trouvés,
organigrammes, impôts et subventions municipales, location, divorce, actes notariés,
vente de matières premières et déplacement intra-empire. Le texte propre aux dossiers
d’escorts de Novomirsk et la ligne déjà dans le catalogue Sovarka sont exclus.

**144 traductions étrangères réutilisées ; aucune nouvelle traduction.**
Le français et chacune des huit autres colonnes sont identiques. Aucun doublon ni
retrait : l’union des deux catalogues conserve les 394 lignes originales. Le commun
passe de 205 à 223 lignes, Républia de 189 à 171, par reclassement. Toutes les
traductions livrées précédemment restent disponibles en Républia, sans changement.

Le résolveur universel existant les applique maintenant aux ordres partagés et aux
futurs pays. Ni moteur, ni données d’ordre, ni coût, PA, tarif, RPC, personnage ou
bâtiment modifié. Aucun contenu rédigé par un joueur n’est traité.

## Audit et preuves

L’audit appelait encore `ov.orders || room.orders`, qui masquait les ordres hérités.
Il utilise maintenant la fonction pure `ordresDeclaresDeLaPiece` de `data.js`, comme
le rendu. Une fixture vérifie héritage, ordres du contexte, exclusions, ajouts et
pièces exclues. La comparaison avant/après utilise cet extracteur corrigé sur les
deux états : la correction d’inventaire n’est pas comptée comme une traduction.

`I18N-COMMUNES-ECONOMIE-871-sources.json` contient les 18 lignes initiales.
Les bancs vérifient l’union entière des anciens catalogues, toutes les colonnes,
l’absence de doublons, le repli français, les pays actuels et un troisième pays
uniquement en fixture. Le modèle du banc Républia est également aligné sur la
fusion réelle : il ne présente plus les descriptions partagées comme exclusivement
nationales. Les champs métier et le catalogue Sovarka restent inchangés.

Chromium vérifie les 18 descriptions, trois pays, neuf langues et trois formats
(320, 390, 1280) : **1 458 descriptions rendues**, dont 972 dialogues tactiles.
Bascule de langue avec fenêtre ouverte, arabe RTL, formats longs, ordres accessibles
et bloqués, gratuits/payants, fermeture répétée, clic normal, absence de débordement,
conservation du brouillon, progression, PA et argent. Aucune RPC ou dépense ajoutée.

Relecture native, compte authentifié et téléphone physique non vérifiés. Les textes
sont repris des traductions existantes ; leur réutilisation ne constitue pas une
nouvelle certification linguistique. CI, production et mesures : relais et PR.

## Mesure contrôlée

Même extracteur sur `651448e` et le code du lot : corpus **inchangé**, 7 557 textes
et 50 565 mots source. Dans chacune des huit langues étrangères : **+18 textes
uniques entièrement raccordés, +225 mots source**, aucune ressource nouvelle.
C’est un gain de raccordement, pas de création de traductions. En anglais :
921 → 939 textes, 11 207 → 11 432 mots raccordés ; taux mots 22,16 → 22,61 % du
corpus statique identifié. Les autres langues gardent leurs écarts antérieurs.
Erreurs d’extraction : zéro. Le nouveau périmètre d’inventaire est appliqué aux
deux états ; aucune variation de méthode n’est ajoutée au gain. Voir le JSON
`I18N-COMMUNES-ECONOMIE-871-mesures.json` et le tableau de bord régénéré.

51 contrôles Node et le banc Chromium sont verts localement. Les essais authentifiés,
physiques et natifs restent non vérifiés. Statut CI/production : PR et relais.

Le banc historique du socle comparait aussi les anciens replis français : il
interdisait ainsi toute extension future du catalogue commun. Il conserve désormais
l’égalité exacte de toutes les traductions livrées et accepte seulement, pour un
ancien repli, la traduction explicitement déclarée dans le catalogue partagé.
La preuve séparée d’égalité intégrale des 394 lignes empêche toute réécriture.
