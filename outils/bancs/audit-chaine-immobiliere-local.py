#!/usr/bin/env python3
"""Photographie d'audit : reproduit des anomalies connues, ne certifie PAS leur correction.
Aucun DSN accepte. PostgreSQL jetable obligatoire, aucun compte reel.
"""
import argparse,hashlib,json,re,tempfile
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[2]
IMMO=ROOT/'baseline/domaines/immobilier-et-territoire/20_fonctions.sql'
ECO=ROOT/'baseline/domaines/economie/20_fonctions-1.sql'
BANQUE=ROOT/'baseline/domaines/banque/20_fonctions.sql'

def definition(nom,f):
 s=f.read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
def table(nom,f):
 s=f.read_text();a=s.index('CREATE TABLE public.'+nom+' (');return s[a:s.index('\n);',a)+3]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--local-jetable',required=True,action='store_true');p.add_argument('--rapport',type=Path);p.add_argument('--ordres',type=Path,required=True,help='JSON du generateur canonique generer_ordres_couts.py --json');args=p.parse_args()
 import pgserver,psycopg2
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-audit-immo-'),cleanup_mode='delete');uri=server.get_uri()
 db=psycopg2.connect(uri);db.autocommit=True;c=db.cursor()
 c.execute('''CREATE ROLE authenticated; CREATE ROLE anon; CREATE ROLE service_role;
 CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,current_city text,current_building text,current_room text,arg numeric,liquide numeric,pa integer,day integer,poste jsonb,updated_at timestamptz);
 CREATE VIEW personnages AS SELECT * FROM personnages_donnees;
 CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$ SELECT nullif(current_setting('audit.acteur',true),'') $$;
 CREATE FUNCTION acteur_identifie() RETURNS boolean LANGUAGE sql AS $$ SELECT mon_personnage() IS NOT NULL $$;
 CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF $1 IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'acteur_invalide'; END IF; END $$;
 CREATE FUNCTION titulaire_est_moi(text) RETURNS boolean LANGUAGE sql AS $$ SELECT $1=mon_personnage() $$;
 CREATE FUNCTION acteur_poste_courant() RETURNS TABLE(nom text,poste_id text,poste_city text,pays text) LANGUAGE sql AS $$ SELECT name,poste->>'id',poste->>'city',country FROM personnages_donnees WHERE name=mon_personnage() $$;
 CREATE TABLE quetes_actives(id text,statut text,resolu_par text);
 CREATE TABLE entreprises(id text PRIMARY KEY,data jsonb,updated_at timestamptz);
 CREATE TABLE batiments_etat(id text PRIMARY KEY,data jsonb,updated_at timestamptz);
 CREATE FUNCTION batiment_etat_lire(jsonb) RETURNS jsonb LANGUAGE sql AS $$ SELECT CASE WHEN jsonb_typeof($1)='string' THEN ($1#>>'{}')::jsonb ELSE $1 END $$;
 ''')
 for nom,dom in [('terrains_etat','immobilier-et-territoire'),('terrains_historique_ventes','immobilier-et-territoire'),('prets','banque'),('comptes_bancaires','banque'),('compromis_historique','banque'),('chantiers_paliers','economie'),('chantiers_besoins_jour','economie'),('ressources_economie','economie'),('locations_actives','immobilier-et-territoire'),('ordres_couts','economie'),('ordres_couts_ecarts','economie'),('ordres_couts_inconnus','economie')]:
  c.execute(table(nom,ROOT/f'baseline/domaines/{dom}/10_tables.sql'))
  if nom in ['terrains_etat','terrains_historique_ventes','prets','comptes_bancaires','compromis_historique']:c.execute('ALTER TABLE '+nom+' ADD PRIMARY KEY(id)')
 c.execute('ALTER TABLE ordres_couts_ecarts ADD PRIMARY KEY(fn,pa,cost); ALTER TABLE ordres_couts_inconnus ADD PRIMARY KEY(fn)')
 for o in json.loads(args.ordres.read_text()):c.execute('INSERT INTO ordres_couts(fn,pa,cost) VALUES(%s,%s,%s)',(o['fn'],o['pa'],o['cost']))
 c.execute((ROOT/'baseline/seeds/90_socle/chantiers_paliers.sql').read_text())
 c.execute((ROOT/'baseline/seeds/90_socle/chantiers_besoins_jour.sql').read_text())
 c.execute("CREATE TABLE entreprises_constantes(cle text PRIMARY KEY,valeur numeric); INSERT INTO entreprises_constantes VALUES('chantier_taux_horaire',70),('seuil_demarrage_pct',35),('seuil_premier_tiers_pct',70),('seuil_deux_tiers_pct',100)")
 charges=[]
 for f,noms in [(IMMO,['terrain_etat_lire','terrain_etat_fusionner_interne','terrain_etat_verrouiller_interne','terrain_compromis_acte','terrain_proprietaire_muter','terrain_reamenagement_poser','terrain_permis_acte','terrain_chantier_acte']), (ECO,['chantier_lancer','chantier_verser','chantier_approvisionner','approvisionner_chantier','chantier_travailler']), (BANQUE,['helvetia_debiter_fonds_ordinaires','compromis_expire_resoudre'])]:
  for nom in noms:c.execute(definition(nom,f));charges.append(nom)
 c.execute(definition('local_vocation_commerciale',ROOT/'baseline/domaines/economie/20_fonctions-2.sql'))
 c.execute(definition('mouvement_titulaire',ROOT/'baseline/domaines/socle/20_fonctions.sql'))
 c.execute(definition('creer_fonds_commerce',ECO));charges.append('creer_fonds_commerce')
 c.execute(definition('payer_ordre',ROOT/'baseline/domaines/economie/20_fonctions-2.sql'));charges.append('payer_ordre')
 c.execute('REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC')
 c.execute('GRANT EXECUTE ON FUNCTION mon_personnage(),acteur_identifie() TO authenticated')
 for dom in ['economie','immobilier-et-territoire']:
  for stmt in (ROOT/f'baseline/domaines/{dom}/70_droits.sql').read_text().split(';'):
   m=re.search(r'GRANT EXECUTE ON FUNCTION public\.([a-z_]+)\(',stmt)
   if m and m[1] in charges:c.execute(stmt+';')
 c.execute('ALTER TABLE terrains_etat ENABLE ROW LEVEL SECURITY; GRANT SELECT ON terrains_etat TO authenticated; CREATE POLICY lecture ON terrains_etat FOR SELECT TO authenticated USING(true)')
 obs=[]
 def q(sql,args=()):c.execute(sql,args);return c.fetchone()[0]
 def noter(id,condition,detail,nature='anomalie_reproduite'):
  assert condition, id+' : constat non reproduit';obs.append({'id':id,'resultat':nature,'constat':detail})
 def appel(sql,args=(),acteur='AuditeurA'):
  q("SELECT set_config('audit.acteur',%s,false)",(acteur,));c.execute('SET ROLE authenticated')
  try:return q(sql,args)
  finally:c.execute('RESET ROLE')
 def reset(data=None):
  c.execute('DELETE FROM terrains_etat; DELETE FROM terrains_historique_ventes; DELETE FROM personnages_donnees; DELETE FROM comptes_bancaires; DELETE FROM prets; DELETE FROM compromis_historique')
  for nom in ['AuditeurA','AuditeurB']:c.execute("INSERT INTO personnages_donnees VALUES(%s,'republic','capitale','ailleurs','accueil',200000,200000,20,1,NULL,now())",(nom,))
  d=data or {'proprietaire':'AuditeurB','city':'capitale','surface':2000}
  c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('republic_audit-parcelle','republic','audit-parcelle',%s,%s)",(d.get('proprietaire'),json.dumps(d)))
 def etat():return q("SELECT data::jsonb FROM terrains_etat LIMIT 1")
 reset();v=appel("SELECT terrain_compromis_acte('audit-parcelle','compromis_signer','{}')")
 noter('I01',v['ok'] and etat()['compromisPar']=='AuditeurA','Compromis pose sur le terrain deja possede par AuditeurB, sans aucun debit.')
 v=appel("SELECT terrain_proprietaire_muter('audit-parcelle','compromis','{\"proprietaire\":\"AuditeurA\",\"valeur_totale\":1,\"compromis\":false,\"constructionAutorisee\":true}')")
 noter('I02',v['ok'] and etat()['proprietaire']=='AuditeurA' and q("SELECT liquide FROM personnages_donnees WHERE name='AuditeurA'")==200000,'Mutation et autorisation posees sans paiement du terrain ni permis independant.')
 reset();v=appel("SELECT terrain_proprietaire_muter('audit-parcelle','serveur','{\"proprietaire\":\"AuditeurA\"}')",acteur='')
 noter('I03',v['ok'] and etat()['proprietaire']=='AuditeurA','Role authenticated sans personnage accepte comme serveur par la RPC de mutation.')
 reset({'proprietaire':'AuditeurA','city':'capitale','constructionAutorisee':True,'niveau_construction':'hangar'})
 v=appel("SELECT chantier_lancer('AuditeurA','republic','audit-parcelle','hangar',10500)")
 noter('I04',v['ok'] and etat()['niveau_construction']=='hangar' and bool(etat()['chantier']),'Second chantier initial autorise sur terrain deja construit.')
 reset({'proprietaire':'AuditeurA','city':'capitale','constructionAutorisee':True})
 def lancer(_):
  d=psycopg2.connect(uri);d.autocommit=True;cc=d.cursor();cc.execute("SELECT set_config('audit.acteur','AuditeurA',false)");cc.execute('SET ROLE authenticated');cc.execute("SELECT chantier_lancer('AuditeurA','republic','audit-parcelle','hangar',10500)");v=cc.fetchone()[0];d.close();return v
 with ThreadPoolExecutor(2) as pool:vs=list(pool.map(lancer,range(2)))
 noter('G01',sum(v['ok'] for v in vs)==1 and q("SELECT liquide FROM personnages_donnees WHERE name='AuditeurA'")==189500,'Deux lancements concurrents, un chantier et un apport seulement.','garantie_locale_observee')
 # Deux commandes de versement identiques : absence d'identifiant de requete.
 appel("SELECT chantier_verser('AuditeurA','republic','audit-parcelle',1000)");appel("SELECT chantier_verser('AuditeurA','republic','audit-parcelle',1000)")
 noter('I05',etat()['chantier']['totalVerse']==12500,'Repetition du meme versement debite deux fois : aucun recu de requete.')
 reset({'proprietaire':'AuditeurA','city':'capitale','permis':{'statut':'valide'},'chantier':{'dureeJours':6,'progressionJours':5,'planVerrouille':True}})
 v=appel("SELECT terrain_permis_acte('audit-parcelle','permis_plan_modifier','{\"permis\":{\"statut\":\"valide\",\"decoupageInitial\":[{\"id\":\"invente\",\"surface\":999999}]}}')")
 noter('I06',v['ok'] and etat()['permis']['decoupageInitial'][0]['surface']==999999,'Plan verrouille et surface non respectes par la porte serveur.')
 reset({'proprietaire':'AuditeurA','niveau_construction':'hangar','city':'capitale'})
 v=appel("SELECT terrain_reamenagement_poser('audit-parcelle','{\"type\":\"reamenagement\",\"dureeJours\":1,\"progressionJours\":1,\"totalVerse\":0,\"planCible\":[] }')")
 noter('I07',v['ok'] and etat()['chantierReamenagement']['progressionJours']==1,'Reamenagement deja acheve fourni par le client, aucun financement preleve.')
 # Reproduction deterministe du pret de 100 000 FR : arg suffit a supprimer le tirage aleatoire.
 reset({'proprietaire':None,'city':'capitale','compromis':True,'compromisPar':'AuditeurA','compromisExpireAt':1,'pretDemande':{'statut':'attente_validation','demandeur':'AuditeurA','montant':100000,'montantTotal':112000,'duree':20,'mensualite':5600}})
 c.execute("INSERT INTO comptes_bancaires(id,personnage,pays,banque,solde) VALUES('audit-compte','AuditeurA','republic','nationale',500)")
 q("SELECT compromis_expire_resoudre('terrain','republic_audit-parcelle')")
 noter('I08',q('SELECT count(*) FROM prets')==1 and q("SELECT arg FROM personnages_donnees WHERE name='AuditeurA'")==300000 and q("SELECT liquide FROM personnages_donnees WHERE name='AuditeurA'")==200000 and q('SELECT solde FROM comptes_bancaires LIMIT 1')==500,'Pret immobilier 100000 inscrit et arg credite, mais aucun credit du liquide ni du compte bancaire.')
 q("SELECT compromis_expire_resoudre('terrain','republic_audit-parcelle')")
 noter('G02',q('SELECT count(*) FROM prets')==1 and q("SELECT arg FROM personnages_donnees WHERE name='AuditeurA'")==300000,'Compromis accorde gele : rejeu sans second contrat/credit arg.','garantie_locale_observee')
 # Une dette historique de meme id est ignoree par ON CONFLICT, alors que le credit est refait.
 c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{pretDemande,statut}','\"attente_validation\"')::text")
 q("SELECT compromis_expire_resoudre('terrain','republic_audit-parcelle')")
 noter('I09',q('SELECT count(*) FROM prets')==1 and q("SELECT arg FROM personnages_donnees WHERE name='AuditeurA'")==400000,'Si le statut du compromis redevient en attente, credit refait malgre conflit sur la dette existante.')
 # Controle financier positif : un refus du debit au lancement ne cree pas de chantier.
 reset({'proprietaire':'AuditeurA','city':'capitale','constructionAutorisee':True});c.execute("UPDATE personnages_donnees SET liquide=0,arg=0")
 v=appel("SELECT chantier_lancer('AuditeurA','republic','audit-parcelle','hangar',10500)")
 noter('G03',not v['ok'] and 'chantier' not in etat(),'Fonds insuffisants : pas de chantier cree.','garantie_locale_observee')
 # Une ligne generee dans un autre pays partage le meme building_id ; recherche non scopee.
 reset();c.execute("DELETE FROM terrains_etat; INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES('narco_audit-parcelle','narco','audit-parcelle','AuditeurB','{\"proprietaire\":\"AuditeurB\"}')")
 v=appel("SELECT terrain_compromis_acte('audit-parcelle','compromis_signer','{}')")
 noter('I10',v['ok'] and etat()['compromisPar']=='AuditeurA','Acteur de Republia modifie la parcelle homonyme narco, recherche sans filtre de pays.')
 # Un fonds dans un batiment construit est refuse APRES le mouvement de tresorerie.
 reset({'proprietaire':'AuditeurA','niveau_construction':'commerce_premium','city':'capitale'})
 c.execute("INSERT INTO locations_actives(id,country,data) VALUES('audit-bail','republic','{\"locataire\":\"AuditeurA\",\"buildingId\":\"audit-parcelle\"}')")
 v=appel("SELECT creer_fonds_commerce('AuditeurA','audit-bail','audit-fonds',1000,'Enseigne fixture')")
 noter('I11',v['raison']=='local_non_commercial' and q("SELECT arg FROM personnages_donnees WHERE name='AuditeurA'")==199000 and q("SELECT count(*) FROM entreprises WHERE id='audit-fonds'")==0,'Creation fonds refusee sur terrain construit, mais apport de 1000 FR retire de arg avant le refus.')
 # RLS prets et droits exacts archives, aucun utilisateur reel.
 c.execute('ALTER TABLE prets ENABLE ROW LEVEL SECURITY')
 droits=(ROOT/'baseline/domaines/banque/70_droits.sql').read_text()
 c.execute(re.search(r'GRANT INSERT, SELECT, UPDATE ON TABLE public.prets TO authenticated;',droits)[0])
 policies=(ROOT/'baseline/domaines/banque/60_rls-policies.sql').read_text()
 for nom in ['prets_maj_acteur','prets_lecture_publique']:
  c.execute(re.search(r'CREATE POLICY '+nom+r' .*?;',policies,re.S)[0])
 c.execute("INSERT INTO prets(id,emprunteur,country,montant_initial,montant_restant,duree_jours,mensualite) VALUES('audit-dette-b','AuditeurB','republic',1000,1000,10,100)")
 appel("UPDATE prets SET montant_restant=0,statut='remboursé' WHERE id='audit-dette-b' RETURNING montant_restant")
 noter('I12',q("SELECT montant_restant FROM prets WHERE id='audit-dette-b'")==0,'RLS du baseline permet a AuditeurA de solder directement la dette de AuditeurB.')
 reset({'proprietaire':'AuditeurB','city':'capitale','chantier':{'type':'construction','coutTravail':21000,'dureeJours':6,'tresorerie':10000,'stockMateriaux':{'bois':100,'minerai':50,'metal':33},'progressionJours':0}})
 v=appel("SELECT chantier_travailler('AuditeurA','republic','audit-parcelle',1)")
 noter('I13',v['ok'] and q("SELECT current_building FROM personnages_donnees WHERE name='AuditeurA'")=='ailleurs','Travail remunere sur chantier sans controle de presence physique dans cette RPC.')
 # Premiere revendication simultanee sur un terrain sans ligne persistante.
 reset();c.execute('DELETE FROM terrains_etat')
 c.execute("CREATE FUNCTION audit_pause_insert() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM pg_sleep(0.4); RETURN NEW; END $$; CREATE TRIGGER audit_pause BEFORE INSERT ON terrains_etat FOR EACH ROW EXECUTE FUNCTION audit_pause_insert()")
 from threading import Barrier
 barriere=Barrier(2)
 def revendiquer(nom):
  d=psycopg2.connect(uri);d.autocommit=True;cc=d.cursor();cc.execute("SELECT set_config('audit.acteur',%s,false)",(nom,));cc.execute('SET ROLE authenticated');barriere.wait();cc.execute("SELECT terrain_compromis_acte('audit-parcelle','compromis_signer','{}')");v=cc.fetchone()[0];d.close();return v
 with ThreadPoolExecutor(2) as pool:vs=list(pool.map(revendiquer,['AuditeurA','AuditeurB']))
 noter('I14',all(v['ok'] for v in vs) and q('SELECT count(*) FROM terrains_etat')==1,'Premiere revendication concurrente : deux verdicts ok pour deux acquereurs, un seul compromis persiste.')
 reset();v=appel("SELECT payer_ordre('AuditeurA','acheter_terrain',2,1000)")
 noter('I15',v['raison']=='cout_non_declare','Vrai payer_ordre + miroir genere : depot acheter_terrain 1000 FR refuse.')
 v=appel("SELECT payer_ordre('AuditeurA','officialiser_transaction',1,23000)")
 noter('I16',v['raison']=='cout_non_declare','Vrai payer_ordre + miroir genere : solde notarial variable 23000 FR refuse.')
 r={'nature':'audit_local_sur_baseline_20261013','productionConsultee':False,'limites':['Identite/poste simules, pas de GoTrue.','Vue personnages projection de fixture, pas la vue masquee et son declencheur complet.','Tables des domaines chargees depuis le baseline ; aucune migration de gameplay appliquee.','Les cas I reproduisent un defaut attendu et ne valent jamais validation fonctionnelle.'], 'sources':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in [IMMO,ECO,BANQUE,ROOT/'baseline/domaines/economie/20_fonctions-2.sql',ROOT/'baseline/domaines/socle/20_fonctions.sql',ROOT/'baseline/domaines/banque/70_droits.sql',ROOT/'baseline/domaines/banque/60_rls-policies.sql']},'observations':obs}
 if args.rapport:args.rapport.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
 for o in obs:print(o['id'],o['resultat'],o['constat'])
 print(f'{len(obs)} constats locaux reproduits ; aucun acces de production.')
 db.close()
if __name__=='__main__':main()
