#!/usr/bin/env python3
"""Moteurs SQL réels, PostgreSQL jetable ; aucune connexion distante ni donnée de PJ.
Décor minimal : identité de fixture, connexion internet et légalité simulées explicitement.
Ne certifie pas le catalogue vivant. Tout est annulé à la fin (y compris la migration).
"""
from pathlib import Path
import re, tempfile, importlib.util, os
R=Path(__file__).resolve().parents[2]
M='migrations/20261104180710_entrepot_novomirsk_isolation_pays.sql'
def fn(f,n):
 s=(R/f).read_text();a=re.search(r'CREATE OR REPLACE FUNCTION public\.'+n+r'\(',s).start();m=re.search(r'AS\s+(\$\w*\$).*?\1;',s[a:],re.S);return s[a:a+m.end()]
def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 if os.environ.get('HG_PG_BIN'):
  import pgserver._commands as commands,pgserver.postgres_server as server
  commands.POSTGRES_BIN_PATH=server.POSTGRES_BIN_PATH=Path(os.environ['HG_PG_BIN'])
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-novomirsk-'),cleanup_mode='delete');n=0
 try:
  db=psycopg2.connect(srv.get_uri());q=db.cursor()
  spec=importlib.util.spec_from_file_location('inv',R/'outils/bancs/banc-inventaire-receptions-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base);base.initialiser(q)
  def sql(s,args=None):
   q.execute(s,args) if args is not None else q.execute(s)
   return q.fetchone()[0] if q.description else None
  print('PostgreSQL',sql('SHOW server_version'),flush=True)
  sql("CREATE ROLE service_role; ALTER TABLE personnages_donnees ADD COLUMN poste jsonb;")
  sources='\n'.join(p.read_text() for p in (R/'baseline/domaines').glob('*/10_tables.sql'))
  for t in ['villes','batiments_etat','entrepots_par_ville','ressources_economie','entrepot_transits','caisses_fret','contenu_caisses_fret','rue_sorties_batiments']:
   sql(re.search(r'CREATE TABLE public\.'+t+r' \(.*?\n\);',sources,re.S)[0])
  sql("CREATE SEQUENCE entrepot_journal_id_seq");sql(re.search(r'CREATE TABLE public.entrepot_journal \(.*?\n\);',sources,re.S)[0])
  sql("ALTER TABLE entrepots_par_ville ADD PRIMARY KEY(ville);ALTER TABLE batiments_etat ADD PRIMARY KEY(id);ALTER TABLE rue_sorties_batiments ADD PRIMARY KEY(country,city,noeud,building)")
  # Tables de déclaration récentes, fidèles à leurs migrations ; pas de données réelles.
  sql("CREATE TABLE navigation_lieux_regles(pays text,ville text,batiment text,pieces jsonb,ferme boolean,membership text,PRIMARY KEY(pays,ville,batiment));CREATE TABLE pnj_lieux_metiers(pays text,ville text,building_id text,room_id text,nom text,job text,rel text,PRIMARY KEY(pays,ville,building_id,room_id,nom));CREATE TABLE organisations(id text PRIMARY KEY,data text);CREATE TABLE entreprises(id text PRIMARY KEY,data jsonb)")
  sql(re.search(r'CREATE TABLE IF NOT EXISTS public.offres_achat \(.*?\n\);',(R/'migrations/20261103030000_trading_offres_achat.sql').read_text(),re.S)[0])
  sql((R/'baseline/seeds/92_mixte/entrepots_par_ville.sql').read_text())
  sql("INSERT INTO villes(pays,ville,nom,rang) VALUES('soviet','capitale','Novomirsk',1),('republic','capitale','Luthécia',1),('republic','ville_a','Port-Sainte-Marie',2),('republic','ville_b','Montrouge',3)")
  sql("INSERT INTO ressources_economie(cle,prix_base) VALUES('bois',5); INSERT INTO ordres_couts VALUES('acheter_ressources_entrepot',0,0)")
  for f,names in [
   ('baseline/domaines/immobilier-et-territoire/20_fonctions-1.sql',['batiment_etat_lire']),
   ('baseline/domaines/socle/20_fonctions.sql',['acteur_poste_courant','mouvement_titulaire']),
   ('baseline/domaines/economie/20_fonctions-1.sql',['capacite_entrepot','acheter_a_entrepot','chantier_commande','chantier_jour_traiter']),
   ('baseline/domaines/economie/20_fonctions-2.sql',['entrepot_caisse_id','entrepot_caisse_lire','entrepot_capacite_disponible','entrepot_du_directeur','entrepot_commander','entrepot_fixer_desiderata','fixer_prix_entrepot']),
   ('migrations/20261103020000_trading_matieres_premieres.sql',['trading_organisations_interne','trading_cours','trading_acheter']),
   ('migrations/20261103030000_trading_offres_achat.sql',['offre_achat_publier','offres_achat_lire','offre_achat_servir','offre_achat_rembourser_interne','offre_achat_retirer']),
   ('migrations/20261104173000_trading_livraison_terrestre.sql',['trading_livraison_entrepot_interne']),
   ('historique/migrations-appliquees/20261030180000_achats_cle_unicite.sql',['achat_requete_ouvrir_interne','achat_requete_clore_interne'])]:
   for name in names:sql(fn(f,name))
  # L'enveloppe d'achat versionnée est distincte du noyau historique (même nom).
  src=(R/'baseline/domaines/economie/20_fonctions-1.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.acheter_a_entrepot(p_requete');m=re.search(r'AS\s+(\$\w*\$).*?\1;',src[a:],re.S);sql(src[a:a+m.end()])
  src=(R/'migrations/20261104173000_trading_livraison_terrestre.sql').read_text();sql(re.search(r'DO \$mig\$.*?END \$mig\$;',src,re.S)[0])
  # Services annexes simulés, sans logique économique alternative.
  sql("CREATE FUNCTION trading_connexion_interne(text) RETURNS boolean LANGUAGE sql AS $$SELECT true$$; CREATE FUNCTION matiere_refus_circuit_legal_lot(text,jsonb,text) RETURNS jsonb LANGUAGE sql AS $$SELECT NULL::jsonb$$;")
  for city,b in [('capitale','luthecia'),('ville_a','psm'),('ville_b','montrouge')]:
   sql('INSERT INTO batiments_etat(id,country,city,building_id,data) VALUES(%s,%s,%s,%s,%s)',('republic_'+city+'_entrepot-logistique-'+b,'republic',city,'entrepot-logistique-'+b,Json({'entrepot':{'stock':{'bois':100},'prixManuel':{'bois':5},'reserveMilitaire':{'bois':10}}})))
   sql('INSERT INTO caisses_batiments(id,data) VALUES(%s,%s)',('republic_entrepot_'+city,Json({'solde':1000})))
  sql("GRANT SELECT ON personnages_donnees,entrepots_par_ville,batiments_etat,entrepot_transits TO authenticated;ALTER TABLE personnages_donnees ENABLE ROW LEVEL SECURITY;CREATE POLICY fixture_soi ON personnages_donnees FOR SELECT TO authenticated USING(user_id=auth.uid())")
  def check(v,msg):
   nonlocal n
   assert v,msg;n+=1;print('OK',n,msg,flush=True)
  def own(s,args=None):sql('RESET ROLE');return sql(s,args)
  numero_requete=200
  def call(f,args):
   nonlocal numero_requete
   if f in ('offre_achat_publier','offre_achat_servir','offre_achat_retirer','trading_acheter'):
    numero_requete+=1;args=[f'00000000-0000-4000-8000-{numero_requete:012d}']+args
   sql("SELECT set_config('role','authenticated',true),set_config('request.path',%s,true)",('/rpc/'+f,));return sql(('SELECT entrepot_id FROM public.' if f=='entrepot_du_directeur' else 'SELECT public.')+f+'('+','.join(['%s']*len(args))+')',args)
  def snap():return own("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(p)) FROM personnages_donnees p),(SELECT jsonb_agg(to_jsonb(b)) FROM batiments_etat b),(SELECT jsonb_agg(to_jsonb(c)) FROM caisses_batiments c),(SELECT jsonb_agg(to_jsonb(t)) FROM entrepot_transits t),(SELECT jsonb_agg(to_jsonb(o)) FROM offres_achat o),(SELECT jsonb_agg(to_jsonb(r)) FROM inventaire_actions_recus r))")
  def actor(pays,city='capitale',job='directeur_entrepot',building=None,room='bureau_direction'):
   own('UPDATE personnages_donnees SET country=%s,current_city=%s,current_building=%s,current_room=%s,poste=%s WHERE name=\'Fixture\'',(pays,city,building or ('entrepot-logistique-novomirsk' if pays=='soviet' else 'entrepot-logistique-'+{'capitale':'luthecia','ville_a':'psm','ville_b':'montrouge'}[city]),room,Json({'id':job,'city':city}) if job else None))
  def uid(i):return f'00000000-0000-4000-8000-{i:012d}'
  actor('soviet');check(call('entrepot_du_directeur',['Fixture'])=='republic_capitale_entrepot-logistique-luthecia','contre-épreuve : ancien résolveur confond les deux capitales')
  sql('RESET ROLE');sql('SAVEPOINT avant_migration');sql((R/M).read_text());check(own('SELECT count(*) FROM entrepots_par_ville')==4,'quatre clés pays/ville, trois entrepôts républiens conservés')
  sql((R/M).read_text());check(own('SELECT count(*) FROM entrepots_par_ville')==4,'rejeu migration idempotent')
  check(call('entrepot_du_directeur',['Fixture'])=='soviet_capitale_entrepot-logistique-novomirsk','directeur sovarkien isolé')
  check(own("SELECT data->>'solde' FROM caisses_batiments WHERE id='soviet_entrepot_capitale'")=='0','aucune dotation monétaire inventée')
  check(call('entrepot_capacite_disponible',['soviet_capitale_entrepot-logistique-novomirsk','bois'])==5000,'capacité commune 5000 par matière')
  v=call('fixer_prix_entrepot',['Fixture','soviet',Json({'bois':6})]);check(v['ok'],'prix manuels Sovarka par moteur existant')
  before=snap();check(call('fixer_prix_entrepot',['Fixture','republic',Json({'bois':9})])['raison']=='pays_invalide' and snap()==before,'prix d’un autre pays refusés sans mutation')
  v=call('entrepot_fixer_desiderata',['Fixture',Json({'bois':50})]);check(v['ok'],'objectifs locaux communs')
  for pays,city in [('republic','capitale'),('republic','ville_a'),('republic','ville_b'),('soviet','capitale')]:
   actor(pays,city);v=call('trading_cours',[]);check(v['ok'] and len(v['entrepots'])==(3 if pays=='republic' else 1) and all(x['id'].startswith(pays+'_') for x in v['entrepots']),'cours isolés '+pays+'/'+city)
   dest=own('SELECT building_id FROM trading_livraison_entrepot_interne(%s,NULL,\'Fixture\')',(pays,));check(dest==('entrepot-logistique-novomirsk' if pays=='soviet' else 'entrepot-logistique-'+{'capitale':'luthecia','ville_a':'psm','ville_b':'montrouge'}[city]),'destination terrestre nationale '+pays+'/'+city)
  actor('soviet');before=snap();v=call('entrepot_commander',[uid(1),'Fixture','bois',1,'entrepot','republic_capitale_entrepot-logistique-luthecia']);check(v['raison']=='international_non_ouvert' and snap()==before,'commande internationale refusée avant débit/transit')
  before=snap();v=call('entrepot_commander',[uid(2),'Fixture','bois',1,'etranger','republic']);check(v['raison']=='international_non_ouvert' and snap()==before,'fournisseur international historique refusé')
  actor('republic','ville_a');v=call('entrepot_commander',[uid(3),'Fixture','bois',4,'entrepot','republic_capitale_entrepot-logistique-luthecia']);check(v['ok'] and v['montant']==20,'commande nationale existante conservée')
  after=snap();v=call('entrepot_commander',[uid(3),'Fixture','bois',4,'entrepot','republic_capitale_entrepot-logistique-luthecia']);check(v['rejeu'] and snap()==after,'réponse perdue : même reçu, aucun second débit ni transit')
  before=snap();v=call('entrepot_commander',[uid(3),'Fixture','bois',5,'entrepot','republic_capitale_entrepot-logistique-luthecia']);check(v['raison']=='requete_reutilisee' and snap()==before,'nonce lié aux paramètres')
  before=snap();v=call('entrepot_commander',[uid(4),'Fixture','bois',90,'entrepot','republic_capitale_entrepot-logistique-luthecia']);check(not v['ok'] and snap()==before,'réserve militaire non vendable et refus sans mutation')
  actor('soviet',job=None);before=snap();v=call('fixer_prix_entrepot',['Fixture','soviet',Json({'bois':9})]);check(not v['ok'] and snap()==before,'non-directeur sans droits de prix')
  check(not own("SELECT has_function_privilege('authenticated','entrepot_commander(text,text,integer,text,text)','EXECUTE')"),'ancienne commande non versionnée fermée au navigateur')
  actor('soviet');own("UPDATE caisses_batiments SET data='{\"solde\":1000}' WHERE id='soviet_entrepot_capitale'")
  v=call('offre_achat_publier',['entrepot',None,'bois',10,5]);offre=v['offre'];check(v['ok'] and v['montant_bloque']==50,'offre sovarkienne et blocage de caisse communs')
  v=call('offres_achat_lire',[]);check(len(v['offres'])==1 and v['directeur_de'].startswith('soviet_'),'offres locales Sovarka visibles')
  actor('republic');before=snap();v=call('offre_achat_servir',[offre,1,'entrepot',None,None]);check(v['raison']=='international_non_ouvert' and snap()==before,'offre étrangère connue par identifiant refusée')
  actor('soviet');v=call('offre_achat_retirer',[offre]);check(v['ok'] and v['rembourse']==50,'offre retirée : restitution exacte')
  before=snap();check(not call('offre_achat_retirer',[offre])['ok'] and snap()==before,'pas de double remboursement')
  # Achat sur place : paiement / dépôt / caisse et reçu forment le moteur commun.
  own("UPDATE batiments_etat SET data=to_jsonb('{\"entrepot\":{\"stock\":{\"bois\":100},\"prixManuel\":{\"bois\":6},\"reserveMilitaire\":{\"bois\":10}}}'::text) WHERE id='soviet_capitale_entrepot-logistique-novomirsk'")
  actor('soviet',job=None,room='salle_ventes');before=snap()
  v=call('acheter_a_entrepot',[uid(50),'Fixture','soviet','capitale','entrepot-logistique-novomirsk',Json({'bois':2}),0,0]);check(v['ok'] and v['paye']==12 and v['revision']>0,'achat local au prix directeur, dépôt et révision serveur')
  check(own("SELECT (data->>'solde')::numeric FROM caisses_batiments WHERE id='soviet_entrepot_capitale'")==1012,'recette uniquement dans la caisse canonique')
  check(not own("SELECT batiment_etat_lire(data)->'entrepot' ? 'caisse' FROM batiments_etat WHERE id='soviet_capitale_entrepot-logistique-novomirsk'"),'aucune seconde bourse dans le stock')
  after=snap();v=call('acheter_a_entrepot',[uid(50),'Fixture','soviet','capitale','entrepot-logistique-novomirsk',Json({'bois':2}),0,0]);check(v['rejeu'] and snap()==after,'rejeu achat sans double paiement ni objet')
  actor('soviet',job=None,room='accueil');before=snap();v=call('acheter_a_entrepot',[uid(51),'Fixture','soviet','capitale','entrepot-logistique-novomirsk',Json({'bois':2}),0,0]);check(not v['ok'] and snap()==before,'achat hors salle des ventes refusé sans paiement')
  actor('soviet',job=None,room='salle_ventes');before=snap();v=call('acheter_a_entrepot',[uid(52),'Fixture','republic','capitale','entrepot-logistique-luthecia',Json({'bois':2}),0,0]);check(not v['ok'] and snap()==before,'achat direct au pays étranger refusé')
  own("UPDATE personnages_donnees SET liquide=0 WHERE name='Fixture';UPDATE comptes_bancaires SET solde=0 WHERE personnage='Fixture'");before=snap();v=call('acheter_a_entrepot',[uid(53),'Fixture','soviet','capitale','entrepot-logistique-novomirsk',Json({'bois':2}),0,0]);check(not v['ok'] and snap()==before,'fonds insuffisants sans objet ni débit partiel')
  # Un trader local sert le stock manquant ; aucune création de matière.
  actor('soviet');v=call('offre_achat_publier',['entrepot',None,'bois',3,5]);offre=v['offre']
  own("INSERT INTO organisations VALUES('sov-org','{\"type\":\"economique\",\"nom\":\"Organisation fixture\",\"chef\":\"Fixture\",\"caisse\":0}')")
  own("UPDATE personnages_donnees SET inventory='[{\"name\":\"Bois\",\"stackable\":true,\"stackKey\":\"bois\",\"qty\":3}]' WHERE name='Fixture'")
  v=call('offre_achat_servir',[offre,3,'inventaire','sov-org',None]);check(v['ok'],'vente locale depuis inventaire par moteur des offres')
  check(own("SELECT (data::jsonb->>'caisse')::numeric FROM organisations WHERE id='sov-org'")==15,'organisation vendeuse payée exactement')
  before=snap();check(not call('offre_achat_servir',[offre,3,'inventaire','sov-org',None])['ok'] and snap()==before,'offre épuisée impossible à resservir')
  # Échec de crédit fournisseur après débit : toute la commande doit être annulée.
  actor('republic','ville_a');own("DELETE FROM caisses_batiments WHERE id='republic_entrepot_capitale'");before=snap();own('SAVEPOINT panne')
  try:call('entrepot_commander',[uid(5),'Fixture','bois',2,'entrepot','republic_capitale_entrepot-logistique-luthecia']);raise AssertionError('crédit absent accepté')
  except psycopg2.Error:sql('ROLLBACK TO SAVEPOINT panne')
  check(snap()==before,'panne du crédit fournisseur : rollback du débit, stock, reçu et transit')
  sql('ROLLBACK TO SAVEPOINT avant_migration');check(own("SELECT count(*) FROM information_schema.columns WHERE table_name='entrepots_par_ville' AND column_name='pays'")==0,'rollback intégral du changement de schéma')
  sql((R/M).read_text());check(own('SELECT count(*) FROM entrepots_par_ville')==4,'rejeu après rollback')
  db.rollback();db.close();print(str(n)+' assertions PostgreSQL réussies ; transaction annulée.',flush=True)
 finally:srv.cleanup()
if __name__=='__main__':main()
