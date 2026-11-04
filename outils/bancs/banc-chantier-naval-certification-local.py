#!/usr/bin/env python3
"""Certification #473 : vrais moteurs financiers, vrais rôles, PostgreSQL jetable.
Identité/auth fixture ; aucune connexion distante. Par défaut transaction annulée.
--concurrence : fixtures locales commitées pour deux sessions, cluster détruit à la fin.
"""
from pathlib import Path
import tempfile,re,importlib.util,os,json,sys
import pgserver,psycopg2
R=Path(__file__).resolve().parents[2]
CORRECTION=R/'migrations/20261104231550_chantier_naval_certification.sql'
UID='00000000-0000-4000-8000-0000000004c9';NOM='NAVAL-FIXTURE';ENT='republic_ville_a_entrepot-logistique-psm';CAISSE='republic_entrepot_ville_a'
def defs(f,n):
 s=(R/f).read_text();out=[]
 for a in re.finditer(r'CREATE OR REPLACE FUNCTION public\.'+n+r'\(',s):
  z=re.search(r'AS\s+(\$\w*\$).*?\1;',s[a.start():],re.S);out.append(s[a.start():a.start()+z.end()])
 assert out,(f,n)
 return out

def main(concurrence=False):
 if os.environ.get('HG_PG_BIN'):
  import pgserver._commands as cm,pgserver.postgres_server as ps
  cm.POSTGRES_BIN_PATH=ps.POSTGRES_BIN_PATH=Path(os.environ['HG_PG_BIN'])
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-naval-certification-'),cleanup_mode='delete');n=0
 try:
  db=psycopg2.connect(srv.get_uri());q=db.cursor()
  def sql(s,p=None):
   q.execute(s,p) if p is not None else q.execute(s)
   return q.fetchone()[0] if q.description else None
  def own(s,p=None):sql('RESET ROLE');return sql(s,p)
  def check(v,msg):
   nonlocal n
   assert v,msg;n+=1;print('OK',n,msg,flush=True)
  def rpc(f,args=(),role='authenticated',uid=UID):
   sql('RESET ROLE');sql('SET LOCAL ROLE '+role)
   sql("SELECT set_config('request.jwt.claim.sub',%s,true),set_config('request.path',%s,true)",(uid,'/rpc/'+f))
   return sql('SELECT public.'+f+'('+','.join(['%s']*len(args))+')',args)
  def token(k):return f'10000000-0000-4000-8000-{k:012d}'
  def snap():
   return own("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(p)) FROM personnages_donnees p),(SELECT jsonb_agg(to_jsonb(c)) FROM comptes_bancaires c),(SELECT jsonb_agg(to_jsonb(b)) FROM batiments_etat b),(SELECT jsonb_agg(to_jsonb(c)) FROM caisses_batiments c),(SELECT jsonb_agg(to_jsonb(c)-'etat') FROM chantier_naval_commandes c),(SELECT jsonb_agg(to_jsonb(j)) FROM entrepot_journal j),(SELECT jsonb_agg(to_jsonb(b)) FROM chantier_naval_bateaux b))")
  def stock(bois=5000,metal=5000,derives=5000,prix=None,reserve=None):
   from psycopg2.extras import Json
   own('UPDATE batiments_etat SET data=%s WHERE id=%s',(Json({'entrepot':{'stock':{'bois':bois,'metal':metal,'derives_petrochimiques':derives},'prixManuel':prix or {},'reserveMilitaire':reserve or {}}}),ENT))
  def nextday(commande):own("UPDATE chantier_naval_commandes SET dernier_jour=((now() AT TIME ZONE 'Europe/Paris')::date-1) WHERE id=%s",(commande,))
  def avancer(c):return rpc('chantier_naval_avancer_interne',[c],role='service_role',uid='')
  spec=importlib.util.spec_from_file_location('reference',R/'outils/bancs/banc-chantier-naval-local.py');ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)
  init=ref.INIT
  for f in ['batiment_etat_lire','est_appel_serveur','helvetia_debiter_fonds_ordinaires','entrepot_caisse_mouvement','caisse_institution_mouvement']:
   init,k=re.subn(r'CREATE FUNCTION public\.'+f+r'\(.*?\$\$;', '', init,flags=re.S);assert k==1,f
  sql(init)
  sql("""ALTER TABLE personnages_donnees ADD COLUMN inventory jsonb DEFAULT '[{"id":"temoin","name":"Document préexistant"}]',ADD COLUMN inventory_revision bigint DEFAULT 0,ADD COLUMN pa integer DEFAULT 30;
  ALTER TABLE batiments_etat ADD COLUMN country text DEFAULT 'republic',ADD COLUMN city text DEFAULT 'ville_a';
  CREATE VIEW personnages AS SELECT * FROM personnages_donnees;
  CREATE TABLE comptes_bancaires(id text PRIMARY KEY,personnage text,banque text,solde numeric,updated_at timestamptz DEFAULT now());
  CREATE TABLE villes(pays text,ville text);INSERT INTO villes VALUES('republic','ville_a');
  ALTER TABLE entrepot_journal ADD COLUMN contrepartie text;
  GRANT USAGE ON SCHEMA public,auth TO authenticated,service_role;
  ALTER TABLE ressources_economie ADD COLUMN prix_achat_fournisseur numeric,ADD COLUMN plafond integer,ADD COLUMN source text;
  INSERT INTO caisses_batiments VALUES('republic_entrepot_ville_a','{"solde":0}',now());
  INSERT INTO comptes_bancaires VALUES('fixture-nationale','NAVAL-FIXTURE','nationale',200000,now());
  UPDATE personnages_donnees SET arg=400000;
  INSERT INTO personnages_donnees(user_id,name,country,current_city,current_building,liquide,arg)
  VALUES('00000000-0000-4000-8000-0000000004ca','AUTRE-FIXTURE','republic','ville_a','chantier-naval',1000,1000);""")
  for f,names in [
   ('baseline/domaines/socle/20_fonctions.sql',['est_appel_serveur','mon_personnage','est_mon_personnage','exiger_acteur','inventaire_reception_etat']),
   ('baseline/domaines/immobilier-et-territoire/20_fonctions-1.sql',['batiment_etat_lire']),
   ('baseline/domaines/banque/20_fonctions.sql',['helvetia_debiter_fonds_ordinaires']),
   ('baseline/domaines/finances-publiques/20_fonctions-1.sql',['caisse_institution_mouvement']),
   ('baseline/domaines/economie/20_fonctions-2.sql',['entrepot_caisse_id','entrepot_caisse_mouvement'])]:
   for name in names:
    for definition in defs(f,name):sql(definition)
  sql((R/'baseline/seeds/95_a-regenerer/ressources_economie.sql').read_text())
  sql(ref.MODELES.read_text());sql(ref.MOTEUR.read_text())
  print('PostgreSQL',own('SHOW server_version'),flush=True)
  # Reproduction de l'ancien défaut : NULL dans la position rendait le IF inopérant.
  own("SAVEPOINT ancien;UPDATE personnages_donnees SET current_building=NULL WHERE name=%s",(NOM,))
  check(rpc('chantier_naval_commander',['bateau_3',token(1)])['ok'],'contre-épreuve : ancien serveur acceptait la commande depuis la rue (NULL)')
  own('ROLLBACK TO SAVEPOINT ancien')
  own('SAVEPOINT correction');sql(CORRECTION.read_text());sql(CORRECTION.read_text())
  check(own("SELECT count(*) FROM information_schema.columns WHERE table_name='chantier_naval_commandes' AND column_name='historique'")==1,'migration corrective idempotente')
  before=snap();own("SAVEPOINT rue;UPDATE personnages_donnees SET current_building=NULL WHERE name=%s",(NOM,));before=snap()
  check(rpc('chantier_naval_commander',['bateau_3',token(1)])['raison']=='lieu_incorrect' and snap()==before,'rue NULL refusée sans débit ni commande')
  own('ROLLBACK TO SAVEPOINT rue')
  check(rpc('chantier_naval_commander',['bateau_3',token(1)],uid='')['raison']=='non_authentifie','commande sans session refusée')
  for col,value in [('country','soviet'),('current_city','capitale'),('current_building','ailleurs')]:
   own('SAVEPOINT lieu');own('UPDATE personnages_donnees SET '+col+'=%s WHERE name=%s',(value,NOM));before=snap()
   check(rpc('chantier_naval_commander',['bateau_3',token(1)])['raison']=='lieu_incorrect' and snap()==before,'territoire refusé : '+col);own('ROLLBACK TO SAVEPOINT lieu')
  own("SAVEPOINT pauvre;UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name=%s;UPDATE comptes_bancaires SET solde=0",(NOM,));before=snap()
  check(rpc('chantier_naval_commander',['bateau_3',token(1)])['raison']=='fonds_insuffisants' and snap()==before,'fonds initiaux insuffisants sans mutation');own('ROLLBACK TO SAVEPOINT pauvre')
  check(not own("SELECT has_function_privilege('authenticated','chantier_naval_avancer_interne(uuid)','EXECUTE')"),'progression interne interdite au navigateur')
  check(not own("SELECT has_function_privilege('anon','chantier_naval_commander(text,uuid)','EXECUTE')"),'commande interdite aux anonymes')
  c=rpc('chantier_naval_commander',['bateau_3',token(1)]);cid=c['commande']
  check(c['ok'] and c['acompte']==31500 and c['paie']['liquide']==168500,'35 pourcent réels et solde courant retourné')
  before=snap();v=rpc('chantier_naval_commander',['bateau_3',token(1)]);check(v['rejeu'] and snap()==before,'réponse perdue : commande et acompte uniques')
  before=snap();check(rpc('chantier_naval_commander',[None,token(1)])['raison']=='requete_deja_utilisee' and snap()==before,'nonce lié au modèle même avec modèle NULL')
  for cle in ['bois','metal','derives_petrochimiques']:
   args={'bois':2000,'metal':2000,'derives':1000};args['derives' if cle=='derives_petrochimiques' else cle]=0;stock(**args);before=snap();v=avancer(cid)
   check(v['raison']=='matieres_insuffisantes' and v['matiere']==cle and snap()==before,'pénurie '+cle+' : aucun stock consommé, paiement ou jour')
  stock(bois=2000,metal=2000,derives=1000,prix={'bois':1000,'metal':1000,'derives_petrochimiques':1000});before=snap()
  check(avancer(cid)['raison']=='prix_matiere_superieur_budget' and snap()==before,'prix trop hauts sans dépassement du contrat ni paiement')
  stock(bois=2000,metal=2000,derives=1000,reserve={'bois':2000});before=snap()
  check(avancer(cid)['raison']=='matieres_insuffisantes' and snap()==before,'réserve militaire jamais consommée par un chantier civil')
  stock();v=avancer(cid);check(v['ok'] and v['jours']==1,'reprise automatique après réapprovisionnement réel du stock partagé')
  before=snap();check(avancer(cid)['rejeu'] and snap()==before,'traitement quotidien répété sans second jour ou paiement')
  own("UPDATE chantier_naval_commandes SET dernier_jour=(now() AT TIME ZONE 'Europe/Paris')::date+1 WHERE id=%s",(cid,));before=snap()
  check(avancer(cid)['rejeu'] and snap()==before,'horloge antérieure au dernier jour : aucune progression rétroactive')
  nextday(cid);own("SAVEPOINT echeance;UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name=%s;UPDATE comptes_bancaires SET solde=0",(NOM,));before=snap()
  check(avancer(cid)['raison']=='fonds_insuffisants' and snap()==before,'échéance refusée : ni matériaux ni progression');own('ROLLBACK TO SAVEPOINT echeance')
  # Panne après débit : l'exception annule fonds, stock, jour et registre ensemble.
  own("SAVEPOINT incident;CREATE FUNCTION fixture_panne_naval() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.id='republic_entrepot_ville_a' THEN RAISE EXCEPTION 'panne_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER fixture_panne BEFORE UPDATE ON caisses_batiments FOR EACH ROW EXECUTE FUNCTION fixture_panne_naval()")
  before=snap();own('SAVEPOINT acte')
  try:avancer(cid);raise AssertionError('panne non propagée')
  except psycopg2.Error as e:check('panne_fixture' in str(e),'panne après débit détectée');sql('ROLLBACK TO SAVEPOINT acte')
  check(snap()==before,'rollback complet après panne de la caisse fournisseur');own('ROLLBACK TO SAVEPOINT incident')
  # Une date vieille de plusieurs jours n'autorise pas plusieurs journées de rattrapage.
  own("UPDATE chantier_naval_commandes SET dernier_jour=(now() AT TIME ZONE 'Europe/Paris')::date-20 WHERE id=%s",(cid,));check(avancer(cid)['jours']==2,'vingt jours écoulés : une seule journée effective');check(avancer(cid)['rejeu'],'aucun rattrapage au second appel')
  # Le changement du prix du catalogue ne revalorise pas un contrat signé.
  own("UPDATE chantier_naval_modeles SET prix_total_fr=90001 WHERE code='bateau_3'")
  for j in range(3,8):nextday(cid);check(avancer(cid)['jours']==j,'standard journée '+str(j))
  own("UPDATE chantier_naval_modeles SET prix_total_fr=90000 WHERE code='bateau_3'")
  check(own('SELECT somme_versee FROM chantier_naval_commandes WHERE id=%s',(cid,))==90000,'prix contractuel standard conservé exactement')
  check(own('SELECT matieres_consommees FROM chantier_naval_commandes WHERE id=%s',(cid,))=={'bois':1200,'metal':1200,'derives_petrochimiques':600},'recette standard exacte')
  before=snap();check(avancer(cid)['etat']=='acheve' and snap()==before,'livraison standard répétée sans effet')
  stock();c2=rpc('chantier_naval_commander',['bateau_5',token(2)]);cid2=c2['commande'];check(c2['acompte']==52500,'35 pourcent du grand modèle')
  for j in range(1,11):
   if j>1:nextday(cid2)
   check(avancer(cid2)['jours']==j,'grande capacité journée '+str(j))
  check(own('SELECT matieres_consommees FROM chantier_naval_commandes WHERE id=%s',(cid2,))=={'bois':1800,'metal':1800,'derives_petrochimiques':600},'recette grande capacité exacte')
  commandes=rpc('chantier_naval_mes_commandes');check(len(commandes)==2 and all(c['bateau']['immatriculation']==c['bateau_id'] and c['bateau']['port']=='port-sainte-marie' and not c['bateau']['navigation_active'] for c in commandes),'deux bateaux immatriculés localisés et non navigables')
  check(sorted((c['bateau']['passagers'],c['bateau']['fret']) for c in commandes)==[(3,300),(5,500)],'capacités physiques des deux bateaux exactes')
  check(own('SELECT count(*) FROM chantier_naval_bateaux')==2,'un seul bateau physique par contrat')
  check(own('SELECT jsonb_array_length(inventory) FROM personnages_donnees WHERE name=%s',(NOM,))==1,'aucun bateau dans l’inventaire classique')
  check(own('SELECT jsonb_array_length(historique) FROM chantier_naval_commandes WHERE id=%s',(cid,))==8,'trace acompte et sept paiements standard')
  check(own('SELECT jsonb_array_length(historique) FROM chantier_naval_commandes WHERE id=%s',(cid2,))==11,'trace acompte et dix paiements grand modèle')
  check(own("SELECT count(*) FROM entrepot_journal WHERE contrepartie LIKE 'Commande navale %'")==51,'51 sorties de matière attribuées aux contrats')
  restant=own('SELECT sum(liquide) FROM personnages_donnees WHERE name=%s',(NOM,))+own('SELECT sum(solde) FROM comptes_bancaires')
  caisses=own("SELECT sum((data->>'solde')::numeric) FROM caisses_batiments")
  check(restant==160000 and caisses==240000 and restant+caisses==400000,'conservation de tous les fonds joueur, banque, séquestres et bénéficiaires')
  check(own("SELECT sum((data->>'solde')::numeric) FROM caisses_batiments WHERE id LIKE 'republic_ville_a_chantier-naval-commande-%'")==0,'séquestres soldés après livraison')
  check(rpc('chantier_naval_mes_commandes',uid='00000000-0000-4000-8000-0000000004ca')==[],'autre PJ : aucun contrat ni bateau privé exposé')
  check(not own("SELECT has_table_privilege('authenticated','chantier_naval_bateaux','SELECT')"),'lecture directe des bateaux privée refusée')
  own('ROLLBACK TO SAVEPOINT correction');check(own("SELECT count(*) FROM information_schema.columns WHERE table_name='chantier_naval_commandes' AND column_name='historique'")==0,'rollback de la correction annule le schéma et tous les scénarios')
  own(CORRECTION.read_text());check(own("SELECT count(*) FROM chantier_naval_commandes")==0,'rejeu après rollback sans commande parasite')
  if concurrence:
   from concurrent.futures import ThreadPoolExecutor
   stock();db.commit()
   def thread(fn,args,role):
    with psycopg2.connect(srv.get_uri()) as other:
     cur=other.cursor();cur.execute("SET LOCAL statement_timeout='12s';SET LOCAL lock_timeout='8s';SET LOCAL ROLE "+role);cur.execute("SELECT set_config('request.jwt.claim.sub',%s,true),set_config('request.path',%s,true)",(UID,'/rpc/'+fn));cur.execute('SELECT public.'+fn+'('+','.join(['%s']*len(args))+')',args);return cur.fetchone()[0]
   with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(lambda _:thread('chantier_naval_commander',['bateau_3',token(9)],'authenticated'),range(2)))
   check(all(v['ok'] for v in rs) and sum(bool(v.get('rejeu')) for v in rs)==1,'double clic concurrent : un seul acompte et un seul contrat');c=rs[0]['commande']
   with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(lambda _:thread('chantier_naval_avancer_interne',[c],'service_role'),range(2)))
   check(all(v['ok'] for v in rs) and sum(bool(v.get('rejeu')) for v in rs)==1,'deux traitements simultanés : une seule journée')
   check(own('SELECT jours_faits FROM chantier_naval_commandes WHERE id=%s',(c,))==1,'progression concurrente exacte')
   print('Concurrence : fixtures exclusivement locales commitées, cluster détruit.',flush=True)
  db.rollback();db.close();print(json.dumps({'ok':True,'assertions':n,'concurrence':concurrence,'production':False}),flush=True)
 finally:srv.cleanup()
if __name__=='__main__':main('--concurrence' in sys.argv)
