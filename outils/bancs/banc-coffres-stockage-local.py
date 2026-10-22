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
   print(f'{n}/{n} assertions locales. Stockage seulement : aucun abonnement ni succession active en production.')
 finally:server.cleanup()
if __name__=='__main__':main()
