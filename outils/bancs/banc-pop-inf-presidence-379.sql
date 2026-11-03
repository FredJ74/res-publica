-- Banc annulé #379, lots présidence et 2 (Claude, 03/11/2026). Base jetable uniquement :
--   outils/bancs/monter-base-jetable.sh puis
--   psql -h /tmp/pgjet -p 54329 -U postgres -d jet -v ON_ERROR_STOP=1 -f outils/bancs/banc-pop-inf-presidence-379.sql
-- Tout est annulé à la fin : ROLLBACK.
BEGIN;
ALTER TABLE public.personnages_donnees DISABLE TRIGGER trg_personnage_pays_declare; -- référentiel absent de la base jetable
SELECT set_config('request.jwt.claims','{"sub":"00000000-0000-4000-9000-000000000379","role":"authenticated"}',true);
-- Coûts relevés en production le 03/11 (le catalogue n'est pas semé dans la base jetable).
INSERT INTO public.ordres_couts(fn,pa,cost) VALUES ('censurer_media',2,0),('mobiliser_police',2,0),('banquet_diplo',3,0),('reception_etat',2,0),('corrompre_armurier#reussite',0,100),('traiter_manifestations',1,0) ON CONFLICT DO NOTHING;
INSERT INTO auth.users(id) VALUES ('00000000-0000-4000-9000-000000000379') ON CONFLICT DO NOTHING;
INSERT INTO public.personnages_donnees(name,country,user_id,pa,moral,resources,poste,current_city)
VALUES ('Banc379','republic','00000000-0000-4000-9000-000000000379',50,50,
        '{"pop":50,"inf":50}','{"id":"president"}','capitale');
CREATE TEMP TABLE banc(cas text, ok boolean, detail text) ON COMMIT DROP;
GRANT ALL ON banc TO authenticated;
CREATE FUNCTION public.banc379_jauges() RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS
 $$ SELECT jsonb_build_object('pop',resources->'pop','inf',resources->'inf','pa',pa,'moral',moral,'arg',arg)
    FROM public.personnages_donnees WHERE name='Banc379' $$;
GRANT EXECUTE ON FUNCTION public.banc379_jauges() TO authenticated;
SELECT set_config('request.path','/rpc/jauges_ordre_executer',true);
SET LOCAL ROLE authenticated;

DO $b$
DECLARE r jsonb; avant jsonb; apres jsonb; i integer; vus_scandale boolean:=false; vus_calme boolean:=false;
BEGIN
 -- Décret inutile : PA 1, POP -5..+14, INF +2..+11, refus sans poste.
 avant:=public.banc379_jauges();
 r:=public.jauges_ordre_executer('decret_inutile',gen_random_uuid(),'{}');
 apres:=public.banc379_jauges();
 INSERT INTO banc VALUES('decret_paye_et_borne',
   r->>'ok'='true' AND (apres->>'pa')::int=(avant->>'pa')::int-1
   AND (r->>'gain_pop')::int BETWEEN -5 AND 14 AND (r->>'gain_inf')::int BETWEEN 2 AND 11
   AND (apres->>'pop')::numeric=(r->>'pop')::numeric, r::text);
 -- Rejeu de la même requête : verdict stable, aucun second effet.
 r:=public.jauges_ordre_executer('decret_inutile','11111111-1111-4111-8111-111111111111','{}');
 avant:=public.banc379_jauges();
 r:=public.jauges_ordre_executer('decret_inutile','11111111-1111-4111-8111-111111111111','{}');
 INSERT INTO banc VALUES('decret_rejeu_sans_double_effet', r->>'rejeu'='true' AND public.banc379_jauges()=avant, r::text);
 -- Contexte forgé refusé.
 r:=public.jauges_ordre_executer('decret_inutile',gen_random_uuid(),'{"pop":99}');
 INSERT INTO banc VALUES('decret_contexte_forge_refuse', r->>'raison'='contexte_invalide', r::text);
 -- Référendum (3 PA, +10/+8) et deuil (1 PA, +15/0).
 avant:=public.banc379_jauges();
 r:=public.jauges_ordre_executer('message_presidentiel',gen_random_uuid(),'{"type":"referendum"}');
 apres:=public.banc379_jauges();
 INSERT INTO banc VALUES('referendum', r->>'ok'='true' AND (apres->>'pa')::int=(avant->>'pa')::int-3
   AND (r->>'gain_pop')::int=10 AND (r->>'gain_inf')::int=8, r::text);
 avant:=public.banc379_jauges();
 r:=public.jauges_ordre_executer('message_presidentiel',gen_random_uuid(),'{"type":"deuil"}');
 apres:=public.banc379_jauges();
 INSERT INTO banc VALUES('deuil', r->>'ok'='true' AND (apres->>'pa')::int=(avant->>'pa')::int-1
   AND (r->>'gain_pop')::int=15 AND (r->>'gain_inf')::int=0, r::text);
 r:=public.jauges_ordre_executer('message_presidentiel',gen_random_uuid(),'{"type":"conference"}');
 INSERT INTO banc VALUES('message_type_inconnu_refuse', r->>'raison'='contexte_invalide', r::text);
 -- Censure : réservée au ministre de l'Information.
 r:=public.jauges_ordre_executer('censurer_media',gen_random_uuid(),'{"media":"La Tribune"}');
 INSERT INTO banc VALUES('censure_poste_requis', r->>'raison'='poste_requis', r::text);
 RESET ROLE;
 UPDATE public.personnages_donnees SET poste='{"id":"min_info"}', pa=200 WHERE name='Banc379';
 SET LOCAL ROLE authenticated;
 FOR i IN 1..40 LOOP
  r:=public.jauges_ordre_executer('censurer_media',gen_random_uuid(),'{"media":"La Tribune"}');
  IF (r->>'scandale')::boolean THEN vus_scandale:=vus_scandale OR (r->>'gain_pop')::int=-20;
  ELSE vus_calme:=vus_calme OR (r->>'gain_pop')::int=0; END IF;
 END LOOP;
 INSERT INTO banc VALUES('censure_scandale_et_calme_serveur', vus_scandale AND vus_calme, '');
 -- Intervention policière : commissaire seulement, catalogue fixe.
 RESET ROLE;
 UPDATE public.personnages_donnees SET poste='{"id":"commissaire"}', resources='{"pop":50,"inf":50}' WHERE name='Banc379';
 SET LOCAL ROLE authenticated;
 r:=public.jauges_ordre_executer('mobiliser_police',gen_random_uuid(),'{"option":"reprimer"}');
 INSERT INTO banc VALUES('police_reprimer_moins_15', r->>'ok'='true' AND (r->>'gain_pop')::int=-15 AND (r->>'isn')::int=10, r::text);
 r:=public.jauges_ordre_executer('mobiliser_police',gen_random_uuid(),'{"option":"reprimer","pop":10}');
 INSERT INTO banc VALUES('police_option_forgee_refusee', r->>'raison'='contexte_invalide', r::text);
 -- Guerre : -20 POP +10 INF au président.
 RESET ROLE;
 UPDATE public.personnages_donnees SET poste='{"id":"president"}', resources='{"pop":50,"inf":50}' WHERE name='Banc379';
 SET LOCAL ROLE authenticated;
 BEGIN
  r:=public.guerre_declarer('soviet');
  INSERT INTO banc VALUES('guerre_jauges_serveur',
    r->>'ok'<>'true' OR ((r->'jauges'->>'pop')::numeric=30 AND (r->'jauges'->>'inf')::numeric=60), r::text);
 EXCEPTION WHEN OTHERS THEN INSERT INTO banc VALUES('guerre_jauges_serveur',false,SQLERRM); END;
 -- Banquet : issue tirée par le serveur, jauges dans la même réponse (formule d'origine).
 BEGIN
  r:=public.indice_diplomatique_ordre('banquet_diplo',3,1);
  INSERT INTO banc VALUES('banquet_jauges_selon_venue', r->>'ok'='true' AND
    CASE WHEN (r->>'venus')::int=1 THEN (r->'jauges'->>'gain_pop')::int=15 AND (r->'jauges'->>'gain_moral')::int=5
         ELSE (r->'jauges'->>'gain_pop')::int=-25 AND (r->'jauges'->>'gain_inf')::int=-20 END, r::text);
 EXCEPTION WHEN OTHERS THEN INSERT INTO banc VALUES('banquet_jauges_selon_venue',false,SQLERRM); END;
 -- Lot 2 : corruption de l'armurier.
 r:=public.jauges_ordre_executer('corrompre_armurier',gen_random_uuid(),'{}');
 INSERT INTO banc VALUES('armurier_hors_comptoir_refuse', r->>'raison'='pas_sur_place', r::text);
 RESET ROLE;
 UPDATE public.personnages_donnees SET current_building='armurerie', liquide=100000, arg=100000 WHERE name='Banc379';
 SET LOCAL ROLE authenticated;
 vus_scandale:=false; vus_calme:=false;
 FOR i IN 1..60 LOOP
  avant:=public.banc379_jauges();
  r:=public.jauges_ordre_executer('corrompre_armurier',gen_random_uuid(),'{}');
  IF (r->>'corruption_reussie')::boolean THEN
    vus_scandale:=vus_scandale OR ((r->>'gain_inf')::int=5 AND (r->>'arg')::numeric=(avant->>'arg')::numeric-100);
  ELSE vus_calme:=vus_calme OR ((r->>'gain_pop')::int=-5 AND (r->>'gain_inf')::int=-5); END IF;
 END LOOP;
 INSERT INTO banc VALUES('armurier_reussite_et_echec_serveur', vus_scandale AND vus_calme, '');
 -- Lot 2 : demande de manifestation traitée par le ministre de l'Intérieur.
 RESET ROLE;
 UPDATE public.personnages_donnees SET poste='{"id":"min_int"}', resources='{"pop":50,"inf":50}', pa=20 WHERE name='Banc379';
 INSERT INTO public.demandes_manifestation(id,statut,data) VALUES ('banc-manif-379','attente','{"pays":"republic","sujet":"Banc"}');
 SET LOCAL ROLE authenticated;
 r:=public.jauges_ordre_executer('manifestation_traiter',gen_random_uuid(),'{"id":"banc-manif-379","autorise":false}');
 INSERT INTO banc VALUES('manifestation_interdite_moins_8', r->>'ok'='true' AND (r->>'gain_pop')::int=-8 AND (r->>'pa')::int=19
   AND (SELECT statut FROM public.demandes_manifestation WHERE id='banc-manif-379')='interdite', r::text);
 r:=public.jauges_ordre_executer('manifestation_traiter',gen_random_uuid(),'{"id":"banc-manif-379","autorise":true}');
 INSERT INTO banc VALUES('manifestation_deja_traitee_gratuite', r->>'raison'='demande_deja_traitee'
   AND (public.banc379_jauges()->>'pa')::int=19, r::text);
 -- Aide interne inaccessible aux navigateurs.
 BEGIN
  PERFORM public.jauges_effet_appliquer_interne('Banc379',50,50);
  INSERT INTO banc VALUES('aide_interne_fermee',false,'appel accepté');
 EXCEPTION WHEN insufficient_privilege THEN INSERT INTO banc VALUES('aide_interne_fermee',true,'');
 END;
END $b$;

RESET ROLE;
SELECT cas, ok, left(detail,200) FROM banc ORDER BY ok, cas;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM banc WHERE NOT ok) THEN RAISE WARNING 'banc 379 presidence : ECHECS'; END IF; END $$;
ROLLBACK;
