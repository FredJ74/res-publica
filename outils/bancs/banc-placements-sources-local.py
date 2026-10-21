#!/usr/bin/env python3
"""Vrai moteur national, vrais schemas archives ; identite/paiement de fixture. Jamais Supabase."""
from pathlib import Path
import re,tempfile
from concurrent.futures import ThreadPoolExecutor
R=Path(__file__).resolve().parents[2]
def fonction(src,nom):
 s=(R/src).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);return s[a:a+m.end()]
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-placement64-'),cleanup_mode='delete');uri=serveur.get_uri();n=0
 try:
  with psycopg2.connect(uri) as db:
   db.autocommit=True;q=db.cursor()
   q.execute("CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role")
   for d,ts in [('personnage-et-presence',['personnages_donnees']),('banque',['comptes_bancaires','placements_bancaires'])]:
    src=(R/f'baseline/domaines/{d}/10_tables.sql').read_text()
    for t in ts:q.execute(re.search(r'CREATE TABLE public\.'+t+r' \(.*?\n\);',src,re.S)[0])
   q.execute("ALTER TABLE personnages_donnees ADD PRIMARY KEY(name);ALTER TABLE comptes_bancaires ADD PRIMARY KEY(id);ALTER TABLE placements_bancaires ADD PRIMARY KEY(id);CREATE VIEW personnages AS SELECT * FROM personnages_donnees;CREATE TABLE investissements(joueur text,statut text);CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT current_setting('test.acteur',true)$$;CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF $1 IS DISTINCT FROM mon_personnage() THEN RAISE EXCEPTION 'acteur_non_authentifie';END IF;END$$;CREATE FUNCTION payer_ordre(text,text,integer,integer) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN UPDATE personnages_donnees SET pa=pa-$3 WHERE name=$1 AND pa>=$3;RETURN jsonb_build_object('ok',FOUND);END$$;")
   q.execute(fonction('baseline/domaines/banque/20_fonctions.sql','creer_placement_national'))
   migration=next((R/'migrations').glob('*_placements_nationaux_sources_atomiques.sql')).read_text();q.execute(migration);q.execute(migration)
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t,flush=True)
   def reset():
    q.execute("TRUNCATE placements_requetes,placements_bancaires,comptes_bancaires,personnages_donnees,investissements;INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,arg,liquide,pa,hp) VALUES('Alice',gen_random_uuid(),'republic','capitale','banque-nationale','accueil_banque',2000,1000,10,100);INSERT INTO comptes_bancaires(id,personnage,pays,banque,solde) VALUES('n','Alice','republic','nationale',1000),('h','Alice','republic','helvetia',777);SET test.acteur='Alice'")
   def appel(req='requete',montant='500',source='compte',cur=q):cur.execute('SELECT banque_nationale_placer(%s,%s,%s,%s)',(req,montant,source,12));return cur.fetchone()[0]
   def photo():q.execute("SELECT jsonb_build_array((SELECT to_jsonb(p) FROM personnages_donnees p),(SELECT jsonb_agg(c ORDER BY id) FROM comptes_bancaires c),(SELECT jsonb_agg(p ORDER BY id) FROM placements_bancaires p),(SELECT jsonb_agg(r) FROM placements_requetes r))");return q.fetchone()[0]
   for source in ['compte','liquide']:
    reset();r=appel(source=source);ok(r['ok'],'souscription '+source)
    q.execute("SELECT liquide,pa,arg FROM personnages_donnees");ok(q.fetchone()==(500 if source=='liquide' else 1000,9,2000),'argent et PA atomiques, fortune inchangee '+source)
    q.execute("SELECT solde FROM comptes_bancaires WHERE banque='nationale'");ok(q.fetchone()[0]==(1000 if source=='liquide' else 500),'aucun depot intermediaire '+source)
    q.execute("SELECT solde FROM comptes_bancaires WHERE banque='helvetia'");ok(q.fetchone()[0]==777,'Helvetia intacte')
    avant=photo();ok(appel(source=source)['rejeu'],'rejeu meme souscription');ok(photo()==avant,'rejeu sans nouvelle contrepartie')
    ok(appel(montant='600',source=source)['raison']=='requete_reutilisee','cle liee au montant')
    ok(not appel(req='autre',source=source)['ok'],'second placement actif refuse');ok(photo()==avant,'refus rend aussi les PA')
    q.execute("SELECT banque_placement_recu('requete')->>'ok'");ok(q.fetchone()[0]=='true','recu retrouve apres F5')
    q.execute("SET test.acteur='Bob';SELECT banque_placement_recu('requete')->>'ok'");ok(q.fetchone()[0]=='false','recu prive')
   for source in ['liquide','compte']:
    reset();avant=photo();ok(not appel(montant='1001',source=source)['ok'],'fonds insuffisants '+source);ok(photo()==avant,'refus sans PA ou argent perdu')
   for m in ['499','500.5','-1','NaN','1e3']:
    reset();avant=photo();ok(not appel(montant=m)['ok'],'montant strict '+m);ok(photo()==avant,'montant refuse sans effet')
   reset();q.execute("INSERT INTO investissements VALUES('Alice','en_cours')");avant=photo();ok(not appel()['ok'],'ancien placement preserve');ok(photo()==avant,'ancien placement sans PA perdu')
   for mod in ["pa=0","hp=0","current_building='banque-privee'","current_room='rue'"]:
    reset();q.execute('UPDATE personnages_donnees SET '+mod);avant=photo();ok(not appel()['ok'],'droits/PA reel '+mod);ok(photo()==avant,'aucune mutation si droit refuse')
   reset();q.execute("CREATE FUNCTION panne_placement() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_fixture';END$$;CREATE TRIGGER panne BEFORE INSERT ON placements_bancaires FOR EACH ROW EXECUTE FUNCTION panne_placement()")
   avant=photo()
   try:appel(source='liquide');raise AssertionError('panne non levee')
   except psycopg2.Error:pass
   ok(photo()==avant,'panne apres debit annule PA, argent et recu');q.execute('DROP TRIGGER panne ON placements_bancaires');ok(appel(source='liquide')['ok'],'reprise meme cle apres rollback')
   reset()
   def concurrent(_):
    with psycopg2.connect(uri) as d:
     d.autocommit=True;c=d.cursor();c.execute("SET test.acteur='Alice'");return appel(cur=c)
   with ThreadPoolExecutor(2) as pool:rs=list(pool.map(concurrent,range(2)))
   ok(all(r['ok'] for r in rs) and sum(bool(r.get('rejeu')) for r in rs)==1,'deux appels concurrents meme recu')
   q.execute('SELECT count(*) FROM placements_bancaires');ok(q.fetchone()[0]==1,'un placement concurrent')
   q.execute("SELECT pa FROM personnages_donnees");ok(q.fetchone()[0]==9,'un PA concurrent')
   q.execute("SELECT has_table_privilege('authenticated','placements_requetes','SELECT'),has_function_privilege('authenticated','creer_placement_national_interne(text,numeric,integer,text,text)','EXECUTE'),has_function_privilege('anon','banque_nationale_placer(text,text,text,integer)','EXECUTE')");ok(q.fetchone()==(False,False,False),'tables privees et moteur injoignable')
  print(f'{n}/{n} assertions PostgreSQL locales ; production non verifiee.')
 finally:serveur.cleanup()
if __name__=='__main__':main()
