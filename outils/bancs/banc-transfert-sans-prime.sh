#!/usr/bin/env bash
# Transferts sans prime de signature (Claude, 01/11/2026), PostgreSQL 16 JETABLE.
# Décision de Fred : GAME-DESIGN-FOOTBALL.md. Migration : 20261101190000_transfert_sans_prime_signature.sql.
# Usage (root) : outils/bancs/banc-transfert-sans-prime.sh            # tous les cas OK
#                outils/bancs/banc-transfert-sans-prime.sh --contre   # sans le correctif : la prime doit être dénoncée
# Identités fictives, chaque cas dans une transaction annulée. Ne touche jamais la production.
set -eu
cd "$(dirname "$0")/../.."
MODE="${1:-}"
P="psql -h /tmp/pgjet -p 54329 -U postgres -d jet -X -q -At -v ON_ERROR_STOP=0"
if [ "$MODE" = "--contre" ]; then
  EXCLURE_MIGRATIONS="20261101190000_transfert_sans_prime_signature.sql" bash outils/bancs/monter-base-jetable.sh >/dev/null
else
  bash outils/bancs/monter-base-jetable.sh >/dev/null
fi

U1=00000000-0000-4000-8000-0000000000c1; U2=00000000-0000-4000-8000-0000000000c2
DECOR="
INSERT INTO villes(pays,ville,nom,est_capitale,rang) SELECT 'republic','capitale','Luthécia',true,1 WHERE NOT EXISTS (SELECT 1 FROM villes WHERE pays='republic');
INSERT INTO auth.users(id) VALUES ('$U1'),('$U2');
SET LOCAL request.path = '/rpc/banc';
SET LOCAL request.jwt.claims = '{\"sub\":\"$U1\"}';
INSERT INTO personnages_donnees(name,country,user_id,liquide,arg,day) VALUES ('Pres','republic','$U1',0,0,1);
SET LOCAL request.jwt.claims = '{\"sub\":\"$U2\"}';
INSERT INTO personnages_donnees(name,country,user_id,liquide,arg,day) VALUES ('Joueur','republic','$U2',100,100,1);
SET LOCAL request.jwt.claims = '';
INSERT INTO clubs_football(id,nom,pays,ville) VALUES ('dep','Départ','republic','capitale'),('arr','Arrivée','republic','capitale');
INSERT INTO presidents_clubs(id,data) VALUES ('arr','{\"president\":\"Pres\"}'),('dep','{\"president\":\"Autre\"}');
INSERT INTO budgets_clubs(id,data) VALUES ('arr','{\"caisse\":10000}'),('dep','{\"caisse\":0}');
"
COMME() { echo "SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims = '{\"sub\":\"$1\",\"role\":\"authenticated\"}';"; }
EXIGE() { echo "DO \$e\$ BEGIN IF ($1) IS NOT TRUE THEN RAISE EXCEPTION 'attendu : %', \$q\$$1\$q\$; END IF; END \$e\$;"; }
ESSAI() { echo "DO \$x\$ BEGIN $1; PERFORM set_config('banc.err','',true);
 EXCEPTION WHEN OTHERS THEN PERFORM set_config('banc.err',SQLERRM,true); END \$x\$;"; }
OFFRE() { echo "{\"statut\":\"propose\",\"joueur\":\"Joueur\",\"clubDepartId\":\"dep\",\"clubArriveeId\":\"arr\",\"proposePar\":\"Pres\",\"prixClub\":1000$1}"; }
OK=0; KO=0
cas() { local nom="$1" sql="$2" out
  out=$(printf 'BEGIN;\n%s\n%s\nROLLBACK;\n' "$DECOR" "$sql" | $P 2>&1 | grep -E 'ERROR' || true)
  if [ -z "$out" ]; then echo "OK      $nom"; OK=$((OK+1)); else echo "ECHEC   $nom :: $out"; KO=$((KO+1)); fi; }

cas "offre_avec_prime_refusee" "
$(COMME $U1) $(ESSAI "INSERT INTO transferts_clubs(id,statut,data) VALUES ('t1','propose','$(OFFRE ',"prixJoueur":500')'::jsonb)") RESET ROLE;
$(EXIGE "current_setting('banc.err') LIKE '%transfert_prime_non_prevue%'")
$(EXIGE "NOT EXISTS (SELECT 1 FROM transferts_clubs WHERE id='t1')")"

cas "offre_sans_prime_ou_prime_nulle_acceptee" "
$(COMME $U1) INSERT INTO transferts_clubs(id,statut,data) VALUES ('t2','propose','$(OFFRE '')'::jsonb),('t3','propose','$(OFFRE ',"prixJoueur":0')'::jsonb); RESET ROLE;
$(EXIGE "(SELECT count(*) FROM transferts_clubs) = 2")"

# Une offre ancienne portant une prime (posée avant le correctif) ne verse rien au joueur.
cas "conclusion_ne_verse_jamais_de_prime" "
SET LOCAL session_replication_role = replica;
INSERT INTO transferts_clubs(id,statut,data) VALUES ('t4','attente_joueur',
 '{\"statut\":\"attente_joueur\",\"joueur\":\"Joueur\",\"clubDepartId\":\"dep\",\"clubArriveeId\":\"arr\",\"proposePar\":\"Pres\",\"prixClub\":1000,\"prixJoueur\":500}');
SET LOCAL session_replication_role = origin;
$(COMME $U2) SELECT set_config('banc.r',(club_transfert_conclure('t4'))::text,true); RESET ROLE;
$(EXIGE "(current_setting('banc.r')::jsonb->>'ok')::boolean")
$(EXIGE "(current_setting('banc.r')::jsonb->>'prime')::numeric = 0")
$(EXIGE "(SELECT liquide FROM personnages_donnees WHERE name='Joueur') = 100")
$(EXIGE "(SELECT (data->>'caisse')::numeric FROM budgets_clubs WHERE id='arr') = 9000")
$(EXIGE "(SELECT (data->>'caisse')::numeric FROM budgets_clubs WHERE id='dep') = 1000")"

echo "---- $OK OK, $KO échec(s)"
[ "$MODE" = "--contre" ] || [ "$KO" = 0 ]
