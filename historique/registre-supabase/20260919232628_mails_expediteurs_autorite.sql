-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919232628
-- Nom original      : mails_expediteurs_autorite
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 23:26:28 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4b355bb77005a4fc5d9a14d104d341a7
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
-- =====================================================================
-- §1B — L'EXPEDITEUR INSTITUTIONNEL DEVIENT UNE AUTORITE, PLUS UNE ETIQUETTE
-- =====================================================================
-- LE DEFAUT DU LOT PRECEDENT, RECONNU. Une liste blanche de NOMS empeche
-- d'inventer une fausse institution, mais n'empeche pas d'usurper une vraie :
-- n'importe quel joueur pouvait signer « Tribunal » parce que le libelle
-- figurait dans le miroir. C'etait une instrumentation, pas un controle.
--
-- CE QUE CE LOT ETABLIT. Chaque expediteur porte desormais son mode d'autorite,
-- derive du SITE D'APPEL REEL (55 envois litteraux releves un par un) :
--
--   postes[]      l'appelant doit DETENIR ce poste, atteste, dans son pays.
--                 13 identites : Tribunal->juge, Ministere des Finances->min_fin,
--                 Commandement->commandant, Chef des Douanes->chef_douanes...
--   autorise_soi  la mecanique ne notifie que le joueur lui-meme : le
--                 destinataire DOIT etre l'appelant. 4 identites (Brigade
--                 Criminelle, Jodie Moitout, Jeremy, Bureau de l'Emploi,
--                 Prefecture) — usurper vers un tiers devient impossible.
--   libre         pas encore contraignable : la mecanique qui produit ce
--                 courrier vit entierement dans le navigateur (le championnat
--                 pour « Ligue Officielle », les consequences de crime pour
--                 « Systeme »/« Evenement »). Ces envois RESTENT journalises et
--                 devront migrer vers un chemin serveur quand leur mecanique le
--                 sera. Ils sont listes tels quels, sans etre presentes comme
--                 fermes.
--
-- Un joueur reste evidemment libre d'ecrire en son propre nom, et une
-- organisation via from_real.

ALTER TABLE public.mails_expediteurs_systeme
  ADD COLUMN IF NOT EXISTS postes       text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS autorise_soi boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS libre        boolean NOT NULL DEFAULT false;

-- --- 13 identites liees a un poste reel -------------------------------------
UPDATE public.mails_expediteurs_systeme SET postes='{juge,min_just}'          WHERE expediteur='Tribunal';
UPDATE public.mails_expediteurs_systeme SET postes='{min_just}'               WHERE expediteur='Ministère de la Justice';
UPDATE public.mails_expediteurs_systeme SET postes='{min_fin}'                WHERE expediteur='Ministère des Finances';
UPDATE public.mails_expediteurs_systeme SET postes='{min_def}'                WHERE expediteur='Ministère de la Défense';
UPDATE public.mails_expediteurs_systeme SET postes='{min_ae}'                 WHERE expediteur='Ministère des Affaires Étrangères';
UPDATE public.mails_expediteurs_systeme SET postes='{commandant}'             WHERE expediteur='Commandement';
UPDATE public.mails_expediteurs_systeme SET postes='{chef_douanes}'           WHERE expediteur='Chef des Douanes';
UPDATE public.mails_expediteurs_systeme SET postes='{maire,maire_adjoint}'    WHERE expediteur='Mairie';
UPDATE public.mails_expediteurs_systeme SET postes='{maire,maire_adjoint}'    WHERE expediteur='Services municipaux';
UPDATE public.mails_expediteurs_systeme SET postes='{juge,min_just,min_int}'  WHERE expediteur='Alerte confidentielle';
UPDATE public.mails_expediteurs_systeme SET postes='{capitaine_port}'         WHERE expediteur='Administration Portuaire';
-- Naturalisation : la demande est confirmee au demandeur lui-meme, le traitement
-- est le fait du ministre de l'Interieur. Les deux sont legitimes.
UPDATE public.mails_expediteurs_systeme SET postes='{min_int}', autorise_soi=true
  WHERE expediteur='Service de l''Immigration';
-- Le prefixe « Lieutenant <nom> » sert a une candidature de soldat : le signataire
-- est le lieutenant lui-meme, donc un poste militaire reel.
UPDATE public.mails_expediteurs_systeme SET postes='{lieutenant,capitaine,commandant}'
  WHERE expediteur='Lieutenant ';

-- --- 5 identites qui ne notifient que le joueur lui-meme ---------------------
UPDATE public.mails_expediteurs_systeme SET autorise_soi=true WHERE expediteur IN
  ('Brigade Criminelle','Jodie Moitout','Jérémy','Bureau National de l''Emploi','Préfecture');

-- --- ce qui reste ouvert, et qui est dit comme tel ---------------------------
UPDATE public.mails_expediteurs_systeme SET libre=true WHERE expediteur IN
  ('Ligue Officielle','Office Notarial','Système','Événement','Événement mystérieux',
   'Chercheurs Civils','Détachement militaire','Assemblée Nationale','Anonyme','Un citoyen');

CREATE OR REPLACE FUNCTION public.mail_expediteur_autorise(p_nom text, p_destinataire text)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE r record; v_moi text;
BEGIN
  SELECT * INTO r FROM public.mails_expediteurs_systeme m
   WHERE (NOT m.est_prefixe AND m.expediteur = p_nom)
      OR (m.est_prefixe AND p_nom LIKE m.expediteur || '%')
   ORDER BY m.est_prefixe LIMIT 1;
  IF NOT FOUND THEN RETURN false; END IF;      -- identite inventee : refus sec

  IF r.libre THEN RETURN true; END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;

  IF r.autorise_soi AND p_destinataire = v_moi THEN RETURN true; END IF;

  IF array_length(r.postes, 1) IS NOT NULL THEN
    RETURN EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                    WHERE a.poste_id = ANY (r.postes));
  END IF;

  RETURN false;
END;
$fn$;
REVOKE ALL ON FUNCTION public.mail_expediteur_autorise(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_autorise(text, text) TO authenticated, service_role;

DROP POLICY IF EXISTS mails_envoi ON public.mails;
CREATE POLICY mails_envoi ON public.mails
  FOR INSERT TO authenticated
  WITH CHECK (from_player = public.mon_personnage()
           OR from_real   = public.mon_personnage()
           OR public.mail_expediteur_organisation(from_player)
           OR public.mail_expediteur_autorise(from_player, to_player));