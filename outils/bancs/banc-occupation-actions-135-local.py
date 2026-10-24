#!/usr/bin/env python3
"""Vrais moteurs PostgreSQL jetables : police et cadavres, aucun joueur reel."""
from pathlib import Path
import importlib.util,json,re
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('nego',R/'outils/bancs/banc-negociation-squatteurs-local.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,t):
  nonlocal n
  assert v,t;n+=1;print('OK occupation',t,flush=True)
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');x=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+x.end()]
 q.execute("CREATE ROLE service_role;ALTER TABLE personnages_donnees ADD COLUMN resources jsonb DEFAULT '{\"dis\":80}',ADD COLUMN hospitalisation jsonb,ADD COLUMN recherche jsonb DEFAULT '[]';ALTER TABLE pnj_membres ADD COLUMN car_dup integer DEFAULT 8;CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT current_setting('hg.serveur',true)='on'$$")
 s=(R/'baseline/domaines/justice/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public.detentions \(.*?\n\);',s,re.S)[0])
 q.execute(fn('baseline/domaines/justice/20_fonctions-1.sql','detention_active'));q.execute(fn('baseline/domaines/justice/20_fonctions-2.sql','recherche_inscrire'))
 q.execute("INSERT INTO ordres_couts VALUES('appeler_police_terrain',1,0),('faire_disparaitre_cadavre',2,0)")
 for f in ['20261024072349_occupation_actions_et_echeances.sql','20261024072634_occupation_commandes_transactionnelles.sql']:
  s=(R/'migrations'/f).read_text();q.execute(s);q.execute(s)
 def lire(s,args=(),cur=q):cur.execute(s,args);return cur.fetchone()[0]
 def reset(pnj='cadavre',version=100):
  q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='terrain-a-batir-1',hp=100,pa=50,resources='{\"dis\":80}',stats='{\"CHA\":13,\"DUP\":13}',stats_affaiblies='{}',excommunie=NULL,liquide=1000,arg=11000;UPDATE comptes_bancaires SET solde=10000;DELETE FROM pnj_employes_metier;DELETE FROM organisations")
  q.execute('UPDATE terrains_etat SET data=%s',(json.dumps({'city':'capitale','pnj':pnj,'dateGeneration':version,'surface':2150,'valeur_totale':25800,'actesIllegaux':[{'type':'crime_historique'}]}),))
 def contexte(action):return lire("SELECT terrain_occupation_action_preparer('terrain-a-batir-1',%s)",(action,))
 def acte(action,k,occupation=None,taux=None,cur=q):
  return lire("SELECT terrain_occupation_action('terrain-a-batir-1',%s,%s,%s,%s,%s)",(action,occupation or '100:cadavre',f'10000000-0000-4000-8000-{k:012d}',taux,190 if action=='corruption_police' else 0),cur)
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(b ORDER BY id) FROM comptes_bancaires b),(SELECT jsonb_agg(t ORDER BY id) FROM terrains_etat t),(SELECT count(*) FROM terrain_actions_recus))")
 def jet(v):q.execute('CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$ SELECT '+str(v)+' $$')
 reset();c=contexte('cadavre');check(c['taux']==40 and c['pa']==2,'taux historique calcule depuis ressources et groupe canoniques')
 jet(100);r=acte('cadavre',1,taux=c['taux']);check(r['ok'] and not r['succes'],'echec reel')
 p=lire("SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='Fixture'");check(p['pa']==48 and p['hp']==95 and p['resources']['dis']==60 and len(p['recherche'])==1,'PA et consequences judiciaires reunis')
 avant=photo();check(acte('cadavre',1,taux=40)['rejeu'] and photo()==avant,'reponse perdue aucun nouveau jet ni sanction')
 avant=photo();check(acte('cadavre',1,taux=41)['raison']=='requete_reutilisee' and photo()==avant,'UUID ne peut changer le taux')
 check(acte('police',1,taux=40)['raison']=='requete_reutilisee' and photo()==avant,'UUID ne peut changer l action')
 r=lire("SELECT terrain_occupation_action('terrain-a-batir-1','cadavre','100:cadavre','10000000-0000-4000-8000-000000000001',40,1)")
 check(r['raison']=='requete_reutilisee' and photo()==avant,'UUID ne peut changer le prix')
 reset();jet(1);r=acte('cadavre',2,taux=40);check(r['succes'] and r['etat']['pnj'] is None and len(r['etat']['actesIllegaux'])==2,'succes persiste et crime ancien conserve')
 avant=photo();check(acte('cadavre',3,taux=40)['raison']=='occupation_incompatible' and photo()==avant,'cadavre absent aucun debit')
 reset('squatter_cool');avant=photo();check(acte('cadavre',4,taux=40)['raison']=='occupation_incompatible' and photo()==avant,'ancien ordre cadavre ne touche pas les squatteurs')
 reset();avant=photo();check(acte('cadavre',5,occupation='99:cadavre',taux=40)['raison']=='occupation_modifiee' and photo()==avant,'version obsolete avant tout paiement')
 q.execute("UPDATE personnages_donnees SET current_city='ailleurs' WHERE name='Fixture'");avant=photo();check(acte('police',6)['raison']=='terrain_incoherent' and photo()==avant,'ville fausse refusee')
 reset('squatter_agr');q.execute("CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'aucun_jet_legal';END$$")
 r=acte('police',7,occupation='100:squatter_agr');check(r['succes'] and r['jet'] is None and r['taux'] is None,'police legale aucun jet')
 p=lire("SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='Fixture'");check(p['pa']==49 and p['liquide']==1000,'appel legal 1 PA et aucun argent')
 avant=photo();check(acte('police',7,occupation='100:squatter_agr')['rejeu'] and photo()==avant,'appel rejoue sans seconde echeance')
 check(acte('police',8,occupation='100:squatter_agr')['raison']=='intervention_en_cours','second appel refuse')
 q.execute("SET hg.serveur='on';UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{interventionPolice,echeance}',to_jsonb(extract(epoch FROM now())*1000-1000))::text")
 check(lire('SELECT terrain_police_echeances_traiter()')['interventions']==1,'echeance persistante consommee')
 e=lire('SELECT data::jsonb FROM terrains_etat');check(e['pnj'] is None and e['surface']==2150 and e['actesIllegaux']==[{'type':'crime_historique'}],'depart sans perte des caracteristiques ou crimes')
 avant=photo();check(lire('SELECT terrain_police_echeances_traiter()')['interventions']==0 and photo()==avant,'rejeu du calendrier sans effet')
 reset();r=acte('police',9);q.execute("SET hg.serveur='on';UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{interventionPolice,echeance}',to_jsonb(extract(epoch FROM now())*1000-1000))::text")
 lire('SELECT terrain_police_echeances_traiter()');e=lire('SELECT data::jsonb FROM terrains_etat');check(e['enqueteJusqua']>lire('SELECT extract(epoch FROM now())*1000')+2*86400000,'cadavre signale conserve les trois jours d enquete')
 reset('squatter_cool');jet(1);c=contexte('corruption_police');check(c['taux']==66 and c['cout']==190,'taux et cout historiques de corruption')
 avant=photo();check(acte('corruption_police',10,occupation='100:squatter_cool',taux=67)['raison']=='taux_modifie' and photo()==avant,'taux affiche obsolete refuse avant depense')
 r=acte('corruption_police',10,occupation='100:squatter_cool',taux=66);p=lire("SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='Fixture'");check(r['succes'] and p['liquide']==810 and p['pa']==49 and p['resources']['dis']==75,'soudoiement cout reel et effets atomiques')
 reset();jet(1);q.execute("CREATE FUNCTION panne_acte() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_recu';END$$;CREATE TRIGGER panne BEFORE INSERT ON terrain_actions_recus FOR EACH ROW EXECUTE FUNCTION panne_acte()")
 avant=photo()
 try:acte('cadavre',11,taux=40);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_recu' in str(ex),'panne injectee apres mutations')
 check(photo()==avant,'rollback PA, etat, sante, discretion, justice et recu');q.execute('DROP TRIGGER panne ON terrain_actions_recus')
 def concurrent(_):
  with psycopg2.connect(srv.get_uri()) as cc:return acte('cadavre',12,taux=40,cur=cc.cursor())
 with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(concurrent,[1,2]))
 check(all(r['ok'] for r in rr) and sum(bool(r.get('rejeu')) for r in rr)==1,'meme UUID concurrent un seul traitement')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==48,'un seul cout concurrent')
 check(lire("SELECT has_function_privilege('anon','terrain_occupation_action(text,text,text,uuid,numeric,integer)','EXECUTE')") is False,'anonyme ferme')
 check(lire("SELECT has_table_privilege('authenticated','terrain_actions_recus','INSERT')") is False,'recu prive')
 # Le lecteur ordinaire applique l'echeance lors d'une interaction, meme sans nouveau cron.
 q.execute('CREATE TABLE terrain_visites_actives(personnage_id uuid,terrain_id text,PRIMARY KEY(personnage_id,terrain_id))')
 q.execute(fn('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','terrain_occupation_lire'))
 q.execute(fn('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','terrain_occupation_tirer_interne'))
 sql=(R/'migrations/20261024072829_occupation_echeances_a_la_visite.sql').read_text();q.execute(sql);q.execute(sql)
 reset('squatter_cool',101);acte('police',20,occupation='101:squatter_cool')
 q.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{interventionPolice,echeance}',to_jsonb(extract(epoch FROM now())*1000-1000))::text")
 r=lire("SELECT terrain_occupation_lire('terrain-a-batir-1')");check(r['ok'] and r['etat']['pnj'] is None,'echeance traitee a la visite sans polling ni cron client')
 reset('squatter_cool',102);acte('police',21,occupation='102:squatter_cool')
 q.execute("UPDATE terrains_etat SET data=jsonb_set(jsonb_set(data::jsonb,'{interventionPolice,echeance}',to_jsonb(extract(epoch FROM now())*1000-1000)),'{pnj}','\"cadavre\"')::text")
 q.execute("SET hg.serveur='on'");lire('SELECT terrain_police_echeances_traiter()');e=lire('SELECT data::jsonb FROM terrains_etat');check(e['pnj']=='cadavre' and e['interventionPolice']['statut']=='occupation_modifiee','echeance obsolete ne retire jamais un nouvel occupant')
 reset('squatter_cool',103);jet(1)
 def deux(nom):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute('SET hg.acteur=%s',(nom,));return acte('police',22,occupation='103:squatter_cool',cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(deux,['Fixture','Autre']))
 check(sum(bool(r['ok']) for r in rr)==1 and sum(r.get('raison')=='intervention_en_cours' for r in rr)==1,'deux demandeurs un seul appel et aucun second cout')
 reset();q.execute("UPDATE personnages_donnees SET pa=0 WHERE name='Fixture'");avant=photo();check(acte('cadavre',23,taux=40)['raison']=='pa_insuffisants' and photo()==avant,'PA insuffisants aucune mutation')
 reset('squatter_cool');q.execute("UPDATE personnages_donnees SET liquide=0 WHERE name='Fixture';UPDATE comptes_bancaires SET solde=0 WHERE personnage='Fixture'");avant=photo();check(acte('corruption_police',24,occupation='100:squatter_cool',taux=66)['raison']=='fonds_insuffisants' and photo()==avant,'fonds insuffisants aucun PA perdu')
 reset();q.execute("UPDATE personnages_donnees SET stats='{\"CHA\":\"NaN\",\"DUP\":13}' WHERE name='Fixture'");avant=photo();check(acte('cadavre',25,taux=40)['raison']=='etat_personnage_invalide' and photo()==avant,'caracteristique non finie refusee avant PA ou jet')
 reset();q.execute("INSERT INTO pnj_membres VALUES('groupe-135','Fixture','Fixture','actif',9,8);INSERT INTO pnj_employes_metier VALUES('groupe-135')")
 check(contexte('cadavre')['taux']==39 and contexte('corruption_police')['taux']==62,'caracteristiques du groupe beta existant')
 q.execute("UPDATE personnages_donnees SET excommunie='{}',stats_affaiblies='{\"CHA\":true,\"DUP\":true}',hp=50 WHERE name='Fixture'")
 check(contexte('cadavre')['taux']==36 and contexte('corruption_police')['taux']==50,'excommunication et affaiblissement existants')
 q.execute("INSERT INTO organisations VALUES('crime-135','{\"type\":\"criminelle\",\"membres\":[{\"nom\":\"Fixture\",\"gradeIdx\":2}]}'),('loge-135','{\"type\":\"loge\",\"membres\":[{\"nom\":\"Fixture\",\"gradeIdx\":2}]}')")
 check(abs(contexte('cadavre')['taux']-(36+25/3))<1e-9,'meilleur palier par organisation et cumul existant')
 reset('squatter_cool');jet(100);r=acte('corruption_police',26,occupation='100:squatter_cool',taux=66);p=lire("SELECT to_jsonb(p) FROM personnages_donnees p WHERE name='Fixture'")
 check(not r['succes'] and p['pa']==49 and p['liquide']==810 and p['resources']['dis']==65 and r['etat']['pnj']=='squatter_cool','refus de corruption : cout historique, DIS -15 et aucun depart')
 reset('squatter_cool');q.execute("UPDATE personnages_donnees SET updated_at='2001-01-01' WHERE name='Fixture'");ancienne=lire("SELECT updated_at FROM personnages_donnees WHERE name='Fixture'")
 acte('police',27,occupation='100:squatter_cool')
 q.execute("UPDATE personnages_donnees SET pa=99 WHERE name='Fixture' AND updated_at=%s",(ancienne,));check(q.rowcount==0 and lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==49,'sauvegarde CAS anterieure ne restaure pas les PA de l appel legal')
 print(json.dumps({'occupation_actions':True,'assertions':n,'production':False}))
if __name__=='__main__':m.main(suite)
