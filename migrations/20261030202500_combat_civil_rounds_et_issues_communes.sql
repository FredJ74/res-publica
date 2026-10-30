-- #219 PRÉPARÉE : règles civiles dans les mêmes fonctions de bataille.
DO $adapter$
DECLARE s text;f text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_camps_hostiles(bigint,text)'::regprocedure);
 IF position('''civil''' IN s)=0 THEN EXECUTE replace(s,'b.contexte->>''type''=''squatteurs''','b.contexte->>''type'' IN (''squatteurs'',''civil'')');END IF;
 -- La phase initiale est choisie par le serveur, pas par un numéro envoyé par l'écran.
 FOREACH f IN ARRAY ARRAY['militaire_bataille_commande_interne(bigint,text,integer,uuid)','militaire_bataille_rendre_groupe_interne(bigint,text)'] LOOP
  s:=pg_get_functiondef(('public.'||f)::regprocedure);
  IF position('-- combat_choix_initial_v1' IN s)=0 THEN
   a:='combat_desengagement_autorise_interne(b.round_courant,true)';
   IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_phase_non_examinee:%',f;END IF;
   s:=replace(s,a,'combat_desengagement_autorise_interne(b.round_courant,NOT (b.round_courant=0 AND b.contexte->>''phase''=''choix''))');
   EXECUTE overlay(s placing '-- combat_choix_initial_v1'||chr(10) FROM position('BEGIN' IN s) FOR 0);
  END IF;
 END LOOP;
 s:=pg_get_functiondef('public.militaire_bataille_round(bigint)'::regprocedure);
 IF position('-- combat_phase_engagee_v1' IN s)=0 THEN
  a:='  v_round := b.round_courant + 1;';IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_round_non_examine';END IF;
  EXECUTE replace(s,a,' -- combat_phase_engagee_v1'||chr(10)||' UPDATE public.batailles SET contexte=jsonb_set(contexte,''{phase}'',''"combat"''::jsonb) WHERE id=p_bataille_id AND contexte->>''type'' IN (''civil'',''squatteurs'');'||chr(10)||a);
 END IF;
 -- VOL est la compétence du combat civil/policier déjà employée par combat_coup_resoudre.
 s:=pg_get_functiondef('public.militaire_bataille_combattants(bigint,text)'::regprocedure);
 IF position('-- combat_civil_VOL_v1' IN s)=0 THEN
  a:='coalesce((pd.competences_militaires->>''combat_rapproche'')::numeric, 0)';
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_lecteur_PJ_non_examine';END IF;
  s:=replace(s,a,'CASE WHEN EXISTS(SELECT 1 FROM public.batailles b WHERE b.id=p_bataille_id AND b.contexte->>''type'' IN (''civil'',''squatteurs'')) THEN coalesce((pd.stats->>''VOL'')::numeric,8) ELSE '||a||' END');
  a:='0::numeric,0::numeric,(af.cle IS NOT NULL)';IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_lecteur_PNJ_non_examine';END IF;
  s:=replace(s,a,'0::numeric,CASE WHEN EXISTS(SELECT 1 FROM public.batailles b WHERE b.id=p_bataille_id AND b.contexte->>''type'' IN (''civil'',''squatteurs'')) THEN m.car_vol::numeric ELSE 0::numeric END,(af.cle IS NOT NULL)');
  EXECUTE replace(s,'AS $function$','AS $function$'||chr(10)||'-- combat_civil_VOL_v1');
 END IF;
 -- Une neutralisation civile utilise le coma existant, pas une infirmerie militaire.
 s:=pg_get_functiondef('public.militaire_bataille_neutralisation_terminale_interne(bigint,jsonb,integer)'::regprocedure);
 IF position('-- combat_civil_terminal_v1' IN s)=0 THEN
  a:='BEGIN';s:=overlay(s placing 'BEGIN -- combat_civil_terminal_v1'||chr(10)||' IF EXISTS(SELECT 1 FROM public.batailles WHERE id=p_bataille_id AND contexte->>''type'' IN (''civil'',''squatteurs'')) THEN UPDATE public.personnages_donnees SET hp=least(coalesce(hp,100),0) WHERE name=act->>''cib_nom'';RETURN;END IF;' FROM position(a IN s) FOR length(a));EXECUTE s;
 END IF;
 s:=pg_get_functiondef('public.militaire_bataille_etat(bigint)'::regprocedure);
 a:='''id'', b.id, ''statut'', b.statut';IF position('''phase_initiale''' IN s)=0 THEN
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_etat_non_examine';END IF;
  EXECUTE replace(s,a,'''phase_initiale'',(b.round_courant=0 AND b.contexte->>''phase''=''choix''),'||a);END IF;
END $adapter$;
-- Le choix de l'agresseur borne son arme, pas celles des compagnons/défenseurs.
DO $arme$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_combattants(bigint,text)'::regprocedure);
 IF position('-- combat_mode_ouverture_v1' IN s)>0 THEN RETURN;END IF;
 a:='LIMIT 1) af ON true';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_arme_feu_non_examinee';END IF;
 s:=overlay(s placing 'LIMIT 1) af ON NOT EXISTS(SELECT 1 FROM public.batailles b WHERE b.id=p_bataille_id AND b.contexte->>''acteur''=e.personnage AND b.contexte->>''mode''<>''feu'')' FROM position(a IN s) FOR length(a));
 a:='LIMIT 1) ac ON true';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_arme_cac_non_examinee';END IF;
 s:=overlay(s placing 'LIMIT 1) ac ON NOT EXISTS(SELECT 1 FROM public.batailles b WHERE b.id=p_bataille_id AND b.contexte->>''acteur''=e.personnage AND b.contexte->>''mode''<>''arme'')' FROM position(a IN s) FOR length(a));
 EXECUTE replace(s,'AS $function$','AS $function$'||chr(10)||'-- combat_mode_ouverture_v1');
END $arme$;
-- Seule l'issue réelle du PNJ unique est acceptée ; la fuite n'est pas une mort.
DO $terrain$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.terrain_squatteurs_issue_bataille_interne(text,text,text,uuid,bigint)'::regprocedure);
 IF position('-- occupant_unique_v1' IN s)>0 THEN RETURN;END IF;
 a:='  IF NOT EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=v_b.contexte->>''camp_squatteurs'') THEN';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'terrain_contrat_non_examine';END IF;
 s:=replace(s,a,' -- occupant_unique_v1'||chr(10)||' IF (SELECT count(*) FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=v_b.contexte->>''camp_squatteurs'')<>1 THEN RETURN jsonb_build_object(''ok'',false,''raison'',''occupant_non_unique'');END IF;'||chr(10)||a);
 s:=replace(s,'AND etat_final IS DISTINCT FROM ''neutralise'') THEN v_constate:=''neutralises''','AND coalesce(etat_final,'''') NOT IN (''neutralise'',''replie'')) THEN v_constate:=''neutralises''');EXECUTE s;
END $terrain$;
CREATE OR REPLACE FUNCTION public.combat_finaliser_interne(p_bataille bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE b public.batailles%ROWTYPE;issue text;v jsonb;
BEGIN
 SELECT * INTO b FROM public.batailles WHERE id=p_bataille FOR UPDATE;
 IF b.statut<>'terminee' OR b.contexte->>'type' NOT IN ('civil','squatteurs') THEN RETURN '{}'::jsonb;END IF;
 IF b.contexte ? 'resultat_civil' THEN RETURN b.contexte->'resultat_civil';END IF;
 IF EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=b.camp_b AND etat_final='mort') THEN issue:='tues';
 ELSIF NOT EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=b.camp_b AND sorti_round IS NULL) THEN issue:='neutralises';
 ELSE issue:='defaite';END IF;
 IF b.contexte->>'type'='squatteurs' THEN
  v:=public.terrain_squatteurs_issue_bataille_interne(b.batiment,b.contexte->>'acteur',issue,(b.contexte->>'requete')::uuid,p_bataille);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION 'terrain_issue_non_confirmee:%',v;END IF;
 ELSE
  IF issue<>'defaite' THEN
   PERFORM public.crime_tracer_interne(b.contexte->>'acteur',CASE WHEN issue='tues' THEN 'meurtre' ELSE 'agression' END,b.contexte->>'cible');
   PERFORM public.crime_detecter_interne(b.contexte->>'acteur',CASE WHEN issue='tues' THEN 'meurtre' ELSE 'agression' END,true);
  ELSE
   -- Conserver le motif d'échec du corps vivant de crime_neutraliser, sans
   -- rejouer son jet ni prélever une amende dans ce résolveur.
   PERFORM public.crime_rechercher_interne(b.contexte->>'acteur','tentative_assassinat','crime');
  END IF;
  v:=jsonb_build_object('ok',true,'issue',issue);
 END IF;
 UPDATE public.batailles SET contexte=jsonb_set(contexte,'{resultat_civil}',v) WHERE id=p_bataille;
 RETURN v;
END $g$;
REVOKE ALL ON FUNCTION public.combat_finaliser_interne(bigint) FROM PUBLIC,anon,authenticated,service_role;
DO $fin$
DECLARE s text;f text;a text;
BEGIN
 FOREACH f IN ARRAY ARRAY['militaire_bataille_round(bigint)','militaire_bataille_avancer(bigint)'] LOOP
  s:=pg_get_functiondef(('public.'||f)::regprocedure);
  IF position('-- combat_fin_civile_v1' IN s)>0 THEN CONTINUE;END IF;
  a:=CASE WHEN f LIKE '%_round(%' THEN '  RETURN jsonb_build_object(''ok'', true, ''round'', v_round' ELSE '    RETURN jsonb_build_object(''ok'', true, ''terminee'', true' END;
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_fin_corps_non_examine:%',f;END IF;
  EXECUTE replace(s,a,' -- combat_fin_civile_v1'||chr(10)||' PERFORM public.combat_finaliser_interne(p_bataille_id);'||chr(10)||a);
 END LOOP;
END $fin$;
-- Un chef neutralisé reste avec ses compagnons : le moteur poursuit, sans
-- tenter de transporter une personne incapable ni nommer un remplaçant.
DO $chef$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_arbitrer_groupes(bigint,integer)'::regprocedure);
 IF position('-- chef_neutralise_continue_v1' IN s)>0 THEN RETURN;END IF;
 a:='  IF g.decision=''tenir'' THEN CONTINUE;END IF;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_chef_arbitrage_non_examine';END IF;
 EXECUTE replace(s,a,$b$  -- chef_neutralise_continue_v1
  IF NOT EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND groupe_id=g.groupe_id AND sorti_round IS NULL) THEN
   UPDATE public.batailles_groupes SET sorti_round=p_round,attente_depuis=NULL WHERE bataille_id=p_bataille_id AND groupe_id=g.groupe_id;CONTINUE;END IF;
  IF g.leader IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=g.leader AND pa>0 AND coalesce(hp,100)>0) THEN
   UPDATE public.batailles_groupes SET decision='tenir',attente_depuis=NULL WHERE bataille_id=p_bataille_id AND groupe_id=g.groupe_id;CONTINUE;END IF;
$b$||a);
END $chef$;
