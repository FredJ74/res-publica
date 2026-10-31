#!/usr/bin/env python3
"""Assemble banc-caisses-collectives.sql avec le corps des deux migrations (#295).
Usage : python3 outils/bancs/banc-caisses-collectives-preparer.py > /tmp/banc.sql
Le banc assemblé se joue tel quel (MCP execute_sql ou psql) : il s'annule lui-même."""
import pathlib, re
r = pathlib.Path(__file__).resolve().parents[2]
def corps(nom):
    s = (r / 'migrations' / nom).read_text()
    s = s.split('BEGIN;', 1)[1]
    return s[:s.rindex('COMMIT;')]
b = (r / 'outils/bancs/banc-caisses-collectives.sql').read_text()
b = re.sub(r'(?m)^--.*\n', '', b)
b = b.replace('{{ETAPE1}}', corps('20261031200000_caisses_collectives_portes_serveur.sql'))
b = b.replace('{{ETAPE2}}', corps('20261031201000_caisses_collectives_fermer_ecran.sql'))
b = re.sub(r'(?m)^--.*\n', '', b)
print(b)
