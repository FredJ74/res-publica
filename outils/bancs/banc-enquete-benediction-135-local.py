#!/usr/bin/env python3
"""Enquête transactionnelle : vraies caisses/instruction/détention/transmission.
Contexte d'identité de fixture, contre-espionnage réel, aucun accès distant.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import importlib.util,re,json,uuid,sys
R=Path(__file__).resolve().parents[2]
MUTANT=next((x.split('=',1)[1] for x in sys.argv if x.startswith('--mutant=')),None)
sys.argv[:]=[x for x in sys.argv if not x.startswith('--mutant=')]
spec=importlib.util.spec_from_file_location('filature',R/'outils/bancs/banc-filature-benediction-135-local.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
MIGRATIONS=['migrations/20261024185228_enquete_confirmation_detention_transactionnelle.sql','migrations/20261025001934_enquete_instruction_trace_commune.sql','migrations/20261025002313_enquete_commande_transactionnelle.sql']
def suite(db,q,srv):
 import psycopg2
 n=0
 def check(v,msg):
  nonlocal n
  assert v,msg;n+=1;print('OK enquete hote',msg,flush=True)
 def lire(sql,args=(),cur=q):cur.execute(sql,args or None);return cur.fetchone()[0]
 def fn(path,nom):
  s=(R/path).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
 def table(domaine,nom,pk=None):
  s=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text();q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',s,re.S)[0])
  if pk:q.execute(f'ALTER TABLE {nom} ADD PRIMARY KEY({pk})')
 q.execute('ALTER TABLE personnages_donnees ADD COLUMN est_emprisonne jsonb,ADD COLUMN detention_qhs jsonb')
 for d,t,pk in [('justice','actions_tracables','id'),('justice','plaintes_en_cours','id'),('justice','dossiers_judiciaires_actes','id'),('justice','dossiers_judiciaires_actes_types','type'),('justice','prisonniers_qhs','id'),('divers-et-technique','administrateurs','user_id'),('renseignement','agents_renseignement','id'),('renseignement','cellules_renseignement','id'),('renseignement','renseignements_connus','id'),('divers-et-technique','evenements_globaux','id')]:table(d,t,pk)
 q.execute((R/'baseline/seeds/90_socle/dossiers_judiciaires_actes_types.sql').read_text())
 for f,nom in [('baseline/domaines/assemblee/20_fonctions-1.sql','assemblee_stat_base'),('baseline/domaines/socle/20_fonctions.sql','is_national')]:q.execute(fn(f,nom))
 for nom in ['agent_position_effective','contre_espionnage_modificateur','contre_espionnage_niveau_connu','contre_espionnage_memoriser','contre_espionnage_palier','contre_espionnage_resoudre']:q.execute(fn('baseline/domaines/renseignement/20_fonctions.sql',nom))
 for f,nom in [('baseline/domaines/socle/20_fonctions.sql','est_administrateur'),('baseline/domaines/socle/20_fonctions.sql','incarnation_courante'),('baseline/domaines/justice/20_fonctions-1.sql','juge_moi'),('baseline/domaines/justice/20_fonctions-1.sql','affaire_autorite_de'),('baseline/domaines/justice/20_fonctions-1.sql','dossier_acte_consigner'),('baseline/domaines/justice/20_fonctions-1.sql','affaire_transmettre'),('baseline/domaines/justice/20_fonctions-1.sql','detention_ouvrir_interne'),('baseline/domaines/justice/20_fonctions-1.sql','detention_clore_interne'),('baseline/domaines/justice/20_fonctions-1.sql','commissaire_enqueter'),('baseline/domaines/justice/20_fonctions-2.sql','plainte_instruire_interne')]:q.execute(fn(f,nom))
 q.execute('REVOKE ALL ON FUNCTION plainte_instruire_interne(text,text,text,text,text) FROM PUBLIC,anon,authenticated;GRANT EXECUTE ON FUNCTION plainte_instruire_interne(text,text,text,text,text) TO service_role')
 acl=lire("SELECT proacl::text FROM pg_proc WHERE oid='plainte_instruire_interne(text,text,text,text,text)'::regprocedure")
 for migration in MIGRATIONS:q.execute((R/migration).read_text());q.execute((R/migration).read_text())
 check(lire("SELECT proacl::text FROM pg_proc WHERE oid='plainte_instruire_interne(text,text,text,text,text)'::regprocedure")==acl,'delegation commune conserve les droits de l ancienne signature')
 if MUTANT:
  nom,avant,apres={
   'jet_sans_candidat':('police_enquete_commande(text,uuid)','IF trace.id IS NOT NULL THEN','IF true THEN'),
   'cible_reutilisee':('police_enquete_commande(text,uuid)','IF ancien.cible IS DISTINCT FROM v_cible THEN','IF false THEN'),
   'trace_substituee':('plainte_instruire_trace_interne(text,text,text,text,text,text)','(p_trace IS NULL OR a.id=p_trace)','true')
  }[MUTANT]
  d=lire('SELECT pg_get_functiondef(%s::regprocedure)',('public.'+nom,));assert d.count(avant)==1;q.execute(d.replace(avant,apres))
 def position():q.execute("SET hg.acteur='Fixture';SET hg.serveur='off';UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='commissariat',current_room='bureau_commissaire',hp=100,pa=50,stats='{\"PER\":13}',stats_affaiblies='{}',inf=0,hospitalisation=NULL,poste='{\"id\":\"commissaire\",\"city\":\"capitale\"}' WHERE name='Fixture';UPDATE personnages_donnees SET stats='{\"PER\":8}',inf=0 WHERE name='Autre';UPDATE indices_villes SET data=data||'{\"isn\":45}' WHERE id='republic_capitale';UPDATE caisses_batiments SET data='{\"solde\":10000}' WHERE id='republic_commissariat_capitale'")
 def jet(v):q.execute(f'CREATE OR REPLACE FUNCTION terrain_negociation_jet_interne() RETURNS integer LANGUAGE sql AS $$SELECT {v}$$')
 def bonus():
  q.execute("UPDATE personnages_donnees SET current_building='tabernacle-impots',current_room='nef_principale' WHERE name='Fixture'");jet(1)
  r=lire('SELECT religion_benediction_demander(%s,%s)',('Père Ception',str(uuid.uuid4())));assert r['ok'] and r['succes'],r
  q.execute("UPDATE personnages_donnees SET current_building='commissariat',current_room='bureau_commissaire' WHERE name='Fixture'")
 def appel(k,cible='Autre',cur=q):return lire('SELECT police_enquete_commande(%s,%s)',(cible,f'c0000000-0000-4000-8000-{k:012d}'),cur)
 def trace(id='trace-valide',date="now()-interval '1 hour'",jour=1,fin=16):q.execute(f"INSERT INTO actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration,created_at) VALUES(%s,'Autre','Victime fixture','vol','republic','capitale',%s,%s,{date})",(id,jour,fin))
 def photo():return lire("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c),(SELECT jsonb_agg(m ORDER BY id) FROM caisses_mouvements_clients m),(SELECT jsonb_agg(a ORDER BY id) FROM actions_tracables a),(SELECT jsonb_agg(d ORDER BY id) FROM detentions d),(SELECT jsonb_agg(a ORDER BY id) FROM plaintes_en_cours a),(SELECT jsonb_agg(a ORDER BY id) FROM dossiers_judiciaires_actes a),(SELECT jsonb_agg(r ORDER BY acteur,requete) FROM police_enquetes_recus r),(SELECT jsonb_agg(b ORDER BY acteur) FROM religion_benedictions b),(SELECT jsonb_agg(c ORDER BY acteur,acte) FROM religion_benedictions_consommations c),(SELECT count(*) FROM courrier_fixture),(SELECT count(*) FROM acquisitions_transactions_internes),(SELECT jsonb_agg(k ORDER BY id) FROM renseignements_connus k),(SELECT jsonb_agg(e ORDER BY id) FROM evenements_globaux e))")
 position();q.execute('DELETE FROM postes_attribues');avant=photo();check(appel(99)['raison']=='commissaire_hors_juridiction' and photo()==avant,'badge seul sans registre ne confere aucun pouvoir')
 q.execute("INSERT INTO postes_attribues(id,country,poste_id,city,titulaire,source) VALUES('fixture-commissaire','republic','commissaire','capitale','Fixture','fixture')")
 for sql,raison in [("UPDATE personnages_donnees SET current_city='ville_a' WHERE name='Fixture'",'commissaire_hors_juridiction'),("UPDATE personnages_donnees SET current_room='accueil' WHERE name='Fixture'",'pas_sur_place'),("UPDATE personnages_donnees SET hp=0 WHERE name='Fixture'",'acteur_indisponible'),("UPDATE personnages_donnees SET pa=1 WHERE name='Fixture'",'pa_insuffisants'),("UPDATE caisses_batiments SET data='{\"solde\":100}' WHERE id='republic_commissariat_capitale'",'caisse_insuffisante')]:
  position();q.execute(sql);avant=photo();check(appel(99)['raison']==raison and photo()==avant,'autorite et refus sans effet '+raison)
 position();bonus();jet('NULL::integer');r=appel(1)
 check(r['ok'] and r['decision']=='aucun_element' and r['jet'] is None and r['bonus']==0,'aucun candidat aucun jet ni bonus consomme')
 check(lire('SELECT religion_benediction_lire()')['benediction']['actif'],'absence de trace preserve la benediction')
 check(r['pa']==47 and r['solde_caisse']==9750,'enquete sans element conserve cout existant deux PA et 250 FR')
 avant=photo();check(appel(1)['rejeu'] and photo()==avant,'reponse perdue sans nouvel examen cout ou jet')
 position();trace('trace-date-inconnue','NULL');avant=photo();check(appel(2)['raison']=='datation_traces_indeterminee' and photo()==avant,'date inconnue refuse avant cout au lieu de pretendre rien trouver')
 # La trace valide est liée à l'instruction ; une ancienne trace au jour personnel élevé ne la remplace pas.
 trace();trace('trace-expiree',"now()-interval '30 days'",99999,100014);jet(50);r=appel(2)
 check(r['ok'] and r['succes'] and r['taux']==50 and r['bonus']==5,'formule et bonus conserves au seuil exact')
 check(r['trace']['id']=='trace-valide' and r['instruction']['decision']=='enquete_ouverte','instruction du fait choisi sans prendre une vieille trace personnelle')
 check(lire("SELECT decouvert FROM actions_tracables WHERE id='trace-valide'") and not lire("SELECT decouvert FROM actions_tracables WHERE id='trace-expiree'"),'seule la trace instruite est decouverte')
 check(lire("SELECT count(*) FROM detentions WHERE nom='Autre' AND mode_fin IS NULL AND jour_fin_effective IS NULL")==1,'garde a vue vraiment ouverte')
 check(r['affaire']['ok'] and lire('SELECT count(*) FROM dossiers_judiciaires_actes')==1,'transmission et chronologie judiciaires communes reellement creees')
 check(lire('SELECT count(*) FROM evenements_globaux WHERE id=%s',(r['evenementPublic'],))==1,'annonce publique persistante liee a la vraie arrestation')
 avant=photo();check(appel(2)['rejeu'] and photo()==avant,'rejeu aucun second debit detention dossier notification')
 check(appel(2,'Fausse cible')['raison']=='requete_reutilisee' and photo()==avant,'meme requete ne change pas de cible')
 # Réinitialisation du décor fictif par le vrai moteur de clôture, sans supprimer son historique.
 lire("SELECT detention_clore_interne('Autre','fixture_fin')");q.execute("UPDATE actions_tracables SET decouvert=true WHERE id='trace-date-inconnue'")
 position();trace('trace-suivante');bonus();jet(100);r=appel(3)
 check(r['ok'] and not r['succes'] and r['decision']=='indices_insuffisants','jet echoue cout du et bonus consomme sans detention fictive')
 check(not lire('SELECT religion_benediction_lire()')['benediction']['actif'],'bonus consomme une fois sur le vrai echec')
 for table,corps,erreur in [('personnages_donnees','NEW.pa:=OLD.pa;RETURN NEW;','paiement_enquete_non_confirme'),('caisses_batiments','NEW.data:=OLD.data;RETURN NEW;','caisse_enquete_non_confirmee'),('actions_tracables','NEW.decouvert:=OLD.decouvert;RETURN NEW;','trace_instruction_non_confirmee'),('personnages_donnees','NEW.est_emprisonne:=OLD.est_emprisonne;RETURN NEW;','instruction_detention_non_confirmee'),('plaintes_en_cours','RETURN NULL;','transmission_enquete_non_confirmee'),('dossiers_judiciaires_actes','RETURN NULL;','transmission_enquete_non_confirmee'),('evenements_globaux','RETURN NULL;','evenement_enquete_non_confirme')]:
  position();bonus();jet(1);operation='INSERT' if table in ('plaintes_en_cours','dossiers_judiciaires_actes','evenements_globaux') else 'UPDATE'
  q.execute('CREATE OR REPLACE FUNCTION defaut_enquete_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN '+corps+'END$$;CREATE TRIGGER defaut_enquete_fixture BEFORE '+operation+' ON '+table+' FOR EACH ROW EXECUTE FUNCTION defaut_enquete_fixture()');avant=photo()
  try:appel(4);raise AssertionError('ecriture ignoree attendue '+erreur)
  except psycopg2.Error as ex:check(erreur in str(ex) and photo()==avant,'ecriture ignoree rollback complet '+erreur)
  q.execute('DROP TRIGGER defaut_enquete_fixture ON '+table)
 position();bonus();jet(1);q.execute("CREATE FUNCTION panne_enquete_fixture() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_enquete_fixture';END$$;CREATE TRIGGER panne_enquete_fixture BEFORE INSERT ON police_enquetes_recus FOR EACH ROW EXECUTE FUNCTION panne_enquete_fixture()")
 avant=photo()
 try:appel(4);raise AssertionError('panne attendue')
 except psycopg2.Error as ex:check('panne_enquete_fixture' in str(ex) and photo()==avant,'panne finale annule cout bonus trace detention affaire et courrier')
 q.execute('DROP TRIGGER panne_enquete_fixture ON police_enquetes_recus')
 def concurrent(_):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(4,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(concurrent,[0,1]))
 check(all(r['ok'] for r in rr) and sum(bool(r.get('rejeu')) for r in rr)==1,'deux requetes concurrentes une seule instruction payee')
 position();jet(1);q.execute("UPDATE personnages_donnees SET stats='{\"PER\":16}' WHERE name='Fixture';UPDATE indices_villes SET data=data||'{\"isn\":100}' WHERE id='republic_capitale';INSERT INTO indices_villes(id,data) VALUES('republic_ville_a','{\"isn\":100}'),('republic_ville_b','{\"isn\":100}');INSERT INTO cellules_renseignement(id,pays_proprietaire,pays_cible,ministre,cout_fr,caisse,echeance_le) VALUES('cellule-enquete-fixture','soviet','republic','Fixture ministre',0,'fixture',now()+interval '1 day');INSERT INTO agents_renseignement(id,cellule_id,role,vrai_nom,dup,pays_couverture,nom_couverture,pays,ville) VALUES('agent-enquete-fixture','cellule-enquete-fixture','informateur','Identite fixture',8,'republic','Couverture fixture','republic','capitale');INSERT INTO actions_tracables(id,auteur,type_action,country,city,jour,jour_expiration) VALUES('trace-agent-fixture','Couverture fixture','vol','republic','capitale',1,16)")
 detenus=lire('SELECT count(*) FROM detentions');r=appel(5,'Couverture fixture')
 check(r['ok'] and r['succes'] and r['decision']=='contre_espionnage' and r['affaire'] is None,'vraie branche contre espionnage conservee sans fausse garde a vue')
 check(lire('SELECT count(*) FROM detentions')==detenus and lire("SELECT count(*) FROM renseignements_connus WHERE cible='Couverture fixture' AND titulaire='etat:republic'")>=1,'moteur commun cree la connaissance et non une detention de couverture')
 avant=photo();savoir=lire("SELECT count(*) FROM renseignements_connus WHERE cible='Couverture fixture'");check(appel(5,'Couverture fixture')['rejeu'] and photo()==avant and lire("SELECT count(*) FROM renseignements_connus WHERE cible='Couverture fixture'")==savoir,'rejeu ne relance ni contre espionnage ni paiement')
 position();lire("SELECT detention_clore_interne('Autre','fixture_fin')");trace('trace-pour-deux');bonus();jet(1)
 def distinct(k):
  with psycopg2.connect(srv.get_uri()) as cc:
   cur=cc.cursor();cur.execute("SET hg.acteur='Fixture';SET hg.serveur='off'");return appel(k,cur=cur)
 with ThreadPoolExecutor(max_workers=2) as pool:rr=list(pool.map(distinct,[7,8]))
 check(sorted(r['decision'] for r in rr)==['aucun_element','enquete_ouverte'] and sorted(r['bonus'] for r in rr)==[0,5],'deux ordres distincts une trace instruite un bonus seulement')
 check(lire("SELECT pa FROM personnages_donnees WHERE name='Fixture'")==45 and lire("SELECT (data->>'solde')::numeric FROM caisses_batiments WHERE id='republic_commissariat_capitale'")==9500,'deux ordres legitimes paient chacun le cout sans doubler les consequences')
 q.execute("INSERT INTO personnages_donnees(name,country,current_city,stats,hp,pa,day) VALUES('Compat fixture','republic','capitale','{}',100,50,1);INSERT INTO actions_tracables(id,auteur,type_action,country,city,jour,jour_expiration) VALUES('trace-compat-fixture','Compat fixture','vol','republic','capitale',1,16)")
 avant=photo();r=lire("SELECT plainte_instruire_trace_interne('republic','capitale','Compat fixture','enquete','Fixture','trace-valide')")
 check(r['decision']=='classee' and photo()==avant,'reference de trace liee a auteur et territoire impossible a substituer')
 r=lire("SELECT commissaire_enqueter('Compat fixture')")
 check(r['ok'] and r['decision']=='enquete_ouverte' and r['detention']['ok'],'ancien appelant commissaire delegue au meme moteur et conserve son comportement')
 check(lire("SELECT has_function_privilege('authenticated','police_enquete_commande(text,uuid)','EXECUTE')") is False,'nouvel hote encore prive avant activation complete')
 definition=lire("SELECT pg_get_functiondef('plainte_instruire_interne(text,text,text,text,text)'::regprocedure)")
 q.execute("CREATE OR REPLACE FUNCTION plainte_instruire_interne(p_pays text,p_ville text,p_cible text,p_motif text,p_instructeur text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$")
 try:q.execute((R/MIGRATIONS[1]).read_text());raise AssertionError('garde attendue')
 except psycopg2.Error as ex:
  q.execute('ROLLBACK');check('definition_non_examinee' in str(ex),'migration refuse un moteur commun different du corps examine')
 q.execute(definition);q.execute((R/MIGRATIONS[1]).read_text())
 print(json.dumps({'enquete_serveur':True,'assertions':n,'contre_espionnage_simule':False,'client_raccorde':False,'production':False}))
def tout(db,q,srv):base.tout(db,q,srv);suite(db,q,srv)
if __name__=='__main__':base.base.banque.m.main(tout)
