-- 2 novembre 2026, decisions de Fred : fumer une boulette de shit.
-- Consommer est LEGAL (seuls l'achat et le transport sont illegaux : trace achat_drogue et
-- objet legal=false, deja saisi par la douane). L'effet ne depend pas de l'age de la boulette.
--   moral +10 (plafond 100), ENT +2 jusqu'a minuit (Paris), PA -1 (plancher 0), sante -5.
--   Le bonus d'ENT ne se cumule pas (cle boulette_ent dans effets_actifs) ; moral, PA et sante
--   s'appliquent a chaque boulette. La sante ne descend pas sous 1 : fumer n'hospitalise pas.
--   Chaque consommation laisse une trace consommation_drogue (7 jours) pour rumeurs et enquetes.
-- Patch en place de la definition de production (deux fragments verifies le 02/11), pas de
-- reecriture. Independante de l'ecran : l'ancien ecran ne propose pas de fumer.
DO $$
DECLARE f text; ancien_type text; nouveau_type text; ancienne_fin text; nouvelle_fin text;
BEGIN
  SELECT pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure) INTO f;
  IF position('boulette_consommation_effets' IN f) > 0 THEN RETURN; END IF;
  ancien_type := 'IN (''medicament'',''explosif'',''poison''))';
  nouveau_type := 'IN (''medicament'',''explosif'',''poison'',''drogue''))';
  ancienne_fin := '''aliment_frais'',v_frais);
 END IF;
 RETURN v_r;';
  nouvelle_fin := '''aliment_frais'',v_frais);
 END IF;
 IF coalesce(v_item->>''type'','''')=''drogue'' THEN /* boulette_consommation_effets */
  DECLARE d_p public.personnages_donnees%rowtype; d_now numeric; d_fin numeric; d_eff jsonb; d_bonus boolean;
  BEGIN
   SELECT * INTO d_p FROM public.personnages_donnees WHERE name=p_acteur;
   d_now:=extract(epoch FROM clock_timestamp())*1000;
   d_fin:=extract(epoch FROM ((date_trunc(''day'',now() AT TIME ZONE ''Europe/Paris'')+interval ''1 day'') AT TIME ZONE ''Europe/Paris''))*1000;
   SELECT coalesce(jsonb_agg(e),''[]''::jsonb) INTO d_eff FROM jsonb_array_elements(coalesce(d_p.effets_actifs,''[]''::jsonb)) e
    WHERE jsonb_typeof(e)=''object'' AND coalesce((e->>''expireA'')::numeric,0)>d_now;
   d_bonus:=NOT EXISTS(SELECT 1 FROM jsonb_array_elements(d_eff) e WHERE e->>''cle''=''boulette_ent'');
   IF d_bonus THEN
    d_eff:=d_eff||jsonb_build_array(jsonb_build_object(''cle'',''boulette_ent'',''cible'',''pj'',
     ''deltas'',jsonb_build_object(''ENT'',2),''libelle'',''Détendu (boulette)'',''poseA'',d_now,''expireA'',d_fin));
   END IF;
   UPDATE public.personnages_donnees SET
     pa=greatest(0,coalesce(pa,0)-1),
     hp=CASE WHEN coalesce(hp,0)>1 THEN greatest(1,hp-5) ELSE hp END,
     moral=least(100,coalesce(moral,0)+10),
     effets_actifs=d_eff
    WHERE name=p_acteur RETURNING * INTO d_p;
   INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration)
    VALUES(''conso-''||d_p.id::text||''-''||md5(random()::text||clock_timestamp()::text),p_acteur,NULL,''consommation_drogue'',
     coalesce(d_p.country,''republic''),d_p.current_city,public.jour_de_jeu_pays(coalesce(d_p.country,''republic'')),
     public.jour_de_jeu_pays(coalesce(d_p.country,''republic''))+7);
   v_r:=v_r||jsonb_build_object(''drogue'',true,''pa'',d_p.pa,''hp'',d_p.hp,''moral'',d_p.moral,
     ''effets_actifs'',d_eff,''bonus_ent'',d_bonus,''effets'',jsonb_build_object(''moral'',10,''ENT'',2,''pa'',-1,''hp'',-5));
  END;
 END IF;
 RETURN v_r;';
  IF position(ancien_type IN f) = 0 OR position(ancienne_fin IN f) = 0 THEN
    RAISE EXCEPTION 'inventaire_consommer_definition_non_examinee';
  END IF;
  f := replace(replace(f, ancien_type, nouveau_type), ancienne_fin, nouvelle_fin);
  EXECUTE f;
END $$;
