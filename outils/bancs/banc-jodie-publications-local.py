#!/usr/bin/env python3
"""Triggers reels sur PostgreSQL local ; aucun compte ou entretien reel."""
from pathlib import Path
import tempfile
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 serveur=pgserver.get_server(tempfile.mkdtemp(prefix='hg-jodie-'),cleanup_mode='delete')
 with psycopg2.connect(serveur.get_uri()) as c:
  c.autocommit=True;q=c.cursor()
  q.execute("CREATE ROLE anon; CREATE ROLE authenticated;")
  for domaine,tables in [('communication',['forum_topics','forum_posts']),('presse',['interviews_jodie','journal_articles_en_attente'])]:
   src=(R/f'baseline/domaines/{domaine}/10_tables.sql').read_text()
   for table in tables:
    a=src.index('CREATE TABLE public.'+table+' (');b=src.index('\n);',a)+3;q.execute(src[a:b]);q.execute(f'ALTER TABLE {table} ADD PRIMARY KEY (id)')
  q.execute('ALTER TABLE interviews_jodie ENABLE ROW LEVEL SECURITY')
  migration=next((R/'migrations').glob('*_jodie_interview_forum_atomique.sql'));q.execute(migration.read_text());q.execute(migration.read_text())
  q.execute((R/'historique/migrations-appliquees/rehorodatees-219/20261031113556_jodie_portraits_forum_journal.sql').read_text())
  q.execute("INSERT INTO interviews_jodie(id,personnage,country) VALUES ('banc','Alice','republic')")
  q.execute('SELECT count(*) FROM forum_topics');assert q.fetchone()[0]==0
  q.execute("UPDATE interviews_jodie SET publie=true,article_titre='Entretien',article_texte='<script>texte du joueur</script>',publie_le=now() WHERE id='banc'")
  q.execute('SELECT content FROM forum_posts');assert q.fetchone()[0]=='&lt;script&gt;texte du joueur&lt;/script&gt;'
  q.execute("UPDATE interviews_jodie SET article_titre='Titre confirme' WHERE id='banc'")
  q.execute('SELECT count(*) FROM forum_topics');assert q.fetchone()[0]==1
  q.execute('SELECT count(*) FROM journal_articles_en_attente');assert q.fetchone()[0]==0 # pas de doublon de la source interviews_jodie
  q.execute("INSERT INTO forum_topics(id,forum_id,title,author,country) VALUES ('portrait','presse','Un jour, un portrait : Alice','Jodie Moitout','republic')")
  q.execute("INSERT INTO forum_posts(id,topic_id,author,content) VALUES ('portrait-post','portrait','Jodie Moitout',repeat('Reponse authentique. ',5))")
  q.execute('SELECT count(*) FROM journal_articles_en_attente');assert q.fetchone()[0]==1
  q.execute("CREATE FUNCTION panne_forum() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'panne_fixture';END$$;CREATE TRIGGER panne_forum BEFORE INSERT ON forum_posts FOR EACH ROW EXECUTE FUNCTION panne_forum()")
  try:q.execute("UPDATE interviews_jodie SET article_titre='Ne doit pas rester' WHERE id='banc'");raise AssertionError('panne attendue')
  except psycopg2.Error as e:assert 'panne_fixture' in str(e)
  q.execute("SELECT article_titre FROM interviews_jodie WHERE id='banc'");assert q.fetchone()[0]=='Titre confirme'
 serveur.cleanup();print('6/6 groupes PostgreSQL reussis : deux supports, idempotence, texte conserve, echappement, absence de doublon et rollback. Aucun Supabase.')
if __name__=='__main__':main()
