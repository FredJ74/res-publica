-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924215331
-- Nom original      : securite_invitations_diner_tournees
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-24 21:53:31 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : be61429c1b2305350aec4707361f6298
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
-- Les invitations sociales (diner d'affaires, boire un verre, tournee) sont une affaire entre
-- DEUX personnages. Elles etaient ouvertes en lecture/ecriture/suppression a n'importe qui, y
-- compris sans jeton. Les roles exacts sont ceux qu'ecrit deja le client, rien d'autre.

ALTER TABLE public.invitations_diner ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournees ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------- invitations_diner
-- Lecture : les deux parties. L'inviteur releve la reponse a son invitation
-- (sbGetInvitationsDinerTraitees, sbGetInvitationsTournee) ; l'invite decouvre celles qu'il
-- recoit (sbGetInvitationsDinerRecues, sbGetInvitationsTourneeRecues).
CREATE POLICY "invitation lecture par les deux parties" ON public.invitations_diner
  FOR SELECT TO authenticated
  USING (inviteur = (SELECT public.mon_personnage()) OR invite = (SELECT public.mon_personnage()));

-- Creation : on n'invite qu'en son propre nom.
CREATE POLICY "invitation creee par l inviteur" ON public.invitations_diner
  FOR INSERT TO authenticated
  WITH CHECK (inviteur = (SELECT public.mon_personnage()));

-- Reponse : c'est l'invite, et lui seul, qui accepte ou refuse (sbRepondreInvitationDiner n'est
-- appele que depuis repondreInvitationSociale et repondreTournee, cote invite). L'inviteur
-- n'ecrit jamais dans la ligne apres l'avoir creee.
CREATE POLICY "invitation repondue par l invite" ON public.invitations_diner
  FOR UPDATE TO authenticated
  USING (invite = (SELECT public.mon_personnage()))
  WITH CHECK (invite = (SELECT public.mon_personnage()));

-- Suppression : c'est le menage apres consommation. Le client ne le fait que cote inviteur, mais
-- la ligne appartient aux deux -- un invite qui efface la sienne ne prive que lui-meme.
CREATE POLICY "invitation supprimee par les deux parties" ON public.invitations_diner
  FOR DELETE TO authenticated
  USING (inviteur = (SELECT public.mon_personnage()) OR invite = (SELECT public.mon_personnage()));

-- ---------------------------------------------------------------- tournees
-- Une tournee est l'etat partage d'une invitation collective : l'offreur la pilote, les invites
-- ont besoin de la lire pour savoir ce qu'on leur offre (verifierTourneesRecues lit la boisson et
-- le nom de l'offreur). La sous-requete passe elle-meme par la RLS ci-dessus : elle ne voit que
-- les invitations du lecteur.
CREATE POLICY "tournee lue par l offreur et ses invites" ON public.tournees
  FOR SELECT TO authenticated
  USING (offreur = (SELECT public.mon_personnage())
         OR EXISTS (SELECT 1 FROM public.invitations_diner i
                    WHERE i.tournee_id = tournees.id AND i.invite = (SELECT public.mon_personnage())));

CREATE POLICY "tournee creee par l offreur" ON public.tournees
  FOR INSERT TO authenticated
  WITH CHECK (offreur = (SELECT public.mon_personnage()));

-- Claim de resolution, pa_debite, statut resolue : toutes ces ecritures viennent de
-- verifierTourneesActivesOffreur, qui ne traite que les tournees dont on est l'offreur.
CREATE POLICY "tournee pilotee par l offreur" ON public.tournees
  FOR UPDATE TO authenticated
  USING (offreur = (SELECT public.mon_personnage()))
  WITH CHECK (offreur = (SELECT public.mon_personnage()));

-- Aucune policy DELETE : le jeu ne supprime jamais une tournee (elle est marquee resolue).

-- Un visiteur sans personnage n'a rien a faire ici. Le role anon conservait meme un DELETE sur
-- les invitations.
REVOKE ALL ON public.invitations_diner FROM anon;
REVOKE ALL ON public.tournees FROM anon;
REVOKE DELETE, TRUNCATE ON public.tournees FROM authenticated;