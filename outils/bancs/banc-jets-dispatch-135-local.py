#!/usr/bin/env python3
"""Identité immuable, transition existante et vrai dispatch, profils jetables."""
from pathlib import Path
import importlib.util,re,json,uuid,sys
R=Path(__file__).resolve().parents[2]
COMMERCE='--commerce' in sys.argv;sys.argv[:]=[x for x in sys.argv if x!='--commerce']
fichier='banc-vol-ordinaire-135-local.py' if COMMERCE else 'banc-evasion-135-local.py'
spec=importlib.util.spec_from_file_location('parent',R/'outils/bancs'/fichier);base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
M='migrations/20261025105501_jets_dispatch_et_identite.sql'
def suite(db,q,srv):
 from psycopg2.extras import Json
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK dispatch',msg,flush=True)
 def lire(s,args=()):q.execute(s,args or None);return q.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 s=(R/'baseline/domaines/politique-et-elections/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public.rp_transitions \(.*?\n\);',s,re.S)[0]);q.execute('ALTER TABLE rp_transitions ADD PRIMARY KEY(cle)');q.execute(fn('baseline/domaines/socle/20_fonctions.sql','rp_transition_active'))
 for _ in range(2):q.execute((R/M).read_text())
 q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET country='republic' WHERE name='Fixture'")
 identite=lire("SELECT id::text FROM personnages_donnees WHERE name='Fixture'");r=lire('SELECT religion_benediction_lire()')
 check(r['personnageId']==identite and r['actesAtomiques']==0,'identite issue du compte et transition absente inactive')
 def appel(ordre,params={},id=None,requete=None):return lire('SELECT ordres_jets_commande(%s,%s,%s,%s)',(id or identite,ordre,Json(params),requete or str(uuid.uuid4())))
 for ordre,params in [('vol',{'p_cible':'Autre','p_genre':'argent'}),('achat_arme_illegal',{'p_entreprise':'armurerie-fixture','p_arme':'couteau'}),('tentative_evasion',{}),('mener_enquete',{'p_cible':'Autre'}),('organiser_filature',{'p_cible':'Autre'}),('organiser_chasse_homme',{'p_cible':'Autre'}),('voler_materiel_chantier',{'p_terrain':'terrain-a-batir-1','p_matiere':'bois'}),('benediction',{'p_religieux':'Père Ception'})]:
  check(appel(ordre,params).get('raison')=='actes_jets_non_actives','aucune activation implicite '+ordre)
 check(appel('benediction',{'p_religieux':'Père Ception'},id=str(uuid.uuid4())).get('raison')=='personnage_change','un nom identique ne remplace pas l identifiant attendu')
 check(appel('benediction',{'p_religieux':'Père Ception','p_montant':99999}).get('raison')=='parametres_invalides','montant navigateur non accepte par adaptateur')
 check(appel('invente').get('raison')=='parametres_invalides','aucun routage arbitraire')
 q.execute("INSERT INTO rp_transitions(cle,actif,note) VALUES('actes_jets_atomiques_republic',true,'fixture seulement');UPDATE personnages_donnees SET hp=100,pa=50,current_city='capitale',current_building='tabernacle-impots',current_room='nef_principale' WHERE name='Fixture';CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT 1$$")
 if not COMMERCE:lire("SELECT detention_clore_interne('Fixture','fixture_fin')")
 check(lire('SELECT religion_benediction_lire()')['actesAtomiques']==1,'transition existante arbitre activation du compte courant')
 cle=str(uuid.uuid4());r=appel('benediction',{'p_religieux':'Père Ception'},requete=cle)
 check(r['ok'] and r['succes'] and r['personnageId']==identite,'attribution deleguee au moteur existant sous meme identite')
 pa=lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'");r=appel('benediction',{'p_religieux':'Père Ception'},requete=cle)
 check(r['rejeu'] and lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==pa,'adaptateur ne casse pas le recu et ne double pas le cout')
 q.execute("ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS resources jsonb DEFAULT '{}'")
 if not COMMERCE:q.execute((R/'migrations/20261025011201_filature_confirmation_financiere.sql').read_text())
 q.execute((R/'migrations/20261025105001_jets_resources_canoniques.sql').read_text())
 if COMMERCE:
  q.execute("UPDATE personnages_donnees SET current_building='armurerie',current_room='magasin',liquide=10000,arg=20000,resources='{\"inf\":0,\"pop\":50}' WHERE name='Fixture';UPDATE comptes_bancaires SET solde=10000 WHERE personnage='Fixture';UPDATE entreprises SET data=jsonb_set(data,'{stockProduits,couteau}','10') WHERE id='armurerie-fixture'")
  r=appel('achat_arme_illegal',{'p_entreprise':'armurerie-fixture','p_arme':'couteau'})
  check(r['ok'] and r['succes'] and r['prix']==750,'route achat clandestin execute la vraie vente')
  q.execute("UPDATE personnages_donnees SET current_building='armurerie',current_room='magasin',country='republic',current_city='capitale',stats='{\"PER\":9,\"CHA\":9}',resources='{\"inf\":0,\"pop\":50}' WHERE name IN('Fixture','Autre');CREATE OR REPLACE FUNCTION vol_hasard_interne() RETURNS numeric LANGUAGE sql AS $$SELECT .9999$$")
  r=appel('vol',{'p_cible':'Autre','p_genre':'argent'});check(r['ok'] and r['succes'],'route vol execute le vrai transfert')
 else:
  q.execute("UPDATE personnages_donnees SET current_building='commissariat',current_room='bureau_commissaire',pa=50,resources='{\"inf\":0,\"pop\":50}' WHERE name='Fixture';UPDATE caisses_batiments SET data='{\"solde\":10000}' WHERE id='republic_commissariat_capitale'")
  r=appel('organiser_filature',{'p_cible':'Autre'});check(r['ok'] and r['succes'],'route filature execute le vrai rapport')
 check(not lire("SELECT has_function_privilege('authenticated','ordres_jets_commande(uuid,text,jsonb,uuid)','EXECUTE')"),'transition seule ne rend pas les commandes publiques')
 q.execute("UPDATE rp_transitions SET actif=false WHERE cle='actes_jets_atomiques_republic'")
 check(lire('SELECT religion_benediction_lire()')['actesAtomiques']==0 and lire('SELECT religion_benediction_lire()')['actesSuspendus'],'relecture constate la suspension et non un retour au moteur historique')
 q.execute("UPDATE personnages_donnees SET current_building='rue-centrale',current_room='sortie' WHERE name='Fixture'")
 avant=lire("SELECT jsonb_build_array(pa,liquide,arg) FROM personnages_donnees WHERE name='Fixture'")
 r=appel('benediction',{'p_religieux':'Père Ception'},requete=cle)
 check(r['ok'] and r['rejeu'] and lire("SELECT jsonb_build_array(pa,liquide,arg) FROM personnages_donnees WHERE name='Fixture'")==avant,'recu relu hors de la piece et apres suspension sans nouveau paiement')
 check(appel('benediction',{'p_religieux':'Faux religieux'},requete=cle).get('raison')=='requete_reutilisee','relecture ne change pas les parametres de l acte acquis')
 check(appel('benediction',{'p_religieux':'Père Ception'}).get('raison')=='actes_jets_non_actives','suspension refuse toute nouvelle demande meme dans une famille deja utilisee')
 if COMMERCE:
  ligne=lire("SELECT jsonb_build_object('requete',requete,'terrain',terrain,'matiere',matiere) FROM chantier_vols_recus WHERE acteur=%s LIMIT 1",(identite,))
  r=appel('voler_materiel_chantier',{'p_terrain':ligne['terrain'].split('_',1)[1],'p_matiere':ligne['matiere']},requete=ligne['requete'])
  check(r['ok'] and r['rejeu'],'reprise du vol de chantier conserve sa liaison au terrain canonique')
 print(json.dumps({'dispatch':True,'profil':'commerce' if COMMERCE else 'justice','assertions':n,'activation_fixture_seulement':True,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':
 driver=base.base.base.base.base.banque.m
 driver.main(tout)
