-- =====================================================================================
-- DOUANES DES VOYAGEURS (#433, Claude, 04/11/2026)
--
-- Aéroport de Luthécia (Fred, 28/10 et 04/11) : UN poste de douane = un groupe de 3 douaniers
-- au hall des douanes, sans coût pour l'État (la paie des douaniers ne couvre que le port de
-- PSM), remplacés à minuit s'ils sont hors de combat. Un recherché est détecté et interpellé
-- par les mécanismes communs : les douaniers présents rejoignent les forces de détection de
-- police_detection_contexte_interne (recherchés seulement, pas de contrôle ordinaire), et le
-- passage du contrôle ouvre la même interception (combat, fuite, reddition, justice) que la
-- police. Le contrôle des inventaires de l'aéroport est inchangé.
--
-- Port industriel (Fred, 28/10) : les douaniers ne fouillent JAMAIS un voyageur non recherché
-- (plus aucune saisie au quai) ; la détection d'un recherché vaut 70 % du taux normal
-- (taux_effectif = taux_normal × 0,70, sur le jet existant).
--
-- Patchs en place vérifiés : chaque fragment remplacé doit exister exactement, sinon la
-- migration s'arrête. Banc : outils/bancs/banc-douanes-voyageurs.sql.
-- =====================================================================================

-- Douaniers présents à un endroit, un candidat par groupe (le chef du groupe), en état d'agir.
CREATE OR REPLACE FUNCTION public.douane_agents_presents_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(jsonb_agg(DISTINCT jsonb_build_object('matricule', 'pnj:' || coalesce(m.leader_pnj_id, m.id))), '[]'::jsonb)
    FROM public.pnj_membres m CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
   WHERE m.famille = 'douanier' AND m.statut = 'actif' AND m.pa > 0 AND m.leader_pj IS NULL
     AND p_batiment IS NOT NULL AND pe.pays = p_pays AND pe.ville = p_ville
     AND pe.building_id = p_batiment AND pe.room_id IS NOT DISTINCT FROM p_piece;
$$;
REVOKE ALL ON FUNCTION public.douane_agents_presents_interne(text, text, text, text) FROM PUBLIC, anon, authenticated;

-- Poste de l'aéroport : 3 douaniers au hall, groupés ; ceux qui sont hors de combat (PA à 0,
-- morts, détenus ou partis) sont remplacés par de nouveaux agents. Appelé par la passe de minuit.
CREATE OR REPLACE FUNCTION public.douane_aeroport_relever_interne()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_pays text := 'republic'; v_ville text := 'capitale'; v_bat text := 'centre-multinodal-luthecia';
  v_id text := 'republic_capitale_centre-multinodal-luthecia'; v_brut jsonb; v_etat jsonb; v_liste jsonb := '[]'::jsonb;
  d jsonb; v_pnj text; v_gardes integer := 0; v_remplaces integer := 0; v_chef text; v_mat text;
BEGIN
  SELECT data INTO v_brut FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  v_etat := coalesce(public.batiment_etat_lire(v_brut), '{}'::jsonb);
  FOR d IN SELECT value FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_etat->'effectifsDouane'->'douaniers') = 'array'
           THEN v_etat->'effectifsDouane'->'douaniers' ELSE '[]'::jsonb END) LOOP
    v_pnj := public.douane_pnj_id(v_pays, v_ville, d->>'matricule');
    IF v_gardes < 3 AND EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_pnj AND statut = 'actif' AND pa > 0) THEN
      v_liste := v_liste || jsonb_build_array(d); v_gardes := v_gardes + 1;
    END IF;
  END LOOP;
  WHILE jsonb_array_length(v_liste) < 3 LOOP
    v_mat := 'DOU-' || replace(gen_random_uuid()::text, '-', '');
    v_liste := v_liste || jsonb_build_array(jsonb_build_object('matricule', v_mat, 'type', 'standard',
      'stats', public.douane_caracteristiques_metier(), 'buildingId', v_bat, 'roomId', 'hall_douanes', 'rueNoeudId', NULL,
      'recruteLe', (extract(epoch FROM clock_timestamp()) * 1000)::bigint));
    v_remplaces := v_remplaces + 1;
  END LOOP;
  v_etat := jsonb_set(v_etat, '{effectifsDouane}', jsonb_build_object('douaniers', v_liste, 'poste', 'aeroport'));
  IF v_brut IS NULL THEN
    INSERT INTO public.batiments_etat(id, country, city, building_id, data) VALUES (v_id, v_pays, v_ville, v_bat, to_jsonb(v_etat::text));
  ELSE
    UPDATE public.batiments_etat SET data = CASE WHEN jsonb_typeof(v_brut) = 'string' THEN to_jsonb(v_etat::text) ELSE v_etat END WHERE id = v_id;
  END IF;
  -- Dégrouper avant le miroir (un suiveur n'a pas de position propre : pnj_position_deux_etats).
  UPDATE public.pnj_membres SET leader_pnj_id = NULL, ville = v_ville, building_id = v_bat, room_id = 'hall_douanes', maj_le = now()
   WHERE famille = 'douanier' AND pays = v_pays AND proprietaire_perimetre = v_ville || ':' || v_bat AND leader_pnj_id IS NOT NULL;
  PERFORM public.pnj_miroir_douane(v_pays, v_ville, v_bat);
  -- Les trois forment un groupe (force collective à la détection et au combat).
  v_chef := public.douane_pnj_id(v_pays, v_ville, v_liste->0->>'matricule');
  UPDATE public.pnj_membres SET ville = v_ville, building_id = v_bat, room_id = 'hall_douanes', maj_le = now() WHERE id = v_chef;
  UPDATE public.pnj_membres SET leader_pnj_id = v_chef, ville = NULL, building_id = NULL, room_id = NULL, maj_le = now()
   WHERE id IN (SELECT public.douane_pnj_id(v_pays, v_ville, x->>'matricule') FROM jsonb_array_elements(v_liste) x) AND id <> v_chef;
  RETURN jsonb_build_object('ok', true, 'gardes', v_gardes, 'remplaces', v_remplaces, 'chef', v_chef);
END; $$;
REVOKE ALL ON FUNCTION public.douane_aeroport_relever_interne() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.douane_aeroport_relever()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.douane_aeroport_relever_interne();
$$;
REVOKE ALL ON FUNCTION public.douane_aeroport_relever() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.douane_aeroport_relever() TO service_role;

-- Patch 1 : les douaniers présents détectent les recherchés (pas de contrôle ordinaire).
DO $patch$
DECLARE d text; f text := 'v_agents:=v_agents || public.securite_agents_prives_presents_interne(v_pj.country,v_pj.current_city,p_batiment,p_piece,p_rue,v_nom);';
BEGIN
  d := pg_get_functiondef('public.police_detection_contexte_interne(text,text,text,text,boolean)'::regprocedure);
  IF position('douane_agents_presents_interne' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, f, ''))) / length(f) <> 1 THEN RAISE EXCEPTION 'fragment_detection_introuvable'; END IF;
  d := replace(d, f, f || E'\n -- douaniers_detecteurs_v1 (#433) : recherchés seulement.\n IF NOT p_controle THEN v_agents:=v_agents || public.douane_agents_presents_interne(v_pj.country,v_pj.current_city,p_batiment,p_piece); END IF;');
  EXECUTE d;
END $patch$;

-- Patch 2 : contrôle des voyageurs (aéroport par le socle, port à 70 %, aucune fouille au port).
DO $patch$
DECLARE d text;
  f1 text := E'   SELECT * INTO d FROM public.personnages_donnees WHERE name=n;\n   taux:=greatest(5,70+floor(coalesce(nullif(d.resources->>''dis'','''')::numeric,50)/10)-public.crime_malus_isn_interne(d.country,d.current_city));\n   jet:=floor(random()*100)::integer+1;\n   IF jet>taux THEN';
  r1 text := E'   -- douane_voyageurs_v1 (#433) : à l''aéroport, détection et interpellation communes.\n   IF p_mode=''avion'' THEN\n    v:=public.police_detection_personnage_interne(lieu.current_building,lieu.current_room,NULL,n);\n    IF coalesce((v->>''detecte'')::boolean,false) THEN\n     UPDATE public.police_interceptions SET\n      combattants_victimes=coalesce(combattants_victimes,(SELECT jsonb_agg(g.cle) FROM public.groupe_combattants_interne(n,v->>''rencontre'') g)),\n      combattants_forces=coalesce(combattants_forces,(SELECT jsonb_agg(x->>''cle'') FROM jsonb_array_elements(public.police_force_combattants_interne(n,v->>''rencontre'')) x))\n     WHERE personnage=n AND rencontre=v->>''rencontre'';\n     RETURN v||jsonb_build_object(''ok'',false,''raison'',''controle_interception'',''interception'',true,''personnage_intercepte'',n,''contrat_groupes'',1,''membre'',n);\n    END IF;\n    CONTINUE;\n   END IF;\n   SELECT * INTO d FROM public.personnages_donnees WHERE name=n;\n   taux:=greatest(5,70+floor(coalesce(nullif(d.resources->>''dis'','''')::numeric,50)/10)-public.crime_malus_isn_interne(d.country,d.current_city));\n   -- Port industriel : détection à 70 % du taux normal (Fred, 28/10).\n   jet:=floor(random()*100)::integer+1;\n   IF jet<=(100-taux)*0.70 THEN';
  f2 text := E'  IF NOT n=ANY(dispenses) THEN\n   v:=public.douane_confisquer_personnage_interne(n);';
  r2 text := E'  -- Port industriel : jamais de fouille d''un voyageur non recherché (Fred, 28/10).\n  IF NOT n=ANY(dispenses) AND p_mode=''avion'' THEN\n   v:=public.douane_confisquer_personnage_interne(n);';
  f3 text := E' FOR obj IN DELETE FROM public.pnj_possessions WHERE pnj_id=ANY(pnjs)\n AND (';
  r3 text := E' FOR obj IN DELETE FROM public.pnj_possessions WHERE pnj_id=ANY(pnjs) AND p_mode=''avion''\n AND (';
BEGIN
  d := pg_get_functiondef('public.douane_controle_groupe_interne(text,text)'::regprocedure);
  IF position('douane_voyageurs_v1' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, f1, ''))) / length(f1) <> 1 THEN RAISE EXCEPTION 'fragment_jet_introuvable'; END IF;
  IF (length(d) - length(replace(d, f2, ''))) / length(f2) <> 1 THEN RAISE EXCEPTION 'fragment_fouille_introuvable'; END IF;
  IF (length(d) - length(replace(d, f3, ''))) / length(f3) <> 1 THEN RAISE EXCEPTION 'fragment_pnj_introuvable'; END IF;
  d := replace(replace(replace(d, f1, r1), f2, r2), f3, r3);
  EXECUTE d;
END $patch$;

-- Mise en place immédiate du poste de l'aéroport.
SELECT public.douane_aeroport_relever_interne();
