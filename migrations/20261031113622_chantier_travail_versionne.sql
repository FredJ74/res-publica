-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261022130418_chantier_travail_versionne.sql ; aucun changement de règle.
-- #57 PREPAREE. Travail remunere dans le recu de la commande, pas un deuxieme moteur.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_commande(text,text,text,jsonb)');
IF h='6ff8d15bf8ac1f6aad509a57bea1c6f6' THEN
s:=replace(s,$a0$ source:=public.chantier_financeur_verrouiller_interne(ancien_etat->>'proprietaire',t.country,ancien_etat->>'city');$a0$,$b0$ IF p_action<>'travailler' THEN source:=public.chantier_financeur_verrouiller_interne(ancien_etat->>'proprietaire',t.country,ancien_etat->>'city');END IF;$b0$);
s:=replace(s,$a1$ PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire',t.country,etat->>'city');$a1$,$b1$ IF p_action<>'travailler' THEN PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire',t.country,etat->>'city');END IF;$b1$);
s:=replace(s,$a2$ ELSIF p_action='plan' THEN$a2$,$b2$ ELSIF p_action='travailler' THEN
  IF p_parametres-ARRAY['heures']<>'{}' OR coalesce(p_parametres->>'heures','') !~ '^[1-9][0-9]*$' THEN RAISE EXCEPTION 'heures_invalides';END IF;
  IF a.current_city IS DISTINCT FROM etat->>'city' OR a.current_building IS DISTINCT FROM t.building_id THEN RAISE EXCEPTION 'pas_sur_place';END IF;
  r:=public.chantier_travailler(acteur,t.country,t.id,(p_parametres->>'heures')::integer);
  IF NOT coalesce((r->>'ok')::boolean,false) THEN RAISE EXCEPTION 'travail_refuse';END IF;
  SELECT data::jsonb INTO etat FROM public.terrains_etat WHERE id=t.id;
  montant:=(r->>'montant')::numeric;
 ELSIF p_action='plan' THEN$b2$);
s:=replace(s,$a3$IF SQLERRM=ANY(ARRAY[$a3$,$b3$IF SQLERRM=ANY(ARRAY['heures_invalides','travail_refuse',$b3$);
EXECUTE s;
ELSIF h IS DISTINCT FROM 'e2e4467e0671aec7c0984b67d52f49ee' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_commande(text,text,text,jsonb)';END IF;
END;$p$;
COMMIT;
