-- Nouvelles generations seulement : les contrats historiques non versionnes ne sont pas reinitialises.
BEGIN;
DO $nouveau$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='pret_national_jour_traiter' AND (p.oid IS DISTINCT FROM to_regprocedure('public.pret_national_jour_traiter(text)') OR md5(p.prosrc)<>'71d218c23706cf23ee35e084c1d783e5')) THEN RAISE EXCEPTION 'definition_non_examinee: pret_national_jour_traiter';END IF;END;$nouveau$;

CREATE OR REPLACE FUNCTION public.pret_national_jour_traiter(p_pret text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE nom text;p public.prets%ROWTYPE;pj record;jour text:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;du numeric;solde numeric;imp integer;penalite numeric;terrain record;etat jsonb;
BEGIN
 IF NOT public.est_appel_serveur() THEN DELETE FROM public.prets_ecritures_internes WHERE transaction_id=txid_current();RETURN jsonb_build_object('ok',false,'raison','serveur_requis');END IF;
 SELECT emprunteur INTO nom FROM public.prets WHERE id=p_pret;
 SELECT * INTO pj FROM public.personnages_donnees WHERE name=nom FOR UPDATE;
 SELECT * INTO p FROM public.prets WHERE id=p_pret FOR UPDATE;
 IF p.emprunteur IS DISTINCT FROM nom OR p.contrat_version IS DISTINCT FROM 2 OR p.type_banque IS DISTINCT FROM 'nationale' THEN DELETE FROM public.prets_ecritures_internes WHERE transaction_id=txid_current();RETURN jsonb_build_object('ok',false,'raison','contrat_non_versionne');END IF;
 IF p.statut<>'en_cours' OR p.jour_dernier_prelevement=jour THEN DELETE FROM public.prets_ecritures_internes WHERE transaction_id=txid_current();RETURN jsonb_build_object('ok',true,'rejeu',true);END IF;
 INSERT INTO public.prets_ecritures_internes VALUES(txid_current()) ON CONFLICT DO NOTHING;
 du:=least(p.mensualite,p.montant_restant);
 IF du<=0 THEN UPDATE public.prets SET statut='remboursé',jour_dernier_prelevement=jour WHERE id=p.id;DELETE FROM public.prets_ecritures_internes WHERE transaction_id=txid_current();RETURN jsonb_build_object('ok',true,'montant',0);END IF;
 IF du<>trunc(du) OR du::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'dette_non_entiere';END IF;
 SELECT cb.solde INTO solde FROM public.comptes_bancaires cb WHERE cb.personnage=nom AND cb.banque='nationale' FOR UPDATE;
 IF coalesce(pj.liquide,0)+coalesce(solde,0)>=du THEN
  IF public.helvetia_debiter_fonds_ordinaires(nom,du) IS NOT TRUE THEN RAISE EXCEPTION 'debit_non_confirme';END IF;
  UPDATE public.prets SET montant_restant=montant_restant-du,jours_impayes=0,jour_dernier_prelevement=jour,statut=CASE WHEN montant_restant-du<=0 THEN 'remboursé' ELSE 'en_cours' END WHERE id=p.id;
  DELETE FROM public.prets_ecritures_internes WHERE transaction_id=txid_current();RETURN jsonb_build_object('ok',true,'montant',du,'statut',CASE WHEN p.montant_restant-du<=0 THEN 'remboursé' ELSE 'en_cours' END);
 END IF;
 imp:=coalesce(p.jours_impayes,0)+1;penalite:=CASE WHEN imp=2 THEN round(p.montant_restant*.10) ELSE 0 END;
 UPDATE public.prets SET jours_impayes=imp,montant_restant=montant_restant+penalite,jour_dernier_prelevement=jour,statut=CASE WHEN imp>=4 THEN 'saisi' ELSE statut END WHERE id=p.id;
 IF imp>=4 THEN
  SELECT * INTO terrain FROM public.terrains_etat WHERE country=p.country AND building_id=coalesce(p.bien_cible_id,p.building_id) FOR UPDATE;
  IF FOUND THEN
   etat:=terrain.data::jsonb;
   IF etat->>'proprietaire' IN(nom,'pj:'||nom) THEN
    etat:=etat||jsonb_build_object('proprietaire',NULL,'coproprietaire',NULL,'enVenteParBanque',true,'prixVenteBanque',round(coalesce((etat->>'valeur_totale')::numeric,0)*.7));
    UPDATE public.terrains_etat SET proprietaire=NULL,data=etat::text,updated_at=now() WHERE id=terrain.id;
   END IF;
  END IF;
 END IF;
 PERFORM public.mail_systeme_poser_interne('Banque Nationale',nom,CASE imp WHEN 1 THEN 'Impayé' WHEN 2 THEN 'Mise en demeure' WHEN 3 THEN 'ULTIMATUM' ELSE 'SAISIE' END,
  CASE imp WHEN 1 THEN 'Votre mensualité ne peut pas être prélevée.' WHEN 2 THEN 'Une pénalité de 10 % est appliquée.' WHEN 3 THEN 'Remboursez sous 24 heures ou le bien sera saisi.' ELSE 'Le contrat est transmis au contentieux ; seul le bien appartenant encore à l’emprunteur peut être repris.' END,NULL);
 DELETE FROM public.prets_ecritures_internes WHERE transaction_id=txid_current();RETURN jsonb_build_object('ok',true,'impaye',imp,'penalite',penalite,'saisi',imp>=4);
END;$f$;
REVOKE ALL ON FUNCTION public.pret_national_jour_traiter(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.pret_national_jour_traiter(text) TO service_role;
COMMIT;
