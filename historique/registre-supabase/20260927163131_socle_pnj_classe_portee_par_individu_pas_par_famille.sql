-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927163131
-- Nom original      : socle_pnj_classe_portee_par_individu_pas_par_famille
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 16:31:31 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 66a7721d6e9cbb0388fa1019bd3b5f4e
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
-- CHECKPOINT A0 — LA CLASSE APPARTIENT AU PNJ, LA FONCTION A SON METIER
--
-- CE QUE CECI CORRIGE. `pnj_classe_de` deduisait la classe de la FAMILLE, par jointure. Or classe
-- et fonction sont deux choses independantes, et le jeu en fournit la preuve : Prosper Tampon
-- exerce la fonction de douanier au passage en douane, mais c'est un GAMMA fixe du decor, tandis
-- que les quatre effectifs du service des Douanes sont des BETA employes. Meme vocabulaire metier,
-- nature completement differente. Un modele qui derive la classe du metier ne peut pas les
-- distinguer, et aurait declare Prosper Tampon beta -- donc consommateur de PA, assassinable et
-- employable.
--
-- LE MODELE CORRIGE :
--   * `pnj_membres.classe`  = la NATURE du PNJ (alpha / beta / gamma). Portee par l'individu.
--   * `pnj_membres.famille` = sa FONCTION, son metier, son job. Ce que le monde voit de lui.
--   * `pnj_familles_classes` cesse d'etre une verite et devient un DEFAUT : la classe habituelle
--     d'une famille, utilisee quand l'individu n'en declare pas. Un individu peut toujours
--     contredire ce defaut, et c'est exactement le cas Prosper Tampon.
--
-- FAIL-CLOSED CONSERVE : si ni l'individu ni sa famille ne declarent de classe, `pnj_classe_de`
-- rend NULL et `pnj_pa_garde` refuse alors toute variation de PA ('classe non_declaree'). Aucune
-- classe implicite n'est inventee.
ALTER TABLE public.pnj_membres
  ADD COLUMN IF NOT EXISTS classe text
  CONSTRAINT pnj_membres_classe_connue CHECK (classe IS NULL OR classe IN ('alpha','beta','gamma'));

COMMENT ON COLUMN public.pnj_membres.classe IS
  'NATURE du PNJ : alpha (consomme ses PA), beta (employable, 12 PA jamais consommes), '
  'gamma (institutionnel, immuable, sans proprietaire). Portee par l''individu, car un meme metier '
  'peut exister dans plusieurs classes. NULL = on retombe sur le defaut de la famille.';
COMMENT ON COLUMN public.pnj_membres.famille IS
  'FONCTION / METIER / JOB du PNJ -- ce que le monde voit de lui. N''implique AUCUNE classe : '
  'cf. Prosper Tampon (fonction douanier, classe gamma) face aux effectifs des Douanes '
  '(metier douanier, classe beta).';
COMMENT ON TABLE public.pnj_familles_classes IS
  'Classe PAR DEFAUT d''une famille, et non une verite : pnj_membres.classe la contredit quand '
  'l''individu le declare. Sert a ne pas repeter la classe sur chaque ligne du cas courant.';

-- Les 101 PNJ existants recoivent explicitement la classe que leur famille leur donnait deja :
-- aucun changement de comportement, mais la valeur devient portee par l'individu.
UPDATE public.pnj_membres m
   SET classe = c.classe
  FROM public.pnj_familles_classes c
 WHERE c.famille = m.famille AND m.classe IS NULL;

CREATE OR REPLACE FUNCTION public.pnj_classe_de(p_pnj_id text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  -- L'individu d'abord, le defaut de sa famille ensuite. Jamais de classe inventee.
  SELECT COALESCE(m.classe,
                  (SELECT c.classe FROM public.pnj_familles_classes c WHERE c.famille = m.famille))
    FROM public.pnj_membres m WHERE m.id = p_pnj_id;
$$;

REVOKE ALL ON FUNCTION public.pnj_classe_de(text) FROM authenticated, anon;