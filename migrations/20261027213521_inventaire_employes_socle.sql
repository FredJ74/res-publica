-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028204929.
-- Eprouvee au role authenticated en transaction annulee : PNJ : donner, reprendre une partie de pile, identifiant stable de possession.
-- (Preparee par Codex.) PREPAREE NON APPLIQUEE. Prolonge pnj_objet_transferer, aucun second porteur/moteur.
-- Depend du depot et des recus inventaire ; verifier les charges historiques avant activation.
-- Les charges encore dans personnages_donnees.employes ne sont ni effacees ni reconstruites.
CREATE OR REPLACE FUNCTION public.pnj_objet_transferer(p_pnj text,p_index integer,p_sens text,
 p_quantite integer,p_revision bigint,p_possession bigint,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE a public.personnages_donnees; m public.pnj_membres; p public.pnj_possessions;
 o jsonb; inv jsonb; d jsonb; v jsonb; params jsonb; q integer; disponible integer; porte integer;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL OR p_sens IS NULL OR p_sens NOT IN('donner','retirer') THEN RETURN jsonb_build_object('ok',false,'raison','commande_invalide'); END IF;
 params:=jsonb_build_object('pnj',p_pnj,'index',p_index,'sens',p_sens,'quantite',p_quantite,'revision',p_revision,'possession',p_possession);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'pnj_objet',params);IF v IS NOT NULL THEN RETURN v; END IF;
 SELECT * INTO m FROM public.pnj_membres WHERE id=p_pnj FOR UPDATE;
 IF NOT FOUND OR m.statut<>'actif' OR NOT public.pnj_peut_administrer(a.name,p_pnj) THEN RETURN jsonb_build_object('ok',false,'raison','autorite_insuffisante'); END IF;
 IF NOT public.pnj_co_present(a.name,p_pnj) THEN RETURN jsonb_build_object('ok',false,'raison','pas_co_presents'); END IF;
 -- Ne pas perdre ni dupliquer l'ancienne charge numerique. Sa reconciliation exige un releve
 -- reel des PNJ/objets ; elle n'est pas remplacee par un objet fourni par l'ecran.
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(a.employes,'[]')) e
  WHERE (e->>'pnjId'=p_pnj OR (e->>'nom'=m.nom AND m.proprietaire_pj=a.name))
   AND (coalesce(e->'charge','{}')<>'{}'::jsonb OR coalesce(e->'chargeUnique','[]')<>'[]'::jsonb)) THEN
  RETURN jsonb_build_object('ok',false,'raison','charge_historique_a_reconcilier'); END IF;
 PERFORM 1 FROM public.pnj_possessions WHERE pnj_id=p_pnj ORDER BY id FOR UPDATE;
 IF p_sens='donner' THEN
  IF p_revision IS DISTINCT FROM a.inventory_revision THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_perime'); END IF;
  IF p_index IS NULL OR p_index<0 OR p_index>=jsonb_array_length(a.inventory) THEN RETURN jsonb_build_object('ok',false,'raison','index_invalide'); END IF;
  o:=a.inventory->p_index;
  IF public.inventaire_objet_protege(a.quete_carriere,o) THEN RETURN jsonb_build_object('ok',false,'raison','objet_protege'); END IF;
 ELSE
  IF p_possession IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','possession_requise'); END IF;
  SELECT * INTO p FROM public.pnj_possessions WHERE id=p_possession AND pnj_id=p_pnj;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','index_invalide'); END IF;
  IF p.origine<>'socle' THEN RETURN jsonb_build_object('ok',false,'raison','objet_non_cessible'); END IF;
  o:=p.objet;
 END IF;
 IF coalesce((o->>'stackable')::boolean,false) THEN
  IF coalesce((o->>'qty')::numeric,1)<=0 OR coalesce((o->>'qty')::numeric,1)<>trunc(coalesce((o->>'qty')::numeric,1)) THEN
   RETURN jsonb_build_object('ok',false,'raison','quantite_historique_invalide'); END IF;
  disponible:=coalesce((o->>'qty')::numeric,1)::integer;
 ELSE disponible:=1; END IF;
 q:=coalesce(p_quantite,disponible);
 IF q<=0 OR q>disponible THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide'); END IF;
 IF p_sens='donner' THEN
  -- Le plafond 100 est celui des employes ; les autres metiers gardent leurs regles.
  IF m.famille='employe' THEN
   SELECT coalesce(sum(CASE WHEN (objet->>'stackable')::boolean THEN coalesce((objet->>'qty')::numeric,1) ELSE 1 END),0) INTO porte FROM public.pnj_possessions WHERE pnj_id=p_pnj;
   q:=least(q,greatest(0,100-porte));IF q=0 THEN RETURN jsonb_build_object('ok',false,'raison','charge_maximale'); END IF;
  END IF;
  inv:=CASE WHEN q=disponible THEN a.inventory-p_index ELSE jsonb_set(a.inventory,ARRAY[p_index::text,'qty'],to_jsonb(disponible-q)) END;
  IF coalesce((o->>'stackable')::boolean,false) THEN o:=o||jsonb_build_object('qty',q);END IF;
  INSERT INTO public.pnj_possessions(pnj_id,objet,origine) VALUES(p_pnj,o,'socle');
  UPDATE public.personnages_donnees SET inventory=inv WHERE name=a.name;
 ELSE
  q:=least(q,public.inventaire_place_restante(a.inventory));
  IF q=0 THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein'); END IF;
  IF coalesce((o->>'stackable')::boolean,false) THEN o:=o||jsonb_build_object('qty',q);END IF;
  d:=public.inventaire_deposer_interne(a.name,o);
  IF (d->>'ok')::boolean IS DISTINCT FROM true OR (d->>'qte')::integer<>q THEN RAISE EXCEPTION 'pnj: depot incomplet'; END IF;
  IF q=disponible THEN DELETE FROM public.pnj_possessions WHERE id=p.id;
  ELSE UPDATE public.pnj_possessions SET objet=jsonb_set(objet,'{qty}',to_jsonb(disponible-q)) WHERE id=p.id;END IF;
 END IF;
 SELECT jsonb_build_object('ok',true,'inventory',inventory,'revision',inventory_revision,'objet',o,'qte',q,'sens',p_sens) INTO v FROM public.personnages_donnees WHERE name=a.name;
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'pnj_objet',params,v,now());RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.pnj_objet_transferer(text,integer,text,integer,bigint,bigint,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pnj_objet_transferer(text,integer,text,integer,bigint,bigint,uuid) TO authenticated;
-- (Fermeture de l'ancien contrat a trois arguments : deplacee dans 20261028210000.)
-- Meme lecteur commun ; ajouter l'identifiant stable sans changer index/origine/cessible.
DO $do$
DECLARE s text; ancien text:=$a$jsonb_build_object('index', t.rang, 'objet', t.objet,$a$;
BEGIN
 s:=pg_get_functiondef('public.pnj_possessions_lire(text)'::regprocedure);
 IF position('possession_id' IN s)=0 THEN
  IF position(ancien IN s)=0 OR position('AS rang, p.objet, p.origine' IN s)=0 THEN RAISE EXCEPTION 'lecteur PNJ vivant different';END IF;
  s:=replace(s,ancien,$a$jsonb_build_object('possession_id', t.id::text, 'index', t.rang, 'objet', t.objet,$a$);
  s:=replace(s,'AS rang, p.objet, p.origine','AS rang, p.id, p.objet, p.origine');EXECUTE s;
 END IF;
END; $do$;
