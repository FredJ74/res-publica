# Stabilisation Luthécia #135 — bilan du 24 octobre 2026

**CHANTIER NON TERMINÉ. Code préparé et testé, aucune livraison en production par cette intervention.** Les parties inachevées sont explicites ; ni les tests locaux ni le dépôt ne prouvent l'état vivant.

## Périmètre vérifié

Départ main e781074, puis intégration de main eb92a6e / PR136 (Ced, Grobras, football, baseline PNJ/sport). Aucune fusion de la consolidation ni restauration complète de l'ancienne branche. La PR134 est conservée : négociation, PA, débit uniquement à l'accord, moral plafonné, offres croissantes, version d'occupation, UUID et reprise. Ses 59 assertions PostgreSQL restent vertes. Seule la réplique sympathique acceptée est alignée sur le texte explicite de la mission.

| Constat | État exact |
|---|---|
| L01 | Corrigé localement : gabarit commun aux cinq parcelles, achat individuel conservé, pas d'accélération de construction. Images et caractéristiques inchangées. Deux tests dédiés ; branche indépendante disponible. |
| L02 | Corrigé localement : contexte serveur, présence/état, taux et coût vérifiés à nouveau, 1 PA, débit et décision atomiques, échéance persistante/versionnée, traitement idempotent au cron et à la visite. Aucune consultation périodique ajoutée. Installation bloquée. |
| L03 | Corrigé localement : PA, tirage, discrétion/santé, trace judiciaire et disparition dans la transaction ; crime antérieur conservé. Rejeu, rechargement et nouvelle occupation protégés. Pas d'arrestation automatique supplémentaire inventée. Installation bloquée. |
| L04 | Codé et testé sur PostgreSQL natif : consommation 1 000–10 000 FR, taux historique 12 %, durées existantes, dette et crédit national atomiques, UUID et échéances communes. Installation réelle restant à effectuer ; voir livraison terrain/banque. |
| L05 | Corrigé côté interface : demande travaux depuis le terrain refusée avant formulaire et coût, avec orientation vers la Banque Nationale. Revalidation à la confirmation. Helvetia reste distincte. Pas de test bancaire authentifié. |
| L06 | Corrigé localement : confirmerReconfiguration transmet un plan à chantier_commande, sans débit séparé ni chantier calculé/posé par le navigateur. Ancienne porte fermée par migration préparée ; reçu et reprise existants réutilisés. Installation bloquée. |
| L07 | Repris et adapté sur main : travailleur tiers, matériaux/prix, réaménagement, journée et réception communs ; panier borné et travail PNJ soldé au franc entier. Pour 100 m² : 290 FR + 700 FR, 10 FR conservés, 100 %. 1 006 superficies en parité JS/SQL et parcours de réception/rejeu. Aucun délai minimal raccourci. |
| L08 | Faille reproduite avec le vrai corps et un NULL SQL : retrait d'un lot tiers. Fermeture testée : aucun retrait arbitraire ni JSON client faisant autorité ; bail réel et droits contrôlés, libération légitime conservée. 18 assertions spécifiques, plus 62 du socle. Installation bloquée. |
| L09 | **Non corrigé** : bénédiction toujours locale. Ni attribution serveur ni consommation atomique des anciens jets implémentées dans ce lot. Pas de colonne ajoutée comme faux remède, pas de bonus réintroduit dans la négociation. Les décisions existantes doivent être appliquées aux circuits concernés ; ce reste n'est pas présenté comme uniquement un problème d'accès. |
| L10 | Le prévol réel 9801461 confirme les sept RPC absentes. Migrations existantes conservées et bancs organisations/équipements natifs exécutés avec succès ; prévol précis préparé. Aucun rejeu historique ni installation supposée. |
| L11 | Codé et testé : dépôt, compromis et titre par commande transactionnelle, crédit immobilier réel, archive/SAS de permis joint, rollback après débit/crédit, UUID et reprise. 58 assertions natives nouvelles. Pas encore installé ni vérifié authentifié ; voir LIVRAISON-TERRAIN-BANQUE-135-20261024.md. |
| L12 | Partiel : faux positif acteur_est_moi corrigé et testé ; fixtures SQL rangées et annulables, sans affaiblir Workflow ni retirer de cas. Workflow vert. Les divergences du baseline et les deux fonctions de trigger manquantes restent documentées ; aucune empreinte corrigée artificiellement. Réextraction officielle bloquée. |

## Implémentation et dépendances

Les commandes d'occupation sont communes aux terrains : aucun cas par numéro de parcelle. Les indices et bonus utilisés proviennent exactement de data.js et sont confrontés à leur source par un test. Les PNJ bêta existants, leurs caractéristiques de groupe, l'excommunication et l'affaiblissement sont relus. Aucun barème de résistance ni moteur de combat ajouté. Le jet commun existant est réutilisé ; l'appel légal ne tire aucun dé. Une modification du taux ou du coût affiché refuse avant paiement.

Les commandes conservent un UUID dans sessionStorage, le réutilisent après réponse perdue/F5, refusent un UUID aux paramètres différents, et relisent l'état actuel. Les réponses d'un ancien personnage sont ignorées. La révision du personnage change aussi pour l'appel légal : une sauvegarde CAS antérieure ne restaure pas les PA consommés. Le coût d'un refus de corruption et les sanctions de dissimulation sont ceux du code existant.

Le prélèvement des loyers de main avait évolué depuis l'ancienne branche. La migration préparée a été adaptée à ce corps, en conservant sa priorité bancaire ; elle n'écrase pas cette correction récente. Les gardes refusent les définitions inconnues. Les nouveaux lecteurs et commandes ne créent pas d'écriture de cache générale.

Installation à sélectionner **après** le prévol réel, jamais en rejouant tous les fichiers :

1. Identifier les parties déjà installées de PR112/114 et leurs dépendances de construction, financeurs, autorité, reçus, plan et travail. Le banc conserve les véritables états antérieurs dans des fixtures gelées, pas le baseline mouvant.
2. Examiner la série reprise 20261023090008–20261023090017, puis matériaux 20261023090710, compatibilité fonds 20261023091701, validation avant apport 20261023092229, quotas PNJ 20261023095517 et panier fixe 20261023161856. La fermeture legacy ne doit pas précéder son remplaçant. Les loyers dépendent des moteurs déjà présents, pas d'un second moteur financier.
3. Pour police/cadavres : 20261024072349 (référentiel privé, reçus, échéances), 20261024072634 (contexte et commande), 20261024072829 (traitement à la visite). Dépendances : négociation/jet PR134, payeur et fonds ordinaires, recherche, détention, PNJ/groupes, organisations, colonnes réelles. Installer avant les adaptateurs et le cron.
4. Pour les organisations, vérifier séparément les migrations 20261019064000/064500, 094425, 130213, 130951, 132431 et 132908. Leur succès local ne prouve pas leur compatibilité ni leur présence en production.

Le prévol en lecture seule est `outils/bancs/prevol-stabilisation-135.sql`. Après application autorisée par le connecteur : contrôle registre/signatures/ACL/RLS/triggers et empreintes métier, puis les quatre exports officiels de requetes.py, rendre.py, seeds.py, lecture du diff et contrôles. Rien de cela n'a été simulé comme une installation réelle. Les migrations restent préparées.

## Tests et limites

Les résultats et journaux sont dans `outils/audits/luthecia-20261024/`. Contrôleur client, contre-épreuves, bancs PostgreSQL du workflow, calendriers et pilote de fixtures exécutés. Les assertions répétées du socle ne sont pas additionnées comme des scénarios nouveaux.

Les identités, certaines notifications et services annexes de tests sont fictifs. PostgreSQL est natif ; les tests locaux ne passent pas par Supabase authentifié. Les pertes de réponse sont simulées. Les comparaisons de révision et de concurrence sont effectivement exécutées en base jetable.

Le contrôle global ne vaut pas feu vert : Classification, Baseline, Authority, Referential, Assemblage et Reconstruction restent rouges. Les 33 noms absents du baseline initial ne sont pas déclarés absents du serveur ; deux nouveaux contrats d'occupation préparés portent ce nombre à 35. La signature interne d'achat et les trois empreintes de référentiels restent signalées. Les triggers vers fermeture_definir_date_universelle et permis_depot_archive_proteger demeurent incomplets dans la photographie. Aucun fichier généré du baseline n'a été édité par cette intervention ; les changements de PR136 sont conservés intégralement.

## Livraison distante

Branche principale : `codex/stabilisation-luthecia-135-20261024`. Commits de correction : 52a5fd7, 6a38ffa, fa15223, 25f216d, 4576e72 ; intégration main 907815a ; rangement du décor Ced 0dc42fa ; protection de la révision ensuite. Branche indépendante L01 : `codex/parcelles-gabarit-135-20261024`.

Aucun accès Supabase exposé dans cette session. Les GET vers Vercel sont refusés au tunnel avec 403 : ce n'est pas un diagnostic de panne de l'application. SHA servi et déploiement non vérifiés. API GitHub GraphQL refusée ; les tentatives finales de PR et mise à jour du ticket sont tracées séparément. Aucun personnage réel utilisé, aucune donnée de production modifiée, aucune migration appliquée ou fusion dans main par cette intervention.

**Ni le lot sensible ni le chantier global ne sont prêts à être déclarés livrés.** L09/L11 restent des lacunes de code ; L04 reste partiel ; le prévol, l'installation, la réextraction et la recette authentifiée restent à faire. Aucune nouvelle décision de game design n'est inventée et aucune manipulation SQL n'est demandée au propriétaire.

### Derniers résultats

- 107/107 bancs client après PR136 ; 91/91 contre-épreuves.
- 30/30 bancs PostgreSQL du workflow après intégration de PR136. Le banc d'occupation a ensuite été enrichi jusqu'à 40 assertions réussies, dont la sauvegarde CAS et les UUID réutilisés avec des paramètres différents ; 59 assertions de négociation conservées et 18 assertions lots.
- Ced/football : 45 assertions natives ; calendriers Node : 11/11 ; pilote E2E : 69/69 sur fixtures, aucune session réelle.
- Globaux : 6/12. Le main e781074 de référence était à 5/12. Les contrôles rouges ne sont pas désactivés.
- Révision des sauvegardes : commit b0237c9. Branche indépendante des parcelles : aa240ad (versionnement du chargement data.js compris).

### Opérations GitHub effectivement tentées

Les deux créations de PR en brouillon ont été refusées : `Post https://api.github.com/graphql: Forbidden`. La mise à jour du ticket a aussi été tentée par l'API REST : `Post https://api.github.com/repos/FredJ74/res-publica/issues/135/comments: Forbidden`. Aucune PR ni aucun commentaire n'a été créé par cette session. Les branches et rapports sont toutefois poussés et leurs SHA distants contrôlés. Les descriptions et le commentaire prêts à publier sont conservés dans les annexes, avec `PUBLICATION.json`. Aucun résultat de GitHub Actions distant n'a été observé.

## Livraison terrain/banque de cette reprise

Commits poussés : `17d99f1` (moteur et interfaces), `d347cdb` (main 3b01469 préservé), `11ebd80` (dépôts/termes privés, courrier notarial, archives distinctes). Ordre exact des douze migrations et conditions : [LIVRAISON-TERRAIN-BANQUE-135-20261024.md](LIVRAISON-TERRAIN-BANQUE-135-20261024.md). Le prévol réel fourni est exploité ; aucun refus de connecteur ne bloque la livraison de code.

Dernière validation : 108/108 bancs client, 91/91 contre-épreuves historiques, 33 configurations PostgreSQL du workflow vertes (dont les deux configurations du banc bancaire et ses contre-épreuves), 47 assertions bancaires finales par configuration et 59 de négociation conservées, 5/5 mutants bancaires détectés, 69/69 tests E2E sur fixtures, 11/11 tests complémentaires jours civils/fontaine/placement. Le banc du cron conserve ses anciens cas et passe 20 assertions nouvelles, 45 au total. Les pannes après crédit/titre et débit/dette annulent toutes leurs contreparties.

Globaux : 6/12 ; Classification, Baseline, Authority (36 noms absents de la photographie et une signature inconnue), Referential, Assemblage et Reconstruction restent rouges. Workflow reste vert. Aucun changement du baseline par rapport au main intégré. Ces résultats sont documentés, sans les rebaptiser succès de production. Aucun compte réel, migration appliquée, fusion main ou déploiement par cette session.

## Complément de sécurisation du calendrier

Le contrôle de bout en bout a révélé un écrasement possible du titre par le cron historique des permis, qui réécrivait un blob lu avant une commande concurrente. La migration `20261024134528_permis_instruction_transactionnelle_acquisitions.sql` déplace l’instruction existante sous verrou serveur, avec archive/SAS/décision atomiques et jour commun. Le cron n’envoie plus de blob ni ne replie vers l’ancienne écriture sur panne. Un refus de PA après crédit de financement est également annulé intégralement par `20261024135353_acquisition_refus_rollback_financement.sql`. Les tests natifs passent 58 assertions bancaires/permis, les 59 de négociation restent conservées. Ces deux migrations complètent l’ordre d’installation ; elles ne sont pas appliquées ici.

## L09 — reste de code constaté, pas un blocage de connecteur

L’attribution de contact utilise 80 %, 1 PA et l’interdiction d’excommunication ; le bonus est +5 points, non cumulable, annoncé 24 h. L’ancien handler de salle utilise encore sa formule variable et ne doit pas être choisi comme nouvelle règle : les boutons de salle ont été retirés. La consommation réelle ne peut pas être sécurisée en ajoutant uniquement un champ ou une RPC qui le décrémente avant un jet local.

Les sept consommateurs actuels sont `confirmerVol`, `confirmerAchatArmeIllegal` (plateau-actions-illegales-rumeurs.js), `doTentativeEvasion`, `confirmerMenerEnquete`, `confirmerOrganiserFilature`, `confirmerOrganiserChasseHomme`, `confirmerVolMateriaux` (plateau-justice-economie.js). Ils appellent le consommateur synchrone de plateau-divers.js, puis tirent localement. Certains paient avant leur RPC d’effet ; l’échec d’évasion ajoute aussi peine/amende localement. Une consommation réseau séparée laisserait donc un bonus dépensé sans acte confirmé après perte de réponse, ou réutilisable si l’effet est rejoué. Aucun tel raccordement partiel n’a été introduit ni présenté comme sûr.

Il reste à réunir tentative, jet, consommation et effet dans les moteurs de ces familles, avec reçu d’acte et relecture, puis basculer l’attribution. La négociation PR134 demeure inchangée et aucun bonus client ne lui est réintroduit. **L09 n’est pas terminé et ce reste est une lacune d’implémentation, pas uniquement un contrôle vivant manquant.** Aucune décision supplémentaire de game design n’est demandée.

La dernière exécution après ce complément passe 109/109 bancs client, 33/33 configurations PostgreSQL, 91/91 contre-épreuves historiques et 6/6 mutants terrain/banque/calendrier détectés. Les globaux restent à 6/12. Les journaux `TERRAIN-BANQUE-*` correspondent à ce complément, sans comptes ni données réels.

### Reprise du 24 octobre — filature et bénédiction

Socle de filature préparé en privé, utilisant les payeurs institutionnels et le lecteur existants, avec receipt, autorité issue du registre et bonus consommé dans la transaction du véritable jet. Lecture des dernières 24h corrigée pour ne plus dépendre du jour personnel. Preuves natives et contre-épreuves dans `banc-filature-benediction-135-local.py` et `contre-epreuves-filature-135-local.py`. Détails et préconditions dans `BENEDICTION-135-20261024.md`. L09 reste en cours, sans exposition de commande ni changement client prématuré ; aucune vérification authentifiée ou installation Supabase revendiquée.

### Défaut de réception locale du vol de matériaux confirmé

Dans `confirmerVolMateriaux`, la quantité demandée était déclarée constante puis réaffectée après le retrait confirmé par `terrain_chantier_acte`. Le succès levait donc `Assignment to constant variable` avant le crédit d’inventaire. La variable est désormais réaffectable : l’interface utilise bien la quantité rendue par le serveur, jamais celle demandée. Aucun tarif, formule ou stock modifié par ce correctif. Trois tests exécutent le vrai corps de fonction : quantité serveur inférieure à la demande, refus/stock épuisé, et contre-épreuve avec l’ancienne constante. La contre-épreuve prouve le plantage après la mutation simulée, sans prétendre avoir exercé un joueur réel.

**Limite conservée explicitement :** le transfert de matériaux vers l’inventaire reste séparé dans le chemin historique ; ce correctif enlève une exception démontrée, mais n’est pas une preuve d’atomicité du vol ni de L09 complet. Il ne restitue ni ne modifie aucun objet réel perdu auparavant.

### Confirmation judiciaire et tirages absents

L’instruction d’enquête pouvait dévoiler une trace malgré le refus du moteur de détention, puis annoncer un succès. La migration préparée exige une confirmation réelle du registre et de la projection PJ, et verrouille la trace. Douze assertions sur PostgreSQL jetable reproduisent le défaut, éprouvent le succès, les refus et l’écriture ignorée, la concurrence et les contre-épreuves. Contre-espionnage simulé, non vérifié en production. La commande globale d’enquête avec paiement/jet/bonus demeure à raccorder.

La bénédiction refuse désormais aussi un tirage SQL NULL dans une migration complémentaire gardée. Le banc du socle passe de 41 à 44 assertions ; les trois tirages invalides annulent l’opération au lieu de consommer un PA avec résultat indéterminé. Ces composants restent privés. Détails, empreintes et dépendances dans `BENEDICTION-135-20261024.md`.

### Vérification de la reprise sur 2c35900

111/111 bancs client ; 37/37 configurations PostgreSQL du workflow, dont les contre-épreuves terrain/banque et filature ; 91/91 contre-épreuves historiques. Six contrôles globaux rouges restent Classification, Baseline, Authority, Referential, Assemblage, Reconstruction. Authority : 38 RPC non extraites, plus la signature commerce historiquement inconnue. La concordance des fonctions passe avec le moteur JS disponible ; une première exécution sans ce moteur avait correctement refusé de conclure. Aucun résultat ou fichier généré modifié pour blanchir un écart. `RESULTATS.json` est actualisé avec les preuves brutes et conserve son ancienne photographie.

L09 reste incomplet ; absence de raccordement des six autres actes et du navigateur. Aucune migration, fusion ou vérification authentifiée de production réalisée par Codex. Les nouvelles corrections de main jusqu’à f69ae9b sont intégrées sans changement des ambassades ou du Bureau de l’Emploi.

### 25 octobre — parcours terrain intégré et reprise après perte de réponse

Correction de reprise client `2e252dc` : le reçu de construction ne fait plus effacer l’intention avant relecture réussie du terrain courant et des finances. Le lecteur commun est réutilisé sans récursion. Dix tests ciblés et reproduction de l’ancienne perte d’intention.

Nouveau parcours PostgreSQL intégré des cinq parcelles et des quatre paliers : 324 assertions, dont deux libérations par négociation, compromis/permis, acte, construction, appels 35/35/30, lots, réception, rollback injecté, concurrence et nouvelle connexion. Aucun prix ni superficie uniformisé. Trois corruptions réelles du code SQL chargé dans la base jetable sont détectées. Résultats globaux de reprise : 111/111 bancs client, 39/39 configurations PostgreSQL, 91/91 contre-épreuves historiques, six contrôles globaux toujours rouges. L’augmentation Authority à 42 RPC non extraites inclut les audiences intégrées de main 6a249a1 ; ne pas masquer ce retard du baseline. Aucun baseline modifié à la main, aucune migration ni donnée réelle changée, aucune preuve authentifiée de production. Détails : `REPRISE-TERRAINS-135-20261025.md`.
