-- =====================================================================
-- FABRIQUER UN SCANDALE -- KOMPROMAT (12 septembre 2026)
-- =====================================================================
-- Contrairement a « Produire une fuite » (fait illegal reel, commanditaire secret), le scandale
-- repose sur une accusation fournie par le joueur, et SON AUTEUR EST PUBLIC. Il n'y a donc plus rien
-- a « detecter » : l'ancienne detection automatique et les mandats automatiques disparaissent.
-- L'illegalite viendra plus tard d'une plainte en diffamation de la victime -- ce chantier ne
-- construit PAS ce mecanisme, il persiste seulement tout ce qu'il faudra pour le rattacher :
-- identifiant, auteur, cible, date, accusation fournie, article publie, reference de publication,
-- type de contenu et statut.
--
-- Appliquee via MCP sous le nom « scandales_presse ». Le corps exact des fonctions est celui
-- applique en base ; ce fichier en est la copie de reference.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.scandales_tentatives (
  auteur     text NOT NULL,
  jour_paris date NOT NULL,
  cible      text,
  accepte    boolean NOT NULL DEFAULT false,
  cree_le    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (auteur, jour_paris)
);
ALTER TABLE public.scandales_tentatives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.scandales_tentatives FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.scandales_tentatives TO anon, authenticated;
DROP POLICY IF EXISTS scandales_tentatives_lecture ON public.scandales_tentatives;
CREATE POLICY scandales_tentatives_lecture ON public.scandales_tentatives FOR SELECT USING (true);

CREATE TABLE IF NOT EXISTS public.scandales_presse (
  id            bigserial PRIMARY KEY,
  auteur        text NOT NULL,
  cible         text NOT NULL,
  pays          text,
  ville         text,
  accusation    text NOT NULL,
  article       text,
  chronique_id  text,
  type_contenu  text NOT NULL DEFAULT 'kompromat',
  statut        text NOT NULL DEFAULT 'accepte',
  plainte_ref   text,
  effet_applique boolean NOT NULL DEFAULT false,
  jour_paris    date NOT NULL,
  cree_le       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS scandales_presse_cible ON public.scandales_presse (cible, cree_le DESC);
CREATE INDEX IF NOT EXISTS scandales_presse_auteur ON public.scandales_presse (auteur, cree_le DESC);
ALTER TABLE public.scandales_presse ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.scandales_presse FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.scandales_presse TO anon, authenticated;
DROP POLICY IF EXISTS scandales_presse_lecture ON public.scandales_presse;
CREATE POLICY scandales_presse_lecture ON public.scandales_presse FOR SELECT USING (true);

-- Voir la base pour le corps exact de scandale_taux / scandale_tenter / scandale_publier
-- (migration MCP « scandales_presse ») : base 35, +15 carriere presse, sinon +10 ministre de
-- l'Information, moins le malus ISN borne, plancher 5 ; tentative quotidienne consommee AVANT le
-- jet ; PA et fonds verifies avant le jet ; publication appliquant POP -15 / INF -15 une seule fois.
