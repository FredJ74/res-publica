-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920225121
-- Nom original      : militaire_batailles_groupes
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 22:51:21 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f4d0c2ae90908b5154e8d88ba2e974ed
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
-- =====================================================================
-- LE GROUPE DEVIENT L'UNITE DE DECISION (21 septembre 2026)
-- =====================================================================
-- Le modele camp_a / camp_b ne convient plus : une bataille peut compter
-- plus de deux pays, et le repli se decide DESORMAIS PAR GROUPE. Un groupe
-- allie peut donc decrocher pendant qu'un autre tient la position.
--
-- Le groupe est la SECTION (compagnie + section). Un PJ engage sans section
-- forme un groupe a lui seul : il commande ce qu'il commande, c'est-a-dire
-- lui-meme.

ALTER TABLE public.batailles_engagements
  ADD COLUMN IF NOT EXISTS groupe_id text;

-- Identifiant deterministe : meme compagnie + meme section = meme groupe.
UPDATE public.batailles_engagements
   SET groupe_id = coalesce(compagnie_id, 'solo') || ':' ||
                   coalesce(section_id, coalesce(personnage, matricule, id::text))
 WHERE groupe_id IS NULL;

CREATE TABLE IF NOT EXISTS public.batailles_groupes (
  bataille_id       bigint  NOT NULL,
  groupe_id         text    NOT NULL,
  camp              text    NOT NULL,
  compagnie_id      text,
  section_id        text,
  leader            text,              -- PJ qui commande, NULL = groupe mene par un PNJ
  effectif_initial  integer NOT NULL,
  -- Decision du round en cours : NULL tant que le chef n'a pas tranche.
  decision          text CHECK (decision IN ('tenir','replier')),
  -- Horodatage d'OUVERTURE de la fenetre de 90 secondes. NULL = pas de
  -- decision en attente.
  attente_depuis    timestamptz,
  repli             jsonb,
  sorti_round       integer,
  PRIMARY KEY (bataille_id, groupe_id)
);

CREATE INDEX IF NOT EXISTS batailles_groupes_bataille_idx
  ON public.batailles_groupes (bataille_id) WHERE sorti_round IS NULL;

ALTER TABLE public.batailles_groupes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.batailles_groupes FROM PUBLIC, anon, authenticated;

-- Lecture seule pour les joueurs : l'ecran de combat a besoin de savoir si
-- une decision est attendue de lui. Aucune ecriture directe : elle passe
-- par militaire_bataille_decider.
CREATE POLICY batailles_groupes_lecture ON public.batailles_groupes
  FOR SELECT TO authenticated USING (true);
GRANT SELECT ON public.batailles_groupes TO authenticated;


-- ---------------------------------------------------------------------
-- LE SEUIL DE REPLI, evalue GROUPE PAR GROUPE
-- ---------------------------------------------------------------------
-- 50 % de pertes sur l'effectif initial DU GROUPE, jamais sur celui du camp.
CREATE OR REPLACE FUNCTION public.militaire_groupe_sous_seuil(p_bataille_id bigint, p_groupe_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public' AS $function$
  SELECT (SELECT count(*) FROM public.batailles_engagements e
           WHERE e.bataille_id = p_bataille_id AND e.groupe_id = p_groupe_id
             AND e.sorti_round IS NULL) * 2
         <= coalesce((SELECT g.effectif_initial FROM public.batailles_groupes g
                       WHERE g.bataille_id = p_bataille_id AND g.groupe_id = p_groupe_id), 0);
$function$;

REVOKE ALL ON FUNCTION public.militaire_groupe_sous_seuil(bigint, text) FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.batailles_groupes IS
  'Unite de decision du combat : un groupe = une section engagee. Porte son effectif initial, son chef et sa decision de repli.';