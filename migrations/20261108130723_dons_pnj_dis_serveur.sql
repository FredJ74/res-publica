-- Tirages dons PNJ : terminer DIS dans le dispatcher transactionnel existant.
-- Dépend de hg379_lot3c_v1 ; aucune table, aucun coût, aucun montant nouveau.
-- ÉCRAN DÉPENDANT : déployer le client contrat_dis=1 d'abord, attendre READY,
-- puis Claude joue le banc annulé et applique. Avant SQL, le client reçoit un refus
-- contexte_invalide AVANT paiement ; après SQL, les anciens clients sont refusés
-- AVANT paiement. Aucun double jet DIS ni double écriture entre versions.
-- DUP : port exact de getMembresGroupeAvecStat + getStatEffective('DUP'),
-- en lisant les colonnes persistantes. Les profils ci-dessous proviennent de
-- PNJ_STATS_PAR_JOB (main d633524f), pas des nouveaux profils car_dup du socle,
-- dont certaines valeurs diffèrent : ne pas changer la formule en les substituant.
DO $prevol$
BEGIN
 IF to_regprocedure('public.jauges_ordre_executer(text,uuid,jsonb)') IS NULL
 OR position('hg379_lot3c_v1' in pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure))=0
 THEN RAISE EXCEPTION 'tirages_dons_dispatcher_non_examine';END IF;
 IF to_regprocedure('public.don_pnj_dup_interne(text)') IS NOT NULL AND
 position('tirages_dons_dup_v1' in pg_get_functiondef(to_regprocedure('public.don_pnj_dup_interne(text)')))=0
 THEN RAISE EXCEPTION 'tirages_dons_helper_non_examine';END IF;
END $prevol$;

CREATE OR REPLACE FUNCTION public.don_pnj_dup_interne(p_acteur text)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp
AS $f$
DECLARE a public.personnages_donnees; e jsonb; v numeric; total numeric:=0; n integer:=0;
 bonus numeric:=0; normale numeric; reel jsonb; entree jsonb; ids_locaux jsonb; ids_reels jsonb;
 instant numeric:=extract(epoch from clock_timestamp())*1000;
BEGIN
 -- tirages_dons_dup_v1 : port de la formule existante, aucune stat déclarée par l'écran.
 SELECT * INTO a FROM public.personnages_donnees WHERE name=p_acteur;
 IF NOT FOUND THEN RAISE EXCEPTION 'don_acteur_absent';END IF;
 -- Réutiliser la projection du socle, jamais croire les inGroupe/stats du miroir ancien.
 -- Si ce miroir contredit le socle, annuler le don plutôt que choisir un nouveau taux.
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(a.employes,'[]')) x
   WHERE x ? 'inGroupe' AND jsonb_typeof(x->'inGroupe') NOT IN('boolean','null')) THEN
  RAISE EXCEPTION 'don_miroir_groupe_format_non_examine';
 END IF;
 reel:=public.employe_mes_employes();
 IF reel->'ok' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'don_groupe_non_confirme';END IF;
 SELECT coalesce(jsonb_agg(x->>'pnjId' ORDER BY x->>'pnjId'),'[]') INTO ids_locaux
  FROM jsonb_array_elements(coalesce(a.employes,'[]')) x WHERE coalesce((x->>'inGroupe')::boolean,false);
 SELECT coalesce(jsonb_agg(x->>'pnj_id' ORDER BY x->>'pnj_id'),'[]') INTO ids_reels
  FROM jsonb_array_elements(reel->'employes') x WHERE (x->>'porte')::boolean;
 IF ids_locaux IS DISTINCT FROM ids_reels THEN RAISE EXCEPTION 'don_groupe_historique_non_reconcilie';END IF;
 IF jsonb_typeof(a.stats->'DUP')='number' THEN total:=(a.stats->>'DUP')::numeric;n:=1;END IF;
 FOR e IN SELECT x FROM jsonb_array_elements(coalesce(a.employes,'[]'::jsonb)) x LOOP
  IF coalesce((e->>'inGroupe')::boolean,false) THEN
   IF jsonb_typeof(e->'stats'->'DUP')='number' THEN v:=(e->'stats'->>'DUP')::numeric;
   ELSE v:=CASE e->>'job'
          WHEN 'serveur' THEN 4
          WHEN 'hotelier' THEN 5
          WHEN 'barman' THEN 5
          WHEN 'escort' THEN 8
          WHEN 'commissaire' THEN 6
          WHEN 'policier' THEN 4
          WHEN 'inspecteur' THEN 5
          WHEN 'militaire' THEN 3
          WHEN 'soldat' THEN 3
          WHEN 'garde' THEN 3
          WHEN 'general' THEN 5
          WHEN 'journaliste' THEN 6
          WHEN 'redacteur' THEN 6
          WHEN 'medecin' THEN 4
          WHEN 'infirmier' THEN 3
          WHEN 'avocat' THEN 7
          WHEN 'juge' THEN 5
          WHEN 'banquier' THEN 7
          WHEN 'commercant' THEN 6
          WHEN 'marchande' THEN 5
          WHEN 'professeur' THEN 4
          WHEN 'syndicaliste' THEN 5
          WHEN 'loge' THEN 8
          WHEN 'venerable' THEN 8
          WHEN 'grand_pretre' THEN 6
          WHEN 'douanier' THEN 6
          WHEN 'docker' THEN 3
          WHEN 'portier' THEN 3
          WHEN 'secretaire' THEN 5
          WHEN 'lobbyiste' THEN 8
          WHEN 'hotesse' THEN 5
          WHEN 'default' THEN 4
          ELSE NULL END;
   END IF;
   SELECT x INTO entree FROM jsonb_array_elements(reel->'employes') x WHERE x->>'pnj_id'=e->>'pnjId';
   IF v IS DISTINCT FROM (entree->'caracteristiques'->>'DUP')::numeric THEN
    RAISE EXCEPTION 'don_caracteristique_historique_non_reconciliee';
   END IF;
   IF v IS NOT NULL THEN total:=total+v;n:=n+1;END IF;
  END IF;
 END LOOP;
 FOR e IN SELECT x FROM jsonb_array_elements(coalesce(a.effets_actifs,'[]'::jsonb)) x LOOP
  IF coalesce((e->>'expireA')::numeric,0)>instant THEN
   bonus:=bonus+coalesce((e->'deltas'->>'DUP')::numeric,0);
  END IF;
 END LOOP;
 normale:=CASE WHEN n>0 THEN total/n ELSE 8 END+bonus;
 IF a.stats_affaiblies ? 'DUP' THEN
  RETURN greatest(1,floor(normale*greatest(0,least(1,coalesce(a.hp,0)::numeric/100))+0.5));
 END IF;
 RETURN floor(normale+0.5); -- Math.round, y compris les demi-entiers négatifs.
END $f$;
REVOKE ALL ON FUNCTION public.don_pnj_dup_interne(text) FROM PUBLIC,anon,authenticated,service_role;

DO $patch$
DECLARE corps text; avant text; apres text;
BEGIN
 corps:=pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure);
 IF position('tirages_dons_dis_v1' in corps)>0 THEN RETURN;END IF;
 avant:='  v_job text; v_obj jsonb; v_montant integer; v_moral_gain integer:=0; v_hp_gain integer:=0;';
 apres:=avant||E'\n  -- tirages_dons_dis_v1\n  don_delta integer:=0; don_taux integer; don_jet integer; don_reussi boolean; don_base numeric;';
 IF (length(corps)-length(replace(corps,avant,'')))/length(avant)<>1 THEN RAISE EXCEPTION 'tirages_dons_declarations';END IF;
 corps:=replace(corps,avant,apres);
 avant:=$a$IF p_contexte-ARRAY['nom','montant']<>'{}'::jsonb OR jsonb_typeof(p_contexte->'nom') IS DISTINCT FROM 'string'$a$;
 apres:=$a$IF p_contexte-ARRAY['nom','montant','contrat_dis']<>'{}'::jsonb OR p_contexte->'contrat_dis' IS DISTINCT FROM '1'::jsonb OR jsonb_typeof(p_contexte->'nom') IS DISTINCT FROM 'string'$a$;
 IF (length(corps)-length(replace(corps,avant,'')))/length(avant)<>1 THEN RAISE EXCEPTION 'tirages_dons_contrat';END IF;
 corps:=replace(corps,avant,apres);
 avant:=$a$    pa_cout:=NULL;
    publication:=jsonb_build_object('job',v_job,'refuse',v_detecte,'montant',CASE WHEN v_detecte THEN 0 ELSE v_montant END,$a$;
 apres:=$a$    -- Même ordre, même verrou d'acteur, même reçu et même transaction que le débit.
    -- Le ||50 de l'ancien écran est conservé, y compris son cas DIS=0 ; aucun correctif de règle caché.
    don_base:=CASE WHEN coalesce((a.resources->>'dis')::numeric,0)=0 THEN 50 ELSE (a.resources->>'dis')::numeric END;
    IF v_detecte THEN don_delta:=-15;
    ELSIF v_job IN('commissaire','policier','inspecteur','juge') THEN
      don_taux:=least(CASE v_job WHEN 'commissaire' THEN 70 WHEN 'policier' THEN 65 WHEN 'inspecteur' THEN 70 ELSE 55 END,
        (CASE v_job WHEN 'commissaire' THEN 30 WHEN 'policier' THEN 25 WHEN 'inspecteur' THEN 35 ELSE 20 END)
        +floor(public.don_pnj_dup_interne(a.name)*2));
      don_jet:=floor(random()*100)::integer+1;don_reussi:=don_jet<=don_taux;
      don_delta:=-CASE WHEN don_reussi THEN CASE v_job WHEN 'commissaire' THEN 5 WHEN 'policier' THEN 3 WHEN 'inspecteur' THEN 5 ELSE 8 END
        ELSE CASE v_job WHEN 'commissaire' THEN 20 WHEN 'policier' THEN 15 WHEN 'inspecteur' THEN 15 ELSE 25 END END;
    ELSIF v_job='banquier' THEN don_delta:=5;END IF;
    pa_cout:=NULL;
    publication:=jsonb_build_object('contrat_dis',1,'dis_taux',don_taux,'dis_jet',don_jet,'dis_reussi',don_reussi,'dis_delta',don_delta,
      'job',v_job,'refuse',v_detecte,'montant',CASE WHEN v_detecte THEN 0 ELSE v_montant END,$a$;
 IF (length(corps)-length(replace(corps,avant,'')))/length(avant)<>1 THEN RAISE EXCEPTION 'tirages_dons_branche';END IF;
 corps:=replace(corps,avant,apres);
 avant:=$a$  ressources:=coalesce(a.resources,'{}'::jsonb)-'popBase'-'infBase';$a$;
 apres:=avant||E'\n  IF don_delta<>0 THEN ressources:=jsonb_set(ressources,''{dis}'',to_jsonb(greatest(0,least(100,don_base+don_delta))));END IF;';
 IF (length(corps)-length(replace(corps,avant,'')))/length(avant)<>1 THEN RAISE EXCEPTION 'tirages_dons_ecriture';END IF;
 corps:=replace(corps,avant,apres);
 -- Deux chemins : verdict initial et rejeu. Le jet reste celui du reçu, DIS est relue.
 avant:=$a$'pa',a.pa,'hp',a.hp$a$;
 apres:=$a$'dis',coalesce((a.resources->>'dis')::numeric,50),'pa',a.pa,'hp',a.hp$a$;
 IF (length(corps)-length(replace(corps,avant,'')))/length(avant)<>2 THEN RAISE EXCEPTION 'tirages_dons_reponses';END IF;
 corps:=replace(corps,avant,apres);
 EXECUTE corps;
END $patch$;
NOTIFY pgrst,'reload schema';
