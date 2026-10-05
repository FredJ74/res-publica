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
  UPDATE public.personnages
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

-- calomnie_distribuer(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.calomnie_distribuer(p_requete text, p_joueur text, p_cible text, p_pnj_nom text, p_vol_pnj integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  RETURN public.calomnie_distribuer_interne(p_requete, p_joueur, p_cible, p_pnj_nom, p_vol_pnj, now());
END;
$function$;

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
  UPDATE public.personnages
     SET recherche = CASE WHEN jsonb_typeof(recherche) = 'array' THEN recherche ELSE '[]'::jsonb END || v_entree
   WHERE name = p_auteur;
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

-- tracts_donner_joueur(text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.tracts_donner_joueur(p_requete text, p_expediteur text, p_destinataire text, p_objet jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_existant record;
  v_qte      integer;
BEGIN
  PERFORM public.exiger_acteur(p_expediteur);
  IF p_requete IS NULL OR p_requete !~ '^don-tracts-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF jsonb_typeof(p_objet) <> 'object' OR COALESCE(p_objet ->> 'type', '') NOT IN ('tract', 'tract_calomnieux')
     OR COALESCE(btrim(p_objet ->> 'cible'), '') = '' OR jsonb_typeof(p_objet -> 'quantite') <> 'number' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide');
  END IF;
  v_qte := (p_objet ->> 'quantite')::integer;
  IF v_qte < 1 OR v_qte > 1000 OR v_qte::numeric <> (p_objet ->> 'quantite')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_expediteur IS NULL OR p_destinataire IS NULL OR p_expediteur = p_destinataire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages WHERE name = p_expediteur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'expediteur_introuvable');
  END IF;
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (p_requete, p_destinataire, p_expediteur, to_jsonb(p_objet::text))
  ON CONFLICT (id) DO NOTHING;
  IF NOT FOUND THEN
    SELECT destinataire, expediteur INTO v_existant FROM public.objets_recus WHERE id = p_requete;
    IF FOUND AND (v_existant.destinataire <> p_destinataire OR v_existant.expediteur <> p_expediteur) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'requete_deja_utilisee');
    END IF;
    RETURN jsonb_build_object('ok', true, 'id', p_requete, 'rejeu', true);
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', p_requete, 'rejeu', false);
END;
$function$;

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
  v_inv     jsonb;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_electoral');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_sens NOT IN ('pour', 'contre') OR COALESCE(btrim(p_candidat), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;
  v_sens := CASE WHEN p_sens = 'pour' THEN 1 ELSE -1 END;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p FROM public.personnages WHERE name = p_joueur;
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
     OR COALESCE(v_d ->> 'phase', '') = 'mandat'
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

  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(p_vol_pnj, 10))));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'consomme', 1, 'pa', 1, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens));
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
    'ok', true, 'reussi', true, 'consomme', 1, 'pa', 1, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens,
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
