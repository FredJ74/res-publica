-- #57 PREPAREE. Adaptateurs des caisses existantes, aucun compte parallele.
BEGIN;
DO $g$ DECLARE h text; BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_financeur_verrouiller_interne(text,text,text)'); IF h IS NOT NULL AND h<>'e23c07c5c8806ca832f23989756f1fe1' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_financeur_verrouiller_interne(text,text,text)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_financeur_debiter_interne(jsonb,numeric)'); IF h IS NOT NULL AND h<>'722aa30a2fd08e7dbe303f13e7c7f716' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_financeur_debiter_interne(jsonb,numeric)';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_appel_fonds_interne(jsonb,jsonb)'); IF h IS NOT NULL AND h<>'9fd0bbebbc32c94cfa50a8f7e1419f2f' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_appel_fonds_interne(jsonb,jsonb)';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.chantier_financeur_verrouiller_interne(p_titulaire text,p_pays text,p_ville text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE d jsonb;n text;c text;v text;
BEGIN
 IF p_titulaire LIKE 'orga:%' THEN
  n:=substr(p_titulaire,6);
  SELECT data::jsonb INTO d FROM public.organisations WHERE id=n FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'organisation_absente';END IF;
  RETURN jsonb_build_object('type','orga','id',n,'destinataire',d->>'chef');
 ELSIF p_titulaire LIKE 'ville:%' THEN
  IF p_titulaire<>'ville:'||p_pays||':'||p_ville THEN RAISE EXCEPTION 'commune_hors_territoire';END IF;
  c:=p_pays||'_mairie_'||p_ville;
  SELECT data INTO d FROM public.caisses_batiments WHERE id=c FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'caisse_communale_absente';END IF;
  IF (d->>'solde') IS NULL OR (d->>'solde')::numeric<0 OR (d->>'solde')::numeric<>trunc((d->>'solde')::numeric) OR d->>'solde' IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'caisse_communale_invalide';END IF;
  SELECT data::jsonb->>'eluId' INTO n FROM public.cycles_electoraux WHERE country=p_pays AND poste_id='maire' AND city=p_ville;
  RETURN jsonb_build_object('type','ville','id',c,'destinataire',n);
 ELSE
  n:=CASE WHEN p_titulaire LIKE 'pj:%' THEN substr(p_titulaire,4) ELSE p_titulaire END;
  IF n IS NULL OR n='' THEN RAISE EXCEPTION 'titulaire_non_pris_en_charge';END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name=n FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'proprietaire_absent';END IF;
  PERFORM 1 FROM public.comptes_bancaires WHERE personnage=n AND banque='nationale' FOR UPDATE;
  RETURN jsonb_build_object('type','pj','id',n,'destinataire',n);
 END IF;
END;$f$;
CREATE OR REPLACE FUNCTION public.chantier_financeur_debiter_interne(p_source jsonb,p_montant numeric)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE d jsonb;s numeric;r jsonb;ancien text;
BEGIN
 IF p_montant IS NULL OR p_montant<0 OR p_montant<>trunc(p_montant) OR p_montant::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'francs_entiers_requis';END IF;
 IF p_montant=0 THEN RETURN true;END IF;
 IF p_source->>'type'='pj' THEN
  RETURN public.helvetia_debiter_fonds_ordinaires(p_source->>'id',p_montant,'nationale');
 ELSIF p_source->>'type'='orga' THEN
  -- Meme bourse organisations.data.caisse que les ordres existants, jamais une caisse de chantier fictive.
  SELECT data::jsonb INTO d FROM public.organisations WHERE id=p_source->>'id' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'organisation_absente';END IF;
  s:=coalesce((d->>'caisse')::numeric,0);
  IF s<0 OR s<>trunc(s) OR s::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'caisse_organisation_invalide';END IF;
  IF s<p_montant THEN RETURN false;END IF;
  UPDATE public.organisations SET data=jsonb_set(d,'{caisse}',to_jsonb(s-p_montant))::text WHERE id=p_source->>'id';
  RETURN true;
 ELSIF p_source->>'type'='ville' THEN
  ancien:=current_setting('rp.caisse_interne',true);
  PERFORM set_config('rp.caisse_interne','on',true);
  r:=public.caisse_institution_mouvement(p_source->>'id',-p_montant,true);
  PERFORM set_config('rp.caisse_interne',coalesce(ancien,''),true);
  RETURN coalesce((r->>'ok')::boolean,false);
 END IF;
 RAISE EXCEPTION 'source_financiere_inconnue';
END;$f$;
CREATE OR REPLACE FUNCTION public.chantier_appel_fonds_interne(p_chantier jsonb,p_source jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE ch jsonb:=p_chantier;p numeric;d numeric;t numeric;verse numeric;cible numeric;m numeric;mail jsonb;evenement text;
BEGIN
 p:=(ch->>'progressionJours')::numeric;d:=(ch->>'dureeJours')::numeric;t:=(ch->>'coutTotal')::numeric;
 verse:=(ch->>'totalVerse')::numeric;
 IF p IS NULL OR d IS NULL OR d<=0 OR t IS NULL OR t<=0 OR verse IS NULL OR verse<0 THEN RAISE EXCEPTION 'dimensionnement_chantier_invalide';END IF;
 cible:=ceil(t*CASE WHEN p>=d*2/3 THEN 1 WHEN p>=d/3 THEN .70 ELSE .35 END);
 m:=greatest(0,cible-verse);
 IF m=0 THEN
  IF ch->>'arrete'='financement' THEN ch:=ch||jsonb_build_object('arrete',null,'appelFondsManquant',null);END IF;
  RETURN ch;END IF;
 IF public.chantier_financeur_debiter_interne(p_source,m) THEN
  ch:=ch||jsonb_build_object('totalVerse',verse+m,'tresorerie',coalesce((ch->>'tresorerie')::numeric,0)+m,'arrete',null,'appelFondsManquant',null);
  evenement:='appel_fonds_paye';
 ELSE
  ch:=ch||jsonb_build_object('arrete','financement');
  IF ch->>'appelFondsManquant'=cible::text THEN RETURN ch;END IF;
  ch:=ch||jsonb_build_object('appelFondsManquant',cible);evenement:='appel_fonds_manquant';
 END IF;
 ch:=ch||jsonb_build_object('evenements',coalesce(ch->'evenements','[]')||jsonb_build_array(jsonb_build_object('cle',evenement,'cible',cible,'montant',m,'date',now())));
 IF nullif(p_source->>'destinataire','') IS NOT NULL THEN
  mail:=public.mail_systeme_poser_interne('Chef de Chantier',p_source->>'destinataire',CASE WHEN evenement='appel_fonds_paye' THEN 'Appel de fonds du chantier acquitte' ELSE 'Chantier en pause — financement' END,
   CASE WHEN evenement='appel_fonds_paye' THEN m||' FR preleves. Financement cumule : '||cible||' FR.' ELSE 'Il manque '||m||' FR. Aucun debit partiel. Le chantier reprendra automatiquement lorsque les fonds seront disponibles.' END);
  IF NOT coalesce((mail->>'ok')::boolean,false) THEN ch:=ch||jsonb_build_object('notificationEchec',mail);END IF;
 END IF;
 RETURN ch;
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_financeur_verrouiller_interne(text,text,text),public.chantier_financeur_debiter_interne(jsonb,numeric),public.chantier_appel_fonds_interne(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
