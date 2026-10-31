-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261028204832.
-- Archivage documentaire seulement ; ne pas rejouer.
-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028204832.
-- Eprouvee au role authenticated en transaction annulee : fret : déposer, reprendre, retirer ; INSERT navigateur refusé.
-- (Preparee par Codex.) PREPAREE, NON APPLIQUEE. Suite inventaire : quatre transferts dans les caisses existantes.
-- Requiert 20261027210800/210810, et les schemas/lois/caisse du fret vivant.
-- Aucun calendrier, tarif douanier ni moteur de transport nouveau ; aucun acte reel.
CREATE OR REPLACE FUNCTION public.fret_deposer_objet_interne(p_acteur text,p_objet jsonb,p_quantite integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE d jsonb; k integer;
BEGIN
 IF p_quantite IS NULL OR p_quantite<=0 THEN RAISE EXCEPTION 'fret: quantite invalide'; END IF;
 IF coalesce((p_objet->>'stackable')::boolean,false) AND nullif(p_objet->>'stackKey','') IS NOT NULL THEN
  d:=public.inventaire_deposer_interne(p_acteur,p_objet||jsonb_build_object('qty',p_quantite));
  IF (d->>'ok')::boolean IS DISTINCT FROM true OR (d->>'qte')::integer<>p_quantite THEN RAISE EXCEPTION 'fret: depot incomplet'; END IF;
 ELSE
  IF p_quantite>1 AND nullif(p_objet->>'id','') IS NOT NULL THEN RAISE EXCEPTION 'fret: identite historique ambigue'; END IF;
  FOR k IN 1..p_quantite LOOP
   d:=public.inventaire_deposer_interne(p_acteur,p_objet);
   IF (d->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'fret: depot incomplet'; END IF;
  END LOOP;
 END IF;
 RETURN d;
END; $function$;
REVOKE ALL ON FUNCTION public.fret_deposer_objet_interne(text,jsonb,integer) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.fret_objet_agir(p_requete uuid,p_caisse uuid,p_action text,
 p_ligne uuid DEFAULT NULL,p_index integer DEFAULT NULL,p_quantite integer DEFAULT NULL,p_revision bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE a public.personnages_donnees; c public.caisses_fret; l public.contenu_caisses_fret;
 params jsonb; v jsonb; d jsonb; o jsonb; inv jsonb; q integer; total integer; prix integer; paiement jsonb;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL OR p_action IS NULL OR p_action NOT IN('deposer','reprendre','retirer','acheter') THEN
 RETURN jsonb_build_object('ok',false,'raison','commande_invalide'); END IF;
 params:=jsonb_build_object('caisse',p_caisse,'action',p_action,'ligne',p_ligne,'index',p_index,'quantite',p_quantite,'revision',p_revision);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'fret',params);IF v IS NOT NULL THEN RETURN v; END IF;
 SELECT * INTO c FROM public.caisses_fret WHERE id=p_caisse FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','caisse_introuvable'); END IF;
 -- L'entrepot est la piece de fret deja commune aux ports (ROOM_CHARGEMENT_FRET).
 IF p_action IN('deposer','reprendre') THEN
  IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM
    (c.pays_origine,c.ville_origine,c.building_origine,'entrepot') THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
  IF c.statut<>'ouverte' THEN RETURN jsonb_build_object('ok',false,'raison','caisse_fermee'); END IF;
 ELSE
  IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM
    (c.pays_destination,c.ville_destination,c.building_destination,'entrepot') THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 END IF;
 -- Caisse puis lignes dans le meme ordre pour toutes les commandes concurrentes.
 PERFORM 1 FROM public.contenu_caisses_fret WHERE caisse_id=c.id ORDER BY id FOR UPDATE;
 IF p_action='deposer' THEN
  IF a.name IS DISTINCT FROM c.leader AND NOT (a.name=ANY(c.chargeurs_autorises)) THEN RETURN jsonb_build_object('ok',false,'raison','pas_chargeur'); END IF;
  IF p_revision IS DISTINCT FROM a.inventory_revision THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_perime'); END IF;
  IF p_index IS NULL OR p_index<0 OR p_index>=jsonb_array_length(a.inventory) THEN RETURN jsonb_build_object('ok',false,'raison','index_invalide'); END IF;
  o:=a.inventory->p_index;
  IF o->>'type' IN('acte_officiel','colis_secret_pat','relique') OR o->>'id'='cle-debarras-musee'
   OR coalesce((o->>'calepinEnigme1')::boolean,false) OR o->>'id' LIKE 'fiche-etat-civil-%' THEN RETURN jsonb_build_object('ok',false,'raison','objet_non_cessible'); END IF;
  IF coalesce((o->>'stackable')::boolean,false) AND (coalesce((o->>'qty')::numeric,1)<=0 OR coalesce((o->>'qty')::numeric,1)<>trunc(coalesce((o->>'qty')::numeric,1))) THEN RETURN jsonb_build_object('ok',false,'raison','quantite_historique_invalide'); END IF;
  q:=CASE WHEN coalesce((o->>'stackable')::boolean,false) THEN coalesce((o->>'qty')::numeric,1)::integer ELSE 1 END;
  IF p_quantite IS NULL OR p_quantite<=0 OR p_quantite>q THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide'); END IF;
  SELECT coalesce(sum(quantite),0) INTO total FROM public.contenu_caisses_fret WHERE caisse_id=c.id;
  IF total+p_quantite>500 THEN RETURN jsonb_build_object('ok',false,'raison','caisse_pleine'); END IF;
  inv:=CASE WHEN q=p_quantite THEN a.inventory-p_index ELSE jsonb_set(a.inventory,ARRAY[p_index::text,'qty'],to_jsonb(q-p_quantite)) END;
  INSERT INTO public.contenu_caisses_fret(caisse_id,deposant,objet,quantite) VALUES(c.id,a.name,o-'qty',p_quantite);
  UPDATE public.personnages_donnees SET inventory=inv WHERE name=a.name;
  q:=p_quantite;
 ELSIF p_action IN('reprendre','retirer') THEN
  SELECT * INTO l FROM public.contenu_caisses_fret WHERE id=p_ligne AND caisse_id=c.id;
  IF NOT FOUND OR l.quantite<=0 THEN RETURN jsonb_build_object('ok',false,'raison','ligne_indisponible'); END IF;
  IF p_action='reprendre' THEN
   IF l.deposant IS DISTINCT FROM a.name THEN RETURN jsonb_build_object('ok',false,'raison','pas_deposant'); END IF;
   q:=l.quantite;
  ELSE
   IF c.statut<>'arrivee' OR NOT c.dedouanee THEN RETURN jsonb_build_object('ok',false,'raison','caisse_non_dedouanee'); END IF;
   IF c.destinataire IS DISTINCT FROM a.name AND NOT(a.name=ANY(c.receptionnaires_autorises)) THEN RETURN jsonb_build_object('ok',false,'raison','pas_receptionnaire'); END IF;
   IF p_quantite IS NULL OR p_quantite<=0 THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide'); END IF;
   q:=least(l.quantite,p_quantite);
  END IF;
  IF public.inventaire_place_restante(a.inventory)<q THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein'); END IF;
  IF p_action='retirer' THEN
   paiement:=public.payer_ordre(a.name,'receptionner_commande',1,0);
   IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement; END IF;
  END IF;
  d:=public.fret_deposer_objet_interne(a.name,l.objet,q);
  UPDATE public.contenu_caisses_fret SET quantite=quantite-q WHERE id=l.id;
  IF p_action='retirer' AND NOT EXISTS(SELECT 1 FROM public.contenu_caisses_fret WHERE caisse_id=c.id AND quantite>0) THEN
   UPDATE public.caisses_fret SET statut='videe' WHERE id=c.id;
  END IF;
 ELSE
  IF c.statut<>'a_vendre' THEN RETURN jsonb_build_object('ok',false,'raison','lot_indisponible'); END IF;
  SELECT coalesce(sum(quantite),0) INTO total FROM public.contenu_caisses_fret WHERE caisse_id=c.id AND quantite>0;
  IF total<=0 THEN RETURN jsonb_build_object('ok',false,'raison','lot_vide'); END IF;
  IF public.inventaire_place_restante(a.inventory)<total THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein'); END IF;
  SELECT public.assemblee_verifier_vente(jsonb_agg(objet),a.country) INTO v FROM public.contenu_caisses_fret WHERE caisse_id=c.id AND quantite>0;
  IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RETURN v; END IF;
  prix:=round(coalesce(c.valeur_declaree,0)*(total::numeric/coalesce(nullif(c.quantite_arrivee,0),total))*0.5);
  IF prix<0 THEN RETURN jsonb_build_object('ok',false,'raison','valeur_invalide'); END IF;
  IF NOT public.helvetia_debiter_fonds_ordinaires(a.name,prix) THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants'); END IF;
  IF prix>0 THEN
   -- 28/10/2026 (Claude) : la caisse du port est creee si besoin, comme pour les autres recettes.
   PERFORM set_config('rp.caisse_interne','on',true);
   v:=public.caisse_institution_mouvement(c.pays_destination||'_'||c.building_destination,prix,false);
   PERFORM set_config('rp.caisse_interne','',true);
   IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'fret: caisse port refusee'; END IF;
  END IF;
  FOR l IN SELECT * FROM public.contenu_caisses_fret WHERE caisse_id=c.id AND quantite>0 ORDER BY id LOOP
   d:=public.fret_deposer_objet_interne(a.name,l.objet,l.quantite);
   UPDATE public.contenu_caisses_fret SET quantite=0 WHERE id=l.id;
  END LOOP;
  UPDATE public.caisses_fret SET statut='vendue' WHERE id=c.id;q:=total;
 END IF;
 SELECT jsonb_build_object('ok',true,'inventory',inventory,'revision',inventory_revision,'qte',q,'prix',coalesce(prix,0),
  'paie',jsonb_build_object('pa',pa,'arg',arg,'liquide',liquide,'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0)))
 INTO v FROM public.personnages_donnees WHERE name=a.name;
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'fret',params,v,now());RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.fret_objet_agir(uuid,uuid,text,uuid,integer,integer,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fret_objet_agir(uuid,uuid,text,uuid,integer,integer,bigint) TO authenticated;

-- Le contenu ne peut plus etre fabrique/augmente par un PATCH ou INSERT du navigateur.
-- La diminution douaniere historique reste utilisable tant que ce circuit est legacy.
CREATE OR REPLACE FUNCTION public.fret_contenu_source_garder() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
BEGIN
 IF NOT public.est_appel_serveur() AND coalesce(current_setting('request.path',true),'')<>'/rpc/fret_objet_agir' THEN
  IF TG_OP='INSERT' THEN RAISE EXCEPTION 'fret: depot serveur requis' USING ERRCODE='42501'; END IF;
  IF (to_jsonb(NEW)-'quantite') IS DISTINCT FROM (to_jsonb(OLD)-'quantite') OR NEW.quantite IS NULL OR NEW.quantite<0 OR NEW.quantite>OLD.quantite THEN
   RAISE EXCEPTION 'fret: contenu forge refuse' USING ERRCODE='42501'; END IF;
 END IF;
 RETURN NEW;
END; $function$;
REVOKE ALL ON FUNCTION public.fret_contenu_source_garder() FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE TRIGGER hg_fret_contenu_source BEFORE INSERT OR UPDATE ON public.contenu_caisses_fret
 FOR EACH ROW EXECUTE FUNCTION public.fret_contenu_source_garder();
