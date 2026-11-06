-- Banc annulé #379, lot 3 (Claude, 03/11/2026). Base jetable uniquement :
--   outils/bancs/monter-base-jetable.sh puis
--   psql -h /tmp/pgjet -p 54329 -U postgres -d jet -v ON_ERROR_STOP=1 -f outils/bancs/banc-pop-inf-lot3-379.sql
-- Tout est annulé à la fin : ROLLBACK. Chaque section porte le nom de son sous-lot.
BEGIN;
ALTER TABLE public.personnages_donnees DISABLE TRIGGER trg_personnage_pays_declare; -- référentiel absent de la base jetable
CREATE TEMP TABLE banc(cas text, ok boolean, detail text) ON COMMIT DROP;
GRANT ALL ON banc TO authenticated;
INSERT INTO auth.users(id) VALUES ('00000000-0000-4000-9000-000000003791'),('00000000-0000-4000-9000-000000003792') ON CONFLICT DO NOTHING;
SELECT 1 FROM (SELECT set_config('request.jwt.claims','{"sub":"00000000-0000-4000-9000-000000003792","role":"authenticated"}',true)) z;
INSERT INTO public.personnages_donnees(name,country,user_id,pa,moral,hp,arg,liquide,resources,current_city)
VALUES ('BancMembre','republic','00000000-0000-4000-9000-000000003792',50,50,80,5000,5000,'{"pop":50,"inf":50}','capitale');
SELECT 1 FROM (SELECT set_config('request.jwt.claims','{"sub":"00000000-0000-4000-9000-000000003791","role":"authenticated"}',true)) z;
INSERT INTO public.personnages_donnees(name,country,user_id,pa,moral,hp,arg,liquide,resources,current_city)
VALUES ('BancChef','republic','00000000-0000-4000-9000-000000003791',50,50,80,5000,5000,'{"pop":50,"inf":50}','capitale');
CREATE FUNCTION public.banc379_j(p text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS
 $$ SELECT jsonb_build_object('pop',resources->'pop','inf',resources->'inf','pa',pa,'moral',moral,'hp',hp,'arg',arg,'liquide',liquide)
    FROM public.personnages_donnees WHERE name=p $$;
GRANT EXECUTE ON FUNCTION public.banc379_j(text) TO authenticated;

-- ===== 3a. Bonus de location (prelever_loyer_bail, rôle serveur) =====
-- La caisse de la mairie n'est pas semée dans la base jetable : recette municipale simulée (annulée).
CREATE OR REPLACE FUNCTION public.recette_municipale(p_pays text,p_ville text,p_montant numeric,p_canal text)
RETURNS jsonb LANGUAGE sql AS $$ SELECT '{"ok":true}'::jsonb $$;
INSERT INTO public.organisations(id,country_origine,data) VALUES
 ('orgBanc','republic','{"chef":"BancChef","membres":["BancMembre"],"caisse":0}');
INSERT INTO public.locations_actives(id,country,data) VALUES
 ('bailChef','republic',jsonb_build_object('country','republic','city','capitale','buildingId','banc-bat','roomId','vitrine',
   'prix',100,'bonusPOP',10,'bonusINF',5,'bonusDIS',0,'orgaId','orgBanc','locataire','BancChef')),
 ('bailMembre','republic',jsonb_build_object('country','republic','city','capitale','buildingId','banc-bat','roomId','boutique',
   'prix',100,'bonusPOP',10,'bonusINF',5,'bonusDIS',0,'orgaId','orgBanc','locataire','BancMembre')),
 ('bailPauvre','republic',jsonb_build_object('country','republic','city','capitale','buildingId','banc-bat','roomId','cave',
   'prix',999999,'bonusPOP',10,'bonusINF',5,'bonusDIS',0,'orgaId','orgBanc','locataire','BancChef'));
DO $b$
DECLARE v text; av jsonb; ap jsonb;
BEGIN
 av:=public.banc379_j('BancChef');
 v:=public.prelever_loyer_bail('bailChef');
 ap:=public.banc379_j('BancChef');
 INSERT INTO banc VALUES('3a_loyer_paye_bonus_chef',v='paye' AND (ap->>'pop')::int=(av->>'pop')::int+3 AND (ap->>'inf')::int=(av->>'inf')::int+1
   AND (ap->>'arg')::numeric=(av->>'arg')::numeric-100, v||' '||av::text||' -> '||ap::text);
 v:=public.prelever_loyer_bail('bailChef');
 INSERT INTO banc VALUES('3a_rejeu_meme_jour_sans_bonus',v='deja_preleve' AND public.banc379_j('BancChef')=ap, v);
 av:=public.banc379_j('BancMembre');
 v:=public.prelever_loyer_bail('bailMembre');
 ap:=public.banc379_j('BancMembre');
 INSERT INTO banc VALUES('3a_locataire_non_chef_sans_bonus',v='paye' AND ap->'pop'=av->'pop' AND ap->'inf'=av->'inf', v||' '||ap::text);
 av:=public.banc379_j('BancChef');
 v:=public.prelever_loyer_bail('bailPauvre');
 ap:=public.banc379_j('BancChef');
 INSERT INTO banc VALUES('3a_impaye_sans_bonus',v<>'paye' AND ap->'pop'=av->'pop' AND ap->'inf'=av->'inf', v);
END $b$;

-- ===== 3b. Paie des escorts (escorts_payer_jour, rôle authenticated) =====
INSERT INTO public.pnj_membres(id,famille,classe,nom,pays,proprietaire_pj,leader_pj,pa,statut)
VALUES ('esc_ok','employe','beta','Escort Payable','republic','BancChef','BancChef',12,'actif'),
       ('esc_ko','employe','beta','Escort Ruineuse','republic','BancChef','BancChef',12,'actif');
INSERT INTO public.pnj_employes_metier(pnj_id,job,role_libelle,cout_jour) VALUES ('esc_ok','escort','Escort',300),('esc_ko','escort','Escort',99999);
SELECT 1 FROM (SELECT set_config('request.path','/rpc/escorts_payer_jour',true)) z;
SELECT 1 FROM (SELECT set_config('request.jwt.claims','{"sub":"00000000-0000-4000-9000-000000003791","role":"authenticated"}',true)) z;
SET LOCAL ROLE authenticated;
DO $b$
DECLARE r jsonb; av jsonb; ap jsonb;
BEGIN
 av:=public.banc379_j('BancChef');
 r:=public.escorts_payer_jour();
 ap:=public.banc379_j('BancChef');
 INSERT INTO banc VALUES('3b_paie_et_impaye',coalesce((r->>'ok')::boolean,false) AND jsonb_array_length(r->'paies')=2
   AND (ap->>'arg')::numeric=(av->>'arg')::numeric-300 AND (ap->>'pop')::int=(av->>'pop')::int-20,
   r::text||' '||av::text||' -> '||ap::text);
 r:=public.escorts_payer_jour();
 INSERT INTO banc VALUES('3b_rejeu_meme_jour_sans_effet',jsonb_array_length(r->'paies')=0 AND public.banc379_j('BancChef')=ap, r::text);
END $b$;
RESET ROLE;
INSERT INTO banc SELECT '3b_escort_impayee_partie',statut='disparu',statut FROM public.pnj_membres WHERE id='esc_ko';
INSERT INTO banc SELECT '3b_escort_payee_reste',statut='actif',statut FROM public.pnj_membres WHERE id='esc_ok';
INSERT INTO banc SELECT '3b_recus_fermes_aux_clients',NOT has_table_privilege('authenticated','public.escorts_paies_recus','SELECT'),'';

-- ===== 3c. Dons aux PNJ (dispatcher, rôle authenticated) =====
-- BancChef au restaurant de La Républia (Marie Leblanc journaliste, Gaston Sauceblanche serveur).
UPDATE public.personnages_donnees SET current_building='hotel-republica',current_room='restaurant',
  inventory='[{"id":"k1","type":"kompromat","name":"Dossier","cible":"X"},{"id":"t1","type":"tract","name":"Tract"},{"id":"c1","type":"cadeau","name":"Fleurs"}]'
 WHERE name='BancChef';
SELECT 1 FROM (SELECT set_config('request.path','/rpc/jauges_ordre_executer',true)) z;
SET LOCAL ROLE authenticated;
DO $b$
DECLARE r jsonb; av jsonb; ap jsonb; inv jsonb;
BEGIN
 av:=public.banc379_j('BancChef');
 r:=public.jauges_ordre_executer('don_argent_pnj',gen_random_uuid(),'{"nom":"Marie Leblanc","montant":200}');
 ap:=public.banc379_j('BancChef');
 INSERT INTO banc VALUES('3c_argent_journaliste',coalesce((r->>'ok')::boolean,false) AND r->>'job'='journaliste'
   AND (ap->>'arg')::numeric=(av->>'arg')::numeric-200 AND (ap->>'inf')::int=least(100,(av->>'inf')::int+8) AND (ap->>'pop')::int=least(100,(av->>'pop')::int+5),
   r::text);
 av:=ap;
 r:=public.jauges_ordre_executer('don_argent_pnj',gen_random_uuid(),'{"nom":"Gaston Sauceblanche","montant":100}');
 ap:=public.banc379_j('BancChef');
 INSERT INTO banc VALUES('3c_argent_serveur_moral',(ap->>'moral')::int=(av->>'moral')::int+5 AND (ap->>'inf')::int=least(100,(av->>'inf')::int+2), r::text);
 av:=ap;
 r:=public.jauges_ordre_executer('don_argent_pnj',gen_random_uuid(),'{"nom":"Personne Inventee","montant":100}');
 INSERT INTO banc VALUES('3c_pnj_absent_refuse',r->>'raison'='pnj_non_present' AND public.banc379_j('BancChef')=av, r::text);
 r:=public.jauges_ordre_executer('don_argent_pnj',gen_random_uuid(),'{"nom":"Marie Leblanc","montant":99999999}');
 INSERT INTO banc VALUES('3c_fonds_insuffisants_rien',r->>'raison'='fonds_insuffisants' AND public.banc379_j('BancChef')=av, r::text);
 r:=public.jauges_ordre_executer('don_argent_pnj',gen_random_uuid(),'{"nom":"Marie Leblanc","montant":-5}');
 INSERT INTO banc VALUES('3c_montant_negatif_refuse',r->>'raison'='contexte_invalide', r::text);
 r:=public.jauges_ordre_executer('don_objet_pnj',gen_random_uuid(),'{"nom":"Marie Leblanc","index":1,"signature":{"id":"t1","type":"tract","name":"Tract"}}');
 INSERT INTO banc VALUES('3c_tract_refuse',r->>'raison' IN('objet_non_donnable','objet_absent') AND public.banc379_j('BancChef')=av, r::text);
 r:=public.jauges_ordre_executer('don_objet_pnj',gen_random_uuid(),'{"nom":"Marie Leblanc","index":0,"signature":{"id":"k1","type":"kompromat","name":"Dossier","cible":"X"}}');
 ap:=public.banc379_j('BancChef');
 inv:=r->'inventory';
 INSERT INTO banc VALUES('3c_kompromat_journaliste',coalesce((r->>'ok')::boolean,false) AND (r->>'scandale')::boolean
   AND jsonb_array_length(inv)=2 AND jsonb_typeof(r->'inventory')='array' AND (ap->>'inf')::int=least(100,(av->>'inf')::int+8),
   r::text);
END $b$;
RESET ROLE;
INSERT INTO banc SELECT '3c_objet_sorti_en_base',jsonb_array_length(inventory)=2 AND NOT inventory @> '[{"id":"k1"}]',inventory::text
  FROM public.personnages_donnees WHERE name='BancChef';

-- ===== 3d. Dîner d'affaires du Capitaine Sauvage (contrat commerce_v1) =====
CREATE OR REPLACE FUNCTION public.appliquer_taxe_transaction(p_pays text,p_ville text,p_montant_brut numeric)
RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object('net',p_montant_brut) $$; -- fiscalité non semée (annulé)
INSERT INTO public.ordres_couts(fn,pa,cost) VALUES ('diner_affaires',2,150) ON CONFLICT DO NOTHING;
INSERT INTO public.pa_bonus_differes(source,montant) VALUES ('diner_affaires',3) ON CONFLICT DO NOTHING;
INSERT INTO public.entreprises(id,data) VALUES ('brasserie-republic-ville_a-capitaine-sauvage-salle_principale',
 '{"type":"brasserie","country":"republic","city":"ville_a","caisse":0,"carte":["menu_psm_1","menu_psm_2","menu_psm_3","vin"],
   "stockProduits":{"menu_psm_1":1,"menu_psm_2":5,"menu_psm_3":0,"vin":3}}')
 ON CONFLICT (id) DO UPDATE SET data=EXCLUDED.data;
UPDATE public.personnages_donnees SET current_city='ville_a',current_building='capitaine-sauvage',current_room='salle_principale',pa=50,bonus_pa_differe=0
 WHERE name IN('BancChef','BancMembre');
SELECT 1 FROM (SELECT set_config('request.path','/rpc/restaurant_diner_servir',true)) z;
CREATE TEMP TABLE diner(id bigint) ON COMMIT DROP; GRANT ALL ON diner TO authenticated;
CREATE FUNCTION public.banc379_stock() RETURNS jsonb LANGUAGE sql SECURITY DEFINER AS
 $$ SELECT data->'stockProduits' FROM public.entreprises WHERE id='brasserie-republic-ville_a-capitaine-sauvage-salle_principale' $$;
GRANT EXECUTE ON FUNCTION public.banc379_stock() TO authenticated;
SET LOCAL ROLE authenticated;
DO $b$ DECLARE r jsonb; BEGIN
 r:=public.restaurant_diner_creer('diner-banc379-psm-0001','BancMembre',false,'Un verre ?');
 INSERT INTO diner VALUES((r->>'id')::bigint);
 INSERT INTO banc VALUES('3d_invitation_pj_en_attente',coalesce((r->>'ok')::boolean,false) AND r->>'statut'='attente' AND (r->>'prix')::int=150,r::text);
 r:=public.restaurant_diner_creer('diner-banc379-psm-0002','Personne Inventee',true,'');
 INSERT INTO banc VALUES('3d_pnj_absent_refuse',r->>'raison'='pnj_non_present',r::text);
 r:=public.restaurant_diner_creer('diner-banc379-psm-0003','Marine Leroux',true,'');
 INSERT INTO banc VALUES('3d_pnj_present_tire_serveur',r->>'statut' IN('acceptee','refusee'),r::text);
 r:=public.restaurant_diner_servir((SELECT id FROM diner));
 INSERT INTO banc VALUES('3d_servir_avant_acceptation_refuse',r->>'raison'='acceptation_requise',r::text);
END $b$;
RESET ROLE;
SELECT 1 FROM (SELECT set_config('request.jwt.claims','{"sub":"00000000-0000-4000-9000-000000003792","role":"authenticated"}',true)) z;
SET LOCAL ROLE authenticated;
DO $b$ DECLARE r jsonb; BEGIN
 r:=public.restaurant_diner_repondre((SELECT id FROM diner),true,'Avec plaisir');
 INSERT INTO banc VALUES('3d_invite_accepte',coalesce((r->>'ok')::boolean,false),r::text);
 r:=public.restaurant_diner_servir((SELECT id FROM diner));
 INSERT INTO banc VALUES('3d_invite_ne_sert_pas',r->>'raison'='pas_mon_invitation',r::text);
END $b$;
RESET ROLE;
SELECT 1 FROM (SELECT set_config('request.jwt.claims','{"sub":"00000000-0000-4000-9000-000000003791","role":"authenticated"}',true)) z;
SET LOCAL ROLE authenticated;
DO $b$ DECLARE r jsonb; c0 jsonb; m0 jsonb; c1 jsonb; m1 jsonb; st jsonb; BEGIN
 c0:=public.banc379_j('BancChef'); m0:=public.banc379_j('BancMembre');
 r:=public.restaurant_diner_servir((SELECT id FROM diner));
 c1:=public.banc379_j('BancChef'); m1:=public.banc379_j('BancMembre'); st:=public.banc379_stock();
 INSERT INTO banc VALUES('3d_servi_paye_une_fois',coalesce((r->>'ok')::boolean,false) AND (c1->>'arg')::numeric=(c0->>'arg')::numeric-150
   AND (c1->>'pa')::int=(c0->>'pa')::int-2 AND (m1->>'arg')::numeric=(m0->>'arg')::numeric,r::text||' '||c0::text||' -> '||c1::text);
 INSERT INTO banc VALUES('3d_effets_deux_convives',(c1->>'inf')::int=least(100,(c0->>'inf')::int+5) AND (m1->>'inf')::int=least(100,(m0->>'inf')::int+5)
   AND (c1->>'moral')::int=(c0->>'moral')::int+2 AND (m1->>'hp')::int=least(100,(m0->>'hp')::int+10),m0::text||' -> '||m1::text);
 INSERT INTO banc VALUES('3d_stock_consomme_dans_l_ordre',st->>'menu_psm_1'='0' AND st->>'menu_psm_2'='4' AND st->>'vin'='2',st::text);
 r:=public.restaurant_diner_servir((SELECT id FROM diner));
 INSERT INTO banc VALUES('3d_rejeu_sans_double_effet',(r->>'rejeu')::boolean AND public.banc379_j('BancChef')=c1 AND public.banc379_stock()=st,r::text);
 r:=public.restaurant_diner_suivre();
 INSERT INTO banc VALUES('3d_suivi_voit_le_contrat',jsonb_array_length(r->'invitations')>=1,r::text);
END $b$;
RESET ROLE;

-- ===== Fermeture : la sauvegarde générale ne fabrique plus de jauges (20261104000000) =====
-- Même montage que banc-pop-inf-forge-379.cjs : table témoin + trigger, navigateur simulé.
CREATE OR REPLACE FUNCTION public.est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$ SELECT false $$; -- annulé
CREATE TEMP TABLE fiche(name text PRIMARY KEY, resources jsonb NOT NULL DEFAULT '{}'::jsonb) ON COMMIT DROP;
CREATE TRIGGER controle BEFORE INSERT OR UPDATE ON fiche FOR EACH ROW EXECUTE FUNCTION public.personnages_fusionner_pop();
INSERT INTO fiche VALUES ('F','{"pop":10,"inf":10,"dis":50}');
SELECT 1 FROM (SELECT set_config('request.path','/rest/v1/personnages',true)) z;
UPDATE fiche SET resources='{"pop":99,"popBase":10,"inf":99,"infBase":10,"dis":42}';
INSERT INTO banc SELECT 'F_base_courante_falsifiee_ignoree',(resources->>'pop')::int=10 AND (resources->>'inf')::int=10
  AND (resources->>'dis')::int=42 AND NOT resources ? 'popBase' AND NOT resources ? 'infBase',resources::text FROM fiche;
UPDATE fiche SET resources='{"pop":3,"popBase":50,"inf":80,"infBase":1,"dis":42}';
INSERT INTO banc SELECT 'F_base_perimee_deux_onglets_ignoree',(resources->>'pop')::int=10 AND (resources->>'inf')::int=10,resources::text FROM fiche;
UPDATE fiche SET resources='{"dis":40}';
INSERT INTO banc SELECT 'F_jauges_absentes_conservees',(resources->>'pop')::int=10 AND (resources->>'inf')::int=10,resources::text FROM fiche;
SELECT 1 FROM (SELECT set_config('request.path','/rpc/jauges_ordre_executer',true)) z;
UPDATE fiche SET resources='{"pop":17,"inf":12,"dis":40}';
INSERT INTO banc SELECT 'F_commande_serveur_ecrit',(resources->>'pop')::int=17 AND (resources->>'inf')::int=12,resources::text FROM fiche;

-- @@SUITE@@

SELECT cas, ok, CASE WHEN ok THEN '' ELSE detail END FROM banc ORDER BY cas;
SELECT count(*) FILTER (WHERE ok)||'/'||count(*) AS bilan FROM banc;
ROLLBACK;
