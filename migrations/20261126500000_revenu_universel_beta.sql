-- Décision de Fred du 26/11/2026 (21 h 29) — APPLIQUÉE en production le 26/11/2026 (feu vert de Fred, contrôlée en lecture : 20261219, vrai, vrai). Après 20261126100000 (revenu universel).
-- REVENU UNIVERSEL PENDANT LA BÊTA : « Rends-le à tous les testeurs ». La limite des 10 premiers jours d'un personnage ne
-- s'applique qu'à partir du LANCEMENT (19/12/2026, date de Paris) ; avant, tout personnage le touche, dans les deux empires.
-- • revenu_universel_parametres : nouvelle clé « limite_a_partir » (date AAAAMMJJ, 20261219).
-- • revenu_universel_ouvert_interne(nom) : vrai avant cette date ; ensuite, règle des « jours » premiers jours, inchangée.
--   Marque revenu_universel_beta_v1 (remplace revenu_universel_v1 dans cette seule fonction).
-- Sans cette migration : comportement actuel (limite de 10 jours dès maintenant).
--
-- Contrôles en lecture après application :
--   SELECT valeur FROM public.revenu_universel_parametres WHERE cle = 'limite_a_partir';                                -- 20261219
--   SELECT position('revenu_universel_beta_v1' in pg_get_functiondef('public.revenu_universel_ouvert_interne(text)'::regprocedure)) > 0;  -- vrai
--   SELECT bool_and(public.revenu_universel_ouvert_interne(name)) FROM public.personnages_donnees;                     -- vrai (avant le 19/12)
BEGIN;

INSERT INTO public.revenu_universel_parametres (cle, valeur) VALUES ('limite_a_partir', 20261219) ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.revenu_universel_ouvert_interne(p_nom text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Bêta (décision de Fred, 26/11) : avant la date de lancement, tout personnage touche le revenu universel.
  SELECT (now() AT TIME ZONE 'Europe/Paris')::date
           < coalesce(to_date((SELECT valeur FROM public.revenu_universel_parametres WHERE cle = 'limite_a_partir')::text, 'YYYYMMDD'),
                      DATE '2026-12-19')
      OR coalesce((SELECT (now() AT TIME ZONE 'Europe/Paris')::date
                          - ((d.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Paris')::date
                          < coalesce((SELECT valeur FROM public.revenu_universel_parametres WHERE cle = 'jours'), 10)
                     FROM public.personnages_donnees d WHERE d.name = p_nom AND d.created_at IS NOT NULL), true) /* revenu_universel_beta_v1 */
$function$;
REVOKE ALL ON FUNCTION public.revenu_universel_ouvert_interne(text) FROM PUBLIC, anon, authenticated;

COMMIT;
