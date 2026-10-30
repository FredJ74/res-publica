-- Banc : capacite de l'Entrepot par la regle universelle (migration 20261030200000), 30/10/2026.
-- Executable sur la production : tout est annule (exception finale). Le premier bloc fabrique la
-- nouvelle fonction depuis la version en production et verifie qu'elle est identique, octet pour
-- octet, a celle du fichier de migration (md5). Compte de test : Arnie.
-- Resultat du 30/10/2026 : 6 controles, 0 echec ; place universelle 86 contre 95 pour l'ancien calcul.
BEGIN;
DO $m$
DECLARE d text;
BEGIN
  d := replace(rtrim(pg_get_functiondef('public.acheter_a_entrepot(text,text,text,text,jsonb)'::regprocedure), E'\n'),
$o$  -- Place restante : meme regle que addToInventory (plafond global de 100, toutes
  -- lignes confondues, qty ou encombrement a defaut).
  SELECT coalesce(sum(coalesce((e->>'qty')::numeric, (e->>'encombrement')::numeric, 1)), 0)::int
    INTO v_occupe FROM jsonb_array_elements(v_inv) e;
  v_place := greatest(0, 100 - v_occupe);$o$,
$n$  -- Place restante : la regle universelle (30/10/2026), comme la Criee, l'usine,
  -- la manufacture et inventaire_deposer_interne. L'ancien calcul local ignorait
  -- la quantite des piles a `quantite` (tracts) : 87 bois livres pour 86 places.
  v_place := public.inventaire_place_restante(v_inv);$n$);
  IF md5(d) <> 'a77f5dd9209a37ea6dd9b648126614a2' THEN RAISE EXCEPTION 'texte different du fichier de migration : %', md5(d); END IF;
  EXECUTE d;
END $m$;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.path', '/rpc/banc', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN PERFORM set_config('role', 'postgres', true); PERFORM set_config('request.jwt.claims', '', true); PERFORM set_config('request.path', '', true); END $f$;
CREATE OR REPLACE FUNCTION pg_temp.etat(p text) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT jsonb_build_object('pa', d.pa, 'liquide', coalesce(d.liquide,0), 'rev', d.inventory_revision,
    'place', public.inventaire_place_restante(d.inventory),
    'ancienne_place', greatest(0, 100 - (SELECT coalesce(sum(coalesce((e->>'qty')::numeric, (e->>'encombrement')::numeric, 1)),0)::int FROM jsonb_array_elements(d.inventory) e)),
    'lignes', jsonb_array_length(d.inventory),
    'piles_bois', (SELECT count(*) FROM jsonb_array_elements(d.inventory) e WHERE e->>'stackKey'='bois'),
    'bois', coalesce((SELECT sum((e->>'qty')::int) FROM jsonb_array_elements(d.inventory) e WHERE e->>'stackKey'='bois'),0),
    'recus', (SELECT count(*) FROM public.inventaire_actions_recus WHERE acteur = p),
    'stock', (SELECT (public.batiment_etat_lire(data)->'entrepot'->'stock'->>'bois')::int FROM public.batiments_etat WHERE id='republic_ville_a_entrepot-logistique-psm'))
  FROM public.personnages_donnees d WHERE d.name = p $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text), pg_temp.serveur(), pg_temp.etat(text) TO PUBLIC;
DO $banc$
DECLARE U text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; A text := 'Arnie';
  v jsonb; w jsonb; e0 jsonb; e1 jsonb; r text := ''; n int := 0; ko int := 0; p int;
  B text := $b$SELECT public.acheter_a_entrepot(gen_random_uuid(), 'Arnie', 'republic', 'ville_a', 'entrepot-logistique-psm', $1, 1, 0)$b$;
BEGIN
  PERFORM pg_temp.serveur();
  UPDATE public.personnages_donnees SET liquide = 1000000, pa = 20 WHERE name = A;
  e0 := pg_temp.etat(A);
  r := r || E'\nDepart : place universelle ' || (e0->>'place') || ', ancien calcul ' || (e0->>'ancienne_place') || ', piles de bois ' || (e0->>'piles_bois');
  -- C1 nouvelle pile empilable
  n := n + 1; PERFORM pg_temp.je_suis(U); EXECUTE B INTO v USING '{"bois":2}'::jsonb; PERFORM pg_temp.serveur(); e1 := pg_temp.etat(A);
  IF (v->>'ok')::boolean IS NOT TRUE OR (e1->>'bois')::int <> (e0->>'bois')::int + 2 OR (e1->>'piles_bois')::int <> 1 OR (e1->>'place')::int <> (e0->>'place')::int - 2 THEN
    ko := ko + 1; r := r || E'\nC1 KO ' || e0 || ' -> ' || e1; ELSE r := r || E'\nC1 ok : 2 bois, une seule pile, place -2'; END IF;
  -- C2 ajout sur la meme pile
  e0 := e1; n := n + 1; PERFORM pg_temp.je_suis(U); EXECUTE B INTO v USING '{"bois":3}'::jsonb; PERFORM pg_temp.serveur(); e1 := pg_temp.etat(A);
  IF (v->>'ok')::boolean IS NOT TRUE OR (e1->>'bois')::int <> (e0->>'bois')::int + 3 OR (e1->>'piles_bois')::int <> 1 OR (e1->>'lignes')::int <> (e0->>'lignes')::int THEN
    ko := ko + 1; r := r || E'\nC2 KO ' || e0 || ' -> ' || e1; ELSE r := r || E'\nC2 ok : +3 sur la meme pile (5 bois, aucune ligne en plus)'; END IF;
  -- C3 demande au-dela de la place : livraison partielle exactement jusqu'au plafond universel
  e0 := e1; p := (e0->>'place')::int; n := n + 1;
  PERFORM pg_temp.je_suis(U); EXECUTE B INTO v USING jsonb_build_object('bois', p + 9); PERFORM pg_temp.serveur(); e1 := pg_temp.etat(A);
  IF (v->>'ok')::boolean IS NOT TRUE OR (e1->>'place')::int <> 0 OR (e1->>'bois')::int <> (e0->>'bois')::int + p
     OR (e0->>'stock')::int - (e1->>'stock')::int <> p OR (v->>'paye')::numeric <> p * ((v->'lignes'->0->>'prix')::numeric) THEN
    ko := ko + 1; r := r || E'\nC3 KO ' || v - 'inventory' || ' ' || e0 || ' -> ' || e1;
  ELSE r := r || E'\nC3 ok : ' || (p + 9) || ' demandes, ' || p || ' livrees et payees (' || (v->>'paye') || ' FR), place 0 ; ancien calcul en aurait encore admis ' || (e1->>'ancienne_place'); END IF;
  -- C4 plein : Entrepot refuse, rien preleve (PA compris), rien enregistre
  e0 := e1; n := n + 1; PERFORM pg_temp.je_suis(U); EXECUTE B INTO v USING '{"bois":1}'::jsonb; PERFORM pg_temp.serveur(); e1 := pg_temp.etat(A);
  IF v->>'raison' IS DISTINCT FROM 'inventaire_plein' OR e1 <> e0 THEN ko := ko + 1; r := r || E'\nC4 KO ' || v - 'inventory' || ' ' || e1;
  ELSE r := r || E'\nC4 ok : plein -> inventaire_plein, PA et fonds intacts, rien enregistre'; END IF;
  -- C5 meme verdict ailleurs : gilet (depot universel)
  n := n + 1; PERFORM pg_temp.je_suis(U);
  w := public.objet_acheter(gen_random_uuid(), 'acheter_gilet', 'gilet', 1, 600);
  PERFORM pg_temp.serveur(); e1 := pg_temp.etat(A);
  IF w->>'raison' IS DISTINCT FROM 'inventaire_plein' OR e1 <> e0 THEN ko := ko + 1; r := r || E'\nC5 KO ' || w - 'inventory';
  ELSE r := r || E'\nC5 ok : gilet refuse de meme (inventaire_plein)'; END IF;
  -- C6 une place liberee : 1 bois livre sur 4 demandes
  n := n + 1;
  UPDATE public.personnages_donnees SET inventory = (SELECT jsonb_agg(CASE WHEN e->>'stackKey'='bois' THEN jsonb_set(e,'{qty}',to_jsonb((e->>'qty')::int - 1)) ELSE e END) FROM jsonb_array_elements(inventory) e) WHERE name = A;
  e0 := pg_temp.etat(A); PERFORM pg_temp.je_suis(U); EXECUTE B INTO v USING '{"bois":4}'::jsonb; PERFORM pg_temp.serveur(); e1 := pg_temp.etat(A);
  IF (e0->>'place')::int <> 1 OR (v->>'ok')::boolean IS NOT TRUE OR (v->'lignes'->0->>'qte')::int <> 4 OR (e1->>'bois')::int <> (e0->>'bois')::int + 1 OR (e1->>'place')::int <> 0 THEN
    ko := ko + 1; r := r || E'\nC6 KO ' || v - 'inventory' || ' ' || e0 || ' -> ' || e1;
  ELSE r := r || E'\nC6 ok : 1 place -> 1 bois livre sur 4 demandes, paye ' || (v->>'paye') || ' FR'; END IF;
  RAISE EXCEPTION 'BANC entrepot-capacite : % controles, % echec(s)%', n, ko, r;
END $banc$;

ROLLBACK;
