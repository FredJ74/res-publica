# Suite technique — successions, coffres et journal des ventes

**CHANTIER NON TERMINÉ. Code préparé et testé localement ; aucune activation de production dans cette intervention.**

Mission jointe lue intégralement, issues #94/#95/#96 et branches #93/successions examinées. Reprise depuis `3cfc428`, sans reconstruction des lots antérieurs. Dernier main intégré : `f2095de` (#97/#98 inclus). Résultats détaillés : `RESULTATS-CLOTURE-95-96-20261022.json`.

## Livraisons de code

### Autorisations successorales #95

`20261022184500_successions_decisions_autorisees.sql` ferme UPDATE/DELETE directs du navigateur sur les dossiers, avec policy restrictive en défense supplémentaire ; l'ouverture est limitée au vrai personnage. `succession_regler` reste réservée au service. L'héritier transmet uniquement son dossier, sa disposition et son acceptation/renonciation : le serveur verrouille, vérifie la convocation et l'échéance, enregistre une seule décision et fait avancer la cascade existante. Les convocations de coffres lient aussi l'UUID du bénéficiaire ; un homonyme ne récupère pas l'autorité. Le client utilise cette commande, sans remplacement global du JSON. Le cron compare sa photographie avant écriture et refuse une réponse PostgREST à zéro ligne : une réponse d'héritier plus récente n'est pas écrasée.

`20261022184501_successions_creation_verifiee.sql` contrôle également l'ouverture : identité et pays, statut/absence de décision préremplie, vraie masse bancaire verrouillée, fiscalité historique 33 % puis part État 90 % des droits, somme des parts et titres de terrains/fonds. Un solde inventé ou un bien d'autrui est refusé. Ces contrôles ne constituent pas une réservation financière intégrale jusqu'à la suppression différée : voir les limites ci-dessous.

21 assertions PostgreSQL : ancienne attaque reproduite avant correctif, tiers refusé après application locale, dossiers inventés refusés, vraie photographie acceptée, héritier légitime, cascade remplaçant/conjoint/absence d'héritier, expiration, rejeu et concurrence. Quatre tests client dédiés. La contre-preuve historique reste exécutée ; le banc de précondition #69 applique maintenant le vrai correctif et ses contre-épreuves, au lieu de rester sur l'état vulnérable archivé.

### Transmission des coffres #69

`20261022210000_coffres_ouverture_successorale.sql` photographie les vrais coffres dans l'ouverture du dossier commun, retire les fausses dispositions de coffre fournies par le client, crée la preuve d'origine privée et gèle l'accès. Testament et conjoint sont relus côté serveur ; aucun contenu privé n'entre dans le dossier public. Le formulaire de testament permet de désigner les vrais coffres ; une panne de catalogue n'est pas traitée comme un patrimoine vide. L'ouverture cliente reprend les dispositions réellement retournées par le serveur pour notifier les héritiers.

`20261022210001_coffres_reglement_successoral.sql` ajoute la branche coffre au règlement commun, dans sa sous-transaction et avec son marqueur existants. Après suppression du vrai UUID du défunt, transfert du même coffre, contenu, taille, arriéré et anniversaire au vrai héritier accepté ; pas de transit par un inventaire personnel ni de nouveau prélèvement. Sans héritier recevable, destruction définitive et terminaison du bail par le moteur existant, conformément à l'arbitrage de #69. Une panne d'archive annule uniquement sa disposition, conserve les objets concernés, nomme l'échec et permet la reprise. Deux règlements concurrents donnent une seule clôture.

Le garde de suppression refuse toujours un coffre sans origine successorale attestée. Le client conserve désormais sa session et ses caches si `sbDeletePersonnage` échoue ou rend un résultat indéterminé ; un changement de personnage pendant l'ouverture ou le DELETE ne nettoie jamais la session suivante.

Le banc coffres passe de 103 à **120 assertions**, avec les dépendances réellement préparées, plus les tests client/testament/suppression. Aucun coffre ou personnage réel touché.

### Journal des ventes #96

`20261022203000_journal_ventes_commerces.sql` utilise **les preuves existantes `ventes_snapshots` comme événements**, sans deuxième moteur d'achat. Un trigger d'insertion fige l'UUID du propriétaire et l'enseigne dans la transaction de vente. La preuve reste immuable ; une petite table privée conserve seulement les acquittements par vente. Aucun événement rétroactif fictif pour les anciennes ventes.

`journal_ventes_lire` ne prend aucun nom de propriétaire en paramètre : identité issue du compte authentifié. Dix ventes restent dix événements, une seule ouverture acquitte la photographie consultée, l'historique demeure. Une vente arrivée pendant cette consultation reste non lue. Prix, article, quantité et acheteur proviennent de la vraie preuve. Un renommage ultérieur du commerce ne réécrit pas son histoire.

Le journal et son badge existants affichent ces événements avec échappement HTML. Chargement/interaction/reconnexion via les lecteurs existants, aucun intervalle ; réponses d'un autre compte ignorées. Le rendu serveur n'est pas recopié dans les anciennes sauvegardes personnelles. 14 assertions PostgreSQL et un banc Chromium réel avec RPC simulées couvrent ces garanties. Le raccordement à un moteur distant ne produisant pas de `ventes_snapshots`, notamment une éventuelle version non archivée de la consommation sur place, doit être examiné au prévol ; il n'est pas présumé couvert.

### Concurrence et corrections indépendantes

Les corrections presse/chocolaterie #93 étaient déjà dans main, puis leur PR a été fusionnée par un autre intervenant (`717cd63`). Aucun doublon réimplémenté. Le test de portée avait une extraction textuelle vide ; il exécute maintenant `WORLD`/`BUILDINGS` et vérifie effectivement Luthécia, Port-Sainte-Marie et Montrouge. Cette correction est sur une branche indépendante. La vraie référence commerciale de la fontaine d'Angie et la définition distante de `consommer_sur_place_commerce` n'ont pas pu être lues : pas de validation fictive de consommation en production.

Les derniers correctifs bancaires #85/#87/#89/#90/#91 sont examinés et intégrés. La branche conserve son composant bancaire commun déjà préparé : deux sources, dates/statuts, plusieurs placements, reçus, contexte UID et relecture obligatoire. Aucun second formulaire ou débit ajouté. La régression de main est adaptée à ce composant réellement actif ; les trois épreuves SQL et les huit tests de comportement bancaire sont conservés. Le libellé Helvetia validé sur main est conservé. La préparation bancaire rangée par main dans `outils/migrations/` faisait réellement échouer le workflow : déplacement vers `migrations/20261022211000_placement_national_idempotent.sql`, références CI/bancs actualisées et **corps SQL strictement inchangé**. Ce déplacement n'est pas une preuve d'application distante.

Les reconnexions #97/#98 sont intégrées. Le parcours sur plateau conserve les gardes UID/personnage et ne rejoue aucun ordre après connexion. Les sorties refusées pour session expirée proposent le bandeau. Treize tests ciblés de reprise/reconnexion passent après intégration. Images WebP, décoration premium et huit originaux Krasnov préservés.

## Tests du dernier état

| Vérification | Résultat local |
|---|---|
| Contrôleur client | 113/113 bancs |
| Contre-épreuves historiques | 90/90 |
| Workflow PostgreSQL jetable | 31/31 bancs |
| Coffres | 120/120 assertions |
| Autorisations successorales | 21/21 assertions |
| Journal ventes | 14/14 assertions, dont concurrence réelle PostgreSQL |
| Calendrier et régressions main | 11/11 tests |
| Pilote E2E sans compte réel | 69/69 fixtures |
| API | 23/23 modules analysés |
| Décoration WebP | Conforme |
| Payload simulé | 256,5 Mo / 330 Mo |
| SQL préparé et YAML | Analyse syntaxique conforme |
| Contrôles globaux | **10/12**, Authority et Referential rouges |

Authority : une signature de moteur de rue renommé absent du baseline et 49 appels RPC non présents dans le baseline. Referential : trois empreintes historiques `ordres_couts`, `postes_nommes_regles`, `miroirs_entreprises`. Pas de baseline généré, empreinte ou résultat modifié pour masquer un écart. Le rangement SQL et l'enveloppe du prévol ont été corrigés, sans modifier le contrôleur. Les lancements interrompus par une intégration Git ont été écartés et la campagne relancée sur une arborescence résolue. Les bancs historiques utilisent l'adaptateur Node local du lanceur, pas JavaScriptCore natif.

## Limites et conditions de clôture

1. **Construction #94/#57 toujours inachevée** : dépôt de permis sous compromis avec paiement/archive/document atomiques ; occupation, combat et sécurité communs ; raccordement complet des deux anciennes portes lots/réaménagement ; financement #65 et chaîne organisations. Le moteur de journée/financement/réception antérieur est conservé et retesté, mais ces trous de code ne sont pas présentés comme un simple problème d'accès. Aucun lot construction activé.
2. **Succession générale pas certifiée intégralement sûre en production** : dossiers historiques potentiellement modifiés avant fermeture des droits, photographie testamentaire initiale encore partiellement construite par le client, absence de preuve de réservation/extinction atomique de toutes les contreparties financières entre ouverture et suppression, anciens chemins bancaires/placements et effets réels des triggers vivants à contrôler. Les nouveaux contrôles refusent les falsifications testées ; ils ne prouvent pas que toutes ces courses historiques sont fermées. Ne pas activer globalement sur le seul succès des nouveaux bancs.
3. **Dépendances #69** : déploiement coordonné de l'inventaire versionné, des primitives d'inventaire/locations/finances et de la sécurité successorale ; rapprochement explicite des anciens baux à 600 FR/jour (la préparation refuse leur conversion silencieuse). Relire l'ordre complet des migrations, pas seulement les deux dernières.
4. **Prévol réel obligatoire** : `outils/bancs/prevol-cloture-95-96.sql` et `prevol-finalisation-57-69.sql`, catalogues, signatures, RLS, droits, triggers, contrats, données historiques et canaux d'écriture. Exécution sur copie isolée représentative puis tests authentifiés autorisés avant activation. Arnie n'est pas autorisé à effectuer ces mutations par ses seules permissions de consultation.
5. **Accès bloqués** : Supabase et Vercel refusés au proxy avant le service (CONNECT 403), aucun connecteur exposé. API GitHub GraphQL et REST Forbidden, donc aucune nouvelle PR créée ni issue close. Git fetch/push et HTML public disponibles. Aucun nouveau commit envoyé sur main, aucune migration appliquée, aucune donnée réelle modifiée, aucun état Vercel READY ou parcours authentifié revendiqué.

Le retour arrière doit fermer les nouvelles commandes tout en conservant contrats, inventaires et reçus ; pas de restauration d'un ancien snapshot financier au-dessus des opérations intervenues depuis. Toute application devra suivre WORKFLOW-SUPABASE et être accompagnée des extractions du baseline, jamais d'une édition manuelle.

## Sauvegardes GitHub

- `codex/finalisation-construction-coffres-20261022` : intégration de travail ; ne pas fusionner en bloc. Coffres `3aa8c7a`, journal `6f25454`, autorisations `8400b3d`, contrôle de création/suppression `958955b`, intégration main `5a3fc9c`.
- `codex/securite-successions-95-20261022` : correctif isolé, commits `cfe8888`, `9505d5a`, `8e16fbf`, `6db325b` ; revue et prévol encore obligatoires.
- `codex/journal-ventes-96-20261022` : lot isolé `9caf72f` ; pas fusionné ni déployé.
- `codex/regression-antenne-93-20261022` : garde indépendante `3c43290` ; pas fusionnée par cette session.

L'agent disposant des accès techniques doit reprendre les prévols, ouvrir les PR limitées et vérifier les déploiements. Aucune manipulation SQL, Git ou de secrets n'est demandée au game designer. Aucun nouvel arbitrage de game design n'est nécessaire.
