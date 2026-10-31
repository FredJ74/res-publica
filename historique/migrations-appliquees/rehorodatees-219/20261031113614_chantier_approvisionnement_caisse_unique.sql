-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261022123321_chantier_approvisionnement_caisse_unique.sql ; aucun changement de règle.
-- #57 PREPAREE. Meme achat, stock et recette dans la vraie caisse, en une transaction.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.approvisionner_chantier(text,text,text,text,jsonb,jsonb,numeric)');
IF h IS NULL OR h NOT IN ('aed6d3286a5c348ea4f17d414259739e','0161eb65fbe30222af55f22b3ad14829') THEN RAISE EXCEPTION 'approvisionnement_definition_non_examinee';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.approvisionner_chantier(p_acteur text, p_pays text, p_ville text, p_entrepot text, p_besoin jsonb, p_stock_chantier jsonb, p_tresorerie numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_entrepot;
  v_etat jsonb; v_entrepot jsonb; v_stock jsonb; v_reserve jsonb;
  v_cle text; v_en_chantier numeric; v_manque numeric; v_prix numeric;
  v_present numeric; v_reserve_m numeric; v_dispo numeric; v_abordable numeric; v_qte numeric;
  v_achats jsonb := '{}'::jsonb; v_nouveau_chantier jsonb := '{}'::jsonb;
  v_depense numeric := 0; v_recette jsonb; v_ancien_flag text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'depense', 0, 'achats', '{}'::jsonb,
                              'stockChantier', coalesce(p_stock_chantier,'{}'::jsonb));
  END IF;
  v_entrepot := coalesce(v_etat->'entrepot', '{}'::jsonb);
  v_stock := coalesce(v_entrepot->'stock', '{}'::jsonb);
  v_reserve := coalesce(v_entrepot->'reserveMilitaire', '{}'::jsonb);

  -- Meme boucle, dans le meme ordre, sur les memes trois materiaux.
  FOREACH v_cle IN ARRAY ARRAY['bois','minerai','metal'] LOOP
    v_en_chantier := greatest(0, coalesce((p_stock_chantier->>v_cle)::numeric, 0));
    v_nouveau_chantier := jsonb_set(v_nouveau_chantier, ARRAY[v_cle], to_jsonb(v_en_chantier));
    v_manque := greatest(0, greatest(0, coalesce((p_besoin->>v_cle)::numeric, 0)) - v_en_chantier);
    CONTINUE WHEN v_manque <= 0;
    -- Le PRIX vient du miroir, jamais du client.
    SELECT prix_base INTO v_prix FROM public.ressources_economie WHERE cle = v_cle;
    CONTINUE WHEN v_prix IS NULL OR v_prix <= 0;
    v_present := greatest(0, floor(coalesce((v_stock->>v_cle)::numeric, 0)));
    v_reserve_m := greatest(0, floor(coalesce((v_reserve->>v_cle)::numeric, 0)));
    v_dispo := greatest(0, v_present - v_reserve_m);     -- reserve militaire opposable
    v_abordable := floor(greatest(0, coalesce(p_tresorerie,0) - v_depense) / v_prix);
    v_qte := least(v_manque, v_dispo, v_abordable);
    CONTINUE WHEN v_qte <= 0;
    v_achats := jsonb_set(v_achats, ARRAY[v_cle], to_jsonb(v_qte));
    v_depense := v_depense + v_qte * v_prix;
    v_nouveau_chantier := jsonb_set(v_nouveau_chantier, ARRAY[v_cle], to_jsonb(v_en_chantier + v_qte));
    -- On debite le stock PHYSIQUE, jamais la vue « disponible ».
    v_stock := jsonb_set(v_stock, ARRAY[v_cle], to_jsonb(v_present - v_qte));
  END LOOP;

  IF v_depense > 0 THEN
    v_ancien_flag:=current_setting('rp.caisse_interne',true);
    PERFORM set_config('rp.caisse_interne','on',true);
    v_recette:=public.caisse_institution_mouvement(public.entrepot_caisse_id(v_id),v_depense,true);
    PERFORM set_config('rp.caisse_interne',coalesce(v_ancien_flag,''),true);
    IF NOT coalesce((v_recette->>'ok')::boolean,false) THEN
      RAISE EXCEPTION 'recette_entrepot_non_confirmee';END IF;
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
             (v_entrepot-'caisse') || jsonb_build_object('stock', v_stock)))::text),
           updated_at = now()
     WHERE id = v_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'achats', v_achats, 'depense', v_depense,
                            'stockChantier', v_nouveau_chantier);
END; $function$;
REVOKE ALL ON FUNCTION public.approvisionner_chantier(text,text,text,text,jsonb,jsonb,numeric) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
