-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261027192040.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration, en deux temps -- registre Supabase
-- 20261027191923 (inventaire_achats_catalogue : tables et catalogue) et 20261027192040 (fonctions).
-- Eprouvee au role authenticated : gilet, poison, faux modele et faux cout refuses, arme au comptoir
-- (et rupture), commerce direct refuse, arme du marche noir deposee avec la version de la ville.
-- ============================================================================
-- INVENTAIRE, LOT 1 : LES ACHATS DEPOSENT L'OBJET PAR LE SERVEUR (27 octobre 2026)
-- ============================================================================
-- Chantier « inventaire » (decision de Fred du 27/10/2026 : « Oui, maintenant »). Le navigateur
-- pouvait reecrire tout son inventaire (inventaire_sauver_revision accepte n'importe quel contenu) :
-- un joueur pouvait se donner armes, explosifs, poisons. Premiere etape : chaque facon de recevoir
-- un objet doit avoir son passage serveur. Ce lot :
--   * inventaire_deposer_interne : le depot serveur unique (empilement par stackKey, plafond de
--     100 sauf reception automatique) ;
--   * objets_modeles : le catalogue des objets que le serveur sait fabriquer (armes par pays et
--     par ville, poisons, gilet, relique), extrait de data.js / plateau-actions-illegales-rumeurs.js ;
--   * objet_acheter : achat simple a un ordre declare (gilet, relique, poisons) ;
--   * arme_acheter : achat legal d'une arme a l'armurerie (vente, stock, caisse, puis depot) ;
--     crime_acheter_arme_noire depose aussi l'arme achetee au marche noir ;
--   * commerce_vendre_produit refuse l'ordre choisir_arme en direct (l'arme ne serait pas deposee).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.objets_modeles (id text PRIMARY KEY, objet jsonb NOT NULL);
ALTER TABLE public.objets_modeles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.objets_modeles FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.objets_achetables (
  ordre  text NOT NULL,
  modele text NOT NULL REFERENCES public.objets_modeles(id),
  PRIMARY KEY (ordre, modele)
);
ALTER TABLE public.objets_achetables ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.objets_achetables FROM anon, authenticated;

INSERT INTO public.objets_modeles (id, objet) VALUES
  ('arme:republic:couteau', '{"type": "arme", "sousType": "blanche", "name": "Couteau de poche", "icon": "ti-tools-kitchen-2", "desc": "Légal pour la chasse. Roger ne demande pas à qui.", "bonus": {"stat": "VOL", "val": 5}, "imageUrl": "images/arme-couteau-republic.webp"}'::jsonb),
  ('arme:republic:revolver', '{"type": "arme", "sousType": "poing", "name": "Revolver .38", "icon": "ti-crosshair", "desc": "Fiable, discret, classique. Trois balles suffisent généralement.", "bonus": {"stat": "PER", "val": 8}, "imageUrl": "images/arme-fusil-republic.webp"}'::jsonb),
  ('arme:republic:carabine_chasse', '{"type": "arme", "sousType": "carabine", "name": "Carabine de chasse", "icon": "ti-target-arrow", "desc": "Pour le gibier. Gros gibier.", "bonus": {"stat": "PER", "val": 15}, "imageUrl": "images/arme-revolver-republic.webp"}'::jsonb),
  ('arme:narco:machette', '{"type": "arme", "sousType": "blanche", "name": "Machette", "icon": "ti-tools-kitchen-2", "desc": "L''outil universel. Multi-usages.", "bonus": {"stat": "VOL", "val": 5}, "imageUrl": "images/arme-machette-narco.png"}'::jsonb),
  ('arme:narco:desert_eagle', '{"type": "arme", "sousType": "poing", "name": "Desert Eagle", "icon": "ti-crosshair", "desc": "El Don lui-même en possède trois.", "bonus": {"stat": "PER", "val": 10}, "imageUrl": "images/arme-deserteagle-narco.png"}'::jsonb),
  ('arme:narco:ak47', '{"type": "arme", "sousType": "carabine", "name": "AK-47", "icon": "ti-target-arrow", "desc": "Origine : inconnue. État : parfait.", "bonus": {"stat": "PER", "val": 18}, "imageUrl": "images/arme-ak47-narco.png"}'::jsonb),
  ('arme:soviet:baionnette', '{"type": "arme", "sousType": "blanche", "name": "Baïonnette", "icon": "ti-tools-kitchen-2", "desc": "Propriété du Peuple. Empruntée indéfiniment.", "bonus": {"stat": "VOL", "val": 5}, "imageUrl": "images/arme-baionnette-soviet.png"}'::jsonb),
  ('arme:soviet:makarov', '{"type": "arme", "sousType": "poing", "name": "Makarov", "icon": "ti-crosshair", "desc": "Standard réglementaire. Camarade Kalachnikov détourne le regard.", "bonus": {"stat": "PER", "val": 8}, "imageUrl": "images/arme-makarov-soviet.png"}'::jsonb),
  ('arme:soviet:kalachnikov', '{"type": "arme", "sousType": "carabine", "name": "Kalachnikov", "icon": "ti-target-arrow", "desc": "Pour la défense de la Patrie. Usage personnel toléré.", "bonus": {"stat": "PER", "val": 16}, "imageUrl": "images/arme-kalachnikov-soviet.png"}'::jsonb),
  ('arme:khalija:jambiya', '{"type": "arme", "sousType": "blanche", "name": "Jambiya", "icon": "ti-tools-kitchen-2", "desc": "Lame recourbée, tradition millénaire. Hassan l''a aiguisée ce matin.", "bonus": {"stat": "VOL", "val": 6}, "imageUrl": "images/arme-jambiya-khalija.png"}'::jsonb),
  ('arme:khalija:pistolet_dore', '{"type": "arme", "sousType": "poing", "name": "Pistolet doré", "icon": "ti-crosshair", "desc": "Serti de nacre. L''élégance n''exclut pas l''efficacité.", "bonus": {"stat": "PER", "val": 9}, "imageUrl": "images/arme-pistolet-khalija.png"}'::jsonb),
  ('arme:khalija:carabine_precision', '{"type": "arme", "sousType": "carabine", "name": "Carabine de précision", "icon": "ti-target-arrow", "desc": "Pour la chasse au faucon. Très grands faucons.", "bonus": {"stat": "PER", "val": 17}, "imageUrl": "images/arme-fusil-khalija.png"}'::jsonb),
  ('arme:republic:couteau:ville_a', '{"type": "arme", "sousType": "blanche", "name": "Couteau de plongée", "icon": "ti-tools-kitchen-2", "desc": "Lame inoxydable, dents de scie pour cordages et filets. Indispensable pour la chasse sous-marine.", "bonus": {"stat": "VOL", "val": 5}, "imageUrl": "images/armurerie-port-sainte-marie-couteau-plongee.webp"}'::jsonb),
  ('arme:republic:revolver:ville_a', '{"type": "arme", "sousType": "poing", "name": "Fusil sous-marin", "icon": "ti-crosshair", "desc": "Harpon professionnel à sandow, moulinet grande capacité. Idéal pour la chasse sous-marine.", "bonus": {"stat": "PER", "val": 8}, "imageUrl": "images/armurerie-port-sainte-marie-fusil-harpon.webp"}'::jsonb),
  ('arme:republic:carabine_chasse:ville_a', '{"type": "arme", "sousType": "carabine", "name": "Carabine de chasse", "icon": "ti-target-arrow", "desc": "Modèle Saint-Marian, mécanisme à verrou, crosse en bois massif. Idéale pour la chasse côtière.", "bonus": {"stat": "PER", "val": 15}, "imageUrl": "images/armurerie-port-sainte-marie-carabine.webp"}'::jsonb),
  ('poison:parapluie', '{"type": "poison", "name": "Parapluie républien", "icon": "ti-umbrella", "poisonType": "parapluie", "legal": false, "usageUnique": true, "desc": "Un accessoire élégant. Discret. La pointe contient... quelque chose.", "imageUrl": "images/parapluie-republicain.webp"}'::jsonb),
  ('poison:ghb', '{"type": "poison", "name": "GHB de contrebande", "icon": "ti-flask", "poisonType": "ghb", "legal": false, "usageUnique": true, "desc": "Un flacon transparent. Inodore, incolore. À manier avec précaution.", "imageUrl": "images/ghb-narco.jpg"}'::jsonb),
  ('poison:polonium', '{"type": "poison", "name": "Fiole de Polonium", "icon": "ti-radioactive", "poisonType": "polonium", "legal": false, "usageUnique": true, "desc": "Un petit contenant blindé. Ne pas ouvrir sans combinaison.", "imageUrl": "images/polonium-sovarka.webp"}'::jsonb),
  ('poison:vipere', '{"type": "poison", "name": "Vipère des sables", "icon": "ti-bug", "poisonType": "vipere", "legal": false, "usageUnique": true, "desc": "Une petite boîte percée. On entend un léger sifflement.", "imageUrl": "images/vipere-des-sables-khalija.webp"}'::jsonb),
  ('gilet', '{"type": "protection", "name": "Gilet pare-balles", "icon": "ti-shield-check", "legal": true, "desc": "Protection physique. Enregistré dans le registre.", "imageUrl": "images/arme-gilet-republic.webp"}'::jsonb),
  ('relique_loukoum', '{"type": "relique", "name": "Relique du Loukoum Sacré", "icon": "ti-star", "legal": true, "effet": "ip+10", "desc": "Accès facilité aux zones réservées d''Al-Khalija."}'::jsonb)
ON CONFLICT (id) DO UPDATE SET objet = EXCLUDED.objet;

INSERT INTO public.objets_achetables (ordre, modele) VALUES
  ('acheter_gilet', 'gilet'), ('acheter_relique', 'relique_loukoum'),
  ('acheter_parapluie', 'poison:parapluie'), ('acheter_ghb', 'poison:ghb'),
  ('acheter_polonium', 'poison:polonium'), ('acheter_vipere', 'poison:vipere')
ON CONFLICT DO NOTHING;
-- Le parapluie n'avait aucun cout declare : l'ecran preleve son prix (400) a part.
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('acheter_parapluie', 0, 400) ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.inventaire_deposer_interne(p_nom text, p_objet jsonb, p_automatique boolean DEFAULT false)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_inv jsonb; v_place integer; v_q integer; v_cle text; v_obj jsonb := p_objet;
BEGIN
  IF p_objet IS NULL OR jsonb_typeof(p_objet) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide'); END IF;
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv
    FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_place := CASE WHEN p_automatique THEN 1000000 ELSE public.inventaire_place_restante(v_inv) END;
  v_cle := nullif(p_objet ->> 'stackKey', '');
  IF coalesce((p_objet ->> 'stackable')::boolean, false) AND v_cle IS NOT NULL THEN
    v_q := least(greatest(1, coalesce((p_objet ->> 'qty')::numeric, 1)::integer), v_place);
    IF v_q <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e WHERE coalesce((e ->> 'stackable')::boolean, false) AND e ->> 'stackKey' = v_cle) THEN
      SELECT jsonb_agg(CASE WHEN coalesce((e ->> 'stackable')::boolean, false) AND e ->> 'stackKey' = v_cle
                       THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e ->> 'qty')::numeric, 1) + v_q)) ELSE e END ORDER BY o)
        INTO v_inv FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o);
    ELSE
      v_inv := v_inv || jsonb_build_array(p_objet || jsonb_build_object('qty', v_q));
    END IF;
  ELSE
    v_q := greatest(1, coalesce((p_objet ->> 'encombrement')::numeric, 1)::integer);
    IF v_place < v_q THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
    IF coalesce(p_objet ->> 'id', '') = '' THEN
      v_obj := p_objet || jsonb_build_object('id', 'obj-' || replace(gen_random_uuid()::text, '-', ''));
    END IF;
    v_inv := v_inv || jsonb_build_array(v_obj);
    v_q := 1;
  END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_nom;
  RETURN jsonb_build_object('ok', true, 'qte', v_q)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_nom);
END; $function$;

CREATE OR REPLACE FUNCTION public.objet_acheter(p_ordre text, p_modele text, p_pa integer, p_cost integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_objet jsonb; v_paie jsonb; v_dep jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT m.objet INTO v_objet FROM public.objets_achetables a JOIN public.objets_modeles m ON m.id = a.modele
   WHERE a.ordre = p_ordre AND a.modele = p_modele;
  IF v_objet IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_non_vendu_ici'); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = v_moi) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(v_moi, p_ordre, p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_dep := public.inventaire_deposer_interne(v_moi, v_objet);
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'objet_acheter: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'objet', v_objet ->> 'name', 'paie', v_paie) || (v_dep - 'ok' - 'qte')
    || jsonb_build_object('pa', v_paie -> 'pa', 'arg', v_paie -> 'arg', 'liquide', v_paie -> 'liquide');
END; $function$;

-- Le modele d'une arme vendue par une armurerie : version de la ville si elle existe, sinon du pays.
CREATE OR REPLACE FUNCTION public.arme_modele_interne(p_entreprise text, p_arme text, p_acteur text)
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ WITH e AS (SELECT coalesce(en.data ->> 'country', (SELECT country FROM public.personnages_donnees WHERE name = p_acteur), 'republic') AS pays,
                        coalesce(en.data ->> 'city', (SELECT current_city FROM public.personnages_donnees WHERE name = p_acteur)) AS ville
                   FROM public.entreprises en WHERE en.id = p_entreprise)
      SELECT coalesce((SELECT objet FROM public.objets_modeles, e WHERE id = 'arme:' || e.pays || ':' || p_arme || ':' || e.ville),
                      (SELECT objet FROM public.objets_modeles, e WHERE id = 'arme:' || e.pays || ':' || p_arme)) $$;

CREATE OR REPLACE FUNCTION public.arme_acheter(p_entreprise text, p_arme text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_objet jsonb; v_r jsonb; v_dep jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_objet := public.arme_modele_interne(p_entreprise, p_arme, v_moi);
  IF v_objet IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_non_propose'); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = v_moi) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_r := public.commerce_vendre_produit_interne(v_moi, p_entreprise, jsonb_build_array(jsonb_build_object('produit', p_arme, 'qte', 1)),
           'comptoir', 'choisir_arme', 1, 0, NULL, NULL);
  IF coalesce((v_r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;
  v_dep := public.inventaire_deposer_interne(v_moi, v_objet || jsonb_build_object('legal', true));
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'arme_acheter: depot refuse %', v_dep; END IF;
  RETURN v_r || (v_dep - 'ok' - 'qte') || jsonb_build_object('objet', v_objet ->> 'name');
END; $function$;

-- Le marche noir depose aussi l'arme achetee.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.crime_acheter_arme_noire(text,text,boolean)'::regprocedure);
  IF position('arme_modele_interne' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'  IF coalesce((v_r ->> ''ok'')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;\n  PERFORM public.crime_tracer_interne(v_moi, ''achat_arme_illegal'', NULL);',
      E'  IF coalesce((v_r ->> ''ok'')::boolean, false) IS NOT TRUE THEN RETURN v_r; END IF;\n'
      || E'  -- L''arme est deposee par le serveur (27/10/2026, chantier inventaire).\n'
      || E'  v_r := v_r || (public.inventaire_deposer_interne(v_moi, coalesce(public.arme_modele_interne(p_entreprise, p_arme, v_moi), ''{}''::jsonb)\n'
      || E'           || jsonb_build_object(''legal'', false), true) - ''ok'' - ''qte'');\n'
      || E'  PERFORM public.crime_tracer_interne(v_moi, ''achat_arme_illegal'', NULL);');
    IF position('arme_modele_interne' IN v_def) = 0 THEN RAISE EXCEPTION 'crime_acheter_arme_noire : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
  v_def := pg_get_functiondef('public.commerce_vendre_produit(text,text,jsonb,text,text,integer,integer,text)'::regprocedure);
  IF position('achat_arme_par_le_serveur' IN v_def) = 0 THEN
    v_def := replace(v_def,
      E'  RETURN public.commerce_vendre_produit_interne(',
      E'  -- 27/10/2026 : une arme achetee au comptoir est deposee par arme_acheter.\n'
      || E'  IF p_ordre = ''choisir_arme'' THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''achat_arme_par_le_serveur''); END IF;\n'
      || E'  RETURN public.commerce_vendre_produit_interne(');
    IF position('achat_arme_par_le_serveur' IN v_def) = 0 THEN RAISE EXCEPTION 'commerce_vendre_produit : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;

REVOKE ALL ON FUNCTION public.inventaire_deposer_interne(text, jsonb, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.arme_modele_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.objet_acheter(text, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.objet_acheter(text, text, integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.arme_acheter(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.arme_acheter(text, text) TO authenticated;
