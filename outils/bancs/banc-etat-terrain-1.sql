-- BANC DE L'ETAT D'UN TERRAIN -- 1/2 : LES AUTORITES, ET CE QUE L'ANCIEN CHEMIN PERMETTAIT
-- Chantier 5, les 22 ecritures de `terrains_etat` (10 octobre 2026).
--
-- Une transaction annulee, aucune donnee residuelle, verdict leve en EXCEPTION.
--
-- CE QU'IL ETABLIT, et les TROIS CONTRE-EPREUVES qui en font une preuve :
--
--   * REPRENDRE LE COMPROMIS D'UN AUTRE. `doAccepterTransfertCompromis` posait `compromisPar` a
--     son propre nom sans jamais verifier que le transfert LUI avait ete propose -- seul l'ecran
--     filtrait. La contre-epreuve refait cet UPDATE a l'identique, en `authenticated`.
--
--   * TRANCHER LE PERMIS D'UN AUTRE. `traiterPermis` ne verifiait rien du tout. La contre-epreuve
--     refait l'UPDATE par lequel un joueur sans poste posait `permis.statut = 'valide'` sur le
--     terrain d'autrui.
--
--   * GELER LE TERRAIN D'UN AUTRE. `succession_gel` est la cle que les quatre portes consultent
--     pour refuser toute action. La contre-epreuve refait l'UPDATE par lequel un gel INVENTE
--     passait -- le defaut que le chantier C avait ferme sur l'entreprise et laisse ouvert sur le
--     terrain.
--
-- CE QUE LES TROIS CONTRE-EPREUVES MESURENT DEPUIS LE REGISTRE 634. Elles constataient jusque-la
-- que l'ancien chemin ABOUTISSAIT (0 refus de la policy, qui n'etait que `acteur_identifie()`), et
-- que seule la porte le refusait. Le registre 634 a revoque INSERT et UPDATE a `authenticated` sur
-- `terrains_etat` : les memes UPDATE, conserves mot pour mot, LEVENT maintenant `42501 permission
-- denied`. Les contre-epreuves attrapent ce refus -- et uniquement celui-la, jamais `others` -- et
-- c'est desormais l'ABSENCE d'exception qui est l'echec. La garantie mesuree est plus forte : le
-- chemin client n'est plus seulement inutile, il est ferme.
--
-- COMMENT IL A REELLEMENT TOURNE. Tel quel sous psql. Par le canal MCP de ce depot, qui plafonne
-- a ~12 500 caracteres de SQL, il a ete envoye DEBARRASSE DE SES LIGNES DE COMMENTAIRE.
BEGIN;
DO $banc$
DECLARE
  ko text[] := '{}'; n integer := 0; v jsonb; d jsonb; c integer;
  -- Vrai quand l'ecriture cliente directe a bien ete refusee par le PRIVILEGE (registre 634).
  v_refuse boolean;
  BEN constant text := '{"sub":"bafc96b1-1628-4ae2-93d2-78d89f8ac5b5","role":"authenticated"}';
  T constant text := 'zzbanc-terrain';
BEGIN
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.terrains_etat WHERE building_id = T;
  UPDATE public.personnages_donnees SET poste = NULL WHERE name IN ('Ben', 'May');
  INSERT INTO public.terrains_etat (id, country, building_id, proprietaire, data)
  VALUES ('republic_' || T, 'republic', T, 'May',
    '{"city":"ville_a","proprietaire":"May","compromis":true,"compromisPar":"May","surface":2000}');

  -- ------------------------------------------------- 1. REPRENDRE LE COMPROMIS D'UN AUTRE
  PERFORM set_config('request.jwt.claims', BEN, true);
  PERFORM set_config('role', 'authenticated', true);
  v := public.terrain_compromis_acte(T, 'compromis_transfert_accepter', '{}'::jsonb);
  n := n + 1; IF v ->> 'raison' <> 'transfert_non_propose'
    THEN ko := ko || ('1 un tiers reprend un compromis : ' || v::text); END IF;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.terrains_etat WHERE building_id = T;
  n := n + 1; IF d ->> 'compromisPar' <> 'May'
    THEN ko := ko || ('2 le detenteur a change malgre le refus : ' || d::text); END IF;

  -- CONTRE-EPREUVE 3 : l'ancien chemin, refait a l'identique -- mais il est desormais refuse par
  -- le DROIT, et plus seulement par la policy. Le registre 634 a revoque INSERT et UPDATE a
  -- `authenticated` sur `terrains_etat` : l'UPDATE direct ne renvoie plus 0 ligne, il LEVE un
  -- refus de privilege. On l'attrape, et c'est l'ABSENCE d'exception qui serait l'echec. La preuve
  -- est plus forte qu'avant : a l'epoque ce chemin ABOUTISSAIT, et seule la porte le refusait.
  PERFORM set_config('role', 'authenticated', true);
  v_refuse := false;
  BEGIN
    UPDATE public.terrains_etat
       SET data = (data::jsonb || '{"compromisPar":"Ben"}'::jsonb)::text
     WHERE building_id = T;
  EXCEPTION WHEN insufficient_privilege THEN v_refuse := true;
  END;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.terrains_etat WHERE building_id = T;
  n := n + 1; IF NOT v_refuse OR d ->> 'compromisPar' <> 'May' THEN
    ko := ko || ('3 L ECRITURE CLIENTE DIRECTE EST ENCORE POSSIBLE : refus de privilege '
                 || v_refuse::text || ', detenteur ' || coalesce(d ->> 'compromisPar', 'NULL'));
  END IF;

  -- ------------------------------------------------- 2. LE TRANSFERT REGULIER, LUI, PASSE
  UPDATE public.terrains_etat SET data =
    '{"city":"ville_a","proprietaire":"May","compromis":true,"compromisPar":"May","transfertPropose":"Ben","transfertProposePar":"May"}'
   WHERE building_id = T;
  PERFORM set_config('role', 'authenticated', true);
  v := public.terrain_compromis_acte(T, 'compromis_transfert_accepter', '{}'::jsonb);
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.terrains_etat WHERE building_id = T;
  n := n + 1; IF NOT (v ->> 'ok' = 'true' AND d ->> 'compromisPar' = 'Ben'
                      AND (d -> 'transfertPropose') = 'null'::jsonb)
    THEN ko := ko || ('4 le transfert regulier ne passe pas : ' || v::text || ' / ' || d::text); END IF;
  -- ET LA PROPRIETE N'A PAS BOUGE : un compromis n'est pas une vente.
  n := n + 1; IF d ->> 'proprietaire' <> 'May'
    THEN ko := ko || ('5 le transfert a change le proprietaire : ' || d::text); END IF;

  -- ------------------------------------------------- 3. UNE CLE HORS DE L'ACTE EST REFUSEE
  PERFORM set_config('role', 'authenticated', true);
  v := public.terrain_compromis_acte(T, 'compromis_transfert_accepter',
         '{"chantier":{"progressionJours":99}}'::jsonb);
  n := n + 1; IF NOT (v ->> 'raison' = 'cle_hors_acte' AND v ->> 'cle' = 'chantier')
    THEN ko := ko || ('6 un acte du compromis a pu ecrire un chantier : ' || v::text); END IF;

  -- ------------------------------------------------- 4. TRANCHER LE PERMIS D'UN AUTRE
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.terrains_etat SET data =
    '{"city":"ville_a","proprietaire":"May","permis":{"statut":"instruction","palierDemande":"hangar","dureeInstruction":2,"joursInstructionFaits":2}}'
   WHERE building_id = T;
  PERFORM set_config('role', 'authenticated', true);
  v := public.terrain_permis_acte(T, 'permis_decider', '{"permis":{"statut":"valide"}}'::jsonb);
  n := n + 1; IF v ->> 'raison' <> 'autorite_refusee'
    THEN ko := ko || ('7 un joueur sans poste tranche un permis : ' || v::text); END IF;

  -- Maire adjoint, mais d'une AUTRE ville : la juridiction est celle du poste.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET poste = '{"id":"maire_adjoint","city":"capitale"}'::jsonb
   WHERE name = 'Ben';
  PERFORM set_config('role', 'authenticated', true);
  v := public.terrain_permis_acte(T, 'permis_decider', '{"permis":{"statut":"valide"}}'::jsonb);
  n := n + 1; IF v ->> 'raison' <> 'hors_juridiction'
    THEN ko := ko || ('8 le maire adjoint d une autre ville tranche : ' || v::text); END IF;

  -- Le maire adjoint de la BONNE ville, lui, tranche -- et un refus doit etre motive.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET poste = '{"id":"maire_adjoint","city":"ville_a"}'::jsonb
   WHERE name = 'Ben';
  PERFORM set_config('role', 'authenticated', true);
  v := public.terrain_permis_acte(T, 'permis_decider', '{"permis":{"statut":"refuse","motifRefus":"trop"}}'::jsonb);
  n := n + 1; IF v ->> 'raison' <> 'motif_requis'
    THEN ko := ko || ('9 un refus de permis sans motif ecrit passe : ' || v::text); END IF;
  v := public.terrain_permis_acte(T, 'permis_decider',
         '{"permis":{"statut":"valide"},"constructionAutorisee":true}'::jsonb);
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.terrains_etat WHERE building_id = T;
  n := n + 1; IF NOT (v ->> 'ok' = 'true' AND (d -> 'permis' ->> 'statut') = 'valide'
                      AND (d ->> 'constructionAutorisee')::boolean)
    THEN ko := ko || ('10 le maire adjoint competent ne peut pas valider : ' || v::text); END IF;
  -- ET LE DOSSIER NE SE RETRANCHE PAS.
  PERFORM set_config('role', 'authenticated', true);
  v := public.terrain_permis_acte(T, 'permis_decider', '{"permis":{"statut":"valide"}}'::jsonb);
  n := n + 1; IF v ->> 'raison' <> 'dossier_deja_decide'
    THEN ko := ko || ('11 un permis deja tranche se retranche : ' || v::text); END IF;

  -- CONTRE-EPREUVE 12 : sans poste du tout, l'ancien chemin tranchait -- il est maintenant arrete
  -- un cran plus tot, par le PRIVILEGE (registre 634) et non par la policy. L'UPDATE est conserve
  -- a l'identique : c'est son refus qui est mesure, et son succes qui serait l'echec.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = 'Ben';
  UPDATE public.terrains_etat SET data =
    '{"city":"ville_a","proprietaire":"May","permis":{"statut":"instruction"}}' WHERE building_id = T;
  PERFORM set_config('role', 'authenticated', true);
  v_refuse := false;
  BEGIN
    UPDATE public.terrains_etat
       SET data = (data::jsonb || '{"permis":{"statut":"valide"},"constructionAutorisee":true}'::jsonb)::text
     WHERE building_id = T;
  EXCEPTION WHEN insufficient_privilege THEN v_refuse := true;
  END;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.terrains_etat WHERE building_id = T;
  n := n + 1; IF NOT v_refuse OR (d -> 'permis' ->> 'statut') <> 'instruction' THEN
    ko := ko || ('12 L ECRITURE CLIENTE DIRECTE EST ENCORE POSSIBLE : un joueur sans poste a '
                 || 'touche le permis (refus de privilege ' || v_refuse::text || ', statut '
                 || coalesce(d -> 'permis' ->> 'statut', 'NULL') || ')');
  END IF;

  -- ------------------------------------------------- 5. GELER LE TERRAIN D'UN AUTRE
  PERFORM set_config('role', 'authenticated', true);
  v := public.terrain_succession_geler(T, 'zzbanc-succession-inventee');
  n := n + 1; IF v ->> 'raison' <> 'succession_inconnue'
    THEN ko := ko || ('13 une succession inventee gele un terrain : ' || v::text); END IF;

  -- CONTRE-EPREUVE 14 : l'ancien chemin posait le gel sans rien verifier. Depuis le registre 634
  -- il ne pose plus rien du tout : l'UPDATE, conserve a l'identique, leve un refus de privilege
  -- avant meme d'atteindre la policy. On l'attrape, et l'absence d'exception serait l'echec.
  v_refuse := false;
  BEGIN
    UPDATE public.terrains_etat
       SET data = (data::jsonb || '{"succession_gel":"zzbanc-succession-inventee"}'::jsonb)::text
     WHERE building_id = T;
  EXCEPTION WHEN insufficient_privilege THEN v_refuse := true;
  END;
  PERFORM set_config('role', 'postgres', true);
  SELECT data::jsonb INTO d FROM public.terrains_etat WHERE building_id = T;
  n := n + 1; IF NOT v_refuse OR coalesce(d ->> 'succession_gel', '') <> '' THEN
    ko := ko || ('14 L ECRITURE CLIENTE DIRECTE EST ENCORE POSSIBLE : le gel invente a ete pose '
                 || 'par le client (refus de privilege ' || v_refuse::text || ')');
  END IF;
  -- LE GEL EST DONC POSE ICI SOUS `postgres` : il n'est pas la preuve, il n'est que le DECOR de
  -- l'epreuve 15. Le client ne peut plus l'ecrire, mais un gel legitime existe en jeu, et c'est
  -- l'arret des portes devant lui qu'on mesure ensuite.
  UPDATE public.terrains_etat
     SET data = (data::jsonb || '{"succession_gel":"zzbanc-succession-inventee"}'::jsonb)::text
   WHERE building_id = T;
  -- ET LE GEL BLOQUE BIEN LES QUATRE PORTES -- c'est ce qui rendait le defaut grave.
  PERFORM set_config('role', 'authenticated', true);
  v := public.terrain_permis_acte(T, 'permis_accelerer', '{"permis":{"dureeInstruction":1}}'::jsonb);
  n := n + 1; IF v ->> 'raison' <> 'terrain_gele'
    THEN ko := ko || ('15 un terrain gele reste actionnable : ' || v::text); END IF;

  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.terrains_etat WHERE building_id = T;
  UPDATE public.personnages_donnees SET poste = NULL WHERE name IN ('Ben', 'May');

  IF array_length(ko, 1) IS NULL THEN
    RAISE EXCEPTION 'LES % EPREUVES DES AUTORITES DE TERRAIN SONT VERTES.', n;
  ELSE
    RAISE EXCEPTION E'ECHEC : % epreuve(s) sur % en defaut.\n  %',
      array_length(ko, 1), n, array_to_string(ko, E'\n  ');
  END IF;
END $banc$;
ROLLBACK;
