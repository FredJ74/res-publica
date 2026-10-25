#!/usr/bin/env python3
"""Vol chantier : vraie réception versionnée, privé, aucun joueur réel."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,re,json,uuid,subprocess,sys
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
spec=importlib.util.spec_from_file_location('filature',R/'outils/bancs/banc-filature-benediction-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
MIGRATION='migrations/20261025000429_chantier_vol_transactionnel.sql'
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK vol chantier',msg,flush=True)
 def lire(sql,args=(),cur=q):cur.execute(sql,args or None);return cur.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 q.execute("ALTER TABLE personnages_donnees ADD COLUMN inventory jsonb DEFAULT '[]',ADD COLUMN reputation_criminelle integer DEFAULT 0,ADD COLUMN recherche jsonb DEFAULT '[]';ALTER TABLE indices_villes ADD COLUMN updated_at timestamptz;ALTER TABLE objets_recus ENABLE ROW LEVEL SECURITY")
 q.execute(fn('baseline/domaines/presse/20_fonctions.sql','tracts_reclamer_don'))
 q.execute((R/'migrations/20261016131932_reception_objets_atomique.sql').read_text())
 s=(R/'baseline/domaines/justice/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public.actions_tracables \(.*?\n\);',s,re.S)[0]);q.execute('ALTER TABLE actions_tracables ADD PRIMARY KEY(id)')
 s=(R/'baseline/domaines/economie/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public.chantiers_besoins_jour \(.*?\n\);',s,re.S)[0]);q.execute((R/'baseline/seeds/90_socle/chantiers_besoins_jour.sql').read_text())
 for f,nom in [('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','terrain_chantier_acte'),('baseline/domaines/politique-et-elections/20_fonctions.sql','indice_ville_ajuster_interne'),('baseline/domaines/justice/20_fonctions-2.sql','recherche_inscrire')]:q.execute(fn(f,nom))
 q.execute((R/MIGRATION).read_text());q.execute((R/MIGRATION).read_text())
 if MUTANT:
  d=lire("SELECT pg_get_functiondef('chantier_vol_commande(text,text,uuid)'::regprocedure)")
  avant,apres={
   'butin_double':("'qty',quantite,'desc'","'qty',quantite*2,'desc'"),
   'bonus_reutilise':("bonus:=public.religion_benediction_consommer_interne(p.id,'voler_materiel_chantier',p_requete);",'bonus:=5;'),
   'rejeu_oublie':('IF FOUND THEN\n  IF recu.terrain','IF FOUND AND false THEN\n  IF recu.terrain')
  }[MUTANT]
  assert d.count(avant)==1;q.execute(d.replace(avant,apres))
 def position():q.execute("SET hg.acteur='Fixture';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='terrain-a-batir-1',current_room='terrain',hp=100,pa=50,stats='{\"DUP\":10}',stats_affaiblies='{}',reputation_criminelle=0,hospitalisation=NULL WHERE name='Fixture';UPDATE indices_villes SET data=data||'{\"isn\":45,\"social\":50}' WHERE id='republic_capitale';UPDATE terrains_etat SET data='{\"city\":\"capitale\",\"proprietaire\":\"Autre\",\"chantier\":{\"type\":\"construction\",\"dureeJours\":6,\"progressionJours\":0,\"stockMateriaux\":{\"bois\":100,\"minerai\":50,\"metal\":33}}}' WHERE id='republic_terrain-a-batir-1'")
 def jet(v):q.execute(f'CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT {v}$$')
 def benediction():
  q.execute("UPDATE personnages_donnees SET current_building='tabernacle-impots',current_room='nef_principale' WHERE name='Fixture'");jet(1)
  r=lire('SELECT religion_benediction_demander(%s,%s)',('Père Ception',str(uuid.uuid4())));assert r['ok'] and r['succes'],r
  q.execute("UPDATE personnages_donnees SET current_building='terrain-a-batir-1',current_room='terrain' WHERE name='Fixture'")
 def appel(k,mat='bois',cur=q):return lire('SELECT chantier_vol_commande(%s,%s,%s)',('terrain-a-batir-1',mat,f'b0000000-0000-4000-8000-{k:012d}'),cur)
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(t ORDER BY id) FROM terrains_etat t),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM chantier_vols_recus r),(SELECT jsonb_agg(a ORDER BY id) FROM actions_tracables a),(SELECT jsonb_agg(i ORDER BY id) FROM indices_villes i),(SELECT jsonb_agg(o ORDER BY id) FROM objets_recus o),(SELECT jsonb_agg(l ORDER BY jeton) FROM inventaire_livraisons_recues l))")
 position();ancien=lire("SELECT inventaire_reception_etat('Fixture')");jet(100);r=appel(1)
 check(r['ok'] and r['score']==100 and r['quantite']==20,'score parfait vingt bois par les regles existantes')
 check(lire("SELECT (data::jsonb->'chantier'->'stockMateriaux'->>'bois')::int FROM terrains_etat WHERE id='republic_terrain-a-batir-1'")==80,'retrait stock confirme')
 check(r['inventaire']['inventory'][-1]['qty']==20 and r['inventaire']['revision']>=1,'butin recu par le vrai moteur revisionne')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==48,'deux PA du catalogue reel')
 check(lire("SELECT count(*) FROM objets_recus WHERE id LIKE 'vol-chantier-%'")==0 and lire("SELECT count(*) FROM inventaire_livraisons_recues WHERE id LIKE 'vol-chantier-%'")==1,'livraison reclamee et recu atomiques aucun depot en suspens')
 check(lire("SELECT data->>'social' FROM indices_villes WHERE id='republic_capitale'")=='49','indice social applique une fois')
 avant=photo();check(appel(1)['rejeu'] and photo()==avant,'reponse perdue aucun second objet PA ou effet')
 check(appel(1,'metal')['raison']=='requete_reutilisee' and photo()==avant,'nonce ne change pas de matiere')
 sauvegarde=lire('SELECT inventaire_sauver_revision(%s,%s,%s)',('Fixture',ancien['revision'],json.dumps(ancien['inventory'])))
 check(not sauvegarde['ok'] and sauvegarde['raison']=='inventaire_perime','ancienne sauvegarde refusee ne perd pas le butin confirme')
 position();q.execute("UPDATE personnages_donnees SET inventory='[{\"id\":\"ancien-a\",\"stackable\":true,\"stackKey\":\"bois\",\"qty\":7,\"memoire\":\"conservee\"},{\"id\":\"ancien-b\",\"stackable\":true,\"stackKey\":\"bois\",\"qty\":9}]' WHERE name='Fixture'");jet(100);r=appel(5)
 check(r['inventaire']['inventory'][0]['qty']==27 and r['inventaire']['inventory'][0]['memoire']=='conservee' and r['inventaire']['inventory'][1]['qty']==9,'premier lot seulement enrichi identifiants et metadonnees preserves')
 q.execute("UPDATE personnages_donnees SET country='soviet' WHERE name='Fixture'");avant=photo();check(appel(1)['raison']=='requete_reutilisee' and photo()==avant,'rejeu ne peut pas devenir un acte d un autre empire');position()
 courant=lire("SELECT inventory FROM personnages_donnees WHERE name='Fixture'")
 q.execute("GRANT UPDATE(inventory),SELECT(name,inventory,inventory_revision) ON personnages_donnees TO authenticated;SET ROLE authenticated;SET request.path='/rest/v1/personnages_donnees';UPDATE personnages_donnees SET inventory='[]' WHERE name='Fixture';RESET ROLE;SET request.path=''")
 check(lire("SELECT inventory FROM personnages_donnees WHERE name='Fixture'")==courant,'ancienne sauvegarde REST ne peut pas effacer le butin confirme')
 position();jet(1);r=appel(2);check(r['ok'] and r['detecte'] and r['quantite']==0,'echec detecte sans retrait ni objet fictif')
 check(lire("SELECT recherche @> '[{\"id\":\"vol-chantier-b0000000-0000-4000-8000-000000000002\"}]' FROM personnages_donnees WHERE name='Fixture'"),'recherche via le moteur judiciaire commun')
 position();jet(30);r=appel(3);check(r['ok'] and not r['succes'] and not r['detecte'] and r['quantite']==0,'echec discret trace sans recherche supplementaire')
 position();q.execute("UPDATE personnages_donnees SET current_room='ailleurs' WHERE name='Fixture'");avant=photo();check(appel(4)['raison']=='pas_sur_place' and photo()==avant,'presence refusee avant PA jet et bonus')
 position();q.execute("UPDATE personnages_donnees SET pa=1 WHERE name='Fixture'");avant=photo();check(appel(4)['raison']=='pa_insuffisants' and photo()==avant,'PA insuffisants sans mutation')
 for sql,raison in [("UPDATE personnages_donnees SET hp=0 WHERE name='Fixture'",'acteur_indisponible'),("UPDATE personnages_donnees SET hospitalisation=jsonb_build_object('dateFinParis',((now() AT TIME ZONE 'Europe/Paris')::date+1)::text) WHERE name='Fixture'",'acteur_indisponible'),("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{succession_gel}','true')::text WHERE id='republic_terrain-a-batir-1'",'terrain_gele'),("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,progressionJours}','6')::text WHERE id='republic_terrain-a-batir-1'",'chantier_absent_ou_termine')]:
  position();q.execute(sql);avant=photo();check(appel(4)['raison']==raison and photo()==avant,'refus avant effets '+raison)
 position();jet(100);q.execute("CREATE FUNCTION stock_ignore_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN NEW.data:=OLD.data;RETURN NEW;END$$;CREATE TRIGGER stock_ignore_fixture BEFORE UPDATE ON terrains_etat FOR EACH ROW EXECUTE FUNCTION stock_ignore_fixture()")
 avant=photo()
 try:appel(4);raise AssertionError('stock ignore attendu')
 except psycopg2.Error as ex:check('retrait_chantier_non_confirme' in str(ex) and photo()==avant,'stock silencieusement ignore ne cree aucun butin gratuit')
 q.execute('DROP TRIGGER stock_ignore_fixture ON terrains_etat')
 for table,corps,erreur,j in [('personnages_donnees','NEW.pa:=OLD.pa;RETURN NEW;','paiement_vol_non_confirme',100),('personnages_donnees','NEW.inventory:=OLD.inventory;RETURN NEW;','inventaire_ecriture_non_appliquee',100),('indices_villes','NEW.data:=OLD.data;RETURN NEW;','indice_social_non_confirme',100),('actions_tracables','RETURN NULL;','trace_vol_non_confirmee',100),('personnages_donnees','NEW.recherche:=OLD.recherche;RETURN NEW;','recherche_non_confirmee',1)]:
  position();jet(j);operation='INSERT' if table=='actions_tracables' else 'UPDATE'
  q.execute('CREATE OR REPLACE FUNCTION defaut_vol_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN '+corps+'END$$;CREATE TRIGGER defaut_vol_fixture BEFORE '+operation+' ON '+table+' FOR EACH ROW EXECUTE FUNCTION defaut_vol_fixture()');avant=photo()
  try:appel(4);raise AssertionError('ecriture ignoree attendue '+erreur)
  except psycopg2.Error as ex:check(erreur in str(ex) and photo()==avant,'ecriture ignoree rollback complet '+erreur)
  q.execute('DROP TRIGGER defaut_vol_fixture ON '+table)
 position();benediction();jet(100);q.execute("CREATE FUNCTION panne_vol_chantier_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_vol_chantier_fixture';END$$;CREATE TRIGGER panne_vol_chantier_fixture BEFORE INSERT ON chantier_vols_recus FOR EACH ROW EXECUTE FUNCTION panne_vol_chantier_fixture()")
 avant=photo()
 try:appel(4);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_vol_chantier_fixture' in str(ex) and photo()==avant,'panne finale annule retrait inventaire revision PA trace social et bonus')
 q.execute('DROP TRIGGER panne_vol_chantier_fixture ON chantier_vols_recus')
 def concurrent(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture'");return appel(4,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:reponses=list(pool.map(concurrent,[0,1]))
 check(all(r['ok'] for r in reponses) and sum(bool(r.get('rejeu')) for r in reponses)==1,'deux sessions meme requete un seul butin')
 position();benediction();jet(45)
 def distinct(k):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture'");return appel(k,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:reponses=list(pool.map(distinct,[7,8]))
 check(sorted(r['bonus'] for r in reponses)==[0,5] and sum(r['quantite'] for r in reponses)==1,'deux actes distincts ne depensent qu une fois le bonus au seuil de reussite')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==45,'attribution et deux tentatives prelevent exactement un puis deux puis deux PA')
 position();jet('NULL::integer');avant=photo()
 try:appel(9);raise AssertionError('jet absent attendu')
 except psycopg2.Error as ex:check('jet_invalide' in str(ex) and photo()==avant,'jet absent annule PA bonus stock et inventaire')
 # Comparaison aux fonctions pures réellement exécutées dans le navigateur, pas à une seconde formule de test.
 cas=[{'dup':10,'isn':45,'rep':0,'vig':0,'jet':j,'mat':'bois','jour':1} for j in [1,19,20,49,50,100]]
 cas += [{'dup':10,'isn':45,'rep':0,'vig':0,'jet':100,'mat':'metal','jour':j} for j in [1,2,3]]
 cas += [{'dup':13,'isn':45,'rep':40,'vig':0,'jet':34,'mat':'minerai','jour':1},{'dup':10,'isn':100,'rep':0,'vig':1,'jet':90,'mat':'bois','jour':1},{'dup':10,'isn':45,'rep':0,'vig':3,'jet':90,'mat':'bois','jour':1}]
 programme="const fs=require('fs'),vm=require('vm'),acorn=require('./outils/vercel/node_modules/acorn');const c=vm.createContext({});vm.runInContext(fs.readFileSync('plateau-chantiers.js','utf8'),c);const s=fs.readFileSync('plateau-justice-economie.js','utf8'),a=s.indexOf('function getPalierCriminel('),n=acorn.parse(s.slice(a),{ecmaVersion:'latest'}).body[0];vm.runInContext(s.slice(a,a+n.end),c);c.cas=JSON.parse(process.argv[1]);console.log(vm.runInContext(\"JSON.stringify(cas.map(x=>{const b=(x.dup-10)*2-(x.isn-45)/3+getPalierCriminel(x.rep).bonus,s=scoreVolMateriaux(b,x.vig,x.jet-50),v=verdictVolMateriaux(s);return {score:s,q:quantiteVolMateriaux(s,x.mat,x.jour,x.mat==='bois'?100:x.mat==='minerai'?50:33),succes:v.reussite,detecte:v.detecte};}))\",c));"
 attendus=json.loads(subprocess.check_output(['node','-e',programme,json.dumps(cas)],cwd=R,text=True))
 for index,(cas,attendu) in enumerate(zip(cas,attendus)):
  position();q.execute("UPDATE personnages_donnees SET stats=jsonb_build_object('DUP',%s),reputation_criminelle=%s WHERE name='Fixture';UPDATE indices_villes SET data=jsonb_set(data,'{isn}',to_jsonb(%s::integer)) WHERE id='republic_capitale';UPDATE terrains_etat SET data=jsonb_set(jsonb_set(data::jsonb,'{chantier,vigiles}',to_jsonb(%s::integer)),'{chantier,progressionJours}',to_jsonb(%s::integer))::text WHERE id='republic_terrain-a-batir-1'",(cas['dup'],cas['rep'],cas['isn'],cas['vig'],cas['jour']-1));jet(cas['jet']);r=appel(100+index,cas['mat'])
  check(r['ok'] and abs(r['score']-attendu['score'])<1e-8 and r['quantite']==attendu['q'] and r['succes']==attendu['succes'] and r['detecte']==attendu['detecte'],'parite formule navigateur seuils vigiles reputation et metal '+str(index))
 check(lire("SELECT has_function_privilege('authenticated','chantier_vol_commande(text,text,uuid)','EXECUTE')") is False,'commande privee avant activation complete')
 print(json.dumps({'vol_chantier_serveur':True,'assertions':n,'client_raccorde':False,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.banque.m.main(tout)
