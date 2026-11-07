# Caisses d'entrepôts — reprise du 7 novembre

Base intégrée : main 747153e4. Aucun compte ou solde de production consulté/modifié
par Codex. Aucun outil Supabase n'est exposé dans cette session. Les constats distants
ci-dessous sont attribués au relais de Claude, pas présentés comme nos propres relevés.

## Ne pas refaire le travail livré

- Le 8 octobre, `entrepot_caisse_canonique_unique_consommateurs` a unifié la lecture
  et plusieurs consommateurs. Le baseline en porte les définitions.
- #565 / 68871dac : Claude a corrigé l'achat PJ par patch en place ; registre signalé
  `achat_entrepot_caisse_canonique_20261107001000`, migration **déclarée appliquée**
  dans RELAIS.md. Notre préparation concurrente non poussée a été supprimée.
- #566 / bb7560ac : dotation autorisée de PSM et Montrouge, 2 → 10 000 FR chacune,
  soit +9 998 FR chacune ; registre signalé
  `dotation_initiale_entrepots_province_20261107003000`. Ne pas rejouer.
- Le « PSM 10 231 / 2 » initial est **explicitement invalidé** par le relevé de Claude :
  aucune clé de caisse dans les blobs en production. Il ne justifie pas un transfert.
  Luthécia était relevée à 18 019 FR avant les derniers traitements. Ces montants
  sont des observations historiques du relais, pas des soldes actuels certifiés.

## Inventaire des chemins exécutables

| Circuit | Lecteur / écrivain | Autorité et état |
|---|---|---|
| Identité de caisse | `entrepot_caisse_id` (baseline économie fonctions-2) | Pays et ville des colonnes du bâtiment + référentiel villes ; identifiant `<pays>_entrepot_<ville>`, aucune déduction fragile par split. |
| Lecture générique | `entrepot_caisse_lire` | `caisses_batiments.data.solde`. |
| Mouvement serveur | `entrepot_caisse_mouvement` | Réservé serveur ; délègue à `caisse_institution_mouvement`, caisse exigée. |
| Écran directeur | `chargerTableauEntrepot`, plateau-entrepots.js | `sbGetCaisseBatiment` avec pays et ville ; un échec reste null, pas zéro inventé. Aucun changement client dans ce lot. |
| Achats PJ | `confirmer...` → `executerReceptionInventaire('acheter_a_entrepot')`, plateau-justice-economie.js → surcharge UUID → noyau texte | Reçu existant / paiement PA / inventaire / prix / fonds ; noyau corrigé par #565 vers primitive commune, pas de moteur bis. |
| Commandes directeur | `entrepot_commander` | Lit la caisse canonique, crédite/débite les caisses via la primitive ; transits et stocks existants. |
| Reversements | `entrepot_reverser`, `entrepot_virement_mairie`, `entrepots_reverser_excedent` | Même caisse, autorité territoriale et comptes municipaux existants. |
| Travaux | `approvisionner_chantier`, appels cron | Caisse canonique via primitive ; pas de modification immobilière. |
| Trading | `trading_acheter` | Crédit caisse du vendeur via `entrepot_caisse_id` / primitive, organisation acheteuse existante. |
| Offres | `offre_achat_publier`, `offre_achat_servir`, remboursement/expiration | Blocage et retour vers caisse canonique, droits et reçus existants inchangés. |
| Exportations | `exportation_caisse_interne`, `exportation_recevoir`, `exportation_sovarka_recevoir` | Dernière migration 20261106103000 remplace aussi les écritures directes de 20261106100000. Fonctions déjà livrées, non modifiées. |
| Minuit | `livrerEntrepotsQuotidien` | Lit `entrepot_caisse_lire`, applique le delta par `entrepot_caisse_mouvement` ; ne lit PAS le champ historique dans main actuel. |
| Minuit exportations/travaux | `traiterExportationsPortQuotidien`, approvisionnement | Même primitive ; trois replis `{stock:{},caisse:8500}` peuvent recréer une clé fantôme si état absent : retirés, stocks inchangés. |
| **Ravitaillement militaire** | `traiterRavitaillementServeur` → **`effort_ravitailler`** | Le corps du baseline crédite encore `v_ent.caisse`, même s'il débite correctement la caserne et livre ses matières. Régression reproduite sur PostgreSQL réel ; **complément préparé dans ce lot**. |
| Production militaire | `effort_produire_lot` | Consomme la réserve, paie l'armurerie : sa caisse n'est pas une caisse d'entrepôt, ne pas la confondre ni la modifier. |

Archives anciennes et fixtures ne sont pas des fonctions de production. La recherche
s'est faite aussi dans les corps SQL entiers (dont les variables `v_ent`), pas seulement
sur la chaîne `entrepot.caisse`. L'inventaire du catalogue vivant reste à confronter
au prévol : un baseline et des fichiers déclarés appliqués ne remplacent pas cette lecture.

## Complément préparé

`migrations/20261107081631_effort_ravitaillement_caisse_canonique.sql` : patch en place
de la grosse fonction, sous présence unique des fragments attendus. Il préserve le
reste de son corps, propriétaire, droits, paramètres, prix et conditions. Rejeu sans
changement de définition. Une incompatibilité interrompt la transaction.

Chaque entrepôt reçoit le coût réellement prélevé par la primitive commune, caisse
existante exigée. Le drapeau interne précédent est restauré. Un refus lève une
exception : les crédits précédents, stocks et débit de caserne s'annulent ensemble.
Aucun nouveau champ financier client, aucun tarif ni stock créé.
L'éventuelle clé historique reste gelée, sans crédit, transfert ou suppression par ce patch.

Le cron reçoit seulement trois retraits de valeurs de repli à 8 500 FR. Aucun module
Sovarka, data.js, plateau-*.js ou fichier graphique modifié. Le workflow existant reçoit
un banc supplémentaire, pas une pipeline redondante.

## Tests exécutés

- PostgreSQL **17.6** : **28 contrôles**, transaction entièrement annulée.
- Même commande que CI avec pgserver fourni : PostgreSQL **16.2**, **28 contrôles**.
- Achats : vraie fonction, vrai wrapper et vrais reçus du baseline, patch de Claude
  inchangé ; appels au rôle authenticated avec request.path. Identité, règles légales
  et paiement PA sont des fixtures explicitement simulées, pas une certification RLS.
- Ravitaillement : contre-épreuve ancienne recette perdue, caisse canonique créditée,
  caserne débitée, matières livrées, panne sur le second entrepôt annulant TOUT,
  rejeu du patch et corps incompatible refusé. Commande réservée service_role ;
  authenticated est effectivement refusé (pas de privilège ajouté par le patch).
- Achats supplémentaires : reçu rejoué, panier modifié refusé, caisse absente,
  identité étrangère, stock/fonds insuffisants, inventaire plein, panne après crédit,
  rollback du DDL et caisse Sovarka séparée. Aucun test sur PJ réel.
- Six tests ciblés Node (dont garde des écritures fiche) réussis ; détecteur AST du
  cron avec contre-épreuves de dotation et lecture d'ancien solde.
- Vérificateur Workflow : conforme après enveloppe BEGIN / SET TRANSACTION / ROLLBACK
  du prévol. Contrôleur client complet et globaux : résultats finaux à la fin du relais.

Limites : les fixtures ne certifient ni le catalogue vivant, ni tous les triggers de
production, ni l'exécution concurrente réelle du calendrier. Le patch n'ajoute aucun
reçu nocturne : la garde quotidienne existante `tacheQuotidienne` reste en place.
Les passages historiques du cron qui écrivent stock puis delta par deux appels restent
un risque de réponse perdue entre ces appels ; ils ne sont pas présentés comme atomiques
par ce correctif de source de caisse.

## Prévol et application restant à faire

1. Exécuter `outils/bancs/PREFLIGHT-CAISSES-ENTREPOTS-20261106.sql` en lecture seule :
   transaction cohérente, registre **par NOM**, soldes et définitions/droits vivants.
2. Confirmer #565/#566 au registre, ne pas les réappliquer. Vérifier si effort_ravitailler
   est déjà corrigée ; ne pas exécuter ce complément inutilement si c'est le cas.
3. Confronter le corps vivant aux fragments, aux ACL et aux dépendances ; rejouer le
   banc annulé sur un environnement fidèle, sans utiliser un compte joueur réel.
4. Après prévol conforme, intégrateur applique via registre, compare empreintes des
   caisses/stocks avant/après DDL (aucune mutation attendue), réextrait le baseline
   avec les générateurs puis archive la migration. Codex n'a rien appliqué ici.
5. Toute régularisation éventuelle est un autre acte explicitement approuvé : capture
   des montants par ville, choix du solde/delta par Fred, mouvement unique journalisé
   sous préconditions des montants et clé de rejeu ; jamais somme des deux champs ni
   effacement automatique. Aucun SQL de régularisation non autorisée n'est livré.

Le point de départ « deux soldes réels à départager » est caduc selon le relais actuel.
Aucune nouvelle demande d'arbitrage artificielle n'est créée sur cette base erronée.
Si un prévol vivant retrouve un ancien montant, le consigner avec ses montants exacts
sous « Décisions attendues de Fred » et suspendre exclusivement sa régularisation.
