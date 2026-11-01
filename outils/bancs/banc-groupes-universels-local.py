#!/usr/bin/env python3
"""Vrais corps SQL proposés + gardes/contraintes PNJ du dépôt, PostgreSQL jetable.
Identité JWT de fixture ; aucune authentification Supabase ni écriture distante.
Les savepoints annulent les actes de la session principale, pas les commits
des connexions concurrentes. Chaque nouvelle scène prépare ses propres fixtures ;
le cluster entièrement fictif est supprimé à la fin.
"""
import importlib.util,json,re,sys,tempfile,os,traceback
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('audit',R/'outils/bancs/banc-audit-securite-135-local.py')
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
def decrire_echec(exc):
 """Préserve le lieu et la trace d'une assertion vide ; ne change pas le verdict."""
 cadres=traceback.extract_tb(exc.__traceback__)
 dernier=cadres[-1] if cadres else None
 fichier=None
 if dernier:
  p=Path(dernier.filename).resolve()
  fichier=str(p.relative_to(R)) if p.is_relative_to(R) else p.name
 message=str(exc)
 if not message:message=type(exc).__name__+(' à '+str(fichier)+':'+str(dernier.lineno) if dernier else '')
 return {'erreur':message[:350],'type_erreur':type(exc).__name__,'fichier':fichier,'ligne':dernier.lineno if dernier else None,'trace':''.join(traceback.format_exception(type(exc),exc,exc.__traceback__,limit=10))[-12000:]}

def enregistrer_rapport(rapport,chemin):
 """Artefact des seuls scénarios fictifs, écrit atomiquement, sans verdict modifié."""
 p=Path(chemin).resolve()
 if p.is_relative_to(R):raise ValueError('Rapport de banc hors dépôt requis')
 texte=json.dumps(rapport,ensure_ascii=False,indent=2)+'\n'
 p.parent.mkdir(parents=True,exist_ok=True)
 temporaire=None
 try:
  with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=p.parent,prefix=p.name+'.',delete=False) as f:
   temporaire=Path(f.name);f.write(texte)
  os.replace(temporaire,p)
 finally:
  if temporaire and temporaire.exists():temporaire.unlink()

def main(extension=None):
 if os.environ.get('HG219_POSTGRES_BIN'):
  sp=importlib.util.spec_from_file_location('pg17_groupes219',R/'outils/baseline/epreuve-postgresql.py');e=importlib.util.module_from_spec(sp);sp.loader.exec_module(e);e.configurer_binaires(Path(os.environ['HG219_POSTGRES_BIN']))
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-groupes-'),cleanup_mode='delete')
 c=psycopg2.connect(serveur.get_uri());q=c.cursor();tests=[]
 try:
  q.execute('SHOW server_version_num');version_moteur=q.fetchone()[0]
  if os.environ.get('HG219_POSTGRES_BIN'):assert version_moteur=='170006','Version PostgreSQL explicite différente de 17.6'
  q.execute("SELECT collversion,pg_collation_actual_version(oid) FROM pg_collation WHERE collname='en-US-x-icu'");icu_moteur=q.fetchone()
  moteur={'server_version_num':version_moteur,'icu_en_US_stockee_et_actuelle':icu_moteur,'binaires_explicites':bool(os.environ.get('HG219_POSTGRES_BIN'))}
  q.execute('''CREATE ROLE authenticated; CREATE ROLE anon; CREATE ROLE service_role;
CREATE TABLE personnages_donnees(name text PRIMARY KEY,user_id uuid,country text,current_city text,current_building text,current_room text,current_street text,inventory jsonb DEFAULT '[]');
CREATE TABLE pnj_membres(id text PRIMARY KEY,famille text,nom text,pays text,proprietaire_pj text,proprietaire_institution text,proprietaire_perimetre text,leader_pj text,leader_pnj_id text,ville text,building_id text,room_id text,rue_noeud_id text,statut text DEFAULT 'actif',maj_le timestamptz DEFAULT now());
CREATE TABLE pnj_possessions(id bigserial PRIMARY KEY,pnj_id text,objet jsonb);
CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE SECURITY DEFINER AS $$ SELECT name FROM personnages_donnees WHERE user_id=nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT current_setting('role',true)='none' $$;
INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,inventory) VALUES
('A','00000000-0000-4000-8000-000000000001','republic','capitale','mairie','accueil','[{"id":"radio"}]'),
('B','00000000-0000-4000-8000-000000000002','republic','capitale','mairie','accueil','[]'),
('C','00000000-0000-4000-8000-000000000003','republic','capitale','mairie','accueil','[]');
INSERT INTO pnj_membres(id,famille,nom,pays,proprietaire_pj,ville,building_id,room_id) VALUES
('ancre','employe','Un','republic','A','capitale','bar','salle'),
('autre','employe','Deux','republic','A','capitale','bar','salle');
UPDATE pnj_membres SET leader_pnj_id='ancre',ville=NULL,building_id=NULL,room_id=NULL WHERE id='autre';
INSERT INTO pnj_possessions(pnj_id,objet) VALUES('autre','{"produitMilitaire":"radio","id":"radio-fictive","qty":1}');
''')
  tables=(R/'baseline/domaines/socle-PNJ/10_tables.sql').read_text()
  for nom in ['pnj_axes_autorite','pnj_mouvement_individuel','pnj_institutions']:
   q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',tables,re.S)[0])
  for nom in ['pnj_axes_autorite','pnj_mouvement_individuel']:
   q.execute((R/f'baseline/seeds/90_socle/{nom}.sql').read_text())
  for nom in ['pnj_autorite_de_perimetre','pnj_autorite_de','pnj_peut_administrer','pnj_peut_conduire','pnj_axe_au_socle','pnj_axe_verrouille','pnj_axe_position_refus','pnj_mouvement_individuel_refus','pnj_position_effective','pnj_co_present','pnj_quitter_groupe','pnj_prendre','pnj_pas_de_sous_hierarchie','pnj_transferer']:
   q.execute(audit.fonction('baseline/domaines/socle-PNJ/20_fonctions.sql',nom))
  contraintes=(R/'baseline/domaines/socle-PNJ/30_contraintes.sql').read_text()
  for nom in ['pnj_mort_sans_leader','pnj_pas_son_propre_leader','pnj_position_deux_etats','pnj_un_seul_leader','pnj_membres_leader_pnj_id_fkey']:
   q.execute(re.search(r'ALTER TABLE public.pnj_membres ADD CONSTRAINT '+nom+r' .*?;',contraintes,re.S)[0])
  q.execute('CREATE TRIGGER sous_hierarchie BEFORE INSERT OR UPDATE ON pnj_membres FOR EACH ROW EXECUTE FUNCTION pnj_pas_de_sous_hierarchie()')
  # Seulement le patch de position existant de #216, pas de faux détecteur/combat.
  socle=(R/audit.M).read_text();q.execute(re.search(r'DO \$position\$.*?END \$position\$;',socle,re.S)[0])
  # Installer la reprise en deux boucles de #216 (déjà auditée), sans le détecteur.
  q.execute(re.search(r'DO \$reprise\$.*?END \$reprise\$;',socle,re.S)[0])
  q.execute('CREATE TABLE compagnies_militaires(id text PRIMARY KEY,data jsonb)')
  q.execute(audit.fonction('baseline/domaines/militaire/20_fonctions-2.sql','militaire_ordre_collectif'))
  q.execute((R/'migrations/20261031115737_radio_ordres_meme_ville.sql').read_text())
  q.execute((R/'migrations/20261031115737_radio_ordres_meme_ville.sql').read_text())
  q.execute("INSERT INTO compagnies_militaires VALUES('compagnie','{\"sections\":[{\"id\":\"s\",\"lieutenantNom\":\"A\"}]}')")
  original='--contre-217' in sys.argv
  for nom in ['20261031115738_reprise_pnj_autorite_administrative.sql','20261031115739_groupe_pj_adhesion_volontaire.sql','20261031115740_pnj_rappel_radio_universel.sql','20261031115741_transfert_pnj_autorite_origine.sql']:
   if original:
    import subprocess
    ancien=next((Path(x['ancien']).name for x in json.loads((R/'outils/audits/REHORODATAGE-GROUPES-219-20261031.json').read_text())['fichiers'] if Path(x['nouveau']).name==nom),nom)
    sql=subprocess.check_output(['git','show','c85d36d5:migrations/'+ancien],cwd=R,text=True)
   else:sql=(R/'migrations'/nom).read_text()
   q.execute(sql)
   q.execute(sql) # Rejeu structurel.
  for p in [R/x['nouveau'] for x in json.loads((R/'outils/audits/REHORODATAGE-GROUPES-219-20261031.json').read_text())['fichiers'] if Path(x['ancien']).match('2026102813*_groupes_*.sql')]:
   if not original:q.execute(p.read_text());q.execute(p.read_text())
  q.execute('REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated,anon,service_role')
  q.execute('GRANT EXECUTE ON FUNCTION pnj_prendre(text[]),pnj_quitter_groupe(text[]),pnj_transferer(text[],text,boolean) TO authenticated')
  q.execute('ALTER TABLE pnj_membres ADD COLUMN pa integer DEFAULT 12, ADD COLUMN liquide numeric DEFAULT 0, ADD COLUMN car_int integer, ADD COLUMN car_cha integer, ADD COLUMN car_vol integer, ADD COLUMN car_per integer, ADD COLUMN car_dup integer, ADD COLUMN car_ent integer')
  tables=(R/'baseline/domaines/socle-PNJ/10_tables.sql').read_text()
  q.execute(re.search(r'CREATE TABLE public\.pnj_employes_metier \(.*?\n\);',tables,re.S)[0])
  q.execute("INSERT INTO pnj_employes_metier(pnj_id,job,role_libelle) VALUES('ancre','agent_securite','agent'),('autre','agent_securite','agent')")
  q.execute(audit.fonction('baseline/domaines/socle-PNJ/20_fonctions.sql','pnj_caracteristiques_base'))
  q.execute(audit.fonction('baseline/domaines/personnage-et-presence/20_fonctions.sql','employe_mes_employes'))
  if not original:
   q.execute((R/'migrations/20261031115744_groupes_employes_position_confirmee.sql').read_text())
   q.execute((R/'migrations/20261031115744_groupes_employes_position_confirmee.sql').read_text())
  q.execute(audit.fonction(audit.M,'securite_agents_prives_presents_interne'))
  if not original:
   q.execute((R/'migrations/20261031115745_groupes_presence_privee_chef_reel.sql').read_text())
   q.execute((R/'migrations/20261031115745_groupes_presence_privee_chef_reel.sql').read_text())
  c.commit()
  def sql(s):q.execute(s)
  def rpc(nom,args=(),qui='A',cur=q):
   uid={'A':1,'B':2,'C':3,'D':4}.get(qui)
   cur.execute("SELECT set_config('request.jwt.claim.sub',%s,true),set_config('request.path',%s,true),set_config('role','authenticated',true)",(f'00000000-0000-4000-8000-{uid:012d}' if uid else '', '/rpc/'+nom))
   cur.execute('SELECT '+nom+'('+','.join(['%s']*len(args))+')',args);v=cur.fetchone()[0];cur.execute('RESET ROLE');return v
  def exige(v,raison=None):
   assert v.get('ok') is (raison is None),v
   if raison:assert v.get('raison')==raison,v
   return v
  def photo():
   q.execute("SELECT jsonb_agg(to_jsonb(t) ORDER BY t.id) FROM pnj_membres t");a=q.fetchone()[0]
   q.execute("SELECT jsonb_agg(to_jsonb(t) ORDER BY t.id) FROM pnj_possessions t");return [a,q.fetchone()[0]]
  def cas(nom,fn):
   q.execute('SAVEPOINT cas')
   try:fn();tests.append({'cas':nom,'ok':True})
   except Exception as e:tests.append({'cas':nom,'ok':False,**decrire_echec(e)})
   finally:q.execute('ROLLBACK TO SAVEPOINT cas')
  def refus_radio(raison,pre=''):
   if pre:sql(pre)
   avant=photo();exige(rpc('pnj_rappeler_radio',('ancre',)),raison);assert avant==photo()
  def radio():
   avant=photo()[1];v=exige(rpc('pnj_rappeler_radio',('ancre',)));assert v['rappeles']==2
   q.execute("SELECT count(*) FROM pnj_membres WHERE leader_pj='A'");assert q.fetchone()[0]==2
   assert photo()[1]==avant
   v=exige(rpc('pnj_rappeler_radio',('ancre',)));assert v.get('deja_present'),v
  cas('rappel_collectif_et_reponse_perdue',radio)
  cas('radio_pj_absente',lambda:refus_radio('radio_appelant_absente',"UPDATE personnages_donnees SET inventory='[]' WHERE name='A'"))
  cas('radio_unite_absente',lambda:refus_radio('radio_unite_absente',"DELETE FROM pnj_possessions"))
  cas('radio_pj_quantite_nulle',lambda:refus_radio('radio_appelant_absente',"UPDATE personnages_donnees SET inventory='[{\"id\":\"radio\",\"qty\":0}]' WHERE name='A'"))
  cas('radio_pnj_quantite_nulle',lambda:refus_radio('radio_unite_absente',"UPDATE pnj_possessions SET objet=objet||'{\"qty\":0}'"))
  cas('radio_autre_ville',lambda:refus_radio('radio_hors_ville',"UPDATE pnj_membres SET ville='port' WHERE id='ancre'"))
  cas('radio_autre_pays',lambda:refus_radio('radio_hors_ville',"UPDATE pnj_membres SET pays='sovarka'"))
  cas('radio_autorites_reparties_aucun_mouvement',lambda:refus_radio('autorite_insuffisante',"UPDATE pnj_membres SET proprietaire_pj='B' WHERE id='autre'"))
  cas('radio_axe_institution_preserve',lambda:refus_radio('axe_position_hors_socle',"UPDATE pnj_membres SET famille='titulaire_poste'"))
  cas('radio_regle_metier_preservee',lambda:refus_radio('mouvement_individuel_interdit',"UPDATE pnj_membres SET famille='soldat'"))
  cas('radio_membre_inactif',lambda:refus_radio('autorite_insuffisante',"UPDATE pnj_membres SET statut='disparu' WHERE id='autre'"))
  cas('adhesion_volontaire',lambda:exige(rpc('groupe_pj_rejoindre',('B',))))
  cas('adhesion_non_authentifiee',lambda:exige(rpc('groupe_pj_rejoindre',('B',),qui=None),'non_authentifie'))
  cas('auto_adhesion_interdite',lambda:exige(rpc('groupe_pj_rejoindre',('A',)),'chef_invalide'))
  cas('chef_absent',lambda:exige(rpc('groupe_pj_rejoindre',('inconnu',)),'pas_co_presents'))
  def distant():
   sql("UPDATE personnages_donnees SET current_room='bureau' WHERE name='B'");exige(rpc('groupe_pj_rejoindre',('B',)),'pas_co_presents')
  cas('adhesion_autre_piece',distant)
  def interieur():
   sql("UPDATE personnages_donnees SET current_street=name");exige(rpc('groupe_pj_rejoindre',('B',)))
  cas('adhesion_interieur_ignore_ancienne_rue',interieur)
  def rue():
   sql("UPDATE personnages_donnees SET current_building=NULL,current_street='noeud',current_room=name");exige(rpc('groupe_pj_rejoindre',('B',)))
  cas('adhesion_rue_ignore_ancienne_piece',rue)
  def rue_vide():
   sql("UPDATE personnages_donnees SET current_building=NULL,current_street=NULL");exige(rpc('groupe_pj_rejoindre',('B',)),'pas_co_presents')
  cas('adhesion_position_absente',rue_vide)
  def lecture():
   exige(rpc('groupe_pj_rejoindre',('B',)));a=rpc('groupe_pj_lire');b=rpc('groupe_pj_lire',qui='B');assert a==b and a['membres']==['A','B'],(a,b)
   exige(rpc('groupe_pj_quitter'));assert rpc('groupe_pj_lire')['membres']==['A']
  cas('lecture_reconnexion_et_depart',lecture)
  def chef_quitte():
   exige(rpc('groupe_pj_rejoindre',('B',)));exige(rpc('groupe_pj_quitter',qui='B'));assert rpc('groupe_pj_lire')['membres']==['A']
  cas('chef_separe_sans_mouvement',chef_quitte)
  def cycle():
   exige(rpc('groupe_pj_rejoindre',('B',)));exige(rpc('groupe_pj_rejoindre',('A',),qui='B'),'chef_deja_membre')
  cas('cycle_refuse',cycle)
  def prive():
   q.execute("SELECT has_table_privilege('authenticated','groupes_pj_adhesions','INSERT'),has_table_privilege('authenticated','groupes_pj_adhesions','SELECT')");assert q.fetchone()==(False,False)
   for f in ['groupe_pj_rejoindre(text)','groupe_pj_quitter()','groupe_pj_lire()','pnj_rappeler_radio(text)']:
    for role in ['anon','service_role']:
     q.execute("SELECT has_function_privilege(%s,%s,'EXECUTE')",(role,f));assert q.fetchone()[0] is False
  cas('aucune_adhesion_imposee_ni_fuite_table',prive)
  def concurrent():
   # Deux transactions d'adhésion opposées : seule la première réussit.
   un=psycopg2.connect(serveur.get_uri());deux=psycopg2.connect(serveur.get_uri())
   try:
    for cc in [un,deux]:cc.cursor().execute("SET statement_timeout='5s'")
    a=rpc('groupe_pj_rejoindre',('B',),cur=un.cursor());exige(a)
    with ThreadPoolExecutor(1) as pool:
     fut=pool.submit(rpc,'groupe_pj_rejoindre',('A',),'B',deux.cursor())
     # Observer réellement le chevauchement, pas seulement lancer deux threads.
     import time
     limite=time.monotonic()+3
     verrou=False
     while time.monotonic()<limite:
      q.execute('SELECT pg_stat_clear_snapshot()')
      q.execute("SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s",(deux.get_backend_pid(),))
      ligne=q.fetchone()
      if ligne and ligne[0]=='Lock':verrou=True;break
      if fut.done():break
      time.sleep(.02)
     assert verrou,'la deuxième adhésion ne se sérialise pas sur la première'
     # Annuler l'opération fictive : la seconde peut rejoindre A, aucun cycle ne persiste.
     un.rollback();exige(fut.result(timeout=7))
   finally:un.rollback();deux.rollback();un.close();deux.close()
  cas('adhesions_concurrentes_sans_deadlock',concurrent)
  def prendre_inconnu():
   sql("UPDATE personnages_donnees SET current_building='bar',current_room='salle' WHERE name='A'")
   avant=photo();exige(rpc('pnj_prendre',(['ancre','inexistant'],)),'identifiants_invalides');assert avant==photo()
  cas('prise_liste_incomplete_aucune_mutation',prendre_inconnu)
  def pret():
   sql("UPDATE personnages_donnees SET current_building='bar',current_room='salle'")
   proprietaires=[x['proprietaire_pj'] for x in photo()[0]]
   exige(rpc('pnj_transferer',(['ancre','autre'],'B',False)))
   assert [x['proprietaire_pj'] for x in photo()[0]]==proprietaires
   exige(rpc('pnj_transferer',(['ancre'],'C',False),qui='B'),'autorite_insuffisante')
   exige(rpc('pnj_quitter_groupe',(['ancre','autre'],),qui='B'))
   exige(rpc('pnj_prendre',(['ancre'],),qui='B'),'autorite_insuffisante')
   exige(rpc('pnj_prendre',(['ancre','autre'],)))
   assert all(x['leader_pj']=='A' for x in photo()[0])
  cas('pret_conduite_sans_transfert_autorite_et_reprise',pret)
  def partiel():
   sql("UPDATE personnages_donnees SET current_building='bar',current_room='salle';UPDATE pnj_membres SET proprietaire_pj='C' WHERE id='autre'")
   avant=photo();exige(rpc('pnj_transferer',(['ancre','autre'],'B',False)),'autorite_insuffisante');assert avant==photo()
  cas('pret_refus_second_membre_sans_mutation',partiel)
  def depose():
   sql("UPDATE personnages_donnees SET current_building='bar',current_room='salle';UPDATE pnj_membres SET proprietaire_pj='C',leader_pj='B',leader_pnj_id=NULL,ville=NULL,building_id=NULL,room_id=NULL WHERE id='autre'")
   avant=photo();exige(rpc('pnj_quitter_groupe',(['ancre','autre'],)),'autorite_insuffisante');assert avant==photo()
  cas('depose_refus_second_membre_sans_mutation',depose)
  def rue_pret():
   sql("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='rue';UPDATE pnj_membres SET building_id=NULL,room_id=NULL,rue_noeud_id='rue' WHERE id='ancre'")
   exige(rpc('pnj_transferer',(['ancre','autre'],'B',False)))
   sql("UPDATE personnages_donnees SET current_street='destination' WHERE name='B'")
   q.execute("SELECT rue_noeud_id FROM pnj_position_effective('autre')");assert q.fetchone()[0]=='destination'
   exige(rpc('pnj_quitter_groupe',(['ancre','autre'],),qui='B'))
   q.execute("SELECT array_agg(rue_noeud_id) FROM pnj_membres");assert q.fetchone()[0]==['destination','destination']
  cas('suivi_pnj_et_depose_rue_reelle',rue_pret)
  def rue_distante():
   sql("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='rue';UPDATE personnages_donnees SET current_street='ailleurs' WHERE name='B';UPDATE pnj_membres SET building_id=NULL,room_id=NULL,rue_noeud_id='rue' WHERE id='ancre'")
   avant=photo();exige(rpc('pnj_transferer',(['ancre','autre'],'B',False)),'pas_co_presents');assert avant==photo()
  cas('pret_autre_rue_refuse',rue_distante)
  def ordre_radio(ville,raison):
   sql("UPDATE personnages_donnees SET inventory='[{\"produitMilitaire\":\"radio\"}]',current_city='"+ville+"' WHERE name='B'")
   if raison=='radio_manquante':sql("UPDATE personnages_donnees SET inventory='[]' WHERE name='A'")
   exige(rpc('militaire_ordre_collectif',('compagnie','s','ration','B',None)),raison)
  cas('ordre_radio_militaire_hors_ville_refuse_avant_effet',lambda:ordre_radio('port','radio_hors_ville'))
  cas('ordre_radio_meme_ville_conserve_garde_equipement',lambda:ordre_radio('capitale','radio_manquante'))
  def projection():
   v=exige(rpc('employe_mes_employes'));assert len(v['employes'])==2
   assert all(e['position']['building_id']=='bar' for e in v['employes']),v
  cas('projection_employes_position_effective',projection)
  def prives_groupes():
   exige(rpc('pnj_rappeler_radio',('ancre',)))
   sql("UPDATE pnj_membres SET car_per=12,car_vol=12")
   q.execute("SELECT securite_agents_prives_presents_interne('republic','capitale','mairie','accueil',NULL,'B')");v=q.fetchone()[0]
   assert len(v)==2 and v[0]['groupeCle']==v[1]['groupeCle'],v
  cas('prives_suiveurs_meme_groupe_reel',prives_groupes)
  def groupes_distincts():
   exige(rpc('pnj_rappeler_radio',('ancre',)))
   sql("UPDATE pnj_membres SET leader_pj=CASE WHEN id='ancre' THEN 'A' ELSE 'B' END,car_per=12,car_vol=12")
   q.execute("SELECT securite_agents_prives_presents_interne('republic','capitale','mairie','accueil',NULL,'C')");v=q.fetchone()[0]
   assert len(v)==2 and v[0]['groupeCle']!=v[1]['groupeCle'],v
   exige(rpc('groupe_pj_rejoindre',('B',)))
   q.execute("SELECT securite_agents_prives_presents_interne('republic','capitale','mairie','accueil',NULL,'C')");v=q.fetchone()[0]
   assert v[0]['groupeCle']==v[1]['groupeCle'],v
  cas('prives_copresence_distincte_puis_adhesion_reelle',groupes_distincts)
  preuves_extension={}
  if extension is not None:extension(locals())
  c.rollback()
  rapport={'tests':tests,'moteur':moteur,'production':False,'authentification':'identite JWT de fixture, role authenticated','rollback':not preuves_extension.get('action_fictive_committee',False),'preuves_extension':preuves_extension,'migrations_appliquees':[],'original217':original}
  if os.environ.get('HG219_RAPPORT_JSON'):enregistrer_rapport(rapport,os.environ['HG219_RAPPORT_JSON'])
  print(json.dumps(rapport,ensure_ascii=False,indent=2))
  return int(any(not x['ok'] for x in tests))
 finally:c.close();serveur.cleanup()
if __name__=='__main__':sys.exit(main())
