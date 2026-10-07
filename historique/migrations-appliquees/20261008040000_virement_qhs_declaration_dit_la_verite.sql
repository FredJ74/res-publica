-- =============================================================================
-- LA DERNIERE TRACE DU VIREMENT JOURNALIER QHS DIT CE QU'ELLE EST : UN VERROU
-- Chantier 4F — arbitrage QHS du 8 octobre 2026
--
-- APPLIQUEE le 8 octobre 2026. Inscrite au registre Supabase sous la version
-- 20261007182523 (le registre horodate a l'APPLICATION ; le nom de ce fichier garde
-- l'horodatage de sa redaction).
--
-- CE QUI A ETE VERIFIE APRES COUP. La declaration subsiste, une seule, verrouillee sur min_just
-- -- la retirer aurait rendu la cle librement ecrivable, ce registre etant une LISTE BLANCHE de
-- champs gouvernes. Aucune ligne de budgets_nationaux ne porte de virement journalier, ni pour
-- le QHS ni pour la caserne. Et la seule regle recurrente du QHS est bien sa part declaree a 0 %
-- sous gouvernement-min_int.
-- =============================================================================
--
-- CE QUI A ETE CHERCHE. L'arbitrage demande de prouver qu'aucun ancien automate ni reglage
-- concurrent du QHS ne subsiste. Trois endroits ont ete fouilles, le 8 octobre 2026 :
--
--   . L'AUTOMATE : aucun. `virementJournalierQHS` n'est lu par AUCUNE fonction SQL (pg_proc
--     balaye) ni par aucun fichier du depot -- ni le cron, ni le navigateur. Il n'a jamais
--     existe. L'ecran de la Justice annoncait « FR/jour, AUTOMATIQUE » et rien ne versait.
--   . LE REGLAGE : aucun. La cle est absente des QUATRE lignes de budgets_nationaux -- les
--     seules cles presentes sont caserneMatieres, derniereDistribJour, derniereDistribJourReel,
--     dernierEffetCouvreFeuJour, derniereMecanismesMilitairesJour, derniereSoldeJour,
--     lotsMilitaires, mobilisationNationaleActive, refectoire, reserveJour,
--     stockArmurerieMilitaire et tauxNational. Aucun ministre n'avait donc rien regle.
--   . LA DECLARATION : elle subsiste, dans budget_national_champs_regles, et c'est l'objet de
--     cette migration.
--
-- POURQUOI LA DECLARATION N'EST PAS SUPPRIMEE, ET C'EST CONTRE-INTUITIF.
--
-- budget_national_champs_regles est une LISTE BLANCHE DE CHAMPS GOUVERNES. Le declencheur
-- budget_national_epingler() parcourt ses lignes et REVERTE toute ecriture cliente sur un champ
-- declare dont l'auteur n'occupe pas le poste nomme. Un champ qui n'y figure PAS n'est pas
-- gouverne du tout : il est librement ecrivable par n'importe quel client authentifie.
--
-- Retirer la ligne `virementJournalierQHS` OUVRIRAIT donc le champ au lieu de le fermer. C'est
-- exactement l'inverse du resultat cherche. Le champ est mort -- personne ne le lit -- mais le
-- laisser libre serait une porte ouverte sans raison.
--
-- La ligne reste donc, et son role a change : ce n'est plus la declaration d'une mecanique, c'est
-- un VERROU sur une cle morte. Seule la note change, pour que le registre cesse de decrire une
-- gestion qui n'existe plus et dise ce qu'il fait reellement.
--
-- LE POSTE RESTE min_just, ET C'EST VOULU. Le passer a min_int donnerait au Ministre de
-- l'Interieur le droit d'ecrire un champ que rien ne lit -- on ne deplace pas une autorite vers
-- un champ mort. Le laisser a min_just gele la cle pour tout le monde sauf un titulaire qui n'en
-- ferait rien. La retirer pour de bon, avec la RPC caserne_virement_journalier_fixer et son
-- declencheur de verrou, releve du lot de menage consigne dans DIFFERENCES-DELIBEREES.json.
--
-- LA SEULE REGLE RECURRENTE DU QHS est desormais sa part declaree dans
-- repartitions_budgetaires : Interieur -> QHS, 0 %.
-- =============================================================================

BEGIN;

UPDATE public.budget_national_champs_regles
   SET note = 'CLE MORTE, GELEE VOLONTAIREMENT (8 octobre 2026). virementJournalierQHS n''est lu '
              'par aucune fonction SQL ni par aucun code du depot, et sa valeur est absente de '
              'toutes les lignes de budgets_nationaux : l''ecran de la Justice promettait un '
              'virement journalier automatique que rien n''a jamais applique. Cette ligne '
              'subsiste parce que ce registre est une LISTE BLANCHE : la retirer rendrait la cle '
              'librement ecrivable par tout client authentifie, au lieu de la fermer. Elle ne '
              'declare donc plus une mecanique, elle verrouille un vestige. Le financement du '
              'QHS releve du Ministere de l''Interieur et vit dans repartitions_budgetaires '
              '(Interieur -> QHS, 0 %).'
 WHERE champ = 'virementJournalierQHS';

-- CONTROLE DANS LA TRANSACTION.
DO $$
DECLARE v_n integer; v_poste text; v_valeurs integer;
BEGIN
  SELECT count(*), max(poste_id) INTO v_n, v_poste
    FROM public.budget_national_champs_regles WHERE champ = 'virementJournalierQHS';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'attendu exactement 1 declaration pour virementJournalierQHS, trouve %', v_n;
  END IF;
  IF v_poste IS DISTINCT FROM 'min_just' THEN
    RAISE EXCEPTION 'le verrou doit rester sur min_just, trouve : %', coalesce(v_poste,'NULL');
  END IF;

  -- Aucune valeur residuelle dans les blobs : si l'une apparaissait, ce serait un reglage
  -- survivant et non un simple vestige de declaration.
  SELECT count(*) INTO v_valeurs FROM public.budgets_nationaux
   WHERE data ? 'virementJournalierQHS' OR data ? 'virementJournalierCaserne';
  IF v_valeurs > 0 THEN
    RAISE EXCEPTION '% ligne(s) de budgets_nationaux portent encore un virement journalier', v_valeurs;
  END IF;

  -- Et la seule regle recurrente du QHS est bien sa part declaree, a l'Interieur.
  IF NOT EXISTS (SELECT 1 FROM public.repartitions_budgetaires
                  WHERE beneficiaire = 'qhs-prison' AND source = 'gouvernement-min_int'
                    AND part_pourcent = 0.00) THEN
    RAISE EXCEPTION 'la part Interieur -> QHS a 0 %% est introuvable';
  END IF;
END $$;

COMMIT;
