-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010012605 (UTC), nom `taux_imposition_une_cle_un_paiement_une_transaction`.
-- Le registre passe de 593 a 594 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 3122820ff7eaedef341d0cc402ad240c, 8261 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- TAUX D'IMPOSITION : UNE CLE, UN PAIEMENT, UNE TRANSACTION
--
-- Trois defauts en un. (1) Read-modify-write SANS condition de version : toute modification
concurrente d'un autre champ du budget etait perdue. (2) La cle du budget venait du CLIENT -- un
maire de Luthecia pouvait fixer le taux de Port-Sainte-Marie. (3) Le paiement et le taux etaient
deux appels, et le toast etait inconditionnel : un maire pouvait payer 2 PA sans rien changer.
`taux_imposition_fixer(portee, taux, fn, pa, cost)` derive le territoire du POSTE reel par
`acteur_poste_courant()`, preleve par `payer_ordre` DANS la transaction, et ne touche QU'UNE CLE
par `jsonb_set`. Pas d'acte nocturne : fixer un taux est un acte legitimement repetable.
--
-- ELLE VA PAR PAIRE AVEC : `plateau-justice-economie.js` (`validerImpotsLocauxReel`, `validerImpotNational`,
-- `fixerTauxImposition`, `signalerRefusTauxImposition` ; suppression du doublon mort
-- `ouvrirFixerImpotsLocaux` / `validerImpotsLocaux`).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ===========================================================================
-- CHANTIER 5, CHAINE 8 -- LE TAUX D'IMPOSITION
-- 10 octobre 2026
-- ===========================================================================
--
-- CE QUI ETAIT FAUX, EN TROIS POINTS.
--
-- 1. READ-MODIFY-WRITE SANS CONDITION. validerImpotsLocauxReel relisait tout le blob du budget
--    municipal, posait tauxLocal dedans, et REECRIVAIT LE BLOB ENTIER. Toute modification
--    concurrente d'un autre champ (reserveJour par une recette, un virement) etait perdue. Le
--    projet est passe au compare-and-swap partout ailleurs ; ces deux chemins ne l'avaient pas.
--    La porte ne touche QU'UNE CLE, par jsonb_set cote serveur : plus rien a ecraser.
--
-- 2. LA VILLE ETAIT CHOISIE PAR LE CLIENT. validerImpotsLocauxReel(key, ...) recevait la cle du
--    budget municipal en argument, posee dans le onclick du bouton. Un maire de Luthecia pouvait
--    donc fixer le taux de Port-Sainte-Marie. La porte ne prend PAS de cle : elle derive le pays
--    et la ville du poste reel de l'acteur, par acteur_poste_courant() -- la brique d'autorite
--    deja en service (caisse_refus_autorite s'en sert pour exactement cette question).
--
-- 3. LE PAIEMENT ET LE TAUX ETAIENT DEUX APPELS. deduireCoutOrdre prelevait 2 PA, PUIS le taux
--    etait ecrit sans que son retour soit lu, et le toast « Impots locaux fixes » etait
--    inconditionnel. Un maire pouvait payer sans que rien ne change, et croire le contraire. Le
--    paiement passe maintenant par payer_ordre DANS LA MEME TRANSACTION que l'ecriture du taux :
--    l'un sans l'autre est impossible. Meme attestation qu'avant -- payer_ordre verifie (fn, pa,
--    cost) contre le miroir ordres_couts -- aucun cout n'est invente ici.
--
-- AUCUNE REGLE DE JEU N'EST MODIFIEE. Bornes 0 a 40 % (celles des deux curseurs en service),
-- maire pour le local, min_fin pour le national, 2 PA pour l'ordre local, cout de l'ordre
-- d'ouverture pour le national. La popularite n'est pas touchee : les chemins en service ne la
-- modifiaient pas (seul le doublon mort le faisait -- voir plateau-justice-economie.js).
--
-- POURQUOI PAS actes_nocturnes : fixer un taux est un acte qu'un joueur peut legitimement
-- REFAIRE. La brique protege ce qu'une journee ne doit produire qu'une fois ; elle serait ici un
-- interdit de game design, pas une protection.
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.taux_imposition_fixer(
  p_portee text, p_taux integer, p_fn text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_poste_requis text; v_cle_champ text; v_nom text; v_pays text; v_ville text;
  v_paie jsonb; v_n integer; v_cle text;
BEGIN
  IF p_portee = 'local' THEN
    v_poste_requis := 'maire'; v_cle_champ := 'tauxLocal';
  ELSIF p_portee = 'national' THEN
    v_poste_requis := 'min_fin'; v_cle_champ := 'tauxNational';
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'portee_inconnue');
  END IF;

  IF p_taux IS NULL OR p_taux < 0 OR p_taux > 40 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_hors_bornes');
  END IF;

  -- L'AUTORITE ET LE TERRITOIRE VIENNENT DU POSTE REEL, JAMAIS DU CLIENT.
  SELECT a.nom, a.pays, a.poste_city INTO v_nom, v_pays, v_ville
    FROM public.acteur_poste_courant() a
   WHERE a.poste_id = v_poste_requis
   LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', v_poste_requis);
  END IF;
  IF p_portee = 'local' AND coalesce(btrim(coalesce(v_ville,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maire_sans_ville');
  END IF;

  -- LE PAIEMENT, DANS CETTE TRANSACTION. Son refus arrete tout ; son echec apres l'ecriture du
  -- taux est impossible puisqu'il la precede dans le meme BEGIN.
  v_paie := public.payer_ordre(v_nom, p_fn, coalesce(p_pa,0), coalesce(p_cost,0));
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison',
                              coalesce(v_paie->>'raison','paiement_refuse'),
                              'disponible', v_paie->'disponible');
  END IF;

  -- UNE SEULE CLE EST TOUCHEE : aucun autre champ du blob ne peut etre perdu.
  IF p_portee = 'local' THEN
    v_cle := v_pays || '_' || v_ville;
    UPDATE public.budgets_municipaux
       SET data = jsonb_set(coalesce(data, '{}'::jsonb), ARRAY[v_cle_champ],
                            to_jsonb(p_taux), true),
           updated_at = now()
     WHERE id = v_cle;
  ELSE
    v_cle := v_pays;
    UPDATE public.budgets_nationaux
       SET data = jsonb_set(coalesce(data, '{}'::jsonb), ARRAY[v_cle_champ],
                            to_jsonb(p_taux), true),
           updated_at = now()
     WHERE id = v_cle;
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    -- Le budget n'existe pas : on ne l'invente pas, et le paiement est annule avec le reste.
    RAISE EXCEPTION 'budget_introuvable:%', v_cle USING ERRCODE = 'no_data_found';
  END IF;

  RETURN jsonb_build_object('ok', true, 'portee', p_portee, 'taux', p_taux,
    'cle', v_cle, 'ville', v_ville, 'pays', v_pays,
    'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg',
    'solde_national', v_paie->'solde_national',
    'pa_preleves', v_paie->'pa_preleves', 'montant_preleve', v_paie->'montant_preleve');
EXCEPTION WHEN no_data_found THEN
  RETURN jsonb_build_object('ok', false, 'raison', 'budget_introuvable');
END; $fn$;

REVOKE ALL ON FUNCTION public.taux_imposition_fixer(text, integer, text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.taux_imposition_fixer(text, integer, text, integer, integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.taux_imposition_fixer(text, integer, text, integer, integer)
  TO authenticated, service_role;

DO $$
DECLARE v_def text; v_acl text;
BEGIN
  SELECT pg_get_functiondef(p.oid),
         coalesce(array_to_string(p.proacl::text[], ' | '), '(defaut)')
    INTO v_def, v_acl
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname='public' AND p.proname='taux_imposition_fixer';
  IF v_def IS NULL THEN RAISE EXCEPTION 'P1 : la porte est absente'; END IF;
  IF v_def NOT LIKE '%SECURITY DEFINER%' THEN RAISE EXCEPTION 'P2 : pas SECURITY DEFINER'; END IF;
  -- Un ordre de joueur : authenticated DOIT pouvoir l'appeler, anon JAMAIS.
  IF v_acl LIKE '%anon=%' THEN RAISE EXCEPTION 'P3 : anon peut fixer un impot -- %', v_acl; END IF;
  IF v_acl NOT LIKE '%authenticated=X/postgres%' THEN
    RAISE EXCEPTION 'P3 : le joueur ne peut pas appeler sa propre porte -- %', v_acl; END IF;
  -- P4 : la porte ne prend AUCUNE cle de budget en argument.
  IF pg_get_function_identity_arguments('public.taux_imposition_fixer(text,integer,text,integer,integer)'::regprocedure)
     <> 'p_portee text, p_taux integer, p_fn text, p_pa integer, p_cost integer' THEN
    RAISE EXCEPTION 'P4 : signature inattendue -- %',
      pg_get_function_identity_arguments('public.taux_imposition_fixer(text,integer,text,integer,integer)'::regprocedure); END IF;
  -- P5 : le territoire vient du poste, le paiement est interne, et rien ne reecrit un blob entier.
  IF v_def NOT LIKE '%acteur_poste_courant()%' THEN
    RAISE EXCEPTION 'P5a : le territoire ne vient pas du poste'; END IF;
  IF v_def NOT LIKE '%public.payer_ordre(v_nom, p_fn%' THEN
    RAISE EXCEPTION 'P5b : le paiement n''est pas dans la transaction'; END IF;
  IF (length(v_def) - length(replace(v_def, 'jsonb_set(coalesce(data', ''))) / 22 <> 2 THEN
    RAISE EXCEPTION 'P5c : les deux portees ne passent pas par une mutation ciblee'; END IF;
  -- P6 : les quatre budgets municipaux et le budget national existent toujours.
  IF (SELECT count(*) FROM public.budgets_municipaux) <> 4
     OR NOT EXISTS (SELECT 1 FROM public.budgets_nationaux WHERE id='republic') THEN
    RAISE EXCEPTION 'P6 : le socle budgetaire a change -- % municipaux',
      (SELECT count(*) FROM public.budgets_municipaux); END IF;
  RAISE NOTICE 'taux_imposition_fixer : 6 preuves structurelles conformes.';
END $$;