-- #69 PREPAREE. Stockage prive uniquement : aucun bail ni abonnement peuple dans le DDL.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_capacite_interne(text)');IF h IS NOT NULL AND h<>'71389320ff10ff38dc8b108d2ef3c556' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_capacite_interne(text)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_verrouiller_interne(uuid,uuid,text)');IF h IS NOT NULL AND h<>'d3cd5908f54b76589aa4b7950c344a1c' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_verrouiller_interne(uuid,uuid,text)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_lire(uuid)');IF h IS NOT NULL AND h<>'7a2ac4216f08dc7a1fee89f4af8e4f65' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_lire(uuid)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_transferer(text,uuid,text,integer,jsonb,integer,bigint,bigint)');IF h IS NOT NULL AND h<>'a1bee0f485677d9325367e31c8a0185b' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_transferer(text,uuid,text,integer,jsonb,integer,bigint,bigint)';END IF;
END;$g$;
DO $marque$ BEGIN
 IF to_regclass('public.coffres_bancaires') IS NOT NULL AND obj_description(to_regclass('public.coffres_bancaires'),'pg_class') IS DISTINCT FROM 'HG69 stockage prive v1' THEN RAISE EXCEPTION 'coffres_schema_non_examine';END IF;
 IF to_regclass('public.coffres_requetes') IS NOT NULL AND obj_description(to_regclass('public.coffres_requetes'),'pg_class') IS DISTINCT FROM 'HG69 recus prives v1' THEN RAISE EXCEPTION 'coffres_recus_non_examines';END IF;
END;$marque$;

CREATE TABLE IF NOT EXISTS public.coffres_bancaires (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bail_id text NOT NULL UNIQUE REFERENCES public.locations_actives(id),
 titulaire_id uuid NOT NULL,site jsonb NOT NULL,taille text NOT NULL CHECK(taille IN('S','M','L','XL')),
 contenu jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(contenu)='array'),revision bigint NOT NULL DEFAULT 0,
 succession_id text,cree_le timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS public.coffres_requetes (
 personnage_id uuid NOT NULL,requete text NOT NULL,commande jsonb NOT NULL,resultat jsonb NOT NULL,cree_le timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(personnage_id,requete));
COMMENT ON TABLE public.coffres_bancaires IS 'HG69 stockage prive v1';
COMMENT ON TABLE public.coffres_requetes IS 'HG69 recus prives v1';
ALTER TABLE public.coffres_bancaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coffres_requetes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.coffres_bancaires,public.coffres_requetes FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.coffre_capacite_interne(p_taille text)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $f$
 SELECT CASE p_taille WHEN 'S' THEN 50 WHEN 'M' THEN 100 WHEN 'L' THEN 150 WHEN 'XL' THEN 400 END;
$f$;
CREATE OR REPLACE FUNCTION public.coffre_verrouiller_interne(p_coffre uuid,p_personnage uuid,p_nom text)
RETURNS public.coffres_bancaires LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE c public.coffres_bancaires;b jsonb;
BEGIN
 SELECT * INTO c FROM public.coffres_bancaires WHERE id=p_coffre;
 IF NOT FOUND OR c.titulaire_id IS DISTINCT FROM p_personnage THEN RAISE EXCEPTION 'coffre_inaccessible';END IF;
 SELECT data INTO b FROM public.locations_actives WHERE id=c.bail_id FOR UPDATE;
 SELECT * INTO c FROM public.coffres_bancaires WHERE id=p_coffre FOR UPDATE;
 IF c.id IS NULL OR b IS NULL OR c.titulaire_id IS DISTINCT FROM p_personnage OR NOT coalesce(b->>'locataire' IN(p_nom,'pj:'||p_nom),false) OR c.succession_id IS NOT NULL THEN RAISE EXCEPTION 'coffre_inaccessible';END IF;
 IF coalesce(b->>'country','')='' OR coalesce(b->>'city','')='' OR coalesce(b->>'buildingId','')='' OR coalesce(b->>'roomId','')='' OR
  jsonb_build_object('country',b->>'country','city',b->>'city','buildingId',b->>'buildingId','roomId',b->>'roomId') IS DISTINCT FROM c.site THEN RAISE EXCEPTION 'contrat_modifie';END IF;
 RETURN c;
END;$f$;
CREATE OR REPLACE FUNCTION public.coffre_lire(p_coffre uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE n text:=public.mon_personnage();c public.coffres_bancaires;p uuid;r jsonb;
BEGIN
 IF n IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 r:=public.inventaire_reception_etat(n);SELECT id INTO p FROM public.personnages_donnees WHERE name=n;
 c:=public.coffre_verrouiller_interne(p_coffre,p,n);
 RETURN r||jsonb_build_object('coffre',c.id,'contenu',c.contenu,'revisionCoffre',c.revision,'capacite',public.coffre_capacite_interne(c.taille),'occupation',public.inventaire_occupation_unites(c.contenu));
EXCEPTION WHEN raise_exception THEN
 IF SQLERRM IN('coffre_inaccessible','contrat_modifie') THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);END IF;RAISE;
END;$f$;
CREATE OR REPLACE FUNCTION public.coffre_transferer(p_requete text,p_coffre uuid,p_action text,p_index integer,p_signature jsonb,p_quantite integer,p_revision_inventaire bigint,p_revision_coffre bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE n text:=public.mon_personnage();pj record;c public.coffres_bancaires;contrat jsonb;avant jsonb;commande jsonb;rec record;etat jsonb;source jsonb;destination jsonb;r jsonb;nouveau_inv jsonb;nouveau_coffre jsonb;
BEGIN
 IF n IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 etat:=public.inventaire_reception_etat(n);
 SELECT * INTO pj FROM public.personnages_donnees WHERE name=n;
 IF p_requete IS NULL OR p_requete !~ '^coffre-[A-Za-z0-9-]{8,100}$' THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide');END IF;
 commande:=jsonb_build_object('coffre',p_coffre,'action',p_action,'index',p_index,'signature',p_signature,'quantite',p_quantite,'revisionInventaire',p_revision_inventaire,'revisionCoffre',p_revision_coffre);
 SELECT * INTO rec FROM public.coffres_requetes cr WHERE cr.personnage_id=pj.id AND cr.requete=p_requete;
 IF FOUND THEN
  IF rec.commande<>commande THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  RETURN jsonb_build_object('ok',true,'rejeu',true,'contrat',1,'inventory',etat->'inventory','revision',etat->'revision');
 END IF;
 c:=public.coffre_verrouiller_interne(p_coffre,pj.id,n);
 SELECT data INTO contrat FROM public.locations_actives WHERE id=c.bail_id;
 IF coalesce(contrat->>'country','')='' OR coalesce(contrat->>'city','')='' OR coalesce(contrat->>'buildingId','')='' OR coalesce(contrat->>'roomId','')='' OR
  jsonb_build_object('country',contrat->>'country','city',contrat->>'city','buildingId',contrat->>'buildingId','roomId',contrat->>'roomId') IS DISTINCT FROM c.site THEN RETURN jsonb_build_object('ok',false,'raison','contrat_modifie');END IF;
 IF pj.country IS DISTINCT FROM contrat->>'country' OR pj.current_city IS DISTINCT FROM contrat->>'city' OR pj.current_building IS DISTINCT FROM contrat->>'buildingId' OR pj.current_room IS DISTINCT FROM contrat->>'roomId' THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 IF coalesce(pj.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(n)) THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 IF p_revision_inventaire IS DISTINCT FROM (etat->>'revision')::bigint OR p_revision_coffre IS DISTINCT FROM c.revision THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_perime');END IF;
 IF p_action NOT IN('deposer','retirer') OR p_action IS NULL OR p_index IS NULL OR p_index<0 OR jsonb_typeof(p_signature) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok',false,'raison','transfert_invalide');END IF;
 source:=CASE WHEN p_action='deposer' THEN etat->'inventory' ELSE c.contenu END;
 destination:=CASE WHEN p_action='deposer' THEN c.contenu ELSE etat->'inventory' END;
 -- Pas de repli par nom sur un autre exemplaire apres une modification de l'inventaire.
 IF source->p_index IS DISTINCT FROM p_signature THEN RETURN jsonb_build_object('ok',false,'raison','objet_modifie');END IF;
 PERFORM public.inventaire_occupation_unites(source);PERFORM public.inventaire_occupation_unites(destination);
 r:=public.helvetia_inventaire_sortie(source,CASE WHEN p_action='deposer' THEN pj.quete_carriere ELSE '{}'::jsonb END,p_index,p_signature,p_quantite);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r;END IF;
 destination:=destination||(r->'objets');
 IF p_action='deposer' THEN nouveau_inv:=r->'inventory';nouveau_coffre:=destination;
 ELSE nouveau_inv:=destination;nouveau_coffre:=r->'inventory';
  IF public.inventaire_occupation_unites(nouveau_inv)>public.inventaire_place_restante('[]'::jsonb) THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein');END IF;
 END IF;
 IF public.inventaire_occupation_unites(nouveau_coffre)>public.coffre_capacite_interne(c.taille) THEN RETURN jsonb_build_object('ok',false,'raison','capacite_depassee');END IF;
 IF public.inventaire_occupation_unites(nouveau_inv)+public.inventaire_occupation_unites(nouveau_coffre)<>
  public.inventaire_occupation_unites(etat->'inventory')+public.inventaire_occupation_unites(c.contenu) THEN RAISE EXCEPTION 'transfert_non_conservatif';END IF;
 UPDATE public.personnages_donnees SET inventory=nouveau_inv,updated_at=now() WHERE id=pj.id;
 UPDATE public.coffres_bancaires SET contenu=nouveau_coffre,revision=revision+1 WHERE id=p_coffre;
 etat:=public.inventaire_reception_etat(n);
 IF etat->'inventory' IS DISTINCT FROM nouveau_inv THEN RAISE EXCEPTION 'inventaire_non_confirme';END IF;
 r:=etat||jsonb_build_object('coffre',p_coffre,'revisionCoffre',c.revision+1,'contenu',nouveau_coffre,'occupation',public.inventaire_occupation_unites(nouveau_coffre));
 INSERT INTO public.coffres_requetes(personnage_id,requete,commande,resultat) VALUES(pj.id,p_requete,commande,r-'inventory'-'contenu');
 RETURN r;
EXCEPTION WHEN raise_exception THEN
 IF SQLERRM IN('coffre_inaccessible','contrat_modifie') THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);END IF;RAISE;
END;$f$;
REVOKE ALL ON FUNCTION public.coffre_verrouiller_interne(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.coffre_lire(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coffre_lire(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.coffre_capacite_interne(text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.coffre_transferer(text,uuid,text,integer,jsonb,integer,bigint,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coffre_transferer(text,uuid,text,integer,jsonb,integer,bigint,bigint) TO authenticated;
COMMIT;
