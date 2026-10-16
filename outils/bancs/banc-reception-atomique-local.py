#!/usr/bin/env python3
"""PostgreSQL jetable exclusivement ; aucun DSN ou compte reel accepte.
La fonction auth.uid est une fixture de JWT ; pas un test d'authentification Supabase.
"""
import argparse,json,re,tempfile,threading,time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[2]
MIG=ROOT/'migrations/20261016131932_reception_objets_atomique.sql'
UID='11111111-1111-1111-1111-111111111111'
SCHEMA='''
CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('hg.uid',true),'')::uuid $$;
CREATE TABLE personnages_donnees(id uuid DEFAULT gen_random_uuid(),name text UNIQUE,user_id uuid,inventory jsonb DEFAULT '[]',quete_carriere jsonb,pa integer DEFAULT 10);
CREATE VIEW personnages AS SELECT * FROM personnages_donnees;
CREATE TABLE objets_recus(id text PRIMARY KEY,destinataire text,expediteur text,data jsonb);
ALTER TABLE objets_recus ENABLE ROW LEVEL SECURITY;
CREATE POLICY fixture_proprietaire ON objets_recus TO authenticated USING(destinataire='Alice');
GRANT USAGE ON SCHEMA public,auth TO authenticated;
GRANT SELECT,UPDATE ON personnages_donnees TO authenticated;
GRANT SELECT,DELETE ON objets_recus TO authenticated;
CREATE FUNCTION tracts_reclamer_don(text,text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM personnages_donnees WHERE name=$1 AND user_id=auth.uid()) THEN RAISE EXCEPTION 'acteur_interdit';END IF;
END $$;
'''
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--local-jetable',action='store_true',required=True);p.parse_args()
 import pgserver,psycopg2
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-reception-'),cleanup_mode='delete')
 uri=server.get_uri();c=psycopg2.connect(uri);c.autocommit=True;q=c.cursor();q.execute(SCHEMA)
 def contexte(cursor=q,path='/rpc/inventaire_reclamer_livraison',uid=UID):
  cursor.execute("SELECT set_config('hg.uid',%s,false),set_config('request.path',%s,false)",(uid,path))
 contexte();sql=MIG.read_text();q.execute(sql);q.execute(sql)
 print('OK migration, garde de versions et rejeu DDL (aucun acte metier).')
 # Charger de vrais helpers archives, sans restaurer un ancien serveur.
 def charger(nom):
  for f in (ROOT/'baseline/domaines').rglob('*fonctions*.sql'):
   for m in re.finditer(r'CREATE OR REPLACE FUNCTION public\.'+re.escape(nom)+r'\([\s\S]*?\$function\$;',f.read_text()):
    q.execute(m[0]);return
  raise AssertionError(nom)
 for nom in ['inventaire_ajouter','inventaire_place_restante','inventaire_localiser','inventaire_objet_protege','inventaire_quantite','inventaire_retirer','inventaire_retirer_position','helvetia_inventaire_sortie','inventaire_detruire','inventaire_consommer']:
  charger(nom)
 n=0
 def ok(message):
  nonlocal n;n+=1;print('OK',n,message)
 def reset(inv=None):
  q.execute('TRUNCATE personnages_donnees,objets_recus,inventaire_livraisons_recues')
  q.execute('INSERT INTO personnages_donnees(name,user_id,inventory) VALUES (%s,%s,%s),(%s,%s,%s)',('Alice',UID,json.dumps(inv or []),'Bob','22222222-2222-2222-2222-222222222222','[]'))
  contexte()
 def envoyer(obj,id='livraison-1',dest='Alice',chaine=True):
  # data jsonb contenant une chaine JSON : format existant de nombreux producteurs.
  data=json.dumps(json.dumps(obj)) if chaine else json.dumps(obj)
  q.execute('INSERT INTO objets_recus VALUES(%s,%s,%s,%s)',(id,dest,'Donneur',data))
 def etat(cursor=q):
  cursor.execute("SELECT inventaire_reception_etat('Alice')");return cursor.fetchone()[0]
 def recevoir(rev=0,id='livraison-1',cursor=q):
  cursor.execute("SELECT inventaire_reclamer_livraison('Alice',%s,%s)",(id,rev));return cursor.fetchone()[0]
 def compte(table):
  assert table in ['objets_recus','inventaire_livraisons_recues'];q.execute('SELECT count(*) FROM '+table);return q.fetchone()[0]
 reset();objet={'name':'Chocolat','familleProduitMarche':'aliment','dateAchat':1792150000000,'provenance':{'fondsId':'fixture'},'photo':'x','origineQuete':'quete-fixture'}
 envoyer(objet);r=recevoir();assert r['inventory']==[objet] and compte('objets_recus')==0 and compte('inventaire_livraisons_recues')==1
 assert recevoir()['rejeu'] and etat()['inventory']==[objet];ok('reception puis repetitions, metadonnees alimentaires/quete intactes')
 reset();envoyer({'name':'Document','texte':'integral'},chaine=False);assert recevoir()['inventory'][0]['texte']=='integral';ok('data JSON objet et document integral')
 reset([{'name':'Sac','stackable':True,'stackKey':'fer','qty':99,'meta':'conservee'}]);envoyer({'name':'Fer','stackable':True,'stackKey':'fer','qty':5});r=recevoir();assert r['inventory'][0]['qty']==104 and r['inventory'][0]['meta']=='conservee';ok('empilement au-dela du plafond : surcharge preservee')
 reset();envoyer({'name':'Arme','exemplaire':{'id':'unique'},'encombrement':2});assert recevoir()['inventory'][0]['exemplaire']=={'id':'unique'};ok('exemplaire individualise')
 reset([{'type':'tract','cible':'Candidate','quantite':4,'legal':True}]);envoyer({'type':'tract','cible':'Candidate','quantite':6,'legal':True},id='don-tracts-1');assert recevoir(id='don-tracts-1')['inventory'][0]['quantite']==10;ok('fusion des quantites de tracts')
 reset([{'type':'tract','cible':'Candidate','quantite':4,'origineQuete':'jean_lou'}]);envoyer({'type':'tract','cible':'Candidate','quantite':6},id='don-tracts-1');assert len(recevoir(id='don-tracts-1')['inventory'])==2;ok('tracts de quete non fusionnes')
 reset();envoyer({'familleProduitMarche':'carte_postale','message':'Confidentiel','expediteur':'Cache'});assert recevoir()['inventory'][0]['message']=='Confidentiel';ok('carte postale complete, confidentialite des notifications testee en JS')
 reset();envoyer({'name':'Autrui'},dest='Bob');assert recevoir()['ok'] is False and compte('objets_recus')==1;ok('livraison d autrui refusee')
 contexte(uid='22222222-2222-2222-2222-222222222222')
 try: etat();raise AssertionError('Refus attendu')
 except psycopg2.Error as e: assert e.pgcode=='42501'
 contexte(uid='')
 try: recevoir();raise AssertionError('Refus attendu')
 except psycopg2.Error as e: assert e.pgcode=='42501'
 ok('autre compte et absence de UID refuses par controle reel SQL (UID de fixture)')
 reset();envoyer({'name':'Annulation'});q.execute('BEGIN');recevoir();q.execute('ROLLBACK');assert etat()['inventory']==[] and compte('objets_recus')==1;ok('interruption avant commit : deux operations annulees')
 q.execute("CREATE FUNCTION fixture_erreur_delete() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'erreur_apres_insertion';END $$")
 q.execute('CREATE TRIGGER fixture_erreur BEFORE DELETE ON objets_recus FOR EACH ROW EXECUTE FUNCTION fixture_erreur_delete()')
 try: recevoir();raise AssertionError('Erreur attendue')
 except psycopg2.Error as e: assert 'erreur_apres_insertion' in str(e)
 assert etat()['inventory']==[] and compte('objets_recus')==1 and compte('inventaire_livraisons_recues')==0
 q.execute('DROP TRIGGER fixture_erreur ON objets_recus');ok('erreur apres insertion : rollback inventaire, revision, recu et livraison')
 recevoir();assert recevoir()['rejeu'] and len(etat()['inventory'])==1;ok('reponse perdue apres commit : repetition sans second ajout')
 reset();envoyer({'name':'Concurrent'});barriere=threading.Barrier(2)
 def concurrent(_):
  conn=psycopg2.connect(uri);conn.autocommit=True
  try:
   with conn.cursor() as z: contexte(z);barriere.wait(timeout=10);return recevoir(cursor=z)
  finally: conn.close()
 with ThreadPoolExecutor(max_workers=2) as pool: rr=list(pool.map(concurrent,[0,1]))
 assert all(x['ok'] for x in rr) and sum(not x['rejeu'] for x in rr)==1 and len(etat()['inventory'])==1;ok('deux connexions/onglets concurrents, un seul ajout')
 # Le client garde la revision avec son snapshot. Un autre onglet ne peut la rebaser.
 q.execute("SELECT inventaire_sauver_revision('Alice',0,'[]')");assert q.fetchone()[0]['raison']=='inventaire_perime';assert len(etat()['inventory'])==1;ok('ancienne sauvegarde RPC refusee apres reception')
 q.execute('SET ROLE authenticated');contexte(path='/personnages')
 q.execute("UPDATE personnages_donnees SET inventory='[]', inventory_revision=0 WHERE name='Alice'")
 q.execute('RESET ROLE');assert len(etat()['inventory'])==1 and etat()['revision']==1;ok('ancien PATCH REST conserve inventaire et revision, meme avec revision falsifiee')
 q.execute('SET ROLE authenticated');contexte(path='/rpc/inventaire_sauver_revision')
 q.execute("SELECT inventaire_sauver_revision('Alice',1,%s)",(json.dumps(etat()['inventory']+[{'name':'Ajout local'}]),))
 assert q.fetchone()[0]['ok'];q.execute('RESET ROLE');assert etat()['revision']==2
 ok('sauvegarde CAS authentifiee sous contexte RPC conserve les ajouts legacy')
 q.execute('SET ROLE authenticated');contexte(path='/objets_recus')
 try:q.execute('DELETE FROM objets_recus');raise AssertionError('Ancien DELETE doit etre refuse')
 except psycopg2.Error as e:assert e.pgcode=='42501'
 try:q.execute("SELECT tracts_reclamer_don('a','Alice')");raise AssertionError('Ancienne RPC doit etre refusee')
 except psycopg2.Error as e:assert e.pgcode=='42501'
 q.execute('RESET ROLE');contexte();ok('anciennes reclamations DELETE et tracts bloquees pour authenticated')
 q.execute("SELECT inventaire_detruire('Alice',0,'{\"name\":\"Concurrent\"}',1)");assert q.fetchone()[0]['ok'];assert etat()['inventory']==[{'name':'Ajout local'}] and etat()['revision']==3;ok('fonction inventaire_detruire archivee compatible, revision incrementee')
 reset();envoyer({'name':'Contexte invalide'});q.execute('SET ROLE authenticated');contexte(path='/contexte-inconnu')
 try:recevoir();raise AssertionError('Contexte RPC requis')
 except psycopg2.Error as e:assert 'inventaire_ecriture_non_appliquee' in str(e)
 q.execute('RESET ROLE');contexte();assert compte('objets_recus')==1 and etat()['inventory']==[]
 ok('contexte PostgREST incompatible : rollback, jamais suppression seule')
 q.execute('SET ROLE authenticated');contexte();assert recevoir()['ok'];q.execute('RESET ROLE')
 ok('reception sous role authenticated et chemin RPC, acces SQL effectif sans donnee reelle')
 reset();envoyer({'name':'Chocolat','familleProduitMarche':'aliment','dateAchat':int(time.time()*1000)})
 recevoir();q.execute("SELECT inventaire_consommer('Alice',0,'{\"name\":\"Chocolat\"}')");r=q.fetchone()[0]
 assert r['ok'] and r['aliment_frais'] and r['pa']==11 and etat()['inventory']==[]
 assert etat()['revision']==2
 ok('aliment recu consommable par la vraie fonction archivee, effet PA inchange')
 reset();envoyer({'name':'Colis','origineQuete':'jean_lou','protege':True});recevoir()
 q.execute("SELECT inventaire_place_restante(inventory) FROM personnages_donnees WHERE name='Alice'");assert q.fetchone()[0]==99
 q.execute("SELECT inventaire_ajouter(inventory,'materiau',2,'fixture') FROM personnages_donnees WHERE name='Alice'")
 assert q.fetchone()[0][0]['origineQuete']=='jean_lou'
 ok('helpers existants ajouter et place restante conservent le nouvel objet et ses metadonnees')
 q.execute('BEGIN');q.execute('ALTER TABLE inventaire_livraisons_recues ADD COLUMN inconnue text')
 try:q.execute(sql);raise AssertionError('Schema inconnu attendu')
 except psycopg2.Error as e:assert 'reception_registre_schema_inconnu' in str(e)
 q.execute('ROLLBACK');ok('derive du schema de recus refusee')
 reset();envoyer({'name':'Invalide'},chaine=False);q.execute("UPDATE objets_recus SET data='\"pas du JSON\"'")
 try: recevoir();raise AssertionError('Erreur attendue')
 except psycopg2.Error: pass
 assert compte('objets_recus')==1 and etat()['inventory']==[];ok('format inconnu : aucune purge et aucune livraison perdue')
 # Les fonctions nouvelles inconnues ne sont jamais remplacees par un rejeu de migration.
 q.execute("CREATE OR REPLACE FUNCTION inventaire_reception_etat(p_acteur text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$")
 try: q.execute(sql);raise AssertionError('Garde attendue')
 except psycopg2.Error as e: assert 'reception_definition_inconnue' in str(e)
 ok('definition modifiee refusee par la migration')
 c.close();print(n,'groupes de scenarios locaux reussis ; aucun acces Supabase')
if __name__=='__main__':main()
