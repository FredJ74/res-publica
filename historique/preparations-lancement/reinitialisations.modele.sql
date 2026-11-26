-- DÉBUT DES RÉINITIALISATIONS
-- 4. Remise à l'état initial des tables mixtes (mission de fin de soirée du 25/11/2026, point 1.1). -----------------------
-- Une entrée par table « à réinitialiser » (marque « ▸ <table> : <stratégie> », contrôlée par le générateur : une table
-- sans entrée fait échouer la génération). Relevé en lecture de la production le 25/11/2026 (colonnes, nombre de lignes,
-- fonctions qui écrivent dans la table) ; états initiaux tirés des seeds baseline et des migrations de semis, jamais
-- inventés. Ce bloc s'exécute APRÈS l'effacement (étape 3) : les tables d'état qui pointaient vers ces lignes sont déjà vides.
-- Stratégies : aucune (référentiel qu'aucune fonction n'écrit), vider (état engendré à la demande : l'absence de ligne EST
-- l'état initial), filtrer (retirer ce qui vient des joueurs), colonnes (remettre à blanc les colonnes vivantes),
-- semis (rejouer le seed baseline ou la migration de semis).

-- ▸ catalogue_correspondance_legacy : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_familles : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_generique_type : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_generiques : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_types : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ catalogue_variantes : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ entrepots_par_ville : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ militaire_armes_bonus : aucune (barème, aucune fonction ne l'écrit)
-- ▸ objets_modeles : aucune (catalogue, aucune fonction ne l'écrit)
-- ▸ ports_productions : aucune (barème de production, aucune fonction ne l'écrit)
-- ▸ recettes_commerce : aucune (recettes, aucune fonction ne l'écrit)
-- ▸ sovarka_productions_villes : aucune (barème de production, aucune fonction ne l'écrit)
-- ▸ structures_medicales : aucune (référentiel, aucune fonction ne l'écrit)
-- ▸ terrain_actions_regles : aucune (règles, aucune fonction ne l'écrit)
-- ▸ rp_transitions : aucune (drapeaux transitoires du moteur : comportement à conserver, arbitrage du chantier 2C)
-- ▸ lois_assemblee : aucune (table morte : 0 ligne, aucune fonction ne la lit ni ne l'écrit)
-- ▸ dotations_amorcage_caisses : aucune (journal d'un amorçage déjà fait, ni lu ni écrit ; les caisses sont remises par
--   leur seed plus bas, ce journal reste pour l'histoire)

-- ▸ drogues_stocks_dealers : vider (ligne recréée au plafond du dealer au premier achat)
-- ▸ niveaux_prison : vider (ligne recréée à 100 au premier dégât)
-- ▸ kolkhoze_caisse : vider (dépôts des joueurs à la caisse du kolkhoze)
-- ▸ enigme_tresor_tsars : vider (progression des joueurs dans l'énigme)
-- ▸ murs_loyers : vider (échéancier recréé au premier prélèvement de loyer)
-- ▸ medicaments_stocks : vider (ligne recréée à 0 à la première production ; les usines remplissent)
-- ▸ ports_stock : vider (stock des ports accumulé pendant la bêta ; la production de la première nuit le remplit)
-- ▸ pnj_possessions : vider (objets acquis en partie ; arbitrage du 05/10 : aucune reprise)
-- ▸ postes_attribues : vider (registre des postes pris par des joueurs : nomination, élection, candidature, tirage)
TRUNCATE public.drogues_stocks_dealers, public.niveaux_prison, public.kolkhoze_caisse, public.enigme_tresor_tsars,
  public.murs_loyers, public.medicaments_stocks, public.ports_stock, public.pnj_possessions, public.postes_attribues;

-- ▸ pnj_membres : filtrer (les PNJ attachés à un joueur — recrutés, militants, soldats d'une compagnie menée par un joueur —
--   disparaissent avec lui ; le personnel des institutions reste, il n'est engendré qu'à la création de l'institution)
DELETE FROM public.pnj_membres WHERE proprietaire_pj IS NOT NULL OR leader_pj IS NOT NULL;
-- ▸ pnj_soldats_metier : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)
-- ▸ pnj_employes_metier : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)
-- ▸ pnj_force_publique_metier : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)
-- ▸ pnj_militants_metier : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)
-- ▸ garde_republicaine_effectifs : filtrer (suit pnj_membres par sa clé ON DELETE CASCADE)

-- ▸ organisations : filtrer (les organisations fondées par des joueurs disparaissent ; celles du monde, dirigées par un PNJ
--   — Syndicat des Dockers, Syndicat national de Sovarka —, restent, vidées de leurs membres, demandes et caisse)
DELETE FROM public.organisations
 WHERE NOT (data IS JSON OBJECT AND coalesce(data::jsonb ->> 'chefEstPnj', 'false') = 'true');
UPDATE public.organisations
   SET data = (data::jsonb || jsonb_build_object('membres', '[]'::jsonb, 'demandesAdhesion', '[]'::jsonb, 'caisse', 0))::text
 WHERE data IS JSON OBJECT;

-- ▸ entreprises : filtrer (les commerces des joueurs disparaissent ; ceux des PNJ restent : leur état initial — stock,
--   caisse — n'est décrit nulle part, voir les questions de la procédure)
DELETE FROM public.entreprises WHERE coalesce(data ->> 'proprietaire', '') NOT LIKE 'PNJ%';

-- ▸ sovarka_locaux : colonnes (plus de demande en cours ; un local tenu par un commerce de joueur redevient libre)
UPDATE public.sovarka_locaux SET demande_id = NULL WHERE demande_id IS NOT NULL;
UPDATE public.sovarka_locaux s SET entreprise_id = NULL
 WHERE s.entreprise_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.entreprises e WHERE e.id = s.entreprise_id);

-- ▸ murs_titres : colonnes (les murs reviennent à la commune, propriétaire semé par la migration du socle ; offres retirées)
UPDATE public.murs_titres SET proprietaire = 'commune', offre = NULL, updated_at = now()
 WHERE proprietaire IS DISTINCT FROM 'commune' OR offre IS NOT NULL;

-- ▸ terrains_etat : colonnes (plus de propriétaire, de copropriétaire, de permis ni de chantier ; le blob garde seulement
--   ce que la migration de semis y pose : ville, surface, valeur, constructibilité, occupant PNJ ; l'occupation est
--   réinitialisée par le moteur au premier passage)
UPDATE public.terrains_etat
   SET proprietaire = NULL, coproprietaire = NULL, niveau_construction = NULL, valeur_totale = NULL, updated_at = now(),
       data = (SELECT coalesce(jsonb_object_agg(k, v), '{}'::jsonb) FROM jsonb_each(data::jsonb) x(k, v)
                WHERE k IN ('city', 'surface', 'valeur_totale', 'constructionAutorisee', 'pnj', 'pnjData'))::text
 WHERE data IS JSON OBJECT;

-- ▸ assemblee_sieges : colonnes (les 9 députés Gamma gardent leur identité permanente ; plus aucun siège endormi)
UPDATE public.assemblee_sieges SET endormi = false, endormi_ts = NULL, endormi_par = NULL, updated_at = now()
 WHERE endormi IS DISTINCT FROM false OR endormi_ts IS NOT NULL OR endormi_par IS NOT NULL;

-- ▸ budgets_clubs : colonnes (caisse à 0 et historique vide ; le barème des salaires est du socle et reste)
UPDATE public.budgets_clubs
   SET data = (data - 'derniereSubventionJour') || jsonb_build_object('caisse', 0, 'historique', '[]'::jsonb), updated_at = now();

-- ▸ budgets_municipaux : colonnes (taux foncier de départ, 0,05 FR/m²/jour : valeur par défaut de taxe_fonciere_prelever)
UPDATE public.budgets_municipaux SET data = (data - 'derniereMaj') || jsonb_build_object('tauxFoncier', 0.05), updated_at = now();

-- ▸ budgets_nationaux : aucune (configuration des empires — réserve du jour, taux, répartition — sans état initial décrit ;
--   la garder telle que réglée en fin de bêta, voir les questions de la procédure)
-- ▸ ports_commerce : aucune (configuration des ports — taux de douane, quotas, prix — réglée par les ministres ; gardée,
--   voir les questions de la procédure)

-- ▸ marche_krasnov_stock : semis (valeurs de la migration 20261122160000_krasnov_marche_unique)
TRUNCATE public.marche_krasnov_stock;
INSERT INTO public.marche_krasnov_stock (cle, qte) VALUES
  ('fruits_legumes', 20), ('oeufs', 10), ('viande', 10), ('sucre', 10), ('cereales', 10), ('poisson', 10), ('textile', 10),
  ('bouteille_eau', 30), ('graisse_ours', 10), ('confiture', 8), ('pain_noir', 10), ('goulash', 6), ('chemise', 4),
  ('tenue_ninja', 2), ('masque_carnaval', 2);

-- ▸ caisses_batiments : semis (les caisses de Républia dont la dotation est arbitrée reprennent leur montant décidé —
--   seed baseline/seeds/92_mixte/caisses_batiments.sql ; les autres caisses de Républia et celles de Sovarka n'ont pas
--   d'état initial décrit : elles sont gardées, voir les questions de la procédure)
/*SEED_CAISSES*/

-- ▸ batiments_etat : semis (les trois entrepôts logistiques de Républia reprennent leur stock décidé — seed
--   baseline/seeds/92_mixte/batiments_etat.sql ; les autres bâtiments, sans état initial décrit, sont gardés)
/*SEED_ENTREPOTS*/
-- FIN DES RÉINITIALISATIONS
