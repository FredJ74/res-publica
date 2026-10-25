#!/usr/bin/env python3
"""Évasion : vraie clôture/prolongation, recherche visible et quota partagé ; privé."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,re,json,uuid,sys
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
spec=importlib.util.spec_from_file_location('chasse',R/'outils/bancs/banc-chasse-benediction-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
MIGRATIONS=['migrations/20261025103801_peines_et_inscription_communes.sql','migrations/20261025104001_evasion_commande_transactionnelle.sql']
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK evasion',msg,flush=True)
 def lire(s,args=(),cur=q):cur.execute(s,args or None);return cur.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 q.execute("ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS requisition jsonb,ADD COLUMN IF NOT EXISTS recherche jsonb DEFAULT '[]'")
 for path,nom in [('baseline/domaines/justice/20_fonctions-2.sql','justice_condamner'),('baseline/domaines/justice/20_fonctions-2.sql','recherche_inscrire'),('baseline/domaines/justice/20_fonctions-1.sql','detention_clore_evasion'),('baseline/domaines/justice/20_fonctions-1.sql','detention_prolonger_interne')]:q.execute(fn(path,nom))
 q.execute("ALTER TABLE personnages_donnees ADD COLUMN IF NOT EXISTS convocations jsonb DEFAULT '[]',ADD COLUMN IF NOT EXISTS historique_crimes jsonb DEFAULT '[]'")
 q.execute(fn('baseline/domaines/assemblee/20_fonctions-1.sql','assemblee_cle_convocation'));q.execute(fn('baseline/domaines/personnage-et-presence/20_fonctions.sql','personnages_preserver_judiciaire'))
 q.execute('CREATE TRIGGER judiciaire_evasion_fixture BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION personnages_preserver_judiciaire()')
 avant_court=lire("SELECT prosrc FROM pg_proc WHERE oid='justice_condamner(text,jsonb)'::regprocedure")
 acl=lire("SELECT proacl::text FROM pg_proc WHERE oid='justice_condamner(text,jsonb)'::regprocedure")
 for m in MIGRATIONS:q.execute((R/m).read_text());q.execute((R/m).read_text())
 if MUTANT:
  signature,avant,apres={
   'quota':('evasion_commande(uuid)',"IF p.est_emprisonne->>'dernierJourEvasion'=v_jour::text OR EXISTS(SELECT 1 FROM public.evasions_jours j WHERE j.acteur=p.id AND j.jour=v_jour) THEN",'IF false THEN'),
   'reliquat':('justice_peine_effective_interne(jsonb,integer)',"IF d->>'reliquat_jours' IS NOT NULL THEN",'IF false THEN'),
   'cloture':('detention_clore_interne(text,text,integer)',"SET mode_fin = p_mode, jour_fin_effective = coalesce(p_jour, v_jour)","SET mode_fin = mode_fin, jour_fin_effective = coalesce(p_jour, v_jour)")
  }[MUTANT]
  d=lire('SELECT pg_get_functiondef(%s::regprocedure)',(signature,));assert d.count(avant)==1;q.execute(d.replace(avant,apres))
 apres_court=lire("SELECT prosrc FROM pg_proc WHERE oid='justice_condamner(text,jsonb)'::regprocedure")
 check(avant_court.split('  SELECT coalesce(sum(')[0]==apres_court.split('  RETURN public.justice_condamnation_poser_interne')[0],'toutes les gardes publiques du juge et du proces conservees textuellement')
 check(lire("SELECT proacl::text FROM pg_proc WHERE oid='justice_condamner(text,jsonb)'::regprocedure")==acl,'aucun droit judiciaire nouveau')
 def jet(x):q.execute(f'CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT {x}$$')
 def position():q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='commissariat',current_room='prison',hp=100,pa=50,liquide=1000,arg=1000,day=50,stats='{\"DUP\":10}',requisition=NULL WHERE name='Fixture';UPDATE comptes_bancaires SET solde=0 WHERE personnage='Fixture';UPDATE indices_villes SET data=data||'{\"isn\":45}' WHERE id='republic_capitale'")
 def ouvrir():
  r=lire("SELECT detention_ouvrir_interne('Fixture','Peine fixture',7,'capitale','republic','[{\"type\":\"Peine fixture\",\"jours\":7}]','Fixture autorite','fixture')");assert r['ok'];return r['detention_id']
 def fermer():lire("SELECT detention_clore_interne('Fixture','fixture_fin')")
 def appel(k,cur=q):return lire('SELECT evasion_commande(%s)',(f'71000000-0000-4000-8000-{k:012d}',),cur)
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(b ORDER BY id) FROM comptes_bancaires b),(SELECT jsonb_agg(d ORDER BY id) FROM detentions d),(SELECT jsonb_agg(j ORDER BY id) FROM jugements j),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM evasions_recus r),(SELECT jsonb_agg(j ORDER BY acteur,jour) FROM evasions_jours j),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c))")
 position();fermer();avant=photo();check(appel(1).get('raison')=='detention_non_confirmee' and photo()==avant,'pas de detention aucun cout ou faux succes')
 d=ouvrir();q.execute("UPDATE personnages_donnees SET requisition='{\"statut\":\"deserteur\"}' WHERE name='Fixture'");avant=photo()
 check(appel(1).get('raison')=='historique_bonus_deserteur_a_verifier' and photo()==avant,'compteur historique absent ne devient jamais un faux zero')
 position();jet(10);q.execute("UPDATE personnages_donnees SET day=53 WHERE name='Fixture'");r=appel(1)
 check(r['ok'] and r['succes'] and r['taux']==10 and r['bonus']==0,'jet ordinaire reussi au seuil sans donner le bonus du deserteur')
 check(r['estEmprisonne'] is None and lire('SELECT mode_fin FROM detentions WHERE id=%s',(d,))=='evasion','cloture reelle de peine et projection alignee')
 check(lire('SELECT jour_fin-jour_debut FROM detentions WHERE id=%s',(d,))==7,'duree historique de peine non reecrite a la cloture')
 check(r['reliquat']==4 and lire('SELECT jours FROM justice_recherches(%s) WHERE id=%s',('Fixture',r['avis']['id']))==6,'avis executable et lisible six jours reliquat quatre plus evasion deux')
 check(lire('SELECT data->>\'detention_precedente_id\' FROM jugements WHERE id=%s',(r['avis']['id'],))==d,'lien a la detention interrompue conserve')
 avant=photo();check(appel(1)['rejeu'] and photo()==avant,'reponse perdue pas de seconde recherche cout ou cloture')
 position();ouvrir();avant=photo();check(appel(2).get('raison')=='tentative_quotidienne_deja_effectuee' and photo()==avant,'nouvelle detention meme jour pas de seconde tentative')
 # Avancer la date de la fixture du quota, jamais une horloge ou des personnages réels.
 q.execute("UPDATE evasions_jours SET jour=jour-1 WHERE acteur=(SELECT id FROM personnages_donnees WHERE name='Fixture')")
 jet(100);r=appel(2)
 check(r['ok'] and not r['succes'] and r['amende']==500 and r['liquide']==500 and r['pa']==47,'echec trois PA amende cinq cents et pas de fausse sortie')
 check(lire("SELECT jour_fin-jour_debut FROM detentions WHERE nom='Fixture' AND mode_fin IS NULL")==8 and r['estEmprisonne']['jours']==8,'prolongation par moteur commun dans registre et projection')
 avant=photo();check(appel(2)['rejeu'] and photo()==avant,'rejeu de peine aggravee sans seconde sanction')
 q.execute("UPDATE evasions_jours SET jour=jour-2 WHERE acteur=(SELECT id FROM personnages_donnees WHERE name='Fixture') AND jour=(now() AT TIME ZONE 'Europe/Paris')::date")
 position();jet(1);q.execute("CREATE FUNCTION panne_evasion_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_evasion_fixture';END$$;CREATE TRIGGER panne_evasion_fixture BEFORE INSERT ON evasions_recus FOR EACH ROW EXECUTE FUNCTION panne_evasion_fixture()");avant=photo()
 try:appel(3);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_evasion_fixture' in str(ex) and photo()==avant,'panne finale annule PA bonus cloture recherche jugement et quota')
 q.execute('DROP TRIGGER panne_evasion_fixture ON evasions_recus')
 def concurrent(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(3,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,[0,1]))
 check(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'deux commandes concurrentes une seule evasion acquise')
 # Les refus et écritures non appliquées ne doivent pas consommer un quota ni un bonus.
 position();ouvrir();q.execute("UPDATE evasions_jours SET jour=jour-5 WHERE acteur=(SELECT id FROM personnages_donnees WHERE name='Fixture') AND jour=(now() AT TIME ZONE 'Europe/Paris')::date");jet(1)
 q.execute("CREATE FUNCTION ignorer_evasion_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN NULL;END$$")
 for table,evenement,condition in [('personnages_donnees','UPDATE',"NEW.name='Fixture' AND NEW.pa<OLD.pa"),('detentions','UPDATE',"NEW.nom='Fixture' AND NEW.mode_fin='evasion'"),('jugements','INSERT',"NEW.juge='Évasion constatée'"),('evasions_recus','INSERT','true')]:
  q.execute(f'CREATE TRIGGER ignorer_evasion_fixture BEFORE {evenement} ON {table} FOR EACH ROW WHEN ({condition}) EXECUTE FUNCTION ignorer_evasion_fixture()');avant=photo()
  try:appel(4);raise AssertionError('ecriture ignoree acceptee')
  except psycopg2.Error:check(photo()==avant,'ecriture ignoree rollback complet '+table+' '+condition)
  q.execute(f'DROP TRIGGER ignorer_evasion_fixture ON {table}')
 jet('NULL::integer');avant=photo()
 try:appel(4);raise AssertionError('jet nul accepte')
 except psycopg2.Error as ex:check('jet_invalide' in str(ex) and photo()==avant,'tirage absent annule paiement consommation et quota')
 jet(1);q.execute("UPDATE personnages_donnees SET est_emprisonne=est_emprisonne||jsonb_build_object('dernierJourEvasion',(now() AT TIME ZONE 'Europe/Paris')::date::text) WHERE name='Fixture'");avant=photo()
 check(appel(4)['raison']=='tentative_quotidienne_deja_effectuee' and photo()==avant,'quota historique deja utilise conserve lors du raccordement')
 check(lire("SELECT has_function_privilege('authenticated','evasion_commande(uuid)','EXECUTE')") is False,'commande privee non activable tant que compteur deserteur et prevol manquent')
 print(json.dumps({'evasion_ordinaire':True,'assertions':n,'deserteur_bloque_sans_historique':True,'client_raccorde':False,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.base.base.banque.m.main(tout)
