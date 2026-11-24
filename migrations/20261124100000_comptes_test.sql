-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture, mission Purge).
-- Purge, bloc A, point A.1 (Fred, 24/11/2026) : comptes de test de Fred marqués en base, puis exclus des statistiques,
-- des élections et des tirages au sort. NON APPLIQUÉE : l'agent principal l'applique à la fusion.
-- Rejouable (IF NOT EXISTS, ON CONFLICT, remplacement contrôlé à marque). Rien du goulag. Aucune donnée de joueur modifiée.
--
--  • comptes_test (personnage, user_id) : la marque. Un compte est « de test » si son NOM y figure OU si son COMPTE
--    (user_id) y figure : un reroll sur le même compte reste donc un compte de test.
--  • est_compte_test(nom) : la seule question à poser (serveur). comptes_test_noms() : la liste des personnages marqués,
--    pour le cron (service seulement).
--  • Comptes retenus (relevé en lecture du 24/11, docs/purge/BLOC-A.md) : Arnie et Tom Tom (même adresse de compte,
--    personnages de Fred cités dans GAME-DESIGN-INTERVIEW-ACCUEIL-20261121.md et GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md),
--    Bernard Bernardov (compte du domaine du jeu, « personnage de test Bernard » de la consigne). Aucun autre n'est marqué
--    sans confirmation de Fred.
--  • Tirage au sort : candidature_poste_tirage_appliquer ne tire plus jamais un compte de test (marque comptes_test_tirage_v1).
--    Élections : le dépouillement du cron (api/cron-minuit.js) ignore les bulletins et les candidatures des comptes de test.
--    Tirage du commerce cité par le PNJ guide (A.10) : exclut les commerces des comptes de test.
--  • MJ : admin_comptes_test_lire() / admin_compte_test_fixer(nom, marque) (journalisé dans admin_journal).

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.comptes_test (
  personnage text PRIMARY KEY,
  user_id uuid,
  motif text NOT NULL DEFAULT '',
  ajoute_le timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS comptes_test_user_idx ON public.comptes_test (user_id);
ALTER TABLE public.comptes_test ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.comptes_test FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.comptes_test TO service_role;

-- Les trois comptes retenus (le user_id est relu sur la fiche : un compte absent est marqué par son nom seul).
INSERT INTO public.comptes_test (personnage, user_id, motif)
SELECT v.nom, (SELECT d.user_id FROM public.personnages_donnees d WHERE d.name = v.nom), v.motif
  FROM (VALUES ('Arnie', 'Personnage de Fred (consignes du 21 et du 22/11/2026)'),
               ('Tom Tom', 'Personnage de Fred (consigne du 21/11/2026), même compte qu''Arnie'),
               ('Bernard Bernardov', 'Personnage de test « Bernard » (consigne du 24/11/2026), compte du domaine du jeu')) v(nom, motif)
ON CONFLICT (personnage) DO UPDATE SET user_id = coalesce(public.comptes_test.user_id, EXCLUDED.user_id);

CREATE OR REPLACE FUNCTION public.est_compte_test(p_nom text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_nom IS NOT NULL AND (
         EXISTS (SELECT 1 FROM public.comptes_test t WHERE t.personnage = p_nom)
      OR EXISTS (SELECT 1 FROM public.comptes_test t JOIN public.personnages_donnees d ON d.user_id = t.user_id
                  WHERE d.name = p_nom AND t.user_id IS NOT NULL)) /* comptes_test_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.comptes_test_noms()
 RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(array_agg(DISTINCT n ORDER BY n), '{}'::text[]) FROM (
    SELECT personnage n FROM public.comptes_test
    UNION SELECT d.name FROM public.personnages_donnees d JOIN public.comptes_test t ON t.user_id = d.user_id WHERE t.user_id IS NOT NULL
  ) x /* comptes_test_v1 */
$function$;

CREATE OR REPLACE FUNCTION public.admin_comptes_test_lire()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true, 'comptes', (SELECT coalesce(jsonb_agg(jsonb_build_object('personnage', personnage,
    'motif', motif, 'ajoute_le', ajoute_le) ORDER BY personnage), '[]'::jsonb) FROM public.comptes_test),
    'personnages', to_jsonb(public.comptes_test_noms())); /* comptes_test_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.admin_compte_test_fixer(p_nom text, p_marque boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid;
BEGIN
  PERFORM public.admin_exiger();
  IF coalesce(btrim(p_nom), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_requis'); END IF;
  IF p_marque THEN
    SELECT user_id INTO v_uid FROM public.personnages_donnees WHERE name = p_nom;
    INSERT INTO public.comptes_test (personnage, user_id, motif) VALUES (p_nom, v_uid, 'Marqué par un MJ')
    ON CONFLICT (personnage) DO NOTHING;
  ELSE
    DELETE FROM public.comptes_test WHERE personnage = p_nom;
  END IF;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'compte_test_fixer', jsonb_build_object('nom', p_nom, 'marque', p_marque), '{}'::jsonb, true);
  RETURN jsonb_build_object('ok', true, 'nom', p_nom, 'marque', public.est_compte_test(p_nom)); /* comptes_test_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.est_compte_test(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.comptes_test_noms() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.est_compte_test(text), public.comptes_test_noms() TO service_role;
REVOKE ALL ON FUNCTION public.admin_comptes_test_lire() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_compte_test_fixer(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_comptes_test_lire(), public.admin_compte_test_fixer(text, boolean) TO authenticated, service_role;

-- Tirage au sort d'une candidature non tranchée : jamais un compte de test (texte de production du 24/11/2026).
DO $do$
BEGIN
  IF to_regprocedure('public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text)') IS NOT NULL THEN
    PERFORM pg_temp.rp_remplacer('public.candidature_poste_tirage_appliquer(text,text,text,text,text[],text)'::regprocedure,
      $a$   WHERE d.name = ANY (p_candidats) AND d.country = v_pays ORDER BY random() LIMIT 1;$a$,
      $b$   WHERE d.name = ANY (p_candidats) AND d.country = v_pays
     AND NOT public.est_compte_test(d.name) /* comptes_test_tirage_v1 : comptes de test exclus (Fred, 24/11/2026, A.1) */
   ORDER BY random() LIMIT 1;$b$,
      1, 'comptes_test_tirage_v1');
  END IF;
END $do$;
