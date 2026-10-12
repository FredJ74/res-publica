-- BANC DE LA PEINE SERVEUR ET DE LA PLAINTE ATOMIQUE (12 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il pose un decor dans `postes_attribues`, `personnages_donnees` et
-- `plaintes_en_cours`, joue des depots de plainte et des jugements, et se termine par un
-- RAISE EXCEPTION INCONDITIONNEL qui annule tout.
--
-- POURQUOI IL EXISTE : les 25 preuves des deux migrations sont STRUCTURELLES -- elles lisent des
-- catalogues, comptent des droits, verifient l'ordre de deux instructions dans un corps de
-- fonction. Elles ne peuvent pas prouver qu'une peine hors bornes est REFUSEE, ni qu'une plainte
-- impayee ne laisse RIEN. Ca se joue, et ca se joue en ecrivant pour de vrai.
--
-- CE QU'IL PROUVE :
--   1. une plainte payee preleve exactement le cout declare au miroir, et cree UN dossier ;
--   2. une plainte dont le paiement echoue ne laisse AUCUN dossier -- le defaut ferme ;
--   3. un doublon est refuse AVANT le paiement : il ne coute rien ;
--   4. un PJ peut porter plainte contre un autre PJ sans etre la victime ;
--   5. une infraction inconnue est refusee ;
--   6. un nom de CATEGORIE est refuse comme qualification ;
--   7. une peine sous la borne basse est refusee ;
--   8. une peine au-dessus de la borne haute est refusee ;
--   9. une peine dans la plage est acceptee, et c'est la valeur VALIDEE qui est archivee ;
--  10. le libelle de la peine est COMPOSE par le serveur ;
--  11. un second jugement sur la meme affaire est refuse (par la saisine, desormais) ;
--  12. l'accuse et le motif de l'affaire ne peuvent plus etre reecrits au jugement ;
--  13. le motif ALLEGUE et la qualification FINALE coexistent, sans que l'un efface l'autre ;
--  14. un non-juge est refuse ;
--  15. un juge d'une AUTRE ville est refuse ;
--  16. un genre de sanction inconnu est refuse ;
--  17. le QHS est IMPOSE a 30 jours -- toute autre valeur est refusee ;
--  18. la torture est IMPOSEE a 3 x (n+1), comptee par le serveur ;
--  19. une amende hors bornes est refusee, dans les bornes acceptee ;
--  20. la plage PROPOSEE a l'ecran est exactement celle que la porte applique ;
--  21. les motifs du jugement portent la duree validee -- plus de repli a 3 jours ;
--  22. un client ne peut pas lire le catalogue des infractions directement.
--  23. une affaire dont le tribunal n'est pas SAISI ne peut pas etre jugee.
--
-- RELU ET ADAPTE DANS LA NUIT DU 12 OCTOBRE 2026, apres la tranche du parquet. Trois epreuves
-- disaient encore l'ancien monde, et une s'est AMELIOREE au passage :
--   . le decor du jugement posait un dossier `deposee` et jugeait dessus. Il n'y a plus de
--     jugement sans SAISINE : le decor pose desormais `saisie`, et l'epreuve 23 verifie que le
--     meme dossier reste injugeable tant qu'il est `au_parquet`.
--   . E14 et E15 attendaient `autorite_refusee`. La garde n'est plus `affaire_autorite_de` --
--     qui acceptait AUSSI le commissaire -- mais `juge_de_la_ville`, liee a auth.uid() : elle ne
--     rend rien du tout a un non-juge comme a un juge d'ailleurs, et le refus s'appelle
--     `pas_juge_de_cette_ville`. Le refus est le meme, son nom est plus exact.
--   . E3 n'a plus besoin de poser son dossier a la main. Sa premiere version redeposait une
--     plainte et n'obtenait pas de refus parce que le commissaire PNJ instruisait IMMEDIATEMENT
--     au depot, donc le premier dossier n'etait plus `deposee` a la ligne suivante. Le depot
--     n'instruit plus rien : le dossier reste `au_parquet` et l'anti-spam mord pour de vrai.
--     L'epreuve joue donc deux depots REELS, ce qui prouve les deux faits d'un coup.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc peine : LES 23 EPREUVES SONT VERTES. -- rien ne doit rester

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
  JUGE_U text := 'a5a55fc8-64fa-4406-b617-76439d1d4aac'; JUGE text := 'Marsault';
  LEE_U  text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; LEE  text := 'Lee Capene';
  TIERS_U text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf'; TIERS text := 'Phileas Frogg';
  v jsonb; n integer := 0; ko integer := 0; e text := '';
  v_n integer; v_pa_av integer; v_pa_ap integer; v_cout integer;
  v_aff text; v_data jsonb; v_jug jsonb; v_prop jsonb;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- DECOR : Marsault devient juge de la capitale. Le poste doit etre INSCRIT AU REGISTRE avant
  -- d'etre pose sur la fiche -- le declencheur `trg_personnages_attester_poste` refuserait sinon,
  -- et c'est exactement la garde qu'on veut laisser en place.
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('banc-poste-juge-cap', 'republic', 'juge', 'capitale', JUGE, 'banc');
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'juge', 'city', 'capitale', 'name', 'Juge')
   WHERE name = JUGE;

  SELECT o.pa INTO v_cout FROM public.ordres_couts o WHERE o.fn = 'plainte_police';

  -- ========================================================================================
  n := n + 1;   -- E1 : UNE PLAINTE PAYEE PRELEVE LE COUT DECLARE, ET CREE UN SEUL DOSSIER.
  SELECT pa INTO v_pa_av FROM public.personnages_donnees WHERE name = LEE;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.plainte_deposer(TIERS, 'Il a pris mon manteau');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT pa INTO v_pa_ap FROM public.personnages_donnees WHERE name = LEE;
  SELECT count(*) INTO v_n FROM public.plaintes_en_cours p
   WHERE p.data::jsonb ->> 'auteur' = LEE AND p.data::jsonb ->> 'cible' = TIERS;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v_n <> 1
     OR (v_pa_av - v_pa_ap) <> v_cout THEN
    ko:=ko+1; e:=e||E'\nE1 depot : '||v::text||' / '||v_n||' dossier(s) / PA '||v_pa_av||'->'||v_pa_ap;
  END IF;

  n := n + 1;   -- E4 : LE PLAIGNANT N'A PAS BESOIN D'ETRE LA VICTIME. Lee se plaint d'un fait
                --      dont la victime n'est pas nommee, contre un autre PJ, et c'est recu.
  IF (SELECT count(*) FROM public.plaintes_en_cours p
       WHERE p.data::jsonb ->> 'auteur' = LEE AND p.data::jsonb ->> 'cible' = TIERS) <> 1 THEN
    ko:=ko+1; e:=e||E'\nE4 plainte d un non-victime refusee';
  END IF;

  n := n + 1;   -- E3 : LE DOUBLON NE COUTE RIEN, ET IL MORD POUR DE VRAI DEPUIS LE PARQUET.
  --
  -- DEUX DEPOTS REELS, ET C'EST NOUVEAU. La premiere version de cette epreuve posait le dossier
  -- « en cours » A LA MAIN parce qu'un redepot n'etait PAS refuse : l'anti-spam ne mordait que
  -- sur le statut `deposee`, et dans une ville sans commissaire joueur le commissaire PNJ
  -- instruisait IMMEDIATEMENT au depot -- le premier dossier n'etait donc plus `deposee` a la
  -- ligne suivante. Le depot n'instruit plus rien du tout : il laisse le dossier AU PARQUET, qui
  -- est un statut vivant. L'epreuve joue donc la vraie sequence, et prouve les deux faits
  -- ensemble : le dossier arrive `au_parquet`, et un second depot est refuse sans rien couter.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.plainte_deposer('Ben', 'Dossier encore ouvert');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE
     OR coalesce(v->>'statut','') <> 'au_parquet'
     OR (SELECT (p.data::jsonb) ->> 'status' FROM public.plaintes_en_cours p
          WHERE p.id = v->>'id') <> 'au_parquet' THEN
    ko:=ko+1; e:=e||E'\nE3a le depot n instruit plus, et arrive au parquet : '||v::text;
  END IF;
  SELECT pa INTO v_pa_av FROM public.personnages_donnees WHERE name = LEE;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.plainte_deposer('Ben', 'Encore lui');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT pa INTO v_pa_ap FROM public.personnages_donnees WHERE name = LEE;
  IF coalesce(v->>'raison','') <> 'plainte_deja_en_cours' OR v_pa_av <> v_pa_ap THEN
    ko:=ko+1; e:=e||E'\nE3b doublon : '||v::text||' / PA '||v_pa_av||'->'||v_pa_ap;
  END IF;

  n := n + 1;   -- E2 : PAIEMENT IMPOSSIBLE -> AUCUN DOSSIER. C'est le defaut ferme : le dossier
                --      etait cree d'abord, et un refus de paiement le laissait en place.
  UPDATE public.personnages_donnees SET pa = 0 WHERE name = LEE;
  SELECT count(*) INTO v_n FROM public.plaintes_en_cours;
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.plainte_deposer(JUGE, 'Plainte que je ne peux pas payer');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,true) IS NOT FALSE
     OR coalesce(v->>'raison','') <> 'pa_insuffisants'
     OR (SELECT count(*) FROM public.plaintes_en_cours) <> v_n THEN
    ko:=ko+1; e:=e||E'\nE2 plainte impayee : '||v::text||' / dossiers '||v_n||'->'
      ||(SELECT count(*) FROM public.plaintes_en_cours)::text;
  END IF;

  -- ========================================================================================
  -- DECOR DU JUGEMENT : une affaire de la capitale contre Lee, DONT LE TRIBUNAL EST SAISI.
  --
  -- LE STATUT EST POSE ICI, ET C'EST ASSUME. Jouer la chaine entiere -- depot, qualification du
  -- parquet, poursuites, saisine -- demanderait un Procureur present dans le tribunal de la
  -- capitale, et c'est l'office de `banc-parquet-serveur.sql`, qui le fait sur 32 epreuves. Ce
  -- banc-ci eprouve LE BAREME, pas le chemin : il part de l'etat ou le juge est regulierement
  -- saisi. L'epreuve 23 ci-dessous verifie tout de meme qu'il n'y a pas de jugement AVANT.
  v_aff := 'banc-affaire-1';
  INSERT INTO public.plaintes_en_cours (id, country, city, data)
  VALUES (v_aff, 'republic', 'capitale', jsonb_build_object(
    'id', v_aff, 'auteur', TIERS, 'cible', LEE, 'motif', 'Il a tue mon chien',
    'jour', 1, 'city', 'capitale', 'country', 'republic', 'status', 'au_parquet')::text);

  n := n + 1;   -- E23 : ON NE JUGE QUE CE DONT ON EST SAISI. Le dossier est encore au parquet.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'assassiner_mains', 'prison', 8, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'affaire_non_saisie'
     OR coalesce(v->>'statut','') <> 'au_parquet' THEN
    ko:=ko+1; e:=e||E'\nE23 jugement sans saisine : '||v::text; END IF;

  -- LE PARQUET SAISIT. A partir d'ici, le tribunal est regulierement saisi.
  UPDATE public.plaintes_en_cours
     SET data = (data::jsonb || jsonb_build_object('status', 'saisie'))::text
   WHERE id = v_aff;

  n := n + 1;   -- E5 : INFRACTION INCONNUE REFUSEE.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'zz_pas_une_infraction', 'prison', 2, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'infraction_inconnue' THEN
    ko:=ko+1; e:=e||E'\nE5 infraction inconnue : '||v::text; END IF;

  n := n + 1;   -- E6 : UNE CATEGORIE N'EST PAS UNE CHARGE.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'crime', 'prison', 8, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'infraction_inconnue' THEN
    ko:=ko+1; e:=e||E'\nE6 categorie acceptee : '||v::text; END IF;

  n := n + 1;   -- E16 : GENRE DE SANCTION INCONNU REFUSE.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'assassiner_mains', 'bucher', 8, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'genre_inconnu' THEN
    ko:=ko+1; e:=e||E'\nE16 genre inconnu : '||v::text; END IF;

  n := n + 1;   -- E7 : SOUS LA BORNE BASSE. assassiner_mains vaut 8 j -> plage [4, 12].
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'assassiner_mains', 'prison', 3, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'peine_hors_bornes' OR (v->>'jours_min')::int <> 4 THEN
    ko:=ko+1; e:=e||E'\nE7 sous la borne : '||v::text; END IF;

  n := n + 1;   -- E8 : AU-DESSUS DE LA BORNE HAUTE.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'assassiner_mains', 'prison', 13, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'peine_hors_bornes' OR (v->>'jours_max')::int <> 12 THEN
    ko:=ko+1; e:=e||E'\nE8 au-dessus de la borne : '||v::text; END IF;

  n := n + 1;   -- E14 : UN NON-JUGE EST REFUSE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.justice_rendre_sentence(v_aff, 'assassiner_mains', 'prison', 8, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  -- LE REFUS NE S'APPELLE PLUS `autorite_refusee`. L'ancienne garde, `affaire_autorite_de`,
  -- acceptait aussi le COMMISSAIRE de la ville : juger n'a jamais ete son office. La nouvelle,
  -- `juge_de_la_ville`, est liee a auth.uid() et ne rend rien a qui n'est pas LE juge de CETTE
  -- ville -- d'ou `pas_juge_de_cette_ville`. Meme refus, nom plus exact.
  IF coalesce(v->>'raison','') <> 'pas_juge_de_cette_ville' THEN
    ko:=ko+1; e:=e||E'\nE14 non-juge accepte : '||v::text; END IF;

  n := n + 1;   -- E15 : UN JUGE D'UNE AUTRE VILLE EST REFUSE. Marsault devient juge de ville_a
                --       le temps de l'epreuve : l'affaire reste a la capitale.
  UPDATE public.postes_attribues SET city = 'ville_a' WHERE id = 'banc-poste-juge-cap';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'juge', 'city', 'ville_a', 'name', 'Juge')
   WHERE name = JUGE;
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'assassiner_mains', 'prison', 8, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_juge_de_cette_ville' THEN
    ko:=ko+1; e:=e||E'\nE15 juge hors juridiction accepte : '||v::text; END IF;
  UPDATE public.postes_attribues SET city = 'capitale' WHERE id = 'banc-poste-juge-cap';
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', 'juge', 'city', 'capitale', 'name', 'Juge')
   WHERE name = JUGE;

  n := n + 1;   -- E20 : LA PLAGE PROPOSEE EST CELLE QUI SERA APPLIQUEE.
  PERFORM pg_temp.je_suis(JUGE_U);
  v_prop := public.justice_peine_proposer(v_aff, 'assassiner_mains', 'prison');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v_prop->>'ok')::boolean,false) IS NOT TRUE
     OR (v_prop->>'jours_min')::int <> 4 OR (v_prop->>'jours_max')::int <> 12
     OR (v_prop->>'jours_defaut')::int <> 8
     OR v_prop->>'motif_allegue' <> 'Il a tue mon chien' THEN
    ko:=ko+1; e:=e||E'\nE20 plage proposee : '||v_prop::text; END IF;

  n := n + 1;   -- E17 : LE QHS EST IMPOSE A 30 JOURS. Une autre valeur est refusee.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'assassiner_mains', 'qhs', 5, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'peine_hors_bornes'
     OR (v->>'jours_min')::int <> 30 OR (v->>'jours_max')::int <> 30 THEN
    ko:=ko+1; e:=e||E'\nE17 QHS non impose : '||v::text; END IF;

  n := n + 1;   -- E18 : LA TORTURE EST IMPOSEE A 3 x (n+1), COMPTEE PAR LE SERVEUR.
                --       Zero condamnation precedente -> 3 jours.
  PERFORM pg_temp.je_suis(JUGE_U);
  v_prop := public.justice_peine_proposer(v_aff, 'assassiner_mains', 'torture');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v_prop->>'jours_min')::int <> 3 OR (v_prop->>'jours_max')::int <> 3 THEN
    ko:=ko+1; e:=e||E'\nE18a torture sans antecedent : '||v_prop::text; END IF;
  -- Deux condamnations anterieures -> 9 jours. Le compte est en base, pas dans le navigateur.
  INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration)
  VALUES ('banc-tort-1', LEE, NULL, 'condamnation_torture', 'republic', 'capitale', 1, 36501),
         ('banc-tort-2', LEE, NULL, 'condamnation_torture', 'republic', 'capitale', 1, 36501);
  PERFORM pg_temp.je_suis(JUGE_U);
  v_prop := public.justice_peine_proposer(v_aff, 'assassiner_mains', 'torture');
  PERFORM pg_temp.je_suis_le_serveur();
  IF (v_prop->>'jours_min')::int <> 9 THEN
    ko:=ko+1; e:=e||E'\nE18b torture avec 2 antecedents : '||v_prop::text; END IF;
  DELETE FROM public.actions_tracables WHERE id IN ('banc-tort-1','banc-tort-2');

  n := n + 1;   -- E19 : AMENDE HORS BORNES REFUSEE. assassiner_mains : 5000 FR -> [2500, 7500].
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'assassiner_mains', 'amende', 0, 9000);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'amende_hors_bornes' OR (v->>'amende_max')::int <> 7500 THEN
    ko:=ko+1; e:=e||E'\nE19 amende hors bornes : '||v::text; END IF;

  n := n + 1;   -- E9 : DANS LA PLAGE, C'EST ACCEPTE -- et c'est la valeur VALIDEE qui est
                --      archivee, pas une chaine libre.
  PERFORM pg_temp.je_suis(JUGE_U);
  v_jug := public.justice_rendre_sentence(v_aff, 'assassiner_mains', 'prison', 11, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v_jug->>'ok')::boolean,false) IS NOT TRUE
     OR (v_jug->>'jours')::int <> 11
     OR v_jug->>'infraction' <> 'assassiner_mains' THEN
    ko:=ko+1; e:=e||E'\nE9 sentence dans la plage : '||v_jug::text; END IF;

  n := n + 1;   -- E10 : LE LIBELLE EST COMPOSE PAR LE SERVEUR.
  IF (SELECT peine FROM public.jugements WHERE id = 'jug-' || v_aff) <> 'Prison 11 jours' THEN
    ko:=ko+1; e:=e||E'\nE10 libelle serveur : '
      ||coalesce((SELECT peine FROM public.jugements WHERE id = 'jug-'||v_aff), '(absent)'); END IF;

  n := n + 1;   -- E21 : LES MOTIFS PORTENT LA DUREE VALIDEE -- plus de repli a 3 jours dans
                --       justice_executer_condamnation.
  SELECT coalesce((SELECT sum((m->>'jours')::int)
                     FROM jsonb_array_elements(data->'motifs') m), 0) INTO v_n
    FROM public.jugements WHERE id = 'jug-' || v_aff;
  IF v_n <> 11 THEN
    ko:=ko+1; e:=e||E'\nE21 somme des motifs : '||v_n||' au lieu de 11'; END IF;

  n := n + 1;   -- E12 : L'ACCUSE ET LE MOTIF DE L'AFFAIRE N'ONT PAS BOUGE. Il n'existe plus de
                --       parametre par lequel les reecrire, et la fusion part de la ligne relue.
  SELECT data::jsonb INTO v_data FROM public.plaintes_en_cours WHERE id = v_aff;
  IF v_data->>'cible' <> LEE OR v_data->>'motif' <> 'Il a tue mon chien'
     OR v_data->>'auteur' <> TIERS THEN
    ko:=ko+1; e:=e||E'\nE12 affaire reecrite : '||v_data::text; END IF;

  n := n + 1;   -- E13 : LE MOTIF ALLEGUE ET LA QUALIFICATION FINALE COEXISTENT.
  IF v_data->>'qualification_finale' <> 'assassiner_mains'
     OR (SELECT data->>'motif_allegue' FROM public.jugements WHERE id = 'jug-'||v_aff)
        <> 'Il a tue mon chien' THEN
    ko:=ko+1; e:=e||E'\nE13 historique de qualification : '||v_data::text; END IF;

  n := n + 1;   -- E11 : UN SECOND JUGEMENT EST REFUSE.
  --
  -- LE REFUS A CHANGE DE NOM, ET LE BANC L'A APPRIS A LA PREMIERE EXECUTION DU 12 OCTOBRE AU
  -- SOIR. Il attendait `affaire_deja_jugee`, qui est le refus porte par l'existence de la ligne
  -- de jugement. Depuis la saisine, une garde ARRIVE AVANT : un dossier juge porte le statut
  -- `jugee`, donc il n'est plus `saisie`, donc on n'en est plus saisi. `affaire_deja_jugee` n'est
  -- pas mort pour autant -- il garde le cas d'un dossier reste `saisie` avec un jugement deja
  -- inscrit -- mais ce n'est pas le chemin ordinaire. L'epreuve asserte ce que la porte fait
  -- VRAIMENT, statut compris, et la protection est la meme : UNE seule ligne de jugement.
  PERFORM pg_temp.je_suis(JUGE_U);
  v := public.justice_rendre_sentence(v_aff, 'vol', 'prison', 1, 0);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.jugements WHERE id = 'jug-' || v_aff;
  IF coalesce(v->>'raison','') <> 'affaire_non_saisie'
     OR coalesce(v->>'statut','') <> 'jugee' OR v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nE11 double jugement : '||v::text||' / '||v_n||' ligne(s)'; END IF;

  n := n + 1;   -- E22 : UN CLIENT NE LIT PAS LE CATALOGUE DIRECTEMENT.
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    PERFORM count(*) FROM public.infractions;
    ko:=ko+1; e:=e||E'\nE22 un client a lu public.infractions directement';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  IF ko = 0 THEN RAISE EXCEPTION 'banc peine : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE RAISE EXCEPTION 'banc peine : % epreuve(s) sur % en defaut.%', ko, n, e; END IF;
END
$banc$;
ROLLBACK;
