-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919224828
-- Nom original      : mails_confidentialite_lot1
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-19 22:48:28 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 213b3bca647882be487194395e4b4a64
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
-- LOT P0-A / INCREMENT 4 — LE COURRIER PRIVE REDEVIENT PRIVE
-- =====================================================================
-- L'AUDIT A DEMONTRE, sous role anon reel : lecture des 6 mails de la base, dont
-- la correspondance privee entre joueurs ; suppression par simple id ; et
-- usurpation de n'importe quel expediteur, la table n'ayant AUCUNE colonne liee
-- a auth.uid(). La policy etait allow_all FOR ALL USING(true) WITH CHECK(true).
--
-- CE LOT FERME ENTIEREMENT deux des trois objectifs :
--   * lire le courrier d'autrui     -> impossible
--   * supprimer le courrier d'autrui -> impossible
-- ET REND LE TROISIEME MESURABLE :
--   * usurper l'expediteur. 81 sites appellent sbSendMail, dont ~55 avec un
--     expediteur institutionnel en dur (« Tribunal », « Ministere des Finances »,
--     « Brigade Criminelle »...). Exiger from_player = mon_personnage() casserait
--     ces 55 parcours d'un coup. Ces expediteurs sont donc declares dans un
--     miroir, et chaque envoi sous un nom systeme est journalise avec son
--     VERITABLE auteur. Le lot suivant deplacera ces envois cote serveur en se
--     fondant sur ce que le miroir aura reellement observe -- pas sur une liste
--     devinee. Meme doctrine que ordres_couts_ecarts.

-- --------------------------------------------------- expediteurs systeme declares
CREATE TABLE IF NOT EXISTS public.mails_expediteurs_systeme (
  expediteur text PRIMARY KEY,
  note       text
);
ALTER TABLE public.mails_expediteurs_systeme ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mails_expediteurs_systeme FROM PUBLIC, anon, authenticated;
-- La policy doit pouvoir lire ce miroir : elle s'execute avec les droits de
-- l'appelant, donc on passe par une fonction SECURITY DEFINER (ci-dessous).

INSERT INTO public.mails_expediteurs_systeme (expediteur, note) VALUES
  ('Ligue Officielle',                    'championnat'),
  ('Ministère des Affaires Étrangères',   'diplomatie'),
  ('Ministère des Finances',              'economie'),
  ('Ministère de la Justice',             'justice'),
  ('Ministère de la Défense',             'militaire'),
  ('Services municipaux',                 'mairie'),
  ('Office Notarial',                     'successions / ventes'),
  ('Mairie',                              'mairie'),
  ('Tribunal',                            'justice'),
  ('Préfecture',                          'administration'),
  ('Brigade Criminelle',                  'police'),
  ('Assemblée Nationale',                 'assemblee'),
  ('Chef des Douanes',                    'douanes'),
  ('Administration Portuaire',            'port'),
  ('Commandement',                        'militaire'),
  ('Détachement militaire',               'militaire'),
  ('Chercheurs Civils',                   'recherche'),
  ('Jodie Moitout',                       'presse — PNJ'),
  ('Jérémy',                              'quete d accueil — PNJ'),
  ('Système',                             'avis technique'),
  ('Événement',                           'evenement'),
  ('Événement mystérieux',                'evenement'),
  ('Alerte confidentielle',               'renseignement')
ON CONFLICT (expediteur) DO NOTHING;

-- Lecture du miroir depuis une policy, sans ouvrir la table.
CREATE OR REPLACE FUNCTION public.mail_expediteur_systeme(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.mails_expediteurs_systeme m WHERE m.expediteur = p_nom);
$$;
REVOKE ALL ON FUNCTION public.mail_expediteur_systeme(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mail_expediteur_systeme(text) TO authenticated, service_role;

-- ------------------------------------------------------------- journal d'usurpation
CREATE TABLE IF NOT EXISTS public.mails_envois_systeme (
  id          bigserial PRIMARY KEY,
  auteur_reel text,
  expediteur  text NOT NULL,
  destinataire text,
  sujet       text,
  vu_le       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.mails_envois_systeme ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mails_envois_systeme FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.mails_envois_systeme_id_seq FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.mails_journaliser_envoi_systeme()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
DECLARE v_moi text;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  v_moi := public.mon_personnage();
  IF NEW.from_player IS DISTINCT FROM v_moi THEN
    INSERT INTO public.mails_envois_systeme (auteur_reel, expediteur, destinataire, sujet)
    VALUES (v_moi, NEW.from_player, NEW.to_player, left(coalesce(NEW.subject,''), 200));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mails_journaliser_envoi_systeme ON public.mails;
CREATE TRIGGER trg_mails_journaliser_envoi_systeme
  BEFORE INSERT ON public.mails
  FOR EACH ROW EXECUTE FUNCTION public.mails_journaliser_envoi_systeme();

-- ------------------------------------------------------------------- policies
DROP POLICY IF EXISTS allow_all_mails ON public.mails;

-- On ne voit que le courrier dont on est partie : destinataire, expediteur, ou
-- auteur reel derriere un envoi au nom d'une organisation.
CREATE POLICY mails_lecture_partie ON public.mails
  FOR SELECT TO authenticated
  USING (to_player = public.mon_personnage()
      OR from_player = public.mon_personnage()
      OR from_real   = public.mon_personnage());

-- Marquer lu / archiver : uniquement sur son propre courrier.
CREATE POLICY mails_maj_partie ON public.mails
  FOR UPDATE TO authenticated
  USING (to_player = public.mon_personnage() OR from_player = public.mon_personnage())
  WITH CHECK (to_player = public.mon_personnage() OR from_player = public.mon_personnage());

CREATE POLICY mails_suppression_partie ON public.mails
  FOR DELETE TO authenticated
  USING (to_player = public.mon_personnage() OR from_player = public.mon_personnage());

-- Envoi : soi-meme, ou un expediteur systeme DECLARE (journalise par le
-- declencheur ci-dessus). Un nom d'expediteur invente est refuse.
CREATE POLICY mails_envoi ON public.mails
  FOR INSERT TO authenticated
  WITH CHECK (from_player = public.mon_personnage()
           OR public.mail_expediteur_systeme(from_player));

-- anon n'a plus rien a faire dans la boite aux lettres.
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.mails FROM anon;