#!/usr/bin/env python3
"""Achat clandestin : commerce, réception, justice et bénédiction réels, privé."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,re,json,uuid,subprocess,sys
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
spec=importlib.util.spec_from_file_location('vol',R/'outils/bancs/banc-vol-chantier-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
MIGRATIONS=['migrations/20261025012601_armes_jet_referentiel.sql','migrations/20261025012701_arme_clandestine_commande.sql']
def suite(db,q,srv):
 import psycopg2
 from psycopg2.extras import Json
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK arme clandestine',msg,flush=True)
 def lire(s,args=(),cur=q):cur.execute(s,args or None);return cur.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS career text;ALTER TABLE entreprises ADD COLUMN IF NOT EXISTS updated_at timestamptz')
 for nom in ['recettes_commerce','recettes_production','entreprises_constantes']:
  s=(R/'baseline/domaines/economie/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',s,re.S)[0])
 q.execute((R/'baseline/seeds/91_empire/recettes_production.sql').read_text());q.execute(fn('baseline/domaines/economie/20_fonctions-1.sql','entreprise_ajouter_historique'))
 for nom in ['restaurant_luthecia_est_commerce','restaurant_luthecia_carte','restaurant_luthecia_vente_verifier','commerce_vendre_produit_interne']:q.execute(fn('migrations/20261019221500_luthecia_cartes_et_diners.sql',nom))
 q.execute("INSERT INTO ordres_couts VALUES('choisir_arme',0,0)")
 for m in MIGRATIONS:q.execute((R/m).read_text());q.execute((R/m).read_text())
 if MUTANT:
  avant,apres={
   'rejeu':('IF FOUND THEN\n  IF ancien.entreprise','IF FOUND AND false THEN\n  IF ancien.entreprise'),
   'prix':("p_arme)::numeric*3;","p_arme)::numeric*2;"),
   'bonus':("bonus:=public.religion_benediction_consommer_interne(p.id,'achat_arme_illegal',p_requete);",'bonus:=0;')
  }[MUTANT]
  d=lire("SELECT pg_get_functiondef('arme_clandestine_commande(text,text,uuid)'::regprocedure)");assert d.count(avant)==1;q.execute(d.replace(avant,apres))
 attendus=json.loads(subprocess.check_output(['node',str(R/'outils/generateurs/generer_armes_jet_referentiel.cjs')],text=True));q.execute('SELECT pays,ville,batiment,piece,arme,data FROM armes_jets_referentiel');rows=q.fetchall()
 check({tuple(r[:5])+(json.dumps(r[5],sort_keys=True),) for r in rows}=={tuple(r[k] for k in ['pays','ville','batiment','piece','arme'])+(json.dumps(r['data'],sort_keys=True),) for r in attendus},'armes lieux carrieres et personnalisation PSM conformes au client existant')
 def jet(v):q.execute(f'CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT {v}$$')
 def position(ville='capitale'):
  bat='chasse-peche-psm' if ville=='ville_a' else 'armurerie';piece='boutique' if ville=='ville_a' else 'magasin'
  q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET hp=100,pa=50,country='republic',current_city=%s,current_building=%s,current_room=%s,career='criminal_c',liquide=10000,arg=20000 WHERE name='Fixture';UPDATE comptes_bancaires SET solde=10000 WHERE personnage='Fixture';UPDATE indices_villes SET data=data||'{\"isn\":45}' WHERE id='republic_capitale'",(ville,bat,piece))
  e={'type':'armurerie','country':'republic','city':ville,'buildingId':bat,'roomId':None,'stockProduits':{'couteau':10,'revolver':10},'parametres':{'prixVente':{'couteau':250,'revolver':800}},'caisse':999,'historique':[],'proprietaire':'Autre'}
  q.execute("INSERT INTO entreprises(id,data) VALUES('armurerie-fixture',%s) ON CONFLICT(id) DO UPDATE SET data=excluded.data",(Json(e),))
 def bonus():
  q.execute("UPDATE personnages_donnees SET current_city='capitale',current_building='tabernacle-impots',current_room='nef_principale' WHERE name='Fixture'");jet(1);r=lire('SELECT religion_benediction_demander(%s,%s)',('Père Ception',str(uuid.uuid4())));assert r['ok'] and r['succes'];position()
 def appel(k,arme='couteau',cur=q):return lire('SELECT arme_clandestine_commande(%s,%s,%s)',('armurerie-fixture',arme,f'e0000000-0000-4000-8000-{k:012d}'),cur)
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(b ORDER BY id) FROM comptes_bancaires b),(SELECT jsonb_agg(e ORDER BY id) FROM entreprises e),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM armes_clandestines_recus r),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c),(SELECT count(*) FROM objets_recus),(SELECT count(*) FROM inventaire_livraisons_recues),(SELECT count(*) FROM actions_tracables),(SELECT count(*) FROM courrier_fixture))")
 position();bonus();jet(55);r=appel(1)
 check(r['ok'] and r['succes'] and r['taux']==55 and r['bonus']==5,'formule carriere indice et bonus conservee au seuil exact')
 check(r['prix']==750 and r['pa']==49 and r['liquide']==9250,'triple prix et un seul PA par le payeur commercial commun')
 check(lire("SELECT data->>'caisse' FROM entreprises WHERE id='armurerie-fixture'")=='999','aucun credit au proprietaire de la vente clandestine')
 check(lire("SELECT data->'stockProduits'->>'couteau' FROM entreprises WHERE id='armurerie-fixture'")=='9','stock reel diminue une seule fois')
 check(r['objet']['legal'] is False and r['objet']['name']=='Couteau de poche' and any(x.get('id')==r['objet']['id'] for x in r['inventaire']['inventory']),'objet reel non enregistre recu par le moteur versionne')
 avant=photo();check(appel(1)['rejeu'] and photo()==avant,'perte de reponse aucun second debit stock objet trace ou bonus')
 check(appel(1,'revolver')['raison']=='requete_reutilisee' and photo()==avant,'nonce ne change pas d arme')
 position();bonus();jet(100);avant=lire("SELECT inventory FROM personnages_donnees WHERE name='Fixture'");r=appel(2)
 check(r['ok'] and not r['succes'] and r['prix']==0 and r['paPreleves']==0 and r['pa']==50 and r['liquide']==10000,'echec de jet ne debite ni PA ni argent ni stock')
 check(lire("SELECT inventory FROM personnages_donnees WHERE name='Fixture'")==avant and lire("SELECT data->'stockProduits'->>'couteau' FROM entreprises WHERE id='armurerie-fixture'")=='10','echec sans arme fictive ni retrait stock')
 check(any(c.get('id')==r['convocation']['id'] for c in r['convocations']) and any(c.get('id')==r['convocation']['id'] for c in r['recherche']),'denonciation et convocation reellement enregistrees')
 check(lire("SELECT extract(epoch FROM (c->>'limiteTs')::timestamptz-r.traitee_at) BETWEEN 86399 AND 86401 FROM armes_clandestines_recus r CROSS JOIN LATERAL (SELECT r.resultat->'convocation' c) a WHERE r.requete=%s",('e0000000-0000-4000-8000-000000000002',)),'convocation vingt quatre heures reelles et non jour personnel')
 avant=photo();check(appel(2)['rejeu'] and photo()==avant,'rejeu de refus ne dedouble pas les consequences judiciaires')
 position('ville_a');jet(1);r=appel(3);check(r['ok'] and r['objet']['name']=='Couteau de plongée' and r['objet']['imageUrl'].endswith('couteau-plongee.webp'),'personnalisation PSM preservee sans changer id bonus ou prix')
 position();q.execute("UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name='Fixture';UPDATE comptes_bancaires SET solde=0 WHERE personnage='Fixture'");avant=photo();check(appel(4)['raison']=='fonds_insuffisants' and photo()==avant,'fonds insuffisants avant consommation du bonus')
 position();q.execute("UPDATE personnages_donnees SET current_room='rue' WHERE name='Fixture'");avant=photo();check(not appel(4)['ok'] and photo()==avant,'autre piece refusee avant toute consequence')
 position();bonus();jet(1);q.execute("CREATE FUNCTION panne_arme_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_arme_fixture';END$$;CREATE TRIGGER panne_arme_fixture BEFORE INSERT ON armes_clandestines_recus FOR EACH ROW EXECUTE FUNCTION panne_arme_fixture()");avant=photo()
 try:appel(4);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_arme_fixture' in str(ex) and photo()==avant,'panne finale annule PA argent stock objet trace et bonus')
 q.execute('DROP TRIGGER panne_arme_fixture ON armes_clandestines_recus')
 def concurrent(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(4,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,[0,1]))
 check(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'deux achats simultanes meme demande une vente un objet')
 position();bonus();jet(1);q.execute("UPDATE entreprises SET data=jsonb_set(data,'{stockProduits,couteau}','1') WHERE id='armurerie-fixture'")
 def distinct(k):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(k,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(distinct,[6,7]))
 check(sum(bool(r.get('ok')) for r in rs)==1 and any(r.get('raison')=='stock_insuffisant' for r in rs),'deux demandes distinctes ne peuvent acheter le dernier exemplaire')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==49 and lire("SELECT liquide FROM personnages_donnees WHERE name='Fixture'")==9250,'dernier exemplaire un paiement aucune depense de la demande refusee')
 position();bonus();jet(1)
 q.execute("CREATE FUNCTION ignorer_arme_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN NULL;END$$")
 for table,evenement,condition in [
  ('personnages_donnees','UPDATE',"NEW.name='Fixture' AND NEW.pa<OLD.pa"),
  ('entreprises','UPDATE',"NEW.id='armurerie-fixture'"),
  ('personnages_donnees','UPDATE',"NEW.name='Fixture' AND NEW.inventory IS DISTINCT FROM OLD.inventory"),
  ('actions_tracables','INSERT',"NEW.type_action='achat_arme_illegal'"),
  ('armes_clandestines_recus','INSERT','true')]:
  q.execute(f'CREATE TRIGGER ignorer_arme_fixture BEFORE {evenement} ON {table} FOR EACH ROW WHEN ({condition}) EXECUTE FUNCTION ignorer_arme_fixture()');avant=photo()
  try:appel(5);raise AssertionError('ecriture ignoree acceptee')
  except psycopg2.Error:check(photo()==avant,'ecriture ignoree rollback complet '+table+' '+condition)
  q.execute(f'DROP TRIGGER ignorer_arme_fixture ON {table}')
 jet(100);q.execute("CREATE TRIGGER ignorer_arme_fixture BEFORE UPDATE ON personnages_donnees FOR EACH ROW WHEN (NEW.name='Fixture' AND NEW.convocations IS DISTINCT FROM OLD.convocations) EXECUTE FUNCTION ignorer_arme_fixture()");avant=photo()
 try:appel(5);raise AssertionError('convocation ignoree acceptee')
 except psycopg2.Error:check(photo()==avant,'convocation ignoree annule denonciation et bonus')
 q.execute('DROP TRIGGER ignorer_arme_fixture ON personnages_donnees')
 jet('NULL::integer');avant=photo()
 try:appel(5);raise AssertionError('jet NULL accepte')
 except psycopg2.Error as ex:check('jet_invalide' in str(ex) and photo()==avant,'jet absent refuse sans effet')
 check(lire("SELECT has_function_privilege('authenticated','arme_clandestine_commande(text,text,uuid)','EXECUTE')") is False,'hote encore prive avant activation globale')
 print(json.dumps({'arme_clandestine':True,'assertions':n,'client_raccorde':False,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.base.banque.m.main(tout)
