#!/usr/bin/env python3
"""RPC d'impacts archivée + migration réelle sur PostgreSQL jetable, identité simulée.
Aucun compte, identifiant, inventaire ou solde de production.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import tempfile,re
R=Path(__file__).resolve().parents[2]

def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-impacts-'),cleanup_mode='delete')
 uri=serveur.get_uri(); total=0
 try:
  with psycopg2.connect(uri) as c:
   c.autocommit=True;q=c.cursor()
   q.execute("""CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;
    CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$SELECT coalesce(nullif(current_setting('test.role',true),''),'authenticated')$$;
    CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('test.acteur',true),'')$$;""")
   # Table réelle du baseline, sans réinventer ses types ni ses valeurs par défaut.
   for domaine,nom in [('personnage-et-presence','personnages_donnees'),('justice','impacts_indices_attente')]:
    texte=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text()
    q.execute(re.search(r'CREATE TABLE public\.'+nom+r' \(.*?\n\);',texte,re.S)[0])
   q.execute('ALTER TABLE personnages_donnees ADD PRIMARY KEY(name);ALTER TABLE impacts_indices_attente ADD PRIMARY KEY(id)')
   src=(R/'baseline/domaines/justice/20_fonctions-1.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.impact_deposer(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[a:],re.S);q.execute(src[a:a+m.end()])
   mig=(R/'migrations/20261021115429_impacts_realites_immediates.sql').read_text()
   q.execute(mig);q.execute(mig)
   def ok(v,titre):
    nonlocal total
    assert v,titre;total+=1;print('OK',titre)
   def perso(n,poste=None):
    from psycopg2.extras import Json
    q.execute("INSERT INTO personnages_donnees(name,user_id,country,current_city,current_building,current_room,hp,pa,day,moral,journal,poste,inventory,arg,liquide) VALUES(%s,gen_random_uuid(),'republic','capitale','mairie','hall',100,8,7,50,'[]',%s,'[{\"id\":\"ancien\"}]',2000,2000)",(n,Json(poste)))
   for n in ['Agresseur','Victime','Autre','Courrier','President','Invalide']:perso(n,{'id':'president'} if n=='President' else None)
   q.execute("SET test.acteur='Agresseur'")
   def impact(id='i1',victime='Victime',indice='hp_set',delta=0,palier='totale'):
    q.execute('SELECT impact_deposer(%s,%s,%s,%s,%s)',(id,victime,indice,delta,palier));return q.fetchone()[0]
   def fiche(n='Victime'):
    q.execute('SELECT row_to_json(p) FROM personnages_donnees p WHERE name=%s',(n,));return q.fetchone()[0]
   v=impact();f=fiche()
   ok(v['ok'] and v['applique_serveur'] and f['hp']==0 and f['pa']==0,'agression immediate, victime inactive, PA nuls')
   ok(f['hospitalisation']['dateFinParis']>f['hospitalisation']['dateDebutParis'] and f['hospitalisation']['lieu']=='dispensaire','convalescence civile Paris et lieu existant')
   ok(f['regen_jour']==7 and len(f['stats_affaiblies'])==2,'regeneration et deux statistiques affaiblies')
   ok(f['arg']==f['liquide']==2000 and f['inventory']==[{'id':'ancien'}],'aucune contrepartie financiere ou inventaire touchee')
   ok(len(f['journal'])==1 and f['journal'][0]['impactId']=='i1','evenement persiste avant connexion')
   q.execute("SELECT traite,applique_serveur FROM impacts_indices_attente WHERE id='i1'");ok(q.fetchone()==(False,True),'notification conservee, application distinguee de lecture')
   ok(impact()['rejeu'] and fiche()==f,'reponse perdue et rejeu strictement sans effet')
   q.execute("SET test.role='service_role';UPDATE personnages_donnees SET current_room='autre' WHERE name='Victime';SET test.role='authenticated'")
   ok(impact()['rejeu'],'recu confirme meme apres deplacement')
   ok(impact('i1',delta=25)['raison']=='identifiant_deja_utilise','id identique, payload different refuse')
   ok(impact('loin')['raison']=='pas_au_meme_endroit','copresence conservee')
   q.execute("SET test.acteur='Autre'");ok(impact()['raison']=='identifiant_deja_utilise','recu lie a son auteur')
   q.execute("SET test.acteur='Agresseur'")
   try:q.execute("UPDATE personnages_donnees SET hp=100,hospitalisation=NULL,pa=8,arg=0 WHERE name='Victime'")
   except psycopg2.Error as e:ok(e.pgcode=='40001','ancienne sauvegarde medicale rejetee')
   else:raise AssertionError('sauvegarde obsolete acceptee')
   ok(fiche()['arg']==2000 and fiche()['hp']==0,'refus atomique de toute la sauvegarde')
   q.execute("SET test.acteur='Victime'")
   try:q.execute("UPDATE personnages_donnees SET current_building=NULL,current_room=NULL WHERE name='Victime'")
   except psycopg2.Error as e:ok(e.pgcode=='42501','PATCH de position ne contourne pas la convalescence')
   else:raise AssertionError('sortie directe acceptee')
   q.execute("UPDATE personnages_donnees SET current_building='dispensaire-public',current_room='salle_attente' WHERE name='Victime'")
   ok(fiche()['current_building']=='dispensaire-public','arrivee hospitaliere historique autorisee')
   q.execute("SET test.role='service_role';UPDATE personnages_donnees SET current_building='mairie',current_room='autre' WHERE name='Victime';SET test.role='authenticated';SET test.acteur='Agresseur'")
   q.execute("UPDATE personnages_donnees SET hp=20 WHERE name='Victime'");ok(fiche()['hp']==20,'soin historique gardant la convalescence autorise')
   q.execute("UPDATE personnages_donnees SET hospitalisation=jsonb_set(hospitalisation,'{lieu}','\"clinique\"') WHERE name='Victime'");ok(fiche()['hospitalisation']['lieu']=='clinique','transfert conservant identite impact autorise')
   q.execute("SET test.acteur='Victime'");ok(impact('incapable',victime='Agresseur')['raison']=='acteur_incapacite','convalescence active : agression refusee meme apres soin')
   q.execute("SET test.acteur='Agresseur';UPDATE personnages_donnees SET hp=0 WHERE name='Agresseur'")
   ok(impact('interdit',victime='Autre')['raison']=='acteur_incapacite','acteur a zero sante refuse sans mutation')
   q.execute("SET test.acteur='Autre'")
   v=impact('president',victime='President');f=fiche('President')
   from datetime import date
   ok(v['ok'] and (date.fromisoformat(f['hospitalisation']['dateFinParis'])-date.fromisoformat(f['hospitalisation']['dateDebutParis'])).days==3,'bareme clinique du haut poste conserve')
   v=impact('carte1',victime='Courrier',indice='moral_carte_postale',delta=999,palier=None)
   ok(v['ok'] and fiche('Courrier')['moral']==60,'moral carte immediat, delta impose a dix')
   impact('carte2',victime='Courrier',indice='moral_carte_postale',palier=None)
   ok(fiche('Courrier')['moral']==60 and len(fiche('Courrier')['journal'])==1,'plafond expediteur quotidien applique serveur')
   ok(not impact('poison',victime='Courrier',indice='poison_start')['ok'],'poison sans schema toujours refuse')
   q.execute("SET test.acteur=''");ok(impact('anon')['raison']=='acteur_non_authentifie','authentification preservee')
   q.execute("SET test.acteur='Autre'");q.execute("BEGIN")
   impact('rollback',victime='Invalide');q.execute('ROLLBACK')
   ok(fiche('Invalide')['hp']==100,'rollback restaure victime et notification')
   # Panne d'ecriture evenement : le debit medical ne doit jamais rester seul.
   q.execute("CREATE FUNCTION panne() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.id='panne' AND NEW.applique_serveur THEN RAISE EXCEPTION 'panne simulee';END IF;RETURN NEW;END$$;CREATE TRIGGER panne BEFORE UPDATE ON impacts_indices_attente FOR EACH ROW EXECUTE FUNCTION panne()")
   try:impact('panne',victime='Invalide')
   except psycopg2.Error:pass
   else:raise AssertionError('panne non declenchee')
   ok(fiche('Invalide')['hp']==100,'panne finale annule sante, PA, journal et recu')
   q.execute("SELECT count(*) FROM impacts_indices_attente WHERE id IN ('rollback','panne')");ok(q.fetchone()[0]==0,'aucun recu orphelin')
   def concurrent(_):
    with psycopg2.connect(uri) as cx:
     cx.autocommit=True
     with cx.cursor() as z:
      z.execute("SET test.acteur='Autre'");z.execute("SELECT impact_deposer('concurrent','Invalide','hp_set',25,'partielle')");return z.fetchone()[0]
   with ThreadPoolExecutor(max_workers=4) as pool:vs=list(pool.map(concurrent,range(4)))
   ok(all(v['ok'] for v in vs) and sum(not v['rejeu'] for v in vs)==1 and len(fiche('Invalide')['journal'])==1,'quatre appels concurrents, une seule application')
   q.execute("SELECT has_function_privilege('authenticated','impact_realite_appliquer(text)','EXECUTE'),has_function_privilege('anon','impact_deposer(text,text,text,integer,text)','EXECUTE')");ok(q.fetchone()==(False,False),'helper prive et porte anonyme fermee')
   perso('Archive');perso('Neuf')
   q.execute("INSERT INTO impacts_indices_attente(id,victime,indice,delta,palier,traite) VALUES('ancien','Archive','hp_set',50,'echec_partiel',false),('ancien-neuf','Neuf','hp_set',50,'echec_partiel',false)")
   q.execute("SET test.acteur='Archive';SELECT impacts_realites_synchroniser()")
   ok(q.fetchone()[0]['ok'] and fiche('Archive')['hp']==50,'ancien impact rattrape serveur au prochain contact')
   q.execute("SELECT impacts_realites_synchroniser()")
   ok(q.fetchone()[0]['ok'] and len(fiche('Archive')['journal'])==1,'rattrapage rejouable sans double application')
   q.execute("SET test.acteur='Autre'");impact('nouveau',victime='Neuf',delta=0)
   ok(fiche('Neuf')['hp']==0 and len(fiche('Neuf')['journal'])==2,'ancien impact applique avant le nouveau, jamais apres')
   q.execute("SET test.acteur='Neuf';SELECT impacts_realites_synchroniser()")
   ok(q.fetchone()[0]['ok'] and fiche('Neuf')['hp']==0,'connexion tardive ne remonte pas la sante apres le nouvel impact')
   q.execute("SELECT has_column_privilege('authenticated','impacts_indices_attente','auteur','SELECT'),has_column_privilege('authenticated','impacts_indices_attente','delta','SELECT')")
   ok(q.fetchone()==(False,True),'identite secrete de l agresseur absente des droits de lecture victime')
   q.execute('SET ROLE authenticated')
   try:q.execute('SELECT auteur FROM impacts_indices_attente')
   except psycopg2.Error as e:ok(e.pgcode=='42501','lecture directe de l auteur refusee meme hors interface')
   else:raise AssertionError('auteur devoile')
   q.execute('SELECT id,indice,delta,applique_serveur,resultat FROM impacts_indices_attente LIMIT 1');ok(q.fetchone() is not None,'projection de notification conservee')
   q.execute('RESET ROLE')
   # Une modification serveur inconnue doit rendre la migration inexecutable.
   q.execute("CREATE OR REPLACE FUNCTION impact_deposer(p_id text,p_victime text,p_indice text,p_delta integer,p_palier text DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$")
   try:q.execute(mig)
   except psycopg2.Error:q.execute('ROLLBACK');ok(True,'definition serveur inconnue refusee par precondition')
   else:raise AssertionError('definition inconnue ecrasee')
  print(f'{total}/{total} scenarios PostgreSQL locaux reussis ; production non verifiee.')
 finally:serveur.cleanup()
if __name__=='__main__':main()
