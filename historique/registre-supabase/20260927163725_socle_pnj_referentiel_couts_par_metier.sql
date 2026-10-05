-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927163725
-- Nom original      : socle_pnj_referentiel_couts_par_metier
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 16:37:25 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 53a8ad880b5d2f480c2a6391a069e15a
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
-- CHECKPOINT A2 (1/2) — LE METIER PORTE AUSSI SES COUTS
--
-- « Son METIER ajoute : recruteur, conditions, cout initial, cout recurrent, profil fixe, ordres. »
-- Le profil fixe y etait deja ; les couts le rejoignent, a la meme adresse. Les valeurs ci-dessous
-- sont RELEVEES du code existant, pas choisies : elles reproduisent exactement ce qui est preleve
-- aujourd'hui. Aucun montant n'est invente.
ALTER TABLE public.pnj_metiers_profils
  ADD COLUMN IF NOT EXISTS pa_initial    integer,
  ADD COLUMN IF NOT EXISTS cout_initial  integer,
  ADD COLUMN IF NOT EXISTS cout_jour     integer,
  ADD COLUMN IF NOT EXISTS quota_note    text;

COMMENT ON COLUMN public.pnj_metiers_profils.cout_jour IS
  'Cout recurrent a la charge du proprietaire. NULL = pas de paye personnelle : soit le metier est '
  'gratuit, soit sa paye est institutionnelle (douane, police : cron de minuit sur la caisse).';

UPDATE public.pnj_metiers_profils SET pa_initial = 0, cout_initial = 800, cout_jour = 800,
  quota_note = 'Un par genre, donc deux au maximum. Plus le plafond commun de 10 employes.'
 WHERE metier = 'escort';
UPDATE public.pnj_metiers_profils SET pa_initial = 1, cout_initial = 150, cout_jour = 150,
  quota_note = 'Un seul, tous genres confondus. Le plafond commun de 10 n''est pas verifie par le '
            || 'chemin historique -- ecart releve, non corrige ici.'
 WHERE metier = 'informateur';
UPDATE public.pnj_metiers_profils SET pa_initial = 0, cout_initial = 100, cout_jour = 100,
  quota_note = 'Un seul. METIER NON ACTIVE : aucun PNJ du jeu ne porte job=codetenu.'
 WHERE metier = 'codetenu';
UPDATE public.pnj_metiers_profils SET pa_initial = 2, cout_initial = 0, cout_jour = NULL,
  quota_note = 'Deux au maximum, un recrutement par jour. Gratuit a vie : aucun cout recurrent.'
 WHERE metier = 'militant';
UPDATE public.pnj_metiers_profils SET pa_initial = 0, cout_initial = 0, cout_jour = NULL,
  quota_note = 'Filiere militaire : pas de recrutement individuel paye, pas de paye personnelle.'
 WHERE metier = 'soldat';
UPDATE public.pnj_metiers_profils SET pa_initial = 0, cout_initial = 0, cout_jour = NULL,
  quota_note = 'Effectifs institutionnels : payes par le cron de minuit sur la caisse du service '
            || '(50 FR/jour, 100 pour le cynophile), jamais par un joueur.'
 WHERE metier IN ('douanier','policier');