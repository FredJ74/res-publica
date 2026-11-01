#!/usr/bin/env python3
"""Exécute un banc existant avec les binaires PostgreSQL locaux sélectionnés.

Ne change ni le décor, ni les fonctions, ni les assertions ou le code de sortie.
Aucune URL distante acceptée ; les bancs conservent leurs serveurs jetables.
"""
import argparse,importlib.util,runpy,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]

def main():
 a=argparse.ArgumentParser(description=__doc__)
 a.add_argument('--postgres-bin',type=Path,required=True)
 a.add_argument('banc',type=Path)
 a.add_argument('arguments',nargs=argparse.REMAINDER)
 o=a.parse_args();banc=o.banc.resolve()
 if not banc.is_file() or not any(p in banc.parents for p in [R/'outils/bancs',R/'outils/e2e']):
  a.error('Banc Python du dépôt requis')
 sp=importlib.util.spec_from_file_location('epreuve_pg',R/'outils/baseline/epreuve-postgresql.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
 m.configurer_binaires(o.postgres_bin)
 print(subprocess.check_output([str(o.postgres_bin/'postgres'),'--version'],text=True).strip(),flush=True)
 sys.argv=[str(banc),*o.arguments]
 runpy.run_path(str(banc),run_name='__main__')

if __name__=='__main__':main()
