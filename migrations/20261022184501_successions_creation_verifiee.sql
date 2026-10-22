-- #95 PREPAREE : un dossier initial n'est pas une autorisation d'inventer une creance.
-- Ne remplace pas la reservation des fonds au deces : cette dependance reste a verifier.
BEGIN;
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.succession_creation_garder()');IF h IS NOT NULL AND h<>'d138ea97766dd29da2480c7baa864b43' THEN RAISE EXCEPTION 'definition_non_examinee: succession_creation_garder()';END IF;END $g$;
CREATE OR REPLACE FUNCTION public.succession_creation_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE pj public.personnages_donnees;total numeric;droits numeric;part_etat numeric;somme numeric:=0;d jsonb;t jsonb;
BEGIN
 SELECT * INTO pj FROM public.personnages_donnees WHERE name=NEW.defunt FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'defunt_introuvable';END IF;
 IF public.est_appel_serveur() IS DISTINCT FROM true AND (pj.name IS DISTINCT FROM public.mon_personnage() OR pj.user_id IS DISTINCT FROM auth.uid()) THEN RAISE EXCEPTION 'defunt_non_possede' USING ERRCODE='42501';END IF;
 IF NEW.country IS DISTINCT FROM pj.country OR NEW.statut<>'en_attente' OR NEW.part_etat_reglee OR NEW.part_notaire_reglee OR NEW.resolved_at IS NOT NULL THEN RAISE EXCEPTION 'dossier_initial_invalide';END IF;
 PERFORM 1 FROM public.comptes_bancaires WHERE personnage=pj.name ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.comptes_bancaires WHERE personnage=pj.name AND (solde<0 OR solde<>trunc(solde) OR solde::text IN('NaN','Infinity','-Infinity'))) THEN RAISE EXCEPTION 'solde_successoral_non_representable';END IF;
 SELECT coalesce(sum(solde),0) INTO total FROM public.comptes_bancaires WHERE personnage=pj.name;
 droits:=floor(total*0.33);part_etat:=floor(droits*0.90);
 IF NEW.argent_brut_total<>total OR NEW.droits_total<>droits OR NEW.part_etat<>part_etat OR NEW.part_notaire<>droits-part_etat OR NEW.argent_net_total<>total-droits THEN RAISE EXCEPTION 'photographie_financiere_incoherente';END IF;
 IF jsonb_typeof(NEW.dispositions)<>'array' THEN RAISE EXCEPTION 'dispositions_invalides';END IF;
 FOR d IN SELECT value FROM jsonb_array_elements(NEW.dispositions) LOOP
  IF coalesce((d->>'regle')::boolean,false) OR (d->'resultat' IS NOT NULL AND d->'resultat'<>'null'::jsonb) OR coalesce(d->>'etat','en_attente')<>'en_attente' THEN RAISE EXCEPTION 'decision_initiale_forgee';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(d->'chaine','[]')) e WHERE e->>'reponse' IS NOT NULL) THEN RAISE EXCEPTION 'reponse_initiale_forgee';END IF;
  IF d->>'type'='argent' THEN
   IF d->>'part_nette' IS NULL OR (d->>'part_nette')::numeric<0 OR (d->>'part_nette')::numeric<>trunc((d->>'part_nette')::numeric) OR (d->>'part_nette')::numeric::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'part_successorale_invalide';END IF;
   somme:=somme+(d->>'part_nette')::numeric;
  ELSIF d->>'type'='terrain' THEN
   IF (SELECT count(*) FROM public.terrains_etat WHERE country=NEW.country AND (id=d->>'terrain_id' OR (d->>'terrain_id' IS NULL AND building_id=d->>'id' AND (d->>'ville' IS NULL OR data::jsonb->>'city'=d->>'ville'))) AND data::jsonb->>'proprietaire' IN(pj.name,'pj:'||pj.name))<>1 THEN RAISE EXCEPTION 'titre_successoral_non_possede';END IF;
  ELSIF d->>'type'='entreprise' THEN
   IF NOT EXISTS(SELECT 1 FROM public.entreprises WHERE id=d->>'id' AND data->>'proprietaire' IN(pj.name,'pj:'||pj.name)) THEN RAISE EXCEPTION 'fonds_successoral_non_possede';END IF;
  END IF;
 END LOOP;
 IF somme<>NEW.argent_net_total THEN RAISE EXCEPTION 'parts_successorales_incoherentes';END IF;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION public.succession_creation_garder() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS aa_succession_creation_garder ON public.successions;
CREATE TRIGGER aa_succession_creation_garder BEFORE INSERT ON public.successions FOR EACH ROW EXECUTE FUNCTION public.succession_creation_garder();
COMMIT;
