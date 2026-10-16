#!/usr/bin/env python3
"""Index statique des acces persistants et miroirs ; ni preuve RLS ni analyseur JS.

python3 outils/auditer-etats-client.py [--json]
Les appels dynamiques et les mutations indirectes doivent etre revus separement.
"""
import json
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parent.parent
def main():
    resultat={'nature':'Index de code local, sans connexion ni donnees de joueurs.',
              'tables':[], 'rpc':[], 'miroirs':[], 'fusions':[]}
    for p in sorted(list(ROOT.glob('*.js'))+list((ROOT/'api').glob('*.js'))):
        src=p.read_text()
        for motif,cle in [
            (r"\b(sbGet|sbGetVerdict|sbUpdate|sbInsert|sbDelete|sbUpsert|sbPatcherBlob)\(\s*['\"]([a-z_0-9]+)['\"]",'tables'),
            (r"\b(sbRpc|sbRpcVerdict|sbTransportRpc)\(\s*['\"]([a-z_0-9]+)['\"]",'rpc'),
            (r'\bstate\.([a-zA-Z_][a-zA-Z_0-9]*)\s*(\+=|-=|\*=|/=|=(?!=|>))','miroirs'),
            (r'Object\.assign\(state\s*,','fusions')]:
            for m in re.finditer(motif,src):
                entree={'fichier':str(p.relative_to(ROOT)),'ligne':src.count('\n',0,m.start())+1}
                if m.lastindex:entree['cible']=m.group(2) if cle in ('tables','rpc') else m.group(1)
                resultat[cle].append(entree)
    catalogue=set()
    hors_circuit={}
    for dossier in ('baseline/domaines','historique/migrations-appliquees','migrations','sql','historique/sql-hors-registre'):
        for p in (ROOT/dossier).rglob('*.sql'):
            fonctions=re.findall(r'CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+public\.([a-z_0-9]+)',p.read_text(),re.I)
            catalogue.update(fonctions)
            if dossier in ('sql','historique/sql-hors-registre'):
                for nom in fonctions:hors_circuit[nom]=str(p.relative_to(ROOT))
    resultat['rpcSansDefinitionLocale']=sorted(set(r['cible'] for r in resultat['rpc'])-catalogue)
    resultat['rpcDefinitionsHorsRegistre']={k:v for k,v in hors_circuit.items() if k in {r['cible'] for r in resultat['rpc']}}
    if '--json' in sys.argv:print(json.dumps(resultat,ensure_ascii=False,indent=2))
    else:
        for cle in ('tables','rpc','miroirs','fusions'):print(cle,':',len(resultat[cle]),'occurrences de code')
        print('RPC litterales sans definition locale : '+', '.join(resultat['rpcSansDefinitionLocale']))
        print('Definitions retrouvees hors registre : '+', '.join(resultat['rpcDefinitionsHorsRegistre']))
        print('Commentaires inclus ; index indicatif, aucune preuve de fonctionnement ou de presence en base.')
if __name__=='__main__':main()
