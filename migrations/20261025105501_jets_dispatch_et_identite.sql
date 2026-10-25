-- Adaptateur privé, mêmes hôtes ; barrière d'identité immuable et transition existante.
-- N'active aucune transition et n'accorde aucun droit de commande au navigateur.
BEGIN;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='ordres_jets_commande' AND (p.oid IS DISTINCT FROM to_regprocedure('public.ordres_jets_commande(uuid,text,jsonb,uuid)') OR md5(p.prosrc)<>'aac6c4128fb6c39855edd696865f50bf')) THEN RAISE EXCEPTION 'definition_non_examinee: ordres_jets_commande';END IF;END;$g$;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='ordres_jets_recu_interne' AND (p.oid IS DISTINCT FROM to_regprocedure('public.ordres_jets_recu_interne(uuid,text,uuid)') OR md5(p.prosrc)<>'dcbd4601e6afd4548778cfa54c935b59')) THEN RAISE EXCEPTION 'definition_non_examinee: ordres_jets_recu_interne';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.ordres_jets_recu_interne(p_personnage uuid,p_ordre text,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE t text;x jsonb;params jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE id=p_personnage AND name=public.mon_personnage() AND user_id=auth.uid()) THEN RETURN jsonb_build_object('ok',false,'raison','personnage_change');END IF;
 t:=CASE p_ordre WHEN 'vol' THEN 'vols_commandes_recus' WHEN 'achat_arme_illegal' THEN 'armes_clandestines_recus' WHEN 'tentative_evasion' THEN 'evasions_recus' WHEN 'mener_enquete' THEN 'police_enquetes_recus' WHEN 'organiser_filature' THEN 'police_filatures_recus' WHEN 'organiser_chasse_homme' THEN 'police_chasses_recus' WHEN 'voler_materiel_chantier' THEN 'chantier_vols_recus' WHEN 'benediction' THEN 'religion_benedictions_recus' ELSE NULL END;
 IF t IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','ordre_inconnu');END IF;
 IF to_regclass('public.'||t) IS NULL THEN RETURN jsonb_build_object('ok',true,'terminee',false);END IF;
 EXECUTE format('SELECT to_jsonb(d) FROM public.%I d WHERE acteur=$1 AND requete=$2',t) INTO x USING p_personnage,p_requete;
 IF x IS NULL THEN RETURN jsonb_build_object('ok',true,'terminee',false);END IF;
 params:=CASE p_ordre
 WHEN 'vol' THEN jsonb_build_object('p_cible',x->'cible','p_genre',x->'genre')
 WHEN 'achat_arme_illegal' THEN jsonb_build_object('p_entreprise',x->'entreprise','p_arme',x->'arme')
 WHEN 'tentative_evasion' THEN '{}'::jsonb
 WHEN 'voler_materiel_chantier' THEN jsonb_build_object('p_terrain',substring(x->>'terrain' FROM position('_' IN x->>'terrain')+1),'p_matiere',x->'matiere')
 WHEN 'benediction' THEN jsonb_build_object('p_religieux',x->'religieux')
 ELSE jsonb_build_object('p_cible',x->'cible') END;
 RETURN jsonb_build_object('ok',true,'terminee',true,'parametres',params,'resultat',x->'resultat');
END;$f$;
REVOKE ALL ON FUNCTION public.ordres_jets_recu_interne(uuid,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.ordres_jets_commande(p_personnage uuid,p_ordre text,p_parametres jsonb,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();acteur record;r jsonb;cles text[];historique jsonb;norme jsonb;
BEGIN
 IF moi IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_personnage IS NULL OR p_requete IS NULL OR jsonb_typeof(p_parametres) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 SELECT id,user_id,country INTO acteur FROM public.personnages_donnees WHERE name=moi;
 IF NOT FOUND OR acteur.user_id IS DISTINCT FROM auth.uid() OR acteur.id IS DISTINCT FROM p_personnage THEN RETURN jsonb_build_object('ok',false,'raison','personnage_change');END IF;
 cles:=CASE p_ordre WHEN 'vol' THEN ARRAY['p_cible','p_genre'] WHEN 'achat_arme_illegal' THEN ARRAY['p_entreprise','p_arme'] WHEN 'tentative_evasion' THEN ARRAY[]::text[] WHEN 'mener_enquete' THEN ARRAY['p_cible'] WHEN 'organiser_filature' THEN ARRAY['p_cible'] WHEN 'organiser_chasse_homme' THEN ARRAY['p_cible'] WHEN 'voler_materiel_chantier' THEN ARRAY['p_terrain','p_matiere'] WHEN 'benediction' THEN ARRAY['p_religieux'] ELSE NULL END;
 IF cles IS NULL OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_parametres) k WHERE NOT k=ANY(cles)) OR EXISTS(SELECT 1 FROM unnest(cles) k WHERE NOT p_parametres?k) THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 -- Même ordre de verrous que le vol, y compris pour les vols réciproques.
 PERFORM 1 FROM public.personnages_donnees d WHERE d.id=p_personnage OR p_ordre='vol' AND d.name=p_parametres->>'p_cible' ORDER BY d.id FOR UPDATE;
 SELECT id,user_id,country INTO acteur FROM public.personnages_donnees WHERE name=moi;
 IF NOT FOUND OR acteur.user_id IS DISTINCT FROM auth.uid() OR acteur.id IS DISTINCT FROM p_personnage THEN RETURN jsonb_build_object('ok',false,'raison','personnage_change');END IF;
 historique:=public.ordres_jets_recu_interne(p_personnage,p_ordre,p_requete);
 IF historique->>'terminee'='true' THEN
  norme:=p_parametres;
  IF p_ordre IN('mener_enquete','organiser_filature','organiser_chasse_homme') THEN norme:=jsonb_build_object('p_cible',btrim(p_parametres->>'p_cible'));END IF;
  IF p_ordre='benediction' THEN norme:=jsonb_build_object('p_religieux',regexp_replace(btrim(p_parametres->>'p_religieux'),' \(PNJ\)$','','i'));END IF;
  IF norme IS DISTINCT FROM historique->'parametres' THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  RETURN historique->'resultat'||jsonb_build_object('rejeu',true,'personnageId',p_personnage);
 END IF;
 IF NOT public.rp_transition_active('actes_jets_atomiques_'||acteur.country) THEN RETURN jsonb_build_object('ok',false,'raison','actes_jets_non_actives');END IF;
 CASE p_ordre
 WHEN 'vol' THEN r:=public.vol_commande(p_parametres->>'p_cible',p_parametres->>'p_genre',p_requete);
 WHEN 'achat_arme_illegal' THEN r:=public.arme_clandestine_commande(p_parametres->>'p_entreprise',p_parametres->>'p_arme',p_requete);
 WHEN 'tentative_evasion' THEN r:=public.evasion_commande(p_requete);
 WHEN 'mener_enquete' THEN r:=public.police_enquete_commande(p_parametres->>'p_cible',p_requete);
 WHEN 'organiser_filature' THEN r:=public.police_filature_commande(p_parametres->>'p_cible',p_requete);
 WHEN 'organiser_chasse_homme' THEN r:=public.police_chasse_commande(p_parametres->>'p_cible',p_requete);
 WHEN 'voler_materiel_chantier' THEN r:=public.chantier_vol_commande(p_parametres->>'p_terrain',p_parametres->>'p_matiere',p_requete);
 WHEN 'benediction' THEN r:=public.religion_benediction_demander(p_parametres->>'p_religieux',p_requete);
 END CASE;
 RETURN r||jsonb_build_object('personnageId',p_personnage);
END;$f$;
REVOKE ALL ON FUNCTION public.ordres_jets_commande(uuid,text,jsonb,uuid) FROM PUBLIC,anon,authenticated,service_role;
-- Le lecteur déjà commun fournit l'identité de la fiche, pas celle de présentation.
DO $g$ DECLARE d text;h text;BEGIN
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.religion_benediction_lire()');
 IF h IS NULL OR h NOT IN('2e558ae53af76cee783b3577e21f5cc7','2a972eb91c616d8429c0e709598f9b1b') THEN RAISE EXCEPTION 'definition_non_examinee: religion_benediction_lire';END IF;
 IF h='2a972eb91c616d8429c0e709598f9b1b' THEN RETURN;END IF;
 d:=replace(d,'SELECT id INTO identite FROM public.personnages_donnees WHERE name=public.mon_personnage();','SELECT id INTO identite FROM public.personnages_donnees WHERE name=public.mon_personnage() AND user_id=auth.uid();');
 d:=replace(d,'''ok'',true,''benediction''','''ok'',true,''personnageId'',identite,''actesSuspendus'',EXISTS(SELECT 1 FROM public.rp_transitions t WHERE t.cle=''actes_jets_atomiques_''||(SELECT country FROM public.personnages_donnees WHERE id=identite) AND NOT t.actif),''actesAtomiques'',CASE WHEN public.rp_transition_active(''actes_jets_atomiques_''||(SELECT country FROM public.personnages_donnees WHERE id=identite)) THEN 1 ELSE 0 END,''benediction''');
 EXECUTE d;
 SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.religion_benediction_lire()');
 IF h<>'2a972eb91c616d8429c0e709598f9b1b' THEN RAISE EXCEPTION 'identite_benediction_non_confirmee';END IF;
END;$g$;
COMMIT;
