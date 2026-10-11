-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261011223728 (UTC), nom
-- `universite_socle_cursus_et_qualifications`.
-- Le registre passe de 668 a 669 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 22e9709dc764ca26fe26fb748e92dc5e, 36401 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- L'UNIVERSITE -- LE SOCLE DES CURSUS ET DES QUALIFICATIONS
--
-- CETTE MIGRATION CREE UNE ARCHITECTURE, ET N'INVENTE AUCUN CONTENU. Les cinq catalogues
-- (`qualifications`, `universite_cursus`, `universite_cursus_jalons`, et les deux tables
-- d'inscription et de jalons accomplis) naissent VIDES, et c'est le point central : les cursus,
-- leurs noms, leurs qualifications, leurs durees, leurs jalons, leurs stages, leurs couts et
-- leurs prerequis metier sont des arbitrages de game design. L'inventaire du commit 9de8d38
-- (baseline/arbitrages/INVENTAIRE-CARRIERES-ET-QUALIFICATIONS.md) sert a les decider.
--
-- ELLE RETIRE AUSSI LA LIGNE DE COUT DE L'ANCIEN ORDRE. `se_former` (2 PA + 100 FR) a quitte
-- data.js dans le meme lot ; sa ligne de `ordres_couts` -- le miroir du canon -- part avec lui,
-- sinon le miroir declare un cout pour un ordre qui n'existe plus.
--
-- LES REGLES VALIDEES QUE LE SOCLE REPRESENTE, ET LA FACON DONT CHACUNE EST TENUE :
--   . au maximum UNE qualification universitaire par personnage A VIE -- index unique PARTIEL
--     `personnages_une_seule_qualif_universitaire` sur (personnage) WHERE source = 'universite' ;
--   . un seul cursus actif a la fois -- index unique partiel `universite_un_seul_cursus_actif` ;
--   . seule l'obtention effective du diplome consomme le slot, et elle le consomme EN ECRIVANT
--     la qualification : `universite_diplomer` est la seule porte du socle qui INSERE dans
--     `personnages_qualifications` (preuve P8) ;
--   . abandon, echec, expiration : rien n'est ecrit, donc le slot reste disponible (preuve P9) ;
--   . duree limite = exactement 2 x la duree theorique, figee a l'inscription en dates
--     calendaires de Paris ;
--   . aucune acceleration par PA, par argent ni par repetition -- un jalon de rang N s'ouvre N-1
--     semaines apres `debut_le`, et la cle primaire (inscription, jalon) interdit de le refaire ;
--   . aucun examen aleatoire : aucune porte du socle ne tire au sort.
--
-- ET LE SLOT N'EST PAS STOCKE, IL EST DERIVE. Il n'existe aucune colonne « slot consomme »
-- (preuve P12) : `universite_slot_consomme(nom)` repond en lisant s'il existe une qualification
-- de source 'universite' sur la fiche. Un drapeau se desynchronise ; une derivation ne peut pas.
-- Meme doctrine que la presidence de l'Assemblee, derivee des neuf sieges.
--
-- AUCUN PERSONNAGE EXISTANT NE RECOIT QUOI QUE CE SOIT (preuve P10). Rien ici ne deduit une
-- qualification de `career`, de `comp`, de `school` ni d'`archetype`.
--
-- LES SIX TABLES PORTENT LA RLS ET N'ONT AUCUN DROIT CLIENT (preuves P1 et P2) : tout passe par
-- les huit fonctions SECURITY DEFINER a search_path figé. C'est la doctrine du projet -- une
-- policy sans GRANT est dormante, un GRANT sans policy est ouvert -- appliquee en n'accordant ni
-- l'un ni l'autre a anon/authenticated.
--
-- LES 12 PREUVES STRUCTURELLES SONT PASSEES A L'APPLICATION. Le comportement des portes est
-- eprouve separement par outils/bancs/banc-universite-socle.sql (21 epreuves, en transaction
-- annulee) -- une migration ne commite jamais de preuve comportementale.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- UNIVERSITE -- LE SOCLE DES CURSUS ET DES QUALIFICATIONS
-- 12 octobre 2026
--
-- CE QUE CETTE MIGRATION FAIT, ET CE QU'ELLE NE FAIT PAS.
--
-- Elle cree l'architecture generique qui permettra, APRES arbitrage de game design, de declarer
-- des cursus universitaires reels. Les cinq catalogues naissent VIDES et c'est deliberе : les
-- cursus, leurs noms, leurs qualifications, leurs durees, leurs jalons, leurs stages, leurs couts
-- et leurs prerequis metier ne sont PAS inventes ici. L'inventaire du commit 9de8d38
-- (baseline/arbitrages/INVENTAIRE-CARRIERES-ET-QUALIFICATIONS.md) sert a les decider.
--
-- ELLE RETIRE AUSSI LE COUT DE L'ANCIEN ORDRE. `se_former` (2 PA + 100 FR) a quitte data.js, donc
-- sa ligne de `ordres_couts` -- le miroir du canon -- doit partir avec lui, sinon le miroir
-- declare un cout pour un ordre qui n'existe plus. Le generateur confirme : 405 triplets, zero
-- `se_former`.
--
-- LES REGLES VALIDEES QUE LE SOCLE REPRESENTE :
--   . au maximum UNE qualification universitaire supplementaire par personnage, A VIE ;
--   . un seul cursus actif a la fois ;
--   . seule l'obtention effective du diplome consomme le slot a vie ;
--   . abandon, echec, expiration : slot NON consomme ;
--   . duree limite = 2 x la duree theorique, exactement ;
--   . aucune acceleration possible par PA, par FR, ni par repetition ;
--   . un jalon manque ne fait pas echouer : il reste a accomplir, et il retarde ;
--   . aucun examen aleatoire.
--
-- ET LE SLOT N'EST PAS STOCKE, IL EST DERIVE. Il n'existe aucune colonne « slot consomme » :
-- `universite_slot_consomme(nom)` repond en lisant s'il existe une qualification de source
-- 'universite' sur la fiche. Un drapeau se desynchronise ; une derivation ne peut pas.

-- ============================================================================================
-- 0. L'ANCIEN ORDRE PERD SON COUT
-- ============================================================================================
DELETE FROM public.ordres_couts WHERE fn = 'se_former';

-- ============================================================================================
-- 1. LES QUALIFICATIONS -- CATALOGUE VIDE, EXTENSIBLE
-- ============================================================================================
-- DISTINCTE DES CHAINES DECORATIVES `comp`. L'inventaire a etabli que les dix chaines de
-- competences des carrieres de creation (« Droit, Procedure judiciaire »...) ne sont parsees par
-- RIEN. Une qualification est ici une ENTITE : un identifiant que du code peut exiger.
CREATE TABLE IF NOT EXISTS public.qualifications (
  id        text PRIMARY KEY,
  libelle   text NOT NULL,
  note      text
);
COMMENT ON TABLE public.qualifications IS
  'Catalogue des qualifications reelles -- entites exigibles par du code, distinctes des chaines decoratives CAREERS[].comp. VIDE au 12 octobre 2026 : son contenu est un arbitrage de game design, non invente par la migration qui cree la table.';

-- ============================================================================================
-- 2. LES QUALIFICATIONS D'UN PERSONNAGE
-- ============================================================================================
-- `source` dit D'OU elle vient, et c'est ce champ qui porte le slot a vie : une seule ligne de
-- source 'universite' est possible par personnage, garantie par un index unique partiel.
--
-- AUCUN PERSONNAGE EXISTANT NE RECOIT QUOI QUE CE SOIT. La table nait vide, et rien dans cette
-- migration ne deduit une qualification de `career`, de `comp`, de `school` ni d'`archetype` --
-- l'inventaire a montre que ces quatre champs sont decoratifs a 95 %, et en faire des
-- qualifications serait un arbitrage.
CREATE TABLE IF NOT EXISTS public.personnages_qualifications (
  personnage     text NOT NULL,
  qualification  text NOT NULL REFERENCES public.qualifications(id),
  source         text NOT NULL CHECK (source IN ('creation', 'universite', 'autre')),
  acquise_le     timestamptz NOT NULL DEFAULT now(),
  inscription_id text,
  PRIMARY KEY (personnage, qualification)
);
CREATE UNIQUE INDEX IF NOT EXISTS personnages_une_seule_qualif_universitaire
  ON public.personnages_qualifications (personnage) WHERE source = 'universite';
COMMENT ON INDEX public.personnages_une_seule_qualif_universitaire IS
  'LE SLOT A VIE, porte par la base et non par du code : un personnage ne peut pas detenir deux qualifications de source universitaire. Index unique PARTIEL -- les qualifications de creation ou autres ne sont pas limitees.';

-- ============================================================================================
-- 3. LE CATALOGUE DES CURSUS -- VIDE
-- ============================================================================================
-- `semaines_theoriques` est la duree de reference. La limite est EXACTEMENT son double, et elle
-- n'est pas stockee en semaines : elle est calculee en dates calendaires de Paris a
-- l'inscription, pour que les changements d'heure ne la deplacent pas.
--
-- `cout_pa` / `cout_fr` sont le cout d'INSCRIPTION, prélevé une fois. Ils ne peuvent pas
-- raccourcir le cursus : aucune porte ne lit un montant pour avancer une date.
CREATE TABLE IF NOT EXISTS public.universite_cursus (
  id                   text PRIMARY KEY,
  libelle              text NOT NULL,
  qualification        text NOT NULL REFERENCES public.qualifications(id),
  semaines_theoriques  integer NOT NULL CHECK (semaines_theoriques > 0),
  cout_pa              integer NOT NULL DEFAULT 0 CHECK (cout_pa >= 0),
  cout_fr              integer NOT NULL DEFAULT 0 CHECK (cout_fr >= 0),
  prerequis            jsonb,
  note                 text
);
COMMENT ON TABLE public.universite_cursus IS
  'Catalogue des cursus universitaires. VIDE au 12 octobre 2026 : durees, jalons, couts et prerequis sont des arbitrages de game design. `semaines_theoriques` est la duree de reference ; la limite est exactement son double, calculee en dates de Paris a l''inscription.';

-- ============================================================================================
-- 4. LE MODELE DES JALONS -- VIDE
-- ============================================================================================
-- UN JALON EST SOIT UNIVERSITAIRE, SOIT DE TERRAIN. Le genre 'terrain' porte un batiment, une
-- ville et une piece optionnels : c'est par la qu'un futur cursus se raccordera a une VRAIE
-- activite de batiment (banque, notaire, EHPAD...) au lieu d'un bouton generique « Faire un
-- stage ». Ce raccordement n'est PAS fait ici -- seule la place pour l'accueillir existe.
--
-- `rang` est la SEMAINE du cursus, a partir de 1. C'est lui qui interdit l'acceleration : un
-- jalon ne peut pas etre accompli avant que sa semaine ne soit ouverte.
CREATE TABLE IF NOT EXISTS public.universite_cursus_jalons (
  id         text PRIMARY KEY,
  cursus     text NOT NULL REFERENCES public.universite_cursus(id) ON DELETE CASCADE,
  rang       integer NOT NULL CHECK (rang >= 1),
  libelle    text NOT NULL,
  genre      text NOT NULL CHECK (genre IN ('universite', 'terrain')),
  batiment   text,
  ville      text,
  piece      text,
  note       text,
  CONSTRAINT universite_jalon_terrain_porte_un_lieu
    CHECK (genre <> 'terrain' OR batiment IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS universite_jalons_par_cursus
  ON public.universite_cursus_jalons (cursus, rang);
COMMENT ON TABLE public.universite_cursus_jalons IS
  'Modele des jalons d''un cursus. VIDE au 12 octobre 2026. `rang` est la semaine du cursus (>=1) : un jalon ne peut jamais etre accompli avant l''ouverture de sa semaine, et c''est ce qui rend la duree incompressible. Le genre terrain porte un batiment : c''est le point de raccordement a une vraie activite de batiment, non branche dans cette passe.';

-- ============================================================================================
-- 5. LES INSCRIPTIONS
-- ============================================================================================
-- `fin_theorique_le` et `limite_le` sont FIGEES A L'INSCRIPTION. Les recalculer a la lecture
-- aurait permis a un changement de catalogue de deplacer la limite d'un cursus deja commence.
--
-- UN SEUL CURSUS ACTIF : index unique partiel sur `personnage WHERE statut = 'en_cours'`. La
-- garantie est dans la base, pas dans une fonction.
CREATE TABLE IF NOT EXISTS public.universite_inscriptions (
  id                   text PRIMARY KEY,
  personnage           text NOT NULL,
  cursus               text NOT NULL REFERENCES public.universite_cursus(id),
  semaines_theoriques  integer NOT NULL CHECK (semaines_theoriques > 0),
  debut_le             timestamptz NOT NULL,
  fin_theorique_le     timestamptz NOT NULL,
  limite_le            timestamptz NOT NULL,
  statut               text NOT NULL CHECK (statut IN ('en_cours', 'diplome', 'abandonne', 'expire')),
  clos_le              timestamptz,
  requete              text,
  CONSTRAINT universite_limite_apres_fin_theorique CHECK (limite_le > fin_theorique_le),
  CONSTRAINT universite_clos_coherent
    CHECK ((statut = 'en_cours' AND clos_le IS NULL) OR (statut <> 'en_cours' AND clos_le IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS universite_un_seul_cursus_actif
  ON public.universite_inscriptions (personnage) WHERE statut = 'en_cours';
CREATE UNIQUE INDEX IF NOT EXISTS universite_inscription_une_par_requete
  ON public.universite_inscriptions (requete) WHERE requete IS NOT NULL;
CREATE INDEX IF NOT EXISTS universite_inscriptions_par_personnage
  ON public.universite_inscriptions (personnage, statut);
COMMENT ON TABLE public.universite_inscriptions IS
  'Inscriptions a un cursus. UN SEUL cursus actif par personnage, garanti par index unique partiel. Les deux dates sont FIGEES a l''inscription : un changement de catalogue ne peut pas deplacer la limite d''un cursus commence. Statuts : en_cours, diplome, abandonne, expire -- seul `diplome` consomme le slot a vie, et il le consomme en ecrivant la qualification, pas en posant un drapeau.';

-- ============================================================================================
-- 6. LES JALONS ACCOMPLIS
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.universite_jalons_accomplis (
  inscription  text NOT NULL REFERENCES public.universite_inscriptions(id) ON DELETE CASCADE,
  jalon        text NOT NULL REFERENCES public.universite_cursus_jalons(id),
  accompli_le  timestamptz NOT NULL DEFAULT now(),
  requete      text,
  PRIMARY KEY (inscription, jalon)
);
CREATE UNIQUE INDEX IF NOT EXISTS universite_jalon_une_par_requete
  ON public.universite_jalons_accomplis (requete) WHERE requete IS NOT NULL;
COMMENT ON TABLE public.universite_jalons_accomplis IS
  'Un jalon accompli, date PAR LE SERVEUR. La cle primaire (inscription, jalon) interdit de l''accomplir deux fois : c''est la seconde barriere contre l''acceleration par repetition, la premiere etant l''ouverture de la semaine du jalon.';

-- ============================================================================================
-- 7. RLS : FERMEE PARTOUT. Les clients lisent par les portes.
-- ============================================================================================
ALTER TABLE public.qualifications                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personnages_qualifications    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.universite_cursus             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.universite_cursus_jalons      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.universite_inscriptions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.universite_jalons_accomplis   ENABLE ROW LEVEL SECURITY;

-- AUCUN GRANT CLIENT SUR CES SIX TABLES, ET C'EST LA VRAIE PORTE. La doctrine du projet le dit :
-- une policy sans GRANT est dormante, un GRANT sans policy est ouvert. Ici il n'y a ni l'un ni
-- l'autre pour anon/authenticated -- tout passe par les fonctions SECURITY DEFINER ci-dessous.
REVOKE ALL ON public.qualifications              FROM anon, authenticated;
REVOKE ALL ON public.personnages_qualifications  FROM anon, authenticated;
REVOKE ALL ON public.universite_cursus           FROM anon, authenticated;
REVOKE ALL ON public.universite_cursus_jalons    FROM anon, authenticated;
REVOKE ALL ON public.universite_inscriptions     FROM anon, authenticated;
REVOKE ALL ON public.universite_jalons_accomplis FROM anon, authenticated;

-- ============================================================================================
-- 8. LES DATES, EN CALENDRIER DE PARIS
-- ============================================================================================
-- Meme doctrine que le calendrier electoral : jamais +N x 24 h. Une duree en semaines est une
-- duree CALENDAIRE, donc un cursus de six semaines dure six semaines murales, changement d'heure
-- compris.
CREATE OR REPLACE FUNCTION public.universite_plus_semaines(p_ts timestamptz, p_semaines integer)
RETURNS timestamptz LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT (((p_ts AT TIME ZONE 'Europe/Paris') + (p_semaines * interval '7 days')) AT TIME ZONE 'Europe/Paris');
$$;
COMMENT ON FUNCTION public.universite_plus_semaines(timestamptz, integer) IS
  'N semaines CALENDAIRES de Paris apres un instant. Jamais +N x 24 h : meme doctrine que le calendrier electoral, pour qu''un cursus qui enjambe un changement d''heure dure bien N semaines murales.';

-- ============================================================================================
-- 9. LE SLOT A VIE -- DERIVE, JAMAIS STOCKE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_slot_consomme(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_qualifications q
                  WHERE q.personnage = p_nom AND q.source = 'universite');
$$;
COMMENT ON FUNCTION public.universite_slot_consomme(text) IS
  'Le slot universitaire a vie est-il consomme ? DERIVE de l''existence d''une qualification de source universitaire -- il n''existe aucune colonne « slot consomme », donc rien ne peut se desynchroniser, et rien ne peut le restaurer sans retirer la qualification elle-meme.';

-- ============================================================================================
-- 10. L'ETAT UNIVERSITAIRE D'UN JOUEUR -- LECTURE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_mon_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_ins record; v_jalons jsonb; v_total integer; v_faits integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_ins FROM public.universite_inscriptions
   WHERE personnage = v_moi AND statut = 'en_cours' LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'cursus_actif', NULL,
      'slot_consomme', public.universite_slot_consomme(v_moi),
      'qualifications', (SELECT coalesce(jsonb_agg(jsonb_build_object(
          'qualification', q.qualification, 'libelle', c.libelle,
          'source', q.source, 'acquise_le', q.acquise_le) ORDER BY q.acquise_le), '[]'::jsonb)
        FROM public.personnages_qualifications q
        LEFT JOIN public.qualifications c ON c.id = q.qualification
        WHERE q.personnage = v_moi),
      'cursus_disponibles', (SELECT coalesce(jsonb_agg(jsonb_build_object(
          'id', u.id, 'libelle', u.libelle, 'qualification', u.qualification,
          'semaines_theoriques', u.semaines_theoriques,
          'cout_pa', u.cout_pa, 'cout_fr', u.cout_fr) ORDER BY u.id), '[]'::jsonb)
        FROM public.universite_cursus u));
  END IF;

  -- LES JALONS, AVEC LA SEMAINE A LAQUELLE CHACUN S'OUVRE. Un jalon dont la semaine n'est pas
  -- ouverte est rendu comme tel : le navigateur ne peut donc pas en proposer l'accomplissement,
  -- et la porte le refuserait de toute facon.
  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', j.id, 'rang', j.rang, 'libelle', j.libelle, 'genre', j.genre,
      'batiment', j.batiment, 'ville', j.ville, 'piece', j.piece,
      'ouvre_le', public.universite_plus_semaines(v_ins.debut_le, j.rang - 1),
      'ouvert', now() >= public.universite_plus_semaines(v_ins.debut_le, j.rang - 1),
      'accompli', (a.jalon IS NOT NULL),
      'accompli_le', a.accompli_le) ORDER BY j.rang, j.id), '[]'::jsonb),
    count(*), count(a.jalon)
    INTO v_jalons, v_total, v_faits
    FROM public.universite_cursus_jalons j
    LEFT JOIN public.universite_jalons_accomplis a
           ON a.jalon = j.id AND a.inscription = v_ins.id
   WHERE j.cursus = v_ins.cursus;

  RETURN jsonb_build_object('ok', true,
    'slot_consomme', public.universite_slot_consomme(v_moi),
    'cursus_actif', jsonb_build_object(
      'inscription', v_ins.id, 'cursus', v_ins.cursus,
      'semaines_theoriques', v_ins.semaines_theoriques,
      'debut_le', v_ins.debut_le, 'fin_theorique_le', v_ins.fin_theorique_le,
      'limite_le', v_ins.limite_le,
      'duree_atteinte', now() >= v_ins.fin_theorique_le,
      'expire', now() > v_ins.limite_le,
      'jalons_total', v_total, 'jalons_accomplis', v_faits,
      'diplomable', (v_faits = v_total AND now() >= v_ins.fin_theorique_le AND now() <= v_ins.limite_le),
      'jalons', v_jalons));
END;
$$;

-- ============================================================================================
-- 11. S'INSCRIRE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_inscrire(p_cursus text, p_requete text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_cur record; v_id text; v_debut timestamptz := now(); v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NOT NULL AND p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;

  -- REJEU : meme convention que partout dans le projet.
  IF p_requete IS NOT NULL THEN
    SELECT id INTO v_id FROM public.universite_inscriptions WHERE requete = p_requete;
    IF v_id IS NOT NULL THEN
      RETURN jsonb_build_object('ok', true, 'rejeu', true, 'inscription', v_id);
    END IF;
  END IF;

  SELECT * INTO v_cur FROM public.universite_cursus WHERE id = p_cursus;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cursus_inconnu'); END IF;

  -- LE SLOT A VIE. Une qualification universitaire deja obtenue ferme definitivement la porte.
  IF public.universite_slot_consomme(v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'slot_universitaire_deja_consomme');
  END IF;

  -- UN SEUL CURSUS ACTIF. L'index unique partiel garde aussi, mais un refus nomme vaut mieux
  -- qu'une violation de contrainte remontee au joueur.
  IF EXISTS (SELECT 1 FROM public.universite_inscriptions
              WHERE personnage = v_moi AND statut = 'en_cours') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cursus_deja_en_cours');
  END IF;

  v_id := 'ins-' || left(md5(v_moi || '|' || p_cursus || '|' || coalesce(p_requete, v_debut::text)), 20);

  INSERT INTO public.universite_inscriptions
    (id, personnage, cursus, semaines_theoriques, debut_le, fin_theorique_le, limite_le, statut, requete)
  VALUES (v_id, v_moi, p_cursus, v_cur.semaines_theoriques, v_debut,
          public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques),
          -- LA LIMITE EST EXACTEMENT LE DOUBLE DE LA DUREE THEORIQUE.
          public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques * 2),
          'en_cours', p_requete)
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inscription_deja_posee'); END IF;

  RETURN jsonb_build_object('ok', true, 'inscription', v_id,
    'semaines_theoriques', v_cur.semaines_theoriques,
    'fin_theorique_le', public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques),
    'limite_le', public.universite_plus_semaines(v_debut, v_cur.semaines_theoriques * 2));
END;
$$;

-- ============================================================================================
-- 12. ABANDONNER -- LE SLOT N'EST PAS CONSOMME
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_abandonner(p_requete text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_id text; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  UPDATE public.universite_inscriptions
     SET statut = 'abandonne', clos_le = now()
   WHERE personnage = v_moi AND statut = 'en_cours'
  RETURNING id INTO v_id;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_cursus_en_cours'); END IF;

  -- RIEN N'EST ECRIT DANS personnages_qualifications : le slot a vie reste disponible, et c'est
  -- la regle. Un abandon n'est pas un echec de qualification, c'est l'absence de qualification.
  RETURN jsonb_build_object('ok', true, 'inscription', v_id, 'statut', 'abandonne',
    'slot_consomme', public.universite_slot_consomme(v_moi));
END;
$$;

-- ============================================================================================
-- 13. ACCOMPLIR UN JALON -- ET L'IMPOSSIBILITE D'ACCELERER
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_jalon_accomplir(p_jalon text, p_requete text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_ins record; v_jal record; v_ouvre timestamptz; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NOT NULL AND p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;

  SELECT * INTO v_ins FROM public.universite_inscriptions
   WHERE personnage = v_moi AND statut = 'en_cours' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_cursus_en_cours'); END IF;

  SELECT * INTO v_jal FROM public.universite_cursus_jalons WHERE id = p_jalon;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'jalon_inconnu'); END IF;
  IF v_jal.cursus <> v_ins.cursus THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jalon_hors_cursus');
  END IF;

  -- LE CURSUS EXPIRE N'ACCEPTE PLUS RIEN.
  IF now() > v_ins.limite_le THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cursus_expire', 'limite_le', v_ins.limite_le);
  END IF;

  -- VOICI CE QUI REND LA DUREE INCOMPRESSIBLE, ET IL N'Y A RIEN D'AUTRE A AJOUTER. Un jalon de
  -- rang N s'ouvre N-1 semaines apres le debut du cursus. Aucune quantite de PA, aucune somme
  -- d'argent et aucune repetition ne peuvent avancer cette date : elle est derivee de
  -- `debut_le`, que seule l'inscription ecrit.
  v_ouvre := public.universite_plus_semaines(v_ins.debut_le, v_jal.rang - 1);
  IF now() < v_ouvre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'semaine_non_ouverte',
      'rang', v_jal.rang, 'ouvre_le', v_ouvre);
  END IF;

  INSERT INTO public.universite_jalons_accomplis (inscription, jalon, requete)
  VALUES (v_ins.id, p_jalon, p_requete)
  ON CONFLICT (inscription, jalon) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'jalon_deja_accompli');
  END IF;

  RETURN jsonb_build_object('ok', true, 'jalon', p_jalon, 'rang', v_jal.rang);
END;
$$;

-- ============================================================================================
-- 14. SE DIPLOMER -- LE SEUL ACTE QUI CONSOMME LE SLOT
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_diplomer(p_requete text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_ins record; v_cur record; v_total integer; v_faits integer; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO v_ins FROM public.universite_inscriptions
   WHERE personnage = v_moi AND statut = 'en_cours' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_cursus_en_cours'); END IF;

  IF now() > v_ins.limite_le THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cursus_expire', 'limite_le', v_ins.limite_le);
  END IF;
  -- LA DUREE THEORIQUE EST UN MINIMUM, PAS UNE ESTIMATION. Meme tous les jalons accomplis ne
  -- diplomsent pas avant son terme.
  IF now() < v_ins.fin_theorique_le THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'duree_theorique_non_atteinte',
      'fin_theorique_le', v_ins.fin_theorique_le);
  END IF;

  SELECT count(*), count(a.jalon) INTO v_total, v_faits
    FROM public.universite_cursus_jalons j
    LEFT JOIN public.universite_jalons_accomplis a
           ON a.jalon = j.id AND a.inscription = v_ins.id
   WHERE j.cursus = v_ins.cursus;
  IF v_faits < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jalons_incomplets',
      'accomplis', v_faits, 'total', v_total);
  END IF;

  IF public.universite_slot_consomme(v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'slot_universitaire_deja_consomme');
  END IF;

  SELECT * INTO v_cur FROM public.universite_cursus WHERE id = v_ins.cursus;

  -- LE SLOT SE CONSOMME EN ECRIVANT LA QUALIFICATION, jamais en posant un drapeau. L'index
  -- unique partiel `personnages_une_seule_qualif_universitaire` est la seconde barriere : deux
  -- appels simultanes ne peuvent pas ecrire deux qualifications universitaires.
  INSERT INTO public.personnages_qualifications
    (personnage, qualification, source, inscription_id)
  VALUES (v_moi, v_cur.qualification, 'universite', v_ins.id)
  ON CONFLICT (personnage, qualification) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'qualification_deja_detenue');
  END IF;

  UPDATE public.universite_inscriptions
     SET statut = 'diplome', clos_le = now()
   WHERE id = v_ins.id;

  RETURN jsonb_build_object('ok', true, 'inscription', v_ins.id,
    'qualification', v_cur.qualification, 'slot_consomme', true);
END;
$$;

-- ============================================================================================
-- 15. EXPIRER LES CURSUS ECHUS -- PORTE SERVEUR
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.universite_expirer_echues()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_n integer;
BEGIN
  -- AU-DELA DE LA LIMITE, LE CURSUS EST ECHOUE ET LE SLOT RESTE DISPONIBLE. Rien n'est ecrit
  -- dans personnages_qualifications : c'est toute la difference avec un diplome.
  UPDATE public.universite_inscriptions
     SET statut = 'expire', clos_le = now()
   WHERE statut = 'en_cours' AND now() > limite_le;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'expires', v_n);
END;
$$;

-- ============================================================================================
-- 16. DROITS
-- ============================================================================================
REVOKE ALL ON FUNCTION public.universite_plus_semaines(timestamptz, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.universite_slot_consomme(text)                 FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.universite_mon_etat()                          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.universite_inscrire(text, text)                FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.universite_abandonner(text)                    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.universite_jalon_accomplir(text, text)         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.universite_diplomer(text)                      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.universite_expirer_echues()                    FROM PUBLIC, anon, authenticated;

-- LE JOUEUR N'OBTIENT QUE LES QUATRE ACTES QUI SONT LES SIENS, PLUS LA LECTURE DE SON ETAT.
GRANT EXECUTE ON FUNCTION public.universite_mon_etat()                  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.universite_inscrire(text, text)        TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.universite_abandonner(text)            TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.universite_jalon_accomplir(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.universite_diplomer(text)              TO authenticated, service_role;
-- L'EXPIRATION N'EST PAS A LA MAIN DES JOUEURS : seul le serveur la declenche.
GRANT EXECUTE ON FUNCTION public.universite_expirer_echues()            TO service_role;
-- Les deux fonctions de calcul sont internes.
GRANT EXECUTE ON FUNCTION public.universite_plus_semaines(timestamptz, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.universite_slot_consomme(text)                TO service_role;

-- ============================================================================================
-- 17. PREUVES STRUCTURELLES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : les six tables existent et portent la RLS.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
     AND c.relname IN ('qualifications','personnages_qualifications','universite_cursus',
                       'universite_cursus_jalons','universite_inscriptions','universite_jalons_accomplis');
  IF v_n <> 6 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % table(s) sur 6 avec RLS', v_n; END IF;

  -- P2 : AUCUN DROIT CLIENT SUR LES SIX TABLES. C'est la vraie porte.
  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND grantee IN ('anon','authenticated')
     AND table_name IN ('qualifications','personnages_qualifications','universite_cursus',
                        'universite_cursus_jalons','universite_inscriptions','universite_jalons_accomplis');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % droit(s) client sur les tables du socle', v_n; END IF;

  -- P3 : LE SLOT A VIE EST PORTE PAR LA BASE. Index unique partiel sur la source universitaire.
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public'
                  AND indexname='personnages_une_seule_qualif_universitaire') THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le slot a vie n''est pas garanti par un index';
  END IF;

  -- P4 : UN SEUL CURSUS ACTIF, garanti par la base et non par du code.
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public'
                  AND indexname='universite_un_seul_cursus_actif') THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- rien n''interdit deux cursus actifs';
  END IF;

  -- P5 : LA LIMITE EST STRUCTURELLEMENT APRES LA FIN THEORIQUE.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conname = 'universite_limite_apres_fin_theorique') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la limite pourrait preceder la fin theorique';
  END IF;

  -- P6 : LA LIMITE VAUT EXACTEMENT LE DOUBLE. Verifie dans le TEXTE de la porte d'inscription,
  --      parce qu'aucune contrainte ne peut exprimer « le double » sans la duree theorique.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname='universite_inscrire';
  IF position('semaines_theoriques * 2' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la limite n''est plus le double de la duree theorique';
  END IF;

  -- P7 : L'ACCELERATION EST IMPOSSIBLE. La porte des jalons lit l'ouverture de la semaine, et
  --      aucune porte du socle ne lit un montant de PA ou d'argent.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname='universite_jalon_accomplir';
  IF position('semaine_non_ouverte' IN v_txt) = 0 OR position('v_jal.rang - 1' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- un jalon peut etre accompli avant l''ouverture de sa semaine';
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname LIKE 'universite\_%'
     AND (position('payer_ordre' IN pg_get_functiondef(p.oid)) > 0
       OR position('liquide' IN pg_get_functiondef(p.oid)) > 0);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- % porte(s) du socle touchent a l''argent ou aux PA', v_n;
  END IF;

  -- P8 : SEUL LE DIPLOME ECRIT UNE QUALIFICATION.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname LIKE 'universite\_%'
     AND position('INSERT INTO public.personnages_qualifications' IN pg_get_functiondef(p.oid)) > 0;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- % porte(s) ecrivent une qualification au lieu d''une seule', v_n;
  END IF;
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace AND p.proname='universite_diplomer';
  IF position('INSERT INTO public.personnages_qualifications' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- ce n''est pas le diplome qui ecrit la qualification';
  END IF;

  -- P9 : NI L'ABANDON NI L'EXPIRATION N'ECRIVENT DE QUALIFICATION -- le slot reste disponible.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace='public'::regnamespace
     AND p.proname IN ('universite_abandonner','universite_expirer_echues')
     AND position('personnages_qualifications' IN pg_get_functiondef(p.oid)) > 0
     AND position('INSERT INTO public.personnages_qualifications' IN pg_get_functiondef(p.oid)) > 0;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P9 ECHOUEE -- un abandon ou une expiration consomme le slot'; END IF;

  -- P10 : AUCUN PERSONNAGE N'A RECU DE QUALIFICATION, et les cinq catalogues sont vides.
  SELECT count(*) INTO v_n FROM public.personnages_qualifications;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P10 ECHOUEE -- % qualification(s) attribuee(s) par la migration', v_n; END IF;
  SELECT (SELECT count(*) FROM public.qualifications)
       + (SELECT count(*) FROM public.universite_cursus)
       + (SELECT count(*) FROM public.universite_cursus_jalons)
       + (SELECT count(*) FROM public.universite_inscriptions)
       + (SELECT count(*) FROM public.universite_jalons_accomplis) INTO v_n;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P10 ECHOUEE -- % ligne(s) inventee(s) dans les catalogues', v_n; END IF;

  -- P11 : L'ANCIEN ORDRE A PERDU SON COUT.
  IF EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'se_former') THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- se_former a encore un cout declare';
  END IF;

  -- P12 : LE SLOT EST DERIVE, PAS STOCKE. Aucune colonne du socle ne le nomme.
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema='public' AND column_name ILIKE '%slot%'
     AND table_name LIKE 'universite\_%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P12 ECHOUEE -- % colonne(s) de slot stocke', v_n; END IF;

  RAISE NOTICE 'LES 12 PREUVES SONT VERTES.';
END
$preuves$;
