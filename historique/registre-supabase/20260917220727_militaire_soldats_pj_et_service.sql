-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917220727
-- Nom original      : militaire_soldats_pj_et_service
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 22:07:27 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f53288d6c7c9a2fcd506b4a8778319a1
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
-- ==========================================================================================
-- SOLDATS PJ, CANDIDATURES, ET SOURCE CANONIQUE DE L'HISTORIQUE DE SERVICE
--
-- REUTILISATION. engagements_militaires (id, statut, data jsonb) est deja la table generique des
-- candidatures militaires : elle porte la filiere officier. On y ajoute la filiere soldat avec un
-- espace de statuts distinct ('soldat_*'), sans nouvelle table et sans systeme parallele.
--
-- REPRESENTATION D'UN SOLDAT PJ. Une entree { pj: true, nom } dans sections[].soldats. Rien de
-- plus : ses PA, sa position et ses caracteristiques vivent sur sa fiche (personnages_donnees) et
-- n'ont pas a etre recopies ici -- deux sources de verite pour la meme donnee finissent toujours
-- par diverger. Il compte en revanche dans les 24 places, comme le GD le demande.
-- L'idiome est celui de construireCivilsCombat, qui fabrique deja des « humains nommes occupant
-- une place ».
--
-- HISTORIQUE DE SERVICE. services_militaires est la SOURCE CANONIQUE (le futur calepin de campagne
-- n'en sera qu'une projection publique, jamais une autorite). Forme reprise de
-- mandats_maires_archives, seule archive datee existante du projet : debut_ts / fin_ts, une ligne
-- par PERIODE, additionnables et interruptibles. Ecriture reservee au serveur ; lecture publique,
-- comme mandats_maires_archives, puisque c'est une histoire publique.
-- ==========================================================================================

CREATE TABLE IF NOT EXISTS public.services_militaires (
  id           bigserial PRIMARY KEY,
  personnage   text NOT NULL,
  pays         text NOT NULL,
  grade        text NOT NULL,
  compagnie_id text,
  section_id   text,
  debut_ts     timestamptz NOT NULL DEFAULT now(),
  fin_ts       timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS services_militaires_perso ON public.services_militaires (personnage, grade);
CREATE UNIQUE INDEX IF NOT EXISTS services_militaires_une_periode_ouverte
  ON public.services_militaires (personnage, grade) WHERE fin_ts IS NULL;

ALTER TABLE public.services_militaires ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS services_militaires_lecture ON public.services_militaires;
CREATE POLICY services_militaires_lecture ON public.services_militaires
  FOR SELECT TO anon, authenticated USING (true);
-- Aucune policy d'ecriture : seules les fonctions SECURITY DEFINER (proprietaire de la table)
-- inscrivent l'histoire. Les DEFAULT PRIVILEGES du schema accordant tout a anon, on retire.
REVOKE ALL ON TABLE public.services_militaires FROM anon, authenticated;
GRANT SELECT ON TABLE public.services_militaires TO anon, authenticated;

-- ---- Primitives d'historique, internes ----
CREATE OR REPLACE FUNCTION public.militaire_service_ouvrir(
  p_nom text, p_pays text, p_grade text, p_compagnie text, p_section text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
BEGIN
  -- Idempotent : une periode deja ouverte pour ce grade n'est pas dupliquee (index unique
  -- partiel). Un double clic ou un rejeu ne cree donc pas deux services simultanes.
  INSERT INTO public.services_militaires (personnage, pays, grade, compagnie_id, section_id)
  SELECT p_nom, p_pays, p_grade, p_compagnie, p_section
   WHERE NOT EXISTS (SELECT 1 FROM public.services_militaires
                      WHERE personnage = p_nom AND grade = p_grade AND fin_ts IS NULL);
END; $fn$;

CREATE OR REPLACE FUNCTION public.militaire_service_fermer(p_nom text, p_grade text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
BEGIN
  UPDATE public.services_militaires SET fin_ts = now()
   WHERE personnage = p_nom AND grade = p_grade AND fin_ts IS NULL;
END; $fn$;

-- Jours cumules de service effectif pour un grade. Les periodes ouvertes comptent jusqu'a
-- maintenant. Base de la regle des 63 jours.
CREATE OR REPLACE FUNCTION public.militaire_service_jours(p_nom text, p_grade text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $fn$
  SELECT coalesce(sum(extract(epoch FROM (coalesce(fin_ts, now()) - debut_ts)) / 86400.0), 0)
    FROM public.services_militaires
   WHERE personnage = p_nom AND (p_grade IS NULL OR grade = p_grade);
$fn$;
REVOKE ALL ON FUNCTION public.militaire_service_ouvrir(text,text,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_service_fermer(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_service_jours(text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_service_jours(text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_service_jours(text,text) TO authenticated, service_role;

-- ---- Un PJ se porte candidat comme simple soldat ----
CREATE OR REPLACE FUNCTION public.militaire_candidater_soldat(
  p_compagnie_id text, p_section_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_moi text; v_pays text; v_bat text; v_poste text;
  v_data jsonb; v_sec jsonb; v_id text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_building,''), coalesce(poste->>'id','')
    INTO v_pays, v_bat, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  -- Presence reelle exigee, comme militaire_retrait et refectoire_repas : on s'engage a la caserne.
  IF v_bat <> 'caserne-militaire' THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF v_poste IN ('lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_officier', 'poste', v_poste);
  END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;
  IF v_data->>'pays' IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_introuvable'); END IF;
  IF coalesce(v_sec->>'lieutenantNom','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'section_sans_lieutenant'); END IF;

  -- Deja soldat quelque part ? On ne sert pas deux sections a la fois.
  IF EXISTS (SELECT 1 FROM public.compagnies_militaires c,
                    jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
                    jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
              WHERE coalesce((sol->>'pj')::boolean,false) AND sol->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_soldat');
  END IF;

  -- Candidature active deja en cours pour ce meme PJ (tous statuts non finaux).
  IF EXISTS (SELECT 1 FROM public.engagements_militaires
              WHERE statut IN ('soldat_attente_lieutenant','soldat_liste_attente')
                AND data->>'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_en_cours');
  END IF;

  v_id := 'engsold-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.engagements_militaires (id, statut, data)
  VALUES (v_id, 'soldat_attente_lieutenant', jsonb_build_object(
    'grade', 'soldat', 'nom', v_moi, 'pays', v_pays,
    'compagnieId', p_compagnie_id, 'sectionId', p_section_id,
    'lieutenantNom', v_sec->>'lieutenantNom', 'depuis', to_jsonb(now())));

  RETURN jsonb_build_object('ok', true, 'engagement', v_id,
                            'lieutenant', v_sec->>'lieutenantNom');
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_candidater_soldat(text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_candidater_soldat(text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_candidater_soldat(text,text) TO authenticated, service_role;

-- ---- Le Lieutenant traite une candidature de sa section ----
CREATE OR REPLACE FUNCTION public.militaire_candidature_traiter(
  p_engagement_id text, p_accepter boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  c_places constant integer := 24;
  g record; v_e record; v_nom text; v_sec jsonb; v_sols jsonb;
  v_total integer; v_pnj_pos integer; v_pnj jsonb; v_reserve jsonb;
BEGIN
  SELECT * INTO v_e FROM public.engagements_militaires WHERE id = p_engagement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'engagement_introuvable'); END IF;
  IF v_e.statut NOT IN ('soldat_attente_lieutenant','soldat_liste_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'engagement_deja_traite', 'statut', v_e.statut);
  END IF;

  -- AUTORITE : le Lieutenant structurel de la section visee, verifie sur la compagnie elle-meme.
  SELECT * INTO g FROM public.militaire_section_de_moi(v_e.data->>'compagnieId', v_e.data->>'sectionId');
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  v_nom := v_e.data->>'nom';
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;

  IF NOT coalesce(p_accepter, false) THEN
    UPDATE public.engagements_militaires SET statut = 'soldat_refuse' WHERE id = p_engagement_id;
    RETURN jsonb_build_object('ok', true, 'resultat', 'refuse', 'nom', v_nom);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s
   WHERE s->>'id' = v_e.data->>'sectionId';
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_total := jsonb_array_length(v_sols);

  -- Deja dans la section ? Idempotence.
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_sols) s
              WHERE coalesce((s->>'pj')::boolean,false) AND s->>'nom' = v_nom) THEN
    UPDATE public.engagements_militaires SET statut = 'soldat_accepte' WHERE id = p_engagement_id;
    RETURN jsonb_build_object('ok', true, 'resultat', 'deja_present', 'nom', v_nom);
  END IF;

  IF v_total < c_places THEN
    -- Place libre : le PJ l'occupe.
    v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_nom));
    v_reserve := CASE WHEN jsonb_typeof(g.o_data->'reserve') = 'array' THEN g.o_data->'reserve' ELSE '[]'::jsonb END;
  ELSE
    -- Section pleine : on cherche un PNJ a remplacer. Le premier venu.
    SELECT pos, sol INTO v_pnj_pos, v_pnj
      FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
     WHERE NOT coalesce((sol->>'pj')::boolean, false) ORDER BY pos LIMIT 1;
    IF v_pnj IS NULL THEN
      -- 24 PJ : personne n'est evince. Liste d'attente, le candidat reste civil.
      UPDATE public.engagements_militaires SET statut = 'soldat_liste_attente' WHERE id = p_engagement_id;
      RETURN jsonb_build_object('ok', true, 'resultat', 'liste_attente', 'nom', v_nom,
                                'places', c_places);
    END IF;
    -- Remplacement ATOMIQUE : le PNJ COMPLET retourne en reserve, avec son matricule et son
    -- entrainement. Aucune perte d'identite, aucun PNJ cree ni detruit.
    SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
      FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos) WHERE pos <> v_pnj_pos;
    v_sols := v_sols || jsonb_build_array(jsonb_build_object('pj', true, 'nom', v_nom));
    v_reserve := (CASE WHEN jsonb_typeof(g.o_data->'reserve') = 'array' THEN g.o_data->'reserve' ELSE '[]'::jsonb END)
                 || jsonb_build_array(v_pnj);
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, v_e.data->>'sectionId',
                  v_sec || jsonb_build_object('soldats', v_sols))
                || jsonb_build_object('reserve', v_reserve)
   WHERE id = v_e.data->>'compagnieId';

  UPDATE public.engagements_militaires SET statut = 'soldat_accepte' WHERE id = p_engagement_id;
  PERFORM public.militaire_service_ouvrir(v_nom, g.o_data->>'pays', 'soldat',
            v_e.data->>'compagnieId', v_e.data->>'sectionId');

  RETURN jsonb_build_object('ok', true, 'resultat', 'accepte', 'nom', v_nom,
    'pnj_rendu_reserve', (v_pnj IS NOT NULL),
    'matricule_rendu', v_pnj->>'matricule',
    'effectif', jsonb_array_length(v_sols),
    'reserve', jsonb_array_length(v_reserve));
END; $fn$;
REVOKE ALL ON FUNCTION public.militaire_candidature_traiter(text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_candidature_traiter(text,boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_candidature_traiter(text,boolean) TO authenticated, service_role;

-- engagements_militaires : la RLS est desactivee et anon a tous les droits DML (defaut du schema).
-- On retire anon immediatement. La filiere OFFICIER ecrit encore cette table depuis le client
-- (sbCreerEngagement / sbMajEngagement) : fermer authenticated exigerait de la migrer d'abord,
-- ce qui reste une dette documentee. Un authenticated peut donc encore forger une candidature --
-- son pire effet est de PROPOSER un faux candidat, qu'un Lieutenant doit encore accepter.
REVOKE ALL ON TABLE public.engagements_militaires FROM anon;