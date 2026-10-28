#!/usr/bin/env python3
"""77 cas + vrai détecteur historique et vrai calcul du coup, jamais production.
L'éligibilité judiciaire est une table fictive ; aucune prison réelle testée.
Le détecteur historique diffère du dernier MD5 vivant communiqué : preuve locale.
"""
import importlib.util,json,hashlib,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('rue',R/'outils/bancs/banc-groupes-rue-local.py');rue=importlib.util.module_from_spec(sp);sp.loader.exec_module(rue)
def suite(ctx, suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']];audit=rue.force.corps.g.audit
 sources=json.loads((R/'outils/bancs/fixtures/groupes-corps-git-20261028.json').read_text())['sources']
 for s in sources:assert hashlib.sha256(s['sql'].encode()).hexdigest()==s['sha256']
 q.execute('''ALTER TABLE personnages_donnees ADD COLUMN resources jsonb DEFAULT '{}';
 ALTER TABLE police_interceptions ADD COLUMN rencontre text,ADD COLUMN country text,ADD COLUMN city text,ADD COLUMN building text,ADD COLUMN room text,ADD COLUMN street text,ADD COLUMN intervenants jsonb;
 ALTER TABLE police_interceptions ALTER COLUMN expires_at SET DEFAULT now()+interval '5 minutes';
 CREATE TABLE police_detection_attempts(personnage text,country text,city text,building text,room text,attempted_at timestamptz,PRIMARY KEY(personnage,country,city,building,room));
 CREATE TABLE recherches_fixture(personnage text,country text);
 INSERT INTO recherches_fixture VALUES('C','republic');
 CREATE FUNCTION justice_recherches(text) RETURNS TABLE(country text) LANGUAGE sql STABLE AS $$ SELECT country FROM recherches_fixture WHERE personnage=$1 $$;''')
 q.execute(sources[1]['sql'])
 q.execute("SELECT md5(pg_get_functiondef('police_detection_verifier(text,text,text)'::regprocedure))");assert q.fetchone()[0]==sources[1]['fonction'][1]
 q.execute(audit.fonction(audit.M,'securite_ordre_detection_interne'))
 patch=(R/'migrations/20261028074753_securite_privee_detection_unites.sql').read_text();q.execute(patch);q.execute(patch)
 for nom,f in [('militaire_taux_combat','20_fonctions-3.sql'),('militaire_degre_combat','20_fonctions-2.sql'),('militaire_degats_pct','20_fonctions-2.sql'),('militaire_pa_restants','20_fonctions-2.sql')]:q.execute(audit.fonction('baseline/domaines/militaire/'+f,nom))
 q.execute(sources[2]['sql'])
 q.execute("SELECT md5(pg_get_functiondef('combat_coup_resoudre(numeric,numeric,numeric,integer,integer)'::regprocedure))");assert q.fetchone()[0]==sources[2]['fonction'][1]
 ctx['c'].commit() # seulement décor fictif, comme les bancs précédents
 def detection():return rpc('police_detection_verifier',('mairie','accueil',None),qui='C')
 def absent():
  v=detection();exige(v,'aucun_policier_present')
 cas('detecteur_historique_absence_agents_ne_cree_pas_rencontre',absent)
 cas('detecteur_historique_non_authentifie_refuse',lambda:exige(rpc('police_detection_verifier',('mairie','accueil',None),qui=None),'non_authentifie'))
 cas('detecteur_historique_fausse_piece_refuse',lambda:exige(rpc('police_detection_verifier',('mairie','autre',None),qui='C'),'position_invalide'))
 def non_recherche():
  sql("DELETE FROM recherches_fixture");exige(detection(),'non_recherche')
 cas('detecteur_historique_justice_eligibilite_refusee',non_recherche)
 def prives():
  sql("UPDATE personnages_donnees SET current_building='mairie',current_room='accueil',current_street=NULL WHERE name='A'")
  exige(rpc('pnj_rappeler_radio',('ancre',)))
  sql('UPDATE pnj_membres SET car_per=12,car_vol=12')
 def sequence():
  prives();vus=set()
  for n in range(60):
   q.execute('DELETE FROM police_interceptions');q.execute('DELETE FROM police_detection_attempts');q.execute('SELECT setseed(%s)',(n/100,))
   v=exige(detection());vus.add(v['detecte'])
   if v['detecte']:
    assert v['effectif']==2,v
    q.execute("SELECT intervenants FROM police_interceptions WHERE rencontre=%s",(v['rencontre'],));ids=q.fetchone()[0];assert sorted(ids)==['prive:ancre','prive:autre'],ids
    assert detection()['rencontre']==v['rencontre']
   else:assert detection().get('raison')=='detection_deja_tentee'
  assert vus=={True,False},vus
 cas('detecteur_historique_vrais_jets_reprise_et_tempo_sans_faux_detecteur',sequence)
 def ordre():
  agents=[{'matricule':str(i),'pa':12,'buildingId':'mairie','roomId':'accueil','groupe_id':'groupe-police'} for i in range(3)]
  agents += [{'matricule':'prive:'+str(i),'pnj_prive_id':str(i),'groupeCle':'prive-groupe','pa':12,'buildingId':'mairie','roomId':'accueil'} for i in range(4)]
  q.execute('SELECT securite_ordre_detection_interne(%s::jsonb,%s,%s,NULL)',(json.dumps(agents),'mairie','accueil'));v=q.fetchone()[0]
  assert [a['categorie'] for a in v]==[0,1] and [a['effectif'] for a in v]==[3,4],v
 cas('detecteur_moteur_ordre_police_avant_prives_meme_plus_nombreux',ordre)
 def coup():
  for pa in [0,1,12,100]:
   for _ in range(30):
    q.execute('SELECT combat_coup_resoudre(12,8,8,0,%s)',(pa,));v=q.fetchone()[0];exige(v)
    assert 1<=v['jet']<=100 and 0<=v['pa_apres']<=pa
    q.execute('SELECT militaire_taux_combat(12,8,8,0),militaire_degre_combat(%s,%s),militaire_pa_restants(%s,%s)',(v['taux'],v['jet'],pa,v['degre']));t,d,p=q.fetchone()
    assert (v['taux'],v['degre'],v['pa_apres'])==(t,d,p),v
    assert v['perte']==pa-p and v['neutralise']==(p==0)
 cas('combat_coup_authentique_reutilise_taux_degres_et_degats_militaires',coup)
 def parametres():
  for pa in [-1,100001,None]:
   q.execute('SELECT combat_coup_resoudre(12,8,8,0,%s)',(pa,));exige(q.fetchone()[0],'parametres_invalides')
 cas('combat_coup_authentique_refuse_parametres_invalides',parametres)
 def prive():
  for role in ['anon','authenticated']:
   q.execute("SELECT has_function_privilege(%s,'combat_coup_resoudre(numeric,numeric,numeric,integer,integer)','EXECUTE')",(role,));assert q.fetchone()[0] is False
 cas('combat_coup_authentique_primitif_inaccessible_au_client',prive)
 ctx['preuves_extension']['detecteur']='Corps historique Git, pas le dernier relevé vivant ; justice éligibilité fictive, vrai hasard PostgreSQL.'
 ctx['preuves_extension']['combat']='Calcul du coup authentique et dépendances militaires, pas un round mixte ni une détention.'
 if suivante is not None:suivante(ctx)
if __name__=='__main__':
 f=rue.force
 sys.exit(f.corps.g.main(lambda c:f.corps.extension(c,lambda c:f.suite(c,lambda c:rue.suite(c,suite)))))
