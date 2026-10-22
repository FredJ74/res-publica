-- #69 PREPAREE. Extension du loyer commun, sans abonnement cree ou contrat historique converti.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.bail_encaisser_montant_interne(jsonb,text,integer)');IF h IS NOT NULL AND h<>'ffe7c910f992cc30210a5b4143a4fec4' THEN RAISE EXCEPTION 'definition_non_examinee: bail_encaisser_montant_interne(jsonb,text,integer)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_loyer_preparer_interne(text)');IF h IS NOT NULL AND h<>'1e6471d689c8a6448107dd6763f8f62d' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_loyer_preparer_interne(text)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.coffre_loyer_terminer_interne(jsonb,text)');IF h IS NOT NULL AND h<>'e403d96fd695b0b6814ad0899dd85ddc' THEN RAISE EXCEPTION 'definition_non_examinee: coffre_loyer_terminer_interne(jsonb,text)';END IF;
END;$g$;
ALTER TABLE public.coffres_bancaires ADD COLUMN IF NOT EXISTS premier_loyer_paye boolean NOT NULL DEFAULT false;
ALTER TABLE public.coffres_bancaires ADD COLUMN IF NOT EXISTS loyer_jour_traitement date;
ALTER TABLE public.coffres_bancaires ADD COLUMN IF NOT EXISTS loyer_impaye integer NOT NULL DEFAULT 0 CHECK(loyer_impaye>=0);
CREATE OR REPLACE FUNCTION public.bail_encaisser_montant_interne(p_bail jsonb,p_nom text,p_montant integer)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE d jsonb;r jsonb;flag text;
BEGIN
 IF p_montant IS NULL OR p_montant<0 THEN RAISE EXCEPTION 'montant_invalide';END IF;
 IF p_montant=0 THEN RETURN true;END IF;
 d:=public.bail_destination_attestee(p_bail);
 IF d->>'type' IS DISTINCT FROM 'municipal' THEN RAISE EXCEPTION 'destination_non_raccordee';END IF;
 IF NOT public.helvetia_debiter_fonds_ordinaires(p_nom,p_montant,'nationale') THEN RETURN false;END IF;
 flag:=current_setting('rp.caisse_interne',true);
 r:=public.recette_municipale(d->>'pays',d->>'ville',p_montant,'loyer');
 PERFORM set_config('rp.caisse_interne',coalesce(flag,''),true);
 IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'encaissement_non_confirme';END IF;
 RETURN true;
END;$f$;
CREATE OR REPLACE FUNCTION public.coffre_loyer_preparer_interne(p_bail_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE c public.coffres_bancaires;pj record;n text:=public.mon_personnage();b jsonb;s numeric;j date:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
 SELECT * INTO c FROM public.coffres_bancaires WHERE bail_id=p_bail_id;
 IF NOT FOUND THEN RETURN NULL;END IF;
 -- Meme ordre de verrouillage que les transferts et changements : PJ, bail, coffre.
 SELECT * INTO pj FROM public.personnages_donnees WHERE id=c.titulaire_id FOR UPDATE;
 IF NOT FOUND OR c.succession_id IS NOT NULL THEN RETURN jsonb_build_object('statut','coffre_gele');END IF;
 IF NOT public.est_appel_serveur() AND (n IS DISTINCT FROM pj.name OR pj.user_id IS DISTINCT FROM auth.uid()) THEN RAISE EXCEPTION 'coffre_inaccessible';END IF;
 c:=public.coffre_verrouiller_interne(c.id,pj.id,pj.name);
 SELECT data INTO b FROM public.locations_actives WHERE id=p_bail_id;
 IF c.debut_annuel IS NULL OR c.renouvellement_annuel IS NULL OR NOT isfinite(c.debut_annuel) OR NOT isfinite(c.renouvellement_annuel)
 OR c.renouvellement_annuel<=c.debut_annuel OR b->>'periodicite' IS DISTINCT FROM 'annuelle' THEN RETURN jsonb_build_object('statut','coffre_annuel_non_raccorde');END IF;
 IF c.loyer_jour_traitement=j THEN RETURN jsonb_build_object('statut','deja_preleve');END IF;
 IF c.premier_loyer_paye AND c.renouvellement_annuel>j THEN RETURN jsonb_build_object('statut','non_echu');END IF;
 PERFORM 1 FROM public.comptes_bancaires WHERE personnage=pj.name AND banque='nationale' FOR UPDATE;
 SELECT coalesce(sum(solde),0) INTO s FROM public.comptes_bancaires WHERE personnage=pj.name AND banque='nationale';
 RETURN jsonb_build_object('coffre',c.id,'locataire',pj.name,'disponible',coalesce(pj.liquide,0)+s,
 'montant',CASE WHEN c.loyer_impaye>0 THEN c.loyer_impaye ELSE public.coffre_tarif_annuel_interne(c.taille) END,'tarif',public.coffre_tarif_annuel_interne(c.taille));
END;$f$;
CREATE OR REPLACE FUNCTION public.coffre_loyer_terminer_interne(p_preparation jsonb,p_statut text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE c public.coffres_bancaires;suivante date;j date:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
 IF p_preparation IS NULL THEN RETURN;END IF;
 SELECT * INTO STRICT c FROM public.coffres_bancaires WHERE id=(p_preparation->>'coffre')::uuid FOR UPDATE;
 IF p_statut='paye' THEN
  suivante:=CASE WHEN NOT c.premier_loyer_paye THEN c.renouvellement_annuel ELSE
   (c.debut_annuel+make_interval(years=>extract(year FROM c.renouvellement_annuel)::integer-extract(year FROM c.debut_annuel)::integer+1))::date END;
  UPDATE public.coffres_bancaires SET premier_loyer_paye=true,renouvellement_annuel=suivante,loyer_impaye=0,loyer_jour_traitement=j WHERE id=c.id;
 ELSE
  IF p_statut NOT IN('avertissement','expulsion_requise','expulsion_requise_deja_avise') THEN RAISE EXCEPTION 'statut_loyer_inattendu';END IF;
  -- Un seul loyer impaye pour cette echeance, jamais un nouveau tarif annuel chaque nuit.
  UPDATE public.coffres_bancaires SET loyer_impaye=(p_preparation->>'montant')::integer,loyer_jour_traitement=j WHERE id=c.id;
 END IF;
END;$f$;
REVOKE ALL ON FUNCTION public.bail_encaisser_montant_interne(jsonb,text,integer),public.coffre_loyer_preparer_interne(text),public.coffre_loyer_terminer_interne(jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
