#!/usr/bin/env python3
"""Vol immédiat, mêmes paliers et butin réel, sur identités fictives."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,re,json,uuid,subprocess,sys
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
spec=importlib.util.spec_from_file_location('arme',R/'outils/bancs/banc-arme-clandestine-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
def suite(db,q,srv):
 import psycopg2
 from psycopg2.extras import Json
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK vol ordinaire',msg,flush=True)
 def lire(s,args=(),cur=q):cur.execute(s,args or None);return cur.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS pop integer DEFAULT 50')
 q.execute(fn('baseline/domaines/socle/20_fonctions.sql','inventaire_retirer_position'))
 for m in ['migrations/20261025014001_vol_pnj_referentiel.sql','migrations/20261025014101_vol_commande_transactionnelle.sql']:q.execute((R/m).read_text());q.execute((R/m).read_text())
 if MUTANT:
  avant,apres={
   'rejeu':('IF FOUND THEN\n  IF ancien.cible','IF FOUND AND false THEN\n  IF ancien.cible'),
   'genre':("IF p_genre='argent' THEN","IF true THEN"),
   'retrait':('SET inventory=nouvel_inv,updated_at=clock_timestamp() WHERE id=v.id','SET inventory=inventory,updated_at=clock_timestamp() WHERE id=v.id')
  }[MUTANT]
  d=lire("SELECT pg_get_functiondef('vol_commande(text,text,uuid)'::regprocedure)");assert d.count(avant)==1;q.execute(d.replace(avant,apres))
 def hasard(x):q.execute(f'CREATE OR REPLACE FUNCTION vol_hasard_interne() RETURNS numeric LANGUAGE sql AS $$SELECT {x}$$')
 def position():q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='armurerie',current_room='magasin',hp=100,pa=50,liquide=1000,arg=1000,stats='{\"PER\":9,\"CHA\":9}',career='neutre',inventory='[]',pop=50 WHERE name='Fixture';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='armurerie',current_room='magasin',hp=100,liquide=500,arg=500,stats='{\"PER\":9,\"INT\":9}',inventory='[]' WHERE name='Autre';UPDATE comptes_bancaires SET solde=0;UPDATE indices_villes SET data=data||'{\"isn\":0}' WHERE id='republic_capitale'")
 def appel(k,genre='argent',cible='Autre',cur=q):return lire('SELECT vol_commande(%s,%s,%s)',(cible,genre,f'f0000000-0000-4000-8000-{k:012d}'),cur)
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(b ORDER BY id) FROM comptes_bancaires b),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM vols_commandes_recus r),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c),(SELECT count(*) FROM objets_recus),(SELECT count(*) FROM inventaire_livraisons_recues),(SELECT count(*) FROM actions_tracables),(SELECT count(*) FROM courrier_fixture))")
 position();lire("SELECT religion_benediction_consommer_interne(id,'fixture_initialisation',gen_random_uuid()) FROM personnages_donnees WHERE name='Fixture'")
 for k,h,palier,score in [(1,0,'identifie',25),(2,.48,'identifie',49),(3,.5,'anonyme',50),(4,.98,'anonyme',74),(5,.9999,'discret',75)]:
  position();hasard(h);courriers=lire('SELECT count(*) FROM courrier_fixture');r=appel(k)
  check(r['ok'] and r['score']==score and r['palier']==palier,'borne exacte '+str(score)+' '+palier)
  total=lire("SELECT sum(liquide)+(SELECT sum(solde) FROM comptes_bancaires) FROM personnages_donnees WHERE name IN('Fixture','Autre')")
  check(total==1500 and r['montant']>=50 and r['montant']<=199 and r['pa']==48,'conservation de la monnaie et deux PA au palier '+str(score))
  check(lire('SELECT count(*) FROM courrier_fixture')==courriers+(0 if score>=75 else 1),'connaissance de la victime sans fuite au palier '+str(score))
 avant=photo();check(appel(5)['rejeu'] and photo()==avant,'reponse perdue ne retire ni ne credite une seconde fois')
 check(appel(5,'objet')['raison']=='requete_reutilisee' and photo()==avant,'genre lie au recu et non modifiable au rejeu')
 position();hasard(0);q.execute("UPDATE personnages_donnees SET stats='{\"PER\":10,\"INT\":9}' WHERE name='Autre'");r=appel(6)
 check(r['ok'] and not r['succes'] and r['score']==24 and r['amende']==300 and r['liquide']==700,'echec complet sanction republicaine et aucun butin')
 position();hasard(.9999);q.execute("UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name='Autre'");r=appel(7)
 check(r['ok'] and r['butin']=='rien' and r['montant']==0,'absence argent ne donne jamais un objet de remplacement')
 position();q.execute("UPDATE personnages_donnees SET inventory='[{\"id\":\"acte-fixture\",\"type\":\"acte_officiel\"},{\"id\":\"colis-fixture\",\"type\":\"colis_secret_pat\"}]' WHERE name='Autre'");r=appel(8,'objet')
 check(r['ok'] and r['butin']=='rien' and r['montant']==0,'objets proteges exclus sans repli vers argent')
 position();obj={'id':'arme-victime-fixture','type':'arme','name':'Arme fixture','legal':True,'bonus':{'stat':'PER','val':8},'memoire':{'cle':'conservee'}};q.execute("UPDATE personnages_donnees SET inventory=%s WHERE name='Autre'",(Json([obj]),));ancienne_revision=lire("SELECT inventory_revision FROM personnages_donnees WHERE name='Autre'");r=appel(9,'objet')
 check(r['ok'] and r['butin']=='objet' and r['objet']==obj and lire("SELECT inventory FROM personnages_donnees WHERE name='Autre'")==[],'transfert immediat objet conserve id et toutes metadonnees')
 check(r['inventaire']['inventory']==[obj] and lire("SELECT inventory_revision FROM personnages_donnees WHERE name='Autre'")==ancienne_revision+1,'recepteur versionne et revision victime avancee')
 q.execute("SET hg.acteur='Autre'");r2=lire('SELECT inventaire_sauver_revision(%s,%s,%s)',('Autre',ancienne_revision,Json([obj])))
 check(r2.get('raison')=='inventaire_perime' and lire("SELECT inventory FROM personnages_donnees WHERE name='Autre'")==[],'ancienne sauvegarde ne ressuscite pas l objet vole');q.execute("SET hg.acteur='Fixture'")
 position();lot1={'id':'lot-a','stackable':True,'stackKey':'bois','qty':100,'name':'Bois','memoire':'a'};lot2={**lot1,'id':'lot-b','qty':200,'memoire':'b'};q.execute("UPDATE personnages_donnees SET inventory=%s WHERE name='Autre'",(Json([lot1,lot2]),));r=appel(10,'objet');inv=lire("SELECT inventory FROM personnages_donnees WHERE name='Autre'")
 check(sum(x['qty'] for x in inv)+r['quantite']==300 and len(inv)==2,'un seul lot choisi debite meme si deux piles partagent la cle')
 check(all(x['memoire']==('a' if x['id']=='lot-a' else 'b') for x in inv),'metadonnees des deux lots preservees')
 position();q.execute("UPDATE personnages_donnees SET current_room='autre' WHERE name='Autre'");avant=photo();check(appel(11)['raison']=='cible_absente' and photo()==avant,'cible distante refusee sans PA ni bonus')
 position();hasard(.9999);q.execute("CREATE FUNCTION panne_vol_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_vol_fixture';END$$;CREATE TRIGGER panne_vol_fixture BEFORE INSERT ON vols_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne_vol_fixture()");avant=photo()
 try:appel(11);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_vol_fixture' in str(ex) and photo()==avant,'panne finale annule le transfert des deux contreparties')
 q.execute('DROP TRIGGER panne_vol_fixture ON vols_commandes_recus')
 def concurrent(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(11,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,[0,1]))
 check(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'double commande un seul debit de chaque contrepartie')
 position();hasard('NULL::numeric');avant=photo()
 try:appel(12);raise AssertionError('hasard invalide accepte')
 except psycopg2.Error as ex:check('hasard_vol_invalide' in str(ex) and photo()==avant,'hasard absent annule paiement et bonus')
 # Pas de règle nouvelle pour les PNJ : l'ancien succès reste sans butin.
 position();hasard(.9999);q.execute("UPDATE personnages_donnees SET current_building='hotel-republica',current_room='accueil' WHERE name='Fixture'");r=appel(13,cible='Nathalie Ondor')
 check(r['ok'] and r['butin']=='rien' and r['montant']==0,'PNJ ambiance declare sur place sans monnaie inventee')
 q.execute("INSERT INTO pnj_membres(id,nom,pays,ville,building_id,room_id,statut) VALUES('pnj-vol-mobile','PNJ mobile fixture','republic','capitale','hotel-republica','accueil','actif')");r=appel(14,cible='PNJ mobile fixture');check(r['ok'] and r['butin']=='rien','PNJ du socle present par son vrai moteur de position')
 q.execute("UPDATE pnj_membres SET room_id='autre' WHERE id='pnj-vol-mobile'");avant=photo();check(appel(15,cible='PNJ mobile fixture')['raison']=='cible_absente' and photo()==avant,'position PNJ reelle prioritaire apres deplacement')
 for k,pays,amende,pop in [(16,'narco',500,50),(17,'soviet',100,40),(18,'khalija',0,50)]:
  position();hasard(0);q.execute("UPDATE personnages_donnees SET country=%s WHERE name IN('Fixture','Autre');UPDATE personnages_donnees SET stats='{\"PER\":10,\"INT\":9}' WHERE name='Autre';UPDATE terrain_actions_regles SET data=jsonb_set(data,ARRAY['indices',%s,'ISN'],'0',true) WHERE id",(pays,pays))
  # Les indices canoniques possèdent déjà les quatre clés (aucun indice local inventé).
  r=appel(k);check(r['ok'] and not r['succes'] and r['amende']==amende and r['pop']==pop,'sanction existante '+pays)
 position();hasard(.9999);q.execute("CREATE FUNCTION ignorer_vol_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN NULL;END$$")
 for table,evenement,condition in [('personnages_donnees','UPDATE',"NEW.name='Autre' AND NEW.liquide<OLD.liquide"),('personnages_donnees','UPDATE',"NEW.name='Fixture' AND NEW.liquide>OLD.liquide"),('actions_tracables','INSERT',"NEW.type_action='vol'"),('vols_commandes_recus','INSERT','true')]:
  q.execute(f'CREATE TRIGGER ignorer_vol_fixture BEFORE {evenement} ON {table} FOR EACH ROW WHEN ({condition}) EXECUTE FUNCTION ignorer_vol_fixture()');avant=photo()
  try:appel(19);raise AssertionError('ecriture ignoree acceptee')
  except psycopg2.Error:check(photo()==avant,'ecriture ignoree rollback complet '+table+' '+condition)
  q.execute(f'DROP TRIGGER ignorer_vol_fixture ON {table}')
 check(lire("SELECT has_function_privilege('authenticated','vol_commande(text,text,uuid)','EXECUTE')") is False,'hote non active avant verification complete')
 print(json.dumps({'vol_ordinaire':True,'assertions':n,'client_raccorde':False,'production':False,'protection_sauvegarde_financiere_vivante_non_verifiee':True}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.base.base.banque.m.main(tout)
