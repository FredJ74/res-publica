-- CLIMAT — complément de Fred du 21/11/2026 (GAME-DESIGN-CLIMAT-20261121.md) : les parades s'achètent dans chaque pays.
-- Principe : certains commerces n'existent volontairement que dans une ville (vitrines) ; la consigne cite alors la ville.
-- • Républia : groupe électrogène ET bidons de carburant à la quincaillerie (armureries-quincailleries de Luthécia et de
--   Montrouge), en plus du garagiste là où il existe (Novomirsk). Prix : règle commune (prix PNJ = 2 × coût de revient) :
--   le bidon à 20, comme à la station-service ; le groupe garde son prix (prix_groupe_electrogene).
-- • Sels de réhydratation : vendus à l'usine pharmaceutique de Républia (déjà point de vente des médicaments) et à l'usine
--   pharmaceutique de Novomirsk (Pharmanov, boutique climat), en plus des pharmacies de joueurs. Prix : celui des
--   médicaments (pharmacie_prix_interne, règle commune) ; objet identique à celui de la pharmacie.
-- • Consignes de l'orage et de la canicule : vrais lieux de vente, nom de la ville quand le commerce est ailleurs.
-- • Contrôle : climat_parades_verifier_interne() liste toute parade citée sans lieu de vente réel dans le pays (vide = bon).
BEGIN;

INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('prix_bidon_carburant', 20) ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.climat_prix_interne(p_cle text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE p_cle
    WHEN 'bouteille_eau' THEN public.aliments_param_interne('prix_bouteille_eau', 0)
    WHEN 'sac_de_sable' THEN public.aliments_param_interne('prix_sac_sable', 0)
    WHEN 'bidon_carburant' THEN public.aliments_param_interne('prix_bidon_carburant', 20)
    WHEN 'sels_rehydratation' THEN public.pharmacie_prix_interne('coup_de_chaleur')::numeric
    ELSE public.aliments_param_interne('prix_groupe_electrogene', 0) END;
$$;

CREATE OR REPLACE FUNCTION public.climat_objet_interne(p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_cle
    WHEN 'bouteille_eau' THEN jsonb_build_object('name', 'Bouteille d''eau', 'icon', 'ti-bottle', 'type', 'bouteille_eau',
      'stackable', true, 'stackKey', 'bouteille_eau', 'qty', p_qte, 'legal', true, 'desc', 'Protège de la canicule (consommée).')
    WHEN 'sac_de_sable' THEN jsonb_build_object('name', 'Sac de sable', 'icon', 'ti-bag', 'type', 'sac_de_sable',
      'stackable', true, 'stackKey', 'sac_de_sable', 'qty', p_qte, 'legal', true, 'imageUrl', 'images/objet-sac-de-sable.webp',
      'desc', 'Posé devant un bâtiment de la zone inondable, il le garde ouvert et protège ses stocks pendant la prochaine crue.')
    WHEN 'groupe_electrogene' THEN jsonb_build_object('name', 'Groupe électrogène', 'icon', 'ti-bolt', 'type', 'groupe-electrogene',
      'generique_id', 'groupe-electrogene', 'stackable', false, 'legal', true, 'bidons', 0,
      'desc', 'Installé dans un bureau, il maintient l''ordinateur, la box et les caméras pendant une coupure (5 bidons par coupure).')
    -- Même objet que celui de la station-service (carburant_acheter_interne).
    WHEN 'bidon_carburant' THEN jsonb_build_object('name', 'carburant', 'stackKey', 'carburant', 'stackable', true, 'qty', p_qte,
      'desc', 'Bidons de carburant (1 bidon = 1 unité).')
    -- Même objet que celui de la pharmacie (pharmacie_acheter_interne).
    WHEN 'sels_rehydratation' THEN jsonb_build_object('name', 'Sels de réhydratation', 'icon', 'ti-pill', 'type', 'medicament_maladie',
      'medicament', 'sels_rehydratation', 'soigne', 'coup_de_chaleur', 'stackable', true, 'stackKey', 'medicament_sels_rehydratation', 'qty', p_qte)
  END;
$$;

UPDATE public.climat_boutiques SET cles = cles || ARRAY['bidon_carburant']
 WHERE id IN ('armurerie-luthecia', 'armurerie-montrouge') AND NOT ('bidon_carburant' = ANY (cles));
INSERT INTO public.climat_boutiques (id, pays, ville, batiment, piece, cles) VALUES
  ('usine-pharma-novomirsk', 'soviet', 'capitale', 'usine-pharmaceutique-luthecia', 'salle_ventes', ARRAY['sels_rehydratation'])
ON CONFLICT (id) DO NOTHING;

-- Lieux cités par les consignes (remplace les lignes du 21/11 matin pour le groupe et les sels).
DELETE FROM public.climat_lieux_vente WHERE cle IN ('groupe_electrogene', 'sels_rehydratation');
INSERT INTO public.climat_lieux_vente (cle, pays, ville, chez) VALUES
  ('groupe_electrogene', 'republic', 'capitale', 'à la quincaillerie de Luthécia (Armurerie Martinon)'),
  ('groupe_electrogene', 'republic', 'ville_b',  'à la quincaillerie de Montrouge (Armurerie-Quincaillerie)'),
  ('groupe_electrogene', 'soviet',   'capitale', 'au garage de Novomirsk'),
  ('sels_rehydratation', 'republic', 'capitale', 'à l''usine pharmaceutique de Luthécia (Usine Pharmaceutique Impériale)'),
  ('sels_rehydratation', 'soviet',   'capitale', 'à l''usine pharmaceutique de Novomirsk (Pharmanov)')
ON CONFLICT DO NOTHING;

-- Consignes : orage et canicule réécrites ; les autres types inchangés.
CREATE OR REPLACE FUNCTION public.climat_consigne_interne(p_type text, p_pays text, p_ville text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_eau text; v_vente text; v_agences text;
BEGIN
  IF p_type = 'orage' THEN
    RETURN 'Pendant 6 heures, ordinateurs, box et caméras sont hors service : plus de surveillance, de trading à distance ni de piratage, '
      || 'et les chantiers sont à l''arrêt. Débranchez vos appareils électroniques. Pour garder le courant, équipez-vous d''un groupe électrogène'
      || coalesce(', en vente ' || public.climat_vente_interne('groupe_electrogene', p_pays, p_ville), '')
      || ', avec ' || public.aliments_param_interne('groupe_bidons', 5)::integer || ' bidons de carburant.';
  ELSIF p_type = 'crue' THEN
    RETURN 'Pendant 6 heures, les commerces et entrepôts non protégés de la zone inondable sont fermés et perdent '
      || public.aliments_param_interne('crue_perte_pct', 20)::integer || ' % de leurs stocks, et les chantiers sont à l''arrêt. '
      || 'Sécurisez vos propriétés : posez des sacs de sable'
      || coalesce(', en vente ' || public.climat_vente_interne('sac_de_sable', p_pays, p_ville), '')
      || ' (1 PA, valables pour une crue). Les lieux protégés restent ouverts. La gare et tous les déplacements restent libres.';
  ELSIF p_type = 'canicule' THEN
    SELECT 'Remplissez-la gratuitement à ' || nom || '.' INTO v_eau FROM public.climat_points_eau
     WHERE actif AND pays = p_pays AND ville = p_ville ORDER BY id LIMIT 1;
    IF v_eau IS NULL THEN
      v_vente := public.climat_vente_interne('bouteille_eau', p_pays, p_ville);
      v_eau := CASE WHEN v_vente IS NOT NULL THEN 'En vente ' || v_vente || '.' END;
    END IF;
    RETURN 'Toute personne présente en ville perd 3 PA, et la nourriture portée sur soi devient insalubre. '
      || 'Gardez une bouteille d''eau sur vous et ne transportez pas de nourriture. ' || coalesce(v_eau || ' ', '')
      || 'En cas de coup de chaleur, achetez des sels de réhydratation '
      || coalesce(public.climat_vente_interne('sels_rehydratation', p_pays, p_ville) || ' ou ', '') || 'dans une pharmacie.' /* climat_parades_v1 */;
  ELSIF p_type = 'brouillard' THEN
    SELECT string_agg('l''agence ' || regexp_replace(nom, '\s+Sécurité$', ''), ' ou ' ORDER BY cree_le) INTO v_agences
      FROM public.pnj_employeurs
     WHERE actif AND pays = p_pays
       AND ((employeur_id = 'grobras-securite' AND p_pays = 'republic' AND p_ville = 'capitale') OR vivier = 'vivier-securite-' || p_ville);
    RETURN 'Pendant 6 heures, les malfaiteurs agissent plus facilement et échappent plus souvent à la police, à la sécurité et aux caméras. '
      || 'Sécurisez vos propriétés : ne laissez rien de précieux sans surveillance, et pensez à engager un agent de sécurité dans une agence de sécurité'
      || coalesce(' : ' || v_agences, '') || '.';
  ELSIF p_type = 'blizzard' THEN
    RETURN 'Le blizzard fait perdre 3 PA à chacun, et la grippe menace ceux qui n''ont plus de forces. Reposez-vous pour garder vos PA : '
      || 'c''est la meilleure protection. Achetez de la graisse animale : de renne à Starovka, d''ours au marché de Krasnov, '
      || 'de castor chez la poissonnière de Novomirsk, ou dans une pharmacie tenue par un joueur.';
  END IF;
  RETURN NULL;
END $$;

-- Contrôle : toute parade citée (lieu de la consigne) doit être réellement en vente dans la ville citée ; et, pour chaque
-- événement actif d'un pays, chaque parade de sa consigne doit être en vente dans au moins un lieu du pays.
CREATE OR REPLACE FUNCTION public.climat_parades_verifier_interne()
RETURNS TABLE (pays text, cle text, probleme text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH vendeurs AS (
    SELECT b.pays, b.ville, k AS cle FROM public.climat_boutiques b, unnest(b.cles) k
    UNION SELECT pv.pays, pv.ville, 'sels_rehydratation' FROM public.pharmacies_points_vente pv
    UNION SELECT pe.pays, pe.ville, 'bouteille_eau' FROM public.climat_points_eau pe WHERE pe.actif
    -- Stations-service (commerce des véhicules) : bidons de carburant.
    UNION SELECT e.data->>'country', e.data->>'city', 'bidon_carburant' FROM public.entreprises e WHERE e.data->>'type' = 'station-service'),
  parades AS (SELECT * FROM (VALUES ('orage', 'groupe_electrogene'), ('orage', 'bidon_carburant'), ('crue', 'sac_de_sable'),
                                    ('canicule', 'bouteille_eau'), ('canicule', 'sels_rehydratation')) x(type, cle)),
  citees AS (SELECT DISTINCT c.pays, p.cle FROM public.climat_parametres c JOIN parades p ON p.type = c.type WHERE c.actif)
  SELECT lv.pays, lv.cle, 'lieu cité sans vente réelle : ' || lv.ville || ' (' || lv.chez || ')'
    FROM public.climat_lieux_vente lv
   WHERE NOT EXISTS (SELECT 1 FROM vendeurs v WHERE v.pays = lv.pays AND v.ville = lv.ville AND v.cle = lv.cle)
  UNION ALL
  SELECT ci.pays, ci.cle, 'parade citée en consigne, introuvable dans le pays'
    FROM citees ci WHERE NOT EXISTS (SELECT 1 FROM vendeurs v WHERE v.pays = ci.pays AND v.cle = ci.cle);
$$;

REVOKE ALL ON FUNCTION public.climat_parades_verifier_interne() FROM PUBLIC, anon, authenticated;

DO $v$ BEGIN
  IF EXISTS (SELECT 1 FROM public.climat_parades_verifier_interne()) THEN
    RAISE EXCEPTION 'parade sans lieu de vente : %', (SELECT string_agg(pays || '/' || cle || ' : ' || probleme, ' ; ') FROM public.climat_parades_verifier_interne());
  END IF;
END $v$;

COMMIT;
