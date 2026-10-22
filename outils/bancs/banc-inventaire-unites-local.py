#!/usr/bin/env python3
"""Occupation #69 et conservation par les vrais outils d'inventaire, PostgreSQL jetable."""
from pathlib import Path
import re,tempfile,random
R=Path(__file__).resolve().parents[2]
M=R/'migrations/20261022115612_inventaire_unites_et_retrait_multilignes.sql'
def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-unites69-'),cleanup_mode='delete');n=0
 try:
  with psycopg2.connect(server.get_uri()) as db:
   db.autocommit=True;c=db.cursor()
   def charger(f,nom):
    s=(R/f).read_text();a=s.index('CREATE OR REPLACE FUNCTION public.'+nom+'(')
    m=re.search(r'AS (\$\w*\$)(.*?)\1;',s[a:],re.S);c.execute(s[a:a+m.end()])
   for nom in ['inventaire_localiser','inventaire_objet_protege','inventaire_quantite','inventaire_retirer','inventaire_retirer_position']:
    charger('baseline/domaines/socle/20_fonctions.sql',nom)
   charger('baseline/domaines/banque/20_fonctions.sql','helvetia_inventaire_sortie')
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t,flush=True)
   def extraire(inv,q,quete=None):
    c.execute('SELECT helvetia_inventaire_sortie(%s,%s,0,%s,%s)',(Json(inv),Json(quete or {}),Json(inv[0]),q));return c.fetchone()[0]
   def occupation(inv):
    c.execute('SELECT inventaire_occupation_unites(%s)',(Json(inv),));return c.fetchone()[0]
   def refuse(fn,t):
    try:fn()
    except psycopg2.Error:db.rollback();ok(True,t);return
    raise AssertionError('acceptation indue : '+t)
   inv=[{'name':'Bois','stackable':True,'stackKey':'bois','qty':4,'provenance':'A'},
        {'name':'Bois','stackable':True,'stackKey':'bois','qty':5,'provenance':'B'}]
   r=extraire(inv,6)
   ok(r['ok'] and r['objet']['qty']==6 and r['inventory']==[], 'contre-exemple archive : annonce 6 sortis mais detruit 9')
   sql=M.read_text();c.execute(sql);c.execute(sql)
   r=extraire(inv,6)
   ok(r['ok'] and r['objet']['qty']==6 and r['inventory']==[dict(inv[1],qty=3)],'retrait multilignes : 6 sortis, 3 conserves avec provenance')
   ok(occupation(inv)==9 and occupation(r['inventory'])+occupation([r['objet']])==9,'conservation entree = sortie + reste')
   ok(extraire(inv,10)=={'ok':False,'raison':'quantite_insuffisante','detenu':9},'stock insuffisant refuse par moteur commun')
   ok(extraire(inv,0)['raison']=='quantite_invalide','quantite nulle refusee')
   for qty in [-1,1.5,'NaN','Infinity']:
    refuse(lambda qty=qty:c.execute("SELECT inventaire_retirer(%s,'bois',1)",(Json([dict(inv[0],qty=qty)]),)),'retrait refuse pile invalide '+str(qty))
   unique=[{'name':'Tableau','type':'oeuvre','qty':500,'encombrement':80,'exemplaire':{'id':'unique'}}]
   ok(occupation(unique)==1,'exemplaire unique compte 1 independamment des anciens champs')
   ok(occupation([{'id':'papier','regime':'empilable','qty':50}])==50,'regime empilable du noyau reconnu')
   ok(occupation([{'id':'tableau','regime':'individuel','stackable':True,'qty':60}])==1,'regime explicite prioritaire comme dans le noyau client')
   ok(occupation([])==0,'coffre vide : zero unite')
   for cap in [50,100,150,400]:
    ok(occupation([{'stackable':True,'qty':cap}])==cap and occupation([{'stackable':True,'qty':cap+1}])>cap,'comptage exact limite et depassement '+str(cap))
   for value in [0,-1,1.5,'NaN','Infinity',True,'x']:
    refuse(lambda value=value:occupation([{'stackable':True,'qty':value}]),'pile invalide refusee '+str(value))
   for value in [None,{},[None],[{'regime':'inconnu'}]]:
    refuse(lambda value=value:occupation(value),'structure invalide refusee '+str(value))
   ok(occupation([{'name':'Pile ancienne','stackable':True}])==1,'quantite absente historique vaut une unite')
   protected=[{'name':'Colis','type':'colis_secret_pat'}]
   ok(extraire(protected,1,{'ambition':'criminel','etape':'en_cours'})['raison']=='objet_protege','protection de quete conservee')
   r=extraire(unique,1);ok(r['ok'] and r['objet']==unique[0] and not r['inventory'],'exemplaire conserve integralement')
   # Pas de simulations de transactions : vrais outils purs, entrees generees deterministes.
   random.seed(69)
   for i in range(100):
    qtes=[random.randint(1,40) for _ in range(random.randint(1,8))]
    piles=[dict(inv[0],qty=q,provenance=str(k)) for k,q in enumerate(qtes)]
    q=random.randint(1,sum(qtes));r=extraire(piles,q)
    assert r['ok'] and occupation(r['inventory'])+r['objet']['qty']==sum(qtes),(qtes,q,r)
    assert all(x['provenance'] in [p['provenance'] for p in piles] for x in r['inventory'])
   ok(True,'100 retraits multilignes aleatoires : conservation et metadonnees')
   c.execute("CREATE TABLE temoin (inv jsonb); INSERT INTO temoin VALUES ('[]');")
   c.execute('COMMIT');c.execute('BEGIN');c.execute('UPDATE temoin SET inv=%s',(Json(inv),))
   try:c.execute("SELECT inventaire_retirer(%s,'bois',10)",(Json(inv),));raise AssertionError('stock insuffisant accepte')
   except psycopg2.Error:c.execute('ROLLBACK')
   c.execute('SELECT inv FROM temoin');ok(c.fetchone()[0]==[],'refus annule toute transaction appelante')
   c.execute("SELECT count(*) FROM pg_proc p, LATERAL aclexplode(p.proacl) a WHERE p.oid='inventaire_occupation_unites(jsonb)'::regprocedure AND a.grantee=0 AND a.privilege_type='EXECUTE'")
   ok(c.fetchone()[0]==0,'aucun EXECUTE public sur la nouvelle primitive privee')
   c.execute("CREATE OR REPLACE FUNCTION inventaire_retirer(p_inv jsonb,p_cle text,p_qte integer) RETURNS jsonb LANGUAGE sql AS $$SELECT p_inv$$")
   refuse(lambda:c.execute(sql),'definition serveur divergente refusee')
  print(f'{n}/{n} assertions + 100 cas generes. Aucun bail active, aucun acces production.')
 finally:server.cleanup()
if __name__=='__main__':main()
