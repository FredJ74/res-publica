#!/usr/bin/env python3
import copy,importlib.util,unittest
from pathlib import Path
R=Path(__file__).resolve().parents[2]
s=importlib.util.spec_from_file_location('plan97',R/'outils/livraison/preparer-recette97-219.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class Plan(unittest.TestCase):
 def test_ordre_exact_et_sources_verifiees(self):
  v=m.preparer();self.assertEqual(v['nombre'],97);self.assertEqual(v['tarifs_source'],{'lignes':460,'md5':'e4f22df47ad847b9b8cf263459ed4fbd'});self.assertFalse(v['execution_autorisee']);self.assertTrue(v['ancien_plan_tarifaire_conforme_source']);self.assertEqual([x['version'] for x in v['migrations'][-2:]],['20261101170000','20261101171000'])
 def test_omission_inversion_et_source_alteree_refusees(self):
  es=m.preparer()['migrations']
  for modif in ('omission','inversion','empreinte'):
   e=copy.deepcopy(es)
   if modif=='omission':e.pop()
   elif modif=='inversion':e[-1],e[-2]=e[-2],e[-1]
   else:e[-1]['sha256']='0'*64
   with self.subTest(modif=modif),self.assertRaises(ValueError):m.verifier_ordre(e)
if __name__=='__main__':unittest.main(verbosity=2)
