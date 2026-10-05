-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927013425
-- Nom original      : socle_pnj_gardes_suppression_fail_closed
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 01:34:25 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4af346992685d22a5fcf95e009fd56d1
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
-- DEUX GARDES FAIL-CLOSED SUR LA DISPARITION (27 septembre 2026)
--
-- PREUVE METIER D'ABORD, GARDE ENSUITE. Avant de refuser quoi que ce soit, j'ai recense tous les
-- chemins qui retirent un soldat du blob. Il y en a exactement UN :
--   militaire_soldat_supprimer, appelee uniquement par militaire_bataille_appliquer, uniquement
--   a 0 PA -- donc la mort.
-- Les trois suspects se sont reveles innocents, et c'est ce qui autorise une garde STRICTE :
--   militaire_desertions_verifier    -- ne touche que `civilsRequisitionnes`, jamais `soldats`
--   militaire_presentation_affectation -- idem
--   militaire_soldat_retirer         -- ne retire que des soldats PJ (sol->>'pj' vrai), que le
--                                       miroir ignore deja par construction
-- Sans cette verification j'aurais pu casser la desertion en refusant une suppression legitime.
--
-- GARDE 1 -- ON NE SUPPRIME PAS UN PNJ VIVANT.
-- La suppression est legitime, mais seulement APRES le cycle de mort. Le chemin de bataille pose
-- desormais statut='mort' avant de retirer l'homme du blob, donc il passe. Tout autre chemin --
-- present ou futur -- est refuse au lieu de faire disparaitre un homme avec son inventaire, son
-- argent et sans avis a son proprietaire. C'est une garde, pas une regle de dissolution : elle
-- n'invente aucun comportement, elle exige seulement qu'on passe par celui qui existe.
CREATE OR REPLACE FUNCTION public.pnj_garde_suppression()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF OLD.statut = 'actif' THEN
    RAISE EXCEPTION 'pnj_garde_suppression: refus de supprimer le PNJ vivant % (%). Le cycle de '
      'mort n a pas eu lieu : ses possessions seraient detruites et son proprietaire jamais '
      'informe. Appeler pnj_mourir() d abord, ou corriger le statut si la disparition est voulue.',
      OLD.id, OLD.nom
      USING ERRCODE = 'raise_exception';
  END IF;
  RETURN OLD;
END; $$;
DROP TRIGGER IF EXISTS trg_pnj_garde_suppression ON public.pnj_membres;
CREATE TRIGGER trg_pnj_garde_suppression BEFORE DELETE ON public.pnj_membres
  FOR EACH ROW EXECUTE FUNCTION public.pnj_garde_suppression();

-- GARDE 2 -- ON NE DISSOUT PAS UNE COMPAGNIE QUI A ENCORE DES PNJ DANS LE SOCLE.
-- Le declencheur miroir ne couvre que INSERT et UPDATE : supprimer la ligne de compagnie
-- laisserait des soldats orphelins, dont le perimetre designerait une compagnie disparue.
-- L'autorite se resoudrait alors a PERSONNE pour toujours -- degradation sans danger, mais
-- SILENCIEUSE. Aucune regle de dissolution n'existe dans le jeu ; je n'en invente pas une, je
-- refuse l'operation en disant quoi faire.
CREATE OR REPLACE FUNCTION public.pnj_garde_dissolution_compagnie()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_n integer;
BEGIN
  SELECT count(*) INTO v_n FROM public.pnj_membres WHERE id LIKE OLD.id || '-%';
  IF v_n > 0 THEN
    RAISE EXCEPTION 'pnj_garde_dissolution_compagnie: refus de supprimer la compagnie % : % PNJ '
      'du socle en dependent et deviendraient orphelins (perimetre pointant vers une compagnie '
      'disparue). Aucune regle de dissolution n existe : traiter le sort de ces hommes d abord.',
      OLD.id, v_n
      USING ERRCODE = 'raise_exception';
  END IF;
  RETURN OLD;
END; $$;
DROP TRIGGER IF EXISTS trg_pnj_garde_dissolution_compagnie ON public.compagnies_militaires;
CREATE TRIGGER trg_pnj_garde_dissolution_compagnie BEFORE DELETE ON public.compagnies_militaires
  FOR EACH ROW EXECUTE FUNCTION public.pnj_garde_dissolution_compagnie();

-- La trace n'a plus de raison d'etre : la garde REFUSE au lieu de constater apres coup.
DROP FUNCTION IF EXISTS public.pnj_miroir_tracer_disparitions(text, text[]);

REVOKE ALL ON FUNCTION public.pnj_garde_suppression() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_garde_dissolution_compagnie()
  FROM PUBLIC, anon, authenticated;