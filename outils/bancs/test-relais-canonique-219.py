#!/usr/bin/env python3
"""Vrai SELECT de relais et refus des transports corrompus, PostgreSQL jetable."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch

R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('relais219',R/'outils/livraison/relais-canonique-219.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class Relais(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  import pgserver,psycopg2
  cls.tmp=tempfile.TemporaryDirectory(prefix='hg-relais-219-');cls.s=pgserver.get_server(Path(cls.tmp.name)/'data',cleanup_mode='delete');cls.c=psycopg2.connect(cls.s.get_uri());cls.q=cls.c.cursor()
  cls.q.execute('CREATE SCHEMA supabase_migrations;CREATE TABLE supabase_migrations.schema_migrations(version text,name text);INSERT INTO supabase_migrations.schema_migrations VALUES(\'20261030193635\',\'fixture\')')
  for table,spec in m.REFERENCES.items():
   cls.q.execute('CREATE TABLE public.'+table+'('+','.join(n+' '+t for n,t in [p.split(':') for p in spec.split()])+')')
  cls.q.execute("CREATE TABLE public.joueur_prive(secret text);INSERT INTO joueur_prive VALUES('NE_PAS_COPIER_LE_JOUEUR');CREATE TABLE public.commerce_decors_sources(proprietaire_user_id uuid,chemin text);INSERT INTO commerce_decors_sources VALUES('00000000-0000-4000-8000-000000000001','NE_PAS_COPIER_LE_FICHIER');CREATE TABLE public.publicites_premium_sources(proprietaire_user_id uuid);CREATE SEQUENCE public.seq_fixture AS bigint;INSERT INTO terrains_referentiel VALUES('republic','capitale','terrain',100,5.50)")
  for table in ['ordres_couts','ressources_economie','pa_bonus_differes','postes_nommes_regles','villes']:
   cls.q.execute('CREATE TABLE public.'+table+'(id integer);CREATE TABLE public.'+table+"_empreinte(empreinte text);CREATE FUNCTION public."+table+"_empreinte_reelle() RETURNS text LANGUAGE sql STABLE AS $$SELECT 'fixture'::text$$")
  cls.q.execute(m.requete());cls.d=cls.q.fetchone()[0];cls.c.commit()
 @classmethod
 def tearDownClass(cls):cls.c.close();cls.s._cleanup();cls.tmp.cleanup()
 def test_fichier_annule_identique_aux_generateurs(self):
  attendu='-- Généré par outils/livraison/relais-canonique-219.py : aucune donnée privée.\nBEGIN;\nSET TRANSACTION READ ONLY;\n'+m.requete()+'ROLLBACK;\n'
  self.assertEqual((R/'outils/bancs/RELAIS-CANONIQUE-219.sql').read_text(),attendu)
 def test_requete_executee_en_transaction_read_only_et_ecriture_refusee(self):
  import psycopg2
  try:
   self.q.execute('SET TRANSACTION READ ONLY')
   self.q.execute(m.requete());m.valider(self.q.fetchone()[0])
   self.q.execute('SHOW transaction_read_only');self.assertEqual(self.q.fetchone()[0],'on')
   with self.assertRaises(psycopg2.errors.ReadOnlySqlTransaction):self.q.execute('UPDATE public.joueur_prive SET secret=secret')
  finally:self.c.rollback()
 def test_select_unique_sans_mutation_meme_dans_CTE(self):
  from pglast import parse_sql
  from pglast.visitors import Visitor
  class Garde(Visitor):
   def visit(self,ancestors,node):
    if type(node).__name__ in ['InsertStmt','UpdateStmt','DeleteStmt','MergeStmt','CreateStmt','CallStmt','DoStmt','CopyStmt','TransactionStmt']:raise AssertionError(type(node).__name__)
  stmts=parse_sql(m.requete());self.assertEqual(len(stmts),1);self.assertEqual(type(stmts[0].stmt).__name__,'SelectStmt');Garde()(stmts)
  with self.assertRaises(AssertionError):Garde()(parse_sql('WITH x AS (INSERT INTO t VALUES (1) RETURNING *) SELECT * FROM x'))
 def test_relais_reel_exact_et_manifeste_vide_constate(self):
  self.assertEqual(m.valider(copy.deepcopy(self.d))['format'],self.d['format'])
  self.assertEqual(self.d['export_structure']['sequences'][0]['max'],'9223372036854775807')
  self.assertEqual(len(self.d['seeds_controle']),10)
  self.assertEqual(len(self.d['referentiels_controle']),5)
  self.assertTrue(any(c['lignes']==0 for c in self.d['seeds_controle']))
  self.assertIn("'5.50'",self.d['export_seeds'][0]['ligne'])
 def test_aucune_ligne_joueur_ou_source_privee_extraite(self):
  self.assertNotIn('NE_PAS_COPIER',json.dumps(self.d))
  self.assertEqual({x['tbl'] for x in self.d['export_seeds']},{'terrains_referentiel'})
 def test_releves_melanges_et_totaux_falsifies_refuses(self):
  for champ in ['releve_utc','totaux']:
   d=copy.deepcopy(self.d)
   if champ=='releve_utc':d[champ]='2099-01-01 00:00:00'
   else:d['controle_global']['totaux']['tables']+=1
   with self.subTest(champ=champ),self.assertRaises(ValueError):m.valider(d)
 def test_mesure_de_referentiels_absente_n_est_pas_remplacee_par_ancienne(self):
  d=copy.deepcopy(self.d);d['referentiels_controle']=[]
  with self.assertRaisesRegex(ValueError,'Mesure'):m.valider(d)
 def test_ancienne_borne_arrondie_refusee(self):
  d=copy.deepcopy(self.d);d['export_structure']['sequences'][0]['max']=9223372036854776000
  with self.assertRaisesRegex(ValueError,'sans arrondi'):m.valider(d)
 def test_seed_tronque_ou_empreinte_modifiee_refuse(self):
  for changement in ['ligne','empreinte']:
   d=copy.deepcopy(self.d)
   if changement=='ligne':d['export_seeds']=[]
   else:d['seeds_controle'][0]['empreinte']='faux'
   with self.subTest(changement=changement),self.assertRaises(ValueError):m.valider(d)
 def test_aucun_zero_invente_si_manifeste_absent(self):
  d=copy.deepcopy(self.d);d['seeds_controle']=[]
  with self.assertRaisesRegex(ValueError,'incomplet'):m.valider(d)
 def test_empreinte_recalculee_n_autorise_pas_une_commande_ou_une_autre_table(self):
  import hashlib
  for sql in ['SELECT 1; DELETE FROM public.terrains_referentiel', 'DELETE FROM public.terrains_referentiel', 'INSERT INTO public.personnages(name) VALUES(\'X\')', "INSERT INTO public.terrains_referentiel(pays,ville,batiment,surface,prix_achat) VALUES(current_user,'capitale','terrain',100,5.50)"]:
   d=copy.deepcopy(self.d);d['export_seeds'][0]['ligne']=sql
   for c in d['seeds_controle']:
    if c['table']=='terrains_referentiel':c['empreinte']=hashlib.md5(sql.encode()).hexdigest()
   with self.subTest(sql=sql),self.assertRaises(ValueError):m.valider(d)
 def test_ligne_de_table_privee_refusee(self):
  d=copy.deepcopy(self.d);d['export_seeds'].append({'tbl':'commerce_decors_sources','rang':1,'ligne':'non exécutée'})
  with self.assertRaisesRegex(ValueError,'hors liste'):m.valider(d)
 def test_compte_registre_incoherent_refuse(self):
  d=copy.deepcopy(self.d);d['registre']=[]
  with self.assertRaisesRegex(ValueError,'Registre'):m.valider(d)
 def test_quatre_exports_et_controle_complet_obligatoires(self):
  d=copy.deepcopy(self.d);d.pop('export_droits')
  with self.assertRaises(ValueError):m.valider(d)
  d=copy.deepcopy(self.d);d['controle_global']['totaux'].pop('colonnes_de_vues')
  with self.assertRaisesRegex(ValueError,'incomplet'):m.valider(d)
 def test_seed_prive_refuse_avant_tout_fichier_meme_apres_un_seed_public(self):
  import io,contextlib
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);livraison=root/'seeds.json';cible=root/'rendu'
   livraison.write_text(json.dumps({'export_seeds':[{'tbl':'actes_nocturnes_mecanismes','ligne':'non exécutée'},{'tbl':'commerce_decors_sources','ligne':'NE_PAS_COPIER'}]}))
   with patch.object(m.seeds,'CIBLE',str(cible)),contextlib.redirect_stdout(io.StringIO()),self.assertRaisesRegex(ValueError,'hors surface'):
    m.seeds.rendre({},str(livraison))
   self.assertFalse(cible.exists())
 def test_materialisation_hors_git_reutilise_le_chargeur_sans_remplacer_de_valeurs(self):
  with tempfile.TemporaryDirectory() as d:
   destination=Path(d)/'prive'
   self.assertEqual(m.materialiser(copy.deepcopy(self.d),destination),9)
   exp,_=m.rendre.charger_exports(str(destination/'canoniques'))
   self.assertEqual(exp['sequences'][0]['max'],'9223372036854775807')
   self.assertEqual(destination.stat().st_mode & 0o777,0o700)
   self.assertEqual((destination/'registre.json').stat().st_mode & 0o777,0o600)
   with self.assertRaises(FileExistsError):m.materialiser(self.d,destination)
 def test_publication_des_exports_dans_git_refusee(self):
  with self.assertRaisesRegex(ValueError,'Git'):m.materialiser(self.d,R/'ne-jamais-creer-ce-dossier')
  self.assertFalse((R/'ne-jamais-creer-ce-dossier').exists())
 def test_contenus_territoriaux_ne_sont_pas_classes_socle_commun(self):
  cls=m.seeds.classification()
  for t in ['locaux_loyers_referentiel','rue_noeuds_serveur','rue_sorties_batiments','scandales_predefinis','terrains_referentiel','tracts_pnj_catalogue']:self.assertEqual(cls[t]['categorie'],'B')
  for t in ['objets_modeles','terrain_actions_regles']:self.assertEqual(cls[t]['categorie'],'D')
 def test_source_privee_ne_redevient_pas_un_seed(self):
  cls=m.seeds.classification()
  for t in ['commerce_decors_sources','publicites_premium_sources']:
   self.assertEqual(cls[t]['categorie'],'C');self.assertEqual(cls[t]['strategie'],'structure_seule')
  cls['objets_modeles']=dict(cls['objets_modeles'],categorie='C')
  with patch.object(m.seeds,'classification',return_value=cls),self.assertRaisesRegex(ValueError,'non autorisée'):m.requete()

if __name__=='__main__':unittest.main(verbosity=2)
