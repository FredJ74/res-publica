-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919182356
-- Nom original      : specialite_coordinateur_port
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 18:23:56 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 176a65be4a6262c4fd7dfc49fe76afe2
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
-- C. COORDINATEUR — volet PORT INDUSTRIEL.
--
-- Il compare les deux sources canoniques, desormais reellement alimentees
-- depuis la reparation de la chaine fret :
--   DECLARE : caisses_fret.declaration_douaniere / valeur_declaree
--   REEL    : contenu_caisses_fret, et data.port.arrivages pour le vrac.
--
-- IL NE RESTITUE QUE DES DIVERGENCES OBJECTIVEMENT ETABLISSABLES. Deux seules
-- le sont a partir des donnees existantes :
--
--  A. QUANTITE. quantite_arrivee est fige par le cron a l'arrivee. Si le total
--     reel actuel en differe, de la marchandise a bouge apres l'arrivee. C'est
--     un ecart arithmetique, pas une interpretation.
--
--  B. NATURE. La declaration est du texte libre : on ne peut PAS en deduire
--     objectivement « c'est faux ». Le seul enonce defendable est textuel --
--     aucun mot significatif (4 lettres ou plus) de la declaration ne se
--     retrouve dans le nom d'une seule des marchandises presentes. Le rapport
--     dit exactement cela, et rien d'autre : il constate que la declaration ne
--     recoupe aucune marchandise, il n'affirme pas une fraude.
--
-- Ce qui n'est PAS fait, faute de donnee : comparer valeur_declaree a une
-- valeur reelle. Les objets d'une caisse n'ont aucune valeur canonique -- toute
-- comparaison serait inventee.
--
-- AUCUNE ACCUSATION, AUCUNE INTENTION, AUCUNE SANCTION.
CREATE OR REPLACE FUNCTION public.agent_coordinateur_port(p_agent_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; c record; v_ref text; v_nb integer := 0;
  v_reel integer; v_noms text; v_mots text[]; v_recoupe boolean;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_port jsonb; v_arr jsonb;
BEGIN
  SELECT ag.*, ce.statut AS statut_cellule, ce.id AS cel
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement ce ON ce.id = ag.cellule_id
   WHERE ag.id = p_agent_id AND ag.role = 'coordinateur';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.leader_courant IS NOT NULL OR a.ville IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_non_pose'); END IF;
  IF a.building_id IS NULL OR a.building_id NOT LIKE 'port-%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_port'); END IF;

  -- ---- CAISSES transitant par CE port ----
  FOR c IN
    SELECT f.id, f.declaration_douaniere, f.valeur_declaree, f.statut, f.quantite_arrivee
      FROM public.caisses_fret f
     WHERE (f.building_origine = a.building_id OR f.building_destination = a.building_id)
       AND f.statut IN ('fermee', 'en_transit', 'arrivee')
  LOOP
    SELECT coalesce(sum(cc.quantite), 0),
           coalesce(string_agg(DISTINCT lower(cc.objet ->> 'name'), ' '), '')
      INTO v_reel, v_noms
      FROM public.contenu_caisses_fret cc WHERE cc.caisse_id = c.id;

    -- A. ecart de quantite constate a l'arrivee
    IF c.quantite_arrivee IS NOT NULL AND c.quantite_arrivee <> v_reel THEN
      v_ref := 'fret_quantite:' || c.id || ':' || v_jour;
      IF NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                      WHERE rc.titulaire = 'cellule:' || a.cel AND rc.fait_objectif_ref = v_ref) THEN
        INSERT INTO public.renseignements_connus
          (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
           fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
        VALUES ('rp_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' || substr(md5(random()::text),1,8),
                'cellule:' || a.cel,
                'Une caisse arrivee a ' || a.building_id || ' comptait ' || c.quantite_arrivee ||
                ' unite(s) a l''arrivee ; il en reste ' || v_reel || '.',
                c.id, 'fret_divergence', a.nom_couverture, 'observation', v_ref, 0, 0, 2147483647);
        v_nb := v_nb + 1;
      END IF;
    END IF;

    -- B. la declaration ne recoupe AUCUNE marchandise presente
    IF coalesce(btrim(c.declaration_douaniere), '') <> '' AND v_reel > 0 THEN
      v_mots := array(SELECT m FROM unnest(regexp_split_to_array(lower(c.declaration_douaniere), '[^[:alnum:]]+')) m
                       WHERE length(m) >= 4);
      IF array_length(v_mots, 1) IS NOT NULL THEN
        SELECT bool_or(v_noms LIKE '%' || m || '%') INTO v_recoupe FROM unnest(v_mots) m;
        IF coalesce(v_recoupe, false) = false THEN
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
    END IF;
  END LOOP;

  -- ---- FLUX DE VRAC reellement arrives au port (fait objectif) ----
  SELECT (b.data #>> '{}')::jsonb -> 'port' INTO v_port
    FROM public.batiments_etat b
   WHERE b.id = a.pays_couverture || '_' || a.ville || '_' || a.building_id;
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
              'Arrivage au port : ' || coalesce(v_arr ->> 'qte', '?') || ' de ' ||
              coalesce(v_arr ->> 'resource', '?') || ', origine ' || coalesce(v_arr ->> 'origine', 'inconnue') || '.',
              a.building_id, 'fret_flux', a.nom_couverture, 'observation', v_ref, 0, 0, 2147483647);
      v_nb := v_nb + 1;
    END LOOP;
  END IF;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$;

REVOKE ALL ON FUNCTION public.agent_coordinateur_port(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.agent_coordinateur_port(text) TO service_role;

-- Le Coordinateur a desormais DEUX usages selon sa position. La collecte
-- quotidienne essaie le centre multimodal, puis le port : l'une des deux rend
-- 'pas_dans_...' et ne fait rien.
CREATE OR REPLACE FUNCTION public.cellules_renseignement_collecter()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_n integer := 0; v_faits integer := 0; v_res jsonb; v_res2 jsonb;
BEGIN
  FOR r IN
    SELECT a.id, a.role FROM public.agents_renseignement a
      JOIN public.cellules_renseignement c ON c.id = a.cellule_id
     WHERE c.statut = 'active' AND a.statut = 'actif'
       AND a.leader_courant IS NULL AND a.ville IS NOT NULL
  LOOP
    IF r.role = 'coordinateur' THEN
      v_res  := public.agent_coordinateur_multimodal(r.id);
      v_res2 := public.agent_coordinateur_port(r.id);
      v_faits := v_faits + coalesce((v_res ->> 'faits')::integer, 0)
                         + coalesce((v_res2 ->> 'faits')::integer, 0);
    ELSE
      v_res := CASE r.role
        WHEN 'garde'      THEN public.agent_garde_observer(r.id)
        WHEN 'traducteur' THEN public.agent_traducteur_ecouter(r.id)
        WHEN 'conseiller' THEN public.agent_conseillere_observer(r.id)
      END;
      v_faits := v_faits + coalesce((v_res ->> 'faits')::integer, 0);
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'agents', v_n, 'faits', v_faits);
END;
$function$;
