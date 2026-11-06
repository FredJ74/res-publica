-- APPLIQUEE le 03/11/2026 par Claude (registre trading_offres_achat_20261103030000), apres le banc annule
-- outils/bancs/banc-trading-offres.sql joue en production (tous les cas conformes).
-- 3 novembre 2026 -- TRADING, etape 2 : LES OFFRES D'ACHAT.
--
-- Decisions de Fred (GAME-DESIGN-TRADING.md, 31/10 et 03/11) :
--   . un directeur d'entrepot ou un trader peut publier une offre d'achat (matiere, quantite, prix) ;
--   . l'argent est BLOQUE des la publication (caisse de l'entrepot, ou caisse de l'organisation du
--     trader) et la part non servie est remboursee au retrait ou a l'echeance de 7 JOURS ;
--   . servie par un directeur (depuis le stock de son entrepot ; paye a la caisse de l'entrepot) ou par
--     un trader (depuis son bureau connecte ; matieres sur lui OU dans le stock d'un de ses locaux ;
--     paye a la caisse de son organisation) ; vente PARTIELLE admise ;
--   . livraison au cron de minuit : dans l'entrepot si l'acheteur est directeur (transit d'entrepot
--     existant), en caisse de fret au port industriel de PSM si l'acheteur est trader.
-- Idempotente. Aucun acte de joueur.

CREATE TABLE IF NOT EXISTS public.offres_achat (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auteur             text NOT NULL,
  acheteur_type      text NOT NULL CHECK (acheteur_type IN ('entrepot', 'organisation')),
  entrepot_id        text,
  organisation_id    text,
  pays               text NOT NULL,
  ressource          text NOT NULL,
  quantite_initiale  integer NOT NULL CHECK (quantite_initiale > 0),
  quantite_restante  integer NOT NULL CHECK (quantite_restante >= 0),
  prix_unitaire      numeric NOT NULL CHECK (prix_unitaire > 0),
  montant_bloque     numeric NOT NULL CHECK (montant_bloque >= 0),
  statut             text NOT NULL DEFAULT 'ouverte' CHECK (statut IN ('ouverte', 'servie', 'retiree', 'expiree')),
  cree_le            timestamptz NOT NULL DEFAULT now(),
  expire_le          timestamptz NOT NULL DEFAULT now() + interval '7 days'
);
CREATE INDEX IF NOT EXISTS offres_achat_ouvertes ON public.offres_achat (pays, statut, ressource);
ALTER TABLE public.offres_achat ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.offres_achat FROM anon, authenticated;

-- Rendre a l'acheteur le montant encore bloque d'une offre (retrait ou echeance).
CREATE OR REPLACE FUNCTION public.offre_achat_rembourser_interne(p_offre uuid, p_statut text)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE o public.offres_achat; v_rep jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  SELECT * INTO o FROM public.offres_achat WHERE id = p_offre FOR UPDATE;
  IF o.id IS NULL OR o.statut <> 'ouverte' THEN RETURN 0; END IF;
  IF o.montant_bloque > 0 THEN
    IF o.acheteur_type = 'entrepot' THEN
      v_rep := public.caisse_institution_mouvement(public.entrepot_caisse_id(o.entrepot_id), o.montant_bloque, true);
      IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN RAISE EXCEPTION 'offre: remboursement entrepot refuse'; END IF;
    ELSE
      IF NOT public.mouvement_titulaire('orga:' || o.organisation_id, o.montant_bloque) THEN
        RAISE EXCEPTION 'offre: remboursement organisation refuse'; END IF;
    END IF;
  END IF;
  UPDATE public.offres_achat SET statut = p_statut, montant_bloque = 0 WHERE id = o.id;
  RETURN o.montant_bloque;
END; $function$;

CREATE OR REPLACE FUNCTION public.offre_achat_publier(p_type text, p_organisation text, p_ressource text, p_quantite integer, p_prix numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ent text; v_org record; v_total numeric; v_rep jsonb; v_id uuid; v_lib text;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_quantite IS NULL OR p_quantite <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  IF p_prix IS NULL OR p_prix <= 0 OR p_prix <> round(p_prix, 2) THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_total := round(p_quantite * p_prix, 2);
  IF p_type = 'entrepot' THEN
    SELECT entrepot_id INTO v_ent FROM public.entrepot_du_directeur(v_moi);
    IF v_ent IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu'); END IF;
    IF public.entrepot_capacite_disponible(v_ent, p_ressource) < p_quantite THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'capacite_insuffisante'); END IF;
    v_rep := public.caisse_institution_mouvement(public.entrepot_caisse_id(v_ent), -v_total, true);
    IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'tresorerie_insuffisante', 'montant', v_total); END IF;
    v_lib := v_ent;
  ELSIF p_type = 'organisation' THEN
    IF NOT public.trading_connexion_interne(v_moi) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
    SELECT * INTO v_org FROM public.trading_organisations_interne(v_moi) t WHERE t.id = p_organisation;
    IF v_org.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_trader'); END IF;
    IF NOT public.mouvement_titulaire('orga:' || p_organisation, -v_total) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_organisation_insuffisante', 'montant', v_total); END IF;
    v_lib := v_org.nom;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'type_inconnu');
  END IF;
  INSERT INTO public.offres_achat (auteur, acheteur_type, entrepot_id, organisation_id, pays, ressource,
      quantite_initiale, quantite_restante, prix_unitaire, montant_bloque)
  VALUES (v_moi, p_type, v_ent, CASE WHEN p_type = 'organisation' THEN p_organisation END, v_pays, p_ressource,
      p_quantite, p_quantite, p_prix, v_total)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'offre', v_id, 'montant_bloque', v_total, 'acheteur', v_lib);
END; $function$;

CREATE OR REPLACE FUNCTION public.offre_achat_retirer(p_offre uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; o public.offres_achat; v_m numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO o FROM public.offres_achat WHERE id = p_offre FOR UPDATE;
  IF o.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'offre_introuvable'); END IF;
  IF o.auteur <> v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_auteur'); END IF;
  IF o.statut <> 'ouverte' THEN RETURN jsonb_build_object('ok', false, 'raison', 'offre_close'); END IF;
  v_m := public.offre_achat_rembourser_interne(o.id, 'retiree');
  RETURN jsonb_build_object('ok', true, 'rembourse', v_m);
END; $function$;

-- Offres ouvertes du pays : lisibles par un trader connecte ou un directeur d'entrepot.
CREATE OR REPLACE FUNCTION public.offres_achat_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_dir text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT entrepot_id INTO v_dir FROM public.entrepot_du_directeur(v_moi);
  IF v_dir IS NULL AND NOT public.trading_connexion_interne(v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'directeur_de', v_dir, 'offres', coalesce((
    SELECT jsonb_agg(jsonb_build_object('id', o.id, 'ressource', o.ressource, 'restante', o.quantite_restante,
             'initiale', o.quantite_initiale, 'prix', o.prix_unitaire, 'expire_le', o.expire_le,
             'acheteur', CASE WHEN o.acheteur_type = 'entrepot'
                              THEN 'Entrepôt — ' || coalesce((SELECT ep.ville FROM public.entrepots_par_ville ep
                                     WHERE o.pays || '_' || ep.ville || '_' || ep.building_id = o.entrepot_id), o.entrepot_id)
                              ELSE coalesce((SELECT og.data::jsonb->>'nom' FROM public.organisations og WHERE og.id = o.organisation_id), o.organisation_id) END,
             'ville', CASE WHEN o.acheteur_type = 'entrepot'
                           THEN (SELECT ep.ville FROM public.entrepots_par_ville ep WHERE o.pays || '_' || ep.ville || '_' || ep.building_id = o.entrepot_id) END,
             'a_moi', o.auteur = v_moi) ORDER BY o.ressource, o.prix_unitaire DESC)
      FROM public.offres_achat o WHERE o.pays = v_pays AND o.statut = 'ouverte' AND o.expire_le > now()), '[]'::jsonb),
    'locaux', coalesce((SELECT jsonb_agg(jsonb_build_object('id', e.id, 'enseigne', e.data->>'enseigne', 'stock', e.data->'stockMatieres'))
                          FROM public.entreprises e
                         WHERE replace(coalesce(e.data->>'proprietaire', ''), 'pj:', '') = v_moi
                           AND coalesce((e.data->>'version')::numeric, 0) >= 2 AND coalesce(e.data->>'statut', 'actif') = 'actif'), '[]'::jsonb));
END; $function$;

-- Servir une offre. p_source : 'entrepot' (directeur), 'inventaire' ou 'local' (trader ; p_fonds = son local).
CREATE OR REPLACE FUNCTION public.offre_achat_servir(p_offre uuid, p_quantite integer, p_source text, p_organisation text, p_fonds text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; o public.offres_achat; q integer; v_montant numeric; v_dir text; v_org record;
  v_etat jsonb; v_ent jsonb; v_dispo numeric; v_inv jsonb; v_idx integer; v_possede integer; v_fonds jsonb;
  v_rep jsonb; v_caisse uuid; v_vendeur text; v_ville_dest text;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO o FROM public.offres_achat WHERE id = p_offre FOR UPDATE;
  IF o.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'offre_introuvable'); END IF;
  IF o.statut <> 'ouverte' OR o.expire_le <= now() OR o.quantite_restante <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'offre_close'); END IF;
  IF p_quantite IS NULL OR p_quantite <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  q := least(p_quantite, o.quantite_restante);
  v_montant := round(q * o.prix_unitaire, 2);
  IF o.acheteur_type = 'entrepot' AND public.entrepot_capacite_disponible(o.entrepot_id, o.ressource) < q THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_acheteur_insuffisante'); END IF;

  -- 1. Le vendeur livre : la matiere quitte sa source.
  IF p_source = 'entrepot' THEN
    SELECT entrepot_id INTO v_dir FROM public.entrepot_du_directeur(v_moi);
    IF v_dir IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu'); END IF;
    IF v_dir = o.entrepot_id THEN RETURN jsonb_build_object('ok', false, 'raison', 'propre_offre'); END IF;
    PERFORM 1 FROM public.batiments_etat WHERE id = v_dir FOR UPDATE;
    SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_dir;
    v_ent := coalesce(v_etat->'entrepot', '{}'::jsonb);
    v_dispo := floor(coalesce((v_ent->'stock'->>o.ressource)::numeric, 0) - coalesce((v_ent->'reserveMilitaire'->>o.ressource)::numeric, 0));
    IF v_dispo < q THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'disponible', greatest(0, v_dispo)); END IF;
    v_ent := v_ent || jsonb_build_object('stock', jsonb_set(coalesce(v_ent->'stock', '{}'::jsonb), ARRAY[o.ressource],
                      to_jsonb(coalesce((v_ent->'stock'->>o.ressource)::numeric, 0) - q)));
    UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('entrepot', v_ent))::text), updated_at = now() WHERE id = v_dir;
    v_vendeur := 'Entrepôt ' || v_dir;
  ELSIF p_source IN ('inventaire', 'local') THEN
    IF NOT public.trading_connexion_interne(v_moi) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
    SELECT * INTO v_org FROM public.trading_organisations_interne(v_moi) t WHERE t.id = p_organisation;
    IF v_org.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_trader'); END IF;
    IF o.acheteur_type = 'organisation' AND o.organisation_id = p_organisation THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'propre_offre'); END IF;
    IF p_source = 'inventaire' THEN
      SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
      SELECT (x.ord - 1)::integer, greatest(0, floor(coalesce((x.val->>'qty')::numeric, 0)))::integer INTO v_idx, v_possede
        FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_inv) = 'array' THEN v_inv ELSE '[]'::jsonb END) WITH ORDINALITY AS x(val, ord)
       WHERE x.val->>'stackKey' = o.ressource AND coalesce((x.val->>'stackable')::boolean, false) ORDER BY x.ord LIMIT 1;
      IF v_idx IS NULL OR v_possede < q THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_insuffisante', 'possede', coalesce(v_possede, 0)); END IF;
      IF v_possede = q THEN
        UPDATE public.personnages_donnees SET inventory = inventory - v_idx WHERE name = v_moi;
      ELSE
        UPDATE public.personnages_donnees SET inventory = jsonb_set(inventory, ARRAY[v_idx::text, 'qty'], to_jsonb(v_possede - q)) WHERE name = v_moi;
      END IF;
    ELSE
      SELECT data INTO v_fonds FROM public.entreprises WHERE id = p_fonds FOR UPDATE;
      IF v_fonds IS NULL OR replace(coalesce(v_fonds->>'proprietaire', ''), 'pj:', '') <> v_moi THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire_local'); END IF;
      v_possede := greatest(0, floor(coalesce((v_fonds->'stockMatieres'->>o.ressource)::numeric, 0)))::integer;
      IF v_possede < q THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_insuffisante', 'possede', v_possede); END IF;
      UPDATE public.entreprises SET data = jsonb_set(data, ARRAY['stockMatieres', o.ressource], to_jsonb(v_possede - q)), updated_at = now()
       WHERE id = p_fonds;
    END IF;
    v_vendeur := v_org.nom;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'source_inconnue');
  END IF;

  -- 2. Le vendeur est paye sur le montant bloque.
  IF p_source = 'entrepot' THEN
    v_rep := public.caisse_institution_mouvement(public.entrepot_caisse_id(v_dir), v_montant, true);
    IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN RAISE EXCEPTION 'offre: credit entrepot vendeur refuse'; END IF;
    INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
    VALUES (v_dir, 'commande_directe', 'sortie', 'Offre d''achat', o.ressource, q, o.prix_unitaire, 0, v_montant, 'comptant', v_moi);
  ELSE
    IF NOT public.mouvement_titulaire('orga:' || p_organisation, v_montant) THEN RAISE EXCEPTION 'offre: credit organisation vendeuse refuse'; END IF;
  END IF;
  UPDATE public.offres_achat SET quantite_restante = quantite_restante - q, montant_bloque = greatest(0, montant_bloque - v_montant),
         statut = CASE WHEN quantite_restante - q <= 0 THEN 'servie' ELSE statut END
   WHERE id = o.id;

  -- 3. Livraison a l'acheteur au cron de minuit.
  IF o.acheteur_type = 'entrepot' THEN
    INSERT INTO public.entrepot_transits (destination_id, ressource, quantite, origine_type, origine_id, origine_libelle,
        prix_unitaire, fret_unitaire, montant_total, arrivee_le, commande_par)
    VALUES (o.entrepot_id, o.ressource, q, 'offre_achat', o.id::text, v_vendeur, o.prix_unitaire, 0, v_montant,
        (now() AT TIME ZONE 'utc')::date + 1, o.auteur);
    INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut, arrivee_le, acteur)
    VALUES (o.entrepot_id, 'commande_directe', 'entree', v_vendeur || ' (offre d''achat)', o.ressource, q, o.prix_unitaire, 0, v_montant,
        'en_transit', (now() AT TIME ZONE 'utc')::date + 1, v_moi);
  ELSE
    INSERT INTO public.caisses_fret (leader, pays_origine, ville_origine, building_origine, destinataire, pays_destination,
        ville_destination, building_destination, statut, declaration_douaniere, valeur_declaree, receptionnaires_autorises,
        dedouanee, date_dedouanement, date_fermeture, date_depart, date_arrivee_prevue)
    SELECT v_moi, o.pays, pd.current_city, pd.current_building, o.auteur, o.pays, 'ville_a', 'port-sainte-marie', 'en_transit',
        'Matières premières — offre d''achat servie par ' || v_vendeur, v_montant, ARRAY[o.auteur],
        true, now(), now(), now(), now() + interval '1 day'
      FROM public.personnages_donnees pd WHERE pd.name = v_moi
    RETURNING id INTO v_caisse;
    INSERT INTO public.contenu_caisses_fret (caisse_id, deposant, objet, quantite)
    VALUES (v_caisse, v_moi, jsonb_build_object('name', o.ressource, 'stackable', true, 'stackKey', o.ressource,
                                                'desc', 'Matière première reçue sur offre d''achat.'), q);
  END IF;

  RETURN jsonb_build_object('ok', true, 'quantite', q, 'montant', v_montant, 'ressource', o.ressource, 'vendeur', v_vendeur)
      || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = v_moi);
END; $function$;

-- Echeance : la part non servie revient a l'acheteur (cron de minuit, rejouable sans double effet).
CREATE OR REPLACE FUNCTION public.offres_achat_expirer_nuit()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; n integer := 0; v_total numeric := 0; v_err jsonb := '[]'::jsonb;
BEGIN
  FOR r IN SELECT id FROM public.offres_achat WHERE statut = 'ouverte' AND expire_le <= now() LOOP
    BEGIN
      v_total := v_total + public.offre_achat_rembourser_interne(r.id, 'expiree');
      n := n + 1;
    EXCEPTION WHEN OTHERS THEN
      v_err := v_err || jsonb_build_object('offre', r.id, 'erreur', SQLERRM);
    END;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'expirees', n, 'rembourse', v_total, 'erreurs', v_err);
END; $function$;

-- Le contenu d'une caisse de fret ne se depose que par le serveur : offre_achat_servir rejoint la liste.
DO $$
DECLARE f text;
BEGIN
  f := pg_get_functiondef('public.fret_contenu_source_garder()'::regprocedure);
  IF position('offre_achat_servir' IN f) > 0 THEN RETURN; END IF;
  IF position('''/rpc/trading_acheter'')' IN f) = 0 THEN RAISE EXCEPTION 'fret_contenu_source_garder_definition_non_examinee'; END IF;
  f := replace(f, '''/rpc/trading_acheter'')', '''/rpc/trading_acheter'', ''/rpc/offre_achat_servir'')');
  EXECUTE f;
END $$;

REVOKE ALL ON FUNCTION public.offre_achat_rembourser_interne(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.offres_achat_expirer_nuit() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.offres_achat_expirer_nuit() TO service_role;
REVOKE ALL ON FUNCTION public.offre_achat_publier(text,text,text,integer,numeric) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.offre_achat_retirer(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.offres_achat_lire() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.offre_achat_servir(uuid,integer,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.offre_achat_publier(text,text,text,integer,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.offre_achat_retirer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.offres_achat_lire() TO authenticated;
GRANT EXECUTE ON FUNCTION public.offre_achat_servir(uuid,integer,text,text,text) TO authenticated;
