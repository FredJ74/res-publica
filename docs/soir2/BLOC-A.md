# Mission de fin de soirée du 25/11/2026 — bloc A (points 1.1, 1.3, 2.4)

Branche `claude/soir2-a-20261125`, issue de main 50b6f162. Aucune écriture en production : lectures de catalogue seulement
(colonnes, nombre de lignes, fonctions qui écrivent dans chaque table, clés étrangères, définition de
`publicite_premium_creer_beta` et de la fonction `publicite-premium` déployée). Aucune fonction Supabase redéployée.

## 1.1 — Remise à zéro du 19/12 (toujours jamais exécutée)

- Décisions de Fred inscrites : **tous les personnages disparaissent** (chacun recrée le sien) ; `blocus_ordres_batiments` et
  `climat_evenements` sont vidées (classement complémentaire : plus aucune table « à vérifier »).
- Relevé des tables de production (630) : les **129 tables créées depuis le classement** sont classées (126 vidées, 3 gardées :
  `frontieres_fermees`, `souvenirs_objets`, `sovarka_urbanisme`). Sans cela, le script aurait refusé de tourner le 19/12.
- **Remise à l'état initial des tables mixtes, table par table** : nouveau `outils/lancement/reinitialisations.modele.sql`
  (une entrée « ▸ table : stratégie » par table ; le générateur échoue si une table n'en a pas), inséré dans le script après
  l'effacement. 45 tables (les 40 d'origine + les 5 tables de métiers des PNJ, qui suivent `pnj_membres` par cascade) :
  - aucune action (17) : référentiels qu'aucune fonction n'écrit, `rp_transitions`, `lois_assemblee` (morte),
    `dotations_amorcage_caisses` (journal) ; configurations gardées : `budgets_nationaux`, `ports_commerce` ;
  - vidées (recréées à la demande) : dealers, niveaux de prison, caisse du kolkhoze, énigme du trésor, échéanciers de loyers,
    médicaments, stocks des ports, possessions des PNJ, postes pris par des joueurs ;
  - filtrées : PNJ attachés à un joueur (25, dont la compagnie menée par un joueur), organisations fondées par des joueurs
    (celles dirigées par un PNJ restent, sans membres, demandes ni caisse), commerces des joueurs ;
  - colonnes remises à blanc : locaux de Sovarka, murs (à la commune), terrains (blob réduit à ce que pose le semis),
    sièges de l'Assemblée, caisses des clubs, taux foncier des mairies (0,05) ;
  - semis rejoué : stock du marché de Krasnov (migration 20261122160000), caisses arbitrées de Républia et trois entrepôts
    (seeds `baseline/seeds/92_mixte/`, réécrits en `ON CONFLICT … DO UPDATE`).
- Effacement : une table vidée mais référencée par une table gardée (`journaux.cree_par` → `personnages_donnees`, seule clé
  relevée en production) est vidée par DELETE (la clé met la référence à NULL) ; les autres d'un seul TRUNCATE.
- Le garde-fou « réinitialisations déclarées faites » disparaît (l'étape est automatisée) ; la phrase de confirmation, la date
  et le refus des tables inconnues non vides restent. Procédure à jour : `docs/premium/REMISE-A-ZERO-20261219.md`.
- Banc : `outils/bancs/banc-remise-a-zero-pglite-20261125.cjs` (5 tests) — réinitialisation éprouvée table par table sur des
  doublures aux colonnes de la production, clé `journaux` comprise.

## 1.3 — Renouvellement d'image rendu si la génération échoue

- Migration `20261125800000_premium_renouvellement_rendu.sql` : `premium_renouvellement_rendre_service(p_user, p_type,
  p_objet)`, réservée au serveur : annule le dernier décompte de moins de 15 minutes pour ce visuel (ligne retirée ; unité
  achetée rendue utilisable), idempotente.
- `supabase/edge-functions/commerce-decoration` et `logement-decoration` : après le décompte, chaque échec (texte trop court,
  clé absente, image source invalide, générateur injoignable ou en erreur, image absente ou non WebP, stockage, enregistrement)
  rend le renouvellement et le signale (`renouvellement_rendu`). **Non redéployées : à redéployer avec Fred après la
  migration** (sans elle, l'appel est sans effet, aucune erreur).
- Banc : `outils/bancs/banc-premium-renouvellement-rendu-20261125.cjs` (6 tests).
- Au passage : `banc-premium-socle-pglite-20261125.cjs` exigeait « NON APPLIQUÉE » dans l'en-tête de 20261125700000, devenu
  « APPLIQUÉE » ce soir sur main (il aurait échoué en CI) : il accepte désormais les deux.

## 2.4 — Atelier de presse : une campagne à la fois, durée réglée par le MJ

- Migration `20261125810000_presse_campagne_duree_mj.sql` : formule libre (« campagne » pour les nouvelles), `nb_parutions` =
  durée fixée à la création (`publicite_joueur_duree_jours`, réglage MJ), contrainte `programmation_payee` sans formule (repli
  5 / 10 pour les deux campagnes de la bêta), une seule campagne de presse à la fois par compte (remplacement contrôlé de
  `publicite_premium_creer_beta`, marque `presse_campagne_v1`).
- `supabase/edge-functions/publicite-premium/index.ts` : copie versionnée de la fonction déployée (v10), qui programme la
  campagne sur `nb_parutions` jours (repli 5 / 10). **Non déployée** ; déployable avant ou après la migration.
- `plateau-publicite-premium.js` : plus de choix 5 / 10 parutions ; texte du modèle unique (l'écran envoie encore « cinq »,
  accepté par l'ancienne fonction et ignoré par la nouvelle).
- Bancs : `outils/bancs/banc-presse-campagne-pglite-20261125.cjs` (2 tests) ; `banc-i18n-publicite-premium-20261112.cjs` adapté.

## Lignes de suivi (prêtes pour docs/suivi-decisions.md)

| 25/11/2026 | 1.1 Remise à zéro du 19/12 : tous les personnages disparaissent (chacun recrée le sien), blocus et climat vidés, 129 tables nouvelles classées, remise à l'état initial des 45 tables mixtes écrite table par table dans le script ; toujours jamais exécutée. | en cours |  |  | Mission de fin de soirée 1.1 |
| 25/11/2026 | 1.3 Renouvellement d'image décompté puis génération en échec : rendu au joueur (migration 20261125800000 écrite, non appliquée ; ateliers de décoration à redéployer). | en cours |  |  | Mission de fin de soirée 1.3 |
| 25/11/2026 | 2.4 Publicités de joueurs : une campagne à la fois par support, durée réglée par le MJ ; formules 5 / 10 parutions de l'atelier de presse retirées (migration 20261125810000 écrite, non appliquée ; fonction publicite-premium à redéployer). | en cours |  |  | Mission de fin de soirée 2.4 |

## Migrations à valider (dans l'ordre) et contrôles

1. `20261125800000_premium_renouvellement_rendu.sql`
   - `SELECT has_function_privilege('service_role', 'public.premium_renouvellement_rendre_service(uuid,text,text)', 'EXECUTE');` — vrai
   - `SELECT has_function_privilege('authenticated', 'public.premium_renouvellement_rendre_service(uuid,text,text)', 'EXECUTE');` — faux
   - `SELECT position('premium_rendu_v1' in pg_get_functiondef('public.premium_renouvellement_rendre_service(uuid,text,text)'::regprocedure)) > 0;` — vrai
   - puis redéployer `commerce-decoration` et `logement-decoration`.
2. `20261125810000_presse_campagne_duree_mj.sql`
   - `SELECT position('campagne' in pg_get_constraintdef(oid)) > 0 FROM pg_constraint WHERE conname = 'publicites_premium_presse_formule_check';` — vrai
   - `SELECT position('nb_parutions' in pg_get_constraintdef(oid)) > 0 FROM pg_constraint WHERE conname = 'programmation_payee';` — vrai
   - `SELECT position('presse_campagne_v1' in pg_get_functiondef('public.publicite_premium_creer_beta(text,text,text,boolean)'::regprocedure)) > 0;` — vrai
   - `SELECT count(*) FROM public.publicites_premium_presse WHERE formule NOT IN ('cinq', 'dix', 'campagne');` — 0
   - puis déployer `publicite-premium` depuis `supabase/edge-functions/publicite-premium/index.ts`.

## Pour Codex (français nouveau ou changé)

- `plateau-publicite-premium.js` : clé `premiumAds.campaignModel` « Une campagne à la fois : elle paraît chaque jour à partir
  du lendemain de sa validation, pendant la durée fixée par le MJ. » (absente des catalogues : repli français) ; les clés
  `five` et `ten` de `i18n/premium-ads-resources.js` ne sont plus affichées (à retirer).
- Ateliers de décoration : message « Generateur d'images injoignable » (erreur renvoyée par la fonction, sans traduction
  aujourd'hui comme les autres messages de ces fonctions).
- Migration 20261125810000 : refus « Campagne de presse déjà en cours ».

## Questions de game design

- Commerces tenus par des PNJ (33) : aucun état initial (stock, caisse) n'est décrit ; la remise à zéro les garde tels qu'en
  fin de bêta. Faut-il un état de départ par commerce ?
- Caisses publiques non arbitrées (Sovarka, une partie de Républia) et bâtiments hors entrepôts : gardés tels qu'en fin de
  bêta. Faut-il des montants de départ ?
- `budgets_nationaux` et `ports_commerce` (réglés par les ministres pendant la bêta) : garder, ou revenir à des valeurs de départ ?
- Classement historique : `avocats_barreau`, `compagnies_militaires` et `admin_journal` sont « vidées » au lancement
  (classement de la baseline, non modifié) ; à confirmer, surtout le journal du MJ.
- Durée d'une campagne de presse : la même que la rue et le cinéma (`publicite_joueur_duree_jours`, 7 jours par défaut) ;
  faut-il un réglage propre à la presse ?
