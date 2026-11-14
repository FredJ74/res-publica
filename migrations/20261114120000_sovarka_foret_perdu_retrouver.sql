-- Forêt profonde de Krasnov : s'enfoncer depuis une vue profonde, se perdre pour de bon, retrouver son chemin
-- (retour de Fred, 14/11/2026).
-- 1. « S'enfoncer dans la forêt » est aussi possible depuis une vue profonde : il mène au hasard vers une des
--    trois AUTRES vues (gratuit, comme depuis l'entrée). Plus besoin de revenir à l'entrée pour retourner au bois.
-- 2. « Revenir à l'entrée » : 1 fois sur 5 on sort ; sinon on s'égare vers une autre vue et l'on est PERDU.
-- 3. Perdu, « Revenir » est refusé (foret_perdu) : seul « Retrouver son chemin » (1 PA) sert, 1 fois sur 2 vers
--    l'entrée, sinon vers une autre vue (toujours perdu). S'enfoncer reste possible et ne guérit pas l'égarement.
-- 4. L'état est au serveur (sovarka_foret_perdus) ; toute arrivée à l'entrée ou tout départ hors de la forêt l'efface.
BEGIN;

CREATE TABLE IF NOT EXISTS public.sovarka_foret_perdus (
  bucheron text PRIMARY KEY,
  depuis timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_foret_perdus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_foret_perdus FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'foret_retrouver', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'foret_retrouver');

CREATE OR REPLACE FUNCTION public.sovarka_foret_aller(p_requete uuid, p_sens text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); x record; v_vue integer; v_dest integer; v jsonb; r jsonb; v_piece text;
        v_perdu boolean; v_paie jsonb; v_egare boolean := false;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF p_sens NOT IN ('enfoncer', 'revenir', 'retrouver') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:foret:' || a, 0));
  SELECT * INTO x FROM public.sovarka_foret_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  IF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chef_de_groupe_requis'); END IF;
  v_vue := public.sovarka_foret_vue_interne(a);
  IF v_vue IS NULL THEN
    DELETE FROM public.sovarka_foret_perdus WHERE bucheron = a;
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  -- A l'entrée (ou ailleurs), on n'est plus perdu.
  IF v_vue = 0 THEN DELETE FROM public.sovarka_foret_perdus WHERE bucheron = a; END IF;
  v_perdu := EXISTS (SELECT 1 FROM public.sovarka_foret_perdus WHERE bucheron = a);
  IF p_sens = 'revenir' AND v_vue = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_a_l_entree'); END IF;
  IF p_sens = 'retrouver' AND v_vue = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_a_l_entree'); END IF;
  IF p_sens = 'revenir' AND v_perdu THEN RETURN jsonb_build_object('ok', false, 'raison', 'foret_perdu', 'perdu', true); END IF;
  IF p_sens = 'retrouver' AND NOT v_perdu THEN RETURN jsonb_build_object('ok', false, 'raison', 'foret_pas_perdu', 'perdu', false); END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_foret_rencontres WHERE bucheron = a AND statut = 'en_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rencontre_en_cours'); END IF;

  IF p_sens = 'retrouver' THEN
    v_paie := public.payer_ordre(a, 'foret_retrouver', 1, 0);
    IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  END IF;

  -- Tirage de la destination : jamais la vue où l'on se trouve déjà.
  IF (p_sens = 'revenir' AND random() < 0.2) OR (p_sens = 'retrouver' AND random() < 0.5) THEN
    v_dest := 0;
  ELSIF v_vue = 0 THEN
    v_dest := 1 + floor(random() * 4)::integer;
  ELSE
    v_dest := (ARRAY(SELECT g FROM generate_series(1, 4) g WHERE g <> v_vue))[1 + floor(random() * 3)::integer];
  END IF;
  v_piece := CASE WHEN v_dest = 0 THEN 'zone_recolte' ELSE 'foret_vue_' || v_dest END;
  v := public.sovarka_foret_deplacer_interne(a, v_piece);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN
    IF p_sens = 'retrouver' THEN RAISE EXCEPTION 'sovarka_foret_aller: deplacement refuse apres paiement %', v; END IF;
    RETURN v;
  END IF;
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = a;
  IF v_dest > 0 THEN INSERT INTO public.sovarka_foret_visites (bucheron, vue) VALUES (a, v_dest); END IF;

  IF v_dest = 0 THEN
    DELETE FROM public.sovarka_foret_perdus WHERE bucheron = a;
    v_perdu := false;
  ELSIF p_sens IN ('revenir', 'retrouver') THEN
    INSERT INTO public.sovarka_foret_perdus (bucheron) VALUES (a) ON CONFLICT (bucheron) DO NOTHING;
    v_perdu := true;
    v_egare := true;
  END IF;

  r := jsonb_build_object('ok', true, 'sens', p_sens, 'vue', v_dest, 'room', v_piece,
    'perdu', v_perdu, 'egare', v_egare, 'membres', v->'membres', 'positions', v->'positions');
  IF v_paie IS NOT NULL THEN
    r := r || jsonb_build_object('pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
  END IF;
  INSERT INTO public.sovarka_foret_actes (acteur, requete, resultat) VALUES (a, p_requete, r);
  RETURN r;
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_aller(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_foret_aller(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_foret_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_vue integer; v_chef text; s record; r record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_vue := public.sovarka_foret_vue_interne(a);
  IF v_vue IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_chef := coalesce((SELECT chef FROM public.groupes_pj_adhesions WHERE membre = a), a);
  SELECT * INTO s FROM public.sovarka_foret_visites WHERE bucheron = v_chef AND vue = v_vue;
  SELECT * INTO r FROM public.sovarka_foret_rencontres WHERE bucheron = v_chef AND statut = 'en_attente' ORDER BY id DESC LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'vue', v_vue, 'chef', v_chef, 'membre', v_chef <> a,
    'coupes', coalesce(s.coupes, 0), 'coupes_bois', CASE WHEN v_vue IN (1, 2) THEN 2 WHEN v_vue IN (3, 4) THEN 1 ELSE 0 END,
    'perdu', v_vue > 0 AND EXISTS (SELECT 1 FROM public.sovarka_foret_perdus WHERE bucheron = v_chef),
    'rencontre', CASE WHEN r.id IS NULL THEN NULL ELSE jsonb_build_object('id', r.id, 'creature', r.creature, 'pnj', r.pnj_id,
      'nom', public.sovarka_foret_creature_interne(r.creature)->>'nom') END);
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_foret_lire() TO authenticated;

COMMIT;
