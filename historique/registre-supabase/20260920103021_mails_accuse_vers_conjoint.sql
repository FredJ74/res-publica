-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920103021
-- Nom original      : mails_accuse_vers_conjoint
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 10:30:21 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : feda7c67489ec6ef5f09326881c4985a
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
-- §5, dernier cas du groupe « le destinataire est impose par le serveur ».
--
-- L'officialisation d'un mariage envoie au conjoint un avis sous l'en-tete
-- « Mairie ». L'emetteur est un citoyen ordinaire : ni maire, ni adjoint. Mais
-- l'union LAISSE UNE TRACE (table mariages, ecrite juste avant l'envoi), donc le
-- lien entre l'emetteur et le destinataire est verifiable cote serveur -- ce qui
-- est exactement la condition qu'on exige partout ailleurs.
--
-- Meme principe que autorise_vers_titulaire : l'identite institutionnelle reste
-- inutilisable pour atteindre un tiers quelconque. Ici le seul destinataire
-- possible est la personne avec qui je suis reellement marie.

ALTER TABLE public.mails_expediteurs_systeme
  ADD COLUMN IF NOT EXISTS autorise_vers_conjoint boolean NOT NULL DEFAULT false;

UPDATE public.mails_expediteurs_systeme
   SET autorise_vers_conjoint = true
 WHERE expediteur = 'Mairie';

CREATE OR REPLACE FUNCTION public.mail_destinataire_est_conjoint(p_moi text, p_destinataire text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.mariages m
     WHERE coalesce(m.statut, 'actif') <> 'dissous'
       AND m.dissous_at IS NULL
       AND ((m.conjoint1 = p_moi AND m.conjoint2 = p_destinataire)
         OR (m.conjoint2 = p_moi AND m.conjoint1 = p_destinataire))
  );
$$;
REVOKE ALL ON FUNCTION public.mail_destinataire_est_conjoint(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_conjoint(text, text) TO authenticated, service_role;

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

  IF r.autorise_soi AND p_destinataire = v_moi THEN RETURN true; END IF;

  IF array_length(r.postes, 1) IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                  WHERE a.poste_id = ANY (r.postes)) THEN
    RETURN true;
  END IF;

  IF r.autorise_vers_titulaire
     AND array_length(r.postes, 1) IS NOT NULL
     AND public.mail_destinataire_est_titulaire(p_destinataire, r.postes) THEN
    RETURN true;
  END IF;

  IF r.autorise_vers_conjoint
     AND public.mail_destinataire_est_conjoint(v_moi, p_destinataire) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;
REVOKE ALL ON FUNCTION public.mail_expediteur_autorise_strict(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise_strict(text, text) TO authenticated, service_role;