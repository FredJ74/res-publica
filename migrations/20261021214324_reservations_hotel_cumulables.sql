-- PREPAREE UNIQUEMENT #63 : paiement/attribution et consommation/bonus dans leurs moteurs existants.
BEGIN;
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.hotel_reservations_normaliser(jsonb)');IF h IS NOT NULL AND h NOT IN('a6a077ebd29d56e403d58a9ffd6373d0') THEN RAISE EXCEPTION 'definition_non_examinee: hotel_reservations_normaliser';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.hotel_reservation_ajouter(text)');IF h IS NOT NULL AND h NOT IN('25010ab65f2c3d5a8005f60917103420') THEN RAISE EXCEPTION 'definition_non_examinee: hotel_reservation_ajouter';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.hotel_reservation_proteger()');IF h IS NOT NULL AND h NOT IN('0125e230f4df32695bb2a4cfaab58984') THEN RAISE EXCEPTION 'definition_non_examinee: hotel_reservation_proteger';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.hotel_repos_attester(text)');IF h IS NOT NULL AND h NOT IN('7ce387a8f83b25c8e58f50b3918472d8') THEN RAISE EXCEPTION 'definition_non_examinee: hotel_repos_attester';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.pa_bonus_chambre(text,text)');IF h IS NOT NULL AND h NOT IN('c276a328571bd8f961f6540ee48076cb','8a2ae0417b535f0f3c6aef6fa189880e') THEN RAISE EXCEPTION 'definition_non_examinee: pa_bonus_chambre';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.hotel_reserver(text,text)');IF h IS NOT NULL AND h NOT IN('d5852264aa3cfa2f3a0982cf68274d96') THEN RAISE EXCEPTION 'definition_non_examinee: hotel_reserver';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.hotel_reservations_lire(text)');IF h IS NOT NULL AND h NOT IN('dc0dc1e9aeec106ab8903951d38442d7') THEN RAISE EXCEPTION 'definition_non_examinee: hotel_reservations_lire';END IF;
END;$g$;
CREATE TABLE IF NOT EXISTS public.hotel_regles(pays text,ville text,building_id text,accueil text NOT NULL,chambres text[] NOT NULL,pa integer NOT NULL,prix integer NOT NULL,moral integer NOT NULL,caisse text NOT NULL,entreprise boolean NOT NULL,PRIMARY KEY(pays,ville,building_id));
CREATE TABLE IF NOT EXISTS public.hotel_requetes(acteur text,requete text,building_id text NOT NULL,transaction_id bigint NOT NULL,verdict jsonb,PRIMARY KEY(acteur,requete));
CREATE TABLE IF NOT EXISTS public.hotel_repos(acteur text,jour date,building_id text NOT NULL,pays text,ville text,nuit_id text NOT NULL,accorde boolean NOT NULL DEFAULT false,transaction_id bigint NOT NULL,PRIMARY KEY(acteur,jour));
ALTER TABLE public.hotel_regles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotel_requetes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotel_repos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.hotel_regles,public.hotel_requetes,public.hotel_repos FROM PUBLIC,anon,authenticated;
-- CONFIGURATION EXTRAITE DE data.js : pas de tarifs/bonus nouveaux.
INSERT INTO public.hotel_regles VALUES('republic','capitale','hotel-republica','accueil',ARRAY['chambres'],0,80,3,'republic_hotel_capitale',true) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('republic','capitale','hotel-republica','accueil',ARRAY['chambres'],0,80,3,'republic_hotel_capitale',true)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('republic','ville_a','hotel-port','hall_port',ARRAY['chambre_port'],0,60,3,'republic_hotel_ville_a',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('republic','ville_a','hotel-port','hall_port',ARRAY['chambre_port'],0,60,3,'republic_hotel_ville_a',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('republic','ville_b','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'republic_hotel_ville_b',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('republic','ville_b','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'republic_hotel_ville_b',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('narco','capitale','hotel-republica','accueil',ARRAY['chambres'],0,80,3,'narco_hotel_capitale',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('narco','capitale','hotel-republica','accueil',ARRAY['chambres'],0,80,3,'narco_hotel_capitale',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('narco','ville_a','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'narco_hotel_ville_a',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('narco','ville_a','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'narco_hotel_ville_a',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('narco','ville_b','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'narco_hotel_ville_b',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('narco','ville_b','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'narco_hotel_ville_b',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('soviet','capitale','hotel-republica','accueil',ARRAY['chambres'],0,80,3,'soviet_hotel_capitale',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('soviet','capitale','hotel-republica','accueil',ARRAY['chambres'],0,80,3,'soviet_hotel_capitale',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('soviet','ville_a','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'soviet_hotel_ville_a',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('soviet','ville_a','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'soviet_hotel_ville_a',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('soviet','ville_b','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'soviet_hotel_ville_b',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('soviet','ville_b','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'soviet_hotel_ville_b',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('khalija','capitale','hotel-republica','accueil',ARRAY['chambres'],0,80,3,'khalija_hotel_capitale',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('khalija','capitale','hotel-republica','accueil',ARRAY['chambres'],0,80,3,'khalija_hotel_capitale',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('khalija','ville_a','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'khalija_hotel_ville_a',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('khalija','ville_a','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'khalija_hotel_ville_a',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
INSERT INTO public.hotel_regles VALUES('khalija','ville_b','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'khalija_hotel_ville_b',false) ON CONFLICT DO NOTHING;
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.hotel_regles WHERE (pays,ville,building_id,accueil,chambres,pa,prix,moral,caisse,entreprise)=ROW('khalija','ville_b','hotel-mineur','hall_mineur',ARRAY['chambre_mineur'],0,60,3,'khalija_hotel_ville_b',false)) THEN RAISE EXCEPTION 'configuration_hotel_divergente';END IF;END$$;
CREATE OR REPLACE FUNCTION public.hotel_reservations_normaliser(v jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $$
BEGIN
 IF v IS NULL OR v='null'::jsonb THEN RETURN '{"version":2,"nuits":[]}';END IF;
 IF v->>'version'='2' AND jsonb_typeof(v->'nuits')='array' THEN RETURN v;END IF;
 IF jsonb_typeof(v)='object' AND nullif(v->>'buildingId','') IS NOT NULL THEN
  -- Le vieux droit ne connait pas sa ville : conserver sa portee historique, ne pas en deviner une.
  RETURN jsonb_build_object('version',2,'nuits',jsonb_build_array(v||jsonb_build_object('id','legacy-'||md5(v::text),'pays',NULL,'ville',NULL,'source','legacy')));
 END IF;
 RAISE EXCEPTION 'format_reservation_historique_a_examiner';
END;$$;
CREATE OR REPLACE FUNCTION public.hotel_reservation_ajouter(acteur text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE p public.personnages_donnees%rowtype;r public.hotel_regles%rowtype;q public.hotel_requetes%rowtype;v jsonb;bonus integer;
BEGIN
 SELECT * INTO STRICT p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 SELECT * INTO STRICT r FROM public.hotel_regles WHERE pays=p.country AND ville=p.current_city AND building_id=p.current_building;
 SELECT * INTO q FROM public.hotel_requetes WHERE hotel_requetes.acteur=hotel_reservation_ajouter.acteur AND transaction_id=txid_current() AND verdict IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'reservation_atomique_requise';END IF;
 SELECT montant INTO STRICT bonus FROM public.pa_bonus_hotel WHERE building_id=p.current_building;
 v:=public.hotel_reservations_normaliser(p.reservation_hotel);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(v->'nuits') n WHERE n->>'id'=q.requete) THEN RETURN;END IF;
 UPDATE public.personnages_donnees SET reservation_hotel=jsonb_set(v,'{nuits}',(v->'nuits')||jsonb_build_array(jsonb_build_object('id',q.requete,'pays',r.pays,'ville',r.ville,'buildingId',r.building_id,'bonus',jsonb_build_object('moral',r.moral,'paBonus',bonus)))),updated_at=now() WHERE name=acteur;
END;$$;
CREATE OR REPLACE FUNCTION public.hotel_reservation_proteger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF TG_OP='INSERT' THEN NEW.reservation_hotel:='{"version":2,"nuits":[]}'::jsonb;RETURN NEW;END IF;
 IF NEW.reservation_hotel IS DISTINCT FROM OLD.reservation_hotel AND NOT EXISTS(SELECT 1 FROM public.hotel_requetes WHERE acteur=OLD.name AND transaction_id=txid_current()) AND NOT EXISTS(SELECT 1 FROM public.hotel_repos WHERE acteur=OLD.name AND transaction_id=txid_current()) THEN NEW.reservation_hotel:=OLD.reservation_hotel;END IF;
 RETURN NEW;
END;$$;
CREATE OR REPLACE FUNCTION public.hotel_repos_attester(acteur text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE p public.personnages_donnees%rowtype;r public.hotel_regles%rowtype;n jsonb;
BEGIN
 SELECT * INTO STRICT p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 SELECT * INTO r FROM public.hotel_regles WHERE pays=p.country AND ville=p.current_city AND building_id=p.current_building AND p.current_room=ANY(chambres);
 IF NOT FOUND THEN RETURN;END IF;
 SELECT x INTO n FROM jsonb_array_elements(public.hotel_reservations_normaliser(p.reservation_hotel)->'nuits') WITH ORDINALITY AS t(x,o)
 WHERE x->>'buildingId'=p.current_building AND ((x->>'source')='legacy' OR (x->>'pays'=p.country AND x->>'ville'=p.current_city)) ORDER BY o LIMIT 1;
 IF n IS NULL THEN RETURN;END IF;
 INSERT INTO public.hotel_repos VALUES(acteur,(now() AT TIME ZONE 'Europe/Paris')::date,p.current_building,p.country,p.current_city,n->>'id',false,txid_current()) ON CONFLICT DO NOTHING;
END;$$;
CREATE OR REPLACE FUNCTION public.pa_bonus_chambre(p_acteur text,p_batiment text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE p public.personnages_donnees%rowtype;r public.hotel_regles%rowtype;a public.hotel_repos%rowtype;v jsonb;n jsonb;bonus integer;pa_final integer;moral_final integer;
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 SELECT * INTO p FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 SELECT * INTO r FROM public.hotel_regles WHERE pays=p.country AND ville=p.current_city AND building_id=p_batiment AND p.current_building=p_batiment AND p.current_room=ANY(chambres);
 IF NOT FOUND OR coalesce(p.hp,100)<=0 THEN RETURN '{"ok":false,"raison":"pas_dans_chambre"}';END IF;
 SELECT * INTO a FROM public.hotel_repos WHERE acteur=p_acteur AND jour=(now() AT TIME ZONE 'Europe/Paris')::date FOR UPDATE;
 IF NOT FOUND OR a.building_id<>p_batiment OR a.pays<>p.country OR a.ville<>p.current_city THEN RETURN '{"ok":false,"raison":"repos_hotel_non_atteste"}';END IF;
 IF a.accorde THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'pa',p.pa,'moral',p.moral,'reservation_hotel',p.reservation_hotel);END IF;
 v:=public.hotel_reservations_normaliser(p.reservation_hotel);
 SELECT x INTO n FROM jsonb_array_elements(v->'nuits') x WHERE x->>'id'=a.nuit_id;
 IF n IS NULL THEN RETURN '{"ok":false,"raison":"aucune_reservation"}';END IF;
 SELECT montant INTO STRICT bonus FROM public.pa_bonus_hotel WHERE building_id=p_batiment;
 UPDATE public.hotel_repos SET accorde=true,transaction_id=txid_current() WHERE acteur=p_acteur AND jour=a.jour;
 SELECT coalesce(jsonb_agg(x),'[]'::jsonb) INTO v FROM jsonb_array_elements(v->'nuits') x WHERE x->>'id'<>a.nuit_id;
 UPDATE public.personnages_donnees SET reservation_hotel=jsonb_build_object('version',2,'nuits',v),moral=least(100,coalesce(moral,0)+r.moral) WHERE name=p_acteur RETURNING moral INTO moral_final;
 pa_final:=public.pa_crediter_interne(p_acteur,bonus);
 RETURN jsonb_build_object('ok',true,'rejeu',false,'pa',pa_final,'moral',moral_final,'montant',bonus,'bonus_moral',r.moral,'reservation_hotel',jsonb_build_object('version',2,'nuits',v));
END;$$;
CREATE OR REPLACE FUNCTION public.hotel_reserver(p_requete text,p_batiment text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE moi text:=public.mon_personnage();p public.personnages_donnees%rowtype;r public.hotel_regles%rowtype;q public.hotel_requetes%rowtype;v jsonb;eid text;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}';END IF;
 IF p_requete IS NULL OR p_requete!~'^[A-Za-z0-9_-]{1,120}$' OR p_batiment IS NULL THEN RETURN '{"ok":false,"raison":"parametres_invalides"}';END IF;
 SELECT * INTO STRICT p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 SELECT * INTO q FROM public.hotel_requetes WHERE acteur=moi AND requete=p_requete;
 IF FOUND THEN
  IF q.building_id<>p_batiment THEN RETURN '{"ok":false,"raison":"requete_reutilisee"}';END IF;
  RETURN q.verdict||jsonb_build_object('rejeu',true,'reservation_hotel',p.reservation_hotel);
 END IF;
 SELECT * INTO r FROM public.hotel_regles WHERE pays=p.country AND ville=p.current_city AND building_id=p.current_building AND accueil=p.current_room AND building_id=p_batiment;
 IF NOT FOUND OR coalesce(p.hp,100)<=0 THEN RETURN '{"ok":false,"raison":"pas_sur_place"}';END IF;
 BEGIN
  INSERT INTO public.hotel_requetes VALUES(moi,p_requete,p_batiment,txid_current(),NULL);
  IF r.entreprise THEN
   SELECT id INTO STRICT eid FROM public.entreprises WHERE data->>'country'=r.pays AND data->>'city'=r.ville AND data->>'buildingId'=r.building_id;
   v:=public.commerce_vendre_produit(moi,eid,'[]'::jsonb,'service','reserver_chambre_hotel',r.pa,r.prix);
  ELSE
   v:=public.vente_structure_encaisser('reserver_chambre_hotel',r.pa,r.prix,r.caisse,r.ville);
   IF v->>'ok'='true' THEN PERFORM public.hotel_reservation_ajouter(moi);END IF;
  END IF;
  IF v->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'encaissement_refuse:%',coalesce(v->>'raison','inconnu');END IF;
  SELECT reservation_hotel INTO v FROM public.personnages_donnees WHERE name=moi;
  v:=jsonb_build_object('ok',true,'reservation_hotel',v);
  UPDATE public.hotel_requetes SET verdict=v WHERE acteur=moi AND requete=p_requete;
  RETURN v;
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM LIKE 'encaissement_refuse:%' THEN RETURN jsonb_build_object('ok',false,'raison',substr(SQLERRM,21));ELSE RAISE;END IF;
 END;
END;$$;
CREATE OR REPLACE FUNCTION public.hotel_reservations_lire(p_requete text DEFAULT NULL) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('ok',true,'reservation_hotel',public.hotel_reservations_normaliser(p.reservation_hotel),'termine',EXISTS(SELECT 1 FROM public.hotel_requetes WHERE acteur=p.name AND requete=p_requete AND verdict->>'ok'='true')) FROM public.personnages_donnees p WHERE name=public.mon_personnage();
$$;
DO $patch$ DECLARE h text;s text;BEGIN SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)');IF h='e7196487095f71e9e60c8a162c648032' THEN
s:=replace(s,$a0$BEGIN
$a0$,$b0$BEGIN
  IF p_ordre='reserver_chambre_hotel' AND NOT EXISTS(SELECT 1 FROM public.hotel_requetes WHERE acteur=p_acteur AND transaction_id=txid_current() AND verdict IS NULL) THEN RETURN '{"ok":false,"raison":"reservation_atomique_requise"}';END IF;
$b0$);
s:=replace(s,$a1$    UPDATE public.personnages_donnees
       SET reservation_hotel=jsonb_build_object('buildingId','hotel-republica',
             'bonus',jsonb_build_object('moral',3,'paBonus',
               (SELECT montant FROM public.pa_bonus_hotel WHERE building_id='hotel-republica'))),
           updated_at=now()
     WHERE name=p_acteur;$a1$,$b1$    PERFORM public.hotel_reservation_ajouter(p_acteur);$b1$);
EXECUTE s;ELSIF h IS DISTINCT FROM '1bc5cf88470aa9d547acdf2dddd8ee97' THEN RAISE EXCEPTION 'definition_non_examinee: commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)';END IF;END;$patch$;
DO $patch$ DECLARE h text;s text;BEGIN SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.vente_structure_encaisser(text,integer,integer,text,text)');IF h='e5a1165c058b4e3b9530a53695ed18a7' THEN
s:=replace(s,$a0$BEGIN
$a0$,$b0$BEGIN
  IF p_fn='reserver_chambre_hotel' AND NOT EXISTS(SELECT 1 FROM public.hotel_requetes WHERE acteur=public.mon_personnage() AND transaction_id=txid_current() AND verdict IS NULL) THEN RETURN '{"ok":false,"raison":"reservation_atomique_requise"}';END IF;
$b0$);
EXECUTE s;ELSIF h IS DISTINCT FROM '7c387b92d1c57926cc57dc2195630f3b' THEN RAISE EXCEPTION 'definition_non_examinee: vente_structure_encaisser(text,integer,integer,text,text)';END IF;END;$patch$;
DO $patch$ DECLARE h text;s text;BEGIN SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,s FROM pg_proc WHERE oid=to_regprocedure('public.pa_repos_nocturne(text)');IF h='5c6433f6c2103757db97316eca5d8479' THEN
s:=replace(s,$a0$  RETURN jsonb_build_object('ok', true, 'pa', v_nouveau$a0$,$b0$  PERFORM public.hotel_repos_attester(p_acteur);
  RETURN jsonb_build_object('ok', true, 'pa', v_nouveau$b0$);
EXECUTE s;ELSIF h IS DISTINCT FROM '835d2da3500f48c0582588ababea1a75' THEN RAISE EXCEPTION 'definition_non_examinee: pa_repos_nocturne(text)';END IF;END;$patch$;
-- Migration de representation uniquement : aucun paiement, pas de nouvelle nuit inventee.
UPDATE public.personnages_donnees SET reservation_hotel=public.hotel_reservations_normaliser(reservation_hotel) WHERE reservation_hotel IS NOT NULL AND reservation_hotel IS DISTINCT FROM public.hotel_reservations_normaliser(reservation_hotel);
DROP TRIGGER IF EXISTS zzzz_hotel_reservation_proteger ON public.personnages_donnees;
CREATE TRIGGER zzzz_hotel_reservation_proteger BEFORE INSERT OR UPDATE OF reservation_hotel ON public.personnages_donnees FOR EACH ROW EXECUTE FUNCTION public.hotel_reservation_proteger();
REVOKE ALL ON FUNCTION public.hotel_reservations_normaliser(jsonb),public.hotel_reservation_ajouter(text),public.hotel_reservation_proteger(),public.hotel_repos_attester(text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.hotel_reserver(text,text),public.hotel_reservations_lire(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hotel_reserver(text,text),public.hotel_reservations_lire(text) TO authenticated;
COMMIT;
