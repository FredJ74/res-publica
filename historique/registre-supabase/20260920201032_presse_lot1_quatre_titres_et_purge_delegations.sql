-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920201032
-- Nom original      : presse_lot1_quatre_titres_et_purge_delegations
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 20:10:32 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : cacabfbdf5b761463b9065067eea73ce
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
-- ===========================================================================
-- PRESSE — LOT 1, CORRECTIF (20 septembre 2026)
--   1. les quatre titres historiques, et la fin du regime transitoire ;
--   2. la purge automatique des delegations devenues invalides.
-- ===========================================================================

-- --------------------------------------------------------------------------
-- LE NOM D'UN GROUPE DEVIENT FACULTATIF.
--
-- « La Tribune de Republia » est le SEUL nom de groupe de presse attesté dans
-- le depot (plateau-communication.js:2141, :2283, :2500 ; api/journal-interview
-- .js:160). Les trois autres empires ne possedent qu'un nom de TITRE. Plutot
-- que d'inventer trois noms de groupe, la colonne devient nullable : un groupe
-- peut exister sans nom jusqu'a son bapteme. Aucune invention, et le
-- durcissement de journal_id reste possible.
-- --------------------------------------------------------------------------
ALTER TABLE public.groupes_presse ALTER COLUMN nom DROP NOT NULL;

-- --------------------------------------------------------------------------
-- LES TROIS GROUPES HISTORIQUES MANQUANTS, SANS NOM ET SANS MEMBRE.
-- Aucun PJ, aucun directeur, aucun PNJ promu membre attesté.
-- --------------------------------------------------------------------------
INSERT INTO public.groupes_presse (id, pays, nom) VALUES
 ('narco_groupe-presse-historique',   'narco',   NULL),
 ('soviet_groupe-presse-historique',  'soviet',  NULL),
 ('khalija_groupe-presse-historique', 'khalija', NULL)
ON CONFLICT (id) DO NOTHING;

-- --------------------------------------------------------------------------
-- LES TROIS TITRES HISTORIQUES. Noms valides par le game design, tous
-- garantis automatiques comme L'Autruche Entravee.
-- --------------------------------------------------------------------------
INSERT INTO public.journaux (id, groupe_id, pays, nom, slug, garanti_automatique) VALUES
 ('narco_el-narco-times',   'narco_groupe-presse-historique',   'narco',
  'El Narco Times',   'el-narco-times',  true),
 ('soviet_la-pravdovka',    'soviet_groupe-presse-historique',  'soviet',
  'La Pravdovka',     'la-pravdovka',    true),
 ('khalija_le-minaret-dore','khalija_groupe-presse-historique', 'khalija',
  'Le Minaret Doré',  'le-minaret-dore', true)
ON CONFLICT (id) DO NOTHING;

-- --------------------------------------------------------------------------
-- RATTACHEMENT DE TOUTES LES EDITIONS ORPHELINES, contenu inchange.
-- --------------------------------------------------------------------------
UPDATE public.journal_editions e
   SET journal_id = j.id
  FROM public.journaux j
 WHERE e.journal_id IS NULL
   AND j.pays = e.country
   AND j.garanti_automatique;

-- --------------------------------------------------------------------------
-- DURCISSEMENT. Le regime transitoire disparait : plus aucune edition ne peut
-- exister sans titre, et l'unicite porte desormais sur le couple (titre, date)
-- et lui seul. Plusieurs titres d'un meme pays peuvent donc publier le meme
-- jour, ce que l'ancienne regle par pays interdisait structurellement.
-- --------------------------------------------------------------------------
ALTER TABLE public.journal_editions ALTER COLUMN journal_id SET NOT NULL;

DROP INDEX IF EXISTS public.journal_editions_pays_date_sans_titre;
DROP INDEX IF EXISTS public.journal_editions_titre_date_unique;

ALTER TABLE public.journal_editions
  DROP CONSTRAINT IF EXISTS journal_editions_journal_date_unique;
ALTER TABLE public.journal_editions
  ADD CONSTRAINT journal_editions_journal_date_unique UNIQUE (journal_id, date_edition);

-- ===========================================================================
-- PURGE DES DELEGATIONS DEVENUES INVALIDES
--
-- Une delegation confere un pouvoir reel sur un titre : elle ne survit pas a
-- la perte du grade qui permet de l'exercer. La regle est portee par un
-- trigger sur presse_membres, et non par un appelant : aucun chemin futur de
-- changement de grade -- promotion, retrogradation, passation, depart -- ne
-- peut laisser subsister un pouvoir editorial invalide.
--
-- Grades autorises a detenir une delegation : redacteur_chef, et directeur
-- lorsqu'elle lui a ete explicitement accordee. Journaliste et correspondant
-- ne le sont pas.
--
-- Le DELETE est couvert lui aussi : quitter le groupe, ou en etre retire,
-- retire les delegations sur les titres de ce groupe -- un non-membre ne peut
-- pas garder un pouvoir editorial que la RPC d'attribution lui refuserait.
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.presse_delegations_purger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.grade IN ('redacteur_chef','directeur') THEN
    RETURN NULL;
  END IF;

  DELETE FROM public.journaux_redacteurs r
   USING public.journaux j
   WHERE r.journal_id = j.id
     AND j.groupe_id  = OLD.groupe_id
     AND r.personnage = OLD.personnage;

  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_presse_delegations_purger_grade ON public.presse_membres;
CREATE TRIGGER trg_presse_delegations_purger_grade
  AFTER UPDATE OF grade ON public.presse_membres
  FOR EACH ROW EXECUTE FUNCTION public.presse_delegations_purger();

DROP TRIGGER IF EXISTS trg_presse_delegations_purger_depart ON public.presse_membres;
CREATE TRIGGER trg_presse_delegations_purger_depart
  AFTER DELETE ON public.presse_membres
  FOR EACH ROW EXECUTE FUNCTION public.presse_delegations_purger();

REVOKE ALL ON FUNCTION public.presse_delegations_purger() FROM PUBLIC, anon, authenticated;