-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260912071832
-- Nom original      : corruption_presse
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-12 07:18:32 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c8784c8729a93355f201dce3a60da3d6
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
-- CORROMPRE UN JOURNALISTE -- COUVERTURE D'UNE AFFAIRE JUDICIAIRE (12 septembre 2026)
-- L'ordre ne concerne ni les scandales ni les fuites : il porte sur LA COUVERTURE d'une affaire
-- judiciaire REELLE du jour, avant la cloture editoriale de minuit (Europe/Paris).
--
-- IDENTITE DE L'AFFAIRE : le Journal identifie deja chaque fait publiable par
-- '<table>:<id>' ('jugements:jug-...' / 'detentions:det-...'), cle stable de la creation a la
-- publication (api/_journal-collecte.js). C'est cette cle, et elle seule, que la corruption vise.
-- Le dossier judiciaire lui-meme n'est JAMAIS touche : seule la couverture mediatique change.
--
-- TRACE : elle existe que le journaliste accepte OU refuse. Elle est ecrite dans actions_tracables,
-- deja fouillable par « Mener une enquete », plus une ligne detaillee ici. Aucune rumeur n'est creee
-- automatiquement, aucun mandat non plus : le jeu enregistre le fait, rien de plus.

CREATE TABLE IF NOT EXISTS public.corruptions_presse (
  id            bigserial PRIMARY KEY,
  affaire_ref   text NOT NULL,              -- 'jugements:jug-...' ou 'detentions:det-...'
  affaire_type  text NOT NULL CHECK (affaire_type IN ('jugements', 'detentions')),
  affaire_pj    text NOT NULL,              -- PJ concerne par l'affaire
  corrupteur    text NOT NULL,
  option        text NOT NULL CHECK (option IN ('etouffer', 'favorable')),
  reussite      boolean NOT NULL,
  jet           smallint,
  taux          smallint,
  pays          text,
  jour_paris    date NOT NULL,
  cree_le       timestamptz NOT NULL DEFAULT now(),
  -- Une seule tentative par affaire ET par corrupteur ; un AUTRE PJ peut tenter sur la meme affaire.
  UNIQUE (affaire_ref, corrupteur)
);
CREATE INDEX IF NOT EXISTS corruptions_presse_affaire ON public.corruptions_presse (affaire_ref) WHERE reussite;
ALTER TABLE public.corruptions_presse ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.corruptions_presse FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.corruptions_presse TO anon, authenticated;
DROP POLICY IF EXISTS corruptions_presse_lecture ON public.corruptions_presse;
CREATE POLICY corruptions_presse_lecture ON public.corruptions_presse FOR SELECT USING (true);

-- Affaires eligibles : celles du JOUR (Europe/Paris) qui n'ont pas encore ete couvertes par une
-- edition publiee. La borne « deja publiee » est exactement celle de la collecte du Journal : le
-- generated_at de la derniere edition publiee du pays.
CREATE OR REPLACE FUNCTION public.corruption_presse_affaires(p_pays text, p_instant timestamptz DEFAULT now())
RETURNS TABLE (affaire_ref text, affaire_type text, affaire_pj text, resume text, cree_le timestamptz)
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  WITH borne AS (
    SELECT COALESCE(max(generated_at), p_instant - interval '1 day') AS depuis
      FROM public.journal_editions WHERE country = p_pays AND statut = 'publiee'
  ), jug AS (
    SELECT 'jugements:' || j.id AS affaire_ref, 'jugements'::text AS affaire_type,
           j.accuse AS affaire_pj,
           j.accuse || ' — condamnation pour ' || COALESCE(j.motif, 'motif non precise')
             || COALESCE(' : ' || j.peine, '') AS resume,
           j.created_at AS cree_le
      FROM public.jugements j, borne b
     WHERE j.country = p_pays AND j.created_at >= b.depuis
       AND (j.created_at AT TIME ZONE 'Europe/Paris')::date = (p_instant AT TIME ZONE 'Europe/Paris')::date
  ), det AS (
    SELECT 'detentions:' || d.id AS affaire_ref, 'detentions'::text AS affaire_type,
           d.nom AS affaire_pj,
           d.nom || ' — placement en detention (' || COALESCE(d.raison, 'motif non precise') || ')' AS resume,
           d.created_at AS cree_le
      FROM public.detentions d, borne b
     WHERE d.country = p_pays AND d.created_at >= b.depuis
       AND (d.created_at AT TIME ZONE 'Europe/Paris')::date = (p_instant AT TIME ZONE 'Europe/Paris')::date
  )
  SELECT * FROM jug UNION ALL SELECT * FROM det ORDER BY cree_le DESC;
$$;

-- Etat editorial d'une affaire, pour la future collecte du Journal :
--   'etouffee'  -> ne pas publier cette affaire dans l'edition
--   'favorable' -> publier, mais demander un cadrage favorable au PJ concerne
--   NULL        -> traitement normal
CREATE OR REPLACE FUNCTION public.corruption_presse_etat(p_affaire_ref text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN bool_or(option = 'etouffer') THEN 'etouffee'
              WHEN bool_or(option = 'favorable') THEN 'favorable' END
    FROM public.corruptions_presse WHERE affaire_ref = p_affaire_ref AND reussite;
$$;

CREATE OR REPLACE FUNCTION public.corruption_presse_tenter(
  p_requete     text,
  p_joueur      text,
  p_affaire_ref text,
  p_option      text,
  p_malus_isn   integer DEFAULT 0,
  p_instant     timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rej  jsonb;
  v_p    record;
  v_a    record;
  v_jour date;
  v_taux integer;
  v_jet  integer;
  v_ok   boolean;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'corruption_presse');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_option NOT IN ('etouffer', 'favorable') OR COALESCE(btrim(p_affaire_ref), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;

  SELECT pa, liquide, banque, stats, resources, country, current_city INTO v_p
    FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  -- L'affaire doit etre eligible MAINTENANT : du jour, et pas encore publiee.
  SELECT * INTO v_a FROM public.corruption_presse_affaires(v_p.country, p_instant) a
   WHERE a.affaire_ref = p_affaire_ref;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'affaire_non_eligible'));
  END IF;

  -- Ressources verifiees AVANT le jet : une reussite ne doit jamais mener a un etat impossible.
  IF COALESCE(v_p.pa, 0) < 2 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;
  IF COALESCE(v_p.liquide, 0) + COALESCE(v_p.banque, 0) < 500 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'));
  END IF;

  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;

  -- Formule propre a cet ordre : 30 + CHA + floor(INF/4) - malus ISN, borne [5, 85].
  v_taux := LEAST(85, GREATEST(5,
    30 + floor(public.assemblee_stat_base(v_p.stats, 'CHA'))::integer
       + floor(GREATEST(0, COALESCE(CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number'
               THEN (v_p.resources ->> 'inf')::numeric END, 0)) / 4)::integer
       - LEAST(25, GREATEST(0, COALESCE(p_malus_isn, 0)))));
  v_jet := floor(random() * 100)::integer + 1;
  v_ok := v_jet <= v_taux;

  -- Une seule tentative par affaire et par corrupteur : c'est l'insertion qui fait foi, donc aussi
  -- contre le double-clic et la concurrence. La TRACE existe que le journaliste accepte ou refuse.
  INSERT INTO public.corruptions_presse (affaire_ref, affaire_type, affaire_pj, corrupteur, option,
                                         reussite, jet, taux, pays, jour_paris)
  VALUES (p_affaire_ref, v_a.affaire_type, v_a.affaire_pj, p_joueur, p_option,
          v_ok, v_jet, v_taux, v_p.country, v_jour)
  ON CONFLICT (affaire_ref, corrupteur) DO NOTHING;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_tente'));
  END IF;

  -- Trace fouillable par « Mener une enquete », en reussite comme en refus. Aucune rumeur n'est
  -- creee ici : le jeu enregistre le fait, son exploitation viendra des systemes d'enquete.
  BEGIN
    INSERT INTO public.actions_tracables (id, auteur, cible, type_action, country, city, jour, jour_expiration, decouvert)
    VALUES ('corrpresse-' || md5(p_affaire_ref || '|' || p_joueur), p_joueur, v_a.affaire_pj,
            CASE WHEN v_ok THEN 'corruption_presse' ELSE 'corruption_presse_refusee' END,
            v_p.country, v_p.current_city,
            0, 0, false);
  EXCEPTION WHEN OTHERS THEN
    NULL;   -- la trace detaillee reste dans corruptions_presse : un echec ici n'annule pas l'acte
  END;

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', v_ok, 'jet', v_jet, 'taux', v_taux,
    'option', p_option, 'affaire_ref', p_affaire_ref, 'affaire_pj', v_a.affaire_pj,
    'resume', v_a.resume,
    'pa', CASE WHEN v_ok THEN 2 ELSE 0 END, 'cout', CASE WHEN v_ok THEN 500 ELSE 0 END));
END;
$$;

REVOKE ALL ON FUNCTION public.corruption_presse_affaires(text, timestamptz)                          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.corruption_presse_etat(text)                                           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.corruption_presse_tenter(text, text, text, text, integer, timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.corruption_presse_affaires(text, timestamptz)                        TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.corruption_presse_etat(text)                                         TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.corruption_presse_tenter(text, text, text, text, integer, timestamptz) TO anon, authenticated, service_role;