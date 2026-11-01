#!/usr/bin/env python3
import importlib.util,unittest,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[2]
s=importlib.util.spec_from_file_location('collecte',R/'outils/livraison/manifeste-collecte-certification-219.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class Collecte(unittest.TestCase):
 def test_manifeste_reutilise_canonique_et_contrats(self):
  d=m.manifeste();self.assertFalse(d['connexion_effectuee']);q={x['id']:x for x in d['requetes']}
  self.assertEqual(set(q),{'canonique','empreinte','registre','catalogue_cible','referentiels','references','capture_privee'})
  for x in q.values():self.assertEqual(hashlib.sha256(x['sql'].encode()).hexdigest(),x['sha256_requete']);m.select_unique(x['sql'])
  for t in m.TABLES:self.assertIn('public.'+t+' x',q['references']['sql'])
  self.assertIn('HG_RELAIS_CANONIQUE_219_V1',q['canonique']['sql']);self.assertIn("'ordres_couts',",q['referentiels']['sql'])
  self.assertNotIn('auth.users',''.join(x['sql'] for x in q.values()))
 def test_mutations_rejetees_meme_dans_cte(self):
  for sql in ['SELECT 1;SELECT 2','WITH x AS (DELETE FROM t RETURNING *) SELECT * FROM x','SELECT * INTO nouveau FROM ancien','UPDATE t SET x=1','BEGIN; SELECT 1; ROLLBACK;']:
   with self.subTest(sql=sql),self.assertRaises(ValueError):m.select_unique(sql)
if __name__=='__main__':unittest.main(verbosity=2)
