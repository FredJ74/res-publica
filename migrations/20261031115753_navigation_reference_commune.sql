-- #219 : référence des mêmes bâtiments/pièces, pas un second moteur.
-- Préparé uniquement, avec les migrations de groupes et le contrat de navigation.
CREATE TABLE IF NOT EXISTS public.navigation_lieux_regles(
 pays text NOT NULL,ville text NOT NULL,batiment text NOT NULL,pieces jsonb NOT NULL,
 ferme boolean NOT NULL DEFAULT false,membership text,
 PRIMARY KEY(pays,ville,batiment),CHECK(jsonb_typeof(pieces)='array')
);
ALTER TABLE public.navigation_lieux_regles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.navigation_lieux_regles FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON TABLE public.navigation_lieux_regles IS 'Déclarations de WORLD/BUILDINGS : pays, villes, pièces existantes. Référence technique générée, ni positions ni droits de joueur.';
