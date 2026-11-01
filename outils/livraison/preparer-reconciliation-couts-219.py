#!/usr/bin/env python3
"""Prépare un delta contrôlé depuis la capture et les sources ; aucune connexion."""
import argparse,hashlib,importlib.util,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
def preparer(capture,sortie=None):
 p=Path(capture);d=json.loads(p.read_text())
 empreinte_capture=hashlib.sha256(p.read_bytes()).hexdigest()
 captures={
  '7a68fd5dc6d9dabf1e51ea3f6cadbd6d4074f93f2014ab028909fa5dab002575':('346064:346064:',438,452,25,39),
  'fcb2d4d2c27026597de9dc2fb1a1545db001a7ba0cfcf305cfea49f5b4ac3aee':('351194:351194:',439,460,26,47),
 }
 if empreinte_capture not in captures:raise ValueError('Capture indépendante examinée exacte requise')
 snapshot,n_avant,n_apres,n_retirer,n_ajouter=captures[empreinte_capture]
 if d.get('snapshot')!=snapshot:raise ValueError('Snapshot différent de la capture examinée')
 sp=importlib.util.spec_from_file_location('diffcouts',R/'outils/baseline/comparer-couts-captures.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
 source=json.loads(subprocess.check_output([sys.executable,str(R/'outils/generateurs/generer_ordres_couts.py'),'--json'],cwd=R,text=True));avant=m.triples(d['ordres_couts']);apres=m.triples(source)
 if len(avant)!=n_avant:raise ValueError('Cardinalité différente de la capture examinée')
 empreinte=lambda t:hashlib.md5('\n'.join('%s|%d|%d'%r for r in sorted(t)).encode()).hexdigest()
 h1,h2=empreinte(avant),empreinte(apres)
 retirer=sorted(avant-apres);ajouter=sorted(apres-avant)
 if len(retirer)!=n_retirer or len(ajouter)!=n_ajouter or len(apres)!=n_apres:raise ValueError('Le diff a changé : réexaminer chaque tarif, ne pas appliquer un ancien plan')
 valeurs=lambda ts:',\n'.join("('"+fn.replace("'","''")+"',"+str(pa)+','+str(cost)+')' for fn,pa,cost in ts)
 calcul="SELECT md5(string_agg(fn||'|'||pa||'|'||cost,E'\\n' ORDER BY fn COLLATE \"C\",pa,cost)) FROM public.ordres_couts"
 sql="""-- PRÉPARATION NON APPLIQUÉE : rapprochement exhaustif de tarifs existants.
-- Capture indépendante examinée ; sources du générateur, aucun montant inventé.
-- Ne touche ni aux personnages, ni aux comptes, ni aux fonctions financières.
DO $couts219$
DECLARE h text;apres text;n integer;sentinelle text;
BEGIN
 LOCK TABLE public.ordres_couts IN SHARE ROW EXCLUSIVE MODE;
 SELECT count(*) INTO n FROM public.ordres_couts;
 h:=("""+calcul+""");
 SELECT empreinte INTO STRICT sentinelle FROM public.ordres_couts_empreinte WHERE seul;
 IF h='"""+h2+"""' AND n="""+str(n_apres)+""" THEN
  IF sentinelle<>left(h,16) THEN RAISE EXCEPTION 'couts219_sentinelle_incoherente_apres_installation';END IF;
  RETURN;
 END IF;
 IF h IS DISTINCT FROM '"""+h1+"""' OR n<>"""+str(n_avant)+""" OR sentinelle<>'6de4a84c58ed9b2b' THEN RAISE EXCEPTION 'couts219_capture_ou_sentinelle_modifiee_prevol_requis';END IF;
 DELETE FROM public.ordres_couts c USING (VALUES
"""+valeurs(retirer)+""") v(fn,pa,cost) WHERE (c.fn,c.pa,c.cost)=(v.fn,v.pa,v.cost);
 -- Les déclarations viennent des sources, pas d'une duplication de la capture privée.
 INSERT INTO public.ordres_couts(fn,pa,cost) VALUES
"""+valeurs(ajouter)+""" ON CONFLICT DO NOTHING;
 apres:=("""+calcul+""");
 IF apres IS DISTINCT FROM '"""+h2+"""' OR (SELECT count(*) FROM public.ordres_couts)<>"""+str(n_apres)+""" THEN RAISE EXCEPTION 'couts219_resultat_different_source';END IF;
 -- Sentinelle posée SEULEMENT après modification réelle et comparaison complète.
 UPDATE public.ordres_couts_empreinte SET empreinte=left(apres,16),pose_le=now() WHERE seul;
 IF NOT FOUND THEN RAISE EXCEPTION 'couts219_sentinelle_absente';END IF;
END $couts219$;
"""
 if sortie:Path(sortie).write_text(sql)
 return sql,{'avant':{'lignes':len(avant),'md5':h1},'apres':{'lignes':len(apres),'md5':h2},'retirer':[dict(zip(('fn','pa','cost'),t)) for t in retirer],'ajouter':[dict(zip(('fn','pa','cost'),t)) for t in ajouter]}
if __name__=='__main__':
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--capture',required=True);a.add_argument('--sortie');o=a.parse_args();_,r=preparer(o.capture,o.sortie);print(json.dumps(r,ensure_ascii=False,indent=2))
