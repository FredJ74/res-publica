-- Régularisation autorisée par le game designer le 31 octobre 2026.
-- Objet : annuler UNIQUEMENT le refinancement BNR excédentaire dû au
-- double débit de la caisse Helvetia, corrigé par la PR #285.
--
-- Rapprochement réel (31/10) :
--  banque privée République, caisse = 0 FR
--  'pret_client'     73 320 FR (nécessaire dans le scénario corrigé)
--  'retrait_client' 150 000 FR (excessif à cause du double débit)
--  total avant :   223 320 FR ; après : 73 320 FR.
--
-- Aucune écriture dans personnages_donnees, comptes_bancaires, prets,
-- caisses_batiments ou toute autre table ; aucune suppression d'historique.
-- L'enregistrement excédentaire est conservé avec le statut 'annule'.
-- Gardes sur les DEUX lignes, leurs montants, taux, dates et statut ;
-- la migration échoue si une donnée a changé depuis le rapprochement.
BEGIN;
DO $regul$
DECLARE
  v_bnr public.bnr_refinancements_helvetia%rowtype;
  v_legitime public.bnr_refinancements_helvetia%rowtype;
  v_encours numeric;
BEGIN
  SELECT * INTO v_legitime FROM public.bnr_refinancements_helvetia
   WHERE id = 'bnr-republic-1793386656-a' FOR UPDATE;
  SELECT * INTO v_bnr FROM public.bnr_refinancements_helvetia
   WHERE id = 'bnr-republic-1793386818-a' FOR UPDATE;

  IF v_legitime.id IS DISTINCT FROM 'bnr-republic-1793386656-a'
     OR v_legitime.country IS DISTINCT FROM 'republic'
     OR v_legitime.motif IS DISTINCT FROM 'pret_client'
     OR v_legitime.montant IS DISTINCT FROM 73320
     OR v_legitime.statut IS DISTINCT FROM 'actif'
     OR v_legitime.interets_cumules IS DISTINCT FROM 0
     OR v_legitime.nb_tranches IS DISTINCT FROM 1
     OR v_legitime.taux_courant IS DISTINCT FROM 5 THEN
    RAISE EXCEPTION 'Refinancement legitime modifie : regularisation interrompue';
  END IF;
  IF v_bnr.id IS DISTINCT FROM 'bnr-republic-1793386818-a'
     OR v_bnr.country IS DISTINCT FROM 'republic'
     OR v_bnr.motif IS DISTINCT FROM 'retrait_client'
     OR v_bnr.montant IS DISTINCT FROM 150000
     OR v_bnr.statut IS DISTINCT FROM 'actif'
     OR v_bnr.interets_cumules IS DISTINCT FROM 0
     OR v_bnr.nb_tranches IS DISTINCT FROM 1
     OR v_bnr.taux_courant IS DISTINCT FROM 5 THEN
    RAISE EXCEPTION 'Refinancement excedentaire modifie : regularisation interrompue';
  END IF;

  SELECT COALESCE(SUM(montant),0) INTO v_encours
   FROM public.bnr_refinancements_helvetia
   WHERE country='republic' AND statut='actif';
  IF v_encours <> 223320 THEN
    RAISE EXCEPTION 'Encours BNR reel modifie : %', v_encours;
  END IF;

  IF (SELECT COALESCE((data->>'solde')::numeric,0)
      FROM public.caisses_batiments
      WHERE id='republic_banque-privee') IS DISTINCT FROM 0 THEN
    RAISE EXCEPTION 'Solde de caisse Helvetia inattendu';
  END IF;

  UPDATE public.bnr_refinancements_helvetia
     SET statut = 'annule', updated_at = now()
   WHERE id = v_bnr.id AND statut='actif';

  IF NOT FOUND THEN RAISE EXCEPTION 'Ligne BNR non annulee'; END IF;
  SELECT COALESCE(SUM(montant),0) INTO v_encours
    FROM public.bnr_refinancements_helvetia
    WHERE country='republic' AND statut='actif';
  IF v_encours <> 73320 THEN
    RAISE EXCEPTION 'Encours BNR apres correction incoherent : %',v_encours;
  END IF;
END $regul$;
COMMIT;
