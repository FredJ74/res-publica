-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010004339 (UTC), nom `taxe_fonciere_un_terrain_une_journee_une_transaction`.
-- Le registre passe de 586 a 587 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 9c154cc0119cd0684edd84ef79a02e99, 11 536 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- TAXE FONCIERE : UN TERRAIN, UNE JOURNEE, UNE TRANSACTION
--
-- `taxe_fonciere_prelever(terrain)` revendique un acte nocturne par (pays, 'taxe_fonciere',
terrain, jour) PUIS fait tout dans une transaction : taux municipal, debit du proprietaire,
recette municipale, ou bien dette, penalite de 10 % et saisie. Sans elle, une seconde execution
le meme jour redebitait la taxe et faisait avancer de DEUX crans la progression avertissement ->
penalite -> saisie municipale. Ici la brique est le bon verrou : une journee ne preleve qu'une
fois.
--
-- ELLE VA PAR PAIRE AVEC : `api/cron-minuit.js` (`preleverTaxeFonciere`, 4511 -> 2654 caracteres).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- Chantier 6, famille A -- LA TAXE FONCIERE N'AVAIT AUCUN MARQUEUR, ET DEUX MOITIES D'ACTE.
--
-- CE QUI SE PASSAIT. `preleverTaxeFonciere` (api/cron-minuit.js) balayait les terrains et, pour
-- chacun, debitait le proprietaire PUIS ecrivait le blob du terrain -- deux requetes HTTP. Puis,
-- APRES la boucle, elle creditait les mairies par commune. Trois consequences, toutes
-- atteignables :
--
--   1. AUCUN MARQUEUR PAR TERRAIN. Une seconde execution le meme jour redebitait la taxe, et
--      pour un insolvable faisait avancer de deux crans la progression
--      avertissement -> penalite de 10 % -> SAISIE MUNICIPALE.
--   2. DEUX MOITIES D'ACTE. Une interruption entre le debit et l'ecriture du blob prelevait sans
--      remettre `dette_fonciere` a zero : la passe suivante redebitait, et la dette restait.
--   3. L'ARGENT POUVAIT DISPARAITRE. Le debit des proprietaires et le credit des mairies etaient
--      separes par toute la boucle. Une panne entre les deux prelevait les joueurs sans que
--      personne n'encaisse.
--
-- LA BRIQUE EST APPROPRIEE ICI, ET CE N'EST PAS AUTOMATIQUE. On a verifie qu'aucune transition
-- d'etat ne protegeait deja : `dette_fonciere = 0` n'empeche rien, puisque la taxe est due CHAQUE
-- jour. Le sujet de la revendication est donc le TERRAIN -- `actes_nocturnes(pays,
-- 'taxe_fonciere', <id du terrain>, <jour>)` -- parce que c'est le terrain, et non la commune ni
-- le pays, qu'une journee ne doit imposer qu'une fois.
--
-- ET LE CREDIT DE LA MAIRIE ENTRE DANS LA MEME TRANSACTION. `recette_municipale` est additive
-- (`ON CONFLICT DO UPDATE SET montant = montant + excluded.montant`) : l'appeler une fois par
-- terrain au lieu d'une fois par commune donne exactement le meme total au compteur du jour, et
-- rend le debit inseparable de l'encaissement. Si la mairie ne peut pas encaisser, la porte LEVE
-- -- le proprietaire n'est alors pas debite du tout, ce qui est le seul etat honnete.
--
-- L'ORDRE DES CONTROLES COMPTE. Terrain, assiette, budget municipal et proprietaire sont
-- verifies AVANT la revendication : un terrain hors assiette ne doit pas consommer sa journee.
--
-- AUCUNE REGLE DE JEU NE CHANGE : meme taux (`tauxFoncier` du budget municipal, 0,05 par defaut),
-- meme arrondi a deux decimales, meme valeur de repli (surface x 12), memes seuils de ratio
-- (0,15 pour la penalite de 10 %, 0,25 pour la saisie), meme prix de remise en vente (70 % de la
-- valeur) et meme evenement public.
--
-- ETAT DE LA BETA AU MOMENT DE CE LOT : aucun terrain n'a a la fois un proprietaire et une
-- surface, donc l'assiette est VIDE -- ce que le journal du cron confirme (`collecte: 0`). Les
-- epreuves comportementales ont donc tourne sur des terrains de banc, en transaction annulee.
--
-- Banc : 7 epreuves vertes, dont le double debit, le double credit et le cran de saisie evites.
INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note)
VALUES ('taxe_fonciere', false,
        'Taxe fonciere d''un terrain : debit du proprietaire et credit de la mairie dans une transaction, ou accumulation de la dette jusqu''a la saisie municipale. Un rejeu redebiterait la taxe et avancerait d''un cran vers la saisie. Un sujet par TERRAIN : chaque bien est impose une fois par jour.')
ON CONFLICT (mecanisme) DO NOTHING;

CREATE OR REPLACE FUNCTION public.taxe_fonciere_prelever(p_terrain_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_pays text; v_data jsonb; v_ville text; v_proprio text; v_budget jsonb;
  v_taux numeric; v_taxe numeric; v_valeur numeric; v_arg numeric; v_existe boolean;
  v_dette numeric; v_nouvelle numeric; v_ratio numeric; v_action text; v_rec jsonb;
BEGIN
  SELECT t.country, t.data::jsonb INTO v_pays, v_data
    FROM public.terrains_etat t WHERE t.id = p_terrain_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok',false,'action','terrain_introuvable'); END IF;
  v_ville   := coalesce(nullif(btrim(coalesce(v_data->>'city','')),''), 'capitale');
  v_proprio := nullif(btrim(coalesce(v_data->>'proprietaire','')),'');
  -- HORS ASSIETTE : pas de proprietaire ou pas de surface. Verifie AVANT la revendication, pour
  -- ne pas consommer la journee d'un terrain qu'on n'impose pas.
  IF v_proprio IS NULL OR (v_data->>'surface') IS NULL THEN
    RETURN jsonb_build_object('ok',false,'action','hors_assiette'); END IF;
  SELECT b.data INTO v_budget FROM public.budgets_municipaux b
   WHERE b.id = v_pays || '_' || v_ville;
  IF v_budget IS NULL THEN
    RETURN jsonb_build_object('ok',false,'action','budget_municipal_absent'); END IF;
  SELECT true, coalesce(arg,0) INTO v_existe, v_arg FROM public.personnages
   WHERE name = v_proprio FOR UPDATE;
  IF NOT coalesce(v_existe,false) THEN
    RETURN jsonb_build_object('ok',false,'action','proprietaire_introuvable'); END IF;

  -- LA REVENDICATION, par terrain et par jour, DANS cette transaction.
  IF NOT public.acte_nocturne_revendiquer(v_pays, 'taxe_fonciere', p_terrain_id,
         jsonb_build_object('ville', v_ville, 'proprietaire', v_proprio)) THEN
    RETURN jsonb_build_object('ok',false,'action','deja_prelevee_aujourdhui'); END IF;

  v_taux   := coalesce(nullif(v_budget->>'tauxFoncier','')::numeric, 0.05);
  v_taxe   := round(((v_data->>'surface')::numeric * v_taux)::numeric, 2);
  v_valeur := coalesce(nullif(v_data->>'valeur_totale','')::numeric,
                       (v_data->>'surface')::numeric * 12);

  IF v_arg >= v_taxe THEN
    UPDATE public.personnages SET arg = v_arg - v_taxe WHERE name = v_proprio;
    v_data := jsonb_set(v_data, '{dette_fonciere}', '0'::jsonb, true);
    v_action := 'collectee';
    -- LE CREDIT DE LA MAIRIE EST INSEPARABLE DU DEBIT. Si elle ne peut pas encaisser, on LEVE :
    -- le proprietaire n'est alors pas debite du tout.
    v_rec := public.recette_municipale(v_pays, v_ville, v_taxe, 'taxe_fonciere');
    IF NOT coalesce((v_rec->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'taxe_fonciere_prelever : la mairie de % n''a pas pu encaisser (%)',
            v_ville, coalesce(v_rec->>'raison','verdict_absent');
    END IF;
  ELSE
    v_dette    := coalesce(nullif(v_data->>'dette_fonciere','')::numeric, 0);
    v_nouvelle := v_dette + v_taxe;
    v_ratio    := CASE WHEN v_valeur > 0 THEN v_nouvelle / v_valeur ELSE 0 END;
    IF v_ratio >= 0.25 THEN
      v_data := v_data || jsonb_build_object('proprietaire', NULL, 'coproprietaire', NULL,
                  'enVenteParMairie', true, 'prixVenteMairie', round(v_valeur * 0.7),
                  'dette_fonciere', 0);
      v_action := 'saisie';
      INSERT INTO public.evenements_globaux (country, city, texte, jour)
      VALUES (v_pays, v_ville,
        '🏛️ SAISIE MUNICIPALE : un bien a été saisi pour non-paiement de la taxe foncière et sera remis en vente.',
        NULL);
    ELSE
      v_data := jsonb_set(v_data, '{dette_fonciere}',
        to_jsonb(CASE WHEN v_ratio >= 0.15 THEN round(v_nouvelle * 1.10) ELSE v_nouvelle END), true);
      v_action := 'avertissement';
    END IF;
  END IF;
  UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;
  RETURN jsonb_build_object('ok',true,'action',v_action,'montant',v_taxe,
                            'ville',v_ville,'proprietaire',v_proprio);
END; $fn$;

COMMENT ON FUNCTION public.taxe_fonciere_prelever(text) IS
'Impose UN terrain pour la journee, en une transaction revendiquee par
acte_nocturne_revendiquer(''taxe_fonciere'', <id du terrain>) : debit du proprietaire ET credit de
la mairie si le compte suit, sinon accumulation de la dette avec sa penalite de 10 % puis saisie
municipale. Un rejeu n''atteint ni le debit ni la progression vers la saisie. Verdicts :
terrain_introuvable, hors_assiette, budget_municipal_absent, proprietaire_introuvable,
deja_prelevee_aujourdhui, puis ok avec action collectee / avertissement / saisie.
Non appelable depuis le reseau.';

DO $$
DECLARE v_def text; v_n int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace AND n.nspname='public'
   WHERE p.proname='taxe_fonciere_prelever';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 ECHOUEE -- la porte n''existe pas'; END IF;

  -- P1 : LA REVENDICATION EST APRES LES PRECONDITIONS ET AVANT LE DEBIT.
  IF position('acte_nocturne_revendiquer' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- aucune revendication'; END IF;
  IF position('hors_assiette' in v_def) >= position('acte_nocturne_revendiquer' in v_def) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- un terrain hors assiette consommerait sa journee'; END IF;
  IF position('acte_nocturne_revendiquer' in v_def) >= position('UPDATE public.personnages SET arg' in v_def) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le debit precede la revendication'; END IF;
  IF position('''taxe_fonciere'', p_terrain_id' in v_def) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le sujet revendique n''est pas le terrain'; END IF;

  -- P2 : LE DEBIT ET LE CREDIT SONT DANS LA MEME FONCTION, et un credit refuse LEVE.
  IF position('public.recette_municipale' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la mairie n''est pas creditee ici'; END IF;
  IF position('RAISE EXCEPTION ''taxe_fonciere_prelever : la mairie' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- un encaissement refuse laisserait le proprietaire debite'; END IF;
  IF position('FOR UPDATE' in v_def) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- ni le terrain ni le proprietaire ne sont verrouilles'; END IF;

  -- P3 : LES SEUILS ET LES TAUX SONT CEUX DU JEU, AU CHIFFRE PRES.
  IF position('0.05' in v_def) = 0 OR position('>= 0.25' in v_def) = 0
     OR position('>= 0.15' in v_def) = 0 OR position('* 1.10' in v_def) = 0
     OR position('* 0.7' in v_def) = 0 OR position('* 12' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- un seuil, un taux ou une valeur de repli a change'; END IF;
  IF position('SAISIE MUNICIPALE' in v_def) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- l''evenement public de saisie a disparu'; END IF;

  -- P4 : droits. Acte de minuit : injoignable depuis le reseau.
  IF has_function_privilege('authenticated','public.taxe_fonciere_prelever(text)','EXECUTE')
     OR has_function_privilege('anon','public.taxe_fonciere_prelever(text)','EXECUTE') THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- un navigateur peut lever la taxe fonciere'; END IF;
  IF NOT has_function_privilege('service_role','public.taxe_fonciere_prelever(text)','EXECUTE') THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le cron ne peut pas appeler la porte'; END IF;

  -- P5 : le mecanisme est a la liste blanche, et il n'est PAS singleton -- un sujet par terrain.
  SELECT count(*) INTO v_n FROM public.actes_nocturnes_mecanismes
   WHERE mecanisme='taxe_fonciere' AND sujet_singleton = false;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 ECHOUEE -- mecanisme absent ou singleton'; END IF;

  -- P6 : AUCUNE DONNEE TOUCHEE, et aucun terrain de banc.
  SELECT count(*) INTO v_n FROM public.terrains_etat WHERE id LIKE 'zzt-%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % terrain(s) de banc', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.actes_nocturnes;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % acte(s) nocturne(s)', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.evenements_globaux WHERE texte LIKE '%SAISIE MUNICIPALE%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % evenement(s) de saisie', v_n; END IF;

  RAISE NOTICE 'SIX PREUVES STRUCTURELLES VERTES.';
END $$;