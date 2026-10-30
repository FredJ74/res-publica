#!/usr/bin/env python3
"""Chargeur strict + véritable extraction/rendu de séquences sur PostgreSQL jetable."""
import importlib.util,json,sys,tempfile,unittest
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
 def test_sequence_incomplete_refusee_sans_valeur_inventee(self):
  with self.assertRaisesRegex(ValueError,'réextraire'):rendre.options_sequence({'sequence':'x','start':1})

class PostgreSQL(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  import pgserver,psycopg2
  cls.tmp=tempfile.TemporaryDirectory(prefix='hg-catalogue-fixture-');cls.s=pgserver.get_server(Path(cls.tmp.name)/'data',cleanup_mode='delete');cls.c=psycopg2.connect(cls.s.get_uri());cls.q=cls.c.cursor()
 @classmethod
 def tearDownClass(cls):cls.c.close();cls.s._cleanup();cls.tmp.cleanup()
 def tearDown(self):self.c.rollback()
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

if __name__=='__main__':unittest.main(verbosity=2)
