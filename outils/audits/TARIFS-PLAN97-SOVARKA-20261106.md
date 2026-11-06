# Photographie historique du plan 97 : ajouts Sovarka

Base examinée : main b061fe2c. Le catalogue courant a 482 triplets ; la projection
historique avant correction en conservait 472 au lieu de 461. Comparaison du générateur
réel avec la coupe 40606289 : exactement 11 ajouts, aucun retrait. La photographie
historique ne doit pas changer ; ni sa migration ni son empreinte ne sont modifiées.

| Source data.js | Ordres nouveaux (PA / FR) | Commit d'introduction |
|---|---|---|
| salon Novomirsk, vers 6950 | salon_coupe 0/0 | b86a4fa4 (#493) |
| Pharmanov, vers 7083 | pharmacie_medicaments 0/0 | d87c4c06 (#501) |
| poissonnière, vers 7107 | poissonniere_poisson 0/0 ; contrebande_poissonniere 1/0 | ed5f2f39 (#525) |
| droits d'exploitation, vers 1870 et 10218–10244 | sovarka_cession 1/0 ; sovarka_commerces_libres 0/0 ; sovarka_demander_local 1/0 ; sovarka_dossiers_commerciaux 0/0 ; sovarka_retirer_droit 1/0 ; sovarka_signer_attribution 1/0 ; sovarka_terrain_municipal 0/0 | 7262fedd (#521) |

Les menus du Grand Hôtel ne créent pas un douzième triplet distinct. Les sources
métiers, les tarifs et les migrations Sovarka restent intacts. Le préparateur
contrôle chaque nouveau triplet puis l'exclut uniquement de la projection historique,
comme les ajouts pétrochimie/naval/véhicules déjà déclarés.

Résultat : 461 lignes et MD5 `0ffc6e1caad1f58114eeba150d3d5f48` conservés ;
catalogue courant 482. Trois tests Python passent : ordre/empreintes, mutations
migrations, et 44 contre-épreuves tarifaires (11 ordres × absence/prix/PA/doublon).
Aucun résultat CI distant observé. REST GET est refusé dans cette session.
