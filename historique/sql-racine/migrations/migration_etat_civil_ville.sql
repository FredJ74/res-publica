-- Migration requise avant que le correctif "ville dans les actes d'etat-civil" ne prenne
-- reellement effet en production.
--
-- Contexte : verifie en direct via l'API REST Supabase (requetes POST/GET de test avant toute
-- modification de code, id explicitement suffixe -QATEST, jamais commitees) -- ni "mariages" ni
-- "etat_civil_deces" n'ont de colonne "city" aujourd'hui (confirme par l'erreur PGRST204
-- "Could not find the 'city' column..." sur les deux tables). Il n'existe aucune colonne
-- equivalente ("ville", "lieu", etc.) a reutiliser : verifie egalement en direct.
--
-- Naissance (nouveau) : AUCUNE colonne n'a ete ajoutee a "personnages" pour cela -- cette table
-- est relue et resauvegardee en integralite (sbSavePersonnage) a CHAQUE action de CHAQUE joueur
-- (pas seulement a la creation), en PATCH REST. Une colonne manquante y ferait echouer TOUTES
-- les sauvegardes de TOUS les joueurs tant que cette migration n'a pas ete appliquee -- risque
-- juge inacceptable pour ce correctif. A la place, la ville de naissance est enregistree UNE
-- SEULE FOIS a la creation du personnage, dans une nouvelle table dediee, exactement sur le
-- modele deja existant de "etat_civil_deces" (ecriture rare, insert-only, deja tolerante a
-- l'echec via .catch(() => {})).
--
-- La cle anon (utilisee par le client via l'API REST) n'a pas les privileges DDL necessaires
-- pour executer ceci elle-meme (deja le cas pour tous les changements de schema de ce projet --
-- voir migration_origin_school_freepts.sql -- toujours executes manuellement par Fred dans
-- l'editeur SQL Supabase). Sans cette migration :
--   - les mariages/deces continuent de fonctionner exactement comme avant (le .catch() existant
--     avale l'echec de l'ecriture de la ville, sans bloquer la ceremonie/suppression elle-meme) ;
--   - la nouvelle naissance echoue silencieusement a s'enregistrer (meme protection .catch()) ;
--   - aucune ecriture "personnages" n'est affectee : cette table n'est pas touchee par cette
--     migration ni par le code associe.
-- Les actes deja existants sans ville restent lisibles normalement (repli d'affichage neutre,
-- cote code, sans erreur).

CREATE TABLE IF NOT EXISTS etat_civil_naissances (
  id text PRIMARY KEY,
  nom text NOT NULL,
  country text NOT NULL,
  city text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE mariages ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE etat_civil_deces ADD COLUMN IF NOT EXISTS city text;
