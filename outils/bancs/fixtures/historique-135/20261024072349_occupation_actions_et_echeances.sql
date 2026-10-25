-- #135 : seuls les parametres deja declares dans data.js, aucune valeur de combat ajoutee.
BEGIN;
CREATE TABLE IF NOT EXISTS public.terrain_actions_regles (id boolean PRIMARY KEY DEFAULT true CHECK(id),data jsonb NOT NULL);
ALTER TABLE public.terrain_actions_regles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.terrain_actions_regles FROM PUBLIC,anon,authenticated;
INSERT INTO public.terrain_actions_regles VALUES(true,$regles${"indices":{"republic":{"ISN":30,"IE":50,"ID":40,"IS":45,"IP":40},"narco":{"ISN":15,"IE":30,"ID":20,"IS":25,"IP":40},"soviet":{"ISN":70,"IE":40,"ID":30,"IS":35,"IP":40},"khalija":{"ISN":60,"IE":65,"ID":50,"IS":40,"IP":40}},"bonus":{"criminelle":[{"grade":0,"valeur":5},{"grade":1,"valeur":10},{"grade":2,"valeur":15},{"grade":3,"valeur":20}],"religieuse":[],"economique":[],"syndicale":[],"loge":[{"grade":2,"valeur":10}]}}$regles$::jsonb) ON CONFLICT(id) DO UPDATE SET data=excluded.data;
CREATE TABLE IF NOT EXISTS public.terrain_actions_recus (
 acteur uuid NOT NULL,requete uuid NOT NULL,terrain text NOT NULL,occupation text NOT NULL,action text NOT NULL,resultat jsonb NOT NULL,
 PRIMARY KEY(acteur,requete));
ALTER TABLE public.terrain_actions_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.terrain_actions_recus FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.terrain_police_traiter_interne(p_terrain text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
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
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_police_traiter_interne(text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.terrain_police_echeances_traiter() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','serveur_requis');END IF;
 RETURN public.terrain_police_traiter_interne();
END;$f$;
REVOKE ALL ON FUNCTION public.terrain_police_echeances_traiter() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.terrain_police_echeances_traiter() TO service_role;
COMMIT;
