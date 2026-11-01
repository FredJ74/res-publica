#!/usr/bin/env python3
"""Chargeur strict + véritable extraction/rendu de séquences sur PostgreSQL jetable."""
import importlib.util,json,subprocess,sys,tempfile,unittest,os
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(R/'outils/baseline'))
import rendre,requetes,seeds

class Exports(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.rep=Path(self.tmp.name)
  self.valeurs={k:{x:[] for x in v} for k,v in rendre.EXPORTS_ATTENDUS.items()}
 def ecrire(self,mode='json'):
  for cle,v in self.valeurs.items():
   row={cle:v}
   if mode=='mcp':row={'result':'<untrusted-data-0000-1111>\n'+json.dumps([row])+'\n</untrusted-data-0000-1111>'}
   (self.rep/(cle+('.txt' if mode=='mcp' else '.json'))).write_text(json.dumps(row))
 def test_livraison95_refuse_les_references_manquantes(self):
  script=R/'outils/bancs/banc-livraison95-catalogue-local.py'
  args=[sys.executable,str(script),'--exports',str(self.rep),'--registre',str(self.rep/'registre.json'),'--capture-couts',str(self.rep/'couts.json'),'--postgres-bin',str(self.rep),'--rapport',str(self.rep/'rapport.json')]
  p=subprocess.run(args,text=True,capture_output=True,check=False)
  self.assertNotEqual(p.returncode,0)
  self.assertIn('--empreinte-reference',p.stderr)
  self.assertIn('--referentiels-reference',p.stderr)
  self.assertFalse((self.rep/'rapport.json').exists())
 def test_livraison95_refuse_http_non_authentifie(self):
  script=R/'outils/bancs/banc-livraison95-catalogue-local.py'
  args=[sys.executable,str(script),'--exports',str(self.rep),'--registre',str(self.rep/'registre.json'),'--capture-couts',str(self.rep/'couts.json'),'--postgres-bin',str(self.rep),'--rapport',str(self.rep/'rapport.json'),'--empreinte-reference',str(self.rep/'racines.json'),'--referentiels-reference',str(self.rep/'referentiels.json')]
  p=subprocess.run(args,text=True,capture_output=True,check=False)
  self.assertNotEqual(p.returncode,0)
  self.assertIn('GoTrue et PostgREST obligatoires',p.stderr)
  self.assertFalse((self.rep/'rapport.json').exists())

 def test_capture_privee_dans_le_depot_refusee_avant_lecture(self):
  sp=importlib.util.spec_from_file_location('prive219',R/'outils/bancs/referentiels-prives-clone-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  with self.assertRaisesRegex(ValueError,'interdite dans le dépôt'):m.lire_capture(R/'fichier-prive-inexistant.json',{})
 def test_locale_icu_incomplete_refusee_avant_reconstruction(self):
  p=subprocess.run([sys.executable,str(R/'outils/bancs/banc-livraison95-catalogue-local.py'),'--exports','/fixture','--registre','/fixture','--capture-couts','/fixture','--postgres-bin','/fixture','--rapport','/fixture','--empreinte-reference','/fixture','--referentiels-reference','/fixture','--locale-provider','icu'],text=True,capture_output=True)
  self.assertNotEqual(p.returncode,0);self.assertIn('ICU exige',p.stderr)
 def test_livraison95_exige_27_http_distincts(self):
  spec=importlib.util.spec_from_file_location('livraison95',R/'outils/bancs/banc-livraison95-catalogue-local.py')
  m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
  cas=[{'cas':f'http_{i}','ok':True} for i in range(27)]
  self.assertEqual(m.verifier_http_27({'cas':cas}),{'cas':27,'conformes':True})
  with self.assertRaises(AssertionError):m.verifier_http_27({'cas':cas[:-1]})
  with self.assertRaises(AssertionError):m.verifier_http_27({'cas':cas[:-1]+[cas[0]]})
  with self.assertRaises(AssertionError):m.verifier_http_27({'cas':cas[:-1]+[{'cas':'http_26','ok':False}]})

 def test_referentiel_refuse_un_seul_ecart(self):
  spec=importlib.util.spec_from_file_location('livraison95',R/'outils/bancs/banc-livraison95-catalogue-local.py')
  m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
  class Cursor:
   def execute(self,sql):self.nom=sql.split('FROM public.')[1].split()[0]
   def fetchone(self):return (0,'e3b0')
  q=Cursor()
  reference={'referentiels':{nom:{'lignes':0,'empreinte':'e3b0'} for nom in m.REFERENTIELS_1012}}
  self.assertTrue(m.verifier_referentiels(q,reference)['conformes'])
  reference['referentiels']['recettes_commerce']['lignes']=1
  with self.assertRaises(AssertionError):m.verifier_referentiels(q,reference)

 def test_empreinte_complete_refuse_un_seul_seau_different(self):
  spec=importlib.util.spec_from_file_location('livraison95',R/'outils/bancs/banc-livraison95-catalogue-local.py')
  m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
  identique={'version_serveur':'17.6','registre':{'lignes':1012,'derniere':'20261031211256'},
             'categories':{'fonctions':{'objets':1213,'racine':'a','seaux':{'0':'10:aaaa'}}}}
  self.assertTrue(m.verifier_empreinte_complete(identique,{'empreinte':identique})['conforme'])
  change=json.loads(json.dumps(identique));change['categories']['fonctions']['seaux']['0']='10:bbbb'
  with self.assertRaises(AssertionError):m.verifier_empreinte_complete(change,{'empreinte':identique})
  change=json.loads(json.dumps(identique));change['registre']['lignes']=1011
  with self.assertRaises(AssertionError):m.verifier_empreinte_complete(change,{'empreinte':identique})
 def test_lecteur_migration_ne_substitue_pas_une_entree_baseline(self):
  spec=importlib.util.spec_from_file_location('restaurant_fixture',R/'outils/bancs/banc-restaurant-luthecia-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
  n='commerce_vendre_produit';f=R/'historique/migrations-appliquees/rehorodatees-219/20261031113607_catalogue_et_offrir_a_boire.sql'
  self.assertEqual(m.definition(n,f),m._sources.fonction(str(f.relative_to(R)),n))
  self.assertNotEqual(m.definition(n,f),m._sources.entree_historique(n))
 def test_ecart_net_onze_ne_prouve_pas_onze_lignes_manquantes(self):
  spec=importlib.util.spec_from_file_location('couts',R/'outils/baseline/comparer-couts-captures.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
  a=[{'fn':'ancien','pa':1,'cost':2}];b=[{'fn':'ordre'+str(i),'pa':1,'cost':2} for i in range(12)]
  r=m.comparer(a,b);self.assertEqual(r['difference_nette'],11);self.assertEqual(len(r['capture_seulement']),12);self.assertEqual(len(r['source_seulement']),1);self.assertFalse(r['coherents'])
  self.assertTrue(m.comparer(b,list(reversed(b)))['coherents'])
  with self.assertRaises(ValueError):m.comparer(a,a+a)
  with self.assertRaises(ValueError):m.comparer(a,[{'fn':'x','pa':True,'cost':2}])
 def test_temoin_conserve_champs_sans_confondre_extension_ddl(self):
  sp=importlib.util.spec_from_file_location('integre95',R/'outils/bancs/banc-livraison95-catalogue-local.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  avant={'liquide':83,'pa':17,'inventory':[{'id':'unique','qty':1}]}
  self.assertEqual(m.verifier_temoin(avant,{**avant,'current_street_from':None})['colonnes_ajoutees_temoin'],['current_street_from'])
  for apres in [{**avant,'liquide':84},{**avant,'inventory':[]},{**avant,'current_street_from':'rue'},{**avant,'inconnu':None},{'liquide':83}]:
   with self.assertRaises(AssertionError):m.verifier_temoin(avant,apres)
 def test_rectification_payeur_n_elargit_pas_la_garde(self):
  d=json.loads((R/'outils/audits/PREVOL-1009-BLOCAGE-219-20261031.json').read_text())['rectification']
  self.assertNotEqual(d['source_md5'],d['definition_md5']);self.assertTrue(d['prevol_payeur_satisfait'])
  s=(R/'migrations/20261031115805_transport_encaissement_existant.sql').read_text()
  self.assertIn(d['source_md5'],s);self.assertNotIn(d['definition_md5'],s)
 def test_auth_locale_refuse_toute_base_distante(self):
  sp=importlib.util.spec_from_file_location('auth219',R/'outils/bancs/auth-locale-groupes-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  for uri in ['postgresql://p@production/db','postgresql://p@/db?host=production']:
   with self.assertRaisesRegex(ValueError,'local'):m.Services(uri,self.rep,Path('/absent'),Path('/absent'))
 def test_auth_locale_refuse_toute_origine_http_exterieure(self):
  sp=importlib.util.spec_from_file_location('auth219',R/'outils/bancs/auth-locale-groupes-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  service=m.Services('postgresql://p@/db?host=/tmp/socket',self.rep,Path('/absent'),Path('/absent'))
  with self.assertRaisesRegex(ValueError,'Origine'):service.http('https://production.invalid/rpc/payer_ordre',{})
  self.assertEqual(service.processus,[]);service.fermer()
 def test_payeur_final_derive_de_la_garde_effectifs_pas_du_catalogue_capture(self):
  import re,hashlib
  transport=(R/'migrations/20261031115805_transport_encaissement_existant.sql').read_text()
  corps=re.search(r'CREATE OR REPLACE FUNCTION public.payer_ordre\(.*?AS \$g\$(.*?)\$g\$;',transport,re.S)[1]
  source=(R/'migrations/20261031115831_effectifs_recrutement_et_licenciement_atomiques.sql').read_text()
  injection=re.search(r"overlay\(s placing E'((?:[^']|'')*)' FROM position",source,re.S)[1].replace("''", "'").replace('\\n','\n')
  final=hashlib.md5(corps.replace('BEGIN',injection,1).encode()).hexdigest()
  self.assertEqual(final,'d5c9f4e8bdbdc2858c8b908fd6c460c5')
  evenement=(R/'migrations/20261031113604_organisations_invitations_elections_atomiques.sql').read_text();self.assertIn(final,evenement)
  self.assertIn("has_function_privilege('authenticated'",evenement);self.assertIn("has_function_privilege('anon'",evenement)
 def test_lot_organisations_selectionne_cinq_sources_sans_transactions_internes(self):
  sp=importlib.util.spec_from_file_location('lotorg',R/'outils/livraison/preparer-organisations-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  from pglast import parse_sql
  sql=m.preparer();transactions=[n for n in parse_sql(sql) if type(n.stmt).__name__=='TransactionStmt']
  self.assertEqual(len(transactions),2);self.assertEqual(sql.count('INSERT INTO supabase_migrations.schema_migrations'),5)
  self.assertNotIn('CREATE OR REPLACE FUNCTION public.organisation_equipement_acheter',sql)
  self.assertIn('organisations219_paiement_non_examine',sql)
 def test_lot_organisations_refuse_empreinte_ou_selection_alteree(self):
  sp=importlib.util.spec_from_file_location('lotorg',R/'outils/livraison/preparer-organisations-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  data=json.loads(m.MAN.read_text());p=self.rep/'manifeste.json';sortie=self.rep/'interdit.sql'
  data['migrations'][0]['sha256']='0'*64;p.write_text(json.dumps(data))
  with self.assertRaisesRegex(ValueError,'Empreinte'):m.preparer(sortie,p)
  self.assertFalse(sortie.exists());data['migrations'].append(data['migrations'][0]);p.write_text(json.dumps(data))
  with self.assertRaisesRegex(ValueError,'cinq'):m.preparer(sortie,p)
  self.assertFalse(sortie.exists())
 def test_livraison_complete_garde_95_versions_et_une_transaction(self):
  sp=importlib.util.spec_from_file_location('complet219',R/'outils/livraison/preparer-livraison-complete-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  from pglast import parse_sql
  sql,entrees=m.preparer();self.assertEqual(len(entrees),95);self.assertEqual(len({e['version'] for e in entrees}),95)
  self.assertEqual(len([n for n in parse_sql(sql) if type(n.stmt).__name__=='TransactionStmt']),2)
  self.assertEqual(sql.count('INSERT INTO supabase_migrations.schema_migrations'),95)
  self.assertNotIn('achat_equipements_collectifs.sql',sql)
  for nom in ['20261031113610_construction_materiaux_prix_et_dons.sql','20261031113631_compromis_financement_reel.sql']:
   self.assertNotIn(nom,{Path(e['fichier']).name for e in entrees})
 def test_prevol_actualise_ne_produit_que_des_SELECT(self):
  sp=importlib.util.spec_from_file_location('prevol219',R/'outils/livraison/requetes-prevol-actualise-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  from pglast import parse_sql
  for nom,sql in m.requetes():
   ns=parse_sql(sql);self.assertEqual(len(ns),1,nom);self.assertEqual(type(ns[0].stmt).__name__,'SelectStmt',nom);self.assertLess(len(sql),12500)
  self.assertNotIn('auth.users',''.join(sql for _,sql in m.requetes()))
 def test_json_et_mcp_meme_resultat_schema_et_seeds(self):
  self.ecrire();exp,_=rendre.charger_exports(str(self.rep));self.assertEqual(exp,seeds.charger_exports(str(self.rep)))
  for p in self.rep.iterdir():p.unlink()
  self.ecrire('mcp');self.assertEqual(exp,rendre.charger_exports(str(self.rep))[0])
 def test_droits_absents_refuses(self):
  self.ecrire();(self.rep/'export_droits.json').unlink()
  with self.assertRaisesRegex(ValueError,'export_droits'):rendre.charger_exports(str(self.rep))
 def test_droits_colonnes_manquants_refuses(self):
  del self.valeurs['export_droits']['droits_colonnes'];self.ecrire()
  with self.assertRaisesRegex(ValueError,'incomplet'):rendre.charger_exports(str(self.rep))
 def test_double_export_contradictoire_refuse(self):
  self.ecrire();(self.rep/'autre.json').write_text(json.dumps({'export_fonctions':{'fonctions':[{'definition':'ne pas exécuter'}]}}))
  with self.assertRaisesRegex(ValueError,'contradictoires'):rendre.charger_exports(str(self.rep))
 def test_json_tronque_refuse_sans_log_du_contenu(self):
  self.ecrire();(self.rep/'export_fonctions.json').write_text('{"texte":"confidentiel"')
  with self.assertRaisesRegex(ValueError,'tronqué') as e:rendre.charger_exports(str(self.rep))
  self.assertNotIn('confidentiel',str(e.exception))
 def test_registre_vivant_absent_ou_duplique_refuse(self):
  sp=importlib.util.spec_from_file_location('epreuve',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  p=self.rep/'registre.json';p.write_text('{"registre":[]}')
  with self.assertRaisesRegex(ValueError,'complet absent'):m.lire_registre(p)
  p.write_text(json.dumps({'registre':[{'version':'20261030160000'},{'version':'20261030160000'}]}))
  with self.assertRaisesRegex(ValueError,'dupliquée'):m.lire_registre(p)
 def test_registre_tableau_brut_du_relais_et_enveloppes_compatibles(self):
  sp=importlib.util.spec_from_file_location('epreuve',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  lignes=[{'version':'20261030160000','name':'fixture_1'},{'version':'20261030161000','name':'fixture_2'}];p=self.rep/'registre.json'
  for valeur in [lignes,{'registre':lignes},[{'registre':lignes}],{'prevol_219':{'registre':lignes}}]:
   p.write_text(json.dumps(valeur));self.assertEqual(m.lire_registre(p),lignes)
  for valeur in [[],[{'version':20261030160000}],lignes+[lignes[0]]]:
   p.write_text(json.dumps(valeur))
   with self.assertRaises(ValueError):m.lire_registre(p)
 def test_omission_d_une_migration_du_manifeste_refusee(self):
  from unittest.mock import patch
  sp=importlib.util.spec_from_file_location('lot',R/'outils/livraison/preparer-groupes-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  d=json.loads(m.MAN.read_text());d['migrations'].pop();p=self.rep/'manifeste.json';p.write_text(json.dumps(d))
  with patch.object(m,'MAN',p),self.assertRaisesRegex(AssertionError,'88 migrations'):m.preparer()
 def test_paquet_233_et_88_garde_un_unique_BEGIN_COMMIT(self):
  from pglast import parse_sql
  sp=importlib.util.spec_from_file_location('lot',R/'outils/livraison/preparer-groupes-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  p=self.rep/'paquet.sql';self.assertEqual(m.preparer(str(p),inclure_prerequis=True),89)
  texte=p.read_text();transactions=[x.stmt.kind.name for x in parse_sql(texte) if type(x.stmt).__name__=='TransactionStmt']
  self.assertEqual(transactions,['TRANS_STMT_BEGIN','TRANS_STMT_COMMIT'])
  self.assertEqual(texte.count('INSERT INTO supabase_migrations.schema_migrations'),89)
  self.assertLess(texte.index('squatteurs_issue_combat.sql SHA256'),texte.index('securite_privee_socle_policier.sql SHA256'))
 def test_prerequis_non_atteste_refuse_avant_ecriture(self):
  from unittest.mock import patch
  sp=importlib.util.spec_from_file_location('lot',R/'outils/livraison/preparer-groupes-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  d=json.loads(m.MAN.read_text());d.pop('prerequis');p=self.rep/'manifeste.json';p.write_text(json.dumps(d));sortie=self.rep/'ne_pas_creer.sql'
  with patch.object(m,'MAN',p),self.assertRaisesRegex(AssertionError,'Prérequis #233 exact'):m.preparer(str(sortie),inclure_prerequis=True)
  self.assertFalse(sortie.exists())
 def test_prerequis_retouche_refuse_avant_ecriture(self):
  from unittest.mock import patch
  sp=importlib.util.spec_from_file_location('lot',R/'outils/livraison/preparer-groupes-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  d=json.loads(m.MAN.read_text());d['prerequis'][0]['sha256']='0'*64;p=self.rep/'manifeste.json';p.write_text(json.dumps(d));sortie=self.rep/'ne_pas_creer.sql'
  with patch.object(m,'MAN',p),self.assertRaisesRegex(AssertionError,'Contenu changé'):m.preparer(str(sortie),inclure_prerequis=True)
  self.assertFalse(sortie.exists())
 def test_nouveau_point_de_coupe_refuse_anciennes_preparations(self):
  sp=importlib.util.spec_from_file_location('lot',R/'outils/livraison/preparer-groupes-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  m.R=self.rep;(self.rep/'baseline').mkdir();(self.rep/'baseline/CONTROLE-GLOBAL.json').write_text('{"releve_le":"2099-01-01T00:00:00"}')
  with self.assertRaisesRegex(AssertionError,'rehorodater'):m.preparer()
 def test_ancien_export_sequence_refuse_avant_rendu(self):
  self.valeurs['export_structure']['sequences']=[{'sequence':'serie_fixture','start':1,'increment':1}];self.ecrire()
  with self.assertRaisesRegex(ValueError,'réextraire'):rendre.charger_exports(str(self.rep))
 def test_retrait_client_verifie_par_AST_et_reintroduction_refusee(self):
  sp=importlib.util.spec_from_file_location('fonctions',R/'outils/baseline/verifier-fonctions.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  p=self.rep/'client.js';p.write_text('// ancienMecanisme() est retiré\nconst x=1;')
  self.assertEqual(m.references_client_interdites('ancienMecanisme',[p]),[])
  for contenu in ['function ancienMecanisme() {}','ancienMecanisme();','window["ancienMecanisme"]();']:
   p.write_text(contenu);self.assertEqual(m.references_client_interdites('ancienMecanisme',[p]),[str(p)])
 def test_homonyme_local_ne_devient_pas_canon_global(self):
  sp=importlib.util.spec_from_file_location('fonctions',R/'outils/baseline/verifier-fonctions.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  p=self.rep/'client.js';p.write_text('function calcul(x){return x;}\nfunction externe(){\n  const lire = function(v){return Number(v)||0;};\n return lire(1);\n}\n')
  self.assertEqual(m.fonctions_premier_niveau(p),{'calcul','externe'})
  serveur=self.rep/'serveur.js';serveur.write_text('async function lire(table,filtre){return fetch(table+filtre);}')
  self.assertEqual(m.fonctions_premier_niveau(serveur),{'lire'})
 def test_sequence_incomplete_refusee_sans_valeur_inventee(self):
  with self.assertRaisesRegex(ValueError,'réextraire'):rendre.options_sequence({'sequence':'x','start':1})

 def test_classification_non_relevee_reste_un_echec_explicitement(self):
  import io,contextlib
  from unittest.mock import patch
  sp=importlib.util.spec_from_file_location('classification',R/'outils/baseline/verifier-classification.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  p=self.rep/'classification.csv';p.write_text('table;domaine;categorie;strategie;lignes_actuelles;justification;arbitrage\nfixture;socle;A;seed_complet;non_releve;Référentiel indispensable au moteur serveur;\n')
  sortie=io.StringIO()
  with patch.object(m,'CSV',str(p)),contextlib.redirect_stdout(sortie):self.assertEqual(m.main(),1)
  self.assertIn('relevé',sortie.getvalue())
 def test_options_bigint_en_texte_sans_perte(self):
  seq={'sequence':'fixture','type':'bigint','start':'1','increment':'1','min':'1','max':'9223372036854775807','cache':'1','cycle':False}
  self.assertIn('MAXVALUE 9223372036854775807',rendre.options_sequence(seq))
  self.assertEqual(seq['max'],'9223372036854775807')
 def test_arrondi_transport_bigint_refuse_avant_rendu(self):
  seq={'sequence':'fixture','type':'bigint','start':1,'increment':1,'min':1,'max':9223372036854776000,'cache':1,'cycle':False}
  self.valeurs['export_structure']['sequences']=[seq];self.ecrire()
  with self.assertRaisesRegex(ValueError,'sans arrondi'):rendre.charger_exports(str(self.rep))
 def test_options_invalides_ne_sont_pas_corrigees_silencieusement(self):
  seq={'sequence':'fixture','type':'integer','start':1,'increment':1,'min':1,'max':900,'cache':1,'cycle':False}
  for cle,val in [('start',901),('increment',0),('cache',0),('max','1.5'),('min',True),('max',2147483648)]:
   with self.subTest(cle=cle,val=val),self.assertRaises(ValueError):rendre.options_sequence(dict(seq,**{cle:val}))

class PostgreSQL(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  if os.environ.get('HG219_POSTGRES_BIN'):
   sp=importlib.util.spec_from_file_location('pg_config219',R/'outils/baseline/epreuve-postgresql.py');e=importlib.util.module_from_spec(sp);sp.loader.exec_module(e);e.configurer_binaires(Path(os.environ['HG219_POSTGRES_BIN']))
  import pgserver,psycopg2
  cls.tmp=tempfile.TemporaryDirectory(prefix='hg-catalogue-fixture-');cls.s=pgserver.get_server(Path(cls.tmp.name)/'data',cleanup_mode='delete');cls.c=psycopg2.connect(cls.s.get_uri());cls.q=cls.c.cursor()
  cls.q.execute('SHOW server_version');print('PostgreSQL outillage réel : '+cls.q.fetchone()[0],file=sys.stderr)
 @classmethod
 def tearDownClass(cls):cls.c.close();cls.s._cleanup();cls.tmp.cleanup()
 def tearDown(self):self.c.rollback()
 def test_comparaison_echouee_ne_retourne_pas_un_code_de_succes(self):
  import io,contextlib
  from unittest.mock import patch
  sp=importlib.util.spec_from_file_location('epreuve',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  with tempfile.TemporaryDirectory() as d:
   rep=Path(d);rapport=rep/'rapport.json';exp=rep/'exports';exp.mkdir()
   for cle,keys in rendre.EXPORTS_ATTENDUS.items():(exp/(cle+'.json')).write_text(json.dumps({cle:{k:[] for k in keys}}))
   args=['epreuve','--rapport',str(rapport),'--exports',str(exp)]
   self.q.execute('SHOW server_version_num')
   if int(self.q.fetchone()[0])//10000 != 17:args.append('--diagnostic-version-differente')
   with patch.object(m,'assembler',return_value=([('fixture','CREATE TABLE public.fixture_ecart(id integer);')],None)),patch.object(sys,'argv',args),contextlib.redirect_stdout(io.StringIO()):self.assertEqual(m.main(),1)
   v=json.loads(rapport.read_text());self.assertTrue(v['reconstruction']);self.assertFalse(v['fidelite_catalogue_vivant']);self.assertIn('erreur',v)
 def test_modele_mixte_avant_achat_socle_vraie_cle_etrangere(self):
  from reconstruire import ordonner_seeds
  import psycopg2
  ddl="CREATE TABLE public.objets_modeles(id text PRIMARY KEY,objet jsonb NOT NULL);CREATE TABLE public.objets_achetables(ordre text,modele text);ALTER TABLE public.objets_achetables ADD CONSTRAINT modele_fk FOREIGN KEY(modele) REFERENCES public.objets_modeles(id);"
  self.q.execute(ddl)
  graines=[('seeds/90_socle/objets_achetables.sql',"INSERT INTO public.objets_achetables VALUES('fixture','modele');"),('seeds/92_mixte/objets_modeles.sql',"INSERT INTO public.objets_modeles VALUES('modele','{}');")]
  self.q.execute('SAVEPOINT ordre_historique')
  with self.assertRaises(psycopg2.errors.ForeignKeyViolation):self.q.execute(graines[0][1])
  self.q.execute('ROLLBACK TO SAVEPOINT ordre_historique')
  ordre=ordonner_seeds([('30_contraintes.sql',ddl)],graines)
  self.assertEqual(ordre,[graines[1],graines[0]]);self.assertCountEqual(ordre,graines)
  for _,sql in ordre:self.q.execute(sql)
  self.q.execute('SELECT count(*) FROM objets_achetables');self.assertEqual(self.q.fetchone()[0],1)
 def test_cycle_de_seeds_refuse_sans_differer_les_contraintes(self):
  from reconstruire import ordonner_seeds
  schema=[('30_contraintes.sql','ALTER TABLE public.a ADD CONSTRAINT a_fk FOREIGN KEY(id) REFERENCES public.b(id);ALTER TABLE public.b ADD CONSTRAINT b_fk FOREIGN KEY(id) REFERENCES public.a(id);')]
  graines=[('a.sql','INSERT INTO public.a VALUES(1);'),('b.sql','INSERT INTO public.b VALUES(1);')]
  with self.assertRaisesRegex(ValueError,'Cycle'):ordonner_seeds(schema,graines)
 def test_commentaire_ne_cree_pas_de_dependance_de_seed(self):
  from reconstruire import ordonner_seeds
  graines=[('a.sql','INSERT INTO public.a VALUES(1);'),('b.sql','INSERT INTO public.b VALUES(1);')]
  self.assertEqual(ordonner_seeds([('30_contraintes.sql','-- ALTER TABLE public.a ADD CONSTRAINT fk FOREIGN KEY(id) REFERENCES public.b(id);')],graines),graines)
 def fixture_capture_referentiels(self):
  sp=importlib.util.spec_from_file_location('prive219',R/'outils/bancs/referentiels-prives-clone-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  for t in (*m.TABLES,'offres_emploi_bne'):
   self.q.execute('CREATE TABLE '+t+'(id text PRIMARY KEY,objet jsonb NOT NULL);INSERT INTO '+t+" VALUES('ancien','{}')")
  self.q.execute("SELECT datcollate,datctype,datlocprovider,COALESCE(to_jsonb(d)->>'datlocale',to_jsonb(d)->>'daticulocale'),datcollversion,pg_database_collation_actual_version(oid) FROM pg_database d WHERE datname=current_database()")
  locale=dict(zip(('collate','ctype','provider','datlocale','version','version_actuelle'),self.q.fetchone()))
  capture={'releve_le':'fixture isolée','registre':{'lignes':1012,'derniere':'20261031211256'},'locale':locale,'referentiels':{t:[{'id':'nouveau','objet':{'montant':5.5}}] for t in m.TABLES}}
  ref={'registre':1012,'derniere_version':'20261031211256','locale':{k:locale[k] for k in ('collate','ctype','provider')},'referentiels':{'offres_emploi_bne':{'lignes':0,'empreinte':'d751713988987e9331980363e24189ce'}}}
  self.q.execute("SELECT md5(jsonb_agg(x)::text) FROM (SELECT jsonb_build_object('id','nouveau','objet',jsonb_build_object('montant',5.5)) AS x) t")
  h=self.q.fetchone()[0]
  for t in m.TABLES:ref['referentiels'][t]={'lignes':1,'empreinte':h}
  return m,capture,ref
 def test_requete_documentaire_produit_le_format_prive_attendu_sans_mutation(self):
  m,capture,ref=self.fixture_capture_referentiels()
  self.q.execute("CREATE SCHEMA supabase_migrations;CREATE TABLE supabase_migrations.schema_migrations(version text);INSERT INTO supabase_migrations.schema_migrations SELECT 'v'||i FROM generate_series(1,1012) i")
  sp=importlib.util.spec_from_file_location('requete_privee219',R/'outils/baseline/epreuve-postgresql.py');e=importlib.util.module_from_spec(sp);sp.loader.exec_module(e)
  doc=(R/'outils/audits/EXPORT-REFERENTIELS-MANQUANTS-219-20261101.md').read_text().split('```sql\n',1)[1].split('```',1)[0]
  selects=0
  for ast,ordre in e.decouper(doc):
   self.assertIn(type(ast).__name__,('SelectStmt','TransactionStmt','VariableSetStmt'))
   if type(ast).__name__=='SelectStmt':self.q.execute(ordre);resultat=self.q.fetchone()[0];selects+=1
  self.assertEqual(selects,1);self.assertEqual(resultat['registre']['lignes'],1012)
  self.assertEqual(set(resultat['referentiels']),set(m.TABLES));self.assertEqual(set(resultat['locale']),set(capture['locale']))
  for t in m.TABLES:self.assertEqual(resultat['referentiels'][t],[{'id':'ancien','objet':{}}])
 def test_capture_privee_typed_json_exact_et_bne_vide(self):
  m,capture,ref=self.fixture_capture_referentiels()
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'capture.json';p.write_text(json.dumps([{'export_referentiels_manquants_219':capture}]))
   preuve=m.charger(self.q,p,ref)
  self.assertEqual(preuve['lignes'],4);self.assertTrue(preuve['locale']['conforme']);self.assertFalse(preuve['donnees_joueurs_importees'])
  self.q.execute("SELECT objet->>'montant' FROM recettes_commerce");self.assertEqual(self.q.fetchone()[0],'5.5')
  self.q.execute('SELECT count(*) FROM offres_emploi_bne');self.assertEqual(self.q.fetchone()[0],0)
 def test_capture_privee_incomplete_locale_registre_et_empreinte_refuses_sans_mutation(self):
  import copy
  m,original,ref=self.fixture_capture_referentiels()
  variantes=[]
  x=copy.deepcopy(original);x['registre']['lignes']=1013;variantes.append(x)
  x=copy.deepcopy(original);x['locale']['provider']='inconnu';variantes.append(x)
  x=copy.deepcopy(original);del x['locale']['datlocale'];variantes.append(x)
  x=copy.deepcopy(original);x['referentiels']['personnages_donnees']=[];variantes.append(x)
  x=copy.deepcopy(original);del x['referentiels']['recettes_commerce'][0]['objet'];variantes.append(x)
  x=copy.deepcopy(original);x['referentiels']['recettes_commerce'][0]['objet']={'montant':5.6};variantes.append(x)
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'capture.json'
   for v in variantes:
    p.write_text(json.dumps(v))
    with self.assertRaises(ValueError):m.charger(self.q,p,ref)
    for t in (*m.TABLES,'offres_emploi_bne'):
     self.q.execute('SELECT * FROM '+t);self.assertEqual(self.q.fetchall(),[('ancien',{})])
 def test_locale_locale_ne_remplace_pas_la_version_attendue_de_production(self):
  import copy
  m,capture,ref=self.fixture_capture_referentiels()
  # La capture concorde avec le moteur LOCAL, mais pas avec le relevé externe.
  ref=copy.deepcopy(ref);ref['locale']=dict(capture['locale']);ref['locale']['version']='autre-version-externe'
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'capture.json';p.write_text(json.dumps(capture))
   with self.assertRaisesRegex(ValueError,'contraire au relevé externe'):m.charger(self.q,p,ref)
  for t in m.TABLES:
   self.q.execute('SELECT * FROM '+t);self.assertEqual(self.q.fetchall(),[('ancien',{})])
 def test_capture_privee_preserve_les_cles_referencees_sans_relacher_les_fk(self):
  m,capture,ref=self.fixture_capture_referentiels()
  self.q.execute("CREATE TABLE enfant_reference(cle text REFERENCES recettes_commerce(id));INSERT INTO enfant_reference VALUES('ancien')")
  capture['referentiels']['recettes_commerce'][0]['id']='ancien'
  self.q.execute("SELECT md5(jsonb_agg(x)::text) FROM (SELECT jsonb_build_object('id','ancien','objet',jsonb_build_object('montant',5.5)) AS x) t");ref['referentiels']['recettes_commerce']['empreinte']=self.q.fetchone()[0]
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'capture.json';p.write_text(json.dumps(capture));m.charger(self.q,p,ref)
  self.q.execute('SELECT cle FROM enfant_reference');self.assertEqual(self.q.fetchone(),('ancien',))
 def test_capture_privee_erreur_sql_ne_divulgue_pas_la_ligne_et_annule_les_tables(self):
  m,capture,ref=self.fixture_capture_referentiels()
  capture['referentiels']['recettes_commerce'][0]['objet']=None
  with tempfile.TemporaryDirectory() as d:
   p=Path(d)/'capture.json';p.write_text(json.dumps(capture))
   with self.assertRaisesRegex(ValueError,'Chargement privé annulé : NotNullViolation') as ex:m.charger(self.q,p,ref)
  self.assertNotIn('nouveau',str(ex.exception))
  for t in m.TABLES:
   self.q.execute('SELECT * FROM '+t);self.assertEqual(self.q.fetchall(),[('ancien',{})])
 def test_generateur_recettes_insere_dans_le_schema_capture(self):
  sp=importlib.util.spec_from_file_location('epreuve_recettes219',R/'outils/baseline/epreuve-postgresql.py');e=importlib.util.module_from_spec(sp);sp.loader.exec_module(e)
  ddl=(R/'baseline/domaines/economie/10_tables.sql').read_text()
  for ast,ordre in e.decouper(ddl):
   if type(ast).__name__=='CreateStmt' and ast.relation.relname=='recettes_commerce':self.q.execute(ordre);break
  else:self.fail('table recettes_commerce absente du schéma capturé')
  self.q.execute("SAVEPOINT ancien_generateur")
  import psycopg2
  with self.assertRaises(psycopg2.errors.UndefinedColumn):self.q.execute("INSERT INTO recettes_commerce(id,type_objet) VALUES('fixture','aliment')")
  self.q.execute('ROLLBACK TO SAVEPOINT ancien_generateur')
  sql=subprocess.check_output([sys.executable,str(R/'outils/generateurs/generer_miroirs_entreprises.py'),'--sql'],text=True,cwd=R)
  for ast,ordre in e.decouper(sql):
   if type(ast).__name__=='InsertStmt' and ast.relation.relname=='recettes_commerce':self.q.execute(ordre)
  self.q.execute("SELECT count(*),bool_and(intermediaires='{}'::jsonb) FROM recettes_commerce")
  n,defaut=self.q.fetchone();self.assertGreater(n,0);self.assertTrue(defaut)
 def test_diagnostic_generateurs_annule_toutes_les_modifications_meme_en_cas_erreur(self):
  from unittest.mock import patch
  sp=importlib.util.spec_from_file_location('schema_diagnostic219',R/'outils/bancs/completer-schema-clone-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  sp=importlib.util.spec_from_file_location('epreuve_diagnostic219',R/'outils/baseline/epreuve-postgresql.py');e=importlib.util.module_from_spec(sp);sp.loader.exec_module(e)
  tables={'postes_nommes_regles':'poste_id','chantiers_paliers':'palier','entreprises_constantes':'cle','recettes_commerce':'id'}
  for table,pk in tables.items():self.q.execute('CREATE TABLE '+table+'('+pk+' text PRIMARY KEY,valeur integer);INSERT INTO '+table+" VALUES('temoin',1)")
  def source(args,**kwargs):
   if 'entreprises' in args[1]:return "INSERT INTO recettes_commerce(id,colonne_inexistante) VALUES('erreur',2);"
   if 'postes' in args[1]:return "('poste','label','maire','ville','ville')"
   return "INSERT INTO chantiers_paliers(palier,valeur) VALUES('temoin',2),('nouveau',3);"
  attendus={t:{'lignes':0,'empreinte':'inconnue'} for t in tables}
  with patch.object(m.subprocess,'check_output',side_effect=source):r=m.diagnostic_generateurs(self.q,e.decouper,attendus)
  self.assertTrue(r['essai_annule']);self.assertFalse(r['modification_des_attentes']);self.assertEqual(r['mesures']['chantiers_paliers']['lignes'],2)
  self.assertIn('generer_miroirs_entreprises.py',r['erreurs_generateurs'])
  self.assertFalse(any(x['concorde_reference'] for x in r['mesures'].values()))
  for table in tables:
   self.q.execute('SELECT * FROM '+table);self.assertEqual(self.q.fetchall(),[('temoin',1)])
 def test_between_retablit_la_definition_catalogue_sans_relacher_la_contrainte(self):
  from unittest.mock import patch
  import psycopg2
  sp=importlib.util.spec_from_file_location('schema_clone219',R/'outils/bancs/completer-schema-clone-219.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  sp=importlib.util.spec_from_file_location('epreuve_clone219',R/'outils/baseline/epreuve-postgresql.py');e=importlib.util.module_from_spec(sp);sp.loader.exec_module(e)
  self.q.execute('CREATE TABLE bornes_clone(a integer,b integer,CONSTRAINT bornes CHECK (a BETWEEN 0 AND 100 AND b BETWEEN 0 AND 100))')
  self.q.execute("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='bornes'");source=self.q.fetchone()[0]
  self.q.execute('ALTER TABLE bornes_clone DROP CONSTRAINT bornes;ALTER TABLE bornes_clone ADD CONSTRAINT bornes '+source)
  self.q.execute("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='bornes'");self.assertNotEqual(self.q.fetchone()[0],source)
  exp={'contraintes':[{'tbl':'bornes_clone','nom':'bornes','genre':'c','definition':source}]}
  with patch.object(m.rendre,'charger_exports',return_value=(exp,[])):
   preuve=m.restituer_checks(self.q,Path('/fixture'),e.expression_check);self.assertEqual(len(preuve),1)
  self.q.execute("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='bornes'");self.assertEqual(self.q.fetchone()[0],source)
  self.q.execute('INSERT INTO bornes_clone VALUES(0,100),(NULL,50);SAVEPOINT borne_refusee')
  with self.assertRaises(psycopg2.errors.CheckViolation):self.q.execute('INSERT INTO bornes_clone VALUES(-1,50)')
  self.q.execute('ROLLBACK TO SAVEPOINT borne_refusee')
 def test_parent_sans_seed_reste_un_refus_PostgreSQL_reel(self):
  from reconstruire import ordonner_seeds
  import psycopg2
  ddl='CREATE TABLE public.parent(id integer PRIMARY KEY);CREATE TABLE public.enfant(id integer);ALTER TABLE public.enfant ADD CONSTRAINT fk FOREIGN KEY(id) REFERENCES public.parent(id);'
  self.q.execute(ddl)
  ordre=ordonner_seeds([('30_contraintes.sql',ddl)],[('enfant.sql','INSERT INTO public.enfant VALUES(1);')])
  with self.assertRaises(psycopg2.errors.ForeignKeyViolation):self.q.execute(ordre[0][1])
 def test_controle_global_contient_les_champs_lus_par_le_verificateur(self):
  self.q.execute('CREATE SCHEMA supabase_migrations;CREATE TABLE supabase_migrations.schema_migrations(version text,name text)')
  self.q.execute(requetes.requete_controle_global());v=self.q.fetchone()[0]
  self.assertIn('colonnes_de_vues',v['totaux'])
  self.assertIn('fonctions_security_invoker',v['securite'])
  self.assertIn('tables_sans_rls',v['securite'])
 def test_identite_serial_et_sequence_autonome_reconstruits_depuis_vrais_exports(self):
  self.q.execute('''CREATE TABLE public.fixture_catalogue(id bigint GENERATED ALWAYS AS IDENTITY(START WITH 7 INCREMENT BY 3 MINVALUE 4 MAXVALUE 900 CACHE 4 CYCLE),n serial,double_n integer GENERATED ALWAYS AS (n * 2) STORED);
CREATE SEQUENCE public.sequence_sans_proprietaire AS integer START WITH 17 INCREMENT BY -2 MINVALUE -999 MAXVALUE 999 CACHE 3 CYCLE;
ALTER SEQUENCE fixture_catalogue_n_seq RENAME TO serie_nom_personnalise;''')
  exp={}
  for cle in rendre.EXPORTS_ATTENDUS:
   self.q.execute(requetes.EXPORTS[cle]);exp.update(self.q.fetchone()[0])
  # Aucun dump de lignes ni compteur courant ; seulement les catalogues.
  m={'tables':[],'sequences':[],'sequences_autonomes':[]}
  ddl=rendre.phase_tables({'colonnes':exp['colonnes'],'sequences':exp['sequences']},m,exp)
  self.q.execute('DROP TABLE fixture_catalogue;DROP SEQUENCE sequence_sans_proprietaire')
  for sql in ddl:self.q.execute(sql)
  self.q.execute(requetes.EXPORTS['export_structure']);nouveau=self.q.fetchone()[0]
  self.assertEqual(exp['colonnes'],nouveau['colonnes'])
  self.assertEqual(exp['sequences'],nouveau['sequences'])
  self.assertEqual(m['sequences_autonomes'],['sequence_sans_proprietaire'])
  self.q.execute('INSERT INTO fixture_catalogue DEFAULT VALUES RETURNING id,n');self.assertEqual(self.q.fetchone(),(7,1))
 def test_generateurs_schema_et_seeds_sur_exports_reels_sans_lignes_privees(self):
  import io,contextlib
  from unittest.mock import patch
  self.q.execute("CREATE TABLE public.fixture_catalogue(id bigint GENERATED BY DEFAULT AS IDENTITY, contenu text);INSERT INTO fixture_catalogue(contenu) VALUES('secret_fixture_ne_pas_seeder')")
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);rep=root/'exports';rep.mkdir();base=root/'baseline';base.mkdir()
   for cle in rendre.EXPORTS_ATTENDUS:
    self.q.execute(requetes.EXPORTS[cle]);(rep/(cle+'.json')).write_text(json.dumps({cle:self.q.fetchone()[0]}))
   cls=base/'classification-donnees.csv';cls.write_text((R/'baseline/classification-donnees.csv').read_text()+'fixture_catalogue;divers et technique;C;structure_seule;non_releve;non;0;0;fixture etat vivant;pas de seed\n')
   with patch.object(rendre,'RACINE',str(root)),patch.object(rendre,'CIBLE',str(base/'domaines')),patch.object(rendre,'CLASSIF',str(cls)),patch.object(sys,'argv',['rendre.py',str(rep)]),contextlib.redirect_stdout(io.StringIO()):
    self.assertEqual(rendre.main(),0)
   resultat=root/'seeds.json';resultat.write_text('{"export_seeds":[]}')
   with patch.object(seeds,'BASE',str(base)),patch.object(seeds,'CIBLE',str(base/'seeds')),contextlib.redirect_stdout(io.StringIO()):
    self.assertEqual(seeds.rendre(seeds.charger_exports(str(rep)),str(resultat)),0)
   textes=''.join(p.read_text() for p in base.rglob('*.sql'))
   self.assertNotIn('secret_fixture_ne_pas_seeder',textes)
   self.assertNotIn('INSERT INTO public.fixture_catalogue',textes)
   self.assertIn('GENERATED BY DEFAULT AS IDENTITY',textes)
 def test_extraction_seed_identite_et_colonne_calculee_preservees(self):
  self.q.execute("CREATE TABLE public.fixture_catalogue(id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,n integer,double_n integer GENERATED ALWAYS AS(n*2) STORED);INSERT INTO fixture_catalogue(n) VALUES(7)")
  exp={}
  for cle in rendre.EXPORTS_ATTENDUS:
   self.q.execute(requetes.EXPORTS[cle]);exp.update(self.q.fetchone()[0])
  self.q.execute(seeds.requete(exp,['fixture_catalogue']));lignes=self.q.fetchone()[0]['export_seeds']
  self.assertEqual(len(lignes),1);self.assertIn('OVERRIDING SYSTEM VALUE',lignes[0]['ligne']);self.assertNotIn('double_n',lignes[0]['ligne'])
  self.q.execute('TRUNCATE fixture_catalogue RESTART IDENTITY');self.q.execute(lignes[0]['ligne'])
  for col in exp['colonnes']:
   if col['tbl']=='fixture_catalogue':
    sql=seeds.recalage_sequence(col,exp)
    if sql:self.q.execute(sql)
  self.q.execute('SELECT id,n,double_n FROM fixture_catalogue');self.assertEqual(self.q.fetchone(),(1,7,14))
  self.q.execute('INSERT INTO fixture_catalogue(n) VALUES(8) RETURNING id,double_n');self.assertEqual(self.q.fetchone(),(2,16))
 def test_recalage_respecte_increment_positif_et_negatif(self):
  for depart,pas,suite in [(7,3,13),(20,-3,14)]:
   with self.subTest(pas=pas):
    self.q.execute('SAVEPOINT compteur')
    self.q.execute(f'CREATE TABLE public.fixture_catalogue(id integer GENERATED ALWAYS AS IDENTITY(START WITH {depart} INCREMENT BY {pas} MINVALUE -99 MAXVALUE 99) PRIMARY KEY);INSERT INTO fixture_catalogue DEFAULT VALUES;INSERT INTO fixture_catalogue DEFAULT VALUES')
    self.q.execute(requetes.EXPORTS['export_structure']);exp=self.q.fetchone()[0]
    self.q.execute(seeds.recalage_sequence(exp['colonnes'][0],exp))
    self.q.execute('INSERT INTO fixture_catalogue DEFAULT VALUES RETURNING id');self.assertEqual(self.q.fetchone()[0],suite)
    self.q.execute('ROLLBACK TO SAVEPOINT compteur')
 def test_comparaison_catalogue_detecte_un_ecart_reel(self):
  sp=importlib.util.spec_from_file_location('epreuve',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  self.q.execute('CREATE TABLE public.fixture_catalogue(id integer)')
  with tempfile.TemporaryDirectory() as d:
   for cle in rendre.EXPORTS_ATTENDUS:
    self.q.execute(requetes.EXPORTS[cle]);(Path(d)/(cle+'.json')).write_text(json.dumps({cle:self.q.fetchone()[0]}))
   self.assertEqual(m.comparer_catalogues(self.q,Path(d)),[])
   self.q.execute('ALTER TABLE fixture_catalogue ADD COLUMN nouvelle_colonne text')
   self.assertTrue(any(x['categorie']=='colonnes' for x in m.comparer_catalogues(self.q,Path(d))))
 def test_compilation_finale_refuse_un_corps_SQL_invalide(self):
  sp=importlib.util.spec_from_file_location('epreuve',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  with self.assertRaisesRegex(RuntimeError,'recompilation finale'):
   m.installer(self.q,[('fixture','CREATE FUNCTION public.fixture_invalide() RETURNS int LANGUAGE sql AS $$SELECT colonne_absente FROM table_absente$$;')])
 def test_fonction_SQL_dependant_vue_recompilee_apres_creation(self):
  sp=importlib.util.spec_from_file_location('epreuve',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  v=m.installer(self.q,[('fixture','CREATE FUNCTION public.fixture_valide() RETURNS int LANGUAGE sql AS $$SELECT n FROM vue_fixture$$;CREATE VIEW vue_fixture AS SELECT 42 AS n;')])
  self.assertEqual(v['fonctions_recompilees'],1);self.q.execute('SELECT fixture_valide()');self.assertEqual(self.q.fetchone()[0],42)
 def test_attribut_supprime_conserve_les_rangs_reels(self):
  self.q.execute('CREATE TABLE fixture_catalogue(a int, perdu text, c text);ALTER TABLE fixture_catalogue DROP COLUMN perdu')
  self.q.execute(requetes.EXPORTS['export_structure']);exp=self.q.fetchone()[0]
  man={'tables':[],'sequences':[],'sequences_autonomes':[]}
  ddl=rendre.phase_tables({'colonnes':exp['colonnes'],'sequences':[]},man,exp)
  self.q.execute('DROP TABLE fixture_catalogue')
  for sql in ddl:self.q.execute(sql)
  self.q.execute(requetes.EXPORTS['export_structure']);self.assertEqual(self.q.fetchone()[0]['colonnes'],exp['colonnes'])
 def test_grant_ne_laisse_pas_PUBLIC_EXECUTE_sur_RPC_fermee(self):
  self.q.execute('CREATE FUNCTION fixture_fermee() RETURNS int LANGUAGE sql AS $$SELECT 1$$;REVOKE ALL ON FUNCTION fixture_fermee() FROM PUBLIC')
  self.q.execute(requetes.EXPORTS['export_droits']);droits=self.q.fetchone()[0]
  self.q.execute('DROP FUNCTION fixture_fermee();CREATE FUNCTION fixture_fermee() RETURNS int LANGUAGE sql AS $$SELECT 1$$')
  man={'droits':[],'droits_colonnes':[]}
  from reconstruire import decouper
  for sql in rendre.phase_droits({'droits':droits['droits_fonctions'],'droits_colonnes':[]},man,{}):
   for _,ordre in decouper(sql):self.q.execute(ordre)
  self.q.execute("SELECT has_function_privilege('public','fixture_fermee()','EXECUTE')");self.assertFalse(self.q.fetchone()[0])
 def test_CHECK_associatif_ne_masque_pas_une_borne_modifiee(self):
  sp=importlib.util.spec_from_file_location('epreuve',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  a='CHECK (((x >= 0 AND x <= 100) AND (x <> 42 AND x <> 43)))'
  b='CHECK ((x >= 0 AND x <= 100 AND (x <> 42 AND x <> 43)))'
  self.assertEqual(m.expression_check(a),m.expression_check(b))
  self.assertNotEqual(m.expression_check(a),m.expression_check(b.replace('100','101')))
  self.assertNotEqual(m.expression_check(a),m.expression_check(b.replace('AND','OR',1)))
 def test_FK_attend_un_index_UNIQUE_autonome(self):
  import reconstruire
  from unittest.mock import patch
  import psycopg2
  tables='CREATE TABLE parent_fk(id text);CREATE TABLE enfant_fk(parent text);'
  fk='ALTER TABLE enfant_fk ADD CONSTRAINT lien_fk FOREIGN KEY(parent) REFERENCES parent_fk(id);'
  index='CREATE UNIQUE INDEX parent_fk_unique ON parent_fk(id);'
  self.q.execute('SAVEPOINT ancien_ordre');self.q.execute(tables)
  with self.assertRaises(psycopg2.errors.InvalidForeignKey):self.q.execute(fk)
  self.q.execute('ROLLBACK TO SAVEPOINT ancien_ordre')
  with tempfile.TemporaryDirectory() as d:
   racine=Path(d);dom=racine/'domaines'/'fixture';dom.mkdir(parents=True);graines=racine/'seeds';graines.mkdir()
   fichiers={'10_tables.sql':tables,'30_contraintes.sql':fk,'35_index.sql':index}
   for nom,s in fichiers.items():(dom/nom).write_text(s)
   (dom/'MANIFESTE.json').write_text(json.dumps({'ordre':list(fichiers)}))
   with patch.object(reconstruire,'DOM',str(dom.parent)),patch.object(reconstruire,'SEEDS',str(graines)):
    morceaux,_=reconstruire.assembler()
   for _,s in morceaux:self.q.execute(s)
  self.q.execute("INSERT INTO parent_fk VALUES('parent');INSERT INTO enfant_fk VALUES('parent')")
  with self.assertRaises(psycopg2.errors.ForeignKeyViolation):self.q.execute("INSERT INTO enfant_fk VALUES('absent')")
 def test_simulateur_compte_les_sequences_IDENTITY_du_catalogue(self):
  import reconstruire
  texte='CREATE TABLE fixture_catalogue(id bigint GENERATED ALWAYS AS IDENTITY(SEQUENCE NAME public.fixture_catalogue_id_seq));'
  cat,erreurs,*_=reconstruire.simuler([('fixture/10_tables.sql',texte)])
  self.assertFalse(erreurs)
  self.assertIn('fixture_catalogue_id_seq',cat.sequences)

if __name__=='__main__':unittest.main(verbosity=2)
