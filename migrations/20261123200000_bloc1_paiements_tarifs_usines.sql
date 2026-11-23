-- Bloc 1 de la mission « Novomirsk, PNJ, interface et suites des rapports » (Fred, 23/11/2026 ;
-- GAME-DESIGN-NOVOMIRSK-PNJ-INTERFACE-20261123.md, points 5, 6, 8, 12, 13). Rejouable (marques).
-- Rien n'est touché au goulag : le taxi du QHS est seulement refusé en Sovarka tant que sovarka_goulag_ouvert() = false.
CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- Point 6 — Tous les paiements en liquide. Deux remplacements par fonction :
--   (a) le débit passe de 'liquide_puis_nationale' à 'liquide' ;
--   (b) le contrôle des fonds AVANT débit ne compte plus la banque (sinon le joueur passerait le contrôle puis le débit
--       échouerait en exception) : la sous-requête sur comptes_bancaires lit une table vide.
-- Exceptions (prélèvements automatiques, le joueur n'est pas là pour sortir l'argent) : taxe_fonciere_prelever et
-- cotisation_renouveler gardent « liquide, puis banque ».
-- ---------------------------------------------------------------------------------------------------------------
DO $paiements$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.boutique_climat_acheter(uuid,text,integer)', 'public.boutique_discretion_acheter(uuid,text)',
    'public.contrebande_poissonniere_interne(text,text,integer)', 'public.furet_acheter(uuid)',
    'public.graisse_acheter(uuid,text,integer)', 'public.pharmacie_bandelettes_acheter(uuid,integer)',
    'public.pnj_debaucher(text,text,text,integer,integer)', 'public.poissonniere_poisson_interne(text,integer)',
    'public.sovarka_parti_commande(uuid,text,text,jsonb)']
  LOOP
    PERFORM pg_temp.rp_remplacer(f::regprocedure, $a$'liquide_puis_nationale'$a$, $b$'liquide' /* paiement_liquide_v1 */$b$, 1, 'paiement_liquide_v1');
    PERFORM pg_temp.rp_remplacer(f::regprocedure, $a$FROM public.comptes_bancaires$a$,
      $b$FROM (SELECT * FROM public.comptes_bancaires WHERE false /* paiement_liquide_controle_v1 : la banque ne compte pas */)$b$,
      1, 'paiement_liquide_controle_v1');
  END LOOP;
  -- Débit seul (pas de contrôle préalable par la banque, ou contrôle sur le liquide traité plus bas).
  FOREACH f IN ARRAY ARRAY[
    'public.football_pari_engager(text,text,integer,text,integer)', 'public.football_pari_playoff_engager(text,text,text,text,integer)',
    'public.marche_krasnov_valider(uuid,jsonb)', 'public.sovarka_bon_etat_souscrire(text,integer)',
    'public.terrain_squatteurs_don(text,integer,text,uuid)']
  LOOP
    PERFORM pg_temp.rp_remplacer(f::regprocedure, $a$'liquide_puis_nationale'$a$, $b$'liquide' /* paiement_liquide_v1 */$b$, 1, 'paiement_liquide_v1');
  END LOOP;
END $paiements$;

-- argent_mouvement_serveur : poche par défaut = liquide (un appelant peut toujours demander explicitement l'autre).
SELECT pg_temp.rp_remplacer('public.argent_mouvement_serveur(text,numeric,text,text)'::regprocedure,
  $a$coalesce(p_poche, 'liquide_puis_nationale')$a$, $b$coalesce(p_poche, 'liquide' /* paiement_liquide_v1 */)$b$, 1, 'paiement_liquide_v1');
-- Paris : la colonne arg additionne liquide et banque ; le contrôle (avant débit, FOR UPDATE) lit le liquide.
SELECT pg_temp.rp_remplacer('public.football_pari_engager(text,text,integer,text,integer)'::regprocedure,
  $a$SELECT coalesce(arg, 0) INTO v_arg
    FROM$a$, $b$SELECT coalesce(liquide, 0) /* paiement_liquide_controle_v1 */ INTO v_arg
    FROM$b$, 1, 'paiement_liquide_controle_v1');
SELECT pg_temp.rp_remplacer('public.football_pari_playoff_engager(text,text,text,text,integer)'::regprocedure,
  $a$SELECT arg INTO v_arg FROM public.personnages_donnees WHERE name=v_moi FOR UPDATE$a$, $b$SELECT liquide /* paiement_liquide_controle_v1 */ INTO v_arg FROM public.personnages_donnees WHERE name=v_moi FOR UPDATE$b$, 1, 'paiement_liquide_controle_v1');
-- Marché de Krasnov : le contrôle lit le liquide (marche_krasnov_argent_interne reste pour l'affichage).
SELECT pg_temp.rp_remplacer('public.marche_krasnov_valider(uuid,jsonb)'::regprocedure,
  $a$v_argent := public.marche_krasnov_argent_interne(a);$a$,
  $b$v_argent := greatest(0, coalesce((SELECT liquide FROM public.personnages_donnees WHERE name = a), 0)); /* paiement_liquide_controle_v1 */$b$,
  1, 'paiement_liquide_controle_v1');
-- Don aux squatteurs : le verrou du compte reste (ordre des verrous), le disponible ne compte plus la banque.
SELECT pg_temp.rp_remplacer('public.terrain_squatteurs_don(text,integer,text,uuid)'::regprocedure,
  $a$dispo := coalesce(p.liquide,0) + coalesce((SELECT solde$a$,
  $b$dispo := coalesce(p.liquide,0) /* paiement_liquide_controle_v1 */ + 0 * coalesce((SELECT solde$b$, 1, 'paiement_liquide_controle_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- Point 12 — Rébellion 1 PA, répression 1 PA (Républia et Sovarka). Tarifs d'ordres_couts et montants déclarés.
-- ---------------------------------------------------------------------------------------------------------------
UPDATE public.ordres_couts SET pa = 1 WHERE fn = 'se_rebeller' AND pa = 2 AND cost = 0;
UPDATE public.ordres_couts SET pa = 1 WHERE fn = 'reprimer_manif' AND pa = 3 AND cost = 0;
UPDATE public.ordres_couts SET pa = 1 WHERE fn = 'sovarka_manif_reprimer' AND pa = 3 AND cost = 0;
SELECT pg_temp.rp_remplacer('public.manifestation_reprimer(text,text)'::regprocedure,
  $a$payer_ordre(v_moi, 'reprimer_manif', 3, 0)$a$, $b$payer_ordre(v_moi, 'reprimer_manif', 1, 0) /* repression_1pa_v1 */$b$, 1, 'repression_1pa_v1');
SELECT pg_temp.rp_remplacer('public.sovarka_ministeres_commande(uuid,text,jsonb)'::regprocedure,
  $a$payer_ordre_interne(a, 'sovarka_manif_reprimer', 3, 0)$a$, $b$payer_ordre_interne(a, 'sovarka_manif_reprimer', 1, 0) /* repression_1pa_v1 */$b$, 1, 'repression_1pa_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- Point 13 — desinstaller_materiel ne passe pas par ordres_couts (2 PA débités par la fonction elle-même) : ligne retirée.
-- ---------------------------------------------------------------------------------------------------------------
DELETE FROM public.ordres_couts WHERE fn = 'desinstaller_materiel';

-- ---------------------------------------------------------------------------------------------------------------
-- Point 8 — Dotation initiale de plantes des usines pharmaceutiques d'État (Républia et Sovarka), une seule fois par
-- usine (marque dotationPlantesInitiale dans l'état de l'usine). Quantité réglable par le MJ : environ un mois de
-- production de nuit à plein (5 médicaments × 10 plantes + antidote 15 = 65 plantes par nuit).
-- ---------------------------------------------------------------------------------------------------------------
INSERT INTO public.sante_parametres (cle, valeur, groupe, libelle) VALUES
  ('usine_plantes_dotation_initiale', 2000, 'usines', 'Usines d''État : dotation initiale de plantes versée une fois (environ un mois de production)')
ON CONFLICT (cle) DO NOTHING;
DO $dotation$
DECLARE p text; c record; v_id text; v_etat jsonb; v_usine jsonb; v_sm jsonb; v_q numeric := public.sante_param('usine_plantes_dotation_initiale', 2000);
BEGIN
  FOREACH p IN ARRAY ARRAY['republic', 'soviet'] LOOP
    SELECT * INTO c FROM public.usine_medicaments_chaine_interne(p);
    IF c.ville IS NULL THEN RAISE EXCEPTION 'chaîne de médicaments inconnue pour %', p; END IF;
    v_id := p || '_' || c.ville || '_' || c.building_id;
    SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF v_etat IS NULL THEN RAISE EXCEPTION 'usine introuvable : %', v_id; END IF;
    v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
    IF v_usine ? 'dotationPlantesInitiale' THEN CONTINUE; END IF;
    v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
    v_sm := v_sm || jsonb_build_object(c.matiere, coalesce((v_sm->>c.matiere)::numeric, 0) + v_q);
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etat || jsonb_build_object('usine', v_usine || jsonb_build_object('stockMatieres', v_sm,
             'dotationPlantesInitiale', jsonb_build_object('quantite', v_q, 'jour', (now() AT TIME ZONE 'Europe/Paris')::date))))::text),
           updated_at = now()
     WHERE id = v_id;
  END LOOP;
END $dotation$;

-- ---------------------------------------------------------------------------------------------------------------
-- Point 5 — Le taxi du QHS mène au goulag : refusé en Sovarka tant que le goulag est verrouillé (le bouton est aussi
-- masqué à l'écran). La configuration du goulag n'est pas touchée : on la lit seulement.
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.transport_effectuer(text,text,text,uuid)'::regprocedure,
  $a$ -- transport_taxis_speciaux_v1$a$,
  $b$ -- taxi_qhs_goulag_verrou_v1 (Fred, 23/11/2026, point 5)
 IF p_mode = 'taxi_qhs' AND p.country = 'soviet' AND NOT coalesce(public.sovarka_goulag_ouvert(), false) THEN RETURN jsonb_build_object('ok',false,'raison','goulag_ferme');END IF;
 -- transport_taxis_speciaux_v1$b$, 1, 'taxi_qhs_goulag_verrou_v1');

-- ---------------------------------------------------------------------------------------------------------------
-- Point 3 — Intitulés de postes accentués (affichage seulement, mêmes valeurs que data.js et le seed régénéré).
-- ---------------------------------------------------------------------------------------------------------------
UPDATE public.postes_nommes_regles SET label = 'Ministre des Affaires Étrangères' WHERE poste_id = 'min_ae' AND label = 'Ministre des Affaires Etrangeres';
UPDATE public.postes_nommes_regles SET label = 'Ministre de la Défense' WHERE poste_id = 'min_def' AND label = 'Ministre de la Defense';
UPDATE public.postes_nommes_regles SET label = 'Ministre de l''Intérieur' WHERE poste_id = 'min_int' AND label = 'Ministre de l''Interieur';
UPDATE public.postes_nommes_regles SET label = 'Procureur de la République' WHERE poste_id = 'procureur' AND label = 'Procureur de la Republique';
