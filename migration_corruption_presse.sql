-- =====================================================================
-- CORROMPRE UN JOURNALISTE -- COUVERTURE D'UNE AFFAIRE JUDICIAIRE (12 septembre 2026)
-- =====================================================================
-- L'ordre porte sur LA COUVERTURE d'une affaire judiciaire REELLE du jour, avant la cloture
-- editoriale de minuit (Europe/Paris), et non sur le dossier lui-meme, qui reste strictement
-- inchange (jugement, condamnation, detention, traces, archives).
--
-- IDENTITE DE L'AFFAIRE : le Journal identifie deja chaque fait publiable par '<table>:<id>'
-- ('jugements:jug-...' / 'detentions:det-...'), cle stable de la creation a la publication
-- (api/_journal-collecte.js). C'est cette cle que la corruption vise.
--
-- TRACE : elle existe que le journaliste accepte OU refuse, dans corruptions_presse et dans
-- actions_tracables (deja fouillable par « Mener une enquete »). Aucune rumeur n'est creee
-- automatiquement, aucun mandat non plus.
--
-- Appliquee via MCP sous le nom « corruption_presse ».
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.corruptions_presse (
  id            bigserial PRIMARY KEY,
  affaire_ref   text NOT NULL,
  affaire_type  text NOT NULL CHECK (affaire_type IN ('jugements', 'detentions')),
  affaire_pj    text NOT NULL,
  corrupteur    text NOT NULL,
  option        text NOT NULL CHECK (option IN ('etouffer', 'favorable')),
  reussite      boolean NOT NULL,
  jet           smallint,
  taux          smallint,
  pays          text,
  jour_paris    date NOT NULL,
  cree_le       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (affaire_ref, corrupteur)
);
CREATE INDEX IF NOT EXISTS corruptions_presse_affaire ON public.corruptions_presse (affaire_ref) WHERE reussite;
ALTER TABLE public.corruptions_presse ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.corruptions_presse FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.corruptions_presse TO anon, authenticated;
DROP POLICY IF EXISTS corruptions_presse_lecture ON public.corruptions_presse;
CREATE POLICY corruptions_presse_lecture ON public.corruptions_presse FOR SELECT USING (true);

-- Voir la base pour le corps exact de corruption_presse_affaires / corruption_presse_etat /
-- corruption_presse_tenter (migration MCP « corruption_presse ») :
--   - affaires eligibles = celles du jour (Paris) non encore couvertes par une edition publiee,
--     borne calculee sur journal_editions.generated_at comme la collecte du Journal ;
--   - formule 30 + CHA + floor(INF/4) - malus ISN, bornee [5, 85] ;
--   - une seule tentative par affaire et par corrupteur (contrainte UNIQUE) ;
--   - corruption_presse_etat(affaire_ref) renvoie 'etouffee', 'favorable' ou NULL : c'est le seul
--     point a lire par la future collecte editoriale.
