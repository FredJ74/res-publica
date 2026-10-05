-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927163254
-- Nom original      : socle_pnj_gamma_sans_proprietaire
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 16:32:54 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9f8e308871e100803b89029504209bdf
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
-- CHECKPOINT A0 (suite) — UN GAMMA N'A AUCUN PROPRIETAIRE, ET LE SCHEMA DOIT POUVOIR LE DIRE
--
-- `pnj_propriete_exclusive` exigeait un proprietaire : soit un PJ, soit une institution avec son
-- perimetre. C'etait vrai des Alpha et des Beta, qui appartiennent toujours a quelqu'un ou a un
-- service. Mais la classe Gamma est definie par l'ABSENCE de proprietaire : un juge, un garde, un
-- depute n'appartiennent a personne. Le schema rendait donc la classe Gamma inexprimable.
--
-- La contrainte devient conditionnelle a la classe, en ne lisant que la colonne de la ligne (aucune
-- fonction dans une CHECK) :
--   * gamma            -> les trois champs de propriete sont OBLIGATOIREMENT vides ;
--   * tout le reste    -> l'exclusivite d'avant, inchangee (PJ seul, ou institution + perimetre).
--
-- `IS DISTINCT FROM` rend le predicat TOTAL : une classe NULL tombe dans la seconde branche et
-- reste donc soumise a l'ancienne regle. Consequence voulue : pour inscrire un Gamma, il faut
-- declarer `classe = 'gamma'` EXPLICITEMENT sur sa ligne. Le defaut de famille ne suffit pas a
-- dispenser de proprietaire -- on n'obtient pas l'exemption par omission.
ALTER TABLE public.pnj_membres DROP CONSTRAINT pnj_propriete_exclusive;
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_propriete_exclusive CHECK (
      (classe = 'gamma'
         AND proprietaire_pj IS NULL
         AND proprietaire_institution IS NULL
         AND proprietaire_perimetre IS NULL)
   OR (classe IS DISTINCT FROM 'gamma'
         AND ((proprietaire_pj IS NOT NULL
               AND proprietaire_institution IS NULL AND proprietaire_perimetre IS NULL)
           OR (proprietaire_pj IS NULL
               AND proprietaire_institution IS NOT NULL AND proprietaire_perimetre IS NOT NULL))));

COMMENT ON CONSTRAINT pnj_propriete_exclusive ON public.pnj_membres IS
  'Alpha et Beta appartiennent a un PJ OU a une institution avec son perimetre, jamais aux deux. '
  'Gamma n''appartient a personne : ses trois champs de propriete doivent etre vides, et cela exige '
  'classe = gamma declaree explicitement sur la ligne.';