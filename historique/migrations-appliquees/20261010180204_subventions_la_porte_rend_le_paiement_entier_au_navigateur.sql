-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010180204 (UTC), nom `subventions_la_porte_rend_le_paiement_entier_au_navigateur`.
-- Le registre passe de 631 a 632 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 a2f10ef7818321b3fd819d6c1aa97918, 2136 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CORRECTIF DU MEME JOUR -- LA PORTE DOIT RENDRE LE PAIEMENT ENTIER
--
-- `subvention_proposer` ne rendait que le solde de points d'action (`'pa', v_paie->'pa'`), alors
-- que la convention du depot est `appliquerPaiementServeur(r.paiement)`, qui attend l'OBJET entier
-- rendu par `payer_ordre` -- le precedent d'`employeur_embaucher`. Une projection partielle laisse
-- le navigateur afficher un liquide perime jusqu'au prochain rechargement. Le corps n'est PAS
-- retape : la definition est relue en base, le fragment exact remplace, et la migration leve si le
-- remplacement n'a rien change -- sinon on croirait avoir corrige en ayant execute l'ancien texte.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CORRECTIF DU MEME JOUR -- LA PORTE DOIT RENDRE LE PAIEMENT ENTIER (10 octobre 2026)
--
-- CE QUE J'AVAIS ECRIT, ET POURQUOI C'ETAIT FAUX. `subvention_proposer` rendait `'pa',
-- v_paie->'pa'` : le seul solde de points d'action. Or la convention du depot est
-- `appliquerPaiementServeur(r.paiement)`, qui attend l'OBJET ENTIER rendu par `payer_ordre` --
-- pa, liquide, arg, solde_national, pa_preleves, montant_preleve. C'est le precedent de
-- `employeur_embaucher`, et il existe pour une raison : l'etat client n'est qu'une PROJECTION de
-- ce que le serveur a ecrit, et une projection partielle laisse le navigateur afficher un
-- liquide perime jusqu'au prochain rechargement.
--
-- LE CORPS N'EST PAS RETAPE. On relit la definition en base, on remplace le fragment exact, et on
-- refuse si le remplacement n'a rien change -- sinon on croirait avoir corrige en ayant execute
-- l'ancien texte.

DO $p$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.subvention_proposer(text,text,numeric)'::regprocedure);
  v_new := replace(v_def,
    '''gestionnaire_connu'', v_gest IS NOT NULL, ''pa'', v_paie->''pa'')',
    '''gestionnaire_connu'', v_gest IS NOT NULL, ''paiement'', v_paie)');
  IF v_new = v_def THEN
    RAISE EXCEPTION 'le fragment a remplacer est absent -- la porte a change depuis sa pose';
  END IF;
  EXECUTE v_new;
END $p$;

DO $p$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.subvention_proposer(text,text,numeric)'::regprocedure);
  IF v_def NOT LIKE '%''paiement'', v_paie%' THEN
    RAISE EXCEPTION 'P1 : la porte ne rend pas le paiement entier'; END IF;
  IF v_def LIKE '%''pa'', v_paie->''pa''%' THEN
    RAISE EXCEPTION 'P2 : l''ancien retour partiel subsiste'; END IF;
  -- P3 : le reste du corps est intact -- les garde-fous sont toujours la.
  IF v_def NOT LIKE '%FOR UPDATE%' OR v_def NOT LIKE '%ON CONFLICT DO NOTHING%'
     OR v_def NOT LIKE '%DELETE FROM public.subventions_municipales WHERE id = v_id%' THEN
    RAISE EXCEPTION 'P3 : le remplacement a abime le corps de la porte'; END IF;
  RAISE NOTICE 'Retour du paiement : 3 preuves vertes.';
END $p$;
