-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918093303
-- Nom original      : caserne_virement_journalier_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 09:33:03 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8a3aed53af02ec07c69a1ec43b0072e7
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
-- =========================================================================================
-- VIREMENT JOURNALIER VERS LA CASERNE : ECRITURE ATTESTEE (18 septembre 2026)
-- =========================================================================================
-- confirmerVirementJournalier ecrivait budgets_nationaux.virementJournalierCaserne en relisant et
-- reecrivant le blob entier, SANS aucune attestation. Deux consequences : n'importe quel joueur
-- authentifie pouvait fixer depuis la console le montant preleve chaque nuit sur la caisse du
-- Ministere de la Defense, et la reecriture du blob pouvait ecraser les sous-cles modifiees
-- entre-temps par quelqu'un d'autre. Le correctif d'autorite avait ete applique au virement
-- PONCTUEL en son temps ; le journalier avait ete oublie.
--
-- INVENTAIRE DES PRODUCTEURS LEGITIMES, fait avant de fermer quoi que ce soit :
--   1. confirmerVirementJournalier (client)          -> FIXE le montant   -> migre vers la RPC
--   2. traiterVirementJournalierCaserne (client)     -> EXECUTE le virement a minuit
--   3. virementCaserneServeur (api/cron-minuit.js)   -> miroir serveur de 2
--   4. ouvrirGererBudgetMilitaire / lecture d'ecran  -> lecture seule
-- 2 et 3 partagent la cle de journee dernierVirementCaserneJour et n'ecrivent JAMAIS le montant.
-- On ne revoque donc PAS l'UPDATE de la table -- 2 en a besoin, comme des dizaines d'autres
-- producteurs. On verrouille la SOUS-CLE, ce qui est exactement le motif deja en service pour le
-- stock d'armurerie (budgets_armurerie_verrou).
CREATE OR REPLACE FUNCTION public.budgets_virement_caserne_verrou()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF coalesce(current_setting('rp.virement_caserne', true), '') = '1' THEN RETURN NEW; END IF;

  -- Toute autre tentative de modifier CETTE sous-cle est annulee silencieusement : la valeur
  -- precedente est restauree. Le reste de l'ecriture passe normalement -- on ne casse pas les
  -- producteurs legitimes qui reecrivent le blob sans toucher a ce champ.
  IF (NEW.data -> 'virementJournalierCaserne') IS DISTINCT FROM (OLD.data -> 'virementJournalierCaserne') THEN
    NEW.data := CASE WHEN (OLD.data -> 'virementJournalierCaserne') IS NULL
                     THEN NEW.data - 'virementJournalierCaserne'
                     ELSE jsonb_set(NEW.data, '{virementJournalierCaserne}',
                                    OLD.data -> 'virementJournalierCaserne') END;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS budgets_virement_caserne_verrou ON public.budgets_nationaux;
CREATE TRIGGER budgets_virement_caserne_verrou
  BEFORE UPDATE ON public.budgets_nationaux
  FOR EACH ROW EXECUTE FUNCTION public.budgets_virement_caserne_verrou();

-- L'unique chemin legitime pour fixer le montant.
CREATE OR REPLACE FUNCTION public.caserne_virement_journalier_fixer(p_montant integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  c_plafond constant integer := 1000000;
  v_moi text; v_pays text; v_montant integer;
BEGIN
  -- exiger_poste leve si l'acteur n'est pas le Ministre de la Defense ATTESTE.
  v_moi := public.exiger_poste('min_def');
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'appel_serveur_interdit'); END IF;

  -- LA JURIDICTION N'EST PAS UN PARAMETRE : c'est le pays de l'acteur. Un Ministre ne peut donc
  -- pas fixer le virement d'un autre empire, meme en forgeant la requete.
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_montant := greatest(0, least(c_plafond, coalesce(p_montant, 0)));

  PERFORM set_config('rp.virement_caserne', '1', true);
  -- Ecriture par SOUS-CLE sous verrou : aucune reecriture de blob, donc aucun ecrasement des
  -- autres cles (reserveJour, repartition, refectoire, caserneMatieres, stock d'armurerie...).
  UPDATE public.budgets_nationaux
     SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{virementJournalierCaserne}', to_jsonb(v_montant)),
         updated_at = now()
   WHERE id = v_pays;
  PERFORM set_config('rp.virement_caserne', '0', true);

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'montant', v_montant);
END;
$$;

REVOKE ALL ON FUNCTION public.caserne_virement_journalier_fixer(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caserne_virement_journalier_fixer(integer) TO authenticated;