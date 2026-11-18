-- MALADIES, PÉREMPTION ET CLIMAT — LOT 2c : plats cuisinés avec un ingrédient avarié, furet renifleur (GAME-DESIGN-MALADIES-CLIMAT.md § 3).
-- • Plats : quand un commerce produit en consommant des unités avariées passées inaperçues à la réception (`matieresAvariees`),
--   les portions produites par ce même geste sont « contaminées » (`portionsContaminees`, invisible). Une portion contaminée
--   vendue donne 20 % d'intoxication à qui la mange (paramètre `plat_avarie` de l'intoxication) : tirage à la consommation
--   (sur place, ou objet emporté marqué `contamine` et tiré quand on le mange) ; dans le moteur historique (tournées, dîners,
--   service d'étage, comptoir), le tirage se fait pour l'acheteur au moment du service.
-- • Furet renifleur : vendu seulement chez Chasse et Pêche (Port-Sainte-Marie, Starovka), deux par boutique et par semaine
--   (rare) ; objet-animal permanent (vente, don, vol, héritage par l'inventaire) ; « Faire renifler un aliment » (1 PA) :
--   éternue si l'aliment est avarié, ronronne s'il est sain ; meurt au 11e aliment avarié reniflé.
-- Raccords à ancre unique, idempotents ; contrôle structurel final. Aucun fichier du goulag.
BEGIN;

INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('prix_furet', 250), ('furets_par_semaine', 2), ('furet_vies', 10)
ON CONFLICT (cle) DO NOTHING;

-- ── Contamination à la production (déclencheur sur les commerces) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.aliments_contamination_production()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m text; v_av numeric; v_baisse numeric; v_n numeric; v_utilises numeric := 0; k text; v_hausse numeric; v_cle text;
BEGIN
  IF NEW.data IS NOT DISTINCT FROM OLD.data OR jsonb_typeof(NEW.data->'matieresAvariees') IS DISTINCT FROM 'object' THEN RETURN NEW; END IF;
  FOR m, v_av IN SELECT key, value::numeric FROM jsonb_each_text(NEW.data->'matieresAvariees') WHERE value ~ '^[0-9.]+$' AND value::numeric > 0 LOOP
    v_baisse := coalesce((OLD.data->'stockMatieres'->>m)::numeric, 0) - coalesce((NEW.data->'stockMatieres'->>m)::numeric, 0);
    IF v_baisse > 0 THEN
      v_n := least(v_baisse, v_av);
      v_utilises := v_utilises + v_n;
      NEW.data := jsonb_set(NEW.data, ARRAY['matieresAvariees', m], to_jsonb(v_av - v_n));
    END IF;
  END LOOP;
  IF v_utilises > 0 THEN
    FOREACH k IN ARRAY ARRAY['stockProduits', 'stockReferences'] LOOP
      IF jsonb_typeof(NEW.data->k) = 'object' THEN
        FOR v_cle IN SELECT jsonb_object_keys(NEW.data->k) LOOP
          v_hausse := coalesce((NEW.data->k->>v_cle)::numeric, 0) - coalesce((OLD.data->k->>v_cle)::numeric, 0);
          IF v_hausse > 0 THEN
            NEW.data := jsonb_set(NEW.data, '{portionsContaminees}', coalesce(NEW.data->'portionsContaminees', '{}'::jsonb)
              || jsonb_build_object(v_cle, coalesce((NEW.data->'portionsContaminees'->>v_cle)::numeric, 0) + v_hausse), true);
          END IF;
        END LOOP;
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
EXCEPTION WHEN others THEN
  RETURN NEW;  -- une donnée de commerce mal formée ne bloque jamais une vente ou une production
END $$;
DROP TRIGGER IF EXISTS aliments_contamination_production ON public.entreprises;
CREATE TRIGGER aliments_contamination_production BEFORE UPDATE OF data ON public.entreprises
  FOR EACH ROW EXECUTE FUNCTION public.aliments_contamination_production();

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

-- Moteur historique : une portion contaminée servie = tirage pour l'acheteur.
SELECT pg_temp.rp_raccorder('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure,
  $a$  v_sp jsonb; v_ligne jsonb; v_id text; v_qte numeric; v_stock numeric; v_prix numeric;$a$,
  $b$  v_sp jsonb; v_ligne jsonb; v_id text; v_qte numeric; v_stock numeric; v_prix numeric; v_contamines numeric := 0; /* aliments_plats_decl */$b$,
  'aliments_plats_decl');
SELECT pg_temp.rp_raccorder('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure,
  $a$    v_sp := jsonb_set(v_sp, ARRAY[v_id], to_jsonb(v_stock - v_qte));$a$,
  $b$    v_sp := jsonb_set(v_sp, ARRAY[v_id], to_jsonb(v_stock - v_qte));
    IF coalesce((v_data->'portionsContaminees'->>v_id)::numeric, 0) > 0 THEN -- aliments_plats_v1
      v_contamines := v_contamines + least(v_qte, (v_data->'portionsContaminees'->>v_id)::numeric);
      v_data := jsonb_set(v_data, ARRAY['portionsContaminees', v_id], to_jsonb(greatest(0, (v_data->'portionsContaminees'->>v_id)::numeric - v_qte)));
    END IF;$b$,
  'aliments_plats_v1');
SELECT pg_temp.rp_raccorder('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure,
  $a$  v_data := jsonb_set(v_data, '{stockProduits}', v_sp, true);$a$,
  $b$  v_data := jsonb_set(v_data, '{stockProduits}', v_sp, true);
  IF v_contamines > 0 THEN -- aliments_plats_tirage
    PERFORM public.maladie_tirer_interne(regexp_replace(p_acteur, '^pj:', ''), 'intoxication', public.maladie_risque_interne('intoxication', 'plat_avarie'), 'plat_avarie');
  END IF;$b$,
  'aliments_plats_tirage');

-- Fonds de commerce PJ : l'objet emporté porte la marque invisible `contamine`.
SELECT pg_temp.rp_raccorder('public.acheter_produit_commerce_interne(text,text,text,text,integer)'::regprocedure,
  $a$  v_enseigne    text;$a$,
  $b$  v_enseigne    text;
  v_contamine   boolean := false; /* aliments_plats_decl */$b$,
  'aliments_plats_decl');
SELECT pg_temp.rp_raccorder('public.acheter_produit_commerce_interne(text,text,text,text,integer)'::regprocedure,
  $a$  v_objet := jsonb_strip_nulls(jsonb_build_object(
    'type',         p_reference_id,$a$,
  $b$  IF coalesce((v_fonds->'portionsContaminees'->>p_reference_id)::numeric, 0) > 0 THEN -- aliments_plats_v1
    v_contamine := true;
    v_fonds := jsonb_set(v_fonds, ARRAY['portionsContaminees', p_reference_id],
      to_jsonb(greatest(0, (v_fonds->'portionsContaminees'->>p_reference_id)::numeric - v_qte)));
  END IF;
  v_objet := jsonb_strip_nulls(jsonb_build_object(
    'contamine',    CASE WHEN v_contamine THEN true END,
    'type',         p_reference_id,$b$,
  'aliments_plats_v1');

-- Consommation sur place (fonds PJ) : la portion contaminée est tirée tout de suite.
SELECT pg_temp.rp_raccorder('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure,
  $a$v_hp integer; v_moral integer; v_nom text;$a$,
  $b$v_hp integer; v_moral integer; v_nom text; v_contam boolean; /* aliments_plats_decl */$b$,
  'aliments_plats_decl');
SELECT pg_temp.rp_raccorder('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure,
  $a$ DELETE FROM public.objets_recus WHERE id=v_id AND destinataire=regexp_replace(p_acheteur,'^pj:','');$a$,
  $b$ SELECT coalesce(((CASE WHEN jsonb_typeof(data)='string' THEN (data #>> '{}')::jsonb ELSE data END)->>'contamine')::boolean, false)
   INTO v_contam FROM public.objets_recus WHERE id=v_id; -- aliments_plats_v1
 DELETE FROM public.objets_recus WHERE id=v_id AND destinataire=regexp_replace(p_acheteur,'^pj:','');$b$,
  'aliments_plats_v1');
SELECT pg_temp.rp_raccorder('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure,
  $a$ IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable: annulation transaction'; END IF;$a$,
  $b$ IF NOT FOUND THEN RAISE EXCEPTION 'Personnage introuvable: annulation transaction'; END IF;
 IF v_contam THEN PERFORM public.maladie_tirer_interne(v_nom, 'intoxication', public.maladie_risque_interne('intoxication', 'plat_avarie'), 'plat_avarie'); END IF; -- aliments_plats_tirage$b$,
  'aliments_plats_tirage');

-- Aliment emporté contaminé, mangé plus tard : 20 % (s'il est aussi périmé, c'est le risque de l'avarié, 50 %, qui joue).
SELECT pg_temp.rp_raccorder('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$'maladie',CASE WHEN NOT v_frais THEN public.maladie_tirer_interne(p_acteur,'intoxication',public.maladie_risque_interne('intoxication','aliment_avarie'),'aliment_avarie') END);$a$,
  $b$'maladie',CASE WHEN NOT v_frais THEN public.maladie_tirer_interne(p_acteur,'intoxication',public.maladie_risque_interne('intoxication','aliment_avarie'),'aliment_avarie')
       WHEN coalesce((v_item->>'contamine')::boolean,false) THEN public.maladie_tirer_interne(p_acteur,'intoxication',public.maladie_risque_interne('intoxication','plat_avarie'),'plat_avarie') END); -- aliments_plats_tirage$b$,
  'aliments_plats_tirage');

-- ── Furet renifleur ──────────────────────────────────────────────────────────────────────────────
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'acheter_furet', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'acheter_furet' AND pa = 0 AND cost = 0);
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'furet_renifler', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'furet_renifler' AND pa = 1 AND cost = 0);

CREATE TABLE IF NOT EXISTS public.furets_boutiques (
  id text PRIMARY KEY, pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL
);
ALTER TABLE public.furets_boutiques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.furets_boutiques FROM anon, authenticated;
INSERT INTO public.furets_boutiques (id, pays, ville, batiment, piece) VALUES
  ('chasse-peche-psm', 'republic', 'ville_a', 'chasse-peche-psm', 'boutique'),
  ('chasse-peche-starovka', 'soviet', 'ville_a', 'armurerie', 'magasin')
ON CONFLICT (id) DO NOTHING;
CREATE TABLE IF NOT EXISTS public.furets_ventes (
  boutique text NOT NULL REFERENCES public.furets_boutiques(id), semaine date NOT NULL, vendus integer NOT NULL DEFAULT 0,
  PRIMARY KEY (boutique, semaine)
);
ALTER TABLE public.furets_ventes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.furets_ventes FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.furet_boutique_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); b public.furets_boutiques; v_sem date := date_trunc('week', public.aliments_jour_interne())::date;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT f.* INTO b FROM public.furets_boutiques f JOIN public.personnages_donnees d ON d.name = a
   WHERE d.country = f.pays AND d.current_city = f.ville AND d.current_building = f.batiment AND d.current_room = f.piece;
  IF b.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_boutique'); END IF;
  RETURN jsonb_build_object('ok', true, 'prix', public.aliments_param_interne('prix_furet', 250),
    'restant', greatest(0, public.aliments_param_interne('furets_par_semaine', 2)::integer
      - coalesce((SELECT vendus FROM public.furets_ventes WHERE boutique = b.id AND semaine = v_sem), 0)));
END $$;

CREATE OR REPLACE FUNCTION public.furet_acheter(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; b public.furets_boutiques; v_prix numeric; v_fonds numeric;
        v_debit numeric; v_dep jsonb; v_sem date := date_trunc('week', public.aliments_jour_interne())::date; v_vendus integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'furet_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT f.* INTO b FROM public.furets_boutiques f JOIN public.personnages_donnees d ON d.name = a
   WHERE d.country = f.pays AND d.current_city = f.ville AND d.current_building = f.batiment AND d.current_room = f.piece;
  IF b.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_boutique'); END IF;
  INSERT INTO public.furets_ventes (boutique, semaine) VALUES (b.id, v_sem) ON CONFLICT DO NOTHING;
  SELECT vendus INTO v_vendus FROM public.furets_ventes WHERE boutique = b.id AND semaine = v_sem FOR UPDATE;
  IF v_vendus >= public.aliments_param_interne('furets_par_semaine', 2) THEN RETURN jsonb_build_object('ok', false, 'raison', 'plus_de_furet'); END IF;
  v_prix := public.aliments_param_interne('prix_furet', 250);
  SELECT coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires c WHERE c.personnage = d.name AND c.banque = 'nationale' ORDER BY id LIMIT 1), 0)
    INTO v_fonds FROM public.personnages_donnees d WHERE d.name = a;
  IF v_fonds < v_prix THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_prix); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = a) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(a, 'acheter_furet', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_debit := public.argent_debiter_interne(a, v_prix, 'liquide_puis_nationale');
  IF v_debit IS DISTINCT FROM v_prix THEN RAISE EXCEPTION 'furet_acheter: debit incomplet'; END IF;
  UPDATE public.furets_ventes SET vendus = vendus + 1 WHERE boutique = b.id AND semaine = v_sem;
  v_dep := public.inventaire_deposer_interne(a, jsonb_build_object('name', 'Furet renifleur', 'icon', 'ti-paw', 'type', 'furet',
    'stackable', false, 'legal', true, 'reniflesAvaries', 0, 'desc', 'Un furet au nez infaillible. Il éternue devant un aliment avarié.'));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'furet_acheter: depot refuse %', v_dep; END IF;
  v := jsonb_build_object('ok', true, 'prix', v_prix)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'liquide', liquide) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'furet_acheter', prm, v);
END $$;

-- Un aliment est-il avarié (ou contaminé) aux yeux du furet ?
CREATE OR REPLACE FUNCTION public.aliment_objet_avarie_interne(p_item jsonb)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_date numeric;
BEGIN
  IF public.aliment_perissable_interne(p_item->>'stackKey') THEN RETURN public.aliment_pile_avariee_interne(p_item); END IF;
  IF coalesce((p_item->>'contamine')::boolean, false) OR coalesce((p_item->>'avarie')::boolean, false) THEN RETURN true; END IF;
  BEGIN v_date := (p_item->>'dateAchat')::numeric; EXCEPTION WHEN others THEN v_date := NULL; END;
  IF v_date IS NULL THEN RETURN false; END IF;
  RETURN extract(epoch FROM now()) * 1000 - v_date > public.aliments_param_interne('peremption_jours', 10) * 86400000;
END $$;

CREATE OR REPLACE FUNCTION public.aliment_objet_comestible_interne(p_item jsonb)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT public.aliment_perissable_interne(p_item->>'stackKey') OR coalesce(p_item->>'familleProduitMarche', '') = 'aliment'
      OR (coalesce(p_item->>'generique_id', '') = 'encas-a-emporter' AND coalesce(p_item->>'recette_id', '') <> '');
$$;

CREATE OR REPLACE FUNCTION public.furet_renifler(p_requete uuid, p_index integer, p_signature jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('index', p_index); v jsonb; v_inv jsonb; v_pos integer;
        v_item jsonb; v_furet integer; v_avarie boolean; v_n integer; v_mort boolean := false;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'furet_renifler', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  SELECT (o - 1)::integer INTO v_furet FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o) WHERE e->>'type' = 'furet' ORDER BY o LIMIT 1;
  IF v_furet IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_furet'); END IF;
  v_pos := public.inventaire_localiser(v_inv, p_index, p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_absent'); END IF;
  v_item := v_inv -> v_pos;
  IF NOT public.aliment_objet_comestible_interne(v_item) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_aliment'); END IF;
  v := public.payer_ordre(a, 'furet_renifler', 1, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_avarie := public.aliment_objet_avarie_interne(v_item);
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = a;
  IF v_avarie THEN
    v_n := coalesce((v_inv -> v_furet ->> 'reniflesAvaries')::integer, 0) + 1;
    IF v_n > public.aliments_param_interne('furet_vies', 10) THEN
      v_mort := true;
      v_inv := v_inv - v_furet;
    ELSE
      v_inv := jsonb_set(v_inv, ARRAY[v_furet::text, 'reniflesAvaries'], to_jsonb(v_n));
    END IF;
    UPDATE public.personnages_donnees SET inventory = v_inv, updated_at = now() WHERE name = a;
  END IF;
  v := jsonb_build_object('ok', true, 'avarie', v_avarie, 'reaction', CASE WHEN v_avarie THEN 'eternue' ELSE 'ronronne' END, 'mort', v_mort, 'pa', v->'pa')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'furet_renifler', prm, v);
END $$;

REVOKE ALL ON FUNCTION public.furet_boutique_etat(), public.furet_acheter(uuid), public.furet_renifler(uuid, integer, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.furet_boutique_etat(), public.furet_acheter(uuid), public.furet_renifler(uuid, integer, jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.aliment_objet_avarie_interne(jsonb), public.aliments_contamination_production() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.aliment_objet_comestible_interne(jsonb) TO authenticated;

-- ── Contrôle structurel ──────────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF position('aliments_plats_v1' IN pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure)) = 0
     OR position('aliments_plats_tirage' IN pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure)) = 0
     OR position('aliments_plats_v1' IN pg_get_functiondef('public.acheter_produit_commerce_interne(text,text,text,text,integer)'::regprocedure)) = 0
     OR position('aliments_plats_tirage' IN pg_get_functiondef('public.consommer_sur_place_commerce(text,text,text,text)'::regprocedure)) = 0
     OR position('aliments_plats_tirage' IN pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure)) = 0
     OR NOT public.aliment_objet_avarie_interne('{"stackKey":"viande","recu":"2026-01-01"}')
     OR public.aliment_objet_avarie_interne(jsonb_build_object('stackKey', 'viande', 'recu', to_char(public.aliments_jour_interne(), 'YYYY-MM-DD')))
     OR NOT public.aliment_objet_avarie_interne('{"familleProduitMarche":"aliment","dateAchat":1,"contamine":true}')
  THEN RAISE EXCEPTION 'lot 2c : controle structurel en echec'; END IF;
END $$;

COMMIT;
