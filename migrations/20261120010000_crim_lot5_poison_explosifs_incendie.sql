-- CRIMINALITÉ — LOT 5 : empoisonnement, explosifs, incendie (GAME-DESIGN-CRIMINALITE.md §§ 6, 9, 10, 11, 15 ; Fred, 18-19/11/2026).
-- Les trois actes passent par la résolution commune crim_resoudre_interne (jet, dissuasion #135 une seule fois, échec critique,
-- détection après réussite, mode visage découvert / caché / masqué, affaire, peine d'office). Aucune copie de jet ni de détection.
-- • crime_empoisonner(cible, requete) : PJ présent (nom ou jeton d'un individu masqué). Anonymat par nature : la victime ne sait
--   jamais qui (message mystérieux, annonce publique inchangés), même à visage découvert. Cachette = bonus +10 (plus exigée).
--   35 + DIS/3 > 50 − 3 × (PER de groupe − 8) + 10 caché + 15 criminelle ; poison : parapluie +5, GHB +10 si la victime a bu dans
--   la journée (verres_du_jour) sinon −10, polonium −10, vipère 0 ; Narco +20, Sovarka −10 ; bornes 5-85. Quatre paliers conservés.
--   Fin du « recherché d'office » et du flagrant délit à l'échec : échec critique 2 % des échecs (identifié sans masque, −15 moral).
-- • crime_explosifs(batiment, requete) : 35 + DIS/3 > 50 + 2 × (INT − 8) + 10 caché + 15 criminelle − 30 bâtiment officiel,
--   5-75. Échec critique 10 % des échecs = explosion prématurée (poseur à 15 de santé, identifié sans masque, −15 moral) ; les
--   autres échecs ne révèlent rien. Détection après réussite 65 (−10 masqué, −20 caché, min 30). Fermeture 5 jours, présents à 15.
-- • crime_incendier(batiment, requete) : 30 + DIS/3 > 50 + 10 caché + 15 criminelle + 15 bidon de carburant (consommé) − 15 orage
--   + 15 canicule (climat_evenements de la ville), 5-80. Échec critique 2 %. Détection après réussite seulement 70 (min 20).
--   Fermeture 1 à 3 jours selon le jet (inchangé).
-- • Brouillard (GAME-DESIGN-MALADIES-CLIMAT.md § 6) branché dans crim_resoudre_interne : +10 de réussite, −20 de détection pour
--   tout acte illégal résolu par la résolution commune dans une ville sous brouillard (climat_brouillard_modificateurs_interne).
-- • Anciennes signatures crime_empoisonner(text), crime_explosifs(text), crime_incendier(text) : « requete_requise ».
BEGIN;

-- ── Paramètres (valeurs de Républia ; les autres empires reprennent Républia) ──────────────────────────────────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES
  ('poison_base', 35), ('poison_min', 5), ('poison_max', 85), ('poison_carriere', 15), ('poison_cache', 10),
  ('poison_per_pivot', 8), ('poison_per_pas', 3), ('poison_parapluie', 5), ('poison_ghb_bu', 10), ('poison_ghb_sobre', -10),
  ('poison_polonium', -10), ('poison_vipere', 0), ('poison_narco', 20), ('poison_soviet', -10), ('poison_detection', 25),
  ('explosifs_base', 35), ('explosifs_min', 5), ('explosifs_max', 75), ('explosifs_carriere', 15), ('explosifs_cache', 10),
  ('explosifs_int_pivot', 8), ('explosifs_int_pas', 2), ('explosifs_officiel', 30), ('explosifs_critique_part', 10),
  ('explosifs_detection', 65), ('explosifs_detection_min', 30), ('explosifs_sante', 15),
  ('incendie_base', 30), ('incendie_min', 5), ('incendie_max', 80), ('incendie_carriere', 15), ('incendie_cache', 10),
  ('incendie_bidon', 15), ('incendie_orage', -15), ('incendie_canicule', 15), ('incendie_detection', 70), ('incendie_detection_min', 20),
  ('crim_dis_pivot', 50), ('crim_dis_tranche', 3)
ON CONFLICT (cle) DO NOTHING;

-- ── Briques ─────────────────────────────────────────────────────────────────────────────────────────────────────
-- +1 par tranche de 3 de DIS au-dessus de 50 (rien en dessous : même convention que le lot 4).
CREATE OR REPLACE FUNCTION public.crim_bonus_dis_interne(p_dis numeric)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(0, trunc((coalesce(p_dis, 50) - public.crim_param_interne('crim_dis_pivot', 50)) / public.crim_param_interne('crim_dis_tranche', 3)))::integer;
$$;

-- Événement climatique en cours dans la ville (même lecture que climat_brouillard_modificateurs_interne).
CREATE OR REPLACE FUNCTION public.crim_climat_actif_interne(p_type text, p_pays text, p_ville text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.climat_evenements e WHERE e.type = p_type AND e.pays = p_pays AND e.ville = p_ville
                   AND NOT e.annule AND e.alerte_le IS NOT NULL AND now() >= e.debut AND now() < e.fin);
$$;

-- Bâtiments officiels (liste existante de crime_explosifs / crime_incendier).
CREATE OR REPLACE FUNCTION public.crim_batiment_officiel_interne(p_batiment text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_batiment IN ('palais-presidentiel','palais-gouvernement','assemblee','tribunal','commissariat','banque-nationale',
    'banque-privee','mairie-capitale','mairie','commissariat-local','tribunal-local','banque-locale'), false);
$$;

-- « A bu dans la journée » : un verre compté aujourd'hui (verres_du_jour : consommation sur place, tournées, boire).
CREATE OR REPLACE FUNCTION public.crim_a_bu_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.verres_du_jour WHERE nom = p_nom AND jour = (now() AT TIME ZONE 'Europe/Paris')::date AND n > 0);
$$;

-- ── Formules (§§ 9, 10, 11), avant dissuasion et bornes ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_empoisonner_taux_interne(p_dis numeric, p_per numeric, p_cache boolean, p_carriere text,
                                                               p_poison text, p_a_bu boolean, p_pays text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT round(public.crim_param_interne('poison_base', 35) + public.crim_bonus_dis_interne(p_dis)
         - public.crim_param_interne('poison_per_pas', 3) * (coalesce(p_per, 8) - public.crim_param_interne('poison_per_pivot', 8))
         + CASE WHEN p_cache THEN public.crim_param_interne('poison_cache', 10) ELSE 0 END
         + CASE WHEN p_carriere = 'criminal_c' THEN public.crim_param_interne('poison_carriere', 15) ELSE 0 END
         + CASE p_poison WHEN 'parapluie' THEN public.crim_param_interne('poison_parapluie', 5)
                         WHEN 'ghb' THEN CASE WHEN p_a_bu THEN public.crim_param_interne('poison_ghb_bu', 10) ELSE public.crim_param_interne('poison_ghb_sobre', -10) END
                         WHEN 'polonium' THEN public.crim_param_interne('poison_polonium', -10)
                         ELSE public.crim_param_interne('poison_vipere', 0) END
         + CASE p_pays WHEN 'narco' THEN public.crim_param_interne('poison_narco', 20) WHEN 'soviet' THEN public.crim_param_interne('poison_soviet', -10) ELSE 0 END)::integer;
$$;

CREATE OR REPLACE FUNCTION public.crim_explosifs_taux_interne(p_dis numeric, p_int numeric, p_cache boolean, p_carriere text, p_officiel boolean)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT round(public.crim_param_interne('explosifs_base', 35) + public.crim_bonus_dis_interne(p_dis)
         + public.crim_param_interne('explosifs_int_pas', 2) * (coalesce(p_int, 8) - public.crim_param_interne('explosifs_int_pivot', 8))
         + CASE WHEN p_cache THEN public.crim_param_interne('explosifs_cache', 10) ELSE 0 END
         + CASE WHEN p_carriere = 'criminal_c' THEN public.crim_param_interne('explosifs_carriere', 15) ELSE 0 END
         - CASE WHEN p_officiel THEN public.crim_param_interne('explosifs_officiel', 30) ELSE 0 END)::integer;
$$;

CREATE OR REPLACE FUNCTION public.crim_incendie_taux_interne(p_dis numeric, p_cache boolean, p_carriere text, p_bidon boolean,
                                                            p_orage boolean, p_canicule boolean)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT round(public.crim_param_interne('incendie_base', 30) + public.crim_bonus_dis_interne(p_dis)
         + CASE WHEN p_cache THEN public.crim_param_interne('incendie_cache', 10) ELSE 0 END
         + CASE WHEN p_carriere = 'criminal_c' THEN public.crim_param_interne('incendie_carriere', 15) ELSE 0 END
         + CASE WHEN p_bidon THEN public.crim_param_interne('incendie_bidon', 15) ELSE 0 END
         + CASE WHEN p_orage THEN public.crim_param_interne('incendie_orage', -15) ELSE 0 END
         + CASE WHEN p_canicule THEN public.crim_param_interne('incendie_canicule', 15) ELSE 0 END)::integer;
$$;

-- Quatre paliers de l'empoisonnement (inchangés) sur le jet de la résolution commune : totale (moitié basse des réussites),
-- partielle, échec partiel (moitié basse des échecs : effet atténué), échec total (rien).
CREATE OR REPLACE FUNCTION public.crim_empoisonner_palier_interne(p_jet numeric, p_taux numeric)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_jet < p_taux / 2.0 THEN 'totale' WHEN p_jet < p_taux THEN 'partielle'
              WHEN p_jet < p_taux + (100 - p_taux) / 2.0 THEN 'echec_partiel' ELSE 'echec_total' END;
$$;

-- Fermeture de l'incendie selon le jet (inchangé) : 3 jours (moitié basse des réussites), 2 (jusqu'à 80 %), 1 sinon.
CREATE OR REPLACE FUNCTION public.crim_incendie_jours_interne(p_jet numeric, p_taux numeric)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_jet >= p_taux THEN 0 WHEN p_jet < p_taux * 0.5 THEN 3 WHEN p_jet < p_taux * 0.8 THEN 2 ELSE 1 END;
$$;

-- ── Brouillard dans la résolution commune (raccords sur le texte de production) ─────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

SELECT pg_temp.rp_raccorder('public.crim_resoudre_interne(text,text,text,jsonb)'::regprocedure,
  $a$v_garde boolean; v_per numeric; v_plafond integer;$a$,
  $b$v_garde boolean; v_per numeric; v_plafond integer; v_brouillard jsonb := '{}'::jsonb; /* crim_brouillard_decl_v1 */$b$,
  'crim_brouillard_decl_v1');

-- Brouillard dans la ville de l'acte : bonus de réussite, et base de détection abaissée (gardée dans l'affaire, donc aussi
-- pour la détection qui suit un combat gagné). Paramètre « brouillard » : false pour l'ignorer.
SELECT pg_temp.rp_raccorder('public.crim_resoudre_interne(text,text,text,jsonb)'::regprocedure,
  $a$  v_cache := v_mode IN ('cache', 'cache_masque');$a$,
  $b$  v_cache := v_mode IN ('cache', 'cache_masque');
  IF coalesce((p ->> 'brouillard')::boolean, true) THEN /* crim_brouillard_v1 */
    v_brouillard := coalesce(public.climat_brouillard_modificateurs_interne(a.country, a.current_city), '{}'::jsonb);
    IF coalesce((v_brouillard ->> 'brouillard')::boolean, false) AND p ->> 'detection_base' IS NOT NULL THEN
      p := p || jsonb_build_object('detection_base_hors_brouillard', (p ->> 'detection_base')::numeric,
                                   'detection_base', (p ->> 'detection_base')::numeric - coalesce((v_brouillard ->> 'malus_detection')::numeric, 0));
    END IF;
  END IF;$b$,
  'crim_brouillard_v1');

SELECT pg_temp.rp_raccorder('public.crim_resoudre_interne(text,text,text,jsonb)'::regprocedure,
  $a$(p ->> 'taux')::numeric - v_dis))::integer;$a$,
  $b$(p ->> 'taux')::numeric + CASE WHEN coalesce((v_brouillard ->> 'brouillard')::boolean, false) THEN coalesce((v_brouillard ->> 'bonus_reussite')::numeric, 0) ELSE 0 END /* crim_brouillard_taux_v1 */ - v_dis))::integer;$b$,
  'crim_brouillard_taux_v1');

SELECT pg_temp.rp_raccorder('public.crim_resoudre_interne(text,text,text,jsonb)'::regprocedure,
  $a$'remarque', v_remarque, 'notifie', v_notif);$a$,
  $b$'remarque', v_remarque, 'notifie', v_notif, 'brouillard', coalesce((v_brouillard ->> 'brouillard')::boolean, false) /* crim_brouillard_retour_v1 */);$b$,
  'crim_brouillard_retour_v1');

-- ── Empoisonner (§ 9) ───────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crime_empoisonner(p_cible text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cible', p_cible); v jsonb; m record; ci jsonb;
  v_victime text; v_pos integer; v_type text; v_mode text; v_per numeric; v_bu boolean; v_taux integer; r jsonb; v_palier text;
  v_stats jsonb; v_msg text; v_out jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crime_empoisonner', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT name, career, country, inventory, est_emprisonne INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(m.est_emprisonne), 'null') <> 'null' AND m.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  ci := public.crim_cible_resoudre_interne(a, p_cible);
  IF coalesce((ci ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN ci; END IF;
  IF NOT (ci ->> 'pj')::boolean THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_pj_seulement'); END IF;
  v_victime := ci ->> 'nom';
  SELECT (o.ord - 1)::integer, o.item ->> 'poisonType' INTO v_pos, v_type
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) WITH ORDINALITY o(item, ord)
   WHERE o.item ->> 'type' = 'poison' ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poison_manquant'); END IF;
  v_type := CASE WHEN v_type IN ('parapluie', 'ghb', 'polonium', 'vipere') THEN v_type ELSE 'parapluie' END;
  UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = a;

  v_mode := public.crim_mode_action_interne(a);
  v_per := public.crim_per_groupe_interne(ci);
  v_bu := public.crim_a_bu_interne(v_victime);
  v_taux := public.crim_empoisonner_taux_interne(public.crim_stat_interne(a, 'dis', 50), v_per, v_mode IN ('cache', 'cache_masque'),
                                                 m.career, v_type, v_bu, m.country);
  -- Anonymat par nature : aucun message nommant l'auteur, jamais d'identification par la victime (même à visage découvert),
  -- l'échec ne se remarque pas. Seuls l'échec critique (sans masque) et la détection après réussite identifient.
  r := public.crim_resoudre_interne('empoisonner', a, v_victime, jsonb_build_object(
    'taux', v_taux, 'min', public.crim_param_interne('poison_min', 5), 'max', public.crim_param_interne('poison_max', 85), 'mode', v_mode,
    'remarque_echec', 0, 'decouvert_identifie', false, 'msg_reussite', '', 'msg_echec', '',
    'titre_reussite', 'Empoisonnement', 'titre_echec', 'Tentative d''empoisonnement',
    'detection_base', public.crim_param_interne('poison_detection', 25), 'detection_min', public.crim_param_interne('detection_min', 5),
    'acte_peine_reussite', 'empoisonnement', 'acte_peine_echec', 'tentative_empoisonnement', 'type_recherche', 'crime',
    'cible_info', ci, 'indices', jsonb_build_object('poison', v_type),
    'poison', v_type, 'per_groupe', v_per, 'a_bu', v_bu,
    'jets', CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END));
  v_palier := public.crim_empoisonner_palier_interne((r ->> 'jet')::numeric, (r ->> 'taux')::numeric);

  IF v_palier <> 'echec_total' THEN
    SELECT jsonb_agg(s) INTO v_stats FROM (SELECT s FROM unnest(ARRAY['INT','CHA','VOL','PER','DUP','ENT']) s ORDER BY random() LIMIT 2) x;
    INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, palier, traite, details)
    VALUES ('poison-' || gen_random_uuid(), v_victime, 'poison_start', 0, v_palier, false,
            jsonb_build_object('poisonType', v_type, 'statsTouchees', v_stats));
    v_msg := CASE v_type
      WHEN 'ghb' THEN 'Votre esprit devient confus. Vous avez la tête qui tourne et vos sens sont perturbés. Vous avez l''impression d''avoir été drogué(e), mais par qui ? Vous perdez 2 PA.'
      WHEN 'polonium' THEN 'Vous vous sentez subitement faible. En passant la main dans vos cheveux, ils se décrochent par paquets de votre crâne, comme si vous aviez été mis(e) en contact avec quelque chose de radioactif. Vous perdez 2 PA.'
      WHEN 'vipere' THEN 'Vous ressentez une violente douleur au niveau du mollet. Deux petits trous douloureux et rouges sont visibles. Un serpent vous aurait-il mordu(e) ? Vous perdez 2 PA.'
      ELSE 'Quelque chose vous pique dans le dos. Une douleur irradie dans tout votre corps et s''intensifie d''heure en heure. Était-ce en lien avec cette personne qui vous a touché avec le bout de son parapluie et s''est excusée ? Vous perdez 2 PA.' END;
    PERFORM public.mail_systeme_poser_interne('Événement mystérieux', v_victime, 'Vous vous sentez mal...', v_msg,
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
    PERFORM public.annonce_publique_interne(m.country, 'MYSTÈRE : ' || v_victime || ' se sent soudainement très mal...');
    PERFORM public.crime_trace_rumeur_interne(a, 'empoisonnement', v_victime);
  END IF;

  -- Réponse : jamais le nom d'une victime visée par jeton.
  v_out := jsonb_build_object('ok', true, 'palier', v_palier, 'poison', v_type, 'effet', v_palier <> 'echec_total',
             'cible', CASE WHEN (ci ->> 'via_jeton')::boolean THEN NULL ELSE v_victime END)
    || (r - 'notifie' - 'affaire' - 'garde' - 'remarque' - 'taux_combat' - 'jet_combat')
    || (SELECT jsonb_build_object('moral', moral, 'recherche', recherche, 'inventaire', inventory, 'inventory', inventory, 'revision', inventory_revision)
          FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_empoisonner', prm, v_out);
END $$;

-- ── Explosifs (§ 10) ────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crime_explosifs(p_nom_batiment text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('batiment', p_nom_batiment); v jsonb; m record; v_paie jsonb;
  v_pos integer; v_nom text; v_mode text; v_officiel boolean; v_taux integer; r jsonb; v_victimes text[] := ARRAY[]::text[]; v_v record;
  v_sante integer := public.crim_param_interne('explosifs_sante', 15)::integer; v_date text := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
  v_prematuree boolean := false; v_out jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crime_explosifs', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT country, current_city, current_building, current_room, career, inventory, est_emprisonne INTO m
    FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(m.est_emprisonne), 'null') <> 'null' AND m.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  IF coalesce(m.current_building, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  SELECT (o.ord - 1)::integer INTO v_pos
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(m.inventory) = 'array' THEN m.inventory ELSE '[]'::jsonb END) WITH ORDINALITY o(item, ord)
   WHERE o.item ->> 'type' = 'explosif' ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'explosif_manquant'); END IF;
  v_nom := left(coalesce(nullif(btrim(p_nom_batiment), ''), m.current_building), 80);
  v_paie := public.payer_ordre(a, 'utiliser_explosifs', 3, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.personnages_donnees SET inventory = inventory - v_pos WHERE name = a;

  v_mode := public.crim_mode_action_interne(a);
  v_officiel := public.crim_batiment_officiel_interne(m.current_building);
  v_taux := public.crim_explosifs_taux_interne(public.crim_stat_interne(a, 'dis', 50), public.crim_stat_interne(a, 'INT', 8),
                                               v_mode IN ('cache', 'cache_masque'), m.career, v_officiel);
  r := public.crim_resoudre_interne('utiliser_explosifs', a, NULL, jsonb_build_object(
    'taux', v_taux, 'min', public.crim_param_interne('explosifs_min', 5), 'max', public.crim_param_interne('explosifs_max', 75), 'mode', v_mode,
    'critique_echec_part', public.crim_param_interne('explosifs_critique_part', 10),
    'detection_base', public.crim_param_interne('explosifs_detection', 65), 'detection_min', public.crim_param_interne('explosifs_detection_min', 30),
    'acte_peine_reussite', 'utiliser_explosifs', 'acte_peine_echec', 'utiliser_explosifs', 'type_recherche', 'crime',
    'indices', jsonb_build_object('batiment', m.current_building), 'batiment', m.current_building, 'officiel', v_officiel,
    'jets', CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END));

  IF r ->> 'issue' = 'reussite' THEN
    INSERT INTO public.batiments_fermes (pays, ville, batiment_id, duree_jours, motif, auteur, jour_fin)
    VALUES (m.country, m.current_city, m.current_building, 5, 'explosifs', a, 0);
    FOR v_v IN SELECT name FROM public.personnages_donnees
                WHERE country = m.country AND current_city = m.current_city AND current_building = m.current_building
                  AND current_room IS NOT DISTINCT FROM m.current_room AND name <> a ORDER BY name FOR UPDATE LOOP
      UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), v_sante) WHERE name = v_v.name;
      INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, traite)
      SELECT 'explosion-' || gen_random_uuid(), v_v.name, 'hp_set', hp, false FROM public.personnages_donnees WHERE name = v_v.name;
      PERFORM public.mail_systeme_poser_interne('Événement', v_v.name, 'Explosion !',
        'Une explosion s''est produite dans la pièce où vous vous trouviez. Vous êtes gravement blessé(e).', v_date);
      v_victimes := v_victimes || v_v.name;
    END LOOP;
    PERFORM public.annonce_publique_interne(m.country, 'EXPLOSION : ' || v_nom || ' dévasté par un attentat à l''explosif. Fermé 5 jours.'
      || CASE WHEN array_length(v_victimes, 1) > 0 THEN ' ' || array_length(v_victimes, 1) || ' blessé(s).' ELSE '' END);
    PERFORM public.crime_trace_rumeur_interne(a, 'utiliser_explosifs', m.current_building);
  ELSIF coalesce((r ->> 'echec_critique')::boolean, false) THEN
    -- Explosion prématurée : le poseur seul est blessé (identification et moral par la résolution commune).
    v_prematuree := true;
    UPDATE public.personnages_donnees SET hp = least(coalesce(hp, 100), v_sante) WHERE name = a;
    INSERT INTO public.impacts_indices_attente (id, victime, indice, delta, traite)
    SELECT 'explosion-' || gen_random_uuid(), a, 'hp_set', hp, false FROM public.personnages_donnees WHERE name = a;
  END IF;

  v_out := jsonb_build_object('ok', true, 'batiment', v_nom, 'victimes', jsonb_array_length(to_jsonb(v_victimes)),
             'explosion_prematuree', v_prematuree, 'paie', v_paie)
    || (r - 'notifie' - 'affaire' - 'garde' - 'remarque' - 'taux_combat' - 'jet_combat')
    || (SELECT jsonb_build_object('hp', hp, 'moral', moral, 'recherche', recherche, 'inventaire', inventory, 'inventory', inventory,
                                  'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_explosifs', prm, v_out);
END $$;

-- ── Incendie (§ 11) ─────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crime_incendier(p_nom_batiment text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('batiment', p_nom_batiment); v jsonb; m record; v_paie jsonb;
  v_nom text; v_mode text; v_bidon boolean; v_orage boolean; v_canicule boolean; v_taux integer; r jsonb; v_jours integer := 0; v_out jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crime_incendier', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT country, current_city, current_building, career, est_emprisonne INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(m.est_emprisonne), 'null') <> 'null' AND m.est_emprisonne <> 'false'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  IF coalesce(m.current_building, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_batiment'); END IF;
  v_nom := left(coalesce(nullif(btrim(p_nom_batiment), ''), m.current_building), 80);
  v_paie := public.payer_ordre(a, 'incendier', 3, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  -- Bidon de carburant de la station-service : utilisé d'office s'il est dans l'inventaire, consommé par la tentative.
  v_bidon := public.inventaire_quantite((SELECT inventory FROM public.personnages_donnees WHERE name = a), 'carburant') >= 1;
  IF v_bidon THEN
    UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(inventory, 'carburant', 1) WHERE name = a;
  END IF;
  v_orage := public.crim_climat_actif_interne('orage', m.country, m.current_city);
  v_canicule := public.crim_climat_actif_interne('canicule', m.country, m.current_city);
  v_mode := public.crim_mode_action_interne(a);
  v_taux := public.crim_incendie_taux_interne(public.crim_stat_interne(a, 'dis', 50), v_mode IN ('cache', 'cache_masque'), m.career,
                                              v_bidon, v_orage, v_canicule);
  r := public.crim_resoudre_interne('incendier', a, NULL, jsonb_build_object(
    'taux', v_taux, 'min', public.crim_param_interne('incendie_min', 5), 'max', public.crim_param_interne('incendie_max', 80), 'mode', v_mode,
    'detection_base', public.crim_param_interne('incendie_detection', 70), 'detection_min', public.crim_param_interne('incendie_detection_min', 20),
    'acte_peine_reussite', 'incendier', 'acte_peine_echec', 'incendier', 'type_recherche', 'crime',
    'indices', jsonb_build_object('batiment', m.current_building), 'batiment', m.current_building,
    'bidon', v_bidon, 'orage', v_orage, 'canicule', v_canicule,
    'jets', CASE WHEN session_user = 'postgres' THEN nullif(current_setting('rp.crim_jets', true), '')::jsonb END));

  IF r ->> 'issue' = 'reussite' THEN
    v_jours := greatest(1, public.crim_incendie_jours_interne((r ->> 'jet')::numeric, (r ->> 'taux')::numeric));
    INSERT INTO public.batiments_fermes (pays, ville, batiment_id, duree_jours, motif, auteur, jour_fin)
    VALUES (m.country, m.current_city, m.current_building, v_jours, 'incendie', a, 0);
    PERFORM public.annonce_publique_interne(m.country, 'INCENDIE : ' || v_nom || ' ravagé par les flammes. Fermé ' || v_jours || ' jour(s).');
    PERFORM public.crime_trace_rumeur_interne(a, 'incendier', m.current_building);
  END IF;

  v_out := jsonb_build_object('ok', true, 'batiment', v_nom, 'jours', v_jours, 'bidon', v_bidon, 'orage', v_orage, 'canicule', v_canicule,
             'paie', v_paie)
    || (r - 'notifie' - 'affaire' - 'garde' - 'remarque' - 'taux_combat' - 'jet_combat')
    || (SELECT jsonb_build_object('moral', moral, 'recherche', recherche, 'inventory', inventory, 'revision', inventory_revision)
          FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_incendier', prm, v_out);
END $$;

-- ── Anciennes routes (sans clé d'unicité) : remplacées ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crime_empoisonner(p_cible text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'requete_requise');
$$;
CREATE OR REPLACE FUNCTION public.crime_explosifs(p_nom_batiment text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'requete_requise');
$$;
CREATE OR REPLACE FUNCTION public.crime_incendier(p_nom_batiment text DEFAULT NULL::text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'requete_requise');
$$;

-- ── Droits ──────────────────────────────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['crim_bonus_dis_interne(numeric)', 'crim_climat_actif_interne(text,text,text)',
    'crim_batiment_officiel_interne(text)', 'crim_a_bu_interne(text)',
    'crim_empoisonner_taux_interne(numeric,numeric,boolean,text,text,boolean,text)',
    'crim_explosifs_taux_interne(numeric,numeric,boolean,text,boolean)',
    'crim_incendie_taux_interne(numeric,boolean,text,boolean,boolean,boolean)',
    'crim_empoisonner_palier_interne(numeric,numeric)', 'crim_incendie_jours_interne(numeric,numeric)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY['crime_empoisonner(text,uuid)', 'crime_explosifs(text,uuid)', 'crime_incendier(text,uuid)',
    'crime_empoisonner(text)', 'crime_explosifs(text)', 'crime_incendier(text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

COMMIT;
