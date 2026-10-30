#!/usr/bin/env bash
# Banc : achats simultanes sur deux sessions authentifiees REELLES (30/10/2026).
# Cible : une base PostgreSQL JETABLE (jamais la production), reconstruite depuis
# baseline/ + migrations/, dont les fonctions du parcours d'achat ont ete verifiees
# identiques a la production par empreinte md5. Usage : PGCIBLE="-h hote -p port -U postgres -d base" $0
set -u
P="psql $PGCIBLE -X -q -At -v ON_ERROR_STOP=1"
U1=11111111-1111-4111-8111-111111111111; U2=22222222-2222-4222-8222-222222222222
$P >/dev/null <<SQL || { echo 'MONTAGE EN ECHEC'; exit 99; }
BEGIN;
SET check_function_bodies = off;
INSERT INTO public.villes(pays,ville,nom,rang) SELECT 'republic','ville_a','Ville fictive',9
  WHERE NOT EXISTS (SELECT 1 FROM public.villes WHERE pays='republic');
INSERT INTO auth.users(id) VALUES ('$U1'),('$U2') ON CONFLICT DO NOTHING;
DELETE FROM public.inventaire_actions_recus WHERE acteur IN ('Alpha','Beta');
DELETE FROM public.comptes_bancaires WHERE personnage IN ('Alpha','Beta');
DELETE FROM public.personnages_donnees WHERE name IN ('Alpha','Beta');
-- Le declencheur de rattachement prend le compte connecte : chaque fiche est creee sous le sien.
SELECT set_config('request.jwt.claims', '{"sub":"$U1","role":"authenticated"}', true);
INSERT INTO public.personnages_donnees(name,country,user_id,pa,liquide,arg,inventory) VALUES ('Alpha','republic','$U1',50,10000,10000,'[]');
SELECT set_config('request.jwt.claims', '{"sub":"$U2","role":"authenticated"}', true);
INSERT INTO public.personnages_donnees(name,country,user_id,pa,liquide,arg,inventory) VALUES ('Beta','republic','$U2',50,10000,10000,'[]');
SELECT set_config('request.jwt.claims', '', true);
UPDATE public.personnages_donnees SET pa=50, liquide=10000, arg=10000, inventory='[]' WHERE name IN ('Alpha','Beta');
INSERT INTO public.comptes_bancaires(id,personnage,pays,banque,solde) VALUES ('cb-alpha','Alpha','republic','nationale',0),('cb-beta','Beta','republic','nationale',0);
INSERT INTO public.ressources_economie(cle,prix_base) VALUES ('bois',5) ON CONFLICT (cle) DO UPDATE SET prix_base=5;
INSERT INTO public.ordres_couts(fn,pa,cost) SELECT 'acheter_ressources_entrepot',1,0
  WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn='acheter_ressources_entrepot' AND pa=1 AND cost=0);
DELETE FROM public.batiments_etat WHERE id='republic_ville_a_entrepot-logistique-psm';
INSERT INTO public.batiments_etat(id,country,city,building_id,data)
  VALUES ('republic_ville_a_entrepot-logistique-psm','republic','ville_a','entrepot-logistique-psm','{"entrepot":{"stock":{"bois":100000}}}');
COMMIT;
SQL
$P -c "SELECT name||':'||user_id FROM public.personnages_donnees WHERE name IN ('Alpha','Beta') ORDER BY 1" | tr '\n' ' '; echo
etat() { $P -c "SELECT d.name||' pa='||d.pa||' liquide='||d.liquide||' bois='||coalesce((SELECT sum((e->>'qty')::int) FROM jsonb_array_elements(d.inventory) e WHERE e->>'stackKey'='bois'),0)||' recus='||(SELECT count(*) FROM public.inventaire_actions_recus WHERE acteur=d.name) FROM public.personnages_donnees d WHERE d.name='$1'"; }
stock() { $P -c "SELECT (public.batiment_etat_lire(data)->'entrepot'->'stock'->>'bois') FROM public.batiments_etat WHERE id='republic_ville_a_entrepot-logistique-psm'"; }
# Une session = une connexion psql distincte, authentifiee comme le fait PostgREST.
achat() { # $1 uid $2 nom $3 cle $4 qte $5 pause_dans_la_transaction
  $P 2>>/tmp/banc-concurrents-erreurs.log <<SQL
SET role authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"$1","role":"authenticated"}', false) \g /dev/null
SELECT set_config('request.path', '/rpc/acheter_a_entrepot', false) \g /dev/null
BEGIN;
SELECT to_char(clock_timestamp(),'SS.MS')||' '||(r->>'ok')||' rejeu='||coalesce(r->>'rejeu','non')||' paye='||coalesce(r->>'paye','-')||' '||coalesce(r->>'raison','')
  FROM (SELECT public.acheter_a_entrepot('$3'::uuid,'$2','republic','ville_a','entrepot-logistique-psm','{"bois":$4}',1,0) r) x;
SELECT pg_sleep($5) \g /dev/null
COMMIT;
SELECT to_char(clock_timestamp(),'SS.MS')||' fin';
SQL
}
ko=0; verif() { if [ "$1" = "$2" ]; then echo "  ok : $3"; else echo "  KO : $3 (attendu « $2 », obtenu « $1 »)"; ko=$((ko+1)); fi; }

echo "S1 meme cle, deux sessions, la premiere garde sa transaction ouverte 2 s"
K=$(cat /proc/sys/kernel/random/uuid); A0=$(etat Alpha); S0=$(stock); T0=$(date +%s.%N)
achat $U1 Alpha $K 2 2 > /tmp/s1a & sleep 0.3; achat $U1 Alpha $K 2 0 > /tmp/s1b & wait
echo "  session 1 : $(tr '\n' ' ' </tmp/s1a)"; echo "  session 2 : $(tr '\n' ' ' </tmp/s1b)"
verif "$(etat Alpha)" "Alpha pa=49 liquide=9990 bois=2 recus=1" "un seul debit (1 PA, 10 FR), une seule livraison, une cle"
verif "$(stock)" "99998" "stock de l'entrepot diminue une seule fois"
verif "$(grep -c 'rejeu=true' /tmp/s1a /tmp/s1b | awk -F: '{s+=$2} END {print s}')" "1" "exactement une reponse est un rejeu"
verif "$(grep -q 'rejeu=true' /tmp/s1b && echo seconde)" "seconde" "la seconde session a attendu la premiere puis a rejoue"

echo "S2 meme cle, deux sessions lancees au meme instant, 20 fois"
before=$($P -c "SELECT liquide FROM public.personnages_donnees WHERE name='Alpha'")
for i in $(seq 1 20); do K=$(cat /proc/sys/kernel/random/uuid); achat $U1 Alpha $K 1 0 >/dev/null & achat $U1 Alpha $K 1 0 >/dev/null & wait; done
verif "$(etat Alpha)" "Alpha pa=29 liquide=9890 bois=22 recus=21" "20 paires = 20 achats, ni plus ni moins"

echo "S3 deux cles distinctes, meme joueur, concurrentes"
K1=$(cat /proc/sys/kernel/random/uuid); K2=$(cat /proc/sys/kernel/random/uuid)
achat $U1 Alpha $K1 3 1 > /tmp/s3a & achat $U1 Alpha $K2 4 1 > /tmp/s3b & wait
verif "$(grep -c 'true rejeu=non' /tmp/s3a /tmp/s3b | awk -F: '{s+=$2} END {print s}')" "2" "deux achats distincts acceptes"
verif "$(etat Alpha)" "Alpha pa=27 liquide=9855 bois=29 recus=23" "deux debits (2 PA, 35 FR) et deux livraisons, aucune ecriture perdue"

echo "S4 deux joueurs, cles distinctes, concurrents, 10 fois"
for i in $(seq 1 10); do achat $U1 Alpha $(cat /proc/sys/kernel/random/uuid) 1 0 >/dev/null & achat $U2 Beta $(cat /proc/sys/kernel/random/uuid) 1 0 >/dev/null & wait; done
verif "$(etat Alpha)" "Alpha pa=17 liquide=9805 bois=39 recus=33" "Alpha : 10 achats"
verif "$(etat Beta)" "Beta pa=40 liquide=9950 bois=10 recus=10" "Beta : 10 achats"
verif "$(stock)" "$((100000-2-20-7-10-10))" "stock coherent avec toutes les livraisons"

echo "S5 meme cle reutilisee par une autre session avec un autre panier pendant la premiere"
K=$(cat /proc/sys/kernel/random/uuid)
achat $U1 Alpha $K 1 1 > /tmp/s5a & sleep 0.3; achat $U1 Alpha $K 5 0 > /tmp/s5b & wait
verif "$(grep -o 'requete_reutilisee' /tmp/s5b)" "requete_reutilisee" "autre panier sous la meme cle refuse"
verif "$(etat Alpha)" "Alpha pa=16 liquide=9800 bois=40 recus=34" "un seul achat (1 bois)"

echo "BILAN : $ko echec(s)"; exit $ko
