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
 def q(s,a=()):
  c.execute(s,a);v=c.fetchone()[0];db.commit();return v
 def ok(v,t):
  nonlocal n
  assert v,t;n+=1;print('OK reamenagement',t,flush=True)
 for p in ['20261023090008_chantier_travailleur_et_client.sql','20261023090009_chantier_reamenagement_socle.sql','20261023090010_chantier_reamenagement_commandes.sql','20261023090011_chantier_reamenagement_jour_travail.sql']:
  c.execute((R/'migrations'/p).read_text());c.execute((R/'migrations'/p).read_text())
 c.execute("SET test.acteur='Alice';SET test.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='ream',hp=100,liquide=5000,arg=10000,pa=50;UPDATE comptes_bancaires SET solde=5000;UPDATE organisations SET data='{\"chef\":\"Chef\",\"caisse\":60000}'")
 lots=[{'id':'a','surface':600,'destination':'commerce','label':'Atelier','loyer':100,'locataire':None,'metadata':{'origine':'historique'}},{'id':'b','surface':600,'destination':'commerce','label':'Loué','loyer':240,'locataire':'Locataire','bailHistorique':'identite'}]
 etat={'city':'capitale','proprietaire':'Alice','surface':1600,'niveau_construction':'commerce_premium','subdivisions':lots,'planInitialValide':True}
 c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data,niveau_construction) VALUES('ream','republic','ream','Alice',%s,'commerce_premium')",(json.dumps(etat),))
 c.execute("INSERT INTO locations_actives(id,country,data) VALUES('bail-b','republic',%s)",(Json({'city':'capitale','buildingId':'ream','roomId':'lot_dyn_b','lotId':'b','locataire':'Locataire'}),))
 def cmd(req,plan=None,action='reamenager',cur=c,terrain='ream'):
  cur.execute('SELECT chantier_commande(%s,%s,%s,%s)',(req,terrain,action,Json({'lots':plan} if action=='reamenager' else {})));v=cur.fetchone()[0];cur.connection.commit();return v
 def photo():return q("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(b ORDER BY personnage,banque) FROM comptes_bancaires b),(SELECT jsonb_agg(t ORDER BY id) FROM terrains_etat t),(SELECT jsonb_agg(r ORDER BY requete) FROM chantier_commandes_recus r),(SELECT jsonb_agg(b ORDER BY id) FROM batiments_etat b),(SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c))")
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
 c.execute("CREATE FUNCTION panne_reception_ream() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.requete='ch-ream-receptionX' THEN RAISE EXCEPTION 'panne_reception_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_reception_ream BEFORE INSERT ON chantier_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne_reception_ream()")
 avant=photo()
 try:cmd('ch-ream-receptionX',action='receptionner');raise AssertionError('panne attendue')
 except psycopg2.Error as e:db.rollback();assert 'panne_reception_fixture' in str(e)
 ok(photo()==avant,'panne apres restitution : caisse, stocks, locaux et recu annules')
 c.execute('DROP TRIGGER panne_reception_ream ON chantier_commandes_recus')
 r=cmd('ch-ream-reception2',action='receptionner');ok(r['ok'] and r['etat']['subdivisions'][0]['surface']==690 and not r['etat'].get('chantierReamenagement'),'reception et plan actifs atomiquement')
 ok(r['etat']['subdivisions'][1]['loyer']==250 and r['etat']['subdivisions'][1]['locataire']=='Locataire','modification legitime du lot non touche conservee')
 ok(r['etat']['niveau_construction']=='commerce_premium' and r['etat']['proprietaire']=='Alice','palier et titre immobilier preserves')
 avant=photo();ok(cmd('ch-ream-reception2',action='receptionner')['rejeu'] and photo()==avant,'reception rejouee sans second reliquat')
 # Nouveau chantier de fixture independant : absence de melange avec le cas receptionne.
 copie=r['etat'];copie['subdivisions'][1]['locataire']=None
 c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data,niveau_construction) VALUES('ream-concurrent','republic','ream-concurrent','Alice',%s,'commerce_premium')",(json.dumps(copie),))
 c.execute("UPDATE personnages_donnees SET current_building='ream-concurrent',liquide=5000,arg=10000;UPDATE comptes_bancaires SET solde=5000")
 plan=[dict(copie['subdivisions'][0],surface=780),copie['subdivisions'][1]]
 c.execute("CREATE FUNCTION panne_lancement_ream() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.requete='ch-ream-lancepanne' THEN RAISE EXCEPTION 'panne_lancement_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_lancement_ream BEFORE INSERT ON chantier_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne_lancement_ream()")
 avant=photo()
 try:cmd('ch-ream-lancepanne',plan,terrain='ream-concurrent');raise AssertionError('panne attendue')
 except psycopg2.Error as e:db.rollback();assert 'panne_lancement_fixture' in str(e)
 photo_apres=photo()
 ok(photo_apres==avant,'panne apres debit : fonds, chantier et recu annules')
 c.execute('DROP TRIGGER panne_lancement_ream ON chantier_commandes_recus')
 c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{subdivisions,0,proprietaire}',to_jsonb('Autre'::text))::text WHERE id='ream-concurrent'")
 avant=photo();refus=cmd('ch-ream-lotvendu01',plan,terrain='ream-concurrent');ok(refus.get('raison')=='lot_vendu' and photo()==avant,'lot dont le titre appartient a autrui refuse')
 c.execute("UPDATE terrains_etat SET data=(data::jsonb #- '{subdivisions,0,proprietaire}')::text WHERE id='ream-concurrent'");db.commit()
 def concurrent(_):
  with psycopg2.connect(server.get_uri()) as d:
   cc=d.cursor();cc.execute("SET test.acteur='Alice';SET test.serveur='off'");return cmd('ch-ream-concurrent1',plan,cur=cc,terrain='ream-concurrent')
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,range(2)))
 ok(all(x['ok'] for x in rs) and sum(bool(x.get('rejeu')) for x in rs)==1,'lancements concurrents : un seul debit et un recu')
 ok(q('SELECT solde FROM comptes_bancaires')==4100 and q('SELECT liquide FROM personnages_donnees')==5000,'900 FR debites une seule fois, liquide preserve')
 avant=photo();refus=cmd('ch-ream-concurrent1',[dict(plan[0],surface=790),plan[1]],terrain='ream-concurrent');ok(refus.get('raison')=='requete_reutilisee' and photo()==avant,'recu non reutilisable pour un autre plan')
 c.execute("UPDATE personnages_donnees SET current_building='ream'");db.commit()
 print(json.dumps({'reamenagement':True,'assertions':n,'production':False}))
 if apres:apres(db,server)
if __name__=='__main__':m.main(suite)
