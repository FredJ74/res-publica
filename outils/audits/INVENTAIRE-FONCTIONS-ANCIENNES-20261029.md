# Inventaire des anciennes fonctions et voies d'écriture encore susceptibles d'être actives — 29 octobre 2026

**Périmètre :** dépôt `FredJ74/res-publica`, audit historique `AUDIT_UNE_SEULE_VERITE.md` (avec ses corrections consignées au 27 octobre), prévol Supabase vivant déjà recueilli pour PR #230, rapports #219 et PR #213. **Lecture seule ; aucune migration, fonction, droit ni donnée de jeu modifié.**

## Règle de lecture — trois niveaux de preuve

- **V — Confirmé vivant** : définition d'une fonction réellement extraite de PostgreSQL au prévol précédent. Cela prouve sa présence et son comportement SQL, **pas** qu'un joueur l'a effectivement déclenchée récemment.
- **H — Historique encore signalé ouvert** : déclaré restant par `AUDIT_UNE_SEULE_VERITE.md` après prise en compte de sa section « Suivi des corrections ». **Recontrôle en production requis**.
- **C — Corrigé selon l'audit, à surveiller** : ne pas présenter comme une faille active sans nouvelle preuve.
- **D — Ancien code déclaré mort** : ne pas confondre présence éventuelle et fonction encore invoquée.

**Limite de cette session :** une nouvelle interrogation Supabase `pg_proc` (lecture seule) a été bloquée par les contrôles d'accès de l'outil ; il n'est pas possible de certifier une liste exhaustive des fonctions actives ni leurs `EXECUTE`/appelants. Les confirmations V sont des observations réelles du prévol précédent, pas un sondage exhaustif réalisé ici.

## A. Confirmé vivant dans PostgreSQL (V)

| Fonction | Comportement confirmé par sa définition SQL vivante | Risque / action |
|---|---|---|
| `pnj_miroir_police(p_pays,p_ville,p_batiment)` | Lit `batiments_etat.effectifsPolice.policiers` et écrase `pnj_membres.ville/building_id/room_id/rue_noeud_id` via `ON CONFLICT DO UPDATE` | **CRITIQUE pour #219** : deuxième écrivain de position des policiers. Raccorder le miroir à une seule autorité ou empêcher la reprise des positions obsolètes, avec test de non-régression. |
| `rue_position_enregistrer(p_noeud)` | Verrouille `personnages_donnees`, vérifie prison/interception, voisins/sortie, écrit `current_street` pour **un** PJ | **Non obsolète par nature** ; incompatible avec mouvement collectif si appelée pour chaque PJ indépendamment. Préserver les contrôles et exiger atomicité groupe. |
| `militaire_blob_projeter(p_compagnie)` | Fonction présente (corps non examiné dans le prévol partiel) | **À vérifier** : projections militaires concurrentes du socle PNJ; inventorier corps, dépendants et écrits. |
| `militaire_bataille_recruter(p_bataille_id,p_camp,p_ville,p_bat,p_piece)` | Fonction présente | **À raccorder** à la participation PJ/PNJ des groupes, sans nouveau moteur de rounds. |
| `militaire_bataille_combattants(p_bataille_id,p_camp)` | Fonction présente | Vérifier la sélection de soldats métier contre les nouveaux groupes mixtes. |
| `militaire_bataille_poursuivre(p_bataille_id)` | Fonction présente | **Moteur à conserver**, doit être réutilisé par combats collectifs ; vérifier ses entrées. |

La fonction `groupe_pj_lire` ne figurait pas parmi les fonctions vivantes retrouvées au prévol antérieur ; absence de preuve d'installation de #219 en production. Les fichiers de migration dans GitHub ne prouvent pas leur application.

## B. Voies anciennes recensées encore ouvertes à la fin de l'audit historique (H)

### Sécurité et état du personnage

1. **Sauvegarde de fiche complète** : `sbSavePersonnage`/`personnages_vue_modifier` et ses protections. L'audit décrit des écritures client encore acceptées sur santé, moral, lieu, prison, hospitalisation, poison, employés, domicile, enquêtes, effets. **Statut actuel incertain** après les chantiers #213/#219/#225 ; l'audit de la fiche versionnée a aussi identifié que `updated_at` n'est pas automatiquement avancé par tous les écrivains. Inventorier colonnes, triggers, RPC et privilèges réels, pas seulement les JS.
2. **Déplacement / arrestation / groupe** : `rue_position_enregistrer`, projections police et militaire, vieille position dans `effectifsPolice` : vérifier chaque chemin écrivant pays/ville/bâtiment/pièce/rue et ce que fait une ancienne sauvegarde chargée avant une mutation serveur. Pas de changement de garde sans preuves d'une transaction unique.
3. **`impact_deposer`** : l'audit a signalé que le navigateur choisissait les dégâts ; l'option `hp_set` fut ensuite **fermée** au 27/10. **Ne pas prétendre** que `hp_set` reste ouverte ; auditer les autres modes/signatures.
4. **`personnage_ajuster_pop_inf`** : registre de causes et montants historiquement choisis par le navigateur, mais causes `rumeur_pj`/`rumeur_gouvernement` **sécurisées** par `rumeur_lancer` au 27/10. Vérifier uniquement les autres causes et la propriété des valeurs.

### Institutions, finances et tables écrites directement

5. `organisations`, `prets` : déclarées encore non reprises dans l'audit au 27/10 ; chantiers parallèles depuis. Vérifier les ACL/RLS **actuelles** avant toute qualification.
6. `budgets_clubs` et `transferts_clubs` : cotisations, sponsoring, boutique, transferts et subventions historiquement écrits depuis le navigateur. **Priorité haute** tant qu'une RPC serveur ne remplace pas toutes les écritures.
7. `indices_villes` : sécurité/économie/social/moral historiquement écrits par le navigateur ; **piété** déjà protégée côté serveur (ne pas la signaler comme ouverte).
8. `budgets_municipaux` : taux foncier et interdiction de manifester ; `niveaux_prison` : rébellion et niveau. Recontrôler ACL et actions.
9. `evenements_globaux`, `addExternalEvent` : annonces publiques créées par le client historiquement nombreuses. Les ambassades et les actions migrées avaient déjà été corrigées ; rechercher **uniquement les appelants restants** et tester que les annonces non attestées sont refusées.
10. `acheterLotNonReclameeFret` : ancien achat de lot de fret déclaré 100% navigateur, sans débit ni dépôt réel au 26/10. Statut **possiblement corrigé par #213**, à vérifier sur branche et prod.
11. Tables à réévaluer après les remédiations partielles : `budgets_nationaux`, `mariages`, `demandes_mariage`, `successions`, `dossiers_urbanisme`, `logements_demandes`, `petites_annonces`, `caisses_fret`, `contenu_caisses_fret`, `championnat`, `quetes_actives`. Ce sont des **candidats historiques**, pas des failles vivantes confirmées.

### Simulation / tâches automatiques

12. **Minuit dans `plateau-core.js`** : `runMidnightUpdate` gardait certaines opérations clientes. Déjà migrés au serveur : couvre-feu, recherche militaire, convocations, découverte de crimes, scandales, informateurs. Restent **à vérifier pour les actes non encore migrés** : `checkEffacementCrimes`, `verifierDecouverteCrimesPasses` pour traces spécifiques (permis, hooliganisme), et leurs appelants.
13. **Tirages aléatoires clients résiduels** : la liste d'origine d'environ 95 cas est une base de recherche **historique**, pas 95 anomalies actuelles (beaucoup corrigées au 27/10). Rechercher parmi douanes/transports spéciaux, football, organisation, justice et autres empires ; différencier tirages RP cosmétiques et effets réels.
14. **Échéances `Date.now()`** : vieux chemins de couvre-feu, votes, cadavre, convocations, presse. Plusieurs migrations déjà réalisées ; vérifier que le serveur impose toujours la date et non un timestamp client.
15. **États locaux `state.*` et inventaire** : `inventaire_sauver_revision` acceptait historiquement un inventaire arbitraire ; la PR #213 y apporte des protections mais elle n'est pas fusionnée. Vérifier la version **en production**, et ne pas attribuer à celle-ci le comportement d'une branche non livrée.

## C. Correctifs consignés et **à ne pas déclarer encore ouverts sans preuve contraire**

- `batiment_caisse_mouvement`, `caisse_institution_mouvement`, `caisse_client_mouvement` : crédits client arbitraires déclarés bloqués le 26/10 (migrations `20261026020000` et `020100`).
- `ordre_generique_executer` : ordre générique remis au serveur le 27/10.
- `objet_abandonne_ramasser` et `objets_abandonnes` : ramassage serveur / écriture client fermée.
- `religion_agir` / `contributions_piete` / `titulaires_pnj` : action de religion et postes sécurisés.
- `dementi_executer`, `rumeur_lancer` : rumeurs/démenti sécurisés pour leurs causes couvertes.
- `cycle_electoral_initialiser`, `assemblee_dissoudre`, `election_contester`, `fraude_electorale_tenter`, `vote_confiance_declencher`, `vote_confiance_voter` : corrections électorales consignées.
- `minuit_convocations`, `minuit_scandale`, `minuit_decouverte_crimes`, `minuit_informateurs` : opérations de nuit transférées au serveur.
- `crime_voler`, `crime_empoisonner`, `crime_neutraliser`, `crime_incendier`, `crime_explosifs`, `crime_corrompre`, `crime_falsifier`, `crime_contrebande` : corrections serveur consignées.
- `inventaire_deposer_interne`, `tracts_imprimer`, `recolte_effectuer` : remédiation initiée ; **ne pas affirmer que tout l'inventaire est verrouillé** tant que #213 n'est pas publié et éprouvé.

## D. Code mort précédemment recensé (D) — ne pas confondre avec une fonction active

`sbSaveCompagnie`, `sbCreerEngagement`, `sbCreerFaitArmes`, `sbArchiverLoi`, `sbCreerPari`, `sbSavePresidentClub`, `calculerResultatElection`, `doCorrompreGardien`, `doFalsifierDocs` : suppression **déclarée** au 27/10. `interagirPnjTerrain` conservée volontairement pour le banc terrains. `confirmerBourrerUrnes` et `confirmerFalsifierListes` étaient de faux « morts » : appel dynamique HTML confirmé.

## E. Protocole de purge « une seule vérité »

1. Extraire depuis **PostgreSQL vivant** : `pg_proc` (signature, définition, `SECURITY DEFINER`), `pg_depend`, `pg_trigger`, ACL `EXECUTE`, vues et politiques RLS ; tracer toute écriture de `personnages_donnees`, `pnj_membres`, finances, inventaire, événements. Aucune modification durant l'inventaire.
2. Croiser avec **tous les appels réels** du client, API, crons, HTML dynamique et fonctions SQL ; distinguer invocation directe, indirecte et absence d'appelant.
3. Attribuer pour chaque champ/table **un seul écrivain canonique** ; ancien composant : supprimer seulement s'il est mort, sinon adapter pour déléguer à ce moteur, sans écraser ses protections.
4. Éprouver par banc PostgreSQL transactionnel (concurrence, deux PJ, police, PNJ, coups réseau perdus, connexion décalée, minute Paris). Tester explicitement qu'une **ancienne écriture** ne peut plus contredire la nouvelle.
5. À la fin du chantier, nouveau contrôle vivant des droits/trigger + recette authentifiée ; archiver les empreintes avant/après et les noms exacts des fonctions supprimées ou devenues adaptateurs.

## Résultat

**6 fonctions confirmées présentes dans le catalogue vivant antérieur, dont une voie d'écriture concurrente de position policière confirmée** ; 15 familles de risques historiques à requalifier sur l'état vivant ; remédiations déjà consignées explicitement distinguées. **Ce document n'est pas un certificat d'exhaustivité en production.** Il sert de registre contrôlable pour la clôture #230 et l'audit universel de Human Gambit.

## F. Contre-vérification du code de production (`main`) — 29/10, confirmation supplémentaire

**Preuve directe côté code (pas simple extrapolation de l'audit historique) :**

1. **Achat de lots de fret non réclamés : ancienne mécanique toujours câblée sur `main`.** Dans `plateau-justice-economie.js`, le bouton HTML invoque effectivement `acheterLotNonReclameeFret(caisseId)`. Ce gestionnaire appelle `sbUpdate('caisses_fret', ... statut:'vendue')`, diminue **localement** `state.arg -= prix`, appelle `crediterCaisseBatiment`, crédite les objets via `addToInventory` ou `state.inventory.push`, et met à zéro des lignes via `sbUpdate('contenu_caisses_fret', ...)`, avant `sbSavePersonnage(state)`. **C'est une voie cliente ancienne confirmée présente dans le code publié ; son effet réel sur PostgreSQL dépend des ACL/trigger en vigueur et ne peut être affirmé sans sondage vivant.** Elle n'est pas une vente atomique vérifiée. La branche d'intégration #230 remplace le corps de cette fonction par `executerReceptionInventaire('fret_objet_agir',{ p_caisse:caisseId,p_action:'acheter' })`. **Cette correction existe dans la PR, pas en production.** Risque élevé d'achat incomplet/rejeté, et divergence des affichages.
2. **Découverte différée de crimes : ancienne décision client confirmée sur `main`.** `plateau-core.js` appelle encore `verifierDecouverteCrimesPasses()` à la passe locale. La fonction de `plateau-justice-economie.js` filtre `state.historiqueCrimes`, réalise `Math.random()` pour la découverte, modifie la liste locale, déclenche `procederArrestation` et tente un mail. Elle exclut les traces marquées `origine:'serveur'`, ce qui réduit le périmètre, **mais ne fait pas disparaître la seconde autorité pour les traces historiques clientes**. Prévoir transfert au traitement serveur des traces restantes ; ne pas supprimer avant reprise de leurs productrices.
3. **`runMidnightUpdate` : routine navigateur encore présente sur `main`.** Elle appelle encore `checkEffacementCrimes()` et la découverte ci-dessus. Plusieurs étapes ont été retirées et remplacées par le cron, donc **ne pas déclarer la totalité du traitement nocturne encore client**. Le cron `api/cron-minuit.js` est bien présent en parallèle.
4. **`militaire_blob_projeter` : appelée depuis le cron sur `main`.** `api/cron-minuit.js` contient `await sbRpc('militaire_blob_projeter', { p_compagnie: r.id })`. La présence de cette invocation côté serveur est démontrée ; son impact exact sur les positions doit être examiné dans la définition SQL vivante.
5. **Sauvegardes :** `sbSavePersonnage` possède encore de nombreux appelants sur `main` (notamment `plateau-core.js`, `plateau-justice-economie.js`, `plateau-politique.js`). Le nombre d'appels ne démontre pas à lui seul une faille : c'est le **jeu des colonnes acceptées par le déclencheur et les RPC** qui définit l'autorité. Le prévol PR #225 reste bloquant.

### Priorités vérifiables issues de cette contre-vérification

**P0 — Ne pas livrer de double autorité :** arrêter toute promotion de #230 tant que le miroir police et les sauvegardes de position ne sont pas verrouillés atomiquement. **P1 — Déployer après validations les remplacements déjà réalisés dans #213 :** achat de fret via transaction serveur et inventaire. **P1 — Purger le minuit client restant :** migrer le traitement des anciennes traces vers la seule passe de nuit, puis retirer ses déclenchements locaux. **P2 — Poursuivre l'inventaire des autres écrivains par table et autorisation réelle.**

**Accès au catalogue vivant :** les deux nouvelles requêtes SQL ont été bloquées par les contrôles d'outils pendant cette session. Aucune conclusion nouvelle sur les droits PostgreSQL actuels n'a été inventée. Cette partie prouve la **présence et l'appel de code côté dépôt**, pas son effet serveur final.

## G. Contrôle direct du catalogue et des ACL Supabase — reprise du 29/10/2026

**Nature : preuve du catalogue de production en lecture seule.** Projet `jxpwoosmmhohoihxpbuc`. Aucun personnage, droit, déclencheur ou schéma modifié par les requêtes.

- `pg_proc` : **1 147 fonctions du schéma public**, toutes catégories confondues ; ceci n'est pas un nombre de fonctions anciennes ni de fonctions effectivement appelées.
- Les définitions ont été retrouvées pour `pnj_miroir_police`, `rue_position_enregistrer`, `inventaire_sauver_revision`, `militaire_blob_projeter`. `groupe_pj_lire` est absente du résultat par nom (et aucune installation de ses migrations n'est démontrée).
- ACL RPC : `rue_position_enregistrer`, `inventaire_sauver_revision`, `fret_objet_agir` et `militaire_bataille_poursuivre` sont exécutables par `authenticated`, pas `anon`. `pnj_miroir_police`, `militaire_blob_projeter` et `personnages_vue_modifier` ne sont exécutables directement par aucun de ces deux rôles. Les sept fonctions sondées sont `SECURITY DEFINER` : contrôler leurs propres gardes et leurs appelants internes.
- `personnages_donnees` et `pnj_membres` : pas de privilège direct `INSERT/UPDATE/DELETE` accordé à `authenticated`; présence de déclencheurs protecteurs à ne pas neutraliser sans inspection.

### Portes RLS confirmées — action prioritaire

| Table | Privilèges authenticated | Politique d'écriture constatée | Qualification |
|---|---|---|---|
| `prets` | INSERT/UPDATE | `acteur_identifie()` | V — accès général, trigger `pret_versionne_ecriture_proteger` à analyser avant conclusion d'exploitation |
| `organisations` | INSERT/UPDATE/DELETE | `acteur_identifie()` | V — porte générale, vérifier les autres triggers/gardes métier |
| `budgets_clubs` | INSERT/UPDATE | `acteur_identifie()` | V — porte générale |
| `transferts_clubs` | INSERT/UPDATE | politiques présentes, corps non extrait ici | V — privilège direct, qualification des politiques à compléter |
| `budgets_municipaux` | INSERT/UPDATE | `acteur_identifie()` | V — porte générale |
| `indices_villes` | INSERT/UPDATE | `acteur_identifie()` | V — porte générale |
| `niveaux_prison` | INSERT/UPDATE | `acteur_identifie()` | V — porte générale |
| `caisses_fret` | INSERT/UPDATE | `acteur_identifie()` | V — porte générale, trigger `assemblee_fret_vente_legale` sur mise à jour de `statut` |
| `contenu_caisses_fret` | INSERT/UPDATE | `acteur_identifie()` | V — porte générale |
| `evenements_globaux` | INSERT | `acteur_identifie()` | V — porte générale |

**Distinction indispensable :** un privilège SQL + une politique permissive démontrent une voie d'accès, non le succès d'une écriture arbitraire dans tous les cas : déclencheurs, contraintes et fonctions peuvent encore la rejeter. Les sondages étaient exclusivement des SELECT système, aucun essai destructif réalisé sur les données réelles.

### Décisions techniques à réaliser et vérifier, sans précipiter la production

1. Répertorier chaque appelant client/serveur des tables ci-dessus ; préparer pour chaque écriture utile son RPC canonique transactionnelle (réutiliser les RPC existantes).
2. Vérifier les triggers (`pret_versionne_ecriture_proteger`, `assemblee_fret_vente_legale`) et les effets exacts de `pnj_miroir_police` ; ne pas casser les prêts ni les ventes de fret.
3. Retirer **après** remplacement effectif les permissions directes et politiques permissives. Tester en contexte `authenticated` que les anciennes écritures sont refusées et les parcours officiels acceptés.
4. Clôturer la migration groupes atomique et les bancs de concurrence, puis réexaminer la PR #230 sur son SHA actuel, avant fusion ou déploiement.
