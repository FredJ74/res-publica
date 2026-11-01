#!/usr/bin/env bash
# Base PostgreSQL JETABLE locale (30/10/2026) : baseline/ + migrations/ + ecarts releves en
# production. Leve le « verrou d'environnement » de WORKFLOW-SUPABASE.md pour les bancs qui
# exigent plusieurs sessions reelles (concurrence). Ne touche jamais la production.
# Usage (root, PostgreSQL 16 installe) : outils/bancs/monter-base-jetable.sh ; puis
#   PGCIBLE="-h /tmp/pgjet -p 54329 -U postgres -d jet" outils/bancs/banc-achats-concurrents.sh
# Ecarts connus : PG16 local contre PG17 en production (droit MAINTAIN retire des GRANT) ;
# fonctions SQL creees sans verification de corps (ordre de creation) ; quelques erreurs
# d'ordre de contraintes et de migrations gardees par empreinte, sans effet sur l'achat.
# EXCLURE_MIGRATIONS="a.sql b.sql" : noms de fichiers de migrations/ a ne pas jouer (contre-epreuves
# des bancs qui appliquent eux-memes une migration, ex. banc-hospitalisation.sh).
# Toujours comparer les empreintes (jetable-empreintes.sql) avec la production avant de conclure.
set -eu
cd "$(dirname "$0")/../.."
B=/usr/lib/postgresql/16/bin; D=/tmp/pgjet
id postgres >/dev/null 2>&1 || useradd -m postgres
runuser -u postgres -- $B/pg_ctl -D $D/data stop >/dev/null 2>&1 || true
rm -rf $D; mkdir -p $D; chown postgres $D
runuser -u postgres -- $B/initdb -D $D/data -U postgres -A trust >/dev/null
runuser -u postgres -- $B/pg_ctl -D $D/data -o "-k $D -p 54329 -c listen_addresses=''" -l $D/log start >/dev/null
sleep 2
P="psql -h $D -p 54329 -U postgres -X -q -v ON_ERROR_STOP=0"
$P -d postgres -c "CREATE DATABASE jet"
$P -d jet >/dev/null 2>&1 <<'SQL'
CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN; CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE ROLE authenticator LOGIN NOINHERIT; GRANT anon, authenticated, service_role TO authenticator;
CREATE ROLE supabase_auth_admin NOLOGIN; CREATE ROLE supabase_admin NOLOGIN; CREATE ROLE dashboard_user NOLOGIN;
CREATE SCHEMA auth; CREATE SCHEMA extensions;
CREATE TABLE auth.users (id uuid PRIMARY KEY, email text, raw_user_meta_data jsonb, created_at timestamptz DEFAULT now());
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'sub','')::uuid $$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'role' $$;
GRANT USAGE ON SCHEMA auth, extensions TO anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO anon, authenticated, service_role;
CREATE EXTENSION IF NOT EXISTS pgcrypto; CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SQL
python3 - <<'PY'
import glob,os,re
fs=sorted(glob.glob('baseline/domaines/*/*.sql'),key=lambda f:(int(re.match(r'(\d+)_',os.path.basename(f)).group(1)),0 if f.split('/')[2]=='socle' else 1,f))
s=''.join(f'\n-- FICHIER {f}\n'+open(f).read()+'\n' for f in fs)
s=re.sub(r'\bMAINTAIN\s*,\s*','',re.sub(r',\s*MAINTAIN\b','',s))
open('/tmp/pgjet/baseline.sql','w').write('SET check_function_bodies = off;\n'+s)
PY
$P -d jet -f $D/baseline.sql > $D/baseline.log 2>&1
for f in $(ls migrations/*.sql | sort); do case " ${EXCLURE_MIGRATIONS:-} " in *" $(basename "$f") "*) continue;; esac; (echo "SET check_function_bodies = off;"; sed -E 's/,\s*MAINTAIN\b//g' "$f") | $P -d jet >> $D/migrations.log 2>&1; done
sed -n 3,5p migrations/20261024122600_acquisitions_capacites_et_gardes.sql | $P -d jet
sed 's/^ROLLBACK;$/COMMIT;/' historique/photographies/20261030-fonctions-achat-communiquees.sql | $P -d jet -v ON_ERROR_STOP=1 >/dev/null
echo "baseline : $(grep -c ERROR $D/baseline.log) erreur(s) ; migrations : $(grep -c ERROR $D/migrations.log) erreur(s) (attendues, voir en-tete)"
psql -h $D -p 54329 -U postgres -d jet -X -q -At -f outils/bancs/jetable-empreintes.sql | sed 's/=\([0-9a-f]\{8\}\) /=\1\n/g'
