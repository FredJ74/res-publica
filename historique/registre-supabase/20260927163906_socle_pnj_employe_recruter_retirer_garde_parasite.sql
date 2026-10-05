-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927163906
-- Nom original      : socle_pnj_employe_recruter_retirer_garde_parasite
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 16:39:06 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ead67492b3f57b17ccff9d2c5eac2d59
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
-- Correctif immediat : une ligne parasite s'etait glissee dans employe_recruter
-- (`IF p_metier IS NOT TRUE IS NULL THEN NULL; END IF;`), vestige d'une frappe. Elle est
-- syntaxiquement acceptee a la CREATION -- PL/pgSQL ne valide les corps qu'a l'EXECUTION -- et
-- aurait leve une erreur de type au premier appel reel. Retiree avant le moindre test.
CREATE OR REPLACE FUNCTION public.employe_recruter(
  p_metier text, p_nom text, p_genre text DEFAULT NULL,
  p_fn text DEFAULT NULL, p_pa integer DEFAULT NULL, p_cost integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  c_max_employes constant integer := 10;
  v_moi text; v_prof record; v_id text; v_nom text; v_pay jsonb;
  v_pa integer; v_cost integer; v_deja integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT (p_metier = ANY (public.employe_metiers_recrutables())) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'metier_non_recrutable',
      'metier', COALESCE(p_metier, '<NULL>'),
      'recrutables', public.employe_metiers_recrutables()); END IF;

  v_nom := btrim(COALESCE(p_nom, ''));
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;

  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = p_metier;
  IF v_prof IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;

  SELECT count(*) INTO v_deja
    FROM public.pnj_membres m WHERE m.famille = 'employe'
     AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_max_employes THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_employes',
      'plafond', c_max_employes); END IF;

  IF p_metier = 'escort' THEN
    IF EXISTS (SELECT 1 FROM public.pnj_membres m
                 JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
                WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif'
                  AND e.job = 'escort' AND e.genre IS NOT DISTINCT FROM p_genre) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier, 'genre', p_genre); END IF;
  ELSE
    IF EXISTS (SELECT 1 FROM public.pnj_membres m
                 JOIN public.pnj_employes_metier e ON e.pnj_id = m.id
                WHERE m.proprietaire_pj = v_moi AND m.statut = 'actif' AND e.job = p_metier) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'quota_metier_atteint',
        'metier', p_metier); END IF;
  END IF;

  v_id := public.employe_pnj_id(v_moi, p_metier, v_nom);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_employe', 'pnj_id', v_id); END IF;

  v_pa   := COALESCE(p_pa,   v_prof.pa_initial,   0);
  v_cost := COALESCE(p_cost, v_prof.cout_initial, 0);
  IF p_fn IS NOT NULL THEN
    v_pay := public.payer_ordre(v_moi, p_fn, v_pa, v_cost);
  ELSIF v_cost > 0 THEN
    v_pay := public.debiter_fonds_ordinaires(v_moi, v_cost);
  ELSE
    v_pay := jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse', 'paiement', v_pay); END IF;

  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      leader_pj, pa, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'employe', 'beta', v_nom,
      (SELECT COALESCE(country, 'republic') FROM public.personnages_donnees WHERE name = v_moi),
      v_moi, v_moi, 12, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
      statut = 'actif', proprietaire_pj = EXCLUDED.proprietaire_pj,
      leader_pj = EXCLUDED.leader_pj, ville = NULL, building_id = NULL, room_id = NULL,
      car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
      car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
      maj_le = now();

  INSERT INTO public.pnj_employes_metier (pnj_id, job, role_libelle, cout_jour, genre, depuis_jour)
  VALUES (v_id, p_metier,
          CASE p_metier WHEN 'escort' THEN 'Escort — Agence Roxane Velours'
                        WHEN 'informateur' THEN 'Informateur' ELSE initcap(p_metier) END,
          v_prof.cout_jour, p_genre, NULL)
  ON CONFLICT (pnj_id) DO UPDATE SET
      job = EXCLUDED.job, role_libelle = EXCLUDED.role_libelle,
      cout_jour = EXCLUDED.cout_jour, genre = EXCLUDED.genre;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id, 'metier', p_metier, 'nom', v_nom,
    'genre', p_genre, 'cout_jour', v_prof.cout_jour, 'cout_initial', v_cost, 'pa', v_pa,
    'caracteristiques', public.pnj_metier_profil(p_metier),
    'paiement', v_pay, 'employes', v_deja + 1, 'plafond', c_max_employes);
END; $$;