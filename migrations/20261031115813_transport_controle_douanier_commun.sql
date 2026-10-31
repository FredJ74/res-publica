-- #219 : contrôles existants par identité, même confiscation/justice, aucun JWT remplacé.
CREATE OR REPLACE FUNCTION public.douane_controle_groupe_interne(p_nom text,p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE lieu public.personnages_donnees%ROWTYPE;d public.personnages_donnees%ROWTYPE;
 ids text[];pnjs text[];dispenses text[]:='{}';n text;v jsonb;j text;jet integer;taux numeric;obj record;
BEGIN
 IF p_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=p_nom) THEN
 RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe_requis');END IF;
 SELECT array_agg(identifiant ORDER BY identifiant) FILTER(WHERE est_pj),
 coalesce(array_agg(identifiant ORDER BY identifiant) FILTER(WHERE NOT est_pj),'{}'::text[])
 INTO ids,pnjs FROM public.groupe_participants_interne(p_nom);
 PERFORM public.pnj_groupes_verrouiller_projections_interne(pnjs);
 PERFORM name FROM public.personnages_donnees WHERE name=ANY(ids) ORDER BY name FOR UPDATE;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(pnjs) ORDER BY id FOR UPDATE;
 PERFORM id FROM public.pnj_possessions WHERE pnj_id=ANY(pnjs) ORDER BY id FOR UPDATE;
 SELECT * INTO lieu FROM public.personnages_donnees WHERE name=p_nom;
 IF NOT FOUND OR p_mode IS NULL OR p_mode NOT IN ('avion','bateau') THEN RETURN jsonb_build_object('ok',false,'raison','controle_invalide');END IF;
 IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles WHERE pays=lieu.country AND ville=lieu.current_city
 AND batiment=lieu.current_building AND pieces ? lieu.current_room) OR NOT coalesce(
 (p_mode='avion' AND lieu.current_building LIKE 'centre-multinodal-%' AND lieu.current_room IN ('hall_douanes','zone_embarquement'))
 OR (p_mode='bateau' AND lieu.current_building LIKE 'port-%' AND lieu.current_room IN ('quai_principal','quai')),false) THEN
 RETURN jsonb_build_object('ok',false,'raison','pas_au_controle');END IF;
 IF cardinality(ids)<>(SELECT count(*)+1 FROM public.groupes_pj_adhesions WHERE chef=p_nom) THEN
 RETURN jsonb_build_object('ok',false,'raison','groupe_incomplet');END IF;
 IF EXISTS(SELECT 1 FROM public.personnages_donnees pj WHERE name=ANY(ids)
 AND (pj.country,pj.current_city,pj.current_building,pj.current_room) IS DISTINCT FROM
 (lieu.country,lieu.current_city,lieu.current_building,lieu.current_room)) THEN
 RETURN jsonb_build_object('ok',false,'raison','groupe_disperse');END IF;
 IF EXISTS(SELECT 1 FROM public.pnj_membres m CROSS JOIN LATERAL public.pnj_position_effective(m.id) pe
 WHERE id=ANY(pnjs) AND (m.statut IS DISTINCT FROM 'actif' OR pe.pays IS DISTINCT FROM lieu.country)) THEN
 RETURN jsonb_build_object('ok',false,'raison','membre_pnj_indisponible');END IF;
 IF EXISTS(SELECT 1 FROM public.batailles_engagements e JOIN public.batailles b ON b.id=e.bataille_id
 JOIN public.pnj_soldats_metier sm ON sm.compagnie_id=e.compagnie_id AND sm.section_id=e.section_id AND sm.matricule=e.matricule
 WHERE sm.pnj_id=ANY(pnjs) AND e.sorti_round IS NULL AND b.statut='en_cours') THEN
 RETURN jsonb_build_object('ok',false,'raison','combat_membre_pnj');END IF;
 -- Première passe : conditions avant toute saisie. La détection garde le jet
 -- douanier existant ; une condamnation détectée passe par la vraie justice.
 FOREACH n IN ARRAY ids LOOP
  v:=public.navigation_disponibilite_interne(n);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v||jsonb_build_object('membre',n);END IF;
  IF EXISTS(SELECT 1 FROM public.ambassades_ouvertes WHERE data->>'ambassadeur'=n)
  OR EXISTS(SELECT 1 FROM public.navigation_passages_douaniers WHERE personnage=n AND corruption
   AND pays=lieu.country AND ville=lieu.current_city AND batiment=lieu.current_building AND mode=p_mode) THEN
   dispenses:=array_append(dispenses,n);CONTINUE;END IF;
  SELECT id INTO j FROM public.douane_recherches_interne(n) WHERE country=lieu.country ORDER BY id LIMIT 1;
  IF j IS NOT NULL THEN
   SELECT * INTO d FROM public.personnages_donnees WHERE name=n;
   taux:=greatest(5,70+floor(coalesce(nullif(d.resources->>'dis','')::numeric,50)/10)-public.crime_malus_isn_interne(d.country,d.current_city));
   jet:=floor(random()*100)::integer+1;
   IF jet>taux THEN
    v:=public.douane_condamnation_executer_interne(j,n);
    IF NOT coalesce((v->>'ok')::boolean,false) OR v->>'detention_id' IS NULL THEN RAISE EXCEPTION 'detention_douaniere_non_confirmee';END IF;
    RETURN v||jsonb_build_object('ok',false,'raison','controle_interception','arrestation',true,'membre',n);
   END IF;
  END IF;
 END LOOP;
 -- L'axe d'autorité, pas l'étiquette historique de l'objet, décide du magasin.
 -- Les anciens accessoires de soldats sont déjà au socle ; leur miroir est arrêté.
 IF EXISTS(SELECT 1 FROM public.pnj_possessions o WHERE pnj_id=ANY(pnjs)
 AND public.pnj_axe_verrouille(ARRAY[pnj_id],'possessions') IS NOT NULL
 AND (coalesce((objet->>'legal')::boolean,true)=false OR public.assemblee_loi_en_vigueur(lieu.country,objet,now()) IS NOT NULL)
 AND NOT public.inventaire_objet_protege(NULL,objet)) THEN
 RETURN jsonb_build_object('ok',false,'raison','axe_possessions_hors_socle');END IF;
 FOREACH n IN ARRAY ids LOOP
  IF NOT n=ANY(dispenses) THEN
   v:=public.douane_confisquer_personnage_interne(n);
   IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION 'confiscation_non_confirmee';END IF;
   IF jsonb_array_length(v->'saisis')>0 THEN
    UPDATE public.personnages_donnees SET convocations=coalesce(convocations,'[]'::jsonb)||jsonb_build_array(jsonb_build_object(
     'id','conv-'||replace(gen_random_uuid()::text,'-',''),'motif','possession_illegale_douane',
     'jourEmission',coalesce(day,1),'heureEmission',extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer,
     'jourLimite',coalesce(day,1)+1,'heureLimite',extract(hour FROM now() AT TIME ZONE 'Europe/Paris')::integer,
     'traitee',false,'limiteTs',to_char((now()+interval '24 hours') AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'))) WHERE name=n;
    PERFORM public.mail_systeme_poser_interne('Commissariat',n,'Convocation officielle',
     'Le contrôle douanier a détecté des objets prohibés ('||(v->>'noms')||'), désormais confisqués. Présentez-vous au commissariat sous 24h pour vous justifier.');
   END IF;
  END IF;
  INSERT INTO public.navigation_passages_douaniers(personnage,pays,ville,batiment,mode)
  VALUES(n,lieu.country,lieu.current_city,lieu.current_building,p_mode)
  ON CONFLICT(personnage) DO UPDATE SET pays=EXCLUDED.pays,ville=EXCLUDED.ville,batiment=EXCLUDED.batiment,mode=EXCLUDED.mode,controle_le=now();
 END LOOP;
 -- Même périmètre de saisie légal que l'inventaire ; pas de convocation PNJ
 -- ni de substitution par le payeur (Fred, 28/10).
 FOR obj IN DELETE FROM public.pnj_possessions WHERE pnj_id=ANY(pnjs)
 AND (coalesce((objet->>'legal')::boolean,true)=false OR public.assemblee_loi_en_vigueur(lieu.country,objet,now()) IS NOT NULL)
 AND NOT public.inventaire_objet_protege(NULL,objet) RETURNING * LOOP
  INSERT INTO public.confiscations_douanieres(id,personne,objet_nom,objet_type,quantite,pays,ville,building_id,room_id,reference)
  VALUES('conf-'||gen_random_uuid()::text,'pnj:'||obj.pnj_id,coalesce(obj.objet->>'name','?'),obj.objet->>'type',
   nullif(coalesce(obj.objet->>'qty',obj.objet->>'quantite'),'')::integer,lieu.country,lieu.current_city,lieu.current_building,lieu.current_room,'controle-pnj-'||obj.id);
 END LOOP;
 RETURN jsonb_build_object('ok',true,'controles',cardinality(ids)+cardinality(pnjs))||
 (SELECT jsonb_build_object('inventory',inventory,'revision',inventory_revision,'convocations',convocations) FROM public.personnages_donnees WHERE name=p_nom);
END $g$;
REVOKE ALL ON FUNCTION public.douane_controle_groupe_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.douane_controle_groupe(p_mode text,p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;v jsonb;a jsonb;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL OR p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide');END IF;
 a:=jsonb_build_object('controle',p_mode);
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT verdict INTO v FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete AND arguments=a;
 IF NOT FOUND THEN
  IF EXISTS(SELECT 1 FROM public.navigation_requetes WHERE acteur=moi AND requete=p_requete) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  v:=public.douane_controle_groupe_interne(moi,p_mode);
  INSERT INTO public.navigation_requetes(acteur,requete,arguments,verdict) VALUES(moi,p_requete,a,v);
 ELSIF coalesce((v->>'ok')::boolean,false) AND NOT public.douane_passage_valide_interne(moi,p_mode) THEN
  RETURN jsonb_build_object('ok',false,'raison','controle_a_renouveler');
 END IF;
 -- Un reçu ne remet jamais en circulation un inventaire historique.
 RETURN v||(SELECT jsonb_build_object('inventory',inventory,'revision',inventory_revision,'convocations',convocations)
 FROM public.personnages_donnees WHERE name=moi);
END;
$g$;
REVOKE ALL ON FUNCTION public.douane_controle_groupe(text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.douane_controle_groupe(text,uuid) TO authenticated;
