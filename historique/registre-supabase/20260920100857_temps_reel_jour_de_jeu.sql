-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920100857
-- Nom original      : temps_reel_jour_de_jeu
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 10:08:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 935ac29f6c36c45ef359af4e9c996431
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
-- §6.2 — LE JOUR DU MONDE DEVIENT LE TEMPS REEL SERVEUR
-- =====================================================================
-- CE QUI N'ALLAIT PAS. jour_de_jeu_pays() valait max(day) sur les personnages du
-- pays, et `day` est ecrit par le navigateur. L'audit l'a demontre : un seul
-- joueur ecrivant day = 9999 faisait basculer la date nationale de Republia pour
-- tout le monde -- et comme la fonction prend un maximum, elle ne redescendait
-- JAMAIS.
--
-- DECISION GD : 24 heures reelles = 24 heures. Le serveur est l'autorite
-- temporelle. personnage.day peut rester un compteur personnel ; il cesse d'etre
-- l'horloge du monde.
--
-- CONTINUITE. L'epoque est choisie pour que le basculement ne decale rien :
-- max(day) vaut 9 aujourd'hui (20/09/2026), et 2026-09-12 + 8 jours + 1 = 9.
-- Les detentions et traces en cours gardent donc exactement leur numerotation.
-- L'epoque est DECLAREE dans une table, pas enfouie dans du code.
--
-- LES SIX APPELANTS ne changent pas d'une ligne : agent_trace_deposer,
-- agent_traducteur_ecouter, arrestation_urgence, cellule_renseignement_clore,
-- detention_ouvrir_interne, detentions_pnj_liberer_echues. Tous s'en servent
-- comme horodatage de detention ou de trace -- le passage au temps reel les
-- rend tous corrects : une peine s'ecoule desormais meme si le detenu ne se
-- reconnecte pas, et personne ne peut l'accelerer en bougeant son compteur.

CREATE TABLE IF NOT EXISTS public.rp_epoques (
  pays       text PRIMARY KEY,
  jour_un    date NOT NULL,
  note       text
);
ALTER TABLE public.rp_epoques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.rp_epoques FROM PUBLIC, anon, authenticated;

INSERT INTO public.rp_epoques (pays, jour_un, note) VALUES
  ('republic', DATE '2026-09-13',
   'Jour 1 = 13/09/2026, date de reinitialisation de la beta et de creation du premier personnage. Choisie pour que le passage de max(day) au temps reel ne decale aucune detention en cours.')
ON CONFLICT (pays) DO NOTHING;

CREATE OR REPLACE FUNCTION public.jour_de_jeu_pays(p_pays text)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $fn$
  SELECT greatest(1,
    ((now() AT TIME ZONE 'Europe/Paris')::date
      - coalesce((SELECT e.jour_un FROM public.rp_epoques e WHERE e.pays = p_pays),
                 DATE '2026-09-13')
    )::int + 1);
$fn$;

-- Meme verite, sans parametre, pour les usages nationaux : evite qu'un futur
-- appelant reinvente le calcul.
CREATE OR REPLACE FUNCTION public.jour_de_jeu_reel()
RETURNS integer LANGUAGE sql STABLE
SET search_path TO 'public','pg_temp' AS $fn$
  SELECT public.jour_de_jeu_pays('republic');
$fn$;
REVOKE ALL ON FUNCTION public.jour_de_jeu_reel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.jour_de_jeu_reel() TO authenticated, service_role;