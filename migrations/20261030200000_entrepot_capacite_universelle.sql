-- =============================================================================
-- ENTREPOT LOGISTIQUE : CAPACITE PAR LA REGLE UNIVERSELLE (Claude, 30/10/2026)
-- =============================================================================
-- Defaut (signale au prevol de #260) : acheter_a_entrepot comptait la place libre
-- a sa maniere (qty, sinon encombrement, sinon 1) et ignorait `quantite` : une
-- pile de 10 tracts pesait 1. Il livrait donc au-dela du plafond de 100.
-- Remede : le seul calcul de place devient public.inventaire_place_restante,
-- deja employe par la Criee, l'usine, la manufacture et le depot d'inventaire.
-- Rien d'autre ne change (texte de depart identique a la production, md5
-- 988dddeaf4edf72e74897356e23f157b). La porte a cle de #260 appelle cette
-- fonction : elle en beneficie sans modification. Droits conserves (CREATE OR
-- REPLACE) : la signature sans cle reste fermee au joueur.
-- Banc : outils/bancs/banc-entrepot-capacite.sql (transaction annulee).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.acheter_a_entrepot(p_acteur text, p_pays text, p_ville text, p_batiment text, p_achats jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_etat jsonb; v_entrepot jsonb; v_stock jsonb; v_reserve jsonb; v_prix_manuel jsonb;
  v_cle text; v_qte int; v_dispo numeric; v_prix numeric;
  v_total numeric := 0; v_lignes jsonb := '[]'::jsonb;
  v_inv jsonb; v_occupe int; v_place int; v_ajoute int;
  v_liquide numeric; v_arg numeric; v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric; v_paye numeric := 0;
  v_idx int; v_ligne jsonb; v_existe boolean;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  -- CIRCUIT LEGAL (30 septembre 2026) : achat de matieres a l'Entrepot logistique.
  -- Tout le panier est examine : une seule matiere interdite suffit a refuser,
  -- avant le moindre debit et avant la moindre entree en inventaire.
  IF public.matiere_refus_circuit_legal_lot(p_acteur, p_achats, 'achat') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal_lot(p_acteur, p_achats, 'achat');
  END IF;
  IF p_achats IS NULL OR jsonb_typeof(p_achats) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'achats_absents');
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat
  FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable', 'id', v_id);
  END IF;
  v_entrepot := coalesce(v_etat->'entrepot', '{}'::jsonb);
  v_stock := coalesce(v_entrepot->'stock', '{}'::jsonb);
  v_reserve := coalesce(v_entrepot->'reserveMilitaire', '{}'::jsonb);
  v_prix_manuel := coalesce(v_entrepot->'prixManuel', '{}'::jsonb);

  -- Inventaire et fonds du joueur, sous verrou.
  SELECT coalesce(inventory, '[]'::jsonb), coalesce(liquide,0), coalesce(arg,0)
    INTO v_inv, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);

  -- Place restante : la regle universelle (30/10/2026), comme la Criee, l'usine,
  -- la manufacture et inventaire_deposer_interne. L'ancien calcul local ignorait
  -- la quantite des piles a `quantite` (tracts) : 87 bois livres pour 86 places.
  v_place := public.inventaire_place_restante(v_inv);

  -- Premiere passe : validation. Aucune mutation avant d'etre sur de tout.
  FOR v_cle, v_qte IN SELECT key, (value #>> '{}')::int FROM jsonb_each(p_achats)
  LOOP
    IF v_qte IS NULL OR v_qte <= 0 THEN CONTINUE; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    -- Stock CIVIL disponible = stock physique moins la reserve militaire.
    v_dispo := greatest(0, coalesce((v_stock->>v_cle)::numeric, 0)
                          - coalesce((v_reserve->>v_cle)::numeric, 0));
    IF v_qte > v_dispo THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant',
                                'cle', v_cle, 'disponible', v_dispo);
    END IF;
    SELECT coalesce((v_prix_manuel->>v_cle)::numeric, r.prix_base) INTO v_prix
    FROM public.ressources_economie r WHERE r.cle = v_cle;
    v_total := v_total + v_qte * v_prix;
    v_lignes := v_lignes || jsonb_build_object('cle', v_cle, 'qte', v_qte, 'prix', v_prix);
  END LOOP;

  IF jsonb_array_length(v_lignes) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_acheter');
  END IF;
  IF v_liquide + v_solde < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'requis', v_total, 'disponible', v_liquide + v_solde);
  END IF;

  -- Seconde passe : application. Comme cote client, un lot empilable peut entrer
  -- PARTIELLEMENT si la place manque, et seul ce qui entre est paye.
  FOR v_idx IN 0 .. jsonb_array_length(v_lignes) - 1 LOOP
    v_ligne := v_lignes -> v_idx;
    v_cle := v_ligne->>'cle';
    v_ajoute := least((v_ligne->>'qte')::int, v_place);
    IF v_ajoute <= 0 THEN CONTINUE; END IF;
    v_place := v_place - v_ajoute;
    v_paye := v_paye + v_ajoute * (v_ligne->>'prix')::numeric;

    SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e
                   WHERE e->>'stackKey' = v_cle) INTO v_existe;
    IF v_existe THEN
      SELECT jsonb_agg(CASE WHEN e->>'stackKey' = v_cle
                            THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e->>'qty')::numeric,1) + v_ajoute))
                            ELSE e END)
        INTO v_inv FROM jsonb_array_elements(v_inv) e;
    ELSE
      v_inv := v_inv || jsonb_build_array(jsonb_build_object(
        'name', (SELECT cle FROM public.ressources_economie WHERE cle = v_cle),
        'stackable', true, 'stackKey', v_cle, 'qty', v_ajoute,
        'desc', 'Ressource achetée à l''entrepôt logistique.'));
    END IF;

    v_stock := jsonb_set(v_stock, ARRAY[v_cle],
                         to_jsonb(coalesce((v_stock->>v_cle)::numeric,0) - v_ajoute));
  END LOOP;

  IF v_paye <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  -- Debit : liquide d'abord, Banque nationale en complement (regle inchangee).
  v_pris_liquide := least(v_liquide, v_paye);
  v_pris_national := v_paye - v_pris_liquide;
  UPDATE public.personnages_donnees
     SET inventory = v_inv, liquide = v_liquide - v_pris_liquide, arg = v_arg - v_paye
   WHERE name = p_acteur;
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national, updated_at = now()
     WHERE id = v_compte_id;
  END IF;

  -- Le produit de la vente revient a la caisse de l'entrepot : sans quoi l'argent
  -- paye par le joueur disparaitrait sans contrepartie.
  v_entrepot := v_entrepot || jsonb_build_object('stock', v_stock,
                  'caisse', coalesce((v_entrepot->>'caisse')::numeric, 0) + v_paye);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('entrepot', v_entrepot))::text),
         updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'paye', v_paye, 'lignes', v_lignes,
    'inventory', v_inv, 'liquide', v_liquide - v_pris_liquide, 'arg', v_arg - v_paye,
    'solde_national', v_solde - v_pris_national,
    'caisse_entrepot', (v_entrepot->>'caisse')::numeric);
END;
$function$;

NOTIFY pgrst, 'reload schema';
