-- MALADIES, PÉREMPTION ET CLIMAT — LOT 2a : piles d'aliments datées, péremption à 10 jours (GAME-DESIGN-MALADIES-CLIMAT.md §§ 3 et 11).
-- Décision de Fred (18/11/2026 au soir) : chaque pile de matière périssable est datée ; une pile avariée est gardée à part des
-- piles saines, sans marque visible ; deux piles de dates différentes ne fusionnent plus.
-- • Matières périssables : viande, viande_renne, laitages, poisson, fruits_legumes, oeufs (céréales, sucre, produits exotiques :
--   non périssables). Champ `recu` (jour de Paris) posé au dépôt ; champ `avarie` réservé à la canicule (lot 5).
-- • Dépôt : fusion seulement avec une pile du même jour (et du même état) ; une pile arrivée avec sa date la garde (don, remise).
-- • Retrait : par quantité, les piles les plus anciennes d'abord ; par ligne choisie, cette pile d'abord puis les plus anciennes.
--   Corrige au passage l'ancien `inventaire_retirer`, qui retirait la quantité de CHAQUE pile de la clé.
-- • Passe de nuit : date les piles arrivées par un chemin qui ne date pas encore, annonce au propriétaire les piles gâtées.
-- • Consommation : un aliment avarié rapporte toujours ses PA, avec 50 % de risque d'intoxication (réglable par le MJ dans le
--   catalogue des maladies). La règle des 7 jours (+1 PA frais, −1 PA périmé) est remplacée.
-- Raccords à ancre unique, idempotents ; contrôle structurel final. Aucun fichier du goulag.
BEGIN;

CREATE TABLE IF NOT EXISTS public.aliments_parametres (
  cle    text PRIMARY KEY,
  valeur numeric NOT NULL
);
ALTER TABLE public.aliments_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.aliments_parametres FROM anon, authenticated;
INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('peremption_jours', 10) ON CONFLICT (cle) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.aliments_avaries_annonces (
  nom        text NOT NULL,
  cle        text NOT NULL,
  recu       date NOT NULL,
  annonce_le timestamptz NOT NULL DEFAULT now(),
  vu         boolean NOT NULL DEFAULT false,
  PRIMARY KEY (nom, cle, recu)
);
ALTER TABLE public.aliments_avaries_annonces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.aliments_avaries_annonces FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.aliment_perissable_interne(p_cle text)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_cle IN ('viande', 'viande_renne', 'laitages', 'poisson', 'fruits_legumes', 'oeufs'), false);
$$;

CREATE OR REPLACE FUNCTION public.aliments_jour_interne()
RETURNS date LANGUAGE sql STABLE AS $$ SELECT (now() AT TIME ZONE 'Europe/Paris')::date; $$;

-- Date d'une pile ; NULL si elle n'en porte pas (ou une date illisible).
CREATE OR REPLACE FUNCTION public.aliment_recu_interne(p_e jsonb)
RETURNS date LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
  IF coalesce(p_e->>'recu', '') !~ '^\d{4}-\d{2}-\d{2}$' THEN RETURN NULL; END IF;
  RETURN (p_e->>'recu')::date;
EXCEPTION WHEN others THEN RETURN NULL;
END $$;

-- Objet daté s'il est une matière périssable sans date (jour de Paris).
CREATE OR REPLACE FUNCTION public.aliment_dater_interne(p_o jsonb)
RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN jsonb_typeof(p_o) = 'object' AND public.aliment_perissable_interne(p_o->>'stackKey') AND public.aliment_recu_interne(p_o) IS NULL
              THEN p_o || jsonb_build_object('recu', to_char(public.aliments_jour_interne(), 'YYYY-MM-DD')) ELSE p_o END;
$$;

CREATE OR REPLACE FUNCTION public.aliment_pile_avariee_interne(p_e jsonb)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.aliment_perissable_interne(p_e->>'stackKey') AND (
    coalesce((p_e->>'avarie')::boolean, false)
    OR public.aliments_jour_interne() - public.aliment_recu_interne(p_e)
       > coalesce((SELECT valeur FROM public.aliments_parametres WHERE cle = 'peremption_jours'), 10));
$$;

-- Deux piles peuvent-elles fusionner ? Même clé ; pour une matière périssable, même jour et même état.
CREATE OR REPLACE FUNCTION public.inventaire_pile_fusionnable(p_e jsonb, p_o jsonb)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT coalesce(p_e->>'stackKey' = p_o->>'stackKey', false) AND (
    NOT public.aliment_perissable_interne(p_o->>'stackKey')
    OR (coalesce(public.aliment_recu_interne(p_e), public.aliments_jour_interne()) = coalesce(public.aliment_recu_interne(p_o), public.aliments_jour_interne())
        AND coalesce((p_e->>'avarie')::boolean, false) = coalesce((p_o->>'avarie')::boolean, false)));
$$;

-- Retrait d'une quantité d'une clé : la pile p_pos d'abord (si fournie), puis les plus anciennes, puis l'ordre de l'inventaire.
CREATE OR REPLACE FUNCTION public.inventaire_retirer_depuis(p_inv jsonb, p_cle text, p_qte integer, p_pos integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb := coalesce(p_inv, '[]'::jsonb); v_reste numeric := greatest(coalesce(p_qte, 0), 0); r record; v_q numeric; v_pris numeric;
BEGIN
  IF jsonb_typeof(v_inv) <> 'array' OR v_reste = 0 THEN RETURN v_inv; END IF;
  FOR r IN SELECT (o - 1)::integer AS i FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)
            WHERE e->>'stackKey' = p_cle
            ORDER BY (o - 1 = coalesce(p_pos, -1)) DESC, public.aliment_recu_interne(e) NULLS FIRST, o LOOP
    EXIT WHEN v_reste <= 0;
    v_q := coalesce((v_inv -> r.i ->> 'qty')::numeric, 1);
    v_pris := least(v_q, v_reste);
    v_inv := jsonb_set(v_inv, ARRAY[r.i::text, 'qty'], to_jsonb(v_q - v_pris));
    v_reste := v_reste - v_pris;
  END LOOP;
  RETURN (SELECT coalesce(jsonb_agg(e ORDER BY o) FILTER (WHERE e->>'stackKey' IS DISTINCT FROM p_cle OR coalesce((e->>'qty')::numeric, 1) > 0), '[]'::jsonb)
            FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o));
END $$;

CREATE OR REPLACE FUNCTION public.inventaire_retirer(p_inv jsonb, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.inventaire_retirer_depuis(p_inv, p_cle, p_qte, NULL);
$$;

-- Ajout d'une quantité : à une pile fusionnable (même jour pour un aliment), sinon une nouvelle pile datée.
CREATE OR REPLACE FUNCTION public.inventaire_ajouter(p_inv jsonb, p_cle text, p_qte integer, p_desc text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb := coalesce(p_inv, '[]'::jsonb); v_neuf jsonb; v_pos integer;
BEGIN
  IF p_qte <= 0 THEN RETURN v_inv; END IF;
  v_neuf := public.aliment_dater_interne(jsonb_build_object('name', p_cle, 'stackable', true, 'stackKey', p_cle, 'qty', p_qte, 'desc', p_desc));
  SELECT (o - 1)::integer INTO v_pos FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)
   WHERE public.inventaire_pile_fusionnable(e, v_neuf) ORDER BY o LIMIT 1;
  IF v_pos IS NOT NULL THEN
    RETURN jsonb_set(v_inv, ARRAY[v_pos::text, 'qty'], to_jsonb(coalesce((v_inv -> v_pos ->> 'qty')::numeric, 1) + p_qte));
  END IF;
  RETURN v_inv || jsonb_build_array(v_neuf);
END $$;

-- Première pile d'une des clés : son index, et la quantité TOTALE détenue de cette clé (toutes piles).
CREATE OR REPLACE FUNCTION public.sovarka_inventaire_ligne_interne(p_inv jsonb, p_cles text[])
RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE i integer; v_cle text;
BEGIN
  IF jsonb_typeof(p_inv) = 'array' THEN
    FOR i IN 0 .. jsonb_array_length(p_inv) - 1 LOOP
      IF (p_inv -> i ->> 'stackKey') = ANY (p_cles) AND coalesce((p_inv -> i ->> 'stackable')::boolean, false)
         AND coalesce((p_inv -> i ->> 'qty')::numeric, 0) >= 1 THEN
        v_cle := p_inv -> i ->> 'stackKey';
        RETURN jsonb_build_object('i', i, 'cle', v_cle, 'qte',
          (SELECT floor(coalesce(sum(coalesce((e->>'qty')::numeric, 0)), 0))::integer FROM jsonb_array_elements(p_inv) e
            WHERE e->>'stackKey' = v_cle AND coalesce((e->>'stackable')::boolean, false)));
      END IF;
    END LOOP;
  END IF;
  RETURN jsonb_build_object('i', -1, 'qte', 0);
END $$;

CREATE OR REPLACE FUNCTION public.sovarka_inventaire_retirer_interne(p_nom text, p_ligne jsonb, p_qte integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb; i integer := (p_ligne->>'i')::integer; v_cle text := p_ligne->>'cle';
BEGIN
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF i < 0 OR (v_inv -> i ->> 'stackKey') IS DISTINCT FROM v_cle OR coalesce(p_qte, 0) <= 0
     OR public.inventaire_quantite(v_inv, v_cle) < p_qte THEN RAISE EXCEPTION 'inventaire_ligne_invalide'; END IF;
  v_inv := public.inventaire_retirer_depuis(v_inv, v_cle, p_qte, i);
  UPDATE public.personnages_donnees SET inventory = v_inv, updated_at = now() WHERE name = p_nom;
  IF (SELECT inventory FROM public.personnages_donnees WHERE name = p_nom) IS DISTINCT FROM v_inv THEN
    RAISE EXCEPTION 'inventaire_non_applique'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.jardins_ouvriers_ligne_legumes(p_inv jsonb)
RETURNS integer[] LANGUAGE plpgsql STABLE AS $$
DECLARE l jsonb := public.sovarka_inventaire_ligne_interne(p_inv, ARRAY['fruits_legumes']);
BEGIN
  RETURN ARRAY[(l->>'i')::integer, greatest(0, (l->>'qte')::integer)];
END $$;

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

-- Jardins ouvriers : retrait sur toutes les piles de fruits et légumes.
SELECT pg_temp.rp_raccorder('public.jardins_laisser_interne(text,integer)'::regprocedure,
  $a$  IF l[2] = p_qte THEN v_inv := v_inv - l[1];
  ELSE v_inv := jsonb_set(v_inv, ARRAY[l[1]::text, 'qty'], to_jsonb(l[2] - p_qte)); END IF;$a$,
  $b$  v_inv := public.inventaire_retirer_depuis(v_inv, 'fruits_legumes', p_qte, l[1]); -- aliments_piles_v1$b$,
  'aliments_piles_v1');

-- Dépôt générique : fusion avec une pile compatible seulement ; nouvelle pile datée.
SELECT pg_temp.rp_raccorder('public.inventaire_deposer_interne(text,jsonb,boolean)'::regprocedure,
  $a$WHERE coalesce((e->>'stackable')::boolean,false) AND e->>'stackKey'=v_cle ORDER BY o LIMIT 1;$a$,
  $b$WHERE coalesce((e->>'stackable')::boolean,false) AND e->>'stackKey'=v_cle AND public.inventaire_pile_fusionnable(e, p_objet) ORDER BY o LIMIT 1; -- aliments_piles_v1$b$,
  'aliments_piles_v1');
SELECT pg_temp.rp_raccorder('public.inventaire_deposer_interne(text,jsonb,boolean)'::regprocedure,
  $a$v_inv := v_inv || jsonb_build_array(p_objet || jsonb_build_object('qty', v_q));$a$,
  $b$v_inv := v_inv || jsonb_build_array(public.aliment_dater_interne(p_objet) || jsonb_build_object('qty', v_q)); -- aliments_dater_v1$b$,
  'aliments_dater_v1');

-- Réception d'une livraison (dons, remises, achats en commerce) : même règle.
SELECT pg_temp.rp_raccorder('public.inventaire_reclamer_livraison(text,text,uuid,bigint)'::regprocedure,
  $a$IF e->'stackable'='true'::jsonb AND e->>'stackKey'=o->>'stackKey' THEN pos:=i;EXIT;END IF;$a$,
  $b$IF e->'stackable'='true'::jsonb AND e->>'stackKey'=o->>'stackKey' AND public.inventaire_pile_fusionnable(e,o) THEN pos:=i;EXIT;END IF; -- aliments_piles_v1$b$,
  'aliments_piles_v1');
SELECT pg_temp.rp_raccorder('public.inventaire_reclamer_livraison(text,text,uuid,bigint)'::regprocedure,
  $a$inv:=inv||jsonb_build_array(o||jsonb_build_object('qty',q)); pos:=jsonb_array_length(inv)-1;$a$,
  $b$inv:=inv||jsonb_build_array(public.aliment_dater_interne(o)||jsonb_build_object('qty',q)); pos:=jsonb_array_length(inv)-1; -- aliments_dater_v1$b$,
  'aliments_dater_v1');

-- Achat en entrepôt : l'ancienne fusion ajoutait la quantité à CHAQUE pile de la clé.
SELECT pg_temp.rp_raccorder('public.acheter_a_entrepot(text,text,text,text,jsonb)'::regprocedure,
  $a$    SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_inv) e
                   WHERE e->>'stackKey' = v_cle) INTO v_existe;
    IF v_existe THEN
      SELECT jsonb_agg(CASE WHEN e->>'stackKey' = v_cle
                            THEN jsonb_set(e, '{qty}', to_jsonb(coalesce((e->>'qty')::numeric,1) + v_ajoute))
                            ELSE e END)
        INTO v_inv FROM jsonb_array_elements(v_inv) e;
    ELSE
      v_inv := v_inv || jsonb_build_array(jsonb_build_object(
        'name', (SELECT cle FROM public.ressources_economie_pays(p_pays) WHERE cle = v_cle),
        'stackable', true, 'stackKey', v_cle, 'qty', v_ajoute,
        'desc', 'Ressource achetée à l''entrepôt logistique.'));
    END IF;$a$,
  $b$    v_inv := public.inventaire_ajouter(v_inv, v_cle, v_ajoute, 'Ressource achetée à l''entrepôt logistique.'); -- aliments_piles_v1$b$,
  'aliments_piles_v1');

-- Sortie par ligne (consommer, donner, détruire, remettre, abandonner, charger un véhicule) : la ligne choisie d'abord.
SELECT pg_temp.rp_raccorder('public.helvetia_inventaire_sortie(jsonb,jsonb,integer,jsonb,integer)'::regprocedure,
  $a$    v_nouveau := public.inventaire_retirer(p_inv, v_cle, p_qte);$a$,
  $b$    v_nouveau := public.inventaire_retirer_depuis(p_inv, v_cle, p_qte, v_pos); -- aliments_piles_v1$b$,
  'aliments_piles_v1');

-- Offres d'achat servies depuis l'inventaire : quantité totale, piles les plus anciennes d'abord.
SELECT pg_temp.rp_raccorder('public.offre_achat_servir(uuid,integer,text,text,text)'::regprocedure,
  $a$      SELECT (x.ord - 1)::integer, greatest(0, floor(coalesce((x.val->>'qty')::numeric, 0)))::integer INTO v_idx, v_possede$a$,
  $b$      SELECT (x.ord - 1)::integer, greatest(0, floor(public.inventaire_quantite(v_inv, o.ressource)))::integer INTO v_idx, v_possede -- aliments_piles_v1$b$,
  'aliments_piles_v1');
SELECT pg_temp.rp_raccorder('public.offre_achat_servir(uuid,integer,text,text,text)'::regprocedure,
  $a$      IF v_possede = q THEN
        UPDATE public.personnages_donnees SET inventory = inventory - v_idx WHERE name = v_moi;
      ELSE
        UPDATE public.personnages_donnees SET inventory = jsonb_set(inventory, ARRAY[v_idx::text, 'qty'], to_jsonb(v_possede - q)) WHERE name = v_moi;
      END IF;$a$,
  $b$      UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(inventory, o.ressource, q) WHERE name = v_moi; -- aliments_retrait_v1$b$,
  'aliments_retrait_v1');

-- Aliments manufacturés : 10 jours (réglable) ; périmé = toujours +1 PA, mais 50 % d'intoxication.
SELECT pg_temp.rp_raccorder('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$   v_frais:=(extract(epoch FROM now())*1000-v_date)<=604800000;
   v_delta:=CASE WHEN v_frais THEN 1 ELSE -1 END;$a$,
  $b$   v_frais:=(extract(epoch FROM now())*1000-v_date)<=coalesce((SELECT valeur FROM public.aliments_parametres WHERE cle='peremption_jours'),10)*86400000; -- aliments_peremption_v1
   v_delta:=1;$b$,
  'aliments_peremption_v1');
SELECT pg_temp.rp_raccorder('public.inventaire_consommer(text,integer,jsonb)'::regprocedure,
  $a$   v_r:=v_r||jsonb_build_object('pa',v_pa,'aliment_frais',v_frais);$a$,
  $b$   v_r:=v_r||jsonb_build_object('pa',v_pa,'aliment_frais',true,
     'maladie',CASE WHEN NOT v_frais THEN public.maladie_tirer_interne(p_acteur,'intoxication',public.maladie_risque_interne('intoxication','aliment_avarie'),'aliment_avarie') END); -- aliments_avarie_v1$b$,
  'aliments_avarie_v1');

-- Viande et laitages bruts, œufs : la pile mangée est la plus ancienne ; avariée, 50 % d'intoxication en plus du risque de la viande crue.
CREATE OR REPLACE FUNCTION public.matiere_brute_manger_interne(p_acteur text, p_matiere text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_inv jsonb; l jsonb; i integer; v jsonb; v_b integer; v_pile jsonb; v_avarie boolean := false; v_mal jsonb;
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
  ELSE
    -- La plus ancienne pile est mangée la première (aliments_piles_v1).
    SELECT (o - 1)::integer INTO i FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)
     WHERE e->>'stackKey' = p_matiere AND coalesce((e->>'qty')::numeric, 0) >= 1
     ORDER BY public.aliment_recu_interne(e) NULLS FIRST, o LIMIT 1;
    l := jsonb_set(l, '{i}', to_jsonb(i));
  END IF;
  v_pile := v_inv -> i;
  v_avarie := public.aliment_pile_avariee_interne(v_pile);
  v := public.payer_ordre(p_acteur, 'manger_matiere_brute', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  IF (l->>'i')::integer >= 0 THEN
    PERFORM public.sovarka_inventaire_retirer_interne(p_acteur, l, 1);
  ELSE
    UPDATE public.personnages_donnees SET inventory = coalesce(inventory, '[]'::jsonb) - i, updated_at = now() WHERE name = p_acteur;
  END IF;
  v_b := public.repas_differe_crediter_interne(p_acteur, 'repas_brut', 'repas_brut');
  IF p_matiere = 'viande' THEN
    v_mal := public.maladie_tirer_interne(p_acteur, 'intoxication', public.maladie_risque_interne('intoxication', 'viande_crue'), 'viande_crue');
  END IF;
  IF v_mal IS NULL AND v_avarie THEN
    v_mal := public.maladie_tirer_interne(p_acteur, 'intoxication', public.maladie_risque_interne('intoxication', 'aliment_avarie'), 'aliment_avarie');
  END IF;
  RETURN jsonb_build_object('ok', true, 'maladie', v_mal, 'matiere', p_matiere, 'bonus', 1, 'bonus_pa_differe', v_b, 'pa', v->'pa')
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur);
END $function$;

CREATE OR REPLACE FUNCTION public.sovarka_oeufs_manger_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE l jsonb; v_bonus integer; v jsonb; v_differe integer; v_inv jsonb; i integer; v_avarie boolean; v_mal jsonb;
BEGIN
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  l := public.sovarka_inventaire_ligne_interne(v_inv, ARRAY['oeufs']);
  IF (l->>'i')::integer < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_d_oeufs'); END IF;
  SELECT (o - 1)::integer INTO i FROM jsonb_array_elements(v_inv) WITH ORDINALITY x(e, o)
   WHERE e->>'stackKey' = 'oeufs' AND coalesce((e->>'qty')::numeric, 0) >= 1
   ORDER BY public.aliment_recu_interne(e) NULLS FIRST, o LIMIT 1;
  l := jsonb_set(l, '{i}', to_jsonb(i));
  v_avarie := public.aliment_pile_avariee_interne(v_inv -> i);
  SELECT montant INTO v_bonus FROM public.pa_bonus_differes WHERE source = 'oeufs';
  v := public.payer_ordre(p_acteur, 'manger_oeufs', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  PERFORM public.sovarka_inventaire_retirer_interne(p_acteur, l, 1);
  UPDATE public.personnages_donnees SET bonus_pa_differe = least(30, coalesce(bonus_pa_differe, 0) + v_bonus), updated_at = now()
   WHERE name = p_acteur RETURNING bonus_pa_differe INTO v_differe;
  IF v_avarie THEN
    v_mal := public.maladie_tirer_interne(p_acteur, 'intoxication', public.maladie_risque_interne('intoxication', 'aliment_avarie'), 'aliment_avarie');
  END IF;
  RETURN jsonb_build_object('ok', true, 'bonus', v_bonus, 'bonus_pa_differe', v_differe, 'pa', v->'pa', 'maladie', v_mal)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur);
END $function$;

-- ── Passe de nuit : datation et annonces ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.aliments_passe_nuit()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_inv jsonb; n_dates integer := 0; n_annonces integer := 0; v_n integer;
BEGIN
  FOR p IN SELECT name, inventory FROM public.personnages_donnees
            WHERE jsonb_typeof(inventory) = 'array'
              AND EXISTS (SELECT 1 FROM jsonb_array_elements(inventory) e WHERE public.aliment_perissable_interne(e->>'stackKey'))
            FOR UPDATE LOOP
    SELECT jsonb_agg(public.aliment_dater_interne(e) ORDER BY o) INTO v_inv FROM jsonb_array_elements(p.inventory) WITH ORDINALITY x(e, o);
    IF v_inv IS DISTINCT FROM p.inventory THEN
      UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p.name;
      n_dates := n_dates + 1;
    END IF;
    INSERT INTO public.aliments_avaries_annonces (nom, cle, recu)
    SELECT DISTINCT p.name, e->>'stackKey', public.aliment_recu_interne(e)
      FROM jsonb_array_elements(v_inv) e
     WHERE public.aliment_pile_avariee_interne(e) AND public.aliment_recu_interne(e) IS NOT NULL
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_n = ROW_COUNT; n_annonces := n_annonces + v_n;
  END LOOP;
  DELETE FROM public.aliments_avaries_annonces WHERE annonce_le < now() - interval '60 days';
  RETURN jsonb_build_object('ok', true, 'inventaires_dates', n_dates, 'annonces', n_annonces);
END $$;
REVOKE ALL ON FUNCTION public.aliments_passe_nuit() FROM PUBLIC, anon, authenticated;

-- Annonces non lues du joueur (clés des matières gâtées) ; lues une fois.
CREATE OR REPLACE FUNCTION public.aliments_annonces_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  WITH lues AS (UPDATE public.aliments_avaries_annonces SET vu = true WHERE nom = a AND NOT vu RETURNING cle)
  SELECT coalesce(jsonb_agg(DISTINCT cle), '[]'::jsonb) INTO v FROM lues;
  RETURN jsonb_build_object('ok', true, 'gates', v);
END $$;
REVOKE ALL ON FUNCTION public.aliments_annonces_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.aliments_annonces_lire() TO authenticated;

DO $$ BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'aliments_passe_nuit';
  PERFORM cron.schedule('aliments_passe_nuit', '10 23 * * *', 'SELECT public.aliments_passe_nuit()');
END $$;

REVOKE ALL ON FUNCTION public.aliment_perissable_interne(text), public.aliments_jour_interne(), public.aliment_recu_interne(jsonb),
  public.aliment_dater_interne(jsonb), public.aliment_pile_avariee_interne(jsonb), public.inventaire_pile_fusionnable(jsonb, jsonb),
  public.inventaire_retirer_depuis(jsonb, text, integer, integer) FROM PUBLIC, anon, authenticated;
-- Fonctions pures, appelées par inventaire_retirer / inventaire_ajouter, eux-mêmes ouverts aux joueurs connectés :
-- même droit qu'eux (appliqué en production par la migration complémentaire « aliments_piles_datees_droits »).
GRANT EXECUTE ON FUNCTION public.aliment_perissable_interne(text), public.aliments_jour_interne(), public.aliment_recu_interne(jsonb),
  public.aliment_dater_interne(jsonb), public.aliment_pile_avariee_interne(jsonb), public.inventaire_pile_fusionnable(jsonb, jsonb),
  public.inventaire_retirer_depuis(jsonb, text, integer, integer) TO authenticated;

-- ── Contrôle structurel ──────────────────────────────────────────────────────────────────────────
DO $$
DECLARE inv jsonb := '[{"stackable":true,"stackKey":"viande","qty":3,"recu":"2026-01-01"},{"stackable":true,"stackKey":"bois","qty":2},{"stackable":true,"stackKey":"viande","qty":4,"recu":"2026-02-01"}]';
BEGIN
  IF public.inventaire_quantite(public.inventaire_retirer(inv, 'viande', 5), 'viande') <> 2
     OR public.inventaire_retirer(inv, 'viande', 5) -> 1 ->> 'recu' <> '2026-02-01'
     OR public.inventaire_quantite(public.inventaire_retirer_depuis(inv, 'viande', 2, 2), 'viande') <> 5
     OR (public.inventaire_retirer_depuis(inv, 'viande', 2, 2) -> 2 ->> 'qty')::int <> 2
     OR jsonb_array_length(public.inventaire_ajouter(inv, 'viande', 1, 'x')) <> 4
     OR (public.inventaire_ajouter(inv, 'bois', 1, 'x') -> 1 ->> 'qty')::int <> 3
     OR (public.sovarka_inventaire_ligne_interne(inv, ARRAY['viande'])->>'qte')::int <> 7
     OR NOT public.aliment_pile_avariee_interne(inv -> 0)
     OR position('aliments_piles_v1' IN pg_get_functiondef('public.inventaire_deposer_interne(text,jsonb,boolean)'::regprocedure)) = 0
     OR position('aliments_piles_v1' IN pg_get_functiondef('public.inventaire_reclamer_livraison(text,text,uuid,bigint)'::regprocedure)) = 0
     OR position('aliments_piles_v1' IN pg_get_functiondef('public.acheter_a_entrepot(text,text,text,text,jsonb)'::regprocedure)) = 0
     OR position('aliments_piles_v1' IN pg_get_functiondef('public.helvetia_inventaire_sortie(jsonb,jsonb,integer,jsonb,integer)'::regprocedure)) = 0
     OR position('aliments_retrait_v1' IN pg_get_functiondef('public.offre_achat_servir(uuid,integer,text,text,text)'::regprocedure)) = 0
     OR position('aliments_avarie_v1' IN pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'lot 2a : controle structurel en echec'; END IF;
END $$;

COMMIT;
