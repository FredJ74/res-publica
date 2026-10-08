#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lance le banc du transport serverless (api/_supabase.js).

CE FICHIER NE FAIT PLUS QUE NOMMER SES INGREDIENTS. Toute la mecanique -- transformation des
modules ES en forme script, injection de `fetch`/`console`/`process`, remontee du verdict dans
le code de sortie -- vit dans lancer-banc.py, parce qu'elle est la meme pour tous les bancs.
Elle a d'abord ete ecrite ici, puis extraite des qu'un second banc en a eu besoin.

Usage :
    python3 outils/bancs/banc-api-supabase.py
"""

import os
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))

if __name__ == "__main__":
    sys.exit(subprocess.run([
        sys.executable, os.path.join(ICI, "lancer-banc.py"),
        "outils/bancs/banc-api-supabase.js",
        "api/_supabase.js",
    ]).returncode)
