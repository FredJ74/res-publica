-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917214855
-- Nom original      : militaire_contingent_reserve
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 21:48:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2c5d9014d9958ba5d4b4b9d21a0cf220
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ==========================================================================================
-- CONTINGENT ET RESERVE D'UNE COMPAGNIE
--
-- MODELE GD. Les 20 000 FR constituent un CONTINGENT MAXIMAL DE 96 PNJ attribuables a la
-- compagnie -- ce n'est PAS quatre achats independants de 24 PNJ. La compagnie nait avec ses
-- 4 sections VIDES ; chaque Lieutenant reellement installe a la tete d'une section y fait entrer
-- jusqu'a 24 hommes pris dans le contingent. Un contingent deja entame donne donc une section
-- incomplete -- la 4e section peut naitre incomplete, exactement comme le GD le decrit.
--
-- REPRESENTATION, sans nouvelle table. Deux cles sur compagnies_militaires.data :
--   contingentInitial : ce que les 20 000 FR ont achete (96), invariant de reference ;
--   reserve           : tableau d'OBJETS SOLDATS COMPLETS non affectes a une section.
-- La reserve doit porter des objets complets et non un compteur : un PNJ remplace par un PJ y
-- retourne AVEC son entrainement, et la regle « un veteran mort emporte son capital
-- d'entrainement » n'a de sens que si le capital voyage avec l'individu. Un compteur la rendrait
-- fausse.
--
-- Un soldat en reserve reste physiquement a la caserne (ville='caserne', corps de garde) : il a
-- une position et aucun leader, l'invariant « leaderCourant renseigne <=> position vide » est
-- preserve. La distinction reserve / section est STRUCTURELLE, pas positionnelle. La reserve vit
-- au niveau COMPAGNIE : aucune RPC de section ne peut y puiser, militaire_recuperer_soldats ne
-- regardant que les soldats de SA section.
--
-- MATRICULE. Le numero de section quitte le matricule (ancien 'AAAAMM-SS-NNN') : un soldat n'est
-- plus ne dans une section, il est ne dans un contingent. Format 'AAAAMM-NNN', serie de la
-- compagnie. compagnies_militaires etant vide, aucune donnee n'est concernee.
--
-- CE QUI RESTE EN ATTENTE D'ARBITRAGE. Le GD veut les 20 000 FR « reserves/immobilises, pas
-- immediatement detruits ». Aucun mecanisme de fonds engages n'existe dans ce jeu : une caisse est
-- un scalaire {solde}, et la seule immobilisation existante (les placements bancaires) est une
-- table dediee a ligne par operation. Cette migration conserve donc le DEBIT IMMEDIAT deja en
-- vigueur -- le flux total est identique a aujourd'hui, puisque doRecruterSection et ses
-- 4 x 5 000 FR de recompletement disparaissent. Seule la question du reliquat (une compagnie qui
-- n'obtient jamais ses 4 Lieutenants) reste ouverte.
--
-- L'entrainement conserve volontairement ses trois cles historiques force/endurance/tir : les
-- quatre domaines du nouveau GD sont l'etape suivante, et il ne faut jamais laisser un ecrivain
-- (militaire_entrainer_section) et un lecteur en desaccord sur la forme des donnees.
-- ==========================================================================================

CREATE OR REPLACE FUNCTION public.militaire_compagnie_creer()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  c_contingent constant integer := 96;   -- 4 sections x 24 places
  c_sections   constant integer := 4;
  c_cout       constant numeric := 20000;
  v_moi text; v_pays text; v_id text; v_prefixe text;
  v_paye jsonb; v_caisse jsonb;
  v_sections jsonb; v_reserve jsonb;
BEGIN
  v_moi := public.exiger_poste('commandant');
  IF v_moi IS NULL THEN v_moi := public.mon_personnage(); END IF;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- PA attestes contre le miroir (recruter_compagnie : 3 PA, 0 FR pour le joueur). Le chemin
  -- client precedent passait par la branche institutionnelle de deduireCoutOrdre, qui ne consulte
  -- PAS le miroir et deduit les PA cote navigateur seulement.
  v_paye := public.payer_ordre(v_moi, 'recruter_compagnie', 3, 0);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN RETURN v_paye; END IF;

  -- Caisse de la caserne, dans la MEME transaction : un echec ici annule le prelevement des PA.
  v_caisse := public.caisse_institution_mouvement(v_pays || '_caserne-militaire', -c_cout, true);
  IF NOT coalesce((v_caisse->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false,
      'raison', coalesce(v_caisse->>'raison', 'caisse_refusee'), 'cout', c_cout);
  END IF;

  v_id := 'compagnie-' || v_pays || '-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint::text;
  v_prefixe := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYYMM');

  -- Quatre sections VIDES, sans lieutenant.
  SELECT jsonb_agg(jsonb_build_object(
           'id', v_id || '-s' || i, 'numero', i, 'lieutenantNom', NULL,
           'soldats', '[]'::jsonb) ORDER BY i)
    INTO v_sections FROM generate_series(1, c_sections) AS g(i);

  -- Le contingent, en reserve de compagnie.
  SELECT jsonb_agg(jsonb_build_object(
           'matricule', v_prefixe || '-' || lpad(i::text, 3, '0'),
           'formation', jsonb_build_object('force', 0, 'endurance', 0, 'tir', 0),
           'arme', 'corps_a_corps',
           'ville', 'caserne', 'buildingId', 'caserne-militaire', 'roomId', 'corps_garde',
           'leaderCourant', NULL, 'pa', 12) ORDER BY i)
    INTO v_reserve FROM generate_series(1, c_contingent) AS g(i);

  INSERT INTO public.compagnies_militaires (id, data)
  VALUES (v_id, jsonb_build_object(
    'id', v_id, 'pays', v_pays, 'capitaineNom', NULL,
    'contingentInitial', c_contingent,
    'reserve', v_reserve,
    'sections', v_sections));

  RETURN jsonb_build_object('ok', true, 'compagnie', v_id, 'contingent', c_contingent,
                            'sections', c_sections, 'cout', c_cout, 'pa', v_paye->'pa');
END;
$fn$;

REVOKE ALL ON FUNCTION public.militaire_compagnie_creer() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.militaire_compagnie_creer() FROM anon;
GRANT EXECUTE ON FUNCTION public.militaire_compagnie_creer() TO authenticated, service_role;


-- ---- Le Lieutenant installe fait entrer jusqu'a 24 hommes pris dans le contingent ----
CREATE OR REPLACE FUNCTION public.militaire_accepter_lieutenant(p_nomination_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  c_places constant integer := 24;
  v_moi text; v_n record; v_data jsonb; v_secs jsonb; v_trouve boolean := false;
  v_reserve jsonb; v_deja integer; v_tire integer; v_pris jsonb; v_reste jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO v_n FROM public.nominations_militaires WHERE id = p_nomination_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable'); END IF;
  IF v_n.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire'); END IF;
  IF v_n.traitee THEN RETURN jsonb_build_object('ok', true, 'rejeu', true); END IF;
  IF v_n.grade <> 'lieutenant' THEN RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide'); END IF;

  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = v_n.compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compagnie_introuvable'); END IF;

  -- Combien d'hommes la section compte-t-elle deja, et combien la reserve peut-elle en fournir ?
  SELECT count(*) INTO v_deja
    FROM jsonb_array_elements(coalesce(v_data->'sections', '[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats', '[]'::jsonb)) sol
   WHERE s->>'id' = v_n.section_id;
  v_reserve := CASE WHEN jsonb_typeof(v_data->'reserve') = 'array'
                    THEN v_data->'reserve' ELSE '[]'::jsonb END;
  -- Jamais plus de 24 places : la limite est desormais APPLIQUEE cote serveur, elle n'etait
  -- jusqu'ici qu'une taille de lot pour la generation des matricules, verifiee nulle part.
  v_tire := least(greatest(0, c_places - v_deja), jsonb_array_length(v_reserve));

  SELECT coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos <= v_tire), '[]'::jsonb),
         coalesce(jsonb_agg(sol ORDER BY pos) FILTER (WHERE pos > v_tire), '[]'::jsonb)
    INTO v_pris, v_reste
    FROM jsonb_array_elements(v_reserve) WITH ORDINALITY AS t(sol, pos);

  SELECT COALESCE(jsonb_agg(
           CASE WHEN s->>'id' = v_n.section_id AND COALESCE(s->>'lieutenantNom','') = ''
                THEN s || jsonb_build_object('lieutenantNom', v_moi,
                       'soldats', coalesce(s->'soldats', '[]'::jsonb) || v_pris)
                ELSE s END ORDER BY ord), '[]'::jsonb)
    INTO v_secs
    FROM jsonb_array_elements(COALESCE(v_data->'sections','[]'::jsonb)) WITH ORDINALITY AS t(s, ord);
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(v_secs) s
                  WHERE s->>'id' = v_n.section_id AND s->>'lieutenantNom' = v_moi) INTO v_trouve;
  IF NOT v_trouve THEN RETURN jsonb_build_object('ok', false, 'raison', 'section_indisponible'); END IF;

  UPDATE public.compagnies_militaires
     SET data = v_data || jsonb_build_object('sections', v_secs, 'reserve', v_reste)
   WHERE id = v_n.compagnie_id;
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id','lieutenant','compagnieId', v_n.compagnie_id,
                                    'sectionId', v_n.section_id), updated_at = now()
   WHERE name = v_moi;
  UPDATE public.nominations_militaires SET traitee = true WHERE id = p_nomination_id;

  RETURN jsonb_build_object('ok', true, 'compagnie', v_n.compagnie_id, 'section', v_n.section_id,
                            'hommes', v_tire, 'places', c_places,
                            'incomplete', (v_deja + v_tire) < c_places,
                            'reserve_restante', jsonb_array_length(v_reste));
END;
$fn$;