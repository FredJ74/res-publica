#!/usr/bin/env python3
"""Actualise les attentes depuis les exports, jamais depuis le SQL rendu.

Ne change aucune empreinte observée et ne touche à aucun fichier SQL.
"""
import argparse
import hashlib
import json
from pathlib import Path
import rendre


def actualiser(repertoire):
    exp,fichiers=rendre.charger_exports(repertoire)
    domaines,strategies,_=rendre.charger_classification()
    conf=json.loads(Path(rendre.CONF).read_text())
    origine={Path(nom).name:hashlib.sha256((Path(repertoire)/nom).read_bytes()).hexdigest() for nom,_,_ in fichiers}
    racine=Path(rendre.RACINE)
    def sauver(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=1)+'\n')
    n={'noms_fonctions':len({f['proname'] for f in exp['fonctions']}),
       'sequences':len([s for s in exp['sequences'] if strategies.get(s.get('tbl'))!='hors_baseline']),
       'origine_exports_sha256':origine}
    sauver(racine/'baseline/ATTENTES-RECONSTRUCTION.json',n)
    for p in (racine/'baseline/domaines').glob('*/CONTROLE.json'):
        ctl=json.loads(p.read_text());d=ctl['domaine']
        tables={t for t,v in domaines.items() if v==d and strategies[t]!='hors_baseline'}
        vues={t for t,v in rendre.DOMAINE_DES_VUES.items() if v==d}
        f=[f for f in exp['fonctions'] if rendre.domaine_fonction(f['proname'],conf)==d]
        signatures={x['signature'] for x in f}
        sequences={s['sequence'] for s in exp['sequences'] if s.get('tbl') in tables}
        att=ctl['attendu']
        att.update(tables=len({c['tbl'] for c in exp['colonnes'] if c['kind']=='r' and c['tbl'] in tables}),
                   colonnes=sum(c['tbl'] in tables and c['kind']=='r' for c in exp['colonnes']),
                   fonctions=len(f),index_autonomes=sum(x['tbl'] in tables and not x.get('contrainte') for x in exp['index']),
                   rls_actives=sum(x['tbl'] in tables and x.get('active',x.get('rls_active',False)) for x in exp['rls']),
                   droits_colonnes=sum(x['tbl'] in tables for x in exp['droits_colonnes']))
        for categorie in ('contraintes','index','triggers','policies'):
            att[categorie]=sum(x['tbl'] in tables for x in exp[categorie])
        att['lignes_droits']=sum(x['objet'] in tables|vues|sequences for x in exp['droits_relations'])+sum(x['objet'] in signatures for x in exp['droits_fonctions'])
        sec=ctl['securite_attendue'];sec['fonctions_security_definer']=sum(x['security_definer'] for x in f)
        sec['fonctions_security_invoker']=len(f)-sec['fonctions_security_definer']
        fermees=sorted({x['tbl'] for x in exp['rls'] if x['tbl'] in tables and x.get('active',x.get('rls_active',False))}-{x['tbl'] for x in exp['policies']})
        sec['tables_rls_active_sans_policy']=len(fermees);sec['tables_rls_active_sans_policy_liste']=fermees
        ctl['empreinte_fonctions']=hashlib.md5('|'.join(sorted(x['signature']+':'+x['empreinte'] for x in f)).encode()).hexdigest()
        ctl['source_actualisation']={'exports_sha256':origine,'methode':'Mesures des exports canoniques ; aucune attente déduite du MANIFESTE ou du rendu SQL.'}
        sauver(p,ctl)


if __name__=='__main__':
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('exports');actualiser(a.parse_args().exports)
