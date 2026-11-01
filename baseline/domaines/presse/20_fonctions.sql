-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine presse -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- calomnie_appliquer_effet(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.calomnie_appliquer_effet(p_cible text, p_pop integer, p_inf integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb;
BEGIN
  UPDATE public.personnages_donnees
     SET resources = jsonb_set(
           jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
                     '{pop}', to_jsonb(GREATEST(0, LEAST(100,
                       COALESCE(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END, 50) + p_pop)))),
           '{inf}', to_jsonb(GREATEST(0, LEAST(100,
             COALESCE(CASE WHEN jsonb_typeof(resources -> 'inf') = 'number' THEN (resources ->> 'inf')::numeric END, 0) + p_inf))))
   WHERE name = p_cible
   RETURNING resources INTO v_res;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'pop', v_res -> 'pop', 'inf', v_res -> 'inf');
END;
$function$;

-- calomnie_distribuer(text,text,text,text,integer) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.calomnie_distribuer(p_requete text, p_joueur text, p_cible text, p_pnj_nom text, p_vol_pnj integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT jsonb_build_object('ok', false, 'raison', 'contrat_versionne_requis'); $function$;

-- calomnie_distribuer_consommer(text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.calomnie_distribuer_consommer(p_requete text, p_cible text, p_pnj_nom text, p_vol_pnj integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_req uuid; v_params jsonb; v jsonb; r jsonb; v_pos integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' OR length(p_requete) > 120 THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  v_req := md5('calomnie|' || p_requete)::uuid;
  v_params := jsonb_build_object('requete', p_requete, 'cible', p_cible, 'pnj', p_pnj_nom);
  PERFORM 1 FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  v := public.inventaire_action_rejouer_interne(v_moi, v_req, 'calomnie', v_params); IF v IS NOT NULL THEN RETURN v; END IF;
  r := public.calomnie_distribuer_interne(p_requete, v_moi, p_cible, p_pnj_nom, p_vol_pnj, now());
  IF coalesce((r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN r; END IF;
  IF r ->> 'poursuite' = 'flagrant_delit' THEN
    UPDATE public.personnages_donnees
       SET inventory = coalesce((SELECT jsonb_agg(e ORDER BY o) FROM jsonb_array_elements(inventory) WITH ORDINALITY x(e, o)
                                  WHERE e ->> 'type' IS DISTINCT FROM 'tract_calomnieux'), '[]'::jsonb),
           pa = greatest(0, coalesce(pa, 0) - 1)
     WHERE name = v_moi;
  ELSE
    SELECT (o - 1)::integer INTO v_pos FROM public.personnages_donnees d, jsonb_array_elements(d.inventory) WITH ORDINALITY x(e, o)
     WHERE d.name = v_moi AND e ->> 'type' = 'tract_calomnieux' AND e ->> 'cible' = p_cible
       AND jsonb_typeof(e -> 'quantite') = 'number' AND (e ->> 'quantite')::numeric >= 1 ORDER BY o LIMIT 1;
    UPDATE public.personnages_donnees
       SET inventory = CASE WHEN v_pos IS NULL THEN inventory
                            WHEN (inventory -> v_pos ->> 'quantite')::numeric <= 1 THEN inventory - v_pos
                            ELSE jsonb_set(inventory, ARRAY[v_pos::text, 'quantite'], to_jsonb((inventory -> v_pos ->> 'quantite')::numeric - 1)) END,
           pa = greatest(0, coalesce(pa, 0) - 1)
     WHERE name = v_moi;
  END IF;
  v := r || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'pa_restants', pa)
               FROM public.personnages_donnees WHERE name = v_moi);
  INSERT INTO public.inventaire_actions_recus VALUES (v_moi, v_req, 'calomnie', v_params, v, now());
  RETURN v;
END; $function$;

-- calomnie_distribuer_interne(text,text,text,text,integer,timestamp with time zone) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.calomnie_distribuer_interne(p_requete text, p_joueur text, p_cible text, p_pnj_nom text, p_vol_pnj integer, p_instant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej    jsonb;
  v_p      record;
  v_v      record;
  v_inv    jsonb;
  v_nom    text;
  v_cle    text;
  v_jour   date;
  v_pays   text;
  v_taux   integer;
  v_jet    integer;
  v_jet2   integer;
  v_effet  jsonb;
  v_mandat jsonb;
  v_res    text;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_calomnieux');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_cible), '') = '' OR p_cible = p_joueur THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_invalide'));
  END IF;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT country, domicile INTO v_v FROM public.personnages WHERE name = p_cible;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_introuvable'));
  END IF;
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_v.domicile ->> 'country', '')), ''), v_v.country);
  IF COALESCE(btrim(v_pays), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'juridiction_indeterminee'));
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_p.inventory) = 'array' THEN v_p.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_inv) i
     WHERE i ->> 'type' = 'tract_calomnieux' AND i ->> 'cible' = p_cible
       AND jsonb_typeof(i -> 'quantite') = 'number' AND (i ->> 'quantite')::numeric >= 1
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'tract_absent'));
  END IF;

  IF COALESCE(v_p.pa, 0) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
  IF v_nom = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
  END IF;
  v_cle := COALESCE(v_p.country, '') || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;
  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;

  PERFORM pg_advisory_xact_lock(hashtext('calomnie|' || v_cle || '|' || p_cible || '|' || v_jour::text));
  IF EXISTS (SELECT 1 FROM public.calomnies_actes
              WHERE pnj_cle = v_cle AND cible = p_cible AND jour_paris = v_jour AND resultat = 'reussite') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_convaincu'));
  END IF;

  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(p_vol_pnj, 10))));
  v_jet := floor(random() * 100)::integer + 1;

  IF v_jet <= v_taux THEN
    v_res := 'reussite';
  ELSE
    v_jet2 := floor(random() * 100)::integer + 1;
    v_res := CASE WHEN v_jet2 <= 10 THEN 'echec_critique' ELSE 'echec' END;
  END IF;

  INSERT INTO public.calomnies_actes (auteur, cible, pnj_cle, pnj_nom, jour_paris, resultat,
                                      pays_faits, ville_faits, pays_competent, jet, taux)
  VALUES (p_joueur, p_cible, v_cle, p_pnj_nom, v_jour, v_res,
          v_p.country, v_p.current_city, v_pays, v_jet, v_taux);

  IF v_res = 'reussite' THEN
    v_effet := public.calomnie_appliquer_effet(p_cible, -5, -2);
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', true, 'critique', false, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'pop', v_effet -> 'pop', 'inf', v_effet -> 'inf',
      'juridiction', v_pays));
  END IF;

  IF v_res = 'echec' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'critique', false, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays));
  END IF;

  IF v_pays IS NOT DISTINCT FROM v_p.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'critique', true, 'consomme', 1, 'pa', 1,
      'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays, 'poursuite', 'flagrant_delit'));
  END IF;
  v_mandat := public.calomnie_inscrire_mandat(p_joueur, p_cible, v_pays, v_p.current_city, p_instant);
  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', false, 'critique', true, 'consomme', 1, 'pa', 1,
    'jet', v_jet, 'taux', v_taux, 'juridiction', v_pays, 'poursuite', 'mandat',
    'mandat', COALESCE(v_mandat -> 'mandat', 'null'::jsonb)));
END;
$function$;

-- calomnie_inscrire_mandat(text,text,text,text,timestamp with time zone) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.calomnie_inscrire_mandat(p_auteur text, p_cible text, p_pays text, p_ville_faits text, p_instant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_entree jsonb;
BEGIN
  v_entree := jsonb_build_object(
    'id', 'rech-calomnie-' || md5(p_auteur || '|' || p_cible || '|' || p_pays || '|' || extract(epoch FROM p_instant)::text),
    'type', 'condamnation',
    'origine', 'serveur',
    'country', p_pays,
    'motifs', jsonb_build_array(jsonb_build_object(
      'type', 'Distribution de tracts calomnieux',
      'jours', 1,
      'source', 'calomnie_juridiction_victime',
      'cible', p_cible,
      'city', p_ville_faits,
      'date_evenement', to_char(p_instant AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
    'issue_judiciaire', 'Mandat d''arret pour calomnie envers un resident (faits commis a l''etranger)',
    'autorite', 'Parquet',
    'jour_condamnation', null);
  PERFORM set_config('rp.recherche_interne', 'on', true);
  UPDATE public.personnages
     SET recherche = CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END || v_entree
   WHERE name = p_auteur;
  PERFORM set_config('rp.recherche_interne', '', true);   -- la portee s'arrete ici
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auteur_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'mandat', v_entree);
END;
$function$;

-- corruption_presse_affaires(text,timestamp with time zone) -> TABLE(affaire_ref text, affaire_type text, affaire_pj text, resume text, cree_le timestamp with time zone) | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.corruption_presse_affaires(p_pays text, p_instant timestamp with time zone DEFAULT now())
 RETURNS TABLE(affaire_ref text, affaire_type text, affaire_pj text, resume text, cree_le timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH borne AS (
    SELECT COALESCE(max(generated_at), p_instant - interval '1 day') AS depuis
      FROM public.journal_editions WHERE country = p_pays AND statut = 'publiee'
  ), jug AS (
    SELECT 'jugements:' || j.id AS affaire_ref, 'jugements'::text AS affaire_type,
           j.accuse AS affaire_pj,
           j.accuse || ' — condamnation pour ' || COALESCE(j.motif, 'motif non precise')
             || COALESCE(' : ' || j.peine, '') AS resume,
           j.created_at AS cree_le
      FROM public.jugements j, borne b
     WHERE j.country = p_pays AND j.created_at >= b.depuis
       AND (j.created_at AT TIME ZONE 'Europe/Paris')::date = (p_instant AT TIME ZONE 'Europe/Paris')::date
  ), det AS (
    SELECT 'detentions:' || d.id AS affaire_ref, 'detentions'::text AS affaire_type,
           d.nom AS affaire_pj,
           d.nom || ' — placement en detention (' || COALESCE(d.raison, 'motif non precise') || ')' AS resume,
           d.created_at AS cree_le
      FROM public.detentions d, borne b
     WHERE d.country = p_pays AND d.created_at >= b.depuis
       AND (d.created_at AT TIME ZONE 'Europe/Paris')::date = (p_instant AT TIME ZONE 'Europe/Paris')::date
  )
  SELECT * FROM jug UNION ALL SELECT * FROM det ORDER BY cree_le DESC;
$function$;

-- corruption_presse_etat(text) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.corruption_presse_etat(p_affaire_ref text)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN bool_or(option = 'etouffer') THEN 'etouffee'
              WHEN bool_or(option = 'favorable') THEN 'favorable' END
    FROM public.corruptions_presse WHERE affaire_ref = p_affaire_ref AND reussite;
$function$;

-- corruption_presse_tenter(text,text,text,text,integer,timestamp with time zone) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.corruption_presse_tenter(p_requete text, p_joueur text, p_affaire_ref text, p_option text, p_malus_isn integer DEFAULT 0, p_instant timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej  jsonb;
  v_p    record;
  v_a    record;
  v_jour date;
  v_taux integer;
  v_jet  integer;
  v_ok   boolean;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'corruption_presse');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_option NOT IN ('etouffer', 'favorable') OR COALESCE(btrim(p_affaire_ref), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;

  SELECT pa, liquide, banque, stats, resources, country, current_city INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  -- L'affaire doit etre eligible MAINTENANT : du jour, et pas encore publiee.
  SELECT * INTO v_a FROM public.corruption_presse_affaires(v_p.country, p_instant) a
   WHERE a.affaire_ref = p_affaire_ref;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'affaire_non_eligible'));
  END IF;

  -- Ressources verifiees AVANT le jet : une reussite ne doit jamais mener a un etat impossible.
  IF COALESCE(v_p.pa, 0) < 2 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;
  IF COALESCE(v_p.liquide, 0) + COALESCE(v_p.banque, 0) < 500 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'));
  END IF;

  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;

  -- Formule propre a cet ordre : 30 + CHA + floor(INF/4) - malus ISN, borne [5, 85].
  v_taux := LEAST(85, GREATEST(5,
    30 + floor(public.assemblee_stat_base(v_p.stats, 'CHA'))::integer
       + floor(GREATEST(0, COALESCE(CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number'
               THEN (v_p.resources ->> 'inf')::numeric END, 0)) / 4)::integer
       - LEAST(25, GREATEST(0, COALESCE(p_malus_isn, 0)))));
  v_jet := floor(random() * 100)::integer + 1;
  v_ok := v_jet <= v_taux;

  -- Une seule tentative par affaire et par corrupteur : c'est l'insertion qui fait foi, donc aussi
  -- contre le double-clic et la concurrence. La TRACE existe que le journaliste accepte ou refuse.
  INSERT INTO public.corruptions_presse (affaire_ref, affaire_type, affaire_pj, corrupteur, option,
                                         reussite, jet, taux, pays, jour_paris)
  VALUES (p_affaire_ref, v_a.affaire_type, v_a.affaire_pj, p_joueur, p_option,
          v_ok, v_jet, v_taux, v_p.country, v_jour)
  ON CONFLICT (affaire_ref, corrupteur) DO NOTHING;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_tente'));
  END IF;

  -- Trace fouillable par « Mener une enquete », en reussite comme en refus. Aucune rumeur n'est
  -- creee ici : le jeu enregistre le fait, son exploitation viendra des systemes d'enquete.
  BEGIN
    INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
    VALUES ('corrpresse-' || md5(p_affaire_ref || '|' || p_joueur), p_joueur, v_a.affaire_pj,
            CASE WHEN v_ok THEN 'corruption_presse' ELSE 'corruption_presse_refusee' END,
            v_p.country, v_p.current_city,
            0, 0, false);
  EXCEPTION WHEN OTHERS THEN
    NULL;   -- la trace detaillee reste dans corruptions_presse : un echec ici n'annule pas l'acte
  END;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', v_ok, 'jet', v_jet, 'taux', v_taux,
    'option', p_option, 'affaire_ref', p_affaire_ref, 'affaire_pj', v_a.affaire_pj,
    'resume', v_a.resume,
    'pa', CASE WHEN v_ok THEN 2 ELSE 0 END, 'cout', CASE WHEN v_ok THEN 500 ELSE 0 END));
END;
$function$;

-- dementi_executer(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dementi_executer(p_rumeur_id text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_poste text; v_pays text; v_rum jsonb; v_cible text; v_poste_cible text;
  v_perdu integer; v_paie jsonb; v_roll integer; v_reussi boolean; v_delta integer; v_res jsonb; v_pop numeric;
  c_gouv text[] := ARRAY['president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae'];
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT poste ->> 'id', country INTO v_poste, v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_poste IS NULL OR NOT (v_poste = ANY (c_gouv)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_gouvernement'); END IF;
  SELECT data INTO v_rum FROM public.rumeurs_actives WHERE id = p_rumeur_id AND resolu = false FOR UPDATE;
  IF v_rum IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'rumeur_introuvable'); END IF;
  v_cible := v_rum ->> 'cible';
  SELECT poste ->> 'id' INTO v_poste_cible FROM public.personnages_donnees WHERE name = v_cible AND country = v_pays;
  IF NOT FOUND OR (v_cible IS DISTINCT FROM v_moi AND NOT (coalesce(v_poste_cible, '') = ANY (c_gouv))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_hors_gouvernement'); END IF;
  v_paie := public.payer_ordre(v_moi, 'dementi', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_perdu := least(100, greatest(1, coalesce(CASE WHEN jsonb_typeof(v_rum -> 'popPerdu') = 'number'
                                                  THEN (v_rum ->> 'popPerdu')::numeric END, 15)::integer));
  v_roll := floor(random() * 100)::integer + 1;
  v_reussi := v_roll <= 80;
  v_delta := CASE WHEN v_reussi THEN v_perdu ELSE -least(100, v_perdu * 2) END;
  SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END
    INTO v_res FROM public.personnages_donnees WHERE name = v_cible FOR UPDATE;
  v_pop := least(100, greatest(0, coalesce(CASE WHEN jsonb_typeof(v_res -> 'pop') = 'number'
                                                 THEN (v_res ->> 'pop')::numeric END, 50) + v_delta));
  UPDATE public.personnages_donnees SET resources = jsonb_set(v_res, '{pop}', to_jsonb(v_pop)) WHERE name = v_cible;
  IF v_reussi THEN
    UPDATE public.rumeurs_actives SET resolu = true WHERE id = p_rumeur_id;
    PERFORM public.annonce_publique_interne(v_pays, '📢 La présidence dément officiellement les rumeurs concernant ' || v_cible || '.');
  ELSE
    PERFORM public.annonce_publique_interne(v_pays, '📢 Le démenti officiel de la présidence échoue, aggravant les soupçons sur ' || v_cible || '.');
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'jet', v_roll, 'cible', v_cible, 'pop_cible', v_pop,
    'pa', v_paie -> 'pa', 'liquide', v_paie -> 'liquide', 'arg', v_paie -> 'arg', 'solde_national', v_paie -> 'solde_national');
END; $function$;

-- fuite_publier(bigint,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fuite_publier(p_fuite_id bigint, p_contenu text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_f record; v_cid text; v_moi text;
BEGIN
  SELECT * INTO v_f FROM public.fuites_journalistiques WHERE id = p_fuite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fuite_introuvable');
  END IF;

  IF NOT public.est_appel_serveur() THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    IF v_f.auteur IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
    END IF;
  END IF;

  IF v_f.chronique_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'chronique_id', v_f.chronique_id);
  END IF;

  v_cid := 'chronique-fuite-' || p_fuite_id::text;
  BEGIN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES (v_cid, v_f.pays, v_f.ville, 'fuite_journalistique',
            jsonb_build_array(v_f.cible),
            COALESCE(NULLIF(btrim(p_contenu), ''), 'Révélations concernant ' || v_f.cible || '.'),
            jsonb_build_object('cible', v_f.cible, 'source', v_f.source, 'faits', v_f.faits,
                               'auteur_public', 'Cellule enquête de la rédaction'),
            'fuite-' || p_fuite_id::text);
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  UPDATE public.fuites_journalistiques
     SET contenu = COALESCE(NULLIF(btrim(p_contenu), ''), contenu), chronique_id = v_cid
   WHERE id = p_fuite_id;

  RETURN jsonb_build_object('ok', true, 'chronique_id', v_cid);
END;
$function$;

-- fuite_reserver(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fuite_reserver(p_requete text, p_joueur text, p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej   jsonb;
  v_p     record;
  v_c     record;
  v_t     record;
  v_id    bigint;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'fuite');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_cible), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_invalide'));
  END IF;

  SELECT pa, country, current_city INTO v_p FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;
  SELECT country INTO v_c FROM public.personnages WHERE name = p_cible;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_introuvable'));
  END IF;
  IF COALESCE(v_p.pa, 0) < 2 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('fuite|' || p_cible));

  SELECT * INTO v_t FROM public.fuite_traces_eligibles(p_cible) ORDER BY random() LIMIT 1;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', true, 'trouve', false));
  END IF;

  INSERT INTO public.fuites_journalistiques (trace_cle, source, cible, auteur, faits, pays, ville)
  VALUES (v_t.trace_cle, v_t.source, p_cible, p_joueur, v_t.faits, v_c.country, v_p.current_city)
  ON CONFLICT (trace_cle) DO NOTHING
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', true, 'trouve', false, 'raison', 'trace_deja_prise'));
  END IF;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'trouve', true, 'fuite_id', v_id, 'source', v_t.source, 'faits', v_t.faits, 'cible', p_cible));
END;
$function$;

-- fuite_traces_eligibles(text) -> TABLE(trace_cle text, source text, faits jsonb) | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fuite_traces_eligibles(p_cible text)
 RETURNS TABLE(trace_cle text, source text, faits jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH hist AS (
    SELECT
      'historique_crimes:' || md5(p_cible || '|' || COALESCE(t.value ->> 'id', '')
        || '|' || COALESCE(t.value ->> 'acte', '') || '|' || COALESCE(t.value ->> 'cible', '')
        || '|' || COALESCE(t.value ->> 'jour', '') || '|' || COALESCE(t.value ->> 'ts', '')) AS trace_cle,
      'historique_crimes'::text AS source,
      jsonb_build_object(
        'acte', t.value ->> 'acte',
        'victime', t.value ->> 'cible',
        'jour', t.value -> 'jour',
        'categorie', t.value ->> 'categorie',
        'quantite', t.value -> 'quantite',
        'loi', t.value ->> 'loiTitre',
        'origine', COALESCE(t.value ->> 'origine', 'personnage'),
        'decouverte_justice', false) AS faits
      FROM public.personnages p
      CROSS JOIN LATERAL jsonb_array_elements(
        CASE WHEN jsonb_typeof(p.historique_crimes) = 'array' THEN p.historique_crimes ELSE '[]'::jsonb END) AS t(value)
     WHERE p.name = p_cible AND COALESCE(t.value ->> 'acte', '') <> ''
  ), publiques AS (
    SELECT
      'actions_tracables:' || a.id AS trace_cle,
      'actions_tracables'::text AS source,
      jsonb_build_object(
        'acte', a.type_action,
        'victime', a.cible,
        'jour', a.jour,
        'ville', a.city,
        'origine', 'action_tracable',
        'decouverte_justice', COALESCE(a.decouvert, false)) AS faits
      FROM public.actions_tracables a
     WHERE a.auteur = p_cible AND COALESCE(a.type_action, '') <> ''
  ), toutes AS (
    SELECT * FROM hist UNION ALL SELECT * FROM publiques
  )
  SELECT t.trace_cle, t.source, t.faits
    FROM toutes t
   WHERE NOT EXISTS (SELECT 1 FROM public.fuites_journalistiques f WHERE f.trace_cle = t.trace_cle);
$function$;

-- imprimerie_acheter_bois(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.imprimerie_acheter_bois(p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_inv jsonb; v_arg numeric; v_liquide numeric;
  v_id text; v_etat jsonb; v_imp jsonb; v_caisse numeric; v_stock numeric; v_prix numeric; v_qte integer; v_total numeric;
  v_plafond integer := 10;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_qte IS NULL OR p_qte <= 0 OR p_qte > 1000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  SELECT coalesce(country, 'republic'), coalesce(current_city, 'capitale'), current_building,
         coalesce(inventory, '[]'::jsonb), coalesce(arg, 0), coalesce(liquide, 0)
    INTO v_pays, v_ville, v_bat, v_inv, v_arg, v_liquide
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_bat NOT IN ('la-tribune', 'imprimerie-librairie') THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.inventaire_quantite(v_inv, 'bois') < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', public.inventaire_quantite(v_inv, 'bois')); END IF;
  SELECT round(coalesce(prix_base, 5) * 1.10, 2) INTO v_prix FROM public.ressources_economie WHERE cle = 'bois';
  v_prix := coalesce(v_prix, 5.5);
  v_id := v_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'imprimerie_introuvable'); END IF;
  v_imp := coalesce(v_etat -> 'imprimerie', '{}'::jsonb);
  v_caisse := coalesce((v_imp ->> 'caisse')::numeric, 0);
  v_stock := coalesce((v_imp ->> 'stockBois')::numeric, 0);
  v_qte := least(p_qte, greatest(0, v_plafond - v_stock)::integer, floor(v_caisse / v_prix)::integer);
  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', CASE WHEN v_stock >= v_plafond THEN 'stock_plafond' ELSE 'caisse_insuffisante' END,
                              'stock', v_stock, 'plafond', v_plafond, 'caisse', v_caisse); END IF;
  v_total := round(v_qte * v_prix, 2);
  UPDATE public.personnages_donnees
     SET inventory = public.inventaire_retirer(v_inv, 'bois', v_qte), arg = v_arg + v_total, liquide = v_liquide + v_total
   WHERE name = v_moi;
  v_imp := v_imp || jsonb_build_object('caisse', v_caisse - v_total, 'stockBois', v_stock + v_qte);
  UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('imprimerie', v_imp))::text), updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'qte', v_qte, 'demande', p_qte, 'prixUnitaire', v_prix, 'total', v_total,
                            'arg', v_arg + v_total, 'liquide', v_liquide + v_total,
                            'inventory', public.inventaire_retirer(v_inv, 'bois', v_qte));
END; $function$;

-- imprimerie_acheter_bois(uuid,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.imprimerie_acheter_bois(p_requete uuid, p_qte integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('qte', p_qte);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'imprimerie_acheter_bois', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.imprimerie_acheter_bois(p_qte);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'imprimerie_acheter_bois', prm, v);
END; $function$;

-- imprimerie_cession_finaliser(text,text,text,numeric,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.imprimerie_cession_finaliser(p_requete text, p_acheteur text, p_imprimerie_id text, p_prix numeric, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_prix     constant numeric := 180000;
  v_rej      jsonb;
  v_data     jsonb;
  v_pays     text;
  v_caisse   text;
  v_acompte  numeric;
  v_expire   numeric;
  v_mvt      jsonb;
  v_hist     jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acheteur);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_acheteur, 'cession_imprimerie');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_imprimerie_id), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'imprimerie_invalide'));
  END IF;
  IF p_prix IS DISTINCT FROM c_prix THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'prix_invalide', 'prix', c_prix));
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_imprimerie_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'imprimerie_introuvable'));
  END IF;
  IF v_data ->> 'type' IS DISTINCT FROM 'imprimerie' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'bien_non_imprimerie'));
  END IF;
  IF v_data ->> 'proprietaire' IS DISTINCT FROM 'PNJ' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vendue',
                                                                        'proprietaire', v_data ->> 'proprietaire'));
  END IF;
  IF COALESCE((v_data -> 'compromis')::text, 'false') <> 'true'
     OR v_data ->> 'compromisPar' IS DISTINCT FROM p_acheteur THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'compromis_invalide'));
  END IF;
  v_expire := CASE WHEN jsonb_typeof(v_data -> 'compromisExpireAt') = 'number'
                   THEN (v_data ->> 'compromisExpireAt')::numeric ELSE NULL END;
  IF v_expire IS NOT NULL AND v_expire < extract(epoch FROM now()) * 1000 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'compromis_expire'));
  END IF;

  v_pays := COALESCE(NULLIF(btrim(v_data ->> 'country'), ''), 'republic');
  v_caisse := v_pays || '_gouvernement-min_fin';
  v_acompte := CASE WHEN jsonb_typeof(v_data -> 'acompte') = 'number'
                    THEN (v_data ->> 'acompte')::numeric ELSE 0 END;

  v_mvt := public.caisse_institution_mouvement(v_caisse, c_prix, true);
  IF COALESCE((v_mvt -> 'ok')::text, 'false') <> 'true' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', false, 'raison', 'caisse_etat_indisponible', 'detail', v_mvt -> 'raison'));
  END IF;

  v_hist := CASE WHEN jsonb_typeof(v_data -> 'historique') = 'array' THEN v_data -> 'historique' ELSE '[]'::jsonb END;
  v_hist := v_hist || jsonb_build_array(jsonb_build_object(
    'jour', COALESCE(p_jour, 1), 'montant', 0,
    'motif', 'Rachat de l''entreprise par ' || p_acheteur || ' (acte notarié)'));
  IF jsonb_array_length(v_hist) > 50 THEN
    v_hist := (SELECT jsonb_agg(e) FROM (
      SELECT e FROM jsonb_array_elements(v_hist) WITH ORDINALITY t(e, n)
       ORDER BY n OFFSET jsonb_array_length(v_hist) - 50) s);
  END IF;

  UPDATE public.entreprises
     SET data = (v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt' - 'compromisExpireAt')
                || jsonb_build_object('proprietaire', p_acheteur, 'historique', v_hist),
         updated_at = now()
   WHERE id = p_imprimerie_id;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'prix', c_prix, 'acompte', v_acompte, 'solde', c_prix - v_acompte,
    'caisse_id', v_caisse, 'caisse_solde', v_mvt -> 'solde', 'proprietaire', p_acheteur));
END;
$function$;

-- imprimerie_produire_tracts(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.imprimerie_produire_tracts(p_acteur text, p_pays text, p_ville text, p_batiment text, p_lots integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id text; v_data jsonb; v_imp jsonb; v_bois numeric; v_caisse numeric;
  v_prix numeric; v_boisLot numeric; v_salaireLot numeric; v_paLot numeric;
  v_cout numeric; v_salaire numeric; v_boisTotal numeric; v_paRequis integer;
  v_pa integer; v_arg numeric; v_liquide numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_lots, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lots_invalides');
  END IF;

  SELECT valeur INTO v_prix       FROM public.entreprises_constantes WHERE cle = 'prix_lot_tracts';
  SELECT valeur INTO v_boisLot    FROM public.entreprises_constantes WHERE cle = 'bois_par_lot_tracts';
  SELECT valeur INTO v_salaireLot FROM public.entreprises_constantes WHERE cle = 'salaire_lot_tracts';
  SELECT valeur INTO v_paLot      FROM public.entreprises_constantes WHERE cle = 'pa_par_lot_tracts';
  IF v_prix IS NULL OR v_boisLot IS NULL OR v_salaireLot IS NULL OR v_paLot IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tarif_indisponible');
  END IF;

  v_cout      := p_lots * v_prix;
  v_salaire   := p_lots * v_salaireLot;
  v_boisTotal := p_lots * v_boisLot;
  v_paRequis  := (p_lots * v_paLot)::integer;

  v_id := p_pays || '_' || p_ville || '_' || p_batiment;
  SELECT public.batiment_etat_lire(data) INTO v_data
    FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'atelier_absent'); END IF;
  v_imp := COALESCE(v_data->'imprimerie', '{}'::jsonb);

  v_bois := GREATEST(0, COALESCE((v_imp->>'stockBois')::numeric, 0));
  IF v_bois < v_boisTotal THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bois_insuffisant',
                              'stock', v_bois, 'requis', v_boisTotal);
  END IF;

  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0)
    INTO v_pa, v_arg, v_liquide
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < v_paRequis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_paRequis, 'pa_reel', v_pa);
  END IF;

  -- Le commanditaire paie. helvetia_debiter_fonds_ordinaires applique la regle existante :
  -- liquide d'abord, complete par la Banque nationale, jamais de debit partiel.
  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_cout) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'cout', v_cout);
  END IF;

  -- Atelier : le bois sort, la caisse encaisse la recette NETTE du salaire. Une seule ecriture.
  v_caisse := GREATEST(0, COALESCE((v_imp->>'caisse')::numeric, 0));
  v_imp := v_imp || jsonb_build_object('stockBois', v_bois - v_boisTotal,
                                       'caisse', v_caisse + (v_cout - v_salaire));
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_data || jsonb_build_object('imprimerie', v_imp))::text),
         updated_at = now()
   WHERE id = v_id;

  -- PA du producteur et salaire, dans la meme transaction que tout le reste.
  UPDATE public.personnages_donnees
     SET pa = pa - v_paRequis, arg = arg + v_salaire, liquide = liquide + v_salaire,
         updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'lots', p_lots, 'cout', v_cout, 'salaire', v_salaire,
    'bois', v_boisTotal, 'paConsommes', v_paRequis,
    'stockBois', v_bois - v_boisTotal, 'caisseAtelier', v_caisse + (v_cout - v_salaire),
    'pa', (SELECT pa FROM public.personnages_donnees WHERE name = p_acteur),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- jean_lou_tract_distribuer(uuid,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.jean_lou_tract_distribuer(p_requete uuid, p_pnj text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; qc jsonb; params jsonb; v jsonb; el jsonb; v_cycle text; v_pos integer;
  v_taux integer; v_roll integer; v_conv boolean; r jsonb; v_cibles jsonb; v_inf numeric;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(btrim(p_pnj), '') = '' OR length(p_pnj) > 120 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  params := jsonb_build_object('pnj', p_pnj);
  v := public.inventaire_action_rejouer_interne(a.name, p_requete, 'jean_lou', params);
  IF v IS NOT NULL THEN RETURN v || jsonb_build_object('quete_carriere', a.quete_carriere); END IF;
  qc := CASE WHEN jsonb_typeof(a.quete_carriere) = 'object' THEN a.quete_carriere ELSE '{}'::jsonb END;
  IF qc ->> 'ambition' IS DISTINCT FROM 'politique' OR qc ->> 'etape' IS DISTINCT FROM 'tracts_recus' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etape_non_conforme'); END IF;
  v_cibles := CASE WHEN jsonb_typeof(qc -> 'ciblesJeanLou') = 'array' THEN qc -> 'ciblesJeanLou' ELSE '[]'::jsonb END;
  IF v_cibles ? p_pnj THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_tente'); END IF;
  el := CASE WHEN jsonb_typeof(qc -> 'electionCible') = 'object' THEN qc -> 'electionCible' END;
  IF el IS NOT NULL THEN
    SELECT id INTO v_cycle FROM public.cycles_electoraux
     WHERE id IN (coalesce(el ->> 'country', a.country) || '_' || (el ->> 'posteId') || '_' || coalesce(el ->> 'city', ''),
                  coalesce(el ->> 'country', a.country) || '_' || (el ->> 'posteId'))
     ORDER BY length(id) DESC LIMIT 1;
  ELSE
    SELECT id, jsonb_build_object('posteId', coalesce(poste_id, data::jsonb ->> 'posteId'), 'city', coalesce(city, data::jsonb ->> 'city'), 'country', country)
      INTO v_cycle, el
      FROM public.cycles_electoraux
     WHERE country = a.country AND data::jsonb -> 'candidats' @> jsonb_build_array(jsonb_build_object('nom', a.name))
     ORDER BY id LIMIT 1;
  END IF;
  IF v_cycle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_candidat'); END IF;
  SELECT (o - 1)::integer INTO v_pos FROM jsonb_array_elements(CASE WHEN jsonb_typeof(a.inventory) = 'array' THEN a.inventory ELSE '[]'::jsonb END)
    WITH ORDINALITY x(e, o)
   WHERE e ->> 'type' = 'tract' AND e ->> 'origineQuete' = 'jean_lou'
     AND jsonb_typeof(e -> 'quantite') = 'number' AND (e ->> 'quantite')::numeric >= 1 ORDER BY o LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'tract_absent'); END IF;
  UPDATE public.personnages_donnees
     SET inventory = CASE WHEN (inventory -> v_pos ->> 'quantite')::numeric <= 1 THEN inventory - v_pos
                          ELSE jsonb_set(inventory, ARRAY[v_pos::text, 'quantite'], to_jsonb((inventory -> v_pos ->> 'quantite')::numeric - 1)) END
   WHERE name = a.name;
  v_inf := coalesce(CASE WHEN jsonb_typeof(a.resources -> 'inf') = 'number' THEN (a.resources ->> 'inf')::numeric END, 0);
  v_taux := least(80, 50 + floor(v_inf / 10)::integer);
  v_roll := floor(random() * 100)::integer + 1;
  v_conv := v_roll <= v_taux;
  IF v_conv THEN
    PERFORM set_config('rp.jean_lou_interne', 'on', true);
    r := public.elections_voix_pnj_enregistrer('jl-' || p_requete::text, a.name, v_cycle, a.name, p_pnj, 'jean_lou', NULL);
    PERFORM set_config('rp.jean_lou_interne', '', true);
    IF coalesce((r ->> 'ok')::boolean, false) IS NOT TRUE THEN v_conv := false; END IF;
  END IF;
  qc := qc || jsonb_build_object('electionCible', el,
          'ciblesJeanLou', v_cibles || to_jsonb(p_pnj),
          'resultatsJeanLou', (CASE WHEN jsonb_typeof(qc -> 'resultatsJeanLou') = 'array' THEN qc -> 'resultatsJeanLou' ELSE '[]'::jsonb END) || to_jsonb(v_conv));
  IF jsonb_array_length(qc -> 'ciblesJeanLou') >= 3 THEN qc := qc || jsonb_build_object('etape', 'tracts_termines'); END IF;
  UPDATE public.personnages_donnees SET quete_carriere = qc WHERE name = a.name;
  v := jsonb_build_object('ok', true, 'convaincu', v_conv, 'taux', v_taux, 'jet', v_roll, 'quete_carriere', qc,
         'voix', CASE WHEN v_conv THEN r ELSE NULL END)
       || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a.name);
  INSERT INTO public.inventaire_actions_recus VALUES (a.name, p_requete, 'jean_lou', params, v, now());
  RETURN v;
END; $function$;

-- jodie_interview_vers_forum() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.jodie_interview_vers_forum()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_texte text;
BEGIN
 IF NOT NEW.publie OR NEW.publie_le IS NULL OR nullif(btrim(NEW.article_titre),'') IS NULL
    OR nullif(btrim(NEW.article_texte),'') IS NULL THEN RETURN NEW; END IF;
 v_id := 'interview-jodie-'||NEW.id;
 -- Le forum affiche du HTML ; l'article original reste intact dans interviews_jodie.
 v_texte := replace(replace(replace(NEW.article_texte,'&','&amp;'),'<','&lt;'),'>','&gt;');
 v_texte := replace(v_texte,E'\n','<br>');
 INSERT INTO public.forum_topics(id,forum_id,title,author,country,time,last_post_author,last_post_time)
 VALUES(v_id,'presse',NEW.article_titre,'Jodie Moitout',NEW.country,NEW.publie_le::text,'Jodie Moitout',NEW.publie_le::text)
 ON CONFLICT(id) DO UPDATE SET title=EXCLUDED.title;
 INSERT INTO public.forum_posts(id,topic_id,author,content,time)
 VALUES(v_id||'-article',v_id,'Jodie Moitout',v_texte,NEW.publie_le::text)
 ON CONFLICT(id) DO UPDATE SET content=EXCLUDED.content;
 -- Le journal lit deja interviews_jodie : ne pas doubler ce circuit par une seconde file.
 RETURN NEW;
END;
$function$;

-- jodie_portrait_vers_journal() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.jodie_portrait_vers_journal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_sujet public.forum_topics%ROWTYPE;
BEGIN
  SELECT * INTO v_sujet FROM public.forum_topics WHERE id=NEW.topic_id;
  IF v_sujet.forum_id='presse'
     AND v_sujet.author='Jodie Moitout'
     AND NEW.author='Jodie Moitout'
     AND v_sujet.title LIKE 'Un jour, un portrait : %'
     AND length(btrim(coalesce(NEW.content,'')))>=40
  THEN
    INSERT INTO public.journal_articles_en_attente
      (id,country,rubrique,titre,texte,origine,priorite,statut,dedup_key)
    VALUES ('jodie-portrait-'||NEW.topic_id,v_sujet.country,'Portraits',
      v_sujet.title,NEW.content,'portrait_jodie','importante','attente',
      'portrait-jodie-'||NEW.topic_id)
    ON CONFLICT (id) DO UPDATE SET texte=EXCLUDED.texte
      WHERE public.journal_articles_en_attente.integree_le IS NULL;
  END IF;
  RETURN NEW;
END; $function$;

-- journal_edition_lire(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.journal_edition_lire(p_edition_id text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH e AS (
    SELECT * FROM public.journal_editions
     WHERE id = p_edition_id
       AND statut = 'publiee'
       AND prompt_version = 'v2-la-tribune'
  ),
  refs AS (
    SELECT DISTINCT jsonb_path_query(
             jsonb_build_array(e.une, e.double_page_centrale, e.page_economie_societe),
             'strict $.**.image.ref_id') #>> '{}' AS ref_id
      FROM e
  ),
  images AS (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'id',         f ->> 'id',
             'estPJ',      (f ->> 'estPJ')::boolean,
             'photo_url',  f ->> 'photo_url',
             'club_image', f ->> 'club_image')), '[]'::jsonb) AS liste
      FROM e,
           jsonb_array_elements(
             coalesce(e.faits_sources -> 'FACTS', '[]'::jsonb)
             || coalesce(e.faits_sources -> 'PUBLIC_STATEMENTS', '[]'::jsonb)) f
     WHERE f ->> 'id' IN (SELECT ref_id FROM refs WHERE ref_id IS NOT NULL)
       AND coalesce(f ->> 'photo_url', f ->> 'club_image') IS NOT NULL
  )
  SELECT jsonb_build_object(
           'ok', true,
           'id', e.id,
           'journal_id', e.journal_id,
           'date_edition', e.date_edition,
           'journal', jsonb_build_object('nom', j.nom, 'pays', j.pays, 'slug', j.slug),
           'une', e.une,
           'double_page_centrale', e.double_page_centrale,
           'page_economie_societe', e.page_economie_societe,
           -- Meme forme que la colonne d'origine, mais reduite a ce que le
           -- renderer lit reellement.
           'faits_sources', jsonb_build_object(
              'FACTS', (SELECT liste FROM images),
              'PUBLIC_STATEMENTS', '[]'::jsonb))
    FROM e JOIN public.journaux j ON j.id = e.journal_id;
$function$;

-- journal_edition_rattacher_au_titre() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.journal_edition_rattacher_au_titre()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_journal text;
BEGIN
  IF NEW.journal_id IS NOT NULL THEN RETURN NEW; END IF;
  SELECT j.id INTO v_journal
    FROM public.journaux j
   WHERE j.pays = NEW.country AND j.garanti_automatique;
  -- Un pays sans titre garanti garde une edition non rattachee : elle reste
  -- alors soumise a l'ancienne regle (un seul numero par pays et par jour).
  NEW.journal_id := v_journal;
  RETURN NEW;
END;
$function$;

-- journal_ventes_lire(boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.journal_ventes_lire(p_acquitter boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text:=public.mon_personnage();v_titulaire uuid;identifiants uuid[];evenements jsonb;restantes integer;
BEGIN
 IF moi IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501';END IF;
 SELECT id INTO v_titulaire FROM public.personnages_donnees WHERE name=moi AND user_id=auth.uid();
 IF v_titulaire IS NULL THEN RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE='42501';END IF;
 -- Toutes les ventes restent consultables ; les recus de lecture ne changent jamais la preuve.
 SELECT array_agg(v.id ORDER BY v.vendu_le DESC,v.id),coalesce(jsonb_agg(jsonb_build_object(
  'id',v.id,'ts',v.vendu_le,'acheteur',v.acheteur,'enseigne',v.journal_enseigne,'article',v.nom_commercial,
  'quantite',v.quantite,'prixUnitaire',v.prix_unitaire,'montant',v.montant_total,
  'nonLu',NOT EXISTS(SELECT 1 FROM public.journal_ventes_lectures l WHERE l.titulaire=v_titulaire AND l.vente=v.id))
  ORDER BY v.vendu_le DESC,v.id),'[]'::jsonb)
 INTO identifiants,evenements FROM public.ventes_snapshots v WHERE v.journal_titulaire=v_titulaire;
 IF p_acquitter THEN
  INSERT INTO public.journal_ventes_lectures(titulaire,vente) SELECT v_titulaire,x FROM unnest(identifiants) x ON CONFLICT DO NOTHING;
 END IF;
 SELECT count(*) INTO restantes FROM public.ventes_snapshots v WHERE v.journal_titulaire=v_titulaire
 AND NOT EXISTS(SELECT 1 FROM public.journal_ventes_lectures l WHERE l.titulaire=v_titulaire AND l.vente=v.id);
 RETURN jsonb_build_object('ok',true,'evenements',evenements,'nonLues',restantes);
END $function$;

-- kompromat_fabriquer(uuid,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.kompromat_fabriquer(p_requete uuid, p_agent text, p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; params jsonb; v jsonb; o jsonb;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(btrim(p_agent), '') = '' OR length(p_agent) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  params := jsonb_build_object('agent', p_agent, 'cible', p_cible);
  v := public.inventaire_action_rejouer_interne(a.name, p_requete, 'kompromat', params); IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_cible IS NULL OR p_cible = a.name OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF public.inventaire_place_restante(a.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  PERFORM 1 FROM public.comptes_bancaires WHERE personnage = a.name AND banque = 'nationale' FOR UPDATE;
  IF NOT public.helvetia_debiter_fonds_ordinaires(a.name, 300) THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  o := public.kompromat_objet_interne(p_cible, 'Information confidentielle obtenue.');
  v := public.inventaire_deposer_interne(a.name, o);
  IF (v ->> 'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'kompromat: depot refuse'; END IF;
  PERFORM public.ressource_ajuster_interne(a.name, 'inf', 5);
  v := v - 'qte' || jsonb_build_object('objet_id', o ->> 'id')
       || (SELECT jsonb_build_object('arg', arg, 'liquide', liquide, 'inf', resources -> 'inf') FROM public.personnages_donnees WHERE name = a.name);
  INSERT INTO public.inventaire_actions_recus VALUES (a.name, p_requete, 'kompromat', params, v, now());
  RETURN v;
END; $function$;

-- kompromat_objet_interne(text,text,integer) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.kompromat_objet_interne(p_cible text, p_desc text, p_expire integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT jsonb_build_object('id', 'kompromat-' || replace(gen_random_uuid()::text, '-', ''),
         'name', 'Kompromat sur ' || p_cible, 'icon', 'ti-file-shredder', 'type', 'kompromat',
         'cible', p_cible, 'desc', p_desc, 'descProvisoire', true, 'legal', false)
       || CASE WHEN p_expire IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('expireDay', p_expire) END $function$;

-- kompromat_rediger(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.kompromat_rediger(p_objet text, p_texte text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; v_pos integer; v_txt text;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_txt := left(btrim(coalesce(p_texte, '')), 600);
  IF v_txt = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_requis'); END IF;
  SELECT (o - 1)::integer INTO v_pos FROM jsonb_array_elements(CASE WHEN jsonb_typeof(a.inventory) = 'array' THEN a.inventory ELSE '[]'::jsonb END)
    WITH ORDINALITY x(e, o) WHERE e ->> 'id' = p_objet AND e ->> 'type' = 'kompromat' AND (e ->> 'descProvisoire')::boolean IS TRUE LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_introuvable'); END IF;
  UPDATE public.personnages_donnees
     SET inventory = jsonb_set(inventory, ARRAY[v_pos::text], (inventory -> v_pos) - 'descProvisoire' || jsonb_build_object('desc', v_txt))
   WHERE name = a.name;
  RETURN jsonb_build_object('ok', true)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a.name);
END; $function$;

-- minuit_informateurs() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.minuit_informateurs()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p record; i jsonb; v_garde jsonb; v_liquide numeric; v_compte text; v_solde numeric; v_cout integer;
  v_payes integer := 0; v_partis integer := 0; v_pris numeric;
BEGIN
  PERFORM set_config('rp.informateurs_interne', 'on', true);
  FOR p IN SELECT name, liquide, informateurs FROM public.personnages_donnees
            WHERE jsonb_typeof(informateurs) = 'array' AND jsonb_array_length(informateurs) > 0 FOR UPDATE LOOP
    v_garde := '[]'::jsonb; v_liquide := coalesce(p.liquide, 0);
    SELECT id, solde INTO v_compte, v_solde FROM public.comptes_bancaires
     WHERE personnage = p.name AND banque = 'nationale' FOR UPDATE;
    v_solde := coalesce(v_solde, 0);
    FOR i IN SELECT * FROM jsonb_array_elements(p.informateurs) LOOP
      v_cout := coalesce((i ->> 'cout')::integer, (public.informateur_niveau_interne((i ->> 'niveau')::integer) ->> 'cout')::integer, 0);
      IF i ->> 'payeLe' = to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD') THEN
        v_garde := v_garde || jsonb_build_array(i);
      ELSIF v_liquide + v_solde >= v_cout THEN
        v_pris := least(v_liquide, v_cout);
        v_liquide := v_liquide - v_pris; v_solde := v_solde - (v_cout - v_pris);
        v_garde := v_garde || jsonb_build_array(i || jsonb_build_object('joursActif', coalesce((i ->> 'joursActif')::integer, 0) + 1, 'payeLe', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD')));
        v_payes := v_payes + 1;
      ELSE
        v_partis := v_partis + 1;
        PERFORM public.mail_systeme_poser_interne('Système', p.name, 'Informateur parti',
          'Votre ' || lower(coalesce(i ->> 'label', 'informateur')) || ' (niveau ' || (i ->> 'niveau') || ') a quitté faute de paiement.',
          to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
      END IF;
    END LOOP;
    UPDATE public.personnages_donnees
       SET informateurs = v_garde, arg = coalesce(arg, 0) - (coalesce(p.liquide, 0) - v_liquide)
                                         - (coalesce((SELECT solde FROM public.comptes_bancaires WHERE id = v_compte), 0) - v_solde),
           liquide = v_liquide
     WHERE name = p.name;
    IF v_compte IS NOT NULL THEN UPDATE public.comptes_bancaires SET solde = v_solde, updated_at = now() WHERE id = v_compte; END IF;
  END LOOP;
  PERFORM set_config('rp.informateurs_interne', '', true);
  RETURN jsonb_build_object('ok', true, 'payes', v_payes, 'partis', v_partis);
END; $function$;

-- minuit_scandale(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.minuit_scandale(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_id integer; v_texte text;
BEGIN
  IF coalesce(btrim(p_pays), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pays_manquant'); END IF;
  IF EXISTS (SELECT 1 FROM public.scandales_tirages WHERE pays = p_pays AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', true, 'deja_tire', true);
  END IF;
  IF random() < 0.15 THEN
    SELECT id, texte INTO v_id, v_texte FROM public.scandales_predefinis ORDER BY random() LIMIT 1;
  END IF;
  INSERT INTO public.scandales_tirages (pays, jour, scandale) VALUES (p_pays, v_jour, v_id) ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', true, 'deja_tire', true); END IF;
  IF v_texte IS NOT NULL THEN
    PERFORM public.annonce_publique_interne(p_pays, '🔴 SCANDALE : ' || v_texte);
  END IF;
  RETURN jsonb_build_object('ok', true, 'scandale', v_id);
END; $function$;

-- presse_acteur_directeur(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_acteur_directeur(p_groupe_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.presse_membres
                  WHERE groupe_id = p_groupe_id AND personnage = v_moi AND grade = 'directeur') THEN
    RETURN NULL;
  END IF;
  RETURN v_moi;
END;
$function$;

-- presse_delegation_accorder(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_delegation_accorder(p_journal_id text, p_personnage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text; v_grade text;
BEGIN
  IF coalesce(btrim(p_journal_id),'') = '' OR coalesce(btrim(p_personnage),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  v_directeur := public.presse_directeur_du_journal(p_journal_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;

  SELECT m.grade INTO v_grade
    FROM public.journaux j
    JOIN public.presse_membres m ON m.groupe_id = j.groupe_id
   WHERE j.id = p_journal_id AND m.personnage = p_personnage;
  IF v_grade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre_du_groupe');
  END IF;
  IF v_grade NOT IN ('redacteur_chef','directeur') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_non_eligible',
                              'grade_actuel', v_grade,
                              'eligibles', jsonb_build_array('redacteur_chef','directeur'));
  END IF;

  INSERT INTO public.journaux_redacteurs (journal_id, personnage, accorde_par)
  VALUES (p_journal_id, p_personnage, v_directeur)
  ON CONFLICT (journal_id, personnage) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'journal', p_journal_id,
                            'personnage', p_personnage, 'grade', v_grade);
END;
$function$;

-- presse_delegation_retirer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_delegation_retirer(p_journal_id text, p_personnage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text; v_retirees int;
BEGIN
  v_directeur := public.presse_directeur_du_journal(p_journal_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;

  DELETE FROM public.journaux_redacteurs
   WHERE journal_id = p_journal_id AND personnage = p_personnage;
  GET DIAGNOSTICS v_retirees = ROW_COUNT;

  IF v_retirees = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delegation_absente');
  END IF;
  RETURN jsonb_build_object('ok', true, 'journal', p_journal_id, 'personnage', p_personnage);
END;
$function$;

-- presse_delegations_purger() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_delegations_purger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.grade IN ('redacteur_chef','directeur') THEN
    RETURN NULL;
  END IF;

  DELETE FROM public.journaux_redacteurs r
   USING public.journaux j
   WHERE r.journal_id = j.id
     AND j.groupe_id  = OLD.groupe_id
     AND r.personnage = OLD.personnage;

  RETURN NULL;
END;
$function$;

-- presse_designer_successeur(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_designer_successeur(p_groupe_id text, p_personnage text, p_grade_sortant text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text;
BEGIN
  v_directeur := public.presse_acteur_directeur(p_groupe_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;
  IF p_personnage = v_directeur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'successeur_identique');
  END IF;

  -- GRADE DU SORTANT : exige, valide, sans defaut. 'directeur' est exclu --
  -- ce serait soit deux directeurs, soit une passation qui n'en est pas une.
  IF p_grade_sortant IS NULL
     OR p_grade_sortant NOT IN ('correspondant','journaliste','redacteur_chef') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_sortant_invalide',
                              'recu', p_grade_sortant,
                              'valides', jsonb_build_array('correspondant','journaliste','redacteur_chef'));
  END IF;

  -- Verrou sur les deux lignes, dans un ordre stable, avant toute ecriture.
  PERFORM 1 FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND personnage IN (v_directeur, p_personnage)
   ORDER BY personnage FOR UPDATE;

  IF NOT EXISTS (SELECT 1 FROM public.presse_membres
                  WHERE groupe_id = p_groupe_id AND personnage = p_personnage) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre_du_groupe');
  END IF;

  -- On RETROGRADE d'abord, on PROMEUT ensuite : l'index unique « un seul
  -- directeur » n'est jamais heurte, et aucun etat intermediaire n'est
  -- visible hors de la transaction.
  UPDATE public.presse_membres
     SET grade = p_grade_sortant, grade_depuis = now(), nomme_par = '(passation)'
   WHERE groupe_id = p_groupe_id AND personnage = v_directeur;

  UPDATE public.presse_membres
     SET grade = 'directeur', grade_depuis = now(), nomme_par = v_directeur
   WHERE groupe_id = p_groupe_id AND personnage = p_personnage;

  RETURN jsonb_build_object('ok', true, 'directeur', p_personnage,
                            'ancien_directeur', v_directeur, 'grade_sortant', p_grade_sortant);
END;
$function$;

-- presse_directeur_du_journal(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_directeur_du_journal(p_journal_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN NULL; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.journaux j
      JOIN public.presse_membres m ON m.groupe_id = j.groupe_id
     WHERE j.id = p_journal_id AND m.personnage = v_moi AND m.grade = 'directeur'
  ) THEN RETURN NULL; END IF;
  RETURN v_moi;
END;
$function$;

-- presse_groupe_fonder(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_groupe_fonder(p_groupe_id text, p_pays text, p_nom text, p_fondateur text, p_organisation_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF coalesce(btrim(p_groupe_id),'') = '' OR coalesce(btrim(p_pays),'') = ''
     OR coalesce(btrim(p_nom),'') = '' OR coalesce(btrim(p_fondateur),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF EXISTS (SELECT 1 FROM public.groupes_presse WHERE id = p_groupe_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'groupe_deja_existant');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_fondateur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fondateur_introuvable');
  END IF;

  INSERT INTO public.groupes_presse (id, pays, nom, organisation_id)
  VALUES (p_groupe_id, p_pays, p_nom, p_organisation_id);

  -- Le fondateur devient Directeur de Publication.
  INSERT INTO public.presse_membres (groupe_id, personnage, grade, nomme_par)
  VALUES (p_groupe_id, p_fondateur, 'directeur', '(fondation)');

  RETURN jsonb_build_object('ok', true, 'groupe', p_groupe_id, 'directeur', p_fondateur);
END;
$function$;

-- presse_journal_creer(text,text,text,text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_journal_creer(p_journal_id text, p_groupe_id text, p_nom text, p_slug text, p_cree_par text DEFAULT NULL::text, p_garanti_automatique boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF coalesce(btrim(p_journal_id),'') = '' OR coalesce(btrim(p_groupe_id),'') = ''
     OR coalesce(btrim(p_nom),'') = '' OR coalesce(btrim(p_slug),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  SELECT pays INTO v_pays FROM public.groupes_presse WHERE id = p_groupe_id;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'groupe_introuvable');
  END IF;
  IF EXISTS (SELECT 1 FROM public.journaux WHERE id = p_journal_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journal_deja_existant');
  END IF;

  INSERT INTO public.journaux (id, groupe_id, pays, nom, slug, garanti_automatique, cree_par)
  VALUES (p_journal_id, p_groupe_id, v_pays, p_nom, p_slug,
          coalesce(p_garanti_automatique, false), p_cree_par);

  RETURN jsonb_build_object('ok', true, 'journal', p_journal_id, 'pays', v_pays);
END;
$function$;

-- presse_nommer_redacteur_chef(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_nommer_redacteur_chef(p_groupe_id text, p_personnage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text; v_grade text;
BEGIN
  v_directeur := public.presse_acteur_directeur(p_groupe_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;

  SELECT grade INTO v_grade FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND personnage = p_personnage FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre_du_groupe');
  END IF;
  IF v_grade <> 'journaliste' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_source_invalide',
                              'grade_actuel', v_grade, 'requis', 'journaliste');
  END IF;

  -- >>> POINT D'ACCROCHAGE (lot articles) : exiger ici les 15 oeuvres publiees
  -- pendant l'appartenance au groupe, comptees en DISTINCT sur les parutions.

  UPDATE public.presse_membres
     SET grade = 'redacteur_chef', grade_depuis = now(), nomme_par = v_directeur
   WHERE groupe_id = p_groupe_id AND personnage = p_personnage;

  RETURN jsonb_build_object('ok', true, 'grade', 'redacteur_chef');
END;
$function$;

-- presse_quitter(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_quitter(p_groupe_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_grade text; v_successeur text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT grade INTO v_grade FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND personnage = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre_du_groupe');
  END IF;

  DELETE FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND personnage = v_moi;

  SELECT personnage INTO v_successeur FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND grade = 'directeur';

  RETURN jsonb_build_object('ok', true, 'grade_quitte', v_grade,
                            'nouveau_directeur', v_successeur,
                            'groupe_sans_directeur', (v_successeur IS NULL));
END;
$function$;

-- presse_recruter(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_recruter(p_groupe_id text, p_personnage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text;
BEGIN
  IF coalesce(btrim(p_groupe_id),'') = '' OR coalesce(btrim(p_personnage),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  v_directeur := public.presse_acteur_directeur(p_groupe_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;
  IF p_personnage = v_directeur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_membre');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_personnage) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF EXISTS (SELECT 1 FROM public.presse_membres
              WHERE groupe_id = p_groupe_id AND personnage = p_personnage) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_membre');
  END IF;

  INSERT INTO public.presse_membres (groupe_id, personnage, grade, nomme_par)
  VALUES (p_groupe_id, p_personnage, 'correspondant', v_directeur);

  RETURN jsonb_build_object('ok', true, 'grade', 'correspondant');
END;
$function$;

-- presse_succession_apres_depart() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presse_succession_apres_depart()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_successeur text;
BEGIN
  IF OLD.grade <> 'directeur' THEN RETURN NULL; END IF;

  SELECT m.personnage INTO v_successeur
    FROM public.presse_membres m
   WHERE m.groupe_id = OLD.groupe_id
   ORDER BY CASE m.grade WHEN 'redacteur_chef' THEN 1
                         WHEN 'journaliste'    THEN 2
                         WHEN 'correspondant'  THEN 3
                         ELSE 9 END,
            m.grade_depuis ASC, m.rang ASC
   LIMIT 1;

  -- Dernier membre : le groupe reste sans directeur. Aucune donnee detruite,
  -- aucune regle inventee -- ce cas rejoindra le traitement general des
  -- organisations vides (arbitrage differe).
  IF v_successeur IS NULL THEN RETURN NULL; END IF;

  UPDATE public.presse_membres
     SET grade = 'directeur', grade_depuis = now(), nomme_par = '(succession)'
   WHERE groupe_id = OLD.groupe_id AND personnage = v_successeur;

  RETURN NULL;
END;
$function$;

-- publicite_premium_creer_beta(text,text,text,boolean) -> uuid | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.publicite_premium_creer_beta(p_personnage text, p_formule text, p_instructions text, p_assistance boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Session requise'; END IF;
 IF p_formule NOT IN ('cinq','dix') THEN RAISE EXCEPTION 'Formule invalide'; END IF;
 IF length(trim(coalesce(p_instructions,''))) < 10 OR length(p_instructions)>1500 THEN RAISE EXCEPTION 'Description invalide'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE user_id=auth.uid() AND name=p_personnage) THEN RAISE EXCEPTION 'Personnage non autorise'; END IF;
 INSERT INTO public.publicites_premium_presse(acheteur_user_id,personnage,formule,prix_centimes,instructions,assistance_ia,mode_beta_gratuit,etat)
 VALUES(auth.uid(),p_personnage,p_formule,CASE WHEN p_formule='cinq' THEN 499 ELSE 799 END,trim(p_instructions),coalesce(p_assistance,true),true,'brouillon') RETURNING id INTO v_id;
 RETURN v_id;
END $function$;

-- publicites_premium_pages_edition(text,text,date) -> TABLE(id uuid, image_path text, personnage text) | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.publicites_premium_pages_edition(p_pays text, p_journal_id text, p_date date)
 RETURNS TABLE(id uuid, image_path text, personnage text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ SELECT p.id,p.image_path,p.personnage FROM public.publicites_premium_presse p WHERE p.pays=p_pays AND p.journal_id=p_journal_id AND p.etat IN ('programmee','terminee') AND (p.paiement_confirme_le IS NOT NULL OR p.mode_beta_gratuit) AND p.image_path IS NOT NULL AND p.premiere_parution<=p_date AND p.derniere_parution>=p_date ORDER BY p.cree_le,p.id $function$;

-- rumeur_lancer(text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rumeur_lancer(p_type text, p_cible text, p_texte text, p_cible_trace text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_paie jsonb; v_reussi boolean; v_perte integer := 0; v_membres text[] := ARRAY[]::text[];
  v_repere boolean; v_effet text; v_ville text; v_retour integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_type NOT IN ('pj', 'organisation', 'local', 'gouvernement', 'pays') OR coalesce(btrim(p_cible), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF coalesce(btrim(p_texte), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_requis'); END IF;
  IF p_type = 'pj' AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  v_paie := public.payer_ordre(v_moi, 'lancer_rumeur_cible', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  v_reussi := random() < 0.75;
  IF v_reussi THEN
    IF p_type = 'pj' THEN
      v_perte := floor(random() * 16)::integer + 5;
      PERFORM public.rumeur_pop_retirer_interne(p_cible, v_perte);
    ELSIF p_type = 'organisation' THEN
      v_perte := floor(random() * 10)::integer + 1;
    ELSIF p_type = 'gouvernement' THEN
      v_perte := floor(random() * 5)::integer + 1;
      SELECT coalesce(array_agg(name), ARRAY[]::text[]) INTO v_membres FROM public.personnages_donnees
       WHERE country = p_cible AND poste ->> 'id' IN ('pm', 'min_int', 'min_fin', 'min_just', 'min_def', 'min_info', 'min_ae');
      PERFORM public.rumeur_pop_retirer_interne(n, v_perte) FROM unnest(v_membres) n;
    ELSIF p_type = 'pays' THEN
      v_perte := floor(random() * 5)::integer + 1;
      IF p_cible = 'republic' THEN
        FOREACH v_ville IN ARRAY ARRAY['capitale', 'ville_a', 'ville_b'] LOOP
          UPDATE public.indices_villes
             SET data = jsonb_set(data, '{social}', to_jsonb(greatest(0, least(100,
                          coalesce(CASE WHEN jsonb_typeof(data -> 'social') = 'number' THEN (data ->> 'social')::numeric END, 50) - v_perte))))
           WHERE id = 'republic_' || v_ville;
        END LOOP;
      END IF;
    END IF;
    PERFORM public.annonce_publique_interne('global', '🗯 ' || left(p_texte, 600));
    PERFORM public.crime_trace_rumeur_interne(v_moi, 'fausse_rumeur', left(coalesce(nullif(btrim(p_cible_trace), ''), p_cible), 200));
  ELSE
    v_retour := floor(random() * 11)::integer;
    v_perte := CASE WHEN v_retour < 5 THEN 0 WHEN v_retour < 10 THEN 1 ELSE 2 END;
    IF v_perte > 0 THEN
      PERFORM public.rumeur_pop_retirer_interne(v_moi, v_perte);
      PERFORM public.crime_dis_ajuster_interne(v_moi, -v_perte);
    END IF;
  END IF;
  v_repere := public.crime_detecter_interne(v_moi, 'fausse_rumeur', true);
  RETURN jsonb_build_object('ok', true, 'reussi', v_reussi, 'perte', v_perte, 'membres', coalesce(array_length(v_membres, 1), 0),
    'repere', v_repere)
    || (SELECT jsonb_build_object('pa', pa, 'pop', (resources ->> 'pop')::numeric, 'dis', resources -> 'dis', 'recherche', recherche)
          FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

-- rumeur_pop_retirer_interne(text,integer) -> void | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rumeur_pop_retirer_interne(p_nom text, p_perte integer)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ UPDATE public.personnages_donnees
         SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{pop}',
               to_jsonb(greatest(0, coalesce(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number'
                                                  THEN (resources ->> 'pop')::numeric END, 50) - p_perte)))
       WHERE name = p_nom $function$;

-- rumeurs_organisations_cibles() -> TABLE(id text, nom text, country text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.rumeurs_organisations_cibles()
 RETURNS TABLE(id text, nom text, country text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT o.id, o.data::jsonb->>'nom', o.data::jsonb->>'country'
  FROM public.organisations AS o
  WHERE coalesce(o.data::jsonb->>'nom','') <> ''
    AND (o.data::jsonb->>'visible' = 'true'
         OR o.data::jsonb->>'type' = 'criminelle')
  ORDER BY o.data::jsonb->>'nom', o.id;
$function$;

-- scandale_publier(bigint,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.scandale_publier(p_scandale_id bigint, p_article text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_s record; v_cid text; v_eff jsonb := NULL; v_n integer; v_moi text;
BEGIN
  SELECT * INTO v_s FROM public.scandales_presse WHERE id = p_scandale_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scandale_introuvable');
  END IF;

  IF NOT public.est_appel_serveur() THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    IF v_s.auteur IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur');
    END IF;
  END IF;

  IF v_s.chronique_id IS NOT NULL THEN
    SELECT count(*) INTO v_n FROM public.scandales_presse WHERE auteur = v_s.auteur AND chronique_id IS NOT NULL;
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'chronique_id', v_s.chronique_id, 'total_auteur', v_n);
  END IF;

  v_cid := 'chronique-scandale-' || p_scandale_id::text;
  BEGIN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES (v_cid, v_s.pays, v_s.ville, 'scandale_presse',
            jsonb_build_array(v_s.cible, v_s.auteur),
            COALESCE(NULLIF(btrim(p_article), ''), v_s.accusation),
            jsonb_build_object('cible', v_s.cible, 'auteur', v_s.auteur, 'auteur_public', v_s.auteur,
                               'type_contenu', 'kompromat', 'accusation', v_s.accusation,
                               'scandale_id', p_scandale_id),
            'scandale-' || p_scandale_id::text);
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  IF NOT v_s.effet_applique THEN
    v_eff := public.personnage_ajuster_pop_inf(v_s.cible, -15, -15);
  END IF;

  UPDATE public.scandales_presse
     SET article = COALESCE(NULLIF(btrim(p_article), ''), article),
         chronique_id = v_cid, statut = 'publie', effet_applique = true
   WHERE id = p_scandale_id;

  SELECT count(*) INTO v_n FROM public.scandales_presse WHERE auteur = v_s.auteur AND chronique_id IS NOT NULL;
  RETURN jsonb_build_object('ok', true, 'chronique_id', v_cid, 'effet', v_eff, 'total_auteur', v_n);
END;
$function$;

-- scandale_taux(text,jsonb,integer) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.scandale_taux(p_career text, p_poste jsonb, p_malus_isn integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT GREATEST(5, 35
    + CASE WHEN p_career = 'press' THEN 15
           WHEN COALESCE(p_poste ->> 'id', '') = 'min_info' THEN 10
           ELSE 0 END
    - LEAST(25, GREATEST(0, COALESCE(p_malus_isn, 0))))::integer;
$function$;

-- scandale_tenter(text,text,text,text,integer,timestamp with time zone) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.scandale_tenter(p_requete text, p_joueur text, p_cible text, p_accusation text, p_malus_isn integer DEFAULT 0, p_instant timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej  jsonb;
  v_p    record;
  v_c    record;
  v_jour date;
  v_taux integer;
  v_jet  integer;
  v_id   bigint;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'scandale');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_cible), '') = '' OR p_cible = p_joueur OR COALESCE(btrim(p_accusation), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;

  SELECT pa, liquide, banque, career, poste, country, current_city INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;
  SELECT country INTO v_c FROM public.personnages WHERE name = p_cible;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'cible_introuvable'));
  END IF;

  -- Ressources verifiees AVANT le jet : une acceptation ne doit jamais conduire a un etat impossible.
  IF COALESCE(v_p.pa, 0) < 3 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;
  IF COALESCE(v_p.liquide, 0) + COALESCE(v_p.banque, 0) < 800 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'));
  END IF;

  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;
  -- La tentative quotidienne est consommee ici, avant meme le jet : refus de la redaction compris.
  INSERT INTO public.scandales_tentatives (auteur, jour_paris, cible)
  VALUES (p_joueur, v_jour, p_cible)
  ON CONFLICT (auteur, jour_paris) DO NOTHING;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_tente_aujourdhui'));
  END IF;

  v_taux := public.scandale_taux(v_p.career, v_p.poste, p_malus_isn);
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'accepte', false, 'jet', v_jet, 'taux', v_taux));
  END IF;

  INSERT INTO public.scandales_presse (auteur, cible, pays, ville, accusation, jour_paris)
  VALUES (p_joueur, p_cible, v_c.country, v_p.current_city, btrim(p_accusation), v_jour)
  RETURNING id INTO v_id;
  UPDATE public.scandales_tentatives SET accepte = true WHERE auteur = p_joueur AND jour_paris = v_jour;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'accepte', true, 'jet', v_jet, 'taux', v_taux,
    'scandale_id', v_id, 'pa', 3, 'cout', 800));
END;
$function$;

-- tractage_collectif_identifiant(text,text,integer) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tractage_collectif_identifiant(p_requete text, p_nom text, p_num integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT md5(p_requete || ':' || p_nom || ':' || p_num::text)
$function$;

-- tracts_appliquer_effet_pop(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_appliquer_effet_pop(p_cible text, p_delta integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pop numeric;
BEGIN
  IF p_delta IS NULL OR abs(p_delta) < 3 OR abs(p_delta) > 8 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_invalide');
  END IF;
  UPDATE public.personnages
     SET resources = jsonb_set(CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END, '{pop}',
           to_jsonb(GREATEST(0, LEAST(100,
             COALESCE(CASE WHEN jsonb_typeof(resources -> 'pop') = 'number' THEN (resources ->> 'pop')::numeric END, 50) + p_delta))))
   WHERE name = p_cible
   RETURNING (resources ->> 'pop')::numeric INTO v_pop;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
  END IF;
  RETURN jsonb_build_object('ok', true, 'pop', v_pop);
END;
$function$;

-- tracts_donner_joueur(text,text,text,jsonb) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_donner_joueur(p_requete text, p_expediteur text, p_destinataire text, p_objet jsonb)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT jsonb_build_object('ok',false,'raison','contrat_versionne_requis'); $function$;

-- tracts_donner_joueur(uuid,integer,bigint,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_donner_joueur(p_requete uuid, p_index integer, p_revision bigint, p_destinataire text, p_quantite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; d public.personnages_donnees; o jsonb; v jsonb; params jsonb; total numeric; don text;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_quantite IS NULL OR p_quantite NOT BETWEEN 1 AND 1000 THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide');END IF;
 params:=jsonb_build_object('index',p_index,'revision',p_revision,'destinataire',p_destinataire,'quantite',p_quantite);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'don_tracts',params);IF v IS NOT NULL THEN RETURN v;END IF;
 SELECT * INTO d FROM public.personnages_donnees WHERE name=p_destinataire;
 IF NOT FOUND OR d.name=a.name THEN RETURN jsonb_build_object('ok',false,'raison','destinataire_invalide');END IF;
 IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM (d.country,d.current_city,d.current_building,d.current_room)
 OR a.current_building IS NULL OR a.current_room IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_co_presents');END IF;
 IF p_revision IS DISTINCT FROM a.inventory_revision THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_perime');END IF;
 IF p_index IS NULL OR p_index<0 OR p_index>=jsonb_array_length(a.inventory) THEN RETURN jsonb_build_object('ok',false,'raison','index_invalide');END IF;
 o:=a.inventory->p_index;
 IF coalesce(o->>'type','') NOT IN('tract','tract_calomnieux') OR o->>'origineQuete'='jean_lou'
 OR nullif(btrim(o->>'cible'),'') IS NULL OR jsonb_typeof(o->'quantite') IS DISTINCT FROM 'number' THEN RETURN jsonb_build_object('ok',false,'raison','objet_invalide');END IF;
 total:=(o->>'quantite')::numeric;
 IF total<>trunc(total) OR total<p_quantite THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide');END IF;
 UPDATE public.personnages_donnees SET inventory=CASE WHEN total=p_quantite THEN inventory-p_index
  ELSE jsonb_set(inventory,ARRAY[p_index::text,'quantite'],to_jsonb(total-p_quantite)) END WHERE name=a.name;
 o:=o||jsonb_build_object('quantite',p_quantite);
 don:='don-tracts-'||md5(a.name)||'-'||p_requete;
 INSERT INTO public.objets_recus(id,destinataire,expediteur,data) VALUES(don,d.name,a.name,to_jsonb(o::text));
 SELECT jsonb_build_object('ok',true,'inventory',inventory,'revision',inventory_revision,'quantite',p_quantite,'destinataire',d.name,'livraison',don)
 INTO v FROM public.personnages_donnees WHERE name=a.name;
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'don_tracts',params,v,now());RETURN v;
END; $function$;

-- tracts_electoraux_distribuer(text,text,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text, p_pnj_nom text, p_vol_pnj integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  RETURN public.tracts_electoraux_distribuer_interne(p_requete, p_joueur, p_cycle_id, p_candidat, p_sens, p_pnj_nom, p_vol_pnj, now());
END;
$function$;

-- tracts_electoraux_distribuer_collectif(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer_collectif(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_prev jsonb;v_p record;v_max integer;v_n text;v_r jsonb;
v_list text[];v_attempts integer:=0;v_success integer:=0;v_qty integer;
v_inv jsonb;v_pa integer;
BEGIN
 PERFORM public.exiger_acteur(p_joueur);
 v_prev:=public.assemblee_requete_ouvrir(p_requete,p_joueur,'tract_electoral_collectif');
 IF v_prev IS NOT NULL THEN RETURN v_prev; END IF;
 SELECT country,current_city,current_building,current_room,inventory,pa INTO v_p
 FROM public.personnages_donnees WHERE name=p_joueur FOR UPDATE;
 IF NOT FOUND OR v_p.current_building IS DISTINCT FROM 'stade' THEN
  RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','hors_stade'));
 END IF;
 SELECT coalesce(sum((i->>'quantite')::integer),0) INTO v_qty
 FROM jsonb_array_elements(coalesce(v_p.inventory,'[]'::jsonb)) i
 WHERE i->>'type'='tract' AND i->>'cible'=p_candidat
 AND coalesce(i->>'tractType','pour')=p_sens
 AND coalesce(i->>'origineQuete','')<>'jean_lou'
 AND (i->>'quantite')~'^[0-9]+$';
 v_max:=least(coalesce(v_p.pa,0),coalesce(v_qty,0));
 IF v_max<1 THEN
  RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison',CASE WHEN v_qty<1 THEN 'tract_absent' ELSE 'pa_insuffisants' END));
 END IF;
 SELECT array_agg(nom ORDER BY nom) INTO v_list FROM (
 SELECT c.nom FROM public.tracts_pnj_catalogue c WHERE c.pays=v_p.country
 AND c.ville=v_p.current_city AND c.building_id='stade'
 UNION
 SELECT m.nom FROM public.pnj_membres m WHERE m.pays=v_p.country
 AND m.ville=v_p.current_city AND m.building_id='stade'
 AND m.statut='actif') x;
 IF coalesce(array_length(v_list,1),0)=0 THEN
  RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','aucune_cible'));
 END IF;
 IF coalesce(v_p.pa,0) < least(v_qty,coalesce(array_length(v_list,1),0)) THEN
  RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','pa_insuffisants'));
 END IF;
 FOREACH v_n IN ARRAY v_list LOOP
  EXIT WHEN v_attempts>=v_max;
  v_r:=public.tracts_electoraux_distribuer_collectif_interne(
   public.tractage_collectif_identifiant(p_requete,v_n,v_attempts),
   p_joueur,p_cycle_id,p_candidat,p_sens,v_n,NULL,now());
  IF coalesce((v_r->>'ok')::boolean,false) THEN
   v_attempts:=v_attempts+1;
   IF coalesce((v_r->>'reussi')::boolean,false) THEN v_success:=v_success+1; END IF;
   v_inv:=v_r->'inventory';v_pa:=(v_r->>'pa')::integer;
  ELSIF v_r->>'raison' NOT IN ('deja_vote','pnj_absent_ou_non_verifiable') THEN
   IF v_attempts=0 THEN RETURN public.assemblee_requete_clore(p_requete,v_r); END IF;
   EXIT;
  END IF;
 END LOOP;
 RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object(
 'ok',true,'essais',v_attempts,'reussites',v_success,
 'inventory',coalesce(v_inv,v_p.inventory),'pa',coalesce(v_pa,v_p.pa)));
END $function$;

-- tracts_electoraux_distribuer_collectif_interne(text,text,text,text,text,text,integer,timestamp with time zone) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer_collectif_interne(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text, p_pnj_nom text, p_vol_pnj integer, p_instant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej     jsonb;
  v_p       record;
  v_c       record;
  v_d       jsonb;
  v_ms      bigint;
  v_tour    bigint;
  v_ville   text;
  v_nom     text;
  v_cle     text;
  v_taux    integer;
  v_jet     integer;
  v_sens    smallint;
  v_effet   smallint;
  v_score   numeric;
  v_vol_pnj integer;
  v_inv     jsonb;
  v_new_inv jsonb; v_tract_pos integer; v_qty integer; v_pa_after integer;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_electoral');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_sens NOT IN ('pour', 'contre') OR COALESCE(btrim(p_candidat), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;
  v_sens := CASE WHEN p_sens = 'pour' THEN 1 ELSE -1 END;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p FROM public.personnages_donnees WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT id, country, city, poste_id, data INTO v_c FROM public.cycles_electoraux WHERE id = p_cycle_id;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'));
  END IF;
  BEGIN v_d := v_c.data::jsonb; EXCEPTION WHEN OTHERS THEN v_d := NULL; END;
  IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_illisible'));
  END IF;
  IF COALESCE(v_c.poste_id, v_d ->> 'posteId', '') NOT IN ('president', 'maire', 'depute') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_non_concerne'));
  END IF;

  IF v_c.country IS DISTINCT FROM v_p.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_pays'));
  END IF;

  v_ms := floor(extract(epoch FROM p_instant) * 1000)::bigint;
  v_tour := CASE WHEN jsonb_typeof(v_d -> 'dateVote') = 'number' THEN (v_d ->> 'dateVote')::numeric::bigint END;
  IF v_tour IS NULL OR jsonb_typeof(v_d -> 'dateResultats') <> 'number'
     OR COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR v_ms < v_tour OR v_ms >= (v_d ->> 'dateResultats')::numeric::bigint THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_phase_vote'));
  END IF;

  IF extract(isodow FROM (p_instant AT TIME ZONE 'Europe/Paris')) <> 7 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pas_dimanche'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(v_d -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'candidat_hors_scrutin'));
  END IF;

  v_ville := NULLIF(COALESCE(v_c.city, v_d ->> 'city'), '');
  IF v_ville IS NOT NULL THEN
    IF v_p.current_city IS DISTINCT FROM v_ville THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_ville', 'ville_scrutin', v_ville));
    END IF;
  ELSIF COALESCE(v_p.current_city, '') NOT IN ('capitale', 'ville_a', 'ville_b', 'caserne', 'qhs') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_territoire'));
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_p.inventory) = 'array' THEN v_p.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_inv) i
     WHERE i ->> 'type' = 'tract' AND i ->> 'cible' = p_candidat
       AND COALESCE(i ->> 'tractType', 'pour') = p_sens
       AND COALESCE(i ->> 'origineQuete', '') <> 'jean_lou'
       AND jsonb_typeof(i -> 'quantite') = 'number' AND (i ->> 'quantite')::numeric >= 1
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'tract_absent'));
  END IF;

  IF COALESCE(v_p.pa, 0) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
  IF v_nom = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
  END IF;
  v_cle := v_c.country || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;

  PERFORM pg_advisory_xact_lock(hashtext('tract_pnj|' || p_cycle_id || '|' || v_tour || '|' || v_cle));
  IF EXISTS (SELECT 1 FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND pnj_cle = v_cle)
     OR (jsonb_typeof(v_d -> 'votesPNJ') = 'object' AND ((v_d -> 'votesPNJ') ? p_pnj_nom
         OR (v_d -> 'votesPNJ') ? replace(p_pnj_nom, '''', ''))) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vote'));
  END IF;


  -- PNJ dynamiques connus de la base : la cible doit etre dans la meme piece.
  -- Les PNJ de decor non enregistres demandent un catalogue serveur avant validation.
  SELECT pm.car_vol INTO v_vol_pnj FROM public.pnj_membres pm
    WHERE lower(btrim(pm.nom))=lower(btrim(p_pnj_nom))
      AND pm.pays=v_c.country AND pm.ville=v_p.current_city
      AND pm.building_id=(SELECT current_building FROM public.personnages_donnees WHERE name=p_joueur)
      
      AND pm.statut='actif' LIMIT 1;
  IF NOT FOUND THEN
    SELECT c.car_vol INTO v_vol_pnj FROM public.tracts_pnj_catalogue c
    WHERE lower(btrim(c.nom))=lower(btrim(split_part(p_pnj_nom, ' (PNJ)', 1)))
      AND c.pays=v_c.country AND c.ville=v_p.current_city
      AND c.building_id=(SELECT current_building FROM public.personnages_donnees WHERE name=p_joueur)
      
    LIMIT 1;
    IF NOT FOUND THEN
      RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','pnj_absent_ou_non_verifiable'));
    END IF;
  END IF;
  -- Debiter PA et tract dans la meme transaction que le jet et la voix.
  SELECT (ord-1)::integer,(item->>'quantite')::integer
    INTO v_tract_pos,v_qty
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY t(item,ord)
   WHERE item->>'type'='tract' AND item->>'cible'=p_candidat
     AND coalesce(item->>'tractType','pour')=p_sens
     AND coalesce(item->>'origineQuete','')<>'jean_lou'
     AND (item->>'quantite') ~ '^[0-9]+$' AND (item->>'quantite')::integer>0
   ORDER BY ord LIMIT 1;
  IF v_tract_pos IS NULL THEN
    RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','tract_absent'));
  END IF;
  IF v_qty=1 THEN
    v_new_inv:=v_inv - v_tract_pos;
  ELSE
    v_new_inv:=jsonb_set(v_inv,ARRAY[v_tract_pos::text,'quantite'],to_jsonb(v_qty-1));
  END IF;
  UPDATE public.personnages_donnees SET inventory=v_new_inv,pa=pa-1 WHERE name=p_joueur AND pa>=1 RETURNING pa INTO v_pa_after;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','pa_insuffisants'));
  END IF;


  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(v_vol_pnj, 10))));
  v_taux := least(100,ceil(v_taux * 1.5)::integer); v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'consomme', 1, 'pa', v_pa_after, 'inventory', v_new_inv, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens));
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('tract_cand|' || p_cycle_id || '|' || v_tour || '|' || p_candidat));
  IF v_sens = 1 THEN
    v_effet := 1;
  ELSE
    SELECT
      (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votes') = 'object' THEN v_d -> 'votes' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votesPNJ') = 'object' THEN v_d -> 'votesPNJ' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + COALESCE((SELECT sum(effet) FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND candidat = p_candidat), 0)
    INTO v_score;
    v_effet := CASE WHEN v_score >= 1 THEN -1 ELSE 0 END;
  END IF;

  INSERT INTO public.elections_tracts_pnj (cycle_id, tour, pnj_cle, pnj_nom, candidat, sens, effet, joueur)
  VALUES (p_cycle_id, v_tour, v_cle, p_pnj_nom, p_candidat, v_sens, v_effet, p_joueur);

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', true, 'consomme', 1, 'pa', v_pa_after, 'inventory', v_new_inv, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens,
    'effet', v_effet, 'tour', v_tour));
END;
$function$;

-- tracts_electoraux_distribuer_interne(text,text,text,text,text,text,integer,timestamp with time zone) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer_interne(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text, p_pnj_nom text, p_vol_pnj integer, p_instant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej     jsonb;
  v_p       record;
  v_c       record;
  v_d       jsonb;
  v_ms      bigint;
  v_tour    bigint;
  v_ville   text;
  v_nom     text;
  v_cle     text;
  v_taux    integer;
  v_jet     integer;
  v_sens    smallint;
  v_effet   smallint;
  v_score   numeric;
  v_vol_pnj integer;
  v_inv     jsonb;
  v_new_inv jsonb; v_tract_pos integer; v_qty integer; v_pa_after integer;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_electoral');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_sens NOT IN ('pour', 'contre') OR COALESCE(btrim(p_candidat), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;
  v_sens := CASE WHEN p_sens = 'pour' THEN 1 ELSE -1 END;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p FROM public.personnages_donnees WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT id, country, city, poste_id, data INTO v_c FROM public.cycles_electoraux WHERE id = p_cycle_id;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'));
  END IF;
  BEGIN v_d := v_c.data::jsonb; EXCEPTION WHEN OTHERS THEN v_d := NULL; END;
  IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_illisible'));
  END IF;
  IF COALESCE(v_c.poste_id, v_d ->> 'posteId', '') NOT IN ('president', 'maire', 'depute') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_non_concerne'));
  END IF;

  IF v_c.country IS DISTINCT FROM v_p.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_pays'));
  END IF;

  v_ms := floor(extract(epoch FROM p_instant) * 1000)::bigint;
  v_tour := CASE WHEN jsonb_typeof(v_d -> 'dateVote') = 'number' THEN (v_d ->> 'dateVote')::numeric::bigint END;
  IF v_tour IS NULL OR jsonb_typeof(v_d -> 'dateResultats') <> 'number'
     OR COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR v_ms < v_tour OR v_ms >= (v_d ->> 'dateResultats')::numeric::bigint THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_phase_vote'));
  END IF;

  IF extract(isodow FROM (p_instant AT TIME ZONE 'Europe/Paris')) <> 7 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pas_dimanche'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(v_d -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'candidat_hors_scrutin'));
  END IF;

  v_ville := NULLIF(COALESCE(v_c.city, v_d ->> 'city'), '');
  IF v_ville IS NOT NULL THEN
    IF v_p.current_city IS DISTINCT FROM v_ville THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_ville', 'ville_scrutin', v_ville));
    END IF;
  ELSIF COALESCE(v_p.current_city, '') NOT IN ('capitale', 'ville_a', 'ville_b', 'caserne', 'qhs') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_territoire'));
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_p.inventory) = 'array' THEN v_p.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_inv) i
     WHERE i ->> 'type' = 'tract' AND i ->> 'cible' = p_candidat
       AND COALESCE(i ->> 'tractType', 'pour') = p_sens
       AND COALESCE(i ->> 'origineQuete', '') <> 'jean_lou'
       AND jsonb_typeof(i -> 'quantite') = 'number' AND (i ->> 'quantite')::numeric >= 1
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'tract_absent'));
  END IF;

  IF COALESCE(v_p.pa, 0) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
  IF v_nom = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
  END IF;
  v_cle := v_c.country || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;

  PERFORM pg_advisory_xact_lock(hashtext('tract_pnj|' || p_cycle_id || '|' || v_tour || '|' || v_cle));
  IF EXISTS (SELECT 1 FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND pnj_cle = v_cle)
     OR (jsonb_typeof(v_d -> 'votesPNJ') = 'object' AND ((v_d -> 'votesPNJ') ? p_pnj_nom
         OR (v_d -> 'votesPNJ') ? replace(p_pnj_nom, '''', ''))) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vote'));
  END IF;


  -- PNJ dynamiques connus de la base : la cible doit etre dans la meme piece.
  -- Les PNJ de decor non enregistres demandent un catalogue serveur avant validation.
  SELECT pm.car_vol INTO v_vol_pnj FROM public.pnj_membres pm
    WHERE lower(btrim(pm.nom))=lower(btrim(p_pnj_nom))
      AND pm.pays=v_c.country AND pm.ville=v_p.current_city
      AND pm.building_id=(SELECT current_building FROM public.personnages_donnees WHERE name=p_joueur)
      AND pm.room_id=(SELECT current_room FROM public.personnages_donnees WHERE name=p_joueur)
      AND pm.statut='actif' LIMIT 1;
  IF NOT FOUND THEN
    SELECT c.car_vol INTO v_vol_pnj FROM public.tracts_pnj_catalogue c
    WHERE lower(btrim(c.nom))=lower(btrim(split_part(p_pnj_nom, ' (PNJ)', 1)))
      AND c.pays=v_c.country AND c.ville=v_p.current_city
      AND c.building_id=(SELECT current_building FROM public.personnages_donnees WHERE name=p_joueur)
      AND c.room_id=(SELECT current_room FROM public.personnages_donnees WHERE name=p_joueur)
    LIMIT 1;
    IF NOT FOUND THEN
      RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','pnj_absent_ou_non_verifiable'));
    END IF;
  END IF;
  -- Debiter PA et tract dans la meme transaction que le jet et la voix.
  SELECT (ord-1)::integer,(item->>'quantite')::integer
    INTO v_tract_pos,v_qty
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY t(item,ord)
   WHERE item->>'type'='tract' AND item->>'cible'=p_candidat
     AND coalesce(item->>'tractType','pour')=p_sens
     AND coalesce(item->>'origineQuete','')<>'jean_lou'
     AND (item->>'quantite') ~ '^[0-9]+$' AND (item->>'quantite')::integer>0
   ORDER BY ord LIMIT 1;
  IF v_tract_pos IS NULL THEN
    RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','tract_absent'));
  END IF;
  IF v_qty=1 THEN
    v_new_inv:=v_inv - v_tract_pos;
  ELSE
    v_new_inv:=jsonb_set(v_inv,ARRAY[v_tract_pos::text,'quantite'],to_jsonb(v_qty-1));
  END IF;
  UPDATE public.personnages_donnees SET inventory=v_new_inv,pa=pa-1 WHERE name=p_joueur AND pa>=1 RETURNING pa INTO v_pa_after;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete,jsonb_build_object('ok',false,'raison','pa_insuffisants'));
  END IF;


  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(v_vol_pnj, 10))));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'consomme', 1, 'pa', v_pa_after, 'inventory', v_new_inv, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens));
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('tract_cand|' || p_cycle_id || '|' || v_tour || '|' || p_candidat));
  IF v_sens = 1 THEN
    v_effet := 1;
  ELSE
    SELECT
      (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votes') = 'object' THEN v_d -> 'votes' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votesPNJ') = 'object' THEN v_d -> 'votesPNJ' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + COALESCE((SELECT sum(effet) FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND candidat = p_candidat), 0)
    INTO v_score;
    v_effet := CASE WHEN v_score >= 1 THEN -1 ELSE 0 END;
  END IF;

  INSERT INTO public.elections_tracts_pnj (cycle_id, tour, pnj_cle, pnj_nom, candidat, sens, effet, joueur)
  VALUES (p_cycle_id, v_tour, v_cle, p_pnj_nom, p_candidat, v_sens, v_effet, p_joueur);

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', true, 'consomme', 1, 'pa', v_pa_after, 'inventory', v_new_inv, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens,
    'effet', v_effet, 'tour', v_tour));
END;
$function$;

-- tracts_electoraux_nom_pnj(text) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_electoraux_nom_pnj(p_nom text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT btrim(regexp_replace(regexp_replace(lower(COALESCE(p_nom, '')), '\s*\(pnj\)\s*$', ''), '[''’]', '', 'g'));
$function$;

-- tracts_electoraux_taux(numeric,numeric,numeric) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_electoraux_taux(p_cha numeric, p_inf numeric, p_vol_pnj numeric)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT LEAST(85, GREATEST(0,
    45 + floor(COALESCE(p_cha, 8))::integer
       + floor(GREATEST(0, COALESCE(p_inf, 0)) / 4)::integer
       - 2 * GREATEST(0, floor(COALESCE(p_vol_pnj, 10))::integer - 10)))::integer;
$function$;

-- tracts_imprimer(text,text,text,integer,text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_imprimer(p_pays text, p_ville text, p_batiment text, p_lots integer, p_cible text, p_sens text, p_calomnieux boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_r jsonb; v_inv jsonb; v_qte integer; v_sens text; v_trouve boolean := false; v_repere boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cible), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_requise'); END IF;
  IF p_calomnieux AND p_batiment NOT IN ('la-tribune', 'imprimerie-librairie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'atelier_introuvable'); END IF;
  v_r := public.imprimerie_produire_tracts(v_moi, p_pays, p_ville, p_batiment, CASE WHEN p_calomnieux THEN 1 ELSE p_lots END);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  v_qte := 10 * CASE WHEN p_calomnieux THEN 1 ELSE greatest(1, p_lots) END;
  v_sens := CASE WHEN p_sens = 'contre' THEN 'contre' ELSE 'pour' END;

  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT coalesce(jsonb_agg(CASE WHEN NOT v_trouve_ligne THEN e ELSE e || jsonb_build_object('quantite', coalesce((e ->> 'quantite')::numeric, 0) + v_qte) END ORDER BY o),
                  '[]'::jsonb), bool_or(v_trouve_ligne)
    INTO v_inv, v_trouve
    FROM (SELECT e, o, coalesce(o = (SELECT min(o2) FROM jsonb_array_elements(v_inv) WITH ORDINALITY y(e2, o2)
                             WHERE CASE WHEN p_calomnieux
                                        THEN e2 ->> 'type' = 'tract_calomnieux' AND e2 ->> 'cible' = p_cible
                                        ELSE e2 ->> 'type' = 'tract' AND e2 ->> 'cible' = p_cible
                                             AND coalesce(e2 ->> 'tractType', 'pour') = v_sens
                                             AND coalesce(e2 ->> 'electionPosteId', '') = '' AND coalesce(e2 ->> 'origineQuete', '') = '' END), false) AS v_trouve_ligne
            FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)) z;
  IF NOT coalesce(v_trouve, false) THEN
    v_inv := v_inv || jsonb_build_array(CASE WHEN p_calomnieux
      THEN jsonb_build_object('type', 'tract_calomnieux', 'name', 'Tracts calomnieux contre ' || p_cible, 'icon', 'ti-alert-triangle',
                              'cible', p_cible, 'quantite', v_qte, 'legal', false)
      ELSE jsonb_build_object('type', 'tract', 'name', 'Tracts ' || CASE WHEN v_sens = 'contre' THEN 'CONTRE ' ELSE 'POUR ' END || p_cible,
                              'icon', 'ti-file-description', 'tractType', v_sens, 'cible', p_cible, 'quantite', v_qte, 'legal', true) END);
  END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  IF p_calomnieux THEN v_repere := public.crime_detecter_interne(v_moi, 'imprimer_tracts_calomnieux', true); END IF;
  RETURN v_r || jsonb_build_object('quantite', v_qte, 'repere', v_repere)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'recherche', recherche, 'dis', resources -> 'dis')
          FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

-- tracts_reclamer_don(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_reclamer_don(p_id text, p_destinataire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_resultat jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_destinataire);
  DELETE FROM public.objets_recus
   WHERE id = p_id AND destinataire = p_destinataire
     AND id LIKE 'don-tracts-%'
  RETURNING jsonb_build_object('id', id, 'expediteur', expediteur, 'data', data)
  INTO v_resultat;
  RETURN v_resultat;
END;
$function$;

-- vente_journal_preparer() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.vente_journal_preparer()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE fonds jsonb; proprio text;
BEGIN
 SELECT data INTO fonds FROM public.entreprises WHERE id=NEW.fonds_id;
 proprio:=regexp_replace(coalesce(fonds->>'proprietaire',''),'^pj:','');
 -- Seuls les vrais titulaires PJ au moment de la transaction ont un journal personnel.
 NEW.journal_titulaire:=NULL;NEW.journal_enseigne:=NULL;
 IF proprio IS DISTINCT FROM regexp_replace(coalesce(NEW.vendeur,''),'^pj:','') THEN
  -- Un journal facultatif ne doit JAMAIS annuler une vente ni son paiement.
  -- Aucun titulaire de notification n'est designe si les identites divergent.
  RETURN NEW;
 END IF;
 SELECT id INTO NEW.journal_titulaire FROM public.personnages_donnees WHERE name=proprio;
 IF NEW.journal_titulaire IS NOT NULL THEN NEW.journal_enseigne:=coalesce(nullif(fonds->>'enseigne',''),'Commerce');END IF;
 RETURN NEW;
END $function$;
