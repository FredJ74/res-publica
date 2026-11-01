-- #219, dépendance PR233/20261029181000. Fred, 29/10 : issue réelle des
-- rounds, aucun score final ni tirage de remplacement. Ne pas activer seul.
DO $penal$
BEGIN
 IF EXISTS(SELECT 1 FROM (VALUES ('agression','delit_mineur',25,1,500),('meurtre','crime',25,2,1500)) r(fn,type,taux,jours,amende)
  LEFT JOIN public.actes_illegaux a ON a.fn=r.fn
  WHERE a.fn IS NULL OR (a.type,a.detect_rate,a.peine_jours,a.amende) IS DISTINCT FROM (r.type,r.taux,r.jours,r.amende)) THEN
  RAISE EXCEPTION 'squatteurs_baremes_PR233_non_conformes';
 END IF;
END $penal$;
ALTER TABLE public.batailles ADD COLUMN IF NOT EXISTS contexte jsonb NOT NULL DEFAULT '{}'::jsonb;
-- Un contexte civil explicite rejoint les mêmes camps/actions, sans fabriquer
-- une guerre entre pays. Le contexte est produit par le serveur, jamais reçu
-- par la porte d'engagement militaire publique.
DO $camps$
DECLARE s text;a text;b text;
BEGIN
 s:=pg_get_functiondef('public.militaire_camps_hostiles(bigint,text)'::regprocedure);
 IF position('-- bataille_civile_camps_v1' IN s)>0 THEN RETURN;END IF;
 a:='OR ( public.mutinerie_pays_du_camp(p_camp)';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_camps_corps_non_examine';END IF;
 b:=E'OR EXISTS(SELECT 1 FROM public.batailles b WHERE b.id=p_bataille_id AND b.contexte->>''type''=''squatteurs'' AND ((p_camp,e.camp)=(b.contexte->>''camp_acteur'',b.contexte->>''camp_squatteurs'') OR (e.camp,p_camp)=(b.contexte->>''camp_acteur'',b.contexte->>''camp_squatteurs'')))\n -- bataille_civile_camps_v1\n '||a;
 EXECUTE replace(s,a,b);
END $camps$;
DO $issue$
DECLARE s text;a text;b text;
BEGIN
 IF to_regprocedure('public.terrain_squatteurs_issue_interne(text,text,text,uuid)') IS NULL THEN RAISE EXCEPTION 'squatteurs_dependance_PR233_absente';END IF;
 s:=pg_get_functiondef('public.terrain_squatteurs_issue_interne(text,text,text,uuid)'::regprocedure);
 s:=replace(s,'CREATE OR REPLACE FUNCTION public.terrain_squatteurs_issue_interne(','CREATE OR REPLACE FUNCTION public.terrain_squatteurs_issue_bataille_interne(');
 a:='p_issue text, p_requete uuid)';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'squatteurs_signature_non_examinee';END IF;
 s:=replace(s,a,'p_issue text, p_requete uuid, p_bataille bigint)');
 a:='DECLARE p record;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'squatteurs_declaration_non_examinee';END IF;
 s:=replace(s,a,'DECLARE v_b public.batailles%ROWTYPE; v_constate text; '||substring(a FROM 9));
 a:=$a$  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur'); END IF;
  IF p_issue IS NULL OR p_issue NOT IN ('defaite','neutralises','tues') OR p_requete IS NULL THEN$a$;
 b:=$b$  -- Autorité : helper privé, appelé par le moteur, sans modifier le JWT.
  SELECT * INTO v_b FROM public.batailles WHERE id=p_bataille FOR UPDATE;
  IF NOT FOUND OR v_b.statut<>'terminee' OR v_b.contexte->>'type' IS DISTINCT FROM 'squatteurs'
   OR v_b.contexte->>'acteur' IS DISTINCT FROM p_acteur OR v_b.batiment IS DISTINCT FROM p_terrain
   OR nullif(v_b.contexte->>'camp_squatteurs','') IS NULL
   OR nullif(v_b.contexte->>'camp_acteur','') IS NULL THEN
   RETURN jsonb_build_object('ok',false,'raison','combat_non_constate');END IF;
  IF NOT EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=v_b.contexte->>'camp_squatteurs') THEN
   RETURN jsonb_build_object('ok',false,'raison','adversaires_absents');END IF;
  IF NOT EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=v_b.contexte->>'camp_acteur' AND personnage=p_acteur) THEN
   RETURN jsonb_build_object('ok',false,'raison','acteur_non_engage');END IF;
  IF EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=v_b.contexte->>'camp_squatteurs' AND sorti_round IS NULL) THEN
   IF EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=v_b.contexte->>'camp_acteur' AND sorti_round IS NULL) THEN
    RETURN jsonb_build_object('ok',false,'raison','combat_interrompu');END IF;
   -- Le contrat immobilier scalaire ne décrit pas encore corps ET survivants.
   IF EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=v_b.contexte->>'camp_squatteurs' AND etat_final='mort') THEN
    RETURN jsonb_build_object('ok',false,'raison','corps_et_survivants_a_raccorder');END IF;
   v_constate:='defaite';
  ELSIF EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=v_b.contexte->>'camp_squatteurs' AND etat_final='mort') THEN v_constate:='tues';
  ELSIF NOT EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille AND camp=v_b.contexte->>'camp_squatteurs' AND etat_final IS DISTINCT FROM 'neutralise') THEN v_constate:='neutralises';
  ELSE RETURN jsonb_build_object('ok',false,'raison','combat_interrompu');END IF;
  IF p_issue IS DISTINCT FROM v_constate THEN RETURN jsonb_build_object('ok',false,'raison','issue_non_constatee');END IF;
  IF p_issue NOT IN ('defaite','neutralises','tues') OR p_requete IS NULL THEN$b$;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'squatteurs_garde_non_examinee';END IF;s:=replace(s,a,b);
 a:=$a$  IF FOUND THEN RETURN a.resultat || jsonb_build_object('rejeu',true); END IF;$a$;
 b:=$b$  IF FOUND THEN
   IF a.terrain IS DISTINCT FROM v_b.pays||'_'||p_terrain OR a.action IS DISTINCT FROM 'squatteurs_issue'
     OR a.parametres IS DISTINCT FROM jsonb_build_object('issue',p_issue,'bataille',p_bataille) THEN
     RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
   RETURN a.resultat || jsonb_build_object('rejeu',true);END IF;$b$;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'squatteurs_recu_non_examine';END IF;s:=replace(s,a,b);
 s:=replace(s,'p.country||''_''||p_terrain','v_b.pays||''_''||p_terrain');
 a:=$a$  IF p.current_building IS DISTINCT FROM p_terrain OR p.current_city IS DISTINCT FROM e->>'city' THEN$a$;
 b:=$b$  IF v_b.batiment IS DISTINCT FROM p_terrain OR v_b.ville IS DISTINCT FROM e->>'city' THEN$b$;
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'squatteurs_lieu_non_examine';END IF;s:=replace(s,a,b);
 s:=replace(s,'''issue'',issue,''occupation''','''issue'',issue,''bataille'',p_bataille,''occupation''');
 s:=replace(s,'jsonb_build_object(''issue'',p_issue), r','jsonb_build_object(''issue'',p_issue,''bataille'',p_bataille), r');
 EXECUTE s;
END $issue$;
REVOKE ALL ON FUNCTION public.terrain_squatteurs_issue_bataille_interne(text,text,text,uuid,bigint) FROM PUBLIC,anon,authenticated,service_role;
-- Aucun ouvrant public ou tirage de profil inventé : les groupes de squatteurs
-- persistants, leurs résistances distinctes et l'amorçage restent à raccorder.
