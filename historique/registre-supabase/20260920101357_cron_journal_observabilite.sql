-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920101357
-- Nom original      : cron_journal_observabilite
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-20 10:13:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : edb2719a700a27c6240404c3e63948ab
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
-- §6.12 CRONS : OBSERVABILITE DURABLE
-- ---------------------------------------------------------------------------
-- LE DEFAUT CONSTATE. La passe nocturne sait deja detecter ses echecs
-- (ECHECS_PASSE + HTTP 500), mais cette trace est VOLATILE : elle ne vit que
-- dans la reponse HTTP rendue a l'ordonnanceur Vercel. Personne, ni le GD ni le
-- jeu, ne peut repondre a la question « la taxe fonciere a-t-elle tourne la nuit
-- du 18 ? ». Pire : tacheQuotidienne() pose son marqueur de journee AVANT
-- d'appeler fn() -- choix deliberi et correct contre le double debit -- si bien
-- qu'une exception dans fn() BRULE la journee sans laisser la moindre trace
-- consultable. Une tache peut donc etre perdue toutes les nuits sans que rien
-- ne le dise.
--
-- LE PRINCIPE. Un journal en base, une ligne par (tache, jour). L'anti-rejeu EST
-- la cle : id = tache || ':' || jour. Un rejeu de la passe ne duplique pas, il
-- met a jour -- en conservant le premier debut, ce qui rend les reessais
-- lisibles au lieu de les effacer.
--
-- AUTORITE. Table fermee a anon/authenticated (RLS active SANS politique = close,
-- plus REVOKE explicite contre les DEFAULT PRIVILEGES du schema public). Ecriture
-- par une seule porte SECURITY DEFINER qui exige est_appel_serveur() -- devenue
-- fail-closed au lot precedent. Le journal est une observation, pas une surface
-- de jeu : aucun joueur n'y ecrit, aucun joueur n'y lit.

CREATE TABLE IF NOT EXISTS public.cron_journal (
  id          text PRIMARY KEY,
  tache       text        NOT NULL,
  jour        date        NOT NULL,
  statut      text        NOT NULL CHECK (statut IN ('demarree','ok','echec','ignoree')),
  debut       timestamptz NOT NULL DEFAULT now(),
  fin         timestamptz,
  duree_ms    integer,
  erreur      text,
  contexte    jsonb,
  tentatives  integer     NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS cron_journal_jour_idx   ON public.cron_journal (jour DESC);
CREATE INDEX IF NOT EXISTS cron_journal_statut_idx ON public.cron_journal (statut) WHERE statut <> 'ok';

ALTER TABLE public.cron_journal ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cron_journal FROM anon, authenticated, public;

-- Porte d'ecriture unique. Renvoie le statut reellement conserve en base, pas ce
-- qu'on a demande d'ecrire : un appelant ne doit jamais deduire d'une absence
-- d'exception que la ligne est passee.
CREATE OR REPLACE FUNCTION public.cron_journal_ecrire(
  p_tache    text,
  p_jour     date,
  p_statut   text,
  p_erreur   text    DEFAULT NULL,
  p_contexte jsonb   DEFAULT NULL,
  p_duree_ms integer DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id  text;
  v_row public.cron_journal%ROWTYPE;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF p_tache IS NULL OR btrim(p_tache) = '' OR p_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_incomplets');
  END IF;
  IF p_statut NOT IN ('demarree','ok','echec','ignoree') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide');
  END IF;

  v_id := p_tache || ':' || p_jour::text;

  INSERT INTO public.cron_journal (id, tache, jour, statut, debut, fin, duree_ms, erreur, contexte)
  VALUES (
    v_id, p_tache, p_jour, p_statut, now(),
    CASE WHEN p_statut = 'demarree' THEN NULL ELSE now() END,
    p_duree_ms, left(p_erreur, 2000), p_contexte
  )
  ON CONFLICT (id) DO UPDATE SET
    statut     = EXCLUDED.statut,
    -- Le premier debut est conserve : un reessai doit rester lisible comme un
    -- reessai, pas se maquiller en premiere execution.
    fin        = CASE WHEN EXCLUDED.statut = 'demarree' THEN NULL ELSE now() END,
    duree_ms   = coalesce(EXCLUDED.duree_ms, public.cron_journal.duree_ms),
    erreur     = EXCLUDED.erreur,
    contexte   = coalesce(EXCLUDED.contexte, public.cron_journal.contexte),
    tentatives = public.cron_journal.tentatives
                 + CASE WHEN EXCLUDED.statut = 'demarree' THEN 1 ELSE 0 END
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'ok', true, 'id', v_row.id, 'statut', v_row.statut, 'tentatives', v_row.tentatives
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cron_journal_ecrire(text, date, text, text, jsonb, integer)
  FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.cron_journal_ecrire(text, date, text, text, jsonb, integer)
  TO service_role;