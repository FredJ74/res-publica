-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919170130
-- Nom original      : securite_actions_tracables
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:01:30 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 57a8108eb5250a460cf29966b10840e1
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
-- LOT 0 du chantier contre-espionnage (19 septembre 2026).
-- actions_tracables devient une PREUVE pouvant conduire a l'arrestation d'un agent
-- etranger. Elle etait jusqu'ici en `allow_all` : lecture, ecriture, modification et
-- suppression ouvertes a TOUS, y compris a `anon` (visiteur non authentifie).
--
-- Banc hostile AVANT, en transaction annulee, en role authenticated (claims d'Arnie) :
--   insertion d'une trace au nom d'un TIERS sans motif ............. ACCEPTE
--   suppression de la trace d'un TIERS ............................. ACCEPTE
--   suppression d'une trace DEJA DECOUVERTE (preuve instruite) ..... ACCEPTE
-- N'importe qui pouvait donc forger une accusation ou effacer une preuve.
--
-- INVENTAIRE COMPLET DES PRODUCTEURS LEGITIMES (verifie avant d'ecrire cette migration,
-- pour ne pas faire un REVOKE aveugle) :
--   * 24 appels via tracerActionPourRumeur(), tous `auteur = state.char.name` ;
--   * 4 INSERT directs sbTracerAction, tous `auteur = state.char.name`
--     (subtilisation_explosif x2, vol_materiel_chantier x2) ;
--   * 1 INSERT direct EXCEPTIONNEL : condamnation_torture
--     (plateau-justice-economie.js:2370) ecrit `auteur: affaire.cible` -- c'est le JUGE
--     qui trace le CONDAMNE, pour permettre le cumul des peines. Une regle
--     "auteur = moi" seule aurait casse cette mecanique ;
--   * INSERT serveur : corruption_presse_tenter ;
--   * UPDATE serveur : plainte_instruire_interne (pose `decouvert`) ;
--   * DELETE client : la confession seule, sur sa propre trace non decouverte
--     (plateau-divers.js:890) ;
--   * AUCUN UPDATE client (verifie : zero occurrence de sbUpdate sur cette table).
--
-- Les deux ecrivains serveur sont SECURITY DEFINER appartenant a `postgres`, proprietaire
-- de la table, et relforcerowsecurity est false : ils contournent donc RLS par construction.
-- Verifie avant migration.
--
-- SELECT EST VOLONTAIREMENT LAISSE INCHANGE (ouvert a tous). Decider qui a le droit de LIRE
-- une trace, c'est trancher le brouillard d'information du jeu : cela releve du game design
-- et n'est pas l'objet de ce lot.

ALTER TABLE public.actions_tracables ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_all_actions_tracables" ON public.actions_tracables;

-- anon n'ecrit plus rien. authenticated perd UPDATE : aucun parcours client n'en fait,
-- et c'est ce qui empeche un joueur de marquer une trace "decouverte" ou de la reecrire.
REVOKE INSERT, UPDATE, DELETE ON public.actions_tracables FROM PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON public.actions_tracables FROM anon;
REVOKE UPDATE                  ON public.actions_tracables FROM authenticated;
GRANT  SELECT, INSERT, DELETE  ON public.actions_tracables TO authenticated;

-- Lecture : STRICTEMENT identique a avant (USING true, anon compris).
CREATE POLICY "traces lecture" ON public.actions_tracables
  FOR SELECT TO authenticated, anon
  USING (true);

-- Ecriture : sa propre trace, PLUS l'exception etroite du juge pour la condamnation
-- pour torture. Le poste est atteste par trg_personnages_attester_poste : on ne peut
-- pas se declarer juge.
CREATE POLICY "traces creation acteur" ON public.actions_tracables
  FOR INSERT TO authenticated
  WITH CHECK (
    auteur = public.mon_personnage()
    OR (
      type_action = 'condamnation_torture'
      AND EXISTS (SELECT 1 FROM public.acteur_poste_courant() a WHERE a.poste_id = 'juge')
    )
  );

-- Suppression : exactement le perimetre de la confession -- sa propre trace, et
-- seulement tant qu'elle n'a pas ete instruite. Une preuve decouverte devient
-- ineffacable.
CREATE POLICY "traces confession" ON public.actions_tracables
  FOR DELETE TO authenticated
  USING (auteur = public.mon_personnage() AND decouvert IS NOT TRUE);
