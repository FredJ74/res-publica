#!/usr/bin/env python3
"""Stockage #69, PostgreSQL jetable, vraie revision d'inventaire ; auth de fixture stricte UID."""
from pathlib import Path
import re,tempfile,json
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
def fonction(f,nom):
 s=(R/f).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-coffres69-'),cleanup_mode='delete');n=0
 try:
  with psycopg2.connect(server.get_uri()) as db:
   db.autocommit=True;c=db.cursor()
   c.execute("CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;CREATE SCHEMA auth;CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('test.uid',true),'')::uuid$$")
   for domaine,table in [('personnage-et-presence','personnages_donnees'),('immobilier-et-territoire','locations_actives'),('justice','detentions')]:
    s=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public\.'+table+r' \(.*?\n\);',s,re.S)[0])
   c.execute("ALTER TABLE locations_actives ADD PRIMARY KEY(id);ALTER TABLE personnages_donnees ADD PRIMARY KEY(name);ALTER TABLE personnages_donnees ADD COLUMN inventory_revision bigint NOT NULL DEFAULT 0;")
   c.execute("CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql SECURITY DEFINER AS $$SELECT name FROM personnages_donnees WHERE user_id=auth.uid()$$;CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF NOT EXISTS(SELECT 1 FROM personnages_donnees WHERE name=$1 AND user_id=auth.uid()) THEN RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE='42501';END IF;END$$")
   for nom in ['inventaire_localiser','inventaire_objet_protege','inventaire_quantite','inventaire_retirer','inventaire_retirer_position','inventaire_place_restante']:c.execute(fonction('baseline/domaines/socle/20_fonctions.sql',nom))
   c.execute(fonction('baseline/domaines/banque/20_fonctions.sql','helvetia_inventaire_sortie'))
   c.execute(fonction('baseline/domaines/justice/20_fonctions-1.sql','detention_active'))
   for nom in ['inventaire_revision_garder','inventaire_reception_etat']:c.execute(fonction('migrations/20261016131932_reception_objets_atomique.sql',nom))
   c.execute('CREATE TRIGGER zzzz_hg_inventory_revision BEFORE UPDATE ON personnages_donnees FOR EACH ROW EXECUTE FUNCTION inventaire_revision_garder()')
   c.execute((R/'migrations/20261022115612_inventaire_unites_et_retrait_multilignes.sql').read_text())
   for m in sorted((R/'migrations').glob('202610221337*.sql')):c.execute(m.read_text());c.execute(m.read_text())
   for table in ['terrains_etat','entreprises','locations_archives']:
    domaine='economie' if table=='entreprises' else 'immobilier-et-territoire'
    src=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public\.'+table+r' \(.*?\n\);',src,re.S)[0])
   for nom in ['terminer_bail','resilier_bail_volontaire']:c.execute(fonction('baseline/domaines/immobilier-et-territoire/20_fonctions.sql',nom))
   c.execute((R/'migrations/20261022141810_coffres_resiliation_vide.sql').read_text());c.execute((R/'migrations/20261022141810_coffres_resiliation_vide.sql').read_text())
   c.execute("INSERT INTO personnages_donnees(name,country,current_city,current_building,current_room,hp,inventory,user_id) VALUES('Alice-fixture','republic','capitale','banque-nationale','coffre_privatif',100,'[]','00000000-0000-4000-8000-000000000069'),('Bob-fixture','republic','capitale','banque-nationale','coffre_privatif',100,'[]','00000000-0000-4000-8000-000000000070');SET test.uid='00000000-0000-4000-8000-000000000069';SET request.path='/rpc/coffre_transferer'")
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t,flush=True)
   def q(sql,args=()):c.execute(sql,args);return c.fetchone()[0]
   def creer(taille='S'):
    id=q('SELECT gen_random_uuid()');bail='fixture:'+str(id);site={'country':'republic','city':'capitale','buildingId':'banque-nationale','roomId':'coffre_privatif'}
    c.execute("INSERT INTO locations_actives(id,country,data) VALUES(%s,'republic',%s)",(bail,Json(dict(site,locataire='Alice-fixture',prix=250))))
    c.execute("INSERT INTO coffres_bancaires(id,bail_id,titulaire_id,site,taille) VALUES(%s,%s,(SELECT id FROM personnages_donnees WHERE name='Alice-fixture'),%s,%s)",(str(id),bail,Json(site),taille));return str(id)
   coffre=creer()
   def inventory(v):c.execute("UPDATE personnages_donnees SET inventory=%s WHERE name='Alice-fixture'",(Json(v),))
   def lire(id=coffre):return q('SELECT coffre_lire(%s)',(id,))
   def transfert(req,action,index=0,qt=1,id=coffre,cur=c,entree=None):
    e=entree or lire(id);src=e['inventory'] if action=='deposer' else e['contenu'];sig=src[index] if index<len(src) else {}
    cur.execute('SELECT coffre_transferer(%s,%s,%s,%s,%s,%s,%s,%s)',(req,id,action,index,Json(sig),qt,e['revision'],e['revisionCoffre']));return cur.fetchone()[0]
   def photo():return q("SELECT jsonb_build_array((SELECT jsonb_agg(p ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM coffres_bancaires c),(SELECT jsonb_agg(c ORDER BY requete) FROM coffres_requetes c),(SELECT jsonb_agg(b ORDER BY id) FROM locations_actives b),(SELECT jsonb_agg(b ORDER BY id) FROM locations_archives b))")
   tableau={'id':'tableau-unique','name':'Tableau','regime':'individuel','exemplaire':{'id':'unique-69','histoire':['origine']},'provenance':{'source':'fixture'},'extensionLibre':{'x':[1,2,3]}}
   inventory([tableau]);e=lire();r=transfert('coffre-depot-00001','deposer',entree=e)
   ok(r['ok'] and r['contenu']==[tableau] and r['inventory']==[],'exemplaire : identite et toutes les metadonnees conservees')
   ok(r['revision']==e['revision']+1 and r['revisionCoffre']==1,'deux revisions avancees dans la meme transaction')
   avant=photo();ok(transfert('coffre-depot-00001','deposer',entree=e)['rejeu'] and photo()==avant,'reponse perdue : meme recu sans duplication')
   r=transfert('coffre-retrait-0001','retirer');ok(r['ok'] and r['inventory']==[tableau] and not r['contenu'],'retrait : meme exemplaire, pas une reconstruction approximative')
   c.execute("SET test.uid='00000000-0000-4000-8000-000000000070'");ok(lire()['raison']=='coffre_inaccessible','contenu inaccessible a un autre UID')
   fantome=q('SELECT gen_random_uuid()');ok(q('SELECT coffre_lire(%s)',(str(fantome),))['raison']=='coffre_inaccessible','meme refus pour un identifiant inconnu, aucune enumeration')
   c.execute("SET test.uid='00000000-0000-4000-8000-000000000069'")
   for taille,cap in [('S',50),('M',100),('L',150),('XL',400)]:
    id=creer(taille);inventory([{'name':'Tickets','stackKey':'tickets','stackable':True,'qty':cap+1,'provenance':{'lot':taille}}]);r=transfert('coffre-limite-'+taille+'0001','deposer',qt=cap,id=id)
    ok(r['ok'] and r['occupation']==cap and r['inventory'][0]['qty']==1,'capacite exacte '+taille)
    avant=photo();r=transfert('coffre-depasse-'+taille+'001','deposer',id=id);ok(r['raison']=='capacite_depassee' and photo()==avant,'depassement refuse sans perte '+taille)
   inventory([{'name':'Bois','stackKey':'bois','stackable':True,'qty':4,'provenance':{'lot':'A'}},{'name':'Bois','stackKey':'bois','stackable':True,'qty':5,'provenance':{'lot':'B'}}]);r=transfert('coffre-piles-00001','deposer',qt=6)
   ok(r['ok'] and [o['qty'] for o in r['contenu']]==[4,2] and r['contenu'][1]['provenance']=={'lot':'B'} and r['inventory'][0]['qty']==3,'pile multi provenance : chaque morceau conserve sa provenance et ses quantites')
   inventory([{'name':'Jetons','regime':'empilable','id':'jetons','qty':3}]);r=transfert('coffre-noyau-00001','deposer',qt=2)
   ok(r['ok'] and r['inventory'][0]['qty']==1 and r['contenu'][-1]['qty']==2,'regime du noyau sans stackKey : vraie pile, pas exemplaire artificiel')
   inventory([{'name':'Colis','type':'colis_secret_pat'}]);e=lire();avant=photo();r=transfert('coffre-quete-00001','deposer',entree=e);ok(r['raison']=='objet_protege' and photo()==avant,'protection de quete reutilisee')
   # Une signature complete refuse l'autre exemplaire de meme nom apres reordonnancement.
   a=dict(tableau,exemplaire={'id':'A'});b=dict(tableau,exemplaire={'id':'B'});inventory([b,a]);e=lire();e['inventory']=[a,b];avant=photo();r=transfert('coffre-signature01','deposer',entree=e);ok(r['raison']=='objet_modifie' and photo()==avant,'ancien index ne retire jamais un autre exemplaire')
   # La revision ferme la fenetre entre selection et clic.
   e=lire();inventory([a,b]);avant=photo();r=transfert('coffre-revision-01','deposer',entree=e);ok(r['raison']=='inventaire_perime' and photo()==avant,'inventaire modifie depuis selection : aucun transfert')
   # Deux commandes concurrentes distinctes partageant la meme revision : une seule peut gagner.
   e=lire();c.execute('COMMIT')
   def concurrent(i):
    with psycopg2.connect(server.get_uri()) as d:
     cc=d.cursor();cc.execute("SET test.uid='00000000-0000-4000-8000-000000000069';SET request.path='/rpc/coffre_transferer'");return transfert('coffre-course-000'+str(i),'deposer',cur=cc,entree=e)
   with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(concurrent,range(2)))
   ok(sum(x.get('ok',False) for x in rs)==1 and sum(x.get('raison')=='inventaire_perime' for x in rs)==1,'concurrence : pas de duplication entre deux intentions distinctes')
   # Ancienne sauvegarde REST, meme avec privilege plus large que la production pour eprouver le trigger.
   c.execute('GRANT SELECT,UPDATE ON personnages_donnees TO authenticated;GRANT USAGE ON SCHEMA auth TO authenticated');c.execute('COMMIT');avant=photo()
   c.execute("SET ROLE authenticated;SET request.path='/personnages';UPDATE personnages_donnees SET inventory='[]' WHERE name='Alice-fixture';RESET ROLE;SET request.path='/rpc/coffre_transferer'")
   ok(photo()==avant,'ancienne sauvegarde ne restaure pas les objets deposes')
   # Refus en serie : pas seulement le verdict, aucune contrepartie ne bouge.
   for qt in [0,-1,None]:
    e=lire();avant=photo();r=transfert('coffre-quantite-'+str(qt)+'00001','deposer',qt=qt,entree=e)
    ok(r.get('raison')=='quantite_invalide' and photo()==avant,'quantite invalide refusee '+str(qt))
   e=lire();avant=photo()
   try:
    c.execute("SELECT * FROM jsonb_to_record('{\"quantite\":1.5}') AS x(quantite integer)");raise AssertionError('fraction acceptee')
   except psycopg2.Error:db.rollback()
   ok(photo()==avant,'transport JSON vers integer : fraction refusee, aucune mutation')
   c.execute("UPDATE personnages_donnees SET current_room='accueil' WHERE name='Alice-fixture'");e=lire();avant=photo();r=transfert('coffre-lointain-001','deposer',entree=e)
   ok(r.get('raison')=='pas_sur_place' and photo()==avant,'consultation autorisee, transfert refuse hors salle reelle')
   c.execute("UPDATE personnages_donnees SET current_room='coffre_privatif' WHERE name='Alice-fixture'")
   inventory([dict(tableau,exemplaire={'id':'rollback'})]);e=lire()
   c.execute("CREATE FUNCTION panne_recu() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.requete='coffre-panne-fin001' THEN RAISE EXCEPTION 'panne_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_recu BEFORE INSERT ON coffres_requetes FOR EACH ROW EXECUTE FUNCTION panne_recu()")
   c.execute('COMMIT');avant=photo()
   try:transfert('coffre-panne-fin001','deposer',entree=e);raise AssertionError('panne attendue')
   except psycopg2.Error as err:db.rollback();assert 'panne_fixture' in str(err)
   ok(photo()==avant,'panne finale du recu : rollback inventaire coffre et deux revisions')
   # Le serveur a repondu mais le client a perdu la reponse : une meme intention concurrente.
   def meme_requete(_):
    with psycopg2.connect(server.get_uri()) as d:
     cc=d.cursor();cc.execute("SET test.uid='00000000-0000-4000-8000-000000000069';SET request.path='/rpc/coffre_transferer'");return transfert('coffre-meme-course01','deposer',cur=cc,entree=e)
   with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(meme_requete,range(2)))
   ok(all(x.get('ok') for x in rs) and sum(bool(x.get('rejeu')) for x in rs)==1,'deux memes intentions concurrentes : un transfert, un recu relu')
   # Le retrait ne doit ni detruire l'objet ni forcer une surcharge volontaire.
   inventory([{'name':'Tickets','stackKey':'tickets','stackable':True,'qty':100}]);e=lire();avant=photo();r=transfert('coffre-plein-000001','retirer',entree=e)
   ok(r.get('raison')=='inventaire_plein' and photo()==avant,'inventaire plein : retrait refuse, contenu conserve')
   # Le meme nom/presentation ne confere aucun droit apres remplacement du personnage.
   c.execute("UPDATE personnages_donnees SET id=gen_random_uuid() WHERE name='Alice-fixture'");avant=photo();r=lire()
   ok(r.get('raison')=='coffre_inaccessible' and photo()==avant,'nouvel UUID homonyme : aucun droit sur ancien coffre')
   c.execute("UPDATE personnages_donnees SET id=(SELECT titulaire_id FROM coffres_bancaires WHERE id=%s) WHERE name='Alice-fixture'",(coffre,))
   c.execute("SELECT has_function_privilege('anon','coffre_lire(uuid)','EXECUTE'),has_function_privilege('anon','coffre_transferer(text,uuid,text,integer,jsonb,integer,bigint,bigint)','EXECUTE'),has_table_privilege('authenticated','coffres_bancaires','SELECT'),has_table_privilege('authenticated','coffres_requetes','SELECT')")
   ok(c.fetchone()==(False,False,False,False),'aucun contenu ni recu lisible directement, anon sans RPC')
   # Resiliation du meme bail : aucun moteur parallele, reprise sans second effet.
   bail=q('SELECT bail_id FROM coffres_bancaires WHERE id=%s',(coffre,));avant=photo();r=q("SELECT resilier_bail_volontaire(%s,'Alice-fixture')",(bail,))
   ok(r.get('raison')=='coffre_non_vide' and photo()==avant,'resiliation non vide refusee sans suppression ni mouvement')
   c.execute("SET test.uid='00000000-0000-4000-8000-000000000070'");avant=photo();r=q("SELECT terminer_bail(%s,'succession_sans_heritier','Bob-fixture',0)",(bail,))
   ok(r.get('raison')=='coffre_inaccessible' and photo()==avant,'autre UID ne peut detruire un coffre en usurpant une cause de succession')
   c.execute("SET test.uid='00000000-0000-4000-8000-000000000069'")
   vide=creer();bail_vide=q('SELECT bail_id FROM coffres_bancaires WHERE id=%s',(vide,))
   r=q("SELECT resilier_bail_volontaire(%s,'Alice-fixture')",(bail_vide,))
   ok(r.get('ok') and q('SELECT count(*) FROM coffres_bancaires WHERE id=%s',(vide,))==0 and q('SELECT count(*) FROM locations_actives WHERE id=%s',(bail_vide,))==0 and q('SELECT count(*) FROM locations_archives WHERE bail_id=%s',(bail_vide,))==1,'coffre vide : suppression contrat et coffre, archive unique commune')
   avant=photo();r=q("SELECT resilier_bail_volontaire(%s,'Alice-fixture')",(bail_vide,))
   ok(r.get('deja_termine') and photo()==avant and q('SELECT count(*) FROM locations_archives WHERE bail_id=%s',(bail_vide,))==1,'resiliation reponse perdue : deja terminee sans autre archive')
   # Panne de l'archivage apres suppression du coffre : aucune perte definitive.
   vide=creer();bail_vide=q('SELECT bail_id FROM coffres_bancaires WHERE id=%s',(vide,))
   c.execute("CREATE FUNCTION panne_archive() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.bail_id="+"'"+bail_vide+"'"+" THEN RAISE EXCEPTION 'archive_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_archive BEFORE INSERT ON locations_archives FOR EACH ROW EXECUTE FUNCTION panne_archive()")
   c.execute('COMMIT');avant=photo()
   try:q("SELECT resilier_bail_volontaire(%s,'Alice-fixture')",(bail_vide,));raise AssertionError('panne attendue')
   except psycopg2.Error as err:db.rollback();assert 'archive_fixture' in str(err)
   ok(photo()==avant,'panne archive : coffre vide et contrat restaures ensemble')
   c.execute('COMMIT');avant=photo()
   try:c.execute("DELETE FROM personnages_donnees WHERE name='Alice-fixture'");raise AssertionError('suppression orpheline acceptee')
   except psycopg2.Error as e:db.rollback();assert 'coffres_succession_non_raccordee' in str(e)
   ok(photo()==avant,'suppression refusee tant que la succession complete n est pas raccordee')
   # Changement de taille : aucun contrat reel converti, fixture annuelle explicite.
   for domaine,table in [('banque','comptes_bancaires'),('finances-publiques','caisses_batiments'),('finances-publiques','recettes_municipales'),('finances-publiques','salaires_caisses'),('immobilier-et-territoire','villes')]:
    src=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public\.'+table+r' \(.*?\n\);',src,re.S)[0])
   c.execute("ALTER TABLE recettes_municipales ADD UNIQUE(pays,ville,jour,canal);CREATE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT false$$")
   for nom in ['caisse_institution_mouvement','salaire_caisse_de','recette_municipale']:c.execute(fonction('baseline/domaines/finances-publiques/20_fonctions-1.sql',nom))
   c.execute(fonction('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','bail_destination_attestee'))
   c.execute(fonction('migrations/20261020222029_construction_lancement_priorite_bancaire.sql','helvetia_debiter_fonds_ordinaires'))
   c.execute((R/'baseline/seeds/90_socle/salaires_caisses.sql').read_text())
   c.execute("INSERT INTO villes(pays,ville,nom,rang) VALUES('republic','capitale','Ville fixture',1);INSERT INTO caisses_batiments(id,data) VALUES('republic_mairie_capitale','{\"solde\":0}');UPDATE personnages_donnees SET liquide=3000,arg=5000 WHERE name='Alice-fixture';INSERT INTO comptes_bancaires(id,personnage,pays,banque,solde) VALUES('fixture-national','Alice-fixture','republic','nationale',2000)")
   m=(R/'migrations/20261022144500_coffres_changement_capacite.sql').read_text();c.execute(m);c.execute(m)
   annuel=creer();bail_annuel=q('SELECT bail_id FROM coffres_bancaires WHERE id=%s',(annuel,))
   def photo_taille():return [photo(),q('SELECT jsonb_agg(c ORDER BY id) FROM comptes_bancaires c'),q('SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c'),q('SELECT jsonb_agg(c) FROM recettes_municipales c')]
   def taille(req,t,rev=None,cur=c):
    if rev is None:rev=q('SELECT revision FROM coffres_bancaires WHERE id=%s',(annuel,))
    cur.execute('SELECT coffre_changer_taille(%s,%s,%s,%s)',(req,annuel,t,rev));return cur.fetchone()[0]
   avant=photo_taille();r=taille('coffre-annee-manque01','M');ok(r.get('raison')=='contrat_annuel_non_raccorde' and photo_taille()==avant,'ancien bail journalier jamais transforme silencieusement')
   c.execute("UPDATE coffres_bancaires SET debut_annuel='2026-10-22',renouvellement_annuel='2027-10-22' WHERE id=%s",(annuel,));c.execute("UPDATE locations_actives SET data=data||'{\"periodicite\":\"annuelle\"}' WHERE id=%s",(bail_annuel,))
   r=taille('coffre-grandir-00001','M',0);ok(r['ok'] and r['montant']==200 and r['renouvellementAnnuel']=='2027-10-22','S vers M : 200 FR sans prorata, meme renouvellement')
   ok(q("SELECT solde FROM comptes_bancaires WHERE id='fixture-national'")==1800 and q("SELECT liquide FROM personnages_donnees WHERE name='Alice-fixture'")==3000 and q("SELECT (data->>'solde')::integer FROM caisses_batiments WHERE id='republic_mairie_capitale'")==200,'primitives communes : banque prioritaire et vraie recette municipale atomiques')
   avant=photo_taille();ok(taille('coffre-grandir-00001','M',0)['rejeu'] and photo_taille()==avant,'reponse taille perdue : aucun second prelevement')
   r=taille('coffre-reduire-00001','S');ok(r['ok'] and r['montant']==0 and r['tarifAnnuel']==250 and r['renouvellementAnnuel']=='2027-10-22','reduction gratuite, tarif prochain renouvellement, date conservee')
   r=taille('coffre-regrandir001','M');ok(r['ok'] and r['montant']==200,'reduction puis agrandissement : aucun credit conserve')
   avant=photo_taille();ok(taille('coffre-perime-00001','L',0)['raison']=='coffre_perime' and photo_taille()==avant,'selection obsolete refusee sans debit')
   c.execute("UPDATE coffres_bancaires SET contenu='[{\"name\":\"Tickets\",\"stackable\":true,\"qty\":51}]' WHERE id=%s",(annuel,));avant=photo_taille();r=taille('coffre-trop-plein01','S')
   ok(r.get('raison')=='capacite_depassee' and photo_taille()==avant,'reduction sous occupation impossible, objets conserves')
   c.execute("UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name='Alice-fixture';UPDATE comptes_bancaires SET solde=0");avant=photo_taille();r=taille('coffre-insolvable1','XL')
   ok(r.get('raison')=='fonds_insuffisants' and photo_taille()==avant,'paiement impossible : taille date contrat objets et soldes inchanges')
   c.execute("UPDATE personnages_donnees SET liquide=3000,arg=3000 WHERE name='Alice-fixture'")
   # Une erreur APRES le paiement et les changements doit tout annuler.
   c.execute("CREATE FUNCTION panne_taille() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.requete='coffre-taille-panne1' THEN RAISE EXCEPTION 'taille_fixture';END IF;RETURN NEW;END$$;CREATE TRIGGER panne_taille BEFORE INSERT ON coffres_requetes FOR EACH ROW EXECUTE FUNCTION panne_taille()")
   c.execute('COMMIT');avant=photo_taille()
   try:taille('coffre-taille-panne1','XL');raise AssertionError('panne attendue')
   except psycopg2.Error as err:db.rollback();assert 'taille_fixture' in str(err)
   ok(photo_taille()==avant,'panne apres paiement : rollback recette banque liquide bail coffre et recu')
   rev=q('SELECT revision FROM coffres_bancaires WHERE id=%s',(annuel,));c.execute('COMMIT')
   def tailles_concurrentes(_):
    with psycopg2.connect(server.get_uri()) as d:
     cc=d.cursor();cc.execute("SET test.uid='00000000-0000-4000-8000-000000000069';SET request.path='/rpc/coffre_changer_taille'");return taille('coffre-meme-taille01','XL',rev,cur=cc)
   with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(tailles_concurrentes,range(2)))
   ok(all(x.get('ok') for x in rs) and sum(bool(x.get('rejeu')) for x in rs)==1,'deux clics concurrents : un agrandissement et un recu')
   ok(q('SELECT renouvellement_annuel::text FROM coffres_bancaires WHERE id=%s',(annuel,))=='2027-10-22' and q("SELECT data->>'prix' FROM locations_actives WHERE id=%s",(bail_annuel,))=='1250','taille XL et futur tarif, anniversaire toujours intact')
   c.execute("SET test.uid='00000000-0000-4000-8000-000000000070'");avant=photo_taille();r=taille('coffre-autrui-00001','S')
   ok(r.get('raison')=='coffre_inaccessible' and photo_taille()==avant,'changement du coffre d autrui refuse meme par RPC directe')
   # Meme RPC de loyer que le cron, dates et impaye financiers conserves au serveur.
   c.execute("SET test.uid='00000000-0000-4000-8000-000000000069';CREATE VIEW personnages AS SELECT * FROM personnages_donnees")
   c.execute("CREATE OR REPLACE FUNCTION est_appel_serveur() RETURNS boolean LANGUAGE sql AS $$SELECT coalesce(current_setting('test.serveur',true),'')='on'$$")
   c.execute(fonction('migrations/20261021203832_immobilier_loyers_titres.sql','prelever_loyer_bail'))
   for f in ['20261022153000_coffres_annuels_primitives.sql','20261022153001_coffres_annuels_loyer_commun.sql']:
    sql=(R/'migrations'/f).read_text();c.execute(sql);c.execute(sql)
   abonnement=creer();bail_abonnement=q('SELECT bail_id FROM coffres_bancaires WHERE id=%s',(abonnement,))
   c.execute("UPDATE coffres_bancaires SET debut_annuel=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date,renouvellement_annuel=((statement_timestamp() AT TIME ZONE 'Europe/Paris')::date+interval '1 year')::date WHERE id=%s",(abonnement,))
   c.execute("UPDATE locations_actives SET data=data||'{\"periodicite\":\"annuelle\"}' WHERE id=%s",(bail_abonnement,))
   c.execute("UPDATE personnages_donnees SET liquide=1000,arg=2000 WHERE name='Alice-fixture';UPDATE comptes_bancaires SET solde=1000")
   def loyer(id=bail_abonnement,cur=c):cur.execute('SELECT prelever_loyer_bail(%s)',(id,));return cur.fetchone()[0]
   echeance=q('SELECT renouvellement_annuel::text FROM coffres_bancaires WHERE id=%s',(abonnement,));solde=q('SELECT solde FROM comptes_bancaires')
   ok(loyer()=='paye' and q('SELECT solde FROM comptes_bancaires')==solde-250,'loyer annuel initial : une transaction commune, 250 FR')
   ok(q('SELECT premier_loyer_paye AND renouvellement_annuel::text=%s FROM coffres_bancaires WHERE id=%s',(echeance,abonnement,)),'premier paiement ne repousse pas l anniversaire initial')
   avant=photo_taille();ok(loyer()=='deja_preleve' and photo_taille()==avant,'meme jour/reponse perdue : un seul loyer annuel')
   c.execute('UPDATE coffres_bancaires SET loyer_jour_traitement=NULL WHERE id=%s',(abonnement,));avant=photo_taille();ok(loyer()=='non_echu' and photo_taille()==avant,'lendemain hors echeance : aucun loyer quotidien')
   # Mise a l echeance de la fixture, pas de changement de calendrier de la machine.
   def a_echeance():
    c.execute("UPDATE coffres_bancaires SET debut_annuel=((statement_timestamp() AT TIME ZONE 'Europe/Paris')::date-interval '1 year')::date,renouvellement_annuel=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date,loyer_jour_traitement=NULL WHERE id=%s",(abonnement,))
   a_echeance();solde=q('SELECT solde FROM comptes_bancaires');ok(loyer()=='paye' and q('SELECT solde FROM comptes_bancaires')==solde-250,'anniversaire : renouvellement dans le moteur commun')
   ok(q('SELECT renouvellement_annuel::text FROM coffres_bancaires WHERE id=%s',(abonnement,))==echeance,'date de renouvellement derivee de l ancrage civil, pas du jour du rattrapage')
   a_echeance();c.execute("UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name='Alice-fixture';UPDATE comptes_bancaires SET solde=0");cash=q('SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c')
   ok(loyer()=='avertissement' and q('SELECT jsonb_agg(c ORDER BY id) FROM caisses_batiments c')==cash,'impaye initial : avertissement sans debit ni credit')
   ok(q('SELECT loyer_impaye FROM coffres_bancaires WHERE id=%s',(abonnement,))==250,'loyer impaye fige pour cette echeance')
   for _ in range(3):
    c.execute('UPDATE coffres_bancaires SET loyer_jour_traitement=NULL WHERE id=%s',(abonnement,));loyer()
   ok(q('SELECT loyer_impaye FROM coffres_bancaires WHERE id=%s',(abonnement,))==250 and q("SELECT (data->'impaye'->>'montantDu')::integer FROM locations_actives WHERE id=%s",(bail_abonnement,))==250,'trois nuits impayees : 250 FR dus, jamais trois annuites')
   ok(q('SELECT count(*) FROM coffres_bancaires WHERE id=%s',(abonnement,))==1 and q('SELECT count(*) FROM locations_actives WHERE id=%s',(bail_abonnement,))==1,'aucune expulsion ni disparition du coffre pour impaye')
   # Une vieille sauvegarde de prix ne dicte ni le montant ni le calendrier prives.
   c.execute("UPDATE locations_actives SET data=data||'{\"prix\":600,\"jourPaiement\":\"2099-01-01\"}' WHERE id=%s",(bail_abonnement,))
   c.execute("UPDATE personnages_donnees SET liquide=1000,arg=1000 WHERE name='Alice-fixture';UPDATE coffres_bancaires SET loyer_jour_traitement=NULL WHERE id=%s",(abonnement,));argent=q("SELECT liquide FROM personnages_donnees WHERE name='Alice-fixture'")
   ok(loyer()=='paye' and q("SELECT liquide FROM personnages_donnees WHERE name='Alice-fixture'")==argent-250,'sauvegarde de bail perimee : tarif prive de 250 FR et ancrage preserves')
   ok(q('SELECT loyer_impaye FROM coffres_bancaires WHERE id=%s',(abonnement,))==0 and q("SELECT data ? 'impaye' FROM locations_actives WHERE id=%s",(bail_abonnement,))==False,'reglement de l echeance efface son impaye, sans oublier une autre date')
   # La panne finale de credit doit annuler aussi le debit et toute modification de date.
   a_echeance();c.execute("DELETE FROM caisses_batiments WHERE id='republic_mairie_capitale'");c.execute('COMMIT');avant=photo_taille()
   try:loyer();raise AssertionError('panne attendue')
   except psycopg2.Error as err:db.rollback();assert 'encaissement_non_confirme' in str(err)
   ok(photo_taille()==avant,'destination indisponible : rollback finances echeance et etat d impaye')
   c.execute("INSERT INTO caisses_batiments(id,data) VALUES('republic_mairie_capitale','{\"solde\":0}')");c.execute('COMMIT')
   def annuites_concurrentes(_):
    with psycopg2.connect(server.get_uri()) as d:
     cc=d.cursor();cc.execute("SET test.uid='00000000-0000-4000-8000-000000000069'");return loyer(cur=cc)
   with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(annuites_concurrentes,range(2)))
   ok(sorted(rs)==['deja_preleve','paye'],'deux passages de loyer concurrents : une seule annuite')
   # Calcul seul de l ancrage bissextile, distinct du test de paiement.
   c.execute("UPDATE coffres_bancaires SET debut_annuel='2024-02-29',renouvellement_annuel='2027-02-28' WHERE id=%s",(abonnement,));q("SELECT coffre_loyer_terminer_interne(jsonb_build_object('coffre',%s),'paye')",(abonnement,))
   ok(q('SELECT renouvellement_annuel::text FROM coffres_bancaires WHERE id=%s',(abonnement,))=='2028-02-29','calendrier : retrouver le 29 fevrier depuis l ancrage, sans derive permanente au 28')
   # Repasser le changement de taille apres mutualisation de l encaissement.
   c.execute("UPDATE personnages_donnees SET liquide=1000,arg=1000 WHERE name='Alice-fixture'");r=q('SELECT coffre_changer_taille(%s,%s,%s,%s)',('coffre-mutualise-001',abonnement,'M',0))
   ok(r['ok'] and r['montant']==200 and r['renouvellementAnnuel']=='2028-02-29','agrandissement apres mutualisation : meme difference et meme echeance')
   ok(q("SELECT has_function_privilege('authenticated','coffre_loyer_terminer_interne(jsonb,text)','EXECUTE')")==False,'aucun client ne peut valider un loyer sans encaissement')
   # Souscription reelle sur fixtures : cout PA historique et premiere annuite, un seul acte.
   for domaine,table in [('economie','ordres_couts'),('economie','ordres_couts_ecarts'),('economie','ordres_couts_inconnus'),('politique-et-elections','presidence_memoire_ordres')]:
    src=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public\.'+table+r' \(.*?\n\);',src,re.S)[0])
   c.execute("ALTER TABLE ordres_couts_inconnus ADD PRIMARY KEY(fn);ALTER TABLE ordres_couts_ecarts ADD UNIQUE(fn,pa,cost);INSERT INTO ordres_couts VALUES('louer_local',1,0)")
   c.execute(fonction('migrations/20261021120540_payer_ordre_garde_incapacite.sql','payer_ordre'))
   c.execute(fonction('baseline/domaines/immobilier-et-territoire/20_fonctions.sql','bail_cle_coherente'))
   c.execute('CREATE TRIGGER trg_bail_cle_coherente BEFORE INSERT OR UPDATE ON locations_actives FOR EACH ROW EXECUTE FUNCTION bail_cle_coherente()')
   for f in ['20261022160000_coffres_souscription_socle.sql','20261022160001_coffres_souscription_et_baux.sql']:
    sql=(R/'migrations'/f).read_text();c.execute(sql);c.execute(sql)
   c.execute("UPDATE personnages_donnees SET pa=30,liquide=10000,arg=20000,current_room='coffre_privatif' WHERE name='Alice-fixture';UPDATE comptes_bancaires SET solde=10000")
   def souscrire(req,t='S',cur=c):cur.execute('SELECT coffre_souscrire(%s,%s)',(req,t));return cur.fetchone()[0]
   def photo_complete():return [photo_taille(),q('SELECT jsonb_agg(c) FROM coffres_couts_autorises c')]
   avant=photo_complete();r=q("SELECT payer_ordre('Alice-fixture','louer_local',1,0)")
   ok(r.get('raison')=='coffre_versionne_requis' and photo_complete()==avant,'ancien onglet : refuser avant PA ou frais, pas apres une inscription rejetee')
   for t,prix in [('S',250),('M',450),('L',750),('XL',1250)]:
    pa=q("SELECT pa FROM personnages_donnees WHERE name='Alice-fixture'");argent=q('SELECT solde FROM comptes_bancaires');r=souscrire('coffre-abonnement-'+t+'0001',t)
    ok(r['ok'] and r['tarifAnnuel']==prix and q('SELECT solde FROM comptes_bancaires')==argent-prix and q("SELECT pa FROM personnages_donnees WHERE name='Alice-fixture'")==pa-1,'souscription '+t+' : premiere annuite et 1 PA atomiques')
    ok(q('SELECT count(*) FROM locations_actives WHERE id=(SELECT bail_id FROM coffres_bancaires WHERE id=%s)',(r['coffre'],))==1 and q('SELECT premier_loyer_paye FROM coffres_bancaires WHERE id=%s',(r['coffre'],)),'vrai bail et paiement acquis ensemble '+t)
   ancien=r;avant=photo_complete();r=souscrire('coffre-abonnement-XL0001','XL');ok(r.get('rejeu') and r['coffre']==ancien['coffre'] and photo_complete()==avant,'reponse de souscription perdue : meme coffre, pas de second bail ni paiement')
   avant=photo_complete();r=souscrire('coffre-abonnement-XL0001','S');ok(r.get('raison')=='requete_reutilisee' and photo_complete()==avant,'cle de souscription ne peut changer de taille apres paiement')
   cat=q('SELECT coffre_catalogue()');ok(cat['ok'] and [o['tarifAnnuel'] for o in cat['offres']]==[250,450,750,1250],'catalogue derive des tarifs serveur, pas prix dictes par formulaire')
   c.execute("SET test.uid='00000000-0000-4000-8000-000000000070'");cat=q('SELECT coffre_catalogue()');ok(cat['ok'] and cat['coffres']==[],'catalogue individuel : Bob ne voit aucun des coffres d Alice');c.execute("SET test.uid='00000000-0000-4000-8000-000000000069'")
   c.execute("UPDATE personnages_donnees SET liquide=0,arg=0 WHERE name='Alice-fixture';UPDATE comptes_bancaires SET solde=0");avant=photo_complete();r=souscrire('coffre-sans-fonds01')
   ok(r.get('raison')=='premier_loyer_refuse' and photo_complete()==avant,'fonds insuffisants : aucun PA perdu, aucun coffre bail ou marqueur abandonne')
   c.execute("UPDATE personnages_donnees SET liquide=1000,arg=1000,pa=0 WHERE name='Alice-fixture'");avant=photo_complete();r=souscrire('coffre-sans-pa-0001')
   ok(r.get('raison')=='cout_souscription_refuse' and photo_complete()==avant,'PA insuffisants : aucun paiement ou bail')
   c.execute("UPDATE personnages_donnees SET pa=30,current_room='accueil' WHERE name='Alice-fixture'");avant=photo_complete();r=souscrire('coffre-hors-site001')
   ok(r.get('raison')=='pas_sur_place' and photo_complete()==avant,'souscription hors site refusee avant cout')
   c.execute("UPDATE personnages_donnees SET current_room='coffre_privatif' WHERE name='Alice-fixture'")
   for t in ['XXL','s',None]:
    avant=photo_complete();r=souscrire('coffre-format-'+str(t)+'0001',t);ok(r.get('raison')=='taille_invalide' and photo_complete()==avant,'format invalide sans effet '+str(t))
   # Le nouveau bail peut seulement conserver les champs attestes par son coffre prive.
   bail=q('SELECT bail_id FROM coffres_bancaires WHERE id=%s',(ancien['coffre'],));c.execute('COMMIT');avant=photo_complete()
   try:c.execute("UPDATE locations_actives SET data=data||'{\"prix\":600}' WHERE id=%s",(bail,));raise AssertionError('ancien tarif accepte')
   except psycopg2.Error as err:db.rollback();assert 'contrat_coffre_modifie' in str(err)
   ok(photo_complete()==avant,'ancienne sauvegarde ne peut restaurer un tarif quotidien sur le contrat annuel')
   c.execute("UPDATE personnages_donnees SET liquide=1000,arg=1000 WHERE name='Alice-fixture'");c.execute('COMMIT')
   def abonnements_concurrents(_):
    with psycopg2.connect(server.get_uri()) as d:
     cc=d.cursor();cc.execute("SET test.uid='00000000-0000-4000-8000-000000000069'");return souscrire('coffre-course-abonne1',cur=cc)
   with ThreadPoolExecutor(max_workers=2) as pool:rs=list(pool.map(abonnements_concurrents,range(2)))
   ok(all(x.get('ok') for x in rs) and rs[0]['coffre']==rs[1]['coffre'] and sum(bool(x.get('rejeu')) for x in rs)==1,'deux inscriptions concurrentes meme intention : un coffre, un PA et un paiement')
   ok(q('SELECT count(*) FROM coffres_couts_autorises')==0 and q("SELECT has_table_privilege('authenticated','coffres_couts_autorises','INSERT')")==False,'autorisation transitoire de cout vide et inaccessible au navigateur')
   for f in ['20261022160002_coffres_reprise_et_resiliation.sql','20261022160003_coffres_baux_confidentialite.sql']:
    sql=(R/'migrations'/f).read_text();c.execute(sql);c.execute(sql)
   # Les policies permissives historiques restent presentes : la restriction doit s ajouter.
   c.execute('CREATE POLICY locations_lecture ON locations_actives FOR SELECT TO anon,authenticated USING(true);GRANT SELECT ON locations_actives TO anon,authenticated')
   c.execute("SET ROLE authenticated;SET test.uid='00000000-0000-4000-8000-000000000070'");ok(q('SELECT count(*) FROM locations_actives')==0,'RLS : meme lecture directe des contrats d autrui refusee');c.execute("RESET ROLE;SET test.uid='00000000-0000-4000-8000-000000000069'")
   r=souscrire('coffre-resilier-cible1');id_fin=r['coffre'];rev=0
   avant=photo_complete();r=q('SELECT coffre_resilier(%s,%s,%s)',('coffre-resilier-0001',id_fin,rev))
   ok(r.get('ok') and r.get('resilie'),'resiliation versionnee reutilise la terminaison du bail vide')
   avant=photo_complete();r=q('SELECT coffre_resilier(%s,%s,%s)',('coffre-resilier-0001',id_fin,rev))
   ok(r.get('rejeu') and photo_complete()==avant,'resiliation reponse perdue : recu retrouve apres suppression du coffre')
   ok(q("SELECT coffre_recu('coffre-resilier-0001')->>'terminee'")=='true','F5 : consultation de confirmation sans reexecuter la commande')
   c.execute("SET test.uid='00000000-0000-4000-8000-000000000070'");ok(q("SELECT coffre_recu('coffre-resilier-0001')->>'terminee'")=='false','recu invisible pour un autre UID');c.execute("SET test.uid='00000000-0000-4000-8000-000000000069'")
   print(f'{n}/{n} assertions locales. Stockage et taille prepares ; aucun abonnement ni succession active en production.')
 finally:server.cleanup()
if __name__=='__main__':main()
