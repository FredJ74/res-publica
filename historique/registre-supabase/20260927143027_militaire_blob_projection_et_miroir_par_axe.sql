-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927143027
-- Nom original      : militaire_blob_projection_et_miroir_par_axe
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 14:30:27 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 5eb194a36bde4b7e3e6796c3d7bdaf27
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHECKPOINT A (2/4) — LE BLOB DEVIENT UNE PROJECTION (27 septembre 2026)
--
-- Le mandat autorise explicitement le blob a rester un STOCKAGE METIER : il doit seulement cesser
-- de faire AUTORITE sur les donnees generiques. C'est exactement ce qu'on fait ici.
--
-- POURQUOI UNE PROJECTION PLUTOT QU'UN ABANDON. Dix-huit lectures clientes, plus l'affichage de
-- la section, les ordres collectifs et l'inspection des troupes, lisent `leaderCourant`, `ville`
-- et `pa` dans le blob. Les reecrire toutes serait un chantier d'interface, pas une migration --
-- et chacune serait une occasion de regression. En projetant le socle vers le blob apres chaque
-- ecriture, ces lectures continuent de dire vrai sans qu'on y touche, et le comparateur devient
-- un controle de projection : si les deux divergent, on le voit.
--
-- L'AUTORITE A BIEN CHANGE DE COTE : c'est le socle qui decide, le blob qui suit. Une ecriture
-- directe du blob sur ces trois axes serait ecrasee a la projection suivante.
CREATE OR REPLACE FUNCTION public.militaire_blob_projeter(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb; v_secs jsonb; v_res jsonb; v_n integer := 0;
BEGIN
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

  -- SECTIONS. Les soldats JOUEURS (pj) n'ont pas de ligne au socle : on ne les touche jamais.
  SELECT COALESCE(jsonb_agg(
           s || jsonb_build_object('soldats', (
             SELECT COALESCE(jsonb_agg(
                      CASE WHEN COALESCE((sol->>'pj')::boolean,false) THEN sol
                           ELSE sol || jsonb_build_object(
                                  'leaderCourant', m.leader_pj,
                                  'ville', m.ville, 'buildingId', m.building_id,
                                  'roomId', m.room_id, 'pa', m.pa)
                      END ORDER BY sp), '[]'::jsonb)
               FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb))
                    WITH ORDINALITY AS ts(sol, sp)
               LEFT JOIN public.pnj_membres m
                 ON m.id = p_compagnie || '-' || (sol->>'matricule')))
           ORDER BY sp2), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, sp2);

  SELECT COALESCE(jsonb_agg(
           r || jsonb_build_object('leaderCourant', m.leader_pj,
                  'ville', m.ville, 'buildingId', m.building_id,
                  'roomId', m.room_id, 'pa', m.pa)
           ORDER BY rp), '[]'::jsonb)
    INTO v_res
    FROM jsonb_array_elements(COALESCE(v_data->'reserve','[]'::jsonb)) WITH ORDINALITY AS t(r, rp)
    LEFT JOIN public.pnj_membres m ON m.id = p_compagnie || '-' || (r->>'matricule');

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_res)
   WHERE id = p_compagnie;
  SELECT count(*) INTO v_n FROM public.pnj_membres WHERE id LIKE p_compagnie || '-%';
  RETURN jsonb_build_object('ok', true, 'projetes', v_n);
END; $$;

-- ---------------------------------------------------------------------------------------
-- LE MIROIR NE RECOPIE PLUS UN AXE QUI A BASCULE
-- ---------------------------------------------------------------------------------------
-- Sans cela, la prochaine ecriture du blob -- un entrainement, une mission -- ramenerait des
-- valeurs perimees dans le socle. Le miroir reste en revanche responsable du ROSTER (creation et
-- disparition des lignes) et de toutes les donnees METIER, qui restent au blob.
CREATE OR REPLACE FUNCTION public.pnj_miroir_compagnie(p_compagnie text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c record; v_pays text; v_vus text[] := '{}'; v_sup integer := 0; v_maj integer := 0;
        s jsonb; sol jsonb; v_id text; v_sec text; v_res_per text;
        v_pos_blob boolean; v_pa_blob boolean;
BEGIN
  SELECT * INTO c FROM public.compagnies_militaires WHERE id = p_compagnie;
  IF c.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  v_pays := c.data->>'pays';
  v_res_per := p_compagnie || ':reserve';
  SELECT COALESCE(autorite,'blob') = 'blob' INTO v_pos_blob
    FROM public.pnj_axes_autorite WHERE famille='soldat' AND axe='position_leader';
  SELECT COALESCE(autorite,'blob') = 'blob' INTO v_pa_blob
    FROM public.pnj_axes_autorite WHERE famille='soldat' AND axe='pa';
  v_pos_blob := COALESCE(v_pos_blob, true);
  v_pa_blob  := COALESCE(v_pa_blob, true);

  FOR s IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'sections','[]'::jsonb)) LOOP
    v_sec := s->>'id';
    FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(s->'soldats','[]'::jsonb)) LOOP
      CONTINUE WHEN COALESCE((sol->>'pj')::boolean, false) IS TRUE;
      v_id := p_compagnie || '-' || (sol->>'matricule');
      v_vus := v_vus || v_id;
      INSERT INTO public.pnj_membres (id, famille, nom, pays,
          proprietaire_institution, proprietaire_perimetre,
          leader_pj, ville, building_id, room_id, pa, statut)
      VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', v_sec,
          sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
          COALESCE((sol->>'pa')::integer, 12), 'actif')
      ON CONFLICT (id) DO UPDATE SET
          leader_pj   = CASE WHEN v_pos_blob THEN EXCLUDED.leader_pj   ELSE pnj_membres.leader_pj END,
          ville       = CASE WHEN v_pos_blob THEN EXCLUDED.ville       ELSE pnj_membres.ville END,
          building_id = CASE WHEN v_pos_blob THEN EXCLUDED.building_id ELSE pnj_membres.building_id END,
          room_id     = CASE WHEN v_pos_blob THEN EXCLUDED.room_id     ELSE pnj_membres.room_id END,
          pa          = CASE WHEN v_pa_blob  THEN EXCLUDED.pa          ELSE pnj_membres.pa END,
          statut = EXCLUDED.statut,
          proprietaire_institution = EXCLUDED.proprietaire_institution,
          proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
          maj_le = now();
      INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, compagnie_id, section_id,
          en_reserve, arme, formation, mutin,
          dernier_ration, nb_ration, dernier_bivouac, dernier_sommeil)
      VALUES (v_id, sol->>'matricule', p_compagnie, v_sec, false, sol->>'arme',
              COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin',
              sol->>'dernier_ration', (sol->>'nb_ration')::integer,
              sol->>'dernier_bivouac', sol->>'dernier_sommeil')
      ON CONFLICT (pnj_id) DO UPDATE SET
          compagnie_id = EXCLUDED.compagnie_id,
          section_id = EXCLUDED.section_id, en_reserve = EXCLUDED.en_reserve,
          arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin,
          dernier_ration = EXCLUDED.dernier_ration, nb_ration = EXCLUDED.nb_ration,
          dernier_bivouac = EXCLUDED.dernier_bivouac, dernier_sommeil = EXCLUDED.dernier_sommeil;
      v_maj := v_maj + 1;
      PERFORM public.pnj_miroir_possessions_si_axe_blob(v_id,
        CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END);
    END LOOP;
  END LOOP;

  FOR sol IN SELECT value FROM jsonb_array_elements(COALESCE(c.data->'reserve','[]'::jsonb)) LOOP
    v_id := p_compagnie || '-' || (sol->>'matricule');
    v_vus := v_vus || v_id;
    INSERT INTO public.pnj_membres (id, famille, nom, pays,
        proprietaire_institution, proprietaire_perimetre,
        leader_pj, ville, building_id, room_id, pa, statut)
    VALUES (v_id, 'soldat', COALESCE(sol->>'matricule','?'), v_pays, 'militaire', v_res_per,
        sol->>'leaderCourant', sol->>'ville', sol->>'buildingId', sol->>'roomId',
        COALESCE((sol->>'pa')::integer, 12), 'actif')
    ON CONFLICT (id) DO UPDATE SET
        leader_pj   = CASE WHEN v_pos_blob THEN EXCLUDED.leader_pj   ELSE pnj_membres.leader_pj END,
        ville       = CASE WHEN v_pos_blob THEN EXCLUDED.ville       ELSE pnj_membres.ville END,
        building_id = CASE WHEN v_pos_blob THEN EXCLUDED.building_id ELSE pnj_membres.building_id END,
        room_id     = CASE WHEN v_pos_blob THEN EXCLUDED.room_id     ELSE pnj_membres.room_id END,
        pa          = CASE WHEN v_pa_blob  THEN EXCLUDED.pa          ELSE pnj_membres.pa END,
        statut = EXCLUDED.statut,
        proprietaire_institution = EXCLUDED.proprietaire_institution,
        proprietaire_perimetre = EXCLUDED.proprietaire_perimetre,
        maj_le = now();
    INSERT INTO public.pnj_soldats_metier (pnj_id, matricule, compagnie_id, section_id,
        en_reserve, arme, formation, mutin,
        dernier_ration, nb_ration, dernier_bivouac, dernier_sommeil)
    VALUES (v_id, sol->>'matricule', p_compagnie, NULL, true, sol->>'arme',
            COALESCE(sol->'formation','{}'::jsonb), sol->>'mutin',
            sol->>'dernier_ration', (sol->>'nb_ration')::integer,
            sol->>'dernier_bivouac', sol->>'dernier_sommeil')
    ON CONFLICT (pnj_id) DO UPDATE SET
        compagnie_id = EXCLUDED.compagnie_id,
        section_id = NULL, en_reserve = true,
        arme = EXCLUDED.arme, formation = EXCLUDED.formation, mutin = EXCLUDED.mutin,
        dernier_ration = EXCLUDED.dernier_ration, nb_ration = EXCLUDED.nb_ration,
        dernier_bivouac = EXCLUDED.dernier_bivouac, dernier_sommeil = EXCLUDED.dernier_sommeil;
    v_maj := v_maj + 1;
    PERFORM public.pnj_miroir_possessions_si_axe_blob(v_id,
      CASE WHEN jsonb_typeof(sol->'accessoires')='array' THEN sol->'accessoires' ELSE '[]'::jsonb END);
  END LOOP;

  DELETE FROM public.pnj_membres
   WHERE id LIKE p_compagnie || '-%' AND NOT (id = ANY(v_vus));
  GET DIAGNOSTICS v_sup = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'synchronises', v_maj, 'supprimes', v_sup);
END; $$;

REVOKE ALL ON FUNCTION public.militaire_blob_projeter(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_blob_projeter(text) TO service_role;