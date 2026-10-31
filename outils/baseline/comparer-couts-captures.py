#!/usr/bin/env python3
"""Diff de contenu en lecture seule : ni empreintes ni baseline ne sont réécrits."""
import argparse,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
REQUETE="""BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SELECT jsonb_build_object('snapshot',pg_current_snapshot()::text,'releve_utc',now(),
 'ordres_couts',(SELECT jsonb_agg(to_jsonb(x) ORDER BY fn,pa,cost)
 FROM (SELECT fn,pa,cost FROM public.ordres_couts) x));
ROLLBACK;"""

def triples(lignes):
    if not isinstance(lignes,list):raise ValueError('Liste de triples requise, pas une empreinte')
    sortie=set()
    for l in lignes:
        if not isinstance(l,dict) or set(l)!={'fn','pa','cost'} or not isinstance(l['fn'],str) or not l['fn'] or any(type(l[k]) is not int for k in ('pa','cost')):
            raise ValueError('Triple fn/pa/cost invalide : aucun arrondi ni valeur implicite')
        t=(l['fn'],l['pa'],l['cost'])
        if t in sortie:raise ValueError('Triple dupliqué dans la capture')
        sortie.add(t)
    return sortie

def comparer(source,capture):
    a,b=triples(source),triples(capture)
    vers=lambda s:[dict(zip(('fn','pa','cost'),v)) for v in sorted(s)]
    return {'lecture_seule':True,'source_lignes':len(a),'capture_lignes':len(b),'difference_nette':len(b)-len(a),
            'communs':len(a&b),'capture_seulement':vers(b-a),'source_seulement':vers(a-b),
            'coherents':a==b,
            'limite':'Les écarts nets ne prouvent ni onze lignes manquantes ni une décision de gameplay. Chaque différence exige sa provenance.'}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--requete',action='store_true');p.add_argument('--capture',type=Path);o=p.parse_args()
    if o.requete:print(REQUETE);return 0
    if not o.capture:p.error('--capture ou --requete requis')
    capture=json.loads(o.capture.read_text())
    if not isinstance(capture,dict) or not capture.get('snapshot') or not capture.get('releve_utc'):raise ValueError('Capture datée et snapshot requis')
    source=json.loads(subprocess.check_output([sys.executable,str(R/'outils/generateurs/generer_ordres_couts.py'),'--json'],text=True,cwd=R))
    r=comparer(source,capture['ordres_couts']);r['snapshot']=capture['snapshot'];r['releve_utc']=capture['releve_utc'];print(json.dumps(r,ensure_ascii=False,indent=2));return 0 if r['coherents'] else 1
if __name__=='__main__':raise SystemExit(main())
