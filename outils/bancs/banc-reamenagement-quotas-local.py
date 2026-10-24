#!/usr/bin/env python3
"""Les quotas PNJ variables ne doivent pas laisser une fraction d'heure impossible a solder."""
import importlib.util,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('ream',R/'outils/bancs/banc-reamenagement-transactionnel-local.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
def verifier(db,server):
 from psycopg2.extras import Json
 c=db.cursor();n=0
 def q(s,a=()):c.execute(s,a);v=c.fetchone()[0];db.commit();return v
 def ok(v,t):
  nonlocal n
  assert v,t;n+=1;print('OK quota PNJ',t,flush=True)
 for p in sorted((R/'migrations').glob('*_chantier_quotas_pnj_francs_entiers.sql')):c.execute(p.read_text());c.execute(p.read_text())
 c.execute("SET test.acteur='Alice';SET test.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',hp=100,liquide=100000,arg=200000;UPDATE comptes_bancaires SET solde=100000");db.commit()
 def lancer(surface,id):
  c.execute("UPDATE personnages_donnees SET current_building=%s",(id,))
  etat={'city':'capitale','proprietaire':'Alice','surface':3000,'niveau_construction':'commerce_premium','subdivisions':[{'id':'a','surface':600,'destination':'commerce','loyer':10,'locataire':None}]}
  c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data,niveau_construction) VALUES(%s,'republic',%s,'Alice',%s,'commerce_premium')",(id,id,json.dumps(etat)));db.commit()
  r=q("SELECT chantier_commande(%s,%s,'reamenager',%s)",('ch-quota-'+id,id,Json({'lots':[{'id':'a','surface':600+surface,'destination':'commerce'}]})));assert r['ok'],r
 def jour(id):
  c.execute("SET test.serveur='on';UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantierReamenagement,jourTraite}','null')::text WHERE id=%s",(id,));db.commit();return q('SELECT chantier_jour_traiter(%s)',(id,))
 lancer(102,'quota102');r=jour('quota102');ch=r['etat']['chantierReamenagement'];print(json.dumps({'surface':102,'progression':ch['progressionJours'],'tresorerie':ch['tresorerie'],'production':False}),flush=True)
 ok(ch['progressionJours']==1,'102 m2 achevables en un jour avec 714 FR de travail, sans PA fractionnaire')
 ok(sum(e.get('coutPNJ',0) for e in ch['evenements'])==714,'cout du travail exact et entier')
 avant=q("SELECT data::jsonb FROM terrains_etat WHERE id='quota102'");ok(q("SELECT chantier_jour_traiter('quota102')")['rejeu'] and q("SELECT data::jsonb FROM terrains_etat WHERE id='quota102'")==avant,'jour rejoue aucun second salaire')
 c.execute("SET test.serveur='off'");lancer(301,'quota301');r=jour('quota301');ok(r['etat']['chantierReamenagement']['progressionJours']==1,'premiere journee ne depasse pas un jour utile')
 r=jour('quota301');ch=r['etat']['chantierReamenagement'];ok(ch['progressionJours']==2,'301 m2 en deux jours, reliquat de salaire solde')
 ok(sum(e.get('coutPNJ',0) for e in ch['evenements'])==2107,'70 pour cent du prix total, aucune monnaie creee')
 ok(all(e.get('coutPNJ',0)==int(e.get('coutPNJ',0)) for e in ch['evenements']),'tous les paiements PNJ restent en francs entiers')
 c.execute("SET test.serveur='off'");lancer(200,'quota-pj')
 c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantierReamenagement,stockMateriaux}','{\"bois\":1000,\"minerai\":1000,\"metal\":1000}')::text WHERE id='quota-pj'");db.commit()
 avant=q("SELECT jsonb_build_array(pa,liquide) FROM personnages_donnees WHERE name='Alice'")
 r=q("SELECT chantier_commande('ch-quota-travailpj','quota-pj','travailler','{\"heures\":\"3\"}')")
 ok(r['ok'] and r['montant']==210 and r['etat']['chantierReamenagement']['progressionJours']==0,'travail PJ : 3 PA, 210 FR, aucune avance du temps')
 r=jour('quota-pj');ch=r['etat']['chantierReamenagement'];ok(ch['progressionJours']==1 and ch['evenements'][-1]['coutPNJ']==1190,'PJ remplace les PNJ, salaire total du chantier inchange')
 ok(q("SELECT jsonb_build_array(pa,liquide) FROM personnages_donnees WHERE name='Alice'")==[avant[0]-3,avant[1]+210],'aucun PA ou salaire PJ supplementaire au cron')
 print(json.dumps({'quotas_pnj':True,'assertions':n,'production':False}))
if __name__=='__main__':b.m.main(lambda db,server:b.suite(db,server,verifier))
