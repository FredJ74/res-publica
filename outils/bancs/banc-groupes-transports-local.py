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
 ctx['c'].commit()
 requete='00000000-0000-4000-8000-000000000099'
 def depart(avec_pnj=False):
  sql("UPDATE personnages_donnees SET current_building='centre-multinodal-luthecia',current_room='hall_gare',current_street=NULL WHERE name IN ('A','B')")
  if not avec_pnj:
   q.execute("SELECT array_agg(id ORDER BY id) FROM pnj_membres WHERE leader_pj='B'");ids=q.fetchone()[0]
   if ids:exige(rpc('pnj_deployer_unite',(ids,True),qui='B'))
 def transport(req=requete,ville='ville_a'):return rpc('transport_effectuer',('train','republic',ville,req),qui='B')
 def photo():
  q.execute('SELECT jsonb_agg(to_jsonb(d) ORDER BY name) FROM personnages_donnees d');return q.fetchone()[0]
 def voyage():
  depart();v=exige(transport());assert len(v['paiements'])==2,v
  q.execute("SELECT count(*) FROM personnages_donnees WHERE name IN ('A','B') AND current_city='ville_a' AND liquide=425 AND pa=10");assert q.fetchone()[0]==2
  avant=photo();assert transport()==v;assert photo()==avant
 cas('transport_train_deux_billets_et_mouvement_atomique_rejeu',voyage)
 def manque():
  depart();sql("UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name='B'");avant=photo();exige(transport(),'fonds_insuffisants');assert photo()==avant
 cas('transport_second_payeur_refuse_annule_premier_debit',manque)
 def prison():
  depart();sql("UPDATE personnages_donnees SET est_emprisonne='{}' WHERE name='A'");avant=photo();exige(transport(),'personnage_indisponible');assert photo()==avant
 cas('transport_prison_membre_refuse_avant_tout_debit',prison)
 def detour():
  depart();v=exige(transport());exige(transport(ville='ville_b'),'requete_reutilisee')
 cas('transport_requete_ne_peut_changer_de_destination',detour)
 def international():
  depart();avant=photo();exige(rpc('transport_effectuer',('avion','soviet','capitale',requete),qui='B'),'controle_douanier_requis');assert photo()==avant
 cas('transport_aucun_contournement_douanier',international)
 def acl():
  for role in ['anon','authenticated','service_role']:
   q.execute("SELECT has_function_privilege(%s,'payer_ordre_interne(text,text,integer,integer)','EXECUTE')",(role,));assert q.fetchone()[0] is False
 cas('transport_encaissement_parametre_non_expose',acl)
 def pnj_non_arbitre():
  depart(True);avant=photo();exige(transport(),'tarification_pnj_a_preciser');assert photo()==avant
 cas('transport_PNJ_pas_de_gratuite_ni_tarif_invente',pnj_non_arbitre)

if __name__=='__main__':
 amb=lots.amb;rondes=amb.rondes;interieur=rondes.interieur;natif=interieur.natif;rue=natif.rue;f=rue.force
 sys.exit(f.corps.g.main(lambda c:f.corps.extension(c,lambda c:f.suite(c,lambda c:rue.suite(c,lambda c:natif.suite(c,lambda c:interieur.suite(c,lambda c:rondes.suite(c,lambda c:amb.suite(c,lambda c:lots.suite(c,suite))))))))))
