#!/usr/bin/env python3
"""Budget fixe valide : arrondis absorbes dans les quantites, sans apport supplementaire."""
import importlib.util,json,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('ream',R/'outils/bancs/banc-reamenagement-transactionnel-local.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
def controle(db,server):
 from psycopg2.extras import Json
 c=db.cursor()
 surfaces=list(range(1,1001))+[2999,3000,3001,9999,10000,100001]
 js="const fs=require('node:fs'),vm=require('node:vm'),c={};vm.createContext(c);vm.runInContext(fs.readFileSync('plateau-chantiers.js','utf8'),c);const surfaces=JSON.parse(fs.readFileSync(0,'utf8'));process.stdout.write(JSON.stringify(surfaces.map(s=>c.materiauxDuJourReamenagement({coutMateriaux:s*3,dureeJours:Math.ceil(s/300)}))));"
 paniers_client=json.loads(subprocess.check_output(['node','-e',js],input=json.dumps(surfaces).encode(),cwd=R))
 for surface,client in zip(surfaces,paniers_client):
  duree=(surface+299)//300
  budget=surface*3
  c.execute("SELECT chantier_besoin_jour_interne(%s,1)",(Json({'type':'reamenagement','coutMateriaux':budget,'dureeJours':duree}),))
  panier=c.fetchone()[0]
  assert panier==client,(surface,panier,client)
  assert sum(panier[k]*p for k,p in [('bois',5),('minerai',10),('metal',15)])*duree<=budget,(surface,panier)
  assert all(v>=0 and int(v)==v for v in panier.values())
 print('OK parite client/SQL et paniers bornes : 1006 superficies',flush=True)
 c.execute("SET test.acteur='Alice';SET test.serveur='off';UPDATE personnages_donnees SET liquide=5000,arg=10000;UPDATE comptes_bancaires SET solde=5000")
 c.execute("SELECT data::jsonb->'subdivisions' FROM terrains_etat WHERE id='ream'");lots=c.fetchone()[0];lots[0]['surface']+=100
 c.execute("SELECT chantier_commande('ch-ream-budget100','ream','reamenager',%s)",(Json({'lots':lots}),));r=c.fetchone()[0];assert r['ok'],r
 c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantierReamenagement,jourTraite}','null')::text WHERE id='ream';SET test.serveur='on'")
 c.execute("SELECT chantier_jour_traiter('ream')");r=c.fetchone()[0];ch=r['etat']['chantierReamenagement']
 print(json.dumps({'controle':'financement_100m2','coutAnnonce':ch['coutTotal'],'avance':ch['progressionJours'],'tresorerie':ch['tresorerie'],'evenements':ch['evenements'],'production':False}),flush=True)
 assert ch['progressionJours']==1,'Le financement annonce doit suffire.'
 # Parcours complet, petites surfaces et frontieres de journee, puis reception/rejeu.
 for surface in [1,2,99,101,300,601]:
  id='budget-'+str(surface)
  c.execute("SET test.serveur='off';UPDATE personnages_donnees SET liquide=100000,arg=200000;UPDATE comptes_bancaires SET solde=100000")
  c.execute("UPDATE personnages_donnees SET current_building=%s",(id,))
  etat={'city':'capitale','proprietaire':'Alice','surface':3000,'niveau_construction':'commerce_premium','subdivisions':[{'id':'a','surface':600,'destination':'commerce','loyer':10,'locataire':None}]}
  c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data,niveau_construction) VALUES(%s,'republic',%s,'Alice',%s,'commerce_premium')",(id,id,json.dumps(etat)))
  c.execute("SELECT chantier_commande(%s,%s,'reamenager',%s)",('ch-budget-start-'+str(surface),id,Json({'lots':[dict(etat['subdivisions'][0],surface=600+surface)]})))
  assert c.fetchone()[0]['ok'];db.commit()
  for jour in range((surface+299)//300):
   c.execute("SET test.serveur='on';UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantierReamenagement,jourTraite}','null')::text WHERE id=%s",(id,))
   c.execute('SELECT chantier_jour_traiter(%s)',(id,));r=c.fetchone()[0];assert r['ok'],r;db.commit()
   c.execute('SELECT chantier_jour_traiter(%s)',(id,));assert c.fetchone()[0]['rejeu'];db.commit()
  ch=r['etat']['chantierReamenagement'];assert ch['progressionJours']==ch['dureeJours'],(surface,ch)
  assert sum(e.get('coutPNJ',0) for e in ch['evenements'])==surface*7,(surface,ch)
  assert ch['tresorerie']>=0 and ch['totalVerse']==surface*10
  c.execute("SET test.serveur='off'")
  c.execute("SELECT chantier_commande(%s,%s,'receptionner','{}')",('ch-budget-end-'+str(surface),id));r=c.fetchone()[0];assert r['ok'],r;db.commit()
  assert r['etat']['subdivisions'][0]['surface']==600+surface
  c.execute("SELECT chantier_commande(%s,%s,'receptionner','{}')",('ch-budget-end-'+str(surface),id));assert c.fetchone()[0]['rejeu'];db.commit()
  print('OK financement, interruption, reception et rejeu',surface,flush=True)
if __name__=='__main__':b.m.main(lambda db,server:b.suite(db,server,controle))
