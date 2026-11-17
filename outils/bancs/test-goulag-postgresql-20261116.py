#!/usr/bin/env python3
"""Épreuves locales réelles, sans URL distante ni données de personnages.

Baseline + métadonnées vivantes du 16/11 + seules migrations du lot.
Les valeurs d'activation sont des PARAMÈTRES DE FIXTURE, jamais une décision
ni une configuration livrée. La production reste verrouillée par CHECK(false).
Ce décor ne certifie pas la fidélité complète du schéma de production.
"""
import argparse, concurrent.futures, importlib.util, json, re, sys, tempfile, unittest
from pathlib import Path
import pgserver, psycopg2
from psycopg2.extras import Json
R=Path(__file__).resolve().parents[2]
F=R/'outils/bancs/fixtures/goulag-20261116'
sys.path.insert(0,str(R/'outils/baseline'))
spec=importlib.util.spec_from_file_location('ep',R/'outils/baseline/epreuve-postgresql.py')
ep=importlib.util.module_from_spec(spec);spec.loader.exec_module(ep)
arg=argparse.ArgumentParser();arg.add_argument('--postgres-bin',type=Path);opt=arg.parse_args()
if opt.postgres_bin:ep.configurer_binaires(opt.postgres_bin)

class Goulag(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory(prefix='hg-goulag-fixture-')
  cls.s=pgserver.get_server(Path(cls.tmp.name)/'data',cleanup_mode='delete')
  cls.c=psycopg2.connect(cls.s.get_uri());q=cls.c.cursor()
  for role in ['anon','authenticated','service_role','authenticator','supabase_auth_admin','supabase_admin','dashboard_user','supabase_read_only_user','hg219_cert_ro_20261101']:
   q.execute('CREATE ROLE '+role)
  q.execute(ep.PLATEFORME);morceaux,_=ep.assembler();ep.installer(q,morceaux)
  # Ajouts du relevé vivant : décor explicite, aucune retouche du baseline.
  for t in json.loads((F/'colonnes-vivantes.json').read_text()):
   q.execute('SELECT to_regclass(%s)',('public.'+t['name'],));existe=q.fetchone()[0] is not None
   for v in t['columns']:
    for seq in re.findall(r"nextval\('([a-z_0-9.]+)'::regclass\)",v['default'] or ''):
     q.execute('CREATE SEQUENCE IF NOT EXISTS '+seq)
   cols=['"'+v['name']+'" '+v['type']+(' DEFAULT '+v['default'] if v['default'] else '') for v in t['columns']]
   if not existe:
    q.execute('CREATE TABLE public."'+t['name']+'" ('+','.join(cols)+')')
    for k in t['constraints'] or []:q.execute('ALTER TABLE public."'+t['name']+'" ADD CONSTRAINT "'+k['name']+'" '+k['definition'])
   else:
    for col in cols:q.execute('ALTER TABLE public."'+t['name']+'" ADD COLUMN IF NOT EXISTS '+col)
  q.execute('SET check_function_bodies=off')
  for f in json.loads((F/'fonctions-vivantes.json').read_text()):
   q.execute(f['definition'])
   # CREATE OR REPLACE conserve les ACL du vieux baseline : rétablir celles du relevé réel.
   signature='public.'+f['signature']
   q.execute('REVOKE ALL ON FUNCTION '+signature+' FROM PUBLIC,anon,authenticated,service_role')
   acl=f.get('acl')
   if acl is None or re.search(r'(?:\{|,)=X',acl):q.execute('GRANT EXECUTE ON FUNCTION '+signature+' TO PUBLIC')
   for role in ['anon','authenticated','service_role']:
    if acl and re.search(r'(?:\{|,)'+role+r'=X',acl):q.execute('GRANT EXECUTE ON FUNCTION '+signature+' TO '+role)
  q.execute('SET check_function_bodies=on')
  q.execute('ALTER TABLE public.rue_noeuds_serveur ADD COLUMN IF NOT EXISTS directions jsonb')
  for table,rows in json.loads((F/'references-vivantes.json').read_text()).items():
   for row in rows:
    q.execute('INSERT INTO public.'+table+' SELECT * FROM jsonb_populate_record(NULL::public.'+table+',%s) ON CONFLICT DO NOTHING',(Json(row),))
  cls.migrations=[p for p in sorted((R/'migrations').glob('*goulag*.sql')) if '105000' not in p.name]
  for p in cls.migrations:q.execute(p.read_text())
  # Le déclencheur vivant de révision est exercé sous rôle client /rpc/.
  q.execute('DROP TRIGGER IF EXISTS fixture_goulag_revision ON public.personnages_donnees;CREATE TRIGGER fixture_goulag_revision BEFORE UPDATE OF inventory ON public.personnages_donnees FOR EACH ROW EXECUTE FUNCTION public.inventaire_revision_garder()')
  for i,(nom,pays) in enumerate([('__goulag_detenu','soviet'),('__goulag_visiteur','soviet'),('__goulag_republic','republic')],1):
   uid=f'00000000-0000-4000-8000-{i:012}'
   q.execute('INSERT INTO auth.users(id) VALUES(%s)',(uid,))
   q.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':uid,'role':'authenticated'}),))
   q.execute("INSERT INTO public.personnages_donnees(name,country,user_id,pa,current_city,current_building,current_room,inventory) VALUES(%s,%s,%s,20,'qhs','qhs-prison','entree_qhs','[]')",(nom,pays,uid))
  q.execute("""CREATE FUNCTION public.fixture_gratuit(p_champ text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$BEGIN
    IF p_champ='pa' THEN UPDATE personnages_donnees SET pa=pa+12 WHERE name=public.mon_personnage();
    ELSIF p_champ='inventaire' THEN PERFORM public.inventaire_deposer_interne(public.mon_personnage(),'{"stackKey":"pain","qty":1}',true);
    ELSE UPDATE personnages_donnees SET current_city=CASE current_city WHEN 'ville_a' THEN 'ville_b' ELSE 'ville_a' END WHERE name=public.mon_personnage(); END IF; END$$;
    REVOKE ALL ON FUNCTION public.fixture_gratuit(text) FROM PUBLIC;GRANT EXECUTE ON FUNCTION public.fixture_gratuit(text) TO authenticated;
    CREATE FUNCTION public.fixture_cadeau(p_cible text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $$SELECT public.inventaire_deposer_interne(p_cible,'{"stackKey":"pain","qty":1}',true)$$;
    REVOKE ALL ON FUNCTION public.fixture_cadeau(text) FROM PUBLIC;GRANT EXECUTE ON FUNCTION public.fixture_cadeau(text) TO authenticated;""")
  cls.c.commit()
 @classmethod
 def tearDownClass(cls):
  cls.c.close();cls.s.cleanup();cls.tmp.cleanup()
 def setUp(self):self.q=self.c.cursor();self._client=False
 def tearDown(self):self.c.rollback();self.q.close()
 def sql(self,sql,args=None):
  appel=re.match(r'SELECT public\.([a-z_0-9]+)\(',sql)
  if self._client and appel:self.q.execute("SELECT set_config('request.path',%s,true)",('/rpc/'+appel[1],))
  self.q.execute(sql,args);return self.q.fetchone()[0] if self.q.description else None
 def client(self,i=1):
  self.sql("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':f'00000000-0000-4000-8000-{i:012}','role':'authenticated'}),))
  self.sql("SELECT set_config('request.path','/rpc/goulag_toundra_agir',true)")
  self.q.execute('SET LOCAL ROLE authenticated');self._client=True
 def admin(self):self.q.execute('RESET ROLE');self._client=False
 def activation_fixture(self):
  self.q.execute('ALTER TABLE public.sovarka_goulag_configuration DROP CONSTRAINT sovarka_goulag_activation_figee')
  # Retrait du verrou dans la seule base jetable ; décisions de Fred du 16/11.
  self.q.execute("UPDATE public.sovarka_goulag_configuration SET active=true,champignons_malus=2,formule_arrestation='30_par_entree',autorisation_usage='permanente',retour_visiteur='choix_ville'")
 def traverser(self,nom='__goulag_detenu',destination='starovka',statut='detenu',progressions=0):
  self.q.execute("INSERT INTO public.sovarka_goulag_traversees(nom,destination,statut,progressions,champignons_choix) VALUES(%s,%s,%s,%s,'manger')",(nom,destination,statut,progressions))
 def test_activation_interdite_et_aucun_effet(self):
  self.q.execute('SAVEPOINT activation')
  with self.assertRaises(psycopg2.errors.CheckViolation):self.q.execute('UPDATE public.sovarka_goulag_configuration SET active=true')
  self.q.execute('ROLLBACK TO activation');self.client()
  for sql in ["SELECT public.goulag_toundra_demarrer('starovka')","SELECT public.goulag_toundra_agir('dormir')","SELECT public.sovarka_goulag_voyager('train')","SELECT public.sovarka_goulag_visite_demander()","SELECT public.sovarka_goulag_juger('absent','absent',3)"]:
   r=self.sql(sql);self.assertFalse(r['ok']);self.assertEqual(r['raison'],'goulag_non_active')
  self.admin();self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_traversees'),0)
  self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_autorisations'),0)
  self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_detenu'"),20)
 def fugitif(self):
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_a',current_building=NULL,current_room=NULL,current_street='starovka-rue-stade',est_emprisonne=NULL WHERE name='__goulag_detenu'")
  self.q.execute("INSERT INTO public.detentions(id,nom,country,city,qhs,jour_debut,jour_fin,mode_fin,jour_fin_effective) VALUES('fixture-origine','__goulag_detenu','soviet','ville_a',true,1,11,'evasion',1)")
  self.q.execute("INSERT INTO public.sovarka_goulag_traversees(nom,destination,statut,en_cours,progressions,detention_id,peine_gelee_secondes,recherche_id) VALUES('__goulag_detenu','starovka','detenu',false,7,'fixture-origine',3600,'fixture-recherche')")
 def graine(self,capture):
  for n in [i/50 for i in range(-50,51)]:
   self.sql('SELECT setseed(%s)',(n,));v=self.sql('SELECT random()')
   if (v<0.30)==capture:self.sql('SELECT setseed(%s)',(n,));return n
  self.fail('graine de fixture introuvable')
 def test_champignons_decision_2_unique(self):
  self.activation_fixture();self.traverser()
  self.q.execute("UPDATE public.sovarka_goulag_traversees SET debut_le=public.sovarka_jour_paris()-4,champignons_choix=NULL")
  self.client();self.assertTrue(self.sql("SELECT public.goulag_toundra_agir('champignons_refuser')")['ok'])
  self.assertEqual(self.sql("SELECT public.goulag_toundra_agir('dormir')")['pa'],21)
  self.admin();self.q.execute("UPDATE public.sovarka_goulag_traversees SET jour_sommeil=NULL")
  self.client();self.assertEqual(self.sql("SELECT public.goulag_toundra_agir('dormir')")['pa'],24)
 def test_refuge_reconnexion_tardive_sans_nuit(self):
  self.activation_fixture()
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_a',current_building='maison-starovka',current_room='piece_maison',pa=1,inventory='[{\"stackKey\":\"bois\",\"stackable\":true,\"qty\":8}]' WHERE name='__goulag_detenu'")
  self.q.execute("INSERT INTO public.sovarka_goulag_refuges(nom,destination,statut,arrivee_le) VALUES('__goulag_detenu','starovka','detenu',public.sovarka_jour_paris()-10)")
  self.client();r=self.sql('SELECT public.sovarka_goulag_refuge_terminer(8)');self.assertTrue(r['ok'],r);self.assertEqual([p['bois'] for p in r['paiements']],[5,3])
  self.assertTrue(self.sql('SELECT public.sovarka_goulag_refuge_terminer(8)')['deja_termine'])
  self.admin();self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_detenu'"),1)
  self.assertEqual(self.sql("SELECT inventory FROM public.personnages_donnees WHERE name='__goulag_detenu'"),[])
 def test_arrestation_jet_unique_et_peine_reprise(self):
  self.activation_fixture();self.fugitif();self.graine(True)
  self.client();self.q.execute("SELECT set_config('request.path','/rpc/fixture_entree',true)")
  # L'UPDATE de fixture simule le mouvement effectif ; le vrai déclencheur fait le jet.
  self.admin();self.q.execute("UPDATE public.personnages_donnees SET current_building='hotel-mineur',current_room='hall_mineur',current_street=NULL WHERE name='__goulag_detenu'")
  self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_entrees'),1)
  self.assertTrue(self.sql('SELECT arrete FROM public.sovarka_goulag_entrees'))
  self.assertEqual(self.sql("SELECT current_city FROM public.personnages_donnees WHERE name='__goulag_detenu'"),'qhs')
  self.assertAlmostEqual(float(self.sql("SELECT (est_emprisonne->>'jours')::numeric FROM public.personnages_donnees WHERE name='__goulag_detenu'")),3600/86400,places=8)
 def test_arrestation_aucun_jet_sur_piece_ou_visiteur(self):
  self.activation_fixture();self.fugitif();self.graine(False)
  self.q.execute("UPDATE public.personnages_donnees SET current_building='hotel-mineur',current_room='hall_mineur',current_street=NULL WHERE name='__goulag_detenu'")
  self.q.execute("UPDATE public.personnages_donnees SET current_room='chambre_mineur' WHERE name='__goulag_detenu'")
  self.q.execute("UPDATE public.personnages_donnees SET current_room='chambre_mineur' WHERE name='__goulag_detenu'")
  self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_entrees'),1)
  self.assertFalse(self.sql('SELECT arrete FROM public.sovarka_goulag_entrees'))
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_a',current_building='hotel-mineur',current_room='hall_mineur' WHERE name='__goulag_visiteur'")
  self.assertEqual(self.sql('SELECT count(*) FROM public.sovarka_goulag_entrees'),1)
 def test_rpc_gratuite_refusee_en_toundra(self):
  self.activation_fixture();self.traverser();self.client()
  for champ in ['pa','inventaire','position']:
   self.q.execute('SAVEPOINT contournement')
   with self.assertRaises(psycopg2.errors.InsufficientPrivilege) as refus:self.sql('SELECT public.fixture_gratuit(%s)',(champ,))
   self.assertIn('traversee_irreversible',str(refus.exception));self.q.execute('ROLLBACK TO contournement')
  self.admin();self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_detenu'"),20)
  self.client(3);self.q.execute('SAVEPOINT cadeau')
  with self.assertRaises(psycopg2.errors.InsufficientPrivilege) as refus:self.sql("SELECT public.fixture_cadeau('__goulag_detenu')")
  self.assertIn('traversee_irreversible',str(refus.exception));self.q.execute('ROLLBACK TO cadeau')
 def test_rpc_gratuite_refusee_au_refuge(self):
  self.activation_fixture()
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_a',current_building='maison-starovka',current_room='piece_maison',pa=1 WHERE name='__goulag_detenu'")
  self.q.execute("INSERT INTO public.sovarka_goulag_refuges(nom,destination,statut,arrivee_le) VALUES('__goulag_detenu','starovka','detenu',public.sovarka_jour_paris())")
  self.client()
  for champ in ['pa','inventaire','position']:
   self.q.execute('SAVEPOINT repos')
   with self.assertRaises(psycopg2.errors.InsufficientPrivilege) as refus:self.sql('SELECT public.fixture_gratuit(%s)',(champ,))
   self.assertIn('repos_force_goulag',str(refus.exception));self.q.execute('ROLLBACK TO repos')
  self.admin();self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_detenu'"),1)
 def test_compte_anonyme_sans_personnage(self):
  self.activation_fixture();self.client()
  self.sql("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':'00000000-0000-4000-8000-000000000001','role':'authenticated','is_anonymous':True}),))
  self.assertIsNone(self.sql('SELECT public.mon_personnage()'))
  self.assertFalse(self.sql("SELECT public.est_mon_personnage('__goulag_detenu')"))
  for sql in ["SELECT public.goulag_toundra_demarrer('starovka')","SELECT public.goulag_toundra_agir('dormir')","SELECT public.sovarka_goulag_visite_demander()","SELECT public.sovarka_goulag_voyager('bus')"]:
   r=self.sql(sql);self.assertFalse(r['ok']);self.assertEqual(r['raison'],'non_authentifie')
 def ministre_fixture(self):
  self.q.execute("UPDATE public.personnages_donnees SET poste='{\"id\":\"min_just\"}',current_city='capitale',current_building='palais-gouvernement',current_room='bureau_min_just' WHERE name='__goulag_detenu'")
  self.q.execute("INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fixture-min-autor','soviet','min_just','capitale','__goulag_detenu','fixture')")
 def test_autorisation_permanente_reutilisable_revocable(self):
  self.activation_fixture();self.ministre_fixture()
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_b',current_building='centre-multinodal-montrouge',current_room='hall_gare_montrouge',liquide=300,pa=30 WHERE name='__goulag_visiteur'")
  self.client(2);demande=self.sql('SELECT public.sovarka_goulag_visite_demander()')['demande_id']
  self.client(1);self.assertTrue(self.sql('SELECT public.sovarka_goulag_visite_decider(%s,%s)',(demande,'accorder'))['ok'])
  self.client(2)
  for destination in ['capitale','ville_a','ville_b']:
   self.assertTrue(self.sql("SELECT public.sovarka_goulag_voyager('train')")['ok'])
   r=self.sql('SELECT public.sovarka_goulag_visiteur_repartir(%s,%s)',('train',destination));self.assertTrue(r['ok'],r);self.assertEqual(r['ville'],destination)
  self.client(1);self.assertTrue(self.sql('SELECT public.sovarka_goulag_visite_decider(%s,%s)',(demande,'revoquer'))['ok'])
  self.assertTrue(self.sql('SELECT public.sovarka_goulag_visite_decider(%s,%s)',(demande,'revoquer'))['deja_revoquee'])
  self.client(2);r=self.sql("SELECT public.sovarka_goulag_voyager('train')");self.assertFalse(r['ok']);self.assertEqual(r['raison'],'autorisation_goulag_requise')
  self.admin();self.assertEqual(self.sql("SELECT liquide FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),120)
  self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),18)
 def test_revocation_ne_bloque_pas_sortie_visiteur_present(self):
  self.activation_fixture();self.ministre_fixture()
  demande=self.sql("INSERT INTO public.sovarka_goulag_autorisations(nom,etat,ministre) VALUES('__goulag_visiteur','accordee','__goulag_detenu') RETURNING id")
  self.q.execute("INSERT INTO public.sovarka_goulag_visites(nom,origine,autorisation) VALUES('__goulag_visiteur','ville_b',%s)",(demande,))
  self.q.execute("UPDATE public.personnages_donnees SET liquide=100 WHERE name='__goulag_visiteur'")
  self.client(1);self.assertTrue(self.sql('SELECT public.sovarka_goulag_visite_decider(%s,%s)',(demande,'revoquer'))['ok'])
  self.client(2);self.assertTrue(self.sql("SELECT public.sovarka_goulag_visiteur_repartir('bus','capitale')")['ok'])
 def test_ministre_etranger_refuse(self):
  self.activation_fixture()
  demande=self.sql("INSERT INTO public.sovarka_goulag_autorisations(nom) VALUES('__goulag_visiteur') RETURNING id")
  self.q.execute("UPDATE public.personnages_donnees SET poste='{\"id\":\"min_just\"}' WHERE name='__goulag_republic'")
  self.q.execute("INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fixture-min-republic','republic','min_just','capitale','__goulag_republic','fixture')")
  self.client(3);r=self.sql('SELECT public.sovarka_goulag_visite_decider(%s,%s)',(demande,'accorder'));self.assertFalse(r['ok']);self.assertEqual(r['raison'],'reserve_ministre_justice_sovarka')
 def test_refuge_reconnexion_partielle_et_devis_perime(self):
  self.activation_fixture()
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_a',current_building='maison-starovka',current_room='piece_maison',inventory='[{\"stackKey\":\"bois\",\"stackable\":true,\"qty\":8}]' WHERE name='__goulag_detenu'")
  self.q.execute("INSERT INTO public.sovarka_goulag_refuges(nom,destination,statut,arrivee_le) VALUES('__goulag_detenu','starovka','detenu',public.sovarka_jour_paris()-10)")
  self.client();r=self.sql('SELECT public.sovarka_goulag_refuge_lire()');self.assertEqual(r['bois_prochain'],8)
  r=self.sql('SELECT public.sovarka_goulag_refuge_nuit(5)');self.assertFalse(r['ok']);self.assertEqual(r['raison'],'bois_a_confirmer')
  self.assertTrue(self.sql('SELECT public.sovarka_goulag_refuge_nuit(8)')['ok'])
  self.assertTrue(self.sql('SELECT public.sovarka_goulag_refuge_terminer(0)')['ok'])
 def test_navigation_publique_reflete_arrestation(self):
  self.activation_fixture();self.fugitif()
  self.q.execute("UPDATE public.personnages_donnees SET current_street='starovka-rue-hotel' WHERE name='__goulag_detenu'")
  self.graine(True);self.client();r=self.sql("SELECT public.navigation_interieure('hotel-mineur','hall_mineur')")
  self.assertTrue(r['ok'],r);self.assertTrue(r['goulag_arrestation']['ok'])
  self.admin();self.assertEqual(self.sql("SELECT current_city FROM public.personnages_donnees WHERE name='__goulag_detenu'"),'qhs')
 def test_migrations_rejouables(self):
  for p in self.migrations:self.q.execute(p.read_text())
  self.assertFalse(self.sql('SELECT active FROM public.sovarka_goulag_configuration'))
  self.assertEqual(self.sql("SELECT camp_bucherons_noeud FROM public.sovarka_goulag_configuration"),'krasnov-camp-bucherons')
 def test_geographie_bidirectionnelle(self):
  self.assertTrue(self.sql("SELECT 'krasnov-camp-bucherons'=ANY(voisins) FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-ecole-foret'"))
  self.assertTrue(self.sql("SELECT 'krasnov-rue-ecole-foret'=ANY(voisins) FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-camp-bucherons'"))
 def test_permissions_et_rls(self):
  for role in ['anon','authenticated','service_role']:
   self.assertFalse(self.sql("SELECT has_function_privilege(%s,'public.sovarka_goulag_confisquer_interne(text,text)','EXECUTE')",(role,)))
  for table in ['traversees','depots','autorisations','refuges','configuration','visites','entrees']:
   self.assertTrue(self.sql('SELECT relrowsecurity FROM pg_class WHERE oid=%s::regclass',('public.sovarka_goulag_'+table,)))
   for role in ['authenticated','anon','service_role']:
    self.assertFalse(self.sql('SELECT has_table_privilege(%s,%s,\'SELECT\')',(role,'public.sovarka_goulag_'+table)))
 def test_inventaire_confiscation_restitution_et_perte(self):
  inv=[{'type':'cle_serrure','id':'unique-cle'},{'type':'cle_vierge','id':'vierge'}, {'type':'serrure_cle','id':'pas-cle'},{'id':'unique-objet'},{'stackKey':'pain','stackable':True,'qty':4}]
  self.q.execute("UPDATE public.personnages_donnees SET inventory=%s WHERE name='__goulag_detenu'",(Json(inv),))
  self.q.execute("INSERT INTO public.detentions(id,nom,country,city,qhs,jour_debut,jour_fin) VALUES('fixture-depot','__goulag_detenu','soviet','capitale',true,1,100)")
  r=self.sql("SELECT public.sovarka_goulag_confisquer_interne('__goulag_detenu','fixture-depot')");self.assertTrue(r['ok']);self.assertEqual(r['confisques'],3)
  self.assertEqual(self.sql("SELECT inventory FROM public.personnages_donnees WHERE name='__goulag_detenu'"),inv[:2])
  self.assertTrue(self.sql("SELECT public.sovarka_goulag_confisquer_interne('__goulag_detenu','fixture-depot')")['ok'])
  self.assertTrue(self.sql("SELECT public.sovarka_goulag_depot_clore_interne('__goulag_detenu','fixture-depot','liberation')")['ok'])
  self.assertTrue(self.sql("SELECT public.sovarka_goulag_depot_clore_interne('__goulag_detenu','fixture-depot','liberation')")['ok'])
  self.assertEqual(self.sql("SELECT inventory FROM public.personnages_donnees WHERE name='__goulag_detenu'"),inv)
  self.assertFalse(self.sql("SELECT public.sovarka_goulag_depot_clore_interne('__goulag_detenu','fixture-depot','evasion')")['ok'])
 def test_departs_visiteur_seuils_et_absence_de_sanction(self):
  self.activation_fixture()
  self.q.execute("INSERT INTO public.sovarka_goulag_visites(nom,origine) VALUES('__goulag_visiteur','ville_b')")
  for destination,pa,ok in [('starovka',6,False),('krasnov',9,False),('krasnov',10,True)]:
   self.q.execute("UPDATE public.personnages_donnees SET pa=%s WHERE name='__goulag_visiteur'",(pa,));self.client(2)
   r=self.sql('SELECT public.goulag_toundra_demarrer(%s)',(destination,));self.assertEqual(r['ok'],ok)
   if ok:self.assertEqual(r['pa'],10);self.assertEqual(r['statut'],'visiteur');self.assertIsNone(r['peine_gelee_secondes'])
   else:self.assertEqual(r['raison'],'pa_insuffisants_depart')
   self.admin()
  self.assertFalse(self.sql("SELECT EXISTS(SELECT 1 FROM public.sovarka_goulag_depots)"))
  self.assertEqual(self.sql("SELECT coalesce(recherche,'[]'::jsonb) FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),[])
 def test_evasion_reliquat_et_perte_depot(self):
  self.activation_fixture()
  self.q.execute("UPDATE public.personnages_donnees SET est_emprisonne=jsonb_build_object('debutTs',extract(epoch from statement_timestamp())*1000,'jours',0.125,'qhs',true),inventory='[{\"id\":\"depot-unique\"}]' WHERE name='__goulag_detenu'")
  self.q.execute("INSERT INTO public.detentions(id,nom,country,city,qhs,jour_debut,jour_fin) VALUES('fixture-fuite','__goulag_detenu','soviet','capitale',true,1,100)")
  self.assertTrue(self.sql("SELECT public.sovarka_goulag_confisquer_interne('__goulag_detenu','fixture-fuite')")['ok'])
  self.client();r=self.sql("SELECT public.goulag_toundra_demarrer('starovka')");self.assertTrue(r['ok']);self.assertGreater(r['peine_gelee_secondes'],0);self.assertLessEqual(r['peine_gelee_secondes'],10801);self.assertEqual(r['pa'],20)
  self.admin();self.assertEqual(self.sql("SELECT etat FROM public.sovarka_goulag_depots WHERE detention_id='fixture-fuite'"),'perdu')
  self.assertIsNone(self.sql("SELECT est_emprisonne FROM public.personnages_donnees WHERE name='__goulag_detenu'"))
  self.assertFalse(self.sql("SELECT public.sovarka_goulag_depot_clore_interne('__goulag_detenu','fixture-fuite','liberation')")['ok'])
  self.assertEqual(self.sql("SELECT jsonb_array_length(recherche) FROM public.personnages_donnees WHERE name='__goulag_detenu'"),1)
  reste=r['peine_gelee_secondes']
  self.q.execute("UPDATE public.sovarka_goulag_traversees SET en_cours=false,debut_le=debut_le-10 WHERE nom='__goulag_detenu'")
  r=self.sql("SELECT public.detention_ouvrir_interne('__goulag_detenu','fixture-reprise',2,'capitale','soviet','[]','fixture-juge','fixture')");self.assertTrue(r['ok'],r)
  duree=self.sql("SELECT (est_emprisonne->>'jours')::numeric FROM public.personnages_donnees WHERE name='__goulag_detenu'")
  self.assertAlmostEqual(float(duree),2+reste/86400,places=6)
  self.assertIsNotNone(self.sql("SELECT peine_reprise_le FROM public.sovarka_goulag_traversees WHERE nom='__goulag_detenu'"))

 def test_jugement_atomique_et_double_clic(self):
  self.activation_fixture()
  self.q.execute("UPDATE public.personnages_donnees SET poste='{\"id\":\"juge\",\"city\":\"capitale\"}',current_city='capitale',current_building='tribunal',current_room='bureau_juge' WHERE name='__goulag_detenu'")
  self.q.execute("INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fixture-juge','soviet','juge','capitale','__goulag_detenu','fixture')")
  self.q.execute("INSERT INTO public.plaintes_en_cours(id,country,city,data) VALUES('fixture-jugement','soviet','capitale','{\"status\":\"saisie\",\"audience_ouverte_le\":\"fixture\",\"cible\":\"__goulag_visiteur\"}')")
  self.client();r=self.sql("SELECT public.sovarka_goulag_juger('fixture-jugement','vol',30)");self.assertTrue(r['ok'],r);self.assertEqual(r['jours'],30)
  r=self.sql("SELECT public.sovarka_goulag_juger('fixture-jugement','vol',30)");self.assertFalse(r['ok']);self.admin()
  self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_detenu'"),18)
  self.assertEqual(self.sql("SELECT current_city FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),'qhs')
  self.assertEqual(self.sql("SELECT count(*) FROM public.sovarka_goulag_depots WHERE nom='__goulag_visiteur'"),1)
 def test_transport_habilite_tarif_national(self):
  self.activation_fixture()
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_b',current_building='centre-multinodal-montrouge',current_room='hall_gare_montrouge',liquide=100 WHERE name='__goulag_visiteur'")
  self.q.execute("INSERT INTO public.sovarka_goulag_autorisations(nom,etat,ministre) VALUES('__goulag_visiteur','accordee','fixture-ministre')")
  self.client(2);r=self.sql("SELECT public.sovarka_goulag_voyager('train')");self.assertTrue(r['ok'],r);self.admin()
  self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),18)
  self.assertEqual(self.sql("SELECT liquide FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),70)
  self.assertEqual(self.sql("SELECT etat FROM public.sovarka_goulag_autorisations WHERE nom='__goulag_visiteur'"),'accordee')
  self.client(2);r=self.sql("SELECT public.sovarka_goulag_visiteur_repartir('train','ville_b')");self.assertTrue(r['ok'],r);self.admin()
  self.assertEqual(self.sql("SELECT liquide FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),40)
  self.assertEqual(self.sql("SELECT current_city FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),'ville_b')

 def test_transport_sans_habilitation_refuse(self):
  self.activation_fixture()
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_b',current_building='centre-multinodal-montrouge',current_room='hall_gare_montrouge' WHERE name='__goulag_visiteur'")
  self.client(2);r=self.sql("SELECT public.sovarka_goulag_voyager('train')");self.assertFalse(r['ok']);self.assertEqual(r['raison'],'autorisation_goulag_requise');self.admin()
  self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),20)
 def test_ministre_ne_condamne_pas(self):
  self.activation_fixture()
  self.q.execute("INSERT INTO public.plaintes_en_cours(id,country,city,data) VALUES('fixture-affaire','soviet','capitale','{\"status\":\"saisie\",\"cible\":\"__goulag_visiteur\"}')")
  self.q.execute("UPDATE public.personnages_donnees SET poste='{\"id\":\"min_just\"}' WHERE name='__goulag_detenu'")
  self.q.execute("INSERT INTO public.postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fixture-ministre','soviet','min_just','capitale','__goulag_detenu','fixture')")
  self.client();r=self.sql("SELECT public.sovarka_goulag_juger('fixture-affaire','absent',3)");self.assertFalse(r['ok']);self.assertEqual(r['raison'],'reserve_juge_sovarka')
  self.admin();self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_detenu'"),20)
 def test_pas_de_bonus_civil_en_toundra(self):
  self.traverser();self.client()
  r=self.sql("SELECT public.pa_repos_nocturne('__goulag_detenu')")
  self.assertFalse(r['ok']);self.assertEqual(r['raison'],'sommeil_toundra_explicit');self.assertEqual(r['pa'],20)
 def test_survie_plancher_et_repetition(self):
  self.activation_fixture();self.traverser();self.q.execute("UPDATE public.personnages_donnees SET pa=7 WHERE name='__goulag_detenu'");self.client()
  self.assertEqual(self.sql("SELECT public.goulag_toundra_agir('progresser')")['pa'],2)
  self.assertEqual(self.sql("SELECT public.goulag_toundra_agir('progresser')")['raison'],'progression_deja_faite')
  self.assertEqual(self.sql("SELECT public.goulag_toundra_agir('dormir')")['pa'],5)
  self.assertEqual(self.sql("SELECT public.goulag_toundra_agir('dormir')")['raison'],'sommeil_deja_fait')
  self.admin();self.q.execute("UPDATE public.sovarka_goulag_traversees SET jour_progression=NULL")
  self.client();self.assertEqual(self.sql("SELECT public.goulag_toundra_agir('progresser')")['raison'],'pa_insuffisants')
 def test_deux_arrivees_bois_et_refuge(self):
  self.activation_fixture()
  for i,dest,total in [(1,'starovka',7),(2,'krasnov',10)]:
   nom=['__goulag_detenu','__goulag_visiteur'][i-1];self.traverser(nom,dest,'detenu' if i==1 else 'visiteur',total-2);self.client(i)
   r=self.sql("SELECT public.goulag_toundra_agir('progresser')");self.assertEqual(r['bois_gagne'],5)
   self.admin();self.q.execute('UPDATE public.sovarka_goulag_traversees SET jour_progression=NULL WHERE nom=%s',(nom,));self.client(i)
   r=self.sql("SELECT public.goulag_toundra_agir('progresser')");self.assertEqual(r['pa'],1);self.assertEqual(r['bois_gagne'],3);self.assertTrue(r['termine'])
   self.assertEqual(r['rue'],'starovka-rue-stade' if i==1 else 'krasnov-camp-bucherons')
   self.assertEqual(self.sql("SELECT public.sovarka_goulag_refuge_rejoindre()")['ok'],True)
   self.assertEqual(self.sql("SELECT public.sovarka_goulag_refuge_nuit(8)")['bois_preleves'],5)
   self.assertEqual(self.sql("SELECT public.sovarka_goulag_refuge_nuit(8)")['raison'],'nuit_deja_prise')
   self.admin();self.q.execute('UPDATE public.sovarka_goulag_refuges SET derniere_nuit=NULL WHERE nom=%s',(nom,));self.client(i)
   self.assertEqual(self.sql("SELECT public.sovarka_goulag_refuge_nuit(8)")['bois_preleves'],3)
   self.assertEqual(self.sql("SELECT public.sovarka_goulag_refuge_nuit(8)")['raison'],'nuit_deja_prise')
   self.admin();self.assertEqual(self.sql("SELECT inventory FROM public.personnages_donnees WHERE name=%s",(nom,)),[])
 def test_parcours_complets_sept_et_dix_jours(self):
  self.activation_fixture()
  for destination,total,ville,rue,i,nom in [('starovka',7,'ville_a','starovka-rue-stade',1,'__goulag_detenu'),('krasnov',10,'ville_b','krasnov-camp-bucherons',2,'__goulag_visiteur')]:
   self.traverser(nom,destination)
   for jour in range(total):
    self.client(i)
    self.assertTrue(self.sql("SELECT public.goulag_toundra_agir('abri')")['ok'])
    self.assertTrue(self.sql("SELECT public.goulag_toundra_agir('dormir')")['ok'])
    r=self.sql("SELECT public.goulag_toundra_agir('progresser')");self.assertTrue(r['ok'],r)
    self.assertEqual(r['progressions'],jour+1)
    if jour<total-1:
     self.assertEqual(self.sql("SELECT public.goulag_toundra_agir('progresser')")['raison'],'progression_deja_faite')
    self.admin()
    self.q.execute("UPDATE public.sovarka_goulag_traversees SET debut_le=debut_le-1,jour_abri=jour_abri-1,jour_sommeil=jour_sommeil-1,jour_progression=jour_progression-1 WHERE nom=%s",(nom,))
   self.assertEqual(self.sql("SELECT current_city FROM public.personnages_donnees WHERE name=%s",(nom,)),ville)
   self.assertEqual(self.sql("SELECT current_street FROM public.personnages_donnees WHERE name=%s",(nom,)),rue)
   self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name=%s",(nom,)),1)
 def test_second_refuge_reinitialise(self):
  self.q.execute("UPDATE public.personnages_donnees SET pa=1,current_city='ville_a' WHERE name='__goulag_detenu'")
  self.assertTrue(self.sql("SELECT public.sovarka_goulag_refuge_creer_interne('__goulag_detenu','starovka','detenu')")['ok'])
  self.q.execute("UPDATE public.sovarka_goulag_refuges SET termine=true,nuits=2,bois_paye=8")
  self.assertTrue(self.sql("SELECT public.sovarka_goulag_refuge_creer_interne('__goulag_detenu','starovka','detenu')")['ok'])
  self.assertEqual(self.sql("SELECT nuits FROM public.sovarka_goulag_refuges"),0)
 def test_rep_reste_inchangee(self):
  self.activation_fixture();self.client(3)
  self.assertEqual(self.sql("SELECT public.goulag_toundra_demarrer('starovka')")['raison'],'pas_entree_goulag')
  self.assertEqual(self.sql("SELECT public.goulag_toundra_agir('dormir')")['raison'],'hors_goulag')
  self.admin();self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_republic'"),20)
 def test_zz_concurrence_progression(self):
  self.activation_fixture();self.traverser();self.c.commit()
  def appel(_):
   with psycopg2.connect(self.s.get_uri()) as c:
    q=c.cursor();q.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':'00000000-0000-4000-8000-000000000001','role':'authenticated'}),));q.execute('SET LOCAL ROLE authenticated')
    q.execute("SELECT set_config('request.path','/rpc/goulag_toundra_agir',true)")
    q.execute("SELECT public.goulag_toundra_agir('progresser')");return q.fetchone()[0]
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:res=list(e.map(appel,range(2)))
  self.assertEqual(sum(r['ok'] for r in res),1);self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_detenu'"),15)
  # Deux paiements concurrents : une seule nuit, exactement 5 puis 3 bois.
  self.q.execute("UPDATE public.sovarka_goulag_traversees SET en_cours=false")
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_a',current_building='maison-starovka',current_room='piece_maison',inventory='[{\"stackKey\":\"bois\",\"stackable\":true,\"qty\":8}]' WHERE name='__goulag_detenu'")
  self.q.execute("INSERT INTO public.sovarka_goulag_refuges(nom,destination,statut,arrivee_le) VALUES('__goulag_detenu','starovka','detenu',public.sovarka_jour_paris())");self.c.commit()
  def nuit(_):
   with psycopg2.connect(self.s.get_uri()) as c:
    q=c.cursor();q.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':'00000000-0000-4000-8000-000000000001','role':'authenticated'}),));q.execute("SELECT set_config('request.path','/rpc/sovarka_goulag_refuge_nuit',true)");q.execute('SET LOCAL ROLE authenticated')
    q.execute('SELECT public.sovarka_goulag_refuge_nuit(8)');return q.fetchone()[0]
  for montant in [5,3]:
   with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:res=list(e.map(nuit,range(2)))
   self.assertEqual(sum(r['ok'] for r in res),1)
   self.assertEqual(next(r['bois_preleves'] for r in res if r['ok']),montant)
   if montant==5:
    self.q.execute("UPDATE public.sovarka_goulag_refuges SET arrivee_le=arrivee_le-1,derniere_nuit=derniere_nuit-1");self.c.commit()
  self.assertEqual(self.sql("SELECT bois_paye FROM public.sovarka_goulag_refuges WHERE nom='__goulag_detenu'"),8)
  self.assertEqual(self.sql("SELECT inventory FROM public.personnages_donnees WHERE name='__goulag_detenu'"),[])
  # Deux requêtes de navigation concurrentes : une seule entrée et un seul jet.
  self.q.execute("UPDATE public.sovarka_goulag_refuges SET termine=true")
  self.q.execute("INSERT INTO public.detentions(id,nom,country,city,qhs,jour_debut,jour_fin,mode_fin,jour_fin_effective) VALUES('origine-concurrence','__goulag_detenu','soviet','ville_a',true,1,11,'evasion',1)")
  self.q.execute("UPDATE public.sovarka_goulag_traversees SET en_cours=false,statut='detenu',detention_id='origine-concurrence',peine_gelee_secondes=3600,peine_reprise_le=NULL WHERE nom='__goulag_detenu'")
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_a',current_street='starovka-rue-hotel',current_building=NULL,current_room=NULL WHERE name='__goulag_detenu'")
  graine=self.graine(False);self.c.commit()
  def entrer(_):
   with psycopg2.connect(self.s.get_uri()) as c:
    q=c.cursor();q.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':'00000000-0000-4000-8000-000000000001','role':'authenticated'}),));q.execute("SELECT set_config('request.path','/rpc/navigation_interieure',true)");q.execute('SET LOCAL ROLE authenticated')
    q.execute('SELECT setseed(%s)',(graine,));q.execute("SELECT public.navigation_interieure('hotel-mineur','hall_mineur')");return q.fetchone()[0]
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:res=list(e.map(entrer,range(2)))
  self.assertTrue(all(r['ok'] for r in res),res)
  self.assertEqual(self.sql("SELECT count(*) FROM public.sovarka_goulag_entrees WHERE nom='__goulag_detenu'"),1)
  # Voyage et révocation simultanés : un ordre transactionnel, aucun droit consommé.
  self.ministre_fixture()
  self.q.execute("UPDATE public.personnages_donnees SET current_city='ville_b',current_building='centre-multinodal-montrouge',current_room='hall_gare_montrouge',liquide=100 WHERE name='__goulag_visiteur'")
  demande=self.sql("INSERT INTO public.sovarka_goulag_autorisations(nom,etat,ministre) VALUES('__goulag_visiteur','accordee','__goulag_detenu') RETURNING id");self.c.commit()
  def decider_ou_voyager(index):
   with psycopg2.connect(self.s.get_uri()) as c:
    q=c.cursor();q.execute("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':f'00000000-0000-4000-8000-{index+1:012}','role':'authenticated'}),));q.execute('SET LOCAL ROLE authenticated')
    fonction='sovarka_goulag_visite_decider' if index==0 else 'sovarka_goulag_voyager'
    q.execute("SELECT set_config('request.path',%s,true)",('/rpc/'+fonction,))
    if index==0:q.execute("SELECT public.sovarka_goulag_visite_decider(%s,'revoquer')",(demande,))
    else:q.execute("SELECT public.sovarka_goulag_voyager('train')")
    return q.fetchone()[0]
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:res=list(e.map(decider_ou_voyager,range(2)))
  self.assertTrue(res[0]['ok'],res)
  self.assertEqual(self.sql("SELECT etat FROM public.sovarka_goulag_autorisations WHERE id=%s",(demande,)),'revoquee')
  self.assertEqual(self.sql("SELECT liquide FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),70 if res[1]['ok'] else 100)
  self.assertEqual(self.sql("SELECT pa FROM public.personnages_donnees WHERE name='__goulag_visiteur'"),18 if res[1]['ok'] else 20)
  if res[1]['ok']:
   self.client(2);self.assertTrue(self.sql("SELECT public.sovarka_goulag_visiteur_repartir('train','ville_b')")['ok']);self.admin()
  self.client(2);self.assertEqual(self.sql("SELECT public.sovarka_goulag_voyager('train')")['raison'],'autorisation_goulag_requise')


if __name__=='__main__':unittest.main(argv=[sys.argv[0]],verbosity=2)
