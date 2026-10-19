-- PREPARE : catalogue vivant, ACL et garde de direction a verifier avant application.
-- Aucun debit neuf, aucun peuplement d'objets ou de soldes historiques.
BEGIN;
DO $versions$
DECLARE v text; r record;
BEGIN
 -- Les anciennes policies autorisent tout acteur identifie a ecrire le blob.
 -- Tant que ces mutations ne passent pas par des RPC controlees, chef/tresorier
 -- et caisse ne constituent pas une autorite suffisante pour les nouveaux biens.
 IF has_column_privilege('authenticated','public.organisations','data','UPDATE')
    OR has_column_privilege('anon','public.organisations','data','UPDATE') THEN
  RAISE EXCEPTION 'organisations_autorite_generale_a_migrer';
 END IF;
 FOREACH v IN ARRAY ARRAY['organisation_objets','organisation_equipements_actes','organisation_equipements_journal','equipements_capacites'] LOOP
  IF to_regclass('public.'||v) IS NOT NULL AND obj_description(to_regclass('public.'||v),'pg_class') IS DISTINCT FROM 'HG equipements collectifs v1' THEN
   RAISE EXCEPTION 'schema_equipements_inconnu: %',v;
  END IF;
 END LOOP;
 FOR r IN SELECT * FROM (VALUES ('organisation_equipement_exiger','7a310d44e1c876b9c343c6471909e52a'),('organisation_equipement_exiger_caisse','aba7d741115acb32ba99a83719bca3c5'),('organisation_direction_garder','af05a07ae530b9a57be92a3e71c7e7d2'),('organisation_livraison_integrer','079f1581cdd2ea99191b193f5672bdff'),('organisation_vente_receptionner','fe8e0758f62f76385cdad25b3084802c'),('organisation_equipement_reclamer','d04f6145a9598c1f5e40885a4cb8783c'),('organisation_equipements_etat','72bea4328bac9e6d2b8d612b69aeb937'),('organisation_equipement_deplacer','c354cbf4aaba7b1276295a9667a1a2f8'),('organisation_equipements_payeurs','da5ed3e76a6089c34caab385592acb38'),('organisation_capacite_exiger','f263f7e569200c4012c43aebd8c3d429')) x(nom,empreinte) LOOP
  IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname=r.nom AND md5(p.prosrc)<>r.empreinte) THEN
   RAISE EXCEPTION 'fonction_equipements_divergente: %',r.nom;
  END IF;
 END LOOP;
END;
$versions$;
CREATE TABLE IF NOT EXISTS public.organisation_objets (
 id text PRIMARY KEY,
 organisation text NOT NULL REFERENCES public.organisations(id) ON DELETE RESTRICT,
 objet jsonb NOT NULL CHECK(jsonb_typeof(objet)='object'),
 pays text, ville text, local_id text,
 recue_le timestamptz NOT NULL DEFAULT now(),
 CHECK ((local_id IS NULL AND pays IS NULL AND ville IS NULL) OR
        (local_id IS NOT NULL AND pays IS NOT NULL AND ville IS NOT NULL))
);
CREATE TABLE IF NOT EXISTS public.organisation_equipements_actes (
 requete text PRIMARY KEY, acteur text NOT NULL, commande jsonb NOT NULL,
 verdict jsonb NOT NULL, cree_le timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.organisation_equipements_journal (
 id bigserial PRIMARY KEY, objet_id text NOT NULL, acteur text,
 source text NOT NULL, destination text NOT NULL, action text NOT NULL,
 lieu jsonb, cree_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.organisation_objets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organisation_equipements_actes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organisation_equipements_journal ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.organisation_objets,public.organisation_equipements_actes,public.organisation_equipements_journal FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE public.organisation_equipements_journal_id_seq FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.organisation_equipement_exiger(p_organisation text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE v_nom text; v_data jsonb;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 SELECT data::jsonb INTO v_data FROM public.organisations WHERE id=p_organisation FOR UPDATE;
 IF NOT FOUND OR v_data->>'chef' IS DISTINCT FROM v_nom THEN
  RAISE EXCEPTION 'representation_organisation_refusee' USING ERRCODE='42501';
 END IF;
 RETURN v_data;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_equipement_exiger(text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.organisation_equipement_exiger_caisse(p_organisation text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE v_nom text; v_data jsonb; v_gestionnaire text;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 SELECT data::jsonb INTO v_data FROM public.organisations WHERE id=p_organisation FOR UPDATE;
 v_gestionnaire:=coalesce(nullif(btrim(v_data->>'tresorier'),''),v_data->>'chef');
 IF NOT FOUND OR v_gestionnaire IS DISTINCT FROM v_nom THEN
  RAISE EXCEPTION 'gestionnaire_caisse_refuse' USING ERRCODE='42501'; END IF;
 RETURN v_data;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_equipement_exiger_caisse(text) FROM PUBLIC,anon,authenticated;

-- Les policies historiques permettent trop d'UPDATE : elles ne suffisent pas a
-- garantir l'identite du chef. Garde minimale commune, sans modifier les autres champs.
CREATE OR REPLACE FUNCTION public.organisation_direction_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE v_av jsonb:=OLD.data::jsonb; v_ap jsonb:=NEW.data::jsonb;
 v_nom text; v_vainqueur text; v_jour integer;
BEGIN
 IF public.est_appel_serveur() THEN RETURN NEW; END IF;
 v_nom:=public.mon_personnage();
 IF v_av->>'chef' IS NOT DISTINCT FROM v_nom THEN RETURN NEW; END IF;
 IF v_av->>'tresorier' IS DISTINCT FROM v_ap->>'tresorier' THEN
  RAISE EXCEPTION 'transmission_tresorerie_non_autorisee' USING ERRCODE='42501'; END IF;
 IF v_av->>'chef' IS DISTINCT FROM v_ap->>'chef' THEN
  -- Preserve le depouillement historique par un autre joueur : resultat des votes
  -- DEJA enregistres, ordre des candidatures comme departage, aucune valeur du client.
  SELECT day INTO v_jour FROM public.personnages_donnees WHERE name=v_nom;
  IF coalesce((v_av->'election'->>'enCours')::boolean,false) IS NOT TRUE OR
     v_av->'election'->>'phase' IS DISTINCT FROM 'vote' OR
     v_jour IS NULL OR v_jour < (v_av->'election'->>'dateFinVote')::integer OR
     v_av->'election'->>'dateFinVote' IS NULL THEN
   RAISE EXCEPTION 'transmission_direction_non_autorisee' USING ERRCODE='42501'; END IF;
  SELECT c.value->>'nom' INTO v_vainqueur
   FROM jsonb_array_elements(coalesce(v_av->'election'->'candidats','[]'::jsonb)) WITH ORDINALITY c(value,ordre)
   ORDER BY (SELECT count(*) FROM jsonb_each_text(coalesce(v_av->'election'->'votes','{}'::jsonb)) v WHERE v.value=c.value->>'nom') DESC,c.ordre
   LIMIT 1;
  IF v_vainqueur IS NULL OR v_ap->>'chef' IS DISTINCT FROM v_vainqueur OR NOT EXISTS
    (SELECT 1 FROM jsonb_array_elements(coalesce(v_av->'membres','[]'::jsonb)) m WHERE m->>'nom'=v_vainqueur) THEN
   RAISE EXCEPTION 'transmission_direction_non_autorisee' USING ERRCODE='42501'; END IF;
 END IF;
 RETURN NEW;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_direction_garder() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_organisation_direction_equipements ON public.organisations;
CREATE TRIGGER trg_organisation_direction_equipements BEFORE UPDATE ON public.organisations
FOR EACH ROW EXECUTE FUNCTION public.organisation_direction_garder();

CREATE OR REPLACE FUNCTION public.organisation_livraison_integrer(p_livraison text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE v_l public.objets_recus%ROWTYPE; v_vente public.ventes_snapshots%ROWTYPE;
 v_obj jsonb; v_org text; v_individuel boolean; v_index text;
BEGIN
 IF EXISTS(SELECT 1 FROM public.organisation_objets WHERE id=p_livraison) THEN
  RETURN jsonb_build_object('ok',true,'deja_recue',true);
 END IF;
 SELECT * INTO v_l FROM public.objets_recus WHERE id=p_livraison FOR UPDATE;
 IF NOT FOUND OR left(v_l.destinataire,5)<>'orga:' THEN
  RAISE EXCEPTION 'livraison_organisation_absente';
 END IF;
 v_org:=substr(v_l.destinataire,6);
 PERFORM 1 FROM public.organisations WHERE id=v_org FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'organisation_absente'; END IF;
 v_obj:=CASE WHEN jsonb_typeof(v_l.data)='string' THEN (v_l.data#>>'{}')::jsonb ELSE v_l.data END;
 IF jsonb_typeof(v_obj) IS DISTINCT FROM 'object' OR coalesce(v_obj->>'qty','') !~ '^[1-9][0-9]{0,5}$' THEN RAISE EXCEPTION 'objet_invalide'; END IF;
 SELECT * INTO v_vente FROM public.ventes_snapshots
 WHERE acheteur='orga:'||v_org AND fonds_id=v_obj->'provenance'->>'fondsId'
 AND reference_id=v_obj->'provenance'->>'referenceId'
 AND generique_id=v_obj->>'generique_id'
 AND (p_livraison=requete OR left(p_livraison,length(requete)+1)=requete||'-')
 ORDER BY length(requete) DESC LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'preuve_achat_organisation_absente'; END IF;
 SELECT individualise INTO v_individuel FROM public.catalogue_generiques WHERE id=v_vente.generique_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'generique_absent'; END IF;
 IF v_individuel THEN
  v_index:=substr(p_livraison,length(v_vente.requete)+2);
  IF v_index !~ '^[1-9][0-9]{0,5}$' OR v_index::integer>v_vente.quantite
     OR p_livraison<>v_vente.requete||'-'||v_index OR (v_obj->>'qty')::integer<>1 THEN
    RAISE EXCEPTION 'exemplaire_achat_invalide';
  END IF;
 ELSE
  IF p_livraison<>v_vente.requete OR (v_obj->>'qty')::integer IS DISTINCT FROM v_vente.quantite THEN
   RAISE EXCEPTION 'quantite_achat_invalide';
  END IF;
 END IF;
 INSERT INTO public.organisation_objets(id,organisation,objet) VALUES(p_livraison,v_org,v_obj);
 INSERT INTO public.organisation_equipements_journal(objet_id,acteur,source,destination,action)
 VALUES(p_livraison,public.mon_personnage(),'livraison:'||p_livraison,'orga:'||v_org,'reception');
 DELETE FROM public.objets_recus WHERE id=p_livraison;
 RETURN jsonb_build_object('ok',true,'deja_recue',false,'proprietaire','orga:'||v_org);
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_livraison_integrer(text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.organisation_vente_receptionner()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE v_id text;
BEGIN
 IF left(NEW.acheteur,5)<>'orga:' THEN RETURN NEW; END IF;
 FOR v_id IN SELECT id FROM public.objets_recus WHERE destinataire=NEW.acheteur
 AND (id=NEW.requete OR left(id,length(NEW.requete)+1)=NEW.requete||'-') ORDER BY id
 LOOP PERFORM public.organisation_livraison_integrer(v_id); END LOOP;
 IF (SELECT coalesce(sum((objet->>'qty')::integer),0) FROM public.organisation_objets
     WHERE organisation=substr(NEW.acheteur,6) AND
     (id=NEW.requete OR left(id,length(NEW.requete)+1)=NEW.requete||'-'))<>NEW.quantite THEN
  RAISE EXCEPTION 'livraison_collective_incomplete';
 END IF;
 RETURN NEW;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_vente_receptionner() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_organisation_vente_reception ON public.ventes_snapshots;
CREATE TRIGGER trg_organisation_vente_reception AFTER INSERT ON public.ventes_snapshots
FOR EACH ROW EXECUTE FUNCTION public.organisation_vente_receptionner();

CREATE OR REPLACE FUNCTION public.organisation_equipement_reclamer(p_organisation text,p_livraison text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
BEGIN
 PERFORM public.organisation_equipement_exiger(p_organisation);
 IF EXISTS(SELECT 1 FROM public.organisation_objets WHERE id=p_livraison) THEN
  -- Un ancien destinataire ne peut pas reprendre un objet deja transfere.
  RETURN jsonb_build_object('ok',true,'deja_recue',true);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.objets_recus WHERE id=p_livraison AND destinataire='orga:'||p_organisation) THEN
  RAISE EXCEPTION 'livraison_non_autorisee' USING ERRCODE='42501';
 END IF;
 RETURN public.organisation_livraison_integrer(p_livraison);
END;
$f$;

CREATE TABLE IF NOT EXISTS public.equipements_capacites (
 generique_id text NOT NULL REFERENCES public.catalogue_generiques(id),
 capacite text NOT NULL, PRIMARY KEY(generique_id,capacite)
);
ALTER TABLE public.equipements_capacites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.equipements_capacites FROM PUBLIC,anon,authenticated;
-- Catalogue existant uniquement : ne recree aucun article.
INSERT INTO public.equipements_capacites(generique_id,capacite)
SELECT v.g,v.c FROM (VALUES
 ('ordinateur-complet','ordinateur'),('box-internet','internet'),
 ('camera-de-surveillance','camera'),('imprimante-papier','papier'),
 ('imprimante-3d','fabrication3d'),('peripherique-stockage','stockage'),
 ('peripherique-reseau-intranet','intranet')) v(g,c)
JOIN public.catalogue_generiques g ON g.id=v.g ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.organisation_equipements_etat(p_organisation text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE v_o jsonb; v_counts jsonb; v_pc boolean; v_items jsonb;
BEGIN
 v_o:=public.organisation_equipement_exiger(p_organisation);
 SELECT coalesce(jsonb_object_agg(capacite,n),'{}'::jsonb) INTO v_counts FROM (
  SELECT c.capacite,sum((e.objet->>'qty')::integer) AS n FROM public.organisation_objets e
  JOIN public.equipements_capacites c ON c.generique_id=e.objet->>'generique_id'
  WHERE e.organisation=p_organisation AND e.local_id=v_o->>'localId' AND e.ville=v_o->>'city'
    AND e.pays=v_o->>'country_origine' GROUP BY c.capacite) z;
 v_pc:=coalesce((v_counts->>'ordinateur')::integer,0)>0;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'objet',objet,'localId',local_id,'pays',pays,'ville',ville) ORDER BY id),'[]'::jsonb)
 INTO v_items FROM public.organisation_objets WHERE organisation=p_organisation;
 RETURN jsonb_build_object('ok',true,'proprietaire','orga:'||p_organisation,'objets',v_items,'equipements',v_counts,
 'capacites',jsonb_build_object(
 'commerce_international',v_pc AND coalesce((v_counts->>'internet')::integer,0)>0,
 'piratage',v_pc AND coalesce((v_counts->>'internet')::integer,0)>0,
 'surveillance',v_pc AND coalesce((v_counts->>'camera')::integer,0)>0,
 'protection_intranet',v_pc AND coalesce((v_counts->>'intranet')::integer,0)>0,
 'impression_papier',v_pc AND coalesce((v_counts->>'papier')::integer,0)>0,
 'impression_3d',v_pc AND coalesce((v_counts->>'fabrication3d')::integer,0)>0));
END;
$f$;

CREATE OR REPLACE FUNCTION public.organisation_equipement_deplacer(p_requete text,p_organisation text,p_objet text,p_action text,p_destination text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE v_o jsonb; v_item public.organisation_objets%ROWTYPE; v_pj public.personnages_donnees%ROWTYPE;
 v_ancien public.organisation_equipements_actes%ROWTYPE; v_payload jsonb; v_id text; v_ret jsonb;
BEGIN
 IF p_requete IS NULL OR p_requete !~ '^equip-[A-Za-z0-9-]{6,100}$' OR p_action IS NULL OR p_organisation IS NULL OR p_objet IS NULL OR p_action NOT IN ('installer','retirer','transferer') THEN
  RAISE EXCEPTION 'commande_equipement_invalide'; END IF;
 IF p_action<>'transferer' AND p_destination IS NOT NULL THEN RAISE EXCEPTION 'destination_inattendue'; END IF;
 IF p_action='transferer' AND (p_destination IS NULL OR p_destination=p_organisation) THEN RAISE EXCEPTION 'destination_invalide'; END IF;
 -- Verrouillage canonique des organisations avant celui de l'objet.
 FOR v_id IN SELECT DISTINCT x FROM unnest(ARRAY[p_organisation,p_destination]) x WHERE x IS NOT NULL ORDER BY x LOOP
  PERFORM public.organisation_equipement_exiger(v_id);
 END LOOP;
 v_o:=public.organisation_equipement_exiger(p_organisation);
 v_payload:=jsonb_build_array(p_organisation,p_objet,p_action,p_destination);
 -- Serialise aussi la cle de requete lorsqu'elle est reutilisee dans une autre organisation.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_requete,0));
 SELECT * INTO v_ancien FROM public.organisation_equipements_actes WHERE requete=p_requete;
 IF FOUND THEN
  IF v_ancien.acteur IS DISTINCT FROM public.mon_personnage() OR v_ancien.commande<>v_payload THEN RAISE EXCEPTION 'requete_reutilisee'; END IF;
  RETURN v_ancien.verdict;
 END IF;
 SELECT * INTO v_item FROM public.organisation_objets WHERE id=p_objet AND organisation=p_organisation FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'objet_non_possede'; END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees WHERE name=public.mon_personnage();
 IF p_action='installer' THEN
  IF v_item.local_id IS NOT NULL OR nullif(v_o->>'localId','') IS NULL OR
     v_pj.country IS DISTINCT FROM v_o->>'country_origine' OR v_pj.current_city IS DISTINCT FROM v_o->>'city' OR
     v_pj.current_building||':'||v_pj.current_room IS DISTINCT FROM v_o->>'localId' THEN
    RAISE EXCEPTION 'installation_hors_local'; END IF;
  UPDATE public.organisation_objets SET pays=v_pj.country,ville=v_pj.current_city,local_id=v_o->>'localId' WHERE id=p_objet;
 ELSE
  IF v_item.local_id IS NOT NULL AND (v_pj.country IS DISTINCT FROM v_item.pays OR v_pj.current_city IS DISTINCT FROM v_item.ville OR
     v_pj.current_building||':'||v_pj.current_room IS DISTINCT FROM v_item.local_id) THEN RAISE EXCEPTION 'retrait_hors_local'; END IF;
  IF p_action='transferer' AND v_item.local_id IS NOT NULL THEN RAISE EXCEPTION 'retirer_avant_transfert'; END IF;
  UPDATE public.organisation_objets SET pays=NULL,ville=NULL,local_id=NULL,
   organisation=CASE WHEN p_action='transferer' THEN p_destination ELSE p_organisation END WHERE id=p_objet;
 END IF;
 INSERT INTO public.organisation_equipements_journal(objet_id,acteur,source,destination,action,lieu)
 VALUES(p_objet,public.mon_personnage(),'orga:'||p_organisation,'orga:'||coalesce(p_destination,p_organisation),p_action,
 jsonb_build_object('pays',v_pj.country,'ville',v_pj.current_city,'local',v_o->>'localId'));
 v_ret:=jsonb_build_object('ok',true,'objet',p_objet,'action',p_action,'proprietaire','orga:'||coalesce(p_destination,p_organisation));
 INSERT INTO public.organisation_equipements_actes(requete,acteur,commande,verdict) VALUES(p_requete,public.mon_personnage(),v_payload,v_ret);
 RETURN v_ret;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_equipement_reclamer(text,text),public.organisation_equipements_etat(text),public.organisation_equipement_deplacer(text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.organisation_equipement_reclamer(text,text),public.organisation_equipements_etat(text),public.organisation_equipement_deplacer(text,text,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.organisation_equipements_payeurs()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE v_nom text; v_orgs jsonb;
BEGIN
 v_nom:=public.mon_personnage();
 IF v_nom IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'nom',data::jsonb->>'nom') ORDER BY id),'[]'::jsonb)
 INTO v_orgs FROM public.organisations
 WHERE coalesce(nullif(btrim(data::jsonb->>'tresorier'),''),data::jsonb->>'chef')=v_nom;
 RETURN jsonb_build_object('ok',true,'achats',to_regprocedure('public.organisation_equipement_acheter(text,text,text,text,integer)') IS NOT NULL,
 'organisations',v_orgs);
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_equipements_payeurs() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.organisation_equipements_payeurs() TO authenticated;

CREATE OR REPLACE FUNCTION public.organisation_capacite_exiger(p_organisation text,p_capacite text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public','pg_temp' AS $f$
DECLARE v_etat jsonb;
BEGIN
 v_etat:=public.organisation_equipements_etat(p_organisation);
 IF coalesce((v_etat->'capacites'->>p_capacite)::boolean,false) IS NOT TRUE THEN
  RAISE EXCEPTION 'configuration_informatique_absente'; END IF;
 RETURN v_etat;
END;
$f$;
REVOKE ALL ON FUNCTION public.organisation_capacite_exiger(text,text) FROM PUBLIC,anon,authenticated;

COMMENT ON TABLE public.organisation_objets IS 'HG equipements collectifs v1';
COMMENT ON TABLE public.organisation_equipements_actes IS 'HG equipements collectifs v1';
COMMENT ON TABLE public.organisation_equipements_journal IS 'HG equipements collectifs v1';
COMMENT ON TABLE public.equipements_capacites IS 'HG equipements collectifs v1';
COMMIT;
