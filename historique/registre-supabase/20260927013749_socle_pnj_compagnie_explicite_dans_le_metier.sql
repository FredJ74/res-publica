-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927013749
-- Nom original      : socle_pnj_compagnie_explicite_dans_le_metier
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 01:37:49 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : a511f0c900ecccabcf0e88b9715dcfee
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
-- LE RATTACHEMENT A LA COMPAGNIE DEVIENT UNE DONNEE, PLUS UNE CONVENTION (27 septembre 2026)
--
-- CE QUI TENAIT LE MODELE. Le lien entre un soldat du socle et sa compagnie n'existait nulle
-- part : il etait DEDUIT du nom, par `m.id LIKE p_compagnie || '-%'`. Cette convention est
-- employee par le miroir, le comparateur, l'outil de copie et les gardes. Elle marche parce que
-- l'identifiant est fabrique comme `<compagnieId>-<matricule>` -- et elle cassera le jour ou un
-- identifiant de compagnie contiendra un tiret suivi de ce qui ressemble a un matricule, ou le
-- jour ou l'on voudra deplacer un soldat d'une compagnie a une autre.
--
-- OU LA COLONNE VA, ET OU ELLE NE VA PAS. Dans `pnj_soldats_metier`. PAS dans `pnj_membres` :
-- une compagnie militaire n'a aucun sens generique, et le socle n'a pas a en connaitre
-- l'existence. Le perimetre generique, lui, reste une chaine opaque -- le socle ne la decoupe
-- jamais pour en extraire une compagnie ; c'est le metier qui detient les deux informations.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS. Elle ne remplace pas encore les `LIKE` existants : ils
-- fonctionnent, et les changer tous en meme temps que le modele d'autorite melangerait deux
-- risques. La colonne est posee, remplie, et SURVEILLEE par le comparateur -- de sorte qu'elle
-- soit deja fiable quand les lectures basculeront dessus.
ALTER TABLE public.pnj_soldats_metier
  ADD COLUMN IF NOT EXISTS compagnie_id text;

UPDATE public.pnj_soldats_metier sm
   SET compagnie_id = c.id
  FROM public.compagnies_militaires c
 WHERE sm.compagnie_id IS NULL AND sm.pnj_id LIKE c.id || '-%';

COMMENT ON COLUMN public.pnj_soldats_metier.compagnie_id IS
  'Compagnie militaire du soldat, explicite. Remplace a terme la deduction par convention de nom '
  '(pnj_id LIKE compagnie || ''-%''). Donnee METIER : elle n''a pas d''equivalent dans le socle.';

-- Une section, quand elle existe, appartient forcement a la compagnie declaree ; un reserviste
-- n'a pas de section. Les deux invariants sont tenus par la base, pas par l'usage.
ALTER TABLE public.pnj_soldats_metier
  DROP CONSTRAINT IF EXISTS pnj_soldats_section_dans_sa_compagnie;
ALTER TABLE public.pnj_soldats_metier ADD CONSTRAINT pnj_soldats_section_dans_sa_compagnie CHECK (
      (en_reserve = true  AND section_id IS NULL)
  OR  (en_reserve = false AND section_id IS NOT NULL
       AND (compagnie_id IS NULL OR section_id LIKE compagnie_id || '-%')));

CREATE INDEX IF NOT EXISTS idx_pnj_soldats_compagnie
  ON public.pnj_soldats_metier(compagnie_id, section_id);