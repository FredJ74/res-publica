#!/usr/bin/env python3
"""Diff réel de références et achat serveur sur PostgreSQL jetable, aucun joueur réel."""
import importlib.util,json,tempfile,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def charger(n,p):
 sp=importlib.util.spec_from_file_location(n,R/p);m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);return m

def main():
 import pgserver,psycopg2
 from psycopg2.extras import Json
 # La capture brute reste privée hors Git. Le diff avant/après public suffit
 # pour reconstituer ce décor de TEST à partir du générateur (pas une preuve vivante).
 plan=json.loads((R/'outils/audits/LIVRAISON-COUTS-219-20261031.json').read_text());source=json.loads(subprocess.check_output(['python3',str(R/'outils/generateurs/generer_ordres_couts.py'),'--json'],text=True,cwd=R));canon={(x['fn'],x['pa'],x['cost']) for x in source}
 retire={(x['fn'],x['pa'],x['cost']) for x in plan['retirer']};ajoute={(x['fn'],x['pa'],x['cost']) for x in plan['ajouter']};capture=sorted((canon-ajoute)|retire)
 assert len(capture)==plan['avant']['lignes']
 base=charger('base','outils/bancs/banc-inventaire-receptions-local.py');a=charger('sources','outils/bancs/banc-audit-securite-135-local.py')
 srv=pgserver.get_server(tempfile.mkdtemp(prefix='hg-couts219-'),cleanup_mode='delete');c=psycopg2.connect(srv.get_uri());c.autocommit=True;q=c.cursor();base.initialiser(q)
 q.execute(a.fonction('baseline/domaines/economie/20_fonctions-2.sql','payer_ordre'))
 for tab in ['objets_achetables']:
  a.creer_table(q,(R/'baseline/domaines/socle/10_tables.sql').read_text(),tab);q.execute('ALTER TABLE '+tab+' ADD PRIMARY KEY(ordre)')
 q.execute(next(l for l in (R/'baseline/seeds/92_mixte/objets_modeles.sql').read_text().splitlines() if l.startswith('INSERT INTO') and "VALUES ('gilet'," in l))
 q.execute((R/'baseline/seeds/90_socle/objets_achetables.sql').read_text())
 q.execute(a.fonction('baseline/domaines/socle/20_fonctions.sql','objet_acheter'))
 q.execute("UPDATE personnages_donnees SET liquide=1000,arg=1200,pa=30,inventory='[]',inventory_revision=0 WHERE name='Fixture';DELETE FROM ordres_couts")
 q.executemany('INSERT INTO ordres_couts(fn,pa,cost) VALUES(%s,%s,%s)',capture)
 a.creer_table(q,(R/'baseline/domaines/economie/10_tables.sql').read_text(),'ordres_couts_empreinte');q.execute("INSERT INTO ordres_couts_empreinte(seul,empreinte) VALUES(true,'6de4a84c58ed9b2b')")
 n=0
 def check(v,msg):
  nonlocal n;n+=1;assert v,msg
 def photo():
  q.execute('RESET ROLE');q.execute("SELECT jsonb_build_array((SELECT jsonb_agg(to_jsonb(p) ORDER BY name) FROM personnages_donnees p),(SELECT jsonb_agg(to_jsonb(b)) FROM comptes_bancaires b))");return q.fetchone()[0]
 def achat(pa,cost=600):
  q.execute("SELECT set_config('role','authenticated',true),set_config('request.path','/rpc/objet_acheter',true),set_config('hg.uid','00000000-0000-4000-8000-000000000001',true)");q.execute("SELECT objet_acheter('acheter_gilet','gilet',%s,%s)",(pa,cost));return q.fetchone()[0]
 def matrice():q.execute('RESET ROLE;SELECT fn,pa,cost FROM ordres_couts');return set(q.fetchall())
 avant=photo();q.execute('BEGIN');v=achat(0);check(v['ok'],'ancien miroir accepte à tort zéro PA pour le gilet');q.execute('RESET ROLE');q.execute("SELECT pa FROM personnages_donnees WHERE name='Fixture'");check(q.fetchone()[0]==30,'contre-épreuve reproduit absence de PA');q.execute('ROLLBACK');check(photo()==avant,'contre-épreuve annulée')
 q.execute('BEGIN');v=achat(0,0);check(not v['ok'],'achat totalement gratuit déjà refusé : protection conservée');q.execute('ROLLBACK');check(photo()==avant,'contre-épreuve gratuite annulée')
 sql=(R/plan['migration']).read_text()
 q.execute("INSERT INTO ordres_couts VALUES('ordre_ajoute_depuis_capture',0,0)");inconnue=matrice()
 try:q.execute(sql);raise AssertionError('miroir inconnu accepté')
 except psycopg2.Error as e:check('capture_ou_sentinelle_modifiee' in str(e),'prévol refuse une nouvelle réalité')
 check(matrice()==inconnue and photo()==avant,'refus sans écrasement de tarif ni fiche');q.execute("DELETE FROM ordres_couts WHERE fn='ordre_ajoute_depuis_capture'")
 panne=sql.replace(' -- Les déclarations'," RAISE EXCEPTION 'panne_apres_suppression_fixture';\n -- Les déclarations")
 try:q.execute(panne);raise AssertionError('panne ignorée')
 except psycopg2.Error as e:check('panne_apres_suppression_fixture' in str(e),'panne réellement après les retraits')
 check(matrice()==set(capture) and photo()==avant,'annulation entière après retraits')
 q.execute(sql);check(matrice()==canon,'triplets exacts du générateur, pas seulement le nombre');check(photo()==avant,'réconciliation sans modification de fiche ou banque');q.execute('SELECT empreinte FROM ordres_couts_empreinte WHERE seul');check(q.fetchone()[0]==plan['apres']['md5'][:16],'sentinelle du contenu réellement installé')
 q.execute(sql);check(matrice()==canon and photo()==avant,'migration rejouable sans second effet')
 q.execute('BEGIN');v=achat(0);check(not v['ok'],'ancien coût zéro PA désormais refusé');q.execute('RESET ROLE');check(photo()==avant,'refus sans dépense ni objet');q.execute('ROLLBACK')
 q.execute('BEGIN');v=achat(0,0);check(not v['ok'],'la consultation gratuite ne peut pas acheter un objet payant');q.execute('ROLLBACK');check(photo()==avant,'gratuité détournée sans effet')
 q.execute('BEGIN');v=achat(1);check(v['ok'],'achat légitime conservé');q.execute('RESET ROLE');q.execute("SELECT pa,liquide,jsonb_array_length(inventory) FROM personnages_donnees WHERE name='Fixture'");check(q.fetchone()==(29,400,1),'un PA, 600 FR, un objet serveur');q.execute('ROLLBACK');check(photo()==avant,'achat fictif intégralement annulé')
 q.execute('BEGIN');v=achat(0,380);check(v['ok'],'variante déclarée 380 FR et zéro PA conservée');q.execute('RESET ROLE');q.execute("SELECT pa,liquide FROM personnages_donnees WHERE name='Fixture'");check(q.fetchone()==(30,620),'variante sans mélange PA/prix');q.execute('ROLLBACK');check(photo()==avant,'variante fictive annulée')
 for t in [('choisir_arme',1,0),('donner_argent_pnj',1,0),('corrompre_fonct',3,500),('corrompre_fonct',3,1500),('corrompre_fonct#reussite',0,500),('corrompre_fonct#reussite',0,1500)]:check(t in matrice(),'coût légitime conservé '+str(t))
 c.close();srv.cleanup();print(json.dumps({'ok':True,'assertions':n,'source_lignes':len(canon),'ancien_miroir':len(capture),'production':False,'role_achats':'authenticated','limite':'Décor de test reconstitué du diff publié ; aucun nouvel export ni contrôle vivant.'},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
