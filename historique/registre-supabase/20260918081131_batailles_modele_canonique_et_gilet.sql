-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260918081131
-- Nom original      : batailles_modele_canonique_et_gilet
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-18 08:11:31 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b28024cc2c0b633d52c666b9e283352b
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
-- =========================================================================================
-- 1. MODELE CANONIQUE D'HISTORIQUE DE BATAILLE (18 septembre 2026)
-- =========================================================================================
-- PREPARATION, pas implementation. Le moteur physique de combat n'existe pas et n'est PAS
-- construit ici. Ce qui est pose, c'est l'endroit ou il ecrira -- pour que le jour ou il arrive,
-- il n'ait pas a inventer son propre format et a creer une enieme verite paralelle.
--
-- Deux tables et une separation nette :
--   * `batailles`             : le FAIT (qui, ou, quand, quelle issue). Une ligne par bataille.
--   * `batailles_engagements` : QUI y etait et dans quel etat il en est sorti. Une ligne par
--                               participant, PJ comme PNJ -- un PNJ n'a pas de fiche, donc il est
--                               identifie par son matricule et sa compagnie, pas par un nom.
--
-- POURQUOI PAS chronique_nationale : la chronique est le RECIT public, deja en service et lue par
-- la Tribune. Elle restera la narration de la bataille. Mais un recit ne se requete pas : on ne
-- peut pas lui demander « combien de fois ce soldat a-t-il combattu », ni « quelles pertes cette
-- compagnie a-t-elle subies ». Les deux coexistent, avec des roles distincts -- exactement comme
-- services_militaires (canonique) et le calepin (projection).
--
-- AUCUNE ECRITURE CLIENT. Ni maintenant ni plus tard : une bataille est un fait etabli par la
-- resolution, jamais declare par un navigateur. Les tables naissent fermees.
CREATE TABLE IF NOT EXISTS public.batailles (
  id           bigserial PRIMARY KEY,
  pays         text NOT NULL,              -- pays sur le territoire duquel elle a lieu
  ville        text,
  batiment     text,
  piece        text,
  debut_ts     timestamptz NOT NULL DEFAULT now(),
  fin_ts       timestamptz,
  -- Volontairement du texte libre et non une enumeration fermee : le moteur n'existe pas, et
  -- figer ici les issues possibles serait decider a sa place.
  issue        text,
  resume       text,
  chronique_id bigint                      -- lien facultatif vers le recit public
);

CREATE INDEX IF NOT EXISTS batailles_pays_idx ON public.batailles (pays, debut_ts DESC);

CREATE TABLE IF NOT EXISTS public.batailles_engagements (
  id           bigserial PRIMARY KEY,
  bataille_id  bigint NOT NULL REFERENCES public.batailles(id) ON DELETE CASCADE,
  camp         text NOT NULL,              -- le pays ou la faction engagee
  -- Un PJ est identifie par son nom ; un PNJ par (compagnie, section, matricule). Exactement un
  -- des deux est renseigne -- un participant n'est jamais les deux a la fois.
  personnage   text,
  compagnie_id text,
  section_id   text,
  matricule    text,
  grade        text,
  etat_final   text,
  CONSTRAINT batailles_engagements_identite CHECK (
    (personnage IS NOT NULL AND matricule IS NULL) OR
    (personnage IS NULL     AND matricule IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS batailles_engagements_bataille_idx
  ON public.batailles_engagements (bataille_id);
CREATE INDEX IF NOT EXISTS batailles_engagements_personnage_idx
  ON public.batailles_engagements (personnage) WHERE personnage IS NOT NULL;

ALTER TABLE public.batailles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batailles_engagements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS batailles_lecture ON public.batailles;
DROP POLICY IF EXISTS batailles_engagements_lecture ON public.batailles_engagements;
-- Une bataille est un fait public : la Salle des Faits d'Armes doit pouvoir l'afficher.
CREATE POLICY batailles_lecture ON public.batailles FOR SELECT TO authenticated USING (true);
CREATE POLICY batailles_engagements_lecture ON public.batailles_engagements FOR SELECT TO authenticated USING (true);

REVOKE ALL ON public.batailles FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.batailles_engagements FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.batailles TO authenticated;
GRANT SELECT ON public.batailles_engagements TO authenticated;
REVOKE ALL ON SEQUENCE public.batailles_id_seq FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.batailles_engagements_id_seq FROM PUBLIC, anon, authenticated;

-- =========================================================================================
-- 2. GILET PARE-BALLES : ETAT `fragilise` (18 septembre 2026)
-- =========================================================================================
-- Le gilet n'est pas un compteur de points de vie : il encaisse, ou il ne suffit pas. Un gilet
-- qui a deja encaisse devient `fragilise` et ne protege plus -- il ne disparait pas, il temoigne.
-- La REPARATION n'est volontairement pas construite : elle suppose un atelier, une recette et un
-- cout, c'est-a-dire des decisions GD qui n'ont pas ete rendues. Dette assumee et signalee.
--
-- 50 % cote SERVEUR. La protection balistique ne peut pas etre un tirage du navigateur de celui
-- qu'on vise : ce serait laisser la cible decider si elle est touchee.
CREATE OR REPLACE FUNCTION public.militaire_gilet_encaisser(p_porteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_inv jsonb; v_pos integer; v_gilet jsonb; v_protege boolean;
BEGIN
  -- APPEL SERVEUR UNIQUEMENT. C'est la resolution du combat qui appelle ceci, jamais un client.
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'appel_non_serveur');
  END IF;

  SELECT CASE WHEN jsonb_typeof(inventory)='array' THEN inventory ELSE '[]'::jsonb END
    INTO v_inv FROM public.personnages_donnees WHERE name = p_porteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'porteur_introuvable'); END IF;

  -- Un gilet DEJA fragilise ne compte pas : on cherche un gilet intact, et lui seul.
  SELECT i, pos INTO v_gilet, v_pos
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos)
   WHERE i->>'produitMilitaire' = 'gilet_pare_balles'
     AND coalesce((i->>'fragilise')::boolean, false) = false
   ORDER BY pos LIMIT 1;
  IF v_gilet IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'protege', false, 'raison', 'aucun_gilet_intact');
  END IF;

  v_protege := (random() < 0.5);

  -- Qu'il ait protege ou non, le gilet a pris le coup : il devient fragilise dans les deux cas.
  SELECT coalesce(jsonb_agg(
           CASE WHEN pos = v_pos
                THEN i || jsonb_build_object('fragilise', true,
                       'desc', coalesce(i->>'desc','') || ' Fragilisé : a déjà encaissé un impact.')
                ELSE i END ORDER BY pos), '[]'::jsonb)
    INTO v_inv FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS t(i, pos);
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = p_porteur;

  RETURN jsonb_build_object('ok', true, 'protege', v_protege, 'gilet_fragilise', true,
    'objet_id', v_gilet->>'id');
END;
$$;

REVOKE ALL ON FUNCTION public.militaire_gilet_encaisser(text) FROM PUBLIC, anon, authenticated;