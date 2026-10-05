-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260922070715
-- Nom original      : renseignement_coordinateurs_position_effective
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-22 07:07:15 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ddd249bb48f08df7b0406b8cc395bb8d
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
-- COORDINATEUR / CENTRE MULTIMODAL. Le centre observe est celui OU L'AGENT SE TROUVE.
CREATE OR REPLACE FUNCTION public.agent_coordinateur_multimodal(p_agent_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  a record; p record; f record;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_ref text; v_nb integer := 0; v_txt text;
BEGIN
  SELECT ag.*, c.statut AS statut_cellule, c.id AS cel,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.id = p_agent_id AND ag.role = 'coordinateur';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.ville_eff IS NULL OR a.pays_eff IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_sans_position'); END IF;
  IF public.agent_au_bureau_min_def(a.bat_eff, a.room_eff) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_au_bureau'); END IF;
  IF a.bat_eff IS NULL OR a.bat_eff NOT LIKE 'centre-multinodal%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_centre_multimodal'); END IF;

  FOR p IN
    WITH suite AS (
      SELECT h.name, h.building_id, h.created_at,
             lag(h.building_id)  OVER w AS avant,
             lead(h.building_id) OVER w AS apres
        FROM public.historique_deplacements h
       WHERE h.country = a.pays_eff AND h.city = a.ville_eff
      WINDOW w AS (PARTITION BY h.name ORDER BY h.created_at)
    )
    SELECT s.name,
           count(*)                              AS passages,
           min(s.created_at)                     AS premier,
           max(s.created_at)                     AS dernier,
           (array_remove(array_agg(s.avant ORDER BY s.created_at), NULL))[1]  AS origine,
           (array_remove(array_agg(s.apres ORDER BY s.created_at DESC), NULL))[1] AS destination
      FROM suite s
     WHERE s.building_id = a.bat_eff
       AND (s.created_at AT TIME ZONE 'Europe/Paris')::date = v_jour
     GROUP BY s.name
  LOOP
    v_ref := 'multimodal:' || a.bat_eff || ':' || p.name || ':' || v_jour;
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                           WHERE rc.titulaire = 'cellule:' || a.cel
                             AND rc.fait_objectif_ref = v_ref);

    v_txt := p.name || ' : ' || p.passages || ' passage' ||
             CASE WHEN p.passages > 1 THEN 's' ELSE '' END ||
             ' au centre multimodal de ' || a.ville_eff ||
             ', entre ' || to_char(p.premier AT TIME ZONE 'Europe/Paris', 'HH24:MI') ||
             ' et ' || to_char(p.dernier AT TIME ZONE 'Europe/Paris', 'HH24:MI') ||
             coalesce(', en provenance de ' || p.origine, '') ||
             coalesce(', reparti vers ' || p.destination, '') || '.';

    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('rm_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
            substr(md5(random()::text), 1, 8),
            'cellule:' || a.cel, v_txt, p.name, 'mouvements', a.nom_couverture, 'observation',
            v_ref, 0, 0, 2147483647);
    v_nb := v_nb + 1;
  END LOOP;

  FOR f IN
    SELECT cd.id, cd.personne, cd.objet_nom, cd.quantite
      FROM public.confiscations_douanieres cd
     WHERE cd.pays = a.pays_eff AND cd.ville = a.ville_eff
       AND cd.building_id = a.bat_eff
       AND (cd.cree_le AT TIME ZONE 'Europe/Paris')::date = v_jour
  LOOP
    v_ref := 'confiscation:' || f.id;
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                           WHERE rc.titulaire = 'cellule:' || a.cel
                             AND rc.fait_objectif_ref = v_ref);
    INSERT INTO public.renseignements_connus
      (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
       fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
    VALUES ('rf_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
            substr(md5(random()::text), 1, 8),
            'cellule:' || a.cel,
            'Les douanes ont confisque a ' || f.personne || ' : ' || f.objet_nom ||
            coalesce(' (x' || f.quantite || ')', '') || '.',
            f.personne, 'confiscation', a.nom_couverture, 'observation',
            v_ref, 0, 0, 2147483647);
    v_nb := v_nb + 1;
  END LOOP;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$fn$;

-- COORDINATEUR / PORT. Meme regle : le port surveille est celui ou l'agent se trouve.
CREATE OR REPLACE FUNCTION public.agent_coordinateur_port(p_agent_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  a record; c record; v_ref text; v_nb integer := 0;
  v_reel integer; v_noms text; v_recoupe boolean;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_port jsonb; v_arr jsonb;
BEGIN
  SELECT ag.*, ce.statut AS statut_cellule, ce.id AS cel,
         pe.pays AS pays_eff, pe.ville AS ville_eff,
         pe.building_id AS bat_eff, pe.room_id AS room_eff
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement ce ON ce.id = ag.cellule_id
    LEFT JOIN LATERAL public.agent_position_effective(ag.id) pe ON true
   WHERE ag.id = p_agent_id AND ag.role = 'coordinateur';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.ville_eff IS NULL OR a.pays_eff IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_sans_position'); END IF;
  IF public.agent_au_bureau_min_def(a.bat_eff, a.room_eff) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_au_bureau'); END IF;
  IF a.bat_eff IS NULL OR a.bat_eff NOT LIKE 'port-%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_port'); END IF;

  FOR c IN
    SELECT f.id, f.declaration_douaniere, f.statut, f.quantite_arrivee
      FROM public.caisses_fret f
     WHERE (f.building_origine = a.bat_eff OR f.building_destination = a.bat_eff)
       AND f.statut IN ('fermee', 'en_transit', 'arrivee')
  LOOP
    SELECT coalesce(sum(cc.quantite), 0),
           coalesce(string_agg(DISTINCT lower(cc.objet ->> 'name'), ' '), '')
      INTO v_reel, v_noms
      FROM public.contenu_caisses_fret cc WHERE cc.caisse_id = c.id;

    IF c.quantite_arrivee IS NOT NULL AND c.quantite_arrivee <> v_reel THEN
      v_ref := 'fret_quantite:' || c.id || ':' || v_jour;
      IF NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                      WHERE rc.titulaire = 'cellule:' || a.cel AND rc.fait_objectif_ref = v_ref) THEN
        INSERT INTO public.renseignements_connus
          (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
           fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
        VALUES ('rp_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(md5(random()::text),1,8),
                'cellule:' || a.cel,
                'Une caisse arrivee a ' || a.bat_eff || ' comptait ' || c.quantite_arrivee ||
                ' unite(s) a l''arrivee ; il en reste ' || v_reel || '.',
                c.id, 'fret_divergence', a.nom_couverture, 'observation', v_ref, 0, 0, 2147483647);
        v_nb := v_nb + 1;
      END IF;
    END IF;

    IF coalesce(btrim(c.declaration_douaniere), '') <> '' AND v_reel > 0 THEN
      SELECT bool_or(
               v_noms LIKE '%' || rtrim(md, 's') || '%'
               OR EXISTS (SELECT 1 FROM unnest(regexp_split_to_array(v_noms, '[^[:alnum:]]+')) mo
                           WHERE length(mo) >= 4
                             AND lower(c.declaration_douaniere) LIKE '%' || rtrim(mo, 's') || '%'))
        INTO v_recoupe
        FROM unnest(regexp_split_to_array(lower(c.declaration_douaniere), '[^[:alnum:]]+')) md
       WHERE length(md) >= 4;

      IF v_recoupe IS NOT NULL AND v_recoupe = false THEN
        v_ref := 'fret_nature:' || c.id || ':' || v_jour;
        IF NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                        WHERE rc.titulaire = 'cellule:' || a.cel AND rc.fait_objectif_ref = v_ref) THEN
          INSERT INTO public.renseignements_connus
            (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
             fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
          VALUES ('rp_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(md5(random()::text),1,8),
                  'cellule:' || a.cel,
                  'Une caisse declaree « ' || c.declaration_douaniere ||
                  ' » ne contient aucune marchandise correspondant a cette declaration.',
                  c.id, 'fret_divergence', a.nom_couverture, 'observation', v_ref, 0, 0, 2147483647);
          v_nb := v_nb + 1;
        END IF;
      END IF;
    END IF;
  END LOOP;

  SELECT (b.data #>> '{}')::jsonb -> 'port' INTO v_port
    FROM public.batiments_etat b
   WHERE b.id = a.pays_eff || '_' || a.ville_eff || '_' || a.bat_eff;
  IF v_port IS NOT NULL AND jsonb_typeof(v_port -> 'arrivages') = 'array' THEN
    FOR v_arr IN SELECT x FROM jsonb_array_elements(v_port -> 'arrivages') x LIMIT 5
    LOOP
      v_ref := 'fret_arrivage:' || coalesce(v_arr ->> 'jour', '?') || ':' ||
               coalesce(v_arr ->> 'resource', '?') || ':' || coalesce(v_arr ->> 'origine', '?');
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                             WHERE rc.titulaire = 'cellule:' || a.cel AND rc.fait_objectif_ref = v_ref);
      INSERT INTO public.renseignements_connus
        (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
         fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
      VALUES ('rp_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(md5(random()::text),1,8),
              'cellule:' || a.cel,
              'Arrivage au port le ' || coalesce(left(v_arr ->> 'jour', 10), '?') || ' : ' ||
              coalesce(v_arr ->> 'qte', '?') || ' de ' || coalesce(v_arr ->> 'resource', '?') ||
              ', origine ' || coalesce(v_arr ->> 'origine', 'inconnue') || '.',
              a.bat_eff, 'fret_flux', a.nom_couverture, 'observation', v_ref, 0, 0, 2147483647);
      v_nb := v_nb + 1;
    END LOOP;
  END IF;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$fn$;