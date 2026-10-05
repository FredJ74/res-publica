-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925075952
-- Nom original      : securite_jour_de_jeu_borne
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-25 07:59:52 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9cdd7025699b53dde1b7aeb82991ef2a
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
-- LE JOUR DE JEU NE PEUT PLUS FAIRE DE BOND (25 septembre 2026)
-- =============================================================================================
-- CE QUI A ETE DEMONTRE, PAS SUPPOSE. Sur banc, un joueur authentifie a porte son `day` de 5 a 99
-- par un simple PATCH sur la vue `personnages`. Le trigger existant OBSERVAIT la hausse -- il
-- inserait bien une ligne dans fiche_hausses_observees -- mais ne la BORNAIT pas, contrairement a
-- `arg`, `liquide`, `pa`, `stats`, `free_pts_restants` ou `banque` qui sont, eux, re-epingles.
--
-- POURQUOI C'EST GRAVE. `day` indexe les peines et les detentions (jour_debut/jour_fin),
-- l'expiration des crimes, les enquetes, les plaintes, et tous les cooldowns personnels. Porter
-- son jour a 99 purge une peine, efface des crimes et debloque tout ce qui attend « demain ».
--
-- CE QUI EST CERTAIN, ET CE QUI NE L'EST PAS. Les DEUX seuls avanceurs legitimes du jour font
-- +1 : runMidnightUpdate (plateau-core.js:2283) et doDormir (plateau-personnage.js:2089). Un
-- bond de plus d'un cran n'est donc jamais legitime : c'est la seule regle que je rends
-- autoritaire ici, et elle ne change RIEN au jeu normal.
--
-- CE QUE JE NE TRANCHE PAS. Un client obstine peut encore envoyer plusieurs PATCH successifs de
-- +1. Le fermer exigerait de decider COMBIEN d'avancements de jour une journee reelle peut
-- contenir -- or le jeu en autorise aujourd'hui deux (minuit, puis le sommeil que minuit
-- deverrouille). C'est un arbitrage de game design, il est consigne dans le rapport et j'y
-- laisse la question intacte.
--
-- OU : un trigger dedie sur la table de base plutot qu'une reecriture de personnages_vue_modifier
-- -- meme emplacement et meme convention que personnages_attester_poste, et aucun risque
-- d'abimer une fonction de 300 lignes pour trois lignes de regle.
CREATE OR REPLACE FUNCTION public.personnages_borner_jour()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- Le serveur (cron, RPC, service_role) n'est pas concerne : lui peut corriger, reparer,
  -- rattraper un retard. La borne ne vise que ce qui vient d'un navigateur.
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;

  IF NEW.day IS DISTINCT FROM OLD.day AND coalesce(NEW.day, 0) > coalesce(OLD.day, 0) + 1 THEN
    NEW.day := coalesce(OLD.day, 0) + 1;
  END IF;

  -- Le jour ne recule pas non plus : une peine ne s'annule pas en revenant en arriere.
  IF coalesce(NEW.day, 0) < coalesce(OLD.day, 0) THEN
    NEW.day := OLD.day;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_personnages_borner_jour
  BEFORE UPDATE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_borner_jour();