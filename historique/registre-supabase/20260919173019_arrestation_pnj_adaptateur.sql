-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919173019
-- Nom original      : arrestation_pnj_adaptateur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:30:19 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : dbcf6809b6b1546ed4c85bcd4950a319
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
-- LOT 4 — Arrestation d'un PNJ explicitement detenable.
--
-- ARCHITECTURE VALIDEE : justice commune -> branche PJ INCHANGEE -> adaptateur
-- pour les systemes PNJ declares detenables -> etat canonique propre a la cible.
-- PAR DEFAUT, TOUT PNJ RESTE INARRETABLE : l'adaptateur ne connait aujourd'hui
-- qu'un seul systeme, les agents de renseignement. Tout autre nom sans fiche
-- continue de recevoir 'cible_introuvable', exactement comme avant.
--
-- GARDE-FOU DE COLLISION PJ/PNJ. detentions.nom n'a pas de cle etrangere et
-- sert d'identifiant a trois systemes ; un PNJ et un PJ homonymes seraient
-- confondus par detention_active. On ajoute donc une colonne de provenance,
-- NULLE pour toutes les lignes existantes : le comportement historique des
-- detentions PJ est strictement inchange.

ALTER TABLE public.detentions ADD COLUMN IF NOT EXISTS provenance text;
COMMENT ON COLUMN public.detentions.provenance IS
  'NULL = detention d''un PJ (comportement historique). Sinon, systeme PNJ proprietaire de l''etat de la cible, ex. agent_renseignement.';

-- Ancre temps reel de la detention, cote agent : l'equivalent de est_emprisonne
-- .debutTs pour un PJ. Sans elle, rien ne libererait jamais.
ALTER TABLE public.agents_renseignement ADD COLUMN IF NOT EXISTS detention_id text;
ALTER TABLE public.agents_renseignement ADD COLUMN IF NOT EXISTS detenu_depuis timestamptz;

-- --------------------------------------------------------------------------
-- L'ADAPTATEUR. Seul point ou la justice demande « cette cible PNJ existe-t-elle
-- reellement, et est-elle arretable MAINTENANT par CET Etat ? ».
-- Il ne renvoie JAMAIS le vrai nom ni le pays d'origine de l'agent.
-- p_pays_autorite est le pays de l'autorite qui arrete : le niveau de
-- connaissance exige est celui de CET Etat, pas d'un autre.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.detention_cible_pnj(p_nom text, p_pays_autorite text)
RETURNS TABLE(systeme text, pays text, ville text, building_id text, room_id text,
              agent_id text, statut text, niveau_connu integer, arretable boolean)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT 'agent_renseignement'::text,
         ag.pays_couverture, ag.ville, ag.building_id, ag.room_id,
         ag.id, ag.statut,
         public.contre_espionnage_niveau_connu(p_pays_autorite, ag.nom_couverture),
         (    ag.statut = 'actif'                      -- ni deja detenu, ni mort, ni disparu
          AND ag.leader_courant IS NULL                -- pose, pas en deplacement
          AND ag.ville IS NOT NULL                     -- position canonique reelle
          AND ag.pays_couverture = p_pays_autorite     -- dans la juridiction
          AND public.contre_espionnage_niveau_connu(p_pays_autorite, ag.nom_couverture) >= 2)
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.nom_couverture = p_nom
     AND ag.pays_couverture = p_pays_autorite
     AND c.statut = 'active'
   LIMIT 1;
$function$;

-- --------------------------------------------------------------------------
-- detention_ouvrir_interne : branche PJ d'abord, INCHANGEE au caractere pres.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.detention_ouvrir_interne(
  p_nom text, p_raison text, p_jours integer, p_city text, p_country text,
  p_motifs jsonb, p_autorite text, p_issue text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id         text := 'det-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
                       substr(md5(random()::text), 1, 6);
  v_jour_cible integer;
  v_deja       jsonb;
  v_pnj        record;
BEGIN
  SELECT coalesce(d.day, 1), d.est_emprisonne INTO v_jour_cible, v_deja
    FROM public.personnages_donnees d WHERE d.name = p_nom FOR UPDATE;

  IF NOT FOUND THEN
    -- ---- Pas de fiche : on demande a l'adaptateur. ----
    SELECT * INTO v_pnj FROM public.detention_cible_pnj(p_nom, p_country);
    IF v_pnj.systeme IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    IF v_pnj.statut = 'detenu' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
    END IF;
    IF NOT v_pnj.arretable THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_arretable',
                                'niveau_connu', v_pnj.niveau_connu, 'niveau_requis', 2);
    END IF;

    v_jour_cible := public.jour_de_jeu_pays(p_country);
    INSERT INTO public.detentions (id, country, city, nom, raison, jour_debut, jour_fin, qhs,
                                   motifs, autorite, issue_judiciaire, ville_condamnation, provenance)
    VALUES (v_id, p_country, p_city, p_nom, p_raison, v_jour_cible, v_jour_cible + p_jours, false,
            p_motifs, p_autorite, p_issue, p_city, v_pnj.systeme);

    -- L'etat de detention vit dans le systeme canonique de la cible, jamais
    -- dans une fausse fiche personnages_donnees.
    UPDATE public.agents_renseignement
       SET statut = 'detenu', detention_id = v_id, detenu_depuis = now(),
           leader_courant = NULL, maj_le = now()
     WHERE id = v_pnj.agent_id;

    RETURN jsonb_build_object('ok', true, 'detention_id', v_id,
                              'jour_debut', v_jour_cible, 'jour_fin', v_jour_cible + p_jours,
                              'provenance', v_pnj.systeme);
  END IF;

  -- ---- Branche PJ : strictement le code historique. ----
  IF v_deja IS NOT NULL AND jsonb_typeof(v_deja) = 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_deja_detenue');
  END IF;

  INSERT INTO public.detentions (id, country, city, nom, raison, jour_debut, jour_fin, qhs,
                                 motifs, autorite, issue_judiciaire, ville_condamnation)
  VALUES (v_id, p_country, p_city, p_nom, p_raison, v_jour_cible, v_jour_cible + p_jours, false,
          p_motifs, p_autorite, p_issue, p_city);

  UPDATE public.personnages_donnees
     SET est_emprisonne = jsonb_build_object(
           'jours', p_jours, 'jourFin', v_jour_cible + p_jours, 'raison', p_raison,
           'detentionId', v_id, 'qhs', false, 'city', p_city, 'country', p_country,
           'debutTs', (extract(epoch from clock_timestamp())*1000)::bigint)
   WHERE name = p_nom;

  RETURN jsonb_build_object('ok', true, 'detention_id', v_id,
                            'jour_debut', v_jour_cible, 'jour_fin', v_jour_cible + p_jours);
END;
$function$;

-- --------------------------------------------------------------------------
-- arrestation_urgence : meme autorite, meme juridiction. Seule la source de la
-- position de la cible change quand il n'y a pas de fiche.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.arrestation_urgence(p_cible text, p_motif text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_cible_pays text; v_cible_ville text;
  v_ville text; v_res jsonb; v_motifs jsonb; v_pnj record;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;

  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS NULL OR v_poste NOT IN ('president', 'min_int', 'min_just', 'commissaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_cible IS NULL OR btrim(p_cible) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente');
  END IF;
  IF p_cible = v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_l_acteur');
  END IF;
  IF p_motif IS NULL OR btrim(p_motif) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_absent');
  END IF;

  SELECT d.country, d.current_city INTO v_cible_pays, v_cible_ville
    FROM public.personnages_donnees d WHERE d.name = p_cible;

  IF v_cible_pays IS NULL THEN
    -- Pas de fiche : l'adaptateur repond, ou la cible reste introuvable.
    SELECT * INTO v_pnj FROM public.detention_cible_pnj(p_cible, v_pays);
    IF v_pnj.systeme IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    IF NOT v_pnj.arretable THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_non_arretable',
                                'niveau_connu', v_pnj.niveau_connu, 'niveau_requis', 2);
    END IF;
    v_cible_pays  := v_pnj.pays;
    v_cible_ville := v_pnj.ville;
  END IF;

  IF v_cible_pays IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF v_poste = 'commissaire' THEN
    IF v_poste_city IS NULL OR v_cible_ville IS DISTINCT FROM v_poste_city THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction_ville');
    END IF;
    v_ville := v_poste_city;
  ELSE
    v_ville := coalesce(v_cible_ville, 'capitale');
  END IF;

  v_motifs := jsonb_build_array(jsonb_build_object(
    'type', 'Arrestation d''urgence : ' || p_motif,
    'jour_fait', coalesce((SELECT d.day FROM public.personnages_donnees d WHERE d.name = p_cible),
                          public.jour_de_jeu_pays(v_pays)),
    'city', v_ville, 'jours', 1, 'source', 'arrestation_urgence',
    'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));

  v_res := public.detention_ouvrir_interne(
    p_cible, 'Arrestation d''urgence (' || p_motif || ')', 1, v_ville, v_pays,
    v_motifs, v_nom || ' (' || v_poste || ')', 'arrestation_urgence');

  IF (v_res ->> 'ok') IS DISTINCT FROM 'true' THEN
    RETURN v_res;
  END IF;

  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'isn', 1);
  PERFORM public.indice_ville_ajuster_interne(v_pays, v_ville, 'social', -1);

  RETURN v_res || jsonb_build_object('cible', p_cible, 'ville', v_ville,
                                     'autorite', v_nom, 'poste', v_poste,
                                     'securite', 1, 'social', -1);
END;
$function$;

REVOKE ALL ON FUNCTION public.detention_cible_pnj(text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.detention_cible_pnj(text,text) TO service_role;
