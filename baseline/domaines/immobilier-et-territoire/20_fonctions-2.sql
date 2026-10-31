-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine immobilier et territoire -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- terrain_occupation_action_preparer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_occupation_action_preparer(p_terrain text, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text:=public.mon_personnage();p record;t record;e jsonb;regles jsonb;cha numeric;dup numeric;isn numeric;indice_d numeric;bonus numeric:=0;org record;m jsonb;grade integer;v numeric;taux numeric;delai integer;cout integer;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_action NOT IN('police','corruption_police','cadavre') OR p_action IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','action_inconnue');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_terrain OR p_terrain NOT LIKE 'terrain-a-batir%' THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 IF coalesce(p.hp,0)<=0 OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text OR EXISTS(SELECT 1 FROM public.detention_active(acteur)) THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 PERFORM public.terrain_police_traiter_interne(p.country||'_'||p_terrain);
 SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain AND country=p.country AND building_id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;
 e:=public.terrain_etat_lire(t.data);
 IF e->>'city' IS DISTINCT FROM p.current_city THEN RETURN jsonb_build_object('ok',false,'raison','terrain_incoherent');END IF;
 IF coalesce(e->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele');END IF;
 IF coalesce(e->>'policeAppellee','')<>'' OR coalesce((e->>'enqueteJusqua')::numeric,0)>extract(epoch FROM clock_timestamp())*1000 THEN RETURN jsonb_build_object('ok',false,'raison','intervention_en_cours','etat',e);END IF;
 IF (p_action='cadavre' AND e->>'pnj' IS DISTINCT FROM 'cadavre') OR coalesce(e->>'pnj','') NOT IN('cadavre','squatter_cool','squatter_agr') THEN RETURN jsonb_build_object('ok',false,'raison','occupation_incompatible','etat',e);END IF;
 SELECT data INTO regles FROM public.terrain_actions_regles WHERE id;
 isn:=(regles->'indices'->p.country->>'ISN')::numeric;indice_d:=(regles->'indices'->p.country->>'ID')::numeric;
 IF isn IS NULL OR indice_d IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','referentiel_indisponible');END IF;
 SELECT avg(c),avg(d) INTO cha,dup FROM (
 SELECT coalesce((p.stats->>'CHA')::numeric,8) c,coalesce((p.stats->>'DUP')::numeric,8) d
 UNION ALL SELECT mb.car_cha,mb.car_dup FROM public.pnj_membres mb JOIN public.pnj_employes_metier em ON em.pnj_id=mb.id
 WHERE mb.proprietaire_pj=acteur AND mb.leader_pj=acteur AND mb.statut='actif') x;
 IF cha::text IN('NaN','Infinity','-Infinity') OR dup::text IN('NaN','Infinity','-Infinity') OR coalesce(p.resources->>'dis','50') IN('NaN','Infinity','-Infinity') THEN RETURN jsonb_build_object('ok',false,'raison','etat_personnage_invalide');END IF;
 cha:=cha-CASE WHEN p.excommunie IS NOT NULL AND p.excommunie<>'null'::jsonb THEN 2 ELSE 0 END;
 IF p.stats_affaiblies ? 'CHA' THEN cha:=greatest(1,floor(cha*greatest(0,least(1,p.hp::numeric/100))+.5));ELSE cha:=floor(cha+.5);END IF;
 IF p.stats_affaiblies ? 'DUP' THEN dup:=greatest(1,floor(dup*greatest(0,least(1,p.hp::numeric/100))+.5));ELSE dup:=floor(dup+.5);END IF;
 FOR org IN SELECT data::jsonb d FROM public.organisations LOOP
  SELECT value INTO m FROM jsonb_array_elements(coalesce(org.d->'membres','[]')) WHERE value->>'nom'=acteur LIMIT 1;
  IF m IS NULL THEN CONTINUE;END IF;grade:=coalesce((m->>'gradeIdx')::integer,0);
  SELECT max((value->>'valeur')::numeric) INTO v FROM jsonb_array_elements(coalesce(regles->'bonus'->(org.d->>'type'),'[]')) WHERE (value->>'grade')::integer<=grade;
  bonus:=bonus+coalesce(v,0);
 END LOOP;
 delai:=greatest(6,floor(96-isn*.6+.5)::integer);cout:=0;
 IF p_action='police' THEN taux:=NULL;
 ELSIF p_action='corruption_police' THEN taux:=least(80,40+floor(dup*2));cout:=floor(100+isn*3);delai:=greatest(1,floor((96-isn*.6)/4+.5)::integer);
 ELSE taux:=least(85,floor(coalesce((p.resources->>'dis')::numeric,50)/2+cha/2)-floor(isn/5)+bonus/3);END IF;
 RETURN jsonb_build_object('ok',true,'etat',e,'occupation',coalesce(e->>'dateGeneration','historique')||':'||(e->>'pnj'),
 'taux',taux,'pa',CASE WHEN p_action='cadavre' THEN 2 ELSE 1 END,'cout',cout,'delaiHeures',delai,'prescriptionJours',greatest(7,floor(indice_d*.6+.5)::integer));
END;$function$;

-- terrain_occupation_lire(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_occupation_lire(p_terrain text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text:=public.mon_personnage();p record;t record;e jsonb;nouvelle boolean;occupation text;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT id,country,current_city,current_building INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_terrain OR p_terrain NOT LIKE 'terrain-a-batir%' THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 PERFORM public.terrain_police_traiter_interne(p.country||'_'||p_terrain);
 SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain AND country=p.country
  AND building_id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
 e:=public.terrain_etat_lire(t.data);
 IF e IS NULL OR e->>'city' IS DISTINCT FROM p.current_city THEN RETURN jsonb_build_object('ok',false,'raison','terrain_incoherent'); END IF;
 nouvelle:=NOT EXISTS(SELECT 1 FROM public.terrain_visites_actives WHERE terrain_id=t.id);
 IF nouvelle AND NOT coalesce((e->>'occupationScellee')::boolean,false)
  AND nullif(e->>'proprietaire','') IS NULL AND NOT coalesce((e->>'compromis')::boolean,false) AND NOT (jsonb_typeof(e->'achatDirect') = 'object' AND coalesce((e->'achatDirect'->>'dateLimite')::numeric,0) > extract(epoch FROM clock_timestamp())*1000)
  AND coalesce(e->>'succession_gel','')=''
  AND coalesce(e->>'policeAppellee','')=''
  AND coalesce((e->>'enqueteJusqua')::numeric,0)<=extract(epoch FROM clock_timestamp())*1000 THEN
  -- Conserver une presence historique a sa premiere adoption, sans la reinterpreter.
  IF coalesce((e->>'occupationInitialisee')::boolean,false) OR NOT (e ? 'pnj') THEN
   occupation:=public.terrain_occupation_tirer_interne();
   e:=public.terrain_etat_fusionner_interne(t.id,jsonb_build_object('pnj',occupation,'pnjData',NULL,
    'occupationInitialisee',true,'dateGeneration',floor(extract(epoch FROM clock_timestamp())*1000)),p.country);
  ELSE
   e:=public.terrain_etat_fusionner_interne(t.id,'{"occupationInitialisee":true}',p.country);
  END IF;
 END IF;
 IF nullif(e->>'proprietaire','') IS NOT NULL OR coalesce((e->>'compromis')::boolean,false) OR (jsonb_typeof(e->'achatDirect') = 'object' AND coalesce((e->'achatDirect'->>'dateLimite')::numeric,0) > extract(epoch FROM clock_timestamp())*1000) THEN
  e:=public.terrain_etat_fusionner_interne(t.id,'{"occupationScellee":true}',p.country);
 END IF;
 INSERT INTO public.terrain_visites_actives VALUES(p.id,t.id) ON CONFLICT DO NOTHING;
 RETURN jsonb_build_object('ok',true,'etat',e);
END;$function$;

-- terrain_occupation_tirer_interne() -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_occupation_tirer_interne()
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT (ARRAY[NULL::text,'squatter_cool','squatter_agr','cadavre'])[1+floor(random()*4)::integer];
$function$;

-- terrain_permis_acte(text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_permis_acte(p_terrain_id text, p_acte text, p_patch jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; v_poste_ville text;
  v_lu jsonb; v_etat jsonb; v_patch jsonb; v_final jsonb; v_permis jsonb;
  v_ville text; v_ville_inconnue boolean := false; v_cles text[]; v_k text;
BEGIN
  IF p_acte = 'permis_deposer' THEN
    RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_acte='permis_plan_modifier' THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  IF p_acte NOT IN ('permis_deposer', 'permis_prevenir_maire', 
                    'permis_plan_modifier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  v_patch := coalesce(p_patch, '{}'::jsonb);
  IF jsonb_typeof(v_patch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'patch_invalide');
  END IF;

  -- LISTE DE CLES PAR ACTE. Seule la decision touche `constructionAutorisee` ; aucun acte de ce
  -- mecanisme ne touche `chantier`, `subdivisions`, `proprietaire` ni le compromis.
  v_cles := CASE WHEN p_acte = 'permis_decider' THEN ARRAY['permis', 'constructionAutorisee']
                 ELSE ARRAY['permis'] END;
  FOR v_k IN SELECT jsonb_object_keys(v_patch) LOOP
    IF NOT (v_k = ANY (v_cles)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cle_hors_acte', 'cle', v_k);
    END IF;
  END LOOP;

  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_moi, v_poste, v_poste_ville, v_pays FROM public.acteur_poste_courant() a;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  v_permis := v_etat -> 'permis';
  v_ville := nullif(btrim(coalesce(v_etat ->> 'city', '')), '');
  v_ville_inconnue := (v_ville IS NULL);

  IF p_acte = 'permis_deposer' THEN
    IF NOT public.titulaire_est_moi(v_etat ->> 'proprietaire') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
    END IF;
    IF jsonb_typeof(v_patch -> 'permis') <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'permis_absent');
    END IF;
    -- LE DEMANDEUR N'EST PLUS DICTE PAR LE NAVIGATEUR.
    v_patch := jsonb_set(v_patch, '{permis,demandeur}', to_jsonb(v_moi));

  ELSIF p_acte = 'permis_prevenir_maire' THEN
    -- ACTE PASSIF : il se declenche a l'entree dans la piece, pour N'IMPORTE QUEL joueur. Il n'a
    -- donc aucune autorite a verifier -- mais il ne doit poser QUE ce drapeau, et la porte le pose
    -- elle-meme plutot que de recopier un patch. Les trois conditions sont celles du client :
    --   if (!instructionAchevee(ts.permis) || ts.permis.mairePrevenu) return;
    IF v_permis IS NULL OR (v_permis ->> 'statut') IS DISTINCT FROM 'instruction'
       OR coalesce((v_permis ->> 'dureeInstruction')::numeric, 0) <= 0
       OR coalesce((v_permis ->> 'joursInstructionFaits')::numeric, 0)
          < coalesce((v_permis ->> 'dureeInstruction')::numeric, 0)
       OR coalesce((v_permis ->> 'mairePrevenu')::boolean, false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_signaler');
    END IF;
    v_patch := jsonb_build_object('permis', v_permis || '{"mairePrevenu": true}'::jsonb);

  ELSIF p_acte = 'permis_decider' THEN
    IF v_poste IS DISTINCT FROM 'maire_adjoint' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee');
    END IF;
    IF NOT v_ville_inconnue AND v_poste_ville IS DISTINCT FROM v_ville THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction',
                                'ville_terrain', v_ville, 'ville_poste', v_poste_ville);
    END IF;
    -- LA MEME REGLE QUE `verdictDecisionPermis` : un dossier deja tranche ne se retranche pas.
    IF v_permis IS NULL OR (v_permis ->> 'statut') IS DISTINCT FROM 'instruction' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'dossier_deja_decide',
                                'statut', v_permis ->> 'statut');
    END IF;
    IF (v_patch -> 'permis' ->> 'statut') NOT IN ('valide', 'refuse') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'decision_invalide');
    END IF;
    IF (v_patch -> 'permis' ->> 'statut') = 'refuse'
       AND length(btrim(coalesce(v_patch -> 'permis' ->> 'motifRefus', ''))) < 10 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'motif_requis');
    END IF;

  ELSIF p_acte = 'permis_accelerer' THEN
    -- REGLE RECOPIEE DU CLIENT : if (!ts.permis || ts.permis.statut !== 'instruction')
    IF v_permis IS NULL OR (v_permis ->> 'statut') IS DISTINCT FROM 'instruction' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'aucune_instruction');
    END IF;
    IF (v_permis->>'demandeur') IS DISTINCT FROM public.mon_personnage() THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_dossier'); END IF;
    IF (v_permis->>'accelereAncienCircuit') IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_accelere'); END IF;
    v_patch := jsonb_build_object('permis', v_permis || jsonb_build_object(
      'dureeInstruction', greatest(1, floor(coalesce((v_permis->>'dureeInstruction')::numeric, 1) / 2)),
      'dateInstructionTerminee', coalesce((v_permis->>'dateDepot')::integer, 0)
                                 + greatest(1, floor(coalesce((v_permis->>'dureeInstruction')::numeric, 1) / 2)),
      'accelereAncienCircuit', true));

  ELSIF p_acte = 'permis_plan_modifier' THEN
    -- PREMIERE REGLE DE `verdictOuvertureModificationPlan`, et la seule qui soit une AUTORITE :
    --   if (!estTitulaire(ts && ts.proprietaire)) return { ok:false, ... }
    -- Les autres (chantier present, deux tiers non franchis, palier divisible, surface connue)
    -- restent au verdict unique du client : les porter ici en ferait une SECONDE version.
    IF NOT public.titulaire_est_moi(v_etat ->> 'proprietaire') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
    END IF;
    IF v_permis IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'aucun_permis');
    END IF;
  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id, v_patch, v_pays);
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final,
                            'ville_inconnue', v_ville_inconnue);
END; $function$;

-- terrain_permis_corrompre(text,uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_permis_corrompre(p_terrain text, p_requete uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; t record; a record; e jsonb; pm jsonb; r jsonb;
  d integer; decouvert boolean; repere boolean := false;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_terrain IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE acteur = moi AND requete = p_requete;
  IF FOUND THEN
    IF a.action <> 'permis_corrompre' OR a.terrain IS DISTINCT FROM p.country||'_'||p_terrain THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    RETURN a.resultat || jsonb_build_object('rejeu',true) || public.crime_etat_acteur_interne(moi);
  END IF;
  SELECT * INTO t FROM public.terrains_etat
   WHERE id = p.country||'_'||p_terrain AND country = p.country AND building_id = p_terrain FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb; pm := e->'permis';
  IF coalesce(e->>'succession_gel','') <> '' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele'); END IF;
  IF p.current_building IS DISTINCT FROM p_terrain OR p.current_city IS DISTINCT FROM e->>'city' THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
  IF jsonb_typeof(pm) IS DISTINCT FROM 'object' OR pm->>'statut' IS DISTINCT FROM 'instruction' THEN
    RETURN jsonb_build_object('ok',false,'raison','aucune_instruction'); END IF;
  r := public.payer_ordre(moi, 'corrompre_fonctionnaire_permis', 2, 800);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN
    RETURN jsonb_build_object('ok',false,'raison',coalesce(r->>'raison','paiement_refuse')); END IF;
  decouvert := random() < 0.25;
  IF decouvert THEN
    repere := public.crime_detecter_interne(moi, 'corruption_fonctionnaire', false);
    r := jsonb_build_object('ok',true,'decouvert',true,'repere',repere);
  ELSE
    d := greatest(1, floor(coalesce((pm->>'dureeInstruction')::numeric, 1) / 2)::integer);
    pm := pm || jsonb_build_object('dureeInstruction', d,
            'dateInstructionTerminee', coalesce((pm->>'dateDepot')::integer, 0) + d);
    e := public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('permis', pm), t.country);
    r := jsonb_build_object('ok',true,'decouvert',false,'dureeInstruction',d,
            'joursRestants', greatest(0, d - coalesce((pm->>'joursInstructionFaits')::integer,0)));
  END IF;
  INSERT INTO public.terrain_acquisitions_recus VALUES (moi, p_requete, t.id, 'permis_corrompre', '{}'::jsonb, r);
  RETURN r || jsonb_build_object('etat', e) || public.crime_etat_acteur_interne(moi);
END;
$function$;

-- terrain_permis_decider(text,boolean,text,uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_permis_decider(p_terrain text, p_valide boolean, p_motif text, p_requete uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
           WHEN 'commerce_premium' THEN 'Commerce premium' WHEN 'building' THEN 'Building' WHEN 'logements_petit' THEN 'Logements sociaux — petit bâtiment' WHEN 'logements_moyen' THEN 'Logements sociaux — bâtiment moyen' WHEN 'logements_barre' THEN 'Logements sociaux — barre d''immeuble' ELSE coalesce(pm->>'palierDemande','') END;
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

-- terrain_permis_deposer(text,text,uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_permis_deposer(p_terrain text, p_palier text, p_requete uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text:=public.mon_personnage(); identite uuid:=auth.uid(); pays text;ville text;jour integer;
 lu jsonb; etat jsonb; permis jsonb; precedent jsonb;doc jsonb; paiement jsonb;reception jsonb;
 duree integer; reference text; batiment text;
BEGIN
 IF acteur IS NULL OR identite IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL OR nullif(btrim(p_terrain),'') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
 duree:=CASE p_palier WHEN 'hangar' THEN 2 WHEN 'commerce_standard' THEN 4 WHEN 'commerce_premium' THEN 6 WHEN 'building' THEN 7 WHEN 'logements_petit' THEN 4 WHEN 'logements_moyen' THEN 6 WHEN 'logements_barre' THEN 7 END;
 IF duree IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','palier_invalide'); END IF;
 -- Meme ordre de verrous que les commandes financieres : personnage, requete, terrain.
 SELECT country,current_city INTO pays,ville FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable'); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('permis:'||identite::text||':'||p_requete::text,0));
 reference:='urb-depot-'||identite::text||'-'||p_requete::text;
 SELECT d.data INTO precedent FROM public.permis_depots_recus r
 JOIN public.dossiers_urbanisme d ON d.id=r.archive
 WHERE r.acteur=identite AND r.requete=p_requete;
 IF FOUND THEN
  IF precedent->>'buildingId' IS DISTINCT FROM p_terrain
     OR precedent->>'palier' IS DISTINCT FROM p_palier OR precedent->>'demandeur' IS DISTINCT FROM acteur THEN
   RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');
  END IF;
  -- La preuve du debit reste l'archive, jamais une nouvelle livraison au rejeu.
  SELECT jsonb_build_object('pa',p.pa,'arg',p.arg,'liquide',p.liquide,
   'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=acteur AND banque='nationale'),0))
   INTO paiement FROM public.personnages_donnees p WHERE p.name=acteur;
  lu:=public.terrain_etat_verrouiller_interne((precedent->>'pays')||'_'||p_terrain);
  RETURN jsonb_build_object('ok',true,'rejeu',true,'document',precedent,'etat',lu->'etat','paiement',paiement);
 END IF;
 -- Une cle canonique pays/batiment evite de choisir un terrain homonyme d'un autre pays.
 SELECT building_id INTO batiment FROM public.terrains_etat WHERE id=pays||'_'||p_terrain AND country=pays;
 IF batiment IS DISTINCT FROM p_terrain THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
 lu:=public.terrain_etat_verrouiller_interne(pays||'_'||p_terrain);etat:=lu->'etat';
 IF coalesce((lu->>'gele')::boolean,true) THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele'); END IF;
 IF etat->>'city' IS DISTINCT FROM ville OR ville IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','hors_juridiction'); END IF;
 IF p_palier LIKE 'logements_%' THEN
  IF NOT public.logements_sociaux_terrain_communal(etat) THEN RETURN jsonb_build_object('ok',false,'raison','logements_reserves_commune');END IF;
  IF (p_palier='logements_moyen' AND coalesce((etat->>'surface')::numeric,0)<2000) OR (p_palier='logements_barre' AND coalesce((etat->>'surface')::numeric,0)<=2200) THEN RETURN jsonb_build_object('ok',false,'raison','terrain_trop_petit');END IF;
 END IF;
 IF public.titulaire_est_moi(etat->>'proprietaire') IS NOT TRUE AND NOT (etat->>'proprietaire'='ville:'||pays||':'||ville AND (SELECT c.data::jsonb->>'eluId' FROM public.cycles_electoraux c WHERE c.country=pays AND c.poste_id='maire' AND c.city=ville) IS NOT DISTINCT FROM acteur) THEN
  IF etat->>'compromis' IS DISTINCT FROM 'true' OR etat->>'compromisPar' IS DISTINCT FROM acteur THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_titulaire'); END IF;
  IF jsonb_typeof(etat->'compromisExpireAt') IS DISTINCT FROM 'number' THEN
   RETURN jsonb_build_object('ok',false,'raison','compromis_expiration_inconnue'); END IF;
  IF (etat->>'compromisExpireAt')::numeric<=extract(epoch FROM clock_timestamp())*1000 THEN
   RETURN jsonb_build_object('ok',false,'raison','compromis_expire'); END IF;
 END IF;
 IF nullif(etat->>'niveau_construction','') IS NOT NULL OR jsonb_typeof(etat->'chantier')='object' THEN
  RETURN jsonb_build_object('ok',false,'raison','deja_construit'); END IF;
 permis:=etat->'permis';jour:=public.jour_de_jeu_pays(pays);
 IF jour IS NULL THEN RAISE EXCEPTION 'calendrier_indisponible'; END IF;
 IF permis->>'statut' IN ('instruction','attente_validation','valide') THEN
  RETURN jsonb_build_object('ok',false,'raison','permis_existant'); END IF;
 IF permis->>'statut'='refuse' AND permis->>'jourRefus' IS NOT NULL
    AND jour<(permis->>'jourRefus')::integer+3 THEN
  RETURN jsonb_build_object('ok',false,'raison','cooldown_refus'); END IF;
 permis:=jsonb_build_object('demandeur',acteur,'palierDemande',p_palier,'dateDepot',jour,
  'dureeInstruction',duree,'joursInstructionFaits',0,'dateInstructionTerminee',jour+duree,
  'statut','instruction','numeroDossier','URB-'||pays||'-'||p_terrain||'-'||p_requete::text,'decoupageInitial','[]'::jsonb);
 INSERT INTO public.permis_transactions_internes VALUES(txid_current(),identite);
 IF EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=public.mon_personnage() AND a.terrain=pays||'_'||p_terrain AND a.ordre='signer_compromis') THEN
 paiement:=public.payer_ordre(acteur,'deposer_demande_permis',0,0);
 ELSIF etat->>'proprietaire'='ville:'||pays||':'||ville THEN paiement:=public.permis_commune_payer_interne(acteur,pays,ville);
 ELSE paiement:=public.payer_ordre(acteur,'deposer_demande_permis',1,100);END IF;

 IF paiement->>'ok' IS DISTINCT FROM 'true' THEN
  DELETE FROM public.permis_transactions_internes WHERE transaction_id=txid_current();
  RETURN paiement;
 END IF;
 etat:=public.terrain_etat_fusionner_interne(pays||'_'||p_terrain,jsonb_build_object('permis',permis),pays);
 doc:=jsonb_build_object('id',reference,'nature','depot','numeroDossier',permis->>'numeroDossier',
  'jour',jour,'jourDepot',jour,'demandeur',acteur,'pays',pays,'ville',ville,
  'buildingId',p_terrain,'palier',p_palier,'palierLabel',CASE p_palier WHEN 'hangar' THEN 'Hangar'
   WHEN 'commerce_standard' THEN 'Commerce standard' WHEN 'commerce_premium' THEN 'Commerce premium' WHEN 'logements_petit' THEN 'Logements sociaux — petit bâtiment' WHEN 'logements_moyen' THEN 'Logements sociaux — bâtiment moyen' WHEN 'logements_barre' THEN 'Logements sociaux — barre d''immeuble' ELSE 'Building' END,
  'surfaceExploitable',etat->'surface','decoupage','[]'::jsonb);
 INSERT INTO public.dossiers_urbanisme(id,country,city,building_id,numero_dossier,type_evenement,demandeur,jour,libelle,data)
 VALUES(reference,pays,ville,p_terrain,permis->>'numeroDossier','depot',acteur,jour,'Depot de demande de permis',doc);
 reception:=public.objet_sas_deposer('document_urbanisme',acteur,jsonb_build_object('id',reference,
  'type','document_urbanisme_depot','name','Recepisse de demande de permis','icon','ti-file-text','legal',true,'documentUrbanisme',doc),reference);
 IF reception->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'document_non_confirme'; END IF;
 INSERT INTO public.permis_depots_recus VALUES(identite,p_requete,reference);
 DELETE FROM public.permis_transactions_internes WHERE transaction_id=txid_current();
 RETURN jsonb_build_object('ok',true,'etat',etat,'document',doc,'paiement',paiement);
END;$function$;

-- terrain_permis_instruction_jour(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_permis_instruction_jour(p_terrain text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE t record;e jsonb;p jsonb;doc jsonb;reception jsonb;courrier jsonb;jour text:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;n integer;d integer;ref text;plan jsonb;accord boolean:=false;instruits integer:=0;suspendu boolean;
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','serveur_requis');END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;
 e:=t.data::jsonb;p:=e->'permis';
 IF coalesce(p->>'statut','') NOT IN('instruction','attente_validation') THEN RETURN jsonb_build_object('ok',true,'ignore',true);END IF;
 IF p->>'jourInstruction'=jour THEN RETURN jsonb_build_object('ok',true,'rejeu',true);END IF;
 d:=coalesce((p->>'dureeInstruction')::integer,0);
 IF d<=0 THEN RETURN jsonb_build_object('ok',false,'raison','duree_instruction_absente');END IF;
 n:=coalesce((p->>'joursInstructionFaits')::integer,CASE WHEN p->>'statut'='attente_validation' THEN d ELSE 0 END);
 suspendu:=e->>'pnj'='cadavre' OR coalesce(e->>'succession_gel','') NOT IN('','null','false');
 p:=p||jsonb_build_object('jourInstruction',jour);
 IF NOT coalesce(suspendu,false) THEN
  IF n<d THEN n:=n+1;instruits:=1;END IF;p:=p||jsonb_build_object('joursInstructionFaits',n);accord:=n>=d;
 END IF;
 IF accord THEN
  IF e->>'acquisitionVersion'='2' AND (coalesce(p->>'numeroDossier','')='' OR coalesce(p->>'demandeur','')='' OR coalesce(e->>'city','')='') THEN RETURN jsonb_build_object('ok',false,'raison','dossier_incomplet');END IF;
  ref:='urb-tacite-'||t.id||'-'||coalesce(nullif(p->>'numeroDossier',''),'ancien-'||coalesce(p->>'dateDepot','sans-date'));
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',x->'id','label',x->'label','surface',(x->>'surface')::numeric,'destination',CASE WHEN x->>'destination'='appartement' THEN 'appartement' ELSE 'commerce' END)),'[]') INTO plan FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p->'decoupageInitial')='array' THEN p->'decoupageInitial' ELSE '[]'::jsonb END) x;
  doc:=jsonb_build_object('id',ref,'nature','accord_tacite','numeroDossier',p->'numeroDossier','jour',NULL,'jourDepot',p->'dateDepot','demandeur',p->'demandeur','pays',t.country,'ville',e->'city','buildingId',t.building_id,'batimentLabel',t.building_id,'palier',p->'palierDemande','palierLabel',p->'palierDemande','surfaceExploitable',e->'surface','decoupage',plan,'motifRefus',NULL);
  INSERT INTO public.dossiers_urbanisme(id,country,city,building_id,numero_dossier,type_evenement,demandeur,jour,libelle,data)
  VALUES(ref,t.country,e->>'city',t.building_id,p->>'numeroDossier','accord_tacite',p->>'demandeur',NULL,'Accord tacite au bénéfice de '||coalesce(nullif(p->>'demandeur',''),'un demandeur')||' pour '||coalesce(t.building_id,'un terrain')||coalesce(' ('||(p->>'palierDemande')||')','')||'.',doc);
  IF coalesce(p->>'demandeur','')<>'' THEN
  reception:=public.objet_sas_deposer('document_urbanisme',p->>'demandeur',jsonb_build_object('id',ref,'type','document_urbanisme_accord_tacite','name','Attestation d’accord tacite — '||t.building_id,'icon','ti-file-certificate','legal',true,'desc','Le délai d’instruction s’est écoulé sans décision. Votre permis de construire est accordé tacitement.','documentUrbanisme',doc),ref);
  IF reception->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'document_accord_non_confirme';END IF;
  courrier:=public.mail_systeme_poser_interne('Services d’urbanisme',p->>'demandeur','Permis accorde tacitement','Le délai d’instruction s’est écoulé sans décision. Votre permis est accordé tacitement ; retrouvez l’attestation dans vos objets à recevoir.',NULL);
  END IF;
  p:=p||jsonb_build_object('statut','valide','accordTacite',true,'jourDecision',jour);e:=e||'{"constructionAutorisee":true}';
 END IF;
 e:=e||jsonb_build_object('permis',p);
 UPDATE public.terrains_etat SET data=e::text,updated_at=clock_timestamp() WHERE id=t.id;
 RETURN jsonb_build_object('ok',true,'instruits',instruits,'suspendus',CASE WHEN coalesce(suspendu,false) THEN 1 ELSE 0 END,'accords_tacites',CASE WHEN accord THEN 1 ELSE 0 END,'courrier',courrier);
END;$function$;

-- terrain_police_echeances_traiter() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_police_echeances_traiter()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','serveur_requis');END IF;
 RETURN public.terrain_police_traiter_interne();
END;$function$;

-- terrain_police_traiter_interne(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_police_traiter_interne(p_terrain text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE t record;e jsonb;ordre jsonb;n integer:=0;ms numeric:=extract(epoch FROM clock_timestamp())*1000;
BEGIN
 FOR t IN SELECT * FROM public.terrains_etat WHERE (p_terrain IS NULL OR id=p_terrain)
 AND data::jsonb->'interventionPolice'->>'statut'='attente'
 AND (data::jsonb->'interventionPolice'->>'echeance')::numeric<=ms ORDER BY id FOR UPDATE LOOP
  e:=t.data::jsonb;ordre:=e->'interventionPolice';
  IF ordre->>'occupation' IS DISTINCT FROM coalesce(e->>'dateGeneration','historique')||':'||coalesce(e->>'pnj','') THEN
   ordre:=ordre||'{"statut":"occupation_modifiee"}';
  ELSE
   IF e->>'pnj'='cadavre' THEN
    e:=e||jsonb_build_object('enqueteJusqua',(ordre->>'echeance')::numeric+3*86400000);
   END IF;
   e:=e||'{"pnj":null,"pnjData":null,"occupationScellee":true}'::jsonb;
   ordre:=ordre||jsonb_build_object('statut','terminee','traitee',ms);n:=n+1;
  END IF;
  e:=e||jsonb_build_object('interventionPolice',ordre,'policeAppellee',NULL,'policeInterventionAt',NULL,'expulsionAt',NULL);
  UPDATE public.terrains_etat SET data=e::text,updated_at=now() WHERE id=t.id;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'interventions',n);
END;$function$;

-- terrain_proprietaire_muter(text,text,jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_proprietaire_muter(p_terrain_id text, p_titre text, p_patch jsonb, p_reference text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_data jsonb; v_cle text; v_prix numeric; v_n integer; v_nouveau text;
BEGIN
  IF p_titre = 'recompense_quete' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quete_aleatoire_supprimee');
  END IF;
  IF p_titre NOT IN ('compromis','achat_direct','recompense_quete','serveur') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titre_inconnu');
  END IF;
  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'patch_invalide');
  END IF;

  v_moi := public.mon_personnage();
  IF p_titre IN('compromis','achat_direct') AND NOT EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=v_moi) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  IF p_titre = 'serveur' THEN
    IF v_moi IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'titre_reserve_au_serveur');
    END IF;
  ELSIF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT t.id, t.data::jsonb INTO v_cle, v_data FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_cle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_introuvable'); END IF;
  v_data := coalesce(v_data, '{}'::jsonb);

  -- LE GEL SUCCESSORAL EST REFUSE AU SERVEUR, plus seulement dans le navigateur.
  IF coalesce(v_data ->> 'succession_gel', '') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;

  IF p_titre = 'compromis' THEN
    IF coalesce((v_data ->> 'compromis')::boolean, false) IS NOT TRUE
       OR (v_data ->> 'compromisPar') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_compromis');
    END IF;
  ELSIF p_titre = 'achat_direct' THEN
    IF (v_data -> 'achatDirect' ->> 'demandeur') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_achat_direct');
    END IF;
  ELSIF p_titre = 'recompense_quete' THEN
    IF NOT EXISTS (SELECT 1 FROM public.quetes_actives q
                    WHERE q.id = p_reference AND q.statut = 'resolue' AND q.resolu_par = v_moi) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_quete');
    END IF;
  END IF;

  -- LA FUSION SE FAIT SUR L'ETAT REEL, SOUS VERROU : un patch partiel n'efface plus rien, et un
  -- cache client perime ne peut plus ecraser le serveur.
  v_data := v_data || p_patch;
  v_nouveau := nullif(v_data ->> 'proprietaire', '');

  UPDATE public.terrains_etat
     SET data = v_data::text, proprietaire = v_nouveau, updated_at = now()
   WHERE id = v_cle;

  -- L'HISTORIQUE PUBLIC DE LA VENTE, DANS LA MEME TRANSACTION. Son identifiant est DATE et non
  -- horodate a la milliseconde : un rejeu le meme jour sur le meme terrain ne cree pas une seconde
  -- ligne, et le registre ne peut plus acter une vente qui n'a pas eu lieu.
  v_prix := nullif(p_patch ->> 'valeur_totale', '')::numeric;
  IF p_titre IN ('compromis','achat_direct') AND v_prix IS NOT NULL AND v_nouveau IS NOT NULL THEN
    INSERT INTO public.terrains_historique_ventes (id, country, building_id, proprietaire, prix)
    SELECT 'vente-' || t.building_id || '-' || to_char(now() AT TIME ZONE 'UTC','YYYYMMDD')
             || '-' || v_nouveau || '-' || coalesce(nullif(p_reference,''),'historique'),
           t.country, t.building_id, v_nouveau, v_prix
      FROM public.terrains_etat t WHERE t.id = v_cle
    ON CONFLICT (id) DO NOTHING;
    GET DIAGNOSTICS v_n = ROW_COUNT;
  ELSE
    v_n := 0;
  END IF;

  RETURN jsonb_build_object('ok', true, 'titre', p_titre, 'cle', v_cle,
    'proprietaire', v_nouveau, 'vente_consignee', v_n = 1, 'etat', v_data);
END; $function$;

-- terrain_rdv_notaire_accelerer(text,uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_rdv_notaire_accelerer(p_terrain text, p_requete uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; t record; a record; e jsonb; ad jsonb; r jsonb;
  ms numeric := floor(extract(epoch FROM clock_timestamp())*1000); restant numeric; nouvelle numeric;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_terrain IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE acteur = moi AND requete = p_requete;
  IF FOUND THEN
    IF a.terrain IS DISTINCT FROM p.country||'_'||p_terrain OR a.action <> 'rdv_accelerer' THEN
      RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
    SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id = a.terrain;
    RETURN a.resultat || jsonb_build_object('rejeu',true,'etat',e);
  END IF;
  IF coalesce(p.hp,0) <= 0 OR EXISTS(SELECT 1 FROM public.detention_active(moi))
     OR coalesce(p.hospitalisation->>'dateFinParis','') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible'); END IF;
  SELECT * INTO t FROM public.terrains_etat
   WHERE id = p.country||'_'||p_terrain AND country = p.country AND building_id = p_terrain FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb; ad := e->'achatDirect';
  IF coalesce(e->>'succession_gel','') <> '' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele'); END IF;
  IF jsonb_typeof(ad) IS DISTINCT FROM 'object' OR ad->>'demandeur' IS DISTINCT FROM moi THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_mon_achat_direct'); END IF;
  IF p.current_building IS DISTINCT FROM p_terrain OR p.current_city IS DISTINCT FROM e->>'city' THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
  IF (ad->>'dateAchat') !~ '^[0-9]+(\.[0-9]+)?$' THEN RETURN jsonb_build_object('ok',false,'raison','rendez_vous_invalide'); END IF;
  restant := (ad->>'dateAchat')::numeric - ms;
  IF restant <= 0 THEN RETURN jsonb_build_object('ok',false,'raison','rendez_vous_deja_arrive'); END IF;
  -- Paiement au tarif déclaré de l'ordre ; tout échec ensuite annule aussi le paiement.
  r := public.payer_ordre(moi, 'corrompre_rdv_notaire', 2, 800);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN
    RETURN jsonb_build_object('ok',false,'raison',coalesce(r->>'raison','paiement_refuse')); END IF;
  nouvelle := ms + floor(restant / 2);
  ad := ad || jsonb_build_object('dateAchat', nouvelle, 'dateLimite', nouvelle + 86400000);
  e := public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('achatDirect', ad), t.country);
  r := jsonb_build_object('ok',true,'dateAchat',nouvelle,'dateLimite',nouvelle + 86400000,'paiement',r);
  INSERT INTO public.terrain_acquisitions_recus VALUES (moi, p_requete, t.id, 'rdv_accelerer', '{}'::jsonb, r);
  UPDATE public.personnages_donnees SET updated_at = clock_timestamp() WHERE name = moi;
  RETURN r || jsonb_build_object('etat', e);
END;
$function$;

-- terrain_reamenagement_poser(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_reamenagement_poser(p_terrain_id text, p_chantier jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_final jsonb;
BEGIN
  RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_chantier IS NULL OR jsonb_typeof(p_chantier) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;
  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi LIMIT 1;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  -- LA REGLE DES DEUX ECRANS DE RECONFIGURATION, lue en base :
  --   if (!estTitulaire(ts.proprietaire)) « Vous n'etes pas proprietaire de ce batiment. »
  IF NOT public.titulaire_est_moi(v_etat ->> 'proprietaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;
  -- LISTE DE CLES, en dur : cette porte n'ecrit QUE son propre chantier. Elle ne peut donc pas
  -- effacer `chantier`, `permis`, `subdivisions` ni le compromis, meme appelee par un client
  -- modifie ou par un ecran reste ouvert pendant la nuit du cron.
  v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
               jsonb_build_object('chantierReamenagement', p_chantier), v_pays);
  RETURN jsonb_build_object('ok', true, 'etat', v_final);
END; $function$;

-- terrain_succession_annuler_compromis(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_succession_annuler_compromis(p_terrain_id text, p_succession text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_defunt text; v_cle text; v_data jsonb; v_final jsonb; v_concerne boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT t.id, coalesce(t.data::jsonb, '{}'::jsonb) INTO v_cle, v_data
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_cle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  -- LES TROIS ENGAGEMENTS QUE LE CLIENT NETTOYAIT, et les trois seules raisons de le faire : le
  -- defunt detenait le compromis, avait un achat direct en cours, ou s'etait vu proposer un
  -- transfert. Rien d'autre n'est touche.
  v_concerne := (v_data ->> 'compromisPar') = v_defunt
             OR (v_data -> 'achatDirect' ->> 'demandeur') = v_defunt
             OR (v_data ->> 'transfertPropose') = v_defunt
             OR (v_data ->> 'transfertProposePar') = v_defunt;
  IF NOT v_concerne THEN
    -- Un engagement deja nettoye n'apparait plus dans le scan du client : on repond ok sans rien
    -- ecrire, exactement comme le jumeau des entreprises.
    IF NOT (v_data ? 'compromisPar' OR v_data ? 'achatDirect' OR v_data ? 'transfertPropose') THEN
      RETURN jsonb_build_object('ok', true, 'deja_nettoye', true);
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_l_engagement_du_defunt');
  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id, jsonb_build_object(
    'compromis', NULL, 'compromisPar', NULL, 'acompte', NULL, 'compromisAt', NULL,
    'compromisExpireAt', NULL, 'achatDirect', NULL,
    'transfertPropose', NULL, 'transfertProposePar', NULL), NULL);
  RETURN jsonb_build_object('ok', true, 'etat', v_final);
END; $function$;

-- terrain_succession_geler(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_succession_geler(p_terrain_id text, p_succession text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_defunt text; v_cle text; v_data jsonb; v_final jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT t.id, coalesce(t.data::jsonb, '{}'::jsonb) INTO v_cle, v_data
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF v_cle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  -- LE TERRAIN DOIT ETRE CELUI DU DEFUNT. `titulaire_est_moi` ne sert pas ici : on compare au
  -- DEFUNT, pas a l'appelant -- mais on reconnait les memes trois formes de reference.
  IF NOT (coalesce(v_data ->> 'proprietaire', '') IN (v_defunt, 'pj:' || v_defunt)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_du_defunt',
                              'proprietaire', v_data ->> 'proprietaire');
  END IF;

  -- Rejouable sans risque : reposer le MEME gel est un no-op. Un gel par une AUTRE succession est
  -- en revanche refuse -- deux successions ne se disputent pas un bien.
  IF coalesce(v_data ->> 'succession_gel', '') NOT IN ('', p_succession) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_gele_par_une_autre_succession',
                              'gel', v_data ->> 'succession_gel');
  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
               jsonb_build_object('succession_gel', p_succession), NULL);
  RETURN jsonb_build_object('ok', true, 'gel', p_succession, 'etat', v_final);
END; $function$;

-- terrain_visites_clore_interne() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_visites_clore_interne()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v record;
BEGIN
  -- Un rafraichissement ou une sauvegarde au meme endroit conserve la visite.
  IF (NEW.country,NEW.current_city,NEW.current_building) IS NOT DISTINCT FROM
     (OLD.country,OLD.current_city,OLD.current_building) THEN RETURN NEW; END IF;
  FOR v IN SELECT t.id
    FROM public.terrain_visites_actives a
    JOIN public.terrains_etat t ON t.id=a.terrain_id
    WHERE a.personnage_id=OLD.id
      AND (t.country IS DISTINCT FROM NEW.country
           OR t.building_id IS DISTINCT FROM NEW.current_building
           OR (t.data::jsonb->>'city') IS DISTINCT FROM NEW.current_city)
    ORDER BY t.id FOR UPDATE OF t LOOP
    DELETE FROM public.terrain_visites_actives
     WHERE personnage_id=OLD.id AND terrain_id=v.id;
  END LOOP;
  RETURN NEW;
END;$function$;

-- ville_est_reelle(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ville_est_reelle(p_pays text, p_ville text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.villes v
                  WHERE v.pays = p_pays AND v.ville = p_ville);
$function$;

-- villes_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.villes_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      pays || '|' || ville || '|' || nom
           || '|' || CASE WHEN est_capitale THEN '1' ELSE '0' END
           || '|' || rang::text,
      E'\n' ORDER BY pays COLLATE "C", ville COLLATE "C")), 16)
  FROM public.villes;
$function$;
