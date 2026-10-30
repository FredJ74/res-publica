-- #219 PRÉPARÉE : activation avec le client d'ouverture à reçu uniquement.
-- Le corps de préparation a été extrait avant fermeture ; aucun deuxième jet.
CREATE OR REPLACE FUNCTION public.crime_neutraliser(p_cible text,p_mode text,p_per_pnj integer DEFAULT 10)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
 SELECT jsonb_build_object('ok',false,'raison','combat_universel_requis');
$g$;
-- Une décision automatique de reddition utilise le même résolveur que les PJ.
DO $automate$
DECLARE s text;a text;
BEGIN
 s:=pg_get_functiondef('public.militaire_bataille_arbitrer_groupes(bigint,integer)'::regprocedure);
 IF position('-- combat_automate_reddition_v1' IN s)>0 THEN RETURN;END IF;
 a:=' IF p_round<5 THEN RETURN 0;END IF;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_automate_phase_non_examinee';END IF;
 s:=replace(s,a,$b$ -- combat_automate_reddition_v1
 IF p_round<5 THEN
  IF p_round=0 AND EXISTS(SELECT 1 FROM public.batailles WHERE id=p_bataille_id AND contexte->>'phase'='choix') THEN
   FOR g IN SELECT * FROM public.batailles_groupes WHERE bataille_id=p_bataille_id AND sorti_round IS NULL AND leader IS NULL ORDER BY groupe_id LOOP
    choix:=public.militaire_bataille_decision_effective(p_bataille_id,g.camp);
    IF choix='rendre' THEN PERFORM public.militaire_bataille_rendre_groupe_interne(p_bataille_id,g.groupe_id);
    ELSIF choix='replier' THEN PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id,g.groupe_id,p_round);END IF;
   END LOOP;
  END IF;
  RETURN 0;
 END IF;$b$);
 a:='  IF g.decision=''tenir'' THEN CONTINUE;END IF;';
 IF position(a IN s)=0 THEN RAISE EXCEPTION 'combat_automate_decision_non_examinee';END IF;
 s:=replace(s,a,' IF g.leader IS NULL AND public.militaire_bataille_decision_effective(p_bataille_id,g.camp)=''rendre'' THEN PERFORM public.militaire_bataille_rendre_groupe_interne(p_bataille_id,g.groupe_id);CONTINUE;END IF;'||chr(10)||a);EXECUTE s;
END $automate$;
