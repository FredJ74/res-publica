-- DÉCISION DU MAIRE ADJOINT SUR UN PERMIS PAR LE SERVEUR — 29/10/2026 (Claude).
-- `terrain_permis_acte('permis_decider')` vérifiait l'autorité mais fusionnait le permis ENTIER
-- envoyé par l'écran (palier, demandeur, durées…), puis l'écran archivait, remettait le document
-- et écrivait le courrier lui-même. Nouvelle porte : l'adjoint ne transmet que sa décision et son
-- motif ; statut, archive, document remis au demandeur, courrier et coût de l'ordre
-- (`traiter_demandes_permis`, 1 PA) sont posés dans une seule transaction. Règles inchangées :
-- maire adjoint de la ville du terrain, dossier en instruction, motif de 10 caractères pour un
-- refus, carence de 3 jours annoncée. L'ancien acte est fermé après la livraison (20261029160000).
CREATE OR REPLACE FUNCTION public.terrain_permis_decider(p_terrain text, p_valide boolean, p_motif text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; t record; a record; e jsonb; pm jsonb; r jsonb; pay jsonb;
  nature text; ref text; doc jsonb; motif text := nullif(btrim(coalesce(p_motif,'')),''); lib text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_terrain IS NULL OR p_valide IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE acteur = moi AND requete = p_requete;
  IF FOUND THEN
    IF a.action <> 'permis_decider' OR a.terrain IS DISTINCT FROM p.country||'_'||p_terrain THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id = a.terrain;
    RETURN a.resultat || jsonb_build_object('rejeu',true,'etat',e);
  END IF;
  SELECT * INTO t FROM public.terrains_etat
   WHERE id = p.country||'_'||p_terrain AND country = p.country AND building_id = p_terrain FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb; pm := e->'permis';
  IF coalesce(e->>'succession_gel','') <> '' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele'); END IF;
  IF p.poste->>'id' IS DISTINCT FROM 'maire_adjoint' THEN RETURN jsonb_build_object('ok',false,'raison','autorite_refusee'); END IF;
  IF p.poste->>'city' IS DISTINCT FROM e->>'city' THEN RETURN jsonb_build_object('ok',false,'raison','hors_juridiction'); END IF;
  IF jsonb_typeof(pm) IS DISTINCT FROM 'object' OR pm->>'statut' IS DISTINCT FROM 'instruction' THEN
    RETURN jsonb_build_object('ok',false,'raison','dossier_deja_decide'); END IF;
  IF NOT p_valide AND length(coalesce(motif,'')) < 10 THEN RETURN jsonb_build_object('ok',false,'raison','motif_requis'); END IF;
  pay := public.payer_ordre(moi, 'traiter_demandes_permis', 1, 0);
  IF pay->>'ok' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('ok',false,'raison',coalesce(pay->>'raison','paiement_refuse')); END IF;

  nature := CASE WHEN p_valide THEN 'acceptation' ELSE 'refus' END;
  lib := CASE pm->>'palierDemande' WHEN 'hangar' THEN 'Hangar' WHEN 'commerce_standard' THEN 'Commerce standard'
           WHEN 'commerce_premium' THEN 'Commerce premium' WHEN 'building' THEN 'Building' ELSE coalesce(pm->>'palierDemande','') END;
  pm := pm || jsonb_build_object('statut', CASE WHEN p_valide THEN 'valide' ELSE 'refuse' END, 'decidePar', moi,
          'jourDecision', (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text)
           || CASE WHEN p_valide THEN '{}'::jsonb ELSE jsonb_build_object('motifRefus', motif, 'jourRefus', coalesce(p.day,1)) END;
  e := public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('permis', pm)
         || CASE WHEN p_valide THEN '{"constructionAutorisee":true}'::jsonb ELSE '{}'::jsonb END, t.country);

  ref := 'urb-'||nature||'-'||t.id||'-'||coalesce(nullif(pm->>'numeroDossier',''),p_requete::text);
  doc := jsonb_build_object('id',ref,'nature',nature,'numeroDossier',pm->'numeroDossier','jour',p.day,'jourDepot',pm->'dateDepot',
           'demandeur',pm->'demandeur','pays',t.country,'ville',e->'city','buildingId',t.building_id,'batimentLabel',t.building_id,
           'palier',pm->'palierDemande','palierLabel',lib,'surfaceExploitable',e->'surface','decoupage','[]'::jsonb,'motifRefus',motif);
  INSERT INTO public.dossiers_urbanisme(id,country,city,building_id,numero_dossier,type_evenement,demandeur,jour,libelle,data)
  VALUES(ref,t.country,e->>'city',t.building_id,pm->>'numeroDossier',nature,pm->>'demandeur',p.day,
    CASE WHEN p_valide THEN 'Permis accordé' ELSE 'Permis refusé' END||' à '||coalesce(pm->>'demandeur','un demandeur')||' pour '||t.building_id||' ('||lib||').',doc)
  ON CONFLICT (id) DO NOTHING;
  IF coalesce(pm->>'demandeur','') <> '' THEN
    r := public.objet_sas_deposer('document_urbanisme', pm->>'demandeur', jsonb_build_object('id',ref,'type','document_urbanisme_'||nature,
      'name', CASE WHEN p_valide THEN 'Arrêté d’accord de permis — ' ELSE 'Arrêté de refus de permis — ' END||t.building_id,
      'icon','ti-file-certificate','legal',true,'desc', CASE WHEN p_valide THEN 'Votre permis de construire est accordé.' ELSE 'Motif : '||motif END,
      'documentUrbanisme',doc), ref);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'document_decision_non_confirme'; END IF;
    PERFORM public.mail_systeme_poser_interne('Mairie', pm->>'demandeur', CASE WHEN p_valide THEN 'Permis validé' ELSE 'Permis refusé' END,
      CASE WHEN p_valide THEN 'Votre permis de construire ('||lib||') a été validé. Vous pouvez construire.'
           ELSE 'Votre permis de construire ('||lib||') a été refusé.'||chr(10)||chr(10)||'Motif retenu par le service d''urbanisme : '||motif
                ||chr(10)||chr(10)||'Vous pourrez déposer une nouvelle demande dans 3 jours.' END, NULL);
  END IF;
  r := jsonb_build_object('ok',true,'decision',nature,'demandeur',pm->>'demandeur') || jsonb_build_object('paiement', pay);
  INSERT INTO public.terrain_acquisitions_recus VALUES (moi, p_requete, t.id, 'permis_decider', jsonb_build_object('valide',p_valide), r);
  RETURN r || jsonb_build_object('etat', e);
END;
$function$;
REVOKE ALL ON FUNCTION public.terrain_permis_decider(text,boolean,text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.terrain_permis_decider(text,boolean,text,uuid) TO authenticated;
