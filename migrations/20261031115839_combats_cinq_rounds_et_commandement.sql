-- #219 NON APPLIQUEE. Fred : cinq rounds sans désengagement volontaire ; chef seul.
-- Dépend de 20261031115835 et 20261031115836. Aucun nouveau moteur/jet/horloge.
CREATE OR REPLACE FUNCTION public.combat_desengagement_autorise_interne(p_round integer,p_engage boolean)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO public,pg_temp AS $g$
 SELECT coalesce(NOT p_engage OR p_round>=5,false);
$g$;
REVOKE ALL ON FUNCTION public.combat_desengagement_autorise_interne(integer,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.militaire_bataille_rendre_groupe_interne(p_bataille bigint,p_groupe text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE b public.batailles%ROWTYPE;pnjs text[];ids text[];
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT * INTO b FROM public.batailles WHERE id=p_bataille FOR UPDATE;
 IF NOT FOUND OR b.statut<>'en_cours' THEN RETURN jsonb_build_object('ok',false,'raison','bataille_terminee');END IF;
 IF p_groupe IS NULL OR NOT EXISTS(SELECT 1 FROM public.batailles_groupes WHERE bataille_id=p_bataille AND groupe_id=p_groupe AND sorti_round IS NULL) THEN RETURN jsonb_build_object('ok',false,'raison','groupe_inactif');END IF;
 IF NOT public.combat_desengagement_autorise_interne(b.round_courant,true) THEN RETURN jsonb_build_object('ok',false,'raison','cinq_rounds_obligatoires');END IF;
 SELECT array_agg(personnage ORDER BY personnage) FILTER(WHERE personnage IS NOT NULL),
 coalesce(array_agg(pnj_id ORDER BY pnj_id) FILTER(WHERE pnj_id IS NOT NULL),'{}'::text[])
 INTO ids,pnjs FROM public.batailles_engagements WHERE bataille_id=p_bataille AND groupe_id=p_groupe AND sorti_round IS NULL;
 PERFORM public.pnj_groupes_verrouiller_projections_interne(pnjs);
 PERFORM name FROM public.personnages_donnees WHERE name=ANY(ids) ORDER BY name FOR UPDATE;
 PERFORM id FROM public.pnj_membres WHERE id=ANY(pnjs) ORDER BY id FOR UPDATE;
 UPDATE public.personnages_donnees SET pa=0 WHERE name=ANY(ids);
 UPDATE public.pnj_membres SET pa=0,maj_le=now() WHERE id=ANY(pnjs) AND statut='actif';
 -- Aucun décès, soin, inventaire, dissolution ou déplacement dans une reddition.
 UPDATE public.batailles_engagements SET sorti_round=b.round_courant,etat_final=CASE WHEN pnj_id IS NOT NULL AND EXISTS(SELECT 1 FROM public.pnj_membres m WHERE m.id=pnj_id AND m.statut='mort') THEN 'mort' ELSE 'neutralise' END
 WHERE bataille_id=p_bataille AND groupe_id=p_groupe AND sorti_round IS NULL;
 UPDATE public.batailles_groupes SET sorti_round=b.round_courant,attente_depuis=NULL
 WHERE bataille_id=p_bataille AND groupe_id=p_groupe AND sorti_round IS NULL;
 PERFORM public.pnj_groupes_projeter_interne(pnjs);
 RETURN jsonb_build_object('ok',true,'reddition',true,'groupe',p_groupe);
END $g$;
REVOKE ALL ON FUNCTION public.militaire_bataille_rendre_groupe_interne(bigint,text) FROM PUBLIC,anon,authenticated,service_role;

-- Même fenêtre de 90 secondes existante, ouverte à partir du cinquième round.
CREATE OR REPLACE FUNCTION public.militaire_bataille_arbitrer_groupes(p_bataille_id bigint,p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE g record;n integer:=0;
BEGIN
 IF p_round<5 THEN RETURN 0;END IF;
 -- Ne pas ouvrir de décisions pour prolonger un combat déjà terminé.
 IF (SELECT count(DISTINCT camp) FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND sorti_round IS NULL)<=1 THEN RETURN 0;END IF;
 FOR g IN SELECT * FROM public.batailles_groupes WHERE bataille_id=p_bataille_id AND sorti_round IS NULL ORDER BY groupe_id FOR UPDATE LOOP
  IF g.decision='tenir' THEN CONTINUE;END IF;
  IF g.decision='replier' OR g.leader IS NULL OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.name=g.leader AND d.pa>0 AND coalesce(d.hp,100)>0 AND (d.est_emprisonne IS NULL OR d.est_emprisonne='null'::jsonb))
   OR (g.attente_depuis IS NOT NULL AND now()-g.attente_depuis>=interval '90 seconds') THEN
   -- Réaction automatique du moteur préexistant ; jamais un nouveau chef PJ.
   PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id,g.groupe_id,p_round);
  ELSIF g.attente_depuis IS NULL THEN
   UPDATE public.batailles_groupes SET attente_depuis=now() WHERE bataille_id=p_bataille_id AND groupe_id=g.groupe_id;n:=n+1;
  ELSE n:=n+1;END IF;
 END LOOP;
 RETURN n;
END $g$;
REVOKE ALL ON FUNCTION public.militaire_bataille_arbitrer_groupes(bigint,integer) FROM PUBLIC,anon,authenticated,service_role;

DO $commandes$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_commande_interne(bigint,text,integer,uuid)'::regprocedure);
 IF position('-- combat_commandement_cinq_v1' IN s)>0 THEN RETURN;END IF;
 s:=replace(s,'''engager'',''continuer'',''tenir'',''replier''','''engager'',''continuer'',''tenir'',''replier'',''rendre''');
 a:='  -- Avancer le monde reste permis à tout participant, même déjà évacué,';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_commande_corps_non_examine';END IF;
 b:=$b$  -- combat_commandement_cinq_v1
  IF p_action IN ('replier','rendre') AND NOT public.combat_desengagement_autorise_interne(b.round_courant,true) THEN
   RETURN jsonb_build_object('ok',false,'raison','cinq_rounds_obligatoires');END IF;
  IF NOT EXISTS(SELECT 1 FROM public.batailles_groupes gg JOIN public.batailles_engagements e ON e.bataille_id=gg.bataille_id AND e.groupe_id=gg.groupe_id
    WHERE gg.bataille_id=p_bataille AND e.personnage=moi AND gg.leader=moi) THEN
   -- Un membre peut seulement faire constater la résolution automatique si le chef
   -- est hors de combat. Aucun ordre volontaire ni transfert de commandement.
   IF p_action<>'continuer' OR EXISTS(SELECT 1 FROM public.batailles_groupes gg JOIN public.batailles_engagements e ON e.bataille_id=gg.bataille_id AND e.groupe_id=gg.groupe_id
     JOIN public.personnages_donnees d ON d.name=gg.leader WHERE gg.bataille_id=p_bataille AND e.personnage=moi AND d.pa>0 AND coalesce(d.hp,100)>0) THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_chef_de_groupe');END IF;
  END IF;
$b$||a;
 s:=replace(s,a,b);
 a:='  v:=CASE WHEN p_action=''engager'' THEN public.militaire_bataille_engager_interne()';
 b:=$b$  IF p_action='rendre' THEN
   v:=public.militaire_bataille_rendre_groupe_interne(p_bataille,(SELECT groupe_id FROM public.batailles_groupes WHERE bataille_id=p_bataille AND leader=moi AND sorti_round IS NULL));
   IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
   -- Avancer constate la fin par les engagements réels, sans jet de sanction.
   v:=v||public.militaire_bataille_avancer(p_bataille);
  ELSE
   IF p_action='continuer' AND EXISTS(SELECT 1 FROM public.batailles_groupes gg JOIN public.personnages_donnees d ON d.name=gg.leader WHERE gg.bataille_id=p_bataille AND gg.leader=moi AND gg.sorti_round IS NULL AND d.pa>0 AND coalesce(d.hp,100)>0) THEN
    UPDATE public.batailles_groupes SET decision='tenir',attente_depuis=NULL WHERE bataille_id=p_bataille AND leader=moi AND sorti_round IS NULL;
   END IF;
$b$||a;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_execution_non_examinee';END IF;s:=replace(s,a,b);
 a:='      ELSE public.militaire_bataille_decider_interne(p_bataille,p_action) END;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_execution_fin_non_examinee';END IF;s:=replace(s,a,a||' END IF;');
 EXECUTE s;
END $commandes$;
DO $round$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_round(bigint)'::regprocedure);
 IF position('-- combat_decision_consommee_v1' IN s)>0 THEN RETURN;END IF;
 a:='  v_attente := public.militaire_bataille_arbitrer_groupes(p_bataille_id, v_round);';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_round_arbitrage_non_examine';END IF;
 EXECUTE replace(s,a,' -- combat_decision_consommee_v1'||chr(10)||' UPDATE public.batailles_groupes SET decision=NULL WHERE bataille_id=p_bataille_id AND sorti_round IS NULL;'||chr(10)||a);
END $round$;
DO $lecture$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_etat(bigint)'::regprocedure);
 IF position('''contrat_combat'', 2' IN s)>0 THEN RETURN;END IF;
 a:='    ''je_suis_leader'', (g.leader IS NOT NULL AND g.leader = v_moi),';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_lecture_commandement_non_examinee';END IF;
 EXECUTE replace(s,a,a||chr(10)||$b$    'contrat_combat', 2,
    'peut_decider', (g.leader=v_moi AND EXISTS(SELECT 1 FROM public.groupe_combattants_interne(v_moi,NULL,v_id) c WHERE c.est_pj AND c.identifiant=v_moi)),
    'resolution_automatique', (g.leader IS NULL OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.name=g.leader AND d.pa>0 AND coalesce(d.hp,100)>0)),
$b$);
END $lecture$;
