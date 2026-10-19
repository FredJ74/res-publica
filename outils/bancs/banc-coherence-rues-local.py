#!/usr/bin/env python3
"""Controle SQL existant, graphes jetables ; aucun graphe de production modifie."""
from pathlib import Path
import tempfile

def main():
 import pgserver,psycopg2
 r=Path(__file__).resolve().parents[2];serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-rues-'),cleanup_mode='delete')
 c=psycopg2.connect(serveur.get_uri());c.autocommit=True;q=c.cursor()
 q.execute('CREATE TABLE rue_noeuds_serveur(country text,city text,noeud text,voisins text[]);CREATE TABLE rue_sorties_batiments(country text,city text,building text,noeud text)')
 s=(r/'outils/bancs/controle-coherence-rues-sorties.sql').read_text();debut=s.index('WITH anomalies AS');fin=s.rindex('ROLLBACK;');requete=s[debut:fin]
 assert 'BEGIN;' in s[:debut] and 'SET TRANSACTION READ ONLY;' in s[:debut]
 def controle():
  q.execute('BEGIN;SET TRANSACTION READ ONLY;'+requete);rows=q.fetchall();q.execute('ROLLBACK');return rows
 q.execute("INSERT INTO rue_noeuds_serveur VALUES ('republic','capitale','A',ARRAY['B']),('republic','capitale','B',ARRAY['A']);INSERT INTO rue_sorties_batiments VALUES ('republic','capitale','mairie','A')")
 assert controle()==[];n=1
 q.execute("UPDATE rue_noeuds_serveur SET voisins=ARRAY['B','B','A','Z'] WHERE noeud='A';UPDATE rue_noeuds_serveur SET voisins=ARRAY[]::text[] WHERE noeud='B';UPDATE rue_sorties_batiments SET noeud='absent'")
 assert {x[0] for x in controle()}=={'voisin_inexistant','retour_absent','boucle_sur_soi','sortie_sans_noeud','voisin_duplique'};n+=1
 # NULL signifie ici aucune liaison retour, pas un resultat logique indetermine a ignorer.
 q.execute("UPDATE rue_noeuds_serveur SET voisins=ARRAY['B'] WHERE noeud='A';UPDATE rue_noeuds_serveur SET voisins=NULL WHERE noeud='B';UPDATE rue_sorties_batiments SET noeud='A'")
 assert [x[0] for x in controle()]==['retour_absent'];n+=1
 q.execute("UPDATE rue_noeuds_serveur SET voisins=ARRAY['A'] WHERE noeud='B';INSERT INTO rue_sorties_batiments VALUES ('republic','ville_a','mairie','A')")
 rows=controle();assert len(rows)==1 and rows[0][0]=='sortie_sans_noeud' and rows[0][2]=='ville_a';n+=1
 avant=rows;q.execute('BEGIN;SET TRANSACTION READ ONLY')
 try:q.execute('DELETE FROM rue_noeuds_serveur');raise AssertionError('ecriture interdite attendue')
 except psycopg2.Error as e:assert e.pgcode=='25006'
 q.execute('ROLLBACK');assert controle()==avant;n+=1
 c.close();serveur.cleanup();print(f'{n}/{n} groupes coherence rues SQL reussis ; aucune production.')
if __name__=='__main__':main()
