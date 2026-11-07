#!/usr/bin/env python3
"""Régressions des contrôles ; fixtures et fichiers temporaires, aucune base distante."""
import copy,hashlib,importlib.util,json,subprocess,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
R=Path(__file__).resolve().parents[2]
def module(n,p):
 s=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
class Globaux(unittest.TestCase):
 def test_extension_signature_et_contre_epreuves(self):
  m=module('ext','outils/baseline/declarations_dynamiques.py')
  texte="""DO $$ DECLARE v_def text; v_new text;
BEGIN
 v_def := pg_get_functiondef('public.source(text,integer)'::regprocedure);
 v_new := replace(v_def, 'p_n integer)', 'p_n integer, p_lieu text DEFAULT NULL::text)');
 v_new := replace(v_new, 'ancien corps', 'nouveau corps');
 EXECUTE v_new;
END $$;"""
  noms={'source(text,integer)':['p_acteur','p_n']}
  connus={'source(text,integer)'};attendu={'source(text,integer,text)'}
  self.assertEqual(m.extensions_parametres(texte,connus,noms),attendu)
  variantes={'source_absente':(texte,set()),'nom_ancre_faux':(texte.replace('p_n integer','p_faux integer'),connus),'sans_execute':(texte.replace(' EXECUTE v_new;',''),connus),'mauvaise_variable':(texte.replace(' EXECUTE v_new;',' EXECUTE v_def;'),connus),'execute_commente':(texte.replace(' EXECUTE v_new;',' -- EXECUTE v_new;'),connus),'source_conditionnelle':(texte.replace(' v_def :=',' IF false THEN\n v_def :=').replace(' v_new := replace(v_def',' END IF;\n v_new := replace(v_def'),connus),'execute_conditionnel':(texte.replace(' EXECUTE v_new;',' IF false THEN EXECUTE v_new; END IF;'),connus),'opaque':(texte.replace(' EXECUTE v_new;'," v_new := 'SELECT 1';\n EXECUTE v_new;"),connus),'select_into':(texte.replace(' EXECUTE v_new;'," SELECT 'SELECT 1' INTO v_new;\n EXECUTE v_new;"),connus),'retour':(texte.replace(' EXECUTE v_new;',' RETURN;\n EXECUTE v_new;'),connus),'type_source_faux':(texte.replace("'p_n integer)'","'p_n text)'"),connus),'fonction_non_executee':(texte.replace('DO $$','CREATE FUNCTION public.inactive() RETURNS void LANGUAGE plpgsql AS $$'),connus),'autre_langage':(texte.replace('END $$;','END $$ LANGUAGE plpython3u;'),connus),'commentaire':('/*'+texte+'*/',connus)}
  for nom,(t,c) in variantes.items():
   with self.subTest(nom=nom):self.assertFalse(m.extensions_parametres(t,c,noms))
  reel=(R/'migrations/20261104173000_trading_livraison_terrestre.sql').read_text()
  self.assertEqual(m.extensions_parametres(reel,{'trading_acheter(text,text,text,integer)'},{'trading_acheter(text,text,text,integer)':['a','b','c','p_quantite']}),{'trading_acheter(text,text,text,integer,text)'})
  self.assertNotIn('trading_acheter(text,text,text,integer,text,text)',m.extensions_parametres(reel,{'trading_acheter(text,text,text,integer)'},{'trading_acheter(text,text,text,integer)':['a','b','c','p_quantite']}))
 def test_ressources_ordre_exhaustif_et_copie_alteree(self):
  g=module('gen','outils/generateurs/generer_referentiels_serveur.py');v=module('verif','outils/baseline/verifier-referentiels.py')
  r=next(r for r in json.loads(Path(g.DECLARATION).read_text())['referentiels'] if r['serveur']=='RESSOURCES_ECONOMIE_SERVEUR')
  valeur,erreur=g.valeur_generee(r,g.jsc());self.assertIsNone(erreur);self.assertEqual(len(json.loads(valeur)),19)
  faux=copy.deepcopy(r);faux['ordre_des_cles'].remove('derives_petrochimiques');_,erreur=g.valeur_generee(faux,g.jsc());self.assertTrue(erreur)
  canon=json.loads(valeur);copie=copy.deepcopy(canon);copie['derives_petrochimiques']['prixBase']+=1
  self.assertTrue(v.comparer(canon,copie,r['champs']))
 def test_seed_miroir_altere_est_refuse(self):
  m=module('seedsmiroirs','outils/baseline/regenerer-seeds-miroirs.py')
  with tempfile.TemporaryDirectory() as d:
   cible=Path(d);(cible/'baseline').mkdir();import shutil;shutil.copytree(R/'baseline/seeds',cible/'baseline/seeds')
   # Réutiliser les vrais générateurs, mais écrire uniquement dans la copie temporaire.
   (cible/'outils').symlink_to(R/'outils',target_is_directory=True)
   for source in R.glob('*.js'):(cible/source.name).symlink_to(source)
   for nom in ['historique','migrations']:(cible/nom).symlink_to(R/nom,target_is_directory=True)
   with patch.object(m,'R',cible):
    m.rendre(verifier=True)
    p=cible/'baseline/seeds/95_a-regenerer/ordres_couts.sql';p.write_text(p.read_text().replace("'acheter_terrain',2,", "'acheter_terrain',99,",1))
    # Si le format change, la contre-épreuve doit échouer, pas prétendre muter.
    self.assertNotEqual(p.read_bytes(),(R/'baseline/seeds/95_a-regenerer/ordres_couts.sql').read_bytes())
    with self.assertRaisesRegex(ValueError,'Seed miroir différent'):m.rendre(verifier=True)
 def test_dotation_ville_capturee_et_ancienne_extraction_incomplete(self):
  g=module('entreprises','outils/generateurs/generer_miroirs_entreprises.py');d=g.extraire();locales=[x for x in d['dotations'] if '@' in x['cle']]
  self.assertEqual([x['cle'] for x in locales],['marche@ville_b']);locale=locales[0]
  self.assertEqual(len(locale['carte']),6);self.assertIn('carbonade_frites_marche',locale['carte']);self.assertNotIn('croque_monsieur_luthecia',locale['carte'])
  generale=next(x for x in d['dotations'] if x['cle']=='marche');self.assertIn('croque_monsieur_luthecia',generale['carte'])
  with patch.object(g,'EXTRACTEUR',g.EXTRACTEUR.replace('Object.keys(g.V.republic).sort()',"Object.keys({}).sort()")):
   ancienne=g.extraire();self.assertFalse(any(x['cle']=='marche@ville_b' for x in ancienne['dotations']))
  sql=g.sql(d);self.assertIn('ON CONFLICT (cle) DO UPDATE',sql);self.assertIn("WHERE position('@' in cle) = 0",sql)
 def test_seeds_preservent_cle_ville_depuis_un_export(self):
  m=module('rendu_seed','outils/baseline/seeds.py');table='commerces_dotations';cls=m.classification()[table]
  with tempfile.TemporaryDirectory() as d:
   sortie=Path(d)/'sortie';export=Path(d)/'capture.json';ligne="INSERT INTO public.commerces_dotations(cle) VALUES ('marche@ville_b');"
   export.write_text(json.dumps([{'tbl':table,'ligne':ligne}]))
   exp={'colonnes':[{'tbl':table,'attname':'cle','attnum':1,'type':'text','defaut':None}],'contraintes':[],'sequences':[]}
   with patch.object(m,'CIBLE',str(sortie)),patch.object(m,'classification',return_value={table:cls}),patch.object(m,'A_CONSTRUIRE',{}),patch.object(m,'A_REGENERER',{}):
    m.rendre(exp,str(export))
   sql=(sortie/'90_socle/commerces_dotations.sql').read_text();self.assertIn(ligne,sql)
   inv=json.loads((sortie/'INVENTAIRE.json').read_text());self.assertEqual(inv['lignes_par_table'][table],1)
   self.assertEqual(inv['fichiers']['90_socle/commerces_dotations.sql'],hashlib.md5(sql.encode()).hexdigest())
if __name__=='__main__':unittest.main(verbosity=2)
