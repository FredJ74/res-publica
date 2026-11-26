-- Décisions du 26/11/2026 (Claude), bloc B — APPLIQUÉE en production le 26/11/2026 (feu vert de Fred, contrôlée en lecture). Après 20261125860000.
-- REVENU UNIVERSEL (décision n° 7 de Fred, 26/11/2026) : Sovarka en reçoit un, 45 PSK par jour (Républia : 150 FR). Dans les
-- deux empires, il n'est versé que pendant les 10 PREMIERS JOURS d'un personnage, pour l'aider à démarrer. Montants et
-- durée réglables dans la page MJ.
-- • salaires_civils_declares : ligne « default » (catégorie universel) de Sovarka, 45 ; celle de Républia (150) inchangée.
-- • revenu_universel_parametres (jours = 10) ; revenu_universel_ouvert_interne(nom) : vrai tant que le personnage a moins de
--   « jours » jours (dates de Paris : le jour de création compte pour le premier).
-- • salaire_civil_percevoir : le revenu universel (et lui seul : salaires de poste et emplois du Bureau inchangés) est refusé
--   au-delà, motif « revenu_universel_termine » (remplacement contrôlé, marque revenu_universel_v1).
-- • Page MJ : admin_revenu_universel_lire / admin_revenu_universel_fixer (jours 0 à 365, montants 1 à 100 000).
-- Sans cette migration : comportement actuel (Républia 150 FR chaque jour sans limite, rien en Sovarka).
--
-- Contrôles en lecture après application :
--   SELECT pays, montant FROM public.salaires_civils_declares WHERE cle = 'default' ORDER BY pays;                     -- republic 150, soviet 45
--   SELECT valeur FROM public.revenu_universel_parametres WHERE cle = 'jours';                                         -- 10
--   SELECT position('revenu_universel_v1' in pg_get_functiondef('public.salaire_civil_percevoir()'::regprocedure)) > 0;  -- vrai
--   SELECT has_function_privilege('authenticated', 'public.admin_revenu_universel_fixer(text,integer)', 'EXECUTE');   -- vrai (admin_exiger filtre)
--   SELECT has_function_privilege('authenticated', 'public.revenu_universel_ouvert_interne(text)', 'EXECUTE');        -- faux
BEGIN;

INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) SELECT 'default', 'universel', 45, 'soviet'
 WHERE NOT EXISTS (SELECT 1 FROM public.salaires_civils_declares WHERE cle = 'default' AND pays = 'soviet');

CREATE TABLE IF NOT EXISTS public.revenu_universel_parametres (cle text PRIMARY KEY, valeur integer NOT NULL, maj_le timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.revenu_universel_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.revenu_universel_parametres FROM PUBLIC, anon, authenticated;
INSERT INTO public.revenu_universel_parametres (cle, valeur) VALUES ('jours', 10) ON CONFLICT (cle) DO NOTHING;

-- Le personnage est-il encore dans ses premiers jours ? (création = premier jour, dates de Paris)
CREATE OR REPLACE FUNCTION public.revenu_universel_ouvert_interne(p_nom text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT (now() AT TIME ZONE 'Europe/Paris')::date
                          - ((d.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Paris')::date
                          < coalesce((SELECT valeur FROM public.revenu_universel_parametres WHERE cle = 'jours'), 10)
                     FROM public.personnages_donnees d WHERE d.name = p_nom AND d.created_at IS NOT NULL), true) /* revenu_universel_v1 */
$function$;
REVOKE ALL ON FUNCTION public.revenu_universel_ouvert_interne(text) FROM PUBLIC, anon, authenticated;

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

SELECT pg_temp.rp_remplacer('public.salaire_civil_percevoir()'::regprocedure,
  $a$  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;$a$,
  $b$  -- Revenu universel (décision de Fred, 26/11) : seulement pendant les premiers jours du personnage. /* revenu_universel_v1 */
  IF v_origine = 'universel' AND NOT public.revenu_universel_ouvert_interne(v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'revenu_universel_termine', 'pays', v_pays,
      'jours', coalesce((SELECT valeur FROM public.revenu_universel_parametres WHERE cle = 'jours'), 10));
  END IF;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;$b$,
  1, 'revenu_universel_v1');

-- Page MJ.
CREATE OR REPLACE FUNCTION public.admin_revenu_universel_lire()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true,
    'jours', coalesce((SELECT valeur FROM public.revenu_universel_parametres WHERE cle = 'jours'), 10),
    'montants', (SELECT coalesce(jsonb_object_agg(pays, montant), '{}'::jsonb) FROM public.salaires_civils_declares WHERE cle = 'default'));
END $function$;

CREATE OR REPLACE FUNCTION public.admin_revenu_universel_fixer(p_cle text, p_valeur integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  IF p_cle = 'jours' THEN
    IF p_valeur IS NULL OR p_valeur NOT BETWEEN 0 AND 365 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
    INSERT INTO public.revenu_universel_parametres (cle, valeur, maj_le) VALUES ('jours', p_valeur, now())
    ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur, maj_le = now();
  ELSIF p_cle IN ('republic', 'soviet') THEN
    IF p_valeur IS NULL OR p_valeur NOT BETWEEN 1 AND 100000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
    UPDATE public.salaires_civils_declares SET montant = p_valeur WHERE cle = 'default' AND pays = p_cle;
    IF NOT FOUND THEN INSERT INTO public.salaires_civils_declares (cle, categorie, montant, pays) VALUES ('default', 'universel', p_valeur, p_cle); END IF;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'reglage_inconnu');
  END IF;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'revenu_universel', jsonb_build_object('cle', p_cle, 'valeur', p_valeur), '{}'::jsonb, true);
  RETURN jsonb_build_object('ok', true); /* revenu_universel_v1 */
END $function$;
REVOKE ALL ON FUNCTION public.admin_revenu_universel_lire(), public.admin_revenu_universel_fixer(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revenu_universel_lire(), public.admin_revenu_universel_fixer(text, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
