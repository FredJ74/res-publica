-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924214210
-- Nom original      : securite_messagerie_privee
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 21:42:10 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9ea886b44d4f3f2d7fc001a4eb7c380c
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
-- =============================================================================================
-- CHANTIER SECURITE — LOT 3 : LA MESSAGERIE PRIVEE REDEVIENT PRIVEE (24 septembre 2026)
-- =============================================================================================
-- Les quatre tables du chat n'avaient AUCUNE RLS et un GRANT nominatif a `anon` : n'importe qui,
-- sans le moindre jeton, pouvait lire toutes les conversations privees, en ecrire au nom
-- d'autrui, et expulser des membres d'un salon.
--
-- ON N'A PAS REVOQUE LES DROITS, ON A POSE LA REGLE. Le client ecrit directement dans ces tables
-- (sbEnvoyerMessageChat, sbCreerSalon, sbRejoindreSalon...). Revoquer casserait le chat et
-- exigerait autant de RPC. Une policy adossee a mon_personnage() laisse passer le joueur
-- authentifie et exclut `anon` AUTOMATIQUEMENT, puisque mon_personnage() rend NULL sans jeton.
--
-- LE MODELE, releve dans supabase.js et non suppose : une conversation privee est identifiee par
-- les DEUX NOMS TRIES et joints par '__' ; un salon est identifie par son propre id, et la ligne
-- porte alors salon = true.
--
-- Helper SECURITY DEFINER pour l'appartenance : une policy sur salons_membres qui interrogerait
-- salons_membres se re-declencherait elle-meme. La fonction contourne la RLS, c'est precisement
-- son role ici, et elle ne rend qu'un booleen sur le joueur courant.

CREATE OR REPLACE FUNCTION public.chat_est_membre_salon(p_salon text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.salons_membres m
                  WHERE m.salon_id = p_salon AND m.membre = public.mon_personnage());
$function$;

-- Suis-je partie prenante de cette conversation ? Prive : l'un des deux noms. Salon : membre.
CREATE OR REPLACE FUNCTION public.chat_participe(p_conversation text, p_salon boolean)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN public.mon_personnage() IS NULL THEN false
    WHEN coalesce(p_salon, false) THEN public.chat_est_membre_salon(p_conversation)
    ELSE public.mon_personnage() IN (split_part(p_conversation, '__', 1),
                                     split_part(p_conversation, '__', 2))
  END;
$function$;

REVOKE ALL ON FUNCTION public.chat_est_membre_salon(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.chat_participe(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_est_membre_salon(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.chat_participe(text, boolean) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- messages_chat : on ne lit que ses conversations, on n'ecrit que sous son propre nom.
-- ---------------------------------------------------------------------------------------------
ALTER TABLE public.messages_chat ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lecture publique messages_chat" ON public.messages_chat;
DROP POLICY IF EXISTS "Ecriture publique messages_chat" ON public.messages_chat;
DROP POLICY IF EXISTS messages_chat_lecture_partie ON public.messages_chat;
DROP POLICY IF EXISTS messages_chat_envoi ON public.messages_chat;
CREATE POLICY messages_chat_lecture_partie ON public.messages_chat
  FOR SELECT TO authenticated USING (public.chat_participe(conversation_id, salon));
CREATE POLICY messages_chat_envoi ON public.messages_chat
  FOR INSERT TO authenticated
  WITH CHECK (auteur = public.mon_personnage() AND public.chat_participe(conversation_id, salon));

-- ---------------------------------------------------------------------------------------------
-- salons_chat : visible de ses membres. La creation s'auto-inscrit juste apres (sbCreerSalon),
-- on autorise donc l'insertion a qui se declare createur sous son propre nom.
-- ---------------------------------------------------------------------------------------------
ALTER TABLE public.salons_chat ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lecture publique salons_chat" ON public.salons_chat;
DROP POLICY IF EXISTS "Ecriture publique salons_chat" ON public.salons_chat;
DROP POLICY IF EXISTS salons_chat_lecture_membre ON public.salons_chat;
DROP POLICY IF EXISTS salons_chat_creation ON public.salons_chat;
CREATE POLICY salons_chat_lecture_membre ON public.salons_chat
  FOR SELECT TO authenticated
  USING (public.chat_est_membre_salon(id) OR createur = public.mon_personnage());
CREATE POLICY salons_chat_creation ON public.salons_chat
  FOR INSERT TO authenticated WITH CHECK (createur = public.mon_personnage());

-- ---------------------------------------------------------------------------------------------
-- salons_membres : on voit les membres de SES salons ; on ne s'inscrit et ne se retire que soi.
-- ---------------------------------------------------------------------------------------------
ALTER TABLE public.salons_membres ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lecture publique salons_membres" ON public.salons_membres;
DROP POLICY IF EXISTS "Ecriture publique salons_membres" ON public.salons_membres;
DROP POLICY IF EXISTS "Suppression publique salons_membres" ON public.salons_membres;
DROP POLICY IF EXISTS salons_membres_lecture ON public.salons_membres;
DROP POLICY IF EXISTS salons_membres_rejoindre ON public.salons_membres;
DROP POLICY IF EXISTS salons_membres_quitter ON public.salons_membres;
CREATE POLICY salons_membres_lecture ON public.salons_membres
  FOR SELECT TO authenticated
  USING (membre = public.mon_personnage() OR public.chat_est_membre_salon(salon_id));
CREATE POLICY salons_membres_rejoindre ON public.salons_membres
  FOR INSERT TO authenticated WITH CHECK (membre = public.mon_personnage());
CREATE POLICY salons_membres_quitter ON public.salons_membres
  FOR DELETE TO authenticated USING (membre = public.mon_personnage());

-- ---------------------------------------------------------------------------------------------
-- lectures_chat : un marqueur « lu » n'appartient qu'a son porteur.
-- ---------------------------------------------------------------------------------------------
ALTER TABLE public.lectures_chat ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lecture publique lectures_chat" ON public.lectures_chat;
DROP POLICY IF EXISTS "Ecriture publique lectures_chat" ON public.lectures_chat;
DROP POLICY IF EXISTS "Maj publique lectures_chat" ON public.lectures_chat;
DROP POLICY IF EXISTS lectures_chat_sienne ON public.lectures_chat;
DROP POLICY IF EXISTS lectures_chat_poser ON public.lectures_chat;
DROP POLICY IF EXISTS lectures_chat_majour ON public.lectures_chat;
CREATE POLICY lectures_chat_sienne ON public.lectures_chat
  FOR SELECT TO authenticated USING (membre = public.mon_personnage());
CREATE POLICY lectures_chat_poser ON public.lectures_chat
  FOR INSERT TO authenticated WITH CHECK (membre = public.mon_personnage());
CREATE POLICY lectures_chat_majour ON public.lectures_chat
  FOR UPDATE TO authenticated
  USING (membre = public.mon_personnage()) WITH CHECK (membre = public.mon_personnage());