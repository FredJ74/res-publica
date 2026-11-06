-- Enquête, filature, chasse à l'homme : le jet passe au serveur (Claude, 05/11/2026, chantier « jets de l'écran »).
--
-- DÉFAUT CORRIGÉ. Les trois ordres du commissaire tiraient le dé dans le navigateur, puis appelaient
-- la fonction serveur qui agit (commissaire_enqueter, filature_deplacements,
-- justice_executer_condamnation). Un écran modifié sautait le jet et réussissait à tous les coups,
-- contre un autre joueur (garde à vue, relevé de déplacements, arrestation).
--
-- Désormais l'écran appelle une porte qui tire le dé puis, seulement en cas de réussite, appelle la
-- fonction d'action ; celle-ci n'est plus exécutable directement par un joueur.
-- Formules reprises telles quelles de l'écran (aucune valeur nouvelle), bornées à [10, 90] :
--   enquête : 35 + 2(PER − PER cible) + 0,3(INF − INF cible) + (ISN − 45)/5
--   chasse  : 45 + 2(PER − PER cible) + 0,3(INF − INF cible) + (ISN − 45)/5
--   filature: 50 + 2(PER − 13) − (PER cible − 13) + (ISN − 50)/5 + 0,3(INF − INF cible)
-- Caractéristiques de base (colonne stats), ISN de la ville du poste (indices_villes), +5 si
-- l'écran déclare une bénédiction (même convention que crime_voler, en attendant une bénédiction
-- tenue par le serveur).

CREATE OR REPLACE FUNCTION public.commissaire_jet_interne(p_ordre text, p_cible text, p_benediction boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_poste text; v_ville text; v_pays text; v_per numeric; v_inf numeric;
  v_per_c numeric; v_inf_c numeric; v_isn numeric; v_t numeric; v_taux integer; v_roll integer;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays INTO v_nom, v_poste, v_ville, v_pays FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'commissaire' OR v_ville IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF coalesce(btrim(p_cible), '') = '' OR p_cible = v_nom THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT coalesce((stats ->> 'PER')::numeric, 8), coalesce((resources ->> 'inf')::numeric, 0) INTO v_per, v_inf
    FROM public.personnages_donnees WHERE name = v_nom;
  SELECT coalesce((stats ->> 'PER')::numeric, 8), coalesce((resources ->> 'inf')::numeric, 0) INTO v_per_c, v_inf_c
    FROM public.personnages_donnees WHERE name = p_cible;
  IF NOT FOUND THEN v_per_c := 8; v_inf_c := 0; END IF;
  v_isn := coalesce((SELECT nullif(data ->> 'isn', '')::numeric FROM public.indices_villes WHERE id = v_pays || '_' || v_ville), 30);
  v_t := CASE p_ordre
    WHEN 'enquete' THEN 35 + (v_per - v_per_c) * 2 + (v_inf - v_inf_c) * 0.3 + (v_isn - 45) / 5
    WHEN 'chasse' THEN 45 + (v_per - v_per_c) * 2 + (v_inf - v_inf_c) * 0.3 + (v_isn - 45) / 5
    WHEN 'filature' THEN 50 + 2 * (v_per - 13) - (v_per_c - 13) + (v_isn - 50) / 5 + (v_inf - v_inf_c) * 0.3
  END;
  IF v_t IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu'); END IF;
  IF p_benediction THEN v_t := v_t + 5; END IF;
  v_taux := greatest(10, least(90, round(v_t)::integer));
  v_roll := floor(random() * 100)::integer + 1;
  RETURN jsonb_build_object('ok', true, 'abouti', v_roll <= v_taux, 'taux', v_taux, 'jet', v_roll);
END; $function$;
REVOKE ALL ON FUNCTION public.commissaire_jet_interne(text, text, boolean) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.commissaire_enquete_mener(p_cible text, p_benediction boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE j jsonb;
BEGIN
  j := public.commissaire_jet_interne('enquete', p_cible, p_benediction);
  IF (j ->> 'ok')::boolean IS NOT TRUE OR (j ->> 'abouti')::boolean IS NOT TRUE THEN RETURN j; END IF;
  RETURN public.commissaire_enqueter(p_cible) || jsonb_build_object('abouti', true, 'taux', j -> 'taux', 'jet', j -> 'jet');
END; $function$;

CREATE OR REPLACE FUNCTION public.filature_mener(p_cible text, p_benediction boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE j jsonb;
BEGIN
  j := public.commissaire_jet_interne('filature', p_cible, p_benediction);
  IF (j ->> 'ok')::boolean IS NOT TRUE OR (j ->> 'abouti')::boolean IS NOT TRUE THEN RETURN j; END IF;
  RETURN public.filature_deplacements(p_cible) || jsonb_build_object('abouti', true, 'taux', j -> 'taux', 'jet', j -> 'jet');
END; $function$;

CREATE OR REPLACE FUNCTION public.chasse_homme_mener(p_cible text, p_jugement_id text, p_ville text, p_benediction boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE j jsonb;
BEGIN
  j := public.commissaire_jet_interne('chasse', p_cible, p_benediction);
  IF (j ->> 'ok')::boolean IS NOT TRUE OR (j ->> 'abouti')::boolean IS NOT TRUE THEN RETURN j; END IF;
  RETURN public.justice_executer_condamnation(p_jugement_id, p_ville) || jsonb_build_object('abouti', true, 'taux', j -> 'taux', 'jet', j -> 'jet');
END; $function$;

REVOKE ALL ON FUNCTION public.commissaire_enquete_mener(text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.filature_mener(text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.chasse_homme_mener(text, text, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.commissaire_enquete_mener(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.filature_mener(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chasse_homme_mener(text, text, text, boolean) TO authenticated;

-- Les fonctions d'action ne sont plus appelables directement par un joueur (seulement par les portes).
REVOKE EXECUTE ON FUNCTION public.commissaire_enqueter(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.filature_deplacements(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.justice_executer_condamnation(text, text) FROM PUBLIC, anon, authenticated;
