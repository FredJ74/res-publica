-- Montrouge SSM : un rendez-vous nominatif pour le jour suivant (Europe/Paris).
-- Réutilise le moteur de mail et la demande de logement social existants.
-- Prévol des deux fonctions vivantes : 03/11/2026. Échec fermé si les corps divergent.

-- Même pour un ordre gratuit sans prélèvement, la source canonique contient
-- le triplet. Le miroir de production et sa sentinelle évoluent ENSEMBLE,
-- sous verrou et empreintes contrôlées. Les 461 coûts historiques ne changent pas.
DO $coutssm$
DECLARE h text; n bigint; sentinelle text;
BEGIN
 LOCK TABLE public.ordres_couts IN SHARE ROW EXCLUSIVE MODE;
 SELECT count(*),md5(string_agg(fn||'|'||pa||'|'||cost,E'\n'
     ORDER BY fn COLLATE "C",pa,cost))
   INTO n,h FROM public.ordres_couts;
 SELECT empreinte INTO STRICT sentinelle
 FROM public.ordres_couts_empreinte WHERE seul FOR UPDATE;
 IF n=462 AND h='ff9d27096e7e8dbd3fbca1da39d0f2f5'
   AND sentinelle='ff9d27096e7e8dbd' THEN RETURN; END IF;
 IF n<>461 OR h<>'0ffc6e1caad1f58114eeba150d3d5f48'
   OR sentinelle<>'0ffc6e1caad1f581' THEN
   RAISE EXCEPTION 'ssm_miroir_couts_prevol_non_conforme';
 END IF;
 INSERT INTO public.ordres_couts(fn,pa,cost)
 VALUES ('ssm_demander_rendezvous',0,0) ON CONFLICT DO NOTHING;
 SELECT count(*),md5(string_agg(fn||'|'||pa||'|'||cost,E'\n'
     ORDER BY fn COLLATE "C",pa,cost))
   INTO n,h FROM public.ordres_couts;
 IF n<>462 OR h<>'ff9d27096e7e8dbd3fbca1da39d0f2f5' THEN
   RAISE EXCEPTION 'ssm_miroir_couts_apres_non_conforme';
 END IF;
 UPDATE public.ordres_couts_empreinte
 SET empreinte=left(h,16),pose_le=clock_timestamp()
 WHERE seul;
 IF NOT FOUND THEN RAISE EXCEPTION 'ssm_sentinelle_absente'; END IF;
END
$coutssm$;

CREATE TABLE IF NOT EXISTS public.ssm_rendezvous (
  personnage text PRIMARY KEY,
  user_id uuid NOT NULL,
  demande_le date NOT NULL,
  rendezvous_le date NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT ssm_rendezvous_sept_jours CHECK
    (rendezvous_le > demande_le AND rendezvous_le <= demande_le + 7)
);
ALTER TABLE public.ssm_rendezvous ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ssm_rendezvous FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.ssm_rendezvous_valide_interne(p_personnage text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $ssm$
 SELECT EXISTS (
  SELECT 1
  FROM public.ssm_rendezvous rdv
  JOIN public.personnages_donnees pj ON pj.name = rdv.personnage
  WHERE rdv.personnage = p_personnage
    AND rdv.user_id = pj.user_id
    AND rdv.rendezvous_le = (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date
 );
$ssm$;
REVOKE ALL ON FUNCTION public.ssm_rendezvous_valide_interne(text)
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.ssm_rendezvous_demander()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $ssm$
DECLARE
 v_nom text := public.mon_personnage();
 v_pj public.personnages_donnees%ROWTYPE;
 v_actuel public.ssm_rendezvous%ROWTYPE;
 v_aujourdhui date := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
 v_rdv date := v_aujourdhui + 1;
 v_courrier jsonb;
BEGIN
 IF v_nom IS NULL OR auth.uid() IS NULL THEN
   RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');
 END IF;
 SELECT * INTO v_pj FROM public.personnages_donnees
 WHERE name=v_nom FOR UPDATE;
 IF NOT FOUND OR v_pj.user_id IS DISTINCT FROM auth.uid() THEN
   RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');
 END IF;
 IF (v_pj.country,v_pj.current_city,v_pj.current_building,v_pj.current_room)
   IS DISTINCT FROM ('republic','ville_b','services-sociaux-montrouge','accueil') THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_a_l_accueil');
 END IF;

 SELECT * INTO v_actuel FROM public.ssm_rendezvous
 WHERE personnage=v_nom FOR UPDATE;
 IF FOUND AND v_actuel.user_id=v_pj.user_id AND v_actuel.rendezvous_le >= v_aujourdhui THEN
   RETURN jsonb_build_object('ok',true,'deja_fixe',true,
       'date',to_char(v_actuel.rendezvous_le,'YYYY-MM-DD'),
       'aujourdhui',v_actuel.rendezvous_le=v_aujourdhui);
 END IF;

 INSERT INTO public.ssm_rendezvous(personnage,user_id,demande_le,rendezvous_le)
 VALUES(v_nom,v_pj.user_id,v_aujourdhui,v_rdv)
 ON CONFLICT(personnage) DO UPDATE
 SET user_id=EXCLUDED.user_id,demande_le=EXCLUDED.demande_le,
     rendezvous_le=EXCLUDED.rendezvous_le,cree_le=clock_timestamp();

 -- Le courrier confirme un rendez-vous déjà attribué : pas de second accord
 -- implicite, pas de plage horaire fictive. Envoi dans la même transaction.
 v_courrier := public.mail_systeme_poser_interne(
   'Pascale — Services sociaux de Montrouge',
   v_nom,
   'Votre rendez-vous avec Edwige Jacquard',
   'Bonjour,'||chr(10)||chr(10)||'Votre rendez-vous avec Edwige Jacquard, assistante sociale des Services sociaux de Montrouge, est fixé au '
      ||to_char(v_rdv,'DD/MM/YYYY')||'.'||chr(10)||chr(10)||'Vous pourrez vous présenter à l’accueil puis entrer dans son bureau pendant toute cette journée (heure de Paris).'
      ||' En dehors de cette date, l’accès au bureau est réservé.'||chr(10)||chr(10)||'À bientôt,'||chr(10)||'Pascale — Services sociaux de Montrouge',
   NULL
 );
 IF coalesce(v_courrier->>'ok','false') <> 'true' THEN
   RAISE EXCEPTION 'ssm_courrier_impossible' USING ERRCODE='P0001';
 END IF;
 RETURN jsonb_build_object('ok',true,'deja_fixe',false,
   'date',to_char(v_rdv,'YYYY-MM-DD'),'mail_envoye',true);
END
$ssm$;
REVOKE ALL ON FUNCTION public.ssm_rendezvous_demander()
 FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.ssm_rendezvous_demander() TO authenticated;

-- Portes existantes, conservées : ajout d'une restriction ciblée uniquement.
DO $garde$
DECLARE
 definition text;
 attendu text;
 insertion text;
 h text;
BEGIN
 SELECT pg_get_functiondef(p.oid),md5(p.prosrc)
 INTO definition,h
 FROM pg_proc p WHERE p.oid=
 'public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure;
 IF h <> '046bb903b1f5573e6cdac86268587929' THEN
   RAISE EXCEPTION 'ssm_navigation_corps_non_examine: %',h;
 END IF;
 attendu := ' IF l.ferme THEN RETURN jsonb_build_object(''ok'',false,''raison'',''acces_restreint''); END IF;';
 IF position(attendu IN definition)=0 THEN RAISE EXCEPTION 'ssm_navigation_ancre_absente'; END IF;
 insertion := E' -- ssm_acces_sur_rendezvous_v1\n'
   ||' IF p.country=''republic'' AND p.current_city=''ville_b'' '
   ||'AND p_batiment=''services-sociaux-montrouge'' '
   ||'AND p_piece=''bureau_assistante_sociale'' '
   ||'AND NOT public.ssm_rendezvous_valide_interne(p_nom) THEN '
   ||'RETURN jsonb_build_object(''ok'',false,''raison'',''rendezvous_ssm_requis''); END IF;'
   ||E'\n'||attendu;
 EXECUTE replace(definition,attendu,insertion);
END
$garde$;

-- Même RPC de demande qu'au bureau de l'adjoint : élargit seulement l'accès
-- depuis le bureau d'Edwige avec rendez-vous encore valable.
DO $garde$
DECLARE definition text; h text; attendu text; remplacement text;
BEGIN
 SELECT pg_get_functiondef(p.oid),md5(p.prosrc)
 INTO definition,h FROM pg_proc p
 WHERE p.oid='public.logement_social_demander(text)'::regprocedure;
 IF h <> '0a319602d9966a84dfbde6a0f0a33a79' THEN
   RAISE EXCEPTION 'ssm_logement_corps_non_examine: %',h;
 END IF;
 attendu := '  IF p.current_building NOT IN (''mairie'',''mairie-capitale'') THEN RETURN jsonb_build_object(''ok'',false,''raison'',''pas_a_la_mairie''); END IF;';
 IF position(attendu IN definition)=0 THEN RAISE EXCEPTION 'ssm_logement_ancre_absente'; END IF;
 remplacement := 
   '  IF p.current_building NOT IN (''mairie'',''mairie-capitale'') '
   ||'AND NOT (p.country=''republic'' AND p.current_city=''ville_b'' '
   ||'AND p.current_building=''services-sociaux-montrouge'' '
   ||'AND p.current_room=''bureau_assistante_sociale'' '
   ||'AND public.ssm_rendezvous_valide_interne(moi)) '
   ||'THEN RETURN jsonb_build_object(''ok'',false,''raison'',''pas_a_la_mairie''); END IF;';
 EXECUTE replace(definition,attendu,remplacement);
END
$garde$;
