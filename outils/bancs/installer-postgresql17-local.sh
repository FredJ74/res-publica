#!/usr/bin/env bash
# PostgreSQL 17.6 natif pour épreuves jetables ; jamais de connexion distante.
# Sources officielles épinglées. Aucun sudo, service système ou ressource payante.
set -euo pipefail
HGPG17_PREFIX="${HGPG17_PREFIX:-/workspace/hg-postgresql-17}"
if [[ -x "$HGPG17_PREFIX/bin/postgres" ]]; then
  [[ "$("$HGPG17_PREFIX/bin/postgres" --version)" == 'postgres (PostgreSQL) 17.6' ]] || { echo 'Préfixe déjà occupé par une autre version' >&2; exit 1; }
  "$HGPG17_PREFIX/bin/postgres" --version
  exit 0
fi
for commande in git curl dpkg-deb gcc make perl python3 sha256sum; do command -v "$commande" >/dev/null; done
HGPG17_TRAVAIL=$(mktemp -d /tmp/hg-pg17-compilation.XXXXXX)
trap 'rm -rf "$HGPG17_TRAVAIL"' EXIT
git clone --depth 1 --branch REL_17_6 https://github.com/postgres/postgres.git "$HGPG17_TRAVAIL/source"
[[ "$(git -C "$HGPG17_TRAVAIL/source" rev-parse HEAD)" == 7885b94dd81b98bbab9ed878680d156df7bf857f ]]
python3 -m venv "$HGPG17_TRAVAIL/outils"
"$HGPG17_TRAVAIL/outils/bin/python" -m pip install bison-bin==3.8.2.3 flex-bin==2.6.4.2
curl --fail --location --max-time 60 --output "$HGPG17_TRAVAIL/m4.deb" https://deb.debian.org/debian/pool/main/m/m4/m4_1.4.19-3_amd64.deb
printf '%s  %s\n' b2dd7bfca426712416e651bb5ff6dabe7d05e4caebbac61d714dbe261b31e4c3 "$HGPG17_TRAVAIL/m4.deb" | sha256sum -c -
dpkg-deb -x "$HGPG17_TRAVAIL/m4.deb" "$HGPG17_TRAVAIL/m4"
export BISON="$HGPG17_TRAVAIL/outils/bin/bison"
export FLEX="$HGPG17_TRAVAIL/outils/bin/flex"
export M4="$HGPG17_TRAVAIL/m4/usr/bin/m4"
export BISON_PKGDATADIR
BISON_PKGDATADIR=$("$HGPG17_TRAVAIL/outils/bin/python" -c 'from pathlib import Path; import bison_bin; print(Path(bison_bin.__file__).parent/"_payload/share/bison")')
cd "$HGPG17_TRAVAIL/source"
./configure --prefix="$HGPG17_PREFIX" --without-icu --without-readline --without-zlib --with-openssl
make -j"${HGPG17_JOBS:-4}"
make install
make -C contrib/pgcrypto install
"$HGPG17_PREFIX/bin/postgres" --version
