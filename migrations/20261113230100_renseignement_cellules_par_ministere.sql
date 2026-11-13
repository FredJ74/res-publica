-- Équipes de renseignement, partie 2/4 : la chaîne des opérations lit l'équipe du ministère.
-- Décisions de Fred (13/11/2026, GAME-DESIGN-NOVOMIRSK.md) :
--  - chaque ministère engage SA propre équipe (« <pays>-<poste> ») ; une équipe ne mène qu'une
--    opération à la fois (ses quatre agents sont des PNJ uniques) ;
--  - les opérations et rapports appartiennent au ministère, pas au ministre : le successeur en
--    hérite, et un ministère ne voit jamais ceux de l'autre ;
--  - une opération coûte 250 PSK en Sovarka (500 FR ailleurs, inchangé).
-- Patch en place des corps existants (WORKFLOW-SUPABASE.md) : un fragment absent fait échouer.

CREATE OR REPLACE FUNCTION pg_temp.patch(p_code text, p_ancien text, p_nouveau text, p_nom text)
RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  IF position(p_ancien IN p_code) = 0 THEN RAISE EXCEPTION 'fragment introuvable dans % : %', p_nom, left(p_ancien, 80); END IF;
  RETURN replace(p_code, p_ancien, p_nouveau);
END $$;

DO $m$
DECLARE f text;
BEGIN
  -- 1. Création d'une opération.
  f := pg_get_functiondef('public.cellule_renseignement_creer(text)'::regprocedure);
  IF position('v_equipe' IN f) = 0 THEN
    f := pg_temp.patch(f, 'c_cout constant numeric := 500;', 'c_cout numeric := 500; v_equipe text;', 'creer');
    f := pg_temp.patch(f, E'v_refus := public.renseignement_lieu_refus_interne(v_nom, v_pays);\n  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;',
      E'v_refus := public.renseignement_lieu_refus_interne(v_nom, v_pays);\n  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;\n'
      || E'  v_equipe := v_pays || ''-'' || v_poste;\n'
      || E'  IF v_pays = ''soviet'' THEN c_cout := 250; END IF;\n'
      || E'  IF EXISTS (SELECT 1 FROM public.cellules_renseignement WHERE pays_proprietaire = v_pays\n'
      || E'              AND coalesce(ministere, ''min_def'') = v_poste AND statut = ''active'') THEN\n'
      || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''equipe_deja_en_mission''); END IF;', 'creer');
    f := pg_temp.patch(f, 'SELECT count(*) INTO v_nb_id FROM public.renseignement_identites_reelles;',
      'SELECT count(*) INTO v_nb_id FROM public.renseignement_identites_reelles WHERE equipe = v_equipe;', 'creer');
    f := pg_temp.patch(f, 'INTO v_besoin_h, v_besoin_f FROM public.renseignement_identites_reelles;',
      'INTO v_besoin_h, v_besoin_f FROM public.renseignement_identites_reelles WHERE equipe = v_equipe;', 'creer');
    f := pg_temp.patch(f, '(id, pays_proprietaire, pays_cible, ministre, statut, cout_fr, caisse, echeance_le)',
      '(id, pays_proprietaire, pays_cible, ministre, statut, cout_fr, caisse, echeance_le, ministere)', 'creer');
    f := pg_temp.patch(f, 'VALUES (v_cellule, v_pays, p_pays_cible, v_nom, ''active'', c_cout, v_caisse, v_echeance);',
      'VALUES (v_cellule, v_pays, p_pays_cible, v_nom, ''active'', c_cout, v_caisse, v_echeance, v_poste);', 'creer');
    f := pg_temp.patch(f, 'FROM public.renseignement_identites_reelles ORDER BY role',
      'FROM public.renseignement_identites_reelles WHERE equipe = v_equipe ORDER BY role', 'creer');
    f := pg_temp.patch(f, 'AND c2.pays_proprietaire = v_pays',
      'AND c2.pays_proprietaire = v_pays AND coalesce(c2.ministere, ''min_def'') = v_poste', 'creer');
    f := pg_temp.patch(f, '(id, cellule_id, role, vrai_nom, dup, pays_couverture, nom_couverture, statut, leader_courant)',
      '(id, cellule_id, role, vrai_nom, dup, pays_couverture, nom_couverture, statut, leader_courant, equipe)', 'creer');
    f := pg_temp.patch(f, 'p_pays_cible, v_couv, ''actif'', v_nom);', 'p_pays_cible, v_couv, ''actif'', v_nom, v_equipe);', 'creer');
    EXECUTE f;
  END IF;

  -- 2. Liste des opérations et rapports : ceux du ministère seulement.
  f := pg_get_functiondef('public.cellule_renseignement_mes_cellules()'::regprocedure);
  IF position('c.ministere' IN f) = 0 THEN
    EXECUTE pg_temp.patch(f, 'WHERE c.pays_proprietaire = v_pays',
      'WHERE c.pays_proprietaire = v_pays AND coalesce(c.ministere, ''min_def'') = v_poste', 'mes_cellules');
  END IF;
  f := pg_get_functiondef('public.cellule_rapports_mes_cellules(integer)'::regprocedure);
  IF position('c.ministere' IN f) = 0 THEN
    EXECUTE pg_temp.patch(f, 'WHERE c.pays_proprietaire = v_pays',
      'WHERE c.pays_proprietaire = v_pays AND coalesce(c.ministere, ''min_def'') = v_poste', 'rapports');
  END IF;

  -- 3. Terminer : seulement une opération de son ministère.
  f := pg_get_functiondef('public.cellule_renseignement_terminer(text)'::regprocedure);
  IF position('cellule_d_un_autre_ministere' IN f) = 0 THEN
    EXECUTE pg_temp.patch(f, 'IF v_proprio IS DISTINCT FROM v_pays THEN',
      E'IF v_proprio = v_pays AND EXISTS (SELECT 1 FROM public.cellules_renseignement c\n'
      || E'       WHERE c.id = p_cellule_id AND coalesce(c.ministere, ''min_def'') IS DISTINCT FROM v_poste) THEN\n'
      || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''cellule_d_un_autre_ministere'');\n  END IF;\n'
      || '  IF v_proprio IS DISTINCT FROM v_pays THEN', 'terminer');
  END IF;

  -- 4. Les alertes et rapports vont au titulaire du ministère propriétaire.
  f := pg_get_functiondef('public.cellule_alerter_ministre(text,text,text,text)'::regprocedure);
  IF position('v_min' IN f) = 0 THEN
    f := regexp_replace(f, 'DECLARE', 'DECLARE v_min text;');
    f := pg_temp.patch(f, 'SELECT c.pays_proprietaire INTO v_pays',
      'SELECT c.pays_proprietaire, coalesce(c.ministere, ''min_def'') INTO v_pays, v_min', 'alerter');
    f := pg_temp.patch(f, 'd.poste ->> ''id'' = ''min_def''', 'd.poste ->> ''id'' = v_min', 'alerter');
    f := pg_temp.patch(f, 't.poste_id = ''min_def''', 't.poste_id = v_min', 'alerter');
    EXECUTE f;
  END IF;
  f := pg_get_functiondef('public.cellules_rapports_generer()'::regprocedure);
  IF position('votre Bureau du Ministre de la Défense' IN f) > 0 THEN
    EXECUTE replace(f, 'votre Bureau du Ministre de la Défense', 'votre bureau de ministre');
  END IF;

  -- 5. Agents proposés au ministre : son équipe, avec les portraits de son pays.
  f := pg_get_functiondef('public.renseignement_agents_disponibles()'::regprocedure);
  IF position('i.equipe' IN f) = 0 THEN
    f := pg_temp.patch(f, 'FROM public.renseignement_identites_reelles i;',
      'FROM public.renseignement_identites_reelles i WHERE i.equipe = v_pays || ''-'' || v_poste;', 'disponibles');
    f := pg_temp.patch(f, 'public.agent_portrait_chemin(i.role, ''republic'')', 'public.agent_portrait_chemin(i.role, v_pays)', 'disponibles');
    EXECUTE f;
  END IF;
END $m$;

DO $preuve$
DECLARE f text := pg_get_functiondef('public.cellule_renseignement_creer(text)'::regprocedure);
BEGIN
  IF position('equipe_deja_en_mission' IN f) = 0 OR position('c_cout := 250' IN f) = 0
     OR position('WHERE equipe = v_equipe ORDER BY role' IN f) = 0 THEN
    RAISE EXCEPTION 'création non adaptée'; END IF;
  IF position('c.ministere' IN pg_get_functiondef('public.cellule_rapports_mes_cellules(integer)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'rapports non cloisonnés'; END IF;
  IF position('v_min' IN pg_get_functiondef('public.cellule_alerter_ministre(text,text,text,text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'alertes non adaptées'; END IF;
END $preuve$;
