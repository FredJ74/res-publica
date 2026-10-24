-- #94 PREPAREE : extension du moteur existant, aucun moteur parallele.
BEGIN;
DO $patch$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_commande(text,text,text,jsonb)');
IF h='f7948b5e7a04d071d6aa13fdd44b2306' THEN
s:=replace(s,$ancien$ montant numeric;$ancien$,$nouveau$ emplacement text;montant numeric;$nouveau$);
s:=replace(s,$ancien$ ch:=etat->'chantier';$ancien$,$nouveau$ emplacement:=CASE WHEN jsonb_typeof(etat->'chantierReamenagement')='object' THEN 'chantierReamenagement' ELSE 'chantier' END;ch:=etat->emplacement;$nouveau$);
s:=replace(s,$ancien$ ELSIF p_action='verser' THEN$ancien$,$nouveau$ ELSIF p_action='reamenager' THEN
  IF p_parametres-ARRAY['lots']<>'{}' OR jsonb_typeof(p_parametres->'lots') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'plan_invalide';END IF;
  ch:=public.chantier_reamenagement_preparer_interne(etat,p_parametres->'lots',t.country,t.building_id,a.day);
  montant:=(ch->>'coutTotal')::numeric;
  IF NOT public.chantier_financeur_debiter_interne(source,montant) THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
  etat:=etat||jsonb_build_object('chantierReamenagement',ch);
 ELSIF p_action='verser' THEN$nouveau$);
s:=replace(s,$ancien$jsonb_build_object('chantier',ch)$ancien$,$nouveau$jsonb_build_object(emplacement,ch)$nouveau$);
s:=replace(s,$ancien$  plan:=coalesce(etat->'permis'->'decoupageInitial','[]');$ancien$,$nouveau$  plan:=CASE WHEN ch->>'type'='reamenagement' THEN ch->'planCible' ELSE coalesce(etat->'permis'->'decoupageInitial','[]') END;$nouveau$);
s:=replace(s,$ancien$  lots:=public.chantier_plan_normaliser_interne(etat,ch->>'niveau',plan);$ancien$,$nouveau$  lots:=CASE WHEN ch->>'type'='reamenagement' THEN public.chantier_reamenagement_livrer_plan_interne(etat,t.country,t.building_id) ELSE public.chantier_plan_normaliser_interne(etat,ch->>'niveau',plan) END;$nouveau$);
s:=replace(s,$ancien$  IF jsonb_array_length(coalesce(etat->'subdivisions','[]'))>0 THEN$ancien$,$nouveau$  IF ch->>'type'<>'reamenagement' AND jsonb_array_length(coalesce(etat->'subdivisions','[]'))>0 THEN$nouveau$);
s:=replace(s,$ancien$etat:=(etat-'chantier')||jsonb_build_object('niveau_construction',ch->>'niveau'$ancien$,$nouveau$etat:=(etat-emplacement)||jsonb_build_object('niveau_construction',CASE WHEN ch->>'type'='reamenagement' THEN etat->>'niveau_construction' ELSE ch->>'niveau' END$nouveau$);
s:=replace(s,$ancien$ARRAY['prix_invalides'$ancien$,$nouveau$ARRAY['reamenagement_indisponible','lot_vendu','aucun_changement','lots_modifies_pendant_travaux','prix_invalides'$nouveau$);
EXECUTE s;ELSIF h IS DISTINCT FROM '8c2b75fc8205853ca2aa86f6cefc87ec' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_commande';END IF;
END;$patch$;
COMMIT;
