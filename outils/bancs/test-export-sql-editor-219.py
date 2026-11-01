#!/usr/bin/env python3
"""Vrai SELECT atomique et transport CSV/JSON ; données exclusivement fictives."""
import copy,csv,importlib.util,json,os,random,tarfile,tempfile,unittest
from pathlib import Path
R=Path(__file__).resolve().parents[2]
s=importlib.util.spec_from_file_location('editor219',R/'outils/livraison/export-sql-editor-219.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
def select_collecte(sql):
 from pglast import parse_sql
 ns=parse_sql(sql);assert len(ns)==1 and type(ns[0].stmt).__name__=='SelectStmt'
 return sql
class Collecte(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  import pgserver,psycopg2
  e=m.module('natif_editor219','outils/baseline/epreuve-postgresql.py')
  if os.environ.get('HG219_POSTGRES_BIN'):e.configurer_binaires(Path(os.environ['HG219_POSTGRES_BIN']))
  cls.tmp=tempfile.TemporaryDirectory(prefix='hg219-editor-fixture-');cls.s=pgserver.get_server(Path(cls.tmp.name)/'data',cleanup_mode='delete');cls.c=psycopg2.connect(cls.s.get_uri());q=cls.c.cursor()
  q.execute('SHOW server_version_num');assert q.fetchone()[0]=='170006','PG17.6 obligatoire'
  cls.c.commit();cls.c.autocommit=True
  q.execute("CREATE DATABASE hg219_editor TEMPLATE template0 LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' LOCALE_PROVIDER icu ICU_LOCALE 'en-US'");cls.c.close();cls.c=psycopg2.connect(cls.s.get_uri(database='hg219_editor'));q=cls.c.cursor()
  q.execute("CREATE ROLE authenticated;CREATE ROLE anon;CREATE SCHEMA supabase_migrations;CREATE TABLE supabase_migrations.schema_migrations(version text,name text);INSERT INTO supabase_migrations.schema_migrations SELECT to_char('2026-01-01'::timestamp + i * interval '1 second','YYYYMMDDHH24MISS'),'fixture' FROM generate_series(1,1022) i")
  relais=m.module('fixture_relais219','outils/livraison/relais-canonique-219.py')
  for table,spec in relais.REFERENCES.items():q.execute('CREATE TABLE public.'+table+'('+','.join(n+' '+t for n,t in [x.split(':') for x in spec.split()])+')')
  for table in m.module('fixture_noms219','outils/livraison/manifeste-collecte-certification-219.py').TABLES:q.execute('CREATE TABLE public.'+table+'(id integer PRIMARY KEY, valeur numeric,objet jsonb)')
  q.execute("INSERT INTO chantiers_paliers VALUES(1,5.50,'{\"valeur\":0.123456789123456789,\"texte\":\"é漢\"}');CREATE TABLE public.ordres_couts(fn text,pa integer,cost integer);INSERT INTO ordres_couts VALUES('fixture_achat',1,6);CREATE TABLE public.pa_bonus_differes(id integer);CREATE TABLE public.villes(id integer)")
  for table in ['ordres_couts','ressources_economie','pa_bonus_differes','postes_nommes_regles','villes']:
   q.execute('CREATE TABLE public.'+table+"_empreinte(seul boolean DEFAULT true,empreinte text);INSERT INTO public."+table+"_empreinte(empreinte) VALUES('0000000000000000');CREATE FUNCTION public."+table+"_empreinte_reelle() RETURNS text LANGUAGE sql STABLE AS $$SELECT '0000000000000000'::text$$")
  q.execute("CREATE TABLE public.fixture_privee(secret text);INSERT INTO fixture_privee VALUES('NE_JAMAIS_EXPORTER_CE_JOUEUR');ALTER TABLE fixture_privee ENABLE ROW LEVEL SECURITY;CREATE POLICY fixture ON fixture_privee FOR SELECT USING(true);CREATE FUNCTION public.fixture_trigger() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN NEW;END$$;CREATE TRIGGER fixture BEFORE INSERT ON fixture_privee FOR EACH ROW EXECUTE FUNCTION public.fixture_trigger();CREATE SEQUENCE public.fixture_sequence AS bigint")
  cls.c.commit();cls.c.set_session(readonly=True,isolation_level='REPEATABLE READ');q.execute(select_collecte(m.generer_sql(taille=256)));cls.rows=[dict(zip(m.COLONNES,row)) for row in q.fetchall()];cls.c.rollback()
  cls.files,cls.ann,cls.sha=m.decoder(cls.rows)
 @classmethod
 def tearDownClass(cls):cls.c.close();cls.s._cleanup();cls.tmp.cleanup()
 def test_SQL_genere_identique_et_SELECT_unique_atomique(self):
  self.assertEqual(m.SQL.read_text(),m.generer_sql())
  m.module('readonly_editor219','outils/livraison/manifeste-collecte-certification-219.py').select_unique(select_collecte(m.generer_sql()))
 def test_vraie_capture_coherente_et_sans_donnee_joueur(self):
  d,_=m.verifier_documents(self.files,self.ann);self.assertEqual(d['references']['registre'],1022)
  self.assertNotIn('NE_JAMAIS_EXPORTER_CE_JOUEUR',b''.join(self.files.values()).decode())
  self.assertEqual(d['capture_privee']['referentiels']['chantiers_paliers'][0]['valeur'],m.Decimal('5.50'))
  self.assertEqual(d['capture_privee']['referentiels']['chantiers_paliers'][0]['objet']['valeur'],m.Decimal('0.123456789123456789'))
 def test_transport_melange_ordre_reconstitue_exact(self):
  rows=copy.deepcopy(self.rows);random.Random(219).shuffle(rows);f,a,h=m.decoder(rows,self.sha);self.assertEqual(f,self.files)
 def test_manquant_duplique_altere_base64_et_autres_coupes_refuses(self):
  mutations=[lambda r:r.pop(),lambda r:r.append(copy.deepcopy(r[0])),lambda r:r[0].update(donnees_base64=r[0]['donnees_base64'][:-1]),lambda r:r[0].update(snapshot='autre'),lambda r:r[0].update(capture_sha256='a'*64),lambda r:r[0].update(fichier='../secret'),lambda r:r[0].update(octets_fragment='1'),lambda r:r[0].update(partie='-1')]
  for f in mutations:
   rows=copy.deepcopy(self.rows);f(rows)
   with self.subTest(mutation=f),self.assertRaises(ValueError):m.decoder(rows)
  with self.assertRaises(ValueError):m.decoder(self.rows,'0'*64)
 def test_ensemble_entier_manquant_refuse(self):
  with self.assertRaises(ValueError):m.decoder([r for r in self.rows if r['fichier']!='referentiels.json'])
 def test_coupe_locale_ou_tarifs_contradictoires_refuses(self):
  for nom,changer in [('REFERENTIELS-PRODUCTION.json',lambda x:x.update(registre=1023)),('REFERENTIELS-PRODUCTION.json',lambda x:x['locale'].update(version='autre')),('referentiels.json',lambda x:x['ordres_couts'][0].update(cost=7)),('relais-canonique.json',lambda x:x.update(snapshot='autre'))]:
   f=dict(self.files);v=m.lire_json(f[nom]);changer(v);f[nom]=m.json_exact(v).encode()
   with self.subTest(fichier=nom),self.assertRaises(ValueError):m.verifier_documents(f,self.ann)
 def test_CSV_archive_importable_et_droits_prives(self):
  with tempfile.TemporaryDirectory(prefix='hg219-import-editor-') as d:
   p=Path(d)/'resultat.csv'
   with p.open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=m.COLONNES);w.writeheader();w.writerows(self.rows)
   dest=Path(d)/'sortie';r=m.assembler([p],dest,self.sha);self.assertFalse(r['catalogue_certifie'])
   for nom,b in self.files.items():self.assertEqual((dest/nom).read_bytes(),b)
   self.assertTrue((dest/'catalogue/canoniques/export_structure.json').is_file());self.assertTrue((dest/'catalogue/registre.json').is_file())
   for f in dest.rglob('*'):self.assertEqual(f.stat().st_mode & 0o077,0)
   with tarfile.open(dest/'exports-certification-219.tar.gz') as t:self.assertIn('capture-couts.json',t.getnames());self.assertEqual(t.extractfile('REFERENTIELS-PRODUCTION.json').read(),self.files['REFERENTIELS-PRODUCTION.json'])
   with self.assertRaises(ValueError):m.assembler([p],dest,self.sha)
 def test_JSON_transport_et_rejet_destination_Git(self):
  with tempfile.TemporaryDirectory(prefix='hg219-json-editor-') as d:
   p=Path(d)/'rows.json';p.write_text(json.dumps(self.rows));self.assertEqual(m.charger_lignes([p]),self.rows)
   with self.assertRaises(ValueError):m.assembler([p],R/'capture-interdite')
 def test_json_duplique_et_generateur_incomplet_refuses(self):
  with self.assertRaises(ValueError):m.lire_json('{"a":1,"a":2}')
  with self.assertRaises(ValueError):m.generer_sql(entrees=[])
  with self.assertRaises(ValueError):m.generer_sql(taille=0)
 def test_limite_SQL_Editor_cent_lignes_refusee(self):
  self.assertGreater(len(self.rows),100)
  with self.assertRaises(ValueError):m.decoder(self.rows[:100])
 def test_capture_incomplete_ne_cree_aucune_sortie(self):
  with tempfile.TemporaryDirectory(prefix='hg219-tronque-editor-') as d:
   p=Path(d)/'rows.json';p.write_text(json.dumps(self.rows[:-1]));dest=Path(d)/'sortie'
   with self.assertRaises(ValueError):m.assembler([p],dest)
   self.assertFalse(dest.exists())
if __name__=='__main__':unittest.main(verbosity=2)
