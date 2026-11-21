-- Socle minimal pour éprouver les migrations du chantier dans PGlite (banc local, jamais la production).
-- chantier_besoin_jour_interne, chantier_travailler et chantier_jour_traiter : définitions de production du 21/11/2026
-- (avant 20261121140000). Les fonctions extérieures sont des bouchons explicites.
SET check_function_bodies = off;
CREATE ROLE anon; CREATE ROLE authenticated;
CREATE TABLE public.terrains_etat (id text PRIMARY KEY, country text, data text, updated_at timestamptz);
CREATE TABLE public.personnages_donnees (name text PRIMARY KEY, pa integer, arg numeric, liquide numeric, day integer, current_city text, updated_at timestamptz);
CREATE TABLE public.entreprises_constantes (cle text PRIMARY KEY, valeur numeric);
INSERT INTO public.entreprises_constantes VALUES ('chantier_taux_horaire', 70), ('chantier_salaire_minimum', 50);
CREATE TABLE public.chantiers_besoins_jour (position_cycle integer PRIMARY KEY, bois numeric, minerai numeric, metal numeric);
INSERT INTO public.chantiers_besoins_jour VALUES (1, 100, 50, 33), (2, 100, 50, 34), (3, 100, 50, 33);
CREATE TABLE public.entrepots_par_ville (pays text, ville text, building_id text);
CREATE TABLE public.ressources_economie (cle text PRIMARY KEY, prix_base numeric);
CREATE TABLE public.caisse_test (id text PRIMARY KEY, total numeric);
CREATE OR REPLACE FUNCTION public.exiger_acteur(p text) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE OR REPLACE FUNCTION public.climat_chantiers_bloques_interne(p text, v text) RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
CREATE OR REPLACE FUNCTION public.terrain_etat_lire(p text) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$ SELECT p::jsonb $$;
CREATE OR REPLACE FUNCTION public.est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$ SELECT true $$;
CREATE OR REPLACE FUNCTION public.chantier_financeur_verrouiller_interne(a text, b text, c text) RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object('destinataire', a) $$;
-- Appel de fonds : le vrai bloque à un palier non financé (arrete = 'financement') ; ici, même règle simplifiée.
CREATE OR REPLACE FUNCTION public.chantier_appel_fonds_interne(ch jsonb, s jsonb) RETURNS jsonb LANGUAGE sql AS $$
  SELECT CASE WHEN (ch->>'progressionJours')::numeric >= (ch->>'dureeJours')::numeric / 3
               AND (ch->>'totalVerse')::numeric < ceil((ch->>'coutTotal')::numeric * .7) THEN ch || '{"arrete":"financement"}'
              ELSE ch || '{"arrete":null}' END $$;
CREATE OR REPLACE FUNCTION public.approvisionner_chantier(a text, p text, v text, e text, b jsonb, s jsonb, t numeric) RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('ok', true, 'stockChantier', s, 'depense', 0, 'achats', '{}'::jsonb) $$;
CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement(p_id text, p_m numeric, p_x boolean) RETURNS jsonb LANGUAGE sql AS $$
  INSERT INTO public.caisse_test VALUES (p_id, p_m) ON CONFLICT (id) DO UPDATE SET total = public.caisse_test.total + EXCLUDED.total RETURNING '{"ok":true}'::jsonb $$;
CREATE OR REPLACE FUNCTION public.mail_systeme_poser_interne(a text, b text, c text, d text, e text DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":true}'::jsonb $$;
CREATE OR REPLACE FUNCTION public.mail_systeme_poser_interne(a text, b text, c text, d text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":true}'::jsonb $$;

CREATE OR REPLACE FUNCTION public.chantier_besoin_jour_interne(p_ch jsonb, p_num integer)
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r jsonb;BEGIN
 IF p_ch->>'type'='construction' THEN
  SELECT jsonb_build_object('bois',bois,'minerai',minerai,'metal',metal) INTO r FROM public.chantiers_besoins_jour WHERE position_cycle=((p_num-1)%(SELECT count(*) FROM public.chantiers_besoins_jour))+1;
 ELSIF p_ch->>'type'='reamenagement' THEN
  SELECT jsonb_object_agg(cle,floor(((p_ch->>'coutMateriaux')::numeric/(p_ch->>'dureeJours')::numeric/3/prix_base))) INTO r FROM public.ressources_economie WHERE cle IN('bois','minerai','metal') AND prix_base>0;
 END IF;
 IF r IS NULL OR (SELECT count(*) FROM jsonb_object_keys(r))<>3 THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
 RETURN r;
END;$function$;

CREATE OR REPLACE FUNCTION public.chantier_travailler(p_acteur text, p_pays text, p_batiment text, p_heures integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_emplacement text;v_id text; v_data jsonb; v_ch jsonb; v_stock jsonb; v_besoin record;
  v_jour_num integer; v_fraction numeric := 1; v_capacite numeric; v_utiles numeric;
  v_faites numeric; v_restantes numeric; v_tresorerie numeric; v_payables numeric;
  v_taux numeric; v_pa integer; v_arg numeric; v_liquide numeric; v_jour integer;
  v_plafond numeric; v_taux_paye numeric; v_min numeric;
  v_heures integer; v_montant numeric; v_m text; v_req numeric; v_dispo numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF public.climat_chantiers_bloques_interne(p_pays, (SELECT current_city FROM public.personnages_donnees WHERE name = p_acteur)) THEN -- climat_chantiers_v1
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_intemperies');
  END IF;
  IF COALESCE(p_heures, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'heures_invalides');
  END IF;
  SELECT id INTO v_id FROM public.terrains_etat WHERE country=p_pays AND id=p_batiment;
  IF v_id IS NULL THEN v_id:=p_pays||'_'||p_batiment;END IF;

  SELECT valeur INTO v_taux FROM public.entreprises_constantes WHERE cle = 'chantier_taux_horaire';
  IF COALESCE(v_taux, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_indisponible');
  END IF;

  SELECT public.terrain_etat_lire(data) INTO v_data
    FROM public.terrains_etat WHERE id = v_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;
  IF COALESCE(v_data->>'succession_gel','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;

  v_emplacement:=CASE WHEN jsonb_typeof(v_data->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;v_ch:=v_data->v_emplacement;
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;
  IF COALESCE(v_ch->>'type','') NOT IN('construction','reamenagement') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_non_couvert', 'type', v_ch->>'type');
  END IF;

  v_jour_num := floor(GREATEST(0, COALESCE((v_ch->>'progressionJours')::numeric, 0)))::integer + 1;
  SELECT (x->>'bois')::numeric AS bois,(x->>'minerai')::numeric AS minerai,(x->>'metal')::numeric AS metal INTO v_besoin FROM (SELECT public.chantier_besoin_jour_interne(v_ch,v_jour_num) AS x) b;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'besoin_indisponible'); END IF;

  v_stock := COALESCE(v_ch->'stockMateriaux', '{}'::jsonb);
  FOR v_m, v_req IN SELECT * FROM (VALUES ('bois', v_besoin.bois), ('minerai', v_besoin.minerai),
                                          ('metal', v_besoin.metal)) AS t(m, r) LOOP
    IF v_req > 0 THEN
      v_dispo := GREATEST(0, COALESCE((v_stock->>v_m)::numeric, 0));
      v_fraction := LEAST(v_fraction, LEAST(1, GREATEST(0, v_dispo / v_req)));
    END IF;
  END LOOP;

  v_capacite := CASE WHEN COALESCE((v_ch->>'dureeJours')::numeric, 0) > 0
                     THEN (COALESCE((v_ch->>'coutTravail')::numeric, 0) / v_taux)
                          / (v_ch->>'dureeJours')::numeric
                     ELSE 0 END;
  v_plafond:=CASE WHEN (v_ch->>'totalVerse')::numeric>=(v_ch->>'coutTotal')::numeric THEN (v_ch->>'dureeJours')::numeric WHEN (v_ch->>'totalVerse')::numeric>=ceil((v_ch->>'coutTotal')::numeric*.7) THEN (v_ch->>'dureeJours')::numeric*2/3 WHEN (v_ch->>'totalVerse')::numeric>=ceil((v_ch->>'coutTotal')::numeric*.35) THEN (v_ch->>'dureeJours')::numeric/3 ELSE 0 END;
  v_utiles:=floor(v_capacite*least(v_fraction,greatest(0,v_plafond-coalesce((v_ch->>'progressionJours')::numeric,0))));
  v_faites   := GREATEST(0, COALESCE((v_ch->>'heuresFaites')::numeric, 0));
  v_restantes := GREATEST(0, v_utiles - v_faites);

  SELECT COALESCE(pa,0), COALESCE(arg,0), COALESCE(liquide,0), COALESCE(day,1)
    INTO v_pa, v_arg, v_liquide, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_tresorerie := GREATEST(0, COALESCE((v_ch->>'tresorerie')::numeric, 0));
  SELECT valeur INTO v_min FROM public.entreprises_constantes WHERE cle = 'chantier_salaire_minimum';
  v_taux_paye := GREATEST(COALESCE((v_ch->>'tauxHoraire')::numeric, v_taux), COALESCE(v_min, 50));
  v_payables   := floor(v_tresorerie / v_taux_paye);

  v_heures := GREATEST(0, LEAST(p_heures, v_restantes, v_pa, v_payables))::integer;
  IF v_heures <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_heure_travaillable',
      'utilesRestantes', v_restantes, 'pa', v_pa, 'payables', v_payables,
      'fractionMateriaux', round(v_fraction, 4));
  END IF;
  v_montant := v_heures * v_taux_paye;

  v_ch := v_ch || jsonb_build_object(
    'heuresFaites', v_faites + v_heures,
    'tresorerie', v_tresorerie - v_montant,
    'travauxPJ', COALESCE(v_ch->'travauxPJ', '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object('nom', p_acteur, 'heures', v_heures, 'montant', v_montant,
                         'jour', v_jour)));

  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object(v_emplacement, v_ch))::text, updated_at = now()
   WHERE id = v_id;

  UPDATE public.personnages_donnees
     SET pa = v_pa - v_heures, arg = v_arg + v_montant, liquide = v_liquide + v_montant,
         updated_at = now()
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'heures', v_heures, 'montant', v_montant, 'taux', v_taux_paye,
    'pa', v_pa - v_heures, 'arg', v_arg + v_montant, 'liquide', v_liquide + v_montant,
    'chantier', v_ch);
END; $function$;

CREATE OR REPLACE FUNCTION public.chantier_jour_traiter(p_terrain_id text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE paye numeric;cible_travail numeric;gain_travail numeric;emplacement text;r record;snapshot jsonb;etat jsonb;ch jsonb;source jsonb;jour text;avant numeric;apres numeric;d numeric;
 besoin jsonb;stock jsonb;plan jsonb;entrepot text;num integer;m text;req numeric;f numeric:=1;cap numeric;faites numeric;heures numeric;cout numeric;gain numeric;plafond numeric;taux numeric;rep jsonb;ancien text;
BEGIN
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur');END IF;
 SELECT * INTO r FROM public.terrains_etat WHERE id=p_terrain_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_absent');END IF;
 snapshot:=r.data::jsonb;
 emplacement:=CASE WHEN jsonb_typeof(snapshot->'chantier')='object' THEN 'chantier' ELSE 'chantierReamenagement' END;
 IF jsonb_typeof(snapshot->emplacement) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok',true,'ignore',true);END IF;
 -- Le verrou du financeur precede celui du terrain, comme lancement/ventes/transferts.
 source:=public.chantier_financeur_verrouiller_interne(snapshot->>'proprietaire',r.country,snapshot->>'city');
 SELECT * INTO r FROM public.terrains_etat WHERE id=p_terrain_id FOR UPDATE;etat:=r.data::jsonb;
 IF etat->>'proprietaire' IS DISTINCT FROM snapshot->>'proprietaire' OR etat->>'city' IS DISTINCT FROM snapshot->>'city' THEN
  RETURN jsonb_build_object('ok',false,'raison','titulaire_modifie');END IF;
 ch:=etat->emplacement;jour:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
 IF coalesce(etat->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',true,'ignore',true,'raison','terrain_gele');END IF;
 IF coalesce(ch->>'type','') NOT IN('construction','reamenagement') THEN RETURN jsonb_build_object('ok',false,'raison','chantier_historique_a_examiner');END IF;
 IF ch->>'jourTraite'=jour THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'etat',etat);END IF;
 avant:=(ch->>'progressionJours')::numeric;d:=(ch->>'dureeJours')::numeric;
 IF avant IS NULL OR avant<0 OR d IS NULL OR d<=0 OR d<>trunc(d) THEN RAISE EXCEPTION 'dimensionnement_chantier_invalide';END IF;
 IF avant<d THEN
  ch:=public.chantier_appel_fonds_interne(ch,source);
  IF ch->>'arrete' IS DISTINCT FROM 'financement' THEN
   num:=floor(avant)::integer+1;
   besoin:=public.chantier_besoin_jour_interne(ch,num);
   IF besoin IS NULL THEN RAISE EXCEPTION 'besoin_chantier_absent';END IF;
   SELECT building_id INTO entrepot FROM public.entrepots_par_ville WHERE pays=r.country AND ville=etat->>'city';
   stock:=coalesce(ch->'stockMateriaux','{}');
   IF entrepot IS NOT NULL THEN
    plan:=public.approvisionner_chantier(source->>'destinataire',r.country,etat->>'city',entrepot,besoin,stock,coalesce((ch->>'tresorerie')::numeric,0));
    IF NOT coalesce((plan->>'ok')::boolean,false) THEN RAISE EXCEPTION 'approvisionnement_non_confirme';END IF;
    stock:=plan->'stockChantier';ch:=ch||jsonb_build_object('tresorerie',(ch->>'tresorerie')::numeric-(plan->>'depense')::numeric);
   END IF;
   FOREACH m IN ARRAY ARRAY['bois','minerai','metal'] LOOP
    req:=(besoin->>m)::numeric;
    IF req>0 THEN f:=least(f,greatest(0,coalesce((stock->>m)::numeric,0))/req);END IF;
   END LOOP;
   IF f<1 THEN
    IF ch->>'manqueMateriauxAvise' IS NULL THEN
     BEGIN
      PERFORM public.mail_systeme_poser_interne('Chantier', ch->>'maitreOuvrage', 'Chantier à l''arrêt : matériaux manquants', 'manque', NULL);
     EXCEPTION WHEN others THEN NULL;
     END;
     ch:=ch||jsonb_build_object('manqueMateriauxAvise',jour);
    END IF;
   ELSIF ch ? 'manqueMateriauxAvise' THEN
    ch:=ch-'manqueMateriauxAvise';
   END IF;
   SELECT valeur INTO taux FROM public.entreprises_constantes WHERE cle='chantier_taux_horaire';
   IF taux IS NULL OR taux<=0 THEN RAISE EXCEPTION 'taux_chantier_indisponible';END IF;
   cap:=(ch->>'coutTravail')::numeric/taux/d;faites:=coalesce((ch->>'heuresFaites')::numeric,0);
   IF cap IS NULL OR cap<=0 OR faites<0 OR faites>cap THEN RAISE EXCEPTION 'capacite_travail_invalide';END IF;
   plafond:=CASE WHEN (ch->>'totalVerse')::numeric>=(ch->>'coutTotal')::numeric THEN d
     WHEN (ch->>'totalVerse')::numeric>=ceil((ch->>'coutTotal')::numeric*.7) THEN d*2/3 ELSE d/3 END;
   IF ch->>'type'='reamenagement' AND ch->>'versionCalculTravail'='2' THEN
    SELECT coalesce(sum((e->>'coutPNJ')::numeric),0) INTO paye FROM jsonb_array_elements(coalesce(ch->'evenements','[]')) e WHERE e->>'cle'='journee';
    SELECT paye+coalesce(sum((e->>'montant')::numeric),0) INTO paye FROM jsonb_array_elements(coalesce(ch->'travauxPJ','[]')) e;
    IF paye<0 OR paye>(ch->>'coutTravail')::numeric THEN RAISE EXCEPTION 'journal_travail_incoherent';END IF;
    cible_travail:=least((ch->>'coutTravail')::numeric,ceil((ch->>'coutTravail')::numeric*least(d,plafond,avant+least(1,f))/d));
    cout:=greatest(0,least(cible_travail-paye,floor((ch->>'tresorerie')::numeric)));heures:=cout/taux;
    gain_travail:=greatest(0,(paye+cout)*d/(ch->>'coutTravail')::numeric-avant);
   ELSE
   heures:=greatest(0,least(floor(cap*least(f,d-avant,plafond-avant))-faites,floor((ch->>'tresorerie')::numeric/taux)));cout:=heures*taux;
   END IF;
   IF cout>0 THEN
    ancien:=current_setting('rp.caisse_interne',true);PERFORM set_config('rp.caisse_interne','on',true);
    rep:=public.caisse_institution_mouvement(r.country||'_gouvernement-min_fin',cout,true);
    PERFORM set_config('rp.caisse_interne',coalesce(ancien,''),true);
    IF NOT coalesce((rep->>'ok')::boolean,false) THEN RAISE EXCEPTION 'remuneration_pnj_non_confirmee';END IF;
   END IF;
   gain:=least(1,f,CASE WHEN ch->>'type'='reamenagement' AND ch->>'versionCalculTravail'='2' THEN gain_travail ELSE (faites+heures)/cap END,d-avant);
   gain:=greatest(0,least(gain,plafond-avant));apres:=avant+gain;
   FOREACH m IN ARRAY ARRAY['bois','minerai','metal'] LOOP
    stock:=jsonb_set(stock,ARRAY[m],to_jsonb(greatest(0,coalesce((stock->>m)::numeric,0)-floor((besoin->>m)::numeric*gain))));
   END LOOP;
   ch:=ch||jsonb_build_object('progressionJours',apres,'tresorerie',(ch->>'tresorerie')::numeric-cout,'stockMateriaux',stock,'heuresFaites',0,'arrete',CASE WHEN gain=0 THEN 'penurie_materiaux' ELSE NULL END,
    'evenements',coalesce(ch->'evenements','[]')||jsonb_build_array(jsonb_build_object('cle','journee','date',jour,'avance',gain,'heuresPNJ',heures,'coutPNJ',cout,'achats',plan->'achats')));
   -- Un seuil atteint aujourd'hui appelle immediatement la tranche suivante, sans avancer le temps utile si refus.
   IF apres<d THEN ch:=public.chantier_appel_fonds_interne(ch,source);END IF;
  END IF;
 END IF;
 IF (ch->>'progressionJours')::numeric>=d THEN
  IF NOT coalesce((ch->>'attenteReception')::boolean,false) AND nullif(source->>'destinataire','') IS NOT NULL THEN
   rep:=public.mail_systeme_poser_interne('Chef de Chantier',source->>'destinataire','Chantier acheve — reception sur place','Les travaux sont acheves. Venez sur place pour receptionner le batiment et ouvrir ses locaux.');
   IF NOT coalesce((rep->>'ok')::boolean,false) THEN ch:=ch||jsonb_build_object('notificationEchec',rep);END IF;
  END IF;
  ch:=ch||jsonb_build_object('attenteReception',true,'arrete',null);
 END IF;
 ch:=ch||jsonb_build_object('jourTraite',jour);
 etat:=etat||jsonb_build_object(emplacement,ch);
 UPDATE public.terrains_etat SET data=etat::text,updated_at=now() WHERE id=p_terrain_id;
 RETURN jsonb_build_object('ok',true,'etat',etat,'attenteReception',coalesce((ch->>'attenteReception')::boolean,false),'avance',coalesce(gain,0));
END;$function$;
