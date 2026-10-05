-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918072746
-- Nom original      : caserne_stock_matieres_commun
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-18 07:27:46 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : ae9e3b07991e97bb17eebfec5dec39f0
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ==========================================================================================
-- STOCK UNIQUE DE MATIERES PREMIERES DE LA CASERNE
--
-- REGLE GD : toutes les matieres premieres de la caserne appartiennent a UN stock commun a tout
-- le batiment, accessible depuis n'importe quelle piece. Une piece determine ce qu'on peut y
-- FABRIQUER, pas a quelles matieres on a acces. Il ne doit donc exister aucun transfert
-- artificiel « stock caserne -> stock infirmerie » parce qu'on change de piece.
--
-- CE QUI EXISTAIT, et qui etait mon erreur : j'avais cree data.infirmerie comme stock dedie, en
-- plus de data.refectoire.brut. Deux magasins de matieres pour un meme batiment.
--
-- LA CLE COMMUNE EST data.caserneMatieres. Les PRODUITS FINIS gardent leur propre magasin, ce que
-- le GD autorise explicitement : data.refectoire.rations (rations deja produites) et
-- data.stockArmurerieMilitaire (armes et accessoires produits).
--
-- MIGRATION SANS PERTE : les quantites presentes dans refectoire.brut ET dans infirmerie sont
-- ADDITIONNEES dans caserneMatieres avant que les anciennes cles soient retirees. Rien ne
-- disparait silencieusement.
-- ==========================================================================================
DO $$
DECLARE v_r record; v_data jsonb; v_brut jsonb; v_inf jsonb; v_commun jsonb; v_cle text;
BEGIN
  FOR v_r IN SELECT id, data FROM public.budgets_nationaux FOR UPDATE LOOP
    v_data := coalesce(v_r.data, '{}'::jsonb);
    v_brut := CASE WHEN jsonb_typeof(v_data->'refectoire'->'brut') = 'object'
                   THEN v_data->'refectoire'->'brut' ELSE '{}'::jsonb END;
    v_inf  := CASE WHEN jsonb_typeof(v_data->'infirmerie') = 'object'
                   THEN v_data->'infirmerie' ELSE '{}'::jsonb END;
    v_commun := CASE WHEN jsonb_typeof(v_data->'caserneMatieres') = 'object'
                     THEN v_data->'caserneMatieres' ELSE '{}'::jsonb END;

    -- Addition, jamais ecrasement : une matiere presente des deux cotes conserve son total.
    FOR v_cle IN SELECT k FROM jsonb_object_keys(v_brut) k LOOP
      v_commun := v_commun || jsonb_build_object(v_cle,
        coalesce((v_commun->>v_cle)::numeric, 0) + coalesce((v_brut->>v_cle)::numeric, 0));
    END LOOP;
    FOR v_cle IN SELECT k FROM jsonb_object_keys(v_inf) k LOOP
      v_commun := v_commun || jsonb_build_object(v_cle,
        coalesce((v_commun->>v_cle)::numeric, 0) + coalesce((v_inf->>v_cle)::numeric, 0));
    END LOOP;

    UPDATE public.budgets_nationaux
       SET data = (v_data
             || jsonb_build_object('caserneMatieres', v_commun)
             || jsonb_build_object('refectoire',
                  (CASE WHEN jsonb_typeof(v_data->'refectoire') = 'object'
                        THEN v_data->'refectoire' ELSE '{}'::jsonb END) - 'brut'))
             - 'infirmerie',
           updated_at = now()
     WHERE id = v_r.id;
  END LOOP;
END $$;

-- ---- effort_ravitailler depose desormais dans le stock COMMUN ----
-- Seule la destination change : l'achat, les prix, la reserve et la caisse sont inchanges.
CREATE OR REPLACE FUNCTION public.effort_ravitailler(
  p_pays text, p_entrepots jsonb, p_cibles jsonb, p_prix jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_ids text[]; v_id text; v_etats jsonb := '{}'::jsonb; v_d jsonb; v_res text;
  v_reste numeric; v_pris numeric; v_prix numeric; v_cout numeric; v_total numeric := 0;
  v_caisse text; v_solde numeric; v_ent jsonb; v_stock jsonb; v_resv jsonb; v_dispo numeric;
  v_achats jsonb := '{}'::jsonb; v_data jsonb; v_commun jsonb;
BEGIN
  IF p_entrepots IS NULL OR jsonb_typeof(p_entrepots) <> 'array'
     OR jsonb_array_length(p_entrepots) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot');
  END IF;
  v_caisse := p_pays || '_caserne-militaire';
  SELECT COALESCE((data ->> 'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN v_solde := 0; END IF;
  IF v_solde <= 0 THEN RETURN jsonb_build_object('ok', true, 'achats', '{}'::jsonb, 'total', 0); END IF;

  SELECT COALESCE(array_agg(x ORDER BY x), ARRAY[]::text[]) INTO v_ids
  FROM (SELECT public.eg_etat_id(p_pays, e) AS x FROM jsonb_array_elements(p_entrepots) e) s;
  FOREACH v_id IN ARRAY v_ids LOOP
    SELECT public.eg_etat_lire(data) INTO v_d FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
    IF FOUND THEN v_etats := v_etats || jsonb_build_object(v_id, v_d); END IF;
  END LOOP;
  IF v_etats = '{}'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_entrepot_trouve'); END IF;

  FOR v_res IN SELECT k FROM jsonb_object_keys(COALESCE(p_cibles, '{}'::jsonb)) k ORDER BY 1 LOOP
    v_reste := GREATEST(0, COALESCE((p_cibles ->> v_res)::numeric, 0));
    v_prix  := GREATEST(0, COALESCE((p_prix ->> v_res)::numeric, 0));
    CONTINUE WHEN v_reste <= 0 OR v_prix <= 0;
    FOR v_id IN SELECT k2 FROM jsonb_object_keys(v_etats) k2 ORDER BY 1 LOOP
      EXIT WHEN v_reste <= 0 OR v_solde < v_prix;
      v_d     := v_etats -> v_id;
      v_ent   := COALESCE(v_d -> 'entrepot', '{}'::jsonb);
      v_stock := COALESCE(v_ent -> 'stock', '{}'::jsonb);
      v_resv  := COALESCE(v_ent -> 'reserveMilitaire', '{}'::jsonb);
      v_dispo := GREATEST(0, COALESCE((v_stock ->> v_res)::numeric, 0))
               - GREATEST(0, COALESCE((v_resv  ->> v_res)::numeric, 0));
      v_pris := LEAST(v_reste, GREATEST(0, v_dispo), floor(v_solde / v_prix));
      CONTINUE WHEN v_pris <= 0;
      v_cout  := v_pris * v_prix;
      v_stock := v_stock || jsonb_build_object(v_res, COALESCE((v_stock ->> v_res)::numeric, 0) - v_pris);
      v_ent   := v_ent || jsonb_build_object('stock', v_stock,
                   'caisse', COALESCE((v_ent ->> 'caisse')::numeric, 0) + v_cout);
      v_etats := v_etats || jsonb_build_object(v_id, v_d || jsonb_build_object('entrepot', v_ent));
      v_solde := v_solde - v_cout;
      v_total := v_total + v_cout;
      v_reste := v_reste - v_pris;
      v_achats := v_achats || jsonb_build_object(v_res, COALESCE((v_achats ->> v_res)::numeric, 0) + v_pris);
    END LOOP;
  END LOOP;

  IF v_total <= 0 THEN RETURN jsonb_build_object('ok', true, 'achats', '{}'::jsonb, 'total', 0); END IF;

  FOR v_id IN SELECT k FROM jsonb_object_keys(v_etats) k ORDER BY 1 LOOP
    UPDATE public.batiments_etat SET data = to_jsonb((v_etats -> v_id)::text), updated_at = now() WHERE id = v_id;
  END LOOP;
  UPDATE public.caisses_batiments
     SET data = COALESCE(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde), updated_at = now()
   WHERE id = v_caisse;

  -- DESTINATION : le stock COMMUN de la caserne, plus refectoire.brut.
  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  v_data := COALESCE(v_data, '{}'::jsonb);
  v_commun := CASE WHEN jsonb_typeof(v_data -> 'caserneMatieres') = 'object'
                   THEN v_data -> 'caserneMatieres' ELSE '{}'::jsonb END;
  FOR v_res IN SELECT k FROM jsonb_object_keys(v_achats) k LOOP
    v_commun := v_commun || jsonb_build_object(v_res,
      COALESCE((v_commun ->> v_res)::numeric, 0) + COALESCE((v_achats ->> v_res)::numeric, 0));
  END LOOP;
  UPDATE public.budgets_nationaux
     SET data = v_data || jsonb_build_object('caserneMatieres', v_commun), updated_at = now()
   WHERE id = p_pays;

  RETURN jsonb_build_object('ok', true, 'achats', v_achats, 'total', v_total, 'solde', v_solde);
END; $fn$;