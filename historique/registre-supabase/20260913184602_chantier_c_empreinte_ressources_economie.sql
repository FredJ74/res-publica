-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913184602
-- Nom original      : chantier_c_empreinte_ressources_economie
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 18:46:02 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : b651e8cce08e38e919c097d9506e2d00
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
-- Meme garde-fou que pour les couts d'ordre : le serveur ne doit jamais porter un
-- tarif perime. Le generateur publie l'empreinte des prix declares dans le vrai
-- data.js ; cette fonction recalcule la meme sur le contenu REEL de la table, et
-- le banc compare les deux. Un prix modifie cote jeu sans regeneration du miroir
-- fait diverger les deux et sort en echec AVANT deploiement.
--
-- Format aligne sur le generateur Python, au caractere pres : un entier s'ecrit
-- sans decimale (3, pas 3.0), un NULL s'ecrit vide, tri en collation "C".
-- Sans cette normalisation, deux miroirs identiques donneraient deux empreintes
-- differentes -- et le controle crierait au loup a chaque execution.
CREATE OR REPLACE FUNCTION public.ressources_economie_empreinte_reelle()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT left(md5(string_agg(
      cle || '|' || trim(trailing '.' from trim(trailing '0' from prix_base::text))
          || '|' || coalesce(trim(trailing '.' from trim(trailing '0' from prix_achat_fournisseur::text)), '')
          || '|' || coalesce(plafond::text, '')
          || '|' || coalesce(source, ''),
      E'\n' ORDER BY cle COLLATE "C")), 16)
  FROM public.ressources_economie;
$$;
GRANT EXECUTE ON FUNCTION public.ressources_economie_empreinte_reelle() TO anon, authenticated;

CREATE TABLE IF NOT EXISTS public.ressources_economie_empreinte (
  seul boolean PRIMARY KEY DEFAULT true CHECK (seul),
  empreinte text NOT NULL, pose_le timestamptz DEFAULT now()
);
ALTER TABLE public.ressources_economie_empreinte ENABLE ROW LEVEL SECURITY;
INSERT INTO public.ressources_economie_empreinte (seul, empreinte) VALUES (true, '2c2a88b3833ca978')
ON CONFLICT (seul) DO UPDATE SET empreinte = excluded.empreinte, pose_le = now();

SELECT public.ressources_economie_empreinte_reelle() AS reelle,
       (SELECT empreinte FROM public.ressources_economie_empreinte) AS attendue;