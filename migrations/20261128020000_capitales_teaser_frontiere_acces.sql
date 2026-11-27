-- Mission du 28/11/2026 (nuit, Claude), étape 3 A — Ouverture en teaser de Ciudad Roja (El Estado) et d'Al Madina (Al-Khalija).
-- Décision 17 de GAME-DESIGN-LANCEMENT.md, à coder le 28/11/2026 :
--   • les frontières des deux empires s'ouvrent pour leurs seules capitales (frontieres_fermees_v1 garde ville_a et ville_b) ;
--   • dans chaque capitale, seuls le centre multimodal et l'hôtel sont ouverts (navigation_lieux_regles.ferme pour les autres) ;
--   • au centre multimodal de ces capitales, seul l'avion vers les autres capitales fonctionne ; bus, train et taxi refusent
--     (« teaser_acces_interdit ») ;
--   • compteur d'ouverture calculé par le serveur (teaser_ouverture_compteur) : 150 PJ actifs (connectés dans les 7 derniers
--     jours, domiciliés dans la ville) dans chacune des six villes de Républia et de Sovarka, ET tous les postes de ministre,
--     de maire et d'adjoint occupés par des joueurs ; le compteur peut redescendre ;
--   • Al Madina : une vue de rue (centre multimodal, Hôtel Royal d'Al-Khalija) ; pièces de l'hôtel : réception, suite,
--     restaurant, salon de thé (ancienne pièce « bar »), salon des gentlemen, hammam des hommes, hammam des femmes ;
--   • accès réservés de l'Hôtel Royal (moteur du Pavillon) : salon des gentlemen et hammam des hommes aux hommes (genre « H »),
--     hammam des femmes aux femmes (genre « F ») ; « Forcer le passage » : 2 PA, 60 % + 4 % par point de VOL au-dessus de 13
--     (− 4 % en dessous) ; échec : 1 jour de prison, sans combat ni amende ; réussite : libre circulation dans les pièces
--     réservées jusqu'à la sortie de l'hôtel, sans être recherché.
--
-- Contrôles en lecture après application :
--   SELECT count(*) FROM public.frontieres_fermees WHERE ville = 'capitale';                                   -- 0
--   SELECT batiment FROM public.navigation_lieux_regles WHERE pays IN ('narco','khalija') AND ville='capitale' AND NOT ferme; -- 2 × 2
--   SELECT position('teaser_transport_v1' in pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure)) > 0;
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> 1 THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de 1 (%)', p_fn, n, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
END $$;

-- 1. Frontières : les capitales s'ouvrent, le reste des deux empires reste fermé.
DELETE FROM public.frontieres_fermees WHERE pays IN ('narco', 'khalija') AND ville = 'capitale';

-- 2. Deux bâtiments ouverts par capitale.
UPDATE public.navigation_lieux_regles SET ferme = (batiment NOT IN ('centre-multinodal-luthecia', 'hotel-republica'))
 WHERE pays IN ('narco', 'khalija') AND ville = 'capitale';
UPDATE public.navigation_lieux_regles
   SET pieces = '["accueil", "chambres", "restaurant", "bar", "salon_gentlemen", "hammam_hommes", "hammam_femmes"]'::jsonb
 WHERE pays = 'khalija' AND ville = 'capitale' AND batiment = 'hotel-republica';

-- 3. Rue d'Al Madina.
INSERT INTO public.rue_noeuds_serveur(country, city, noeud, voisins, directions) VALUES
 ('khalija', 'capitale', 'al-madina-rue', ARRAY[]::text[], '{"liens":{},"parArrivee":{}}'::jsonb)
ON CONFLICT (country, city, noeud) DO UPDATE SET voisins = EXCLUDED.voisins, directions = EXCLUDED.directions;
INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
 ('khalija', 'capitale', 'al-madina-rue', 'centre-multinodal-luthecia'),
 ('khalija', 'capitale', 'al-madina-rue', 'hotel-republica')
ON CONFLICT DO NOTHING;

-- 4. Transports : depuis Ciudad Roja et Al Madina, l'avion seulement.
SELECT pg_temp.rp_remplacer('public.transport_effectuer(text,text,text,uuid)'::regprocedure,
  'SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;',
  'SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF p.country IN (''narco'',''khalija'') AND p_mode IS DISTINCT FROM ''avion'' THEN RETURN jsonb_build_object(''ok'',false,''raison'',''teaser_acces_interdit'');END IF; /* teaser_transport_v1 (Fred, 28/11/2026) */',
  'teaser_transport_v1');

-- 5. Compteur d'ouverture des autres villes (calculé par le serveur ; il peut redescendre).
CREATE OR REPLACE FUNCTION public.teaser_ouverture_compteur()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_villes jsonb; v_postes jsonb; v_ok boolean;
BEGIN
  WITH villes(pays, ville) AS (VALUES ('republic','capitale'),('republic','ville_a'),('republic','ville_b'),
                                      ('soviet','capitale'),('soviet','ville_a'),('soviet','ville_b')),
  actifs AS (
    SELECT v.pays, v.ville, count(p.name) AS n
      FROM villes v LEFT JOIN public.personnages_donnees p
        ON p.user_id IS NOT NULL AND p.domicile ->> 'country' = v.pays AND p.domicile ->> 'city' = v.ville
       AND p.updated_at >= now() - interval '7 days'
     GROUP BY v.pays, v.ville)
  SELECT jsonb_agg(jsonb_build_object('pays', pays, 'ville', ville, 'actifs', n, 'requis', 150, 'atteint', n >= 150)
                   ORDER BY pays DESC, ville) INTO v_villes FROM actifs;
  WITH postes(pays, poste, ville) AS (
    SELECT c.pays, m.poste, NULL::text FROM (VALUES ('republic'),('soviet')) c(pays),
           (VALUES ('min_ae'),('min_def'),('min_fin'),('min_info'),('min_int'),('min_just')) m(poste)
    UNION ALL
    SELECT c.pays, m.poste, v.ville FROM (VALUES ('republic'),('soviet')) c(pays), (VALUES ('maire'),('maire_adjoint')) m(poste),
           (VALUES ('capitale'),('ville_a'),('ville_b')) v(ville)),
  occ AS (
    SELECT po.pays, po.poste, po.ville,
           (SELECT d.name FROM public.personnages_donnees d
             WHERE d.user_id IS NOT NULL AND d.poste ->> 'id' = po.poste
               AND coalesce(public.poste_pays_de(d.name), d.country) = po.pays
               AND (po.ville IS NULL OR coalesce(d.poste ->> 'city', 'capitale') = po.ville)
             LIMIT 1) AS titulaire
      FROM postes po)
  SELECT jsonb_agg(jsonb_build_object('pays', pays, 'poste', poste, 'ville', ville, 'occupe', titulaire IS NOT NULL)
                   ORDER BY pays DESC, ville NULLS FIRST, poste) INTO v_postes FROM occ;
  v_ok := NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_villes) e WHERE NOT (e ->> 'atteint')::boolean)
      AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_postes) e WHERE NOT (e ->> 'occupe')::boolean);
  RETURN jsonb_build_object('ok', true, 'conditions_remplies', v_ok, 'villes', v_villes, 'postes', v_postes);
END $$;
REVOKE ALL ON FUNCTION public.teaser_ouverture_compteur() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.teaser_ouverture_compteur() TO authenticated;

-- 6. Accès réservés de l'Hôtel Royal d'Al-Khalija.
CREATE OR REPLACE FUNCTION public.acces_piece_reservee_interne(p_batiment text, p_piece text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT (p_batiment = 'pavillon-ambassadeurs-novomirsk'
           AND p_piece IN ('bar', 'salle_reception', 'suite_privee', 'suite_presidentielle', 'suite_parti'))
      OR (p_batiment = 'residence-imperiale-novomirsk'
           AND p_piece IN ('appartement_1', 'appartement_2', 'appartement_3', 'appartement_4', 'grand_appartement'))
      -- Hôtel Royal d'Al-Khalija (Fred, 28/11/2026) : ces pièces n'existent qu'à Al Madina.
      OR (p_batiment = 'hotel-republica' AND p_piece IN ('salon_gentlemen', 'hammam_hommes', 'hammam_femmes'));
$function$;

SELECT pg_temp.rp_remplacer('public.acces_reserve_raison_interne(text,text,text)'::regprocedure,
  '  IF p_batiment = ''pavillon-ambassadeurs-novomirsk'' THEN',
  '  -- hotel_royal_genre_v1 (Fred, 28/11/2026) : salons et hammams de l''Hôtel Royal réservés selon le genre du personnage.
  IF p_batiment = ''hotel-republica'' THEN
    RETURN CASE WHEN p_piece IN (''salon_gentlemen'', ''hammam_hommes'')
                 AND (SELECT stats ->> ''genre'' FROM public.personnages_donnees WHERE name = p_nom) IS DISTINCT FROM ''H'' THEN ''reserve_hommes''
                WHEN p_piece = ''hammam_femmes''
                 AND (SELECT stats ->> ''genre'' FROM public.personnages_donnees WHERE name = p_nom) IS DISTINCT FROM ''F'' THEN ''reserve_femmes''
                ELSE NULL END;
  END IF;
  IF p_batiment = ''pavillon-ambassadeurs-novomirsk'' THEN',
  'hotel_royal_genre_v1');

CREATE OR REPLACE FUNCTION public.acces_forcer_passage(p_requete uuid, p_piece text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); p record; x record; v_paie jsonb; v_vol integer; v_taux integer; v_jet integer;
        g jsonb; v_id bigint; v_pnj text; r jsonb; v_raison text; v_hotel boolean; v_det jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('acces_reserve:' || a, 0));
  SELECT * INTO x FROM public.acces_actes WHERE acteur = a AND requete = p_requete;
  IF FOUND THEN RETURN x.resultat || jsonb_build_object('rejeu', true); END IF;
  SELECT country, current_city, current_building, current_room, stats, hp INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  -- hotel_royal_forcer_v1 (Fred, 28/11/2026) : l'Hôtel Royal d'Al-Khalija rejoint le Pavillon et la Résidence de Novomirsk.
  v_hotel := p.country = 'khalija' AND p.current_city = 'capitale' AND p.current_building = 'hotel-republica';
  IF NOT (v_hotel OR (p.country = 'soviet' AND p.current_city = 'capitale'
                      AND p.current_building IN ('pavillon-ambassadeurs-novomirsk', 'residence-imperiale-novomirsk')))
     OR NOT public.acces_piece_reservee_interne(p.current_building, p_piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF false /* sante_zero_libre_v1 */ OR EXISTS (SELECT 1 FROM public.detention_active(a)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  v_raison := public.acces_reserve_raison_interne(a, p.current_building, p_piece);
  IF v_raison IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acces_deja_autorise'); END IF;
  v_paie := public.payer_ordre(a, 'forcer_passage', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_vol := coalesce(CASE WHEN jsonb_typeof(p.stats->'VOL') = 'number' THEN (p.stats->>'VOL')::integer END, 10);
  v_taux := least(100, greatest(0, 60 + 4 * (v_vol - 13)));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet <= v_taux THEN
    INSERT INTO public.acces_intrusions (acteur, batiment) VALUES (a, p.current_building)
      ON CONFLICT (acteur, batiment) DO UPDATE SET cree_le = now();
    -- À l'Hôtel Royal, la réussite ne rend pas recherché (Fred, 28/11/2026).
    IF NOT v_hotel THEN
      PERFORM public.crime_rechercher_interne(a, 'forcer_passage', 'delit_mineur');
      PERFORM public.crime_tracer_interne(a, 'forcer_passage', p.current_building);
    END IF;
    r := jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet, 'batiment', p.current_building, 'piece', p_piece);
  ELSIF v_hotel THEN
    -- Échec à l'Hôtel Royal : un jour de prison, sans combat ni amende.
    v_det := public.detention_ouvrir_interne(a, 'Intrusion dans un salon réservé de l''Hôtel Royal', 1, 'capitale', 'khalija',
      jsonb_build_array(jsonb_build_object('type', 'Intrusion dans un salon réservé de l''Hôtel Royal', 'jours', 1,
        'source', 'acces_reserve', 'city', 'capitale')), 'garde_hotel_royal', 'intrusion_hotel_royal');
    r := jsonb_build_object('ok', true, 'reussi', false, 'prison', true, 'jours', 1, 'taux', v_taux, 'jet', v_jet,
      'batiment', p.current_building, 'piece', p_piece, 'detention', v_det);
  ELSE
    g := public.acces_garde_interne(p.current_building);
    INSERT INTO public.acces_tentatives (acteur, batiment, piece) VALUES (a, p.current_building, p_piece) RETURNING id INTO v_id;
    v_pnj := 'garde_acces:' || v_id;
    INSERT INTO public.pnj_membres (id, famille, nom, pays, ville, building_id, room_id, classe, pa, proprietaire_institution, proprietaire_perimetre,
                                    car_int, car_cha, car_vol, car_per, car_dup, car_ent)
    VALUES (v_pnj, 'employe', g->>'nom', 'soviet', 'capitale', p.current_building, p.current_room, 'beta', public.pnj_pa_max(),
            'garde_acces', 'soviet:capitale:' || p.current_building, 10, 8, 12, 12, 8, 8)
    ON CONFLICT (id) DO NOTHING;
    UPDATE public.acces_tentatives SET pnj_id = v_pnj WHERE id = v_id;
    r := jsonb_build_object('ok', true, 'reussi', false, 'combat', true, 'taux', v_taux, 'jet', v_jet,
      'pnj', v_pnj, 'garde', g->>'nom', 'batiment', p.current_building, 'piece', p_piece);
  END IF;
  r := r || public.crime_etat_acteur_interne(a);
  INSERT INTO public.acces_actes (acteur, requete, resultat) VALUES (a, p_requete, r - 'inventory' - 'inventaire');
  RETURN r;
END $function$;

COMMIT;
