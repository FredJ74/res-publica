-- MALADIES — LOT 1, corrections demandées par Fred le 18/11/2026 au soir (GAME-DESIGN-MALADIES-CLIMAT.md § 11).
-- 1. Boissons : deux sous-articles explicites, « alcoolisée » et « non alcoolisée », posés à la main sur chaque recette de
--    catégorie boisson (jamais déduits de la matière « alcool »). Seules les boissons alcoolisées comptent un verre :
--    tournée (selon la boisson), consommation sur place, service d'étage, boisson des dîners d'affaires (le « verre offert »),
--    bouteille bue depuis l'inventaire (mini-bar, distillerie). Trinquer chez l'habitant reste toujours alcoolisé.
-- 2. Médicaments : la production journalière (stock journalier du MJ) est répartie entre les points de vente d'un même
--    pays selon leur part ; en Républia, 25 % au comptoir de l'usine de Luthécia et 25 % à chacun des trois entrepôts
--    logistiques, au plus fort reste. La recette d'une vente en entrepôt revient à la caisse de l'entrepôt.
-- Raccords à ancre unique, idempotents, contrôle structurel en fin de migration. Aucun fichier du goulag.
BEGIN;

-- ── 1. Étiquette des boissons ───────────────────────────────────────────────────────────────────
ALTER TABLE public.recettes_commerce ADD COLUMN IF NOT EXISTS boisson text;
ALTER TABLE public.recettes_commerce DROP CONSTRAINT IF EXISTS recettes_commerce_boisson_valeur;
ALTER TABLE public.recettes_commerce ADD CONSTRAINT recettes_commerce_boisson_valeur
  CHECK (boisson IS NULL OR boisson IN ('alcoolisee', 'non_alcoolisee'));

UPDATE public.recettes_commerce r SET boisson = v.boisson FROM (VALUES
  ('biere_pression', 'alcoolisee'), ('champagne_luthecia', 'alcoolisee'), ('cocktail_luthecia', 'alcoolisee'),
  ('grand_hotel_champagne_sovietique', 'alcoolisee'), ('grand_hotel_vodka_imperiale', 'alcoolisee'),
  ('samogon_distillerie', 'alcoolisee'), ('sever_vodka', 'alcoolisee'), ('slivovitz_distillerie', 'alcoolisee'),
  ('vin', 'alcoolisee'), ('vin_chaud_sovarka', 'alcoolisee'), ('vodka_distillerie', 'alcoolisee'),
  ('voyageurs_tarassoun', 'alcoolisee'), ('voyageurs_vodka', 'alcoolisee'),
  ('boisson_sans_alcool', 'non_alcoolisee'), ('cafe_boisson', 'non_alcoolisee'), ('chocolat_chaud_sovarka', 'non_alcoolisee'),
  ('jus_de_fruits', 'non_alcoolisee'), ('sever_the_samovar', 'non_alcoolisee'), ('the_chaud_sovarka', 'non_alcoolisee'),
  ('voyageurs_the_beurre', 'non_alcoolisee')
) AS v(id, boisson) WHERE r.id = v.id;

-- Toute boisson du catalogue porte son étiquette ; une recette future sans étiquette est refusée.
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.recettes_commerce WHERE categorie = 'boisson' AND boisson IS NULL) THEN
    RAISE EXCEPTION 'boissons sans etiquette : %', (SELECT string_agg(id, ', ') FROM public.recettes_commerce WHERE categorie = 'boisson' AND boisson IS NULL);
  END IF;
END $$;
ALTER TABLE public.recettes_commerce DROP CONSTRAINT IF EXISTS recettes_commerce_boisson_obligatoire;
ALTER TABLE public.recettes_commerce ADD CONSTRAINT recettes_commerce_boisson_obligatoire
  CHECK (categorie IS DISTINCT FROM 'boisson' OR boisson IS NOT NULL);

CREATE OR REPLACE FUNCTION public.boisson_alcoolisee_interne(p_recette text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT boisson = 'alcoolisee' FROM public.recettes_commerce WHERE id = p_recette), false);
$$;

-- Étiquette d'un objet d'inventaire : la sienne (bouteille du mini-bar), sinon celle de sa recette.
CREATE OR REPLACE FUNCTION public.boisson_objet_interne(p_item jsonb)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_item->>'boisson' IN ('alcoolisee', 'non_alcoolisee') THEN p_item->>'boisson'
              ELSE (SELECT boisson FROM public.recettes_commerce WHERE id = nullif(p_item->>'recette_id', '')) END;
$$;
REVOKE ALL ON FUNCTION public.boisson_alcoolisee_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.boisson_objet_interne(jsonb) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple', p_fn; END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Tournée : un verre par buveur seulement si la boisson commandée est alcoolisée.
SELECT pg_temp.rp_raccorder('public.tournee_cloturer_boire(text)'::regprocedure,
  $a$PERFORM public.maladie_verre_interne(x) FROM unnest(v_participants||ARRAY[v_moi]) x; -- maladies_alcool_v1$a$,
  $b$PERFORM public.maladie_verre_interne(x) FROM unnest(v_participants||ARRAY[v_moi]) x WHERE public.boisson_alcoolisee_interne(t.recette_id); -- maladies_alcool_v1 maladies_boissons_v1$b$,
  'maladies_boissons_v1');

-- Consommation sur place au comptoir.
SELECT pg_temp.rp_raccorder('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure,
  $a$ IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable: annulation transaction'; END IF;$a$,
  $b$ IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable: annulation transaction'; END IF;
 IF public.boisson_alcoolisee_interne(v_ref->>'recette_id') THEN PERFORM public.maladie_verre_interne(v_nom); END IF; -- maladies_boissons_v1$b$,
  'maladies_boissons_v1');

-- Service d'étage.
SELECT pg_temp.rp_raccorder('public.service_etage_commander(uuid,text)'::regprocedure,
  $a$  IF coalesce((v_eff->>'paDiffere')::integer, 0) > 0 THEN PERFORM public.pa_bonus_differe_crediter(moi, p_produit); END IF;$a$,
  $b$  IF coalesce((v_eff->>'paDiffere')::integer, 0) > 0 THEN PERFORM public.pa_bonus_differe_crediter(moi, p_produit); END IF;
  IF public.boisson_alcoolisee_interne(p_produit) THEN PERFORM public.maladie_verre_interne(moi); END IF; -- maladies_boissons_v1$b$,
  'maladies_boissons_v1');

-- Dîner d'affaires du restaurant de Luthécia : deux coupes de champagne, un verre par convive joueur.
SELECT pg_temp.rp_raccorder('public.restaurant_diner_servir(bigint)'::regprocedure,
  $a$    r:=jsonb_build_object('ok',true,'total',300,'repas',2,'champagnes',2,'pa',2,'articles',articles);$a$,
  $b$    IF public.boisson_alcoolisee_interne('champagne_luthecia') THEN -- maladies_boissons_v1
     PERFORM public.maladie_verre_interne(moi);
     IF NOT i.invite_pnj THEN PERFORM public.maladie_verre_interne(i.invite); END IF;
    END IF;
    r:=jsonb_build_object('ok',true,'total',300,'repas',2,'champagnes',2,'pa',2,'articles',articles);$b$,
  'maladies_boissons_v1');

-- Dîners des autres restaurants : la boisson du lieu (vin, champagne soviétique, tarassoun, bière).
SELECT pg_temp.rp_raccorder('public.diner_commerce_servir_interne(text,bigint)'::regprocedure,
  $a$    r:=jsonb_build_object('ok',true,'total',(cfg->>'prix')::integer,'repas',2,$a$,
  $b$    IF public.boisson_alcoolisee_interne(cfg->>'boisson') THEN -- maladies_boissons_v1
     PERFORM public.maladie_verre_interne(moi);
     IF NOT i.invite_pnj THEN PERFORM public.maladie_verre_interne(i.invite); END IF;
    END IF;
    r:=jsonb_build_object('ok',true,'total',(cfg->>'prix')::integer,'repas',2,$b$,
  'maladies_boissons_v1');

-- Inventaire : une boisson étiquetée se boit (sans effet sur les PA) ; alcoolisée, elle compte un verre.
SELECT pg_temp.rp_raccorder('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$v_ch text;v_digit integer;$a$, $b$v_ch text;v_digit integer;v_boisson text; /* maladies_boissons_decl */$b$,
  'maladies_boissons_decl');
SELECT pg_temp.rp_raccorder('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$ IF NOT (v_aliment OR coalesce(v_item->>'type','') IN ('medicament','explosif','poison','drogue')) THEN$a$,
  $b$ v_boisson:=CASE WHEN v_aliment THEN NULL ELSE public.boisson_objet_interne(v_item) END; -- maladies_boissons_gate
 IF NOT (v_aliment OR v_boisson IS NOT NULL OR coalesce(v_item->>'type','') IN ('medicament','explosif','poison','drogue')) THEN$b$,
  'maladies_boissons_gate');
SELECT pg_temp.rp_raccorder('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$ IF coalesce(v_item->>'type','')='drogue' AND coalesce(v_item->>'drogue','')='estadine' THEN$a$,
  $b$ IF v_boisson IS NOT NULL THEN -- maladies_boissons_effet
   IF v_boisson='alcoolisee' THEN PERFORM public.maladie_verre_interne(p_acteur); END IF;
   v_r:=v_r||jsonb_build_object('boisson',v_boisson);
 END IF;
 IF coalesce(v_item->>'type','')='drogue' AND coalesce(v_item->>'drogue','')='estadine' THEN$b$,
  'maladies_boissons_effet');

-- Bouteille du mini-bar de la Résidence impériale : étiquette explicite.
SELECT pg_temp.rp_raccorder('public.residence_acte(uuid,text,text)'::regprocedure,
  $a$'stackKey', 'vodka', 'qty', 1, 'legal', true,$a$,
  $b$'stackKey', 'vodka', 'qty', 1, 'legal', true, 'boisson', 'alcoolisee',$b$,
  '''boisson'', ''alcoolisee''');

-- ── 2. Répartition de la production de médicaments ─────────────────────────────────────────────
ALTER TABLE public.pharmacies_points_vente ADD COLUMN IF NOT EXISTS part numeric NOT NULL DEFAULT 1 CHECK (part >= 0 AND part <= 1);
ALTER TABLE public.pharmacies_points_vente ADD COLUMN IF NOT EXISTS caisse_institution text;
UPDATE public.pharmacies_points_vente SET part = 0.25 WHERE id = 'usine-pharma-luthecia';
INSERT INTO public.pharmacies_points_vente (id, pays, ville, batiment, piece, caisse_entreprise, part, caisse_institution) VALUES
  ('entrepot-luthecia',  'republic', 'capitale', 'entrepot-logistique-luthecia',  'salle_ventes', NULL, 0.25, 'republic_entrepot_capitale'),
  ('entrepot-psm',       'republic', 'ville_a',  'entrepot-logistique-psm',       'salle_ventes', NULL, 0.25, 'republic_entrepot_ville_a'),
  ('entrepot-montrouge', 'republic', 'ville_b',  'entrepot-logistique-montrouge', 'salle_ventes', NULL, 0.25, 'republic_entrepot_ville_b')
ON CONFLICT (id) DO UPDATE SET part = EXCLUDED.part, caisse_institution = EXCLUDED.caisse_institution;

-- Part du stock journalier d'un point de vente : quota de son pays, au plus fort reste (aucune unité perdue à l'arrondi).
CREATE OR REPLACE FUNCTION public.pharmacie_stock_point_interne(p_point text, p_cle_maladie text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH s AS (SELECT stock_journalier::numeric AS n FROM public.maladies_parametres WHERE cle = p_cle_maladie),
       g AS (SELECT pv.id, floor(s.n * pv.part) AS base, s.n * pv.part - floor(s.n * pv.part) AS reste
               FROM public.pharmacies_points_vente pv, s
              WHERE pv.pays = (SELECT pays FROM public.pharmacies_points_vente WHERE id = p_point) AND pv.part > 0),
       t AS (SELECT round(sum(pv.part) * (SELECT n FROM s)) AS total FROM public.pharmacies_points_vente pv
              WHERE pv.pays = (SELECT pays FROM public.pharmacies_points_vente WHERE id = p_point) AND pv.part > 0),
       r AS (SELECT id, base, row_number() OVER (ORDER BY reste DESC, id) AS rang FROM g)
  SELECT coalesce((SELECT (base + CASE WHEN rang <= (SELECT total FROM t) - (SELECT sum(base) FROM g) THEN 1 ELSE 0 END)::integer
                     FROM r WHERE id = p_point), 0);
$$;
REVOKE ALL ON FUNCTION public.pharmacie_stock_point_interne(text, text) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_raccorder('public.pharmacie_etat()'::regprocedure,
  $a$'restant', greatest(0, m.stock_journalier - coalesce(s.vendus, 0)))$a$,
  $b$'restant', greatest(0, public.pharmacie_stock_point_interne(pv.id, m.cle) - coalesce(s.vendus, 0))) /* maladies_repartition_v1 */$b$,
  'maladies_repartition_v1');

DO $$
DECLARE f regprocedure := 'public.pharmacie_acheter_interne(text,text,integer)'::regprocedure; d text;
BEGIN
  d := pg_get_functiondef(f);
  IF position('maladies_repartition_v1' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, 'm.stock_journalier', ''))) / length('m.stock_journalier') <> 4 THEN
    RAISE EXCEPTION 'pharmacie_acheter_interne : 4 lectures du stock attendues'; END IF;
  d := replace(d, 'm.stock_journalier', 'v_stock_point');
  d := replace(d, 'v_jour date := (now() AT TIME ZONE ''Europe/Paris'')::date;',
                  'v_jour date := (now() AT TIME ZONE ''Europe/Paris'')::date; v_stock_point integer; v_rep jsonb; v_flag text; /* maladies_repartition_v1 */');
  d := replace(d, '  INSERT INTO public.pharmacies_ventes (point, jour, medicament, vendus) VALUES (pv.id, v_jour, p_medicament, 0)',
                  '  v_stock_point := public.pharmacie_stock_point_interne(pv.id, m.cle);
  INSERT INTO public.pharmacies_ventes (point, jour, medicament, vendus) VALUES (pv.id, v_jour, p_medicament, 0)');
  d := replace(d, '  v_dep := public.inventaire_deposer_interne(p_acteur,',
                  '  IF pv.caisse_institution IS NOT NULL THEN
    v_flag := current_setting(''rp.caisse_interne'', true);
    PERFORM set_config(''rp.caisse_interne'', ''on'', true);
    v_rep := public.caisse_institution_mouvement(pv.caisse_institution, v_total, true);
    PERFORM set_config(''rp.caisse_interne'', coalesce(v_flag, ''''), true);
    IF (v_rep->>''ok'')::boolean IS NOT TRUE THEN RAISE EXCEPTION ''pharmacie_acheter: caisse refusee %'', v_rep; END IF;
  END IF;
  v_dep := public.inventaire_deposer_interne(p_acteur,');
  IF position('v_stock_point := public.pharmacie_stock_point_interne' IN d) = 0 OR position('caisse_institution_mouvement' IN d) = 0
     OR position('/* maladies_repartition_v1 */' IN d) = 0 THEN RAISE EXCEPTION 'pharmacie_acheter_interne : ancrage'; END IF;
  EXECUTE d;
END $$;

-- ── Contrôle structurel ──────────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF position('maladies_boissons_v1' IN pg_get_functiondef('public.tournee_cloturer_boire(text)'::regprocedure)) = 0
     OR position('maladies_boissons_v1' IN pg_get_functiondef('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure)) = 0
     OR position('maladies_boissons_v1' IN pg_get_functiondef('public.service_etage_commander(uuid,text)'::regprocedure)) = 0
     OR position('maladies_boissons_v1' IN pg_get_functiondef('public.restaurant_diner_servir(bigint)'::regprocedure)) = 0
     OR position('maladies_boissons_v1' IN pg_get_functiondef('public.diner_commerce_servir_interne(text,bigint)'::regprocedure)) = 0
     OR position('maladies_boissons_effet' IN pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure)) = 0
     OR position('maladies_repartition_v1' IN pg_get_functiondef('public.pharmacie_etat()'::regprocedure)) = 0
     OR position('maladies_repartition_v1' IN pg_get_functiondef('public.pharmacie_acheter_interne(text,text,integer)'::regprocedure)) = 0
     OR (SELECT sum(public.pharmacie_stock_point_interne(id, 'grippe')) FROM public.pharmacies_points_vente WHERE pays = 'republic')
        IS DISTINCT FROM (SELECT stock_journalier FROM public.maladies_parametres WHERE cle = 'grippe')::numeric
  THEN RAISE EXCEPTION 'maladies lot 1 corrections : controle structurel en echec'; END IF;
END $$;

COMMIT;
