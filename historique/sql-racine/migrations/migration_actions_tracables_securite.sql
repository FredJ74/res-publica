-- =====================================================================
-- TRACE — LOT 0 du chantier contre-espionnage (19 septembre 2026)
--
-- CE FICHIER N'EST QU'UNE TRACE. Il n'est pas execute par le jeu : la
-- migration a deja ete appliquee en production sous le nom
--   securite_actions_tracables
-- =====================================================================
--
-- POURQUOI MAINTENANT. actions_tracables devient une PREUVE : c'est elle qui
-- portera la trace laissee par un agent etranger, et c'est l'enquete sur cette
-- trace qui conduira a son demasquage puis a son arrestation. Elle etait en
-- `allow_all` -- lecture, ecriture, modification et suppression ouvertes a
-- TOUS, `anon` compris.
--
-- BANC HOSTILE AVANT, en transaction annulee, role authenticated (claims d'Arnie) :
--   insertion d'une trace au nom d'un TIERS sans motif ............ ACCEPTE
--   suppression de la trace d'un TIERS ........................... ACCEPTE
--   suppression d'une trace DEJA DECOUVERTE (preuve instruite) .... ACCEPTE
--
-- INVENTAIRE COMPLET DES PRODUCTEURS, etabli AVANT d'ecrire la migration
-- (consigne explicite : pas de REVOKE aveugle) :
--   * 24 appels via tracerActionPourRumeur(), tous `auteur = state.char.name` ;
--   * 4 INSERT directs sbTracerAction, tous `auteur = state.char.name`
--     (subtilisation_explosif x2, vol_materiel_chantier x2) ;
--   * 1 INSERT direct EXCEPTIONNEL -- condamnation_torture
--     (plateau-justice-economie.js:2370) ecrit `auteur: affaire.cible` : c'est
--     le JUGE qui trace le CONDAMNE, pour le cumul des peines. Une regle
--     "auteur = moi" seule aurait casse cette mecanique ;
--   * INSERT serveur : corruption_presse_tenter ;
--   * UPDATE serveur : plainte_instruire_interne (pose `decouvert`) ;
--   * DELETE client : la confession seule, sur sa propre trace non decouverte ;
--   * AUCUN UPDATE client (verifie : zero sbUpdate sur cette table).
--
-- Les deux ecrivains serveur sont SECURITY DEFINER appartenant a `postgres`,
-- proprietaire de la table, avec relforcerowsecurity = false : ils contournent
-- RLS par construction. Verifie avant migration, puis CONFIRME par banc apres
-- (commissaire_enqueter a bien marque `decouvert = true`).
--
-- BANC APRES, en transaction annulee :
--   trace de soi ................................ ACCEPTE (1)
--   condamnation_torture par un JUGE atteste .... ACCEPTE (1)
--   forge au nom d'autrui ....................... REFUSE 42501
--   condamnation_torture sans etre juge ......... REFUSE 42501
--   UPDATE client ............................... REFUSE 42501
--   confession sur sa trace non decouverte ...... supprimee (0 restante)
--   suppression de la trace d'autrui ............ bloquee (1 restante)
--   suppression d'une preuve decouverte ......... bloquee (1 restante)
--   anon INSERT / UPDATE / DELETE ............... REFUSE 42501
--   anon SELECT ................................. inchange
--   commissaire_enqueter (ecrivain serveur) ..... decouvert = true
-- Zero residu : tout en BEGIN/ROLLBACK, verifie (0 trace, poste d'Arnie rendu).
--
-- SELECT EST VOLONTAIREMENT LAISSE INCHANGE, anon compris. Decider qui a le
-- droit de LIRE une trace, c'est trancher le brouillard d'information du jeu :
-- game design, hors perimetre de ce lot, consigne explicite.

ALTER TABLE public.actions_tracables ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_all_actions_tracables" ON public.actions_tracables;

REVOKE INSERT, UPDATE, DELETE ON public.actions_tracables FROM PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON public.actions_tracables FROM anon;
REVOKE UPDATE                  ON public.actions_tracables FROM authenticated;
GRANT  SELECT, INSERT, DELETE  ON public.actions_tracables TO authenticated;

-- Lecture : STRICTEMENT identique a avant.
CREATE POLICY "traces lecture" ON public.actions_tracables
  FOR SELECT TO authenticated, anon
  USING (true);

-- Ecriture : sa propre trace, PLUS l'exception etroite du juge. Le poste est
-- atteste par trg_personnages_attester_poste : on ne peut pas se declarer juge.
CREATE POLICY "traces creation acteur" ON public.actions_tracables
  FOR INSERT TO authenticated
  WITH CHECK (
    auteur = public.mon_personnage()
    OR (
      type_action = 'condamnation_torture'
      AND EXISTS (SELECT 1 FROM public.acteur_poste_courant() a WHERE a.poste_id = 'juge')
    )
  );

-- Suppression : exactement le perimetre de la confession. Une preuve deja
-- instruite devient ineffacable.
CREATE POLICY "traces confession" ON public.actions_tracables
  FOR DELETE TO authenticated
  USING (auteur = public.mon_personnage() AND decouvert IS NOT TRUE);
