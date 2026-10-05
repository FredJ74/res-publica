-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916134131
-- Nom original      : clubs_football_miroir_serveur
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-16 13:41:31 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : f936026cf2a2ee83c2cc92e6bb8ecb71
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
-- MIROIR SERVEUR DES CLUBS (16 septembre 2026).
--
-- Le serveur doit ecrire lui-meme les communiques officiels de la Ligue -- « X est sacre
-- champion », « finale au stade de Y ». Les noms n'existaient qu'en memoire du navigateur
-- (CLUBS_SPORTIFS, data.js) : les accepter du client reviendrait a lui laisser signer le
-- communique, ce que ce chantier ferme.
--
-- GENERE, JAMAIS SAISI : .scratch/generer_clubs_football.py charge le vrai data.js dans
-- JavaScriptCore et capture les clubs tels que le jeu les lit. Empreinte 2c2f8d0fe578a8bb,
-- 12 clubs. A REJOUER si un nom change ou si un club entre/sort -- le banc compare l'empreinte.
--
-- Aucun nom n'est invente ni traduit : ce sont exactement ceux du jeu.

CREATE TABLE IF NOT EXISTS public.clubs_football (
  id    text PRIMARY KEY,
  nom   text NOT NULL,
  pays  text NOT NULL,
  ville text NOT NULL
);

INSERT INTO public.clubs_football (id, nom, pays, ville) VALUES
  ('olympique-luthecia', 'Olympique de Luthécia', 'republic', 'capitale'),
  ('brise-mariannaise', 'La Brise Mariannaise', 'republic', 'ville_a'),
  ('cheminote-montrouge', 'Union Cheminote de Montrouge', 'republic', 'ville_b'),
  ('rojos-cartel', 'Estudiantes de la Ciudad', 'narco', 'capitale'),
  ('fronterizos-unidos', 'Atlético Puerto Negro', 'narco', 'ville_a'),
  ('jaguares-selva', 'Independiente de Villa Sangre', 'narco', 'ville_b'),
  ('dynamo-novomirsk', 'Dynamo Novomirsk', 'soviet', 'capitale'),
  ('spartak-sibirsk', 'Partizan de Starovka', 'soviet', 'ville_a'),
  ('kolkhoze-ouvrier', 'Étoile Rouge de Krasnov', 'soviet', 'ville_b'),
  ('nadi-al-madina', 'Shabab Al Madina', 'khalija', 'capitale'),
  ('al-baraka-fc', 'Oasis City FC', 'khalija', 'ville_a'),
  ('sharq-al-nour', 'Al-Petrol United FC', 'khalija', 'ville_b')
ON CONFLICT (id) DO UPDATE SET nom = EXCLUDED.nom, pays = EXCLUDED.pays, ville = EXCLUDED.ville;

-- Lecture publique (les noms sont deja affiches partout dans le jeu), ecriture a personne.
ALTER TABLE public.clubs_football ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS clubs_football_lecture ON public.clubs_football;
CREATE POLICY clubs_football_lecture ON public.clubs_football
  FOR SELECT TO anon, authenticated USING (true);
REVOKE INSERT, UPDATE, DELETE ON public.clubs_football FROM PUBLIC, anon, authenticated;