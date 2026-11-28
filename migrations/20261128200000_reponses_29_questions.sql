-- Réponses de Fred aux 29 questions de la mission du 28/11/2026 (après-midi) — mission du 28/11 (soir), chantier 1.
--   Q1-2 : assignation à résidence inchangée (un « Dormir » pour sortir, même si l'on a déjà dormi ; intouchable).
--   Q3   : Tito Maletas — le vrai secret porte d'abord sur un joueur actif (connecté dans les 7 derniers jours ;
--          clients du standard Roxane Velours en tête), sinon sur n'importe quel joueur réel (jamais un PNJ ni un
--          compte de test).
--   Q4   : détenu transféré — une nuit passée à l'hôpital (ou à la clinique) décompte aussi un jour de peine.
-- Contrôle :
--   SELECT position('tito_joueur_actif_v1' in pg_get_functiondef('public.tito_secret_reseau_interne(text)'::regprocedure)) > 0,
--          position('transfert_peine_hopital_v1' in pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure)) > 0;
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_marque text, p_n integer DEFAULT 1)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente (%)', p_fn, p_marque; END IF;
END $$;

-- ===================================================================== Q3. Tito : joueurs actifs d'abord
-- Activité : dernière connexion (auth) ou dernier chargement du plateau (comptes_activite), comme les comptes inactifs.
CREATE OR REPLACE FUNCTION public.tito_secret_reseau_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_cible text; v_source text; v_secret text; v_actif boolean;
BEGIN
  -- tito_joueur_actif_v1 (Fred, 28/11/2026 soir)
  WITH reels AS (
    SELECT d.name,
           coalesce(greatest(u.last_sign_in_at, ca.vu_le), u.last_sign_in_at, ca.vu_le) > now() - interval '7 days' AS actif,
           d.name IN (SELECT appelant FROM public.escort_appels UNION SELECT client FROM public.escort_relations) AS client
      FROM public.personnages_donnees d
      JOIN auth.users u ON u.id = d.user_id
      LEFT JOIN public.comptes_activite ca ON ca.user_id = d.user_id
     WHERE d.name <> p_acteur AND NOT public.est_compte_test(d.name)
  )
  SELECT name, coalesce(actif, false), CASE WHEN client THEN 'reservation' ELSE 'reseau' END
    INTO v_cible, v_actif, v_source
    FROM reels
   ORDER BY coalesce(actif, false) DESC, client DESC, random()
   LIMIT 1;
  IF v_cible IS NULL THEN RETURN jsonb_build_object('cible', NULL); END IF;
  v_secret := public.hotel_secret_vrai_interne(v_cible);
  PERFORM public.hotel_teaser_apprendre_interne(p_acteur, v_cible, 'confidence', 'secret_tito', v_secret, 'tito');
  RETURN jsonb_build_object('cible', v_cible, 'secret', v_secret, 'source', v_source, 'actif', v_actif);
END $$;
REVOKE ALL ON FUNCTION public.tito_secret_reseau_interne(text) FROM PUBLIC, anon, authenticated;

-- ===================================================================== Q4. Nuit à l'hôpital : un jour de peine
-- Le premier sommeil d'hospitalisation (jour 0) n'est pas une nuit et reste refusé ; dès le jour 1, le « Dormir » à
-- l'hôpital passe par les mêmes suites que le « Dormir » ordinaire (peine au sommeil, assignation, heure du sommeil).
SELECT pg_temp.rp_remplacer('public.pa_repos_nocturne(text)'::regprocedure,
$q$       SET pa = v_nouveau, bonus_pa_differe = 0, pa_repos_le = v_jour
     WHERE name = p_acteur;
    -- Rébellion$q$,
$q$       SET pa = v_nouveau, bonus_pa_differe = 0, pa_repos_le = v_jour
     WHERE name = p_acteur;
    PERFORM public.pa_repos_suites_interne(p_acteur); /* transfert_peine_hopital_v1 */
    -- Rébellion$q$,
'transfert_peine_hopital_v1');

COMMIT;
