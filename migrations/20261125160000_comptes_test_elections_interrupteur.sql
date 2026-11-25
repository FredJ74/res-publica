-- Mission de jour du 25/11/2026 (Claude), bloc 1.3 — APPLIQUÉE en production le 25/11/2026 au soir (feu vert de Fred, contrôlée en lecture). Après 20261124100000.
-- Décision de Fred (A.1) : seuls Arnie, Tom Tom et Bernard Bernardov sont des comptes de test (relevé en lecture le 25/11 :
-- ce sont bien les trois seules lignes de comptes_test ; aucun autre compte n'est marqué, cette migration n'en marque aucun).
-- Interrupteur de MJ qui RÉINTÈGRE les comptes de test dans le dépouillement des élections le temps d'un test ; par défaut,
-- ils restent exclus. L'interrupteur s'éteint de lui-même à l'heure choisie par le MJ (48 h par défaut), pour qu'un test
-- oublié ne fausse jamais une vraie élection.
-- • comptes_test_parametres (cle 'elections_inclure_jusqu_au') ; admin_comptes_test_elections_fixer(p_actif, p_heures) ;
--   admin_comptes_test_lire renvoie aussi l'état de l'interrupteur.
-- • comptes_test_noms_elections() : la liste à exclure du dépouillement (vide tant que l'interrupteur est allumé). Le
--   traitement de nuit (api/cron-minuit.js) l'appelle ; sans cette migration il retombe sur comptes_test_noms (exclusion).
-- Le tirage au sort des candidatures et le PNJ guide gardent l'exclusion (est_compte_test inchangée).
--
-- Contrôles en lecture après application :
--   SELECT personnage FROM public.comptes_test ORDER BY 1;                        -- Arnie, Bernard Bernardov, Tom Tom
--   SELECT public.comptes_test_noms_elections() = public.comptes_test_noms();     -- vrai (interrupteur éteint)
--   SELECT has_function_privilege('authenticated', 'public.comptes_test_noms_elections()', 'EXECUTE');            -- faux
--   SELECT has_function_privilege('service_role', 'public.comptes_test_noms_elections()', 'EXECUTE');             -- vrai
BEGIN;

CREATE TABLE IF NOT EXISTS public.comptes_test_parametres (
  cle text PRIMARY KEY,
  valeur timestamptz,
  maj_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.comptes_test_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.comptes_test_parametres FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.comptes_test_parametres TO service_role;
INSERT INTO public.comptes_test_parametres (cle, valeur) VALUES ('elections_inclure_jusqu_au', NULL) ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.comptes_test_elections_inclus_interne()
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT valeur > now() FROM public.comptes_test_parametres WHERE cle = 'elections_inclure_jusqu_au'), false)
$function$;

-- Ce que le dépouillement doit ignorer : les comptes de test, sauf pendant un test du MJ.
CREATE OR REPLACE FUNCTION public.comptes_test_noms_elections()
 RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN public.comptes_test_elections_inclus_interne() THEN '{}'::text[] ELSE public.comptes_test_noms() END /* comptes_test_elections_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.admin_comptes_test_elections_fixer(p_actif boolean, p_heures integer DEFAULT 48)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jusqu timestamptz;
BEGIN
  PERFORM public.admin_exiger();
  IF p_actif THEN
    IF p_heures IS NULL OR p_heures < 1 OR p_heures > 720 THEN RETURN jsonb_build_object('ok', false, 'raison', 'duree_invalide'); END IF;
    v_jusqu := now() + make_interval(hours => p_heures);
  END IF;
  INSERT INTO public.comptes_test_parametres (cle, valeur, maj_le) VALUES ('elections_inclure_jusqu_au', v_jusqu, now())
  ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur, maj_le = now();
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'comptes_test_elections', jsonb_build_object('actif', p_actif, 'heures', p_heures),
          jsonb_build_object('jusqu_au', v_jusqu), true);
  RETURN jsonb_build_object('ok', true, 'inclus', public.comptes_test_elections_inclus_interne(), 'jusqu_au', v_jusqu); /* comptes_test_elections_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.admin_comptes_test_lire()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true, 'comptes', (SELECT coalesce(jsonb_agg(jsonb_build_object('personnage', personnage,
    'motif', motif, 'ajoute_le', ajoute_le) ORDER BY personnage), '[]'::jsonb) FROM public.comptes_test),
    'personnages', to_jsonb(public.comptes_test_noms()),
    'elections_inclus', public.comptes_test_elections_inclus_interne(),
    'elections_inclus_jusqu_au', (SELECT valeur FROM public.comptes_test_parametres WHERE cle = 'elections_inclure_jusqu_au' AND valeur > now())); /* comptes_test_v1 */ /* comptes_test_elections_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.comptes_test_elections_inclus_interne(), public.comptes_test_noms_elections() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.comptes_test_noms_elections() TO service_role;
REVOKE ALL ON FUNCTION public.admin_comptes_test_elections_fixer(boolean, integer), public.admin_comptes_test_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_comptes_test_elections_fixer(boolean, integer), public.admin_comptes_test_lire() TO authenticated, service_role;

COMMIT;
