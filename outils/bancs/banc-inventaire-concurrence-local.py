#!/usr/bin/env python3
"""Deux sessions PostgreSQL authentifiees, verrous reels ; chaque appel metier est ROLLBACK.
Seule la preparation du schema et des identites fictives est commitee dans la base jetable.
Ce test prouve l'exclusion et l'absence d'etat intermediaire visible, pas un commit de joueur.
"""
import importlib.util,tempfile,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 spec=importlib.util.spec_from_file_location('base',R/'outils/bancs/banc-inventaire-receptions-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-inventaire-concurrence-'),cleanup_mode='delete');conn=[]
 try:
  admin=psycopg2.connect(srv.get_uri());conn.append(admin);q=admin.cursor();m.initialiser(q);admin.commit()
  n=0
  def check(v,msg):
   nonlocal n
   assert v,msg;n+=1;print('OK',n,msg,flush=True)
  def snap():
   q.execute("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d),(SELECT jsonb_agg(to_jsonb(b) ORDER BY id) FROM comptes_bancaires b),(SELECT jsonb_agg(to_jsonb(c) ORDER BY id) FROM caisses_batiments c),(SELECT count(*) FROM inventaire_actions_recus))");v=q.fetchone()[0];admin.rollback();return v
  def session(uid):
   c=psycopg2.connect(srv.get_uri());conn.append(c);cur=c.cursor();cur.execute("SELECT set_config('hg.uid',%s,true),set_config('role','authenticated',true),set_config('request.path','/rpc/sels_ammoniaque_acheter',true)",(uid,));return c,cur
  for autre in [False,True]:
   avant=snap();a,qa=session('00000000-0000-4000-8000-000000000001');b,qb=session('00000000-0000-4000-8000-000000000002' if autre else '00000000-0000-4000-8000-000000000001')
   qa.execute("SELECT sels_ammoniaque_acheter('00000000-0000-4000-8000-000000000099',2,0)");check(qa.fetchone()[0]['qte']==2,'premier appel execute dans une transaction encore ouverte')
   check(snap()==avant,'autre session ne voit ni objet ni debit ou credit intermediaire')
   qb.execute("SET LOCAL lock_timeout='100ms'")
   try:qb.execute("SELECT sels_ammoniaque_acheter('00000000-0000-4000-8000-000000000099',2,0)");raise AssertionError('commande concurrente non serialisee')
   except psycopg2.Error as e:check(e.pgcode=='55P03','verrou reel '+('de caisse entre deux acheteurs' if autre else 'de personnage pour la meme requete'));b.rollback()
   a.rollback();check(snap()==avant,'deux transactions annulees sans effet permanent')
  print(json.dumps({'assertions':n,'production':False,'role_appels':'authenticated','metier_committe':False,'schema_et_jwt':'fixtures'}))
 finally:
  for c in conn:c.close()
  srv.cleanup()
if __name__=='__main__':main()
