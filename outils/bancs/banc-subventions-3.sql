-- BANC DES SUBVENTIONS MUNICIPALES -- 3 SUR 3 : L'EXPIRATION (10 octobre 2026)
--
-- Comme les bancs 1 et 2 : decor en tables de jeu, RAISE EXCEPTION final, ROLLBACK garanti.
--
-- COMMENT ON FAIT VIEILLIR UNE PROPOSITION SANS TRUQUER LE CALENDRIER. On ne touche PAS au jour
-- de jeu : le modifier changerait le monde entier pour une seule epreuve, et toutes les autres
-- mesures deviendraient douteuses. On vieillit la PROPOSITION -- son jour passe de 28 a 25, son
-- echeance de 31 a 28 -- ce que la contrainte `jour_echeance = jour + 3` oblige a faire des deux
-- cotes a la fois. Le jour de jeu reste 28, et l'echeance tombe donc aujourd'hui.
--
-- LA FRONTIERE EST EPROUVEE DES DEUX COTES, parce qu'un delai juste a un jour pres est faux. Le
-- contrat est : proposee au jour J, repondable J, J+1, J+2, expiree des que le jour atteint J+3.
-- Une proposition d'echeance 28 expire donc aujourd'hui ; une d'echeance 29 ne doit PAS expirer.

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END $f$;

CREATE OR REPLACE FUNCTION pg_temp.je_suis_le_serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', '', true);
END $f$;

GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;

DO $banc$
DECLARE
  BEN text := 'bafc96b1-1628-4ae2-93d2-78d89f8ac5b5';
  MAY text := '3d91b1fa-a22d-41ae-82cf-fef98194b10a';
  LEE text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6';
  v jsonb; ko integer := 0; n integer := 0;
  v_jour integer; v_id1 text; v_id2 text; v_id3 text; v_vues integer;
BEGIN
  -- ============================ LE DECOR ============================
  PERFORM pg_temp.je_suis_le_serveur();
  v_jour := public.jour_de_jeu_pays('republic');
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('eluId', 'Ben', 'phase', 'mandat'))::text
   WHERE id = 'republic_maire_capitale';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'maire', 'name', 'Maire', 'city', 'capitale')
   WHERE name = 'Ben';
  INSERT INTO public.presidents_clubs (id, data, updated_at)
  VALUES ('olympique-luthecia', jsonb_build_object('president', 'May'), now())
  ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data;
  UPDATE public.caisses_batiments SET data = jsonb_build_object('solde', 5000)
   WHERE id = 'republic_subventions_capitale';

  PERFORM pg_temp.je_suis(BEN);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1200);
  v_id1 := v->>'id';
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 800);
  v_id2 := v->>'id';
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 600);
  v_id3 := v->>'id';

  -- id1 : echeance AUJOURD'HUI, doit expirer. id2 : echeance DEMAIN, ne doit pas expirer.
  -- id3 : laissee intacte (echeance J+3), ne doit pas expirer non plus.
  PERFORM pg_temp.je_suis_le_serveur();
  UPDATE public.subventions_municipales
     SET jour = v_jour - 3, jour_echeance = v_jour WHERE id = v_id1;
  UPDATE public.subventions_municipales
     SET jour = v_jour - 2, jour_echeance = v_jour + 1 WHERE id = v_id2;

  -- ============ EPREUVE 1 : UN CLIENT NE DECLENCHE PAS L'EXPIRATION ============
  -- Un joueur qui pourrait l'appeler libererait la reserve d'une commune a volonte.
  PERFORM pg_temp.je_suis(LEE);
  n := n + 1;
  BEGIN
    PERFORM public.subventions_expirer('republic');
    ko := ko + 1; RAISE WARNING 'E1 un client a declenche l''expiration';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
            WHEN others THEN NULL;
  END;

  -- ============ EPREUVES 2 A 4 : LA PASSE N'EXPIRE QUE CE QUI EST ECHU ============
  PERFORM pg_temp.je_suis_le_serveur();
  v := public.subventions_expirer('republic');
  n := n + 1;
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'expirees')::integer <> 1
     OR (v->>'montant_libere')::numeric <> 1200 THEN
    ko := ko + 1; RAISE WARNING 'E2 la passe d''expiration a rendu : %', v; END IF;

  n := n + 1;
  IF (SELECT statut FROM public.subventions_municipales WHERE id = v_id1) <> 'expiree' THEN
    ko := ko + 1; RAISE WARNING 'E3 la proposition echue n''est pas expiree'; END IF;

  -- LA FRONTIERE : celle d'echeance demain, et celle intacte, sont toujours en attente.
  n := n + 1;
  IF (SELECT count(*) FROM public.subventions_municipales
       WHERE id IN (v_id2, v_id3) AND statut = 'proposee') <> 2 THEN
    ko := ko + 1; RAISE WARNING 'E4 la passe a expire une proposition non echue'; END IF;

  -- ============ EPREUVES 5 ET 6 : L'EXPIRATION NE DEPLACE AUCUN ARGENT ============
  n := n + 1;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
       WHERE id='republic_subventions_capitale') <> 5000 THEN
    ko := ko + 1; RAISE WARNING 'E5 l''expiration a touche l''enveloppe'; END IF;
  n := n + 1;
  IF (SELECT (data->>'caisse')::numeric FROM public.budgets_clubs
       WHERE id='olympique-luthecia') <> 0 THEN
    ko := ko + 1; RAISE WARNING 'E6 l''expiration a credite le club'; END IF;

  -- ============ EPREUVE 7 : UNE EXPIRATION N'A PAS D'AUTEUR ============
  -- Personne ne l'a decidee : le temps l'a close. La contrainte de coherence l'impose, cette
  -- epreuve verifie que la fonction la respecte.
  n := n + 1;
  IF (SELECT clos_par FROM public.subventions_municipales WHERE id = v_id1) IS NOT NULL
     OR (SELECT clos_le FROM public.subventions_municipales WHERE id = v_id1) IS NULL THEN
    ko := ko + 1; RAISE WARNING 'E7 l''expiration a un auteur, ou pas de date'; END IF;

  -- ============ EPREUVE 8 : LA RESERVE EST LIBEREE POUR DE VRAI ============
  -- 1 400 restaient reserves (800 + 600) sur 5 000 : il doit y avoir 3 600 disponibles, et une
  -- proposition de 3 600 doit passer. C'est la preuve que le montant expire est revenu.
  PERFORM pg_temp.je_suis(BEN);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 3600);
  n := n + 1;
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'disponible')::numeric <> 0 THEN
    ko := ko + 1; RAISE WARNING 'E8 les fonds expires ne sont pas revenus : %', v; END IF;

  -- ============ EPREUVE 9 : L'EXPIRATION EST IDEMPOTENTE ============
  -- Un second passage la meme nuit -- un rejeu du cron -- ne doit rien trouver. C'est pour cela
  -- qu'aucune revendication nocturne n'etait necessaire.
  PERFORM pg_temp.je_suis_le_serveur();
  v := public.subventions_expirer('republic');
  n := n + 1;
  IF (v->>'expirees')::integer <> 0 OR (v->>'montant_libere')::numeric <> 0 THEN
    ko := ko + 1; RAISE WARNING 'E9 un second passage a re-expire : %', v; END IF;

  -- ============ EPREUVE 10 : REPONDRE A UNE PROPOSITION ECHUE LA CLOT ============
  -- La passe du 8 octobre 2026 n'a pas tourne. Si cela se reproduit, une proposition echue doit
  -- etre close au premier passage de quiconque, pour ne pas immobiliser l'argent indefiniment.
  UPDATE public.subventions_municipales
     SET jour = v_jour - 3, jour_echeance = v_jour WHERE id = v_id2;
  PERFORM pg_temp.je_suis(MAY);
  v := public.subvention_repondre(v_id2, 'accepter');
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'proposition_echue'
     OR (v->>'montant_libere')::numeric <> 800 THEN
    ko := ko + 1; RAISE WARNING 'E10 la reponse a une echue a rendu : %', v; END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF (SELECT statut FROM public.subventions_municipales WHERE id = v_id2) <> 'expiree' THEN
    ko := ko + 1; RAISE WARNING 'E11 la reponse a une echue ne l''a pas close'; END IF;

  -- ============ EPREUVE 12 : ET ELLE N'A RIEN VERSE ============
  n := n + 1;
  IF (SELECT (data->>'caisse')::numeric FROM public.budgets_clubs
       WHERE id='olympique-luthecia') <> 0
     OR (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
          WHERE id='republic_subventions_capitale') <> 5000 THEN
    ko := ko + 1; RAISE WARNING 'E12 une acceptation echue a deplace de l''argent'; END IF;

  -- ============ EPREUVE 13 : LE NON-DIT DE TROIS JOURS EST PUBLIC ============
  -- « Un non-dit de trois jours doit aussi laisser une trace publique. » Sous la RLS, les deux
  -- expirations doivent etre lisibles par n'importe qui, avec leur maire et leur montant.
  PERFORM pg_temp.je_suis(LEE);
  SELECT count(*) INTO v_vues FROM public.subventions_municipales s
   WHERE s.statut = 'expiree' AND s.ville = 'capitale' AND s.maire = 'Ben'
     AND s.beneficiaire_nom IS NOT NULL AND s.clos_par IS NULL
     AND s.montant IN (1200, 800);
  n := n + 1;
  IF v_vues <> 2 THEN
    ko := ko + 1; RAISE WARNING 'E13 % expiration(s) publique(s) au lieu de 2', v_vues; END IF;

  -- ============ EPREUVE 14 : AUCUN JUGEMENT DE JEU N'EST PORTE ============
  -- La consigne l'interdit explicitement. Aucune colonne de la table ne doit nommer un jugement :
  -- le systeme expose des faits, les joueurs les interpretent.
  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'subventions_municipales'
                AND (column_name ILIKE '%favoritisme%' OR column_name ILIKE '%clientelisme%'
                  OR column_name ILIKE '%score%' OR column_name ILIKE '%indice%'
                  OR column_name ILIKE '%jugement%' OR column_name ILIKE '%reputation%')) THEN
    ko := ko + 1; RAISE WARNING 'E14 une colonne porte un jugement de jeu'; END IF;

  IF ko = 0 THEN RAISE EXCEPTION 'LES % EPREUVES SONT VERTES.', n;
  ELSE RAISE EXCEPTION 'ECHEC : % epreuve(s) sur % en defaut.', ko, n; END IF;
END $banc$;

ROLLBACK;
