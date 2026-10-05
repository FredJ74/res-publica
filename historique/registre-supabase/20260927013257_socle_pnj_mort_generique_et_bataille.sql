-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927013257
-- Nom original      : socle_pnj_mort_generique_et_bataille
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 01:32:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : d95f976b2779c858514806e9c639cafe
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
-- LA MORT GENERIQUE, ET LE COMBAT QUI LA CONTOURNAIT (27 septembre 2026)
--
-- DEFAUT B4, mesure dans le code. Quand un soldat PNJ tombe a 0 PA en bataille,
-- militaire_bataille_appliquer appelle militaire_soldat_supprimer, qui le RETIRE du tableau du
-- blob. Le declencheur miroir constate son absence et DELETE la ligne du socle, ce qui cascade
-- sur pnj_soldats_metier et pnj_possessions. Consequences :
--   * pnj_mourir n'etait JAMAIS appele : aucun avis au proprietaire, rien au sol ;
--   * les `accessoires` du soldat etaient detruits avec lui, SANS TRACE. Un des 96 soldats de
--     Vince porte une trousse de premiers secours : elle disparaissait purement et simplement ;
--   * son liquide disparaissait de meme.
-- militaire_soldat_supprimer n'a qu'UN SEUL appelant, et uniquement pour une mort a 0 PA : c'est
-- donc bien le chemin de mort, et le brancher sur le cycle generique n'invente aucune regle.
--
-- CE QUE LE CYCLE FAIT DESORMAIS : statut 'mort', deliaison, possessions au sol par la mecanique
-- existante (objets_abandonnes), et un EVENEMENT au proprietaire -- inconditionnel, sans radio :
-- apprendre la mort d'un homme ne depend d'aucun materiel.
--
-- L'ARGENT : UNE LACUNE QUE JE NE COMBLE PAS SEUL. La regle dit « objets ET argent deposes au
-- sol ». Or le jeu N'A AUCUNE mecanique d'argent au sol : objets_abandonnes ne transporte que
-- des objets, et le vol transfere l'argent de main a main sans jamais le poser. Inventer un objet
-- « bourse » reviendrait a creer un objet ramassable qu'aucun chemin ne sait reconvertir en
-- liquide -- une nouvelle mecanique, donc une decision de game design.
-- Je choisis donc de ne rien inventer ET de ne rien detruire en silence : le montant est INSCRIT
-- dans l'avis de mort, visible du proprietaire, en attendant l'arbitrage. Aujourd'hui les 96
-- soldats portent 0, donc rien n'est en jeu dans l'immediat.

-- --------------------------------------------------------------------------------------
-- 1. L'AVIS DE MORT DIT CE QU'IL Y A A RECUPERER. Deux colonnes NOMMEES, pas un fourre-tout.
-- --------------------------------------------------------------------------------------
ALTER TABLE public.pnj_evenements
  ADD COLUMN IF NOT EXISTS objets_deposes   integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS argent_du_defunt numeric NOT NULL DEFAULT 0;
COMMENT ON COLUMN public.pnj_evenements.objets_deposes IS
  'Nombre d''objets effectivement deposes au sol a l''endroit de la mort.';
COMMENT ON COLUMN public.pnj_evenements.argent_du_defunt IS
  'Liquide que portait le PNJ. En attente d''une mecanique d''argent au sol : inscrit ici pour '
  'que rien ne disparaisse sans trace, non credite a quiconque.';

ALTER TABLE public.pnj_evenements DROP CONSTRAINT IF EXISTS pnj_evt_type;
ALTER TABLE public.pnj_evenements ADD CONSTRAINT pnj_evt_type
  CHECK (type IN ('mort', 'disparition_sans_cycle'));

-- --------------------------------------------------------------------------------------
-- 2. pnj_mourir : le cycle complet, et la cause de la mort.
-- --------------------------------------------------------------------------------------
-- p_cause n'est pas decoratif : `degats` signe la mort DEFINITIVE par 0 PA, que le metier
-- declenche. Le socle ne decide pas de la cause, il l'enregistre.
CREATE OR REPLACE FUNCTION public.pnj_mourir(p_id text, p_cause text DEFAULT 'indetermine')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m record; pe record; v_n integer := 0; o record; v_ville text; v_bat text; v_room text;
BEGIN
  SELECT * INTO m FROM public.pnj_membres WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF m.statut = 'mort' THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_mort', 'deposes', 0); END IF;

  SELECT * INTO pe FROM public.pnj_position_effective(p_id);
  -- Le lieu du depot, encode comme le jeu le fait deja pour la rue.
  v_ville := COALESCE(pe.ville, 'inconnue');
  v_bat   := COALESCE(pe.building_id, 'rue-centrale');
  v_room  := COALESCE(pe.room_id, pe.rue_noeud_id, 'inconnu');

  -- Delier AVANT d'ecrire la position propre : I1 interdit les deux a la fois.
  UPDATE public.pnj_membres
     SET statut = 'mort', leader_pj = NULL, leader_pnj_id = NULL,
         ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
   WHERE id = p_id;

  -- TOUTES les possessions tombent, y compris celles issues du miroir du blob : dans ce chemin
  -- le blob perd le soldat, donc la ligne miroir est le dernier exemplaire. C'est ici qu'elle
  -- doit atterrir au sol, pas disparaitre.
  FOR o IN SELECT * FROM public.pnj_possessions WHERE pnj_id = p_id LOOP
    INSERT INTO public.objets_abandonnes (id, country, city, building_id, room_id, data)
    VALUES ('objet-abandonne-' || replace(gen_random_uuid()::text, '-', ''),
            pe.pays, v_ville, v_bat, v_room,
            (o.objet || jsonb_build_object('id',
               'objet-abandonne-' || replace(gen_random_uuid()::text, '-', '')))::text);
    v_n := v_n + 1;
  END LOOP;
  DELETE FROM public.pnj_possessions WHERE pnj_id = p_id;

  -- L'AVIS AU PROPRIETAIRE. Inconditionnel : aucune radio, aucune co-presence exigee.
  INSERT INTO public.pnj_evenements (pnj_id, pnj_nom, famille, type, pays, proprietaire_pj,
      proprietaire_institution, proprietaire_perimetre, ville, building_id, room_id,
      objets_deposes, argent_du_defunt)
  VALUES (m.id, m.nom, m.famille, 'mort', m.pays, m.proprietaire_pj,
      m.proprietaire_institution, m.proprietaire_perimetre, v_ville, v_bat, v_room,
      v_n, COALESCE(m.liquide, 0));

  RETURN jsonb_build_object('ok', true, 'cause', p_cause, 'deposes', v_n,
                            'argent_du_defunt', COALESCE(m.liquide, 0),
                            'ville', v_ville, 'building_id', v_bat, 'room_id', v_room);
END; $$;
DROP FUNCTION IF EXISTS public.pnj_mourir(text);

-- --------------------------------------------------------------------------------------
-- 3. LE COMBAT PASSE PAR LE CYCLE. militaire_soldat_supprimer garde son nom et son unique
--    appelant ; elle cesse simplement d'effacer un homme sans ceremonie.
-- --------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_soldat_supprimer(
  p_compagnie_id text, p_section_id text, p_matricule text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_data jsonb; v_sec jsonb; v_sols jsonb; v_pnj text;
BEGIN
  SELECT data INTO v_data FROM public.compagnies_militaires WHERE id = p_compagnie_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN; END IF;
  SELECT s INTO v_sec FROM jsonb_array_elements(coalesce(v_data->'sections','[]'::jsonb)) s
   WHERE s->>'id' = p_section_id;
  IF v_sec IS NULL THEN RETURN; END IF;

  -- LE CYCLE DE MORT D'ABORD, LE RETRAIT DU BLOB ENSUITE. Dans cet ordre seulement : apres le
  -- retrait, le declencheur miroir aurait deja supprime la ligne du socle et il n'y aurait plus
  -- ni possessions a poser au sol ni proprietaire a prevenir.
  v_pnj := p_compagnie_id || '-' || p_matricule;
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_pnj) THEN
    PERFORM public.pnj_mourir(v_pnj, 'degats');
  END IF;

  SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb) INTO v_sols
    FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(v_sec->'soldats')='array' THEN v_sec->'soldats' ELSE '[]'::jsonb END)
      WITH ORDINALITY AS t(sol, pos)
   WHERE sol->>'matricule' IS DISTINCT FROM p_matricule;
  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(v_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;
END; $$;

-- --------------------------------------------------------------------------------------
-- 4. LE MIROIR NE FAIT PLUS DISPARAITRE UN HOMME EN SILENCE.
-- --------------------------------------------------------------------------------------
-- Son DELETE reste legitime -- le blob fait autorite, un soldat qu'il ne contient plus n'existe
-- plus. Mais si la ligne etait encore 'actif', alors le cycle de mort n'a PAS eu lieu : quelque
-- chose a retire un soldat du blob sans passer par le chemin metier. On ne bloque pas (ce serait
-- inventer une regle de dissolution), on LAISSE UNE TRACE lisible.
CREATE OR REPLACE FUNCTION public.pnj_miroir_tracer_disparitions(p_compagnie text, p_vus text[])
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_n integer := 0; r record;
BEGIN
  FOR r IN SELECT * FROM public.pnj_membres
            WHERE id LIKE p_compagnie || '-%' AND NOT (id = ANY(p_vus))
              AND statut = 'actif' LOOP
    INSERT INTO public.pnj_evenements (pnj_id, pnj_nom, famille, type, pays, proprietaire_pj,
        proprietaire_institution, proprietaire_perimetre, ville, building_id, room_id,
        objets_deposes, argent_du_defunt)
    VALUES (r.id, r.nom, r.famille, 'disparition_sans_cycle', r.pays, r.proprietaire_pj,
        r.proprietaire_institution, r.proprietaire_perimetre, r.ville, r.building_id, r.room_id,
        (SELECT count(*) FROM public.pnj_possessions p WHERE p.pnj_id = r.id),
        COALESCE(r.liquide, 0));
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END; $$;

REVOKE ALL ON FUNCTION public.pnj_mourir(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_miroir_tracer_disparitions(text,text[])
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_mourir(text,text) TO service_role;