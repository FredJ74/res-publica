"""GoTrue/PostgREST natifs locaux : vrais logins, comptes entièrement jetables.

Les binaires sont fournis explicitement. Aucun secret, DSN distant ou compte
existant accepté ; aucun jeton ni mot de passe n'entre dans le rapport.
"""
import json,os,secrets,socket,subprocess,time,urllib.request,urllib.error,urllib.parse,uuid
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
def port_libre():
 with socket.socket() as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
class Services:
 def __init__(self,uri,repertoire,gotrue,postgrest):
  u=urllib.parse.urlsplit(uri)
  if u.hostname or not urllib.parse.parse_qs(u.query).get('host',[''])[0].startswith('/'):raise ValueError('Socket PostgreSQL local requis')
  self.uri=uri;self.rep=Path(repertoire);self.gotrue=gotrue;self.rest=postgrest;self.processus=[];self.fichiers=[];self.secret=secrets.token_urlsafe(48);self.auth_url='http://127.0.0.1:'+str(port_libre());self.rest_url='http://127.0.0.1:'+str(port_libre())
 def lancer(self,binaire,variables,nom):
  f=(self.rep/(nom+'.log')).open('wb');self.fichiers.append(f)
  env={'PATH':os.environ.get('PATH','/usr/bin:/bin'),'HOME':str(self.rep),**variables}
  self.processus.append(subprocess.Popen([str(binaire)],env=env,stdout=f,stderr=subprocess.STDOUT))
 def attendre(self,url):
  limite=time.monotonic()+35
  while time.monotonic()<limite:
   if any(p.poll() is not None for p in self.processus):raise RuntimeError('Service local arrêté ; consulter son journal privé')
   try:
    with urllib.request.urlopen(url,timeout=1):return
   except (OSError,urllib.error.URLError):time.sleep(.2)
  raise RuntimeError('Initialisation du service local non confirmée')
 def demarrer_auth(self):
  u=urllib.parse.urlsplit(self.uri);uri=urllib.parse.urlunsplit((u.scheme,'supabase_auth_admin@',u.path,u.query,u.fragment))
  self.lancer(self.gotrue,{'GOTRUE_DB_DRIVER':'postgres','GOTRUE_DB_DATABASE_URL':uri+'&sslmode=disable','GOTRUE_DB_NAMESPACE':'auth','GOTRUE_API_HOST':'127.0.0.1','PORT':self.auth_url.rsplit(':',1)[1],'GOTRUE_API_PORT':self.auth_url.rsplit(':',1)[1],'API_EXTERNAL_URL':self.auth_url,'GOTRUE_SITE_URL':self.auth_url,'GOTRUE_JWT_SECRET':self.secret,'GOTRUE_JWT_AUD':'authenticated','GOTRUE_JWT_DEFAULT_GROUP_NAME':'authenticated','GOTRUE_EXTERNAL_EMAIL_ENABLED':'true','GOTRUE_MAILER_AUTOCONFIRM':'true','GOTRUE_DISABLE_SIGNUP':'false','GOTRUE_LOG_LEVEL':'error'},'gotrue')
  self.attendre(self.auth_url+'/health')
 def demarrer_rest(self,q):
  q.execute('ALTER ROLE authenticator LOGIN;GRANT anon,authenticated TO authenticator');q.connection.commit()
  u=urllib.parse.urlsplit(self.uri);uri=urllib.parse.urlunsplit((u.scheme,'authenticator@',u.path,u.query,u.fragment))
  self.lancer(self.rest,{'PGRST_DB_URI':uri,'PGRST_DB_ANON_ROLE':'anon','PGRST_DB_SCHEMAS':'public','PGRST_JWT_SECRET':self.secret,'PGRST_SERVER_HOST':'127.0.0.1','PGRST_SERVER_PORT':self.rest_url.rsplit(':',1)[1],'PGRST_LOG_LEVEL':'crit'},'postgrest')
  self.attendre(self.rest_url+'/')
 def fermer(self):
  for p in reversed(self.processus):
   if p.poll() is None:
    p.terminate()
    try:p.wait(timeout=5)
    except subprocess.TimeoutExpired:p.kill();p.wait(timeout=5)
  for f in self.fichiers:f.close()
 def http(self,url,charge,token=None):
  # Les seules origines utilisables viennent des ports loopback de cette instance.
  if not any(url.startswith(x+'/') for x in [self.auth_url,self.rest_url]):raise ValueError('Origine hors fixture interdite')
  h={'Content-Type':'application/json'}
  if token:h['Authorization']='Bearer '+token
  try:
   with urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(charge).encode(),headers=h),timeout=15) as r:return r.status,json.load(r)
  except urllib.error.HTTPError as e:
   try:body=json.load(e)
   except ValueError:body={}
   return e.code,body
 def recette(self,q):
  comptes=[];resultats=[]
  def cas(nom,condition):
   assert condition,nom;resultats.append({'cas':nom,'ok':True})
  def photo():
   q.execute('SELECT name,pa,arg,liquide,current_city,current_building,current_room,inventory,inventory_revision FROM personnages_donnees WHERE name LIKE %s ORDER BY name',('__hg219_http_%',));v=q.fetchall();q.connection.commit();return v
  for i in range(3):
   email='hg219-'+secrets.token_hex(8)+'@example.invalid';password=secrets.token_urlsafe(32)
   status,v=self.http(self.auth_url+'/signup',{'email':email,'password':password});assert status in [200,201],'signup local refusé'
   status,v=self.http(self.auth_url+'/token?grant_type=password',{'email':email,'password':password});assert status==200 and v.get('access_token'),'login local refusé'
   comptes.append({'nom':'__hg219_http_'+str(i),'uid':v['user']['id'],'token':v['access_token'],'email':email,'password':password})
   q.execute("SELECT set_config('request.jwt.claim.sub',%s,true),set_config('request.jwt.claims',%s,true)",(v['user']['id'],json.dumps({'sub':v['user']['id'],'role':'authenticated'})))
   q.execute("INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,pa,arg,liquide,hp) VALUES(%s,%s,'republic','capitale','mairie','accueil',100,1000,1000,100)",(comptes[-1]['nom'],v['user']['id']));q.connection.commit()
  def rpc(fn,params=None,qui=0):
   status,v=self.http(self.rest_url+'/rpc/'+fn,params or {},comptes[qui]['token']);assert status==200,fn+' HTTP '+str(status);return v
  cas('trois_logins_GoTrue_UID_et_personnage',all(rpc('mon_personnage',qui=i)==c['nom'] for i,c in enumerate(comptes)))
  status,v=self.http(self.rest_url+'/rpc/groupe_pj_rejoindre',{'p_chef':comptes[0]['nom']});cas('anonyme_refuse',status>=400 or v.get('ok') is False)
  avant=photo();cas('adhesion_HTTP',rpc('groupe_pj_rejoindre',{'p_chef':comptes[0]['nom']},1)['ok']);cas('adhesion_repetee_sans_depense',rpc('groupe_pj_rejoindre',{'p_chef':comptes[0]['nom']},1)['ok'] and photo()==avant)
  b=comptes[1];status,v=self.http(self.auth_url+'/token?grant_type=password',{'email':b['email'],'password':b['password']});cas('reconnexion_meme_UID',status==200 and v['user']['id']==b['uid']);b['token']=v['access_token'];cas('groupe_persistant_apres_reconnexion',len(rpc('groupe_pj_lire',qui=1)['membres'])==2)
  cas('depart_groupe_HTTP',rpc('groupe_pj_quitter',qui=1)['ok'] and photo()==avant)
  avant=photo();v=rpc('pnj_rappeler_radio',{'p_ancre':'agent_inconnu'});cas('radio_absente_refusee_sans_depense',v.get('ok') is False and v.get('raison')=='radio_appelant_absente' and photo()==avant)
  v=rpc('police_detection_verifier',{'p_batiment':'mairie','p_piece':'accueil','p_rue':None});cas('detection_prioritaire_sans_fausse_interception',v.get('ok') is False and not v.get('detecte') and photo()==avant)
  q.execute("SELECT set_config('request.jwt.claim.sub',%s,true)",(comptes[0]['uid'],));q.execute("INSERT INTO pnj_membres(id,famille,nom,pays,proprietaire_pj,ville,building_id,room_id,classe,car_int,car_cha,car_vol,car_per,car_dup,car_ent) VALUES('__hg219_http_agent','employe','Agent HTTP fictif','republic',%s,'capitale','mairie','accueil','beta',10,10,10,10,10,10)",(comptes[0]['nom'],));q.connection.commit()
  cas('PNJ_pris_par_employeur_HTTP',rpc('pnj_prendre',{'p_ids':['__hg219_http_agent']})['ok'])
  avant=photo();v=rpc('pnj_prendre',{'p_ids':['__hg219_http_agent']},1);cas('PNJ_tiers_refuse_sans_mutation',v.get('ok') is False and photo()==avant)
  # Ressources de fixture uniquement : aucune donnée réelle et aucun mécanisme financier remplacé.
  q.execute("UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name=%s",(comptes[0]['nom'],));q.connection.commit();avant=photo()
  v=rpc('payer_ordre',{'p_acteur':comptes[0]['nom'],'p_fn':'acheter_gilet','p_pa':1,'p_cost':600});cas('fonds_insuffisants_refuses_sans_PA_ni_mutation',v.get('ok') is False and v.get('raison')=='fonds_insuffisants' and photo()==avant)
  q.execute("UPDATE personnages_donnees SET liquide=1000,arg=1000,inventory='[{\"id\":\"radio\",\"produitMilitaire\":\"radio\",\"qty\":1}]' WHERE name=%s",(comptes[0]['nom'],))
  q.execute("UPDATE pnj_membres SET leader_pj=NULL,ville='montrouge',building_id='mairie',room_id='accueil' WHERE id='__hg219_http_agent'")
  q.execute("INSERT INTO pnj_possessions(pnj_id,objet) VALUES('__hg219_http_agent','{\"produitMilitaire\":\"radio\"}')");q.connection.commit();avant=photo()
  v=rpc('pnj_rappeler_radio',{'p_ancre':'__hg219_http_agent'});cas('radio_hors_ville_refusee',v.get('ok') is False and v.get('raison')=='radio_hors_ville' and photo()==avant)
  q.execute("UPDATE pnj_membres SET ville='capitale' WHERE id='__hg219_http_agent'");q.connection.commit()
  v=rpc('pnj_rappeler_radio',{'p_ancre':'__hg219_http_agent'});cas('radio_meme_ville_reelle',v.get('ok') is True and v.get('rappeles')==1)
  v=rpc('pnj_rappeler_radio',{'p_ancre':'__hg219_http_agent'});cas('radio_rejeu_sans_deplacement_supplementaire',v.get('ok') is True and v.get('deja_present') is True and photo()==avant)
  req=str(uuid.uuid4());charge={'p_cible':comptes[1]['nom'],'p_mode':'mains','p_requete':req};
  with ThreadPoolExecutor(2) as pool:reponses=list(pool.map(lambda _:rpc('combat_ouvrir',charge),[0,1]))
  v=reponses[0];cas('double_clic_HTTP_meme_combat',reponses[0]==reponses[1]);q.execute('SELECT count(*) FROM navigation_requetes WHERE acteur=%s AND requete=%s',(comptes[0]['nom'],req));cas('double_clic_HTTP_un_seul_recu',q.fetchone()[0]==1);q.connection.commit();cas('combat_mixte_HTTP_ouvert',v.get('ok') is True);apres=photo();cas('reponse_ouverture_ignoree_puis_rejeu_sans_double_debit',rpc('combat_ouvrir',charge)==v and photo()==apres)
  q.execute('SELECT count(*),count(pnj_id) FROM batailles_engagements WHERE bataille_id=%s',(v['bataille'],));cas('composition_reelle_PJ_PNJ',q.fetchone()==(3,1));q.connection.commit()
  charge={'p_bataille_id':v['bataille'],'p_round_attendu':0,'p_requete':str(uuid.uuid4())};v=rpc('militaire_bataille_poursuivre',charge);cas('round_reel_HTTP',v.get('ok') is True and v.get('round')==1);apres=photo();cas('round_rejoue_sans_double_effet',rpc('militaire_bataille_poursuivre',charge)==v and photo()==apres)
  v=rpc('militaire_bataille_poursuivre',{'p_bataille_id':charge['p_bataille_id'],'p_round_attendu':1,'p_requete':str(uuid.uuid4())},2);cas('tiers_non_engage_refuse',v.get('ok') is False and v.get('raison')=='non_engage' and photo()==apres)
  q.execute("UPDATE personnages_donnees SET hp=0 WHERE name=%s",(comptes[2]['nom'],));q.connection.commit();avant=photo()
  v=rpc('rue_position_enregistrer',{'p_noeud':'luthecia-hotel-de-ville'},2);cas('coma_refuse_sortie_sans_mutation_HTTP',v.get('ok') is False and v.get('raison')=='acteur_incapacite' and photo()==avant)
  q.execute("UPDATE personnages_donnees SET hp=100 WHERE name=%s",(comptes[2]['nom'],));q.execute("SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',true),set_config('request.jwt.claim.sub','',true),set_config('request.path','/rpc/police_action',true)")
  q.execute("SELECT detention_ouvrir_interne(%s,'Recette HTTP isolée',1,'capitale','republic','[]'::jsonb,'police','arrestation',NULL)",(comptes[2]['nom'],));cas('ecrou_reel_moteur_interne_local',q.fetchone()[0]['ok']);q.connection.commit();avant=photo()
  v=rpc('rue_position_enregistrer',{'p_noeud':'luthecia-hotel-de-ville'},2);cas('prison_refuse_sortie_sans_mutation_HTTP',v.get('ok') is False and v.get('raison')=='personnage_indisponible' and photo()==avant)
  return {'type':'GoTrue login + PostgREST HTTP réels, environnement natif isolé','cas':resultats,'production':False,'limites':['pas de recette interface Chromium du jeu','réponse ignorée côté client, pas de panne réseau injectée','écrou initié par le moteur interne SQL local ; pas d’arrestation via interface policière']}
