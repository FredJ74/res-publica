-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926090657
-- Nom original      : securite_fermeture_categorie_a_trois_tables
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-26 09:06:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 2b5333ef485f0a9f75090bdfbdf75471
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
-- SECURITE : FERMETURE DES TROIS TABLES DE CATEGORIE A (26 septembre 2026)
--
-- CONTEXTE. 25 tables ont la RLS desactivee et le role `authenticated` y possede INSERT et
-- UPDATE (relacl = authenticated=arwxtm). Comme la RLS est desactivee, l'acces effectif est
-- donc le GRANT seul : n'importe quel joueur connecte pouvait ecrire ces tables directement
-- par PostgREST. L'audit des 25 a classe chaque table selon ses ecritures clientes legitimes :
--   A = aucune ecriture cliente  -> fermeture immediate sure   (3 tables, celles-ci)
--   B = une RPC couvre deja tout -> aucune table dans ce cas
--   C = ecriture cliente encore necessaire -> migration requise (22 tables, NON fermees ici)
--
-- POURQUOI CELLE-CI D'ABORD -- pa_credits_sources est une ELEVATION DE PRIVILEGE reelle.
-- pa_crediter_atteste(p_acteur, p_source, p_reference, p_ordre) lit :
--     SELECT true, montant INTO v_declare, v_montant
--       FROM public.pa_credits_sources WHERE source = p_source;
-- puis credite EXACTEMENT ce montant. La seule garde est pa_credits_uniques, qui empeche le
-- rejeu d'une meme reference -- pas la repetition avec une reference differente.
-- Un joueur connecte pouvait donc inserer ('ma_source', 999) puis appeler la RPC autant de
-- fois qu'il voulait avec des references distinctes, et s'octroyer des PA sans limite.
-- La RPC elle-meme est correctement ecrite : c'etait sa liste blanche qui etait ouverte.
-- Figure deja rencontree dans ce depot : une porte verrouillee a cote d'une fenetre ouverte.
--
-- Les deux autres sont des tables d'EMPREINTE (une ligne, miroir de regles), jamais ecrites
-- ni lues a l'execution : zero occurrence dans tout le depot, et aucune fonction de pg_proc ne
-- les reference.
--
-- CE QUI EST CONSERVE : le SELECT de `authenticated`. Aucune de ces trois tables ne contient
-- de secret (ce sont des regles de jeu), et le garder supprime tout risque de regression sur
-- une lecture que l'audit aurait manquee. pa_crediter_atteste est SECURITY DEFINER et
-- appartient a postgres : elle lit la liste blanche sans dependre de ces droits.
--
-- CE QUI N'EST PAS FAIT : activer la RLS. Le piege est connu et documente dans ce depot --
-- activer la RLS reveille les policies dormantes USING(true) et, les policies permissives se
-- combinant par OR, un seul `true` annulerait toute regle d'autorite. Ces trois tables n'ont
-- certes aucune policy, mais la revocation du GRANT suffit et ne depend d'aucune subtilite :
-- acces effectif = GRANT ET (pas de RLS OU policy permissive).

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.pa_credits_sources, public.pa_bonus_differes_empreinte,
     public.postes_nommes_regles_empreinte
  FROM anon, authenticated, PUBLIC;

GRANT SELECT ON public.pa_credits_sources, public.pa_bonus_differes_empreinte,
                public.postes_nommes_regles_empreinte
  TO authenticated;

COMMENT ON TABLE public.pa_credits_sources IS
  'LISTE BLANCHE des sources de credit de PA, avec le montant autorise. Lue par '
  'pa_crediter_atteste, qui credite exactement ce montant. ECRITURE FERMEE AU CLIENT le '
  '26 septembre 2026 : y inserer une ligne equivalait a s''octroyer des PA sans limite, la '
  'garde pa_credits_uniques ne portant que sur la reference. Ne jamais rouvrir INSERT/UPDATE '
  'a anon ni a authenticated.';