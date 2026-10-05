-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919225034
-- Nom original      : forum_propriete_des_messages
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 22:50:34 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 1c2fbc2328da4f0155b33082142c42f3
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
-- LOT P0-A / INCREMENT 5 — ON N'EDITE PLUS LES MESSAGES DES AUTRES
-- =====================================================================
-- L'AUDIT A DEMONTRE : forum_topics et forum_posts portaient la meme policy
-- allow_all FOR ALL USING(true) WITH CHECK(true) que mails. Tous les update et
-- delete du client filtrent sur id=eq.<id> SEUL, jamais sur l'auteur. La seule
-- verification de propriete du systeme etait l'emission conditionnelle du bouton
-- « editer » dans un gabarit HTML -- editPost() et executerSuppressionPost()
-- restent des fonctions globales qui ne retestent rien.
--
-- CE QUI NE CHANGE PAS :
--   * la LECTURE reste ouverte. Le forum est public par construction ; les
--     forums prives (gouvernement, org_*) sont aujourd'hui filtres cote client
--     par canAccessForum(). C'est une fuite distincte, qui demande de porter les
--     regles d'acces cote serveur -- elle est consignee, pas traitee ici, parce
--     qu'elle exige un arbitrage sur QUI a le droit de lire quoi.
--   * les 4 declencheurs BEFORE INSERT existants (forum_verrou_message_ligue,
--     forum_local_territorial, forum_verrou_compte_rendu, forum_verrou_programme)
--     sont intacts : ils s'executent avant la policy et gardent leur role.
--
-- MODERATION : il n'existe aujourd'hui AUCUN role de moderation dans le jeu --
-- ni colonne, ni fonction, ni poste. Aucune exception n'est donc ecrite ici :
-- en inventer une reviendrait a creer une mecanique. Le jour ou la moderation
-- sera arbitree, elle s'ajoutera comme une policy supplementaire.

DROP POLICY IF EXISTS allow_all_forum_posts  ON public.forum_posts;
DROP POLICY IF EXISTS allow_all_forum_topics ON public.forum_topics;

-- ------------------------------------------------------------------ SUJETS
CREATE POLICY forum_topics_lecture ON public.forum_topics
  FOR SELECT USING (true);

CREATE POLICY forum_topics_creation ON public.forum_topics
  FOR INSERT TO authenticated
  WITH CHECK (author = public.mon_personnage()
           OR author_real = public.mon_personnage());

CREATE POLICY forum_topics_maj_auteur ON public.forum_topics
  FOR UPDATE TO authenticated
  USING (author = public.mon_personnage() OR author_real = public.mon_personnage())
  WITH CHECK (author = public.mon_personnage() OR author_real = public.mon_personnage());

CREATE POLICY forum_topics_suppression_auteur ON public.forum_topics
  FOR DELETE TO authenticated
  USING (author = public.mon_personnage() OR author_real = public.mon_personnage());

-- ---------------------------------------------------------------- MESSAGES
CREATE POLICY forum_posts_lecture ON public.forum_posts
  FOR SELECT USING (true);

CREATE POLICY forum_posts_creation ON public.forum_posts
  FOR INSERT TO authenticated
  WITH CHECK (author = public.mon_personnage()
           OR author_real = public.mon_personnage());

CREATE POLICY forum_posts_maj_auteur ON public.forum_posts
  FOR UPDATE TO authenticated
  USING (author = public.mon_personnage() OR author_real = public.mon_personnage())
  WITH CHECK (author = public.mon_personnage() OR author_real = public.mon_personnage());

CREATE POLICY forum_posts_suppression_auteur ON public.forum_posts
  FOR DELETE TO authenticated
  USING (author = public.mon_personnage() OR author_real = public.mon_personnage());

-- L'ecriture anonyme n'a plus lieu d'etre : le jeu exige une session nominative.
REVOKE INSERT, UPDATE, DELETE ON public.forum_topics FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.forum_posts  FROM anon;