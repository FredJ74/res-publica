#!/usr/bin/env bash
# Assemble le banc annulé de l'étape B des organisations : les cinq migrations (sans leurs
# BEGIN/COMMIT) puis outils/bancs/banc-organisations-etape-b.sql, dans UNE transaction qui finit
# par l'exception BANC_ANNULE (rien ne reste). Imprime le SQL à jouer contre la base.
set -euo pipefail
cd "$(dirname "$0")/../.."
echo "BEGIN;"
for f in migrations/20261102000900_*.sql migrations/20261102001000_*.sql migrations/20261102001100_*.sql \
         migrations/20261102001200_*.sql migrations/20261102001300_*.sql; do
  grep -v -E '^(BEGIN|COMMIT);$' "$f"
done
cat outils/bancs/banc-organisations-etape-b.sql
