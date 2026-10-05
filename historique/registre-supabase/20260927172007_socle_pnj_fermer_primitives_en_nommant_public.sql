-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927172007
-- Nom original      : socle_pnj_fermer_primitives_en_nommant_public
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 17:20:07 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 94ed8719c4f46de0a1002e06264b87c2
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
-- CORRECTIF DE DROITS. Mes REVOKE nommaient `authenticated, anon` et laissaient donc EXECUTE a
-- PUBLIC, dont `authenticated` herite : les primitives restaient grandes ouvertes. C'est la regle 2
-- de ma propre doctrine de controle, et j'y suis retombe. Il faut TOUJOURS nommer PUBLIC.
--
-- Restent volontairement ouvertes, parce qu'un chemin client les appelle reellement :
--   employe_recruter, employe_liberer, employe_mes_employes, militant_recruter.
-- Toutes les autres sont techniques : le client n'en a aucun besoin, et l'ancien bouton generique
-- a ete retire en dur plutot qu'en interrogeant le registre.
REVOKE ALL ON FUNCTION public.employe_pnj_id(text, text, text)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.employe_metiers_recrutables()         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_metier_profil(text)               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_metier_de(text)                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_fonction_recrutable(text)         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_classe_decor(text)                FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_axe_au_socle(text, text)          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.depute_presence(text)                 FROM PUBLIC, anon, authenticated;

-- Meme correction sur les primitives des lots precedents, verifiees au passage.
REVOKE ALL ON FUNCTION public.pnj_classe_de(text)                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_axe_verrouille(text[], text)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_axe_position_refus(text[])        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_garde(text[])                  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_debiter(text[], integer)       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_crediter(text[], integer)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_fixer(text[], integer)         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_max()                          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.militaire_blob_projeter(text)         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_miroir_compagnie(text)            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_comparer_soldats(text)            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_caracteristiques_base(text)       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_caracteristique_base(text, text)  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_caracteristiques_cles()           FROM PUBLIC, anon, authenticated;