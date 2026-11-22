-- Forêt de Krasnov (Fred, 22/11/2026, nuit, point 4) :
-- • Égarement au retour vers la clairière : 50 % au lieu de 80 % (réglage aliments_parametres.foret_egarement_pct).
-- • Rencontres : en plus de la seconde coupe, 15 % de chance de rencontre en arrivant dans une vue profonde (1 à 4),
--   même sans couper (réglage foret_rencontre_arrivee_pct). Mêmes créatures (loup, meute, ours) et mêmes règles :
--   la bête est un PNJ de faune posé dans la vue ; combat de groupe si le chef a un groupe ; fuir ou se laisser faire.
-- • « Se laisser faire » vise désormais la vue de la rencontre (elle était écrite pour la vue 3 seulement).
-- Raccords par appel ajouté (marques foret_rencontre_arrivee_v1, foret_rencontre_vue_v1). Aucun objet du goulag touché.
BEGIN;
UPDATE public.aliments_parametres SET valeur = 50 WHERE cle = 'foret_egarement_pct';
INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('foret_rencontre_arrivee_pct', 15) ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.sovarka_foret_rencontre_arrivee_interne(p_acteur text, p_vue integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_type text; c jsonb; v_id bigint; v_pnj text;
BEGIN
  IF p_acteur IS NULL OR coalesce(p_vue, 0) NOT BETWEEN 1 AND 4 THEN RETURN NULL; END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_foret_rencontres WHERE bucheron = p_acteur AND statut = 'en_attente') THEN RETURN NULL; END IF;
  IF random() * 100 >= public.aliments_param_interne('foret_rencontre_arrivee_pct', 15) THEN RETURN NULL; END IF;
  v_type := (ARRAY['loup', 'meute', 'ours'])[1 + floor(random() * 3)::integer];
  c := public.sovarka_foret_creature_interne(v_type);
  INSERT INTO public.sovarka_foret_rencontres (bucheron, vue, creature, statut) VALUES (p_acteur, p_vue, v_type, 'en_attente') RETURNING id INTO v_id;
  v_pnj := 'faune:krasnov:' || v_id;
  INSERT INTO public.pnj_membres (id, famille, nom, pays, ville, building_id, room_id, classe, pa, proprietaire_institution, proprietaire_perimetre, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_pnj, 'employe', c->>'nom', 'soviet', 'ville_b', 'zone-production', 'foret_vue_' || p_vue, 'beta', coalesce((c->>'pa')::integer, public.pnj_pa_max()), 'faune', 'soviet:ville_b:foret',
          4, 4, (c->>'vol')::integer, (c->>'per')::integer, (c->>'dup')::integer, 4)
  ON CONFLICT (id) DO NOTHING;
  UPDATE public.sovarka_foret_rencontres SET pnj_id = v_pnj WHERE id = v_id;
  RETURN jsonb_build_object('rencontre', 'attaque', 'a_l_arrivee', true, 'creature', v_type, 'nom', c->>'nom', 'pnj', v_pnj, 'id', v_id);
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_foret_rencontre_arrivee_interne(text, integer) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;
SELECT pg_temp.rp_raccorder('public.sovarka_foret_aller(uuid, text)'::regprocedure,
  $a$  INSERT INTO public.sovarka_foret_actes (acteur, requete, resultat) VALUES (a, p_requete, r);$a$,
  $b$  r := r || coalesce(public.sovarka_foret_rencontre_arrivee_interne(a, v_dest), '{}'::jsonb); /* foret_rencontre_arrivee_v1 */
  INSERT INTO public.sovarka_foret_actes (acteur, requete, resultat) VALUES (a, p_requete, r);$b$,
  'foret_rencontre_arrivee_v1');
SELECT pg_temp.rp_raccorder('public.sovarka_foret_rencontre(uuid, text)'::regprocedure,
  $a$d.current_room = 'foret_vue_3'$a$,
  $b$d.current_room = 'foret_vue_' || e.vue /* foret_rencontre_vue_v1 */$b$,
  'foret_rencontre_vue_v1');
COMMIT;
