-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920103309
-- Nom original      : mails_accuse_vers_destinataire_fret
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 10:33:09 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ca08273deba04bf154751a5de2401e1d
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
-- §5, dernier blocage mesure avant fermeture de la tolerance.
--
-- expedierCaisseFret() (plateau-justice-economie.js) avise le DESTINATAIRE d'une
-- caisse sous l'en-tete « Administration Portuaire ». L'emetteur est le
-- commercant expediteur : il n'est pas capitaine du port, donc le controle strict
-- le refusait. Couper la tolerance sans traiter ce cas aurait fait partir des
-- caisses sans que le destinataire soit jamais prevenu -- une marchandise perdue
-- de vue, pas seulement un mail manquant.
--
-- Comme pour le titulaire et le conjoint, le LIEN EST INSCRIT EN BASE avant
-- l'envoi : la ligne caisses_fret porte le leader (l'expediteur) et le
-- destinataire. Le serveur peut donc verifier que j'ecris bien au destinataire
-- d'une caisse qui est la mienne, et a personne d'autre.
--
-- On exclut volontairement les caisses deja arrivees ou fermees : l'avis
-- accompagne une expedition en cours, il ne doit pas rester un droit d'ecriture
-- permanent sur un ancien partenaire commercial.

ALTER TABLE public.mails_expediteurs_systeme
  ADD COLUMN IF NOT EXISTS autorise_vers_destinataire_fret boolean NOT NULL DEFAULT false;

UPDATE public.mails_expediteurs_systeme
   SET autorise_vers_destinataire_fret = true
 WHERE expediteur = 'Administration Portuaire';

CREATE OR REPLACE FUNCTION public.mail_destinataire_est_fret(p_moi text, p_destinataire text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.caisses_fret f
     WHERE f.leader = p_moi
       AND f.destinataire = p_destinataire
       AND f.date_arrivee_reelle IS NULL
  );
$$;
REVOKE ALL ON FUNCTION public.mail_destinataire_est_fret(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_destinataire_est_fret(text, text) TO authenticated, service_role;

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
  IF NOT FOUND THEN RETURN false; END IF;     -- identite inventee : jamais
  IF r.libre THEN RETURN true; END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;

  -- 1. A moi-meme.
  IF r.autorise_soi AND p_destinataire = v_moi THEN RETURN true; END IF;

  -- 2. Je detiens le poste : l'identite est la mienne, sans restriction.
  IF array_length(r.postes, 1) IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                  WHERE a.poste_id = ANY (r.postes)) THEN
    RETURN true;
  END IF;

  -- 3..5. SAISINE : le destinataire est impose par un lien verifiable en base.
  --       Dans les trois cas, l'identite institutionnelle ne permet JAMAIS
  --       d'atteindre un tiers librement choisi.
  IF r.autorise_vers_titulaire
     AND array_length(r.postes, 1) IS NOT NULL
     AND public.mail_destinataire_est_titulaire(p_destinataire, r.postes) THEN
    RETURN true;
  END IF;

  IF r.autorise_vers_conjoint
     AND public.mail_destinataire_est_conjoint(v_moi, p_destinataire) THEN
    RETURN true;
  END IF;

  IF r.autorise_vers_destinataire_fret
     AND public.mail_destinataire_est_fret(v_moi, p_destinataire) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;
REVOKE ALL ON FUNCTION public.mail_expediteur_autorise_strict(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise_strict(text, text) TO authenticated, service_role;