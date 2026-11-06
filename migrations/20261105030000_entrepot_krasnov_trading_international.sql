-- Entrepôt Logistique de Krasnov (Sovarka) et trading international (Claude, 05/11/2026, décisions de Fred).
--
-- 1. L'entrepôt : copie de celui de Montrouge (écran), directeur PNJ Fiodor Kolkhozov, pièces et entrée
--    depuis la rue de l'entrepôt ; ligne entrepots_par_ville (pays soviet), état et caisse propres.
--    Stock de départ agricole « façon kolkhoze » (choix de Fred) ; caisse 10 000. Pas d'approvisionnement
--    de nuit : la passe de minuit ne nourrit que les entrepôts de Républia (économie de Sovarka à décider).
-- 2. Le port de Sovarka sera à Starovka (Fred) : déclaré dans fret_port_interne (`port-starovka`), bâtiment
--    à raccorder plus tard. Il sert de port de départ ; il ne peut pas encore recevoir de caisses.
-- 3. Trading international, sur les règles existantes (GAME-DESIGN-TRADING.md, décision 5 ; GAME-DESIGN-DOUANES.md) :
--    les cours montrent aussi les entrepôts des autres pays ; un achat à l'étranger part en caisse de fret par le
--    port du pays vendeur et arrive au port industriel du pays de l'acheteur, où il la dédouane (fret_dedouaner,
--    10 % de la valeur) puis la retire. Délai : livraison terrestre jusqu'au port (tranches de 4 h) puis 1 jour de
--    mer, comme une expédition au port ; une caisse sur trois inspectée au départ, comme au port. Fret international
--    du socle (fret_unitaire_international, 0,40 par unité) payé avec l'achat par la caisse de l'organisation.
--    Refus nommé `port_indisponible` si l'un des deux pays n'a pas de port en service (Sovarka ne peut pas encore
--    recevoir : Starovka n'est pas raccordée). Le commerce national est inchangé.

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'ville_b', 'entrepot-logistique-krasnov', '["salle_ventes", "bureau_direction"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'ville_b', 'krasnov-rue-entrepot', 'entrepot-logistique-krasnov')
ON CONFLICT DO NOTHING;

INSERT INTO public.entrepots_par_ville(pays, ville, building_id)
SELECT 'soviet', 'ville_b', 'entrepot-logistique-krasnov'
 WHERE NOT EXISTS (SELECT 1 FROM public.entrepots_par_ville WHERE pays = 'soviet' AND ville = 'ville_b');

INSERT INTO public.batiments_etat(id, country, city, building_id, data, updated_at) VALUES
  ('soviet_ville_b_entrepot-logistique-krasnov', 'soviet', 'ville_b', 'entrepot-logistique-krasnov',
   jsonb_build_object('entrepot', jsonb_build_object('stock', jsonb_build_object(
     'cereales', 800, 'viande', 300, 'laitages', 300, 'fruits_legumes', 400,
     'plantes', 200, 'alcool', 150, 'tabac', 100, 'bois', 300))), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.caisses_batiments(id, data, updated_at) VALUES
  ('soviet_entrepot_ville_b', '{"solde": 10000}'::jsonb, now())
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.fret_port_interne(p_pays text)
 RETURNS TABLE(ville text, batiment text)
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT v, b FROM (VALUES ('republic', 'ville_a', 'port-sainte-marie'),
                           ('soviet',   'ville_a', 'port-starovka')) t(p, v, b) WHERE t.p = p_pays;
$function$;

-- Un port peut recevoir des caisses quand son bâtiment est en service (raccordé dans navigation_lieux_regles).
CREATE OR REPLACE FUNCTION public.fret_port_en_service_interne(p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.fret_port_interne(p_pays) fp
                   JOIN public.navigation_lieux_regles n ON n.pays = p_pays AND n.ville = fp.ville AND n.batiment = fp.batiment);
$function$;
REVOKE ALL ON FUNCTION public.fret_port_en_service_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.trading_cours()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_port_ici record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.trading_connexion_interne(v_moi) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  SELECT * INTO v_port_ici FROM public.fret_port_interne(v_pays);
  RETURN jsonb_build_object('ok', true,
    'organisations', coalesce((SELECT jsonb_agg(jsonb_build_object('id', t.id, 'nom', t.nom, 'chef', t.chef, 'caisse', t.caisse))
                                 FROM public.trading_organisations_interne(v_moi) t), '[]'::jsonb),
    'entrepots', coalesce((
      SELECT jsonb_agg(jsonb_build_object('id', ep.pays || '_' || ep.ville || '_' || ep.building_id, 'pays', ep.pays,
               'ville', ep.ville, 'batiment', ep.building_id, 'international', ep.pays IS DISTINCT FROM v_pays)
             || CASE WHEN ep.pays IS DISTINCT FROM v_pays THEN jsonb_build_object(
                  'port_depart_ville', (SELECT fp.ville FROM public.fret_port_interne(ep.pays) fp),
                  'port_arrivee_ville', v_port_ici.ville,
                  'fret_unitaire', public.fret_unitaire_international()) ELSE '{}'::jsonb END
             || jsonb_build_object(
               'cours', (SELECT coalesce(jsonb_agg(jsonb_build_object('ressource', r.cle,
                           'prix', coalesce((ent->'prixManuel'->>r.cle)::numeric, r.prix_base),
                           'disponible', greatest(0, floor(coalesce((ent->'stock'->>r.cle)::numeric, 0)
                                                  - coalesce((ent->'reserveMilitaire'->>r.cle)::numeric, 0))))
                           ORDER BY r.cle), '[]'::jsonb) FROM public.ressources_economie r))
             ORDER BY (ep.pays IS DISTINCT FROM v_pays), ep.pays, ep.ville)
        FROM public.entrepots_par_ville ep
        CROSS JOIN LATERAL (SELECT coalesce(public.batiment_etat_lire(b.data)->'entrepot', '{}'::jsonb) AS ent
                              FROM public.batiments_etat b WHERE b.id = ep.pays || '_' || ep.ville || '_' || ep.building_id) x), '[]'::jsonb));
END; $function$;

CREATE OR REPLACE FUNCTION public.trading_acheter(p_organisation text, p_entrepot text, p_ressource text, p_quantite integer, p_livraison text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_org record; v_pays_ent text; v_ville text; v_bat text; v_etat jsonb; v_ent jsonb; v_prix numeric;
  v_dispo numeric; v_total numeric; v_caisse_ent text; v_rep jsonb; v_caisse uuid; v_objet jsonb; v_dest record; v_prevue timestamptz;
  v_intl boolean; v_port_dep record; v_port_arr record; v_fret numeric := 0; v_insp jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.trading_connexion_interne(v_moi) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
  IF p_quantite IS NULL OR p_quantite <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  SELECT * INTO v_org FROM public.trading_organisations_interne(v_moi) t WHERE t.id = p_organisation;
  IF v_org.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_trader'); END IF;
  SELECT name, country, pa INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF coalesce(m.pa, 0) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  SELECT ep.pays, ep.ville, ep.building_id INTO v_pays_ent, v_ville, v_bat FROM public.entrepots_par_ville ep
   WHERE ep.pays || '_' || ep.ville || '_' || ep.building_id = p_entrepot;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_inconnu'); END IF;
  v_intl := v_pays_ent IS DISTINCT FROM m.country;
  IF v_intl THEN
    SELECT * INTO v_port_dep FROM public.fret_port_interne(v_pays_ent);
    SELECT * INTO v_port_arr FROM public.fret_port_interne(m.country);
    IF v_port_dep.ville IS NULL OR v_port_arr.ville IS NULL OR NOT public.fret_port_en_service_interne(m.country) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'port_indisponible'); END IF;
  END IF;
  v_caisse_ent := public.entrepot_caisse_id(p_entrepot);
  IF v_caisse_ent IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree'); END IF;
  PERFORM 1 FROM public.batiments_etat WHERE id = p_entrepot FOR UPDATE;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = p_entrepot;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_ent := coalesce(v_etat->'entrepot', '{}'::jsonb);
  v_dispo := floor(coalesce((v_ent->'stock'->>p_ressource)::numeric, 0) - coalesce((v_ent->'reserveMilitaire'->>p_ressource)::numeric, 0));
  IF v_dispo < p_quantite THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'disponible', greatest(0, v_dispo)); END IF;
  v_prix := coalesce((v_ent->'prixManuel'->>p_ressource)::numeric, (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource));
  v_total := round(p_quantite * v_prix, 2);
  IF v_intl THEN v_fret := round(p_quantite * public.fret_unitaire_international(), 2); END IF;
  IF NOT public.mouvement_titulaire('orga:' || p_organisation, -(v_total + v_fret)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_organisation_insuffisante', 'montant', v_total + v_fret, 'caisse', v_org.caisse); END IF;
  UPDATE public.personnages_donnees SET pa = pa - 1 WHERE name = v_moi;
  v_ent := v_ent || jsonb_build_object('stock', jsonb_set(coalesce(v_ent->'stock', '{}'::jsonb), ARRAY[p_ressource],
                    to_jsonb(coalesce((v_ent->'stock'->>p_ressource)::numeric, 0) - p_quantite)));
  UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('entrepot', v_ent))::text), updated_at = now()
   WHERE id = p_entrepot;
  v_rep := public.caisse_institution_mouvement(v_caisse_ent, v_total, true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN RAISE EXCEPTION 'trading: credit entrepot refuse'; END IF;
  INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource, quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
  VALUES (p_entrepot, 'commande_directe', 'sortie', v_org.nom || CASE WHEN v_intl THEN ' (trading international)' ELSE ' (trading)' END,
          p_ressource, p_quantite, v_prix, CASE WHEN v_intl THEN public.fret_unitaire_international() ELSE 0 END, v_total, 'comptant', v_moi);
  v_objet := jsonb_build_object('name', p_ressource, 'stackable', true, 'stackKey', p_ressource, 'desc', 'Matière première achetée par trading.');

  IF NOT v_intl THEN
    -- Livraison terrestre nationale (décision de Fred, 04/11/2026) : entrepôt de la ville choisie.
    SELECT * INTO v_dest FROM public.trading_livraison_entrepot_interne(m.country, p_livraison, v_moi);
    v_prevue := public.livraison_terrestre_echeance(now());
    INSERT INTO public.caisses_fret (leader, pays_origine, ville_origine, building_origine, destinataire, pays_destination,
        ville_destination, building_destination, statut, declaration_douaniere, valeur_declaree, receptionnaires_autorises,
        dedouanee, date_dedouanement, date_fermeture, date_depart, date_arrivee_prevue)
    VALUES (v_moi, m.country, v_ville, v_bat, v_moi, m.country, v_dest.ville, v_dest.building_id, 'en_transit',
        'Matières premières — achat de trading (' || v_org.nom || ')', v_total, ARRAY[v_moi],
        true, now(), now(), now(), v_prevue)
    RETURNING id INTO v_caisse;
    PERFORM public.trading_livraison_courrier_interne(v_moi, v_dest.ville, v_prevue,
      'Achat de trading : ' || p_quantite || ' × ' || p_ressource || ' pour ' || v_org.nom || '.');
    INSERT INTO public.contenu_caisses_fret (caisse_id, deposant, objet, quantite) VALUES (v_caisse, v_moi, v_objet, p_quantite);
    RETURN jsonb_build_object('ok', true, 'ressource', p_ressource, 'quantite', p_quantite, 'prix_unitaire', v_prix,
      'montant', v_total, 'caisse_fret', v_caisse, 'organisation', v_org.nom, 'pa', m.pa - 1, 'arrivee', v_dest.building_id,
      'pays_livraison', m.country, 'ville_livraison', v_dest.ville, 'disponible_apres', v_prevue, 'international', false);
  END IF;

  -- International : terrestre jusqu'au port du pays vendeur, puis 1 jour de mer jusqu'au port de l'acheteur,
  -- à dédouaner sur place (frais de douane du socle). Déclaration exacte : toutes les lignes sont déclarées.
  v_prevue := public.livraison_terrestre_echeance(now()) + interval '1 day';
  INSERT INTO public.caisses_fret (leader, pays_origine, ville_origine, building_origine, destinataire, pays_destination,
      ville_destination, building_destination, statut, declaration_douaniere, valeur_declaree, receptionnaires_autorises,
      dedouanee, date_fermeture, date_depart, date_arrivee_prevue)
  VALUES (v_moi, v_pays_ent, v_ville, v_bat, v_moi, m.country, v_port_arr.ville, v_port_arr.batiment, 'fermee',
      'Matières premières — achat de trading international (' || v_org.nom || ') : ' || p_quantite || ' × ' || p_ressource,
      v_total, ARRAY[v_moi], false, now(), now(), v_prevue)
  RETURNING id INTO v_caisse;
  INSERT INTO public.contenu_caisses_fret (caisse_id, deposant, objet, quantite) VALUES (v_caisse, v_moi, v_objet, p_quantite);
  -- Même déroulé qu'une expédition au port (fret_caisse_commande_interne, action expedier).
  IF random() < 1.0 / 3 THEN v_insp := public.fret_inspecter_interne(v_caisse, 'inspection_port'); END IF;
  UPDATE public.caisses_fret SET statut = 'en_transit', inspection = coalesce(v_insp, jsonb_build_object('inspectee', false))
   WHERE id = v_caisse;
  PERFORM public.mail_systeme_poser_interne('Administration Portuaire', v_moi, 'Achat international en route',
    'Achat de trading : ' || p_quantite || ' × ' || p_ressource || ' pour ' || v_org.nom || '. La caisse part par le port de '
    || coalesce((SELECT nom FROM public.villes WHERE pays = v_pays_ent AND ville = v_port_dep.ville), v_port_dep.ville)
    || ' et sera à retirer au port industriel de '
    || coalesce((SELECT nom FROM public.villes WHERE pays = m.country AND ville = v_port_arr.ville), v_port_arr.ville)
    || ' à partir du ' || to_char(v_prevue AT TIME ZONE 'Europe/Paris', 'DD/MM à HH24"h"')
    || ' (constat d''arrivée à minuit), après dédouanement (10 % de sa valeur déclarée).');
  RETURN jsonb_build_object('ok', true, 'ressource', p_ressource, 'quantite', p_quantite, 'prix_unitaire', v_prix,
    'montant', v_total, 'fret', v_fret, 'caisse_fret', v_caisse, 'organisation', v_org.nom, 'pa', m.pa - 1,
    'arrivee', v_port_arr.batiment, 'pays_livraison', m.country, 'ville_livraison', v_port_arr.ville,
    'disponible_apres', v_prevue, 'international', true);
END; $function$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.entrepots_par_ville WHERE pays = 'soviet' AND ville = 'ville_b' AND building_id = 'entrepot-logistique-krasnov')
     OR NOT EXISTS (SELECT 1 FROM public.batiments_etat WHERE id = 'soviet_ville_b_entrepot-logistique-krasnov')
     OR public.entrepot_caisse_id('soviet_ville_b_entrepot-logistique-krasnov') IS DISTINCT FROM 'soviet_entrepot_ville_b'
     OR NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = 'soviet_entrepot_ville_b')
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'ville_b' AND building = 'entrepot-logistique-krasnov')
     OR NOT public.fret_port_en_service_interne('republic') OR public.fret_port_en_service_interne('soviet') THEN
    RAISE EXCEPTION 'entrepot_krasnov_incomplet';
  END IF;
END $$;
