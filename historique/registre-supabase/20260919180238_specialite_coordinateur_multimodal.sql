-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919180238
-- Nom original      : specialite_coordinateur_multimodal
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 18:02:38 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : dffc198408421e5cb951a9be501466e6
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
-- C. COORDINATEUR — Yannick Helle, volet CENTRE MULTIMODAL.
--
-- Observation AUTOMATIQUE des mouvements reels de TOUS les PJ transitant par
-- le centre ou il est physiquement pose. Aucune action du PJ accompagnateur,
-- aucun PA.
--
-- CE NE SONT PLUS DES BATTEMENTS. historique_deplacements ne recoit desormais
-- une ligne QUE lorsque la position change reellement (deplacement_enregistrer)
-- : une ligne = un passage. La synthese ci-dessous compte donc de vrais
-- passages, jamais des minutes de stationnement.
--
-- ORIGINE / DESTINATION uniquement lorsqu'elles sont FACTUELLEMENT DERIVABLES :
-- ce sont le batiment de la ligne qui PRECEDE immediatement l'entree dans le
-- centre, et celui de la ligne qui la SUIT. S'il n'y en a pas, le champ reste
-- absent -- jamais une supposition.
--
-- AUCUNE INTERPRETATION : ni motif, ni alliance, ni intention. Le rapport dit
-- combien de passages, d'ou et vers ou, et rien de plus.
--
-- CONFISCATIONS : si une confiscation douaniere reelle survient dans CE centre
-- pendant sa presence, il apprend la personne et l'objet. Source = l'evenement
-- monde canonique confiscations_douanieres, JAMAIS les mails.
CREATE OR REPLACE FUNCTION public.agent_coordinateur_multimodal(p_agent_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; p record; f record;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_ref text; v_nb integer := 0; v_txt text;
BEGIN
  SELECT ag.*, c.statut AS statut_cellule, c.id AS cel
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id AND ag.role = 'coordinateur';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.leader_courant IS NOT NULL OR a.ville IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_non_pose'); END IF;
  IF a.building_id IS NULL OR a.building_id NOT LIKE 'centre-multinodal%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_un_centre_multimodal'); END IF;

  -- ---- SYNTHESE PAR PERSONNE des passages reels du jour ----
  FOR p IN
    WITH suite AS (
      SELECT h.name, h.building_id, h.created_at,
             lag(h.building_id)  OVER w AS avant,
             lead(h.building_id) OVER w AS apres
        FROM public.historique_deplacements h
       WHERE h.country = a.pays_couverture AND h.city = a.ville
      WINDOW w AS (PARTITION BY h.name ORDER BY h.created_at)
    )
    SELECT s.name,
           count(*)                              AS passages,
           min(s.created_at)                     AS premier,
           max(s.created_at)                     AS dernier,
           -- Origine / destination : uniquement si une ligne encadrante existe.
           (array_remove(array_agg(s.avant ORDER BY s.created_at), NULL))[1]  AS origine,
           (array_remove(array_agg(s.apres ORDER BY s.created_at DESC), NULL))[1] AS destination
      FROM suite s
     WHERE s.building_id = a.building_id
       AND (s.created_at AT TIME ZONE 'Europe/Paris')::date = v_jour
     GROUP BY s.name
  LOOP
    v_ref := 'multimodal:' || a.building_id || ':' || p.name || ':' || v_jour;
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.renseignements_connus rc
                           WHERE rc.titulaire = 'cellule:' || a.cel
                             AND rc.fait_objectif_ref = v_ref);

    v_txt := p.name || ' : ' || p.passages || ' passage' ||
             CASE WHEN p.passages > 1 THEN 's' ELSE '' END ||
             ' au centre multimodal de ' || a.ville ||
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

  -- ---- CONFISCATIONS REELLES survenues dans CE centre aujourd'hui ----
  FOR f IN
    SELECT cd.id, cd.personne, cd.objet_nom, cd.quantite
      FROM public.confiscations_douanieres cd
     WHERE cd.pays = a.pays_couverture AND cd.ville = a.ville
       AND cd.building_id = a.building_id
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
$function$;

REVOKE ALL ON FUNCTION public.agent_coordinateur_multimodal(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.agent_coordinateur_multimodal(text) TO service_role;
