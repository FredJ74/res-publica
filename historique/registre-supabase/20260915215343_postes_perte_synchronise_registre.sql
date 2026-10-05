-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915215343
-- Nom original      : postes_perte_synchronise_registre
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-15 21:53:43 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 7875cd3551309f5f44f76388b0c0f5c1
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
-- AUTORITE DES POSTES — LA PERTE D'UN POSTE EFFACE AUSSI SON ATTESTATION.
--
-- Le jeu remet poste a NULL par SIX chemins differents, tous cote client et tous legitimes :
-- demission volontaire, fin de mandat, condamnation pour crime, changement de domicile,
-- naturalisation, delogement par un successeur. NULL est toujours accepte par l'attestation --
-- on ne bloque jamais quelqu'un qui PERD une fonction.
--
-- Mais si la ligne de postes_attribues survivait a cette perte, le registre continuerait
-- d'attester un titulaire qui n'exerce plus : il lui suffirait de reecrire son ancien poste sur
-- sa fiche pour le reprendre, et le verrou serait contourne par la porte de sortie.
--
-- Plutot que de raccorder six fonctions clientes une par une -- et d'en oublier la septieme le
-- jour ou elle sera ecrite -- on synchronise a la source : quiconque cesse de porter un poste
-- nomme cesse au meme instant d'y etre inscrit.
CREATE OR REPLACE FUNCTION public.personnages_poste_perdu()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF OLD.poste IS NOT NULL AND jsonb_typeof(OLD.poste) = 'object'
     AND (NEW.poste IS NULL OR jsonb_typeof(NEW.poste) = 'null'
          OR (NEW.poste ->> 'id') IS DISTINCT FROM (OLD.poste ->> 'id')
          OR (NEW.poste ->> 'city') IS DISTINCT FROM (OLD.poste ->> 'city')) THEN
    DELETE FROM public.postes_attribues
     WHERE titulaire = OLD.name
       AND poste_id = (OLD.poste ->> 'id')
       AND country = OLD.country
       AND city IS NOT DISTINCT FROM nullif(OLD.poste ->> 'city', '');
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_personnages_poste_perdu ON public.personnages_donnees;
CREATE TRIGGER trg_personnages_poste_perdu
  AFTER UPDATE OF poste ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_poste_perdu();

-- ATTRIBUTION SUR CANDIDATURE. Le joueur a postule, l'autorite accepte : le consentement du
-- candidat est deja acquis, la prise de fonction est donc immediate -- exactement le
-- comportement actuel d'accepterCandidaturePoste, dont l'ecriture (sur la ligne d'autrui) est
-- de toute facon refusee depuis le chantier B.
CREATE OR REPLACE FUNCTION public.poste_attribuer_candidature(p_poste text, p_city text, p_candidat text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_nom text; v_pays text; v_depuis timestamptz;
BEGIN
  SELECT a.nom, a.pays INTO v_nom, v_pays FROM public.poste_autorite_de(p_poste, p_city) a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_candidat IS NULL OR btrim(p_candidat) = ''
     OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = p_candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;

  SELECT depuis INTO v_depuis FROM public.postes_attribues
   WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  IF v_depuis IS NOT NULL AND v_depuis > now() - interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_protege');
  END IF;

  RETURN public.poste_attribuer_interne(v_pays, p_poste, p_city, p_candidat, 'candidature_acceptee');
END;
$$;
REVOKE ALL ON FUNCTION public.poste_attribuer_candidature(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poste_attribuer_candidature(text, text, text) TO authenticated, service_role;