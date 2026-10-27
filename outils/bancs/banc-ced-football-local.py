#!/usr/bin/env python3
"""Vrais corps SQL et verrous PostgreSQL jetable ; aucune connexion distante."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json, re, tempfile
R=Path(__file__).resolve().parents[2]
M1='migrations/20261024074120_centre_artisanal_achat_ced.sql'
M2='migrations/20261024074129_football_quota_jour_commun.sql'
SOURCES=[
 ('migrations/20261020222029_construction_lancement_priorite_bancaire.sql','helvetia_debiter_fonds_ordinaires'),
 ('baseline/domaines/socle/20_fonctions.sql','inventaire_place_restante'),
 ('baseline/domaines/socle/20_fonctions.sql','jour_de_jeu_pays'),
 ('migrations/20261016131932_reception_objets_atomique.sql','inventaire_revision_garder'),
 ('migrations/20261016131932_reception_objets_atomique.sql','inventaire_reception_etat'),
 ('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre')]
def setup_sql():
 s=(R/'historique/fixtures-bancs/ced-football-schema.sql').read_text()
 for path,fn in SOURCES:
  src=(R/path).read_text()
  for x in re.finditer(r'CREATE OR REPLACE FUNCTION public\.'+fn+r'\(',src):
   m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[x.start():],re.S)
   s+='\n'+src[x.start():x.start()+m.end()]
 s+='\nCREATE TRIGGER zzzz_hg_inventory_revision BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION inventaire_revision_garder();'
 return s
def main():
 import pgserver,psycopg2
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-ced-foot-'),cleanup_mode='delete')
 try:
  uri=srv.get_uri();c=psycopg2.connect(uri);c.autocommit=True;q=c.cursor();q.execute(setup_sql())
  for path in [M1,M2,M1,M2]:q.execute((R/path).read_text())
  n=0
  def check(v):
   nonlocal n
   assert v;n+=1
  def call(k,cur=q):
   cur.execute('SELECT pnj_ced_acheter(%s)',(f'00000000-0000-4000-8000-{k:012d}',));return cur.fetchone()[0]
  def snap():
   q.execute("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(d)) FROM personnages_donnees d),(SELECT jsonb_agg(to_jsonb(b)) FROM comptes_bancaires b),(SELECT count(*) FROM actions_tracables),(SELECT count(*) FROM pnj_ced_achats_recus))")
   return q.fetchone()[0]
  before=snap();q.execute("SET hg.uid=''");check(call(1)['raison']=='acteur_non_authentifie');check(snap()==before)
  q.execute("SET hg.uid='00000000-0000-4000-8000-000000000001'")
  for col,value in [('country','soviet'),('current_city','port'),('current_building','stade'),('current_room','ailleurs')]:
   q.execute(f'UPDATE personnages_donnees SET {col}=%s WHERE name=\'Fixture\' RETURNING '+col,(value,));before=snap()
   check(call(1)['raison']=='pas_sur_place');check(snap()==before)
   q.execute(f'UPDATE personnages_donnees SET {col}=%s WHERE name=\'Fixture\'',({'country':'republic','current_city':'capitale','current_building':'centre-artisanal','current_room':'travees'}[col],))
  r=call(1);check(r['ok'] and not r['rejeu']);check(r['paiement']['liquide']==20 and r['paiement']['solde_national']==200)
  check(r['inventory'][0]['name']=='Boulette de shit' and r['inventory'][0]['legal'] is False);check(r['revision']==1)
  before=snap();check(call(1)['rejeu']);check(snap()==before)
  r=call(2);check(r['paiement']['liquide']==0 and r['paiement']['solde_national']==170)
  check(len(r['inventory'])==2 and r['revision']==2 and r['paiement']['pa']==30)
  q.execute("SELECT type_action,cible FROM actions_tracables ORDER BY id");check(q.fetchall()==[('achat_drogue',"Céd' Labone")]*2)
  # Rejouer hors du lieu ne rachete rien et rend l'inventaire actuel, pas le vieux recu.
  q.execute("UPDATE personnages_donnees SET current_building='ailleurs' WHERE name='Fixture'");before=snap()
  check(len(call(1)['inventory'])==2);check(snap()==before)
  q.execute("UPDATE personnages_donnees SET current_building='centre-artisanal',inventory='[{\"qty\":100}]' WHERE name='Fixture'");before=snap()
  check(call(3)['raison']=='inventaire_plein');check(snap()==before)
  q.execute("UPDATE personnages_donnees SET inventory='[]',liquide=0 WHERE name='Fixture';UPDATE comptes_bancaires SET solde=49 WHERE personnage='Fixture'");before=snap()
  check(call(3)['raison']=='fonds_insuffisants');check(snap()==before)
  q.execute("UPDATE comptes_bancaires SET solde=200 WHERE personnage='Fixture'")
  # Toutes les ecritures et le debit s'annulent si la preuve ou le recu echoue.
  for table in ['actions_tracables','pnj_ced_achats_recus']:
   q.execute(f"CREATE FUNCTION panne_ced() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'panne_test';END $$;CREATE TRIGGER panne BEFORE INSERT ON {table} FOR EACH ROW EXECUTE FUNCTION panne_ced()")
   before=snap()
   try:call(3);raise AssertionError('panne attendue')
   except psycopg2.Error as exc:check('panne_test' in str(exc))
   check(snap()==before);q.execute(f'DROP TRIGGER panne ON {table};DROP FUNCTION panne_ced()')
  def parallel(k):
   with psycopg2.connect(uri) as cc:
    qq=cc.cursor();qq.execute("SET hg.uid='00000000-0000-4000-8000-000000000001';SET request.path='/rpc/pnj_ced_acheter'")
    return call(k,qq)
  with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(parallel,[4,4]))
  check(all(x['ok'] for x in rs));check(sum(x['rejeu'] for x in rs)==1)
  q.execute("SELECT count(*) FROM actions_tracables");check(q.fetchone()[0]==3)
  q.execute("SELECT solde FROM comptes_bancaires WHERE personnage='Fixture'");check(q.fetchone()[0]==150)
  q.execute("SELECT has_function_privilege('anon','pnj_ced_acheter(uuid)','EXECUTE'),has_table_privilege('authenticated','pnj_ced_achats_recus','SELECT')");check(q.fetchone()==(False,False))
  # Jour personnel deliberement fige a 1 : les deux entrainements d'hier ne bloquent pas.
  q.execute("INSERT INTO entrainements_football VALUES('hier1','Fixture',1,'defense',((now() AT TIME ZONE 'Europe/Paris')::date-1)::timestamp AT TIME ZONE 'Europe/Paris'),('hier2','Fixture',1,'technique',((now() AT TIME ZONE 'Europe/Paris')::date-1)::timestamp AT TIME ZONE 'Europe/Paris')")
  q.execute('SELECT football_entrainements_du_jour()');check(q.fetchone()[0]['nb']==0)
  q.execute("SELECT football_entrainement_consommer('defense')");check(q.fetchone()[0]['nb']==1)
  # Dormir/changer day au milieu de la journee ne redonne pas un quota.
  q.execute("UPDATE personnages_donnees SET day=900 WHERE name='Fixture'")
  q.execute('SELECT football_entrainements_du_jour()');check(q.fetchone()[0]['nb']==1)
  q.execute("SELECT football_entrainement_consommer('endurance')");check(q.fetchone()[0]['nb']==2)
  q.execute("SELECT football_entrainement_consommer('technique')");check(q.fetchone()[0]['raison']=='limite_quotidienne_atteinte')
  q.execute("SELECT pa FROM personnages_donnees WHERE name='Fixture'");check(q.fetchone()[0]==26)
  # Trois tentatives simultanees avec une seule place restante : une seule consomme 2 PA.
  q.execute("DELETE FROM entrainements_football WHERE personnage='Fixture';INSERT INTO entrainements_football VALUES('deja','Fixture',1,'defense',now())")
  def sport(_):
   with psycopg2.connect(uri) as cc:
    qq=cc.cursor();qq.execute("SET hg.uid='00000000-0000-4000-8000-000000000001';SELECT football_entrainement_consommer('technique')")
    return qq.fetchone()[0]
  with ThreadPoolExecutor(max_workers=3) as pool:rs=list(pool.map(sport,range(3)))
  check(sum(x['ok'] for x in rs)==1)
  q.execute("SELECT pa FROM personnages_donnees WHERE name='Fixture'");check(q.fetchone()[0]==24)
  # Fenetres parisiennes exactes, y compris jour court/long aux changements d'heure.
  for date in ['2026-03-29','2026-10-25']:
   q.execute("DELETE FROM entrainements_football WHERE personnage='DST'")
   q.execute("INSERT INTO entrainements_football VALUES('dst0','DST',1,'defense',(%s::date::timestamp AT TIME ZONE 'Europe/Paris')-interval '1 microsecond'),('dst1','DST',1,'defense',%s::date::timestamp AT TIME ZONE 'Europe/Paris'),('dst2','DST',1,'defense',((%s::date+1)::timestamp AT TIME ZONE 'Europe/Paris')-interval '1 microsecond'),('dst3','DST',1,'defense',(%s::date+1)::timestamp AT TIME ZONE 'Europe/Paris')",[date]*4)
   q.execute('SELECT football_entrainements_compter_interne(%s,%s)',('DST',date));check(q.fetchone()[0]==2)
  q.execute("SELECT has_function_privilege('authenticated','football_entrainements_compter_interne(text,date)','EXECUTE')");check(q.fetchone()[0] is False)
  print(f'OK {n} assertions Ced/football, PostgreSQL natif jetable')
 finally:srv.cleanup()
if __name__=='__main__':main()
