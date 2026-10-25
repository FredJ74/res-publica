#!/usr/bin/env python3
"""Fermer les anciennes portes après activation, garder les mêmes moteurs internes."""
from pathlib import Path
import importlib.util,re,json,uuid,sys
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
COMMERCE='--commerce' in sys.argv
spec=importlib.util.spec_from_file_location('dispatch',R/'outils/bancs/banc-jets-dispatch-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
M='migrations/20261025110001_jets_gardes_historiques.sql'
def suite(db,q,srv):
 import psycopg2
 from psycopg2.extras import Json
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK garde legacy',msg,flush=True)
 def lire(s,args=()):q.execute(s,args or None);return q.fetchone()[0]
 src=(R/'baseline/domaines/justice/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public.vols_en_attente \(.*?\n\);',src,re.S)[0]);q.execute('ALTER TABLE vols_en_attente ADD PRIMARY KEY(id)')
 for _ in range(2):q.execute((R/M).read_text())
 if MUTANT:
  if MUTANT=='paiement':q.execute("CREATE OR REPLACE FUNCTION ordres_jets_refuser_legacy(p_acteur text,p_famille text) RETURNS boolean LANGUAGE sql AS $$SELECT false$$")
  else:
   nom,avant,apres={
    'lecture':('filature_deplacements(text)',"IF public.ordres_jets_refuser_legacy(public.mon_personnage(),'organiser_filature') THEN",'IF false THEN'),
    'depot':('vol_legacy_inserer_garder()',"IF public.rp_transition_active('actes_jets_atomiques_'||(SELECT country FROM public.personnages_donnees WHERE name=public.mon_personnage())) THEN",'IF false THEN')
   }[MUTANT]
   d=lire('SELECT pg_get_functiondef(%s::regprocedure)',(nom,));assert d.count(avant)==1;q.execute(d.replace(avant,apres))
 q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET hp=100,pa=50,country='republic',current_city='capitale',current_building='commissariat',current_room='bureau_commissaire' WHERE name='Fixture'")
 check(lire("SELECT ordres_jets_refuser_legacy('Fixture','organiser_filature')") is False,'transition inactive ne supprime pas les anciennes fonctions')
 q.execute("UPDATE rp_transitions SET actif=true WHERE cle='actes_jets_atomiques_republic'")
 avant=lire("SELECT jsonb_build_array(pa,liquide,arg) FROM personnages_donnees WHERE name='Fixture'")
 for nom,pa in [('voler',2),('mener_enquete',2),('organiser_filature',2),('organiser_chasse_homme',3),('tentative_evasion',3),('demander_benediction_contact',1),('voler_materiel_chantier',2)]:
  r=lire('SELECT payer_ordre(%s,%s,%s,0)',('Fixture',nom,pa));check(r.get('raison')=='commande_jet_atomique_requise','paiement historique bloque avant depense '+nom)
 check(lire("SELECT jsonb_build_array(pa,liquide,arg) FROM personnages_donnees WHERE name='Fixture'")==avant,'aucun des refus ne depense PA ou argent')
 r=lire("SELECT filature_deplacements('Autre')");check(r.get('raison')=='commande_jet_atomique_requise','rapport ne se lit pas sans acte acquitte')
 if not COMMERCE:
  r=lire("SELECT commissaire_enqueter('Autre')");check(r.get('raison')=='commande_jet_atomique_requise','enquete historique ne contourne pas le jet')
  r=lire("SELECT detention_clore_evasion()");check(r.get('raison')=='commande_jet_atomique_requise','cloture nue ne contourne pas le jet d evasion')
 try:q.execute("INSERT INTO vols_en_attente(id,victime,voleur,type_butin,montant) VALUES('legacy-forge-fixture','Autre','Nom usurpe','argent',100)");raise AssertionError('ancien depot accepte')
 except psycopg2.Error as ex:check('commande_jet_atomique_requise' in str(ex),'nouveau vol differe bloque meme avec nom de voleur usurpe')
 identite=lire("SELECT id::text FROM personnages_donnees WHERE name='Fixture'")
 if COMMERCE:
  q.execute("UPDATE personnages_donnees SET current_building='armurerie',current_room='magasin',liquide=10000,arg=20000 WHERE name='Fixture';UPDATE comptes_bancaires SET solde=10000 WHERE personnage='Fixture';UPDATE entreprises SET data=jsonb_set(data,'{stockProduits,couteau}','10') WHERE id='armurerie-fixture';CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT 1$$")
  r=lire("SELECT commerce_vendre_produit_interne('Fixture','armurerie-fixture','[{\"produit\":\"couteau\",\"qte\":1}]','marche_noir','choisir_arme',1,0,NULL,NULL)");check(r.get('raison')=='commande_jet_atomique_requise','ancienne vente clandestine seule refusee')
  r=lire('SELECT ordres_jets_commande(%s,%s,%s,%s)',(identite,'achat_arme_illegal',Json({'p_entreprise':'armurerie-fixture','p_arme':'couteau'}),str(uuid.uuid4())))
  check(r['ok'] and r['succes'],'meme vente fonctionne a travers le vrai hote et sa capacite privee')
  # Vrai moteur fiscal chargé ; cette fixture choisit des taux nuls, sans simuler le calcul.
  source_fiscal=(R/'baseline/domaines/finances-publiques/10_tables.sql').read_text()
  for nom in ['budgets_municipaux','budgets_nationaux']:
   q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',source_fiscal,re.S)[0])
  f=(R/'baseline/domaines/finances-publiques/20_fonctions-1.sql').read_text();a=f.index('CREATE OR REPLACE FUNCTION public.appliquer_taxe_transaction(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',f[a:],re.S);q.execute(f[a:a+m.end()])
  q.execute("INSERT INTO budgets_municipaux(id,data) VALUES('republic_capitale','{\"tauxLocal\":0}');INSERT INTO budgets_nationaux(id,data) VALUES('republic','{\"tauxNational\":0}')")
  # L'achat légal ne dépend pas du nouveau jet clandestin.
  q.execute("UPDATE entreprises SET data=jsonb_set(data,'{stockProduits,couteau}','10') WHERE id='armurerie-fixture'")
  r=lire("SELECT commerce_vendre_produit_interne('Fixture','armurerie-fixture','[{\"produit\":\"couteau\",\"qte\":1}]','comptoir','choisir_arme',0,0,NULL,NULL)")
  check(r['ok'] and r['total']==250,'achat legal preserve sans imposer un jet clandestin')
 else:
  q.execute("UPDATE caisses_batiments SET data='{\"solde\":10000}' WHERE id='republic_commissariat_capitale';CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT 1$$")
  r=lire('SELECT ordres_jets_commande(%s,%s,%s,%s)',(identite,'organiser_filature',Json({'p_cible':'Autre'}),str(uuid.uuid4())))
  check(r['ok'] and r['succes'],'vrai rapport fonctionne dans le meme moteur sous capacite privee')
 check(lire('SELECT count(*) FROM vols_en_attente')==0,'aucune livraison historique purgee ou inventee')
 print(json.dumps({'gardes_historiques':True,'assertions':n,'profil':'commerce' if COMMERCE else 'justice','execution_personnelle_non_archivee':True,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.base.base.base.base.banque.m.main(tout)
