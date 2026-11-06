-- APPLIQUEE le 04/11/2026 par Claude (registre serrures_porte_armoire_20261104124400), structure eprouvee en transaction annulee
-- avant application, puis banc annule outils/bancs/banc-serrures.sql joue en production : vert.
-- 4 novembre 2026 -- SERRURES, etape 5 : la porte fermee a cle et l'armoire installable (issue #434).
--
--   * navigation_interieure_personnage_interne (patch en place, marque serrure_porte_v1) : un
--     lieu dont la serrure est fermee refuse l'entree a qui ne detient pas une de ses cles
--     (« porte_fermee_a_cle ») ; on sort toujours ; le detenteur d'une cle entre et la porte reste
--     fermee derriere lui. Une serrure dont le bail a pris fin est d'abord detruite.
--   * Armoire a souvenirs (decision du 04/11) : meme mecanique que l'ordinateur et la box --
--     equipement_installer accepte l'armoire (objet de type armoire_souvenirs, plusieurs par piece
--     possibles, un identifiant d'objet lui est donne a l'installation) ; equipement_desinstaller
--     tient compte de son encombrement (3) et refuse une armoire fermee a cle ;
--     equipements_local_lire la propose et decrit les serrures du local ; la passe de nuit
--     (equipements_jouissance_nuit, 48 h) la nomme et detruit les serrures des baux finis.
-- Idempotente : chaque patch est reconnu a sa marque.

CREATE OR REPLACE FUNCTION public.serrure_porte_fermee_interne(p_nom text, p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id uuid;
BEGIN
  IF p_batiment IS NULL OR p_piece IS NULL THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.serrures WHERE statut = 'posee' AND cible = 'lieu' AND fermee
                   AND (pays, ville, batiment, piece) = (p_pays, p_ville, p_batiment, p_piece)) THEN RETURN false; END IF;
  PERFORM public.serrures_fin_bail_interne(p_pays, p_ville, p_batiment, p_piece);
  SELECT id INTO v_id FROM public.serrures WHERE statut = 'posee' AND cible = 'lieu' AND fermee
     AND (pays, ville, batiment, piece) = (p_pays, p_ville, p_batiment, p_piece);
  RETURN v_id IS NOT NULL AND NOT public.serrure_cle_detenue_interne(p_nom, v_id);
END $$;

CREATE OR REPLACE FUNCTION public.serrure_resume_interne(s public.serrures, p_acteur text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN s.id IS NULL THEN NULL ELSE jsonb_build_object('id', s.id, 'numero', public.serrure_numero_interne(s.id),
    'fermee', s.fermee, 'a_cle', public.serrure_cle_detenue_interne(p_acteur, s.id)) END;
$$;

-- Serrures du local : celle du lieu, et ce que le PJ peut y poser (lieu, armoires).
CREATE OR REPLACE FUNCTION public.serrures_local_lire_interne(p_acteur text, p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE s public.serrures; v_jouit boolean;
BEGIN
  PERFORM public.serrures_fin_bail_interne(p_pays, p_ville, p_batiment, p_piece);
  SELECT * INTO s FROM public.serrures WHERE statut = 'posee' AND cible = 'lieu'
     AND (pays, ville, batiment, piece) = (p_pays, p_ville, p_batiment, p_piece);
  v_jouit := public.local_jouissance_interne(p_acteur, p_pays, p_ville, p_batiment, p_piece);
  RETURN jsonb_build_object(
    'lieu', public.serrure_resume_interne(s, p_acteur),
    'lieu_posable', s.id IS NULL AND v_jouit AND p_batiment !~* '(hotel|clinique|hopital)',
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

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
  IF strpos(v_def, 'serrure_porte_v1') = 0 THEN
    v_new := replace(v_def, $a$ -- blocus_syndical_v1$a$,
$b$ -- serrure_porte_v1 (04/11/2026) : un lieu ferme a cle ne s'ouvre qu'a qui en detient une cle.
 IF (p.current_building IS DISTINCT FROM p_batiment OR p.current_room IS DISTINCT FROM p_piece)
    AND public.serrure_porte_fermee_interne(p_nom, p.country, p.current_city, p_batiment, p_piece) THEN
  RETURN jsonb_build_object('ok',false,'raison','porte_fermee_a_cle'); END IF;
 -- blocus_syndical_v1$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch navigation non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.equipement_installer(text)'::regprocedure);
  IF strpos(v_def, 'armoire_souvenirs') = 0 THEN
    v_new := replace(replace(replace(v_def,
      $a$p_generique NOT IN ('ordinateur-complet', 'box-internet')$a$,
      $b$p_generique NOT IN ('ordinateur-complet', 'box-internet', 'armoire_souvenirs')$b$),
      $a$WHERE proprietaire = v_moi AND generique_id = p_generique$a$,
      $b$WHERE proprietaire = v_moi AND generique_id = p_generique AND p_generique <> 'armoire_souvenirs'$b$),
      $a$WHERE o.val->>'generique_id' = p_generique ORDER BY o.ord LIMIT 1;$a$,
      $b$WHERE coalesce(o.val->>'generique_id', o.val->>'type') = p_generique ORDER BY o.ord LIMIT 1;
  IF coalesce(v_obj->>'id', '') = '' THEN v_obj := v_obj || jsonb_build_object('id', 'obj-' || replace(gen_random_uuid()::text, '-', '')); END IF;$b$);
    IF (length(v_new) - length(v_def)) < 200 THEN RAISE EXCEPTION 'patch equipement_installer incomplet'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.equipement_desinstaller(uuid)'::regprocedure);
  IF strpos(v_def, 'armoire_fermee_a_cle') = 0 THEN
    v_new := replace(v_def,
      $a$  IF public.inventaire_place_restante((SELECT inventory FROM public.personnages_donnees WHERE name = v_moi)) < 1 THEN$a$,
      $b$  IF EXISTS (SELECT 1 FROM public.serrures x WHERE x.statut = 'posee' AND x.cible = 'armoire' AND x.fermee
               AND x.armoire_objet = e.objet->>'id') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'armoire_fermee_a_cle'); END IF;
  IF public.inventaire_place_restante((SELECT inventory FROM public.personnages_donnees WHERE name = v_moi))
     < greatest(1, coalesce(nullif(e.objet->>'encombrement', '')::integer, 1)) THEN$b$);
    IF v_new = v_def THEN RAISE EXCEPTION 'patch equipement_desinstaller non applique'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.equipements_local_lire()'::regprocedure);
  IF strpos(v_def, 'serrures_local_lire_interne') = 0 THEN
    v_new := replace(replace(v_def,
      $a$'a_moi', public.equipement_a_moi_interne(e.proprietaire, v_moi),$a$,
      $b$'a_moi', public.equipement_a_moi_interne(e.proprietaire, v_moi),
                              'serrure', public.serrure_resume_interne((SELECT x FROM public.serrures x WHERE x.statut = 'posee'
                                           AND x.cible = 'armoire' AND x.armoire_objet = e.objet->>'id'), v_moi),$b$),
      $a$WHERE o->>'generique_id' IN ('ordinateur-complet', 'box-internet')), '[]'::jsonb));$a$,
      $b$WHERE coalesce(o->>'generique_id', o->>'type') IN ('ordinateur-complet', 'box-internet', 'armoire_souvenirs')), '[]'::jsonb),
    'serrures', public.serrures_local_lire_interne(v_moi, d.country, d.current_city, d.current_building, d.current_room));$b$);
    IF (length(v_new) - length(v_def)) < 300 THEN RAISE EXCEPTION 'patch equipements_local_lire incomplet'; END IF;
    EXECUTE v_new;
  END IF;

  v_def := pg_get_functiondef('public.equipements_jouissance_nuit()'::regprocedure);
  IF strpos(v_def, 'serrures_fin_bail_interne') = 0 THEN
    v_new := replace(replace(v_def,
      $a$WHEN 'box-internet' THEN 'votre box internet'$a$,
      $b$WHEN 'box-internet' THEN 'votre box internet'
                                       WHEN 'armoire_souvenirs' THEN 'votre armoire à souvenirs'$b$),
      $a$  DELETE FROM public.bureaux_option_premium b$a$,
      $b$  PERFORM public.serrures_fin_bail_interne();
  DELETE FROM public.bureaux_option_premium b$b$);
    IF (length(v_new) - length(v_def)) < 100 THEN RAISE EXCEPTION 'patch equipements_jouissance_nuit incomplet'; END IF;
    EXECUTE v_new;
  END IF;
END $mig$;

-- equipements_local_lire est STABLE : elle appelle desormais un moteur qui detruit les serrures
-- des baux finis. Elle devient VOLATILE (le patch ci-dessus la recree a l'identique sinon).
ALTER FUNCTION public.equipements_local_lire() VOLATILE;

REVOKE ALL ON FUNCTION public.serrure_porte_fermee_interne(text, text, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrure_resume_interne(public.serrures, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrures_local_lire_interne(text, text, text, text, text) FROM PUBLIC, anon, authenticated;
