#!/usr/bin/env python3
"""Progression et appels de fonds, vrais moteurs financiers/approvisionnement, base jetable."""
from pathlib import Path
import re,tempfile,json,sys
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
import runpy
_sources=runpy.run_path(str(R/'outils/bancs/banc-audit-securite-135-local.py'))
def fn(f,nom):
 return _sources['entree_historique'](nom) if f.startswith('baseline/') and nom in ('chantier_lancer','chantier_verser','chantier_travailler') else _sources['fonction'](f,nom)
def main(suite_supplementaire=None):
 import pgserver,psycopg2
 from psycopg2.extras import Json
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-construction-jour-'),cleanup_mode='delete');n=0
 try:
  with psycopg2.connect(server.get_uri()) as db:
   db.autocommit=True;c=db.cursor()
   c.execute("""CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
   CREATE TABLE personnages_donnees(name text PRIMARY KEY,country text,arg integer,liquide integer,updated_at timestamptz);
   CREATE TABLE comptes_bancaires(personnage text,banque text,solde numeric,updated_at timestamptz);
   CREATE TABLE organisations(id text PRIMARY KEY,data text);
   CREATE TABLE caisses_batiments(id text PRIMARY KEY,data jsonb,updated_at timestamptz);
   CREATE TABLE cycles_electoraux(country text,poste_id text,city text,data text);
   CREATE TABLE terrains_etat(id text PRIMARY KEY,country text,building_id text,proprietaire text,data text,updated_at timestamptz,niveau_construction text);
   CREATE TABLE batiments_etat(id text PRIMARY KEY,country text,city text,data jsonb,updated_at timestamptz);
   CREATE TABLE villes(pays text,ville text);INSERT INTO villes VALUES('republic','capitale');
   CREATE TABLE chantiers_besoins_jour(position_cycle integer,bois numeric,minerai numeric,metal numeric);
   CREATE TABLE entrepots_par_ville(ville text,building_id text);INSERT INTO entrepots_par_ville VALUES('capitale','entrepot');
   CREATE TABLE ressources_economie(cle text PRIMARY KEY,prix_base numeric);INSERT INTO ressources_economie VALUES('bois',5),('minerai',10),('metal',15);
   CREATE TABLE entreprises_constantes(cle text PRIMARY KEY,valeur numeric);INSERT INTO entreprises_constantes VALUES('chantier_taux_horaire',70);
   CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT current_setting('test.serveur',true)='on'$$;
   CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF NOT est_appel_serveur() AND $1 IS DISTINCT FROM public.mon_personnage() THEN RAISE EXCEPTION 'interdit_fixture';END IF;END$$;
   CREATE TABLE notifications(destinataire text,sujet text,corps text);
   CREATE FUNCTION mail_systeme_poser_interne(text,text,text,text,text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO notifications VALUES($2,$3,$4);RETURN '{"ok":true}';END$$;
   SET test.serveur='on';""")
   for f,nom in [('migrations/20261031113611_construction_lancement_priorite_bancaire.sql','helvetia_debiter_fonds_ordinaires'),('baseline/domaines/finances-publiques/20_fonctions-1.sql','caisse_institution_mouvement'),('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','batiment_etat_lire'),('baseline/domaines/economie/20_fonctions-1.sql','entrepot_caisse_id'),('baseline/domaines/economie/20_fonctions-1.sql','entrepot_caisse_mouvement'),('baseline/domaines/economie/20_fonctions-1.sql','approvisionner_chantier')]:c.execute(fn(f,nom))
   for f in ['chantiers_besoins_jour']:
    s=(R/f'baseline/seeds/90_socle/{f}.sql').read_text();c.execute(s)
   for f in [_sources['chemin_source'](f) for f in ['migrations/20261022123319_chantier_financeurs_et_appels.sql', 'migrations/20261022123320_chantier_jour_transactionnel.sql', 'migrations/20261022123321_chantier_approvisionnement_caisse_unique.sql']]:c.execute(f.read_text());c.execute(f.read_text())
   c.execute("INSERT INTO personnages_donnees VALUES('Alice','republic',60000,30000,now());INSERT INTO comptes_bancaires VALUES('Alice','nationale',30000,now());INSERT INTO caisses_batiments VALUES('republic_gouvernement-min_fin','{\"solde\":0}',now()),('republic_entrepot_capitale','{\"solde\":0}',now()),('republic_mairie_capitale','{\"solde\":60000}',now());INSERT INTO organisations VALUES('orga','{\"chef\":\"Chef\",\"caisse\":60000}');INSERT INTO cycles_electoraux VALUES('republic','maire','capitale','{\"eluId\":\"Maire1\"}');INSERT INTO batiments_etat VALUES('republic_capitale_entrepot','republic','capitale','{\"entrepot\":{\"stock\":{\"bois\":10000,\"minerai\":10000,\"metal\":10000}}}',now())")
   c.execute("ALTER TABLE personnages_donnees ADD COLUMN id uuid DEFAULT gen_random_uuid(),ADD COLUMN pa integer DEFAULT 50,ADD COLUMN hp integer DEFAULT 100,ADD COLUMN hospitalisation jsonb,ADD COLUMN current_city text DEFAULT 'capitale',ADD COLUMN current_building text,ADD COLUMN day integer DEFAULT 1,ADD COLUMN poste jsonb")
   c.execute("CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT nullif(current_setting('test.acteur',true),'')$$;CREATE FUNCTION acteur_poste_courant() RETURNS TABLE(nom text,poste_id text,poste_city text,pays text) LANGUAGE sql AS $$SELECT name,poste->>'id',poste->>'city',country FROM personnages_donnees WHERE name=mon_personnage()$$")
   src=(R/'baseline/domaines/justice/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public.detentions \(.*?\n\);',src,re.S)[0])
   c.execute(fn('baseline/domaines/justice/20_fonctions-1.sql','detention_active'))
   c.execute(fn('migrations/20261031113558_organisations_equipements_collectifs.sql','organisation_equipement_exiger'))
   c.execute(fn('baseline/domaines/politique-et-elections/20_fonctions.sql','poste_est_atteste'))
   src=(R/'baseline/domaines/economie/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public.chantiers_paliers \(.*?\n\);',src,re.S)[0])
   c.execute((R/'baseline/seeds/90_socle/chantiers_paliers.sql').read_text())
   for migration in [_sources['chemin_source'](f) for f in ['migrations/20261022124055_chantier_autorite_et_recus.sql', 'migrations/20261022124056_chantier_commandes_et_reception.sql']]:c.execute(migration.read_text());c.execute(migration.read_text())
   c.execute(_sources['chemin_source']('migrations/20261031113617_chantier_recu_relecture.sql').read_text())
   for nom in ['chantier_lancer','chantier_verser']:c.execute(fn('baseline/domaines/economie/20_fonctions-1.sql',nom))
   c.execute(_sources['chemin_source']('migrations/20261031113618_chantier_fermer_commandes_non_versionnees.sql').read_text());c.execute(_sources['chemin_source']('migrations/20261031113618_chantier_fermer_commandes_non_versionnees.sql').read_text())
   for domaine,table in [('immobilier-et-territoire','dossiers_urbanisme'),('personnage-et-presence','objets_recus'),('immobilier-et-territoire','locations_actives')]:
    src=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public\.'+table+r' \(.*?\n\);',src,re.S)[0])
   c.execute(fn('baseline/domaines/socle/20_fonctions.sql','objet_sas_deposer'))
   for migration in [_sources['chemin_source'](f) for f in ['migrations/20261022125942_chantier_plan_initial.sql', 'migrations/20261022125943_chantier_plan_raccordement.sql']]:c.execute(migration.read_text());c.execute(migration.read_text())
   # Etat reel AVANT les migrations testees, independant du baseline vivant.
   for nom,fixture in [('terrain_permis_acte','terrain-permis-acte-avant-depot.sql'),('terrain_chantier_acte','terrain-chantier-acte-avant-commandes.sql')]:
    c.execute(fn('outils/bancs/banc-fixture-'+fixture,nom))
   c.execute(fn('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','terrain_etat_lire'))
   c.execute(fn('baseline/domaines/economie/20_fonctions-1.sql','chantier_travailler'))
   c.execute(fn('migrations/20261031113610_construction_materiaux_prix_et_dons.sql','chantier_prix_definir'))
   if '--permis112' in sys.argv:
    # Definition exacte du garde #112, sans embarquer sa migration ni ses paiements.
    definition=fn('outils/bancs/banc-fixture-terrain-permis-acte-avant-depot.sql','terrain_permis_acte')
    garde="  IF p_acte = 'permis_deposer' THEN\n    RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');\n  END IF;\n"
    c.execute(definition.replace('  v_moi := public.mon_personnage();',garde+'  v_moi := public.mon_personnage();'))
   for migration in [_sources['chemin_source'](f) for f in ['migrations/20261022130417_chantier_gardes_legacy_et_travail.sql', 'migrations/20261022130418_chantier_travail_versionne.sql', 'migrations/20261022130419_chantier_prix_representants.sql']]:c.execute(migration.read_text());c.execute(migration.read_text())
   c.execute(_sources['chemin_source']('migrations/20261031113624_construction_delais_quatre_empires.sql').read_text());c.execute(_sources['chemin_source']('migrations/20261031113624_construction_delais_quatre_empires.sql').read_text())
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t,flush=True)
   def q(sql,args=()):c.execute(sql,args);return c.fetchone()[0]
   def creer(id,owner='Alice',progress=0,verse=10500,tre=10500):
    ch={'type':'construction','niveau':'hangar','dureeJours':6,'coutTotal':30000,'coutTravail':21000,'progressionJours':progress,'totalVerse':verse,'tresorerie':tre,'heuresFaites':0,'stockMateriaux':{},'evenements':[]}
    etat={'city':'capitale','proprietaire':owner,'surface':741,'prixAchat':23000,'chantier':ch}
    c.execute('INSERT INTO terrains_etat(id,country,building_id,proprietaire,data,updated_at) VALUES(%s,\'republic\',%s,%s,%s,now())',(id,id,owner,json.dumps(etat)));return etat
   def traiter(id,cur=c):cur.execute('SELECT chantier_jour_traiter(%s)',(id,));return cur.fetchone()[0]
   def prochain(id):c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,jourTraite}','null')::text WHERE id=%s",(id,))
   def photo():return q("SELECT jsonb_build_array((SELECT jsonb_agg(t ORDER BY id) FROM terrains_etat t),(SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c),(SELECT jsonb_agg(c) FROM comptes_bancaires c),(SELECT jsonb_agg(b) FROM batiments_etat b),(SELECT jsonb_agg(n) FROM notifications n),(SELECT jsonb_agg(o) FROM organisations o),(SELECT jsonb_agg(r ORDER BY requete) FROM chantier_commandes_recus r),(SELECT jsonb_agg(x ORDER BY id) FROM dossiers_urbanisme x),(SELECT jsonb_agg(x ORDER BY id) FROM objets_recus x))")
   creer('normal');r=traiter('normal');ch=r['etat']['chantier'];ok(ch['progressionJours']==1 and ch['tresorerie']==5505,'journee reelle, matieres et PNJ payes')
   ok(q("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_entrepot_capitale'")=='1495','recette entrepot dans seule caisse canonique')
   ok(q("SELECT batiment_etat_lire(data)->'entrepot' ? 'caisse' FROM batiments_etat")==False,'aucune caisse parasite dans le blob')
   avant=photo();ok(traiter('normal')['rejeu'] and photo()==avant,'reponse perdue : meme jour aucun double achat travail debit mail')
   prochain('normal');r=traiter('normal');ch=r['etat']['chantier'];ok(ch['progressionJours']==2 and ch['totalVerse']==21000,'premier tiers : appel automatique 35 pour cent')
   ok(q("SELECT solde FROM comptes_bancaires WHERE personnage='Alice'")==19500,'appel banque prioritaire, liquide preserve')
   ok(q("SELECT liquide FROM personnages_donnees WHERE name='Alice'")==30000,'liquide inchange quand banque suffit')
   for jour in range(3,7):prochain('normal');r=traiter('normal')
   ok(r['etat']['chantier']['progressionJours']==6 and r['etat']['chantier']['totalVerse']==30000,'deux tiers : 30 pour cent puis 6 jours incompressibles')
   ok(r['attenteReception'] and not r['etat'].get('niveau_construction') and not r['etat'].get('subdivisions'),'achevement sans livraison ni locaux avant reception')
   ok(q("SELECT count(*) FROM notifications WHERE sujet='Chantier acheve — reception sur place'")==1,'invitation reception unique')
   avant=photo();prochain('normal');traiter('normal');ok(q("SELECT count(*) FROM notifications WHERE sujet='Chantier acheve — reception sur place'")==1,'lendemain acheve : aucun nouvel achat salaire ni invitation')
   creer('pauvre',progress=2,tre=0);c.execute("UPDATE personnages_donnees SET liquide=2,arg=3;UPDATE comptes_bancaires SET solde=1")
   r=traiter('pauvre');ok(r['etat']['chantier']['arrete']=='financement' and r['etat']['chantier']['progressionJours']==2,'fonds insuffisants : pause sans progression')
   ok(q('SELECT liquide FROM personnages_donnees')==2 and q('SELECT solde FROM comptes_bancaires')==1,'aucun debit partiel en refus')
   nb=q("SELECT count(*) FROM notifications WHERE sujet='Chantier en pause — financement'");prochain('pauvre');traiter('pauvre');ok(q("SELECT count(*) FROM notifications WHERE sujet='Chantier en pause — financement'")==nb,'manque persistant : pas de mail duplique')
   c.execute('UPDATE comptes_bancaires SET solde=10500');prochain('pauvre');r=traiter('pauvre');ok(r['etat']['chantier']['progressionJours']==3 and r['etat']['chantier']['totalVerse']==21000,'fonds arrives : reprise automatique, temps utile conserve')
   # Meme moteur et memes seuils pour les deux personnes morales, pas de branche de progression municipale.
   for id,owner in [('organisation','orga:orga'),('commune','ville:republic:capitale')]:
    creer(id,owner,progress=2,tre=0);r=traiter(id);ok(r['etat']['chantier']['progressionJours']==3 and r['etat']['proprietaire']==owner,'financeur et propriete stables '+owner)
   ok(q("SELECT data::jsonb->>'caisse' FROM organisations")=='49500','caisse organisation reelle debitee')
   ok(q("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_mairie_capitale'")=='49500','caisse municipale reelle debitee')
   c.execute("UPDATE cycles_electoraux SET data='{\"eluId\":\"Maire2\"}'");prochain('commune');r=traiter('commune');ok(r['etat']['chantier']['progressionJours']==4 and r['etat']['proprietaire']=='ville:republic:capitale','changement de maire : chantier autonome et communal')
   creer('concurrent',owner='orga:orga')
   def concurrent(_):
    with psycopg2.connect(server.get_uri()) as d:
     cc=d.cursor();cc.execute("SET test.serveur='on'");return traiter('concurrent',cc)
   with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,range(2)))
   ok(all(x['ok'] for x in rs) and sum(bool(x.get('rejeu')) for x in rs)==1,'deux cron concurrents : une seule journee')
   creer('rollback',owner='orga:orga',progress=2,tre=0)
   c.execute("CREATE FUNCTION panne() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.id='rollback' THEN RAISE EXCEPTION 'panne_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER panne BEFORE UPDATE ON terrains_etat FOR EACH ROW EXECUTE FUNCTION panne()")
   avant=photo()
   try:traiter('rollback');raise AssertionError('panne attendue')
   except psycopg2.Error as e:db.rollback();assert 'panne_fixture' in str(e)
   ok(photo()==avant,'panne finale : rollback fonds stocks caisses notifications et temps')
   c.execute("SET test.serveur='off'");avant=photo();ok(traiter('normal')['raison']=='reserve_au_serveur' and photo()==avant,'appel navigateur refuse sans mutation')
   c.execute("SELECT has_function_privilege('authenticated','chantier_jour_traiter(text)','EXECUTE'),has_function_privilege('service_role','chantier_jour_traiter(text)','EXECUTE'),has_function_privilege('service_role','chantier_financeur_debiter_interne(jsonb,numeric)','EXECUTE')")
   ok(c.fetchone()==(False,True,False),'droits : cron seul, primitives financieres privees')
   c.execute("SELECT has_function_privilege('authenticated','chantier_lancer(text,text,text,text,numeric)','EXECUTE'),has_function_privilege('authenticated','chantier_verser(text,text,text,numeric)','EXECUTE')");ok(c.fetchone()==(False,False),'anciennes commandes sans recu inaccessibles au navigateur')
   # Commandes du meme moteur : lancement, versement et reception, avec vrai recu.
   c.execute("SET test.acteur='Alice';UPDATE personnages_donnees SET liquide=100000,arg=100000,current_building='lancement';UPDATE comptes_bancaires SET solde=0")
   def terrain_vierge(id,owner='Alice',palier='hangar'):
    d={'proprietaire':owner,'city':'capitale','surface':1500,'prixAchat':3570,'constructionAutorisee':True,'permis':{'palierDemande':palier,'decoupageInitial':[]}}
    c.execute("INSERT INTO terrains_etat(id,country,building_id,proprietaire,data) VALUES(%s,'republic',%s,%s,%s)",(id,id,owner,json.dumps(d)))
   def commande(req,id,action,params={}):return q('SELECT chantier_commande(%s,%s,%s,%s)',(req,id,action,Json(params)))
   def refuse(fn,t):
    c.execute('COMMIT')
    avant=photo()
    try:
     r=fn();assert r.get('ok') is False,'refus attendu : '+t
    except psycopg2.Error:db.rollback()
    ok(photo()==avant,t)
   terrain_vierge('lancement');r=commande('ch-lancement-0001','lancement','lancer',{'palier':'hangar','apport':'10500'})
   ok(r['ok'] and r['chantier']['prixAchatPJ']=={'bois':6,'minerai':11,'metal':17},'lancement commun, prix miroir arrondis au franc superieur')
   avant=photo();ok(commande('ch-lancement-0001','lancement','lancer',{'palier':'hangar','apport':'10500'})['rejeu'] and photo()==avant,'lancement : reponse perdue sans second debit')
   refuse(lambda:commande('ch-lancement-0001','lancement','lancer',{'palier':'hangar','apport':'12000'}),'reutilisation du recu pour un autre montant refusee')
   refuse(lambda:commande('ch-reception-0001','lancement','receptionner'),'reception prematuree refusee sans mutation')
   commande('ch-complement-0001','lancement','verser',{'montant':'19500'})
   c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,progressionJours}','6')::text WHERE id='lancement';UPDATE personnages_donnees SET current_building='ailleurs'")
   refuse(lambda:commande('ch-reception-0002','lancement','receptionner'),'reception hors site refusee')
   c.execute("UPDATE personnages_donnees SET current_building='lancement'")
   r=commande('ch-reception-0003','lancement','receptionner');ok(r['ok'] and 'chantier' not in r['etat'] and r['etat']['niveau_construction']=='hangar','reception sur place active le batiment une seule fois')
   ok(q("SELECT data->>'solde' FROM caisses_batiments WHERE id='republic_capitale_lancement'")=='28505','reliquat financier a la caisse du batiment, jamais au PJ')
   ok(q("SELECT chantier_commande_recu('ch-reception-0003')")['terminee'],'rechargement : recu confirme consultable sans rejouer la commande')
   c.execute("SET test.acteur='Bob'");ok(not q("SELECT chantier_commande_recu('ch-reception-0003')")['terminee'],'autre acteur : aucun recu divulgue');c.execute("SET test.acteur='Alice'")
   avant=photo();ok(commande('ch-reception-0003','lancement','receptionner')['rejeu'] and photo()==avant,'reception reponse perdue : aucun second reliquat')
   ok(r['etat']['stockMateriaux']=={'bois':100,'minerai':50,'metal':33},'reliquat materiaux au stock du batiment sans passage par inventaire PJ')
   ok(r['etat']['surface']==1500 and r['etat']['prixAchat']==3570,'surface et prix propres preserves')
   terrain_vierge('municipal','ville:republic:capitale');c.execute("UPDATE personnages_donnees SET poste='{\"id\":\"maire_adjoint\",\"city\":\"capitale\"}',current_building='municipal'")
   refuse(lambda:commande('ch-commune-0001','municipal','lancer',{'palier':'hangar','apport':'10500'}),'adjoint ne peut engager une construction communale')
   c.execute("UPDATE personnages_donnees SET poste='{\"id\":\"maire\",\"city\":\"capitale\"}';UPDATE cycles_electoraux SET data='{\"eluId\":\"Maire2\"}'")
   refuse(lambda:commande('ch-commune-0001','municipal','lancer',{'palier':'hangar','apport':'10500'}),'faux poste maire sans mandat atteste refuse')
   c.execute("UPDATE cycles_electoraux SET data='{\"eluId\":\"Alice\"}'")
   argent=q('SELECT liquide FROM personnages_donnees');r=commande('ch-commune-0001','municipal','lancer',{'palier':'hangar','apport':'10500'})
   ok(r['ok'] and q('SELECT liquide FROM personnages_donnees')==argent and r['etat']['proprietaire']=='ville:republic:capitale','maire decide seul, finance communal, aucune appropriation personnelle')
   terrain_vierge('projet-orga','orga:orga');c.execute("UPDATE personnages_donnees SET current_building='projet-orga';UPDATE organisations SET data=jsonb_set(data::jsonb,'{chef}','\"Autre\"')::text")
   refuse(lambda:commande('ch-orga-00001','projet-orga','lancer',{'palier':'hangar','apport':'10500'}),'organisation : membre sans representation refuse')
   c.execute("UPDATE organisations SET data=jsonb_set(data::jsonb,'{chef}','\"Alice\"')::text")
   r=commande('ch-orga-00001','projet-orga','lancer',{'palier':'hangar','apport':'10500'});ok(r['ok'] and r['chantier']['maitreOuvrage']=='orga:orga','organisation : chef via porte commune, caisse et maitrise ouvrage organisationnelles')
   c.execute("UPDATE personnages_donnees SET liquide=200000,arg=200000,current_building='plan-projet'")
   terrain_vierge('plan-projet',palier='commerce_premium');commande('ch-projet-plan0001','plan-projet','lancer',{'palier':'commerce_premium','apport':'31500'})
   plan=[{'id':'local-A','label':'Local A','surface':600,'destination':'commerce'}]
   refuse(lambda:commande('ch-plan-avant0001','plan-projet','plan',{'lots':plan,'valider':False}),'plan gratuit interdit avant dernier tiers')
   c.execute("UPDATE terrains_etat SET data=jsonb_set(data::jsonb,'{chantier,progressionJours}','12')::text WHERE id='plan-projet'")
   r=commande('ch-plan-sauve0001','plan-projet','plan',{'lots':plan,'valider':False});ok(r['ok'] and not r['etat'].get('subdivisions'),'plan dernier tiers enregistre sans activer les locaux')
   ok(q('SELECT count(*) FROM dossiers_urbanisme')==1 and q('SELECT count(*) FROM objets_recus')==1,'archive et recepisse remis par sas commun dans la transaction')
   avant=photo();ok(commande('ch-plan-sauve0001','plan-projet','plan',{'lots':plan,'valider':False})['rejeu'] and photo()==avant,'plan : reponse perdue sans seconde archive ni document')
   plan2=[dict(plan[0],surface=900)];r=commande('ch-plan-sauve0002','plan-projet','plan',{'lots':plan2,'valider':False});ok(r['ok'],'brouillon initial encore modifiable gratuitement')
   refuse(lambda:commande('ch-plan-trop0001','plan-projet','plan',{'lots':[dict(plan[0],surface=1600)],'valider':False}),'surface excedentaire refusee sans archive ni document')
   r=commande('ch-plan-valid0001','plan-projet','plan',{'lots':plan2,'valider':True});ok(r['ok'] and r['etat']['chantier']['planInitialValide'],'validation initiale explicite fige le plan')
   refuse(lambda:commande('ch-plan-encore001','plan-projet','plan',{'lots':plan,'valider':False}),'nouvelle modification gratuite apres validation refusee')
   c.execute("SET test.acteur='Alice';UPDATE personnages_donnees SET current_building='projet-orga',pa=50")
   argent=q('SELECT liquide FROM personnages_donnees');pa=q('SELECT pa FROM personnages_donnees')
   r=commande('ch-travail-000001','projet-orga','travailler',{'heures':'3'});ok(r['ok'] and r['montant']==210,'travail PJ : moteur commun paie 70 FR par heure')
   ok(q('SELECT liquide FROM personnages_donnees')==argent+210 and q('SELECT pa FROM personnages_donnees')==pa-3,'salaire et PA atomiques')
   avant=photo();ok(commande('ch-travail-000001','projet-orga','travailler',{'heures':'3'})['rejeu'] and photo()==avant,'reponse de travail perdue : aucun double PA ou salaire')
   c.execute("UPDATE personnages_donnees SET current_building='ailleurs'");refuse(lambda:commande('ch-travail-loin001','projet-orga','travailler',{'heures':'1'}),'travail distant refuse')
   ok(q("SELECT terrain_permis_acte('plan-projet','permis_plan_modifier','{}')")['raison']=='commande_versionnee_requise','ancienne porte de plan ne contourne pas les phases')
   ok(q("SELECT terrain_chantier_acte('plan-projet','chantier_accelerer')")['raison']=='delai_incompressible','construction Republia : aucune acceleration du delai incompressible')
   c.execute("UPDATE personnages_donnees SET current_building='municipal',poste='{\"id\":\"maire\",\"city\":\"capitale\"}';UPDATE cycles_electoraux SET data='{\"eluId\":\"Alice\"}'")
   r=commande('ch-prix-maire0001','municipal','prix',{'prix':{'bois':'7'}});ok(r['ok'] and r['etat']['chantier']['prixAchatPJ']['bois']==7,'maire : tarifs du chantier communal via meme moteur')
   refuse(lambda:commande('ch-prix-fraction1','municipal','prix',{'prix':{'bois':'7.5'}}),'fraction de franc refusee sans nouvelle ecriture')
   for pays in ['republic','soviet','narco','khalija']:
    c.execute('UPDATE personnages_donnees SET country=%s',(pays,));avant=photo()
    r=q("SELECT terrain_chantier_acte('plan-projet','chantier_accelerer')")
    ok(r.get('raison')=='delai_incompressible' and photo()==avant,'delai incompressible avant mutation dans '+pays)
   if suite_supplementaire is not None:suite_supplementaire(db,c,server)
  print(f'{n}/{n} assertions, PostgreSQL jetable ; authentification et notifications de fixture, aucun acces production.')
 finally:server.cleanup()
if __name__=='__main__':main()

