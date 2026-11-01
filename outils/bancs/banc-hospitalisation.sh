#!/usr/bin/env bash
# Banc de l'hospitalisation à 0 PA (Claude, 01/11/2026), PostgreSQL JETABLE.
# Règles : GAME-DESIGN-HOSPITALISATION.md (Fred, 01/11/2026).
# Usage (root, PostgreSQL 16) :
#   outils/bancs/banc-hospitalisation.sh            # monte la base, #318 puis le correctif : tous les cas OK
#   outils/bancs/banc-hospitalisation.sh --contre   # sans le correctif : les règles doivent être dénoncées
#   GARDER_BASE=1 … : réutilise la base déjà montée (le correctif est rejoué, il est idempotent)
# Identités fictives, chaque cas dans une transaction annulée. Ne touche jamais la production.
set -eu
cd "$(dirname "$0")/../.."
MODE="${1:-}"
P="psql -h /tmp/pgjet -p 54329 -U postgres -d jet -X -q -At -v ON_ERROR_STOP=0"
if [ "${GARDER_BASE:-0}" != 1 ]; then
  bash outils/bancs/monter-base-jetable.sh >/dev/null
  for f in baseline/seeds/95_a-regenerer/villes.sql baseline/seeds/91_empire/rue_noeuds_serveur.sql \
           baseline/seeds/91_empire/rue_sorties_batiments.sql \
           outils/audits/circuits-residuels-219-20261101/migration-a-integrer-circuits-residuels-positions.sql; do
    $P -v ON_ERROR_STOP=1 -f "$f" >/dev/null
  done
fi
if [ "$MODE" != "--contre" ]; then
  $P -v ON_ERROR_STOP=1 -f outils/audits/hospitalisation-20261101/migration-a-integrer-hospitalisation.sql >/dev/null 2>&1
fi

DECOR="
SET LOCAL request.path = '/rpc/banc';
INSERT INTO auth.users(id) VALUES ('00000000-0000-4000-8000-00000000000a'),('00000000-0000-4000-8000-00000000000b');
SET LOCAL request.jwt.claims = '{\"sub\":\"00000000-0000-4000-8000-00000000000a\"}';
INSERT INTO personnages_donnees(name,country,user_id,current_city,current_building,current_room,pa,liquide,arg,hp,day)
VALUES ('A','republic','00000000-0000-4000-8000-00000000000a','capitale','assemblee','hemicycle',10,2000,2000,100,1);
SET LOCAL request.jwt.claims = '{\"sub\":\"00000000-0000-4000-8000-00000000000b\"}';
INSERT INTO personnages_donnees(name,country,user_id,current_city,current_building,current_room,pa,liquide,arg,hp,day)
VALUES ('B','republic','00000000-0000-4000-8000-00000000000b','capitale','assemblee','hemicycle',10,0,0,100,1);
SET LOCAL request.jwt.claims = '';
INSERT INTO groupes_pj_adhesions(membre,chef) VALUES ('B','A');
INSERT INTO ordres_couts(fn,pa,cost) SELECT 'banc_ordre',3,0 WHERE NOT EXISTS(SELECT 1 FROM ordres_couts WHERE fn='banc_ordre');
INSERT INTO ordres_couts(fn,pa,cost) SELECT 'transfert_clinique_privee',0,1000 WHERE NOT EXISTS(SELECT 1 FROM ordres_couts WHERE fn='transfert_clinique_privee');
INSERT INTO ordres_couts(fn,pa,cost) SELECT 'repas_hopital',1,0 WHERE NOT EXISTS(SELECT 1 FROM ordres_couts WHERE fn='repas_hopital');
INSERT INTO ordres_couts(fn,pa,cost) SELECT 'repas_clinique',1,30 WHERE NOT EXISTS(SELECT 1 FROM ordres_couts WHERE fn='repas_clinique');
"
COMME_A="SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claims = '{\"sub\":\"00000000-0000-4000-8000-00000000000a\",\"role\":\"authenticated\"}';"
AUJ="(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date"
# Hospitalisation du régime pa0 commencée il y a N jours, au lieu L (dispensaire de la capitale par défaut).
HOSPI() { # jours_ecoules lieu batiment piece pa [repas_hier]
  local repas=""; [ "${6:-}" = repas ] && repas=",'repasLe',($AUJ - 1)::text"
  echo "DELETE FROM groupes_pj_adhesions;
UPDATE personnages_donnees SET pa=$5, current_city='capitale', current_building='$3', current_room='$4', current_street=NULL,
 hospitalisation=jsonb_build_object('regime','pa0','lieu','$2','dateDebutParis',($AUJ - $1)::text,'dateFinParis','9999-12-31'$repas)
 WHERE name='A';"
}
EXIGE() { echo "DO \$e\$ BEGIN IF ($1) IS NOT TRUE THEN RAISE EXCEPTION 'attendu : %', \$q\$$1\$q\$; END IF; END \$e\$;"; }
# Exécute une écriture comme A et range l'erreur éventuelle dans banc.err.
ESSAI() { echo "DO \$x\$ BEGIN $1; PERFORM set_config('banc.err','',true);
 EXCEPTION WHEN OTHERS THEN PERFORM set_config('banc.err',SQLERRM,true); END \$x\$;"; }
FIN="SET CONSTRAINTS ALL IMMEDIATE;"   # le déclencheur différé tourne avant l'annulation du cas
POS="(SELECT concat_ws('|',current_city,current_building,current_room) FROM personnages_donnees WHERE name='A')"
H="(SELECT hospitalisation FROM personnages_donnees WHERE name='A')"
PA="(SELECT pa FROM personnages_donnees WHERE name='A')"

OK=0; KO=0
cas() { # nom, corps SQL
  local sortie
  sortie=$( { echo "BEGIN;"; echo "$DECOR"; echo "$2"; echo "SELECT 'CAS_OK';"; echo "ROLLBACK;"; } | $P 2>&1 || true)
  if echo "$sortie" | grep -q '^CAS_OK$'; then echo "OK      $1"; OK=$((OK+1))
  else echo "ECHEC   $1 :: $(echo "$sortie" | grep -m1 -E 'ERROR|attendu' | cut -c1-220)"; KO=$((KO+1)); fi
}

# ---- Déclenchement automatique ----
cas "ordre_dernier_pa_hospitalise_au_dispensaire_de_la_ville" "
UPDATE personnages_donnees SET pa=3, current_city='ville_a', current_building='hotel-du-port', current_room='hall' WHERE name='A';
$COMME_A SELECT payer_ordre('A','banc_ordre',3,0); RESET ROLE; $FIN
$(EXIGE "$PA=0")
$(EXIGE "$H->>'regime'='pa0' AND $H->>'lieu'='dispensaire' AND $H->>'dateDebutParis'=$AUJ::text")
$(EXIGE "$POS='ville_a|dispensaire-public-v|attente'")
$(EXIGE "NOT EXISTS(SELECT 1 FROM groupes_pj_adhesions WHERE chef='A' OR membre='A')")"

cas "combat_perdu_pa_a_zero_hospitalise_a_la_capitale" "
UPDATE personnages_donnees SET pa=0 WHERE name='A'; $FIN
$(EXIGE "$H->>'regime'='pa0'")
$(EXIGE "$POS='capitale|dispensaire-public|salle_attente'")"

# ---- Rébellion (Fred, 01/11) : arrêté au terme du combat qui l'a mis à 0 PA ----
cas "rebellion_arrete_a_zero_pa_passe_j0_a_l_hopital_sous_ecrou" "
UPDATE personnages_donnees SET pa=0 WHERE name='A';
UPDATE personnages_donnees SET est_emprisonne='{\"raison\":\"banc\",\"jours\":3}', current_building='commissariat', current_room='prison' WHERE name='A'; $FIN
$(EXIGE "$H->>'regime'='pa0' AND ($H->>'detention')::boolean")
$(EXIGE "$H->'cellule'->>'building'='commissariat' AND $H->'cellule'->>'room'='prison'")
$(EXIGE "$POS='capitale|dispensaire-public|salle_attente'")
$(EXIGE "(SELECT est_emprisonne->>'raison' FROM personnages_donnees WHERE name='A')='banc'")"

cas "rebellion_j1_dormir_2_pa_puis_retour_en_cellule" "
$(HOSPI 1 dispensaire dispensaire-public salle_attente 0)
UPDATE personnages_donnees SET est_emprisonne='{\"raison\":\"banc\",\"jours\":3}',
 hospitalisation=hospitalisation||'{\"detention\":true,\"cellule\":{\"country\":\"republic\",\"city\":\"capitale\",\"building\":\"commissariat\",\"room\":\"prison\"}}' WHERE name='A';
$COMME_A SELECT set_config('banc.v',(pa_repos_nocturne('A'))::text,true); RESET ROLE;
$(EXIGE "$PA=2 AND (current_setting('banc.v')::jsonb->>'transfert_prison')::boolean")
$(EXIGE "$POS='capitale|commissariat|prison' AND $H IS NULL")
$(EXIGE "(SELECT (est_emprisonne->>'rebellion')::boolean FROM personnages_donnees WHERE name='A')")"

cas "rebellion_en_prison_dormir_ne_rend_que_4_pa" "
UPDATE personnages_donnees SET pa=2, current_building='commissariat', current_room='prison',
 est_emprisonne='{\"raison\":\"banc\",\"jours\":3,\"rebellion\":true}' WHERE name='A';
$COMME_A SELECT pa_repos_nocturne('A'); RESET ROLE;
$(EXIGE "$PA=6")"

cas "detenu_ordinaire_dormir_inchange" "
UPDATE personnages_donnees SET pa=2, current_building='commissariat', current_room='prison',
 est_emprisonne='{\"raison\":\"banc\",\"jours\":3}' WHERE name='A';
$COMME_A SELECT pa_repos_nocturne('A'); RESET ROLE;
$(EXIGE "$PA=14")"

cas "deja_detenu_tombe_a_zero_reste_en_cellule" "
UPDATE personnages_donnees SET est_emprisonne='{\"raison\":\"banc\",\"jours\":3}', current_building='commissariat', current_room='prison' WHERE name='A';
UPDATE personnages_donnees SET pa=0 WHERE name='A'; $FIN
$(EXIGE "$H IS NULL")
$(EXIGE "$POS='capitale|commissariat|prison'")"

cas "rebelle_libere_avant_j1_reste_patient_ordinaire" "
$(HOSPI 1 dispensaire dispensaire-public salle_attente 0)
UPDATE personnages_donnees SET hospitalisation=hospitalisation||'{\"detention\":true,\"cellule\":{\"country\":\"republic\",\"city\":\"capitale\",\"building\":\"commissariat\",\"room\":\"prison\"}}' WHERE name='A';
$COMME_A SELECT pa_repos_nocturne('A'); RESET ROLE;
$(EXIGE "$PA=2 AND $H->>'regime'='pa0' AND NOT ($H ? 'detention')")
$(EXIGE "$POS='capitale|dispensaire-public|salle_attente'")"

cas "pa_rendus_dans_la_meme_transaction_pas_d_hospitalisation" "
UPDATE personnages_donnees SET pa=0 WHERE name='A';
UPDATE personnages_donnees SET pa=4 WHERE name='A'; $FIN
$(EXIGE "$H IS NULL")"

cas "empoisonnement_garde_son_propre_fonctionnement" "
UPDATE personnages_donnees SET pa=0, hospitalisation=jsonb_build_object('lieu','dispensaire','palier','partielle',
  'dateFinParis',($AUJ + 4)::text) WHERE name='A'; $FIN
$(EXIGE "$H->>'regime' IS NULL AND $H->>'palier'='partielle'")
$(EXIGE "$POS='capitale|assemblee|hemicycle'")"

cas "sans_dispensaire_hospitalise_sur_place_et_immobilise" "
UPDATE personnages_donnees SET pa=0, current_city='qhs', current_building='qhs-prison', current_room='parloir' WHERE name='A'; $FIN
$(EXIGE "$H->>'regime'='pa0' AND $H->>'transfert'='lieu_non_reference'")
$(EXIGE "(navigation_disponibilite_interne('A'))->>'raison'='acteur_incapacite'")"

# ---- J0 ----
cas "j0_dormir_refuse_sans_rien_consommer" "
$(HOSPI 0 dispensaire dispensaire-public salle_attente 0)
$COMME_A SELECT set_config('banc.v',(pa_repos_nocturne('A'))::text,true); RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'raison'='hospitalise_j0'")
$(EXIGE "(SELECT pa_repos_le IS NULL AND pa=0 FROM personnages_donnees WHERE name='A')")"

cas "j0_immobilise_par_la_navigation_commune" "
$(HOSPI 0 dispensaire dispensaire-public salle_attente 5)
$COMME_A SELECT set_config('banc.v',(navigation_interieure('dispensaire-public','ehpad_tilleuls'))::text,true); RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'raison'='acteur_incapacite'")"

cas "j0_mail_personnel_refuse" "
$(HOSPI 0 dispensaire dispensaire-public salle_attente 0)
$COMME_A $(ESSAI "INSERT INTO mails(id,from_player,to_player,subject,body,time,read) VALUES ('m-banc','A','B','s','b','t',false)") RESET ROLE;
$(EXIGE "current_setting('banc.err') LIKE 'hospitalise_j0%'")"

cas "j0_mail_au_nom_d_une_organisation_refuse" "
$(HOSPI 0 dispensaire dispensaire-public salle_attente 0)
$COMME_A $(ESSAI "INSERT INTO mails(id,from_player,to_player,subject,body,time,read,from_real,from_org_id) VALUES ('m-banc','Mon Parti','B','s','b','t',false,'A','org-x')") RESET ROLE;
$(EXIGE "current_setting('banc.err') LIKE 'hospitalise_j0%'")"

cas "j0_sujet_de_forum_refuse" "
$(HOSPI 0 dispensaire dispensaire-public salle_attente 0)
$COMME_A $(ESSAI "INSERT INTO forum_topics(id,forum_id,title,author,country,time) VALUES ('t-banc','general','x','A','republic','t')") RESET ROLE;
$(EXIGE "current_setting('banc.err') LIKE 'hospitalise_j0%'")"

cas "j0_message_de_forum_refuse" "
$(HOSPI 0 dispensaire dispensaire-public salle_attente 0)
INSERT INTO forum_topics(id,forum_id,title,author,country,time) VALUES ('t-banc','general','x','B','republic','t');
$COMME_A $(ESSAI "INSERT INTO forum_posts(id,topic_id,author,content,time) VALUES ('p-banc','t-banc','A','c','t')") RESET ROLE;
$(EXIGE "current_setting('banc.err') LIKE 'hospitalise_j0%'")"

cas "j1_mail_permis" "
$(HOSPI 1 dispensaire dispensaire-public salle_attente 0)
$COMME_A $(ESSAI "INSERT INTO mails(id,from_player,to_player,subject,body,time,read) VALUES ('m-banc','A','B','s','b','t',false)") RESET ROLE;
$(EXIGE "current_setting('banc.err') NOT LIKE 'hospitalise_j0%'")"

cas "transfert_clinique_par_ambulance_des_j0" "
$(HOSPI 0 dispensaire dispensaire-public salle_attente 0)
UPDATE personnages_donnees SET current_city='ville_a', current_building='dispensaire-public-v', current_room='attente' WHERE name='A';
$COMME_A SELECT set_config('banc.v',(hospitalisation_lieu_rejoindre('clinique'))::text,true); RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'ok'='true'")
$(EXIGE "$POS='capitale|clinique-privee|reception_clinique' AND $H->>'lieu'='clinique' AND $H->>'regime'='pa0'")
$(EXIGE "(SELECT liquide FROM personnages_donnees WHERE name='A')=1000")"

# ---- Récupération, repas, sortie ----
cas "j1_dormir_rend_2_pa_au_dispensaire" "
$(HOSPI 1 dispensaire dispensaire-public salle_attente 0)
$COMME_A SELECT set_config('banc.v',(pa_repos_nocturne('A'))::text,true); RESET ROLE;
$(EXIGE "$PA=2 AND (current_setting('banc.v')::jsonb->>'gain')::int=2")"

cas "j1_repas_1_pa_une_fois_par_jour" "
$(HOSPI 1 dispensaire dispensaire-public salle_attente 2)
$COMME_A SELECT set_config('banc.v',(hospitalisation_repas_prendre())::text,true);
SELECT set_config('banc.v2',(hospitalisation_repas_prendre())::text,true); RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'ok'='true' AND $PA=1 AND $H->>'repasLe'=$AUJ::text")
$(EXIGE "($H->>'repasBonus')::int=2 AND (SELECT liquide FROM personnages_donnees WHERE name='A')=2000")
$(EXIGE "current_setting('banc.v2')::jsonb->>'raison'='repas_deja_pris'")"

cas "repas_refuse_hors_de_l_hopital" "
$(HOSPI 1 dispensaire assemblee hemicycle 2)
$COMME_A SELECT set_config('banc.v',(hospitalisation_repas_prendre())::text,true); RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'raison'='pas_a_l_hopital' AND $PA=2")"

cas "repas_refuse_sans_hospitalisation" "
$COMME_A SELECT set_config('banc.v',(hospitalisation_repas_prendre())::text,true); RESET ROLE;
$(EXIGE "current_setting('banc.v')::jsonb->>'raison'='non_hospitalise'")"

cas "j2_dormir_6_plus_repas_2_sortie_refusee_sous_20" "
$(HOSPI 2 dispensaire dispensaire-public salle_attente 1 repas)
$COMME_A SELECT set_config('banc.v',(pa_repos_nocturne('A'))::text,true);
SELECT set_config('banc.s',(hospitalisation_lieu_rejoindre('sortie'))::text,true); RESET ROLE;
$(EXIGE "$PA=9")
$(EXIGE "current_setting('banc.s')::jsonb->>'raison'='pa_insuffisants_sortie'")
$(EXIGE "$H->>'regime'='pa0'")"

cas "j3_dormir_12_puis_sortie_par_la_porte_du_dispensaire" "
$(HOSPI 3 dispensaire dispensaire-public salle_attente 9 repas)
$COMME_A SELECT set_config('banc.v',(pa_repos_nocturne('A'))::text,true);
SELECT set_config('banc.s',(hospitalisation_lieu_rejoindre('sortie'))::text,true); RESET ROLE;
$(EXIGE "$PA=23 AND (current_setting('banc.v')::jsonb->>'sortie_possible')::boolean")
$(EXIGE "current_setting('banc.s')::jsonb->>'ok'='true'")
$(EXIGE "$H IS NULL")
$(EXIGE "(SELECT current_building IS NULL AND current_street='luthecia-imprimerie' FROM personnages_donnees WHERE name='A')")"

cas "clinique_x3_repas_30_fr_plus_4_sortie_a_j2" "
$(HOSPI 1 clinique clinique-privee chambre_3 0)
INSERT INTO locations_actives(id,country,data) VALUES ('loc-a','republic','{\"buildingId\":\"clinique-privee\",\"roomId\":\"chambre_3\",\"city\":\"capitale\",\"locataire\":\"A\",\"chambreClinique\":true}');
$COMME_A SELECT set_config('banc.v1',(pa_repos_nocturne('A'))::text,true);
SELECT hospitalisation_repas_prendre(); RESET ROLE;
$(EXIGE "$PA=5 AND (SELECT liquide FROM personnages_donnees WHERE name='A')=1970 AND ($H->>'repasBonus')::int=4")
UPDATE personnages_donnees SET pa_repos_le=NULL,
  hospitalisation=hospitalisation||jsonb_build_object('dateDebutParis',($AUJ - 2)::text,'repasLe',($AUJ - 1)::text) WHERE name='A';
$COMME_A SELECT set_config('banc.v2',(pa_repos_nocturne('A'))::text,true);
SELECT set_config('banc.s',(hospitalisation_lieu_rejoindre('sortie'))::text,true); RESET ROLE;
$(EXIGE "(current_setting('banc.v1')::jsonb->>'gain')::int=6 AND (current_setting('banc.v2')::jsonb->>'gain')::int=18")
$(EXIGE "$PA=27 AND current_setting('banc.s')::jsonb->>'ok'='true' AND $H IS NULL")
$(EXIGE "NOT EXISTS(SELECT 1 FROM locations_actives WHERE id='loc-a')")"

cas "sortie_refusee_a_j1_meme_avec_20_pa" "
$(HOSPI 1 clinique clinique-privee reception_clinique 25)
$COMME_A SELECT set_config('banc.s',(hospitalisation_lieu_rejoindre('sortie'))::text,true); RESET ROLE;
$(EXIGE "current_setting('banc.s')::jsonb->>'raison'='sortie_trop_tot' AND $H IS NOT NULL")"

cas "sortie_sans_objet_pour_l_empoisonnement" "
UPDATE personnages_donnees SET pa=25, hospitalisation=jsonb_build_object('lieu','dispensaire','palier','partielle',
  'dateFinParis',($AUJ + 2)::text) WHERE name='A';
$COMME_A SELECT set_config('banc.s',(hospitalisation_lieu_rejoindre('sortie'))::text,true); RESET ROLE;
$(EXIGE "current_setting('banc.s')::jsonb->>'raison'='sortie_par_date'")"

cas "hors_hopital_dormir_inchange_12_pa" "
UPDATE personnages_donnees SET pa=5 WHERE name='A';
$COMME_A SELECT set_config('banc.v',(pa_repos_nocturne('A'))::text,true); RESET ROLE;
$(EXIGE "$PA=17")"

cas "droits_des_portes" "
$(EXIGE "has_function_privilege('authenticated','public.hospitalisation_repas_prendre()','EXECUTE')")
$(EXIGE "NOT has_function_privilege('anon','public.hospitalisation_repas_prendre()','EXECUTE')")
$(EXIGE "NOT has_function_privilege('authenticated','public.hospitalisation_lieu_rejoindre_interne(text,text,text,boolean,boolean)','EXECUTE')")
$(EXIGE "NOT has_function_privilege('anon','public.hospitalisation_lieu_rejoindre(text,text,boolean)','EXECUTE')")"

echo "---- $OK OK, $KO échec(s)"
