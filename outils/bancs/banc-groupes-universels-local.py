#!/usr/bin/env python3
"""Vrais corps SQL proposés + gardes/contraintes PNJ du dépôt, PostgreSQL jetable.
Identité JWT de fixture ; aucune authentification Supabase ni écriture distante.
Chaque scénario est annulé ; le décor fictif seul est committé pour la concurrence.
"""
import importlib.util,json,re,sys,tempfile
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('audit',R/'outils/bancs/banc-audit-securite-135-local.py')
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-groupes-'),cleanup_mode='delete')
 c=psycopg2.connect(serveur.get_uri());q=c.cursor();tests=[]
 try:
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
  original='--contre-217' in sys.argv
  for nom in ['20261028122500_reprise_pnj_autorite_administrative.sql','20261028123000_groupe_pj_adhesion_volontaire.sql','20261028123500_pnj_rappel_radio_universel.sql','20261028124000_transfert_pnj_autorite_origine.sql']:
   if original:
    import subprocess
    sql=subprocess.check_output(['git','show','c85d36d5:migrations/'+nom],cwd=R,text=True)
   else:sql=(R/'migrations'/nom).read_text()
   q.execute(sql)
   q.execute(sql) # Rejeu structurel.
  for p in sorted((R/'migrations').glob('2026102813*_groupes_*.sql')):
   if not original:q.execute(p.read_text());q.execute(p.read_text())
  q.execute('REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated,anon,service_role')
  q.execute('GRANT EXECUTE ON FUNCTION pnj_prendre(text[]),pnj_quitter_groupe(text[]),pnj_transferer(text[],text,boolean) TO authenticated')
  c.commit()
  def sql(s):q.execute(s)
  def rpc(nom,args=(),qui='A',cur=q):
   uid={'A':1,'B':2,'C':3}.get(qui)
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
   except Exception as e:tests.append({'cas':nom,'ok':False,'erreur':str(e)[:350]})
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
     # Annuler l'opération fictive : la seconde peut rejoindre A, aucun cycle ne persiste.
     un.rollback();exige(fut.result(timeout=7))
   finally:un.rollback();deux.rollback();un.close();deux.close()
  cas('adhesions_concurrentes_sans_deadlock',concurrent)
  c.rollback()
  print(json.dumps({'tests':tests,'production':False,'authentification':'identite JWT de fixture, role authenticated','rollback':True,'migrations_appliquees':[],'original217':original},ensure_ascii=False,indent=2))
  return int(any(not x['ok'] for x in tests))
 finally:c.close();serveur.cleanup()
if __name__=='__main__':sys.exit(main())
