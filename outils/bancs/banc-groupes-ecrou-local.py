#!/usr/bin/env python3
"""Écrou réel et séparation commune, aucune mutation hors PostgreSQL jetable."""
import importlib.util,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('recrutement',R/'outils/bancs/banc-groupes-recrutement-local.py');r=importlib.util.module_from_spec(sp);sp.loader.exec_module(r)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 if '--contre-separation-ecrou' not in sys.argv:
  q.execute((R/'migrations/20261031115823_groupes_separation_ecrou.sql').read_text())
  q.execute((R/'migrations/20261031115823_groupes_separation_ecrou.sql').read_text())
 sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='mairie',current_room='accueil',current_street=NULL WHERE name IN ('A','B')")
 ctx['c'].commit()
 def jugement(nom):
  sql("INSERT INTO jugements(id,country,city,accuse,motif,data,executee) VALUES('jugement-ecrou-fixture','republic','capitale','"+nom+"','Peine fictive','{\"motifs\":[{\"jours\":2}]}',false)")
  return exige(rpc('justice_executer_condamnation_soi',('jugement-ecrou-fixture',),qui=nom))
 def position(nom):
  q.execute('SELECT country,current_city,current_building,current_room,current_street FROM personnages_donnees WHERE name=%s',(nom,));return q.fetchone()
 def pnj_position(ident):
  q.execute('SELECT pays,ville,building_id,room_id,rue_noeud_id FROM pnj_position_effective(%s)',(ident,));return q.fetchone()
 def chef():
  avant=position('A');q.execute("SELECT array_agg(id ORDER BY id) FROM pnj_membres WHERE leader_pj='B'");ids=q.fetchone()[0]
  positions={i:pnj_position(i) for i in ids}
  v=jugement('B');assert position('B')[2:4]==('commissariat','prison'),position('B')
  assert position('A')==avant
  for i in ids:
   assert pnj_position(i)==positions[i],(i,pnj_position(i),positions[i])
   q.execute('SELECT leader_pj,leader_pnj_id FROM pnj_membres WHERE id=%s',(i,));assert q.fetchone()==(None,None)
  q.execute("SELECT count(*) FROM groupes_pj_adhesions WHERE membre='B' OR chef='B'");assert q.fetchone()[0]==0
  q.execute("SELECT count(*) FROM detentions WHERE nom='A'");assert q.fetchone()[0]==0
  q.execute("SELECT detention_id FROM (SELECT est_emprisonne->>'detentionId' AS detention_id FROM personnages_donnees WHERE name='B') d");assert q.fetchone()[0]==v['detention_id']
  exige(rpc('justice_executer_condamnation_soi',('jugement-ecrou-fixture',),qui='B'),'deja_executee')
  q.execute("SELECT count(*) FROM detentions WHERE nom='B'");assert q.fetchone()[0]==1
 cas('ecrou_chef_ne_transporte_pas_PJ_innocent_ni_ses_7PNJ_rejeu_sans_double_peine',chef)
 def membre():
  sql("UPDATE pnj_membres SET leader_pj='A' WHERE id='cie-S1'")
  avant=position('B');lieu=pnj_position('cie-S1');autre=pnj_position('cie-S2')
  jugement('A');assert position('A')[2:4]==('commissariat','prison') and position('B')==avant
  assert pnj_position('cie-S1')==lieu and pnj_position('cie-S2')==autre
  q.execute("SELECT leader_pj FROM pnj_membres WHERE id='cie-S2'");assert q.fetchone()[0]=='B'
  q.execute("SELECT count(*) FROM groupes_pj_adhesions WHERE membre='A'");assert q.fetchone()[0]==0
 cas('ecrou_membre_detache_uniquement_ses_suiveurs_sans_sanction_du_chef',membre)
 def refus():
  avant=position('B');q.execute("SELECT jsonb_agg(to_jsonb(g)) FROM groupes_pj_adhesions g");g=q.fetchone()[0]
  exige(rpc('justice_executer_condamnation_soi',('inexistant',),qui='B'),'condamnation_non_autorisee')
  assert position('B')==avant
  q.execute("SELECT jsonb_agg(to_jsonb(g)) FROM groupes_pj_adhesions g");assert q.fetchone()[0]==g
 cas('ecrou_refuse_ne_separe_pas_le_groupe',refus)
 def rollback():
  avant=position('B');lieu=pnj_position('cie-S1')
  # Panne aval simulée dans le schéma jetable : aucune peine, séparation ou
  # projection ne doit survivre au refus de la position finale.
  q.execute("CREATE FUNCTION panne_cellule_fixture() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.current_room='prison' THEN RAISE EXCEPTION 'panne-cellule-fixture';END IF;RETURN NEW;END $$")
  q.execute("CREATE TRIGGER panne_cellule BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION panne_cellule_fixture()")
  q.execute('SAVEPOINT panne_ecrou')
  try:
   jugement('B');raise AssertionError('panne non propagée')
  except Exception as e:
   assert 'panne-cellule-fixture' in str(e),e
  finally:q.execute('ROLLBACK TO SAVEPOINT panne_ecrou')
  assert position('B')==avant and pnj_position('cie-S1')==lieu
  q.execute("SELECT count(*) FROM groupes_pj_adhesions WHERE membre='A' AND chef='B'");assert q.fetchone()[0]==1
  q.execute("SELECT count(*) FROM detentions WHERE nom='B'");assert q.fetchone()[0]==0
 cas('ecrou_panne_aval_annule_peine_positions_et_separation',rollback)
 def droits():
  for sig in ['pnj_positions_separer_interne(jsonb)','groupe_ecrou_separer_interne(text)']:
   q.execute("SELECT has_function_privilege('authenticated',%s,'EXECUTE')",(sig,));assert not q.fetchone()[0],sig
 cas('ecrou_primitives_privees_sans_porte_de_teleportation',droits)
 ctx['preuves_extension']['ecrou']='Vraie exécution de jugement et écrou sur PJ fictifs : séparation atomique du chef/membre et PNJ, refus/rejeu/panne aval. Aucun test production.'
 if suivante is not None:suivante(ctx)
def lancer(suivante=None):
 return r.p.v.d.i.lancer(lambda c:r.p.v.d.suite(c,lambda c:r.p.v.suite(c,lambda c:r.p.suite(c,lambda c:r.suite(c,lambda c:suite(c,suivante))))))
if __name__=='__main__':sys.exit(lancer())
