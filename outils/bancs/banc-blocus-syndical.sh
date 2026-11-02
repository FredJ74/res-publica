#!/bin/sh
# Concatène la migration du blocus syndical et son banc annulé, à jouer en une seule requête
# (canal technique) : l'exception finale du banc annule tout.
# LEGER=1 : ne garde du catalogue que les bâtiments du banc (requête plus courte).
cd "$(dirname "$0")/../.." || exit 1
python3 - "${1:-/tmp/banc-blocus.sql}" <<'PY'
import os, re, sys
m = open('migrations/20261102135437_blocus_syndical_serveur.sql', encoding='utf-8').read()
if os.environ.get('LEGER') == '1':
    tete, _, reste = m.partition("SELECT 'republic', x.v, x.b, unnest(string_to_array(x.f, ' ')) FROM (VALUES\n")
    lignes, _, fin = reste.partition('\n) AS x(v, b, f)')
    garde = [l.rstrip(',') for l in lignes.split('\n')
             if re.match(r"\('capitale','(banque-nationale|mairie|commissariat)',", l)]
    m = tete + "SELECT 'republic', x.v, x.b, unnest(string_to_array(x.f, ' ')) FROM (VALUES\n" + ',\n'.join(garde) + '\n) AS x(v, b, f)' + fin
banc = open('outils/bancs/banc-blocus-syndical.sql', encoding='utf-8').read()
open(sys.argv[1], 'w', encoding='utf-8').write('BEGIN;\n' + m + '\n' + banc + '\nROLLBACK;\n')
PY
