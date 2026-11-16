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
  for f in json.loads((F/'fonctions-vivantes.json').read_text()):q.execute(f['definition'])
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
  cls.c.commit()
 @classmethod
 def tearDownClass(cls):
  cls.c.close();cls.s.cleanup();cls.tmp.cleanup()
 def setUp(self):self.q=self.c.cursor()
 def tearDown(self):self.c.rollback();self.q.close()
 def sql(self,sql,args=None):self.q.execute(sql,args);return self.q.fetchone()[0] if self.q.description else None
 def client(self,i=1):
  self.sql("SELECT set_config('request.jwt.claims',%s,true)",(json.dumps({'sub':f'00000000-0000-4000-8000-{i:012}','role':'authenticated'}),))
  self.sql("SELECT set_config('request.path','/rpc/goulag_toundra_agir',true)")
  self.q.execute('SET LOCAL ROLE authenticated')
 def admin(self):self.q.execute('RESET ROLE')
 def activation_fixture(self):
  self.q.execute('ALTER TABLE public.sovarka_goulag_configuration DROP CONSTRAINT sovarka_goulag_activation_figee')
  # Simulation uniquement : aucune arrestation ni validité n'est ici arbitrée.
  self.q.execute("UPDATE public.sovarka_goulag_configuration SET active=true,champignons_malus=1,formule_arrestation='FIXTURE_NON_OPERATIONNELLE',autorisation_usage='unique',retour_visiteur='meme_ville'")
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
  for table in ['traversees','depots','autorisations','refuges','configuration','visites']:
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
  self.assertEqual(self.sql("SELECT etat FROM public.sovarka_goulag_autorisations WHERE nom='__goulag_visiteur'"),'utilisee')
  self.client(2);r=self.sql("SELECT public.sovarka_goulag_visiteur_repartir('train',NULL)");self.assertTrue(r['ok'],r);self.admin()
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
   self.assertEqual(self.sql("SELECT public.sovarka_goulag_refuge_nuit()")['bois_preleves'],5)
   self.assertEqual(self.sql("SELECT public.sovarka_goulag_refuge_nuit()")['raison'],'nuit_deja_prise')
   self.admin();self.q.execute('UPDATE public.sovarka_goulag_refuges SET derniere_nuit=NULL WHERE nom=%s',(nom,));self.client(i)
   self.assertEqual(self.sql("SELECT public.sovarka_goulag_refuge_nuit()")['bois_preleves'],3)
   self.assertEqual(self.sql("SELECT public.sovarka_goulag_refuge_nuit()")['raison'],'nuit_deja_prise')
   self.admin();self.assertEqual(self.sql("SELECT inventory FROM public.personnages_donnees WHERE name=%s",(nom,)),[])
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
    q.execute('SELECT public.sovarka_goulag_refuge_nuit()');return q.fetchone()[0]
  for montant in [5,3]:
   with concurrent.futures.ThreadPoolExecutor(max_workers=2) as e:res=list(e.map(nuit,range(2)))
   self.assertEqual(sum(r['ok'] for r in res),1)
   self.assertEqual(next(r['bois_preleves'] for r in res if r['ok']),montant)
   if montant==5:
    self.q.execute("UPDATE public.sovarka_goulag_refuges SET arrivee_le=arrivee_le-1,derniere_nuit=derniere_nuit-1");self.c.commit()
  self.assertEqual(self.sql("SELECT bois_paye FROM public.sovarka_goulag_refuges WHERE nom='__goulag_detenu'"),8)
  self.assertEqual(self.sql("SELECT inventory FROM public.personnages_donnees WHERE name='__goulag_detenu'"),[])


if __name__=='__main__':unittest.main(argv=[sys.argv[0]],verbosity=2)
