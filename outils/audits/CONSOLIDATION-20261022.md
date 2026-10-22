# Consolidation Human Gambit — 22 octobre 2026

**NON TERMINÉ. Aucune fusion dans main, aucune migration de production, aucun déploiement lancé, aucune donnée réelle modifiée.** Les lots codés sont sauvegardés sur GitHub. Leurs tests locaux ne constituent ni une validation du catalogue vivant ni une validation en jeu. Les PR56/58/71 sont restées en brouillon au dernier contrôle public accessible.

## État et sauvegardes

La branche de revue `codex/consolidation-20261021` rassemble les lots pour les contrôles locaux ; ce n'est pas une autorisation de fusion globale. Les branches indépendantes restent disponibles. Main a été relu avec `git fetch` et contrôlé à `baa9cb7e2b7f89db66cf268d21382deb0be2a3a2` : aucune évolution concurrente supplémentaire lors de cette session. Les conflits de consolidation ont porté sur les versions des scripts, le menu commun et les étapes CI ; les variantes fonctionnelles et leurs tests ont été conservés. Aucun fichier du baseline, des seeds ou de l'historique généré modifié.

| Lot | Décidé | Codé | Testé localement | Fusionné dans main | Déployé / vérifié en production |
|---|---|---|---|---|---|
| PR56 / #62 réalités | Oui | Correctifs existants conservés ; garanties globales incomplètes | Impacts immédiats, gardes déplacement/paiement, consultations sur interaction | Non | Non |
| #68 sessions | Oui | Renouvellement et reconnexion intégrés | Expiration, 401, identité, inter-onglets, réponse tardive, pas de rejeu métier ; Chromium avec service simulé | Non | Non |
| PR58 / #57 construction | Oui | Lots existants conservés, chaîne complète inachevée | Parcours et matériaux existants | Non | Non |
| PR71 / #66 immobilier | Oui | Socle existant + titres et ouverture successorale corrigés | Transactions notariales et successions ciblées | Non | Non |
| #65 crédit acquisition | Conditions bancaires indispensables manquantes | Pas de contrat de prêt inventé | Audit des dépendances | Non | Non |
| #63 hôtels | Oui | Nuits cumulables, paiement/reçus et bonus attesté | 39 assertions PostgreSQL, clients et régressions | Non | Non |
| #64 Banque nationale | Oui | Compte/placements unifiés, source espèces ou compte, reçu | 52 assertions PostgreSQL, clients et Helvetia | Non | Non |
| #67 musée | Oui | Ordre conditionné par l'autorisation existante utilisable | 5 tests Node, même quête et clé | Non | Non |
| #69 coffres | Oui, y compris une unité par exemplaire/unité empilable | Garde successorale et comptage ; location/stockage/succession complets non livrés | 15 assertions de garde, 35 assertions d'inventaire + 100 cas générés | Non | Non |
| #70 Krasnov | Oui | Huit originaux archivés, sans raccordement | ZIP, huit SHA256 et contenu de la branche GitHub identiques | Non | Archivage distant confirmé ; aucune activation en jeu |

## Corrections réalisées pendant la consolidation

### Sessions #68

`auth.js`, `supabase.js`, `plateau-core.js`, `plateau-realites.js`, `plateau.html` : reprise dédupliquée sur interaction, jeton renouvelé partagé, verrou natif Web Locks lorsqu'il existe, conservation des credentials en panne transitoire. Seul un GET peut être rejoué une fois sous le même UID. Aucune RPC/écriture financière rejouée après authentification. Le formulaire intégré réutilise le moteur de connexion, vérifie l'UID avant adoption puis le personnage avant synchronisation. Aucun heartbeat nouveau.

Commits `d2bec15`, `874c3a5`, branche `codex/reprise-sessions-68`. Rapport : [REPRISE-SESSIONS-68.md](REPRISE-SESSIONS-68.md). La sérialisation inter-onglets universelle n'est pas revendiquée si Web Locks manque.

### Hôtels #63 et banque #64

Hôtels : le champ canonique `reservation_hotel` conserve plusieurs nuits et les anciennes réservations ; aucune ville historique inventée. Achat et attribution dans la même transaction, reçu privé, protection contre les anciennes sauvegardes. Le repos commun atteste un droit dans la bonne chambre ; le bonus existant consomme exactement une nuit. Consultation après rechargement, aucune expiration ajoutée. L'ensemble des anciens effets de sommeil (salaires, poison, soins) n'est pas pour autant devenu une transaction serveur globale.

Banque : le même écran réutilise les finances et le moteur des placements existants. Espèces prélevées directement ou compte bancaire au choix ; minimum/durée/rendement historiques inchangés. L'intention persistée et son reçu évitent le double débit après réponse perdue ; les soldes sont relus, pas recomposés par des deltas locaux. Helvetia conserve son parcours. Le snapshot d'INT effectif reste le contrat historique, pas une nouvelle preuve d'autorité des statistiques de groupe.

Les deux mouvements mettent aussi à jour `updated_at`, nécessaire aux lecteurs versionnés. Commits hôtels `6fca78e`, `5f1246b`, banque `7ce9531`, `89d7d86`. Rapports : [RESERVATIONS-CUMULABLES-63.md](RESERVATIONS-CUMULABLES-63.md), [BANQUE-UNIFIEE-64.md](BANQUE-UNIFIEE-64.md).

### Musée #67

Le rendu et le handler consultent les mêmes marqueurs existants `autorisationCoffre` et `coffreOuvert`. Autorisation absente/utilisée : pas d'ordre, pas de débit. Aucun objet d'autorisation artificiel créé et aucune étape de quête supprimée. Commit `b984229`, branche `codex/autorisation-musee-67` ; [AUTORISATION-MUSEE-67.md](AUTORISATION-MUSEE-67.md).

### Successions et capacité #66/#69

Trois défauts confirmés par des contre-exemples :

1. Un type d'actif inconnu, notamment `coffre`, était marqué réglé sans transfert. La garde le maintient non réglé avec erreur explicite ; les autres dispositions indépendantes continuent (`da50ff3`). Elle ne prétend pas implémenter la transmission des coffres.
2. Le règlement successoral des murs ne mettait à jour que le blob, déclenchant la vraie garde de titre #66. La colonne et le blob sont maintenant transférés ensemble, avec refus des titres ambigus ou déjà transférés (`cc9bfd3`). Le lecteur et l'ouverture conservent aussi le vrai `terrain_id`, la ville et les données propres au terrain ; le gel commun reçoit le titre exact (`ec9ea8d`). Les anciens dossiers ambigus doivent être réconciliés, jamais devinés. L'ouverture historique multi-RPC reste une limite distincte.
3. Le retrait commun enlevait la quantité demandée à chaque pile de même clé. Exemple démontré : deux piles de 4 et 5, retrait annoncé de 6, disparition des 9. Le retrait répartit maintenant les 6 unités et laisse 3 avec leurs métadonnées. Le compteur privé applique la règle reçue : un exemplaire = 1, une pile = sa quantité entière positive ; fractions et données invalides refusées (`dac9318`). La primitive n'est pas une RPC de coffre activée. L'extraction historique agrège encore l'objet sorti à partir de la première ligne : les éventuelles différences de métadonnées entre piles sont à traiter dans le raccordement du stockage, pas à déclarer préservées par ce seul correctif.

Branches `codex/immobilier-fonds-murs-66`, `codex/coffres-bancaires-69`. Rapports : [IMMOBILIER-66.md](IMMOBILIER-66.md), [COFFRES-SUCCESSIONS-69.md](COFFRES-SUCCESSIONS-69.md).

## Vérifications exécutées

Résultats structurés et noms des bancs : [RESULTATS-CONSOLIDATION-20261022.json](RESULTATS-CONSOLIDATION-20261022.json).

- **104/104 bancs client**, Node natif ou lanceur historique via adaptateur Node local ; JavaScriptCore natif indisponible.
- **90/90 contre-épreuves**, sans désactivation ni changement arbitraire des attentes.
- **25/25 bancs PostgreSQL du workflow**, bases jetables et services annexes de fixture. Les moteurs métier archivés sont utilisés là où ils sont disponibles ; le moteur vivant de rue ne l'est pas. Il s'agit de bancs isolés par domaine, pas d'une preuve que toutes les migrations du dépôt forment déjà un déploiement global compatible.
- Parmi eux : placements 52, hôtels 39, garde successorale 15, titres successoraux 11, inventaire 35 assertions et 100 cas déterministes ; nouveaux identifiants successoraux : 9 tests Node.
- **69/69 tests du pilote en fixtures**, **5/5 calendrier**, **23/23 modules API analysés**.
- 13 migrations différant de main analysées par pglast, YAML analysé, `git diff --check` conforme.
- Les huit illustrations de Krasnov ont exactement les octets du ZIP, SHA256 vérifiés ; le commit distant est `7e084166800473dff79c8d105d325a65f17f55f3`. Aucun raccordement aux scènes.

### Contrôles globaux : 10/12, pas 12/12

**Authority** : invariant 12, une signature privée créée par renommage non reconnue (`rue_position_enregistrer_moteur_20261021(text)`) ; invariant 13, **42 RPC appelées mais absentes du baseline**, dont les nouvelles préparées. Le corps du moteur de rue vivant n'est pas archivé dans ce baseline : une empreinte connue dans une issue n'en remplace pas la définition. Prévol réel, registre et réextraction nécessaires ; pas de déclaration fictive ni d'exception ajoutée au contrôleur.

**Referential** : trois écarts inchangés entre générateur et observations enregistrées :

| Référentiel | Générateur courant | Déclaration enregistrée |
|---|---|---|
| ordres_couts | 25a657826ddd2f02 | 20e52d8f9bbe8e3f |
| postes_nommes_regles | 694f117ace57b0b1 | 6c0c7aa0d29bf852 |
| miroirs_entreprises | a497db09af2c6fe7 | e2b15dda50c9a640 |

Aucune empreinte modifiée pour masquer ces écarts. Les 10 autres contrôles sont verts. Cela ne prouve pas que la production soit conforme au vieux relevé.

## Accès et état de production

Aucun connecteur Supabase/Vercel disponible dans cette session. La tentative HTTPS Supabase est rejetée par le proxy **CONNECT 403 avant le service** : ce n'est pas un diagnostic de panne Supabase. Les secrets, les soldes d'Angie/Arnie et les joueurs réels n'ont pas été utilisés. Aucun test authentifié réel, aucune inspection vivante des RLS/triggers/registre, aucune consommation facturée mesurée.

Le transport Git fonctionne ; les branches et commits sont poussés. L'API GraphQL GitHub retourne **Forbidden**, y compris pour la création du brouillon de consolidation et le commentaire #69. Aucune nouvelle PR n'a donc été créée et aucun commentaire/fermeture d'issue n'est revendiqué. Les textes exacts sont conservés dans `suivi-consolidation-20261022/` pour publication lorsque l'accès technique sera rétabli. Les PR existantes restent [#56](https://github.com/FredJ74/res-publica/pull/56), [#58](https://github.com/FredJ74/res-publica/pull/58), [#71](https://github.com/FredJ74/res-publica/pull/71).

La réduction locale de requêtes n'est pas une réduction démontrée de facture. Après déploiement autorisé et vérifié : comparer mêmes plages/durées/population, requêtes et octets par interaction, trafic au repos, anciennes versions du client et consommations Supabase réellement facturées. Aucun build de test superflu déclenché pour cette mesure.

## Dépendances inachevées, à ne pas confondre avec l'accès distant

- **PR56/#62** : garanties de tous les ordres historiques et autonomie du championnat encore à compléter ; aucun ordonnanceur réel du football établi. Un coma immédiat testé n'établit pas l'atomicité universelle de tous les ordres. Contrôler rapports de combat et conséquences dans le catalogue vivant.
- **PR58/#57** : pipeline commun complet occupation/combat, permis sous compromis, appels 35/35/30, pause et temps utile/courriers, cron atomique, lots/réception et stocks restants encore inachevé. Le parcours organisationnel n'est pas disponible comme moteur à copier : `peutAgirPourOrganisation` est explicitement fermé et le lanceur finance un PJ. La construction communale demande un raccordement commun maître d'ouvrage/autorité/caisse, puis toutes les phases ; un bouton réservé au maire ne suffit pas. Pas de conseil municipal inventé.
- **#66** : dépend du pipeline de réception #58 ; coût **complet** comparable non établi. Les sous-totaux connus ne remplacent pas une comparaison exhaustive avec 150 FR/m² ; surface manquante non inventée. Réconciliation nécessaire pour anciens titres/dossiers ambigus.
- **#65** : les conditions indispensables du prêt d'acquisition ne sont pas disponibles dans les arbitrages consultés ; taux, plafonds et durées non inventés. Décaissement lié à acquisition réelle reste à raccorder.
- **#69** : baux annuels/anciens contrats, renouvellement/impayés, stockage privé, contrôle transactionnel de capacité, reçus, résiliation vide et succession complète restent à implémenter avant souscription. La précision sur les unités est désormais résolue ; ce n'est plus une demande en attente. Le calendrier affiché est civil Paris, mais la compatibilité des échéances et anciens baux doit être examinée avant modification ; aucun prélèvement annuel déguisé en débit quotidien ajouté.
- **#63/#64** : protections des sauvegardes financières, dépendances vivantes, RLS/grants et coexistence des anciennes versions nécessitent validation. Les transactions locales ne prouvent pas l'absence de tous les anciens chemins d'écriture de production.

## Déploiement contrôlé et retour arrière

Aucune des migrations préparées n'a été appliquée. Elles restent sous `migrations/`, y compris les nouvelles `20261021213659_placements_nationaux_sources_atomiques.sql`, `20261021214324_reservations_hotel_cumulables.sql`, `20261021220151_succession_refuser_actifs_non_raccordes.sql`, `20261021220316_succession_titres_canoniques.sql` et `20261022115612_inventaire_unites_et_retrait_multilignes.sql`. Leurs gardes refusent une définition différente de celle examinée. Ne pas jouer aveuglément tout le répertoire.

Avant toute activation, l'agent doit obtenir le catalogue vivant en lecture seule, examiner corps/grants/triggers/RLS et chemins d'écriture, préparer un lot indépendant de commits, vérifier les écarts, puis tester sur un environnement isolé cohérent et des comptes autorisés. Conserver l'ordre PR58 → PR71, et garde de types successions → patch de titres (l'inverse est refusé à juste titre). Utiliser le canal de migration enregistré prévu par WORKFLOW-SUPABASE.md ; aucune commande à déléguer au game designer.

Après application seulement : réextraire baseline/seeds avec les générateurs, relancer contrôles puis tests authentifiés et observation du déploiement Vercel. Avant application, abandonner une branche suffit. Après actes réels, pas de restauration d'anciens soldes/patrimoines : conserver reçus, réservations et placements, utiliser des corrections en avant et un client compatible avec les droits déjà acquis. Les définitions d'avant et dépendances vivantes doivent être conservées par l'agent de déploiement ; une ancienne interface ne doit pas pouvoir effacer les nouveaux droits.

**Priorité suivante : terminer le pipeline commun #57 et la chaîne #69, tout en rétablissant le prévol technique permettant de valider les lots indépendants #63/#64/#68. Le chantier global n'est ni clos ni prêt pour un déploiement en bloc.**
