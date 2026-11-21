-- FORÊT DE KRASNOV — entrée par le portique, clairière, retour au campement (GAME-DESIGN-FORET-KRASNOV-20261121.md,
-- version définitive et complément « exploration en groupe »). Tout le reste du mécanisme existant est inchangé
-- (vues 1 à 4, coupes, rencontres loup / meute / ours / Olga, combats, groupes).
-- • Nouvelle pièce « foret_clairiere » (vue 5 pour le serveur) : première et dernière image de l'exploration ; on n'y coupe
--   pas et rien n'y attaque.
-- • sovarka_foret_aller : sens « clairiere » (entrée → clairière) ; « enfoncer » depuis la clairière ou une vue profonde
--   (depuis l'entrée, il mène à la clairière) ; « campement » : depuis la clairière, retour direct à l'exploitation ; depuis
--   une vue profonde, 1er clic : clairière ou égarement (même tirage que l'aller), 2e clic : toujours la clairière.
--   Les anciens sens « revenir » et « retrouver » valent « campement » (écrans encore ouverts).
-- • Aucun PA pour se déplacer (« retrouver » coûtait 1 PA : supprimé). Couper et les rencontres gardent leurs coûts.
-- • Tirage : jamais deux images de bois identiques de suite (les vues 1 et 2 partagent l'image des coupes : on ne passe
--   jamais de l'une à l'autre directement).
-- • Probabilité de s'égarer au premier clic : celle du code existant (« revenir » arrivait 1 fois sur 5, soit 80 %
--   d'égarement), en réglage MJ : aliments_parametres.foret_egarement_pct.
-- • Groupes : inchangé — seul le chef clique (les membres reçoivent « chef_de_groupe_requis ») ; le déplacement emmène tout
--   le groupe (un seul tirage, même image pour tous) ; un combat contre la faune est le combat de groupe existant.
BEGIN;

INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('foret_egarement_pct', 80) ON CONFLICT (cle) DO NOTHING;
-- Miroir du coût de l'ordre d'écran « Retour au campement » (0 PA, comme tous les déplacements).
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'foret_campement', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'foret_campement' AND pa = 0 AND cost = 0);

UPDATE public.navigation_lieux_regles
   SET pieces = pieces || '["foret_clairiere"]'::jsonb
 WHERE pays = 'soviet' AND ville = 'ville_b' AND batiment = 'zone-production' AND NOT pieces ? 'foret_clairiere';

CREATE OR REPLACE FUNCTION public.sovarka_foret_vue_interne(p_nom text)
 RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN d.current_room = 'zone_recolte' THEN 0
              WHEN d.current_room ~ '^foret_vue_[1-4]$' THEN right(d.current_room, 1)::integer
              WHEN d.current_room = 'foret_clairiere' THEN 5 END   -- foret_clairiere_v1
    FROM public.personnages_donnees d
   WHERE d.name = p_nom AND d.country = 'soviet' AND d.current_city = 'ville_b' AND d.current_building = 'zone-production';
$function$;

-- Tirage d'une vue profonde depuis la vue p_depuis (5 = clairière) : une vue différente, jamais l'autre vue des coupes
-- juste après une vue des coupes (même image de bois).
CREATE OR REPLACE FUNCTION public.sovarka_foret_tirer_vue_interne(p_depuis integer)
RETURNS integer LANGUAGE sql VOLATILE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT g FROM generate_series(1, 4) g
   WHERE g <> coalesce(p_depuis, 0) AND NOT (p_depuis IN (1, 2) AND g IN (1, 2))
   ORDER BY random() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.sovarka_foret_aller(p_requete uuid, p_sens text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); x record; v_vue integer; v_dest integer; v jsonb; r jsonb; v_piece text;
        v_perdu boolean; v_egare boolean := false; v_sens text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF p_sens NOT IN ('clairiere', 'enfoncer', 'campement', 'revenir', 'retrouver') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  v_sens := CASE WHEN p_sens IN ('revenir', 'retrouver') THEN 'campement' ELSE p_sens END;   -- foret_clairiere_v1
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:foret:' || a, 0));
  SELECT * INTO x FROM public.sovarka_foret_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  -- Groupe : seul le chef clique ; les membres suivent (le déplacement emmène tout le groupe).
  IF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = a) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chef_de_groupe_requis'); END IF;
  v_vue := public.sovarka_foret_vue_interne(a);
  IF v_vue IS NULL THEN
    DELETE FROM public.sovarka_foret_perdus WHERE bucheron = a;
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  IF v_vue IN (0, 5) THEN DELETE FROM public.sovarka_foret_perdus WHERE bucheron = a; END IF;
  v_perdu := EXISTS (SELECT 1 FROM public.sovarka_foret_perdus WHERE bucheron = a);
  IF v_sens = 'campement' AND v_vue = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_a_l_entree'); END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_foret_rencontres WHERE bucheron = a AND statut = 'en_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rencontre_en_cours'); END IF;

  IF v_sens = 'clairiere' OR (v_sens = 'enfoncer' AND v_vue = 0) THEN
    v_dest := 5;                                                   -- le portique mène toujours à la clairière
  ELSIF v_sens = 'enfoncer' THEN
    v_dest := public.sovarka_foret_tirer_vue_interne(v_vue);       -- mécanisme existant : une vue profonde au hasard
  ELSIF v_vue = 5 THEN
    v_dest := 0;                                                   -- clairière → campement, sans tirage ni rencontre
  ELSIF v_perdu THEN
    v_dest := 5;                                                   -- second clic : toujours la clairière
  ELSIF random() * 100 < public.aliments_param_interne('foret_egarement_pct', 80) THEN
    v_dest := public.sovarka_foret_tirer_vue_interne(v_vue);       -- égaré : même tirage que l'aller
    v_egare := true;
  ELSE
    v_dest := 5;
  END IF;

  v_piece := CASE v_dest WHEN 0 THEN 'zone_recolte' WHEN 5 THEN 'foret_clairiere' ELSE 'foret_vue_' || v_dest END;
  v := public.sovarka_foret_deplacer_interne(a, v_piece);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  DELETE FROM public.sovarka_foret_visites WHERE bucheron = a;
  IF v_dest BETWEEN 1 AND 4 THEN INSERT INTO public.sovarka_foret_visites (bucheron, vue) VALUES (a, v_dest); END IF;
  IF v_egare THEN
    INSERT INTO public.sovarka_foret_perdus (bucheron) VALUES (a) ON CONFLICT (bucheron) DO NOTHING;
    v_perdu := true;
  ELSIF v_dest IN (0, 5) THEN
    DELETE FROM public.sovarka_foret_perdus WHERE bucheron = a;
    v_perdu := false;
  END IF;

  r := jsonb_build_object('ok', true, 'sens', v_sens, 'vue', v_dest, 'room', v_piece,
    'perdu', v_perdu, 'egare', v_egare, 'membres', v->'membres', 'positions', v->'positions');
  INSERT INTO public.sovarka_foret_actes (acteur, requete, resultat) VALUES (a, p_requete, r);
  RETURN r;
END $function$;

-- On ne coupe pas dans la clairière (ni à l'entrée) : seulement dans les vues profondes.
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;
SELECT pg_temp.rp_raccorder('public.sovarka_foret_couper(uuid)'::regprocedure,
  $a$IF coalesce(v_vue, 0) = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_foret_profonde'); END IF;$a$,
  $b$IF coalesce(v_vue, 0) NOT BETWEEN 1 AND 4 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_foret_profonde'); END IF; /* foret_clairiere_v1 */$b$,
  'foret_clairiere_v1');

REVOKE ALL ON FUNCTION public.sovarka_foret_tirer_vue_interne(integer) FROM PUBLIC, anon, authenticated;

COMMIT;
