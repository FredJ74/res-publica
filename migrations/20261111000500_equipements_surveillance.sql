-- MATERIELS PAR COMBINAISON, ETAPE 1 : SURVEILLANCE, FOUILLER LES LIEUX, COUINATOR 3000 (decisions de Fred du 31/10 et
-- du 10/11/2026, GAME-DESIGN-EQUIPEMENTS.md, decisions 1 a 5 ; feu vert pour la session de nuit a 23 h 42).
--  * Surveillance = ordinateur + box installes dans un bureau dont le proprietaire a la jouissance + camera ; 8 cameras par
--    ordinateur connecte (un bureau equipe des deux = un ordinateur connecte).
--  * Une camera se pose dans une piece ou une vue de rue (batiment « rue-centrale », piece = noeud de rue), 1 PA, reussit
--    toujours ; legale dans un batiment dont on est proprietaire foncier, sinon acte illegal : trace, detection commune
--    (actes_illegaux « poser_camera », delit mineur), repere = flagrant delit au bareme du delit mineur et camera saisie.
--  * Reprendre sa camera : 1 PA, sur place. Frequence des rapports : 1 a 24 h, reglee par le proprietaire.
--  * Rapports par mail : PJ passes (historique_deplacements, heures d'entree et de sortie) et actes illegaux commis sur place
--    pendant leur presence (traces serveur datees), jamais les PNJ ordinaires. Passe horaire (pg_cron).
--  * Fouiller les lieux : 2 PA, chaque camera cachee trouvee a 15 % a mains nues, 75 % avec le Couinator 3000 (objet de
--    l'inventaire), +/- (PER - 10). Camera trouvee : detruite ou emportee (vol trace, sauf chez soi) ; le proprietaire recoit
--    « Signal perdu » sans le nom ; celui qui trouve ne connait pas le proprietaire.
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;

INSERT INTO public.actes_illegaux (fn, type, detect_rate, decouvrable)
VALUES ('poser_camera', 'delit_mineur', 30, false) ON CONFLICT (fn) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.cameras_posees (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proprietaire  text NOT NULL,
  objet         jsonb NOT NULL,
  pays          text NOT NULL,
  ville         text NOT NULL,
  batiment      text NOT NULL,
  piece         text NOT NULL,
  libelle       text,
  legale        boolean NOT NULL DEFAULT false,
  frequence_h   integer NOT NULL DEFAULT 24 CHECK (frequence_h BETWEEN 1 AND 24),
  posee_le      timestamptz NOT NULL DEFAULT now(),
  dernier_rapport timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cameras_posees_lieu ON public.cameras_posees (pays, ville, batiment, piece);
CREATE INDEX IF NOT EXISTS cameras_posees_proprietaire ON public.cameras_posees (proprietaire);
ALTER TABLE public.cameras_posees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cameras_posees FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.cameras_decouvertes (
  acteur      text NOT NULL,
  camera_id   uuid NOT NULL,
  trouvee_le  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur, camera_id)
);
ALTER TABLE public.cameras_decouvertes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cameras_decouvertes FROM anon, authenticated;

-- Lieu d'un PJ, rue comprise (la rue se note batiment « rue-centrale », piece = noeud, comme historique_deplacements).
CREATE OR REPLACE FUNCTION public.surveillance_lieu_interne(p_acteur text)
RETURNS TABLE(pays text, ville text, batiment text, piece text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT pd.country, pd.current_city,
         CASE WHEN pd.current_building IS NOT NULL AND pd.current_room IS NOT NULL THEN pd.current_building
              WHEN pd.current_street IS NOT NULL THEN 'rue-centrale' END,
         CASE WHEN pd.current_building IS NOT NULL AND pd.current_room IS NOT NULL THEN pd.current_room
              ELSE pd.current_street END
    FROM public.personnages_donnees pd WHERE pd.name = p_acteur;
$$;

-- Nombre d'ordinateurs connectes d'un proprietaire : bureaux ou il a ordinateur ET box installes, jouissance valide.
CREATE OR REPLACE FUNCTION public.equipements_ordinateurs_connectes_interne(p_proprietaire text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT count(*)::integer FROM (
    SELECT e.pays, e.ville, e.batiment, e.piece FROM public.equipements_installes e
     WHERE e.proprietaire = p_proprietaire AND e.generique_id IN ('ordinateur-complet', 'box-internet')
     GROUP BY e.pays, e.ville, e.batiment, e.piece
    HAVING count(DISTINCT e.generique_id) = 2
       AND (left(p_proprietaire, 5) = 'orga:'
            OR public.local_jouissance_interne(p_proprietaire, e.pays, e.ville, e.batiment, e.piece))) x;
$$;

-- Une camera est operationnelle si son rang (par date de pose) tient dans 8 x ordinateurs connectes.
CREATE OR REPLACE FUNCTION public.camera_operationnelle_interne(p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT r.rang <= 8 * public.equipements_ordinateurs_connectes_interne(r.proprietaire)
                     FROM (SELECT c.id, c.proprietaire,
                                  row_number() OVER (PARTITION BY c.proprietaire ORDER BY c.posee_le, c.id) AS rang
                             FROM public.cameras_posees c
                            WHERE c.proprietaire = (SELECT proprietaire FROM public.cameras_posees WHERE id = p_id)) r
                    WHERE r.id = p_id), false);
$$;

CREATE OR REPLACE FUNCTION public.camera_resume_interne(c public.cameras_posees)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('id', c.id, 'lieu', coalesce(c.libelle, c.batiment || ' / ' || c.piece), 'ville', c.ville, 'pays', c.pays,
    'batiment', c.batiment, 'piece', c.piece, 'frequence', c.frequence_h, 'legale', c.legale,
    'operationnelle', public.camera_operationnelle_interne(c.id), 'posee_le', c.posee_le);
$$;

-- Lecture : mes cameras ici, toutes mes cameras, capacite, cameras de l'inventaire, Couinator.
CREATE OR REPLACE FUNCTION public.cameras_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); l record; v_inv jsonb; n integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO l FROM public.surveillance_lieu_interne(a);
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv
    FROM public.personnages_donnees WHERE name = a;
  n := public.equipements_ordinateurs_connectes_interne(a);
  RETURN jsonb_build_object('ok', true,
    'ici', coalesce((SELECT jsonb_agg(public.camera_resume_interne(c) ORDER BY c.posee_le) FROM public.cameras_posees c
                      WHERE c.proprietaire = a AND c.pays = l.pays AND c.ville = l.ville AND c.batiment = l.batiment AND c.piece = l.piece), '[]'::jsonb),
    'toutes', coalesce((SELECT jsonb_agg(public.camera_resume_interne(c) ORDER BY c.posee_le) FROM public.cameras_posees c
                         WHERE c.proprietaire = a), '[]'::jsonb),
    'ordinateurs_connectes', n, 'capacite', 8 * n,
    'cameras_inventaire', (SELECT count(*) FROM jsonb_array_elements(v_inv) o WHERE o->>'generique_id' = 'camera-de-surveillance'),
    'couinator', EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) o WHERE o->>'generique_id' = 'couinator-3000'),
    'lieu_valide', l.batiment IS NOT NULL AND l.piece IS NOT NULL);
END $$;
REVOKE ALL ON FUNCTION public.cameras_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cameras_lire() TO authenticated;

-- Poser une camera ici.
CREATE OR REPLACE FUNCTION public.camera_poser(p_libelle text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); l record; d record; v_pos integer; v_obj jsonb; n integer; v_proprio text;
        v_legale boolean; v_det boolean := false; v_arr jsonb; v_id uuid;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('cameras:' || a, 0));
  SELECT name, pa, est_emprisonne, inventory INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(d.est_emprisonne), 'null') <> 'null' AND d.est_emprisonne <> 'false'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  SELECT * INTO l FROM public.surveillance_lieu_interne(a);
  IF l.batiment IS NULL OR l.piece IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide'); END IF;
  SELECT (o.ord - 1)::integer, o.val INTO v_pos, v_obj
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) WITH ORDINALITY o(val, ord)
   WHERE o.val->>'generique_id' = 'camera-de-surveillance' ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_camera'); END IF;
  n := public.equipements_ordinateurs_connectes_interne(a);
  IF n = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_ordinateur_connecte'); END IF;
  IF (SELECT count(*) FROM public.cameras_posees WHERE proprietaire = a) >= 8 * n THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_cameras', 'capacite', 8 * n); END IF;
  IF coalesce(d.pa, 0) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  v_proprio := public.local_proprietaire_foncier_interne(l.pays, l.ville, l.batiment, l.piece);
  v_legale := l.batiment <> 'rue-centrale' AND v_proprio IN (a, 'pj:' || a);
  UPDATE public.personnages_donnees SET pa = pa - 1, inventory = inventory - v_pos WHERE name = a;
  INSERT INTO public.cameras_posees (proprietaire, objet, pays, ville, batiment, piece, libelle, legale)
  VALUES (a, v_obj, l.pays, l.ville, l.batiment, l.piece, left(nullif(btrim(coalesce(p_libelle, '')), ''), 80), v_legale)
  RETURNING id INTO v_id;
  IF NOT v_legale THEN
    PERFORM public.crime_tracer_interne(a, 'poser_camera', coalesce(left(nullif(btrim(p_libelle), ''), 80), 'caméra de surveillance'));
    v_det := public.crime_detecter_interne(a, 'poser_camera', true);
    IF v_det THEN
      DELETE FROM public.cameras_posees WHERE id = v_id;
      v_arr := public.arrestation_flagrant_interne(a, 'poser_camera', false, 'poser_camera',
                 'Surpris en train de poser une caméra de surveillance');
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'legale', v_legale, 'repere', v_det, 'arrestation', v_arr, 'pa', d.pa - 1,
                            'camera', CASE WHEN v_det THEN NULL ELSE v_id END)
      || public.crime_etat_acteur_interne(a)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
END $$;
REVOKE ALL ON FUNCTION public.camera_poser(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.camera_poser(text) TO authenticated;

-- Reprendre sa camera (sur place).
CREATE OR REPLACE FUNCTION public.camera_reprendre(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); l record; c public.cameras_posees; d record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT name, pa, inventory INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  SELECT * INTO c FROM public.cameras_posees WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'camera_introuvable'); END IF;
  IF NOT public.equipement_a_moi_interne(c.proprietaire, a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  SELECT * INTO l FROM public.surveillance_lieu_interne(a);
  IF (l.pays, l.ville, l.batiment, l.piece) IS DISTINCT FROM (c.pays, c.ville, c.batiment, c.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF coalesce(d.pa, 0) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  IF public.inventaire_place_restante(d.inventory) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  DELETE FROM public.cameras_posees WHERE id = c.id;
  DELETE FROM public.cameras_decouvertes WHERE camera_id = c.id;
  UPDATE public.personnages_donnees SET pa = pa - 1,
         inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END) || jsonb_build_array(c.objet)
   WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'pa', d.pa - 1)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
END $$;
REVOKE ALL ON FUNCTION public.camera_reprendre(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.camera_reprendre(uuid) TO authenticated;

-- Frequence des rapports (1 a 24 h), depuis n'importe ou.
CREATE OR REPLACE FUNCTION public.camera_frequence(p_id uuid, p_heures integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); c public.cameras_posees;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_heures IS NULL OR p_heures < 1 OR p_heures > 24 THEN RETURN jsonb_build_object('ok', false, 'raison', 'frequence_invalide'); END IF;
  SELECT * INTO c FROM public.cameras_posees WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'camera_introuvable'); END IF;
  IF NOT public.equipement_a_moi_interne(c.proprietaire, a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  UPDATE public.cameras_posees SET frequence_h = p_heures WHERE id = c.id;
  RETURN jsonb_build_object('ok', true, 'frequence', p_heures);
END $$;
REVOKE ALL ON FUNCTION public.camera_frequence(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.camera_frequence(uuid, integer) TO authenticated;

-- Fouiller les lieux.
CREATE OR REPLACE FUNCTION public.fouiller_lieux()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); l record; d record; v_couin boolean; v_mod integer; v_taux integer;
        c public.cameras_posees; v_trouvees jsonb := '[]'::jsonb; v_n integer := 0;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT name, pa, stats, inventory, est_emprisonne INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(jsonb_typeof(d.est_emprisonne), 'null') <> 'null' AND d.est_emprisonne <> 'false'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'emprisonne'); END IF;
  SELECT * INTO l FROM public.surveillance_lieu_interne(a);
  IF l.batiment IS NULL OR l.piece IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide'); END IF;
  IF coalesce(d.pa, 0) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  v_couin := EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) o
                      WHERE o->>'generique_id' = 'couinator-3000');
  v_mod := coalesce(CASE WHEN coalesce(d.stats->>'PER', '') ~ '^-?[0-9]+(\.[0-9]+)?$' THEN floor((d.stats->>'PER')::numeric)::integer END, 10) - 10;
  v_taux := greatest(1, least(99, CASE WHEN v_couin THEN 75 ELSE 15 END + v_mod));
  UPDATE public.personnages_donnees SET pa = pa - 2 WHERE name = a;
  FOR c IN SELECT * FROM public.cameras_posees
            WHERE pays = l.pays AND ville = l.ville AND batiment = l.batiment AND piece = l.piece
              AND NOT public.equipement_a_moi_interne(proprietaire, a) ORDER BY posee_le FOR UPDATE LOOP
    v_n := v_n + 1;
    IF floor(random() * 100)::integer + 1 <= v_taux THEN
      INSERT INTO public.cameras_decouvertes (acteur, camera_id) VALUES (a, c.id)
      ON CONFLICT (acteur, camera_id) DO UPDATE SET trouvee_le = now();
      v_trouvees := v_trouvees || jsonb_build_array(jsonb_build_object('id', c.id));
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'couinator', v_couin, 'taux', v_taux, 'trouvees', v_trouvees,
                            'nb', jsonb_array_length(v_trouvees), 'pa', d.pa - 2);
END $$;
REVOKE ALL ON FUNCTION public.fouiller_lieux() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fouiller_lieux() TO authenticated;

-- Camera trouvee : detruire ou emporter.
CREATE OR REPLACE FUNCTION public.camera_trouvee_traiter(p_id uuid, p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); l record; c public.cameras_posees; d record; v_chez_moi boolean; v_proprio text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_action NOT IN ('detruire', 'emporter') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_invalide'); END IF;
  SELECT name, inventory INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF NOT EXISTS (SELECT 1 FROM public.cameras_decouvertes WHERE acteur = a AND camera_id = p_id AND trouvee_le > now() - interval '2 hours') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camera_non_trouvee'); END IF;
  SELECT * INTO c FROM public.cameras_posees WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'camera_introuvable'); END IF;
  SELECT * INTO l FROM public.surveillance_lieu_interne(a);
  IF (l.pays, l.ville, l.batiment, l.piece) IS DISTINCT FROM (c.pays, c.ville, c.batiment, c.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF p_action = 'emporter' AND public.inventaire_place_restante(d.inventory) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  DELETE FROM public.cameras_posees WHERE id = c.id;
  DELETE FROM public.cameras_decouvertes WHERE camera_id = c.id;
  IF p_action = 'emporter' THEN
    v_proprio := public.local_proprietaire_foncier_interne(c.pays, c.ville, c.batiment, c.piece);
    v_chez_moi := c.batiment <> 'rue-centrale' AND v_proprio IN (a, 'pj:' || a);
    UPDATE public.personnages_donnees
       SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END) || jsonb_build_array(c.objet)
     WHERE name = a;
    IF NOT v_chez_moi THEN PERFORM public.crime_tracer_interne(a, 'vol', 'caméra de surveillance'); END IF;
  END IF;
  PERFORM public.mail_systeme_poser_interne('Surveillance', CASE WHEN left(c.proprietaire, 5) = 'orga:' THEN
            coalesce((SELECT o.data::jsonb->>'chef' FROM public.organisations o WHERE o.id = substr(c.proprietaire, 6)), c.proprietaire)
          ELSE c.proprietaire END,
    'Signal perdu — ' || coalesce(c.libelle, c.batiment),
    'Votre caméra posée à « ' || coalesce(c.libelle, c.batiment || ' / ' || c.piece) || ' » ne répond plus. '
      || 'Quelqu''un l''a trouvée. Vous ignorez qui.');
  RETURN jsonb_build_object('ok', true, 'action', p_action)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a)
      || public.crime_etat_acteur_interne(a);
END $$;
REVOKE ALL ON FUNCTION public.camera_trouvee_traiter(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.camera_trouvee_traiter(uuid, text) TO authenticated;

-- Texte du rapport d'une camera sur une periode.
CREATE OR REPLACE FUNCTION public.camera_rapport_texte_interne(c public.cameras_posees, p_depuis timestamptz, p_jusqua timestamptz)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; v text := ''; v_actes text; n integer := 0;
BEGIN
  FOR r IN
    WITH passages AS (
      SELECT h.name, h.created_at AS entree,
             (SELECT min(h2.created_at) FROM public.historique_deplacements h2
               WHERE h2.name = h.name AND h2.created_at > h.created_at) AS sortie
        FROM public.historique_deplacements h
       WHERE h.country = c.pays AND h.city = c.ville AND h.building_id = c.batiment AND h.room_id = c.piece
         AND h.created_at < p_jusqua
         AND h.name IS DISTINCT FROM c.proprietaire
         AND EXISTS (SELECT 1 FROM public.personnages_donnees pd WHERE pd.name = h.name))
    SELECT * FROM passages WHERE coalesce(sortie, p_jusqua) > p_depuis ORDER BY entree
  LOOP
    n := n + 1;
    SELECT string_agg(DISTINCT replace(t->>'acte', '_', ' '), ', ') INTO v_actes
      FROM public.personnages_donnees pd, jsonb_array_elements(CASE WHEN jsonb_typeof(pd.historique_crimes) = 'array' THEN pd.historique_crimes ELSE '[]'::jsonb END) t
     WHERE pd.name = r.name AND t->>'origine' = 'serveur' AND coalesce(t->>'expireTs', '') <> ''
       AND ((t->>'expireTs')::timestamptz - interval '8 days') BETWEEN greatest(r.entree, p_depuis) AND coalesce(r.sortie, p_jusqua);
    v := v || E'\n• ' || r.name || ' — entrée ' || to_char(r.entree AT TIME ZONE 'Europe/Paris', 'DD/MM HH24"h"MI')
           || CASE WHEN r.sortie IS NOT NULL AND r.sortie <= p_jusqua
                   THEN ', sortie ' || to_char(r.sortie AT TIME ZONE 'Europe/Paris', 'DD/MM HH24"h"MI') ELSE ', toujours sur place' END
           || CASE WHEN v_actes IS NOT NULL THEN E'\n   Actes filmés : ' || v_actes ELSE '' END;
  END LOOP;
  IF n = 0 THEN RETURN NULL; END IF;
  RETURN 'Caméra : ' || coalesce(c.libelle, c.batiment || ' / ' || c.piece) || E'\nPériode : '
      || to_char(p_depuis AT TIME ZONE 'Europe/Paris', 'DD/MM HH24"h"MI') || ' – ' || to_char(p_jusqua AT TIME ZONE 'Europe/Paris', 'DD/MM HH24"h"MI')
      || E'\n' || v;
END $$;

-- Passe horaire : un rapport par camera operationnelle dont la periode est ecoulee (seulement s'il y a eu du passage).
CREATE OR REPLACE FUNCTION public.cameras_rapports_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c public.cameras_posees; v_texte text; v_envoyes integer := 0; v_dest text; v_now timestamptz := now();
BEGIN
  FOR c IN SELECT * FROM public.cameras_posees WHERE dernier_rapport + make_interval(hours => frequence_h) <= v_now FOR UPDATE SKIP LOCKED LOOP
    IF public.camera_operationnelle_interne(c.id) THEN
      v_texte := public.camera_rapport_texte_interne(c, c.dernier_rapport, v_now);
      IF v_texte IS NOT NULL THEN
        FOR v_dest IN SELECT * FROM public.equipements_destinataires_interne(c.proprietaire) LOOP
          PERFORM public.mail_systeme_poser_interne('Surveillance', v_dest,
            'Rapport de surveillance — ' || coalesce(c.libelle, c.batiment), v_texte);
        END LOOP;
        v_envoyes := v_envoyes + 1;
      END IF;
    END IF;
    UPDATE public.cameras_posees SET dernier_rapport = v_now WHERE id = c.id;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'rapports', v_envoyes);
END $$;
REVOKE ALL ON FUNCTION public.cameras_rapports_passe() FROM PUBLIC, anon, authenticated;

-- Destinataires des rapports : le PJ proprietaire ; pour une organisation, le chef et les membres autorises (etape 6).
CREATE OR REPLACE FUNCTION public.equipements_destinataires_interne(p_proprietaire text)
RETURNS SETOF text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_proprietaire WHERE left(p_proprietaire, 5) <> 'orga:'
  UNION
  SELECT o.data::jsonb->>'chef' FROM public.organisations o WHERE left(p_proprietaire, 5) = 'orga:' AND o.id = substr(p_proprietaire, 6);
$$;

COMMIT;
