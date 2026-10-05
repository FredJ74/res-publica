-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919182457
-- Nom original      : coordinateur_port_correctifs
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 18:24:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 339a6ef7a59a243d5706b814e3636c95
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
-- CORRECTIFS issus du banc du Coordinateur port.
--
-- 1. FAUX POSITIF, le plus grave. Une caisse declaree « Caisses de vin » et
--    contenant « Caisse de vin de Luthecia » etait signalee comme ne
--    correspondant a rien : le test comparait les mots bruts, et « caisses »
--    (pluriel) n'est pas une sous-chaine de « caisse de vin... » (singulier).
--    Le rapport accusait donc a tort -- exactement ce que le GD interdit.
--    Le test tolere desormais le pluriel (rtrim 's') et compare dans les DEUX
--    sens : un mot de la declaration retrouve dans les marchandises, OU un mot
--    des marchandises retrouve dans la declaration. En cas de doute, on ne
--    signale rien : le silence est toujours preferable a une fausse accusation.
--
-- 2. Les arrivages rendaient plusieurs lignes textuellement identiques (meme
--    ressource, meme origine, jours differents). La date est desormais dans le
--    texte, sans quoi le rapport ressemblait a du bruit.
CREATE OR REPLACE FUNCTION public.agent_coordinateur_port(p_agent_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; c record; v_ref text; v_nb integer := 0;
  v_reel integer; v_noms text; v_recoupe boolean;
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

  FOR c IN
    SELECT f.id, f.declaration_douaniere, f.statut, f.quantite_arrivee
      FROM public.caisses_fret f
     WHERE (f.building_origine = a.building_id OR f.building_destination = a.building_id)
       AND f.statut IN ('fermee', 'en_transit', 'arrivee')
  LOOP
    SELECT coalesce(sum(cc.quantite), 0),
           coalesce(string_agg(DISTINCT lower(cc.objet ->> 'name'), ' '), '')
      INTO v_reel, v_noms
      FROM public.contenu_caisses_fret cc WHERE cc.caisse_id = c.id;

    -- A. ecart arithmetique constate depuis l'arrivee
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

    -- B. la declaration ne recoupe AUCUNE marchandise, pluriel tolere,
    --    comparaison dans les deux sens.
    IF coalesce(btrim(c.declaration_douaniere), '') <> '' AND v_reel > 0 THEN
      SELECT bool_or(
               v_noms LIKE '%' || rtrim(md, 's') || '%'
               OR EXISTS (SELECT 1 FROM unnest(regexp_split_to_array(v_noms, '[^[:alnum:]]+')) mo
                           WHERE length(mo) >= 4
                             AND lower(c.declaration_douaniere) LIKE '%' || rtrim(mo, 's') || '%'))
        INTO v_recoupe
        FROM unnest(regexp_split_to_array(lower(c.declaration_douaniere), '[^[:alnum:]]+')) md
       WHERE length(md) >= 4;

      -- v_recoupe NULL = aucun mot significatif dans la declaration : on ne
      -- signale rien, faute de pouvoir comparer quoi que ce soit.
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
              'Arrivage au port le ' || coalesce(left(v_arr ->> 'jour', 10), '?') || ' : ' ||
              coalesce(v_arr ->> 'qte', '?') || ' de ' || coalesce(v_arr ->> 'resource', '?') ||
              ', origine ' || coalesce(v_arr ->> 'origine', 'inconnue') || '.',
              a.building_id, 'fret_flux', a.nom_couverture, 'observation', v_ref, 0, 0, 2147483647);
      v_nb := v_nb + 1;
    END LOOP;
  END IF;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$;
