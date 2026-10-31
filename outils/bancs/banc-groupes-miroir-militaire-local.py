#!/usr/bin/env python3
"""Histoire des soldats et rejet des anciens documents, PostgreSQL jetable.

Les permissions de table larges sont uniquement une contre-épreuve du décor :
elles ne prétendent pas reproduire les ACL actuellement déployées.
"""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('transports',R/'outils/bancs/banc-groupes-transports-speciaux-local.py');t=importlib.util.module_from_spec(sp);sp.loader.exec_module(t)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 ctx['installer_fonction_canonique']('militaire_soldat_supprimer')
 migration=R/'migrations/20261031115830_militaire_miroir_et_ecrivains_historiques.sql'
 if '--contre-miroir-militaire' not in sys.argv:q.execute(migration.read_text());q.execute(migration.read_text())
 ctx['c'].commit()
 def photo():
  q.execute("SELECT to_jsonb(p) FROM pnj_membres p WHERE id='cie-S1'");return q.fetchone()[0]
 def mort():
  q.execute("SELECT pnj_mourir('cie-S1','fixture')");exige(q.fetchone()[0]);avant=photo()
  q.execute("SELECT pnj_miroir_compagnie('cie')")
  assert photo()['statut']=='mort','le miroir réactive le soldat mort'
  assert photo()['leader_pj'] is None
  assert photo()['nom']==avant['nom']
 cas('militaire_miroir_ne_ressuscite_pas_mort',mort)
 def detenu():
  sql("UPDATE pnj_membres SET statut='detenu' WHERE id='cie-S1'")
  q.execute("SELECT pnj_miroir_compagnie('cie')");assert photo()['statut']=='detenu'
 cas('militaire_miroir_ne_libere_pas_detenu',detenu)
 def disparition():
  q.execute("SELECT militaire_soldat_supprimer('cie','cie-s1','S1')")
  p=photo();assert p is not None and p['statut']=='mort','identité/histoire supprimées après le cycle de mort'
  q.execute("SELECT count(*) FROM compagnies_militaires c CROSS JOIN LATERAL jsonb_array_elements(c.data->'sections') s CROSS JOIN LATERAL jsonb_array_elements(s->'soldats') x WHERE c.id='cie' AND x->>'matricule'='S1'");assert q.fetchone()[0]==0
 cas('militaire_cycle_mort_retrait_blob_conserve_identite',disparition)
 def brut(chemin):
  # Même une ACL trop large ou un request.path forgé ne donne pas un ordre métier.
  sql('GRANT SELECT,UPDATE ON compagnies_militaires TO authenticated')
  q.execute('SAVEPOINT tentative_document')
  try:
   q.execute("SELECT set_config('role','authenticated',true),set_config('request.path',%s,true)",(chemin,))
   q.execute("UPDATE compagnies_militaires SET data=jsonb_set(data,'{reserve}','[]') WHERE id='cie'")
  except Exception as exc:
   q.execute('ROLLBACK TO SAVEPOINT tentative_document')
   assert 'compagnie_ecriture_metier_requise' in str(exc),str(exc)
  else:
   q.execute('ROLLBACK TO SAVEPOINT tentative_document');raise AssertionError('document navigateur accepté')
 for chemin in ['/compagnies_militaires','/rpc/militaire_ordre_collectif']:
  cas('militaire_refus_document_authentifie_'+chemin,lambda chemin=chemin:brut(chemin))
 def utile():
  exige(rpc('pnj_quitter_groupe',(['cie-S1'],),qui='B'))
  q.execute("SELECT leader_pj FROM pnj_membres WHERE id='cie-S1'");assert q.fetchone()[0] is None
  exige(rpc('pnj_prendre',(['cie-S1'],),qui='A'))
 cas('militaire_commandes_communes_utiles_passent_garde',utile)
 ctx['preuves_extension']['miroir_militaire']='Cycle de mort existant, conservation identité, statut mort/détenu, écritures brutes authenticated refusées même sous chemin falsifié ; commandes communes conservées. ACL de table permissive propre au décor.'
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):return t.lancer(lambda ctx:suite(ctx,suivante))
if __name__=='__main__':sys.exit(lancer())
