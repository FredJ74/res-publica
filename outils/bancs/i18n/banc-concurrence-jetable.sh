#!/usr/bin/env bash
# Contre-épreuve de concurrence sur base PostgreSQL JETABLE seulement.
set -euo pipefail

psql -X -v ON_ERROR_STOP=1 -q -c \
  "UPDATE public.rp_i18n_configuration SET enabled=true,daily_requests=1,daily_characters=100 WHERE singleton=1"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
uid='33333333-3333-4333-8333-333333333333'
# Deux processus différents, deux clés distinctes, même UID/jour.
psql -X -v ON_ERROR_STOP=1 -Atq \
  -c "SET ROLE service_role; SELECT public.rp_i18n_budget_reserver('$uid'::uuid,repeat('d',64),5)" \
  >"$tmpdir/a" &
pid_a=$!
psql -X -v ON_ERROR_STOP=1 -Atq \
  -c "SET ROLE service_role; SELECT public.rp_i18n_budget_reserver('$uid'::uuid,repeat('e',64),5)" \
  >"$tmpdir/b" &
pid_b=$!
wait "$pid_a"
wait "$pid_b"
a="$(tr -d '[:space:]' < "$tmpdir/a")"
b="$(tr -d '[:space:]' < "$tmpdir/b")"
if [[ "$a$b" != 'tf' && "$a$b" != 'ft' ]]; then
  echo "ÉCHEC : réservations concurrentes inattendues ($a, $b)" >&2
  exit 1
fi
counts="$(psql -X -Atq -c "SELECT request_count::text||':'||character_count::text FROM public.rp_i18n_usage WHERE uid='$uid'::uuid AND usage_day=(clock_timestamp() AT TIME ZONE 'UTC')::date")"
if [[ "$counts" != '1:5' ]]; then
  echo "ÉCHEC : consommation atomique incorrecte ($counts)" >&2
  exit 1
fi
echo "OK : une seule réservation, seconde refusée, compteur 1:5"
