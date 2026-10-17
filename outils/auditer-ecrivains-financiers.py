#!/usr/bin/env python3
"""Cartographie de candidats a examiner, PAS une certification d'atomicite ni du serveur vivant."""
import json,re,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
champs=r'arg|liquide|banque|solde|montant_restant|montant_initial|mensualite|caisse|reserveJour'
sql=[];js=[]
for p in sorted((ROOT/'baseline/domaines').glob('*/*fonctions*.sql')):
 s=p.read_text()
 for m in re.finditer(r'CREATE OR REPLACE FUNCTION public\.(\w+)\((.*?)\)\n.*?AS \$function\$(.*?)\$function\$;',s,re.S):
  if not re.search(r'\b(UPDATE|INSERT\s+INTO|DELETE\s+FROM)\b',m[3],re.I):continue
  if not re.search(r'\b('+champs+r')\b',m[3]):continue
  sql.append({'fonction':m[1],'source':str(p.relative_to(ROOT)),'ligne':s[:m.start()].count('\n')+1,
   'md5_source_archivee':hashlib.md5(m[3].encode()).hexdigest(),
   'a_examiner':'contreparties, identite, verrous, reprises, droits et ecrivains JSON/dynamiques'})
for p in sorted([*ROOT.glob('plateau-*.js'),ROOT/'supabase.js',*(ROOT/'api').glob('*.js')]):
 for n,l in enumerate(p.read_text().splitlines(),1):
  if re.search(r'(?:\.(?:arg|liquide|banque|solde)\s*[+*/-]?=|\b(?:arg|liquide|banque|solde)\s*:|sb(?:Insert|Update)\([^\n]*(?:prets|caisses|comptes|dons|batiments_etat))',l):
   js.append({'source':str(p.relative_to(ROOT)),'ligne':n,'texte':l.strip()})
print(json.dumps({'nature':'Candidats statiques, faux positifs possibles, SQL dynamique et serveur vivant non certifies',
 'nombre_fonctions_candidates':len(sql),'fonctions_sql':sql,'nombre_points_js':len(js),'points_js':js},ensure_ascii=False,indent=2))
