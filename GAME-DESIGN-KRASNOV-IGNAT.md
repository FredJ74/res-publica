# Krasnov — maison et personnage d’Ignat Lykov (15 novembre 2026)

Décision explicite du game designer : la maison de bois à l'angle droit de la rue des terrains est celle d'un fonctionnaire à la retraite, idéaliste, défenseur sans réserve de l'État fort et du collectivisme.

L'identifiant et le nom déjà référencés dans le jeu restent `maison-krasnov-terrains` et **Ignat Lykov** : il ne faut pas créer un second Ignat. Son ancienne description provisoire comme trappeur est remplacée.

Décor : affiches collectivistes ; photo d'Ignat inspectant les résultats de la moisson avec les agriculteurs du kolkhoze, à côté d'une moissonneuse et d'un tracteur avec benne de blé. Portrait : cheveux blancs dégarnis, visage anguleux, petites lunettes rondes, barbichette. Images fournies par Fred : `images/Sovarka/Krasnov/Krasnov_maison_ignat_interieur.webp` et `images/Sovarka/Krasnov/Ignat.webp`.

**Dialogue** : un invité PJ peut critiquer le système. Ignat ne l'expulse jamais pour cela ; il développe calmement, longuement et avec pédagogie les avantages du modèle selon ses convictions. Il reste hospitalier même face à la contradiction. Pas de nouveaux effets de jeu, sanctions, dénonciations ou mécaniques décidés.

La maison conserve les ordres existants (hospitalité, trinquer, dormir) et les besoins/quantités serveur existants : seule la représentation et la personnalité changent.

Vérifications : tests statiques et intégrité du contenu WebP à vérifier sur la branche ; recette connectée et déploiement à contrôler séparément.

## Reprise du 24/11/2026 (mission Purge, point 1.1)

PR #993 et #994 (ChatGPT, 15/11) reprises sur main : le personnage, les images (`images/Sovarka/Krasnov/Ignat.webp`,
`Krasnov_maison_ignat_interieur.webp`) et la règle « fonctionnaire à la retraite, jamais trappeur » étaient déjà sur main
(point 27 de `GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md`). Seule la règle de dialogue ci-dessus (critique du système :
jamais d'expulsion, explication calme et pédagogique) manquait : elle est ajoutée à la fiche `ignat_lykov`
(`api/_pnj-personnalites.js`). Le reste des deux PR (anciens chemins d'images, ancienne fiche) est périmé et n'est pas repris.
