-- Mission du 27/11/2026 (après-midi, Claude), étape 3 — APPLIQUÉE en production le 27/11/2026 à 18 h 45 (Claude, choix technique délégué par Fred) ; contrôles en lecture vérifiés.
-- « STAGE À LA CASERNE » PORTÉ PAR LE SERVEUR (audit des ordres du 27/11, docs/audit-ordres-creux-20261127.md : le serveur
-- prélevait les PA, l'écran ajoutait +5 VOL). Relevé en lecture le 27/11 : `stats` est un champ protégé de la vue
-- `personnages` (personnages_vue_modifier) et le suivi `stageCaserne` n'a aucune colonne : le +5 et le repos n'étaient
-- donc pas tenus. Même coût (3 PA, 0), même effet (+5 VOL), même durée (une fois par jour de jeu du personnage ; trois
-- jours consécutifs puis 7 jours de repos ; un jour manqué relance la série à zéro, sans repos).
-- Lieu : Caserne militaire, Corps de Garde (seul lieu de l'ordre dans data.js). Le paiement passe par payer_ordre, qui
-- valide aussi l'étape « ordre » de l'accueil (accueil_ordre_paye_v1).
--
-- Contrôles en lecture après application :
--   SELECT to_regprocedure('public.stage_caserne_effectuer()') IS NOT NULL;                        -- vrai
--   SELECT has_function_privilege('authenticated', 'public.stage_caserne_effectuer()', 'EXECUTE');  -- vrai
--   SELECT count(*) FROM public.stage_caserne_suivi;                                                -- 0 au départ
BEGIN;

CREATE TABLE IF NOT EXISTS public.stage_caserne_suivi (
  nom text PRIMARY KEY,
  dernier_jour integer NOT NULL,
  serie integer NOT NULL DEFAULT 0,
  repos_jusqua integer,
  maj timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.stage_caserne_suivi ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.stage_caserne_suivi FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.stage_caserne_effectuer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; p record; s public.stage_caserne_suivi%ROWTYPE; v_jour integer; v_paie jsonb;
  v_serie integer; v_vol numeric; v_repos integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT day, current_building, current_room, stats INTO p FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p.current_building IS DISTINCT FROM 'caserne-militaire' OR p.current_room IS DISTINCT FROM 'corps_garde' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_jour := coalesce(p.day, 1);
  SELECT * INTO s FROM public.stage_caserne_suivi WHERE nom = v_moi FOR UPDATE;
  IF FOUND AND s.repos_jusqua IS NOT NULL AND v_jour < s.repos_jusqua THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'repos_obligatoire', 'repos_jusqua', s.repos_jusqua); END IF;
  IF FOUND AND s.dernier_jour = v_jour THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_fait_aujourdhui'); END IF;
  v_paie := public.payer_ordre(v_moi, 'stage_caserne', 3, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_serie := CASE WHEN FOUND AND s.dernier_jour = v_jour - 1 THEN s.serie + 1 ELSE 1 END;
  v_vol := coalesce(CASE WHEN jsonb_typeof(p.stats -> 'VOL') = 'number' THEN (p.stats ->> 'VOL')::numeric END, 0) + 5;
  UPDATE public.personnages_donnees SET stats = coalesce(stats, '{}'::jsonb) || jsonb_build_object('VOL', v_vol)
   WHERE name = v_moi;
  v_repos := CASE WHEN v_serie >= 3 THEN v_jour + 7 END;
  INSERT INTO public.stage_caserne_suivi (nom, dernier_jour, serie, repos_jusqua, maj)
  VALUES (v_moi, v_jour, CASE WHEN v_serie >= 3 THEN 0 ELSE v_serie END, v_repos, now())
  ON CONFLICT (nom) DO UPDATE SET dernier_jour = EXCLUDED.dernier_jour, serie = EXCLUDED.serie,
    repos_jusqua = EXCLUDED.repos_jusqua, maj = now();
  RETURN jsonb_build_object('ok', true, 'vol', v_vol, 'serie', v_serie, 'repos_jusqua', v_repos, 'paie', v_paie);
END; $function$;
REVOKE ALL ON FUNCTION public.stage_caserne_effectuer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stage_caserne_effectuer() TO authenticated;

COMMIT;
