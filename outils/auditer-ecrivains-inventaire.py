#!/usr/bin/env python3
"""Inventaire documentaire du code archive ; aucune connexion, aucune preuve du serveur vivant."""
import argparse,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--json',action='store_true');args=p.parse_args()
 fonctions=[]
 for fichier in sorted((ROOT/'baseline/domaines').rglob('*fonctions*.sql')):
  source=fichier.read_text()
  for m in re.finditer(r'CREATE OR REPLACE FUNCTION public\.(\w+)\([\s\S]*?AS \$function\$([\s\S]*?)\$function\$;',source):
   corps=m[2]
   if not re.search(r'\b(?:SET|,)\s*inventory\s*=',corps,re.I):continue
   debut=source[:m.start()].count('\n')+1
   fonctions.append({'fonction':m[1],'source':str(fichier.relative_to(ROOT)), 'ligne':debut,
     'md5_corps_archive':hashlib.md5(corps.encode()).hexdigest(),
     'ecritures_inventory':len(re.findall(r'\binventory\s*=',corps)),
     'lignes_verrouillage_a_lire':[{'ligne_relative':i+1,'texte':l.strip()} for i,l in enumerate(m[0].splitlines()) if re.search(r'FOR (?:NO KEY )?UPDATE',l,re.I)],
     'via_vue':bool(re.search(r'UPDATE (?:public\.)?personnages\s+SET',corps,re.I))})
 clients=[]
 for f in [ROOT/'supabase.js',*sorted(ROOT.glob('plateau-*.js'))]:
  for i,l in enumerate(f.read_text().splitlines(),1):
   if re.search(r'(?:state\.inventory\s*=|inventory\s*:|sbAdopterInventaireServeur\()',l):
    clients.append({'source':f.name,'ligne':i,'texte':l.strip()})
 resultat={'nature':'Sources archivees, ne certifie ni tous les ecrivains reels ni les verrous vivants',
  'fonctions_baseline':fonctions,'nombre_fonctions_baseline':len(fonctions),
  'ecritures_baseline':sum(f['ecritures_inventory'] for f in fonctions),'points_client':clients,
  'a_verifier':'Comparer aux catalogues reels, y compris nouvelles fonctions, SQL dynamique, triggers et Edge Functions.'}
 if args.json:print(json.dumps(resultat,ensure_ascii=False,indent=2))
 else:
  for f in fonctions: print(f"{f['fonction']}: {f['source']}:{f['ligne']} ; {f['ecritures_inventory']} ecriture(s), verrous a lire: {len(f['lignes_verrouillage_a_lire'])}")
  print(f"{len(fonctions)} fonctions, {resultat['ecritures_baseline']} ecritures archivees ; aucune lecture Supabase.")
if __name__=='__main__':main()
