# Reconstruction canonique et combats #219 — 30 octobre 2026

**Chantier non terminé : moteur PostgreSQL 17.6 disponible et corrections testées, mais les exports de production n'ont pas été transmis en fichiers. Aucune installation des 88 migrations sur une copie fidèle, aucune fusion ni production.**

Ce rapport actualise `LIVRAISON-CONTROLEE-GROUPES-219-20261030.md`. Les anciens résultats restent historiques, pas des preuves du catalogue actuel.

## Travail repris et préservation de main

AGENTS.md, RELAIS.md, WORKFLOW-SUPABASE.md et les commentaires des PR #262/#219 ont été lus. La PR #262 contient un rapport de 48 lignes, pas les quatre exports. Ses commentaires précisent explicitement que les requêtes ont répondu mais que les résultats ne sont pas matérialisés.

Main `7ddce4ee4f9c4e9d2280bf3918f6543b50aa5050` intégré par `40d6ca8d`, puis **main `bd1673ca` (#276) par `c069f987`** : protections #258/#260, écritures financières serveur de #265, notaire, occupation, caisses et interview de Jodie conservés. Aucun nouveau développement immobilier ou métier d'ambassade. Le contrôle de #265 interdisant les écritures de fiche serveur par la vue passe.

La version 20261030210000 de #265 entrait à nouveau en collision avec une préparation de #219. Les 29 préparations concernées passent à leurs horodatages UTC de reprise, **20261030223538 à 20261030223606** ; correspondance dans `VERSIONS-GROUPES-219-20261030.json`, manifeste et bancs raccordés. Aucune version appliquée n'est renumérotée. Zéro collision avec les fichiers du main intégré ; la nouvelle liste doit encore être confrontée au registre vivant complet. Le relevé extérieur « zéro déjà appliquée » concernait la liste précédente, pas une homologation automatique de toutes les suivantes.

## Corrections réellement réalisées

- **Acquisition stricte des exports** : un seul chargeur réutilisé par rendre.py et seeds.py, JSON natifs et anciennes enveloppes MCP acceptés. Refus des exports absents, tronqués, contradictoires, catégories de droits manquantes ou options de séquence incomplètes, avant le rendu. Les listes réellement vides du catalogue ne sont pas confondues avec un export manquant.
- **Classement d'acquisitions_transactions_internes** : C / structure seule, aucun seed de transaction. Justification fondée sur #262 et les écrivains existants ; compteurs non relevés explicitement notés `non_releve`, aucun chiffre inventé. Le DDL, les policies, commentaires et droits réels ne sont pas reconstitués depuis ce relevé partiel.
- **Défaut de reconstruction confirmé sur vrai PostgreSQL** : l'ancien rendu crée deux fois une séquence IDENTITY. Le générateur distingue désormais séquences ordinaires, serial et IDENTITY, préserve nom/propriété/type/minimum/maximum/départ/incrément/cache/cycle, et ne crée chaque séquence qu'une fois. Les colonnes calculées STORED restent calculées.
- **Seeds** : colonnes calculées exclues des INSERT, identités ALWAYS importées explicitement, séquences possédées recalées depuis les identifiants initiaux avec leur vrai incrément positif ou négatif. Aucun compteur de bêta copié. Le premier INSERT après import est réellement testé. Une séquence partagée sans propriétaire exige une stratégie explicite ; elle n'est pas recalée arbitrairement.
- **Linux** : les générateurs réutilisent le moteur JavaScript portable déjà présent, sans toucher leurs extracteurs ni leurs résultats attendus. Les divergences réelles deviennent mesurables.
- **Fonctions** : copie préexistante du taux horaire déclarée et comparée sur 12 cas. L'ancien miroir client d'expulsion, supprimé le 25/10 (audit R11), n'est plus exigé. Le contrôle conserve l'empreinte serveur et l'ancienne empreinte historique à l'identique ; il exige l'absence AST du mécanisme retiré et détecte sa réintroduction. Aucun code métier d'ambassade modifié, aucune empreinte ajustée pour obtenir un vert.
- **Détection de copies** après #276 : la lecture REST `lire` et une aide numérique locale homonyme ne sont pas le même calcul. La portée des déclarations est désormais vérifiée par AST ; une fonction locale ne devient plus un faux canon de module. Test de non-régression ajouté, aucune exclusion et aucun changement de métier Jodie.
- **Fixtures clientes** : les nouveaux référentiels/résolveurs de caisse de main sont chargés depuis les vraies sources par les bancs Commerce et immobilier. Les assertions sont conservées ; aucun faux résultat réseau ajouté.

**Aucun SQL généré de baseline/domaines ou baseline/seeds n'a été modifié.** Le rendu complet de production reste volontairement en attente de ses sources ; rendre.py et seeds.py ont été exercés sur de vrais exports d'une base de fixture, en répertoire temporaire.

## Moteur réel : verrou levé

Le moteur fourni initialement par pgserver est PostgreSQL 16.2. L'épreuve stricte le refuse ; aucune suppression du privilège MAINTAIN ni substitution de version pour faire passer la reconstruction.

Le téléchargement direct PostgreSQL a répondu HTTP403. Alternative réussie : miroir **officiel** GitHub, tag `REL_17_6`, commit `7885b94dd81b98bbab9ed878680d156df7bf857f`. Compilation puis installation locale de PostgreSQL **17.6**, avec pgcrypto, sans sudo ni ressource Supabase/payante. GNU m4 provient du paquet officiel Debian contrôlé par SHA-256. L'analyseur est pglast 7.21, grammaire PostgreSQL 17.7 ; il est distinct du moteur natif 17.6.

- Recette reproductible : `outils/bancs/installer-postgresql17-local.sh`.
- Lanceur des bancs existants, sans modification de leurs assertions : `outils/bancs/lancer-postgresql-local.py --postgres-bin <binaires-locaux> <banc.py> ...`.
- Épreuve globale : `outils/baseline/epreuve-postgresql.py`, réutilisant l'assembleur canonique, aucune URL distante acceptée, serveur éphémère détruit après usage. Pas de migrations historiques rejouées.
- Les fonctions sont déclarées selon les phases, puis **toutes recompilées avec check_function_bodies=on**. Aucun corps invalide n'est accepté par la désactivation temporaire de son contrôle initial.

La reconstruction stricte du **vieux** baseline sur 17.6 échoue réellement : `divers-et-technique/10_tables.sql`, ordre 58, SQLSTATE **42P07**, `registre_ventes_armes_id_seq already exists`. La correction du générateur est prouvée sur PostgreSQL 17.6, mais ses nouveaux fichiers doivent être générés depuis les exports réels, pas retouchés à la main ni inventés à partir de l'ancien SQL.

## Résultats vérifiés

Code des corrections : `4efa7e88` (main #276 conservé), précédé de `add82a1b`, `5ae16451`, `c28e7482`, `0c6a885a`, `6b24656b`. Preuves après #276 : `outils/audits/preuves-reconstruction-219-main276-20261030/`. Étapes antérieures, compilation du moteur et six contre-épreuves : `outils/audits/preuves-reconstruction-219-20261030/`, conservées sans retouche.

| Épreuve | Résultat et portée |
|---|---|
| Acquisition, rendu, séquences, seeds, compilation et contrôle de retrait client | **18/18**, PostgreSQL **17.6 natif** ; fixtures, aucun état réel |
| Groupes/combats mixtes, détection, interception, prison, radio, transports et conséquences | **379/379**, PostgreSQL **17.6 natif**, RPC au rôle authenticated ; identités/JWT de fixture |
| Six mutations défectueuses | **6/6 détectées**, 379 cas chacune sur 17.6 ; codes non nuls et erreurs conservés |
| Contrôleur client complet | **143/143** après correction des fixtures reçues de main |
| Pilote Chromium | **105/105**, local, aucun compte réel connecté |
| Constructeur Vercel | **12/12 locaux**, aucune demande de déploiement |
| Écritures serveur de fiche #265 | Réussite, aucune réintroduction d'écriture par la vue |
| Fonctions | **Vert**, 56 entrées dont 43 comparées sur **1 894 cas**, contrats épinglés conservés |
| Workflow | **Vert** |
| Contrôles globaux | **6/12** ; six contrôles encore rouges, détails ci-dessous |
| Reconstruction complète fidèle / lot atomique de 88 sur cette copie | **Non réalisés** ; exports complets absents |
| Recette authentifiée isolée / production | **Non exécutée** |

Les tests concurrents committent exclusivement dans PostgreSQL jetable ; ne pas les présenter tous comme des transactions annulées. Les tests du générateur nécessitent le rôle de création DDL ; les RPC métier sont éprouvées sous authenticated. Ces preuves ne sont ni des visites de joueurs ni une homologation des RLS de production.

## Contrôles encore rouges, sans masquer les écarts

1. Classification : 326 entrées contre le relevé gelé de 319, empreinte de liste différente. Le catalogue communiqué annonce 375 tables, mais sa liste complète n'est pas fournie : ne pas remplacer 319 par 375 ni recalculer une empreinte depuis notre CSV pour simuler un relevé.
2. Fidélité du baseline : 22 anomalies, dont le nouveau classement sans DDL extrait. Le contrôle global et le baseline sont toujours datés du 13 octobre ; aucune observation artificiellement actualisée.
3. Authority : 123 RPC absentes du baseline et 10 signatures inconnues dans les préparations ; les protections préparées de #219 n'ont pas été installées/extraites. Le défaut préexistant de garde de `resilier_bail_volontaire` reste signalé, sans nouveau développement immobilier.
4. Referential : **cinq divergences mesurées** maintenant que les générateurs tournent sur Linux : ordres_couts, postes_nommes_regles, miroirs_chantiers, miroirs_entreprises et offres_emploi_bne. Aucune déclaration d'empreinte modifiée pour les effacer. Comparaison au catalogue vivant nécessaire avant toute correction ou régénération des référentiels.
5. Assemblage : deux fonctions de triggers immobiliers absentes du baseline (`fermeture_definir_date_universelle`, `permis_depot_archive_proteger`). Leur définition canonique doit venir de l'extraction.
6. Reconstruction statique : zéro refus de grammaire, deux dépendances et six attentes du monde non satisfaites. L'épreuve native montre en outre le doublon IDENTITY ci-dessus. Aucun succès annoncé pour la reconstruction globale.

## Blocage extérieur : preuves et action nécessaire

- Aucun outil Supabase/execute_sql exposé dans cette session, y compris après le redémarrage de l'environnement ; aucune variable de connexion PostgreSQL ni configuration DB disponible. Aucun secret recherché en clair.
- API GitHub refusée (`Forbidden`) ; pages publiques et Git accessibles. Les commentaires des PR confirment que les quatre exports ont été lus dans **l'autre session** mais pas enregistrés. Ni la branche #262 ni les fichiers de travail inspectés ne contiennent ces exports complets.
- Relevés communiqués seulement : environ 783 k caractères structure, 2,85 M fonctions, 259 k logique, 566 k droits ; 1 002 versions et zéro collision de l'ancienne proposition. Les trois MD5 de #262 ne permettent pas de reconstruire 1 199 fonctions, 375 tables, ACL, policies et dépendances.

**Passage de relais unique nécessaire à la session disposant du connecteur :** rendre accessible dans cet environnement une archive des **quatre exports JSON complets**, du **contrôle global daté** et du **registre complet**. `export_structure` doit être relancé avec la requête actuelle enrichie en options de séquence. Ne transférer aucune ligne de personnage, compte bancaire, inventaire, mail, historique de joueur ou auth.users. Les exports restent dans un espace de travail sécurisé ; publier seulement leurs empreintes et les différences techniques examinées. Il ne s'agit pas de demander au game designer d'exécuter du SQL, Git ou des scripts.

## Enchaînement prêt après transfert

1. Vérifier complétude, provenance, même fenêtre de stabilité et empreintes des exports ; confronter les définitions/divergences #262 aux sources actuelles, pas aux archives rejouées.
2. Compléter explicitement la classification et les règles de domaine des objets réellement nouveaux ; aucune valeur initiale de joueur copiée. Exécuter les vrais `rendre.py` et `seeds.py`. La requête de seeds est générée depuis la classification validée et relue avant extraction ; aucun état C n'est seedé.
3. Relever le vrai point de coupe, archiver seulement les migrations prouvées appliquées. **Rehorodater ensemble les 88 préparations désormais antérieures au nouveau baseline**, avec correspondance explicite et nouvelles empreintes ; ne jamais reculer le point de coupe. Le générateur bloque ce cas et les collisions locales.
4. Exécuter les contrôles canoniques et l'épreuve PostgreSQL 17.6. Celle-ci compare les quatre ensembles du schéma reconstruit aux exports, en retirant uniquement les exclusions documentées `hors_baseline`. Toute différence bloque le lot.
5. Fournir le registre réel avec `--registre`, jamais un faux registre vide. Le lot de 88 est généré puis exécuté dans une transaction, contrôles d'intégrité des anciennes colonnes PJ, prérequis, collision avant DDL et estampillage en fin. Aucun appel MCP indépendant ne doit simuler une transaction globale.
6. Exercer sur cette copie fidèle les fixtures intégrées sous authenticated, contraintes/RLS/ACL réelles et concurrence. Les 379 cas actuels utilisent leurs décors ; ils ne doivent pas être rebaptisés tests de la copie fidèle.
7. Recette authentifiée sur environnement isolé autorisé, avec le pilote existant et comptes de test : groupes PJ/PNJ, métiers, présence, détection avant interception, combat réel, cinq rounds, fuite, prison, radio, deux sessions/perte de réponse, PA/fonds et anciennes sauvegardes. Arnie reste consultation seule : aucune extension de ses autorisations.
8. Préparer la livraison coordonnée et la PR, sans fusion ni activation tant que les preuves requises manquent. Déploiement de production uniquement après autorisation et prévol conforme.

**Verdict : chantier non terminé.** Les verrous locaux corrigeables ont été traités et les tests exécutés sur le bon moteur ; la reconstruction fidèle et l'installation du lot restent bloquées par le transfert des exports complets. Aucune donnée ni aucun schéma de production modifié, aucune ressource payante créée, aucune fusion.
