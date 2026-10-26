#!/usr/bin/env python3
"""Salaire actuel et commande commune ; PostgreSQL jetable, pas de joueur réel."""
from pathlib import Path
import importlib.util,json
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('jour',R/'outils/bancs/banc-construction-jour-local.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
def suite(db,c,serveur):
 import psycopg2
 from psycopg2.extras import Json
 n=0
 def check(v,message):
  nonlocal n
  assert v,message;n+=1;print('OK salaire commun',message,flush=True)
 def lire(sql,args=(),cur=c):cur.execute(sql,args);return cur.fetchone()[0]
 # Migration actuelle de Claude, non remplacée et exécutée uniquement dans la base jetable.
 sql=(R/'migrations/20261025070000_chantier_taux_horaire.sql').read_text();c.execute(sql);c.execute(sql)
 c.execute("SET test.acteur='Alice';SET test.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='salaire135',pa=50,hp=100 WHERE name='Alice'")
 chantier={'type':'construction','niveau':'hangar','dureeJours':6,'progressionJours':0,'coutTotal':30000,'coutTravail':21000,'totalVerse':30000,'tresorerie':5000,'heuresFaites':0,'stockMateriaux':{'bois':1000,'minerai':1000,'metal':1000}}
 etat={'city':'capitale','proprietaire':'Alice','surface':2150,'chantier':chantier}
 c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('republic_salaire135','republic','salaire135','Alice',%s)",(json.dumps(etat),))
 c.execute("INSERT INTO personnages_donnees(name,country,current_city,current_building,pa,hp,arg,liquide) VALUES('Ouvrier fixture','republic','capitale','salaire135',50,100,1000,1000)")
 def cmd(k,action,params,cur=c):return lire('SELECT chantier_commande(%s,%s,%s,%s)',('ch-taux135-'+str(k),'salaire135',action,Json(params)),cur)
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT data FROM terrains_etat WHERE id='republic_salaire135'),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM chantier_commandes_recus r))")
 for k,taux in enumerate([49,0,'90.5',None],1):
  avant=photo();r=cmd('refus'+str(k),'taux',{'taux':taux});check(not r['ok'] and photo()==avant,'taux invalide refusé sans mutation '+str(taux))
 r=cmd('fixer','taux',{'taux':'90'});check(r['ok'] and r['etat']['chantier']['tauxHoraire']==90,'propriétaire fixe 90 FR par la commande existante')
 avant=photo();check(cmd('fixer','taux',{'taux':'90'}).get('rejeu') and photo()==avant,'réponse perdue du changement de taux sans deuxième écriture')
 c.execute("SET test.acteur='Ouvrier fixture'")
 avant=photo();r=cmd('tiersprix','taux',{'taux':'50'});check(not r['ok'] and photo()==avant,'ouvrier tiers ne peut pas fixer le salaire')
 pa,liq=lire("SELECT jsonb_build_array(pa,liquide) FROM personnages_donnees WHERE name='Ouvrier fixture'")
 r=cmd('travail','travailler',{'heures':'2'});check(r['ok'] and r['montant']==180,'ouvrier tiers payé au taux de 90 par le moteur commun')
 check(lire("SELECT jsonb_build_array(pa,liquide) FROM personnages_donnees WHERE name='Ouvrier fixture'")==[pa-2,liq+180],'salaire et deux PA atomiques')
 avant=photo();check(cmd('travail','travailler',{'heures':'2'}).get('rejeu') and photo()==avant,'rejeu aucun deuxième salaire ni coût')
 c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,tresorerie}','179')::text WHERE id='republic_salaire135'")
 r=cmd('borner','travailler',{'heures':'2'});check(r['ok'] and r['montant']==90,'179 FR de trésorerie bornent le travail à une heure au taux réel')
 avant=photo();check(not cmd('vide','travailler',{'heures':'1'})['ok'] and photo()==avant,'moins de 90 FR disponibles : aucun PA ou salaire perdu')
 c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,tresorerie}','1000')::text WHERE id='republic_salaire135'")
 def concurrent(_):
  with psycopg2.connect(serveur.get_uri()) as cc:
   q=cc.cursor();q.execute("SET test.acteur='Ouvrier fixture';SET test.serveur='off'");return cmd('concurrent','travailler',{'heures':'1'},cur=q)
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,[0,1]))
 check(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'deux appels concurrents un seul salaire')
 c.execute("CREATE FUNCTION panne_taux135() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.requete='ch-taux135-panne' THEN RAISE EXCEPTION 'panne_taux135';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_taux135 BEFORE INSERT ON chantier_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne_taux135()")
 avant=photo()
 try:cmd('panne','travailler',{'heures':'1'});raise AssertionError('panne attendue')
 except psycopg2.Error as e:check('panne_taux135' in str(e) and photo()==avant,'panne finale annule salaire PA trésorerie heures et reçu')
 c.execute('DROP TRIGGER panne_taux135 ON chantier_commandes_recus')
 check(not lire("SELECT has_function_privilege('authenticated','chantier_travailler(text,text,text,integer)','EXECUTE')"),'ancienne porte non versionnée toujours fermée')
 print(json.dumps({'assertions_salaire_commun':n,'production':False,'migrations_vivantes_non_verifiees':True,'lecture_bne_non_verifiee':'definition chantier_besoin_jour_interne non archivee sur main, aucun remplacement simule'}))
if __name__=='__main__':base.main(suite)
