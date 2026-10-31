# #219 — reconstruction canonique réussie, livraison toujours retenue

État du 31 octobre 2026. Branche `codex/groupes-universels-20261028`, PR #219. Main intégré : `3aa6ceef21d93653c55bc82bcc623db9a6e36937` (#281, #283 à #290 compris). Aucune fusion de #219, aucune écriture de production, aucun compte réel connecté, aucune commande de déploiement Vercel. Le statut distant de Vercel n'a pas été vérifié.

**Le blocage des exports et de la reconstruction est résolu. Le chantier n'est pas déclaré terminé : contrôles globaux 10/12, prérequis #233 absent du catalogue reçu et recette authentifiée isolée encore manquante.**

## Capture et périmètre réellement reconstruits

Le relais du commentaire 6542866046 a fourni quatorze fragments vérifiés par leur empreinte Git. Aucun fragment, identifiant d'objet ou export brut n'est publié dans le dépôt. La concaténation est complète ; l'écart entre caractères Unicode et unités UTF-16 est expliqué par onze caractères hors du plan de base, pas par une troncature.

Capture : snapshot `345374:345374:`, coupe **31/10/2026 11:35:45.899473 UTC** (12:35:45 à Paris), registre **1 003 versions**. Les quatre exports canoniques, les dix captures de seeds et les mesures des référentiels sont validés hors Git. Le registre inclut `genre_personnage_serveur_20261031100000`, version réelle `20261031113025` ; cette migration n'est pas rejouée.

PostgreSQL **17.6 natif**, `server_version_num=170006`, pas une approximation par le parser ni une base 16 présentée comme 17.6. Réassemblage issu des générateurs : **10 921 ordres**, **1 199 fonctions recompilées**, puis comparaison avec les quatre captures. Elle ne détecte aucun écart dans le périmètre déclaré du baseline : **371 tables et trois vues**, 42 séquences, 729 contraintes, 201 index autonomes, 79 triggers et 264 politiques. Les cinq tables déjà classées `hors_baseline` ne sont pas reconstruites ; les services Supabase et les ACL par défaut des autres propriétaires/de `storage` restent hors rendu. Ce n'est donc ni un clone de toute la plateforme ni une copie des données de bêta.

Deux CHECK produisent un parenthésage différent au retour DDL/catalogue : `pnj_car_bornes` et `pnj_metiers_profils_bornes`. Le comparateur vérifie leurs AST, en normalisant seulement l'associativité AND/OR. Les empreintes textuelles source et locale restent **distinctes et consignées** dans la preuve JSON. Des bornes ou opérateurs modifiés échouent aux contre-épreuves ; aucune empreinte observée n'a été réécrite pour obtenir une égalité.

## Corrections réalisées

- FK différées après les index autonomes UNIQUE : l'ancien ordre produisait réellement `42830`. La contre-épreuve reproduit ce refus, puis le nouvel ordre accepte le parent et refuse toujours un enfant orphelin.
- Conservation des rangs des colonnes visibles après suppression d'attributs. Les emplacements vides sont créés puis retirés, sans recopier de contenu supprimé.
- Révocation de l'EXECUTE natif de PUBLIC avant les GRANT capturés sur les fonctions à ACL explicite. L'ancien rendu créait 1 162 droits surnuméraires ; le rendu corrigé rejoint les 3 137 lignes capturées.
- Table Auth locale de fixture complétée pour les corps SQL qui consultent `email_confirmed_at`. Aucun compte ou service d'authentification réel modifié.
- Dix tables de seeds ajoutées, **474 INSERT** capturés ; les 82 tables anciennement versionnées restent identifiées comme anciennes, pas comme fraîchement réextraites. Les deux sources privées sont exclues. Provenance : `PROVENANCE-SEEDS-219-20261031.json`.
- Huit fichiers de miroirs auparavant vides raccordés aux générateurs existants. Vérification par régénération intégrale, pas par retouche des SQL. Les coûts de crimes devenus exclusivement serveur sont relus de leur déclaration authored existante ; aucun coût n'est inventé ni changé.
- Attentes structurelles du simulateur et du pilote communication recalculées depuis les captures indépendantes du rendu ; les attentes métier du monde neuf restent contrôlées. Les séquences IDENTITY sont désormais comptées par le simulateur.
- **131 fichiers appliqués attestés** archivés avec leur version réelle ; **65 préparations sans application attestée** conservées et rehorodatées après la coupe, sans les déclarer appliquées ni modifier leurs règles. Aucun rejeu global de ce répertoire. Correspondances et empreintes antérieures : `CLASSEMENT-MIGRATIONS-219-20261031.json`.
- Les **88 préparations #219** sont rehorodatées après la nouvelle coupe ; manifeste, bancs et générateurs raccordés. Les anciennes preuves restent inchangées, avec une table de correspondance séparée.
- Défaut réel d'intégration financière corrigé : l'ancienne adaptation du paiement aurait remplacé le corps actuel par une ancienne copie. L'adaptation conserve désormais le corps examiné, notamment les attestations acquisitions/permis et les fonds en transit, puis ajoute uniquement la quantité du transport. Empreintes strictes, rejeu idempotent et refus d'installation partielle testés.
- Décors de tests adaptés au découpage des fichiers générés, aux séquences explicites et aux sources archivées. Le test de l'achat historique épingle sa définition vulnérable antérieure afin de continuer à reproduire le défaut ; il ne prétend pas représenter la nouvelle porte publique d'achat.

## Installation et tests réellement exécutés

Le prérequis #233 `migrations/20261031113650_squatteurs_issue_combat.sql` est **absent** du registre et des fonctions de la capture. L'essai initial l'a constaté et s'est arrêté ; il n'a pas été présumé déployé. Il a ensuite été installé **explicitement, seulement sur la base jetable**, séparément des 88 migrations.

Les **88 migrations** s'installent dans une transaction indivisible sur cette reconstruction. Une fiche et un objet entièrement fictifs préexistent aux DDL : la preuve d'intégrité ne porte pas sur une table vide. Une erreur volontaire après les 88 écritures de registre annule les quatre catalogues complets, ramène le registre à 1 003 lignes et préserve la fiche. L'installation nominale suit sur la même base.

| Épreuve | Résultat | Portée |
|---|---:|---|
| Reconstruction/catalogue, compilation et installation du lot | réussies | PostgreSQL 17.6 réel ; périmètre public déclaré |
| Recette sur le catalogue entier après installation | **30/30** | Fonctions et triggers réels, aucun moteur remplacé ; rôle authenticated et JWT SQL fictifs |
| Suite groupes, transports, police, rounds, prison et radio | **379/379** | Décors PostgreSQL conservés, services périphériques de fixture explicités |
| Six contre-épreuves | **6/6 détectées** | Chacune exécute les 379 cas et échoue sur les assertions attendues |
| Bancs clients sur main intégré | **149/149** | Dont Workflow et bundle Vercel local |
| Pilote Chromium | **105/105** | Local, aucun compte réel connecté |
| Outillage catalogue | **35/35** | Dont trois nouveaux cas droits/attributs/CHECK et deux cas FK/IDENTITY |
| Relais canonique | **19/19** | Refus des données incomplètes, incohérentes ou privées |
| Achat historique, réception, concurrence, fret | **4 bancs réussis** | Respectivement 12 groupes, 31 groupes, 8 assertions, 51 assertions ; bases jetables |
| Contrôles globaux | **10/12** | Authority et Referential restent rouges |

Le banc supplémentaire du verrou inventaire de #283 passe également : **8/8 assertions SQL** sur PostgreSQL 17.6 jetable, sans appliquer ce verrou en production. Les nouveaux refus/resynchronisations du client et le retrait des écritures de quête de #290 sont conservés. Les versions de cache portent aussi le préfixe du verrou, sans perdre les groupes.

Les 30 cas sur le catalogue complet couvrent identités, groupes volontaires, cycles et distance, absence de mutation au refus, maintien des six protections de paiement immobilier, sorties/prison/coma, ouverture de combat PJ/PJ et PJ/PNJ, vrais rounds, rejeux sans double paiement ni double effet, tiers non engagé, lecture des cibles, radio sans équipement, détecteur sans policier, écrou et séparation réelle, doubles écrous et fermeture des portes internes. La recette n'injecte aucun substitut à ces fonctions. Elle ne couvre pas tous les parcours de l'application ni toutes les lignes vivantes des PNJ.

Sur **498 formes d'appel RPC** trouvées par l'analyse statique : 29 incompatibilités avant le lot, 17 après, soit **12 corrigées et zéro nouvelle**. Ces 17 signalements préexistent au lot ; ils comprennent des appels historiques fermés et des organisations/équipements non encore activés. Ils ne sont pas déclarés 17 bugs exécutables sans tracer leurs routes, ni effacés du rapport. Ils restent listés dans la preuve.

## Pourquoi les deux contrôles restent rouges

**Authority.** Le contrôle porte sur le baseline capturé de production, pas sur une projection inventée : les fonctions préparées de #219 n'y sont pas installées. Ses 19 écarts de raccordement et cinq références de signatures ne sont pas maquillés. Les signatures du lot sont effectivement validées sur le moteur local après installation ; cela ne transforme pas la production en base migrée. Les appels hors lot et leur accessibilité doivent rester distingués.

**Referential.** Des déclarations du 8–13 octobre sont périmées et trois miroirs ne sont pas surveillés en production. Les mesures fraîches ci-dessous sont rapportées sans remplacer les anciennes références pour verdir le contrôle :

| Référentiel | Mesure du serveur capturé | Générateur actuel | Conclusion |
|---|---|---|---|
| ordres_couts | 438 lignes ; `176fd337ce3a3d1a` | 427 triples ; `edec84347c32daed` | Écart de contenu réel à réconcilier avant toute régénération distante ; aucune suppression ou modification de tarif autorisée par ce rapport |
| postes_nommes_regles | 18 ; `694f117ace57b0b1` | 18 ; même empreinte | Contenu concordant ; ancienne déclaration et sentinelle à distinguer |
| ressources_economie | 18 ; `d65ae14b210eaac4` | 18 ; même empreinte | Contenu concordant ; ancien compte de 17 et sentinelle périmés |
| pa_bonus_differes | 10 ; `1c02ca809fdb9b8b` | même empreinte | Concordance |
| villes | 12 ; `d41051aa8bcafadd` | même empreinte | Concordance |

Les anciennes sentinelles restent réellement posées : ordres `6de4a84c58ed9b2b`, postes `a2993a8bc519ea01`, ressources `2c2a88b3833ca978`. Rien n'a été écrit pour les faire concorder. `miroirs_chantiers`, `miroirs_entreprises` et `offres_emploi_bne` changent également d'empreinte de génération ; faute de comparaison de contenu vivant dédiée, leurs anciennes attentes ne sont pas remplacées arbitrairement. Les exports canoniques de schéma sont complets ; ce point n'est **plus** un blocage de reconstruction.

## Livraison contrôlée restant à effectuer par l'intégrateur

1. Relecture de ces changements et des correspondances d'archives. Les 65 autres préparations ne sont pas un lot à appliquer et ne deviennent pas des dépendances implicites de #219.
2. Prévol **read-only** actuel du projet autorisé et comparaison au point de coupe : registre, corps/ACL/RLS, profils PNJ et tarifs effectivement nécessaires. Ne pas réinstaller le genre #281 ni les protections de fiche/achats déjà capturées. Les 17 autres signalements RPC et les écarts de référentiels restent visibles.
3. Valider explicitement le prérequis #233 et son ordre, puis le manifeste des 88 fichiers. `preparer-groupes-219.py` refuse les sources modifiées, collisions de versions, prérequis manquants et transactions internes. Ne pas appliquer les 65 préparations ni les nouvelles migrations #284/#285 par un glob ; elles demandent leur propre validation.
4. Après autorisation et prévol conformes seulement : livraison coordonnée SQL/client, puis réextraction canonique et contrôles. La transaction SQL est indivisible ; sur erreur, annulation intégrale. Après succès, retour arrière par correction en avant préparée, sans supprimer tables, reçus, PNJ ou données devenus actifs. Garder l'ancien client en repli jusqu'à la recette ; aucun rollback destructeur improvisé.
5. Recette authentifiée sur des comptes et ressources **réservés**, avec budget, stocks, contreparties et lieux isolés validés par l'intégrateur. Un leader et un accompagnant PJ plus PNJ : transport réussi/refusé/rejeu, détection avant interception, arrestation/remise à la police et prison, combat mixte/rounds/repli, radio même ville. Vérifier rechargement et absence de dépense partielle. Arnie reste limité à la consultation et n'est pas utilisé pour ces actes.

Aucun compte isolé ni accès GoTrue de recette n'est disponible ici ; aucune recette authentifiée réelle n'est annoncée. L'API GitHub GraphQL refuse `gh pr view` (`Forbidden`) : aucune fusion ni changement d'état distant de PR n'est revendiqué. Git permet les pushs de la branche ; les preuves sont livrées dans les fichiers de #219, sans exiger de manipulation SQL du game designer.

## Preuves et reprise

`preuves-canonique-219-20261031/` contient le rapport JSON du moteur, les résultats détaillés, journaux compressés et empreintes des sources. Les exports bruts restent privés hors dépôt. Reprendre ce rapport et `RELAIS.md`, sans refaire la reconstruction déjà réussie, sans redemander les quatre exports et sans ouvrir le chantier suivant tant que le périmètre #219 reste en validation.
