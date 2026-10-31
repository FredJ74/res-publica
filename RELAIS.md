
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

### Migrations fusionnées, en attente d'application (ChatGPT)

Vérifier toujours une migration par son **NOM** dans `supabase_migrations.schema_migrations`, jamais par son numéro.

- `20261031130000_reliquats_immobilier_accord_tacite_succession` (PR #284, fusionnée) : accord tacite de nuit (aujourd'hui toujours en échec : le permis de Jean Jaaj, terrain 5, en dépend dans environ 6 jours) et colonnes `proprietaire` / `coproprietaire` à la succession. Indépendante de l'écran. Banc : `outils/bancs/banc-reliquats-immobilier.sql`.
- `20261031140000_helvetia_caisse_argent_detenu` (PR #285, fusionnée, #267) : la caisse d'Helvetia représente l'argent détenu (prêt sans débit de caisse, sommes prises sur le compte Helvetia sans recrédit, dépôt d'ouverture crédité). Indépendante de l'écran. Banc : `outils/bancs/banc-caisse-helvetia.sql`.
- `20261029181000_squatteurs_issue_combat` : **attend le combat de groupe de Codex (#219)** ; ne pas appliquer avant.

### Décisions attendues de Fred

- **Refinancement BNR d'Helvetia** : 223 320 FR en cours pour la République, dont environ 150 000 FR dus au défaut #267. Le ramener ou non est une décision d'économie.
- **Fonds et murs des commerces (#66)** : règles décidées le 21/10 (murs à 150 FR/m², La Republica 1 200 m², fonds et murs indépendants, achat conjoint atomique, murs des commerces PNJ à la commune), **rien n'est en production**. La PR #71 qui les implémentait est périmée (laissée ouverte, commentaire du 31/10) : à reconstruire depuis main si Fred en fait une priorité.
- **Ambassades** : griser « Bientôt disponible » les ordres non raccordables tant que le voyage entre empires n'existe pas (immunité, arrestation de l'expulsé, transfert de détenus, naturalisation). Référence : `GAME-DESIGN-AMBASSADES.md`.

### Points ouverts transmis (non bloquants)

- **Helvetia, même famille que #267** : `resoudre_placement_helvetia` crédite la caisse des frais d'un placement et `finaliser_achat_bien_helvetia` du prix entier, même quand l'argent venait déjà du compte Helvetia. À examiner.
- **Codex** : `minuit_decouverte_crimes` (police) retire des amendes de `arg` sans les verser nulle part ; il peut appeler `amende_imposer_interne`. Le hooliganisme (organisations) écrit encore sa trace de crime à l'écran (à passer par `crime_tracer_interne`). Écritures de l'écran encore ouvertes : `budgets_clubs`, `organisations.caisse` (bilan `outils/bancs/ECRITURES-ECRAN-20261029.md`).
- **Écriture encore ouverte côté Claude** : `quetes_actives`.
- **Budget national** : répéter en production une écriture légitime par un titulaire de poste (garde `20261030110000` appliquée ; la répétition avait été interrompue).
- **Baseline (ChatGPT, #262)** : `payer_ordre`, `inventaire_place_restante` et `personnages_convocations_garder` diffèrent en production des migrations du dépôt (copie dans `jetable-ecarts-production-20261030.sql`) ; `acquisitions_transactions_internes` n'est créée par aucune migration rejouable.
- **PNJ sans profil de dialogue** : Yvon Paletier et Norbert Charton (directeurs d'entrepôt hors Luthécia).
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
