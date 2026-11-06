#!/usr/bin/env python3
"""Paquet de catalogue #422 : vrais SELECT locaux et contre-épreuves de droits."""
import copy, hashlib, importlib.util, json
from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[2]
s=importlib.util.spec_from_file_location('tests_relais',R/'outils/bancs/test-relais-canonique-219.py')
t=importlib.util.module_from_spec(s);s.loader.exec_module(t)

class Collecte422(t.Relais):
 def test_paquet_exact_et_sans_mutation(self):
  p=R/'outils/bancs/collecte-forums422';mf=json.loads((p/'MANIFESTE.json').read_text())
  for nom,sql in t.m.requetes.EXPORTS.items():
   self.assertEqual((p.parent/('COLLECTE-FORUMS422-'+nom+'.sql')).read_text(),sql.strip()+'\n')
  self.assertEqual((p.parent/'COLLECTE-FORUMS422-controle_global.sql').read_text(),t.m.requetes.requete_controle_global().strip()+'\n')
  self.assertTrue((p.parent/'COLLECTE-FORUMS422-capture_atomique.sql').read_text().endswith(t.m.requete()))
  for nom,attendu in mf['fichiers'].items():
   b=(p/nom).read_bytes();self.assertEqual(len(b),attendu['octets']);self.assertEqual(hashlib.sha256(b).hexdigest(),attendu['sha256'])
  from pglast import parse_sql
  from pglast.visitors import Visitor
  class Lecture(Visitor):
   def visit(self,ancestors,node):
    if type(node).__name__ in ('InsertStmt','UpdateStmt','DeleteStmt','MergeStmt','CallStmt','DoStmt','CopyStmt','TransactionStmt'):raise AssertionError(type(node).__name__)
  for sql in p.parent.glob('COLLECTE-FORUMS422-*.sql'):
   arbres=parse_sql(sql.read_text());self.assertEqual(len(arbres),1);self.assertEqual(type(arbres[0].stmt).__name__,'SelectStmt');Lecture()(arbres)
 def test_droits_sequence_reels_puis_troncatures_refusees(self):
  try:
   self.q.execute('CREATE ROLE hg422_export_fixture;GRANT USAGE,SELECT ON SEQUENCE public.seq_fixture TO hg422_export_fixture')
   self.q.execute(t.m.requete());d=self.q.fetchone()[0];t.m.valider(d)
   ds=d['export_droits']['droits_relations'];n=next(i for i,x in enumerate(ds)if x['genre']=='SEQUENCE' and x['objet']=='seq_fixture' and x['beneficiaire']=='hg422_export_fixture')
   self.assertEqual(ds[n]['privileges'],'SELECT, USAGE')
   a=copy.deepcopy(d);a['export_droits']['droits_relations'].pop(n)
   with self.assertRaisesRegex(ValueError,'Comptes des droits'):t.m.valider(a)
   # Même un compte falsifié ne remplace pas l'empreinte indépendante du snapshot.
   a['controle_global']['totaux']['droits_relations']-=1
   with self.assertRaisesRegex(ValueError,'Empreinte des droits'):t.m.valider(a)
   a=copy.deepcopy(d);a['export_droits']['droits_relations'][n]['privileges']='USAGE'
   with self.assertRaisesRegex(ValueError,'Empreinte des droits'):t.m.valider(a)
  finally:self.c.rollback()

if __name__=='__main__':unittest.main()
