-- #135 L09 : état et reçus privés, contacts générés depuis data.js ; aucune donnée joueur réinitialisée.
BEGIN;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='religion_benediction_lire' AND (p.oid IS DISTINCT FROM to_regprocedure('public.religion_benediction_lire()') OR md5(p.prosrc)<>'2e558ae53af76cee783b3577e21f5cc7')) THEN RAISE EXCEPTION 'definition_non_examinee: religion_benediction_lire';END IF;END;$g$;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='religion_benediction_consommer_interne' AND (p.oid IS DISTINCT FROM to_regprocedure('public.religion_benediction_consommer_interne(uuid,text,uuid)') OR md5(p.prosrc)<>'f6d810a9189e586fe6eee37aefbde869')) THEN RAISE EXCEPTION 'definition_non_examinee: religion_benediction_consommer_interne';END IF;END;$g$;
DO $g$ BEGIN IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='religion_benediction_demander' AND (p.oid IS DISTINCT FROM to_regprocedure('public.religion_benediction_demander(text,uuid)') OR md5(p.prosrc)<>'469dcbbccb2f987b550e3cac67d2100f')) THEN RAISE EXCEPTION 'definition_non_examinee: religion_benediction_demander';END IF;END;$g$;

CREATE TABLE IF NOT EXISTS public.religion_contacts_referentiel(pays text,ville text,batiment text,piece text,nom text,fonction text NOT NULL,PRIMARY KEY(pays,ville,batiment,piece,nom));
CREATE TABLE IF NOT EXISTS public.religion_benedictions(acteur uuid PRIMARY KEY,demande uuid NOT NULL,religieux text NOT NULL,accordee_at timestamptz NOT NULL,expire_at timestamptz NOT NULL,consommee_at timestamptz,CHECK(expire_at>accordee_at));
CREATE TABLE IF NOT EXISTS public.religion_benedictions_recus(acteur uuid NOT NULL,requete uuid NOT NULL,religieux text NOT NULL,resultat jsonb NOT NULL,traitee_at timestamptz NOT NULL,PRIMARY KEY(acteur,requete));
CREATE TABLE IF NOT EXISTS public.religion_benedictions_consommations(acteur uuid NOT NULL,acte uuid NOT NULL,famille text NOT NULL,demande uuid,bonus integer NOT NULL,traitee_at timestamptz NOT NULL,PRIMARY KEY(acteur,acte),UNIQUE(acteur,demande),CHECK((bonus=0 AND demande IS NULL) OR (bonus=5 AND demande IS NOT NULL)));
ALTER TABLE public.religion_benedictions_consommations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.religion_benedictions_consommations FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE public.religion_contacts_referentiel ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.religion_benedictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.religion_benedictions_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.religion_contacts_referentiel,public.religion_benedictions,public.religion_benedictions_recus FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO public.religion_contacts_referentiel VALUES
('republic','capitale','tabernacle-impots','nef_principale','Enfant de chœur Lacroix','clerc'),
('republic','capitale','tabernacle-impots','nef_principale','Père Ception','grand_pretre'),
('republic','capitale','tabernacle-impots','sacristie','Père Ception','grand_pretre'),
('republic','ville_a','notre-dame-mer','nef','Père Iscope','pretre'),
('republic','ville_b','eglise-montrouge','salle','Abbé Tonnière','pretre')
ON CONFLICT(pays,ville,batiment,piece,nom) DO NOTHING;
DO $r$ BEGIN IF EXISTS(WITH attendu(pays,ville,batiment,piece,nom,fonction) AS (VALUES ('republic','capitale','tabernacle-impots','nef_principale','Enfant de chœur Lacroix','clerc'),
('republic','capitale','tabernacle-impots','nef_principale','Père Ception','grand_pretre'),
('republic','capitale','tabernacle-impots','sacristie','Père Ception','grand_pretre'),
('republic','ville_a','notre-dame-mer','nef','Père Iscope','pretre'),
('republic','ville_b','eglise-montrouge','salle','Abbé Tonnière','pretre')) SELECT 1 FROM attendu a FULL JOIN public.religion_contacts_referentiel r USING(pays,ville,batiment,piece,nom) WHERE a.fonction IS DISTINCT FROM r.fonction) THEN RAISE EXCEPTION 'referentiel_religieux_divergent';END IF;END;$r$;
CREATE OR REPLACE FUNCTION public.religion_benediction_lire() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE identite uuid;b record;
BEGIN
 SELECT id INTO identite FROM public.personnages_donnees WHERE name=public.mon_personnage();
 IF identite IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 SELECT * INTO b FROM public.religion_benedictions WHERE acteur=identite;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'benediction',jsonb_build_object('actif',false));END IF;
 RETURN jsonb_build_object('ok',true,'benediction',jsonb_build_object('actif',b.consommee_at IS NULL AND b.expire_at>clock_timestamp(),'expireA',b.expire_at,'accordeeA',b.accordee_at));
END;$f$;
REVOKE ALL ON FUNCTION public.religion_benediction_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.religion_benediction_lire() TO authenticated;

CREATE OR REPLACE FUNCTION public.religion_benediction_consommer_interne(p_acteur uuid,p_famille text,p_requete uuid) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE b record;bonus integer:=0;instant timestamptz;
BEGIN
 IF p_acteur IS NULL OR p_requete IS NULL OR coalesce(p_famille,'')!~'^[a-z][a-z_0-9]*$' THEN RAISE EXCEPTION 'acte_benediction_invalide';END IF;
 -- Même verrou et même ordre que les actes hôtes : acteur, état privé, reçu.
 PERFORM 1 FROM public.personnages_donnees WHERE id=p_acteur FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'acteur_benediction_absent';END IF;
 IF EXISTS(SELECT 1 FROM public.religion_benedictions_consommations WHERE acteur=p_acteur AND acte=p_requete) THEN
  RAISE EXCEPTION 'acte_benediction_deja_traite';
 END IF;
 SELECT * INTO b FROM public.religion_benedictions WHERE acteur=p_acteur FOR UPDATE;
 instant:=clock_timestamp();
 IF FOUND AND b.consommee_at IS NULL AND b.expire_at>instant THEN
  bonus:=5;
  UPDATE public.religion_benedictions SET consommee_at=instant WHERE acteur=p_acteur;
 END IF;
 INSERT INTO public.religion_benedictions_consommations(acteur,acte,famille,demande,bonus,traitee_at)
 VALUES(p_acteur,p_requete,p_famille,CASE WHEN bonus=5 THEN b.demande ELSE NULL END,bonus,instant);
 RETURN bonus;
END;$f$;
REVOKE ALL ON FUNCTION public.religion_benediction_consommer_interne(uuid,text,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.religion_benediction_demander(p_religieux text,p_requete uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE moi text:=public.mon_personnage();p record;ancien record;r jsonb;v_religieux text:=btrim(regexp_replace(coalesce(p_religieux,''),' \(PNJ\)$',''));jet integer;instant timestamptz;
BEGIN
 IF moi IS NULL OR auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR v_religieux='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 SELECT * INTO ancien FROM public.religion_benedictions_recus WHERE acteur=p.id AND requete=p_requete;
 IF FOUND THEN
  IF ancien.religieux IS DISTINCT FROM v_religieux THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  RETURN ancien.resultat||jsonb_build_object('rejeu',true)||public.religion_benediction_lire();
 END IF;
 IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi))
  OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 IF p.excommunie IS NOT NULL AND p.excommunie<>'null'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','excommunication');END IF;
 IF NOT EXISTS(SELECT 1 FROM public.religion_contacts_referentiel c WHERE c.pays=p.country AND c.ville=p.current_city AND c.batiment=p.current_building AND c.piece=p.current_room AND c.nom=v_religieux) THEN RETURN jsonb_build_object('ok',false,'raison','religieux_non_habilite_sur_place');END IF;
 -- Un référent matérialisé dans le socle PNJ suit sa position réelle (y compris un leader).
 IF EXISTS(SELECT 1 FROM public.pnj_membres m WHERE m.nom=v_religieux AND m.pays=p.country)
  AND NOT EXISTS(SELECT 1 FROM public.pnj_membres m WHERE m.nom=v_religieux AND m.pays=p.country AND m.statut='actif' AND public.pnj_co_present(moi,m.id)) THEN RETURN jsonb_build_object('ok',false,'raison','religieux_absent');END IF;
 -- Capacité privée déjà employée par les commandes financières : même payeur, aucun débit local.
 INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,p.country||'_'||p.current_building,'demander_benediction_contact',1,0);
 r:=public.payer_ordre(moi,'demander_benediction_contact',1,0);
 DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r;END IF;
 jet:=public.terrain_negociation_jet_interne();
 IF jet NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'jet_invalide';END IF;
 IF jet<=80 THEN
  instant:=clock_timestamp();
  INSERT INTO public.religion_benedictions(acteur,demande,accordee_at,expire_at,religieux) VALUES(p.id,p_requete,instant,instant+interval '24 hours',v_religieux)
  ON CONFLICT(acteur) DO UPDATE SET demande=excluded.demande,accordee_at=excluded.accordee_at,expire_at=excluded.expire_at,religieux=excluded.religieux,consommee_at=NULL;
 END IF;
 r:=jsonb_build_object('ok',true,'succes',jet<=80,'jet',jet,'religieux',v_religieux,'pa',(r->>'pa')::integer);
 INSERT INTO public.religion_benedictions_recus VALUES(p.id,p_requete,v_religieux,r,clock_timestamp());
 RETURN r||public.religion_benediction_lire();
END;$f$;
-- Attribution non exposée tant que les actes consommateurs ne sont pas raccordés.
REVOKE ALL ON FUNCTION public.religion_benediction_demander(text,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
