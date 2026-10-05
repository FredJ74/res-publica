-- =====================================================================================
-- VENTES A UNE STRUCTURE — un seul acte attesté : débit + taxe + crédit
-- Res Publica, 17 septembre 2026 (suite de l'audit d'autorité, lot « ventes à une structure »)
--
-- CE QUI EXISTAIT. Trois sites clients suivaient tous le même enchaînement :
--   1. deduireCoutOrdre({pa, cost})            -> débit ATTESTÉ (payer_ordre, miroir ordres_couts)
--   2. appliquerTaxeTransaction(cout)          -> taxe calculée et écrite PAR LE NAVIGATEUR
--   3. crediterCaisseBatiment(pays, id, net)   -> crédit en tir-et-oublie, .catch(() => {})
-- Sites : doFaireDon (plateau-divers.js:728, non taxé), doReserverChambreHotel
-- (plateau-personnage.js:2356, branche hors entreprise), doConsommerBuvette
-- (plateau-actions-illegales-rumeurs.js:6647).
--
-- LES DEUX DEFAUTS PROUVES.
--   a) La TAXE est décidée par le navigateur. Les étapes 2 et 3 sont deux appels distincts
--      du client : un client modifié saute l'étape 2 et crédite le brut. Évasion fiscale
--      complète (taxe locale + nationale) sur chaque nuit d'hôtel et chaque verre de buvette.
--   b) Le débit aboutit SANS le crédit. Les étapes 2 et 3 sont non transactionnelles et leur
--      retour n'est jamais vérifié (`.catch(() => {})`) : le joueur paie, la structure ne
--      reçoit rien, et l'argent disparaît du jeu sans aucun signal.
--
-- CE QUE CETTE RPC CHANGE — ET RIEN D'AUTRE. Aucun nouveau prix, aucun nouveau taux, aucun
-- nouveau bénéficiaire, aucune nouvelle vente. Elle réordonne les trois étapes existantes dans
-- UNE transaction et déplace la décision « taxé ou non » du navigateur vers un registre serveur
-- qui est le miroir exact des trois sites ci-dessus. Le taux appliqué est celui de
-- appliquer_taxe_transaction(), déjà en service pour commerce_vendre_produit et recevoir_soin :
-- mêmes taux, même arrondi, mêmes sous-clés {caisse} / {reserveJour}, sous FOR UPDATE.
--
-- ATOMICITE. Un échec du crédit lève une exception : la fonction s'exécutant dans la transaction
-- de l'appelant, le débit de payer_ordre et l'écriture de taxe sont annulés avec elle. Tout ou rien.
--
-- RESIDU DOCUMENTE, volontairement non fermé ici. p_caisse et p_ville restent transmis par le
-- client. p_caisse est contrainte à l'empire de l'acteur (lu en base, pas déclaré) : une recette
-- ne peut pas être exportée vers un autre empire. Au sein d'un même empire, un client modifié
-- peut encore désigner une autre caisse de son pays ou une autre ville pour la part municipale.
-- Ce n'est pas un gain pour lui (il paie de sa poche dans les deux cas), et le fermer exigerait
-- de faire dériver la caisse bénéficiaire de personnages_donnees.current_building — dont
-- l'écriture est debounced à 3 s côté client : un joueur entrant dans une église et donnant
-- aussitôt serait refusé. La correspondance ordre -> caisse relève d'un arbitrage de modèle.
-- =====================================================================================

CREATE OR REPLACE FUNCTION public.vente_structure_encaisser(
  p_fn text,
  p_pa integer DEFAULT 0,
  p_cost integer DEFAULT 0,
  p_caisse text DEFAULT NULL,
  p_ville text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_acteur text;
  v_pays text;
  v_ville text;
  v_taxable boolean;
  v_paye jsonb;
  v_taxe jsonb := NULL;
  v_net numeric;
  v_credit jsonb;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- REGISTRE SERVEUR DES VENTES A UNE STRUCTURE. Miroir exact des trois seuls sites clients
  -- existants. Tout fn absent est refusé : cette RPC ne doit jamais devenir une API générique
  -- « crédite telle caisse de tel montant ».
  v_taxable := CASE p_fn
    WHEN 'reserver_chambre_hotel' THEN true   -- vente de service, taxée (comportement actuel)
    WHEN 'consommer_buvette'      THEN true   -- vente de boisson, taxée (comportement actuel)
    WHEN 'faire_don'              THEN false  -- un don n'est pas une vente : jamais taxé
    ELSE NULL
  END;
  IF v_taxable IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vente_non_declaree', 'fn', p_fn);
  END IF;

  SELECT coalesce(pd.country, 'republic'),
         coalesce(nullif(btrim(coalesce(p_ville, '')), ''), pd.current_city, 'capitale')
    INTO v_pays, v_ville
    FROM public.personnages_donnees pd
   WHERE pd.name = v_acteur;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- La caisse bénéficiaire porte l'empire en préfixe (convention de crediterCaisseBatiment :
  -- pays || '_' || buildingId). Une vente encaisse dans son propre empire, jamais ailleurs.
  IF coalesce(btrim(coalesce(p_caisse, '')), '') = ''
     OR p_caisse NOT LIKE v_pays || '\_%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_empire', 'caisse', p_caisse);
  END IF;

  -- 1. DEBIT ATTESTE. payer_ordre valide (pa, cost) contre le miroir ordres_couts et refuse
  --    tout montant non déclaré pour cet ordre.
  v_paye := public.payer_ordre(v_acteur, p_fn, p_pa, p_cost);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RETURN v_paye;
  END IF;

  -- 2. TAXE, décidée par le registre ci-dessus et non par l'appelant.
  v_net := coalesce(p_cost, 0);
  IF v_taxable AND v_net > 0 THEN
    v_taxe := public.appliquer_taxe_transaction(v_pays, v_ville, v_net);
    v_net := coalesce((v_taxe->>'net')::numeric, v_net);
  END IF;

  -- 3. CREDIT DE LA STRUCTURE, dans la même transaction. Un échec annule tout ce qui précède.
  IF v_net > 0 THEN
    v_credit := public.caisse_institution_mouvement(p_caisse, v_net, false);
    IF NOT coalesce((v_credit->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'vente_structure: credit impossible sur % (%)',
        p_caisse, coalesce(v_credit->>'raison', 'motif inconnu');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'pa', v_paye->'pa',
    'liquide', v_paye->'liquide',
    'arg', v_paye->'arg',
    'solde_national', v_paye->'solde_national',
    'pa_preleves', v_paye->'pa_preleves',
    'montant_preleve', v_paye->'montant_preleve',
    'net', v_net,
    'taxe', v_taxe,
    'caisse', p_caisse,
    'ville', v_ville);
END;
$$;

-- Le rôle anon n'a aucun usage légitime sur une RPC mutante (un client anon ne peut pas
-- sauvegarder de personnage, donc pas jouer). PUBLIC est nommé explicitement : PostgreSQL
-- accorde EXECUTE à PUBLIC par défaut et authenticated en hérite silencieusement.
REVOKE ALL ON FUNCTION public.vente_structure_encaisser(text, integer, integer, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.vente_structure_encaisser(text, integer, integer, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.vente_structure_encaisser(text, integer, integer, text, text) TO authenticated, service_role;
