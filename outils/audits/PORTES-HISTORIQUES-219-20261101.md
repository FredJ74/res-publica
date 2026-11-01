# PR #219 — qualification des portes historiques encore visibles

Périmètre : reprise du 01/11 à partir de `4c2fbd5e`, main `ddb72dbd`.
Cette analyse complète les preuves intégrées antérieures ; **elle n'est pas un
nouveau test sur le catalogue 1012 + 95**, encore interdit par les référentiels
manquants. Aucun droit serveur n'a été rouvert pour faire disparaître un écart.

## Authority sur le baseline : 17 écarts, causes séparées

Le contrôle du 01/11 relève 16 noms absents et une nouvelle surcharge absente.
Deux noms (`club_salaires_fixer`, `club_transfert_conclure`) sont livrés par #300/
#301, avec leurs définitions dans le delta et les empreintes du relevé 1012.
Les **15 autres formes** sont des commandes du paquet préparé #219 : cibles,
douane collective, corruption avec reçu, effectifs, groupe PJ lire/rejoindre/
quitter, navigation intérieure, trois commandes d'organisations, déploiement
privé, rappel radio, unités administrables et transport atomique.

`crime_corrompre_douanier(p_pa,p_cost,p_requete)` n'est pas un paramètre client
mal nommé : la surcharge UUID est créée par
`20261031115816_transport_corruption_passage_serveur.sql:46`, avec EXECUTE
`authenticated` à la ligne 65. L'ancienne surcharge à deux arguments reste un
chemin distinct. Le contrôle baseline doit rester rouge tant que le baseline
n'observe pas ces contrats ; leur préparation ne prouve pas leur déploiement.

## Écarts du contrôle RPC sur l'ancien décor intégré : preuves d'appel

La preuve antérieure `hg219-validation-auth27.json.gz` est antérieure à #300.
Ses deux fonctions clubs « absentes » sont expliquées par le delta depuis cette
coupe ; ne pas les présenter comme absentes du vivant actuel. Les neuf autres
formes se classent ainsi, par examen des scripts actuellement chargés :

| Porte | Appel actuellement trouvé | Qualification / suite |
|---|---|---|
| `tournee_creer` | `plateau-actions-illegales-rumeurs.js:4987`, `{p_id,...charge}` ; `charge` explicite ligne 4974 | Spread non résolu par le détecteur, **pas** une preuve de requête incomplète. Aucun paramètre supprimé, aucun contrôle désactivé. |
| `chantier_travailler` | `plateau-justice-economie.js:12161`, confirmation HTML ligne 12135 | Appel d'écran réel ; l'ancien décor en refuse EXECUTE. Dépendance immobilière à vérifier avec Claude sur le catalogue installé, ne pas rouvrir arbitrairement le droit historique. |
| `vendre_materiaux_chantier` (sans reçu) | `supabase.js:5674`, helper `sbVendreMateriauxChantier` | Aucun appel du helper trouvé dans les autres scripts de jeu examinés. L'ancienne surcharge est fermée ; la nouvelle avec reçu n'est pas contournée. Compatibilité non supprimée aveuglément. |
| `vendre_fonds_commerce` | `supabase.js:3001`, `sbVendreFondsCommerce` | Helper explicitement non appelable par un client, faute de consentement acheteur ; aucun autre appel trouvé. Refus de sécurité attendu. |
| `tracts_appliquer_effet_pop` | `supabase.js:4484`, `sbTractAppliquerEffetPop` | Aucun appel du helper dans les autres scripts examinés ; garder la fermeture. |
| `militaire_subtiliser` | `supabase.js:4606`, `sbMilitaireSubtiliser` | Aucun appel du helper trouvé ; l'écran utilise `sbMilitaireSubtiliserTenter` (`plateau-actions-illegales-rumeurs.js:1670`) et sa commande complète. |
| `tracts_reclamer_don` | `supabase.js:4874`, `sbTractsReclamerDon` | Aucun appel du helper trouvé dans les autres scripts examinés. Ne pas accorder EXECUTE pour satisfaire un détecteur statique. |
| `creer_placement_national` | `supabase.js:5568`, `sbCreerPlacementNational` | Aucun appel de l'ancien helper trouvé ; l'écran utilise `sbCreerPlacementNationalSecurise` (`plateau-justice-economie.js:4348`). |
| `batiment_caisse_mouvement` | helper `supabase.js:4523`, appelé par `mouvementBoisAtelier` (`plateau-communication.js:310`) | Aucun appel de `mouvementBoisAtelier` trouvé ailleurs. `crediterCaisseRedaction` ne fait qu'un test d'existence du vieux helper puis utilise la porte crédit adossé (`plateau-justice-economie.js:12529`). Ne pas confondre ce test avec l'exécution du vieux mouvement. |

« Aucun appel trouvé » concerne les scripts du jeu versionnés, pas une preuve
qu'une fonction globale ne peut pas être invoquée depuis une console. Ce sont
les **droits serveur fermés** du décor antérieur qui empêchent ces appels de
muter les données. Les droits restent à réexaminer après le paquet sur le clone
fidèle, avec les contextes `authenticated`, pas au rôle postgres.

## Referential : cinq échecs non masqués

1. `ordres_couts` : capture réelle 438 triples, plan de réconciliation préparé
   vers 452 (`LIVRAISON-COUTS-219-20261031.json`). L'ancien témoin posé et la
   déclaration hors ligne restent datés ; ne pas les remplacer par le résultat
   souhaité. La migration est dans les 95, pas livrée.
2. `postes_nommes_regles` : les champs du générateur concordaient avec la mesure
   ciblée 1003 (694f117ace57b0b1), mais la déclaration hors ligne est plus ancienne.
   L'empreinte complète des 18 lignes sous le tri réel reste à vérifier à partir
   de la capture privée demandée, sans transformer la mesure ciblée en copie des
   lignes.
3. `miroirs_chantiers` : le générateur actuel atteint sept paliers, mais son
   contenu complet ne concorde pas avec la référence 1012. Ne pas le substituer
   aux sept lignes vivantes.
4. `miroirs_entreprises` : INSERT SQL corrigé (colonne obsolète), mais 40 recettes
   générées contre 52 vivantes ; différence de contenu toujours conservée.
5. `offres_emploi_bne` : le générateur actuel donne zéro offre, comme le relevé
   vivant ; le seed et la déclaration datée en portent encore sept. La mise à
   jour générée de l'état canonique attend le paquet de captures cohérent.

Le passage à 12/12 exige ces observations cohérentes et, pour les contrats #219,
la validation du paquet puis la réextraction du catalogue réellement livré.
Aucun résultat global 12/12 n'a été produit ici.
