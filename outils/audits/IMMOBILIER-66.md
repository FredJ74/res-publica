# Socle immobilier #66 — inventaire préalable

Base : PR #58, `cda39528ead0df92b5cedfe441ca0898fcbf874b`, encore brouillon et non déployable. Branche dédiée ; aucun changement de la PR #56 ni des réservations #63 repris.

| Flux | Source existante | Réutilisation / manque confirmé |
|---|---|---|
| Fonds historiques PNJ | `entreprises`, `entreprise_signer_compromis`, `entreprise_acte_rachat`, `entreprise_prix_rachat` | Prix catalogue, acompte, compromis et prêt existants ; pas de titre des murs |
| Fonds version 2 | même table `entreprises`, `vendre_fonds_commerce` | Déjà transactionnel, conserve l'identité, extrait la caisse et transfère le titulaire du bail. Service-only car consentement acheteur manquant : la nouvelle offre acceptée doit apporter cette preuve |
| Murs | `terrains_etat.proprietaire` et miroir JSON `data.proprietaire` | Préserver les deux représentations existantes et les subdivisions ; aucune vente implicite avec le fonds |
| Baux / loyers | `locations_actives`, `bail_destination_attestee`, `prelever_loyer_bail` | Les lots dynamiques résolvent le titulaire à chaque débit ; les autres locaux restent routés vers la commune, même après vente des murs : adaptation commune requise |
| Paiement | `helvetia_debiter_fonds_ordinaires`, `helvetia_crediter_destination`, `payer_ordre`, `recette_municipale` | Pas de caisse parallèle ; refus/rollback de toute la transaction si une contrepartie échoue |
| Titulaires | `pj:`, `orga:`, `ville:<pays>_<ville>` déjà définis dans `plateau-fonds.js` | Réutiliser le format municipal existant ; ne pas créer de nouveau type de propriétaire |
| Notaire | `ouvrirMenuOfficialiserTransaction`, `officialiser_transaction` (1 PA, 0 FR) | Consultation d'offres séparée du menu des compromis historiques ; frais existants uniquement |
| Préemption | préemptions d'État des entreprises | Mécanisme distinct du droit nouveau de l'exploitant : ne pas détourner le pouvoir du ministre. Nouvel état d'offre, même courrier et horloge serveur ; aucun moteur de bâtiment |
| Financement #65 | `prets`, prêts travaux/consommation, `pretDemande` des compromis | Type acquisition et termes non définis dans #65 ; ne pas créer un faux prêt ni créditer sans décaissement attesté. Garder les prêts existants et leurs clauses |

## Arbitrages et données

Républia : 150 FR/m² pour cessions publiques, sans coefficient ; prix de revente PJ libre, indépendant des références. La Republica : un bâtiment, 1200 m², murs 180000 FR, fonds 380000 FR. Les autres surfaces restent NULL, aucune surface extrapolée ; les surfaces persistantes des centres/locaux ne doivent pas être écrasées.

La fiche de raccordement ne remplace aucun titre : elle référence les lignes canoniques existantes. Les offres et reçus attestent une vente ; ce ne sont ni un second cadastre ni une seconde caisse. Les anciens titulaires PJ ne sont jamais convertis en titulaires municipaux.

Préemption : mail avant départ de la fenêtre, 72 heures réelles exclusives, refus explicite ou échéance autoritaire => publication. La politique de retrait/republication/changement de prix n'est pas validée : aucune de ces commandes ne sera ajoutée implicitement. Baux multiples/occupation ambiguë : refuser la mise en vente au lieu de choisir arbitrairement un prioritaire.

## Dépendances et limites préalables

Les corps vivants, contraintes, RLS et tâches Supabase restent à confronter au prévol avant toute application. Les archives sont des sources locales, pas une preuve de production. Pas de migration en production, pas de modification de joueur, pas de fusion.

## Implémentation livrée sur la branche

Branche `codex/immobilier-fonds-murs-66`, empilée sur le commit de PR58 indiqué plus haut. Les moteurs de paiement, de compromis, d'acte PNJ, de transfert de fonds version 2, de courrier et de perception des loyers sont réutilisés. Les migrations restent **préparées uniquement**.

- `20261021203047_immobilier_offres_fonds_murs.sql` : métadonnées reliant les titres existants, offres immuables, priorité, catalogue filtré, acte unique et reçu privé. L'offre fonds et l'offre murs restent indépendantes ; l'ensemble est la signature atomique des deux offres, y compris avec deux vendeurs distincts.
- `20261021203832_immobilier_loyers_titres.sql` : destination des loyers résolue depuis le propriétaire actuel des murs enregistrés ; conservation du bail, des prix, des impayés et des exceptions clinique/box. Aucun nouveau prélèvement périodique.
- `plateau-immobilier-ventes.js`, `supabase.js`, menu notarial et styles : consultation, dépôt, refus de priorité, confirmation avant paiement, verrou de commande, reprise par le même identifiant et lecture du reçu après F5. Les réponses d'une ancienne identité/session/position sont ignorées via le contexte de navigation existant. Aucun polling ajouté.
- Les anciens compromis d'un bien enregistré sont dirigés vers ce même catalogue avant tout débit historique, y compris les imprimeries. Les biens non enregistrés conservent leur parcours historique. Lecture incertaine = refus de lancer un autre circuit. L'acompte déjà versé et les clauses existantes sont relus par le serveur.
- `api/cron-minuit.js` utilise la tâche quotidienne existante pour matérialiser les publications. L'expiration est effective exactement à l'échéance d'après l'horloge SQL, même avant cette matérialisation et sans navigateur connecté.

L'acte verrouille les participants, le bien, les offres, les baux et les titres. Toute défaillance après le premier mouvement annule PA, paiement, crédit, transfert, acompte nouveau et reçu dans la même transaction. Un identifiant rejoué sur les mêmes actifs rend le reçu sans paiement ; un autre contenu avec cet identifiant est refusé. Le prix public est relu ; un prix PJ reste celui offert, sans plancher/plafond de référence. Les montants d'offres sont des francs entiers transportés comme chaînes ; le total d'affichage utilise BigInt. L'extension privée du transfert de fonds évite la limite integer de son prix, sans changer la signature historique ni introduire de centimes.

Le moteur version 2 conserve l'historique, l'extraction de caisse et le transfert du bail. La cession d'imprimerie conserve sa recette de l'État via sa fonction existante ; le débit du prix restant et cette fonction sont englobés dans l'acte commun. La préemption d'État existante du ministre est distincte, conservée et testée.

Les anciennes copies de titres ne peuvent pas rétablir un propriétaire précédent : déclencheur sur les biens enregistrés, mutation client de titre permise uniquement par le reçu privé de la transaction courante. Les traitements serveur autonomes restent possibles. Cela **ne constitue pas** une correction globale de toutes les anciennes sauvegardes financières du jeu.

Les fonctions et contraintes existantes sont protégées par des préconditions : définition différente non examinée => arrêt de la migration. Le catalogue des canaux municipaux n'est étendu que si sa contrainte correspond exactement à la définition examinée. Aucun SQL généré de `baseline/`, seed, observation ou empreinte de référence n'a été modifié.

## Vérifications locales

Résultats machine : `VERIFICATIONS-IMMOBILIER-66.json`.

| Vérification | Résultat | Portée |
|---|---|---|
| Contrôleur client complet | 95/95 bancs | Transport et identités simulés ; Chromium local pour les bancs navigateur |
| Contre-épreuves existantes | 90/90 | Les mutations introduites sont toujours détectées ; seule l'ancre de signature du lecteur de terrain a été adaptée à son paramètre ville |
| Nouveau banc PostgreSQL immobilier | 92/92 scénarios | PostgreSQL jetable, tables et moteurs archivés réels, identité et certains services annexes simulés |
| Nouveaux tests client et Chromium | 19/19 | 17 cas JavaScript, 2 scénarios navigateur à 390/1200 px, serveur fictif |
| Bancs PostgreSQL du workflow | 15/15 bancs | Dont PR58 et immobilier ; le banc immobilier a ensuite été relancé à 92 scénarios après les derniers compléments |
| Calendrier Node | 5/5 | Aucun service distant |
| Pilote e2e et prévol | 69/69 | Fixtures et serveurs locaux, aucun compte réel |
| Syntaxe API | 23/23 modules | Aucun appel distant |
| Syntaxe SQL/YAML/JavaScript, diff, inventaire économique reproductible | Conformes | Deux migrations et prévol parsés avec pglast |
| Contrôles globaux du baseline | **10/12, échec** | Authority et Referential restent rouges, détail ci-dessous |

Les scénarios immobiliers couvrent fonds seuls, murs seuls, ensemble, vendeurs distincts, prix libres dont zéro, refus de fonds, clause de prêt en attente, paiement et PA uniques, conservation des stocks, loyers au nouveau titulaire, priorité cachée aux tiers, mail unique, panne de mail, refus explicite, expiration hors connexion, tiers prématuré, concurrence, rollback après premier transfert, F5 et réponse perdue. La migration est appliquée deux fois dans la base jetable. Une contrainte municipale inconnue provoque bien un arrêt et reste intacte.

Les bancs historiques demandant JavaScriptCore ont été exécutés avec l'adaptateur Node local disponible dans cet environnement, pas avec un JavaScriptCore natif. Les tests PostgreSQL ne chargent pas toute la production ni toutes ses policies/triggers ; ils ne prouvent pas le fonctionnement authentifié distant.

### Contrôles rouges non masqués

- **Authority** : invariant 13, 36 appels RPC sans définition dans le baseline archivé. Les six RPC client de ce chantier ont leurs déclarations dans la migration préparée ; leur présence vivante ne peut pas être revendiquée. Le rapport indique aussi des écarts antérieurs, notamment `consommer_sur_place_commerce` et des fonctions de construction. Les autres invariants rapportés sont verts.
- **Referential** : trois empreintes divergentes : `ordres_couts` (générateur `25a657826ddd2f02`, déclaration `20e52d8f9bbe8e3f`), `postes_nommes_regles` (`694f117ace57b0b1` / `6c0c7aa0d29bf852`), `miroirs_entreprises` (`a497db09af2c6fe7` / `e2b15dda50c9a640`). Rien n'a été recalé artificiellement pour les rendre vertes. Comparaison au catalogue réel nécessaire avant synchronisation du baseline.

## Dépendances et limites de clôture

1. **PR58** reste une dépendance non fusionnée. Son commit de base et `main` n'ont pas avancé lors de la dernière vérification distante ; `main` est ancêtre de cette branche. Ses prix, superficies et graphismes ont été conservés. Le parcours complet de réception du bâtiment et les coûts obligatoires restent à valider avant de conclure sur le coût complet d'un existant comparable.
2. **Financement #65** : aucun nouveau type de prêt acquisition ni termes validés n'ont été trouvés. Pas de prêt fictif ajouté. Les prêts existants des compromis sont conservés ; une clause en attente bloque avant mutation. Le futur décaissement d'acquisition devra être lié à l'acte et à son reçu dans la transaction du moteur bancaire existant. Ce financement neuf n'est **pas livré** par cette branche.
3. **Supabase vivant non vérifié** : aucun connecteur Supabase disponible dans cette session, aucun compte de test authentifié utilisé. Le registre, les définitions actives, RLS, triggers, droits, tâches et circuits de sauvegarde restent à comparer. Les archives ne prouvent pas l'état de production.
4. **Données immobilières incomplètes** : seule la surface PNJ La Republica est nouvellement approuvée. Les autres restent absentes ou préservées telles quelles ; une offre incomplète est refusée. L'initialisation automatique est limitée aux commerces PNJ univoques ; les biens PJ déjà construits nécessitent un raccordement de configuration à leurs titres réels, après audit. Plusieurs exploitants distincts dans un même bien : arrêt explicite, aucune priorité choisie arbitrairement.
5. **Sauvegardes financières historiques** : l'acte est atomique, mais la protection globale contre les sauvegardes générales périmées ne doit pas être supposée déployée. Le prélèvement de loyer historique utilisant `arg` est conservé ; ce chantier ne prétend pas résoudre la représentation monétaire générale ni changer l'ordre des poches existantes. Vérifier les protections réelles avant activation.
6. **Économie** : `ECONOMIE-IMMOBILIER-66.json` est reproductible par `node outils/audits/auditer-economie-immobilier-66.cjs`. Les sous-totaux terrain + immeuble + permis connu vont de 123600 à 156100 FR, face aux 180000 FR de murs La Republica. Ce ne sont **pas** des preuves de coût complet/comparabilité : géométrie, réception et frais réels de PR58 à confirmer. Une parcelle sans surface/prix reste signalée. Aucun tarif ni budget de construction changé.

**Verdict : socle commun implémenté et testé localement ; activation en production non autorisée et non prête à être déclarée vérifiée.** Les dépendances ci-dessus restent visibles. L'issue ne doit pas être fermée comme intégralement opérationnelle.

## Procédure d'activation contrôlée, après validation

Cette procédure sera exécutée par l'agent disposant des accès ; elle ne demande aucune manipulation SQL au game designer.

1. Achever/revoir PR58 et le financement #65 ; réexaminer la différence avec `main` avant intégration. Conserver les corrections concurrentes.
2. Exécuter en lecture seule `outils/bancs/prevol-immobilier-66.sql`, confronter signatures, corps, droits, contraintes, triggers, catalogue, inventaires des biens et agrégats financiers. Examiner en particulier les écritures concurrentes de baux et les sauvegardes de personnage. Ne pas publier d'identifiants ou soldes personnels dans les rapports.
3. Reproduire les dépendances vivantes dans un environnement isolé avec de vrais comptes de test autorisés ; tester les actes et les anciens compromis, l'imprimerie, loyers, droits municipaux, F5 et sessions concurrentes. Aucun faux crédit à un joueur réel.
4. Après approbation, appliquer dans l'ordre la migration des offres puis celle des loyers. Tout désaccord d'une précondition impose une nouvelle revue, jamais la suppression de la garde. Les fichiers DDL ne signent aucun acte ni ne modifient les titulaires des joueurs.
5. Réconcilier les titres et surfaces approuvés ; appeler explicitement le raccordement serveur `immobilier_raccorder_pnj()`, puis `immobilier_references_publier()`. Ces opérations sont idempotentes, mais constituent des écritures d'activation non effectuées ici. Ne pas remplacer un titre PJ, ne pas inventer de surface, conserver les comptes rendus des fiches non valorisées. Raccorder les biens PJ existants par configuration univoque, sans nouveau moteur métier.
6. Déployer ensemble les raccordements client et cron après installation du contrat SQL. Vérifier que les anciens parcours dirigent les biens enregistrés vers l'acte commun avant tout débit, et que des clients obsolètes ne peuvent contourner les titres. Vérifier la tâche quotidienne et l'ouverture à l'échéance SQL, puis l'absence de polling.
7. Exécuter les contrôles du workflow ; réextraire le baseline depuis les catalogues conformément à `WORKFLOW-SUPABASE.md`, jamais en le faisant précéder la base. Observer les premiers actes autorisés et leurs contreparties sans provoquer d'opération fictive en production.

Retour arrière : avant application, rien à annuler ; le DDL transactionnel peut être annulé en cas de précondition refusée. Avant premier acte, une restauration contrôlée du schéma doit préserver les baux et données existants. **Après un acte réel, ne jamais remettre les anciens soldes ou propriétaires depuis un snapshot** : conserver reçus/historiques et corriger en avant après audit. Ne pas retirer les gardes de titres ni remettre un client ancien susceptible de débiter hors transaction. Suspendre l'entrée des nouvelles signatures si une anomalie survient, puis réparer dans le moteur commun.
