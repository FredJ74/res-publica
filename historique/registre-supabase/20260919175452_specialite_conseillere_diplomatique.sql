-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919175452
-- Nom original      : specialite_conseillere_diplomatique
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:54:52 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6c2d7a744615191bf963841123140ed7
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
-- B. CONSEILLERE DIPLOMATIQUE — Gladys Crête.
--
-- CIBLES : les personnalites politiques presentes dans le MEME BATIMENT
-- qu'elle, toutes pieces confondues. Le perimetre reprend les identifiants de
-- postes REELS du jeu : president, pm et les six ministeres (postes_nommes),
-- depute et maire (postes_electifs). Le siege de depute peut aussi etre porte
-- par la colonne dediee poste_depute : les deux formes sont acceptees.
--
-- DEUX CANAUX INDEPENDANTS, une tentative de chacun par cible et par jour.
-- Une meme journee peut donc produire une trace criminelle ET une appartenance.
--   trace criminelle : clamp(10, 90, 90 - 2 * DUP_cible)
--   appartenance     : clamp(10, 75, 75 - 2 * DUP_cible)
-- Un echec ne signifie JAMAIS innocence ni absence d'appartenance : il n'ecrit
-- rien du tout.
--
-- L'anti-rejeu EST LA CLE, comme partout ailleurs dans le projet.
CREATE TABLE IF NOT EXISTS public.agent_tentatives (
  agent_id   text NOT NULL,
  cible      text NOT NULL,
  canal      text NOT NULL,
  jour_paris date NOT NULL,
  cree_le    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (agent_id, cible, canal, jour_paris)
);
ALTER TABLE public.agent_tentatives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.agent_tentatives FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.agent_conseillere_observer(p_agent_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; t record; o record; tr record;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_dup numeric; v_chance integer; v_jet integer; v_ref text; v_nb integer := 0;
BEGIN
  SELECT ag.*, c.statut AS statut_cellule, c.id AS cel
    INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id AND ag.role = 'conseiller';
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' OR a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_inactif'); END IF;
  IF a.leader_courant IS NOT NULL OR a.ville IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_non_pose'); END IF;

  FOR t IN
    SELECT d.name, public.assemblee_stat_base(d.stats, 'DUP') AS dup
      FROM public.personnages_donnees d
     WHERE d.country = a.pays_couverture
       AND d.current_city = a.ville
       AND d.current_building = a.building_id          -- MEME BATIMENT, toutes pieces
       AND (d.poste ->> 'id' IN ('president','pm','min_ae','min_def','min_fin',
                                 'min_info','min_int','min_just','depute','maire')
            OR jsonb_typeof(d.poste_depute) = 'object')
  LOOP
    v_dup := t.dup;

    -- ---- CANAL 1 : trace criminelle, possiblement d'une AUTRE ville ----
    BEGIN
      INSERT INTO public.agent_tentatives (agent_id, cible, canal, jour_paris)
      VALUES (p_agent_id, t.name, 'trace', v_jour);

      v_chance := greatest(10, least(90, round(90 - 2 * v_dup)::integer));
      v_jet    := floor(random() * 100)::integer + 1;                 -- RNG SERVEUR
      IF v_jet <= v_chance THEN
        SELECT at.id, at.type_action, at.city, at.cible AS victime INTO tr
          FROM public.actions_tracables at
         WHERE at.auteur = t.name
           AND NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                            WHERE rc.titulaire = 'cellule:' || a.cel
                              AND rc.fait_objectif_ref = 'actions_tracables:' || at.id)
         ORDER BY at.jour DESC LIMIT 1;                               -- une seule par jour
        IF tr.id IS NOT NULL THEN
          INSERT INTO public.renseignements_connus
            (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
             fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
          VALUES ('rc_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
                  substr(md5(random()::text), 1, 8),
                  'cellule:' || a.cel,
                  t.name || ' serait implique dans : ' || tr.type_action ||
                  coalesce(' (vise : ' || tr.victime || ')', '') ||
                  coalesce(', a ' || tr.city, '') || '.',
                  t.name, 'trace_criminelle', a.nom_couverture, 'observation',
                  'actions_tracables:' || tr.id, 0, 0, 2147483647);
          v_nb := v_nb + 1;
        END IF;
      END IF;
    EXCEPTION WHEN unique_violation THEN NULL;   -- deja tente aujourd'hui
    END;

    -- ---- CANAL 2 : appartenance secrete (organisation criminelle ou loge) ----
    BEGIN
      INSERT INTO public.agent_tentatives (agent_id, cible, canal, jour_paris)
      VALUES (p_agent_id, t.name, 'appartenance', v_jour);

      v_chance := greatest(10, least(75, round(75 - 2 * v_dup)::integer));
      v_jet    := floor(random() * 100)::integer + 1;
      IF v_jet <= v_chance THEN
        -- On ne lit QUE l'appartenance de CETTE personne. Jamais la liste des
        -- membres, jamais l'organisation entiere.
        SELECT og.id, (og.data::jsonb ->> 'nom') AS nom_org,
               (og.data::jsonb ->> 'type') AS type_org
          INTO o
          FROM public.organisations og
         WHERE (og.data::jsonb ->> 'type') IN ('criminelle', 'loge')
           AND EXISTS (SELECT 1 FROM jsonb_array_elements(
                         coalesce(og.data::jsonb -> 'membres', '[]'::jsonb)) m
                        WHERE m ->> 'nom' = t.name)
           AND NOT EXISTS (SELECT 1 FROM public.renseignements_connus rc
                            WHERE rc.titulaire = 'cellule:' || a.cel
                              AND rc.fait_objectif_ref = 'appartenance:' || og.id || ':' || t.name)
         ORDER BY random() LIMIT 1;                                   -- une seule par jour
        IF o.id IS NOT NULL THEN
          INSERT INTO public.renseignements_connus
            (id, titulaire, contenu, cible, categorie, source, mode_acquisition,
             fait_objectif_ref, jour_acquisition, jour_derniere_reactivation, jour_expiration)
          VALUES ('ra_' || (extract(epoch from clock_timestamp())*1000)::bigint || '_' ||
                  substr(md5(random()::text), 1, 8),
                  'cellule:' || a.cel,
                  t.name || ' appartiendrait a ' ||
                  CASE o.type_org WHEN 'loge' THEN 'la loge' ELSE 'l''organisation' END ||
                  ' « ' || coalesce(o.nom_org, '?') || ' ».',
                  t.name, 'appartenance_secrete', a.nom_couverture, 'observation',
                  'appartenance:' || o.id || ':' || t.name, 0, 0, 2147483647);
          v_nb := v_nb + 1;
        END IF;
      END IF;
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
  END LOOP;

  IF v_nb > 0 THEN PERFORM public.agent_trace_deposer(p_agent_id); END IF;
  RETURN jsonb_build_object('ok', true, 'faits', v_nb);
END;
$function$;

REVOKE ALL ON FUNCTION public.agent_conseillere_observer(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.agent_conseillere_observer(text) TO service_role;
