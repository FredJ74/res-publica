-- Plafond universel de 100 unités : les piles de tracts ont "quantite", pas "qty".
-- Prévol atomique SOUS VERROU sur la fiche du PJ, AVANT l'appel producteur débitant
-- les PA, les fonds et le bois. Même protection pour tracts électoraux et calomnieux.
-- Aucune modification des règles d'impression, cibles POUR/CONTRE, salaire ni inventaire.
-- La fonction de production existante est préservée par remplacement de deux ancrages exacts.
-- Empreinte vérifiée en production le 04/11/2026 avant rédaction : 900ac20f81f40b5f14fadc12de33de47.

DO $migration$
DECLARE
  v_source text;
  v_declare text := $ancre$
DECLARE v_moi text; v_r jsonb; v_inv jsonb; v_qte integer; v_sens text; v_trouve boolean := false; v_repere boolean := false;
$ancre$;
  v_declare_corrige text := $declaration$
DECLARE v_moi text; v_r jsonb; v_inv jsonb; v_qte integer; v_sens text; v_trouve boolean := false; v_repere boolean := false;
        v_charge numeric := 0;
$declaration$;
  v_prelevement text := $prelevement$
  v_r := public.imprimerie_produire_tracts(v_moi, p_pays, p_ville, p_batiment, CASE WHEN p_calomnieux THEN 1 ELSE p_lots END);
$prelevement$;
  v_prelevement_corrige text := $precontrole$
  -- Le serveur doit refuser TOUT dépassement du plafond avant le premier débit.
  -- Calcul de la quantité valide : toujours dix tracts par lot, un lot pour les calomnieux.
  IF NOT p_calomnieux AND (p_lots IS NULL OR p_lots < 1 OR p_lots > 100000) THEN
    RETURN jsonb_build_object('ok',false,'raison','quantite_invalide');
  END IF;
  v_qte := CASE WHEN p_calomnieux THEN 10 ELSE p_lots * 10 END;
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_introuvable'); END IF;

  SELECT COALESCE(SUM(CASE
      WHEN x ->> 'type' IN ('tract','tract_calomnieux')
      THEN GREATEST(coalesce(nullif(x ->> 'quantite','')::numeric, 1), 1)
      ELSE GREATEST(coalesce(nullif(x ->> 'qty','')::numeric,
                             nullif(x ->> 'encombrement','')::numeric, 1), 1)
      END),0)
    INTO v_charge
    FROM jsonb_array_elements(v_inv) AS x;
  IF v_charge + v_qte > 100 THEN
    RETURN jsonb_build_object('ok',false,'raison','inventaire_plein',
      'capacite',100,'occupe',v_charge,'requis',v_qte,
      'libres',greatest(0,100-v_charge));
  END IF;

  -- Même appel historique : débit atomique PA/FR/bois, puis remise des tracts.
  v_r := public.imprimerie_produire_tracts(v_moi, p_pays, p_ville, p_batiment, CASE WHEN p_calomnieux THEN 1 ELSE p_lots END);
$precontrole$;
BEGIN
  SELECT pg_get_functiondef('public.tracts_imprimer(text,text,text,integer,text,text,boolean)'::regprocedure)
    INTO v_source;
  IF md5(v_source) <> '900ac20f81f40b5f14fadc12de33de47' THEN
    RAISE EXCEPTION 'tracts_imprimer: empreinte de fonction inattendue, aucune modification: %', md5(v_source);
  END IF;
  IF (length(v_source)-length(replace(v_source,v_declare,'')))/length(v_declare) <> 1
    OR (length(v_source)-length(replace(v_source,v_prelevement,'')))/length(v_prelevement) <> 1 THEN
    RAISE EXCEPTION 'tracts_imprimer: ancres absentes ou ambiguës, aucune modification';
  END IF;
  EXECUTE replace(replace(v_source,v_declare,v_declare_corrige),
                  v_prelevement,v_prelevement_corrige);
END;
$migration$;

-- Les permissions d'exécution déjà accordées à authenticated restent inchangées.
