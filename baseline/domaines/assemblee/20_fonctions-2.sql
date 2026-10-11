-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine assemblee -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- assemblee_suspension_depassee(text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_suspension_depassee(p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- now() ET NON clock_timestamp() : une lecture doit rendre UN instant pour toute la requete.
  -- clock_timestamp() est reserve, dans ce projet, aux horodatages d'ORDRE ecrits en base.
  SELECT EXISTS (
    SELECT 1 FROM public.assemblee_suspensions
     WHERE pays = p_pays AND cause = 'presidence' AND close_le IS NULL
       AND (now() - ouverte_le) > public.assemblee_suspension_seuil());
$function$;

-- assemblee_suspension_seuil() -> interval | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_suspension_seuil()
 RETURNS interval
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT interval '1 hour' $function$;

-- assemblee_taux_marchandage(jsonb,boolean) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_taux_marchandage(p_stats jsonb, p_bonus_lobbyiste boolean)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT GREATEST(0, LEAST(66, round(50 + (public.assemblee_stat_base(p_stats, 'CHA')
                                           + public.assemblee_stat_base(p_stats, 'ENT')) / 2)::integer))
         + CASE WHEN p_bonus_lobbyiste THEN 20 ELSE 0 END;
$function$;

-- assemblee_taux_neutralisation(text,jsonb,text) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_taux_neutralisation(p_mode text, p_stats jsonb, p_career text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT GREATEST(0, LEAST(m.cap, round(m.base
           + public.assemblee_stat_base(p_stats, m.stat) * 2
           + CASE WHEN p_career = 'criminal_c' THEN 15 ELSE 0 END
           - 6 / 2.0)::integer))
    FROM (VALUES ('mains', 'FOR', 15, 65), ('arme', 'DUP', 25, 75), ('feu', 'PER', 35, 85))
         AS m(mode, stat, base, cap)
   WHERE m.mode = p_mode;
$function$;

-- assemblee_tracer_vente_interdite(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_tracer_vente_interdite(p_commerce_id text, p_categorie text, p_libelle text, p_country text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_vendeur text;
  v_loi     jsonb;
  v_det     jsonb;
BEGIN
  SELECT NULLIF(e.data ->> 'proprietaire', 'PNJ') INTO v_vendeur FROM public.entreprises e WHERE e.id = p_commerce_id;
  IF v_vendeur IS NULL OR btrim(v_vendeur) = '' THEN
    RETURN jsonb_build_object('ok', true, 'vendeur', null, 'raison', 'commerce_pnj_ou_introuvable');
  END IF;

  SELECT jsonb_build_object('id', p.id, 'titre', p.titre, 'categorie', p.categorie, 'adoptee_ts', p.adoptee_ts)
    INTO v_loi
    FROM public.assemblee_propositions p
   WHERE p.country = p_country AND p.type = 'mecanique' AND p.statut = 'adoptee'
     AND p.categorie = p_categorie AND p.adoptee_ts IS NOT NULL AND p.adoptee_ts <= now()
   ORDER BY p.adoptee_ts, p.id LIMIT 1;
  IF v_loi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_non_interdite');
  END IF;

  v_det := public.assemblee_detecter_partie(v_vendeur, 'vente', v_loi, COALESCE(p_libelle, p_categorie), 1, false);
  IF v_det IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'vendeur', null, 'raison', 'vendeur_introuvable');
  END IF;

  RETURN jsonb_build_object('ok', true, 'detecte', v_det -> 'detecte',
    'convocation_creee', v_det -> 'convocation_creee', 'loi', v_loi ->> 'titre');
END;
$function$;

-- assemblee_transaction_interdite_interne(text,text,text,jsonb,text,integer) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_transaction_interdite_interne(p_country text, p_acheteur text, p_vendeur text, p_objet jsonb, p_libelle text, p_quantite integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_loi     jsonb;
  v_vendeur text;
  v_a       jsonb := NULL;
  v_v       jsonb := NULL;
BEGIN
  v_loi := public.assemblee_loi_en_vigueur(p_country, p_objet, now());
  IF v_loi IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'interdit', false);
  END IF;

  v_vendeur := NULLIF(NULLIF(btrim(COALESCE(p_vendeur, '')), ''), 'PNJ');
  IF v_vendeur IS NOT DISTINCT FROM p_acheteur THEN v_vendeur := NULL; END IF;

  PERFORM 1 FROM public.personnages
   WHERE name IN (p_acheteur, v_vendeur) ORDER BY name FOR UPDATE;

  IF p_acheteur IS NOT NULL THEN
    v_a := public.assemblee_detecter_partie(p_acheteur, 'achat', v_loi, p_libelle, p_quantite, true);
  END IF;
  IF v_vendeur IS NOT NULL THEN
    v_v := public.assemblee_detecter_partie(v_vendeur, 'vente', v_loi, p_libelle, p_quantite, false);
  END IF;

  RETURN jsonb_build_object('ok', true, 'interdit', true, 'loi', v_loi, 'acheteur', v_a, 'vendeur', v_v);
END;
$function$;

-- assemblee_verifier_vente(jsonb,text) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_verifier_vente(p_objets jsonb, p_country text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH o AS (
    SELECT (t.ord - 1)::integer AS idx,
           public.assemblee_loi_en_vigueur(p_country, t.val, now()) AS loi
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_objets) = 'array' THEN p_objets ELSE '[]'::jsonb END)
           WITH ORDINALITY AS t(val, ord)
  )
  SELECT CASE WHEN jsonb_typeof(p_objets) IS DISTINCT FROM 'array'
    THEN jsonb_build_object('ok', false, 'instant', now(), 'raison', 'objets_invalides', 'interdits', '[]'::jsonb)
    ELSE jsonb_build_object(
           'ok', NOT EXISTS (SELECT 1 FROM o WHERE loi IS NOT NULL),
           'instant', now(),
           'interdits', COALESCE((SELECT jsonb_agg(jsonb_build_object('index', idx, 'loi', loi) ORDER BY idx)
                                    FROM o WHERE loi IS NOT NULL), '[]'::jsonb))
  END;
$function$;

-- assemblee_verser_indemnite(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_verser_indemnite(p_nom text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_montant CONSTANT integer := 250;
  v_perso   public.personnages%ROWTYPE;
  v_jour    date;
  v_id      text;
  v_verse   integer := 0;
  v_credit  jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_nom);
  SELECT * INTO v_perso FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable', 'montant', 0);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := p_nom || ':' || v_jour::text;

  IF NOT EXISTS (
    SELECT 1 FROM public.assemblee_occupation_sieges(v_perso.country) o WHERE o.pj_nom = p_nom
  ) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute', 'montant', 0);
  END IF;

  BEGIN
    INSERT INTO public.assemblee_indemnites (id, personnage, jour, montant)
    VALUES (v_id, p_nom, v_jour, 0);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_verse_aujourdhui', 'montant', 0);
  END;

  v_verse := public.assemblee_debiter_caisse_plafonne(v_perso.country || '_assemblee', c_montant);
  UPDATE public.assemblee_indemnites SET montant = v_verse WHERE id = v_id;

  v_credit := public.assemblee_crediter_joueur(p_nom, v_verse);

  RETURN v_credit || jsonb_build_object('ok', true, 'montant', v_verse, 'vise', c_montant);
END;
$function$;

-- assemblee_voter(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.assemblee_voter(p_id text, p_votant text, p_choix text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row   public.assemblee_propositions%ROWTYPE;
  v_perso public.personnages%ROWTYPE;
  v_city  text;
BEGIN
  PERFORM public.exiger_acteur(p_votant);
  IF p_choix IS NULL OR p_choix NOT IN ('POUR', 'CONTRE', 'ABSTENTION') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide');
  END IF;

  -- FOR SHARE : un vote ne chevauche jamais le depouillement (qui prend FOR UPDATE).
  SELECT * INTO v_row FROM public.assemblee_propositions WHERE id = p_id FOR SHARE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF v_row.statut <> 'session' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_session');
  END IF;
  IF v_row.cloture_ts IS NULL OR now() >= v_row.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos');
  END IF;

  SELECT * INTO v_perso FROM public.personnages WHERE name = p_votant;
  IF NOT FOUND OR NOT (v_perso.country = v_row.country AND v_perso.current_building = 'assemblee'
                       AND v_perso.current_room = 'hemicycle') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_lieu');
  END IF;

  -- Le votant doit occuper reellement l'un des neuf sieges MAINTENANT.
  SELECT o.city INTO v_city
    FROM public.assemblee_occupation_sieges(v_row.country) o
   WHERE o.pj_nom = p_votant
   LIMIT 1;
  IF v_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute');
  END IF;

  INSERT INTO public.assemblee_votes (id, proposition_id, session_num, votant, city, choix)
  VALUES (p_id || ':' || v_row.session_num || ':' || p_votant, p_id, v_row.session_num, p_votant, v_city, p_choix)
  ON CONFLICT (id) DO UPDATE SET choix = EXCLUDED.choix, updated_at = now();

  RETURN jsonb_build_object('ok', true, 'choix', p_choix);
END;
$function$;

-- depute_presence(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.depute_presence(p_country text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('ok', true, 'pays', p_country,
    'sieges', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'siege_id', o.siege_id, 'ville', o.city, 'rang', o.rang,
        -- IDENTITE GAMMA, conservee en toute circonstance.
        'pnj_id', o.pnj_id, 'pnj_nom', o.pnj_nom, 'fonction', 'depute', 'classe', 'gamma',
        -- PRESENCE : 1 present, 0 absent. Derivee, jamais stockee.
        'present', CASE WHEN o.est_pnj THEN 1 ELSE 0 END,
        'occupe_par_pj', o.pj_nom,
        -- L'endormissement est une entrave METIER, distincte de l'absence : un depute endormi est
        -- PRESENT mais empeche de voter. Il ne disparait pas.
        'endormi', COALESCE(o.endormi, false))
      ORDER BY o.city, o.rang)
      FROM public.assemblee_occupation_sieges(p_country) o), '[]'::jsonb),
    'presents', (SELECT count(*) FROM public.assemblee_occupation_sieges(p_country) o WHERE o.est_pnj),
    'absents',  (SELECT count(*) FROM public.assemblee_occupation_sieges(p_country) o
                  WHERE NOT o.est_pnj));
$function$;
