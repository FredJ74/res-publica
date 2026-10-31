-- #219 PRÉPARÉE, après 223800. Même doctrine, rounds et fenêtre de 90 secondes.
-- Un chef présent n'attend pas le clic du chef adverse pour poursuivre son ordre.
CREATE OR REPLACE FUNCTION public.militaire_bataille_arbitrer_groupes(p_bataille_id bigint,p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE g record;n integer:=0;acteur text;commande boolean;choix text;
BEGIN
 IF p_round<5 THEN RETURN 0;END IF;
 IF (SELECT count(DISTINCT camp) FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND sorti_round IS NULL)<=1 THEN RETURN 0;END IF;
 acteur:=public.mon_personnage();
 commande:=EXISTS(SELECT 1 FROM public.batailles_groupes WHERE bataille_id=p_bataille_id AND leader=acteur AND sorti_round IS NULL);
 FOR g IN SELECT * FROM public.batailles_groupes WHERE bataille_id=p_bataille_id AND sorti_round IS NULL ORDER BY groupe_id FOR UPDATE LOOP
  IF g.decision='tenir' THEN CONTINUE;END IF;
  IF g.decision='replier' OR g.leader IS NULL OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees d WHERE d.name=g.leader AND d.pa>0 AND coalesce(d.hp,100)>0 AND (d.est_emprisonne IS NULL OR d.est_emprisonne='null'::jsonb))
   OR (g.attente_depuis IS NOT NULL AND now()-g.attente_depuis>=interval '90 seconds') THEN
   PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id,g.groupe_id,p_round);
  ELSIF commande AND g.leader IS DISTINCT FROM acteur THEN
   -- Ce n'est pas un ordre donné à l'adversaire par l'acteur : le serveur
   -- applique sa doctrine existante, sans changer de chef ni de caractéristiques.
   choix:=public.militaire_bataille_decision_effective(p_bataille_id,g.camp);
   IF choix='replier' THEN PERFORM public.militaire_bataille_decrocher_groupe(p_bataille_id,g.groupe_id,p_round);
   ELSE UPDATE public.batailles_groupes SET decision='tenir',attente_depuis=NULL WHERE bataille_id=p_bataille_id AND groupe_id=g.groupe_id;END IF;
  ELSIF g.attente_depuis IS NULL THEN
   UPDATE public.batailles_groupes SET attente_depuis=now() WHERE bataille_id=p_bataille_id AND groupe_id=g.groupe_id;n:=n+1;
  ELSE n:=n+1;END IF;
 END LOOP;
 RETURN n;
END $g$;
REVOKE ALL ON FUNCTION public.militaire_bataille_arbitrer_groupes(bigint,integer) FROM PUBLIC,anon,authenticated,service_role;

-- Rattrapage par le calendrier serveur existant ; aucune nouvelle horloge.
-- Les interactions continuent d'appliquer l'échéance de 90 s sans attendre ce passage quotidien.
CREATE OR REPLACE FUNCTION public.militaire_batailles_echues_traiter()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE b record;v jsonb;n integer:=0;erreurs jsonb:='[]';avant integer;apres integer;pas integer;
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','serveur_requis');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 FOR b IN SELECT id FROM public.batailles WHERE statut='en_cours' ORDER BY id FOR UPDATE SKIP LOCKED LOOP
  BEGIN
   -- Borne technique déjà utilisée par militaire_bataille_round, pas de round gratuit.
   FOR pas IN 0..200 LOOP
    SELECT round_courant INTO avant FROM public.batailles WHERE id=b.id;
    v:=public.militaire_bataille_avancer(b.id);
    IF NOT coalesce((v->>'ok')::boolean,false) THEN
     RAISE EXCEPTION USING ERRCODE='P2196',MESSAGE='progression_non_confirmee';END IF;
    EXIT WHEN coalesce((v->>'terminee')::boolean,false) OR coalesce((v->>'en_attente')::integer,0)>0;
    SELECT round_courant INTO apres FROM public.batailles WHERE id=b.id;
    EXIT WHEN apres IS NOT DISTINCT FROM avant;
   END LOOP;
   n:=n+1;
  EXCEPTION WHEN OTHERS THEN
   -- L'échec de cette bataille annule ses effets, pas ceux des autres traitements.
   erreurs:=erreurs||jsonb_build_array(jsonb_build_object('bataille',b.id,'code',SQLSTATE));
  END;
 END LOOP;
 RETURN jsonb_build_object('ok',jsonb_array_length(erreurs)=0,'traitees',n,'erreurs',erreurs);
END $g$;
REVOKE ALL ON FUNCTION public.militaire_batailles_echues_traiter() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.militaire_batailles_echues_traiter() TO service_role;

-- Une évacuation mutuelle n'est pas un anéantissement : ne pas annoncer de morts fictifs.
DO $issue$
DECLARE f text;s text;a text;
BEGIN
 FOREACH f IN ARRAY ARRAY['militaire_bataille_avancer(bigint)','militaire_bataille_round(bigint)'] LOOP
  s:=pg_get_functiondef(('public.'||f)::regprocedure);
  IF position('-- bataille_issue_reelle_v1' IN s)>0 THEN CONTINUE;END IF;
  a:='WHEN v_debout = 0 THEN ''aneantissement_mutuel''';
  IF position(a IN s)=0 THEN RAISE EXCEPTION 'bataille_issue_non_examinee:%',f;END IF;
  s:=replace(s,a,'WHEN v_debout = 0 THEN CASE WHEN EXISTS(SELECT 1 FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND etat_final IS DISTINCT FROM ''mort'') THEN NULL ELSE ''aneantissement_mutuel'' END');
  EXECUTE overlay(s placing '-- bataille_issue_reelle_v1'||chr(10) FROM position('BEGIN' IN s) FOR 0);
 END LOOP;
END $issue$;
