-- Le pays d'un poste est celui du poste, pas celui où se trouve son titulaire (Claude, 05/11/2026,
-- demande de Fred : « on ne continue pas si le serveur ne vérifie pas le pays »).
--
-- DÉFAUT CORRIGÉ. acteur_poste_courant() rendait comme pays du poste personnages_donnees.country, qui est
-- la POSITION du joueur (gardée avec current_city/current_building par navigation_positions_garder).
-- Un ministre de Républia en voyage à Novomirsk était donc traité, par les 27 fonctions d'autorité qui la
-- lisent (taxes, budgets, arrestations, renseignement…), comme un ministre de Sovarka : caisse, cible et
-- périmètre de l'autre empire. Constaté le 05/11 : Arnie, ministre de la Défense de Républia, est à Novomirsk.
--
-- 1. acteur_poste_courant : le pays vient du registre des postes (postes_attribues : titulaire + poste), puis
--    de la compagnie pour les grades militaires (« compagnie-<pays>-… », seuls postes absents du registre),
--    et seulement en dernier recours de la position (comportement d'avant, pour un poste inconnu).
--    Signature inchangée.
-- 2. ordre_generique_executer : un ordre réservé à un poste se passe dans le pays de ce poste
--    (refus nommé « hors_de_son_pays »). Les ordres sans poste restent valables partout.
-- 3. Renseignement militaire (cellule_renseignement_creer, renseignement_agents_disponibles) : il fallait
--    déjà être ministre de la Défense, mais on pouvait lancer une opération de n'importe où. Désormais :
--    dans son propre pays, et dans le bâtiment qui porte l'ordre — le siège du renseignement militaire si
--    l'empire en a un (navigation_lieux_regles, aujourd'hui Sovarka), sinon le Palais du Gouvernement
--    (Républia). Le suivi des opérations en cours n'est pas restreint.

CREATE OR REPLACE FUNCTION public.acteur_poste_courant()
 RETURNS TABLE(nom text, poste_id text, poste_city text, pays text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.name, p.poste->>'id', p.poste->>'city',
         coalesce(
           (SELECT a.country FROM public.postes_attribues a
             WHERE a.titulaire = p.name AND a.poste_id = p.poste->>'id'
               AND (p.poste->>'city' IS NULL OR a.city IS NULL OR a.city = p.poste->>'city')
             ORDER BY a.updated_at DESC NULLS LAST LIMIT 1),
           CASE WHEN p.poste->>'compagnieId' LIKE 'compagnie-%-%'
                THEN nullif(split_part(p.poste->>'compagnieId', '-', 2), '') END,
           p.country)
    FROM public.personnages_donnees p
   WHERE p.user_id = auth.uid()
   LIMIT 1;
$function$;

-- Garde de lieu du renseignement militaire, commune au lancement et à la liste des agents.
CREATE OR REPLACE FUNCTION public.renseignement_lieu_refus_interne(p_nom text, p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_ici_pays text; v_ici_bat text; v_lieu text;
BEGIN
  SELECT country, current_building INTO v_ici_pays, v_ici_bat
    FROM public.personnages_donnees WHERE name = p_nom;
  IF v_ici_pays IS DISTINCT FROM p_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_son_pays', 'pays_poste', p_pays);
  END IF;
  v_lieu := CASE WHEN EXISTS (SELECT 1 FROM public.navigation_lieux_regles
                               WHERE pays = p_pays AND batiment = 'siege-renseignement')
                 THEN 'siege-renseignement' ELSE 'palais-gouvernement' END;
  IF v_ici_bat IS DISTINCT FROM v_lieu THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place', 'lieu', v_lieu);
  END IF;
  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION public.renseignement_lieu_refus_interne(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.renseignement_agents_disponibles()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_pays text; v_res jsonb; v_refus jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays FROM public.acteur_poste_courant() a;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  v_refus := public.renseignement_lieu_refus_interne(v_nom, v_pays);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'role', i.role, 'vrai_nom', i.vrai_nom, 'dup', i.dup,
           'portrait', public.agent_portrait_chemin(i.role, 'republic'))
           ORDER BY i.role), '[]'::jsonb)
    INTO v_res FROM public.renseignement_identites_reelles i;
  RETURN jsonb_build_object('ok', true, 'agents', v_res);
END;
$function$;

CREATE OR REPLACE FUNCTION public.cellule_renseignement_creer(p_pays_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa   constant integer := 3;
  c_cout constant numeric := 500;
  v_nom text; v_poste text; v_pays text;
  v_pa integer; v_caisse text; v_mvt jsonb; v_refus jsonb;
  v_cellule text; v_echeance timestamptz;
  v_nb_id integer; v_libres_h integer; v_libres_f integer;
  v_besoin_h integer; v_besoin_f integer;
  v_agents jsonb := '[]'::jsonb;
  r record; v_couv text; v_prec text; v_idx integer := 0;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  SELECT a.nom, a.poste_id, a.pays INTO v_nom, v_poste, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'min_def' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  v_refus := public.renseignement_lieu_refus_interne(v_nom, v_pays);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_pays_cible IS NULL OR btrim(p_pays_cible) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'couverture_absente'); END IF;

  SELECT count(*) INTO v_nb_id FROM public.renseignement_identites_reelles;
  IF v_nb_id < 4 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'identites_reelles_incompletes',
                              'definies', v_nb_id, 'attendues', 4); END IF;

  SELECT count(*) FILTER (WHERE sexe = 'H'), count(*) FILTER (WHERE sexe = 'F')
    INTO v_besoin_h, v_besoin_f FROM public.renseignement_identites_reelles;

  SELECT count(*) FILTER (WHERE c.sexe = 'H'), count(*) FILTER (WHERE c.sexe = 'F')
    INTO v_libres_h, v_libres_f
    FROM public.renseignement_couvertures c
   WHERE c.pays = p_pays_cible
     AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                      WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                        AND a.statut IN ('actif', 'detenu'));
  IF v_libres_h < v_besoin_h OR v_libres_f < v_besoin_f THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pool_couvertures_insuffisant',
      'libres_h', v_libres_h, 'requis_h', v_besoin_h,
      'libres_f', v_libres_f, 'requis_f', v_besoin_f); END IF;

  SELECT coalesce(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = v_nom FOR UPDATE;
  IF v_pa < c_pa THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', c_pa, 'disponibles', v_pa); END IF;

  v_caisse := v_pays || '_gouvernement-min_def';
  v_mvt := public.caisse_institution_mouvement(v_caisse, -c_cout, false);
  IF coalesce((v_mvt ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
      'caisse', v_caisse, 'requis', c_cout, 'detail', v_mvt ->> 'raison'); END IF;

  UPDATE public.personnages_donnees SET pa = v_pa - c_pa WHERE name = v_nom;

  v_cellule  := 'cel-' || (extract(epoch from clock_timestamp())*1000)::bigint
                       || '-' || substr(md5(random()::text), 1, 6);
  v_echeance := now() + interval '10 days';

  INSERT INTO public.cellules_renseignement
    (id, pays_proprietaire, pays_cible, ministre, statut, cout_fr, caisse, echeance_le)
  VALUES (v_cellule, v_pays, p_pays_cible, v_nom, 'active', c_cout, v_caisse, v_echeance);

  FOR r IN SELECT role, vrai_nom, dup, sexe
             FROM public.renseignement_identites_reelles ORDER BY role
  LOOP
    SELECT a.nom_couverture INTO v_prec
      FROM public.agents_renseignement a
      JOIN public.cellules_renseignement c2 ON c2.id = a.cellule_id
     WHERE a.role = r.role AND a.pays_couverture = p_pays_cible
       AND c2.pays_proprietaire = v_pays
     ORDER BY a.cree_le DESC LIMIT 1;

    SELECT c.nom INTO v_couv
      FROM public.renseignement_couvertures c
     WHERE c.pays = p_pays_cible
       AND c.sexe IS NOT DISTINCT FROM r.sexe
       AND c.nom IS DISTINCT FROM coalesce(v_prec, '')
       AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                        WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                          AND a.statut IN ('actif', 'detenu'))
     ORDER BY random() LIMIT 1;

    IF v_couv IS NULL THEN
      SELECT c.nom INTO v_couv
        FROM public.renseignement_couvertures c
       WHERE c.pays = p_pays_cible
         AND c.sexe IS NOT DISTINCT FROM r.sexe
         AND NOT EXISTS (SELECT 1 FROM public.agents_renseignement a
                          WHERE a.pays_couverture = c.pays AND a.nom_couverture = c.nom
                            AND a.statut IN ('actif', 'detenu'))
       ORDER BY random() LIMIT 1;
    END IF;
    IF v_couv IS NULL THEN RAISE EXCEPTION 'pool_couvertures_epuise'; END IF;

    v_idx := v_idx + 1;
    INSERT INTO public.agents_renseignement
      (id, cellule_id, role, vrai_nom, dup, pays_couverture, nom_couverture, statut, leader_courant)
    VALUES (v_cellule || '-a' || v_idx, v_cellule, r.role, r.vrai_nom, r.dup,
            p_pays_cible, v_couv, 'actif', v_nom);
    v_agents := v_agents || jsonb_build_array(jsonb_build_object(
      'role', r.role, 'vrai_nom', r.vrai_nom, 'couverture', v_couv,
      'sexe', r.sexe, 'dup', r.dup, 'statut', 'actif'));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'cellule', v_cellule, 'pays_couverture', p_pays_cible,
    'pays_cible', p_pays_cible, 'echeance', v_echeance, 'cout', c_cout, 'caisse', v_caisse,
    'pa_restants', v_pa - c_pa, 'agents', v_agents);
END;
$function$;

-- 2. Ordres génériques : le corps de production (lu le 05/11) est conservé, seule la garde de pays s'ajoute.
CREATE OR REPLACE FUNCTION public.ordre_generique_executer(p_fn text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; o record; d record; v_paie jsonb; v_roll integer; v_taux integer; v_res text; v_mult numeric;
  v_hp integer; v_moral integer; v_res_j jsonb; v_rembourse numeric := 0; v_repere boolean := false;
  e_hp numeric; e_moral numeric; e_pop numeric; e_inf numeric; e_dis numeric; v_pays_poste text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO o FROM public.ordres_generiques WHERE fn = p_fn;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'ordre_indisponible'); END IF;
  SELECT current_building, country, poste ->> 'id' AS poste INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT (coalesce(d.current_building, '') = ANY (o.batiments)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF o.poste_requis = '*' AND d.poste IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  IF o.poste_requis IS NOT NULL AND o.poste_requis <> '*' AND d.poste IS DISTINCT FROM o.poste_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis', 'requis', o.poste_requis); END IF;
  -- Un ordre de poste se passe dans le pays du poste (05/11/2026).
  IF o.poste_requis IS NOT NULL THEN
    SELECT a.pays INTO v_pays_poste FROM public.acteur_poste_courant() a;
    IF v_pays_poste IS DISTINCT FROM d.country THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_son_pays', 'pays_poste', v_pays_poste); END IF;
  END IF;

  v_paie := public.payer_ordre(v_moi, p_fn, p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_roll := floor(random() * 100)::integer + 1;
  v_taux := greatest(5, CASE WHEN o.taux_reussite >= 98 THEN 99 ELSE o.taux_reussite END);
  IF v_roll <= 100 - v_taux THEN v_res := 'crit-fail';
  ELSIF v_roll <= 100 - (v_taux * 0.7) THEN v_res := 'fail';
  ELSIF v_roll <= 100 - (v_taux * 0.4) THEN v_res := 'partial';
  ELSIF v_roll >= 95 THEN v_res := 'crit';
  ELSE v_res := 'success'; END IF;
  IF o.toujours_reussi THEN v_res := CASE WHEN v_roll >= 95 THEN 'crit' ELSE 'success' END; END IF;
  v_mult := CASE v_res WHEN 'crit' THEN 1.5 WHEN 'success' THEN 1 WHEN 'partial' THEN 0.5 WHEN 'fail' THEN 0 ELSE -0.5 END;

  e_hp := coalesce((o.effets ->> 'hp')::numeric, 0);
  e_moral := coalesce((o.effets ->> 'moral')::numeric, 0);
  e_pop := coalesce((o.effets ->> 'pop')::numeric, 0);
  e_inf := coalesce((o.effets ->> 'inf')::numeric, 0);
  e_dis := coalesce((o.effets ->> 'dis')::numeric, 0);

  SELECT coalesce(hp, 100), coalesce(moral, 75),
         CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_hp, v_moral, v_res_j FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;

  IF e_hp <> 0 THEN v_hp := least(100, greatest(0, v_hp + round(e_hp * v_mult)::integer)); END IF;
  IF e_moral <> 0 THEN v_moral := least(100, greatest(0, v_moral + round(e_moral * v_mult)::integer)); END IF;
  IF e_inf <> 0 THEN v_res_j := jsonb_set(v_res_j, '{inf}', to_jsonb(least(100, greatest(0,
      coalesce((v_res_j ->> 'inf')::numeric, 0) + round(e_inf * v_mult))))); END IF;
  IF e_pop <> 0 THEN v_res_j := jsonb_set(v_res_j, '{pop}', to_jsonb(least(100, greatest(0,
      coalesce((v_res_j ->> 'pop')::numeric, 50) + round(e_pop * CASE WHEN v_res = 'crit-fail' THEN -1 ELSE v_mult END))))); END IF;
  IF e_dis <> 0 THEN v_res_j := jsonb_set(v_res_j, '{dis}', to_jsonb(least(100, greatest(0,
      coalesce((v_res_j ->> 'dis')::numeric, 85) + round(e_dis * CASE WHEN e_dis < 0 THEN 1 ELSE v_mult END))))); END IF;

  IF v_res = 'fail' AND coalesce(p_cost, 0) > 0 THEN v_rembourse := round(p_cost * 0.3); END IF;

  UPDATE public.personnages_donnees
     SET hp = v_hp, moral = v_moral, resources = v_res_j,
         liquide = coalesce(liquide, 0) + v_rembourse, arg = coalesce(arg, 0) + v_rembourse
   WHERE name = v_moi;

  -- DETECTION PAR LE SERVEUR (27/10/2026) : l'ecran la tirait apres coup, un tricheur s'en dispensait.
  IF v_res IN ('partial', 'success', 'crit') AND EXISTS (SELECT 1 FROM public.actes_illegaux WHERE fn = p_fn) THEN
    v_repere := public.crime_detecter_interne(v_moi, p_fn, true);
    SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END INTO v_res_j
      FROM public.personnages_donnees WHERE name = v_moi;
  END IF;
  RETURN jsonb_build_object('ok', true, 'resultat', v_res, 'repere', v_repere,
    'recherche', (SELECT recherche FROM public.personnages_donnees WHERE name = v_moi), 'jet', v_roll, 'hp', v_hp, 'moral', v_moral,
    'pop', v_res_j -> 'pop', 'inf', v_res_j -> 'inf', 'dis', v_res_j -> 'dis', 'rembourse', v_rembourse,
    'pa', (v_paie -> 'pa'),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'solde_national', v_paie -> 'solde_national');
END; $function$;
