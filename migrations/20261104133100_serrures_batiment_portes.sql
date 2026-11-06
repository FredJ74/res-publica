-- APPLIQUEE le 04/11/2026 par Claude (registre serrures_batiment_portes_20261104133100), structure eprouvee en transaction annulee,
-- banc annule outils/bancs/banc-serrures-batiment.sql vert.
-- 4 novembre 2026 -- SERRURES, etape 7 bis : les portes du batiment entier (issue #434).
-- Suite de 20261104133000_serrures_batiment.sql (decisions de Fred du 04/11, 14 h 27).
--   * navigation_interieure_personnage_interne (marque serrure_batiment_v1) : entrer dans un
--     batiment ferme a cle depuis la rue est refuse a qui n'en a pas de cle (porte_fermee_a_cle).
--   * serrure_poser accepte la cible 'batiment' (integralite de la jouissance exigee) ;
--     serrure_basculer, cle_dupliquer, serrure_etat la traitent comme un lieu (dans le batiment).
--   * lectures : serrures_local_lire_interne (serrure du batiment + pose possible),
--     serrures_portes_lire (toutes les serrures posees du batiment, ouvertes comprises),
--     serrures_batiments_lire (batiments de la ville, pour l'infobulle et le cadenas de la rue).

DO $mig$
DECLARE v_def text; v_new text; f text;
BEGIN
  v_def := pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
  IF strpos(v_def, 'serrure_batiment_v1') = 0 THEN
    v_new := replace(v_def, $a$ -- serrure_porte_v1$a$,
$b$ -- serrure_batiment_v1 (04/11/2026) : un batiment ferme a cle ne s'ouvre qu'a qui en detient une cle.
 IF p.current_building IS DISTINCT FROM p_batiment
    AND public.serrure_batiment_ferme_interne(p_nom, p.country, p.current_city, p_batiment) THEN
  RETURN jsonb_build_object('ok',false,'raison','porte_fermee_a_cle','batiment',true); END IF;
 -- serrure_porte_v1$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch navigation (batiment) non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.serrure_poser(uuid,uuid,text,uuid)'::regprocedure);
  IF strpos(v_def, 'pas_de_jouissance_integrale') = 0 THEN
    v_new := replace(replace(v_def,
      $a$p_cible NOT IN ('lieu', 'armoire')$a$, $b$p_cible NOT IN ('lieu', 'armoire', 'batiment')$b$),
      $a$  ELSE
    SELECT * INTO e FROM public.equipements_installes WHERE id = p_equipement FOR UPDATE;$a$,
      $b$  ELSIF p_cible = 'batiment' THEN
    IF NOT public.batiment_jouissance_integrale_interne(v_moi, d.country, d.current_city, d.current_building) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jouissance_integrale'); END IF;
    PERFORM public.serrures_fin_bail_interne(d.country, d.current_city, d.current_building, NULL);
    IF EXISTS (SELECT 1 FROM public.serrures WHERE statut = 'posee' AND cible = 'batiment' AND pays = d.country
                 AND ville = d.current_city AND batiment = d.current_building) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_une_serrure'); END IF;
    UPDATE public.serrures SET statut = 'posee', fermee = false, cible = 'batiment', pays = d.country, ville = d.current_city,
           batiment = d.current_building, piece = NULL, bail_ref = d.country || '_' || d.current_building, bail_titulaire = v_moi,
           poseur = v_moi, posee_le = now() WHERE id = s.id;
  ELSE
    SELECT * INTO e FROM public.equipements_installes WHERE id = p_equipement FOR UPDATE;$b$);
    IF (length(v_new) - length(v_def)) < 600 THEN RAISE EXCEPTION 'patch serrure_poser incomplet'; END IF;
    EXECUTE v_new;
  END IF;

  FOREACH f IN ARRAY ARRAY['public.serrure_basculer(uuid,boolean)', 'public.cle_dupliquer(uuid,uuid)', 'public.serrure_etat(uuid)'] LOOP
    v_def := pg_get_functiondef(f::regprocedure);
    IF strpos(v_def, $a$s.cible IN ('lieu', 'batiment')$a$) = 0 THEN
      v_new := replace(v_def, $a$s.cible = 'lieu'$a$, $b$s.cible IN ('lieu', 'batiment')$b$);
      IF v_new = v_def THEN RAISE EXCEPTION 'patch % non applique', f; END IF;
      EXECUTE v_new;
    END IF;
  END LOOP;
END $mig$;

CREATE OR REPLACE FUNCTION public.serrures_local_lire_interne(p_acteur text, p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE s public.serrures; b public.serrures; v_jouit boolean;
BEGIN
  PERFORM public.serrures_fin_bail_interne(p_pays, p_ville, p_batiment, p_piece);
  SELECT * INTO s FROM public.serrures WHERE statut = 'posee' AND cible = 'lieu'
     AND (pays, ville, batiment, piece) = (p_pays, p_ville, p_batiment, p_piece);
  SELECT * INTO b FROM public.serrures WHERE statut = 'posee' AND cible = 'batiment'
     AND (pays, ville, batiment) = (p_pays, p_ville, p_batiment);
  v_jouit := public.local_jouissance_interne(p_acteur, p_pays, p_ville, p_batiment, p_piece);
  RETURN jsonb_build_object(
    'lieu', public.serrure_resume_interne(s, p_acteur),
    'lieu_posable', s.id IS NULL AND v_jouit AND p_batiment !~* '(hotel|clinique|hopital)',
    'batiment', public.serrure_resume_interne(b, p_acteur),
    'batiment_posable', b.id IS NULL AND public.batiment_jouissance_integrale_interne(p_acteur, p_pays, p_ville, p_batiment),
    'armoires_posables', coalesce((SELECT jsonb_agg(e.id ORDER BY e.installe_le) FROM public.equipements_installes e
        WHERE (e.pays, e.ville, e.batiment, e.piece) = (p_pays, p_ville, p_batiment, p_piece)
          AND e.generique_id = 'armoire_souvenirs' AND v_jouit AND public.equipement_a_moi_interne(e.proprietaire, p_acteur)
          AND NOT EXISTS (SELECT 1 FROM public.serrures x WHERE x.statut = 'posee' AND x.cible = 'armoire' AND x.armoire_objet = e.objet->>'id')),
      '[]'::jsonb),
    'blocs', coalesce((SELECT jsonb_agg(jsonb_build_object('id', o->>'serrureId', 'numero', o->>'numero'))
        FROM public.personnages_donnees d,
             jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) o
       WHERE d.name = p_acteur AND o->>'type' = 'serrure_cle'), '[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.serrures_portes_lire(p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); d record;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city INTO d FROM public.personnages_donnees WHERE name = v_moi;
  PERFORM public.serrures_fin_bail_interne(d.country, d.current_city, p_batiment, NULL);
  RETURN jsonb_build_object('ok', true, 'batiment', p_batiment,
    'pieces', coalesce((SELECT jsonb_object_agg(x.piece, jsonb_build_object('fermee', x.fermee,
                          'a_cle', public.serrure_cle_detenue_interne(v_moi, x.id)))
                          FROM public.serrures x
                         WHERE x.statut = 'posee' AND x.cible = 'lieu'
                           AND x.pays = d.country AND x.ville = d.current_city AND x.batiment = p_batiment), '{}'::jsonb),
    'entree', (SELECT jsonb_build_object('fermee', x.fermee, 'a_cle', public.serrure_cle_detenue_interne(v_moi, x.id))
                 FROM public.serrures x WHERE x.statut = 'posee' AND x.cible = 'batiment'
                  AND x.pays = d.country AND x.ville = d.current_city AND x.batiment = p_batiment));
END $$;

CREATE OR REPLACE FUNCTION public.serrures_batiments_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); d record; s public.serrures;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city INTO d FROM public.personnages_donnees WHERE name = v_moi;
  FOR s IN SELECT * FROM public.serrures WHERE statut = 'posee' AND cible = 'batiment'
             AND pays = d.country AND ville = d.current_city LOOP
    PERFORM public.serrures_fin_bail_interne(s.pays, s.ville, s.batiment, NULL);
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'pays', d.country, 'ville', d.current_city,
    'batiments', coalesce((SELECT jsonb_object_agg(x.batiment, jsonb_build_object('fermee', x.fermee,
                             'a_cle', public.serrure_cle_detenue_interne(v_moi, x.id)))
                             FROM public.serrures x WHERE x.statut = 'posee' AND x.cible = 'batiment'
                              AND x.pays = d.country AND x.ville = d.current_city), '{}'::jsonb));
END $$;

REVOKE ALL ON FUNCTION public.serrures_batiments_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.serrures_batiments_lire() TO authenticated;
