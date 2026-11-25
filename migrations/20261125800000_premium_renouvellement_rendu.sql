-- Mission de fin de soirée du 25/11/2026 (Claude), point 1.3 — NON APPLIQUÉE. Après 20261125700000 (premium, appliquée).
-- Décision de Fred : un renouvellement d'image est décompté AVANT la génération ; si la génération échoue (générateur
-- d'images en panne, image refusée, enregistrement impossible), il est RENDU : aucune perte pour le joueur.
-- • premium_renouvellement_rendre_service(p_user, p_type, p_objet) : réservée au serveur (les ateliers de décoration,
--   supabase/edge-functions/commerce-decoration et logement-decoration). Elle annule le dernier décompte de ce compte pour
--   ce visuel, posé il y a moins de 15 minutes : la ligne de premium_renouvellements disparaît (le renouvellement inclus de
--   la semaine redevient libre pour l'abonné) et, si une unité achetée avait été consommée, elle redevient utilisable.
--   Idempotente : un second appel ne trouve plus rien et répond « rien_a_rendre ».
-- Sans cette migration, les ateliers appellent une RPC absente : l'erreur est ignorée (comportement d'aujourd'hui).
--
-- Contrôles en lecture après application :
--   SELECT has_function_privilege('service_role', 'public.premium_renouvellement_rendre_service(uuid,text,text)', 'EXECUTE');    -- vrai
--   SELECT has_function_privilege('authenticated', 'public.premium_renouvellement_rendre_service(uuid,text,text)', 'EXECUTE');  -- faux
--   SELECT position('premium_rendu_v1' in pg_get_functiondef('public.premium_renouvellement_rendre_service(uuid,text,text)'::regprocedure)) > 0;  -- vrai
BEGIN;

CREATE OR REPLACE FUNCTION public.premium_renouvellement_rendre_service(p_user uuid, p_type text, p_objet text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.premium_renouvellements; v_droit bigint;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  IF p_user IS NULL OR coalesce(p_type, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  SELECT * INTO r FROM public.premium_renouvellements
   WHERE user_id = p_user AND type_visuel = p_type AND objet IS NOT DISTINCT FROM p_objet AND cree_le > now() - interval '15 minutes'
   ORDER BY cree_le DESC, id DESC LIMIT 1 FOR UPDATE;
  IF r.id IS NULL THEN RETURN jsonb_build_object('ok', true, 'rendu', false, 'raison', 'rien_a_rendre'); END IF;
  DELETE FROM public.premium_renouvellements WHERE id = r.id;
  IF r.source = 'unite' THEN
    -- L'unité consommée pour ce visuel (cible « type:objet », posée par premium_unite_utiliser_interne) redevient utilisable.
    SELECT id INTO v_droit FROM public.premium_droits
     WHERE user_id = p_user AND produit = 'renouvellement_image' AND revoque_le IS NULL AND consomme_le IS NOT NULL
       AND cible = p_type || ':' || coalesce(p_objet, '')
     ORDER BY consomme_le DESC LIMIT 1 FOR UPDATE;
    IF v_droit IS NOT NULL THEN UPDATE public.premium_droits SET consomme_le = NULL, cible = NULL WHERE id = v_droit; END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'rendu', true, 'source', r.source); /* premium_rendu_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.premium_renouvellement_rendre_service(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.premium_renouvellement_rendre_service(uuid, text, text) TO service_role;

COMMIT;
