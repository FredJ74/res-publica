-- 2 novembre 2026, decisions de Fred : consommer de l'Estadine (legal ; achat et transport illegaux).
--   Montee immediate : PA +3 (plafond 30), moral +15, CHA +2 pendant 6 h (non cumulable).
--   Descente 6 h apres CHAQUE dose : moral -25, sante -10 (jamais sous 1), -3 PA a la recharge
--   suivante (bonus_pa_differe).
--   Usure cognitive : INT -0,1 par dose, chaque dose s'efface au bout de 15 jours (reversible).
--   Trace consommation_estadine (7 jours) pour rumeurs et enquetes.
-- Les descentes echues sont appliquees par le serveur seul (horloge du serveur) : a chaque
-- consommation, a la demande de l'ecran (drogues_descentes_appliquer) et chaque nuit pour tous
-- (drogues_descentes_nuit, cron-minuit).

CREATE OR REPLACE FUNCTION public.drogues_descentes_appliquer_interne(p_acteur text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d public.personnages_donnees%rowtype; t numeric := extract(epoch FROM clock_timestamp())*1000;
  eff jsonb; m integer; h integer; pd integer; n integer;
BEGIN
  SELECT * INTO d FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable'); END IF;
  SELECT coalesce(sum((e#>>'{descente,moral}')::int),0), coalesce(sum((e#>>'{descente,hp}')::int),0),
         coalesce(sum((e#>>'{descente,pa_differe}')::int),0), count(*)
    INTO m, h, pd, n
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.effets_actifs)='array' THEN d.effets_actifs ELSE '[]'::jsonb END) e
   WHERE jsonb_typeof(e)='object' AND e ? 'descente' AND coalesce((e->>'descenteAppliquee')::boolean,false) = false
     AND coalesce((e->>'descenteA')::numeric, 0) <= t;
  IF n = 0 THEN RETURN jsonb_build_object('ok',true,'appliquees',0); END IF;
  SELECT jsonb_agg(CASE WHEN jsonb_typeof(e)='object' AND e ? 'descente'
            AND coalesce((e->>'descenteAppliquee')::boolean,false) = false
            AND coalesce((e->>'descenteA')::numeric, 0) <= t
          THEN e || jsonb_build_object('descenteAppliquee', true, 'libelle', 'Descente subie (Estadine)')
          ELSE e END ORDER BY o)
    INTO eff FROM jsonb_array_elements(d.effets_actifs) WITH ORDINALITY x(e, o);
  UPDATE public.personnages_donnees SET
     moral = greatest(0, least(100, coalesce(moral,0) + m)),
     hp = CASE WHEN coalesce(hp,0) > 1 THEN greatest(1, hp + h) ELSE hp END,
     bonus_pa_differe = greatest(-30, coalesce(bonus_pa_differe,0) + pd),
     effets_actifs = eff
   WHERE name = p_acteur RETURNING * INTO d;
  RETURN jsonb_build_object('ok',true,'appliquees',n,'moral',d.moral,'hp',d.hp,'effets_actifs',eff,
    'descente',jsonb_build_object('moral',m,'hp',h,'pa_differe',pd));
END;
$function$;

CREATE OR REPLACE FUNCTION public.drogues_descentes_appliquer()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text := public.mon_personnage();
BEGIN
  IF auth.uid() IS NULL OR acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  RETURN public.drogues_descentes_appliquer_interne(acteur);
END;
$function$;

CREATE OR REPLACE FUNCTION public.drogues_descentes_nuit()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v jsonb; total integer := 0; erreurs jsonb := '[]'::jsonb;
BEGIN
  FOR r IN SELECT name FROM public.personnages_donnees
            WHERE jsonb_typeof(effets_actifs)='array' AND effets_actifs::text LIKE '%"descente"%' LOOP
    BEGIN
      v := public.drogues_descentes_appliquer_interne(r.name);
      total := total + coalesce((v->>'appliquees')::int, 0);
    EXCEPTION WHEN others THEN
      erreurs := erreurs || jsonb_build_array(jsonb_build_object('personnage', r.name, 'erreur', SQLERRM));
    END;
  END LOOP;
  RETURN jsonb_build_object('ok',true,'appliquees',total,'erreurs',erreurs);
END;
$function$;

CREATE OR REPLACE FUNCTION public.estadine_consommer_effets(p_acteur text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d public.personnages_donnees%rowtype; t numeric; eff jsonb; montee boolean; c_6h constant numeric := 21600000;
BEGIN
  PERFORM public.drogues_descentes_appliquer_interne(p_acteur);
  SELECT * INTO d FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  t := extract(epoch FROM clock_timestamp())*1000;
  SELECT coalesce(jsonb_agg(e),'[]'::jsonb) INTO eff
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.effets_actifs)='array' THEN d.effets_actifs ELSE '[]'::jsonb END) e
   WHERE jsonb_typeof(e)='object' AND coalesce((e->>'expireA')::numeric,0) > t;
  montee := NOT EXISTS (SELECT 1 FROM jsonb_array_elements(eff) e WHERE e->>'cle' = 'estadine_montee');
  IF montee THEN
    eff := eff || jsonb_build_array(jsonb_build_object('cle','estadine_montee','cible','pj',
      'deltas',jsonb_build_object('CHA',2),'libelle','Montée (Estadine)','poseA',t,'expireA',t + c_6h));
  END IF;
  eff := eff || jsonb_build_array(
    jsonb_build_object('cle','estadine_descente_'||t::bigint,'cible','pj','deltas','{}'::jsonb,
      'libelle','Descente à venir (Estadine)','poseA',t,'descenteA',t + c_6h,
      'descente',jsonb_build_object('moral',-25,'hp',-10,'pa_differe',-3),'expireA',t + c_6h + 604800000),
    jsonb_build_object('cle','estadine_int_'||t::bigint,'cible','pj','deltas',jsonb_build_object('INT',-0.1),
      'libelle','Usure cognitive (Estadine)','poseA',t,'expireA',t + 1296000000));
  UPDATE public.personnages_donnees SET
     pa = least(30, coalesce(pa,0) + 3),
     moral = least(100, coalesce(moral,0) + 15),
     effets_actifs = eff
   WHERE name = p_acteur RETURNING * INTO d;
  INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration)
   VALUES('conso-est-'||d.id::text||'-'||md5(random()::text||clock_timestamp()::text), p_acteur, NULL,
    'consommation_estadine', coalesce(d.country,'republic'), d.current_city,
    public.jour_de_jeu_pays(coalesce(d.country,'republic')), public.jour_de_jeu_pays(coalesce(d.country,'republic'))+7);
  RETURN jsonb_build_object('drogue',true,'produit','estadine','pa',d.pa,'hp',d.hp,'moral',d.moral,
    'effets_actifs',eff,'montee_nouvelle',montee,'descente_a',t + c_6h,
    'effets',jsonb_build_object('pa',3,'moral',15,'CHA',2,'INT',-0.1));
END;
$function$;

REVOKE ALL ON FUNCTION public.drogues_descentes_appliquer_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.estadine_consommer_effets(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.drogues_descentes_nuit() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drogues_descentes_nuit() TO service_role;
REVOKE ALL ON FUNCTION public.drogues_descentes_appliquer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.drogues_descentes_appliquer() TO authenticated;

-- Branchement dans inventaire_consommer (patch en place du bloc pose par 20261102200000).
DO $$
DECLARE f text; ancien text; nouveau text;
BEGIN
  SELECT pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure) INTO f;
  IF position('estadine_consommation_effets' IN f) > 0 THEN RETURN; END IF;
  ancien := ' IF coalesce(v_item->>''type'','''')=''drogue'' THEN /* boulette_consommation_effets */';
  nouveau := ' IF coalesce(v_item->>''type'','''')=''drogue'' AND coalesce(v_item->>''drogue'','''')=''estadine'' THEN /* estadine_consommation_effets */
  v_r:=v_r||public.estadine_consommer_effets(p_acteur);
 ELSIF coalesce(v_item->>''type'','''')=''drogue'' THEN /* boulette_consommation_effets */';
  IF position(ancien IN f) = 0 THEN RAISE EXCEPTION 'inventaire_consommer_definition_non_examinee'; END IF;
  EXECUTE replace(f, ancien, nouveau);
END $$;
