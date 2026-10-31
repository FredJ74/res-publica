
### Priorité P0 explicite — affichage navigateur / vérité serveur (29/10)

**Responsable unique : ChatGPT (coordination avec Codex pour socle inventaire/groupes).** La clôture Luthécia exige : (1) cartographier les valeurs calculées, sauvegardées ou affichées localement sans confirmation serveur ; (2) supprimer/adapter les anciennes écritures qui écrasent positions, inventaire, soldes, santé, moral, sanctions et état du PJ ; (3) sécuriser chargement, autosauvegarde, perte de réponse, reconnexion, changement de version après déploiement ; (4) tester égalité état UI / état canonique après action, refresh, reconnexion et deux sessions, sans mutation d'un PJ réel lors de l'audit. **Ne pas confondre suppression d'une double autorité avec simple actualisation cosmétique.** Les six fermetures liées à #213 restent subordonnées à prévol et validation. Toute régression de cette catégorie bloque la promotion en production.

## Arbitrage du 29 octobre 2026 — clôture Luthécia au 1er novembre

**Décision explicite du game designer : Claude reprend les cinq terrains et l'intégralité du parcours immobilier.** Codex cesse les nouveaux changements sur ce périmètre (parcelles, occupation, compromis, notaire, permis, construction, approvisionnement, division, livraison, rénovation), y compris dans ses PR historiques ; il transmet à Claude les branches/PR, commits, migrations et résultats de tests existants. Claude repart du dernier main et incorpore les modifications vérifiées sans écraser les travaux du socle.

**Répartition sans chevauchement :**
- **Claude :** terrains, immobilier, prêts et placements fonctionnels ; revue/correction des défauts bloquants commerce, électronique, premium, presse, PNJ et douanes. Sur sécurité privée, il ne touche qu'au raccordement immobilier après livraison du socle commun.
- **Codex :** inventaire serveur, groupes PJ/PNJ, police/armée, sécurité privée universelle, combats par rounds, atomicité des déplacements, transports et anciennes écritures concurrentes propres à ce socle. Pas de modification immobilière, sauf transmission de correctifs déjà préparés.
- **ChatGPT :** inventaire réel SQL/ACL/RLS des autres écrivains, fiche personnage, orchestration PR #230, migration et fermeture des anciens accès inventaire après vérification, tests combinés, fusion et production. Les **six fermetures associées à #213** doivent être identifiées précisément avant exécution ; ne jamais les inventer ni les appliquer sur une livraison incomplète.

**Cadence de livraison :** une fenêtre de livraison quotidienne en fin de journée pour les lots **prêts et testés**, sans obligation de livrer si garde bloquante ; pas d'accumulation forcée jusqu'à dimanche. Avant chaque livraison, rebase/réconciliation sur main, tests de l'exact SHA, prévol SQL, migrations ordonnées, contrôle Vercel READY et recette. Les modifications communes (`data.js`, `plateau-*.js`, `supabase.js`) sont ciblées et les agents repartent du dernier main publié.

**Critère dimanche :** Luthécia jouable sans défaut bloquant, données des PJ protégées, parcours essentiels vérifiés. Les non-bloquants restent listés explicitement : ne pas les présenter comme terminés. Ne pas repousser un verrou de sécurité qui expose directement argent, inventaire, position ou sanctions si la voie reste exploitable.

---

# Relais entre agents

Passage de témoin entre Codex et Claude. Mis à jour à **chaque push**.
Règles : voir `AGENTS.md`.

## En cours

Rubrique nettoyée le 31/10 (Claude) : les chantiers livrés sont passés dans « Derniers chantiers » ; l'ancien texte détaillé reste dans l'historique Git de ce fichier (`git log -p RELAIS.md`).

### Codex — #219 : reconstruction réussie, livraison retenue

Branche `codex/groupes-universels-20261028`, PR #219, main intégré jusqu’à `3aa6ceef` (#290). Rapport de reprise : `outils/audits/RECONSTRUCTION-CANONIQUE-GROUPES-219-20261031.md`, preuves sous `preuves-canonique-219-20261031/`. PostgreSQL 17.6 natif, 88 migrations atomiques et 30 parcours sur catalogue entier validés ; 149 bancs clients et 105 Chromium passent. **Global 10/12, prérequis #233 et recette authentifiée isolée encore à valider : ne pas fusionner ni déployer.** Aucun nouvel export canonique à demander, aucune production modifiée par cette intervention. Ne pas ouvrir le chantier suivant.

### Migrations fusionnées, en attente d'application (ChatGPT)

**Prises en charge par ChatGPT (Fred, 31/10)** : `20261031130000` et `20261031140000`.

Vérifier toujours une migration par son **NOM** dans `supabase_migrations.schema_migrations`, jamais par son numéro.

- `20261031130000_reliquats_immobilier_accord_tacite_succession` (PR #284, fusionnée) : accord tacite de nuit (aujourd'hui toujours en échec : le permis de Jean Jaaj, terrain 5, en dépend dans environ 6 jours) et colonnes `proprietaire` / `coproprietaire` à la succession. Indépendante de l'écran. Banc : `outils/bancs/banc-reliquats-immobilier.sql`.
- `20261031140000_helvetia_caisse_argent_detenu` (PR #285, fusionnée, #267) : la caisse d'Helvetia représente l'argent détenu (prêt sans débit de caisse, sommes prises sur le compte Helvetia sans recrédit, dépôt d'ouverture crédité). Indépendante de l'écran. Banc : `outils/bancs/banc-caisse-helvetia.sql`.
- `20261031151000_placement_helvetia_gain_unique` (Claude, 31/10, suite de #267) : à la résolution d'un placement Helvetia, le gain net n'est plus ajouté à `arg` (argent total liquide + Banque nationale, où il apparaissait en double) et entre dans la caisse avec les frais. Indépendante de l'écran ; **à appliquer avant le 6/11** (échéance du placement actif de Jean Jaaj). Banc : `outils/bancs/banc-placement-helvetia.sql` (attendu sur ce placement : caisse +6 314, compte +83 340, `arg` +0).
- `20261031113650_squatteurs_issue_combat` (ancien préfixe `20261029181000`, rehorodatage documentaire #219) : **attend le combat de groupe de Codex (#219)** ; ne pas appliquer avant.

### Décisions attendues de Fred

- **Fonds et murs des commerces (#66)** : règles décidées le 21/10 (murs à 150 FR/m², La Republica 1 200 m², fonds et murs indépendants, achat conjoint atomique, murs des commerces PNJ à la commune), **rien n'est en production**. La PR #71 qui les implémentait est périmée (laissée ouverte, commentaire du 31/10) : à reconstruire depuis main si Fred en fait une priorité.
- **Ambassades** : griser « Bientôt disponible » les ordres non raccordables tant que le voyage entre empires n'existe pas (immunité, arrestation de l'expulsé, transfert de détenus, naturalisation). Référence : `GAME-DESIGN-AMBASSADES.md`.

### Points ouverts transmis (non bloquants)

- **Refinancement BNR en trop d'Helvetia (#267)** : annulé par `20261031150000_helvetia_bnr_excedent_regulariser` (PR #288, appliquée) ; Fred a laissé le choix à Claude, qui garde l'annulation (la première note « remboursement normal » est caduque). Voir `GAME-DESIGN-BANQUES.md`.

- **Helvetia, même famille que #267 (examiné le 31/10)** : `finaliser_achat_bien_helvetia` est juste (acompte et solde viennent du liquide ou de la Banque nationale, jamais du compte Helvetia). `resoudre_placement_helvetia` corrigé par `20261031151000`. Le seul placement déjà résolu (Jean Jaaj, 25/10) a ajouté 3 920 FR fantômes à son `arg` ; non régularisé, car son `arg` s'écarte déjà de liquide + Banque nationale de bien plus (≈ 47 000 FR ; Angie aussi, en sens inverse) : écart général de `arg` à examiner côté fiche (ChatGPT).
- **Codex** : `minuit_decouverte_crimes` (police) retire des amendes de `arg` sans les verser nulle part ; il peut appeler `amende_imposer_interne`. Le hooliganisme (organisations) écrit encore sa trace de crime à l'écran (à passer par `crime_tracer_interne`). Écritures de l'écran encore ouvertes : `budgets_clubs`, `organisations.caisse` (bilan `outils/bancs/ECRITURES-ECRAN-20261029.md`).
- **Budget national (répété le 31/10, annulé)** : Jean Jaaj (min_fin) change le taux national 5 → 6, sa fausse réserve du Trésor glissée dans la même écriture est ignorée ; Arnie (min_def) ne change rien. La garde fonctionne ; seul bémol, le refus d'un non-titulaire est silencieux (valeur conservée), pas nommé.
- **Baseline (ChatGPT, #262)** : `payer_ordre`, `inventaire_place_restante` et `personnages_convocations_garder` diffèrent en production des migrations du dépôt (copie dans `jetable-ecarts-production-20261030.sql`) ; `acquisitions_transactions_internes` n'est créée par aucune migration rejouable.
- **PNJ encore muets (déclarés dans `banc-dialogue-pnj-republia.js`)** : Maître Ali Bihanbeton et Maître Henri Nossant (avocats commis d'office de PSM et Montrouge), huit députés.
- **Sécurité privée #135** : PR #196, #212, #216, #217 ouvertes ; décision de Fred du 27/10 dans `AGENTS.md` (deux socles seulement, aucune affectation au chantier). Le raccordement reste à tester en production.
- **Issue #143** : passer toutes les fenêtres à la charte ardoise et or.

### Consignes durables pour tous les agents (reprises des chantiers des 26-30/10)

- Popularité ou influence rendue par une RPC : `adopterJaugeServeur('pop'|'inf', valeur)`, jamais `state.pop = v.pop` (double comptage à la sauvegarde suivante).
- Réponse serveur qui change l'inventaire : elle rend `inventory` et `revision`, l'écran l'adopte par `sbAdopterInventaireServeur(v)`. Tout nouvel objet est déposé par le serveur (`inventaire_deposer_interne`).
- Acte illégal : détection tirée dans sa fonction serveur (`crime_detecter_interne`), trace par `crime_tracer_interne`, jamais `checkDetection` à l'écran. Un dégât ou une fermeture se pose dans la fonction serveur de l'acte.
- Tout retrait de motif de recherche passe par une fonction serveur qui sait pourquoi ; tout crédit de caisse se fait dans la fonction serveur de l'action.
- Une fonction serveur écrit `personnages_donnees`, jamais la vue `personnages` (voir `AGENTS.md`).
- Bancs SQL : se placer au rôle `authenticated` (sinon `est_appel_serveur()` est vrai et masque les défauts) ; poser `request.path` = `/rpc/...` pour les écritures d'inventaire (sinon `inventaire_revision_garder` les annule).
- La passe de nuit pose `cycle.dernierScrutin` à chaque proclamation : ne pas le retirer, la contestation en dépend.

### À vérifier en jeu (Fred, Angie, Vince)

- Terrain occupé par des squatteurs : « Appeler la police » propose l'intervention légale (1 PA, sans paiement) et la corruption (coût et taux annoncés par le serveur) ; « Faire disparaître le corps » sur un cadavre.
- Après application de `20261031130000` : le permis de Jean Jaaj (terrain 5) est accordé tacitement à la fin de l'instruction, attestation et courrier reçus.
- Chez Petit : « Monsieur le ministre » / « Madame la ministre » selon le genre du personnage (#281).
- Chez le notaire : « Officialiser une transaction » → « Vente de terrain » → « Confirmer » (#269).
- Louer un local dans les centres de Montrouge et de PSM ; acheter un terrain pour la commune en tant que maire ; attribuer un logement social en tant qu'adjoint.

## Derniers chantiers
- 31/10/2026 — **Placement Helvetia (PR #289, fusionnée)** : gain net versé une seule fois, caisse créditée frais + gain ; migration `20261031151000` en attente d'application (avant le 6/11). Annulation BNR de #288 conservée (choix délégué par Fred).
- 31/10/2026 — **Quêtes (PR #290, fusionnée)** : écritures mortes de `quetes_actives` retirées de l'écran (déjà en lecture seule en base), baseline réaligné.
- 31/10/2026 — **PNJ Norbert Charton et Yvon Paletier (PR #291, fusionnée)** : fiches de personnalité écrites sur délégation, à la relecture de Fred.
- 31/10/2026 — **Reliquats immobiliers (PR #284, fusionnée `88a317b8`)** : revue des vieilles PR #139, #123, #118, #114, #113, #112, #71, #58 (49 de leurs 53 migrations en production ; sept PR fermées avec justification, #71 laissée ouverte). Police, corruption de l'inspecteur, expulsion légale et dissimulation d'un cadavre décidées par le serveur ; interventions échues traitées la nuit. Migration `20261031130000` en attente d'application.
- 31/10/2026 — **Caisse d'Helvetia = argent détenu (PR #285, fusionnée `05bbe5e4`, #267)** : migration `20261031140000` en attente d'application ; refinancement BNR en trop laissé à la décision de Fred.
- 31/10/2026 — **Genre du personnage dans les dialogues PNJ (PR #281, fusionnée, migration appliquée sous le nom `genre_personnage_serveur_20261031100000`)** : création refusée sans genre, civilité « Monsieur / Madame le ministre » dans les dialogues et la conférence de presse.
- 30/10/2026 — **Signature chez le notaire (PR #269, fusionnée)** : l'écran ne prélève plus le solde, le serveur encaisse à l'acte après avoir versé le prêt.
- 30/10/2026 — **Argent écrit par les fonctions serveur (PR #265, fusionnée, migrations `210000`, `211000`, `212000` appliquées)** : dix-neuf fonctions écrivent `personnages_donnees` ; la vue refuse bruyamment ; Jean Jaaj régularisé (150 000 FR).
- 30/10/2026 — **Capacité de l'Entrepôt (PR #261, fusionnée, `20261030200000` appliquée)** : place comptée par `inventaire_place_restante` ; achats simultanés éprouvés sur base jetable.
- 30/10/2026 — **Amendes au Trésor national (consolidée dans #255, migrations `20261030100000` et `110000` appliquées)** : dette prélevée chaque nuit, appel suspensif, fraude électorale par le même canal, garde du budget national.
- 29/10/2026 — **Mairies, terrain acheté par la commune, logements sociaux, commissariats (#243, #244, #246, #253, livrés par la PR consolidée #255, migrations appliquées)**.
- 29/10/2026 — **Centres des trois villes et location par le serveur (PR #240, fusionnée, migrations appliquées)** ; **écritures de l'écran et mariage par le serveur (PR #241, fusionnée)**.
- 29/10/2026 — **Terrains, parcours immobilier, prêts, placements (PR #233)** et **vérification commerces, électronique, premium, presse, PNJ, douanes (PR #234)** : fusionnées, toutes leurs migrations appliquées sauf `20261029181000` (squatteurs, attend #219). #224 (loyers) fermée avec preuve le 31/10.
- 28/10/2026 — Stabilisation Luthécia cinq points (ChatGPT, PR #218, fusionnée) ; fiabilisation GitHub / Vercel (Codex, PR #214, fusionnée) ; recette de clôture #135 (Codex, PR #194, fusionnée).
- 24-27/10/2026 — Ambassades et Bureau de l'Emploi (Claude, PR #141, #142, #144, #146, #147, #148, #150, #162, #168, #170, fusionnées) ; « une seule vérité » : ordre générique, religion, jauges, scrutins, justice, crime, informateurs par le serveur (migrations `20261027030000` à `130000` appliquées). Références : `GAME-DESIGN-AMBASSADES.md`, `GAME-DESIGN-BNE.md`, `AUDIT_UNE_SEULE_VERITE.md`.
- 31/10/2026 — **Caisses communales à l'accueil (PR #275, fusionnée `ecedfd97`, en production)** : consultation centralisée retirée ; caisse affichée à l'accueil des 21 bâtiments communaux des trois villes, mairies comprises (commissariat sous contrôle d'accès serveur) ; affichage isolé dans `afficherCaisseAccueilCommunal`, qui répare le contrôle « Cohérence client » rouge depuis #273 ; banc `banc-caisses-accueil-communal.cjs`. À constater en jeu : « Caisse : X FR » à chaque accueil, plus d'ordre à l'Hôtel de Ville.
- 30/10/2026 — #260 (Claude) fusionnée `888eb386`, migrations `20261030180000` puis `180100` appliquées par ChatGPT après déploiement READY : clé d'unicité sur neuf achats, anciennes portes sans clé fermées.

- 30/10/2026 — #258 (Claude) fusionnée `d5be7311`, migrations `20261030160000` et `161000` appliquées par ChatGPT : fiche PJ en fusion à trois voies, double clic, réponse perdue, fermetures fret et historique des terrains. Restent à faire en réel : création authentifiée, pertes de réponse et deux sessions.
- 30/10/2026 — #257 (Claude) fusionnée `d4ee7224`, migrations `20261030135000` et `140000` appliquées : crédits du budget national rétablis, sanctions financières communes au Trésor.

- 24/10/2026 — Mise en place du relais Codex/Claude (`AGENTS.md`,
  `CLAUDE.md`, `RELAIS.md`).

### Intégration inventaire #213 — 29/10/2026

- PR #249 : branche dédiée, issue du `main` 27198955, sans importer les groupes inachevés #219. Les raccordements d'inventaire de #213 sont réconciliés avec le code récent des écrans. Aucun déploiement, aucune migration de fermeture à cette étape.
- Dix migrations métier déjà installées en base ; six fermetures différées au déploiement d'un client compatible : `20261028210000`, `20261028210500`, `20261028210600`, `20261028210700`, `20261028210800`, `20261028210900`. Ne pas activer le verrou final sans observation et accord du game designer.
- CI au SHA de la PR #249 et validation des chemins d'inventaire impératives avant fusion. La garde fret `hg_fret_contenu_source` demeure désactivée en attendant le nouveau client.


### #219 — relais canonique complet reçu, #281 conservée (31/10)

Reprise sur `13bd120a`. Commentaire de relais 6542866046 lu ; quatorze fragments récupérés hors Git, sans publier leurs identifiants. Snapshot annoncé 345374:345374:, coupe UTC 2026-10-31 11:35:45.899473 et registre 1003 à vérifier intégralement. Main #281 intégré, y compris genre contrôlé serveur à la création, contexte PNJ et conférence, sans recréer la migration appliquée. Plus aucun export demandé à Fred ; poursuivre reconstruction, réconciliation et tests. Aucune production ni fusion de #219.

### #219 — reconstruction canonique et première installation réelle locale (31/10, EN COURS)

Relais complet validé hors dépôt (14 fragments, snapshot UTC 11:35:45, registre 1003), main #281 intégré dans 2175f16a. PostgreSQL **17.6 natif** : baseline rendu par les générateurs, 1199 fonctions recompilées, 10913 ordres avec seeds, comparaison sans écart dans le périmètre déclaré (371 tables publiques, cinq exclues documentées ; plateforme hors périmètre). Dix captures de seeds ajoutées ; provenance des 82 tables anciennes conservée, aucune prétendue réextraction. 33 tests outillage passent, dont rangs des colonnes supprimées, fermeture PUBLIC EXECUTE et contre-épreuve sur les bornes CHECK.

Les 88 préparations non appliquées sont rehorodatées après la nouvelle coupe, correspondance versionnée. Défaut réel de paiement corrigé : adaptation du corps examiné actuel, préservant les verrous acquisitions/permis et les fonds en transit. **Première installation atomique des 88 réussie sur cette copie locale**, après installation EXPLICITE du prérequis #233 (présent sur main, mais absent du registre et du catalogue reçus). Ce prérequis n'est pas déclaré déployé. Rapport local /tmp/hg219-lot-fidele-nouveau.json.

Ce n'est PAS la clôture : poursuivre recette sur schéma complet, bancs/contre-épreuves, classement des migrations déjà appliquées, contrôles globaux et cohérence des référentiels. Pas de production, pas de fusion, pas de Vercel, pas de compte réel utilisé. Les exports et identifiants des fragments restent privés hors Git.

### #219 — suite locale complète éprouvée, contrôles 10/12 (31/10, EN COURS)

379/379 scénarios de décors repassés, six mutations détectées (379 cas chacune), 105/105 tests Chromium, 147/147 bancs clients avant l'ultime raccord des coûts. Nouveau décor du catalogue entier : 29/29 scénarios sous les véritables fonctions, dont combats PJ/PJ et PJ/PNJ, rounds, rejeux, refus, radio, détecteur et écrou ; JWT SQL locaux, jamais GoTrue ni joueur réel. Avant/après installation : 12 incompatibilités RPC corrigées, zéro nouvelle ; 17 autres appels historiques/non déployés restent distingués dans le rapport, sans les effacer.

131 migrations attestées archivées avec leur version réelle du registre ; 65 autres conservées comme préparations non attestées et rehorodatées après la coupe, avant les 88 de #219. Aucun changement de leurs règles. Pré-requis #233 désormais `migrations/20261031113650_squatteurs_issue_combat.sql`, non appliqué en production. Workflow, Baseline, Assemblage, Reconstruction et pilote passent. Authority et Referential restent rouges, pas de faux 12/12. Référentiels du monde neuf raccordés aux huit générateurs existants ; les tarifs serveur de crimes sont relus de leur déclaration authored, pas réinventés.

Poursuivre les vérifications finales et l'enregistrement des preuves avant rapport. Production, fusion et Vercel toujours interdits.

### #219 — preuves finales sur main #286, livraison retenue (31/10)

Rapport courant : `outils/audits/RECONSTRUCTION-CANONIQUE-GROUPES-219-20261031.md`. Main intégré `9a821b1b` (#281/#284/#285/#286), sans perdre les adaptations des groupes. La reconstruction native 17.6 et l'installation atomique des 88 ne sont plus bloquées. **30/30 cas sur le catalogue entier** sans remplacement de moteurs, avec fiche fictive préexistante ; une panne après les 88 inscriptions annule les quatre catalogues, le registre et préserve la fiche. 379/379 cas de décors et six contre-épreuves, 148/148 bancs clients, 105/105 Chromium, 35/35 outillage, 19/19 relais et quatre régressions SQL passent. Preuves détaillées dans `preuves-canonique-219-20261031/`.

**NON LIVRABLE en production : global 10/12 (Authority, Referential rouges)** ; prérequis #233 absent du registre/capture, installé uniquement sur le décor ; aucun compte isolé de recette GoTrue. RPC : 29 incompatibilités statiques avant, 17 après, 12 corrigées et zéro nouvelle ; ne pas présenter les autres chemins historiques/non activés comme corrigés. Générateur des coûts 427 triples contre 438 mesurés en base : ne pas régénérer en production pour verdir la référence. Les mesures fraîches sont dans le rapport sans falsifier les anciennes observations. Aucune migration/fusion/commande Vercel de production. API GitHub GraphQL refusée ; Git push reste possible. **Ne pas redemander les exports canoniques, déjà complets et privés.** Ne pas ouvrir un autre chantier.

### #219 — intégration finale de main #290 (31/10)

Main `3aa6ceef` intégré dans `c129bc6c`, après sauvegarde des preuves dans `3e963bcd`. Les protections #283 du refus d'ajout inventaire et les suppressions d'écritures mortes de quêtes #290 sont préservées, ainsi que les changements bancaires #287–#289 (aucune migration appliquée par Codex). Les nouvelles étapes CI sont conservées avec celles de #219 ; caches index/plateau distincts, préfixés par `verrou-inventaire-20261031`. Sur cet arbre : **149/149 bancs clients, 105/105 Chromium, 30/30 sur catalogue entier, huit assertions du verrou #283**. Les 88 sources SQL restent identiques à celles de la dernière passe 379/379 + six mutants ; empreintes vérifiées. Global toujours **10/12**, jamais un feu vert de production. Rapport et preuves actualisés ; aucun nouveau chantier ouvert.

### #219 — nouvelle mission de clôture technique, CI et diagnostic Authority (31/10)

Reprise du vrai HEAD `1be8991b` (les dix fichiers annoncés sont déjà poussés), main #291/#292 intégré. Correction du lecteur SQL de bancs : morceaux générés, sources archivées, surcharges et séquences explicites ; réutilisé par immobilier et restaurant. Leurs anciennes transformations prennent des entrées historiques explicitement épinglées à `13bd120a`, pas un faux catalogue actuel ; gardes et assertions non retouchées. Résultats : **324 assertions immobilier, 94 restaurant**, tant sur 17.6 natif que sur le 16.2 du gestionnaire CI. Le rejet initial des définitions actuelles reste une limite de déploiement des anciens préparatifs, pas une compatibilité affirmée. 379 scénarios groupes repassés après changement du lecteur commun.

Authority : les cinq faux signalements de fonctions créées par CREATE FUNCTION/dans un DO sont corrigés par analyse PostgreSQL des déclarations et des listes VALUES reliées à EXECUTE format. Commentaires et fonctions simplement mentionnées ne comptent pas. Trois bancs de détecteur passent avec contre-exemples. Le parseur existant est installé avant les bancs clients dans la CI, sans second pipeline. Invariant 12 conforme ; **invariant 13 reste rouge (19 formes absentes ou incompatibles dans le catalogue capturé)**. Aucune migration, fusion ou production. Poursuivre Referential, raccordements et inventaire de clôture sans masquer ces écarts.

### #219 — paquet complet atomique et preuves après #292 (31/10, EN COURS)

Prérequis #233 et 88 migrations désormais préparables dans **une seule transaction** (`preparer-groupes-219.py --inclure-prerequis-233`). Épreuve native PostgreSQL 17.6 avec `--lot-219 --paquet-complet-219 --recette-219` : reconstruction fidèle dans le périmètre déclaré, 89 installations, 30 cas réels ; panne tardive annule aussi le prérequis, registre reste à 1003 et fiche fictive préservée. Aucun déploiement réel. 38 tests de l’outillage passent, dont refus de prérequis omis et de SHA altéré. Ne pas activer #233 séparément sur la production. Le canal distant capable d’exécuter cette transaction complète reste à valider ; la limite par appel MCP n’est pas une preuve de livraison possible.

Le diagnostic des cinq mesures est STRICTEMENT en lecture seule (`diagnostiquer-mesures-referentiels.py`) ; aucun changement de baseline, d’attentes ni d’observations. Une tentative d’actualisation a été refusée par la revue automatique pour risque de masquer Referential ; changements retirés, pas de contournement. Coûts : 427 générés contre 438 capturés ; postes et ressources concordent avec le contenu capturé, mais leurs sentinelles sont périmées. Global toujours **10/12**, Authority (19 formes RPC) et Referential rouges.

Mails : défilement déjà présent, testé dans Chromium avec rendu/CSS réels, deux largeurs et contre-épreuve de l’ancien défaut (3/3) ; aucun écran recodé. Caisses à l’accueil déjà intégrées #275 ; fonds/murs #71 non intégrés selon le relais actuel. API Actions refusée et ressources Vercel refusées (403) depuis cet environnement : aucun statut distant vert ni recette authentifiée revendiqué. Les exports restent privés hors Git.

Dernière passe complète après ces corrections : **150/150 bancs clients**, zéro échec, sockets locaux autorisés. Une première exécution confinée avait neuf échecs d’infrastructure navigateur/HTTP ; elle ne constitue pas le verdict fonctionnel. Preuves clients et complément du rapport enregistrés.

### #219 — correction de la CI réservation et inventaire des 19 écarts (31/10, EN COURS)

Le lecteur de la fixture restaurant substituait l’entrée historique `commerce_vendre_produit` même lorsqu’une migration explicite était demandée : contre-épreuve exécutée contre le mauvais moteur, retour sans `raison`. Substitution limitée au baseline ; versions historiques des deux fonctions de bonus épinglées au même commit public que le décor. **49/49 réservation** sur PostgreSQL 17.6 et sur le moteur 16.2 de CI, **94/94 restaurant**, **40/40 outillage** dont contre-épreuve de non-substitution. Aucun affaiblissement d’assertion.

`AUTHORITY-19-219-20261031.json` détaille les 19 : **12 résolus après installation locale des 89**, sept contrats d’organisations restent hors lot. Ne pas les masquer ni importer les 65 préparations. L’inventaire plus strict du catalogue après lot conserve 17 formes à examiner (dont arguments spread et anciens appels), distinctes de ces 19.

Le relais canonique contient cinq nombres/empreintes et dix tables de seeds, mais **aucun contenu des 438 triples `ordres_couts`**. Impossible d’attribuer les onze de différence nette à des clés sans ces lignes. `comparer-couts-captures.py` compare les ensembles réels, refuse doublons/types invalides, et fournit la requête strictement en lecture seule ; ne touche à aucun vérificateur ni référence. Contre-épreuve : +11 peut signifier +12/-1, pas forcément onze absences.

Main relu via le credential helper GitHub CLI existant : toujours `59ea6d90`, déjà intégré. API Actions encore Forbidden, pas de conclusion distante revendiquée. Aucun accès Supabase vivant exposé, aucune production modifiée. Continuer contrôles et preuves, puis pousser par le même helper ; pas de fusion.

### #219 — suite du workflow au-delà du premier arrêt (31/10)

La passe intégrale des commandes Python du workflow a trouvé 13 autres bancs bloqués par découpage/archives, séquences explicites et entrées de transformations devenues différentes. Lecteur existant réutilisé, chemins de migrations résolus par le classement, listes de versions explicites à la place des anciens globs vides. Les décors des transformations historiques épinglent leurs entrées publiques d’origine (SHA256), sans modifier une garde ni le SQL de production. Les assertions et contre-épreuves d’inventaire sont conservées ; aucun verrou d’inventaire modifié.

Les équipements collectifs restent incompatibles avec le payeur entier du catalogue capturé : refus des 5,50 FR vérifié sans débit dans le banc, avant chargement des entrées historiques cohérentes. Cette préparation d’organisations n’entre PAS dans les 89 migrations #219 ; son succès historique ne vaut pas feu vert de production. Continuer la passe complète du workflow et publier les résultats, sans prétendre 6/6 distants tant que l’API refuse l’accès.

### #219 — CI distante vérifiée par la page publique (31/10)

Alternative autorisée à l’API refusée : `https://github.com/FredJ74/res-publica/pull/219/checks`. **Six workflows réussis sur `6ef82a65dc3f8ecb5a18a874194109626ea85188`**, dont Cohérence client (run 41214656628). Les 43 commandes Python passent localement sur le moteur de CI ; 150 bancs clients et 105 tests Chromium repassés. Cette preuve ne vaut pas une livraison en production. PR toujours en brouillon.

Détecteur RPC ajusté pour les commentaires/accolades citées à l’intérieur des objets ; quatre tests et contre-exemples, notamment conservation des gestionnaires embarqués en HTML. Les 496 fonctions recensées sont conservées ; le paramètre `p_fn` des impôts est désormais correctement lu. Aucun appel propagé par spread n’est faussement déclaré complètement résolu. Les 19 écarts capture persistent (12 résolus après lot, sept organisations hors lot).

Les six mutations sont détectées, chacune sur 379 cas ; comparaison historique exacte : cinq listes identiques, une liste différente parce qu’un scénario additionnel dépend de l’issue du vrai combat. Le cas obligatoire `squatteurs_issue_reelle_obligatoire_tues` échoue toujours sous mutation. Le contrôle strict de listes a échoué et cette réserve est conservée, sans retirer ni modifier un scénario.

Rapport de reprise/livraison courant : `outils/audits/FINALISATION-LIVRAISON-219-20261031.md`. CI distante six succès confirmés sur 6ef82a65, reconstruction non recommencée, paquet inchangé, ordre de livraison suspendu pour les blocages détaillés. Ne pas redemander les quatre exports ; les contenus de coûts et des trois miroirs restent à lire par le connecteur disponible chez ChatGPT.

### #219 — capture 438 récupérée, premières causes corrigées (31/10, EN COURS)

Reprise de `4a8990a5`, main toujours `59ea6d90`. Deux derniers commentaires de ChatGPT lus sur la page publique. Capture publique des 438 tarifs récupérée du commit `4ec07923`, snapshot `346064:346064:` ; ne pas la redemander. Diff initial exhaustif : **388 communs, 50 seulement en base, 39 seulement générés**, pas onze simples absences.

Générateur raccordé à sept déclarations SQL authored appliquées et à leur projection tentative/réussite ; extraction AST des modules (ordre des propriétés, constantes locales, appel d’achat réel), aucun zéro fabriqué pour coût dynamique. Quatre contre-épreuves passent. **450 triples source, 411 communs avec la capture, 27 anciens couples restants, 39 nouvelles déclarations**. Aucune valeur de gameplay changée dans les écrans, aucun tarif copié depuis la capture comme canon. Seeds régénérés par l’outil existant. Diff individuel et origines dans `RECONCILIATION-COUTS-219-20261031.json`.

Poursuivre le nettoyage contrôlé des tarifs et les sept contrats : trois commandes actives ont leurs cinq migrations existantes sélectionnables ; quatre fonctions d’équipements doivent rester inaccessibles tant que leurs dépendances financières ne sont pas compatibles. Ne pas importer les 65 préparations en bloc, ne pas fusionner ni appliquer en production.
