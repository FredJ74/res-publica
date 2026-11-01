#!/usr/bin/env bash
# Banc des circuits résiduels de déplacement #219 (Claude, 01/11/2026), PostgreSQL JETABLE.
# Usage (root, PostgreSQL 16) :
#   outils/bancs/banc-circuits-residuels-219.sh             # monte la base, applique le correctif, 14 cas attendus OK
#   outils/bancs/banc-circuits-residuels-219.sh --contre    # sans correctif : les défauts doivent être dénoncés
# Identités fictives, chaque cas dans une transaction annulée. Ne touche jamais la production.
set -eu
cd "$(dirname "$0")/../.."
MODE="${1:-}"
[ "${GARDER_BASE:-0}" = 1 ] || EXCLURE_MIGRATIONS="20261101170000_circuits_residuels_positions_219.sql 20261101171000_hospitalisation_pa0.sql" bash outils/bancs/monter-base-jetable.sh >/dev/null
# Réutilisation uniquement d'un socket local de clone, jamais d'une URL distante.
HG219_SOCKET_CIBLE="${HG219_PG_SOCKET:-/tmp/pgjet}"
HG219_PORT_CIBLE="${HG219_PG_PORT:-54329}"
HG219_BASE_CIBLE="${HG219_PG_BASE:-jet}"
[[ "$HG219_SOCKET_CIBLE" =~ ^/(tmp|workspace)/[A-Za-z0-9_./-]+$ ]] || { echo 'Socket local invalide' >&2; exit 2; }
[[ "$HG219_PORT_CIBLE" =~ ^[0-9]+$ && "$HG219_BASE_CIBLE" =~ ^[a-zA-Z0-9_]+$ ]] || { echo 'Cible locale invalide' >&2; exit 2; }
P="psql -h $HG219_SOCKET_CIBLE -p $HG219_PORT_CIBLE -U postgres -d $HG219_BASE_CIBLE -X -q -At -v ON_ERROR_STOP=0"
# Référentiel des villes du dépôt (seed généré depuis data.js), exigé par la fiche.
[ "${GARDER_BASE:-0}" = 1 ] || $P -v ON_ERROR_STOP=1 -f baseline/seeds/95_a-regenerer/villes.sql >/dev/null
if [ "$MODE" != "--contre" ]; then
  $P -v ON_ERROR_STOP=1 -f migrations/20261101170000_circuits_residuels_positions_219.sql >/dev/null
  # Rejeu : le correctif est idempotent.
  $P -v ON_ERROR_STOP=1 -f migrations/20261101170000_circuits_residuels_positions_219.sql >/dev/null
fi

# Décor commun : deux PJ fictifs (A chef, B membre), un député reconnu pour le cas.
DECOR="
SET LOCAL request.path = '/rpc/banc';
INSERT INTO auth.users(id) VALUES ('00000000-0000-4000-8000-00000000000a'),('00000000-0000-4000-8000-00000000000b');
-- user_id vient de auth.uid() (personnages_lier_proprietaire) : chaque fiche est créée sous son identité.
SET LOCAL request.jwt.claims = '{\"sub\":\"00000000-0000-4000-8000-00000000000a\"}';
INSERT INTO personnages_donnees(name,country,user_id,current_city,current_building,current_room,pa,liquide,arg,hp,day)
VALUES ('A','republic','00000000-0000-4000-8000-00000000000a','capitale','assemblee','hemicycle',10,2000,2000,100,1);
SET LOCAL request.jwt.claims = '{\"sub\":\"00000000-0000-4000-8000-00000000000b\"}';
INSERT INTO personnages_donnees(name,country,user_id,current_city,current_building,current_room,pa,liquide,arg,hp,day)
VALUES ('B','republic','00000000-0000-4000-8000-00000000000b','capitale','assemblee','hemicycle',10,0,0,100,1);
SET LOCAL request.jwt.claims = '';
INSERT INTO groupes_pj_adhesions(membre,chef) VALUES ('B','A');
CREATE OR REPLACE FUNCTION assemblee_est_depute(p_pays text,p_nom text) RETURNS boolean LANGUAGE sql AS 'SELECT true';
"
COMME_A="SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims = '{\"sub\":\"00000000-0000-4000-8000-00000000000a\",\"role\":\"authenticated\"}';"
COMME_B="SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims = '{\"sub\":\"00000000-0000-4000-8000-00000000000b\",\"role\":\"authenticated\"}';"
HOSPI="UPDATE personnages_donnees SET hospitalisation = jsonb_build_object('lieu','dispensaire','palier','partielle',
  'dateFinParis', ((statement_timestamp() AT TIME ZONE 'Europe/Paris')::date + 3)::text) WHERE name='A';"
EXIGE() { echo "DO \$e\$ BEGIN IF NOT ($1) THEN RAISE EXCEPTION 'attendu : %', \$q\$$1\$q\$; END IF; END \$e\$;"; }

cas() { # nom, corps SQL
  local sortie
  sortie=$( { echo "BEGIN;"; echo "$DECOR"; echo "$2"; echo "SELECT 'CAS_OK';"; echo "ROLLBACK;"; } | $P 2>&1 || true)
  if echo "$sortie" | grep -q '^CAS_OK$'; then echo "OK      $1"; else echo "ECHEC   $1 :: $(echo "$sortie" | grep -m1 -E 'ERROR|attendu' | cut -c1-200)"; fi
}

cas "assemblee_chef_proteste_quitte_son_groupe" "
$COMME_A SELECT assemblee_protester(); RESET ROLE;
$(EXIGE "(SELECT current_room FROM personnages_donnees WHERE name='A')='accueil_assemblee'")
$(EXIGE "(SELECT current_room FROM personnages_donnees WHERE name='B')='hemicycle'")
$(EXIGE "NOT EXISTS(SELECT 1 FROM groupes_pj_adhesions WHERE chef='A' OR membre='A')")
$COMME_A SELECT set_config('banc.v', (navigation_interieure('assemblee','hemicycle'))::text, true);
RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'ok'='true'")"

cas "assemblee_membre_proteste_le_chef_reste_mobile" "
$COMME_B SELECT assemblee_protester(); RESET ROLE;
$(EXIGE "NOT EXISTS(SELECT 1 FROM groupes_pj_adhesions WHERE membre='B')")
$COMME_A SELECT set_config('banc.v', (navigation_interieure('assemblee','couloirs'))::text, true);
RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'ok'='true'")"

cas "assemblee_revenir_seul_ne_disperse_pas" "
UPDATE personnages_donnees SET current_room='accueil_assemblee' WHERE name IN ('A','B');
$COMME_B SELECT assemblee_revenir(); RESET ROLE;
$(EXIGE "(SELECT current_room FROM personnages_donnees WHERE name='B')='hemicycle'")
$(EXIGE "NOT EXISTS(SELECT 1 FROM groupes_pj_adhesions WHERE membre='B')")"

cas "liberation_qhs_purgee_depose_au_terminal_de_retour" "
DELETE FROM groupes_pj_adhesions;
UPDATE personnages_donnees SET current_city='qhs',current_building='qhs-prison',current_room='cellules_qhs',
  est_emprisonne='{\"qhs\":true,\"retourVille\":\"ville_a\",\"jours\":1}' WHERE name='A';
SELECT detention_clore_interne('A','purgee');
$(EXIGE "(SELECT concat_ws('|',current_city,current_building,current_room,current_street IS NULL) FROM personnages_donnees WHERE name='A')='ville_a|centre-multinodal-port-sainte-marie|hall_gare_psm|t'")
$(EXIGE "(SELECT est_emprisonne IS NULL FROM personnages_donnees WHERE name='A')")"

cas "liberation_qhs_par_grace_ne_deplace_pas" "
DELETE FROM groupes_pj_adhesions;
UPDATE personnages_donnees SET current_city='qhs',current_building='qhs-prison',current_room='cellules_qhs',
  est_emprisonne='{\"qhs\":true,\"retourVille\":\"ville_a\",\"jours\":1}' WHERE name='A';
SELECT detention_clore_interne('A','grace_presidentielle');
$(EXIGE "(SELECT current_city FROM personnages_donnees WHERE name='A')='qhs'")"

cas "incorporation_depose_au_corps_de_garde" "
DELETE FROM groupes_pj_adhesions;
UPDATE personnages_donnees SET current_city='ville_a',current_building='commissariat-local',current_room='geoles',
  est_emprisonne='{\"motifDesertionSeul\":true,\"jours\":2}' WHERE name='A';
$COMME_A SELECT set_config('banc.v', (detention_clore_motif_eteint('incorporation'))::text, true);
RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'ok'='true'")
$(EXIGE "(SELECT concat_ws('|',current_city,current_building,current_room) FROM personnages_donnees WHERE name='A')='caserne|caserne-militaire|corps_garde'")"

cas "ancien_circuit_hospitalise_refuse_par_la_navigation" "
$HOSPI
UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='n1' WHERE name IN ('A','B');
$COMME_A SELECT set_config('banc.v', (navigation_interieure('dispensaire-public','salle_attente'))::text, true);
RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'raison' IN ('acteur_incapacite','personnage_indisponible')")"

cas "hospitalisation_dispensaire_capitale_et_sortie_du_groupe" "
$HOSPI
UPDATE personnages_donnees SET current_building=NULL,current_room=NULL,current_street='n1' WHERE name IN ('A','B');
$COMME_A SELECT set_config('banc.v', (hospitalisation_lieu_rejoindre('dispensaire'))::text, true);
RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'ok'='true'")
$(EXIGE "(SELECT concat_ws('|',current_city,current_building,current_room,current_street IS NULL) FROM personnages_donnees WHERE name='A')='capitale|dispensaire-public|salle_attente|t'")
$(EXIGE "(SELECT current_street FROM personnages_donnees WHERE name='B')='n1'")
$(EXIGE "NOT EXISTS(SELECT 1 FROM groupes_pj_adhesions)")"

cas "hospitalisation_dispensaire_de_province" "
$HOSPI
DELETE FROM groupes_pj_adhesions;
UPDATE personnages_donnees SET current_city='ville_a',current_building='hotel-port',current_room=NULL WHERE name='A';
$COMME_A SELECT set_config('banc.v', (hospitalisation_lieu_rejoindre('dispensaire'))::text, true);
RESET ROLE;
$(EXIGE "(SELECT concat_ws('|',current_city,current_building,current_room) FROM personnages_donnees WHERE name='A')='ville_a|dispensaire-public-v|attente'")"

cas "hospitalisation_refusee_sans_hospitalisation_ni_ecriture" "
CREATE TEMP TABLE avant AS SELECT * FROM personnages_donnees;
$COMME_A SELECT set_config('banc.v', (hospitalisation_lieu_rejoindre('dispensaire'))::text, true);
RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'raison'='non_hospitalise'")
$(EXIGE "NOT EXISTS(SELECT * FROM personnages_donnees EXCEPT SELECT * FROM avant)")"

cas "clinique_depuis_province_payee_et_deplacee_atomiquement" "
$HOSPI
DELETE FROM groupes_pj_adhesions;
INSERT INTO ordres_couts(fn,pa,cost) VALUES ('transfert_clinique_privee',0,1000) ON CONFLICT DO NOTHING;
INSERT INTO locations_actives(id,country,data) VALUES ('loc-a','republic','{\"buildingId\":\"clinique-privee\",\"roomId\":\"chambre_3\",\"city\":\"capitale\",\"locataire\":\"A\"}');
UPDATE personnages_donnees SET current_city='ville_a',current_building='dispensaire-public-v',current_room='attente' WHERE name='A';
$COMME_A SELECT set_config('banc.verif', (hospitalisation_lieu_rejoindre('clinique','chambre_3',true))::text, true);
SELECT set_config('banc.v', (hospitalisation_lieu_rejoindre('clinique','chambre_3'))::text, true);
SELECT set_config('banc.rejeu', (hospitalisation_lieu_rejoindre('clinique','chambre_3'))::text, true);
RESET ROLE;
$(EXIGE "current_setting('banc.verif')::jsonb->>'verifie'='true'")
$(EXIGE "current_setting('banc.v')::jsonb->>'ok'='true'")
$(EXIGE "current_setting('banc.rejeu')::jsonb->>'ok'='true'")
$(EXIGE "(SELECT concat_ws('|',current_city,current_building,current_room,hospitalisation->>'lieu',liquide) FROM personnages_donnees WHERE name='A')='capitale|clinique-privee|chambre_3|clinique|1000'")"

cas "clinique_fonds_insuffisants_rien_ne_bouge" "
$HOSPI
DELETE FROM groupes_pj_adhesions;
INSERT INTO ordres_couts(fn,pa,cost) VALUES ('transfert_clinique_privee',0,1000) ON CONFLICT DO NOTHING;
UPDATE personnages_donnees SET liquide=10,arg=10,current_building='dispensaire-public',current_room='salle_attente' WHERE name='A';
CREATE TEMP TABLE avant AS SELECT * FROM personnages_donnees;
$COMME_A SELECT set_config('banc.v', (hospitalisation_lieu_rejoindre('clinique'))::text, true);
RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'raison'='fonds_insuffisants'")
$(EXIGE "NOT EXISTS(SELECT * FROM personnages_donnees EXCEPT SELECT * FROM avant)")"

cas "clinique_chambre_d_un_autre_refusee" "
$HOSPI
INSERT INTO locations_actives(id,country,data) VALUES ('loc-b','republic','{\"buildingId\":\"clinique-privee\",\"roomId\":\"chambre_4\",\"city\":\"capitale\",\"locataire\":\"B\"}');
$COMME_A SELECT set_config('banc.v', (hospitalisation_lieu_rejoindre('clinique','chambre_4'))::text, true);
RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'raison'='chambre_non_attribuee'")"

cas "porte_hospitalisation_fermee_a_anon" "
$(EXIGE "NOT has_function_privilege('anon','public.hospitalisation_lieu_rejoindre(text,text,boolean)','EXECUTE')")
$(EXIGE "has_function_privilege('authenticated','public.hospitalisation_lieu_rejoindre(text,text,boolean)','EXECUTE')")"
