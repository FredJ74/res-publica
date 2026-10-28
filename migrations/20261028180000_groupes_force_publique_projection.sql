-- #219. Préparation interdépendante, NON APPLIQUÉE.
-- Les identités/emplois restent dans les miroirs institutionnels ; leurs positions
-- ne sont plus importées dès que l'axe commun est activé par l'étape suivante.
CREATE OR REPLACE FUNCTION public.pnj_groupes_projeter_institutions_interne(p_ids text[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $g$
DECLARE b record; etat jsonb; suivant jsonb; liste jsonb; cle text; agents text; valeur jsonb;
BEGIN
 FOR b IN SELECT DISTINCT t.id,t.country,t.city,t.building_id FROM public.batiments_etat t
  JOIN public.pnj_membres m ON m.pays=t.country
   AND m.proprietaire_perimetre=t.city||':'||t.building_id
  WHERE m.id=ANY(p_ids) AND m.proprietaire_institution IN ('police','douane')
   AND m.famille IN ('policier','douanier') ORDER BY t.id LOOP
  SELECT data INTO valeur FROM public.batiments_etat WHERE id=b.id FOR UPDATE;
  etat:=public.batiment_etat_lire(valeur);
  IF jsonb_typeof(etat) IS DISTINCT FROM 'object' THEN
   RAISE EXCEPTION 'projection_service_etat_invalide'; END IF;
  cle:=CASE WHEN b.building_id IN ('commissariat','commissariat-local') THEN 'effectifsPolice' ELSE 'effectifsDouane' END;
  agents:=CASE WHEN cle='effectifsPolice' THEN 'policiers' ELSE 'douaniers' END;
  IF jsonb_typeof(etat->cle->agents) IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION 'projection_service_liste_invalide'; END IF;
  SELECT coalesce(jsonb_agg(CASE WHEN m.id IS NULL OR m.statut<>'actif' THEN d.objet
    ELSE d.objet||jsonb_build_object('buildingId',pe.building_id,'roomId',pe.room_id,
      'rueNoeudId',pe.rue_noeud_id) END ORDER BY d.rang),'[]'::jsonb) INTO liste
   FROM jsonb_array_elements(etat->cle->agents) WITH ORDINALITY d(objet,rang)
   LEFT JOIN public.pnj_membres m ON m.id=CASE WHEN cle='effectifsPolice'
    THEN public.police_pnj_id(b.country,b.city,d.objet->>'matricule')
    ELSE public.douane_pnj_id(b.country,b.city,d.objet->>'matricule') END
   LEFT JOIN LATERAL public.pnj_position_effective(m.id) pe ON true;
  suivant:=jsonb_set(etat,ARRAY[cle,agents],liste,false);
  -- Conserver le format historique (objet ou chaîne JSON), les PA et tous les autres champs.
  suivant:=CASE WHEN jsonb_typeof(valeur)='string' THEN to_jsonb(suivant::text) ELSE suivant END;
  -- Cette condition termine la récursion du trigger de miroir après un seul rapprochement.
  UPDATE public.batiments_etat SET data=suivant WHERE id=b.id AND data IS DISTINCT FROM suivant;
 END LOOP;
END $g$;
REVOKE ALL ON FUNCTION public.pnj_groupes_projeter_institutions_interne(text[]) FROM PUBLIC,anon,authenticated,service_role;

DO $miroirs$
DECLARE f record; s text; a text; b text; champ text;
BEGIN
 FOR f IN SELECT * FROM (VALUES ('pnj_miroir_police','policier'),('pnj_miroir_douane','douanier')) t(nom,famille) LOOP
  s:=pg_get_functiondef(('public.'||f.nom||'(text,text,text)')::regprocedure);
  IF position('-- groupes_force_publique_position_v1' IN s)>0 THEN CONTINUE; END IF;
  FOREACH champ IN ARRAY CASE WHEN f.famille='policier'
    THEN ARRAY['ville','building_id','room_id','rue_noeud_id']
    ELSE ARRAY['ville','building_id','room_id'] END LOOP
   a:=champ||' = EXCLUDED.'||champ;
   b:=champ||' = CASE WHEN public.pnj_axe_au_socle('''||f.famille||''',''position_leader'')'
    ||' THEN pnj_membres.'||champ||' ELSE EXCLUDED.'||champ||' END';
   IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN
    RAISE EXCEPTION 'miroir_position_definition_non_examinee: %/%',f.nom,champ; END IF;
   s:=replace(s,a,b);
  END LOOP;
  a:='  RETURN jsonb_build_object(''ok'', true, ''synchronises'', v_maj, ''partis'', v_partis);';
  b:='  -- groupes_force_publique_position_v1'||chr(10)
   ||'  PERFORM public.pnj_groupes_projeter_institutions_interne(v_vus);'||chr(10)||a;
  IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN
   RAISE EXCEPTION 'miroir_position_verdict_non_examine: %',f.nom; END IF;
  EXECUTE replace(s,a,b);
 END LOOP;
END $miroirs$;
