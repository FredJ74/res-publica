-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013125920 (UTC), nom
-- `greffe_le_registre_des_documents_officiels_et_l_extrait_de_casier`.
-- Le registre passe de 709 a 710 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 7081e83a31f32e60ccc762379e490e1a, 33959 caracteres, 1
-- instruction au registre. Empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE REGISTRE STOCKE LE MEME CORPS SUIVI D'UN SAUT DE LIGNE FINAL : md5
-- 1f361d903591b034df7190bf12945d7b, 33960 caracteres. Les deux ont ete compares : le corps
-- archive ici est, au saut de ligne final pres, OCTET POUR OCTET celui que Supabase a
-- enregistre.
--
-- LE GREFFE DELIVRE DES DOCUMENTS, ET C'EST LE SERVEUR QUI LES FABRIQUE
--
-- DEUX TABLES NEUVES, toutes deux FERMEES AU CLIENT : `documents_officiels` -- le registre de
-- provenance, seule place ou vivent le genre REEL et l'authenticite -- et `greffes_tribunaux`,
-- le greffier PNJ de chaque tribunal.
--
-- POURQUOI LA PROVENANCE N'EST PAS DANS L'OBJET : la vue `personnages` accorde UPDATE a
-- `authenticated`, donc tout ce qui est dans l'inventaire est forgeable. La seule garantie
-- possible est a l'exterieur -- un document forge porte un identifiant absent du registre.
--
-- UNE CONTRAINTE LIE LE FAUX A SON AUTHENTICITE, et l'apparence ne declare jamais le genre du
-- faux : un faux extrait produira exactement le meme objet qu'un vrai.
--
-- LE GREFFIER NE SERA JAMAIS UN POSTE DE JOUEUR, et c'est une contrainte CHECK sur
-- `postes_attribues`, pas une intention.
--
-- DEUX PORTES : son propre extrait (1 PA + 100 FR du joueur, 100 FR a la caisse du tribunal) et
-- l'extrait d'un autre dans une enquete (1 PA du magistrat, 100 FR de la caisse de SON
-- institution, 100 FR a la caisse du tribunal). Trois autorites, et aucune autre.
--
-- PREUVES STRUCTURELLES -- 10.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE GREFFE DELIVRE DES DOCUMENTS, ET C'EST LE SERVEUR QUI LES FABRIQUE.
--
-- CE QUI N'EXISTAIT PAS. Le jeu n'avait AUCUN document judiciaire. Le seul « faux casier » du
-- depot etait une ligne de `DOCUMENTS_FALSIFIABLES` poussee dans `state.inventory` par le
-- navigateur, avec `type: 'document_falsifie'` et `legal: false` ECRITS DANS L'OBJET -- un faux
-- qui s'annonce comme tel -- et une description qui promettait d'« effacer vos antecedents
-- judiciaires dans les archives » alors qu'elle ne touchait rien. Un bouton qui mentait.
--
-- CE QUE POSE CETTE MIGRATION, ET RIEN DE PLUS :
--   1. `documents_officiels`, le registre SERVEUR des documents emis -- la seule place ou vit la
--      PROVENANCE, donc la seule place ou l'on puisse savoir si un document est authentique ;
--   2. `greffes_tribunaux`, le registre du greffier PNJ de chaque tribunal ;
--   3. le contenu d'un casier judiciaire, DERIVE du registre des jugements, jamais stocke ;
--   4. l'emission d'un document : une ligne au registre, et un OBJET D'INVENTAIRE ordinaire ;
--   5. deux portes pour l'extrait de casier -- la sienne, et celle d'une autorite en enquete.
--
-- POURQUOI LA PROVENANCE N'EST PAS DANS L'OBJET. Un joueur peut ECRIRE sa propre fiche : la vue
-- `personnages` accorde UPDATE a `authenticated`, et `inventory` en fait partie. Tout ce qui est
-- dans l'objet est donc forgeable, et un drapeau `authentique: false` pose dans l'objet serait a
-- la fois visible et effacable. La seule garantie possible est a l'exterieur : `documents_officiels`
-- n'a AUCUN droit client -- ni lecture, ni ecriture --, donc un document forge dans un inventaire
-- porte un identifiant qui ne correspond a RIEN au registre. C'est cela que « preparer les
-- donnees de provenance pour qu'une authentification soit possible plus tard » veut dire, et
-- c'est pose des maintenant, sans construire aujourd'hui le systeme transversal d'authentification.
--
-- UN FAUX SE PRESENTE COMME UN VRAI. L'objet d'inventaire porte le genre APPARENT ; le registre
-- porte le genre REEL. Les deux colonnes existent pour cette raison, et une contrainte lie
-- `genre = 'casier_faux'` a `authentique = false` : on ne peut pas enregistrer un faux
-- authentique ni un vrai qui ne le soit pas.
--
-- UN DOCUMENT EST FIGE. Son contenu est calcule UNE FOIS, a la delivrance, et recopie dans
-- l'objet comme au registre. Rien ne le met a jour : un extrait de casier delivre hier dit ce que
-- le casier disait hier, et c'est tout l'interet d'un extrait date.
--
-- ET C'EST UN OBJET D'INVENTAIRE ORDINAIRE. Pas de mecanique speciale : il se donne, se detruit,
-- s'abandonne et se confisque par les portes generiques qui existent (`inventaire_donner`,
-- `inventaire_detruire`, `inventaire_abandonner`, `inventaire_confisquer`), parce qu'il a la meme
-- forme que n'importe quel autre objet -- `name`, `type`, `stackKey` absent, `qty`, `encombrement`.
-- AUCUNE porte judiciaire de destruction n'est creee.
--
-- LE GREFFIER EST UN PNJ, ET IL NE SERA JAMAIS UN POSTE DE JOUEUR. La garantie est STRUCTURELLE :
-- une contrainte CHECK sur `postes_attribues` interdit la valeur `greffier`, et le registre des
-- postes nommes ne la connait pas. Luthecia a son greffier depuis le casting du 1er octobre --
-- « Greffier Petit » -- ; Port-Sainte-Marie et Montrouge n'ont pas de nom propre, et en inventer
-- deux serait une decision de CASTING : leurs lignes existent avec un greffier NUL, et le
-- document est alors signe par l'institution (« Greffe du tribunal de … »). C'est signale au
-- rapport.

-- ---------------------------------------------------------------------------------------------
-- 1. LE REGISTRE DES DOCUMENTS EMIS
-- ---------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.documents_officiels (
  id             text PRIMARY KEY,
  genre          text NOT NULL,
  genre_apparent text NOT NULL,
  authentique    boolean NOT NULL,
  pays           text NOT NULL,
  tribunal_ville text,
  sujet          text,
  organisation   text,
  affaire        text,
  porteur        text NOT NULL,
  emis_par       text NOT NULL,
  demande_par    text NOT NULL,
  emis_le        timestamptz NOT NULL DEFAULT now(),
  emis_jour      integer NOT NULL,
  contenu        jsonb NOT NULL,
  donnees        jsonb,
  CONSTRAINT documents_officiels_genre_declare
    CHECK (genre IN ('casier_extrait', 'casier_faux', 'dossier_copie', 'domiciliation_extrait')),
  CONSTRAINT documents_officiels_apparence_declaree
    CHECK (genre_apparent IN ('casier_extrait', 'dossier_copie', 'domiciliation_extrait')),
  -- UN FAUX EST UN FAUX, ET UN VRAI EST UN VRAI. La contrainte lie les deux colonnes : aucune
  -- porte, presente ou future, ne peut enregistrer un faux casier « authentique ».
  CONSTRAINT documents_officiels_faux_est_un_faux
    CHECK ((genre = 'casier_faux') = (authentique = false))
);

COMMENT ON TABLE public.documents_officiels IS
  'Registre SERVEUR des documents officiels emis (extrait de casier, copie de dossier, faux casier, extrait de domiciliation). Seule place ou vit la PROVENANCE : `authentique` et le genre REEL. Aucun droit client -- un document forge dans un inventaire porte un identifiant absent de ce registre, et c''est la seule authentification possible tant que la vue des personnages accorde UPDATE a authenticated.';

ALTER TABLE public.documents_officiels ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.documents_officiels FROM PUBLIC;
REVOKE ALL ON TABLE public.documents_officiels FROM anon, authenticated;

CREATE INDEX IF NOT EXISTS documents_officiels_porteur_idx
  ON public.documents_officiels (porteur);

-- ---------------------------------------------------------------------------------------------
-- 2. LE GREFFIER DE CHAQUE TRIBUNAL
-- ---------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.greffes_tribunaux (
  pays         text NOT NULL,
  ville        text NOT NULL,
  greffier_pnj text,
  PRIMARY KEY (pays, ville)
);

COMMENT ON TABLE public.greffes_tribunaux IS
  'Le greffier de chaque tribunal. C''est TOUJOURS un PNJ : la contrainte postes_attribues_jamais_greffier interdit la valeur `greffier` au registre des postes attribues, et `postes_nommes_regles` ne la connait pas. Un `greffier_pnj` NUL signifie que le casting n''a pas encore nomme ce greffier : le document est alors signe par l''institution.';

ALTER TABLE public.greffes_tribunaux ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.greffes_tribunaux FROM PUBLIC;
REVOKE ALL ON TABLE public.greffes_tribunaux FROM anon, authenticated;

INSERT INTO public.greffes_tribunaux (pays, ville, greffier_pnj) VALUES
  ('republic', 'capitale', 'Greffier Petit'),
  ('republic', 'ville_a',  NULL),
  ('republic', 'ville_b',  NULL)
ON CONFLICT (pays, ville) DO NOTHING;

-- LE GREFFIER N'EST JAMAIS UN POSTE DE JOUEUR, ET C'EST UNE CONTRAINTE, PAS UNE INTENTION.
ALTER TABLE public.postes_attribues
  DROP CONSTRAINT IF EXISTS postes_attribues_jamais_greffier;
ALTER TABLE public.postes_attribues
  ADD CONSTRAINT postes_attribues_jamais_greffier CHECK (poste_id <> 'greffier');

-- ---------------------------------------------------------------------------------------------
-- 3. QUI SIGNE AU GREFFE
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.greffe_signataire(p_pays text, p_ville text)
 RETURNS text
 LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(g.greffier_pnj,
                  'Greffe du tribunal de ' || coalesce(v.nom, coalesce(p_ville, 'la capitale')))
    FROM public.greffes_tribunaux g
    LEFT JOIN public.villes v ON v.pays = g.pays AND v.ville = g.ville
   WHERE g.pays = p_pays AND g.ville IS NOT DISTINCT FROM coalesce(p_ville, 'capitale');
$function$;
REVOKE ALL ON FUNCTION public.greffe_signataire(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.greffe_signataire(text, text) TO service_role;

-- ---------------------------------------------------------------------------------------------
-- 4. LE CONTENU D'UN CASIER JUDICIAIRE
-- ---------------------------------------------------------------------------------------------
-- IL N'EST PAS STOCKE : il est DERIVE du registre des jugements, qui fait foi. Un casier
-- judiciaire porte les CONDAMNATIONS -- pas les relaxes, pas les non-lieux, pas les plaintes.
--
-- UNE CONDAMNATION DEFINITIVEMENT ANNULEE N'Y FIGURE PAS, et ce n'est pas une invention : le
-- jugement d'appel est DEFINITIF (le registre des types d'actes le dit), donc une condamnation de
-- premiere instance suivie d'une relaxe en appel n'est plus une condamnation. La peine d'appel,
-- elle, figure au casier comme n'importe quelle autre.
--
-- ET IL NE PORTE PAS LE TEXTE DU PLAIGNANT. Comme l'avis de recherche depuis ce matin, le casier
-- dit la QUALIFICATION RETENUE, pas ce que quelqu'un a declare.
CREATE OR REPLACE FUNCTION public.casier_judiciaire_contenu(p_personne text, p_pays text)
 RETURNS jsonb
 LANGUAGE sql STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH retenues AS (
    SELECT j.id, j.jour, j.city, j.peine, j.juge, j.motif, j.data, j.created_at
      FROM public.jugements j
     WHERE j.accuse = p_personne
       AND j.country IS NOT DISTINCT FROM p_pays
       AND (j.data ->> 'verdict') = 'condamnation'
       AND NOT EXISTS (
             SELECT 1 FROM public.jugements a
              WHERE j.id LIKE 'jug-%'
                AND j.id NOT LIKE 'jug-app-%'
                AND a.id = 'jug-app-' || right(j.id, length(j.id) - 4)
                AND (a.data ->> 'verdict') = 'relaxe')
  )
  SELECT jsonb_build_object(
    'personne', p_personne,
    'pays', p_pays,
    'vierge', (SELECT count(*) FROM retenues) = 0,
    'condamnations', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'jugement',  r.id,
               'jour',      r.jour,
               'ville',     r.city,
               'infraction', r.data ->> 'infraction',
               'libelle',   coalesce(r.data ->> 'infraction_libelle', r.motif),
               'peine',     r.peine,
               'instance',  coalesce(r.data ->> 'instance', 'premiere'),
               'juge',      r.juge)
             ORDER BY r.jour, r.created_at)
        FROM retenues r), '[]'::jsonb));
$function$;
REVOKE ALL ON FUNCTION public.casier_judiciaire_contenu(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.casier_judiciaire_contenu(text, text) TO service_role;

-- ---------------------------------------------------------------------------------------------
-- 5. L'EMISSION D'UN DOCUMENT
-- ---------------------------------------------------------------------------------------------
-- UNE SEULE PORTE D'EMISSION pour les quatre especes de documents. Elle fait les DEUX moities
-- dans la meme transaction : la ligne au registre de provenance, et l'objet dans l'inventaire du
-- porteur. Interne : aucun droit client, aucun appel possible depuis un navigateur.
CREATE OR REPLACE FUNCTION public.document_officiel_emettre(
  p_genre text, p_genre_apparent text, p_authentique boolean,
  p_pays text, p_ville text, p_sujet text, p_organisation text, p_affaire text,
  p_porteur text, p_demande_par text, p_jour integer,
  p_nom text, p_desc text, p_icone text, p_contenu jsonb, p_donnees jsonb DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_inv jsonb; v_objet jsonb; v_signataire text; v_le text;
BEGIN
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv
    FROM public.personnages_donnees WHERE name = p_porteur FOR UPDATE;
  IF v_inv IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'porteur_introuvable');
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  v_id := 'doc-' || replace(gen_random_uuid()::text, '-', '');
  v_signataire := public.greffe_signataire(p_pays, p_ville);
  v_le := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');

  INSERT INTO public.documents_officiels
    (id, genre, genre_apparent, authentique, pays, tribunal_ville, sujet, organisation, affaire,
     porteur, emis_par, demande_par, emis_jour, contenu, donnees)
  VALUES (v_id, p_genre, p_genre_apparent, p_authentique, p_pays, p_ville, p_sujet,
          p_organisation, p_affaire, p_porteur, coalesce(v_signataire, 'Greffe'), p_demande_par,
          p_jour, p_contenu, p_donnees);

  -- L'OBJET NE PORTE NI `authentique`, NI LE GENRE REEL. Un vrai extrait et un faux extrait
  -- produisent ici exactement le meme objet : c'est la regle, et c'est pourquoi la provenance
  -- vit ailleurs. Aucun `stackKey` : un document ne s'empile pas avec un autre.
  v_objet := jsonb_strip_nulls(jsonb_build_object(
    'name',         p_nom,
    'type',         'document_officiel',
    'stackable',    false,
    'qty',          1,
    'encombrement', 1,
    'icon',         coalesce(p_icone, 'ti-file-certificate'),
    'desc',         p_desc,
    'document',     v_id,
    'genre',        p_genre_apparent,
    'pays',         p_pays,
    'tribunal',     p_ville,
    'sujet',        p_sujet,
    'organisation', p_organisation,
    'affaire',      p_affaire,
    'emis_par',     coalesce(v_signataire, 'Greffe'),
    'emis_le',      v_le,
    'emis_jour',    p_jour,
    'contenu',      p_contenu));

  UPDATE public.personnages_donnees
     SET inventory = coalesce(inventory, '[]'::jsonb) || jsonb_build_array(v_objet)
   WHERE name = p_porteur;

  RETURN jsonb_build_object('ok', true, 'document', v_id, 'porteur', p_porteur,
                            'emis_par', v_signataire, 'emis_jour', p_jour, 'objet', v_objet);
END;
$function$;
REVOKE ALL ON FUNCTION public.document_officiel_emettre(text, text, boolean, text, text, text, text, text, text, text, integer, text, text, text, jsonb, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.document_officiel_emettre(text, text, boolean, text, text, text, text, text, text, text, integer, text, text, text, jsonb, jsonb) TO service_role;

-- ---------------------------------------------------------------------------------------------
-- 6. MON PROPRE EXTRAIT DE CASIER -- 100 FR ET 1 PA
-- ---------------------------------------------------------------------------------------------
-- AUCUNE ENQUETE N'EST REQUISE : un joueur a droit a son casier. Les 100 FR sortent de son
-- portefeuille et entrent dans la caisse du TRIBUNAL ou il les a payes.
CREATE OR REPLACE FUNCTION public.casier_mon_extrait()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_piece text;
        v_g record; v_jour integer; v_paye jsonb; v_doc jsonb; v_contenu jsonb;
        v_caisse text; v_inv jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country, current_city, current_building, current_room, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_bat, v_piece, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'site', v_g.batiment, 'piece', v_g.piece);
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  v_caisse := v_pays || '_tribunal_' || coalesce(v_ville, 'capitale');
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_du_tribunal_introuvable',
                              'caisse', v_caisse);
  END IF;

  -- LE PAIEMENT D'ABORD, ET C'EST LUI QUI PEUT REFUSER. Tout ce qui suit est garanti.
  v_paye := public.payer_ordre(v_moi, 'casier_mon_extrait', 1, 100);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  -- LES 100 FR NE SONT PAS DETRUITS : ils entrent dans la caisse du tribunal.
  PERFORM public.caisse_institution_mouvement(v_caisse, 100, true);

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_contenu := public.casier_judiciaire_contenu(v_moi, v_pays);

  v_doc := public.document_officiel_emettre(
    'casier_extrait', 'casier_extrait', true,
    v_pays, v_ville, v_moi, NULL, NULL, v_moi, v_moi, v_jour,
    'Extrait de casier judiciaire — ' || v_moi,
    'Delivre par le greffe au jour ' || v_jour || '. Document FIGE : il dit l''etat du casier '
      || 'au moment de sa delivrance, et ne se met jamais a jour.',
    'ti-file-certificate', v_contenu,
    jsonb_build_object('motif', 'demande_personnelle'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    -- L'EMISSION A ECHOUE APRES LE PAIEMENT : on LEVE, ce qui annule le paiement avec le reste.
    -- Un refus rendu ici laisserait les 100 FR preleves sans document.
    RAISE EXCEPTION 'casier_mon_extrait : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'document', v_doc ->> 'document',
    'jour', v_jour, 'tribunal', v_ville, 'emis_par', v_doc ->> 'emis_par',
    'vierge', (v_contenu ->> 'vierge')::boolean,
    'condamnations', jsonb_array_length(v_contenu -> 'condamnations'));
END;
$function$;
REVOKE ALL ON FUNCTION public.casier_mon_extrait() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.casier_mon_extrait() TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- 7. L'EXTRAIT DE CASIER D'UN AUTRE -- DANS UNE ENQUETE, ET AUX FRAIS DE L'INSTITUTION
-- ---------------------------------------------------------------------------------------------
-- TROIS AUTORITES, ET AUCUNE AUTRE : le Commissaire ou le Juge de la VILLE d'une affaire vivante
-- qui vise cette personne, et le Procureur de la Republique. Ni l'avocat, ni le Ministre de la
-- Justice, ni le maire, ni un employeur, ni un journaliste.
--
-- LE PA EST PAYE PAR LE MAGISTRAT, LES 100 FR PAR SON INSTITUTION. Le tribunal pour le juge et
-- pour le parquet, le commissariat pour le commissaire -- et dans les deux cas l'argent arrive
-- dans la caisse du TRIBUNAL ou l'extrait est delivre.
--
-- UNE DEMANDE ORDINAIRE NE CREE AUCUNE TRACE EXPLOITABLE EN JEU : la ligne au registre des
-- documents n'est lisible par AUCUN client, aucun acte n'est consigne a la chronologie de
-- l'affaire, et rien n'entre au Journal. Un magistrat qui consulte un casier dans son enquete
-- fait son travail ; ce n'est pas un evenement public.
CREATE OR REPLACE FUNCTION public.casier_extrait_enquete(p_personne text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text; v_bat text; v_piece text; v_inv jsonb;
        v_g record; v_jour integer; v_paye jsonb; v_doc jsonb; v_contenu jsonb;
        v_poste record; v_caisse text; v_caisse_trib text; v_solde numeric;
        v_affaire text; v_affaire_ville text; v_parquet record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(coalesce(p_personne, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personne_manquante');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_personne) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personne_introuvable');
  END IF;

  SELECT country, current_city, current_building, current_room, coalesce(inventory, '[]'::jsonb)
    INTO v_pays, v_ville, v_bat, v_piece, v_inv
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- LE POSTE, LU EN BASE. `acteur_poste_courant` est la seule source d'autorite.
  SELECT * INTO v_poste FROM public.acteur_poste_courant();
  IF v_poste.poste_id IS NULL OR v_poste.poste_id NOT IN ('juge', 'commissaire', 'procureur') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_refusee');
  END IF;

  -- UNE AFFAIRE VIVANTE QUI VISE CETTE PERSONNE, ET DONT L'APPELANT EST L'AUTORITE.
  SELECT * INTO v_parquet FROM public.parquet_moi();
  SELECT p.id, p.city INTO v_affaire, v_affaire_ville
    FROM public.plaintes_en_cours p
   WHERE p.country = v_pays
     AND left(btrim(coalesce(p.data, '')), 1) = '{'
     AND (p.data::jsonb ->> 'cible') = p_personne
     AND (p.data::jsonb ->> 'status') IN ('au_parquet', 'enquete', 'poursuites', 'saisie',
                                          'abandon_demande', 'appel')
     AND (public.affaire_autorite_de(p.city)
          OR (v_parquet.nom IS NOT NULL AND v_parquet.pays IS NOT DISTINCT FROM p.country))
   ORDER BY p.created_at
   LIMIT 1;
  IF v_affaire IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_enquete_sur_cette_personne',
                              'personne', p_personne);
  END IF;

  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', v_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(v_moi, v_pays, v_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'site', v_g.batiment, 'piece', v_g.piece);
  END IF;
  IF public.inventaire_place_restante(v_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  -- LA CAISSE DE SON INSTITUTION, et elle est nommee par son POSTE.
  v_caisse := CASE v_poste.poste_id
    WHEN 'commissaire' THEN v_pays || '_commissariat_' || coalesce(v_poste.poste_city, 'capitale')
    WHEN 'juge'        THEN v_pays || '_tribunal_'     || coalesce(v_poste.poste_city, 'capitale')
    ELSE                    v_pays || '_tribunal_'     || coalesce(v_affaire_ville, 'capitale')
  END;
  v_caisse_trib := v_pays || '_tribunal_' || coalesce(v_ville, 'capitale');

  -- LE VERROU AVANT LE PAIEMENT. La caisse est lue FOR UPDATE : son solde ne peut plus changer
  -- avant la fin de la transaction, donc le debit qui suit ne peut plus manquer de fonds. Sans
  -- cela, un refus apres le prelevement des PA laisserait le PA consomme sans document.
  SELECT coalesce((data ->> 'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF v_solde IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_institution_introuvable',
                              'caisse', v_caisse);
  END IF;
  IF v_solde < 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_institution_insuffisante',
                              'caisse', v_caisse, 'solde', v_solde, 'requis', 100);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = v_caisse_trib) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_du_tribunal_introuvable',
                              'caisse', v_caisse_trib);
  END IF;

  -- LE PA EST CELUI DU MAGISTRAT, ET LUI SEUL : zero FR sur son portefeuille.
  v_paye := public.payer_ordre(v_moi, 'casier_extrait_enquete', 1, 0);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  -- LE DEBIT INSTITUTIONNEL PASSE PAR LA PORTE INTERNE : l'autorite a ete verifiee ci-dessus
  -- (c'est la caisse de SON institution), et le controle generique de la porte, concu pour un
  -- appel client direct, refuserait un debit qu'aucun poste « proprietaire de caisse » ne couvre.
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.caisse_institution_mouvement(v_caisse, -100, true);
  PERFORM public.caisse_institution_mouvement(v_caisse_trib, 100, true);
  PERFORM set_config('rp.caisse_interne', '', true);

  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  v_contenu := public.casier_judiciaire_contenu(p_personne, v_pays);

  v_doc := public.document_officiel_emettre(
    'casier_extrait', 'casier_extrait', true,
    v_pays, v_ville, p_personne, NULL, NULL, v_moi, v_moi, v_jour,
    'Extrait de casier judiciaire — ' || p_personne,
    'Delivre par le greffe au jour ' || v_jour || '. Document FIGE : il dit l''etat du casier '
      || 'au moment de sa delivrance, et ne se met jamais a jour.',
    'ti-file-certificate', v_contenu,
    jsonb_build_object('motif', 'enquete', 'affaire', v_affaire,
                       'poste', v_poste.poste_id, 'caisse', v_caisse));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'casier_extrait_enquete : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'document', v_doc ->> 'document',
    'personne', p_personne, 'jour', v_jour, 'tribunal', v_ville,
    'emis_par', v_doc ->> 'emis_par', 'affaire', v_affaire,
    'caisse_debitee', v_caisse,
    'vierge', (v_contenu ->> 'vierge')::boolean,
    'condamnations', jsonb_array_length(v_contenu -> 'condamnations'));
END;
$function$;
REVOKE ALL ON FUNCTION public.casier_extrait_enquete(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.casier_extrait_enquete(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------------------
-- 8. LES DEUX ORDRES AU MIROIR DES COUTS
-- ---------------------------------------------------------------------------------------------
-- `payer_ordre` REFUSE tout triplet (fn, pa, cost) absent de ce miroir -- `ordre_inconnu` puis
-- `cout_non_declare`. Sans ces deux lignes, les deux portes seraient inappelables.
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES
  ('casier_mon_extrait', 1, 100),
  ('casier_extrait_enquete', 1, 0)
ON CONFLICT (fn, pa, cost) DO NOTHING;

-- =============================================================================================
-- PREUVES STRUCTURELLES
-- =============================================================================================
DO $$
DECLARE v_n integer; v_src text;
BEGIN
  -- P1. LE REGISTRE DES DOCUMENTS EST FERME AU CLIENT, et c'est toute la provenance.
  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND table_name IN ('documents_officiels', 'greffes_tribunaux')
     AND grantee IN ('anon', 'authenticated');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE : % droit(s) client sur les deux registres de documents', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname IN ('documents_officiels', 'greffes_tribunaux')
     AND c.relrowsecurity;
  IF v_n <> 2 THEN RAISE EXCEPTION 'P1b ECHOUEE : % table(s) sur 2 avec RLS active', v_n; END IF;

  -- P2. UN FAUX NE PEUT PAS ETRE ENREGISTRE COMME AUTHENTIQUE. La contrainte lie les colonnes.
  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE conname IN ('documents_officiels_faux_est_un_faux',
                     'documents_officiels_genre_declare',
                     'documents_officiels_apparence_declaree');
  IF v_n <> 3 THEN RAISE EXCEPTION 'P2 ECHOUEE : % contrainte(s) sur 3 posees', v_n; END IF;
  -- Et l'apparence ne connait PAS le genre du faux : il se presente comme un vrai extrait.
  SELECT pg_get_constraintdef(oid) INTO v_src FROM pg_constraint
   WHERE conname = 'documents_officiels_apparence_declaree';
  IF v_src LIKE '%casier_faux%' THEN
    RAISE EXCEPTION 'P2b ECHOUEE : l apparence declare le genre du faux -- %', v_src;
  END IF;

  -- P3. LE GREFFIER NE SERA JAMAIS UN POSTE DE JOUEUR, et c'est une contrainte.
  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE conname = 'postes_attribues_jamais_greffier';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE : la contrainte du greffier n est pas posee'; END IF;
  SELECT count(*) INTO v_n FROM public.postes_nommes_regles WHERE poste_id = 'greffier';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P3b ECHOUEE : greffier figure au registre des postes nommes'; END IF;
  SELECT count(*) INTO v_n FROM public.greffes_tribunaux WHERE pays = 'republic';
  IF v_n <> 3 THEN RAISE EXCEPTION 'P3c ECHOUEE : % greffe(s) sur 3 declares', v_n; END IF;

  -- P4. LES DEUX PORTES CLIENTES SONT APPELABLES PAR UN JOUEUR, les trois internes NE LE SONT PAS.
  SELECT count(*) INTO v_n FROM information_schema.role_routine_grants
   WHERE specific_schema = 'public' AND grantee = 'authenticated' AND privilege_type = 'EXECUTE'
     AND routine_name IN ('casier_mon_extrait', 'casier_extrait_enquete');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P4 ECHOUEE : % porte(s) cliente(s) sur 2', v_n; END IF;
  SELECT count(*) INTO v_n FROM information_schema.role_routine_grants
   WHERE specific_schema = 'public' AND grantee IN ('anon', 'authenticated')
     AND routine_name IN ('document_officiel_emettre', 'casier_judiciaire_contenu',
                          'greffe_signataire');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P4b ECHOUEE : % droit(s) client sur les portes internes', v_n;
  END IF;

  -- P5. LE MIROIR DES COUTS DECLARE LES DEUX ORDRES, et aux montants de l'arbitrage.
  SELECT count(*) INTO v_n FROM public.ordres_couts
   WHERE (fn, pa, cost) IN (('casier_mon_extrait', 1, 100), ('casier_extrait_enquete', 1, 0));
  IF v_n <> 2 THEN RAISE EXCEPTION 'P5 ECHOUEE : % ligne(s) sur 2 au miroir des couts', v_n; END IF;

  -- P6. LES DEUX PORTES NOMMENT LEURS GARDES : presence au greffe, autorite, enquete, caisse.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'casier_mon_extrait';
  IF v_src !~ 'acteur_present_sur_site' OR v_src !~ 'presence_au_greffe_requise'
     OR v_src !~ 'payer_ordre' OR v_src !~ 'caisse_institution_mouvement' THEN
    RAISE EXCEPTION 'P6 ECHOUEE : casier_mon_extrait ne porte pas ses quatre gardes';
  END IF;
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'casier_extrait_enquete';
  IF v_src !~ 'acteur_poste_courant' OR v_src !~ 'aucune_enquete_sur_cette_personne'
     OR v_src !~ 'acteur_present_sur_site' OR v_src !~ 'caisse_institution_insuffisante'
     OR v_src !~ 'FOR UPDATE' THEN
    RAISE EXCEPTION 'P6b ECHOUEE : casier_extrait_enquete ne porte pas ses cinq gardes';
  END IF;
  -- ET ELLE N'OUVRE PAS LA PORTE A UN QUATRIEME POSTE.
  IF v_src ~ 'min_just' OR v_src ~ 'min_int' OR v_src ~ 'avocat' OR v_src ~ 'maire' THEN
    RAISE EXCEPTION 'P6c ECHOUEE : une autorite non declaree figure dans la porte';
  END IF;

  -- P7. LE CASIER EST DERIVE, JAMAIS STOCKE : la fonction ne fait que LIRE les jugements.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'casier_judiciaire_contenu';
  IF v_src ~ '(INSERT|UPDATE|DELETE)' THEN
    RAISE EXCEPTION 'P7 ECHOUEE : le contenu du casier ecrit quelque chose';
  END IF;
  IF v_src !~ '''condamnation''' OR v_src !~ 'jug-app-' OR v_src ~ 'motif_allegue' THEN
    RAISE EXCEPTION 'P7b ECHOUEE : le casier ne tient pas ses trois regles';
  END IF;

  -- P8. AUCUNE PORTE D'EMISSION NE TOUCHE AU REGISTRE DES JUGEMENTS. Un extrait LIT le casier ;
  -- il ne le modifie jamais -- c'est vrai de l'extrait authentique comme du faux a venir.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('document_officiel_emettre', 'casier_mon_extrait', 'casier_extrait_enquete')
     AND public.sans_commentaires(p.prosrc) ~ '(INSERT INTO public.jugements|UPDATE public.jugements|DELETE FROM public.jugements)';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE : % porte(s) de document ecrivent au registre des jugements', v_n;
  END IF;

  -- P9. L'OBJET D'INVENTAIRE NE PORTE NI LE GENRE REEL NI L'AUTHENTICITE.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'document_officiel_emettre';
  -- La cle 'authentique' ENTRE GUILLEMETS n'existe que dans un jsonb_build_object : l'INSERT,
  -- lui, nomme la colonne sans guillemets. Son absence prouve donc que l'objet ne la porte pas.
  IF v_src ~ '''authentique''' THEN
    RAISE EXCEPTION 'P9 ECHOUEE : l objet d inventaire porte l authenticite';
  END IF;
  IF v_src !~ '''genre'',\s*p_genre_apparent' THEN
    RAISE EXCEPTION 'P9b ECHOUEE : l objet d inventaire ne porte pas le genre APPARENT';
  END IF;
  IF v_src !~ '''stackable'',\s*false' OR v_src ~ 'stackKey' THEN
    RAISE EXCEPTION 'P9c ECHOUEE : un document s empile ou porte une cle de pile';
  END IF;

  -- P10. AUCUN DOCUMENT N'EST EMIS PAR LA MIGRATION, et aucune donnee n'est touchee.
  SELECT count(*) INTO v_n FROM public.documents_officiels;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P10 ECHOUEE : % document(s) deja emis', v_n; END IF;

  RAISE NOTICE 'LES 10 PREUVES STRUCTURELLES SONT VERTES.';
END $$;
