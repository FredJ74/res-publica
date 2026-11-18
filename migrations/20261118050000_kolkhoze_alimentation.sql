-- KOLKHOZE ET ALIMENTATION (décisions de Fred, 18/11/2026 ; GAME-DESIGN-NOVOMIRSK.md « Décisions du 18/11/2026 », point 2) :
--  1. Toute viande et tous les laitages bruts (matières `viande` et `laitages`) se mangent : +1 PA au prochain
--     Dormir. Un seul repas brut compte entre deux Dormir (le suivant est refusé avant tout retrait).
--  2. Confiture d'airelles : +1 PA au prochain Dormir, cumulable avec un repas brut (une par nuit).
--  3. Magasin du kolkhoze : viande et lait de renne livrés comme matières viande et laitages, peau = textile,
--     bois de renne = bois ; bocal de graisse de renne : objet sans effet, non consommable.
--     (Correctif : peau et bois de renne n'étaient pas déposés en inventaire par la vente.)
-- Nuit de référence : pa_repos_le (dernier Dormir). Aucune donnée de joueur modifiée. Idempotente.
BEGIN;

CREATE TABLE IF NOT EXISTS public.repas_differes_nuits (
  nom text NOT NULL, cle text NOT NULL CHECK (cle IN ('repas_brut', 'confiture')), nuit text NOT NULL,
  pris_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (nom, cle));
ALTER TABLE public.repas_differes_nuits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.repas_differes_nuits FROM PUBLIC, anon, authenticated;

INSERT INTO public.pa_bonus_differes (source, montant) VALUES ('repas_brut', 1), ('confiture_airelles', 1)
ON CONFLICT (source) DO NOTHING;
INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'manger_matiere_brute', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'manger_matiere_brute');

-- Crédite un bonus différé une fois par nuit (clé) ; false si déjà pris depuis le dernier Dormir.
CREATE OR REPLACE FUNCTION public.repas_differe_crediter_interne(p_nom text, p_cle text, p_source text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_nuit text; v_m integer; v_b integer;
BEGIN
  SELECT coalesce(pa_repos_le::text, 'jamais') INTO v_nuit FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF EXISTS (SELECT 1 FROM public.repas_differes_nuits WHERE nom = p_nom AND cle = p_cle AND nuit = v_nuit) THEN RETURN NULL; END IF;
  INSERT INTO public.repas_differes_nuits (nom, cle, nuit) VALUES (p_nom, p_cle, v_nuit)
  ON CONFLICT (nom, cle) DO UPDATE SET nuit = excluded.nuit, pris_le = now();
  SELECT montant INTO v_m FROM public.pa_bonus_differes WHERE source = p_source;
  UPDATE public.personnages_donnees SET bonus_pa_differe = least(30, coalesce(bonus_pa_differe, 0) + coalesce(v_m, 1)), updated_at = now()
   WHERE name = p_nom RETURNING bonus_pa_differe INTO v_b;
  RETURN v_b;
END $function$;
REVOKE ALL ON FUNCTION public.repas_differe_crediter_interne(text, text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.repas_differe_deja_pris_interne(p_nom text, p_cle text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
  SELECT EXISTS (SELECT 1 FROM public.repas_differes_nuits r JOIN public.personnages_donnees p ON p.name = r.nom
                  WHERE r.nom = p_nom AND r.cle = p_cle AND r.nuit = coalesce(p.pa_repos_le::text, 'jamais'));
$function$;
REVOKE ALL ON FUNCTION public.repas_differe_deja_pris_interne(text, text) FROM PUBLIC, anon, authenticated;

-- 1. Manger une matière brute (viande, laitages) : pile (stackKey) ou unité (type matiere_premiere).
CREATE OR REPLACE FUNCTION public.matiere_brute_manger_interne(p_acteur text, p_matiere text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_inv jsonb; l jsonb; i integer; v jsonb; v_b integer;
BEGIN
  IF p_matiere IS NULL OR p_matiere NOT IN ('viande', 'laitages') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_comestible'); END IF;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF public.repas_differe_deja_pris_interne(p_acteur, 'repas_brut') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'repas_brut_deja_pris'); END IF;
  l := public.sovarka_inventaire_ligne_interne(v_inv, ARRAY[p_matiere]);
  IF (l->>'i')::integer < 0 THEN
    SELECT (o.ord - 1)::integer INTO i FROM jsonb_array_elements(v_inv) WITH ORDINALITY o(e, ord)
     WHERE o.e->>'type' = 'matiere_premiere' AND o.e->>'matiere' = p_matiere ORDER BY o.ord LIMIT 1;
    IF i IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_matiere', 'matiere', p_matiere); END IF;
  END IF;
  v := public.payer_ordre(p_acteur, 'manger_matiere_brute', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  IF (l->>'i')::integer >= 0 THEN
    PERFORM public.sovarka_inventaire_retirer_interne(p_acteur, l, 1);
  ELSE
    UPDATE public.personnages_donnees SET inventory = coalesce(inventory, '[]'::jsonb) - i, updated_at = now() WHERE name = p_acteur;
  END IF;
  v_b := public.repas_differe_crediter_interne(p_acteur, 'repas_brut', 'repas_brut');
  RETURN jsonb_build_object('ok', true, 'matiere', p_matiere, 'bonus', 1, 'bonus_pa_differe', v_b, 'pa', v->'pa')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur);
END $function$;
REVOKE ALL ON FUNCTION public.matiere_brute_manger_interne(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.matiere_brute_manger(p_requete uuid, p_matiere text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('matiere', p_matiere); v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'matiere_brute_manger', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.matiere_brute_manger_interne(a, p_matiere);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'matiere_brute_manger', prm, v);
END $function$;
REVOKE ALL ON FUNCTION public.matiere_brute_manger(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.matiere_brute_manger(uuid, text) TO authenticated;

-- 2. Confiture d'airelles : bonus différé (une par nuit) au lieu du +1 PA immédiat des aliments.
DO $conso$
DECLARE d text; a1 text; b1 text; a2 text; b2 text;
BEGIN
  d := pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure);
  IF position('confiture_deja_prise' IN d) > 0 THEN RETURN; END IF;
  a1 := E' v_item:=v_inv->v_pos;\n';
  b1 := a1 || E' -- Confiture d''airelles du kolkhoze (Fred, 18/11/2026) : +1 PA au prochain Dormir, une par nuit.\n'
            || E' IF coalesce(v_item->>''type'','''')=''kolkhoze_confiture_airelles'' AND public.repas_differe_deja_pris_interne(p_acteur,''confiture'') THEN\n'
            || E'   RETURN jsonb_build_object(''ok'',false,''raison'',''confiture_deja_prise'');\n END IF;\n';
  a2 := E' IF v_aliment THEN\n   v_frais:=';
  b2 := E' IF coalesce(v_item->>''type'','''')=''kolkhoze_confiture_airelles'' THEN\n'
     || E'   v_r:=v_r||jsonb_build_object(''bonus_pa_differe'',public.repas_differe_crediter_interne(p_acteur,''confiture'',''confiture_airelles''),''bonus_differe'',1);\n'
     || E' ELSIF v_aliment THEN\n   v_frais:=';
  IF (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 OR (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 THEN
    RAISE EXCEPTION 'inventaire_consommer : ancrage introuvable'; END IF;
  EXECUTE replace(replace(d, a1, b1), a2, b2);
END $conso$;

-- 3. Articles du kolkhoze : matières et objet simple, déposés par la vente.
UPDATE public.recettes_commerce SET famille_produit_marche = NULL, effets = '{"matiere":"viande"}'::jsonb WHERE id = 'kolkhoze_viande_renne';
UPDATE public.recettes_commerce SET famille_produit_marche = NULL, effets = '{"matiere":"laitages"}'::jsonb WHERE id = 'kolkhoze_lait_renne';
UPDATE public.recettes_commerce SET famille_produit_marche = NULL, effets = '{"matiere":"textile"}'::jsonb WHERE id = 'kolkhoze_peau_renne';
UPDATE public.recettes_commerce SET famille_produit_marche = NULL, effets = '{"matiere":"bois"}'::jsonb, materiaux = '{"bois":1}'::jsonb WHERE id = 'kolkhoze_bois_renne';
UPDATE public.recettes_commerce SET famille_produit_marche = NULL, effets = '{"objetSimple":true}'::jsonb WHERE id = 'kolkhoze_graisse_renne';
UPDATE public.commerces_dotations
   SET stock_matieres = stock_matieres || '{"bois":10}'::jsonb, cout_moyen_matieres = cout_moyen_matieres || '{"bois":1}'::jsonb
 WHERE cle = 'magasin-kolkhoze-starovka@soviet.ville_a' AND NOT stock_matieres ? 'bois';
UPDATE public.entreprises
   SET data = jsonb_set(jsonb_set(data, '{stockMatieres,bois}', to_jsonb(coalesce((data->'stockMatieres'->>'bois')::numeric, 0) + 10)),
                        '{coutMoyenMatieres,bois}', '1'::jsonb), updated_at = now()
 WHERE id = 'tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka' AND NOT (data->'coutMoyenMatieres') ? 'bois';

-- Bois de renne : prix PNJ recalculé sur la matière bois (coût 1) : 2 × (1 + 15) / 3 = 10 PSK.
UPDATE public.commerces_dotations SET parametres = jsonb_set(parametres, '{prixVente,kolkhoze_bois_renne}', '10')
 WHERE cle = 'magasin-kolkhoze-starovka@soviet.ville_a' AND (parametres->'prixVente'->>'kolkhoze_bois_renne') = '11';
UPDATE public.entreprises SET data = jsonb_set(data, '{parametres,prixVente,kolkhoze_bois_renne}', '10'), updated_at = now()
 WHERE id = 'tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka' AND (data->'parametres'->'prixVente'->>'kolkhoze_bois_renne') = '11';

DO $vente$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure);
  IF position('objetSimple' IN d) > 0 THEN RETURN; END IF;
  a := E'  -- Produits du marche non alimentaires (familleProduitMarche deposes par le serveur, 27/10 ; retabli le 14/11/2026).\n';
  b := E'  -- Magasin du kolkhoze (Fred, 18/11/2026) : matières (viande, laitages, textile, bois) en pile, objet simple sans effet.\n'
    || E'  FOR v_ligne IN SELECT value FROM jsonb_array_elements(v_livraison) LOOP\n'
    || E'    IF coalesce(v_ligne -> ''effets'' ->> ''matiere'', '''') IN (''viande'', ''laitages'', ''textile'', ''bois'') THEN\n'
    || E'      v_r := public.inventaire_deposer_interne(p_acteur, public.sovarka_matiere_objet_interne(v_ligne -> ''effets'' ->> ''matiere'',\n'
    || E'               coalesce((v_ligne ->> ''qte'')::numeric, 1)::integer, coalesce(v_ligne ->> ''label'', '''') || '' : '' || coalesce(v_ligne ->> ''description'', '''')));\n'
    || E'      IF coalesce((v_r ->> ''ok'')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION ''commerce_vendre_produit_interne : depot refuse %'', v_r; END IF;\n'
    || E'    ELSIF coalesce((v_ligne -> ''effets'' ->> ''objetSimple'')::boolean, false) THEN\n'
    || E'      v_r := public.inventaire_deposer_interne(p_acteur, jsonb_build_object(''name'', v_ligne ->> ''label'', ''icon'', coalesce(v_ligne ->> ''icone'', ''ti-package''),\n'
    || E'               ''stackable'', true, ''stackKey'', v_ligne ->> ''produit'', ''qty'', coalesce((v_ligne ->> ''qte'')::numeric, 1)::integer,\n'
    || E'               ''legal'', true, ''desc'', v_ligne ->> ''description'', ''villeOrigine'', v_ville));\n'
    || E'      IF coalesce((v_r ->> ''ok'')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION ''commerce_vendre_produit_interne : depot refuse %'', v_r; END IF;\n'
    || E'    END IF;\n  END LOOP;\n' || a;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'commerce_vendre_produit_interne : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $vente$;

DO $$ BEGIN
  IF position('confiture_deja_prise' IN pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure)) = 0
     OR position('objetSimple' IN pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure)) = 0
     OR (SELECT count(*) FROM public.recettes_commerce WHERE source = 'kolkhoze' AND famille_produit_marche IS NULL AND effets IS NOT NULL) <> 5
     OR (SELECT famille_produit_marche FROM public.recettes_commerce WHERE id = 'kolkhoze_confiture_airelles') IS DISTINCT FROM 'aliment'
  THEN RAISE EXCEPTION 'kolkhoze_alimentation : controle structurel en echec'; END IF;
END $$;
NOTIFY pgrst, 'reload schema';
COMMIT;
