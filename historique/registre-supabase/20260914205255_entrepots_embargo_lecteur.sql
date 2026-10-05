-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914205255
-- Nom original      : entrepots_embargo_lecteur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 20:52:55 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0443fb69cfbe3337c19421e7371a6f26
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
-- EMBARGO — REUTILISATION DU MOTEUR EXISTANT, PAS D'UNE SECONDE NOTION.
-- plateau-gouvernement.js porte deja un moteur de sanctions complet (MESURES_SANCTION,
-- sanctionsActives, sanctionActive, EMBARGO_FLUX_CONNUS) dont la semantique est :
--     etat[paysCible].mesures contient 'embargo'
-- Ce moteur est aujourd'hui DORMANT : aucune de ses fonctions n'a d'appelant hors de son propre
-- fichier, et son etat n'etait persiste nulle part. On lui donne donc une maison -- la meme que
-- le reste de l'etat national, budgets_nationaux.data -- sans changer sa forme d'un caractere,
-- pour que l'ecran du Ministre des Affaires etrangeres puisse s'y brancher plus tard sans
-- rien reecrire.
--
-- Ce lot ne CREE aucune sanction et n'ajoute aucune interface pour en imposer : il se contente
-- de LIRE, afin que les commandes internationales sachent s'abstenir.
CREATE OR REPLACE FUNCTION public.embargo_actif(p_pays_soi text, p_pays_cible text)
RETURNS boolean LANGUAGE sql STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT coalesce((
    SELECT (data -> 'sanctions' -> p_pays_cible -> 'mesures') ? 'embargo'
      FROM public.budgets_nationaux
     WHERE id = p_pays_soi
       AND jsonb_typeof(data -> 'sanctions' -> p_pays_cible -> 'mesures') = 'array'
  ), false);
$$;

REVOKE ALL ON FUNCTION public.embargo_actif(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.embargo_actif(text, text) TO anon, authenticated;
