-- =====================================================================================
-- PHASE 2 — SECURITE : fermeture de engagements_militaires — 18 septembre 2026
--
-- ORDRE RESPECTE, et il est la clef : les producteurs legitimes (filiere officier ET filiere
-- soldat) ont ete migres vers des RPC attestees ET DEPLOYES avant cette fermeture. Poser les
-- droits d'abord aurait fait echouer les candidatures en silence -- la lecon de la passe 3.
--
-- La table et les RPC productrices appartiennent a postgres, relforcerowsecurity est faux : le
-- proprietaire contourne la RLS, donc les SECURITY DEFINER continuent d'ecrire. Verifie avant.
--
-- LECTURE OUVERTE, ECRITURE FERMEE : un Commandant et un Capitaine doivent voir les candidatures
-- qui leur sont adressees. Seules les ecritures directes disparaissent.
--
-- UNE PANNE REELLE CORRIGEE AU PASSAGE. confirmerAffectationSection ecrivait personnages.poste DU
-- CANDIDAT par sbUpdate, ce que la RLS refuse depuis le chantier B -- et sbUpdate ne leve pas. Le
-- candidat n'obtenait donc JAMAIS son poste de Lieutenant : la « promotion fantome » que le
-- commentaire du code disait avoir corrigee en aout etait revenue, silencieusement.
--
-- BANC HOSTILE 9/9, avec vrais SET ROLE et claims :
--   anon INSERT (faux candidat)            -> permission denied
--   authenticated INSERT (faux candidat)   -> permission denied
--   candidature par la RPC                 -> ACCEPTE, statut attente_commandant
--   authenticated UPDATE de son statut     -> permission denied
--   Capitaine saute l'etape du Commandant  -> 'etape_invalide' (l'ETAT PRECEDENT est verifie)
--   Capitaine usurpe le Commandant         -> 'autorite_insuffisante'
--   Commandant affecte a la compagnie      -> ACCEPTE, attente_capitaine
--   Capitaine installe le Lieutenant       -> ACCEPTE, ET LE POSTE EST REELLEMENT POSE
--   rejeu de la meme affectation           -> 'etape_invalide'
-- =====================================================================================
ALTER TABLE public.engagements_militaires ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS engagements_militaires_lecture ON public.engagements_militaires;
CREATE POLICY engagements_militaires_lecture ON public.engagements_militaires
  FOR SELECT TO authenticated USING (true);
REVOKE ALL ON TABLE public.engagements_militaires FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.engagements_militaires FROM authenticated;
GRANT SELECT ON TABLE public.engagements_militaires TO authenticated;
