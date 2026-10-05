-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913182309
-- Nom original      : chantier_c_miroir_etat_civil_et_empreinte
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 18:23:09 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 6feccc295d3f1c50970314f8ba6b6f92
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
-- Les quatre ordres de l'etat civil declares dans plateau-politique.js et nulle
-- part dans data.js. Sans eux, le miroir fail-closed aurait refuse la demande
-- d'acte officiel, la naturalisation, la demande en mariage et sa celebration.
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
('acte_officiel',1,50),('demander_mariage',1,0),('demander_naturalisation',2,0),('officialiser_mariage',2,200)
ON CONFLICT (fn, pa, cost) DO NOTHING;

-- Empreinte du miroir REELLEMENT en base, recalculee a la demande. md5 et non
-- sha256 : Postgres l'a en natif, sans extension a installer. L'ordre de tri est
-- fige en collation "C" pour reproduire exactement l'ordre d'octets du
-- generateur Python -- une collation linguistique classerait les underscores
-- autrement et ferait diverger deux miroirs pourtant identiques.
CREATE OR REPLACE FUNCTION public.ordres_couts_empreinte_reelle()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT left(md5(string_agg(fn || '|' || pa || '|' || cost, E'\n'
                             ORDER BY fn COLLATE "C", pa, cost)), 16)
  FROM public.ordres_couts;
$$;
GRANT EXECUTE ON FUNCTION public.ordres_couts_empreinte_reelle() TO anon, authenticated;

UPDATE public.ordres_couts_empreinte SET empreinte = 'b6de87c8ebb831d2', pose_le = now();

SELECT public.ordres_couts_empreinte_reelle() AS empreinte_reelle,
       (SELECT count(*) FROM public.ordres_couts) AS triples;