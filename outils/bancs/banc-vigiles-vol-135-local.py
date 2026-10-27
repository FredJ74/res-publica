#!/usr/bin/env python3
"""#135 : extension du banc commun, PostgreSQL jetable ; aucun compte reel.
La colonne benediction est une HYPOTHESE de contrat, PAS un acquis de production.
Le prevol prouve explicitement le refus de deploiement si elle manque.
"""
from pathlib import Path
import importlib.util,re,json,subprocess,sys
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
spec=importlib.util.spec_from_file_location('jour',R/'outils/bancs/banc-construction-jour-local.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
def suite(db,q,srv):
 import psycopg2
 from psycopg2.extras import Json
 n=0
 def check(v,texte):
  nonlocal n
  assert v,texte;n+=1;print('OK vol/vigiles',texte,flush=True)
 def lire(sql,args=(),cur=q):cur.execute(sql,args);return cur.fetchone()[0]
 def table(domaine,nom,pk=None):
  src=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text()
  q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',src,re.S)[0])
  if pk:q.execute(f'ALTER TABLE {nom} ADD PRIMARY KEY({pk})')
 def fn(f,nom):q.execute(base.fn(f,nom))
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN user_id uuid,ADD COLUMN current_room text,ADD COLUMN stats jsonb,ADD COLUMN stats_affaiblies jsonb DEFAULT \'{}\',ADD COLUMN reputation_criminelle integer DEFAULT 0,ADD COLUMN inventory jsonb DEFAULT \'[]\',ADD COLUMN inventory_revision bigint DEFAULT 0,ADD COLUMN journal jsonb DEFAULT \'[]\'')
 q.execute('ALTER TABLE comptes_bancaires ADD COLUMN id text')
 q.execute('CREATE VIEW personnages AS SELECT * FROM personnages_donnees')
 q.execute("CREATE SCHEMA auth;CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;GRANT USAGE ON SCHEMA auth TO authenticated")
 for f in ['mon_personnage','est_mon_personnage','exiger_acteur']:fn('baseline/domaines/socle/20_fonctions.sql',f)
 q.execute("CREATE FUNCTION jour_de_jeu_pays(text) RETURNS integer LANGUAGE sql AS $$SELECT 1$$")
 for d,t,pk in [('socle-PNJ','pnj_membres','id'),('socle-PNJ','pnj_employes_metier','pnj_id'),('socle-PNJ','pnj_candidats_catalogue','candidat_id'),('socle-PNJ','pnj_employeurs','employeur_id'),('socle-PNJ','pnj_axes_autorite',None),('socle-PNJ','pnj_mouvement_individuel',None),('socle-PNJ','pnj_institutions',None),('justice','actions_tracables','id'),('politique-et-elections','indices_villes','id'),('divers-et-technique','evenements_globaux',None),('economie','ordres_couts','fn'),('economie','ordres_couts_inconnus','fn'),('economie','ordres_couts_ecarts',None),('politique-et-elections','presidence_memoire_ordres',None)]:table(d,t,pk)
 q.execute('ALTER TABLE ordres_couts_ecarts ADD UNIQUE(fn,pa,cost)')
 q.execute("INSERT INTO ordres_couts VALUES('voler_materiel_chantier',2,0)")
 q.execute("CREATE FUNCTION presidence_memoire_noter(text,text,text,text,jsonb,text) RETURNS void LANGUAGE sql AS $$SELECT$$")
 for f in ['pnj_autorite_de_perimetre','pnj_autorite_de','pnj_peut_administrer','pnj_peut_conduire','pnj_position_effective','pnj_co_present','pnj_axe_au_socle','pnj_axe_verrouille','pnj_axe_position_refus','pnj_mouvement_individuel_refus','pnj_quitter_groupe','pnj_prendre']:
  fn('baseline/domaines/socle-PNJ/20_fonctions.sql',f)
 fn('baseline/domaines/personnage-et-presence/20_fonctions.sql','employe_liberer')
 q.execute((R/'baseline/seeds/90_socle/pnj_axes_autorite.sql').read_text())
 q.execute((R/'baseline/seeds/90_socle/pnj_mouvement_individuel.sql').read_text())
 for f,path in [('payer_ordre','economie/20_fonctions-2.sql'),('inventaire_ajouter','socle/20_fonctions.sql'),('indice_ville_ajuster_interne','politique-et-elections/20_fonctions.sql'),('recherche_inscrire','justice/20_fonctions-2.sql')]:fn('baseline/domaines/'+path,f)
 q.execute("ALTER TABLE personnages_donnees ADD COLUMN recherche jsonb DEFAULT '[]'")
 fn('migrations/20261016131932_reception_objets_atomique.sql','inventaire_revision_garder')
 q.execute('CREATE TRIGGER zzzz_hg_inventory_revision BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION inventaire_revision_garder()')
 for _ in range(2):q.execute((R/'migrations/20261027121000_chantier_vigiles_socle.sql').read_text())
 sql=(R/'migrations/20261027122000_chantier_vol_transaction_interne.sql').read_text()
 try:q.execute(sql);raise AssertionError('dependance absente doit refuser')
 except psycopg2.Error as e:check('dependance_benediction' in str(e),'prevol refuse le stockage de benediction absent, aucune hypothese cachee');q.execute('ROLLBACK')
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN benediction jsonb')
 # Refaire la vue apres l'ajout (la vue ne sert qu'a l'identite).
 for _ in range(2):q.execute(sql);q.execute((R/'migrations/20261027122100_chantier_vol_commande_et_fermeture.sql').read_text())
 if MUTANT:
  signatures={'sans_statut':('chantier_vigiles_presents_interne(text)',"m.statut='actif'",'true'),
   'parametres_ignores':('chantier_commande(text,text,text,jsonb)','rec.commande<>commande','false'),
   'sans_credit':('chantier_vol_executer_interne(text,jsonb,text)','SET inventory=inv,updated_at=now()','SET inventory=p.inventory,updated_at=now()')}
  sig,avant,apres=signatures[MUTANT];d=lire('SELECT pg_get_functiondef(%s::regprocedure)',('public.'+sig,));assert d.count(avant)==1;d=d.replace(avant,apres)
  if MUTANT=='sans_credit':
   # Reproduire le circuit historique qui annonce un succes sans attribution persistante.
   d=re.sub(r"  IF NOT EXISTS\(SELECT 1 FROM public.personnages_donnees WHERE name=acteur AND inventory=inv AND inventory_revision=avant_revision\+1\) THEN\n   RAISE EXCEPTION 'inventaire_ecriture_non_confirmee';END IF;",'',d)
  q.execute(d)
 q.execute("INSERT INTO personnages_donnees(name,country,arg,liquide,pa,hp,current_city,current_building,current_room,stats,user_id) VALUES('Chef','republic',1000,1000,50,100,'capitale','terrain-a-batir-1','terrain','{\"DUP\":10}','00000000-0000-4000-8000-000000000001'),('VoleurA','republic',1000,1000,50,100,'capitale','terrain-a-batir-1','terrain','{\"DUP\":10}','00000000-0000-4000-8000-000000000002'),('VoleurB','republic',1000,1000,50,100,'capitale','terrain-a-batir-1','terrain','{\"DUP\":10}','00000000-0000-4000-8000-000000000003')")
 q.execute("INSERT INTO indices_villes(id,data) VALUES('republic_capitale','{\"isn\":45,\"social\":45}')")
 q.execute("INSERT INTO pnj_employeurs(employeur_id,pays,nom) VALUES('agence','republic','Agence fixture');INSERT INTO pnj_candidats_catalogue(candidat_id,employeur_id,metier,nom) VALUES('a','agence','agent_securite','Agent fixture')")
 for i in range(1,6):
  ch={'type':'construction','niveau':'hangar','dureeJours':6,'progressionJours':0,'totalVerse':30000,'coutTotal':30000,'stockMateriaux':{'bois':20,'minerai':20,'metal':20}}
  q.execute('INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES(%s,\'republic\',%s,\'Chef\',%s)',('republic_terrain-a-batir-'+str(i),'terrain-a-batir-'+str(i),json.dumps({'city':'capitale','proprietaire':'Chef','chantier':ch})))
 for i in range(1,4):
  q.execute("INSERT INTO pnj_membres(id,famille,classe,nom,pays,proprietaire_pj,leader_pj,car_dup,car_per,car_vol) VALUES(%s,'employe','alpha',%s,'republic','Chef','Chef',8,12,16)",('g'+str(i),'Agent '+str(i)))
  q.execute("INSERT INTO pnj_employes_metier(pnj_id,job,role_libelle,candidat_id) VALUES(%s,'agent_securite','Agent','a')",('g'+str(i),))
 def identite(nom,cur=q):
  cur.execute('RESET ROLE');cur.execute('SELECT user_id::text FROM personnages_donnees WHERE name=%s',(nom,));uid=cur.fetchone()[0]
  cur.execute("SELECT set_config('request.jwt.claim.sub',%s,false),set_config('request.path','/rpc/chantier_commande',false),set_config('test.serveur','off',false)",(uid,));cur.execute('SET ROLE authenticated')
 def admin(sql,args=()):q.execute('RESET ROLE');q.execute(sql,args or None)
 def terrain(i=1):return 'republic_terrain-a-batir-'+str(i)
 def presents(i=1):return lire('SELECT chantier_securite_lire(%s)',(terrain(i),))
 def affect(ids,i=1):return lire('SELECT chantier_vigiles_affecter(%s,%s)',(terrain(i),ids))
 def commande(k,params={'matiere':'bois'},cur=q):return lire('SELECT chantier_commande(%s,%s,\'voler\',%s)',('ch-vol135-'+k,terrain(),Json(params)),cur)
 def photo():
  q.execute('RESET ROLE');r=lire("SELECT jsonb_build_array((SELECT jsonb_agg(x ORDER BY name) FROM personnages_donnees x),(SELECT jsonb_agg(x ORDER BY id) FROM terrains_etat x),(SELECT jsonb_agg(x ORDER BY requete) FROM chantier_commandes_recus x),(SELECT jsonb_agg(x ORDER BY id) FROM actions_tracables x),(SELECT jsonb_agg(x ORDER BY id) FROM evenements_globaux x),(SELECT data FROM indices_villes WHERE id='republic_capitale'))");return r
 def jet(j):admin('CREATE OR REPLACE FUNCTION chantier_vol_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT '+str(j)+'$$')
 def reset():
  admin("UPDATE personnages_donnees SET pa=50,hp=100,inventory='[]',journal='[]',benediction=NULL,recherche='[]',current_city='capitale',current_building='terrain-a-batir-1',current_room='terrain' WHERE name IN('Chef','VoleurA','VoleurB');UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,stockMateriaux,bois}','20')::text WHERE id='republic_terrain-a-batir-1';DELETE FROM chantier_commandes_recus WHERE requete LIKE 'ch-vol135-%';DELETE FROM actions_tracables;DELETE FROM evenements_globaux")
 identite('Chef');check(presents()['nombre']==0,'sans affectation aucun vigile fictif')
 check(affect(['g1'])['ok'] and presents()['nombre']==1,'agent du socle detache et affecte, presence effective')
 avant=lire('SELECT chantier_securite_lire(%s)',(terrain(),));check(affect(['g1'])['ok'] and presents()==avant,'reconnexion/rejeu affectation sans agent duplique')
 check(affect(['g2'])['ok'] and presents()['nombre']==2,'plusieurs agents reels, pas un nombre dans le blob')
 admin("UPDATE pnj_membres SET building_id='terrain-a-batir-2' WHERE id='g2'");identite('Chef');check(presents()['nombre']==1,'agent absent ne protege plus')
 admin("UPDATE pnj_membres SET building_id='terrain-a-batir-1' WHERE id='g2'");identite('Chef');check(lire("SELECT employe_liberer('g2')")['ok'] and presents()['nombre']==1,'licenciement commun retire protection sans copie de statut')
 identite('VoleurA');check(not affect(['g3'])['ok'],'tiers ne peut affecter employe d autrui')
 admin("UPDATE pnj_membres SET pa=0 WHERE id='g1'");identite('Chef');check(presents()['nombre']==0,'agent sans PA indisponible')
 admin("UPDATE pnj_membres SET pa=12 WHERE id='g1'")
 # Les cinq parcelles reutilisent les memes affectations et positions du socle.
 for i in range(1,6):
  admin("UPDATE personnages_donnees SET current_building=%s WHERE name='Chef';UPDATE pnj_membres SET leader_pj='Chef',building_id=NULL,room_id=NULL,ville=NULL WHERE id='g3'",('terrain-a-batir-'+str(i),))
  identite('Chef');check(affect(['g3'],i)['ok'] and any(a['pnj_id']=='g3' for a in presents(i)['agents']),'affectation et presence generiques sur parcelle '+str(i))
 check(lire("SELECT pnj_prendre(ARRAY['g3'])")['ok'],'rappel par le groupe commun, pas un second moteur')
 check(all(a['pnj_id']!='g3' for a in presents(5)['agents']),'agent repris dans groupe ne garde plus le chantier')
 admin("UPDATE personnages_donnees SET current_building='terrain-a-batir-1' WHERE name='Chef'")
 identite('Chef');check(all(a['pnj_id']!='g3' for a in presents()['agents']),'agent porte/non affecte a ce chantier sans protection fantome')
 admin("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{proprietaire}','\"Autre\"')::text WHERE id=%s",(terrain(),))
 identite('Chef');check(presents()['nombre']==0,'mutation de propriete invalide les anciennes affectations')
 admin("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{proprietaire}','\"Chef\"')::text WHERE id=%s",(terrain(),))
 # Le calcul SQL est confronte aux fonctions REELLES du navigateur sur une grille.
 grille=json.loads(subprocess.check_output(['node','-e',"const vm=require('vm'),fs=require('fs'),c=vm.createContext({});vm.runInContext(fs.readFileSync('plateau-chantiers.js','utf8'),c);const r=[];for(const b of [-30,0,5,33.3])for(const g of [0,1,2,4])for(const j of [1,20,50,70,100])for(const m of ['bois','minerai','metal'])for(const d of [1,2,3]){const v=vm.runInContext('verdictVolMateriaux(scoreVolMateriaux('+b+','+g+','+(j-50)+'))',c);const q=vm.runInContext('quantiteVolMateriaux('+v.score+','+JSON.stringify(m)+','+d+',9)',c);r.push([b,g,j,m,d,{...v,quantite:q}]);}console.log(JSON.stringify(r))"],cwd=R,text=True))
 for b,g,j,m,d,attendu in grille:
  obtenu=lire('SELECT chantier_vol_calcul_interne(%s,%s,%s,%s,%s,9)',(b,g,j,m,d));assert obtenu==attendu,(b,g,j,m,d,obtenu,attendu)
 check(True,str(len(grille))+' comparaisons exactes des formules historiques JS/SQL, malus inchanges')
 reset();jet(100);identite('VoleurA');r=commande('succes0001');check(r['ok'] and r['reussite'] and r['vigiles']==1,'vol decide par serveur avec vigile reel')
 admin("SELECT inventory,pa FROM personnages_donnees WHERE name='VoleurA'");inv,pa=q.fetchone();check(len(inv)==1 and inv[0]['qty']==r['quantite'] and pa==48,'stock et inventaire persistant avec deux PA')
 avant=photo();identite('VoleurA');check(commande('succes0001').get('rejeu'),'reponse perdue meme commande retourne recu');check(photo()==avant,'aucun deuxieme objet PA trace indice ou evenement')
 identite('VoleurA');check(not commande('succes0001',{'matiere':'metal'})['ok'],'identifiant reutilise avec autre matiere refuse')
 reset();jet(1);identite('VoleurA');r=commande('echec00001');check(r['ok'] and not r['reussite'] and r['detecte'],'echec detecte serveur')
 admin("SELECT inventory,pa,jsonb_array_length(recherche) FROM personnages_donnees WHERE name='VoleurA'");check(q.fetchone()==([],48,1),'echec: aucun objet, cout et recherche uniques')
 reset();admin("UPDATE pnj_membres SET building_id='ailleurs' WHERE id='g1'");jet(100);admin("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,stockMateriaux,bois}','2')::text WHERE id=%s",(terrain(),));identite('VoleurA');r=commande('stockborne1');check(r['quantite']==2,'stock reel borne attribution')
 avant=photo();identite('VoleurA');check(commande('stockvide01')['raison']=='stock_vide','stock vide refuse');check(photo()==avant,'stock vide aucun prelevement')
 reset();jet(100)
 def concurrent(nom):
  with psycopg2.connect(srv.get_uri()) as c:
   cur=c.cursor();identite(nom,cur);return commande('concurrent1',cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,['VoleurA','VoleurA']))
 check(all(x['ok'] for x in rs) and sum(bool(x.get('rejeu')) for x in rs)==1,'double clic concurrent un seul acte')
 reset();jet(100);admin("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,stockMateriaux,bois}','3')::text WHERE id=%s",(terrain(),))
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,['VoleurA','VoleurB']))
 check(sum(x.get('quantite',0) for x in rs)==3,'deux voleurs concurrents aucun stock negatif ni duplication')
 reset();jet(100);avant=photo()
 admin("CREATE FUNCTION panne_vol() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.inventory IS DISTINCT FROM OLD.inventory THEN RAISE EXCEPTION 'panne_apres_stock';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_vol BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION panne_vol()")
 identite('VoleurA')
 try:commande('panne00001');raise AssertionError('panne attendue')
 except psycopg2.Error as e:check('panne_apres_stock' in str(e),'panne injectee entre stock et inventaire')
 check(photo()==avant,'rollback total PA stock inventaire recu traces indices')
 admin('DROP TRIGGER panne_vol ON personnages_donnees');reset();jet(100)
 admin("UPDATE personnages_donnees SET current_building='rue' WHERE name='VoleurA'");avant=photo();identite('VoleurA');check(not commande('distant001')['ok'],'position serveur distante refusee');check(photo()==avant,'refus distant sans paiement')
 admin("UPDATE personnages_donnees SET current_building='terrain-a-batir-1',pa=1 WHERE name='VoleurA'");avant=photo();identite('VoleurA');check(not commande('paepuise01')['ok'],'PA insuffisants refuses');check(photo()==avant,'aucune mutation en fonds/PA insuffisants')
 identite('VoleurA');check(lire("SELECT terrain_chantier_acte('terrain-a-batir-1','chantier_materiaux_voler','bois',999,1)")['raison']=='vol_commande_versionnee_requise','ancienne porte ne peut contourner commande atomique')
 # Une mauvaise route HTTP ne peut retirer le stock sans l'inventaire.
 reset();jet(100);avant=photo();identite('VoleurA');q.execute("SET request.path='/personnages'")
 try:commande('mauvaisrpc1');raise AssertionError('contexte inventaire doit refuser')
 except psycopg2.Error as e:check('inventaire_ecriture_non_confirmee' in str(e),'garde inventaire refuse le faux contexte RPC')
 check(photo()==avant,'rollback stock PA et recu si inventaire protege contre la route REST')
 # La panne APRES tous les effets doit aussi tout annuler.
 reset();jet(100);avant=photo()
 admin("CREATE FUNCTION panne_recu_vol() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.requete='ch-vol135-recupanne1' THEN RAISE EXCEPTION 'panne_recu_vol';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_recu_vol BEFORE INSERT ON chantier_commandes_recus FOR EACH ROW EXECUTE FUNCTION panne_recu_vol()")
 identite('VoleurA')
 try:commande('recupanne1');raise AssertionError('panne finale attendue')
 except psycopg2.Error as e:check('panne_recu_vol' in str(e),'panne finale du recu apres tous les effets')
 check(photo()==avant,'panne du recu annule egalement recherche trace journal indices et objets')
 admin('DROP TRIGGER panne_recu_vol ON chantier_commandes_recus')
 # Plusieurs agents reels pesent sur le meme calcul, sans changer les malus.
 reset();jet(70)
 admin("UPDATE pnj_membres SET building_id='terrain-a-batir-1',room_id='terrain',ville='capitale',leader_pj=NULL,statut='actif',pa=12 WHERE id='g1'")
 admin("UPDATE pnj_membres SET statut='actif',pa=12,leader_pj='Chef',ville=NULL,building_id=NULL,room_id=NULL WHERE id='g2'")
 identite('Chef');check(affect(['g2'])['ok'],'second agent affecte par la commande commune')
 identite('VoleurA');r=commande('deuxgardes1');check(r['vigiles']==2 and not r['reussite'] and r['score']==40,'deux agents presents : malus historique de 30 effectif serveur')
 reset();jet(70);admin("UPDATE pnj_membres SET statut='disparu' WHERE id='g2'")
 identite('VoleurA');r=commande('ungarde0001');check(r['vigiles']==1 and r['reussite'] and r['score']==50,'un seul agent : malus de 20 et reussite au seuil historique')
 reset();jet(70);admin("UPDATE pnj_membres SET building_id='ailleurs' WHERE id='g1'")
 identite('VoleurA');r=commande('aucungarde1');check(r['vigiles']==0 and r['score']==70,'agent non present ne protege pas meme si affectation subsiste')
 # Benediction : contrat de stockage hypothetique clairement signale, bonus consomme une fois.
 reset();jet(45);admin("UPDATE personnages_donnees SET benediction='{\"actif\":true,\"expire\":1}' WHERE name='VoleurA'")
 identite('VoleurA');r=commande('benediction1');check(r['reussite'] and r['score']==50,'bonus historique +5 consomme dans transaction sous contrat explicite')
 admin("SELECT benediction->>'actif' FROM personnages_donnees WHERE name='VoleurA'");check(q.fetchone()[0]=='false','benediction consommee persistante sur fixture de contrat')
 avant=photo();identite('VoleurA');check(commande('benediction1')['rejeu'],'reponse perdue ne consomme pas une autre benediction');check(photo()==avant,'rejeu de benediction sans effet supplementaire')
 # Reconnexion par une NOUVELLE connexion SQL, pas adoption d'un cache.
 with psycopg2.connect(srv.get_uri()) as cc:
  cur=cc.cursor();identite('VoleurA',cur);r=commande('benediction1',cur=cur)
  check(r['rejeu'] and r['quantite']>=1,'reconnexion retrouve recu du vol sans le rejouer')
 for nom in ['inventaire_reception_etat','inventaire_sauver_revision']:fn('migrations/20261016131932_reception_objets_atomique.sql',nom)
 identite('VoleurA');inv=lire("SELECT inventaire_reception_etat('VoleurA')")
 check(inv['inventory'][0]['qty']>=1 and inv['revision']>0,'rechargement inventaire et revision persistants')
 r=lire("SELECT inventaire_sauver_revision('VoleurA',%s,'[]')",(inv['revision']-1,));check(not r['ok'] and r['raison']=='inventaire_perime','ancienne sauvegarde CAS refusee apres vol')
 admin("GRANT SELECT(name,inventory),UPDATE(inventory,inventory_revision) ON personnages_donnees TO authenticated")
 identite('VoleurA');q.execute("SET request.path='/personnages';UPDATE personnages_donnees SET inventory='[]',inventory_revision=0 WHERE name='VoleurA'")
 check(lire("SELECT inventaire_reception_etat('VoleurA')")['inventory']==inv['inventory'],'ancienne sauvegarde generale ne retire pas les objets voles')
 for sig in ['chantier_vigiles_presents_interne(text)','chantier_vol_executer_interne(text,jsonb,text)','chantier_vol_jet_interne()']:
  q.execute('RESET ROLE');check(not lire("SELECT has_function_privilege('authenticated',%s,'EXECUTE')",('public.'+sig,)),'moteur interne non executable '+sig)
 print(json.dumps({'assertions_vigiles_vol':n,'production':False,'formules_comparees':len(grille),'intervention_privee_non_verifiee':True,'benediction_schema_hypothetique':True}))
if __name__=='__main__':base.main(suite)


def installer_sur_parcours(q):
 """Assemble le contrat prepare DANS le banc existant des cinq parcelles.
 Ne remplace pas son identite/horloge de fixture. Benediction reste une hypothese.
 Les colonnes ajoutees sont celles des vrais DDL archives, sans nouvelle valeur metier.
 """
 def existe(t):q.execute('SELECT to_regclass(%s)',('public.'+t,));return q.fetchone()[0] is not None
 for nom in ['pnj_membres','pnj_employes_metier','pnj_candidats_catalogue','pnj_employeurs','pnj_axes_autorite','pnj_mouvement_individuel','pnj_institutions']:
  ddl=re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',(R/'baseline/domaines/socle-PNJ/10_tables.sql').read_text(),re.S)[0]
  if not existe(nom):q.execute(ddl)
  else:
   temporaire='contrat_'+nom
   q.execute(ddl.replace('CREATE TABLE public.'+nom,'CREATE TEMP TABLE '+temporaire))
   q.execute("SELECT attname,format_type(atttypid,atttypmod) FROM pg_attribute WHERE attrelid=%s::regclass AND attnum>0 AND NOT attisdropped",(temporaire,))
   for cle,ty in q.fetchall():q.execute('ALTER TABLE '+nom+' ADD COLUMN IF NOT EXISTS '+cle+' '+ty)
   q.execute('DROP TABLE '+temporaire)
 for nom,cle in [('pnj_membres','id'),('pnj_employes_metier','pnj_id'),('pnj_candidats_catalogue','candidat_id'),('pnj_employeurs','employeur_id')]:
  q.execute("SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid=%s::regclass AND contype='p')",(nom,))
  if not q.fetchone()[0]:q.execute('ALTER TABLE '+nom+' ADD PRIMARY KEY('+cle+')')
 for cle,ty in [('current_room',"text DEFAULT 'terrain'"),('inventory',"jsonb DEFAULT '[]'"),('inventory_revision','bigint DEFAULT 0'),('journal',"jsonb DEFAULT '[]'"),('benediction','jsonb'),('reputation_criminelle','integer DEFAULT 0')]:q.execute('ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS '+cle+' '+ty)
 for domaine,nom in [('justice','actions_tracables'),('divers-et-technique','evenements_globaux'),('politique-et-elections','presidence_memoire_ordres')]:
  if not existe(nom):q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text(),re.S)[0])
 for nom in ['pnj_autorite_de_perimetre','pnj_autorite_de','pnj_peut_administrer','pnj_peut_conduire','pnj_position_effective','pnj_co_present','pnj_axe_au_socle','pnj_axe_verrouille','pnj_axe_position_refus','pnj_mouvement_individuel_refus','pnj_quitter_groupe']:
  q.execute(base.fn('baseline/domaines/socle-PNJ/20_fonctions.sql',nom))
 for nom in ['pnj_axes_autorite','pnj_mouvement_individuel']:q.execute((R/f'baseline/seeds/90_socle/{nom}.sql').read_text())
 for fichier,nom in [('migrations/20261016131932_reception_objets_atomique.sql','inventaire_revision_garder'),('baseline/domaines/socle/20_fonctions.sql','inventaire_ajouter'),('baseline/domaines/justice/20_fonctions-2.sql','recherche_inscrire'),('baseline/domaines/politique-et-elections/20_fonctions.sql','indice_ville_ajuster_interne')]:q.execute(base.fn(fichier,nom))
 q.execute('CREATE TRIGGER zzzz_hg_inventory_revision BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION inventaire_revision_garder()')
 q.execute("INSERT INTO ordres_couts(fn,pa,cost) VALUES('voler_materiel_chantier',2,0);INSERT INTO pnj_employeurs(employeur_id,pays,nom) VALUES('integration135','republic','Agence fixture');INSERT INTO pnj_candidats_catalogue(candidat_id,employeur_id,metier,nom) VALUES('integration135','integration135','agent_securite','Agent integration')")
 for fichier in ['20261027121000_chantier_vigiles_socle.sql','20261027122000_chantier_vol_transaction_interne.sql','20261027122100_chantier_vol_commande_et_fermeture.sql']:
  q.execute((R/'migrations'/fichier).read_text());q.execute((R/'migrations'/fichier).read_text())
 q.execute("CREATE OR REPLACE FUNCTION chantier_vol_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT 40$$")
