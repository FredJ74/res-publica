#!/usr/bin/env python3
"""Encaissement existant et positions dans une seule transaction, identités fictives."""
import importlib.util,re,sys,subprocess,json
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('lots',R/'outils/bancs/banc-groupes-lots-dynamiques-local.py');lots=importlib.util.module_from_spec(sp);sp.loader.exec_module(lots)
def suite(ctx):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 q.execute("CREATE SCHEMA IF NOT EXISTS auth;CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$")
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN arg integer DEFAULT 500, ADD COLUMN liquide integer DEFAULT 500')
 q.execute('CREATE VIEW personnages AS SELECT * FROM personnages_donnees')
 ctx['installer_fonction_canonique']('payer_ordre')
 # Les types, tarifs et villes viennent du dépôt, pas de prix de fixture.
 for domaine,nom in [('economie','ordres_couts'),('immobilier-et-territoire','villes')]:
  q.execute('SELECT to_regclass(%s)',('public.'+nom,))
  if q.fetchone()[0] is None:
   s=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',s,re.S)[0])
 # Exécuter les extracteurs existants sous Node pour ce décor ; pas de seed
 # inventé, et pas une prétendue réussite des contrôles JavaScriptCore.
 def extraire(nom):
  sp=importlib.util.spec_from_file_location('generateur_'+nom,R/('outils/generateurs/generer_'+nom+'.py'));g=importlib.util.module_from_spec(sp);sp.loader.exec_module(g)
  js="const fs=require('fs'),vm=require('vm'),c=vm.createContext({readFile:p=>fs.readFileSync(p,'utf8'),print:x=>process.stdout.write(String(x)+'\\n')});c.load=p=>vm.runInContext(fs.readFileSync(p,'utf8'),c);vm.runInContext(fs.readFileSync(0,'utf8'),c);"
  retour=subprocess.run(['node','-e',js],input=g.EXTRACTEUR,text=True,cwd=R,capture_output=True,check=True)
  return g,json.loads(retour.stdout)
 g,brut=extraire('ordres_couts')
 for fn,pa,cout in g.triples(brut):q.execute('INSERT INTO ordres_couts(fn,pa,cost) VALUES(%s,%s,%s)',(fn,pa,cout))
 g,villes=extraire('villes')
 assert not villes['desaccords'],villes['desaccords']
 for v in villes['villes']:q.execute('INSERT INTO villes(pays,ville,nom,est_capitale,rang) VALUES(%s,%s,%s,%s,%s)',(v['pays'],v['ville'],v['nom'],v['est_capitale'],v['rang']))
 for nom in ['20261028194000_transport_encaissement_existant.sql','20261028194100_transport_intra_atomique.sql']:
  q.execute((R/'migrations'/nom).read_text());q.execute((R/'migrations'/nom).read_text())
 if '--contre-tarif-collectif' in sys.argv:
  # Réintroduire seulement le défaut « un billet pour tout le groupe ». Aucun
  # scénario désactivé : les mêmes attentes doivent dénoncer le sous-paiement.
  q.execute("SELECT pg_get_functiondef('public.payer_ordre_interne(text,text,integer,integer,integer)'::regprocedure)")
  q.execute(q.fetchone()[0].replace('p_cost:=coalesce(p_cost,0)*p_quantite;','p_cost:=coalesce(p_cost,0);'))
 ctx['c'].commit()
 requete='00000000-0000-4000-8000-000000000099'
 def depart(avec_pnj=True):
  sql("UPDATE personnages_donnees SET current_building='centre-multinodal-luthecia',current_room='hall_gare',current_street=NULL WHERE name IN ('A','B')")
  if not avec_pnj:
   q.execute("SELECT array_agg(id ORDER BY id) FROM pnj_membres WHERE leader_pj='B'");ids=q.fetchone()[0]
   if ids:exige(rpc('pnj_deployer_unite',(ids,True),qui='B'))
 def transport(req=requete,ville='ville_a'):return rpc('transport_effectuer',('train','republic',ville,req),qui='B')
 def photo():
  q.execute('SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d');return q.fetchone()[0]
 def voyage():
  depart();sql("UPDATE personnages_donnees SET liquide=2000,arg=2000 WHERE name='B'");v=exige(transport());assert len(v['paiements'])==1 and v['voyageurs']==9,v
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_city='ville_a' ");assert q.fetchone()[0]==2
  q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='B'");assert q.fetchone()==(1325,10)
  q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(500,12)
  q.execute("SELECT count(*) FROM pnj_membres m CROSS JOIN LATERAL pnj_position_effective(m.id) pe WHERE m.leader_pj='B' AND pe.ville='ville_a'");assert q.fetchone()[0]==7
  avant=photo();assert transport()==v;assert photo()==avant
 cas('transport_train_leader_paie_neuf_voyageurs_rejeu',voyage)
 def manque():
  depart();sql("UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name='B'");avant=photo();exige(transport(),'fonds_insuffisants');assert photo()==avant
 cas('transport_leader_insuffisant_aucun_debit_ni_position',manque)
 def prison():
  depart();sql("UPDATE personnages_donnees SET est_emprisonne='{}' WHERE name='A'");avant=photo();exige(transport(),'personnage_indisponible');assert photo()==avant
 cas('transport_prison_membre_refuse_avant_tout_debit',prison)
 def detour():
  depart();sql("UPDATE personnages_donnees SET liquide=2000,arg=2000 WHERE name='B'");v=exige(transport());exige(transport(ville='ville_b'),'requete_reutilisee')
 cas('transport_requete_ne_peut_changer_de_destination',detour)
 def international():
  depart();avant=photo();exige(rpc('transport_effectuer',('avion','soviet','capitale',requete),qui='B'),'controle_douanier_requis');assert photo()==avant
 cas('transport_aucun_contournement_douanier',international)
 def acl():
  for role in ['anon','authenticated','service_role']:
   for signature in ['payer_ordre_interne(text,text,integer,integer)','payer_ordre_interne(text,text,integer,integer,integer)']:
    q.execute('SELECT has_function_privilege(%s,%s,%s)',(role,signature,'EXECUTE'));assert q.fetchone()[0] is False
 cas('transport_encaissement_parametre_non_expose',acl)
 def bus():
  depart();sql("UPDATE personnages_donnees SET liquide=2000,arg=2000 WHERE name='B'")
  v=exige(rpc('transport_effectuer',('bus','republic','ville_a',requete),qui='B'))
  assert v['voyageurs']==9 and v['paie']['montant_preleve']==1350 and v['paie']['pa_preleves']==1,v
  q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='B'");assert q.fetchone()==(650,11)
 cas('transport_bus_neuf_voyageurs_PA_de_l_ordre_une_fois',bus)
 def public_unitaire():
  depart();v=exige(rpc('payer_ordre',('B','prendre_train',2,75),qui='B'));assert v['montant_preleve']==75 and v['pa_preleves']==2
 cas('paiement_public_historique_garde_le_tarif_unitaire',public_unitaire)

 def total_insuffisant():
  depart(True);avant=photo();exige(transport(),'fonds_insuffisants');assert photo()==avant
 cas('transport_fonds_pour_un_billet_mais_pas_pour_tous_refuse',total_insuffisant)
 def banque():
  depart();sql("UPDATE personnages_donnees SET liquide=100,arg=700 WHERE name='B'")
  sql("INSERT INTO comptes_bancaires(id,personnage,pays,banque,solde) VALUES('banque-B','B','republic','nationale',600)")
  v=exige(transport());assert v['paie']['montant_preleve']==675,v
  q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='B'");assert q.fetchone()==(0,10)
  q.execute("SELECT solde FROM comptes_bancaires WHERE id='banque-B'");assert q.fetchone()[0]==25
 cas('transport_encaissement_liquide_et_compte_national_existants',banque)
 def rue_interdite():
  depart();sql("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='rue-1',liquide=2000,arg=2000 WHERE name IN ('A','B')")
  avant=photo();exige(transport(),'pas_au_terminal');assert photo()==avant
 cas('transport_depuis_rue_refuse_meme_si_batiment_NULL',rue_interdite)
 def passager_sans_pa():
  depart();sql("UPDATE personnages_donnees SET liquide=2000,arg=2000 WHERE name='B';UPDATE personnages_donnees SET liquide=0,arg=0,pa=0 WHERE name='A'")
  exige(transport())
  q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='A'");assert q.fetchone()==(0,0)
 cas('transport_passager_pas_de_debit_financier_ni_PA',passager_sans_pa)
 def surcharge():
  depart();sql("UPDATE personnages_donnees SET liquide=2000,arg=2000 WHERE name='B';UPDATE personnages_donnees SET inventory='[{\"id\":\"objet-fixture\",\"qty\":101}]' WHERE name='A'")
  avant=photo();exige(transport(),'inventaire_surcharge');assert photo()==avant
 cas('transport_surcharge_passager_refuse_avant_tout_debit',surcharge)
 def solo():
  sql("UPDATE personnages_donnees SET current_building='centre-multinodal-luthecia',current_room='hall_gare',current_street=NULL WHERE name='C'")
  v=exige(rpc('transport_effectuer',('train','republic','ville_a',requete),qui='C'))
  assert v['voyageurs']==1 and v['paie']['montant_preleve']==75 and v['paie']['pa_preleves']==2,v
  q.execute("SELECT liquide FROM personnages_donnees WHERE name='C'");assert q.fetchone()[0]==425
 cas('transport_individuel_conserve_tarif_et_PA_historiques',solo)
 def membre_non_chef():
  depart();avant=photo();exige(rpc('transport_effectuer',('train','republic','ville_a',requete),qui='A'),'chef_de_groupe_requis');assert photo()==avant
 cas('transport_membre_ne_peut_engager_paiement_du_chef',membre_non_chef)
 def panne_projection():
  depart();sql("UPDATE personnages_donnees SET liquide=2000,arg=2000 WHERE name='B'");avant=photo()
  q.execute("SELECT jsonb_agg(to_jsonb(m) ORDER BY id) FROM pnj_membres m");pnjs=q.fetchone()[0]
  q.execute("CREATE OR REPLACE FUNCTION pnj_groupes_projeter_institutions_interne(p_ids text[]) RETURNS void LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'panne_transport_fixture'; END $$")
  q.execute('SAVEPOINT panne_transport')
  try:transport()
  except Exception as e:
   q.execute('ROLLBACK TO SAVEPOINT panne_transport');q.execute('RESET ROLE');assert 'panne_transport_fixture' in str(e),e
  else:raise AssertionError('projection échouée mais transport accepté')
  assert photo()==avant
  q.execute("SELECT jsonb_agg(to_jsonb(m) ORDER BY id) FROM pnj_membres m");assert q.fetchone()[0]==pnjs
  q.execute('SELECT count(*) FROM navigation_requetes');assert q.fetchone()[0]==0
 cas('transport_panne_aval_annule_debit_positions_PJ_PNJ_et_recu',panne_projection)

 # Le décor et un transport fictif sont committés uniquement dans pgserver pour
 # observer la visibilité du reçu après un verrou concurrent réellement attendu.
 depart();sql("UPDATE personnages_donnees SET liquide=2000,arg=2000 WHERE name='B'");ctx['c'].commit()
 def concurrence():
  import psycopg2,time
  from concurrent.futures import ThreadPoolExecutor
  un=psycopg2.connect(ctx['serveur'].get_uri());deux=psycopg2.connect(ctx['serveur'].get_uri())
  try:
   for cc in [un,deux]:cc.cursor().execute("SET statement_timeout='8s'")
   args=('train','republic','ville_a',requete)
   v=exige(rpc('transport_effectuer',args,qui='B',cur=un.cursor()))
   with ThreadPoolExecutor(1) as pool:
    f=pool.submit(rpc,'transport_effectuer',args,'B',deux.cursor())
    try:
     limite=time.monotonic()+3;bloque=False
     while time.monotonic()<limite:
      q.execute('SELECT pg_stat_clear_snapshot()');q.execute('SELECT wait_event_type FROM pg_stat_activity WHERE pid=%s',(deux.get_backend_pid(),))
      if q.fetchone()[0]=='Lock':bloque=True;break
      if f.done():break
      time.sleep(.01)
     assert bloque,'pas de concurrence observée sur le verrou'
    finally:
     un.commit()
     ctx['preuves_extension']['precision']='Une sortie et un transport fictifs committés uniquement dans PostgreSQL éphémère pour les snapshots concurrents ; autres scénarios annulés, aucune production.'
    assert exige(f.result(timeout=8))==v
   deux.rollback()
   q.execute("SELECT liquide,pa FROM personnages_donnees WHERE name='B'");assert q.fetchone()==(1325,10)
   q.execute('SELECT count(*) FROM navigation_requetes');assert q.fetchone()[0]==1
  finally:un.rollback();deux.rollback();un.close();deux.close()
 cas('transport_deux_commandes_concurrentes_meme_recu_un_seul_debit',concurrence)

if __name__=='__main__':
 amb=lots.amb;rondes=amb.rondes;interieur=rondes.interieur;natif=interieur.natif;rue=natif.rue;f=rue.force
 sys.exit(f.corps.g.main(lambda c:f.corps.extension(c,lambda c:f.suite(c,lambda c:rue.suite(c,lambda c:natif.suite(c,lambda c:interieur.suite(c,lambda c:rondes.suite(c,lambda c:amb.suite(c,lambda c:lots.suite(c,suite))))))))))
