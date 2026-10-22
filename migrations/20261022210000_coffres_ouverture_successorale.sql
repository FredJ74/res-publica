-- #69/#95 PREPAREE : photographie privee du vrai titulaire, dans l'ouverture commune.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffres_succession_ouvrir()');IF h IS NOT NULL AND h NOT IN('d1da21f9c2a6325d8c74b5bbe59f7429') THEN RAISE EXCEPTION 'definition_non_examinee: coffres_succession_ouvrir()';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffres_suppression_garder()');IF h IS NOT NULL AND h NOT IN('83a43c61e2f5be91ad6aaeac028cac8f','18fe81303c601ac9ae88c3975425d594') THEN RAISE EXCEPTION 'definition_non_examinee: coffres_suppression_garder()';END IF;
END $g$;
DO $$BEGIN
 IF has_table_privilege('authenticated','public.successions','UPDATE') THEN RAISE EXCEPTION 'autorite_successorale_non_securisee';END IF;
END$$;
CREATE TABLE IF NOT EXISTS public.coffres_sources_successorales(
 coffre uuid PRIMARY KEY,dossier text NOT NULL REFERENCES public.successions(id),defunt_id uuid NOT NULL,defunt_nom text NOT NULL);
ALTER TABLE public.coffres_sources_successorales ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.coffres_sources_successorales FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.coffres_succession_ouvrir()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE pj public.personnages_donnees;c public.coffres_bancaires;testament jsonb;legs jsonb;chaine jsonb;benef text;rempl text;conjoint text;rol text;
BEGIN
 SELECT * INTO pj FROM public.personnages_donnees WHERE name=NEW.defunt FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'defunt_introuvable';END IF;
 IF NOT public.est_appel_serveur() AND (pj.user_id IS DISTINCT FROM auth.uid() OR public.mon_personnage() IS DISTINCT FROM pj.name) THEN RAISE EXCEPTION 'defunt_non_possede' USING ERRCODE='42501';END IF;
 IF NEW.country IS DISTINCT FROM pj.country THEN RAISE EXCEPTION 'pays_successoral_incoherent';END IF;
 SELECT contenu INTO testament FROM public.testaments WHERE id=NEW.testament_id AND testateur=pj.name AND statut='actif';
 SELECT CASE WHEN conjoint1=pj.name THEN conjoint2 ELSE conjoint1 END INTO conjoint FROM public.mariages
  WHERE statut='actif' AND (conjoint1=pj.name OR conjoint2=pj.name) ORDER BY created_at DESC LIMIT 1;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=conjoint) THEN conjoint:=NULL;END IF;
 -- Un coffre envoye par le navigateur n'est jamais une preuve de propriete.
 NEW.dispositions:=coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements(NEW.dispositions) x WHERE x->>'type' IS DISTINCT FROM 'coffre'),'[]');
 FOR c IN SELECT * FROM public.coffres_bancaires WHERE titulaire_id=pj.id ORDER BY id FOR UPDATE LOOP
  IF c.succession_id IS NOT NULL THEN RAISE EXCEPTION 'coffre_deja_gele';END IF;
  SELECT x INTO legs FROM jsonb_array_elements(coalesce(testament->'biens','[]')) x WHERE x->>'id'=c.id::text;
  benef:=NULL;rempl:=nullif(legs->>'remplacant','');rol:=NULL;chaine:='[]';
  IF EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=legs->>'beneficiaire') THEN benef:=legs->>'beneficiaire';rol:='principal';
  ELSIF EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=rempl) THEN benef:=rempl;rol:='remplacant';
  ELSIF conjoint IS NOT NULL THEN benef:=conjoint;rol:='legal_conjoint';END IF;
  IF benef IS NOT NULL THEN chaine:=jsonb_build_array(jsonb_build_object('beneficiaire',benef,'beneficiaire_id',(SELECT id FROM public.personnages_donnees WHERE name=benef),'role',rol,'reponse',NULL,'repondu_le',NULL,'convoque_le',statement_timestamp(),'expires_at',statement_timestamp()+interval '10 days'));END IF;
  INSERT INTO public.coffres_sources_successorales VALUES(c.id,NEW.id,pj.id,pj.name);
  UPDATE public.coffres_bancaires SET succession_id=NEW.id,revision=revision+1 WHERE id=c.id;
  NEW.dispositions:=NEW.dispositions||jsonb_build_array(jsonb_build_object('id',c.id::text,'type','coffre','libelle','Coffre bancaire '||c.taille,'remplacant_prevu',rempl,'chaine',chaine,'etat','en_attente','resultat',NULL,'regle',false));
 END LOOP;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION public.coffres_succession_ouvrir() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS coffres_ouverture_successorale ON public.successions;
CREATE TRIGGER coffres_ouverture_successorale BEFORE INSERT ON public.successions FOR EACH ROW EXECUTE FUNCTION public.coffres_succession_ouvrir();
-- FK deferrable car la photographie est creee par le BEFORE INSERT du dossier.
ALTER TABLE public.coffres_sources_successorales DROP CONSTRAINT IF EXISTS coffres_sources_successorales_dossier_fkey;
ALTER TABLE public.coffres_sources_successorales ADD CONSTRAINT coffres_sources_successorales_dossier_fkey FOREIGN KEY(dossier) REFERENCES public.successions(id) DEFERRABLE INITIALLY DEFERRED;
CREATE OR REPLACE FUNCTION public.coffres_suppression_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
BEGIN
 IF EXISTS(SELECT 1 FROM public.coffres_bancaires c WHERE c.titulaire_id=OLD.id AND NOT EXISTS(
  SELECT 1 FROM public.coffres_sources_successorales p JOIN public.successions s ON s.id=p.dossier
   WHERE p.coffre=c.id AND p.defunt_id=OLD.id AND p.defunt_nom=OLD.name AND c.succession_id=s.id AND s.statut='en_attente')) THEN
  RAISE EXCEPTION 'coffres_succession_non_preparee';END IF;
 RETURN OLD;
END $f$;
REVOKE ALL ON FUNCTION public.coffres_suppression_garder() FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
