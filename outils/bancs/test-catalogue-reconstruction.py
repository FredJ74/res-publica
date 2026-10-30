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
  self.q.execute('''CREATE TABLE public.fixture_catalogue(id bigint GENERATED ALWAYS AS IDENTITY(START WITH 7 INCREMENT BY 3 MINVALUE 4 MAXVALUE 900 CACHE 4 CYCLE),n serial);
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
 def test_compilation_finale_refuse_un_corps_SQL_invalide(self):
  sp=importlib.util.spec_from_file_location('epreuve',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  with self.assertRaisesRegex(RuntimeError,'recompilation finale'):
   m.installer(self.q,[('fixture','CREATE FUNCTION public.fixture_invalide() RETURNS int LANGUAGE sql AS $$SELECT colonne_absente FROM table_absente$$;')])
 def test_fonction_SQL_dependant_vue_recompilee_apres_creation(self):
  sp=importlib.util.spec_from_file_location('epreuve',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
  v=m.installer(self.q,[('fixture','CREATE FUNCTION public.fixture_valide() RETURNS int LANGUAGE sql AS $$SELECT n FROM vue_fixture$$;CREATE VIEW vue_fixture AS SELECT 42 AS n;')])
  self.assertEqual(v['fonctions_recompilees'],1);self.q.execute('SELECT fixture_valide()');self.assertEqual(self.q.fetchone()[0],42)

if __name__=='__main__':unittest.main(verbosity=2)
