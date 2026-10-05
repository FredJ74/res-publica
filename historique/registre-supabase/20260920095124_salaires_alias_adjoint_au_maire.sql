-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260920095124
-- Nom original      : salaires_alias_adjoint_au_maire
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-20 09:51:24 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0923dd61a84731b3fc71ab48597a94ca
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
-- DEFAUT DETERMINISTE TROUVE AU CALCUL DES DOTATIONS.
-- Le meme poste porte DEUX identifiants selon la source :
--   data.js SALAIRES ............. 'adj_maire'     (500 FR)
--   postes_nommes_regles ......... 'maire_adjoint' (nomme par le maire, scope ville)
-- La fiche d'un adjoint porte l'identifiant atteste, 'maire_adjoint'. Le bareme
-- etant range sous 'adj_maire', son salaire ne se serait JAMAIS resolu : il
-- serait retombe sur le revenu universel de 150 FR au lieu de 500 FR.
-- On declare donc le bareme sous les deux cles, sans trancher laquelle est
-- canonique -- ce choix-la revient au game design, et l'unifier ici casserait
-- l'un des deux appelants.
INSERT INTO public.salaires_civils_declares (cle, categorie, montant)
VALUES ('maire_adjoint', 'poste', 500)
ON CONFLICT (cle) DO UPDATE SET categorie=EXCLUDED.categorie, montant=EXCLUDED.montant;

INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note) VALUES
  ('adj_maire', '{pays}_mairie_{ville}', true, 'alias de maire_adjoint — les deux identifiants coexistent dans le depot')
ON CONFLICT (poste_id) DO UPDATE
  SET motif=EXCLUDED.motif, par_ville=EXCLUDED.par_ville, note=EXCLUDED.note;