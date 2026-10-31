#!/usr/bin/env python3
"""SQL reel sur PostgreSQL jetable ; JWT/presence/taxes simules, jamais Supabase."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,tempfile,runpy
R=Path(__file__).resolve().parents[2]
M1=R/'migrations/20261031113558_organisations_equipements_collectifs.sql'
M2=R/'migrations/20261031113559_achat_equipements_collectifs.sql'
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-equipements-'),cleanup_mode='delete');uri=serveur.get_uri();c=psycopg2.connect(uri);c.autocommit=True;q=c.cursor()
 schema=runpy.run_path(str(R/'outils/bancs/banc-achat-commerce-local.py'))['SCHEMA'];q.execute(schema)
 q.execute("ALTER TABLE organisations ALTER COLUMN data TYPE text USING data::text; ALTER TABLE catalogue_generiques ADD PRIMARY KEY (id); CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;")
 q.execute("CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,current_city text,current_building text,current_room text,day integer DEFAULT 10);INSERT INTO personnages_donnees VALUES ('Alice','republic','capitale','siege','bureau',10),('Bob','republic','capitale','siege','bureau',10)")
 q.execute("CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT nullif(current_setting('hg.acteur',true),'')$$;CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT coalesce(current_setting('hg.serveur',true),'')='oui'$$")
 q.execute("CREATE OR REPLACE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF replace($1,'pj:','') IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'acteur_interdit';END IF;END$$")
 q.execute("CREATE OR REPLACE FUNCTION fonds_generiques_accessibles(text) RETURNS TABLE(generique_id text,famille text) LANGUAGE sql AS $$SELECT id,'informatique' FROM catalogue_generiques$$")
 q.execute("CREATE FUNCTION appliquer_taxe_transaction(text,text,numeric) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('net',$3,'taxeLocale',0,'taxeNationale',0)$$")
 def charger(nom,fichier):
  s=(R/fichier).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');b=s.index('$function$;',a)+len('$function$;');q.execute(s[a:b])
 charger('mouvement_titulaire','baseline/domaines/socle/20_fonctions.sql')
 charger('acheter_produit_commerce','baseline/domaines/economie/20_fonctions-1.sql')
 ids=['ordinateur-complet','box-internet','camera-de-surveillance','imprimante-papier','imprimante-3d','peripherique-stockage','peripherique-reseau-intranet','jeu-video']
 for g in ids:q.execute("INSERT INTO catalogue_generiques(id,libelle,regime,est_service,empilable,individualise,encombrement,famille_id) VALUES (%s,%s,'libre',false,false,true,1,'informatique')",(g,g))
 for id,chef in [('o1','Alice'),('o2','Alice'),('o3','Bob')]:q.execute('INSERT INTO organisations VALUES (%s,%s)',(id,json.dumps({'chef':chef,'caisse':1000,'type':'association','country_origine':'republic','city':'capitale','localId':'siege:bureau'})))
 refs={g:{'nom':g,'active':True,'prixVente':5.5,'generique_id':g} for g in ids}
 fonds={'version':2,'statut':'actif','proprietaire':'Alice','implantation':{'country':'republic','city':'capitale'},'references':refs,'stockReferences':{g:50 for g in ids},'coutMoyenReferences':{g:2 for g in ids},'caisse':0}
 q.execute('INSERT INTO entreprises VALUES (%s,%s,now())',('fonds',json.dumps(fonds)))
 q.execute("SELECT set_config('hg.acteur','Alice',false)")
 q.execute("ALTER TABLE ventes_snapshots ALTER COLUMN prix_unitaire TYPE integer; ALTER TABLE ventes_snapshots ALTER COLUMN montant_total TYPE integer")
 q.execute("INSERT INTO ventes_snapshots(requete,acheteur,prix_unitaire,montant_total) VALUES ('achat-historique','Alice',10,20)")
 q.execute(M1.read_text());q.execute(M1.read_text());q.execute(M2.read_text());q.execute(M2.read_text())
 q.execute("SELECT prix_unitaire,montant_total FROM ventes_snapshots WHERE requete='achat-historique'");assert q.fetchone()==(10,20)
 q.execute('GRANT USAGE ON SCHEMA public TO authenticated');n=0
 def call(sql,args=(),cur=q):cur.execute(sql,args);return cur.fetchone()[0]
 def fail(sql,args=(),motif=None):
  try:
   q.execute(sql,args) if args else q.execute(sql)
   raise AssertionError('refus attendu')
  except psycopg2.Error as e:
   if motif:assert motif in str(e),str(e)
 def achat(g,req,qty=1,org='o1',cur=q):return call('SELECT organisation_equipement_acheter(%s,%s,%s,%s,%s)',(req,org,'fonds',g,qty),cur)
 def deplacer(objet,action,req,dest=None):return call('SELECT organisation_equipement_deplacer(%s,%s,%s,%s,%s)',(req,'o1',objet,action,dest))
 def etat(org='o1'):return call('SELECT organisation_equipements_etat(%s)',(org,))
 # Un paiement partage, aucun blocage des achats a son propre commerce.
 r=achat(ids[0],'achat-equipement-000001');assert r['ok'] and r['montant_exact']=='5.5';q.execute("SELECT (data::jsonb->>'caisse')::numeric FROM organisations WHERE id='o1'");assert q.fetchone()[0]==994.5
 q.execute("SELECT count(*) FROM objets_recus");assert q.fetchone()[0]==0
 assert etat()['objets'][0]['id']=='achat-equipement-000001-1';n+=1
 assert achat(ids[0],'achat-equipement-000001')['rejeu'];assert len(etat()['objets'])==1;n+=1
 assert achat(ids[0],'achat-equipement-000001',2)['raison']=='requete_reutilisee';n+=1
 # Chaque peripherique simultane sur UN ordinateur ; plusieurs cameras.
 for i,g in enumerate(ids[1:]):assert achat(g,f'achat-peripherique-{i:06d}',2 if g=='camera-de-surveillance' else 1)['ok']
 assert not any(etat()['capacites'].values())
 for i,o in enumerate(etat()['objets']):assert deplacer(o['id'],'installer',f'equip-install-{i:06d}')['ok']
 e=etat();assert all(e['capacites'].values()) and e['equipements']['ordinateur']==1 and e['equipements']['camera']==2;assert 'jeu_video' not in e['capacites'];n+=1
 before=len(e['objets']);assert deplacer('achat-equipement-000001-1','installer','equip-install-000000')['ok'];assert len(etat()['objets'])==before;n+=1
 # Meme cle, autre operation : refusee.
 fail("SELECT organisation_equipement_deplacer('equip-install-000000','o1','achat-equipement-000001-1','retirer',NULL)",motif='requete_reutilisee');n+=1
 # Pas de possession par presence ou manipulation du navigateur.
 q.execute("SELECT set_config('hg.acteur','Bob',false)");fail("SELECT organisation_equipements_etat('o1')",motif='representation');n+=1
 fail("UPDATE organisations SET data=jsonb_set(data::jsonb,'{chef}','\"Bob\"')::text WHERE id='o1'",motif='transmission');n+=1
 q.execute("SELECT set_config('hg.acteur','Alice',false)")
 fail("SELECT organisation_equipement_deplacer('equip-transfert-00001','o1','achat-equipement-000001-1','transferer','o3')",motif='representation');n+=1
 fail("SELECT organisation_equipement_deplacer('equip-transfert-00002','o1','achat-equipement-000001-1','transferer','o2')",motif='retirer_avant');n+=1
 deplacer('achat-equipement-000001-1','retirer','equip-retirer-000001');assert not any(etat()['capacites'].values());n+=1
 deplacer('achat-equipement-000001-1','transferer','equip-transfert-000003','o2');assert len(etat('o2')['objets'])==1
 assert call("SELECT organisation_equipement_reclamer('o1','achat-equipement-000001-1')")['deja_recue'];assert len(etat('o2')['objets'])==1;n+=1
 # Transition de direction : proprietaire identique, autorisation actualisee.
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{chef}','\"Bob\"')::text WHERE id='o2'")
 fail("SELECT organisation_equipements_etat('o2')",motif='representation');q.execute("SELECT set_config('hg.acteur','Bob',false)");assert len(etat('o2')['objets'])==1;n+=1
 # RLS et ACL : aucun acces direct, meme membre authentifie.
 q.execute('SET ROLE authenticated');fail("INSERT INTO organisation_objets VALUES ('faux','o3','{}',NULL,NULL,NULL,now())");q.execute('RESET ROLE');n+=1
 # Refus de debit : aucun stock, objet ou argent vendeur cree.
 q.execute("SELECT set_config('hg.acteur','Alice',false)");q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{caisse}','0')::text WHERE id='o1'")
 avant=call("SELECT data FROM entreprises WHERE id='fonds'");assert achat(ids[0],'achat-refus-000001')['raison']=='fonds_insuffisants';assert call("SELECT data FROM entreprises WHERE id='fonds'")==avant;n+=1
 # Preuve d'achat obligatoire : un objet adresse a l'organisation ne suffit pas.
 q.execute('INSERT INTO objets_recus VALUES (%s,%s,%s,%s)',('fausse-livraison','orga:o1','x',json.dumps({'generique_id':ids[0],'qty':1})))
 fail("SELECT organisation_equipement_reclamer('o1','fausse-livraison')",motif='preuve_achat');n+=1
 # Concurrence de meme achat : un debit, un exemplaire, un recu.
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{caisse}','100')::text WHERE id='o1'")
 def concurrent(_):
  with psycopg2.connect(uri) as cc:
   with cc.cursor() as cur:cur.execute("SELECT set_config('hg.acteur','Alice',true)");return achat(ids[0],'achat-concurrent-000001',cur=cur)
 with ThreadPoolExecutor(2) as pool:rr=list(pool.map(concurrent,range(2)))
 assert all(r['ok'] for r in rr) and sum(bool(r.get('rejeu')) for r in rr)==1
 assert call("SELECT (data::jsonb->>'caisse')::numeric FROM organisations WHERE id='o1'")==94.5;n+=1
 # Lieu du serveur, pas une chaine envoyee par le navigateur.
 q.execute("UPDATE personnages_donnees SET current_room='ailleurs' WHERE name='Alice'")
 fail("SELECT organisation_equipement_deplacer('equip-horslieu-000001','o1','achat-concurrent-000001-1','installer',NULL)",motif='installation_hors_local');n+=1
 # Sous-centime refuse, aucune conversion silencieuse.
 q.execute("UPDATE entreprises SET data=jsonb_set(data,ARRAY['references','ordinateur-complet','prixVente'],'5.555') WHERE id='fonds'")
 assert achat(ids[0],'achat-centime-000001')['raison']=='fraction_centime_interdite';n+=1
 # Delegation de tresorerie existante : chef dessaisi, tresorier seul payeur.
 q.execute("UPDATE entreprises SET data=jsonb_set(data,ARRAY['references','ordinateur-complet','prixVente'],'5.50') WHERE id='fonds'")
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{tresorier}','\"Bob\"')::text WHERE id='o1'")
 fail("SELECT organisation_equipement_acheter('achat-tresorier-000001','o1','fonds','ordinateur-complet',1)",motif='gestionnaire')
 q.execute("SELECT set_config('hg.acteur','Bob',false)")
 assert achat(ids[0],'achat-tresorier-000002')['ok']
 fail("UPDATE organisations SET data=(data::jsonb-'tresorier')::text WHERE id='o1'",motif='transmission')
 q.execute("SELECT set_config('hg.acteur','Alice',false)");q.execute("UPDATE organisations SET data=(data::jsonb-'tresorier')::text WHERE id='o1'");n+=1
 # Un echec de journal doit annuler debit, stock, vente, livraison et objet.
 avant=call("SELECT data FROM entreprises WHERE id='fonds'");solde=call("SELECT data FROM organisations WHERE id='o1'")
 q.execute("CREATE FUNCTION panne_journal() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_journal_fixture';END$$;CREATE TRIGGER panne_journal BEFORE INSERT ON organisation_equipements_journal FOR EACH ROW EXECUTE FUNCTION panne_journal()")
 fail("SELECT organisation_equipement_acheter('achat-panne-000001','o1','fonds','ordinateur-complet',1)",motif='panne_journal_fixture')
 assert call("SELECT data FROM entreprises WHERE id='fonds'")==avant and call("SELECT data FROM organisations WHERE id='o1'")==solde
 q.execute("SELECT count(*) FROM ventes_snapshots WHERE requete='achat-panne-000001'");assert q.fetchone()[0]==0
 q.execute('DROP TRIGGER panne_journal ON organisation_equipements_journal');n+=1
 # Aucun filtre d'eligibilite fonde sur le type d'organisation.
 for t in ['commerciale','association','politique','criminelle','syndicale','religieuse','loge','supporters']:
  q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{type}',%s::jsonb)::text WHERE id='o1'",(json.dumps(t),));assert etat()['ok']
 n+=1
 fail("DELETE FROM organisations WHERE id='o1'");n+=1
 q.execute("SELECT count(*) FROM organisation_equipements_journal");assert q.fetchone()[0]>10;n+=1
 # Deux onglets sur le meme acte d'installation, un seul mouvement.
 q.execute("UPDATE personnages_donnees SET current_room='bureau' WHERE name='Alice'")
 def installer_concurrent(_):
  with psycopg2.connect(uri) as cc:
   with cc.cursor() as cur:
    cur.execute("SELECT set_config('hg.acteur','Alice',true)")
    cur.execute("SELECT organisation_equipement_deplacer('equip-concurrent-000001','o1','achat-concurrent-000001-1','installer',NULL)");return cur.fetchone()[0]
 with ThreadPoolExecutor(2) as pool:rr=list(pool.map(installer_concurrent,range(2)))
 assert all(r['ok'] for r in rr)
 q.execute("SELECT count(*) FROM organisation_equipements_journal WHERE objet_id='achat-concurrent-000001-1' AND action='installer'");assert q.fetchone()[0]==1;n+=1
 # Les capacites cessent immediatement au retrait d'une piece necessaire.
 call("SELECT organisation_capacite_exiger('o1','impression_3d')")
 deplacer('achat-concurrent-000001-1','retirer','equip-retrait-000002')
 fail("SELECT organisation_capacite_exiger('o1','impression_3d')",motif='configuration');n+=1
 # Definir une autre version n'est jamais ecrase silencieusement par la migration.
 definition=call("SELECT pg_get_functiondef('acheter_produit_commerce(text,text,text,text,integer)'::regprocedure)")
 q.execute(definition.replace('BEGIN','BEGIN\n-- divergence de test',1))
 fail(M2.read_text(),motif='a_reexaminer');q.execute('ROLLBACK');q.execute(definition);n+=1
 q.execute("COMMENT ON TABLE organisation_objets IS 'autre schema'")
 fail(M1.read_text(),motif='schema_equipements_inconnu');q.execute('ROLLBACK');q.execute("COMMENT ON TABLE organisation_objets IS 'HG equipements collectifs v1'");n+=1
 # RPC publiques sous role authentifie ; primitives internes et anon refusees.
 q.execute('SET ROLE authenticated');assert etat()['ok']
 fail("SELECT organisation_equipement_exiger('o1')")
 q.execute('RESET ROLE');q.execute('SET ROLE anon');fail("SELECT organisation_equipements_etat('o1')");q.execute('RESET ROLE');n+=1
 # Une election historique legitime peut changer le dirigeant sans perdre les objets.
 election={'enCours':True,'phase':'vote','dateFinVote':5,'candidats':[{'nom':'Bob'},{'nom':'Alice'}],'votes':{'Alice':'Bob','Bob':'Bob'}}
 q.execute("UPDATE organisations SET data=(data::jsonb || %s::jsonb)::text WHERE id='o1'",(json.dumps({'membres':[{'nom':'Alice'},{'nom':'Bob'}],'election':election}),))
 q.execute("SELECT set_config('hg.acteur','Bob',false)")
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{chef}','\"Bob\"')::text WHERE id='o1'")
 assert len(etat()['objets'])>0
 q.execute("SELECT set_config('hg.acteur','Alice',false)");fail("SELECT organisation_equipements_etat('o1')",motif='representation');n+=1
 # Le droit d'UPDATE historique rend le financement non deployable : garde reelle.
 q.execute('GRANT UPDATE ON organisations TO authenticated')
 fail(M2.read_text(),motif='ecritures_generales_a_migrer');q.execute('ROLLBACK')
 fail(M1.read_text(),motif='autorite_generale_a_migrer');q.execute('ROLLBACK')
 q.execute('REVOKE UPDATE ON organisations FROM authenticated');n+=1
 # Le nouveau contrat de dissolution respecte la FK du socle reel.
 q.execute((R/'migrations/20261031113600_organisations_commandes_administratives.sql').read_text())
 q.execute("SELECT set_config('hg.acteur','Bob',false)")
 fail("SELECT organisation_commande_administrative('orgcmd-dissolution-000001','o1','dissoudre','{}')",motif='foreign key')
 assert len(etat()['objets'])>0
 assert call("SELECT count(*) FROM organisation_commandes_recus WHERE requete='orgcmd-dissolution-000001'")==0;n+=1
 # Progression atomique compatible avec la garde municipale/organisation et les biens persistants.
 q.execute((R/'migrations/20261031113602_organisations_adhesions_grades.sql').read_text())
 q.execute((R/'migrations/20261031113603_organisations_progression_elections.sql').read_text())
 q.execute("SELECT set_config('hg.acteur','Alice',false)")
 election={'enCours':True,'phase':'candidatures','dateFinCandidatures':5,'dateFinVote':6,'candidats':[{'nom':'Alice'},{'nom':'Bob'}],'votes':{'Bob':'Alice'}}
 q.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{election}',%s::jsonb)::text WHERE id='o1'",(json.dumps(election),))
 total=call("SELECT count(*) FROM organisation_objets WHERE organisation='o1'")
 assert call("SELECT organisation_commande_membres('orgcmd-election-equipee','o1','avancer_election','{}')")['ok']
 assert len(etat()['objets'])==total
 q.execute("SELECT set_config('hg.acteur','Bob',false)");fail("SELECT organisation_equipements_etat('o1')",motif='representation');n+=1
 c.close();serveur.cleanup();print(f'{n}/{n} groupes SQL collectifs reussis ; paiement commun et tables jetables, aucun Supabase.')
if __name__=='__main__':main()
