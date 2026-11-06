-- Marchande de poissons de Novomirsk (vue 16), decisions de Fred du 06/11/2026 :
-- * une commercante comme au marche, tenue par une PNJ (Galina Karpova) ;
-- * elle vend du poisson de riviere, legerement moins cher qu'a l'entrepot, mais 12 poissons par
--   jour au plus (toute la ville confondue) ; au-dela : « il faut que mon mari releve les filets » ;
-- * elle connait et colporte les rumeurs (ordres existants ecouter_rumeurs / lancer_rumeur_cible,
--   rien a ajouter cote serveur) ;
-- * son mari fait passer en douce par la riviere ce que la Sovarka importe officiellement de la
--   Republia : alcool et medicaments, moins chers que le circuit d'Etat, achat illegal (detection,
--   trace, bareme du delit mineur existant).
-- Valeurs provisoires (a valider par Fred) : poisson a 75 % du prix de reference de l'entrepot,
-- contrebande a 80 %, arrivage de contrebande limite a 10 unites par jour.
-- Independante de l'ecran : fonctions nouvelles, aucun ecran actuel ne les appelle.
BEGIN;

-- Compteurs du jour (heure de Paris), par ville : poisson vendu, unites de contrebande vendues.
CREATE TABLE IF NOT EXISTS public.poissonniere_ventes (
  pays text NOT NULL, ville text NOT NULL, jour date NOT NULL,
  poisson integer NOT NULL DEFAULT 0 CHECK (poisson >= 0),
  contrebande integer NOT NULL DEFAULT 0 CHECK (contrebande >= 0),
  PRIMARY KEY (pays, ville, jour));
ALTER TABLE public.poissonniere_ventes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.poissonniere_ventes FROM anon, authenticated;

-- Le commerce (rachetable comme les autres commerces de Sovarka, droit d'exploiter).
INSERT INTO public.entreprises (id, data, updated_at) VALUES
  ('poissonniere-soviet-capitale', jsonb_build_object(
     'id', 'poissonniere-soviet-capitale', 'type', 'poissonnerie', 'country', 'soviet', 'city', 'capitale',
     'buildingId', 'poissonniere-novomirsk', 'proprietaire', 'PNJ', 'caisse', 500,
     'historique', '[]'::jsonb, 'typesAutorises', '["poissonnerie"]'::jsonb), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'poissonniere-novomirsk', '["etal_poissonniere"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;
INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-16', 'poissonniere-novomirsk')
ON CONFLICT DO NOTHING;

-- Couts des ordres (miroir de data.js).
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'poissonniere_poisson', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'poissonniere_poisson' AND pa = 0 AND cost = 0);
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'contrebande_poissonniere', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'contrebande_poissonniere' AND pa = 1 AND cost = 0);

-- Acte illegal : meme categorie et meme detection que contrebande_port (marchandise prohibee
-- acquise par un canal discret) ; peine et amende = bareme existant du delit mineur (2 jours,
-- 500) ; decouvrable : la trace permet au commissaire de remonter la filiere.
INSERT INTO public.actes_illegaux (fn, type, detect_rate, peine_jours, amende, decouvrable)
VALUES ('contrebande_poissonniere', 'delit_mineur', 20, 2, 500, true)
ON CONFLICT (fn) DO UPDATE SET type = EXCLUDED.type, detect_rate = EXCLUDED.detect_rate,
  peine_jours = EXCLUDED.peine_jours, amende = EXCLUDED.amende, decouvrable = EXCLUDED.decouvrable, maj_le = now();

-- Presence, disponibilite, etal encore tenu par la PNJ. Verrouille la fiche.
CREATE OR REPLACE FUNCTION public.poissonniere_acteur_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m record;
BEGIN
  IF p_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, hp, hospitalisation INTO m
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(m.hp, 0) <= 0
     OR coalesce(m.hospitalisation->>'dateFinParis', '') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text
     OR EXISTS (SELECT 1 FROM public.detention_active(p_acteur)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_indisponible'); END IF;
  IF m.country IS DISTINCT FROM 'soviet' OR m.current_city IS DISTINCT FROM 'capitale'
     OR m.current_building IS DISTINCT FROM 'poissonniere-novomirsk' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'poissonniere-soviet-capitale'
                  AND data->>'proprietaire' = 'PNJ') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etal_repris'); END IF;
  RETURN jsonb_build_object('ok', true);
END; $$;

-- Ligne du jour, creee au besoin et verrouillee.
CREATE OR REPLACE FUNCTION public.poissonniere_jour_interne()
RETURNS public.poissonniere_ventes LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_jour date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date; r public.poissonniere_ventes;
BEGIN
  INSERT INTO public.poissonniere_ventes (pays, ville, jour) VALUES ('soviet', 'capitale', v_jour) ON CONFLICT DO NOTHING;
  SELECT * INTO r FROM public.poissonniere_ventes WHERE pays = 'soviet' AND ville = 'capitale' AND jour = v_jour FOR UPDATE;
  RETURN r;
END; $$;

CREATE OR REPLACE FUNCTION public.poissonniere_poisson_interne(p_acteur text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb; r public.poissonniere_ventes; v_restant integer; v_prix numeric; v_total numeric;
        v_fonds numeric; v_debit numeric; v_dep jsonb;
BEGIN
  IF coalesce(p_qte, 0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  v := public.poissonniere_acteur_interne(p_acteur);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  v := public.matiere_refus_circuit_legal_lot(p_acteur, jsonb_build_object('poisson', p_qte), 'achat');
  IF v IS NOT NULL THEN RETURN v; END IF;
  r := public.poissonniere_jour_interne();
  v_restant := greatest(0, 12 - r.poisson);
  IF v_restant = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quota_epuise'); END IF;
  IF p_qte > v_restant THEN RETURN jsonb_build_object('ok', false, 'raison', 'quota_insuffisant', 'restant', v_restant); END IF;
  SELECT greatest(1, round(prix_base * 0.75)) INTO v_prix FROM public.ressources_economie WHERE cle = 'poisson';
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  v_total := v_prix * p_qte;
  SELECT coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b
           WHERE b.personnage = d.name AND b.banque = 'nationale' ORDER BY id LIMIT 1), 0)
    INTO v_fonds FROM public.personnages_donnees d WHERE d.name = p_acteur;
  IF v_fonds < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total, 'disponible', v_fonds); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = p_acteur) < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(p_acteur, 'poissonniere_poisson', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_debit := public.argent_debiter_interne(p_acteur, v_total, 'liquide_puis_nationale');
  IF v_debit IS DISTINCT FROM v_total THEN RAISE EXCEPTION 'poissonniere_poisson: debit incomplet % / %', v_debit, v_total; END IF;
  UPDATE public.poissonniere_ventes SET poisson = poisson + p_qte
   WHERE pays = r.pays AND ville = r.ville AND jour = r.jour;
  UPDATE public.entreprises
     SET data = jsonb_set(data, '{caisse}', to_jsonb(coalesce((data->>'caisse')::numeric, 0) + v_total)), updated_at = now()
   WHERE id = 'poissonniere-soviet-capitale';
  v_dep := public.inventaire_deposer_interne(p_acteur, jsonb_build_object('name', 'Poisson',
    'icon', 'ti-fish', 'stackable', true, 'stackKey', 'poisson', 'qty', p_qte,
    'desc', 'Poisson de rivière, pêché par le mari de la marchande de Novomirsk.'));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'poissonniere_poisson: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'quantite', p_qte, 'prix', v_prix, 'paye', v_total,
    'restant', v_restant - p_qte) || public.crime_etat_acteur_interne(p_acteur);
END; $$;

CREATE OR REPLACE FUNCTION public.contrebande_poissonniere_interne(p_acteur text, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb; r public.poissonniere_ventes; v_restant integer; v_prix numeric; v_total numeric;
        v_fonds numeric; v_debit numeric; v_dep jsonb; v_det boolean;
BEGIN
  IF p_cle IS NULL OR p_cle NOT IN ('alcool', 'medicaments') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  IF coalesce(p_qte, 0) <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  v := public.poissonniere_acteur_interne(p_acteur);
  IF (v->>'ok')::boolean IS NOT TRUE THEN RETURN v; END IF;
  r := public.poissonniere_jour_interne();
  v_restant := greatest(0, 10 - r.contrebande);
  IF v_restant = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'arrivage_epuise'); END IF;
  IF p_qte > v_restant THEN RETURN jsonb_build_object('ok', false, 'raison', 'arrivage_insuffisant', 'restant', v_restant); END IF;
  SELECT greatest(1, round(prix_base * 0.8)) INTO v_prix FROM public.ressources_economie WHERE cle = p_cle;
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue'); END IF;
  v_total := v_prix * p_qte;
  SELECT coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b
           WHERE b.personnage = d.name AND b.banque = 'nationale' ORDER BY id LIMIT 1), 0)
    INTO v_fonds FROM public.personnages_donnees d WHERE d.name = p_acteur;
  IF v_fonds < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total, 'disponible', v_fonds); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = p_acteur) < p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(p_acteur, 'contrebande_poissonniere', 1, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  -- L'argent de la contrebande quitte l'economie declaree (ni caisse ni Tresor).
  v_debit := public.argent_debiter_interne(p_acteur, v_total, 'liquide_puis_nationale');
  IF v_debit IS DISTINCT FROM v_total THEN RAISE EXCEPTION 'contrebande_poissonniere: debit incomplet % / %', v_debit, v_total; END IF;
  UPDATE public.poissonniere_ventes SET contrebande = contrebande + p_qte
   WHERE pays = r.pays AND ville = r.ville AND jour = r.jour;
  v_dep := public.inventaire_deposer_interne(p_acteur, jsonb_build_object(
    'name', CASE p_cle WHEN 'alcool' THEN 'Alcool' ELSE 'Médicaments' END,
    'icon', CASE p_cle WHEN 'alcool' THEN 'ti-glass-full' ELSE 'ti-pill' END,
    'stackable', true, 'stackKey', p_cle, 'qty', p_qte,
    'desc', 'Passé en douce par la rivière, sans facture ni tampon.'));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'contrebande_poissonniere: depot refuse %', v_dep; END IF;
  PERFORM public.crime_tracer_interne(p_acteur, 'contrebande_poissonniere', NULL);
  PERFORM public.crime_trace_rumeur_interne(p_acteur, 'contrebande_poissonniere', NULL);
  v_det := public.crime_detecter_interne(p_acteur, 'contrebande_poissonniere', true, NULL);
  RETURN jsonb_build_object('ok', true, 'cle', p_cle, 'quantite', p_qte, 'prix', v_prix, 'paye', v_total,
    'restant', v_restant - p_qte, 'detecte', v_det) || public.crime_etat_acteur_interne(p_acteur);
END; $$;

-- Enveloppes appelables : cle d'unicite (une reponse perdue se rejoue sans double effet).
CREATE OR REPLACE FUNCTION public.poissonniere_acheter_poisson(p_requete uuid, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('qte', p_qte); v jsonb; d text;
BEGIN
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'poissonniere_acheter_poisson', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.poissonniere_poisson_interne(a, p_qte);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'poissonniere_acheter_poisson', prm, v);
END; $$;

CREATE OR REPLACE FUNCTION public.poissonniere_acheter_contrebande(p_requete uuid, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cle', p_cle, 'qte', p_qte); v jsonb; d text;
BEGIN
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'poissonniere_acheter_contrebande', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.contrebande_poissonniere_interne(a, p_cle, p_qte);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'poissonniere_acheter_contrebande', prm, v);
END; $$;

-- Ce qui reste a vendre aujourd'hui (lecture seule, pour l'ecran ; le serveur revalide a l'achat).
CREATE OR REPLACE FUNCTION public.poissonniere_etat()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object(
    'poisson_restant', 12 - coalesce((SELECT poisson FROM public.poissonniere_ventes v
       WHERE v.pays = 'soviet' AND v.ville = 'capitale' AND v.jour = (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date), 0),
    'contrebande_restant', 10 - coalesce((SELECT contrebande FROM public.poissonniere_ventes v
       WHERE v.pays = 'soviet' AND v.ville = 'capitale' AND v.jour = (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date), 0),
    'prix_poisson', (SELECT greatest(1, round(prix_base * 0.75)) FROM public.ressources_economie WHERE cle = 'poisson'),
    'prix_alcool', (SELECT greatest(1, round(prix_base * 0.8)) FROM public.ressources_economie WHERE cle = 'alcool'),
    'prix_medicaments', (SELECT greatest(1, round(prix_base * 0.8)) FROM public.ressources_economie WHERE cle = 'medicaments'),
    'etal_pnj', EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'poissonniere-soviet-capitale' AND data->>'proprietaire' = 'PNJ'));
$$;

REVOKE ALL ON FUNCTION public.poissonniere_acteur_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.poissonniere_jour_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.poissonniere_poisson_interne(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.contrebande_poissonniere_interne(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.poissonniere_acheter_poisson(uuid, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.poissonniere_acheter_contrebande(uuid, text, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.poissonniere_etat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.poissonniere_acheter_poisson(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poissonniere_acheter_contrebande(uuid, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.poissonniere_etat() TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'poissonniere-soviet-capitale')
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE building = 'poissonniere-novomirsk')
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'contrebande_poissonniere' AND pa = 1)
     OR NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'poissonniere_poisson')
     OR NOT EXISTS (SELECT 1 FROM public.actes_illegaux WHERE fn = 'contrebande_poissonniere') THEN
    RAISE EXCEPTION 'poissonniere_novomirsk_incomplete';
  END IF;
END $$;

COMMIT;
