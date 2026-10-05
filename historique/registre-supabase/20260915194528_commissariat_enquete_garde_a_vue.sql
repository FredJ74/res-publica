-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915194528
-- Nom original      : commissariat_enquete_garde_a_vue
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-15 19:45:28 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 47bc2d83ffb26855a3292e047c2345c4
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
-- COMMISSARIAT — LOT 4 : « Mener l'enquete » place enfin reellement en garde a vue.
--
-- L'ordre du bureau du commissaire appelait enregistrerDetention() sur la cible depuis le
-- navigateur. La policy detentions_ecriture_soi n'autorise l'insert que pour soi : l'appel
-- echouait, avale par .catch(() => {}). Le commissaire voyait « enquete reussie », l'affaire
-- partait au tribunal, mais AUCUNE garde a vue n'existait -- exactement le meme defaut que
-- l'ancienne arrestation d'urgence.
--
-- On ne duplique pas la logique : cette RPC appelle plainte_instruire_interne, la meme primitive
-- que le commissaire PNJ, donc le meme critere (un acte trace non decouvert dans SA ville), la
-- meme garde a vue de 2 jours et le meme demasquage atomique de l'acte. Le taux de reussite et
-- le paiement sur la caisse du commissariat restent cote client : le game design de l'ordre ne
-- change pas, seule son ecriture devient reelle.
CREATE OR REPLACE FUNCTION public.commissaire_enqueter(p_cible text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_nom text; v_poste text; v_poste_city text; v_pays text;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_poste IS DISTINCT FROM 'commissaire' OR v_poste_city IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_cible IS NULL OR btrim(p_cible) = '' OR p_cible = v_nom THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  RETURN public.plainte_instruire_interne(v_pays, v_poste_city, p_cible, 'enquete', v_nom);
END;
$$;
REVOKE ALL ON FUNCTION public.commissaire_enqueter(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.commissaire_enqueter(text) TO authenticated, service_role;