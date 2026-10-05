-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920132241
-- Nom original      : club_president_scrutin_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 13:22:41 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 32263347e0ec3f136ccf84500959e302
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- §6.3 — LE SCRUTIN DE LA PRESIDENCE DE CLUB PASSE AU SERVEUR
-- ---------------------------------------------------------------------------
-- Trois portes, et elles seules. Les regles de jeu sont reprises a l'identique ;
-- ce qui change est QUI les applique.

-- 1. DEPOSER SA CANDIDATURE -------------------------------------------------
CREATE OR REPLACE FUNCTION public.club_president_postuler(p_club text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_moi text; c record; v_data jsonb; v_jour integer; v_elect jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_inconnu');
  END IF;
  v_jour := public.jour_de_jeu_pays(c.country);

  SELECT coalesce(data, '{}'::jsonb) INTO v_data
    FROM public.presidents_clubs WHERE id = p_club FOR UPDATE;
  v_data := coalesce(v_data, '{}'::jsonb);

  IF (v_data -> 'candidature') IS NOT NULL AND jsonb_typeof(v_data -> 'candidature') = 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_en_cours');
  END IF;

  -- Protection du president en poste : 8 jours, regle existante.
  IF (v_data ->> 'president') IS NOT NULL
     AND (v_data ->> 'president') <> v_moi
     AND (v_data ->> 'dateElection') IS NOT NULL
     AND (v_jour - (v_data ->> 'dateElection')::int) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_protege',
                              'jours_restants', 8 - (v_jour - (v_data ->> 'dateElection')::int));
  END IF;

  -- LES ELECTEURS SONT RESOLUS ICI, PAR LE SERVEUR. Aucune identite transmise.
  v_elect := public.club_electeurs(p_club);

  v_data := v_data || jsonb_build_object('candidature', jsonb_build_object(
    'candidat',   v_moi,
    'dateDebut',  v_jour,
    'dateLimite', v_jour + 2,
    'votes',      '{}'::jsonb,
    'electeurs',  v_elect));

  INSERT INTO public.presidents_clubs (id, data, updated_at)
  VALUES (p_club, v_data, now())
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = now();

  RETURN jsonb_build_object('ok', true, 'candidat', v_moi,
                            'dateLimite', v_jour + 2, 'electeurs', v_elect);
END;
$$;

-- 2. VOTER -------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.club_president_voter(p_club text, p_vote boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_data jsonb; v_cand jsonb; v_elect jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(data, '{}'::jsonb) INTO v_data
    FROM public.presidents_clubs WHERE id = p_club FOR UPDATE;
  IF v_data IS NULL OR jsonb_typeof(v_data -> 'candidature') <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_candidature');
  END IF;
  v_cand  := v_data -> 'candidature';
  v_elect := v_cand -> 'electeurs';

  -- Seul un des trois electeurs vote. L'instantane est celui du SERVEUR.
  IF v_moi IS DISTINCT FROM (v_elect ->> 'chefSupporters')
     AND v_moi IS DISTINCT FROM (v_elect ->> 'maire')
     AND v_moi IS DISTINCT FROM (v_elect ->> 'capitaine') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_electeur');
  END IF;

  -- Un seul vote par electeur.
  IF (v_cand -> 'votes') ? v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote');
  END IF;

  v_cand := jsonb_set(v_cand, ARRAY['votes', v_moi], to_jsonb(coalesce(p_vote, false)), true);
  UPDATE public.presidents_clubs
     SET data = v_data || jsonb_build_object('candidature', v_cand), updated_at = now()
   WHERE id = p_club;

  RETURN jsonb_build_object('ok', true, 'vote', coalesce(p_vote, false));
END;
$$;

-- 3. DEPOUILLER --------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.club_president_cloturer(p_club text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_data jsonb; v_cand jsonb; v_elect jsonb; v_votes jsonb;
  v_jour integer; c record; v_nom text; v_pour int := 0; v_total int := 0;
  v_valide boolean; v_tous boolean := true;
  v_noms text[];
BEGIN
  SELECT * INTO c FROM public.clubs_sportifs_regles WHERE club_id = p_club;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'club_inconnu');
  END IF;
  v_jour := public.jour_de_jeu_pays(c.country);

  SELECT coalesce(data, '{}'::jsonb) INTO v_data
    FROM public.presidents_clubs WHERE id = p_club FOR UPDATE;
  IF v_data IS NULL OR jsonb_typeof(v_data -> 'candidature') <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_candidature');
  END IF;
  v_cand  := v_data -> 'candidature';
  v_elect := v_cand -> 'electeurs';
  v_votes := coalesce(v_cand -> 'votes', '{}'::jsonb);

  v_noms := ARRAY(SELECT x FROM unnest(ARRAY[
      v_elect ->> 'chefSupporters', v_elect ->> 'maire', v_elect ->> 'capitaine']) x
     WHERE x IS NOT NULL AND btrim(x) <> '');

  FOREACH v_nom IN ARRAY v_noms LOOP
    v_total := v_total + 1;
    IF NOT (v_votes ? v_nom) THEN v_tous := false; END IF;
  END LOOP;

  -- Depouillement des que tous ont vote OU a l'echeance. Pas avant.
  IF NOT v_tous AND v_jour < (v_cand ->> 'dateLimite')::int THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_en_cours',
                              'votes', jsonb_array_length(
                                 coalesce(jsonb_path_query_array(v_votes, '$.keyvalue().key'), '[]'::jsonb)),
                              'attendus', v_total, 'dateLimite', (v_cand ->> 'dateLimite')::int);
  END IF;

  -- SILENCE = ACCORD : les votes manquants comptent pour « oui ».
  FOREACH v_nom IN ARRAY v_noms LOOP
    IF NOT (v_votes ? v_nom) THEN
      v_pour := v_pour + 1;
    ELSIF coalesce((v_votes ->> v_nom)::boolean, false) THEN
      v_pour := v_pour + 1;
    END IF;
  END LOOP;

  v_valide := (v_pour >= 2);

  IF v_valide THEN
    v_data := v_data || jsonb_build_object(
      'president',    v_cand ->> 'candidat',
      'dateElection', v_jour);
  END IF;
  v_data := v_data || jsonb_build_object('candidature', 'null'::jsonb);

  UPDATE public.presidents_clubs SET data = v_data, updated_at = now() WHERE id = p_club;

  RETURN jsonb_build_object('ok', true, 'elu', v_valide,
                            'candidat', v_cand ->> 'candidat',
                            'pour', v_pour, 'electeurs', v_total);
END;
$$;

REVOKE ALL ON FUNCTION public.club_president_postuler(text) FROM public, anon;
REVOKE ALL ON FUNCTION public.club_president_voter(text, boolean) FROM public, anon;
REVOKE ALL ON FUNCTION public.club_president_cloturer(text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.club_president_postuler(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.club_president_voter(text, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.club_president_cloturer(text) TO authenticated, service_role;