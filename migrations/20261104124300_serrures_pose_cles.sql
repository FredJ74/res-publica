-- APPLIQUEE le 04/11/2026 par Claude (registre serrures_pose_cles_20261104124300), structure eprouvee en transaction annulee
-- avant application, puis banc annule outils/bancs/banc-serrures.sql joue en production : vert.
-- 4 novembre 2026 -- SERRURES, etape 4 : poser, fermer/ouvrir, dupliquer (issue #434).
--
-- Decisions de Fred : la serrure se pose depuis l'inventaire, sur place, jamais a distance, sur
-- une armoire a souvenirs installee, un local ou un appartement dont le PJ a la jouissance
-- (chambres d'hotel et de clinique exclues ; pas de cible « autre ») ; une fois posee, une cle
-- la ferme ou l'ouvre (04/11) ; une cle vierge taillee sur une cle detenue devient un double,
-- sans autre frais ; doubles illimites ; la cle ouvre pour qui la detient.
--
--   serrure_poser(requete, serrure, cible, equipement) : consomme le bloc, pose la serrure
--     (ouverte), retient le bail du lieu ; une seule serrure par lieu et par armoire.
--   serrure_basculer(serrure, fermer) : cle detenue exigee ; lieu : dans le meme batiment
--     (on ferme sa porte de l'interieur comme du couloir) ; armoire : dans la piece ou elle est
--     installee, ou portee sur soi.
--   cle_dupliquer(requete, serrure) : une cle detenue + une cle vierge -> un double.
--   serrure_etat(serrure) : ce que sait le detenteur d'une cle ou du bloc.
-- Une serrure de lieu dont le bail a pris fin est detruite des qu'on la touche
-- (serrures_fin_bail_interne), avant tout effet.

CREATE OR REPLACE FUNCTION public.serrure_poser(p_requete uuid, p_serrure uuid, p_cible text, p_equipement uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); prm jsonb; v jsonb; s public.serrures; d record;
  v_pos integer; e public.equipements_installes; v_bail text; v_tit text;
BEGIN
  prm := jsonb_build_object('serrure', p_serrure, 'cible', p_cible, 'equipement', p_equipement);
  v := public.achat_requete_ouvrir_interne(v_moi, p_requete, 'serrure_poser', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_cible IS NULL OR p_cible NOT IN ('lieu', 'armoire') THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  SELECT * INTO s FROM public.serrures WHERE id = p_serrure FOR UPDATE;
  IF s.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'serrure_introuvable'); END IF;
  IF s.statut <> 'neuve' THEN RETURN jsonb_build_object('ok', false, 'raison', 'serrure_deja_posee'); END IF;
  SELECT country, current_city, current_building, current_room, inventory INTO d
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT (o.ord - 1)::integer INTO v_pos
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END)
         WITH ORDINALITY o(val, ord)
   WHERE o.val->>'type' = 'serrure_cle' AND o.val->>'serrureId' = p_serrure::text ORDER BY o.ord LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_local'); END IF;

  IF p_cible = 'lieu' THEN
    IF d.current_building ~* '(hotel|clinique|hopital)' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_exclue'); END IF;
    IF NOT public.local_jouissance_interne(v_moi, d.country, d.current_city, d.current_building, d.current_room) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jouissance'); END IF;
    v_bail := d.country || ':' || d.current_building || ':' || d.current_room || ':' || d.current_city;
    SELECT coalesce(nullif(l.data->>'orgaId', ''), replace(coalesce(l.data->>'locataire', ''), 'pj:', '')) INTO v_tit
      FROM public.locations_actives l WHERE l.id = v_bail;
    PERFORM public.serrures_fin_bail_interne(d.country, d.current_city, d.current_building, d.current_room);
    IF EXISTS (SELECT 1 FROM public.serrures WHERE statut = 'posee' AND cible = 'lieu' AND pays = d.country
                 AND ville = d.current_city AND batiment = d.current_building AND piece = d.current_room) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_une_serrure'); END IF;
    UPDATE public.serrures SET statut = 'posee', fermee = false, cible = 'lieu', pays = d.country, ville = d.current_city,
           batiment = d.current_building, piece = d.current_room, bail_ref = v_bail, bail_titulaire = v_tit,
           poseur = v_moi, posee_le = now() WHERE id = s.id;
  ELSE
    SELECT * INTO e FROM public.equipements_installes WHERE id = p_equipement FOR UPDATE;
    IF e.id IS NULL OR e.generique_id <> 'armoire_souvenirs' THEN RETURN jsonb_build_object('ok', false, 'raison', 'armoire_introuvable'); END IF;
    IF (e.pays, e.ville, e.batiment, e.piece) IS DISTINCT FROM (d.country, d.current_city, d.current_building, d.current_room) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
    IF NOT public.equipement_a_moi_interne(e.proprietaire, v_moi) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
    IF NOT public.local_jouissance_interne(v_moi, e.pays, e.ville, e.batiment, e.piece) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_jouissance'); END IF;
    IF coalesce(e.objet->>'id', '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'armoire_introuvable'); END IF;
    IF EXISTS (SELECT 1 FROM public.serrures WHERE statut = 'posee' AND cible = 'armoire' AND armoire_objet = e.objet->>'id') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_une_serrure'); END IF;
    UPDATE public.serrures SET statut = 'posee', fermee = false, cible = 'armoire', pays = e.pays, ville = e.ville,
           batiment = e.batiment, piece = e.piece, armoire_objet = e.objet->>'id', poseur = v_moi, posee_le = now()
     WHERE id = s.id;
  END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer_position(inventory, v_pos) WHERE name = v_moi;
  RETURN public.achat_requete_clore_interne(v_moi, p_requete, 'serrure_poser', prm,
    jsonb_build_object('ok', true, 'serrure', p_serrure, 'numero', public.serrure_numero_interne(p_serrure), 'cible', p_cible));
END $$;

-- Ou se trouve, pour la verification de presence, la serrure d'une armoire.
CREATE OR REPLACE FUNCTION public.serrure_armoire_a_portee_interne(p_acteur text, p_objet text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.equipements_installes e, public.personnages_donnees d
                  WHERE d.name = p_acteur AND e.objet->>'id' = p_objet AND e.pays = d.country
                    AND e.ville = d.current_city AND e.batiment = d.current_building AND e.piece = d.current_room)
      OR EXISTS (SELECT 1 FROM public.personnages_donnees d,
                   jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) o
                  WHERE d.name = p_acteur AND o->>'id' = p_objet);
$$;

CREATE OR REPLACE FUNCTION public.serrure_basculer(p_serrure uuid, p_fermer boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); s public.serrures; d record;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_fermer IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  SELECT * INTO s FROM public.serrures WHERE id = p_serrure;
  IF s.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'serrure_introuvable'); END IF;
  IF s.cible = 'lieu' THEN PERFORM public.serrures_fin_bail_interne(s.pays, s.ville, s.batiment, s.piece); END IF;
  SELECT * INTO s FROM public.serrures WHERE id = p_serrure FOR UPDATE;
  IF s.statut = 'detruite' THEN RETURN jsonb_build_object('ok', false, 'raison', 'serrure_detruite'); END IF;
  IF s.statut <> 'posee' THEN RETURN jsonb_build_object('ok', false, 'raison', 'serrure_non_posee'); END IF;
  IF NOT public.serrure_cle_detenue_interne(v_moi, s.id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'cle_requise'); END IF;
  SELECT country, current_city, current_building INTO d FROM public.personnages_donnees WHERE name = v_moi;
  IF s.cible = 'lieu' AND (d.country, d.current_city, d.current_building) IS DISTINCT FROM (s.pays, s.ville, s.batiment) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF s.cible = 'armoire' AND NOT public.serrure_armoire_a_portee_interne(v_moi, s.armoire_objet) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  UPDATE public.serrures SET fermee = p_fermer WHERE id = s.id;
  RETURN jsonb_build_object('ok', true, 'serrure', s.id, 'numero', public.serrure_numero_interne(s.id), 'fermee', p_fermer, 'cible', s.cible);
END $$;

REVOKE ALL ON FUNCTION public.serrure_armoire_a_portee_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.serrure_poser(uuid, uuid, text, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.serrure_basculer(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.serrure_poser(uuid, uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.serrure_basculer(uuid, boolean) TO authenticated;
