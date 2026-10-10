-- BANC DES SUBVENTIONS MUNICIPALES -- 2 SUR 3 : LA REPONSE ET LE TRANSFERT (10 octobre 2026)
--
-- Comme le banc 1 : decor ecrit dans des tables de jeu, RAISE EXCEPTION final inconditionnel,
-- ROLLBACK garanti. Voir l'en-tete de banc-subventions-1.sql pour le pourquoi.
--
-- CE QUE CE BANC MESURE, ET QU'AUCUNE PREUVE STRUCTURELLE NE PEUT ETABLIR : que l'acceptation
-- deplace EXACTEMENT le montant promis, dans les deux sens a la fois -- l'enveloppe perd 1 500,
-- la caisse du club gagne 1 500, et aucune des deux ne bouge d'un franc de plus. Une migration ne
-- peut pas le prouver, parce qu'elle commiterait ses propres effets de bord.
--
-- UNE LIMITE EST NOMMEE ICI, PLUTOT QUE MASQUEE. La consigne demande « si plusieurs dirigeants
-- habilites agissent en meme temps, une seule reponse peut gagner ». Pour la famille
-- `club_football`, la structure du jeu ne designe qu'UN gestionnaire -- le president -- donc deux
-- dirigeants habilites simultanement ne peuvent pas exister aujourd'hui. Le compare-and-swap est
-- quand meme en place, et ce banc le met a l'epreuve par la seule voie qu'une session SQL
-- unique autorise : une seconde reponse apres la premiere, qui doit perdre. La concurrence
-- VRAIMENT simultanee demanderait deux sessions, ce qu'un banc en transaction ne peut pas faire ;
-- la structure de l'UPDATE, elle, est prouvee par la migration du registre 629 (preuve P2).

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
  v_id1 text; v_id2 text; v_solde numeric; v_club numeric; v_hist jsonb; v_vues integer;
BEGIN
  -- ============================ LE DECOR ============================
  PERFORM pg_temp.je_suis_le_serveur();
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

  -- Deux propositions : 1 500 qui sera acceptee, 3 000 qui sera refusee.
  PERFORM pg_temp.je_suis(BEN);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 1500);
  v_id1 := v->>'id';
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 3000);
  v_id2 := v->>'id';
  IF v_id1 IS NULL OR v_id2 IS NULL THEN
    RAISE EXCEPTION 'DECOR : les deux propositions n''ont pas ete creees'; END IF;

  -- ============ EPREUVE 1 : UN TIERS NE REPOND PAS POUR L'ORGANISATION ============
  PERFORM pg_temp.je_suis(LEE);
  v := public.subvention_repondre(v_id1, 'accepter');
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'pas_gestionnaire_caisse' THEN
    ko := ko + 1; RAISE WARNING 'E1 un tiers a repondu : %', v; END IF;

  -- ============ EPREUVE 2 : LE MAIRE N'ACCEPTE PAS SA PROPRE SUBVENTION ============
  -- Sans cette garde, un maire se verserait a lui-meme les fonds de sa commune.
  PERFORM pg_temp.je_suis(BEN);
  v := public.subvention_repondre(v_id1, 'accepter');
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'pas_gestionnaire_caisse' THEN
    ko := ko + 1; RAISE WARNING 'E2 le maire a accepte sa propre proposition : %', v; END IF;

  -- ============ EPREUVE 3 : LE CLIENT NE NOMME PAS L'ISSUE ============
  PERFORM pg_temp.je_suis(MAY);
  v := public.subvention_repondre(v_id1, 'expiree');
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'reponse_invalide' THEN
    ko := ko + 1; RAISE WARNING 'E3 un statut forge a ete accepte : %', v; END IF;

  -- ============ EPREUVE 4 : L'ACCEPTATION TRANSFERE EXACTEMENT ============
  v := public.subvention_repondre(v_id1, 'accepter');
  n := n + 1;
  IF (v->>'ok')::boolean IS NOT TRUE OR v->>'statut' IS DISTINCT FROM 'acceptee' THEN
    ko := ko + 1; RAISE WARNING 'E4 l''acceptation a echoue : %', v; END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (data->>'solde')::numeric INTO v_solde FROM public.caisses_batiments
   WHERE id = 'republic_subventions_capitale';
  SELECT (data->>'caisse')::numeric INTO v_club FROM public.budgets_clubs
   WHERE id = 'olympique-luthecia';
  n := n + 1;
  IF v_solde <> 3500 THEN
    ko := ko + 1; RAISE WARNING 'E5 l''enveloppe vaut % au lieu de 3500', v_solde; END IF;
  n := n + 1;
  IF v_club <> 1500 THEN
    ko := ko + 1; RAISE WARNING 'E6 la caisse du club vaut % au lieu de 1500', v_club; END IF;

  -- ============ EPREUVE 7 : L'HISTORIQUE DU CLUB DIT CE QUI EST ARRIVE ============
  SELECT data->'historique' INTO v_hist FROM public.budgets_clubs WHERE id = 'olympique-luthecia';
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_hist, '[]'::jsonb)) h
                  WHERE h->>'motif' = 'Subvention municipale'
                    AND (h->>'montant')::numeric = 1500) THEN
    ko := ko + 1; RAISE WARNING 'E7 l''historique ne porte pas la subvention : %', v_hist; END IF;

  -- ============ EPREUVES 8 ET 9 : LA PREMIERE DECISION EST DEFINITIVE ============
  -- Une seconde acceptation, puis un refus apres coup : les deux doivent perdre, et SURTOUT ne
  -- rien deplacer. C'est la protection contre le rejeu d'une reponse.
  PERFORM pg_temp.je_suis(MAY);
  v := public.subvention_repondre(v_id1, 'accepter');
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'deja_close' THEN
    ko := ko + 1; RAISE WARNING 'E8 une seconde acceptation a obtenu : %', v; END IF;

  v := public.subvention_repondre(v_id1, 'refuser');
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'deja_close' THEN
    ko := ko + 1; RAISE WARNING 'E9 un refus apres acceptation a obtenu : %', v; END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF (SELECT (data->>'caisse')::numeric FROM public.budgets_clubs WHERE id='olympique-luthecia') <> 1500
     OR (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
          WHERE id='republic_subventions_capitale') <> 3500 THEN
    ko := ko + 1; RAISE WARNING 'E10 le rejeu de la reponse a deplace de l''argent'; END IF;

  -- ============ EPREUVES 11 A 13 : LE REFUS LIBERE SANS RIEN DEPLACER ============
  PERFORM pg_temp.je_suis(MAY);
  v := public.subvention_repondre(v_id2, 'refuser');
  n := n + 1;
  IF (v->>'ok')::boolean IS NOT TRUE OR v->>'statut' IS DISTINCT FROM 'refusee'
     OR (v->>'montant_libere')::numeric <> 3000 THEN
    ko := ko + 1; RAISE WARNING 'E11 le refus a echoue : %', v; END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  n := n + 1;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
       WHERE id='republic_subventions_capitale') <> 3500 THEN
    ko := ko + 1; RAISE WARNING 'E12 un refus a touche l''enveloppe'; END IF;
  n := n + 1;
  IF (SELECT (data->>'caisse')::numeric FROM public.budgets_clubs
       WHERE id='olympique-luthecia') <> 1500 THEN
    ko := ko + 1; RAISE WARNING 'E13 un refus a credite le club'; END IF;

  -- ============ EPREUVE 14 : LA RESERVE EST RETOMBEE A ZERO ============
  n := n + 1;
  IF (SELECT coalesce(sum(montant),0) FROM public.subventions_municipales
       WHERE pays='republic' AND ville='capitale' AND statut='proposee') <> 0 THEN
    ko := ko + 1; RAISE WARNING 'E14 la reserve n''est pas liberee'; END IF;

  -- ============ EPREUVE 15 : L'ARGENT LIBERE EST REUTILISABLE ============
  -- 3 500 restent dans l'enveloppe, et plus rien n'est reserve : une proposition de 3 500 doit
  -- passer. C'est ce qui prouve que le refus a rendu les fonds, et pas seulement change un mot.
  PERFORM pg_temp.je_suis(BEN);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 3500);
  n := n + 1;
  IF (v->>'ok')::boolean IS NOT TRUE OR (v->>'disponible')::numeric <> 0 THEN
    ko := ko + 1; RAISE WARNING 'E15 les fonds liberes ne sont pas reutilisables : %', v; END IF;

  -- ============ EPREUVE 16 : LES ARCHIVES CLOSES SONT PUBLIQUES ET EXACTES ============
  -- Sous l'identite d'un joueur quelconque -- donc sous la RLS -- les deux issues doivent etre
  -- lisibles, avec leur maire, leur beneficiaire, leur montant et leur statut.
  PERFORM pg_temp.je_suis(LEE);
  SELECT count(*) INTO v_vues FROM public.subventions_municipales s
   WHERE s.ville = 'capitale' AND s.maire = 'Ben'
     AND s.beneficiaire_nom IS NOT NULL AND s.montant > 0
     AND ((s.statut = 'acceptee' AND s.montant = 1500 AND s.clos_par = 'May')
       OR (s.statut = 'refusee'  AND s.montant = 3000 AND s.clos_par = 'May'));
  n := n + 1;
  IF v_vues <> 2 THEN
    ko := ko + 1; RAISE WARNING 'E16 % archive(s) publique(s) exacte(s) au lieu de 2', v_vues; END IF;

  -- ============ EPREUVE 17 : L'ENVELOPPE SURVIT AU CHANGEMENT DE MAIRE ============
  -- La caisse appartient a la commune, pas au titulaire. On destitue Ben, on elit Marsault a la
  -- capitale, et le solde ne doit pas bouger d'un franc.
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT (data->>'solde')::numeric INTO v_solde FROM public.caisses_batiments
   WHERE id = 'republic_subventions_capitale';
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = 'Ben';
  UPDATE public.cycles_electoraux
     SET data = (data::jsonb || jsonb_build_object('eluId', 'Marsault'))::text
   WHERE id = 'republic_maire_capitale';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'maire', 'name', 'Maire', 'city', 'capitale')
   WHERE name = 'Marsault';
  n := n + 1;
  IF (SELECT (data->>'solde')::numeric FROM public.caisses_batiments
       WHERE id='republic_subventions_capitale') <> v_solde THEN
    ko := ko + 1; RAISE WARNING 'E17 le changement de maire a change l''enveloppe'; END IF;

  -- ============ EPREUVE 18 : L'ANCIEN MAIRE NE PROPOSE PLUS ============
  PERFORM pg_temp.je_suis(BEN);
  v := public.subvention_proposer('club_football', 'olympique-luthecia', 100);
  n := n + 1;
  IF v->>'raison' IS DISTINCT FROM 'autorite_insuffisante' THEN
    ko := ko + 1; RAISE WARNING 'E18 un maire destitue propose encore : %', v; END IF;

  PERFORM pg_temp.je_suis_le_serveur();
  IF ko = 0 THEN RAISE EXCEPTION 'LES % EPREUVES SONT VERTES.', n;
  ELSE RAISE EXCEPTION 'ECHEC : % epreuve(s) sur % en defaut.', ko, n; END IF;
END $banc$;

ROLLBACK;
