-- EAU DE LA PLACE DE L'OURS — « Puiser de l'eau » (Fred, 21/11/2026, mission du soir, point 3) et SORTIE DE LA MAIRIE
-- DE KRASNOV (point 9).
-- • Eau gratuite ; 1 PA par puisage quelle que soit la quantité ; au plus 10 bouteilles par tranche de 6 h (compteur remis
--   à zéro à 0 h, 6 h, 12 h, 18 h, heure de Paris) ; quantité plafonnée au plus petit de : reste de la tranche, place libre
--   dans l'inventaire ; aucun PA consommé si le plafond est atteint ou l'inventaire plein ; pas de bouteille vide nécessaire.
-- • point_eau_remplir (0 PA, une bouteille) est retiré : il renvoie « remplace_par_puiser ».
-- • L'image de la fontaine est renseignée sur le point d'eau existant krasnov-fontaine-ours.
-- • Mairie de Krasnov : on n'en sort plus sur la place de l'Ours, seulement dans krasnov-rue-mairie-place.
-- Aucune fonction commune modifiée ; aucun objet du goulag touché.
BEGIN;

INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('point_eau_bouteilles_tranche', 10) ON CONFLICT (cle) DO NOTHING;
-- Miroir du coût de l'ordre de rue « Puiser de l'eau » (déclaré dans plateau-climat.js).
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'puiser_eau', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'puiser_eau' AND pa = 1 AND cost = 0);

UPDATE public.climat_points_eau SET image = 'images/Sovarka/Krasnov/Krasnov_place_ours_fontaine.webp'
 WHERE id = 'krasnov-fontaine-ours' AND image IS NULL;

CREATE TABLE IF NOT EXISTS public.climat_points_eau_puisages (
  nom      text NOT NULL,
  tranche  timestamptz NOT NULL,          -- début de la tranche de 6 h (heure de Paris)
  quantite integer NOT NULL DEFAULT 0 CHECK (quantite >= 0),
  PRIMARY KEY (nom, tranche)
);
ALTER TABLE public.climat_points_eau_puisages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_points_eau_puisages FROM anon, authenticated;

-- Début de la tranche de 6 h en cours (0 h, 6 h, 12 h, 18 h à Paris).
CREATE OR REPLACE FUNCTION public.point_eau_tranche_interne()
RETURNS timestamptz LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT (date_trunc('day', now() AT TIME ZONE 'Europe/Paris')
          + make_interval(hours => (extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer / 6) * 6)) AT TIME ZONE 'Europe/Paris';
$$;

-- État lu par la fenêtre « Puiser de l'eau » : tout ce qu'il faut pour expliquer, sans rien écrire.
CREATE OR REPLACE FUNCTION public.point_eau_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d public.personnages_donnees; pe public.climat_points_eau;
        v_max integer := public.aliments_param_interne('point_eau_bouteilles_tranche', 10)::integer;
        v_tr timestamptz := public.point_eau_tranche_interne(); v_deja integer; v_place integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = a;
  SELECT * INTO pe FROM public.climat_points_eau p WHERE p.actif AND p.pays = d.country AND p.ville = d.current_city
     AND p.noeud = d.current_street AND d.current_building IS NULL ORDER BY p.id LIMIT 1;
  IF pe.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_point_eau'); END IF;
  SELECT coalesce(sum(quantite), 0) INTO v_deja FROM public.climat_points_eau_puisages WHERE nom = a AND tranche = v_tr;
  v_place := public.inventaire_place_restante(d.inventory);
  RETURN jsonb_build_object('ok', true, 'point', jsonb_build_object('id', pe.id, 'nom', pe.nom, 'image', pe.image),
    'max_tranche', v_max, 'deja', v_deja, 'restant', greatest(0, v_max - v_deja), 'place', v_place,
    'pa', coalesce(d.pa, 0), 'cout_pa', 1,
    'fin_tranche', v_tr + interval '6 hours',
    'heure_fin', extract(hour FROM (v_tr + interval '6 hours') AT TIME ZONE 'Europe/Paris')::integer);
END $$;

-- Puiser p_quantite bouteilles (plafonnées automatiquement). Idempotent par requête.
CREATE OR REPLACE FUNCTION public.point_eau_puiser(p_requete uuid, p_quantite integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; e jsonb; p jsonb; d public.personnages_donnees;
        v_n integer; v_tr timestamptz := public.point_eau_tranche_interne();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;
  IF p_quantite IS NULL OR p_quantite < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  prm := jsonb_build_object('quantite', p_quantite);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'point_eau_puiser', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('point_eau:' || a, 0));
  SELECT * INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  e := public.point_eau_etat();
  IF coalesce((e->>'ok')::boolean, false) IS NOT TRUE THEN RETURN e; END IF;
  IF (e->>'restant')::integer <= 0 THEN RETURN e || jsonb_build_object('ok', false, 'raison', 'plafond_atteint'); END IF;
  IF (e->>'place')::integer <= 0 THEN RETURN e || jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_n := least(p_quantite, (e->>'restant')::integer, (e->>'place')::integer);
  p := public.payer_ordre_interne(a, 'puiser_eau', 1, 0);
  IF coalesce((p->>'ok')::boolean, false) IS NOT TRUE THEN RETURN p; END IF;
  v := public.inventaire_deposer_interne(a, public.climat_objet_interne('bouteille_eau', v_n));
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'point_eau_depot_refuse:%', v->>'raison'; END IF;
  INSERT INTO public.climat_points_eau_puisages (nom, tranche, quantite) VALUES (a, v_tr, v_n)
    ON CONFLICT (nom, tranche) DO UPDATE SET quantite = climat_points_eau_puisages.quantite + EXCLUDED.quantite;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'point_eau_puiser', prm,
    v || jsonb_build_object('ok', true, 'quantite', v_n, 'pa_depenses', 1,
      'restant', (e->>'restant')::integer - v_n, 'heure_fin', (e->>'heure_fin')::integer,
      'pa', (SELECT pa FROM public.personnages_donnees WHERE name = a)));
END $$;

-- L'ancien bouton « Remplir une bouteille d'eau » (0 PA) est retiré : un écran resté ouvert reçoit une explication.
CREATE OR REPLACE FUNCTION public.point_eau_remplir(p_requete uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', false, 'raison', 'remplace_par_puiser');
$$;

-- Consigne de canicule : l'eau se puise (1 PA), elle ne se remplit plus.
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;
SELECT pg_temp.rp_raccorder('public.climat_consigne_interne(text,text,text)'::regprocedure,
  $a$SELECT 'Remplissez-la gratuitement à ' || nom || '.' INTO v_eau$a$,
  $b$SELECT 'L''eau est gratuite à ' || nom || ' : puiser coûte 1 PA, jusqu''à 10 bouteilles toutes les 6 heures.' /* point_eau_puiser_v1 */ INTO v_eau$b$,
  'point_eau_puiser_v1');

REVOKE ALL ON FUNCTION public.point_eau_tranche_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.point_eau_etat() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.point_eau_puiser(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.point_eau_etat() TO authenticated;
GRANT EXECUTE ON FUNCTION public.point_eau_puiser(uuid, integer) TO authenticated;

-- Mairie de Krasnov : une seule sortie, dans sa rue.
DELETE FROM public.rue_sorties_batiments
 WHERE country = 'soviet' AND city = 'ville_b' AND building = 'mairie' AND noeud = 'krasnov-place-ours';

COMMIT;
