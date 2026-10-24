-- #94 PREPAREE : quotas PNJ variables, memes transactions et aucun changement des salaires PJ.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_jour_traiter(text)');
IF h='c8d40a2ec77b7e7a5b2bf155eda5302c' THEN
s:=replace(s,$ancien$DECLARE emplacement text;r record;$ancien$,$nouveau$DECLARE paye numeric;cible_travail numeric;gain_travail numeric;emplacement text;r record;$nouveau$);
s:=replace(s,$ancien$   heures:=greatest(0,least(floor(cap*least(f,d-avant,plafond-avant))-faites,floor((ch->>'tresorerie')::numeric/taux)));cout:=heures*taux;$ancien$,$nouveau$   IF ch->>'type'='reamenagement' AND ch->>'versionCalculTravail'='2' THEN
    -- Les paiements de chaque jour restent entiers ; leur cumul solde exactement le cout.
    -- Les heures PJ restent entieres a 1 PA/heure. Aucun ancien salaire n'est reconstitue.
    SELECT coalesce(sum((e->>'coutPNJ')::numeric),0) INTO paye FROM jsonb_array_elements(coalesce(ch->'evenements','[]')) e WHERE e->>'cle'='journee';
    SELECT paye+coalesce(sum((e->>'montant')::numeric),0) INTO paye FROM jsonb_array_elements(coalesce(ch->'travauxPJ','[]')) e;
    IF paye<0 OR paye>(ch->>'coutTravail')::numeric THEN RAISE EXCEPTION 'journal_travail_incoherent';END IF;
    cible_travail:=least((ch->>'coutTravail')::numeric,ceil((ch->>'coutTravail')::numeric*least(d,plafond,avant+least(1,f))/d));
    cout:=greatest(0,least(cible_travail-paye,floor((ch->>'tresorerie')::numeric)));heures:=cout/taux;
    gain_travail:=greatest(0,(paye+cout)*d/(ch->>'coutTravail')::numeric-avant);
   ELSE
   heures:=greatest(0,least(floor(cap*least(f,d-avant,plafond-avant))-faites,floor((ch->>'tresorerie')::numeric/taux)));cout:=heures*taux;
   END IF;$nouveau$);
s:=replace(s,$ancien$   gain:=least(1,f,(faites+heures)/cap,d-avant);$ancien$,$nouveau$   gain:=least(1,f,CASE WHEN ch->>'type'='reamenagement' AND ch->>'versionCalculTravail'='2' THEN gain_travail ELSE (faites+heures)/cap END,d-avant);$nouveau$);
EXECUTE s;ELSIF h IS DISTINCT FROM 'e986330f8b0a63c5dd74bc4e6bc44281' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_jour_traiter quotas';END IF;
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_commande(text,text,text,jsonb)');
IF h IN('8c2b75fc8205853ca2aa86f6cefc87ec','d2b5297076a983b4b660a26a18d914de') THEN
s:=replace(s,$ancien$  ch:=public.chantier_reamenagement_preparer_interne(etat,p_parametres->'lots',t.country,t.building_id,a.day);$ancien$,$nouveau$  ch:=public.chantier_reamenagement_preparer_interne(etat,p_parametres->'lots',t.country,t.building_id,a.day)||jsonb_build_object('versionCalculTravail',2);$nouveau$);EXECUTE s;
ELSIF h IS NULL OR h NOT IN('c626a160fb1e933797bdbec4f40ae5ea','ff8da61f8fc6fa6dfab8ebf3c5b0e70b') THEN RAISE EXCEPTION 'definition_non_examinee: chantier_commande quotas';END IF;
END;$p$;
COMMIT;
