-- NON DEPLOYEE. Requiert aussi le contrat inventaire atomique prepare le 16 octobre.
-- Bois : prix du canon * 1,10, plafond PNJ 10 ; aucune valeur fournie par le vendeur.
BEGIN;
DO $definitions_preparees$
DECLARE r record; p pg_proc%rowtype;
BEGIN
 FOR r IN SELECT * FROM (VALUES ('hg_fin_bois_vendre(uuid,text,jsonb)','d50796fc356d27414b67131aa5da8125')) t(signature,empreinte) LOOP
  SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure('public.'||r.signature);
  IF FOUND AND (md5(p.prosrc)<>r.empreinte OR p.proowner::regrole::text NOT IN ('postgres','supabase_admin') OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']) THEN
   RAISE EXCEPTION 'definition financiere preexistante non examinee : %',r.signature;
  END IF;
 END LOOP;
END;
$definitions_preparees$;
DO $preconditions$
BEGIN
 IF to_regprocedure('public.inventaire_sauver_revision(text,bigint,jsonb)') IS NULL
  OR to_regprocedure('public.hg_fin_etat(text)') IS NULL THEN
  RAISE EXCEPTION 'bois: contrats inventaire et financier requis';
 END IF;
END;
$preconditions$;
CREATE OR REPLACE FUNCTION public.hg_fin_bois_vendre(p_requete uuid,p_personnage text,p_quantite jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE v public.personnages_donnees%rowtype; d jsonb; imp jsonb; lot jsonb; inv jsonb;
 recu public.hg_fin_requetes%rowtype; corps jsonb; e jsonb; qte integer; disponible integer;
 pos integer:=-1; n integer:=0; prix numeric; caisse numeric; stock numeric; paiement numeric;
 r jsonb; resultat jsonb; ancien_arg numeric; ancien_liquide numeric; ancienne_revision bigint; controle jsonb;
BEGIN
 IF p_requete IS NULL OR p_quantite IS NULL OR jsonb_typeof(p_quantite)<>'number'
  OR p_quantite::text !~ '^[1-9][0-9]*$' THEN RAISE EXCEPTION 'quantite_entiere_requise'; END IF;
 qte:=(p_quantite::text)::integer;
 PERFORM public.hg_fin_etat(p_personnage);
 corps:=jsonb_build_object('operation','bois_vendre','personnage',p_personnage,'quantite',qte);
 PERFORM pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_requete::text,0));
 SELECT * INTO recu FROM public.hg_fin_requetes WHERE utilisateur=auth.uid() AND requete=p_requete;
 IF FOUND THEN
  IF recu.corps IS DISTINCT FROM corps THEN RAISE EXCEPTION 'requete_reutilisee'; END IF;
  SELECT * INTO v FROM public.personnages_donnees WHERE name=p_personnage;
  RETURN jsonb_build_object('ok',true,'rejeu',true,'resultat',recu.resultat,'etat',public.hg_fin_etat(p_personnage),
   'inventory',v.inventory,'inventory_revision',v.inventory_revision::text);
 END IF;
 SELECT * INTO v FROM public.personnages_donnees WHERE name=p_personnage FOR UPDATE;
 IF v.country IS DISTINCT FROM 'republic' OR NOT (
  (v.current_city IN ('capitale','ville_b') AND v.current_building='la-tribune' AND v.current_room='accueil_tribune')
  OR (v.current_city='ville_a' AND v.current_building='imprimerie-librairie' AND v.current_room='atelier'))
  THEN RAISE EXCEPTION 'presence_imprimerie_requise' USING ERRCODE='42501'; END IF;
 IF jsonb_typeof(v.inventory) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'inventaire_invalide'; END IF;
 FOR e IN SELECT * FROM jsonb_array_elements(v.inventory) LOOP
  IF e->>'stackKey'='bois' AND coalesce((e->>'qty')::numeric,0)>0 THEN pos:=n;lot:=e;EXIT; END IF;
  n:=n+1;
 END LOOP;
 IF pos<0 OR (lot->>'qty')::numeric<qte THEN RAISE EXCEPTION 'bois_personnel_insuffisant'; END IF;
 IF (lot->>'qty')::numeric<>trunc((lot->>'qty')::numeric) THEN RAISE EXCEPTION 'lot_bois_non_entier'; END IF;
 SELECT prix_base INTO prix FROM public.ressources_economie WHERE cle='bois';
 IF prix IS DISTINCT FROM 5::numeric THEN RAISE EXCEPTION 'bois: miroir tarifaire a synchroniser'; END IF;
 prix:=round(prix*1.10,2)::public.hg_francs_exacts;
 SELECT public.batiment_etat_lire(data) INTO d FROM public.batiments_etat
  WHERE id=v.country||'_'||v.current_city||'_'||v.current_building FOR UPDATE;
 IF d IS NULL OR jsonb_typeof(d->'imprimerie') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'atelier_absent'; END IF;
 imp:=d->'imprimerie';stock:=coalesce((imp->>'stockBois')::numeric,0);caisse:=coalesce((imp->>'caisse')::numeric,0);
 IF stock<>trunc(stock) OR stock<0 OR caisse<0 THEN RAISE EXCEPTION 'atelier_etat_invalide'; END IF;
 disponible:=least(qte,greatest(0,10-stock),greatest(0,floor(caisse/prix)))::integer;
 IF disponible<=0 THEN RAISE EXCEPTION 'atelier_caisse_ou_capacite_insuffisante'; END IF;
 paiement:=(disponible*prix)::public.hg_francs_exacts;
 ancien_arg:=coalesce(v.arg,0);ancien_liquide:=coalesce(v.liquide,0);ancienne_revision:=v.inventory_revision;
 r:=public.batiment_caisse_mouvement(v.country,v.current_city,v.current_building,'imprimerie',-paiement,'stockBois',disponible,10,true);
 IF (r->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'atelier_mouvement_refuse'; END IF;
 IF (lot->>'qty')::integer=disponible THEN inv:=v.inventory-pos;
 ELSE inv:=jsonb_set(v.inventory,ARRAY[pos::text,'qty'],to_jsonb((lot->>'qty')::integer-disponible)); END IF;
 r:=public.inventaire_sauver_revision(p_personnage,v.inventory_revision,inv);
 IF (r->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'inventaire_mouvement_refuse'; END IF;
 UPDATE public.personnages_donnees SET arg=coalesce(arg,0)+paiement,liquide=coalesce(liquide,0)+paiement WHERE name=p_personnage;
 SELECT * INTO v FROM public.personnages_donnees WHERE name=p_personnage;
 IF v.inventory IS DISTINCT FROM inv OR v.inventory_revision IS DISTINCT FROM ancienne_revision+1
  OR v.arg IS DISTINCT FROM ancien_arg+paiement OR v.liquide IS DISTINCT FROM ancien_liquide+paiement
  THEN RAISE EXCEPTION 'bois_mouvement_non_applique'; END IF;
 SELECT public.batiment_etat_lire(data)->'imprimerie' INTO controle FROM public.batiments_etat
  WHERE id=v.country||'_'||v.current_city||'_'||v.current_building;
 IF (controle->>'stockBois')::numeric IS DISTINCT FROM stock+disponible
  OR (controle->>'caisse')::numeric IS DISTINCT FROM caisse-paiement THEN RAISE EXCEPTION 'atelier_mouvement_non_applique'; END IF;
 resultat:=jsonb_build_object('quantite',disponible,'montant',public.hg_fr_texte(paiement),'prix_unitaire',public.hg_fr_texte(prix));
 INSERT INTO public.hg_fin_requetes(utilisateur,requete,personnage,corps,resultat) VALUES(auth.uid(),p_requete,p_personnage,corps,resultat);
 RETURN jsonb_build_object('ok',true,'rejeu',false,'resultat',resultat,'etat',public.hg_fin_etat(p_personnage),
  'inventory',v.inventory,'inventory_revision',v.inventory_revision::text);
END;
$function$;
REVOKE ALL ON FUNCTION public.hg_fin_bois_vendre(uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.hg_fin_bois_vendre(uuid,text,jsonb) TO authenticated;
COMMIT;
