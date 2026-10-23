#!/usr/bin/env python3
"""Extension du meme moteur construction, vrai financeur et approvisionnement locaux."""
import importlib.util,json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('construction',R/'outils/bancs/banc-construction-jour-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def suite(db,server,apres=None):
 import psycopg2
 from psycopg2.extras import Json
 c=db.cursor();n=0
 def q(s,a=()):c.execute(s,a);return c.fetchone()[0]
 def ok(v,t):
  nonlocal n
  assert v,t;n+=1;print('OK reamenagement',t,flush=True)
 for p in ['20261023083000_chantier_travailleur_et_client.sql','20261023084000_chantier_reamenagement_socle.sql','20261023084001_chantier_reamenagement_commandes.sql','20261023084002_chantier_reamenagement_jour_travail.sql']:
  c.execute((R/'migrations'/p).read_text());c.execute((R/'migrations'/p).read_text())
 c.execute("SET test.acteur='Alice';SET test.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='ream',hp=100,liquide=5000,arg=10000,pa=50;UPDATE comptes_bancaires SET solde=5000;UPDATE organisations SET data='{\"chef\":\"Chef\",\"caisse\":60000}'")
 lots=[{'id':'a','surface':600,'destination':'commerce','label':'Atelier','loyer':100,'locataire':None,'metadata':{'origine':'historique'}},{'id':'b','surface':600,'destination':'commerce','label':'Loué','loyer':240,'locataire':'Locataire','bailHistorique':'identite'}]
 etat={'city':'capitale','proprietaire':'Alice','surface':1600,'niveau_construction':'commerce_premium','subdivisions':lots,'planInitialValide':True}
 c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data,niveau_construction) VALUES('ream','republic','ream','Alice',%s,'commerce_premium')",(json.dumps(etat),))
 c.execute("INSERT INTO locations_actives(id,country,data) VALUES('bail-b','republic',%s)",(Json({'city':'capitale','buildingId':'ream','roomId':'lot_dyn_b','lotId':'b','locataire':'Locataire'}),))
 def cmd(req,plan=None,action='reamenager',cur=c):
  cur.execute('SELECT chantier_commande(%s,%s,%s,%s)',(req,'ream',action,Json({'lots':plan} if action=='reamenager' else {})));return cur.fetchone()[0]
 def photo():return q("SELECT jsonb_build_array((SELECT jsonb_agg(p) FROM personnages_donnees p),(SELECT jsonb_agg(b) FROM comptes_bancaires b),(SELECT jsonb_agg(t) FROM terrains_etat t),(SELECT jsonb_agg(r) FROM chantier_commandes_recus r))")
 cible=[dict(lots[0],surface=690,locataire='Usurpateur',loyer=1),lots[1]]
 avant=photo();r=cmd('ch-ream-occupe0001',[lots[0],dict(lots[1],surface=690)]);ok(not r['ok'] and r['raison']=='local_occupe' and photo()==avant,'lot loue protege avant paiement')
 avant=photo();r=cmd('ch-ream-surface001',[dict(lots[0],surface=2000),lots[1]]);ok(not r['ok'] and photo()==avant,'surface excedentaire refusee')
 c.execute('UPDATE comptes_bancaires SET solde=500;UPDATE personnages_donnees SET liquide=100,arg=600');avant=photo();r=cmd('ch-ream-pauvre0001',cible);ok(r['raison']=='fonds_insuffisants' and photo()==avant,'aucun debit partiel ni chantier si manque')
 c.execute('UPDATE comptes_bancaires SET solde=800;UPDATE personnages_donnees SET liquide=500,arg=1300')
 r=cmd('ch-ream-lance0001',cible);ok(r['ok'],'lancement par moteur commun');ch=r['etat']['chantierReamenagement'];ok(ch['coutTotal']==900 and ch['dureeJours']==1 and ch['totalVerse']==900,'90 m2 : 10 FR m2, jour incompressible, tout finance')
 ok(q('SELECT solde FROM comptes_bancaires')==0 and q('SELECT liquide FROM personnages_donnees')==400,'banque prioritaire puis liquide')
 ok(ch['planCible'][0]['locataire'] is None and ch['planCible'][0]['loyer']==100 and ch['planCible'][1]['bailHistorique']=='identite','metadonnees serveur preservees, faux locataire ignore')
 avant=photo();ok(cmd('ch-ream-lance0001',cible)['rejeu'] and photo()==avant,'reponse perdue aucun second debit')
 avant=photo();ok(not cmd('ch-ream-encore0001',cible)['ok'] and photo()==avant,'second lancement refuse')
 avant=photo();ok(cmd('ch-ream-reception1',action='receptionner')['raison']=='chantier_non_acheve' and photo()==avant,'reception anticipee refusee')
 # Aucun ordre de navigation ni aucun jour fictif d'un joueur reel : horloge locale remise.
 c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantierReamenagement,jourTraite}','null')::text WHERE id='ream';SET test.serveur='on'")
 r=q("SELECT chantier_jour_traiter('ream')");ok(r['ok'] and r['etat']['chantierReamenagement']['progressionJours']==1,'approvisionnement et travail PNJ par jour commun')
 ok(r['etat']['subdivisions'][0]['surface']==600,'aucun local active avant reception');avant=photo();ok(q("SELECT chantier_jour_traiter('ream')")['rejeu'] and photo()==avant,'jour rejoue sans nouvelle progression')
 c.execute("SET test.serveur='off';UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{subdivisions,1,loyer}','250')::text WHERE id='ream'")
 r=cmd('ch-ream-reception2',action='receptionner');ok(r['ok'] and r['etat']['subdivisions'][0]['surface']==690 and not r['etat'].get('chantierReamenagement'),'reception et plan actifs atomiquement')
 ok(r['etat']['subdivisions'][1]['loyer']==250 and r['etat']['subdivisions'][1]['locataire']=='Locataire','modification legitime du lot non touche conservee')
 ok(r['etat']['niveau_construction']=='commerce_premium' and r['etat']['proprietaire']=='Alice','palier et titre immobilier preserves')
 avant=photo();ok(cmd('ch-ream-reception2',action='receptionner')['rejeu'] and photo()==avant,'reception rejouee sans second reliquat')
 print(json.dumps({'reamenagement':True,'assertions':n,'production':False}))
 if apres:apres(db,server)
if __name__=='__main__':m.main(suite)
