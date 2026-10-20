-- Issue #57, lot 3. PREPAREE UNIQUEMENT, ne pas appliquer sans prevol vivant.
-- Reutilise le moteur de vente existant. Aucun changement de type monetaire ni de solde historique.
-- Si une fraction ne peut pas etre conservee par les colonnes vivantes : refus avant mutation.
-- La reception versionnee existante est une precondition, jamais contournee.
DO $g$ DECLARE h text; BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.vendre_materiaux_chantier(text,text,text,text,integer,integer)'); IF h IS NULL OR h NOT IN ('454957349e1b59a60f4313b9f60eebe8','b2b1aaa3e494429c1e43d5f58a9f14a7') THEN RAISE EXCEPTION 'definition_non_examinee: public.vendre_materiaux_chantier(text,text,text,text,integer,integer)'; END IF; END;$g$;
DO $g$ BEGIN
 IF to_regprocedure('public.inventaire_reception_etat(text)') IS NULL THEN RAISE EXCEPTION 'reception_versionnee_requise'; END IF;
 IF to_regclass('public.chantier_requetes') IS NOT NULL AND obj_description(to_regclass('public.chantier_requetes')) IS DISTINCT FROM 'HG chantier requetes #57 v1' THEN RAISE EXCEPTION 'table_requetes_inconnue'; END IF;
END;$g$;
CREATE TABLE IF NOT EXISTS public.chantier_requetes(id text PRIMARY KEY,acteur text NOT NULL,charge jsonb NOT NULL,resultat jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
COMMENT ON TABLE public.chantier_requetes IS 'HG chantier requetes #57 v1';
ALTER TABLE public.chantier_requetes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chantier_requetes FROM PUBLIC,anon,authenticated;
DO $g$ DECLARE h text; BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.vendre_materiaux_chantier(text,text,text,text,integer,integer,text)'); IF h IS NOT NULL AND h NOT IN ('29869c27f561e8bee3c1671a37fa90a1') THEN RAISE EXCEPTION 'definition_non_examinee: public.vendre_materiaux_chantier(text,text,text,text,integer,integer,text)'; END IF; END;$g$;
DO $g$ DECLARE h text; BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_prix_definir(text,jsonb)'); IF h IS NOT NULL AND h NOT IN ('e76d871ac5092dcc5e72953162ddbd5e') THEN RAISE EXCEPTION 'definition_non_examinee: public.chantier_prix_definir(text,jsonb)'; END IF; END;$g$;
CREATE OR REPLACE FUNCTION public.vendre_materiaux_chantier(p_vendeur text, p_country text, p_building_id text, p_matiere text, p_quantite integer, p_prix integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pj          personnages%ROWTYPE;
  v_terrain     terrains_etat%ROWTYPE;
  v_data        jsonb;
  v_chantier    jsonb;
  v_stock       jsonb;
  v_inv         jsonb;
  v_ligne       jsonb;
  v_idx         integer := -1;
  v_i           integer;
  v_possede     integer := 0;
  v_tresorerie  numeric;
  v_payables    integer;
  v_qte         integer;
  v_montant     numeric;
  v_duree       numeric;
  v_progression numeric;
  v_prix numeric;
  v_terrain_id  text := p_country || '_' || p_building_id;
BEGIN
  PERFORM public.exiger_acteur(p_vendeur);
  IF p_matiere NOT IN ('bois', 'minerai', 'metal') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_invalide');
  END IF;
  IF COALESCE(p_quantite, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF p_prix IS NULL OR p_prix < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide');
  END IF;

  -- VERROUS. Ordre fixe personnages -> terrains_etat, applique a toutes les ventes : deux ventes
  -- simultanees sur le meme chantier se serialisent au lieu de s'ecraser, et l'ordre etant
  -- toujours le meme, aucune de ces deux transactions ne peut en bloquer une autre en sens
  -- inverse.
  SELECT * INTO v_pj FROM personnages WHERE name = p_vendeur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'vendeur_absent'); END IF;

  SELECT * INTO v_terrain FROM terrains_etat WHERE id = v_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;

  -- PRESENCE PHYSIQUE, verifiee sur la donnee faisant autorite cote serveur.
  IF COALESCE(v_pj.current_building, '') <> p_building_id OR v_pj.country IS DISTINCT FROM p_country THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- terrains_etat.data est une colonne TEXT contenant du JSON (meme convention que organisations).
  BEGIN
    v_data := v_terrain.data::jsonb;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_illisible');
  END;

  v_chantier := v_data -> 'chantier';
  IF v_chantier IS NULL OR jsonb_typeof(v_chantier) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;

  -- Un chantier arrive a son terme n'accepte plus de marchandise.
  v_duree       := COALESCE((v_chantier ->> 'dureeJours')::numeric, 0);
  v_progression := COALESCE((v_chantier ->> 'progressionJours')::numeric, 0);
  IF v_duree > 0 AND v_progression >= v_duree THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_termine');
  END IF;

  IF v_pj.current_city IS DISTINCT FROM (v_data->>'city') OR nullif(v_data->>'succession_gel','') IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_ville_ou_gele');
  END IF;
  IF p_prix=0 THEN v_prix:=0;
  ELSE
    v_prix:=coalesce((v_chantier->'prixAchatPJ'->>p_matiere)::numeric,
      (SELECT round(prix_base*1.10,2) FROM public.ressources_economie WHERE cle=p_matiere));
  END IF;
  IF v_prix IS NULL OR v_prix<0 OR v_prix<>round(v_prix,2) THEN
    RETURN jsonb_build_object('ok',false,'raison','prix_indisponible');
  END IF;

  -- STOCK REEL DU VENDEUR, relu sur son inventaire -- jamais celui annonce par le client.
  v_inv := COALESCE(v_pj.inventory, '[]'::jsonb);
  IF jsonb_typeof(v_inv) <> 'array' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_illisible');
  END IF;
  FOR v_i IN 0 .. jsonb_array_length(v_inv) - 1 LOOP
    v_ligne := v_inv -> v_i;
    IF (v_ligne ->> 'stackKey') = p_matiere AND COALESCE((v_ligne ->> 'stackable')::boolean, false) THEN
      v_idx := v_i;
      v_possede := GREATEST(0, floor(COALESCE((v_ligne ->> 'qty')::numeric, 0))::integer);
      EXIT;
    END IF;
  END LOOP;
  IF v_idx < 0 OR v_possede <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant');
  END IF;

  -- Tresorerie reelle ; le prix est celui du proprietaire, jamais celui du vendeur.
  v_tresorerie := GREATEST(0, COALESCE((v_chantier ->> 'tresorerie')::numeric, 0));
  v_payables   := CASE WHEN v_prix=0 THEN p_quantite ELSE least(2147483647,floor(v_tresorerie/v_prix))::integer END;

  -- RECALCUL SERVEUR de la quantite transferable.
  v_qte := LEAST(p_quantite, v_possede, v_payables);
  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tresorerie_insuffisante');
  END IF;
  v_montant := v_qte::numeric * v_prix;
  IF v_montant<>trunc(v_montant) AND EXISTS(
    SELECT 1 FROM pg_attribute WHERE attrelid='public.personnages_donnees'::regclass
    AND attname IN ('arg','liquide') AND atttypid IN ('int2'::regtype,'int4'::regtype,'int8'::regtype)
  ) THEN RETURN jsonb_build_object('ok',false,'raison','precision_monetaire_requise'); END IF;

  -- ---- A partir d'ici, tout est applique ou rien ne l'est.

  -- 1. Retrait chez le vendeur. La ligne d'inventaire disparait si elle tombe a zero.
  IF v_possede - v_qte <= 0 THEN
    v_inv := v_inv - v_idx;
  ELSE
    v_inv := jsonb_set(v_inv, ARRAY[v_idx::text, 'qty'], to_jsonb(v_possede - v_qte));
  END IF;

  -- 2. Credit du stock du chantier. Le stock est un VRAI stock : aucune limitation au besoin du
  --    jour, une reserve peut etre constituee pour les jours suivants.
  v_stock := COALESCE(v_chantier -> 'stockMateriaux', '{}'::jsonb);
  v_stock := jsonb_set(v_stock, ARRAY[p_matiere],
               to_jsonb(GREATEST(0, COALESCE((v_stock ->> p_matiere)::numeric, 0)) + v_qte));
  v_chantier := jsonb_set(v_chantier, '{stockMateriaux}', v_stock);

  -- 3. Debit de la tresorerie du chantier.
  v_chantier := jsonb_set(v_chantier, '{tresorerie}', to_jsonb(v_tresorerie - v_montant));

  -- 4. Journal NOMINATIF : contrairement au journal d'un vol, le vendeur est connu.
  v_chantier := jsonb_set(v_chantier, '{ventesMateriauxPJ}',
    COALESCE(v_chantier -> 'ventesMateriauxPJ', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('vendeur', p_vendeur, 'matiere', p_matiere, 'quantite', v_qte,
                         'prixUnitaire',round(v_prix,2)::text, 'montant', v_montant,
                         'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));

  UPDATE terrains_etat
    SET data = (v_data || jsonb_build_object('chantier', v_chantier))::text,
        updated_at = now()
    WHERE id = v_terrain_id;

  -- 5. Paiement du vendeur et ecriture de son inventaire, dans la MEME transaction.
  UPDATE personnages
    SET arg = COALESCE(arg, 0) + v_montant,
        liquide = COALESCE(liquide,0) + v_montant,
        inventory = v_inv
    WHERE name = p_vendeur;

  IF (SELECT inventory FROM public.personnages_donnees WHERE name=p_vendeur) IS DISTINCT FROM v_inv THEN
    RAISE EXCEPTION 'inventaire_non_applique';
  END IF;
  RETURN jsonb_build_object('ok', true, 'quantite', v_qte, 'montant', round(v_montant,2)::text,
                            'prixUnitaire',round(v_prix,2)::text, 'matiere', p_matiere);
END;
$function$;
CREATE OR REPLACE FUNCTION public.vendre_materiaux_chantier(p_vendeur text,p_country text,p_building_id text,p_matiere text,p_quantite integer,p_prix integer,p_requete text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v_charge jsonb; v_recu public.chantier_requetes%rowtype; v_resultat jsonb; v_inv jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_vendeur);
  IF p_requete IS NULL OR length(p_requete)<8 OR length(p_requete)>160 THEN
    RETURN jsonb_build_object('ok',false,'raison','requete_requise'); END IF;
  v_charge:=jsonb_build_object('pays',p_country,'terrain',p_building_id,'matiere',p_matiere,'quantite',p_quantite,'mode',p_prix);
  PERFORM pg_advisory_xact_lock(hashtextextended('chantier:'||p_requete,0));
  SELECT * INTO v_recu FROM public.chantier_requetes WHERE id=p_requete;
  IF FOUND THEN
    IF v_recu.acteur IS DISTINCT FROM p_vendeur OR v_recu.charge IS DISTINCT FROM v_charge THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    RETURN v_recu.resultat||jsonb_build_object('rejeu',true);
  END IF;
  v_resultat:=public.vendre_materiaux_chantier(p_vendeur,p_country,p_building_id,p_matiere,p_quantite,p_prix);
  IF (v_resultat->>'ok')::boolean THEN
    v_inv:=public.inventaire_reception_etat(p_vendeur);
    IF NOT coalesce((v_inv->>'ok')::boolean,false) THEN RAISE EXCEPTION 'inventaire_non_confirme'; END IF;
    v_resultat:=v_resultat||v_inv||jsonb_build_object('contratConstruction',57);
  END IF;
  INSERT INTO public.chantier_requetes(id,acteur,charge,resultat) VALUES(p_requete,p_vendeur,v_charge,v_resultat);
  RETURN v_resultat;
END;$function$;
CREATE OR REPLACE FUNCTION public.chantier_prix_definir(p_terrain_id text,p_prix jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v_acteur text:=public.mon_personnage(); v_pays text; v_etat jsonb; v_ch jsonb; v_k text; v_val jsonb; v_n numeric;
BEGIN
  IF v_acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name=v_acteur;
  SELECT public.terrain_etat_lire(data) INTO v_etat FROM public.terrains_etat WHERE id=v_pays||'_'||p_terrain_id FOR UPDATE;
  IF v_etat IS NULL OR v_etat->>'proprietaire' IS DISTINCT FROM v_acteur THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_proprietaire'); END IF;
  v_ch:=v_etat->'chantier';
  IF v_ch IS NULL OR (v_ch->>'progressionJours')::numeric >= (v_ch->>'dureeJours')::numeric
     OR nullif(v_etat->>'succession_gel','') IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','chantier_indisponible'); END IF;
  IF jsonb_typeof(p_prix) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok',false,'raison','prix_invalides'); END IF;
  FOR v_k,v_val IN SELECT * FROM jsonb_each(p_prix) LOOP
    IF v_k NOT IN ('bois','minerai','metal') OR jsonb_typeof(v_val) NOT IN ('string','number') OR (v_val#>>'{}') !~ '^(0|[1-9][0-9]*)([.][0-9]{1,2})?$' THEN
      RETURN jsonb_build_object('ok',false,'raison','prix_invalides'); END IF;
    v_n:=(v_val#>>'{}')::numeric;
    v_ch:=jsonb_set(v_ch,ARRAY['prixAchatPJ'],coalesce(v_ch->'prixAchatPJ','{}')||jsonb_build_object(v_k,round(v_n,2)::text));
  END LOOP;
  v_etat:=jsonb_set(v_etat,'{chantier}',v_ch);
  UPDATE public.terrains_etat SET data=v_etat::text,updated_at=now() WHERE id=v_pays||'_'||p_terrain_id;
  RETURN jsonb_build_object('ok',true,'etat',v_etat);
END;$function$;
REVOKE ALL ON FUNCTION public.vendre_materiaux_chantier(text,text,text,text,integer,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.vendre_materiaux_chantier(text,text,text,text,integer,integer,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.chantier_prix_definir(text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.vendre_materiaux_chantier(text,text,text,text,integer,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chantier_prix_definir(text,jsonb) TO authenticated;
