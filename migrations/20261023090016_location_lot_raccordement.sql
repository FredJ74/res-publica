-- #94 PREPAREE : location via la commande, les baux et les loyers communs.
BEGIN;
DO $p$ DECLARE h text;s text;BEGIN
SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.chantier_commande(text,text,text,jsonb)');
IF h='8c2b75fc8205853ca2aa86f6cefc87ec' THEN
s:=replace(s,$ancien$ IF p_action<>'travailler' THEN
 PERFORM public.chantier_autorite_exiger_interne$ancien$,$nouveau$ IF p_action NOT IN('travailler','louer') THEN
 PERFORM public.chantier_autorite_exiger_interne$nouveau$);
s:=replace(s,$ancien$ ELSIF p_action='plan' THEN$ancien$,$nouveau$ ELSIF p_action='louer' THEN
  IF p_parametres-ARRAY['lot']<>'{}' OR nullif(p_parametres->>'lot','') IS NULL THEN RAISE EXCEPTION 'lot_introuvable';END IF;
  IF a.current_city IS DISTINCT FROM etat->>'city' OR a.current_building IS DISTINCT FROM t.building_id THEN RAISE EXCEPTION 'pas_sur_place';END IF;
  IF coalesce(a.pa,0)<1 THEN RAISE EXCEPTION 'pa_insuffisants';END IF;
  INSERT INTO public.chantier_commandes_recus(personnage_id,acteur,requete,terrain_id,commande,resultat)
   VALUES(a.id,acteur,p_requete,p_terrain_id,commande,jsonb_build_object('interne','location_lot','transaction_id',txid_current()::text,'bail_id',t.country||':'||t.building_id||':lot_dyn_'||regexp_replace(p_parametres->>'lot','[^A-Za-z0-9_-]','_','g')||':'||(etat->>'city')));
  etat:=public.location_lot_enregistrer_interne(etat,t.country,t.building_id,p_parametres->>'lot',acteur,a.day);
  UPDATE public.personnages_donnees SET pa=pa-1,updated_at=now() WHERE name=acteur;
 ELSIF p_action='plan' THEN$nouveau$);
s:=replace(s,$ancien$ INSERT INTO public.chantier_commandes_recus(personnage_id,acteur,requete,terrain_id,commande,resultat) VALUES(a.id,acteur,p_requete,p_terrain_id,commande,resultat);$ancien$,$nouveau$ IF p_action='louer' THEN
  UPDATE public.chantier_commandes_recus cr SET resultat=resultat WHERE cr.acteur=acteur AND cr.requete=p_requete AND cr.personnage_id=a.id AND cr.resultat->>'transaction_id'=txid_current()::text AND cr.resultat->>'interne'='location_lot';
  IF NOT FOUND THEN RAISE EXCEPTION 'recu_location_absent';END IF;
 ELSE
  INSERT INTO public.chantier_commandes_recus(personnage_id,acteur,requete,terrain_id,commande,resultat) VALUES(a.id,acteur,p_requete,p_terrain_id,commande,resultat);
 END IF;$nouveau$);
s:=replace(s,$ancien$ARRAY['reamenagement_indisponible'$ancien$,$nouveau$ARRAY['lot_introuvable','lot_en_travaux','loyer_invalide','premier_loyer_refuse','pa_insuffisants','reamenagement_indisponible'$nouveau$);
EXECUTE s;ELSIF h IS DISTINCT FROM 'd2b5297076a983b4b660a26a18d914de' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_commande location';END IF;
END;$p$;
COMMIT;
