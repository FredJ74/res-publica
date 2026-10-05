-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913231259
-- Nom original      : chantier_c_miroirs_chantiers
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-13 23:12:59 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bf9e0cdb2cdf1e8b7d31f350780d9bc0
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
-- CHANTIER C — MIROIR DES CHANTIERS (14 septembre 2026).
-- Le gabarit d'un chantier de construction est entierement determine par son PALIER. Le serveur
-- doit le connaitre pour creer le chantier lui-meme : sinon le navigateur annonce le cout total
-- qu'il veut, donc l'apport minimal de 35 %, donc ce qu'il paie.
-- Genere par .scratch/generer_miroirs_chantiers.py, qui EXECUTE plateau-chantiers.js dans
-- JavaScriptCore -- les formules ne sont pas recopiees en SQL, leur resultat est capture.
CREATE TABLE IF NOT EXISTS public.chantiers_paliers (
  palier text PRIMARY KEY, label text NOT NULL DEFAULT '',
  duree_jours numeric NOT NULL, cout_total numeric NOT NULL,
  cout_materiaux numeric NOT NULL, cout_travail numeric NOT NULL,
  heures_totales numeric NOT NULL, apport_minimal numeric NOT NULL,
  gabarit jsonb NOT NULL);

CREATE TABLE IF NOT EXISTS public.chantiers_besoins_jour (
  position_cycle integer PRIMARY KEY,
  bois numeric NOT NULL, minerai numeric NOT NULL, metal numeric NOT NULL);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['chantiers_paliers','chantiers_besoins_jour'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || ' lecture', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT USING (true)', t || ' lecture', t);
    EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.%I FROM anon, authenticated', t);
    EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated', t);
  END LOOP;
END $$;

DELETE FROM public.chantiers_paliers;
INSERT INTO public.chantiers_paliers (palier, label, duree_jours, cout_total, cout_materiaux, cout_travail, heures_totales, apport_minimal, gabarit) VALUES
  ('building', 'Building', 24, 120000, 36000, 84000, 1200, 42000, '{"arrete": null, "coutMateriaux": 36000, "coutTotal": 120000, "coutTravail": 84000, "dureeJours": 24, "evenements": [], "heuresFaites": 0, "heuresTotales": 1200, "jourDebut": 1, "jourTraite": null, "niveau": "building", "progressionJours": 0, "stockMateriaux": {"bois": 0, "metal": 0, "minerai": 0}, "totalVerse": 0, "travauxPJ": [], "tresorerie": 0, "type": "construction", "ventesMateriauxPJ": []}'::jsonb),
  ('commerce_premium', 'Commerce premium', 18, 90000, 27000, 63000, 900, 31500, '{"arrete": null, "coutMateriaux": 27000, "coutTotal": 90000, "coutTravail": 63000, "dureeJours": 18, "evenements": [], "heuresFaites": 0, "heuresTotales": 900, "jourDebut": 1, "jourTraite": null, "niveau": "commerce_premium", "progressionJours": 0, "stockMateriaux": {"bois": 0, "metal": 0, "minerai": 0}, "totalVerse": 0, "travauxPJ": [], "tresorerie": 0, "type": "construction", "ventesMateriauxPJ": []}'::jsonb),
  ('commerce_standard', 'Commerce standard', 12, 60000, 18000, 42000, 600, 21000, '{"arrete": null, "coutMateriaux": 18000, "coutTotal": 60000, "coutTravail": 42000, "dureeJours": 12, "evenements": [], "heuresFaites": 0, "heuresTotales": 600, "jourDebut": 1, "jourTraite": null, "niveau": "commerce_standard", "progressionJours": 0, "stockMateriaux": {"bois": 0, "metal": 0, "minerai": 0}, "totalVerse": 0, "travauxPJ": [], "tresorerie": 0, "type": "construction", "ventesMateriauxPJ": []}'::jsonb),
  ('hangar', 'Hangar', 6, 30000, 9000, 21000, 300, 10500, '{"arrete": null, "coutMateriaux": 9000, "coutTotal": 30000, "coutTravail": 21000, "dureeJours": 6, "evenements": [], "heuresFaites": 0, "heuresTotales": 300, "jourDebut": 1, "jourTraite": null, "niveau": "hangar", "progressionJours": 0, "stockMateriaux": {"bois": 0, "metal": 0, "minerai": 0}, "totalVerse": 0, "travauxPJ": [], "tresorerie": 0, "type": "construction", "ventesMateriauxPJ": []}'::jsonb);

DELETE FROM public.chantiers_besoins_jour;
INSERT INTO public.chantiers_besoins_jour (position_cycle, bois, minerai, metal) VALUES
  (1, 100, 50, 33), (2, 100, 50, 33), (3, 100, 50, 34);

INSERT INTO public.entreprises_constantes (cle, valeur) VALUES
  ('chantier_taux_horaire', 70), ('cycle_metal', 3), ('seuil_demarrage_pct', 35)
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;
