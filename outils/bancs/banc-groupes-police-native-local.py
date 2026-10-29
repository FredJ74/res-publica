#!/usr/bin/env python3
"""Après les transports : vrais RPC policiers historiques et coups, pas de stub judiciaire."""
import importlib.util,re,json,hashlib,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sp=importlib.util.spec_from_file_location('voyages',R/'outils/bancs/banc-groupes-voyages-local.py');v=importlib.util.module_from_spec(sp);sp.loader.exec_module(v)
def suite(ctx,suivante=None):
 q,cas,rpc,exige,sql=[ctx[x] for x in ['q','cas','rpc','exige','sql']]
 q.execute('ALTER TABLE police_interceptions ADD COLUMN IF NOT EXISTS fuite_tentee boolean NOT NULL DEFAULT false')
 q.execute('ALTER TABLE police_interceptions ADD PRIMARY KEY(personnage)')
 q.execute('ALTER TABLE batiments_etat ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now()')
 source=json.loads((R/'outils/bancs/fixtures/groupes-police-corps-git-20261028.json').read_text())
 assert hashlib.sha256(source['sql'].encode()).hexdigest()==source['sha256']
 q.execute(source['table_rounds']['definition'])
 q.execute(re.search(r'CREATE TABLE IF NOT EXISTS public.police_action_receipts \(.*?\n\);',source['sql'],re.S)[0])
 fonctions=list(re.finditer(r'CREATE OR REPLACE FUNCTION public\.\w+\(.*?AS (\$\w*\$).*?\1\s*;',source['sql'],re.S));assert len(fonctions)==5
 for fn in fonctions:q.execute(fn[0])
 # ACL de portes imposées dans le décor, comparaison au vivant encore requise.
 for sig in ['police_combat_resoudre(text,text,text,text,integer)','police_fuite_resoudre(text)','police_reddition_resoudre(text)']:
  q.execute('REVOKE ALL ON FUNCTION '+sig+' FROM PUBLIC,anon,authenticated,service_role');q.execute('GRANT EXECUTE ON FUNCTION '+sig+' TO authenticated')
 ctx['installer_fonction_canonique']('recherche_inscrire')
 q.execute((R/'migrations/20261028074754_securite_privee_combat_pa_et_registre.sql').read_text())
 nouveau=R/'migrations/20261029100000_groupes_miroirs_statuts_et_pa.sql'
 # Donnée historique antérieure à la bascule, pas un dégât inventé après elle.
 q.execute("UPDATE batiments_etat SET data=jsonb_set(data,'{effectifsPolice,policiers}',(SELECT jsonb_agg(CASE WHEN p->>'matricule'='P2' THEN p||'{\"pa\":5}'::jsonb ELSE p END) FROM jsonb_array_elements(data->'effectifsPolice'->'policiers') p)) WHERE id='capitale'")
 if '--contre-etats-miroir' not in sys.argv:q.execute(nouveau.read_text());q.execute(nouveau.read_text())
 ctx['c'].commit()
 def import_initial():
  q.execute("SELECT pa FROM pnj_membres WHERE id='police-republic-capitale-P2'");assert q.fetchone()[0]==5,'PA historiques non repris au premier passage'
 cas('police_PA_historiques_importes_une_seule_fois',import_initial)
 def mort():
  q.execute("SELECT pnj_mourir('police-republic-capitale-P1','fixture')");exige(q.fetchone()[0])
  q.execute("SELECT pnj_miroir_police('republic','capitale','commissariat')")
  q.execute("SELECT statut FROM pnj_membres WHERE id='police-republic-capitale-P1'");assert q.fetchone()[0]=='mort','PNJ ressuscité par le miroir'
  q.execute("SELECT count(*) FROM batiments_etat b CROSS JOIN LATERAL jsonb_array_elements(b.data->'effectifsPolice'->'policiers') p WHERE b.id='capitale' AND p->>'matricule'='P1'");assert q.fetchone()[0]==0
 cas('police_miroir_ne_ressuscite_pas_mort_ni_ne_le_garde_dans_effectif',mort)
 def detenu():
  sql("UPDATE pnj_membres SET statut='detenu' WHERE id='police-republic-capitale-P1'")
  q.execute("SELECT pnj_miroir_police('republic','capitale','commissariat')")
  q.execute("SELECT statut FROM pnj_membres WHERE id='police-republic-capitale-P1'");assert q.fetchone()[0]=='detenu'
 cas('police_miroir_ne_libere_pas_un_detenu',detenu)
 def douane_detenu():
  sql("UPDATE pnj_membres SET statut='detenu' WHERE id='douane-republic-ville_a-D1'")
  q.execute("SELECT pnj_miroir_douane('republic','ville_a','port-sainte-marie')")
  q.execute("SELECT statut FROM pnj_membres WHERE id='douane-republic-ville_a-D1'");assert q.fetchone()[0]=='detenu','Douanier détenu réactivé par le miroir'
 cas('douane_miroir_ne_libere_pas_un_detenu',douane_detenu)
 def pa_stables():
  sql("UPDATE pnj_membres SET pa=0 WHERE id='police-republic-capitale-P2'")
  q.execute("SELECT pnj_groupes_projeter_institutions_interne(ARRAY['police-republic-capitale-P2'])")
  q.execute("SELECT p->>'pa' FROM batiments_etat b CROSS JOIN LATERAL jsonb_array_elements(b.data->'effectifsPolice'->'policiers') p WHERE b.id='capitale' AND p->>'matricule'='P2'");assert q.fetchone()[0]=='0'
  q.execute(nouveau.read_text())
  q.execute("SELECT pa FROM pnj_membres WHERE id='police-republic-capitale-P2'");assert q.fetchone()[0]==0
 cas('police_pa_zero_projete_sans_reimport_au_rejeu',pa_stables)
 def deux_rounds():
  sql("UPDATE personnages_donnees SET country='republic',current_city='capitale',current_building='mairie',current_room='accueil',current_street=NULL,hp=100,pa=100,stats='{\"VOL\":15,\"PER\":15}',resources='{\"dis\":0}' WHERE name IN ('A','B','C')")
  sql("INSERT INTO jugements(id,country,city,accuse,motif,data,executee) VALUES('jugement-combat-fixture','republic','capitale','C','Peine fictive','{\"motifs\":[{\"jours\":2}]}',false)")
  q.execute("SELECT pnj_groupes_projeter_interne(ARRAY['police-republic-capitale-P1','police-republic-capitale-P2','police-republic-capitale-P3'])")
  succes=False
  for seed in range(30):
   q.execute('SAVEPOINT rounds_police');q.execute('SELECT setseed(%s)',(seed/30,))
   try:
    detection=exige(rpc('police_detection_verifier',('mairie','accueil',None),qui='C'))
    if not detection.get('detecte'):continue
    rencontre=detection['rencontre'];un=exige(rpc('police_combat_resoudre',(rencontre,None,'mairie','accueil',1),qui='C'))
    if un.get('arrestation') or un.get('police_neutralisee'):continue
    deux=exige(rpc('police_combat_resoudre',(rencontre,None,'mairie','accueil',2),qui='C'))
    q.execute("SELECT m.id,m.pa,(p->>'pa')::integer FROM pnj_membres m JOIN batiments_etat b ON b.id='capitale' CROSS JOIN LATERAL jsonb_array_elements(b.data->'effectifsPolice'->'policiers') p WHERE m.id=police_pnj_id(b.country,b.city,p->>'matricule') ORDER BY m.id")
    etats=q.fetchall();assert len(etats)==3 and all(pa==miroir for _,pa,miroir in etats),etats
    q.execute("SELECT pa FROM personnages_donnees WHERE name='C'");assert q.fetchone()[0]==deux['pa']
    assert rpc('police_combat_resoudre',(rencontre,None,'mairie','accueil',2),qui='C')==deux
    q.execute('SELECT count(*) FROM police_action_receipts WHERE personnage=%s AND rencontre=%s AND action=\'combat\'',('C',rencontre));assert q.fetchone()[0]==2
    q.execute("SELECT count(*) FROM personnages_donnees d CROSS JOIN LATERAL jsonb_array_elements(d.recherche) r WHERE d.name='C' AND r->>'id'=%s",('rebellion-police:'+rencontre,));assert q.fetchone()[0]==1
    succes=True;break
   finally:q.execute('ROLLBACK TO SAVEPOINT rounds_police')
  assert succes,'aucun scénario de deux rounds réels obtenu'
 cas('police_deux_rounds_historiques_reels_detection_justice_et_PA_sans_stub',deux_rounds)
 ctx['police_deux_rounds_reels']=deux_rounds
 if suivante is not None:suivante(ctx)
if __name__=='__main__':sys.exit(v.d.i.lancer(lambda c:v.d.suite(c,lambda c:v.suite(c,suite))))
