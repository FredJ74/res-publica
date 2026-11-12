-- Banc : énigme du trésor des Tsars et fouille du serveur (migration 20261112200000), 12/11/2026.
-- Se termine TOUJOURS par une exception portant le rapport : rien ne survit.
-- Compte de test : Arnie (personnage d'essai des agents).
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.path', '/rpc/banc', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN PERFORM set_config('role', 'postgres', true); PERFORM set_config('request.jwt.claims', '', true); PERFORM set_config('request.path', '', true); END $f$;
CREATE OR REPLACE FUNCTION pg_temp.aller(p text, b text, r text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM pg_temp.serveur();
  UPDATE public.personnages_donnees SET country = 'soviet', current_city = 'capitale', current_building = b, current_room = r, pa = 20, moral = 50
   WHERE name = p;
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text), pg_temp.serveur(), pg_temp.aller(text, text, text) TO PUBLIC;

DO $banc$
DECLARE
  U text := '9abef1c4-75ab-4352-b5ca-a219fc37a35c'; A text := 'Arnie';
  v jsonb; v2 jsonb; q uuid; n int; rap text := '';
  livres int;
BEGIN
  PERFORM pg_temp.serveur();
  DELETE FROM public.enigme_tresor_tsars WHERE acteur = A;
  UPDATE public.personnages_donnees SET inventory = coalesce((SELECT jsonb_agg(o) FROM jsonb_array_elements(inventory) o
     WHERE o->>'tresorTsars' IS NULL), '[]'::jsonb) WHERE name = A;

  -- 1. Fouille ordinaire (hors énigme), dans une pièce quelconque : réponse habituelle, sans livre, 2 PA.
  PERFORM pg_temp.aller(A, 'musee-novomirsk', 'hall'); PERFORM pg_temp.je_suis(U);
  v := public.fouiller_lieux();
  IF (v->>'ok')::boolean IS DISTINCT FROM true OR v ? 'livre_tresor' OR (v->>'pa')::int <> 18
     OR NOT (v ? 'taux' AND v ? 'nb' AND v ? 'trouvees' AND v ? 'couinator') THEN RAISE EXCEPTION 'ECHEC 1 fouille ordinaire : %', v; END IF;
  rap := rap || '1 fouille ordinaire OK ; ';

  -- 2. Fouille du musée présidentiel AVANT l'énigme : pas de livre.
  PERFORM pg_temp.aller(A, 'palais-presidentiel', 'musee_presidentiel'); PERFORM pg_temp.je_suis(U);
  v := public.fouiller_lieux();
  IF (v->>'ok')::boolean IS DISTINCT FROM true OR v ? 'livre_tresor' THEN RAISE EXCEPTION 'ECHEC 2 livre trop tot : %', v; END IF;
  rap := rap || '2 pas de livre avant l''enigme ; ';

  -- 3. PNJ interrogés trop tôt : rien.
  PERFORM pg_temp.aller(A, 'poissonniere-novomirsk', 'etal_poissonniere'); PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_parler('galina_karpova', true);
  IF v->'scene' <> 'null'::jsonb THEN RAISE EXCEPTION 'ECHEC 3 karpova trop tot : %', v; END IF;

  -- 4. Guide : hors salle refusé, puis étape guide.
  v := public.tresor_tsars_guide();
  IF v->>'raison' IS DISTINCT FROM 'pas_sur_place' THEN RAISE EXCEPTION 'ECHEC 4a guide hors salle : %', v; END IF;
  PERFORM pg_temp.aller(A, 'musee-novomirsk', 'salle_origines'); PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_guide();
  IF v->>'etape' IS DISTINCT FROM 'guide' THEN RAISE EXCEPTION 'ECHEC 4b guide : %', v; END IF;
  rap := rap || '3-4 ordre impose et guide OK ; ';

  -- 5. Sudakov avant Karpova : rien. Karpova sans mot clé : rien. Puis Karpova.
  PERFORM pg_temp.aller(A, 'dispensaire-public', 'ehpad_tilleuls'); PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_parler('evgueni_sudakov', true);
  IF v->'scene' <> 'null'::jsonb THEN RAISE EXCEPTION 'ECHEC 5a sudakov avant karpova : %', v; END IF;
  PERFORM pg_temp.aller(A, 'poissonniere-novomirsk', 'etal_poissonniere'); PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_parler('galina_karpova', false);
  IF v->'scene' <> 'null'::jsonb THEN RAISE EXCEPTION 'ECHEC 5b karpova sans mot cle : %', v; END IF;
  v := public.tresor_tsars_parler('galina_karpova', true);
  IF v->>'scene' IS DISTINCT FROM 'karpova' THEN RAISE EXCEPTION 'ECHEC 5c karpova : %', v; END IF;
  rap := rap || '5 karpova OK ; ';

  -- 6. Sudakov.
  PERFORM pg_temp.aller(A, 'dispensaire-public', 'ehpad_tilleuls'); PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_parler('evgueni_sudakov', true);
  IF v->>'scene' IS DISTINCT FROM 'sudakov' THEN RAISE EXCEPTION 'ECHEC 6 sudakov : %', v; END IF;
  rap := rap || '6 sudakov OK ; ';

  -- 7. Tatiana sans livre : rien.
  PERFORM pg_temp.aller(A, 'capitaine-sauvage', 'salle_principale'); PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_parler('tatiana_bortchova', false);
  IF v->'scene' <> 'null'::jsonb THEN RAISE EXCEPTION 'ECHEC 7 tatiana sans livre : %', v; END IF;

  -- 8. Fouille du musée présidentiel : livre à coup sûr, une seule fois.
  PERFORM pg_temp.aller(A, 'palais-presidentiel', 'musee_presidentiel'); PERFORM pg_temp.je_suis(U);
  v := public.fouiller_lieux();
  IF (v->>'livre_tresor')::boolean IS DISTINCT FROM true OR (v->>'ok')::boolean IS DISTINCT FROM true
     OR NOT (v ? 'inventory' AND v ? 'revision') THEN RAISE EXCEPTION 'ECHEC 8a livre : %', v; END IF;
  v2 := public.fouiller_lieux();
  PERFORM pg_temp.serveur();
  SELECT count(*) INTO livres FROM public.personnages_donnees d, jsonb_array_elements(d.inventory) o
   WHERE d.name = A AND o->>'tresorTsars' = 'livre';
  IF v2 ? 'livre_tresor' OR livres <> 1 THEN RAISE EXCEPTION 'ECHEC 8b second livre : % (livres=%)', v2, livres; END IF;
  rap := rap || '8 livre trouve une seule fois ; ';

  -- 9. Tatiana réagit au livre ; don du livre (rejeu sans effet double).
  PERFORM pg_temp.aller(A, 'capitaine-sauvage', 'salle_principale'); PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_parler('tatiana_bortchova', false);
  IF v->>'scene' IS DISTINCT FROM 'tatiana_livre' THEN RAISE EXCEPTION 'ECHEC 9a tatiana : %', v; END IF;
  v := public.tresor_tsars_recit(gen_random_uuid());
  IF v->>'raison' IS DISTINCT FROM 'etape_invalide' THEN RAISE EXCEPTION 'ECHEC 9b recit avant don : %', v; END IF;
  q := gen_random_uuid();
  v := public.tresor_tsars_donner_livre(q);
  v2 := public.tresor_tsars_donner_livre(q);
  PERFORM pg_temp.serveur();
  SELECT count(*) INTO livres FROM public.personnages_donnees d, jsonb_array_elements(d.inventory) o
   WHERE d.name = A AND o->>'tresorTsars' = 'livre';
  IF v->>'etape' IS DISTINCT FROM 'livre_donne' OR livres <> 0 OR (v2->>'ok')::boolean IS DISTINCT FROM true
    THEN RAISE EXCEPTION 'ECHEC 9c don : % / % (livres=%)', v, v2, livres; END IF;
  rap := rap || '9 don du livre OK, rejeu sans effet ; ';

  -- 10. Récit : deux gâteaux.
  PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_recit(gen_random_uuid());
  PERFORM pg_temp.serveur();
  SELECT coalesce(sum(coalesce((o->>'qty')::int, 1)), 0) INTO n FROM public.personnages_donnees d, jsonb_array_elements(d.inventory) o
   WHERE d.name = A AND o->>'stackKey' = 'tresor-tsars';
  IF v->>'etape' IS DISTINCT FROM 'terminee' OR n <> 2 THEN RAISE EXCEPTION 'ECHEC 10 recit : % (gateaux=%)', v, n; END IF;
  rap := rap || '10 recit et 2 gateaux OK ; ';

  -- 11. Manger un gâteau frais : +1 PA, +10 moral, il en reste un.
  PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_manger(gen_random_uuid());
  PERFORM pg_temp.serveur();
  SELECT coalesce(sum(coalesce((o->>'qty')::int, 1)), 0) INTO n FROM public.personnages_donnees d, jsonb_array_elements(d.inventory) o
   WHERE d.name = A AND o->>'stackKey' = 'tresor-tsars';
  IF (v->>'frais')::boolean IS DISTINCT FROM true OR (v->>'pa')::int <> 21 OR (v->>'moral')::int <> 60 OR n <> 1
    THEN RAISE EXCEPTION 'ECHEC 11 manger : % (reste=%)', v, n; END IF;
  rap := rap || '11 gateau frais +1 PA +10 moral OK ; ';

  -- 12. Gâteau périmé (reçu il y a 5 jours) : -1 PA.
  UPDATE public.personnages_donnees SET inventory = (SELECT jsonb_agg(CASE WHEN o->>'stackKey' = 'tresor-tsars'
      THEN o || jsonb_build_object('recuA', floor(extract(epoch FROM now() - interval '5 days') * 1000)) ELSE o END) FROM jsonb_array_elements(inventory) o)
   WHERE name = A;
  PERFORM pg_temp.je_suis(U);
  v := public.tresor_tsars_manger(gen_random_uuid());
  IF (v->>'frais')::boolean IS DISTINCT FROM false OR (v->>'pa')::int <> 20 THEN RAISE EXCEPTION 'ECHEC 12 perime : %', v; END IF;
  rap := rap || '12 gateau perime -1 PA OK ; ';

  -- 13. Énigme terminée : la fouille du musée ne redonne pas de livre.
  PERFORM pg_temp.aller(A, 'palais-presidentiel', 'musee_presidentiel'); PERFORM pg_temp.je_suis(U);
  v := public.fouiller_lieux();
  IF v ? 'livre_tresor' OR (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'ECHEC 13 livre apres la fin : %', v; END IF;
  rap := rap || '13 pas de livre apres la fin';

  RAISE EXCEPTION 'RAPPORT VERT : %', rap;
END $banc$;
ROLLBACK;
