-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916194959
-- Nom original      : justice_garde_a_vue_enquete
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 19:49:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a3f40c50645d8deec9b045f2491bd35d
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
-- LA GARDE A VUE APRES ENQUETE REDEVIENT EFFECTIVE (16 septembre 2026).
--
-- LE DEFAUT. Au terme d'une enquete concluante, traiterEnquetes ouvrait la garde a vue de la
-- cible par une ecriture directe sur SA fiche -- refusee depuis le chantier B, et avalee par un
-- .catch() muet. Le texte annoncait « mise en garde a vue immediate, affaire transmise au
-- tribunal » et la personne continuait de jouer librement.
--
-- PAS DE SECONDE MECANIQUE : on passe par detention_ouvrir_interne, la primitive deja utilisee
-- par l'arrestation d'urgence, l'enquete du commissaire et l'instruction des plaintes.
--
-- L'AUTORITE N'EST PAS DECLAREE, ELLE EST PROUVEE. traiterEnquetes tourne au passage quotidien
-- chez l'enqueteur, sur SON propre blob enquetes_en_cours. Le serveur relit ce blob sur la ligne
-- de l'appelant et exige d'y retrouver une enquete VISANT CETTE CIBLE et ARRIVEE A TERME. Un
-- navigateur ne peut donc pas reclamer la garde a vue de quelqu'un qu'il n'enquete pas.
--
-- Regles conservees : duree indeterminee jusqu'au jugement (comme avant -- jourFin absent cote
-- client se traduisait par une detention sans terme fixe ; on reprend le meme esprit avec la
-- duree de garde a vue deja utilisee ailleurs par le commissariat), motif et ville d'origine.

CREATE OR REPLACE FUNCTION public.enquete_garde_a_vue(p_cible text, p_motif text, p_ville text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_acteur text; v_enquetes jsonb; v_jour integer; v_pays text; v_ok boolean := false;
  v_e jsonb; v_res jsonb; v_jours integer := 2;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT enquetes_en_cours, coalesce(day, 1), country
    INTO v_enquetes, v_jour, v_pays
    FROM public.personnages_donnees WHERE name = v_acteur;

  -- L'enquete doit exister SUR LA FICHE DE L'APPELANT, viser cette cible, et etre arrivee a terme.
  FOR v_e IN SELECT e FROM jsonb_array_elements(coalesce(v_enquetes, '[]'::jsonb)) e LOOP
    IF v_e->>'cible' = p_cible AND coalesce((v_e->>'day')::int, 999999) <= v_jour THEN
      v_ok := true;
      EXIT;
    END IF;
  END LOOP;
  IF NOT v_ok THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_enquete_arrivee_a_terme');
  END IF;

  v_res := public.detention_ouvrir_interne(
             p_cible,
             coalesce(nullif(p_motif, ''), 'Garde a vue suite a enquete'),
             v_jours,
             coalesce(nullif(p_ville, ''), 'capitale'),
             coalesce(v_e->>'country', v_pays, 'republic'),
             jsonb_build_array(jsonb_build_object(
               'type', coalesce(nullif(p_motif, ''), 'Garde a vue suite a enquete'),
               'jour_fait', coalesce((v_e->>'day')::int, v_jour),
               'city', coalesce(nullif(p_ville, ''), 'capitale'),
               'jours', v_jours,
               'source', 'garde_a_vue',
               'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
             v_acteur,
             'garde_a_vue');
  RETURN v_res;
END; $$;

REVOKE ALL ON FUNCTION public.enquete_garde_a_vue(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enquete_garde_a_vue(text, text, text) TO authenticated;