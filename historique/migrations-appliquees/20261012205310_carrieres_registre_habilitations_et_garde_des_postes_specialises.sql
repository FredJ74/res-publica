-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012205310 (UTC), nom
-- `carrieres_registre_habilitations_et_garde_des_postes_specialises`.
-- Le registre passe de 696 a 697 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 4d4f701c802f41283abe7ef85d453640, 20319 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA CARRIERE EST UNE FAMILLE PROFESSIONNELLE, ET ELLE OUVRE OU FERME DES FONCTIONS
--
-- CE QUI N'EXISTAIT PAS, ET C'EST LE FOND DU MALENTENDU. `personnages_donnees.career` portait un
-- identifiant de carriere depuis la creation du personnage, et AUCUNE porte serveur ne le lisait
-- jamais. Les seules consequences professionnelles vivaient cote navigateur. Un personnage etait
-- donc un couteau suisse professionnel : rien n'empechait un officier d'etre nomme juge.
--
-- LE MODELE EST BORNE A DEUX, ET LA BORNE EST UNE CLE PRIMAIRE. Une carriere initiale, plus au
-- maximum une seconde acquise ensuite. Jamais trois -- `carrieres_acquises` porte le personnage
-- en cle primaire, donc une troisieme ne peut pas s'ecrire, meme si une porte future oubliait de
-- verifier.
--
-- LES HABILITATIONS SONT DECLAREES, PAS DEDUITES. Trois registres : ce qui existe, quelle famille
-- l'ouvre, quel poste l'exige. JUSTICE ouvre juge, procureur, commissaire et avocat (arbitrage
-- valide). ARMEE ouvre le commandement -- la correspondance n'est pas inventee ici, elle est
-- ecrite dans `aQualificationMilitaire` depuis le chantier militaire, et ce lot la rend
-- SERVEUR-AUTORITAIRE. `doctor` et `press` reprennent les deux lignes de
-- `QUALIFICATIONS_PAR_CARRIERE`. Rien d'autre : deduire « menuiserie » de « Monde ouvrier »
-- serait trancher un arbitrage qui n'a pas ete rendu.
--
-- LA GARDE EST POSEE A UN SEUL ENDROIT, et c'est ce qui la rend sure : `poste_attribuer_interne`
-- est le goulot des TROIS chemins d'acces a un poste nomme. Un quatrieme en heritera.
-- AUCUN TITULAIRE EN PLACE N'EST REVOQUE : la garde porte sur les attributions a venir.
--
-- `justice_barreau_qualifications` EST SUPPRIMEE. C'etait l'abstraction d'attente posee vide le
-- 12 octobre au soir faute d'arbitrage. L'arbitrage est rendu.
--
-- PREUVES STRUCTURELLES -- 14.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LA CARRIERE EST UNE FAMILLE PROFESSIONNELLE, ET ELLE OUVRE OU FERME DES FONCTIONS
-- 12 octobre 2026, nuit -- lot 2
--
-- CE QUI N'EXISTAIT PAS, ET C'EST LE FOND DU MALENTENDU. `personnages_donnees.career` portait un
-- identifiant de carriere depuis la creation du personnage, et AUCUNE porte serveur ne le lisait
-- jamais. Les seules consequences professionnelles vivaient cote navigateur -- `aQualificationMilitaire`
-- dans plateau-gouvernement.js, `QUALIFICATIONS_PAR_CARRIERE` dans plateau-commerce.js, le forum
-- `presse` dans forum.js -- c'est-a-dire nulle part ou cela compte. Un personnage etait donc un
-- couteau suisse professionnel : rien n'empechait un officier d'etre nomme juge.
--
-- LE MODELE, ET IL EST BORNE A DEUX. Un personnage a UNE carriere initiale, choisie a la creation
-- et jamais modifiable, PLUS AU MAXIMUM UNE seconde carriere acquise ensuite. Jamais trois. Cette
-- borne n'est pas une regle ecrite dans un corps de fonction : c'est la CLE PRIMAIRE de
-- `carrieres_acquises`, qui porte le personnage et lui seul. Une troisieme carriere ne peut donc
-- pas exister, meme si une porte future oubliait de verifier.
--
-- LES HABILITATIONS SONT LA TRADUCTION, ET ELLES SONT DECLAREES, PAS DEDUITES. Trois registres :
-- `habilitations` dit ce qui existe, `habilitations_carrieres` dit quelle famille l'ouvre,
-- `habilitations_postes` dit quel poste institutionnel l'exige. Ajouter une correspondance est
-- une LIGNE, pas une migration de code.
--
-- CE QUI EST DECLARE, ET POURQUOI SEULEMENT CELA.
--   . JUSTICE (`magistrat`) ouvre juge, procureur, commissaire et avocat -- arbitrage valide.
--   . ARMEE (`officer`) ouvre `militaire`, et le poste de Commandant l'exige : la correspondance
--     n'est pas inventee ici, elle est deja ecrite dans `aQualificationMilitaire` depuis le
--     chantier militaire -- ce lot la rend SERVEUR-AUTORITAIRE au lieu de la laisser au navigateur.
--   . `doctor` ouvre `medecine` et `press` ouvre `communication` : ce sont exactement les deux
--     lignes de `QUALIFICATIONS_PAR_CARRIERE`, et leurs intitules NOMMENT eux-memes le domaine.
--     Aucun poste institutionnel ne les exige aujourd'hui ; elles sont declarees pour que la
--     matrice soit complete, et elles ne ferment rien de plus qu'aujourd'hui.
-- Rien d'autre n'est declare. Deduire « menuiserie » de « Monde ouvrier » ou « armurerie » de
-- « Officier superieur » serait trancher un arbitrage qui n'a pas ete rendu.
--
-- LA GARDE EST POSEE A UN SEUL ENDROIT, et c'est ce qui la rend sure : `poste_attribuer_interne`
-- est le goulot par lequel passent les TROIS chemins d'acces a un poste nomme -- acceptation
-- d'une nomination, candidature spontanee quand l'autorite est PNJ, et attribution par l'autorite.
-- Un quatrieme chemin herite de la garde sans qu'on y pense.
--
-- CE QUI N'EST PAS TOUCHE : aucun titulaire en place n'est revoque. La garde porte sur les
-- attributions A VENIR. Au jour de cette migration un seul poste nomme est tenu par un joueur
-- (`min_def`), et un ministere n'exige aucune habilitation -- c'est une fonction politique.
--
-- `justice_barreau_qualifications` EST SUPPRIMEE. Elle etait l'abstraction d'attente du 12 octobre
-- au soir, posee vide parce que l'arbitrage manquait. L'arbitrage est rendu : la qualification
-- pertinente est la CARRIERE JUSTICE. Garder une table vide qui ne dit plus rien serait garder un
-- mensonge en place parce qu'il existe.
--
-- PREUVES STRUCTURELLES -- 14.

-- ============================================================================================
-- 1. LE REGISTRE DES CARRIERES -- miroir des 10 familles de data.js
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.carrieres (
  id      text PRIMARY KEY,
  libelle text NOT NULL,
  ordre   integer NOT NULL
);
REVOKE ALL ON TABLE public.carrieres FROM PUBLIC, anon, authenticated;
ALTER TABLE public.carrieres ENABLE ROW LEVEL SECURITY;

INSERT INTO public.carrieres (id, libelle, ordre) VALUES
  ('officer',    'Armée — Officier supérieur / Mercenaire',                       1),
  ('business',   'Affaires — Homme d''affaires / Lobbyiste',                      2),
  ('magistrat',  'Justice — Magistrat / Avocat',                                  3),
  ('press',      'Médias & Communication — Grand journaliste / Influenceur',      4),
  ('clergy',     'Religion — Chef de culte',                                      5),
  ('doctor',     'Professions intellectuelles — Médecin / Universitaire',         6),
  ('worker',     'Monde ouvrier — Ouvrier / Syndicaliste',                        7),
  ('intel',      'Renseignement — Agent des services',                            8),
  ('criminal_c', 'Crime organisé — Criminel organisé',                            9),
  ('escort',     'Prostitution — Prostitué(e)',                                  10)
ON CONFLICT (id) DO UPDATE SET libelle = EXCLUDED.libelle, ordre = EXCLUDED.ordre;

-- ============================================================================================
-- 2. LES HABILITATIONS, ET CE QUI LES OUVRE
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.habilitations (
  id      text PRIMARY KEY,
  libelle text NOT NULL,
  note    text
);
REVOKE ALL ON TABLE public.habilitations FROM PUBLIC, anon, authenticated;
ALTER TABLE public.habilitations ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.habilitations_carrieres (
  habilitation text NOT NULL REFERENCES public.habilitations(id),
  carriere     text NOT NULL REFERENCES public.carrieres(id),
  PRIMARY KEY (habilitation, carriere)
);
REVOKE ALL ON TABLE public.habilitations_carrieres FROM PUBLIC, anon, authenticated;
ALTER TABLE public.habilitations_carrieres ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.habilitations_postes (
  poste_id     text PRIMARY KEY,
  habilitation text NOT NULL REFERENCES public.habilitations(id)
);
REVOKE ALL ON TABLE public.habilitations_postes FROM PUBLIC, anon, authenticated;
ALTER TABLE public.habilitations_postes ENABLE ROW LEVEL SECURITY;

INSERT INTO public.habilitations (id, libelle, note) VALUES
  ('avocat',        'Exercer comme avocat',
   'Exiger la carriere JUSTICE : arbitrage du 12 octobre 2026. Remplace le registre vide justice_barreau_qualifications.'),
  ('juge',          'Sieger comme juge',            'Arbitrage du 12 octobre 2026.'),
  ('procureur',     'Diriger le parquet',           'Arbitrage du 12 octobre 2026.'),
  ('commissaire',   'Diriger un commissariat',      'Arbitrage du 12 octobre 2026.'),
  ('militaire',     'Commander une troupe',
   'Correspondance deja ecrite cote navigateur par aQualificationMilitaire depuis le chantier militaire ; ce lot la rend serveur-autoritaire.'),
  ('medecine',      'Exercer la medecine',
   'Deja declaree par QUALIFICATIONS_PAR_CARRIERE ; aucun poste institutionnel ne l''exige a ce jour.'),
  ('communication', 'Exercer dans la communication',
   'Deja declaree par QUALIFICATIONS_PAR_CARRIERE ; aucun poste institutionnel ne l''exige a ce jour.')
ON CONFLICT (id) DO UPDATE SET libelle = EXCLUDED.libelle, note = EXCLUDED.note;

INSERT INTO public.habilitations_carrieres (habilitation, carriere) VALUES
  ('avocat', 'magistrat'), ('juge', 'magistrat'),
  ('procureur', 'magistrat'), ('commissaire', 'magistrat'),
  ('militaire', 'officer'),
  ('medecine', 'doctor'), ('communication', 'press')
ON CONFLICT DO NOTHING;

INSERT INTO public.habilitations_postes (poste_id, habilitation) VALUES
  ('juge', 'juge'), ('procureur', 'procureur'),
  ('commissaire', 'commissaire'), ('commandant', 'militaire')
ON CONFLICT (poste_id) DO UPDATE SET habilitation = EXCLUDED.habilitation;

-- ============================================================================================
-- 3. LA SECONDE CARRIERE -- UNE LIGNE PAR PERSONNAGE, AU PLUS
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.carrieres_acquises (
  personnage     text PRIMARY KEY,
  carriere       text NOT NULL REFERENCES public.carrieres(id),
  source         text NOT NULL DEFAULT 'universite',
  acquise_le     timestamptz NOT NULL DEFAULT now(),
  inscription_id text,
  CONSTRAINT carrieres_acquises_source_check CHECK (source IN ('universite'))
);
REVOKE ALL ON TABLE public.carrieres_acquises FROM PUBLIC, anon, authenticated;
ALTER TABLE public.carrieres_acquises ENABLE ROW LEVEL SECURITY;

-- ============================================================================================
-- 4. LES RESOLVEURS
-- ============================================================================================
-- LA CARRIERE INITIALE, AVEC LA TABLE DE MIGRATION DES ANCIENS IDENTIFIANTS. `migrerCareerId`
-- fait le meme travail au chargement cote navigateur ; une fiche sauvegardee avant la
-- consolidation 18 -> 10 porte encore un ancien id, et le serveur doit lire la meme chose.
CREATE OR REPLACE FUNCTION public.carriere_initiale(p_nom text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE coalesce(d.career, '')
           WHEN 'civil' THEN 'magistrat' WHEN 'local_civil' THEN 'magistrat'
           WHEN 'lawyer' THEN 'magistrat' WHEN 'influencer' THEN 'press'
           WHEN 'academic' THEN 'doctor'  WHEN 'lobbyist' THEN 'business'
           WHEN 'union' THEN 'worker'     WHEN 'unemployed' THEN 'worker'
           ELSE d.career END
    FROM public.personnages_donnees d WHERE d.name = p_nom;
$$;

-- LES CARRIERES D'UN PERSONNAGE : une, ou deux, jamais plus.
CREATE OR REPLACE FUNCTION public.carrieres_de(p_nom text)
RETURNS text[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT ARRAY(SELECT DISTINCT x FROM unnest(ARRAY[
           public.carriere_initiale(p_nom),
           (SELECT a.carriere FROM public.carrieres_acquises a WHERE a.personnage = p_nom)
         ]) AS x WHERE x IS NOT NULL);
$$;

CREATE OR REPLACE FUNCTION public.carriere_possede(p_nom text, p_carriere text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT p_carriere = ANY (public.carrieres_de(p_nom));
$$;

-- L'HABILITATION EST OUVERTE SI L'UNE DES CARRIERES L'OUVRE. Une habilitation inconnue du
-- registre est FERMEE : fail closed, pas fail open.
CREATE OR REPLACE FUNCTION public.habilitation_ouverte(p_nom text, p_habilitation text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.habilitations_carrieres h
     WHERE h.habilitation = p_habilitation
       AND h.carriere = ANY (public.carrieres_de(p_nom)));
$$;

-- CE QUE LE NAVIGATEUR A LE DROIT DE SAVOIR DE LUI-MEME. Il n'apprend rien sur les autres.
CREATE OR REPLACE FUNCTION public.mes_carrieres()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true,
    'initiale', public.carriere_initiale(v_moi),
    'seconde', (SELECT a.carriere FROM public.carrieres_acquises a WHERE a.personnage = v_moi),
    'carrieres', to_jsonb(public.carrieres_de(v_moi)),
    'seconde_carriere_disponible',
      NOT EXISTS (SELECT 1 FROM public.carrieres_acquises a WHERE a.personnage = v_moi),
    'habilitations', (SELECT coalesce(jsonb_agg(DISTINCT h.habilitation), '[]'::jsonb)
                        FROM public.habilitations_carrieres h
                       WHERE h.carriere = ANY (public.carrieres_de(v_moi))));
END $$;
GRANT EXECUTE ON FUNCTION public.mes_carrieres() TO authenticated;

-- ============================================================================================
-- 5. LA GARDE, AU GOULOT UNIQUE DES POSTES NOMMES
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.poste_attribuer_interne(p_pays text, p_poste text, p_city text, p_titulaire text, p_source text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_id text := p_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  v_label text; v_ancien text; v_hab text;
BEGIN
  SELECT r.label INTO v_label FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF v_label IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;

  -- LA CARRIERE OUVRE LA FONCTION, OU LA FERME. Verifie ICI parce que les trois chemins d'acces
  -- a un poste nomme passent tous par cette porte : acceptation de nomination, candidature
  -- spontanee, attribution directe par l'autorite. Un PNJ n'a pas de fiche : il n'a pas de
  -- carriere non plus, et cette garde ne le concerne pas -- `poste_nommer` l'a deja oriente
  -- vers `titulaires_pnj` avant d'arriver ici.
  SELECT h.habilitation INTO v_hab FROM public.habilitations_postes h WHERE h.poste_id = p_poste;
  IF v_hab IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = p_titulaire)
     AND NOT public.habilitation_ouverte(p_titulaire, v_hab) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'carriere_requise',
      'poste', p_poste, 'habilitation', v_hab,
      'carrieres_qui_ouvrent', (SELECT coalesce(jsonb_agg(c.carriere ORDER BY c.carriere), '[]'::jsonb)
                                  FROM public.habilitations_carrieres c WHERE c.habilitation = v_hab));
  END IF;

  SELECT a.titulaire INTO v_ancien FROM public.postes_attribues a WHERE a.id = v_id;

  -- Le predecesseur perd la fonction : registre d'abord, miroir de fiche ensuite.
  IF v_ancien IS NOT NULL AND v_ancien IS DISTINCT FROM p_titulaire THEN
    UPDATE public.personnages_donnees SET poste = NULL
     WHERE name = v_ancien AND poste ->> 'id' = p_poste;
  END IF;

  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, depuis, source, updated_at)
  VALUES (v_id, p_pays, p_poste, p_city, p_titulaire, now(), p_source, now())
  ON CONFLICT (id) DO UPDATE
    SET titulaire = EXCLUDED.titulaire, depuis = now(),
        source = EXCLUDED.source, updated_at = now();

  DELETE FROM public.titulaires_pnj
   WHERE country = p_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city;

  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', p_poste, 'name', v_label, 'city', p_city,
                                    'nommeLe', (extract(epoch from now())*1000)::bigint)
   WHERE name = p_titulaire;

  RETURN jsonb_build_object('ok', true, 'poste', p_poste, 'city', p_city,
                            'titulaire', p_titulaire, 'predecesseur', v_ancien);
END;
$$;

-- ============================================================================================
-- 6. L'AVOCAT : LA CARRIERE JUSTICE, ET PLUS AUCUN REGISTRE D'ATTENTE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.avocat_est_qualifie(p_nom text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  -- L'ARBITRAGE EST RENDU : exercer comme avocat exige la carriere JUSTICE, initiale ou acquise
  -- a l'Universite comme seconde carriere. Il n'y a plus de registre vide, donc plus de porte
  -- fermee faute de decision.
  SELECT public.habilitation_ouverte(p_nom, 'avocat');
$$;

DROP TABLE IF EXISTS public.justice_barreau_qualifications;

-- ============================================================================================
-- PREUVES STRUCTURELLES -- 14
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  SELECT count(*) INTO v_n FROM public.carrieres;
  IF v_n <> 10 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % carriere(s) au registre, 10 attendues', v_n; END IF;

  SELECT count(*) INTO v_n FROM public.carrieres
   WHERE id IN ('officer','business','magistrat','press','clergy','doctor','worker','intel','criminal_c','escort');
  IF v_n <> 10 THEN RAISE EXCEPTION 'P2 ECHOUEE -- le registre ne correspond pas aux 10 id de data.js'; END IF;

  SELECT count(*) INTO v_n FROM public.habilitations_carrieres
   WHERE habilitation IN ('avocat','juge','procureur','commissaire') AND carriere = 'magistrat';
  IF v_n <> 4 THEN RAISE EXCEPTION 'P3 ECHOUEE -- la carriere JUSTICE n''ouvre pas les quatre fonctions'; END IF;

  SELECT count(*) INTO v_n FROM public.habilitations_carrieres WHERE carriere = 'magistrat';
  IF v_n <> 4 THEN RAISE EXCEPTION 'P4 ECHOUEE -- JUSTICE ouvre % habilitations au lieu de 4', v_n; END IF;

  SELECT count(*) INTO v_n FROM public.habilitations_postes
   WHERE poste_id IN ('juge','procureur','commissaire','commandant');
  IF v_n <> 4 THEN RAISE EXCEPTION 'P5 ECHOUEE -- les quatre postes specialises n''exigent pas d''habilitation'; END IF;

  -- AUCUN POSTE POLITIQUE N'EXIGE UNE CARRIERE. Un ministere, une mairie, une presidence ne sont
  -- pas des professions : les y soumettre serait inventer une regle que personne n'a arbitree.
  SELECT count(*) INTO v_n FROM public.habilitations_postes
   WHERE poste_id IN ('president','pm','maire','maire_adjoint','depute',
                      'min_just','min_int','min_def','min_fin','min_ae','min_info');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- un poste politique exige une carriere'; END IF;

  SELECT count(*) INTO v_n FROM pg_constraint k JOIN pg_class c ON c.oid = k.conrelid
   WHERE c.relname = 'carrieres_acquises' AND k.contype = 'p';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 ECHOUEE -- la seconde carriere n''a pas de cle primaire'; END IF;
  SELECT count(*) INTO v_n FROM pg_index x JOIN pg_class ic ON ic.oid = x.indexrelid
   JOIN pg_class tc ON tc.oid = x.indrelid
   WHERE tc.relname = 'carrieres_acquises' AND x.indisprimary
     AND pg_get_indexdef(ic.oid) LIKE '%(personnage)%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P8 ECHOUEE -- la cle primaire ne porte pas le personnage SEUL : une troisieme carriere reste possible'; END IF;

  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
     AND c.relname IN ('carrieres','habilitations','habilitations_carrieres',
                       'habilitations_postes','carrieres_acquises');
  IF v_n <> 5 THEN RAISE EXCEPTION 'P9 ECHOUEE -- % table(s) neuve(s) sous RLS au lieu de 5', v_n; END IF;

  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relname IN ('carrieres','habilitations','habilitations_carrieres',
                       'habilitations_postes','carrieres_acquises')
     AND EXISTS (SELECT 1 FROM aclexplode(c.relacl) ae JOIN pg_roles r ON r.oid = ae.grantee
                  WHERE r.rolname IN ('anon', 'authenticated'));
  IF v_n <> 0 THEN RAISE EXCEPTION 'P10 ECHOUEE -- % table(s) neuve(s) ouverte(s) aux roles clients', v_n; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'poste_attribuer_interne';
  IF v_txt !~ 'habilitations_postes' OR v_txt !~ 'habilitation_ouverte' THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- le goulot des postes ne verifie aucune carriere'; END IF;
  IF position('''carriere_requise''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- le refus de carriere n''est pas nomme'; END IF;

  SELECT prosrc INTO v_txt FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND proname = 'avocat_est_qualifie';
  IF v_txt !~ 'habilitation_ouverte' THEN
    RAISE EXCEPTION 'P13 ECHOUEE -- le barreau ne passe pas par l''habilitation'; END IF;

  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'justice_barreau_qualifications';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P14 ECHOUEE -- le registre d''attente du barreau survit'; END IF;

  RAISE NOTICE 'LES 14 PREUVES SONT VERTES.';
END $preuves$;
