-- Versions de PRODUCTION (relevees le 30/10/2026) de fonctions modifiees hors du depot.
-- Appliquees par monter-base-jetable.sh apres baseline + migrations. A rafraichir si la
-- comparaison d empreintes (jetable-empreintes.sql) signale un nouvel ecart.
CREATE OR REPLACE FUNCTION public.inventaire_place_restante(p_inv jsonb)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT greatest(0,100-coalesce((
 SELECT sum(CASE
   WHEN coalesce(e->>'quantite','') ~ '^[0-9]+$' THEN (e->>'quantite')::numeric
   WHEN coalesce(e->>'qty','') ~ '^[0-9]+$' THEN (e->>'qty')::numeric
   WHEN coalesce(e->>'encombrement','') ~ '^[0-9]+$' THEN (e->>'encombrement')::numeric
   ELSE 1 END)
 FROM jsonb_array_elements(coalesce(p_inv,'[]'::jsonb)) e),0))::integer;
$function$
;
CREATE OR REPLACE FUNCTION public.payer_ordre(p_acteur text, p_fn text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_fn text := coalesce(nullif(btrim(coalesce(p_fn,'')), ''), '(non transmis)');
  v_acquisition boolean;
  v_connu boolean; v_valide boolean;
  v_pa integer; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric;
  v_memorable record; v_pays text;
BEGIN
  IF v_fn='louer_lot_ici' THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  IF v_fn = 'deposer_demande_permis' AND NOT EXISTS (
    SELECT 1 FROM public.permis_transactions_internes WHERE transaction_id=txid_current() AND acteur=auth.uid()
  ) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise'); END IF;
  PERFORM public.exiger_acteur(p_acteur);
  v_acquisition:=EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=p_acteur AND ((a.ordre=v_fn AND a.pa=p_pa AND a.montant=p_cost) OR (a.ordre='signer_compromis' AND v_fn='deposer_demande_permis' AND p_pa=0 AND p_cost=0)));
  IF v_fn IN('acheter_terrain','signer_compromis','acte_vente_terrain','emprunter') AND NOT v_acquisition THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  IF coalesce(p_pa, 0) < 0 OR coalesce(p_cost, 0) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_negatif');
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v_fn) INTO v_connu;

  IF NOT v_connu AND NOT v_acquisition THEN
    INSERT INTO public.ordres_couts_inconnus (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn) DO UPDATE SET occurrences = public.ordres_couts_inconnus.occurrences + 1;
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu', 'fn', v_fn);
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o
                 WHERE o.fn = v_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0))
    INTO v_valide;
  IF NOT v_valide AND NOT v_acquisition THEN
    INSERT INTO public.ordres_couts_ecarts (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn, pa, cost)
      DO UPDATE SET occurrences = public.ordres_couts_ecarts.occurrences + 1, vu_le = now();
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare',
                              'fn', v_fn, 'pa', p_pa, 'cost', p_cost);
  END IF;

  SELECT pa, liquide, arg INTO v_pa, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);

  IF v_pa < coalesce(p_pa, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;
  IF coalesce(v_liquide,0) + v_solde < coalesce(p_cost, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'disponible', coalesce(v_liquide,0) + v_solde);
  END IF;

  v_pris_liquide := least(coalesce(v_liquide,0), coalesce(p_cost,0));
  v_pris_national := coalesce(p_cost,0) - v_pris_liquide;

  UPDATE public.personnages_donnees
     SET pa = v_pa - coalesce(p_pa,0),
         liquide = coalesce(v_liquide,0) - v_pris_liquide,
         arg = coalesce(v_arg,0) - coalesce(p_cost,0)
   WHERE name = p_acteur;

  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national,
           updated_at = now() WHERE id = v_compte_id;
  END IF;

  -- LA MEMOIRE DES MANDATS (11 octobre 2026). Apres le prelevement, donc sur un fait accompli, et
  -- seulement si le triplet figure au registre des actes memorables. `presidence_memoire_noter`
  -- verifie elle-meme que l'acteur est bien le President en exercice : si c'est un ministre qui
  -- tient la conference de presse, rien n'est ecrit. Le registre ne contient AUCUN panneau a
  -- (0 PA, 0 FR) -- ouvrir une fenetre n'est pas un acte.
  SELECT * INTO v_memorable FROM public.presidence_memoire_ordres
   WHERE fn = v_fn AND pa = coalesce(p_pa,0) AND cost = coalesce(p_cost,0);
  IF FOUND THEN
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_acteur;
    PERFORM public.presidence_memoire_noter(
      v_pays, 'reaction', 'ordre_presidentiel', v_memorable.sujet,
      jsonb_build_object('ordre', v_fn, 'pa', coalesce(p_pa,0), 'cout', coalesce(p_cost,0)),
      p_acteur);
  END IF;

  -- FONDS EN TRANSIT (26/10/2026) : ce que le navigateur vient de payer pourra etre verse a une
  -- caisse par lui, et rien d'autre. Seulement pour un paiement demande directement par le navigateur.
  IF coalesce(p_cost, 0) > 0 AND coalesce(current_setting('request.path', true), '') = '/rpc/payer_ordre' THEN
    PERFORM public.fonds_transit_deposer_interne(p_acteur, p_cost, 'ordre:' || v_fn);
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'pa', v_pa - coalesce(p_pa,0),
    'liquide', coalesce(v_liquide,0) - v_pris_liquide,
    'arg', coalesce(v_arg,0) - coalesce(p_cost,0),
    'solde_national', v_solde - v_pris_national,
    'pa_preleves', coalesce(p_pa,0), 'montant_preleve', coalesce(p_cost,0));
END;
$function$
;
CREATE OR REPLACE FUNCTION public.personnages_convocations_garder()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_elem jsonb; v_old jsonb; v_out jsonb := '[]'::jsonb;
BEGIN
  IF NEW.convocations IS NOT DISTINCT FROM OLD.convocations THEN RETURN NEW; END IF;
  IF public.est_appel_serveur() OR coalesce(current_setting('request.path', true), '') LIKE '/rpc/%' THEN RETURN NEW; END IF;
  FOR v_elem IN SELECT value FROM jsonb_array_elements(coalesce(NEW.convocations, '[]'::jsonb)) LOOP
    SELECT o.value INTO v_old FROM jsonb_array_elements(coalesce(OLD.convocations, '[]'::jsonb)) o
     WHERE public.assemblee_cle_convocation(o.value) = public.assemblee_cle_convocation(v_elem) LIMIT 1;
    IF v_old IS NOT NULL THEN
      v_elem := v_elem || jsonb_build_object('traitee', coalesce(v_old -> 'traitee', 'false'::jsonb));
      IF v_old ? 'limiteTs' THEN v_elem := v_elem || jsonb_build_object('limiteTs', v_old -> 'limiteTs'); END IF;
    ELSE
      v_elem := v_elem || jsonb_build_object('traitee', false,
        'limiteTs', to_char((now() + interval '24 hours') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
    END IF;
    v_out := v_out || jsonb_build_array(v_elem);
    v_old := NULL;
  END LOOP;
  NEW.convocations := v_out;
  RETURN NEW;
END; $function$
;
