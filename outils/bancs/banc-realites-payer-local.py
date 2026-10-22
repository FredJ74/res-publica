#!/usr/bin/env python3
"""Débit commun SQL réel, fixtures fictives, pas de production ni centimes introduits."""
from pathlib import Path
import re,tempfile
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-realites-payer-'),cleanup_mode='delete');n=0
 try:
  with psycopg2.connect(serveur.get_uri()) as c:
   c.autocommit=True;q=c.cursor()
   for d,table in [('personnage-et-presence','personnages_donnees'),('banque','comptes_bancaires'),('economie','ordres_couts'),('economie','ordres_couts_inconnus'),('economie','ordres_couts_ecarts'),('politique-et-elections','presidence_memoire_ordres')]:
    q.execute(re.search(r'CREATE TABLE public\.'+table+r' \(.*?\n\);',(R/f'baseline/domaines/{d}/10_tables.sql').read_text(),re.S)[0])
   q.execute("""ALTER TABLE ordres_couts_inconnus ADD PRIMARY KEY(fn);ALTER TABLE ordres_couts_ecarts ADD UNIQUE(fn,pa,cost);
    CREATE FUNCTION exiger_acteur(text) RETURNS void LANGUAGE plpgsql AS $$BEGIN IF $1<>'Victime' THEN RAISE EXCEPTION 'acteur_non_authentifie';END IF;END$$;
    INSERT INTO personnages_donnees(name,user_id,country,hp,pa,arg,liquide,current_building) VALUES('Victime',gen_random_uuid(),'republic',0,8,2000,30,'mairie');
    INSERT INTO comptes_bancaires(id,personnage,pays,banque,solde) VALUES('national','Victime','republic','nationale',1970);
    INSERT INTO ordres_couts(fn,pa,cost) VALUES('achat_test',1,50),('soin_public',0,25),('consultation_test',0,0);""")
   src=(R/'baseline/domaines/economie/20_fonctions-2.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.payer_ordre(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[a:],re.S);q.execute(src[a:a+m.end()])
   mig=(R/'migrations/20261021120540_payer_ordre_garde_incapacite.sql').read_text();q.execute(mig);q.execute(mig)
   def ok(v,t):
    nonlocal n
    assert v,t;n+=1;print('OK',t)
   def payer(fn='achat_test',pa=1,cost=50):
    q.execute('SELECT payer_ordre(%s,%s,%s,%s)',('Victime',fn,pa,cost));return q.fetchone()[0]
   def soldes():
    q.execute("SELECT pa,arg,liquide,(SELECT solde FROM comptes_bancaires WHERE id='national') FROM personnages_donnees WHERE name='Victime'");return q.fetchone()
   avant=soldes();ok(payer()['raison']=='acteur_incapacite' and soldes()==avant,'coma refuse avant PA ou mouvement financier')
   ok(payer('soin_public',0,25)['raison']=='acteur_incapacite' and soldes()==avant,'pas de faux soin payant depuis une mairie')
   q.execute("UPDATE personnages_donnees SET current_building='dispensaire-public'")
   ok(payer('soin_public',0,25)['ok'] and soldes()==(8,1975,5,1970),'debit de soin existant autorise sur place')
   ok(payer('consultation_test',0,0)['ok'],'consultation gratuite non assimilee a un effort')
   q.execute('UPDATE personnages_donnees SET hp=100')
   ok(payer()['ok'] and soldes()==(7,1925,0,1925),'achat sain : liquide puis banque et PA inchanges dans leurs regles')
   avant=soldes();ok(payer('achat_test',1,51)['raison']=='cout_non_declare' and soldes()==avant,'tarif serveur non affaibli')
   q.execute('UPDATE personnages_donnees SET pa=0');avant=soldes();ok(payer()['raison']=='pa_insuffisants' and soldes()==avant,'fonds et PA insuffisants restent sans debit partiel')
   q.execute("UPDATE personnages_donnees SET pa=8,liquide=0,arg=0;UPDATE comptes_bancaires SET solde=0")
   avant=soldes();ok(payer()['raison']=='fonds_insuffisants' and soldes()==avant,'fonds nuls sans debit PA')
  print(f'{n}/{n} scenarios PostgreSQL reussis, dependances annexes simulees.')
 finally:serveur.cleanup()
if __name__=='__main__':main()
