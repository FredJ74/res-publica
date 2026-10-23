#!/usr/bin/env python3
"""Travail d'un tiers, vrai moteur financier et recus, PostgreSQL jetable."""
import importlib.util,json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('construction',(R/'outils/bancs/banc-construction-jour-local.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def suite(db,server):
 from psycopg2.extras import Json
 import psycopg2
 c=db.cursor();n=0
 def q(s,a=()):
  c.execute(s,a);v=c.fetchone()[0];db.commit();return v
 def ok(v,t):
  nonlocal n
  assert v,t;n+=1;print('OK travailleur',t)
 sql=(R/'migrations/20261023083000_chantier_travailleur_et_client.sql').read_text();c.execute(sql);c.execute(sql)
 c.execute("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='tiers',pa=50;SET test.acteur='Alice';SET test.serveur='off'")
 c.execute("UPDATE organisations SET data='{\"chef\":\"Chef\",\"caisse\":60000}'")
 etat={'city':'capitale','proprietaire':'orga:orga','surface':777,'chantier':{'type':'construction','niveau':'hangar','dureeJours':6,'coutTotal':30000,'coutTravail':21000,'totalVerse':30000,'tresorerie':10000,'progressionJours':0,'heuresFaites':0,'stockMateriaux':{'bois':1000,'minerai':1000,'metal':1000}}}
 c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('tiers','republic','tiers','orga:orga',%s)",(json.dumps(etat),))
 def cmd(req,action='travailler',params={'heures':'2'},cur=c):
  cur.execute('SELECT chantier_commande(%s,%s,%s,%s)',(req,'tiers',action,Json(params)));return cur.fetchone()[0]
 avant=q('SELECT jsonb_build_array(pa,liquide) FROM personnages_donnees');r=cmd('ch-travail-tiers0001');ok(r['ok'] and r['montant']==140,'tiers non proprietaire remunere')
 apres=q('SELECT jsonb_build_array(pa,liquide) FROM personnages_donnees');ok(apres==[avant[0]-2,avant[1]+140],'PA et salaire atomiques')
 r=cmd('ch-travail-tiers0001');ok(r['rejeu'] and q('SELECT jsonb_build_array(pa,liquide) FROM personnages_donnees')==apres,'rejeu aucune repetition')
 ok(cmd('ch-prix-tiers0001','prix',{'prix':{'bois':'1'}})['raison']=='representation_organisation_refusee','tiers ne gere pas les prix')
 c.execute("UPDATE personnages_donnees SET current_building='ailleurs'");ok(cmd('ch-travail-loin0001')['raison']=='pas_sur_place','distance refusee');c.execute("UPDATE personnages_donnees SET current_building='tiers',hp=0")
 ok(cmd('ch-travail-coma0001')['raison']=='acteur_incapacite','coma avant depense');c.execute('UPDATE personnages_donnees SET hp=100')
 def appel(_):
  with psycopg2.connect(server.get_uri()) as d:
   cc=d.cursor();cc.execute("SET test.acteur='Alice';SET test.serveur='off'");return cmd('ch-travail-concur01',cur=cc)
 db.commit()
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(appel,range(2)))
 ok(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'concurrence une execution')
 c.execute("CREATE FUNCTION panne_travail() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.requete='ch-travail-panne001' THEN RAISE EXCEPTION 'panne_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_travail BEFORE INSERT ON chantier_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne_travail()")
 avant=q("SELECT jsonb_build_array((SELECT jsonb_agg(p) FROM personnages_donnees p),(SELECT data FROM terrains_etat WHERE id='tiers'))")
 try:cmd('ch-travail-panne001');raise AssertionError('panne attendue')
 except psycopg2.Error as e:db.rollback();assert 'panne_fixture' in str(e)
 ok(q("SELECT jsonb_build_array((SELECT jsonb_agg(p) FROM personnages_donnees p),(SELECT data FROM terrains_etat WHERE id='tiers'))")==avant,'panne recu annule salaire PA chantier')
 c.execute("SELECT has_function_privilege('authenticated','chantier_travailler(text,text,text,integer)','EXECUTE')");ok(not c.fetchone()[0],'ancienne RPC reste fermee')
 print(json.dumps({'travailleur_tiers':True,'assertions':n,'production':False}))
if __name__=='__main__':m.main(suite)
