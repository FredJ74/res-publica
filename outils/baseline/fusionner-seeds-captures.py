#!/usr/bin/env python3
"""Prépare une entrée de seeds complète, sans prétendre réextraire les anciens.

Les INSERT déjà versionnés sont contrôlés par leur manifeste et analysés avec
le parser PostgreSQL. La capture remplace une TABLE entière, jamais quelques
lignes choisies. Le rendu reste exclusivement celui de seeds.py.
"""
import argparse
import hashlib
import json
from pathlib import Path
from reconstruire import decouper
import seeds


def fusionner(capture):
    nouveau=json.loads(Path(capture).read_text())
    if not isinstance(nouveau,dict) or not isinstance(nouveau.get('export_seeds'),list):
        raise ValueError('Capture de seeds complète attendue')
    controles={x['table']:x for x in nouveau.get('seeds_controle',[])}
    lignes=nouveau['export_seeds'];remplacees={x['tbl'] for x in lignes}
    # Le relais canonique a déjà validé les comptes. Contrôle répété ici pour
    # empêcher qu'une capture amputée remplace silencieusement une table.
    if not controles or set(controles)!=remplacees:
        raise ValueError('Comptes par table absents ou incohérents')
    for table in remplacees:
        c=controles[table]
        nombre=c.get('lignes',c.get('count',c.get('nombre')))
        if nombre is None or int(nombre)!=sum(x['tbl']==table for x in lignes):
            raise ValueError('Compte de capture incohérent : '+table)
    base=Path(seeds.CIBLE);inv=json.loads((base/'INVENTAIRE.json').read_text())
    sortie=[];provenance={}
    for nom,empreinte in sorted(inv['fichiers'].items()):
        p=base/nom;texte=p.read_text()
        if hashlib.md5(texte.encode()).hexdigest()!=empreinte:
            raise ValueError('Ancien seed retouché : '+nom)
        table=p.stem
        if table in remplacees:continue
        rang=0
        for ast,sql in decouper(texte):
            if type(ast).__name__!='InsertStmt':continue
            if ast.relation.relname!=table or ast.relation.schemaname!='public':
                raise ValueError('INSERT hors table déclarée : '+nom)
            rang+=1;sortie.append({'tbl':table,'rang':rang,'ligne':sql})
        if rang:provenance[table]={'origine':'seed_versionne_anterieur','lignes':rang,'md5_source':empreinte}
    sortie.extend(lignes)
    for table in remplacees:provenance[table]={'origine':'capture_canonique','lignes':sum(x['tbl']==table for x in lignes)}
    return {'export_seeds':sorted(sortie,key=lambda x:(x['tbl'],x['rang'])),'provenance':provenance}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',required=True);p.add_argument('--sortie',required=True);a=p.parse_args()
    v=fusionner(a.capture);Path(a.sortie).write_text(json.dumps(v,ensure_ascii=False)+'\n')
    print(str(len(v['provenance']))+' tables préparées ; provenance conservée, aucune base modifiée.')
