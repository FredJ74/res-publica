-- #69 PREPAREE, NON ACTIVABLE SEULE : depend du cycle annuel encore a raccorder.
-- Aucune conversion d'un ancien bail journalier, aucune echeance inventee.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_tarif_annuel_interne(text)');IF h IS NOT NULL AND h<>'6d6f856d3f82e11625310f1dcce936ae' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_tarif_annuel_interne(text)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_changer_taille(text,uuid,text,bigint)');IF h IS NOT NULL AND h<>'0bf01a5203ca6f3817eb55526b7810a0' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_changer_taille(text,uuid,text,bigint)';END IF;
END;$g$;
ALTER TABLE public.coffres_bancaires ADD COLUMN IF NOT EXISTS debut_annuel date;
ALTER TABLE public.coffres_bancaires ADD COLUMN IF NOT EXISTS renouvellement_annuel date;
CREATE OR REPLACE FUNCTION public.coffre_tarif_annuel_interne(p_taille text)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $f$
 SELECT CASE p_taille WHEN 'S' THEN 250 WHEN 'M' THEN 450 WHEN 'L' THEN 750 WHEN 'XL' THEN 1250 END;
$f$;
CREATE OR REPLACE FUNCTION public.coffre_changer_taille(p_requete text,p_coffre uuid,p_taille text,p_revision bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE n text:=public.mon_personnage();pj record;c public.coffres_bancaires;b jsonb;commande jsonb;rec record;r jsonb;d jsonb;
 prix integer;difference integer;ancien_flag text;
BEGIN
 IF n IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 -- Meme verrou du personnage et meme recu que les transferts ; aucune signature fournie par le joueur.
 PERFORM public.inventaire_reception_etat(n);SELECT * INTO pj FROM public.personnages_donnees WHERE name=n;
 IF p_requete IS NULL OR p_requete !~ '^coffre-[A-Za-z0-9-]{8,100}$' THEN RAISE EXCEPTION 'requete_invalide';END IF;
 commande:=jsonb_build_object('action','taille','coffre',p_coffre,'taille',p_taille,'revisionCoffre',p_revision);
 SELECT * INTO rec FROM public.coffres_requetes WHERE personnage_id=pj.id AND requete=p_requete;
 IF FOUND THEN
  IF rec.commande IS DISTINCT FROM commande THEN RAISE EXCEPTION 'requete_reutilisee';END IF;
  RETURN rec.resultat||jsonb_build_object('rejeu',true);
 END IF;
 c:=public.coffre_verrouiller_interne(p_coffre,pj.id,n);
 SELECT data INTO b FROM public.locations_actives WHERE id=c.bail_id;
 IF pj.country IS DISTINCT FROM c.site->>'country' OR pj.current_city IS DISTINCT FROM c.site->>'city'
 OR pj.current_building IS DISTINCT FROM c.site->>'buildingId' OR pj.current_room IS DISTINCT FROM c.site->>'roomId' THEN RAISE EXCEPTION 'pas_sur_place';END IF;
 IF coalesce(pj.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(n))
 OR coalesce(pj.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RAISE EXCEPTION 'acteur_indisponible';END IF;
 IF c.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'coffre_perime';END IF;
 prix:=public.coffre_tarif_annuel_interne(p_taille);
 IF prix IS NULL THEN RAISE EXCEPTION 'taille_invalide';END IF;
 -- Les colonnes privees attestent le contrat annuel : un ancien JSON de bail ne suffit pas.
 IF c.debut_annuel IS NULL OR c.renouvellement_annuel IS NULL OR c.renouvellement_annuel<=c.debut_annuel
 OR b->>'periodicite' IS DISTINCT FROM 'annuelle' OR b->>'prix' IS DISTINCT FROM public.coffre_tarif_annuel_interne(c.taille)::text THEN RAISE EXCEPTION 'contrat_annuel_non_raccorde';END IF;
 IF public.inventaire_occupation_unites(c.contenu)>public.coffre_capacite_interne(p_taille) THEN RAISE EXCEPTION 'capacite_depassee';END IF;
 difference:=greatest(0,prix-public.coffre_tarif_annuel_interne(c.taille));
 IF difference>0 THEN
  -- Memes primitives financieres et meme destination attestee que le loyer commun.
  -- Aucun routage de paiement ou de remboursement fourni par le navigateur.
  d:=public.bail_destination_attestee(b);
  IF d->>'type' IS DISTINCT FROM 'municipal' THEN RAISE EXCEPTION 'destination_non_raccordee';END IF;
  IF NOT public.helvetia_debiter_fonds_ordinaires(n,difference,'nationale') THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
  ancien_flag:=current_setting('rp.caisse_interne',true);
  r:=public.recette_municipale(d->>'pays',d->>'ville',difference,'loyer');
  PERFORM set_config('rp.caisse_interne',coalesce(ancien_flag,''),true);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'encaissement_non_confirme';END IF;
 END IF;
 -- Les objets, identites, debuts et dates de renouvellement restent integralement inchanges.
 UPDATE public.coffres_bancaires SET taille=p_taille,revision=revision+1 WHERE id=c.id;
 UPDATE public.locations_actives SET data=b||jsonb_build_object('prix',prix,'tailleCoffre',p_taille) WHERE id=c.bail_id;
 r:=jsonb_build_object('ok',true,'coffre',c.id,'taille',p_taille,'capacite',public.coffre_capacite_interne(p_taille),
 'tarifAnnuel',prix,'montant',difference,'renouvellementAnnuel',c.renouvellement_annuel,'revisionCoffre',c.revision+1);
 INSERT INTO public.coffres_requetes(personnage_id,requete,commande,resultat) VALUES(pj.id,p_requete,commande,r);
 RETURN r;
EXCEPTION WHEN raise_exception THEN
 IF SQLERRM=ANY(ARRAY['requete_invalide','requete_reutilisee','coffre_inaccessible','contrat_modifie','pas_sur_place','acteur_indisponible','coffre_perime','taille_invalide','contrat_annuel_non_raccorde','capacite_depassee','destination_non_raccordee','fonds_insuffisants','encaissement_non_confirme']) THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);END IF;RAISE;
END;$f$;
REVOKE ALL ON FUNCTION public.coffre_tarif_annuel_interne(text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.coffre_changer_taille(text,uuid,text,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.coffre_changer_taille(text,uuid,text,bigint) TO authenticated;
COMMIT;
