#!/usr/bin/env python3
"""Precondition de succession #69 : droits/policies archives sur un PostgreSQL jetable.

Echec si un autre joueur authentifie peut reecrire les beneficiaires d'un dossier.
Ce verdict porte sur le baseline, jamais sur une production inaccessible.
"""
from pathlib import Path
import re,tempfile,json
R=Path(__file__).resolve().parents[2]
def main():
 import pgserver,psycopg2
 server=pgserver.get_server(tempfile.mkdtemp(prefix='hg-autorite-succession69-'),cleanup_mode='delete')
 try:
  with psycopg2.connect(server.get_uri()) as db:
   c=db.cursor();c.execute("CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;CREATE FUNCTION mon_personnage() RETURNS text LANGUAGE sql AS $$SELECT 'Tiers-fixture'::text$$")
   def fn(nom):
    src=(R/'baseline/domaines/socle/20_fonctions.sql').read_text();a=src.index('CREATE OR REPLACE FUNCTION public.'+nom+'(');m=re.search(r'AS (\$\w*\$)(.*?)\1;',src[a:],re.S);c.execute(src[a:a+m.end()])
   fn('est_appel_serveur');fn('acteur_identifie')
   src=(R/'baseline/domaines/personnage-et-presence/10_tables.sql').read_text();c.execute(re.search(r'CREATE TABLE public.successions \(.*?\n\);',src,re.S)[0]);c.execute('ALTER TABLE successions ENABLE ROW LEVEL SECURITY')
   declencheurs=(R/'baseline/domaines/personnage-et-presence/50_triggers.sql').read_text()
   if re.search(r'CREATE TRIGGER[^;]* ON (?:public\.)?successions\b',declencheurs,re.S):raise RuntimeError('Un declencheur successoral exige une reconstruction plus complete ; aucune conclusion positive autorisee.')
   src=(R/'baseline/domaines/personnage-et-presence/60_rls-policies.sql').read_text()
   policies=re.findall(r'CREATE POLICY .*? ON public\.successions .*?;',src,re.S)
   # Ne pas capturer les policies des tables precedentes.
   policies=[p[p.rfind('CREATE POLICY '):] for p in policies]
   assert policies,'aucune policy examinee : audit invalide'
   for p in policies:c.execute(p)
   src=(R/'baseline/domaines/personnage-et-presence/70_droits.sql').read_text()
   # Le role exerce est authenticated ; ne pas charger les privileges de maintenance du proprietaire.
   droits=[l for l in src.splitlines() if l.startswith('GRANT ') and ' ON TABLE public.successions ' in l and l.endswith(' TO authenticated;')]
   assert droits,'aucun droit examine : audit invalide'
   for d in droits:c.execute(d)
   c.execute("INSERT INTO successions(id,defunt,country,dispositions) VALUES('dossier-fixture','Defunt-fixture','republic','[{\"type\":\"argent\",\"id\":\"part-1\",\"resultat\":{\"beneficiaire\":\"Heritier-fixture\"}}]')");db.commit()
   refuse=False
   try:
    c.execute('SET ROLE authenticated')
    c.execute("UPDATE successions SET dispositions='[{\"type\":\"argent\",\"id\":\"part-1\",\"resultat\":{\"beneficiaire\":\"Tiers-fixture\"}}]' WHERE id='dossier-fixture'")
    refuse=c.rowcount==0
   except psycopg2.errors.InsufficientPrivilege:refuse=True
   finally:db.rollback()
   print(json.dumps({'source':'baseline PostgreSQL archive','production_verifiee':False,'tiers_authentifie_refuse':refuse,'precondition_succession_coffres':refuse},ensure_ascii=False))
   if not refuse:
    print('ECHEC : les droits/policies archives permettent au tiers de reecrire les beneficiaires. Ne pas activer le transfert des coffres sur ce socle non verifie.')
    return 1
   print('OK : le tiers ne peut pas reecrire ce dossier selon les droits/policies examines.');return 0
 finally:server.cleanup()
if __name__=='__main__':raise SystemExit(main())
