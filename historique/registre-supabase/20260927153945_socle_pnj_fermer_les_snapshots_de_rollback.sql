-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927153945
-- Nom original      : socle_pnj_fermer_les_snapshots_de_rollback
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 15:39:45 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : abf7ee8a565628d49ab8819ac770f0f3
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
-- Les trois tables de sauvegarde du checkpoint A ont ete creees dans `public`, donc nees GRAND
-- OUVERTES a `anon` et `authenticated` par les DEFAULT PRIVILEGES du schema -- et elles contiennent
-- la copie complete des 101 PNJ et du blob militaire. C'est une exposition que J'AI creee en
-- prenant le snapshot. Je la referme tout de suite.
--
-- RLS activee SANS AUCUNE POLICY, volontairement : ces tables ne servent qu'au rollback, execute par
-- `postgres` ou `service_role`, qui contournent la RLS. Ici, « bloquer tout le monde » est
-- exactement l'effet voulu -- ce n'est pas le piege des policies dormantes, c'est son usage legitime.
-- Le REVOKE est ajoute par ceinture et bretelles : sans droit de table, la question de la policy ne
-- se pose meme pas.
ALTER TABLE public.zz_snap_cka_blob    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zz_snap_cka_membres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zz_snap_cka_metier  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.zz_snap_cka_blob    FROM anon, authenticated, PUBLIC;
REVOKE ALL ON TABLE public.zz_snap_cka_membres FROM anon, authenticated, PUBLIC;
REVOKE ALL ON TABLE public.zz_snap_cka_metier  FROM anon, authenticated, PUBLIC;

COMMENT ON TABLE public.zz_snap_cka_blob IS
  'Sauvegarde du blob militaire avant la bascule des axes position_leader et pa (27/09/2026). '
  'Supprimable une fois la bascule constatee en jeu sur plusieurs jours.';
COMMENT ON TABLE public.zz_snap_cka_membres IS
  'Sauvegarde de pnj_membres avant la bascule des axes position_leader et pa (27/09/2026).';
COMMENT ON TABLE public.zz_snap_cka_metier IS
  'Sauvegarde de pnj_soldats_metier avant la bascule des axes position_leader et pa (27/09/2026).';