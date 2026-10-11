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
