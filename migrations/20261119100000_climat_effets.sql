-- MALADIES, PÉREMPTION ET CLIMAT — LOT 5 : effets du brouillard, de l'orage, de la crue et de la canicule
-- (GAME-DESIGN-MALADIES-CLIMAT.md §§ 3, 6 à 9 et décisions de Fred des 18 et 19/11/2026).
-- • Canicule : au début, −3 PA pour toute personne présente dans la ville, sauf avec une bouteille d'eau (consommée) ; puis
--   coup de chaleur selon le tableau des PA (eau : −5 points). À la fin de la journée, la nourriture portée sur soi est avariée.
-- • Orage : ordinateurs, box et caméras de la ville hors service pendant l'événement ; un groupe électrogène installé dans un
--   bureau le maintient en service s'il contient 5 bidons de carburant au début de la coupure (consommés).
-- • Crue : les 2 ou 3 lieux nommés sont inaccessibles ; entrepôts et commerces qui s'y trouvent perdent 20 % de leurs stocks,
--   sauf protection par sacs de sable (posés par le propriétaire ou l'exploitant, 1 PA, pour une crue).
-- • État de catastrophe naturelle (décision du 19/11) : le ministre de l'Intérieur propose, le Premier ministre déclare dans
--   les 72 h ; 50 % des stocks perdus remboursés au prix de base sur le budget de l'État ; par défaut, seuls ceux qui avaient
--   posé des sacs ; le Premier ministre peut étendre à tous les sinistrés. Son écran montre les deux options et leur coût.
-- • Brouillard : ses modificateurs (+10 % de réussite, −20 % de détection) sont exposés par une fonction, sans être branchés
--   dans les actes illégaux : la criminalité est en cours de conception (consigne de Fred), on n'y touche pas.
-- • Boutique « Équipements contre les intempéries » : bouteilles d'eau (marchés de Républia), sacs de sable (quincailleries de
--   Républia : armureries de Luthécia et de Montrouge, Chasse et Pêche de Port-Sainte-Marie), groupe électrogène (garage de
--   Novomirsk ; en Républia, faute de garagiste, armureries-quincailleries de Luthécia et de Montrouge).
BEGIN;

INSERT INTO public.aliments_parametres (cle, valeur) VALUES
  ('prix_bouteille_eau', 3), ('prix_sac_sable', 60), ('prix_groupe_electrogene', 900), ('groupe_bidons', 5),
  ('crue_perte_pct', 20), ('sacs_protection_pct', 100), ('catastrophe_part_pct', 50), ('catastrophe_delai_h', 72),
  ('brouillard_bonus_reussite', 10), ('brouillard_malus_detection', 20)
ON CONFLICT (cle) DO NOTHING;
ALTER TABLE public.climat_evenements ADD COLUMN IF NOT EXISTS fin_traitee_le timestamptz;
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'boutique_climat', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'boutique_climat' AND pa = 0 AND cost = 0);
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'poser_sacs_sable', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'poser_sacs_sable' AND pa = 1 AND cost = 0);

-- ── Objets et boutique ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.climat_objet_interne(p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_cle
    WHEN 'bouteille_eau' THEN jsonb_build_object('name', 'Bouteille d''eau', 'icon', 'ti-bottle', 'type', 'bouteille_eau',
      'stackable', true, 'stackKey', 'bouteille_eau', 'qty', p_qte, 'legal', true, 'desc', 'Protège de la canicule (consommée).')
    WHEN 'sac_de_sable' THEN jsonb_build_object('name', 'Lot de sacs de sable', 'icon', 'ti-bag', 'type', 'sac_de_sable',
      'stackable', true, 'stackKey', 'sac_de_sable', 'qty', p_qte, 'legal', true, 'imageUrl', 'images/objet-sac-de-sable.webp',
      'desc', 'Posé devant un bâtiment de la zone inondable, il le protège pour une crue.')
    WHEN 'groupe_electrogene' THEN jsonb_build_object('name', 'Groupe électrogène', 'icon', 'ti-bolt', 'type', 'groupe-electrogene',
      'generique_id', 'groupe-electrogene', 'stackable', false, 'legal', true, 'bidons', 0,
      'desc', 'Installé dans un bureau, il maintient l''ordinateur, la box et les caméras pendant une coupure (5 bidons par coupure).')
  END;
$$;

CREATE TABLE IF NOT EXISTS public.climat_boutiques (
  id text PRIMARY KEY, pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL, cles text[] NOT NULL
);
ALTER TABLE public.climat_boutiques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_boutiques FROM anon, authenticated;
INSERT INTO public.climat_boutiques (id, pays, ville, batiment, piece, cles) VALUES
  ('armurerie-luthecia',  'republic', 'capitale', 'armurerie',        'magasin',        ARRAY['sac_de_sable', 'groupe_electrogene']),
  ('armurerie-montrouge', 'republic', 'ville_b',  'armurerie',        'magasin',        ARRAY['sac_de_sable', 'groupe_electrogene']),
  ('chasse-peche-psm',    'republic', 'ville_a',  'chasse-peche-psm', 'boutique',       ARRAY['sac_de_sable']),
  ('marche-luthecia',     'republic', 'capitale', 'marche',           'marche_ext',     ARRAY['bouteille_eau']),
  ('marche-montrouge',    'republic', 'ville_b',  'marche',           'marche_ext',     ARRAY['bouteille_eau']),
  ('marche-psm',          'republic', 'ville_a',  'marche-psm',       'etals',          ARRAY['bouteille_eau']),
  ('garage-novomirsk',    'soviet',   'capitale', 'garage-novomirsk', 'atelier_garage', ARRAY['groupe_electrogene'])
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.climat_boutique_interne(p_nom text)
RETURNS public.climat_boutiques LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT b.* FROM public.climat_boutiques b JOIN public.personnages_donnees d ON d.name = p_nom
   WHERE d.country = b.pays AND d.current_city = b.ville AND d.current_building = b.batiment AND d.current_room = b.piece;
$$;
CREATE OR REPLACE FUNCTION public.climat_prix_interne(p_cle text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.aliments_param_interne(CASE p_cle WHEN 'bouteille_eau' THEN 'prix_bouteille_eau' WHEN 'sac_de_sable' THEN 'prix_sac_sable'
           ELSE 'prix_groupe_electrogene' END, 0);
$$;

CREATE OR REPLACE FUNCTION public.boutique_climat_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); b public.climat_boutiques;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  b := public.climat_boutique_interne(a);
  IF b.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_boutique'); END IF;
  RETURN jsonb_build_object('ok', true, 'offre', (SELECT jsonb_agg(jsonb_build_object('cle', c, 'prix', public.climat_prix_interne(c))) FROM unnest(b.cles) c));
END $$;

CREATE OR REPLACE FUNCTION public.boutique_climat_acheter(p_requete uuid, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cle', p_cle, 'qte', p_qte); v jsonb; b public.climat_boutiques;
        v_prix numeric; v_total numeric; v_fonds numeric; v_debit numeric; v_dep jsonb; i integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'boutique_climat_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  b := public.climat_boutique_interne(a);
  IF b.id IS NULL OR NOT (p_cle = ANY (b.cles)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_boutique'); END IF;
  IF p_qte IS NULL OR p_qte < 1 OR p_qte > (CASE WHEN p_cle = 'groupe_electrogene' THEN 1 ELSE 10 END) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  v_prix := public.climat_prix_interne(p_cle);
  v_total := v_prix * p_qte;
  SELECT coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires c WHERE c.personnage = d.name AND c.banque = 'nationale' ORDER BY id LIMIT 1), 0)
    INTO v_fonds FROM public.personnages_donnees d WHERE d.name = a;
  IF v_fonds < v_total THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = a) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(a, 'boutique_climat', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_debit := public.argent_debiter_interne(a, v_total, 'liquide_puis_nationale');
  IF v_debit IS DISTINCT FROM v_total THEN RAISE EXCEPTION 'boutique_climat: debit incomplet'; END IF;
  v_dep := public.inventaire_deposer_interne(a, public.climat_objet_interne(p_cle, p_qte));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'boutique_climat: depot refuse %', v_dep; END IF;
  v := jsonb_build_object('ok', true, 'cle', p_cle, 'quantite', p_qte, 'paye', v_total)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'liquide', liquide) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'boutique_climat_acheter', prm, v);
END $$;

-- ── Groupe électrogène ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;
SELECT pg_temp.rp_raccorder('public.equipement_installer(text)'::regprocedure,
  $a$'peripherique-reseau-intranet')$a$, $b$'peripherique-reseau-intranet', 'groupe-electrogene')$b$, 'groupe-electrogene');
SELECT pg_temp.rp_raccorder('public.equipements_local_lire()'::regprocedure,
  $a$'peripherique-reseau-intranet')$a$, $b$'peripherique-reseau-intranet', 'groupe-electrogene')$b$, 'groupe-electrogene');

-- Remplir le groupe électrogène de son bureau avec des bidons de carburant de l'inventaire.
CREATE OR REPLACE FUNCTION public.groupe_remplir(p_requete uuid, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('qte', p_qte); v jsonb; g public.equipements_installes; v_inv jsonb; v_n integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'groupe_remplir', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  IF coalesce(p_qte, 0) < 1 OR p_qte > 50 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  SELECT * INTO g FROM public.equipements_bureau_interne(a) WHERE generique_id = 'groupe-electrogene' LIMIT 1;
  IF g.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_groupe'); END IF;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF public.inventaire_quantite(v_inv, 'carburant') < p_qte THEN RETURN jsonb_build_object('ok', false, 'raison', 'bidons_insuffisants'); END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(v_inv, 'carburant', p_qte), updated_at = now() WHERE name = a;
  UPDATE public.equipements_installes SET objet = jsonb_set(coalesce(objet, '{}'::jsonb), '{bidons}', to_jsonb(coalesce((objet->>'bidons')::integer, 0) + p_qte), true)
   WHERE id = g.id RETURNING (objet->>'bidons')::integer INTO v_n;
  v := jsonb_build_object('ok', true, 'bidons', v_n)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'groupe_remplir', prm, v);
END $$;

-- Coupure de courant dans une pièce : orage annoncé en cours dans la ville, sans groupe électrogène alimenté dans la pièce.
CREATE OR REPLACE FUNCTION public.climat_coupure_interne(p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.climat_evenements e WHERE e.type = 'orage' AND e.pays = p_pays AND e.ville = p_ville AND NOT e.annule
                   AND e.alerte_le IS NOT NULL AND now() >= e.debut AND now() < e.fin)
     AND NOT EXISTS (SELECT 1 FROM public.equipements_installes g WHERE g.generique_id = 'groupe-electrogene' AND g.pays = p_pays
                   AND g.ville = p_ville AND g.batiment = p_batiment AND g.piece = p_piece
                   AND coalesce((g.objet->>'actif_jusqu')::timestamptz, '-infinity') > now());
$$;

SELECT pg_temp.rp_raccorder('public.equipements_connecte_interne(text)'::regprocedure,
  $a$           WHERE generique_id IN ('ordinateur-complet', 'box-internet')) = 2;$a$,
  $b$           WHERE generique_id IN ('ordinateur-complet', 'box-internet')) = 2
     AND NOT coalesce((SELECT public.climat_coupure_interne(country, current_city, current_building, current_room)
                         FROM public.personnages_donnees WHERE name = p_acteur), false); -- climat_coupure_v1$b$,
  'climat_coupure_v1');
SELECT pg_temp.rp_raccorder('public.equipements_ordinateurs_connectes_interne(text)'::regprocedure,
  $a$     WHERE e.proprietaire = p_proprietaire AND e.generique_id IN ('ordinateur-complet', 'box-internet')$a$,
  $b$     WHERE e.proprietaire = p_proprietaire AND e.generique_id IN ('ordinateur-complet', 'box-internet')
       AND NOT public.climat_coupure_interne(e.pays, e.ville, e.batiment, e.piece) -- climat_coupure_v1$b$,
  'climat_coupure_v1');
SELECT pg_temp.rp_raccorder('public.camera_operationnelle_interne(uuid)'::regprocedure,
  $a$                    WHERE r.id = p_id), false);$a$,
  $b$                    WHERE r.id = p_id), false)
     AND NOT coalesce((SELECT public.climat_coupure_interne(c.pays, c.ville, c.batiment, c.piece) FROM public.cameras_posees c WHERE c.id = p_id), false); -- climat_coupure_v1$b$,
  'climat_coupure_v1');

-- ── Crue : lieux inaccessibles, sacs de sable, pertes ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.climat_batiment_inonde_interne(p_pays text, p_ville text, p_batiment text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.climat_evenements e WHERE e.type = 'crue' AND e.pays = p_pays AND e.ville = p_ville AND NOT e.annule
                   AND e.alerte_le IS NOT NULL AND now() >= e.debut AND now() < e.fin
                   AND EXISTS (SELECT 1 FROM jsonb_array_elements(e.lieux) l WHERE l->>'batiment' = p_batiment));
$$;
SELECT pg_temp.rp_raccorder('public.navigation_commander_personnage_interne(text,text,text,text)'::regprocedure,
  $a$ moi:=p_nom;$a$,
  $b$ moi:=p_nom;
 IF p_mode='piece' AND public.climat_batiment_inonde_interne((SELECT country FROM public.personnages_donnees WHERE name=p_nom),
      (SELECT current_city FROM public.personnages_donnees WHERE name=p_nom), p_destination) THEN -- climat_crue_v1
  RETURN jsonb_build_object('ok',false,'raison','batiment_inonde'); END IF;$b$,
  'climat_crue_v1');

CREATE TABLE IF NOT EXISTS public.climat_protections (
  id bigserial PRIMARY KEY, pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, pose_par text NOT NULL,
  pose_le timestamptz NOT NULL DEFAULT now(), evenement bigint
);
CREATE INDEX IF NOT EXISTS climat_protections_lieu_idx ON public.climat_protections (pays, ville, batiment) WHERE evenement IS NULL;
ALTER TABLE public.climat_protections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_protections FROM anon, authenticated;

-- Le propriétaire ou l'exploitant pose un lot de sacs (1 PA) devant un bâtiment de la zone inondable où il se trouve.
CREATE OR REPLACE FUNCTION public.sacs_sable_poser(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; d public.personnages_donnees; v_inv jsonb; v_droit boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'sacs_sable_poser', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF NOT EXISTS (SELECT 1 FROM public.climat_zones_inondables WHERE pays = d.country AND ville = d.current_city AND batiment = d.current_building) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_zone_inondable'); END IF;
  v_droit := EXISTS (SELECT 1 FROM public.entreprises e
                      WHERE replace(coalesce(e.data->>'proprietaire', ''), 'pj:', '') = a
                        AND ((e.data->>'country' = d.country AND e.data->>'city' = d.current_city AND e.data->>'buildingId' = d.current_building)
                          OR (e.data->'implantation'->>'country' = d.country AND e.data->'implantation'->>'city' = d.current_city
                              AND e.data->'implantation'->>'buildingId' = d.current_building)))
          OR (d.current_building LIKE 'entrepot-logistique-%' AND d.poste->>'id' = 'directeur_entrepot');
  IF NOT v_droit THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire_ni_exploitant'); END IF;
  IF EXISTS (SELECT 1 FROM public.climat_protections WHERE pays = d.country AND ville = d.current_city AND batiment = d.current_building AND evenement IS NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_protege'); END IF;
  v_inv := coalesce(d.inventory, '[]'::jsonb);
  IF public.inventaire_quantite(v_inv, 'sac_de_sable') < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_sacs'); END IF;
  v := public.payer_ordre(a, 'poser_sacs_sable', 1, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(inventory, 'sac_de_sable', 1), updated_at = now() WHERE name = a;
  INSERT INTO public.climat_protections (pays, ville, batiment, pose_par) VALUES (d.country, d.current_city, d.current_building, a);
  v := jsonb_build_object('ok', true, 'batiment', d.current_building, 'pa', v->'pa')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'sacs_sable_poser', prm, v);
END $$;

CREATE TABLE IF NOT EXISTS public.climat_crue_pertes (
  evenement bigint NOT NULL REFERENCES public.climat_evenements(id), cible text NOT NULL, pays text NOT NULL, ville text NOT NULL,
  batiment text NOT NULL, proprietaire text, protege boolean NOT NULL, valeur numeric NOT NULL DEFAULT 0, detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  indemnite numeric NOT NULL DEFAULT 0, PRIMARY KEY (evenement, cible)
);
ALTER TABLE public.climat_crue_pertes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_crue_pertes FROM anon, authenticated;

-- Retire p_pct % (arrondi inférieur) de chaque stock d'un objet {cle: quantité} ; rend {stock, perdu, valeur}.
CREATE OR REPLACE FUNCTION public.climat_stock_amputer_interne(p_stock jsonb, p_pct numeric, p_pays text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE k text; q numeric; p numeric; v_stock jsonb := coalesce(p_stock, '{}'::jsonb); v_perdu jsonb := '{}'::jsonb; v_valeur numeric := 0; v_prix numeric;
BEGIN
  IF jsonb_typeof(v_stock) <> 'object' THEN RETURN jsonb_build_object('stock', p_stock, 'perdu', '{}'::jsonb, 'valeur', 0); END IF;
  FOR k, q IN SELECT key, CASE WHEN value ~ '^-?[0-9.]+$' THEN value::numeric ELSE 0 END FROM jsonb_each_text(v_stock) LOOP
    p := floor(greatest(q, 0) * p_pct / 100);
    IF p > 0 THEN
      v_stock := jsonb_set(v_stock, ARRAY[k], to_jsonb(q - p));
      v_perdu := v_perdu || jsonb_build_object(k, p);
      SELECT prix_base INTO v_prix FROM public.ressources_economie_pays(p_pays) WHERE cle = k;
      IF v_prix IS NULL THEN SELECT prix_fixe INTO v_prix FROM public.recettes_commerce WHERE id = k; END IF;
      v_valeur := v_valeur + p * coalesce(v_prix, 0);
    END IF;
  END LOOP;
  RETURN jsonb_build_object('stock', v_stock, 'perdu', v_perdu, 'valeur', round(v_valeur, 2));
END $$;

CREATE OR REPLACE FUNCTION public.climat_crue_appliquer_interne(e public.climat_evenements)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE l jsonb; v_bat text; v_prot boolean; v_pct numeric; v_id text; v_etat jsonb; r jsonb; ent record; v_d jsonb; v_val numeric; v_det jsonb;
        k text; v_n integer := 0; v_min text;
BEGIN
  FOR l IN SELECT * FROM jsonb_array_elements(e.lieux) LOOP
    v_bat := l->>'batiment';
    UPDATE public.climat_protections SET evenement = e.id
     WHERE pays = e.pays AND ville = e.ville AND batiment = v_bat AND evenement IS NULL;
    v_prot := FOUND;
    v_pct := public.aliments_param_interne('crue_perte_pct', 20)
             * CASE WHEN v_prot THEN (100 - public.aliments_param_interne('sacs_protection_pct', 100)) / 100 ELSE 1 END;
    -- Entrepôt logistique de l'État.
    v_id := e.pays || '_' || e.ville || '_' || v_bat;
    SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF v_etat IS NOT NULL AND jsonb_typeof(v_etat->'entrepot'->'stock') = 'object' THEN
      r := public.climat_stock_amputer_interne(v_etat->'entrepot'->'stock', v_pct, e.pays);
      UPDATE public.batiments_etat SET data = to_jsonb((v_etat || jsonb_build_object('entrepot', (v_etat->'entrepot') || jsonb_build_object('stock', r->'stock')))::text),
             updated_at = now() WHERE id = v_id;
      INSERT INTO public.climat_crue_pertes (evenement, cible, pays, ville, batiment, proprietaire, protege, valeur, detail)
      VALUES (e.id, 'entrepot:' || v_id, e.pays, e.ville, v_bat, NULL, v_prot, (r->>'valeur')::numeric, r->'perdu') ON CONFLICT DO NOTHING;
      v_n := v_n + 1;
    END IF;
    -- Commerces (moteur historique et fonds PJ) installés dans ce bâtiment.
    FOR ent IN SELECT id, data FROM public.entreprises
                WHERE (data->>'country' = e.pays AND data->>'city' = e.ville AND data->>'buildingId' = v_bat)
                   OR (data->'implantation'->>'country' = e.pays AND data->'implantation'->>'city' = e.ville AND data->'implantation'->>'buildingId' = v_bat)
                FOR UPDATE LOOP
      v_d := ent.data; v_val := 0; v_det := '{}'::jsonb;
      FOREACH k IN ARRAY ARRAY['stockMatieres', 'stockProduits', 'stockReferences'] LOOP
        IF jsonb_typeof(v_d->k) = 'object' THEN
          r := public.climat_stock_amputer_interne(v_d->k, v_pct, e.pays);
          v_d := jsonb_set(v_d, ARRAY[k], r->'stock');
          v_val := v_val + (r->>'valeur')::numeric;
          v_det := v_det || jsonb_build_object(k, r->'perdu');
        END IF;
      END LOOP;
      UPDATE public.entreprises SET data = v_d, updated_at = now() WHERE id = ent.id;
      INSERT INTO public.climat_crue_pertes (evenement, cible, pays, ville, batiment, proprietaire, protege, valeur, detail)
      VALUES (e.id, ent.id, e.pays, e.ville, v_bat, nullif(replace(coalesce(ent.data->>'proprietaire', ''), 'pj:', ''), ''), v_prot, v_val, v_det)
      ON CONFLICT DO NOTHING;
      v_n := v_n + 1;
    END LOOP;
  END LOOP;
  -- Proposition d'état de catastrophe naturelle : courrier au ministre de l'Intérieur en poste.
  SELECT name INTO v_min FROM public.personnages_donnees WHERE country = e.pays AND poste->>'id' = 'min_int' LIMIT 1;
  IF v_min IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne('Ministère de l''Intérieur', v_min, 'Crue à ' || public.climat_nom_ville_interne(e.pays, e.ville),
      'Une crue frappe ' || public.climat_nom_ville_interne(e.pays, e.ville) || '. Vous pouvez proposer au Premier ministre de déclarer l''état de catastrophe naturelle (72 h après la crue au plus tard). '
      || '[[act:catastrophe_proposer|' || e.id || ']]', NULL);
  END IF;
  RETURN v_n;
END $$;

-- ── Canicule ─────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.climat_canicule_appliquer_interne(e public.climat_evenements)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_eau boolean; v_pa integer; v_pct numeric; v_n integer := 0; v_hosp boolean;
BEGIN
  FOR p IN SELECT name, coalesce(inventory, '[]'::jsonb) inv, coalesce(pa, 0) pa, hospitalisation FROM public.personnages_donnees
            WHERE country = e.pays AND current_city = e.ville FOR UPDATE LOOP
    v_hosp := coalesce(p.hospitalisation, 'null'::jsonb) NOT IN ('null'::jsonb, '{}'::jsonb, 'false'::jsonb);
    v_eau := public.inventaire_quantite(p.inv, 'bouteille_eau') >= 1;
    IF v_eau THEN
      UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(p.inv, 'bouteille_eau', 1), updated_at = now() WHERE name = p.name;
      v_pa := p.pa;
    ELSE
      v_pa := greatest(0, p.pa - 3);
      UPDATE public.personnages_donnees SET pa = v_pa, updated_at = now() WHERE name = p.name;
    END IF;
    v_pct := greatest(0, public.maladie_risque_pa_interne(v_pa, v_hosp) - CASE WHEN v_eau THEN 5 ELSE 0 END);
    PERFORM public.maladie_tirer_interne(p.name, 'coup_de_chaleur', v_pct, 'canicule');
    INSERT INTO public.climat_effets_personnages (evenement, nom, effets)
    VALUES (e.id, p.name, jsonb_build_object('eau', v_eau, 'pa_perdus', CASE WHEN v_eau THEN 0 ELSE least(3, p.pa) END, 'risque', v_pct))
    ON CONFLICT DO NOTHING;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END $$;

-- Fin de la canicule : la nourriture portée sur soi par les présents est avariée (piles et aliments manufacturés).
CREATE OR REPLACE FUNCTION public.climat_canicule_fin_interne(e public.climat_evenements)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_inv jsonb; v_gates integer; v_n integer := 0;
BEGIN
  FOR p IN SELECT name, inventory FROM public.personnages_donnees WHERE country = e.pays AND current_city = e.ville AND jsonb_typeof(inventory) = 'array' FOR UPDATE LOOP
    SELECT count(*) FILTER (WHERE public.aliment_objet_comestible_interne(x) AND NOT coalesce((x->>'avarie')::boolean, false)),
           jsonb_agg(CASE WHEN public.aliment_objet_comestible_interne(x) THEN x || '{"avarie": true}'::jsonb ELSE x END ORDER BY o)
      INTO v_gates, v_inv FROM jsonb_array_elements(p.inventory) WITH ORDINALITY t(x, o);
    IF v_gates > 0 THEN
      UPDATE public.personnages_donnees SET inventory = v_inv, updated_at = now() WHERE name = p.name;
      INSERT INTO public.climat_effets_personnages (evenement, nom, effets) VALUES (e.id, p.name, jsonb_build_object('aliments_gates', v_gates))
      ON CONFLICT (evenement, nom) DO UPDATE SET effets = public.climat_effets_personnages.effets || EXCLUDED.effets, vu = false;
      v_n := v_n + 1;
    END IF;
  END LOOP;
  RETURN v_n;
END $$;

-- Aliment manufacturé gâté par la chaleur : il compte comme périmé quand on le mange.
SELECT pg_temp.rp_raccorder('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$*86400000; -- aliments_peremption_v1$a$,
  $b$*86400000; -- aliments_peremption_v1
   v_frais:=v_frais AND NOT coalesce((v_item->>'avarie')::boolean,false); -- climat_canicule_v1$b$,
  'climat_canicule_v1');

-- ── Orage : le groupe électrogène prend ses bidons au début de la coupure ─────────────────────────
CREATE OR REPLACE FUNCTION public.climat_orage_appliquer_interne(e public.climat_evenements)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_n integer; v_b integer := public.aliments_param_interne('groupe_bidons', 5)::integer;
BEGIN
  UPDATE public.equipements_installes SET objet = jsonb_set(jsonb_set(coalesce(objet, '{}'::jsonb), '{bidons}', to_jsonb(coalesce((objet->>'bidons')::integer, 0) - v_b)),
         '{actif_jusqu}', to_jsonb(e.fin))
   WHERE generique_id = 'groupe-electrogene' AND pays = e.pays AND ville = e.ville AND coalesce((objet->>'bidons')::integer, 0) >= v_b;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;

-- ── Brouillard : modificateurs exposés (non branchés : criminalité en cours de conception) ─────────
CREATE OR REPLACE FUNCTION public.climat_brouillard_modificateurs_interne(p_pays text, p_ville text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN EXISTS (SELECT 1 FROM public.climat_evenements e WHERE e.type = 'brouillard' AND e.pays = p_pays AND e.ville = p_ville
                             AND NOT e.annule AND e.alerte_le IS NOT NULL AND now() >= e.debut AND now() < e.fin)
         THEN jsonb_build_object('brouillard', true, 'bonus_reussite', public.aliments_param_interne('brouillard_bonus_reussite', 10),
                                 'malus_detection', public.aliments_param_interne('brouillard_malus_detection', 20))
         ELSE jsonb_build_object('brouillard', false, 'bonus_reussite', 0, 'malus_detection', 0) END;
$$;

-- ── Passe : débuts et fins d'événements ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.climat_effets_passe_interne()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e public.climat_evenements; v_n integer := 0;
BEGIN
  FOR e IN SELECT * FROM public.climat_evenements WHERE NOT annule AND alerte_le IS NOT NULL AND effets_le IS NULL
            AND now() >= debut AND now() < fin ORDER BY debut FOR UPDATE LOOP
    IF e.type = 'blizzard' THEN PERFORM public.climat_blizzard_appliquer_interne(e);
    ELSIF e.type = 'canicule' THEN PERFORM public.climat_canicule_appliquer_interne(e);
    ELSIF e.type = 'crue' THEN PERFORM public.climat_crue_appliquer_interne(e);
    ELSIF e.type = 'orage' THEN PERFORM public.climat_orage_appliquer_interne(e);
    END IF;
    UPDATE public.climat_evenements SET effets_le = now() WHERE id = e.id;
    v_n := v_n + 1;
  END LOOP;
  FOR e IN SELECT * FROM public.climat_evenements WHERE NOT annule AND effets_le IS NOT NULL AND fin_traitee_le IS NULL AND now() >= fin
            ORDER BY fin FOR UPDATE LOOP
    IF e.type = 'canicule' THEN PERFORM public.climat_canicule_fin_interne(e); END IF;
    UPDATE public.climat_evenements SET fin_traitee_le = now() WHERE id = e.id;
  END LOOP;
  RETURN v_n;
END $$;

-- ── État de catastrophe naturelle ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.climat_catastrophes (
  evenement bigint PRIMARY KEY REFERENCES public.climat_evenements(id), pays text NOT NULL,
  propose_par text, propose_le timestamptz, declare_par text, declare_le timestamptz, option text CHECK (option IN ('sacs', 'tous')),
  cout numeric
);
ALTER TABLE public.climat_catastrophes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_catastrophes FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.catastrophe_couts_interne(p_evenement bigint)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object(
    'part', public.aliments_param_interne('catastrophe_part_pct', 50),
    'cout_sacs', coalesce(round(sum(valeur) FILTER (WHERE protege) * public.aliments_param_interne('catastrophe_part_pct', 50) / 100, 2), 0),
    'cout_tous', coalesce(round(sum(valeur) * public.aliments_param_interne('catastrophe_part_pct', 50) / 100, 2), 0),
    'sinistres_sacs', count(*) FILTER (WHERE protege AND valeur > 0), 'sinistres_tous', count(*) FILTER (WHERE valeur > 0),
    'pertes', coalesce(round(sum(valeur), 2), 0))
  FROM public.climat_crue_pertes WHERE evenement = p_evenement;
$$;

CREATE OR REPLACE FUNCTION public.catastrophe_etat(p_evenement bigint)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); e public.climat_evenements; c public.climat_catastrophes; v_poste text; v_pays text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO e FROM public.climat_evenements WHERE id = p_evenement AND type = 'crue';
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'crue_inconnue'); END IF;
  SELECT poste->>'id', country INTO v_poste, v_pays FROM public.personnages_donnees WHERE name = a;
  IF v_pays IS DISTINCT FROM e.pays OR v_poste NOT IN ('min_int', 'pm') THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  SELECT * INTO c FROM public.climat_catastrophes WHERE evenement = e.id;
  RETURN jsonb_build_object('ok', true, 'evenement', e.id, 'ville', e.ville, 'poste', v_poste,
    'limite', e.fin + make_interval(hours => public.aliments_param_interne('catastrophe_delai_h', 72)::integer),
    'propose', c.propose_le IS NOT NULL, 'declare', c.declare_le IS NOT NULL, 'option', c.option, 'cout', c.cout,
    'reserve', (SELECT coalesce((data->>'reserveJour')::numeric, 0) FROM public.budgets_nationaux WHERE id = e.pays))
    || public.catastrophe_couts_interne(e.id);
END $$;

CREATE OR REPLACE FUNCTION public.catastrophe_proposer(p_evenement bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); e public.climat_evenements; v_pm text; v_c jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO e FROM public.climat_evenements WHERE id = p_evenement AND type = 'crue' AND effets_le IS NOT NULL;
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'crue_inconnue'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = a AND country = e.pays AND poste->>'id' = 'min_int') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  IF now() > e.fin + make_interval(hours => public.aliments_param_interne('catastrophe_delai_h', 72)::integer) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_depasse'); END IF;
  INSERT INTO public.climat_catastrophes (evenement, pays, propose_par, propose_le) VALUES (e.id, e.pays, a, now())
  ON CONFLICT (evenement) DO NOTHING;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_propose'); END IF;
  v_c := public.catastrophe_couts_interne(e.id);
  SELECT name INTO v_pm FROM public.personnages_donnees WHERE country = e.pays AND poste->>'id' = 'pm' LIMIT 1;
  IF v_pm IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne('Ministère de l''Intérieur', v_pm, 'Proposition : état de catastrophe naturelle',
      'Le ministre de l''Intérieur vous propose de déclarer l''état de catastrophe naturelle après la crue de ' || public.climat_nom_ville_interne(e.pays, e.ville)
      || '. Deux options : indemniser les seuls sinistrés qui avaient posé des sacs de sable (' || (v_c->>'cout_sacs') || '), ou tous les sinistrés ('
      || (v_c->>'cout_tous') || '). [[act:catastrophe_examiner|' || e.id || ']]', NULL);
  END IF;
  RETURN jsonb_build_object('ok', true, 'premier_ministre', v_pm IS NOT NULL) || v_c;
END $$;

CREATE OR REPLACE FUNCTION public.catastrophe_declarer(p_evenement bigint, p_etendre boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); e public.climat_evenements; c public.climat_catastrophes; v_part numeric; v_total numeric := 0;
        r record; v_ind numeric; v_nat jsonb; v_rep jsonb; v_flag text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO e FROM public.climat_evenements WHERE id = p_evenement AND type = 'crue';
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'crue_inconnue'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = a AND country = e.pays AND poste->>'id' = 'pm') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  SELECT * INTO c FROM public.climat_catastrophes WHERE evenement = e.id FOR UPDATE;
  IF c.propose_le IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_proposition'); END IF;
  IF c.declare_le IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_declare'); END IF;
  IF now() > e.fin + make_interval(hours => public.aliments_param_interne('catastrophe_delai_h', 72)::integer) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_depasse'); END IF;
  v_part := public.aliments_param_interne('catastrophe_part_pct', 50);
  SELECT coalesce(round(sum(valeur) * v_part / 100, 2), 0) INTO v_total FROM public.climat_crue_pertes
   WHERE evenement = e.id AND valeur > 0 AND (protege OR coalesce(p_etendre, false));
  SELECT data INTO v_nat FROM public.budgets_nationaux WHERE id = e.pays FOR UPDATE;
  IF coalesce((v_nat->>'reserveJour')::numeric, 0) < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'budget_insuffisant', 'cout', v_total, 'reserve', coalesce((v_nat->>'reserveJour')::numeric, 0)); END IF;
  UPDATE public.budgets_nationaux SET data = jsonb_set(coalesce(v_nat, '{}'::jsonb), '{reserveJour}', to_jsonb(coalesce((v_nat->>'reserveJour')::numeric, 0) - v_total)),
         updated_at = now() WHERE id = e.pays;
  FOR r IN SELECT * FROM public.climat_crue_pertes WHERE evenement = e.id AND valeur > 0 AND (protege OR coalesce(p_etendre, false)) FOR UPDATE LOOP
    v_ind := round(r.valeur * v_part / 100, 2);
    IF r.cible LIKE 'entrepot:%' THEN
      v_flag := current_setting('rp.caisse_interne', true);
      PERFORM set_config('rp.caisse_interne', 'on', true);
      v_rep := public.caisse_institution_mouvement(public.entrepot_caisse_id(substr(r.cible, 10)), v_ind, true);
      PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
      IF (v_rep->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'catastrophe : caisse entrepot refusee %', v_rep; END IF;
    ELSE
      UPDATE public.entreprises SET data = jsonb_set(data, '{caisse}', to_jsonb(coalesce((data->>'caisse')::numeric, 0) + v_ind)), updated_at = now() WHERE id = r.cible;
    END IF;
    UPDATE public.climat_crue_pertes SET indemnite = v_ind WHERE evenement = r.evenement AND cible = r.cible;
  END LOOP;
  UPDATE public.climat_catastrophes SET declare_par = a, declare_le = now(), option = CASE WHEN p_etendre THEN 'tous' ELSE 'sacs' END, cout = v_total
   WHERE evenement = e.id;
  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES (e.pays, e.ville, '🏛️ État de catastrophe naturelle déclaré à ' || public.climat_nom_ville_interne(e.pays, e.ville) || ' : '
    || CASE WHEN p_etendre THEN 'tous les sinistrés' ELSE 'les sinistrés qui avaient posé des sacs de sable' END
    || ' sont indemnisés à ' || v_part || ' % de leurs pertes.', NULL);
  RETURN jsonb_build_object('ok', true, 'option', CASE WHEN p_etendre THEN 'tous' ELSE 'sacs' END, 'cout', v_total);
END $$;

REVOKE ALL ON FUNCTION public.climat_objet_interne(text, integer), public.climat_boutique_interne(text), public.climat_prix_interne(text),
  public.climat_coupure_interne(text, text, text, text), public.climat_batiment_inonde_interne(text, text, text),
  public.climat_stock_amputer_interne(jsonb, numeric, text), public.climat_crue_appliquer_interne(public.climat_evenements),
  public.climat_canicule_appliquer_interne(public.climat_evenements), public.climat_canicule_fin_interne(public.climat_evenements),
  public.climat_orage_appliquer_interne(public.climat_evenements), public.climat_brouillard_modificateurs_interne(text, text),
  public.climat_effets_passe_interne(), public.catastrophe_couts_interne(bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.boutique_climat_etat(), public.boutique_climat_acheter(uuid, text, integer), public.groupe_remplir(uuid, integer),
  public.sacs_sable_poser(uuid), public.catastrophe_etat(bigint), public.catastrophe_proposer(bigint), public.catastrophe_declarer(bigint, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.boutique_climat_etat(), public.boutique_climat_acheter(uuid, text, integer), public.groupe_remplir(uuid, integer),
  public.sacs_sable_poser(uuid), public.catastrophe_etat(bigint), public.catastrophe_proposer(bigint), public.catastrophe_declarer(bigint, boolean) TO authenticated;

DO $$ BEGIN
  IF position('climat_coupure_v1' IN pg_get_functiondef('public.equipements_connecte_interne(text)'::regprocedure)) = 0
     OR position('climat_coupure_v1' IN pg_get_functiondef('public.equipements_ordinateurs_connectes_interne(text)'::regprocedure)) = 0
     OR position('climat_coupure_v1' IN pg_get_functiondef('public.camera_operationnelle_interne(uuid)'::regprocedure)) = 0
     OR position('climat_crue_v1' IN pg_get_functiondef('public.navigation_commander_personnage_interne(text,text,text,text)'::regprocedure)) = 0
     OR position('climat_canicule_v1' IN pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure)) = 0
     OR position('groupe-electrogene' IN pg_get_functiondef('public.equipement_installer(text)'::regprocedure)) = 0
     OR (public.climat_stock_amputer_interne('{"bois":10,"viande":4}', 20, 'republic')->'stock'->>'bois')::int <> 8
     OR (public.climat_stock_amputer_interne('{"bois":10,"viande":4}', 20, 'republic')->'stock'->>'viande')::int <> 4
  THEN RAISE EXCEPTION 'lot 5 : controle structurel en echec'; END IF;
END $$;

COMMIT;
