-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920102935
-- Nom original      : mails_accuse_vers_titulaire
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 10:29:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8ced3ece72ab09193947ab0797ae5292
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
-- §5 : FERMER LA TOLERANCE SANS CASSER L'ACCUSE DE RECEPTION
-- ---------------------------------------------------------------------------
-- CE QUE LA MESURE A MONTRE. 34 envois clients utilisent une identite
-- institutionnelle DECLAREE mais non libre. La majorite est emise par le
-- titulaire lui-meme (un ministre qui repond sous l'en-tete de son ministere) et
-- passe deja le controle strict. Mais un groupe entier ne passe pas, et il a
-- toujours la meme forme :
--
--   un CITOYEN depose une demande, et l'institution en avise SON TITULAIRE.
--     - permis de construire      -> « Services municipaux » au Maire
--     - logement social Montrouge -> « Services municipaux » au Maire Adjoint
--     - naturalisation            -> « Service de l'Immigration » au Min. Interieur
--
-- Couper la tolerance sans traiter ce groupe rendrait ces demandes invisibles :
-- le citoyen croirait avoir depose, et aucun titulaire ne serait prevenu.
--
-- LA REGLE AJOUTEE est le pendant exact d'autorise_soi. autorise_soi dit « vous
-- ne pouvez ecrire sous cette identite qu'a VOUS-MEME » ; autorise_vers_titulaire
-- dit « ... qu'au TITULAIRE ACTUEL de cette institution ». Dans les deux cas le
-- destinataire est impose par le serveur, donc l'identite ne peut pas servir a
-- ecrire a un tiers quelconque -- qui est tout l'interet d'une usurpation.
-- Ce n'est pas une permission nouvelle : le citoyen declenche DEJA ces avis
-- aujourd'hui. On ne fait que borner qui il peut atteindre.

ALTER TABLE public.mails_expediteurs_systeme
  ADD COLUMN IF NOT EXISTS autorise_vers_titulaire boolean NOT NULL DEFAULT false;

UPDATE public.mails_expediteurs_systeme
   SET autorise_vers_titulaire = true
 WHERE expediteur IN ('Services municipaux', 'Service de l''Immigration');

-- Titulaire courant d'un poste : un PJ dont la fiche porte ce poste. La fiche est
-- deja attestee par trg_personnages_attester_poste, donc « poste » n'est plus
-- auto-declare depuis le chantier des postes.
CREATE OR REPLACE FUNCTION public.mail_destinataire_est_titulaire(p_destinataire text, p_postes text[])
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.name = p_destinataire
       AND d.poste ->> 'id' = ANY (p_postes)
  );
$$;
REVOKE ALL ON FUNCTION public.mail_destinataire_est_titulaire(text, text[]) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_titulaire(text, text[]) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.mail_expediteur_autorise_strict(p_nom text, p_destinataire text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE r record; v_moi text;
BEGIN
  SELECT * INTO r FROM public.mails_expediteurs_systeme m
   WHERE (NOT m.est_prefixe AND m.expediteur = p_nom)
      OR (m.est_prefixe AND p_nom LIKE m.expediteur || '%')
   ORDER BY m.est_prefixe LIMIT 1;
  IF NOT FOUND THEN RETURN false; END IF;
  IF r.libre THEN RETURN true; END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;

  -- Je peux m'ecrire a moi-meme sous cette identite.
  IF r.autorise_soi AND p_destinataire = v_moi THEN RETURN true; END IF;

  -- Je detiens le poste : l'identite est la mienne, sans restriction de destinataire.
  IF array_length(r.postes, 1) IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                  WHERE a.poste_id = ANY (r.postes)) THEN
    RETURN true;
  END IF;

  -- ACCUSE DE RECEPTION : je ne detiens pas le poste, mais je peux saisir
  -- l'institution -- et UNIQUEMENT son titulaire, jamais un tiers.
  IF r.autorise_vers_titulaire
     AND array_length(r.postes, 1) IS NOT NULL
     AND public.mail_destinataire_est_titulaire(p_destinataire, r.postes) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;
REVOKE ALL ON FUNCTION public.mail_expediteur_autorise_strict(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise_strict(text, text) TO authenticated, service_role;