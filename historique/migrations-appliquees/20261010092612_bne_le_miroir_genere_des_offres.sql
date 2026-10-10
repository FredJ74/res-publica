-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010092612 (UTC), nom `bne_le_miroir_genere_des_offres`.
-- Le registre passe de 608 a 609 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 8e508a0f5c213ecfe55cf4d2d31505be, 5061 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHANTIER 5, CHAINE 20 : LE MIROIR DES OFFRES DU BNE
--
-- Le nombre de places d'une offre ne vivait qu'en memoire du navigateur, et le plafond etait
-- verifie cote client sur une lecture perimee : deux joueurs pouvaient prendre la meme derniere
-- place. La table `offres_emploi_bne` est le miroir serveur, GENERE depuis le vrai data.js par
-- outils/generateurs/generer_offres_emploi_bne.py (empreinte 2cf0edcba2fa05fc, 7 offres), en
-- lecture seule pour les clients -- seules les valeurs qui bornent une decision serveur y sont.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 20 -- LE MIROIR DES OFFRES DU BNE (10 octobre 2026)
--
-- CE QUI SE PASSAIT. Les quatre chemins du BNE lisaient le blob `offres` ENTIER depuis
-- `batiments_etat`, en modifiaient une copie, et reecrivaient le blob entier, sans jamais lire le
-- retour de `sbSetEtatBNE`. Or ce blob est PARTAGE : il porte les affectations de TOUS les
-- joueurs. Deux defauts, et le second est le plus couteux.
--   1. Deux joueurs qui prennent un poste en meme temps : le second ecrase le premier, qui se
--      croit employe et ne l'est plus.
--   2. LE PLAFOND DE PLACES ETAIT VERIFIE SUR UNE LECTURE PERIMEE -- `placesPrises >=
--      offre.places` teste cote client sur un blob lu avant l'ecriture : deux joueurs pouvaient
--      prendre LA MEME DERNIERE PLACE. Et le succes etait annonce sans condition.
--
-- POURQUOI CE MIROIR EST INDISPENSABLE. Le nombre de places ne vivait qu'en memoire du navigateur
-- (OFFRES_EMPLOI_BNE, data.js). Le transmettre a la porte aurait ete exactement le defaut ferme le
-- meme jour sur l'approvisionnement de chantier : un parametre que le client dicte et qui BORNE
-- une autorisation est une faille, meme derriere une RPC.
--
-- IL EST GENERE, PAS RECOPIE : outils/generateurs/generer_offres_emploi_bne.py charge le VRAI
-- data.js dans JavaScriptCore. Empreinte 2cf0edcba2fa05fc sur les sept offres. Le LIBELLE n'y
-- figure pas : il part en clair dans les messages du jeu, que le client compose -- seules les
-- valeurs qui BORNENT une decision serveur sont miroitees.
--
-- ET LE GENERATEUR A RENDU SERVICE DES SON PREMIER PASSAGE : il a REFUSE de semer parce qu'il ne
-- connaissait pas la portee 'internationale' de `hotesse_ambassade`. Un garde-fou qui s'arrete
-- vaut mieux qu'un referentiel tronque en silence ; la liste close a ete corrigee sur la mesure.

CREATE TABLE IF NOT EXISTS public.offres_emploi_bne (
  id       text    PRIMARY KEY,
  job      text    NOT NULL,
  portee   text    NOT NULL,
  ville    text,
  salaire  integer NOT NULL,
  places   integer NOT NULL
);

COMMENT ON TABLE public.offres_emploi_bne IS
  'Miroir SERVEUR de OFFRES_EMPLOI_BNE (data.js), genere par '
  'outils/generateurs/generer_offres_emploi_bne.py. Il existe pour une seule raison : `places` '
  'BORNE une autorisation concurrente -- la derniere place d''une offre -- et un plafond transmis '
  'par le client n''est pas un plafond. Le libelle n''y figure pas : il ne borne rien.';

ALTER TABLE public.offres_emploi_bne ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS offres_emploi_bne_lecture ON public.offres_emploi_bne;
CREATE POLICY offres_emploi_bne_lecture ON public.offres_emploi_bne
  FOR SELECT TO anon, authenticated USING (true);

REVOKE ALL ON TABLE public.offres_emploi_bne FROM PUBLIC;
REVOKE ALL ON TABLE public.offres_emploi_bne FROM anon, authenticated;
GRANT SELECT ON TABLE public.offres_emploi_bne TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN
  ON TABLE public.offres_emploi_bne TO postgres, service_role;

INSERT INTO public.offres_emploi_bne (id, job, portee, ville, salaire, places) VALUES
  ('banquier_national', 'banquier', 'nationale', NULL, 0, 1),
  ('commercant_national', 'commercant', 'nationale', NULL, 0, 3),
  ('docker_psm', 'docker', 'locale', 'ville_a', 220, 2),
  ('hotelier_montrouge', 'hotelier', 'locale', 'ville_b', 250, 1),
  ('hotesse_ambassade', 'hotesse', 'internationale', NULL, 0, 2),
  ('secretaire_nationale', 'secretaire', 'nationale', NULL, 0, 3),
  ('serveur_luthecia', 'serveur', 'locale', 'capitale', 200, 2)
ON CONFLICT (id) DO UPDATE
  SET job = excluded.job, portee = excluded.portee, ville = excluded.ville,
      salaire = excluded.salaire, places = excluded.places;

DO $$
DECLARE v_n integer;
BEGIN
  SELECT count(*) INTO v_n FROM public.offres_emploi_bne;
  IF v_n <> 7 THEN RAISE EXCEPTION 'P1 : % offre(s) au lieu de 7', v_n; END IF;
  IF (SELECT places FROM public.offres_emploi_bne WHERE id='hotelier_montrouge') <> 1
     OR (SELECT places FROM public.offres_emploi_bne WHERE id='serveur_luthecia') <> 2
     OR (SELECT salaire FROM public.offres_emploi_bne WHERE id='docker_psm') <> 220 THEN
    RAISE EXCEPTION 'P2 : les valeurs semees ne sont pas celles de data.js'; END IF;
  IF EXISTS (SELECT 1 FROM public.offres_emploi_bne WHERE places IS NULL OR places < 0) THEN
    RAISE EXCEPTION 'P3 : une offre porte un plafond invalide'; END IF;
  IF EXISTS (SELECT 1 FROM information_schema.role_table_grants
              WHERE table_schema='public' AND table_name='offres_emploi_bne'
                AND grantee IN ('anon','authenticated') AND privilege_type <> 'SELECT') THEN
    RAISE EXCEPTION 'P4 : un role client peut ecrire le miroir'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                  WHERE n.nspname='public' AND c.relname='offres_emploi_bne' AND c.relrowsecurity) THEN
    RAISE EXCEPTION 'P5 : le miroir est sans RLS'; END IF;
  RAISE NOTICE 'offres_emploi_bne : 5 preuves conformes, 7 offres semees.';
END $$;
