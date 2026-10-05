-- =====================================================================
-- CAISSES INSTITUTIONNELLES : LE SOCLE D'AUTORITE
-- 19 septembre 2026
-- =====================================================================
--
-- OBJET
-- -----
-- Ce fichier ferme l'exploit demontre au banc : un joueur ordinaire, sans aucun
-- poste, vidait republic_palais-presidentiel (88 604 -> 0) et creait de toutes
-- pieces une caisse a 99 000 000. Le seul controle etait « mon_personnage()
-- n'est pas nul », c'est-a-dire « il existe un personnage ».
--
-- Il pose les trois objets dont depend tout le chantier des caisses :
--   * caisses_mouvements_clients  -- le journal d'observation des mouvements ;
--   * caisses_autorites           -- le registre « quel poste repond de quelle
--                                    caisse » ;
--   * caisse_postes_requis()      -- la derivation du poste requis a partir de
--                                    l'identifiant de caisse.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES
-- ----------------------------------
--   20260919224608  caisse_institution_autorite_lot1
--   20260919232818  caisse_autorite_par_batiment
--
-- POURQUOI LES DEUX DANS UN SEUL FICHIER. Elles forment un seul chantier, a
-- cinquante minutes d'intervalle : la premiere cree le journal et la porte
-- cliente caisse_client_mouvement, la seconde ajoute le registre d'autorite et
-- REDEFINIT cette meme porte pour qu'elle exige un poste. Les separer
-- obligerait a versionner une version intermediaire de caisse_client_mouvement
-- remplacee le soir meme. Seule la version FINALE figure ici.
--
-- POURQUOI CE FICHIER EXISTE
-- --------------------------
-- Le rattrapage du 20 septembre a revele que ces deux migrations n'etaient
-- versionnees dans aucun fichier du depot, alors que
-- migration_20260920_caisses_marqueur_interne.sql en depend de trois facons :
--   * la section DONNEES alimente caisses_autorites -- table creee ici ;
--   * les deux primitives durcies lisent caisse_postes_requis() -- creee ici ;
--   * elles ecrivent dans caisses_mouvements_clients -- creee ici.
-- Sans ce fichier, une base reconstruite depuis le depot ne pouvait pas
-- atteindre l'etat attendu.
--
-- LES DEUX RAISONNEMENTS QUI FONDENT LE LOT
-- -----------------------------------------
-- 1. POURQUOI LA REVOCATION SUFFIT, ET NE CASSE PAS LES APPELANTS INTERNES.
--    caisse_institution_mouvement est appelee par 13 fonctions SQL, toutes
--    SECURITY DEFINER et proprietaire postgres, toutes deja gardees par leur
--    propre controle d'autorite. A l'interieur d'une fonction SECURITY DEFINER,
--    l'utilisateur effectif est le PROPRIETAIRE : le test du droit EXECUTE
--    porte donc sur postgres, pas sur le joueur. Revoquer le droit au
--    navigateur ne les touche pas.
--
--    PIEGE ECARTE : on ne peut PAS distinguer l'appel interne de l'appel direct
--    avec est_appel_serveur(). Une RPC SECURITY DEFINER declenchee par un joueur
--    porte toujours les claims JWT de ce joueur -- est_appel_serveur() y repond
--    false. Seul le droit EXECUTE separe reellement les deux mondes.
--    (Le 20 septembre reviendra sur ce point avec le marqueur rp.caisse_interne,
--    rendu necessaire parce que le bundle deploye appelait encore la primitive
--    en direct : on ne pouvait alors plus la revoquer sans casser le client.)
--
-- 2. ASYMETRIE DEBIT / CREDIT, ET ELLE EST FONDEE.
--    DEBIT  = sortir de l'argent public. Exige le poste qui repond de cette
--             caisse. C'est l'exploit demontre par l'audit.
--    CREDIT = verser dans une caisse publique. 17 des 29 sites du jeu sont des
--             recettes (taxe, vente, amende, cotisation) versees par un citoyen
--             ordinaire, qui n'a par construction aucun poste. Les exiger d'un
--             poste casserait l'economie entiere sans fermer aucun exploit :
--             donner de l'argent a l'Etat n'est pas une attaque. La creation
--             monetaire, elle, est fermee ailleurs -- c'est la fiche du joueur
--             qui ne doit pas pouvoir fabriquer la somme versee.
--
--    Les caisses NON institutionnelles (marche, hotel, stade, dispensaire, port,
--    lieux de culte...) n'ont pas de poste titulaire identifiable : leurs debits
--    restent ouverts et JOURNALISES, en attendant que chaque mecanique marchande
--    porte elle-meme son autorite. C'est dit tel quel, pas presente comme ferme.
--
-- AVERTISSEMENT
-- -------------
-- Ce fichier reproduit un ETAT FINAL, pas un historique. Il est idempotent et
-- rejouable, mais il ne rejoue pas la version intermediaire de
-- caisse_client_mouvement posee a 22:46 puis remplacee a 23:28.
--
-- DEPENDANCES — a rejouer AVANT ce fichier
-- ----------------------------------------
--   migration_caisse_institution.sql  -- caisse_institution_mouvement et
--                                        caisse_institution_mouvement_plafonne,
--                                        appelees et revoquees plus bas.
--   public.caisses_batiments          -- lue pour le solde.
--   public.personnages_donnees        -- lue pour le pays de l'acteur.
--   public.mon_personnage()           -- identite de l'appelant.
--   public.acteur_poste_courant()     -- poste atteste de l'appelant.
--
-- NON VERSIONNEES DANS LE DEPOT, et ce fichier ne les cree pas :
--   mon_personnage() et acteur_poste_courant() n'ont aucun fichier createur.
--   Elles viennent des migrations de production 20260913120554
--   (chantier_b_ossature_identite_auth) et 20260915193552
--   (commissariat_arrestation_urgence). Le schema se cree sans elles ; c'est
--   l'EXECUTION de caisse_client_mouvement qui les exige.
--
-- ORDRE DE REJEU
-- --------------
--   migration_caisse_institution.sql
--     -> CE FICHIER
--       -> migration_20260920_caisses_marqueur_interne.sql
--         -> migration_20260920_entrepot_reversement_mairie.sql
-- =====================================================================


-- =====================================================================
-- 1. LE JOURNAL D'OBSERVATION — migration 20260919224608
-- =====================================================================
-- Tout mouvement demande par un client y est consigne, accepte ou refuse, avec
-- sa raison. C'est ce qui a permis de mesurer l'exploit plutot que de le
-- supposer.

CREATE TABLE IF NOT EXISTS public.caisses_mouvements_clients (
  id          bigserial PRIMARY KEY,
  acteur      text,
  caisse      text        NOT NULL,
  delta       numeric     NOT NULL,
  motif       text,
  accepte     boolean     NOT NULL,
  raison      text,
  vu_le       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS caisses_mouvements_clients_idx
  ON public.caisses_mouvements_clients (caisse, vu_le DESC);

-- RLS active SANS aucune politique = table close. Le REVOKE explicite est
-- indispensable : les DEFAULT PRIVILEGES du schema public reaccordent arwdDxtm
-- a anon sur toute table creee -- piege connu du projet.
ALTER TABLE public.caisses_mouvements_clients ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.caisses_mouvements_clients FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.caisses_mouvements_clients_id_seq FROM PUBLIC, anon, authenticated;


-- =====================================================================
-- 2. LE REGISTRE D'AUTORITE — migration 20260919232818
-- =====================================================================
-- LE MODELE REPRIS, ET IL EXISTAIT DEJA : caisse_ministere_mouvement derive le
-- poste requis DE L'IDENTIFIANT DE LA CAISSE (<pays>_gouvernement-<poste>) puis
-- appelle exiger_poste(). On generalise exactement ce raisonnement a toutes les
-- caisses institutionnelles, via un registre -- plutot que d'ecrire une RPC par
-- batiment.

CREATE TABLE IF NOT EXISTS public.caisses_autorites (
  motif        text PRIMARY KEY,   -- suffixe de batiment, apres <pays>_
  est_prefixe  boolean NOT NULL DEFAULT false,
  postes_debit text[]  NOT NULL,
  note         text
);
ALTER TABLE public.caisses_autorites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.caisses_autorites FROM PUBLIC, anon, authenticated;

-- Les NEUF lignes du 19 septembre. Les six suivantes (port, palais du
-- gouvernement, entrepot, usine pharmaceutique, raffinerie, pole tabac-alcools)
-- appartiennent au 20 septembre et sont posees par
-- migration_20260920_caisses_marqueur_interne.sql : elles ne sont PAS reprises
-- ici.
INSERT INTO public.caisses_autorites (motif, est_prefixe, postes_debit, note) VALUES
  ('palais-presidentiel', false, '{president}',              'presidence'),
  ('gouvernement-',       true,  '{}',                       'ministere : le poste est lu dans l identifiant'),
  ('assemblee',           false, '{}',                       'assemblee : chemin serveur dedie (assemblee_debiter_caisse_plafonne)'),
  ('mairie',              true,  '{maire,maire_adjoint}',    'mairies, toutes villes'),
  ('commissariat',        true,  '{commissaire,min_int}',    'commissariats'),
  ('tribunal',            true,  '{juge,min_just}',          'tribunaux'),
  ('caserne-militaire',   false, '{commandant,min_def}',     'caserne'),
  ('qhs-prison',          false, '{min_int,min_just}',       'quartier haute securite'),
  ('reserve-nationale',   false, '{min_fin}',                'reserve nationale')
ON CONFLICT (motif) DO UPDATE
  SET est_prefixe=EXCLUDED.est_prefixe, postes_debit=EXCLUDED.postes_debit, note=EXCLUDED.note;


-- =====================================================================
-- 3. LA DERIVATION DU POSTE REQUIS — migration 20260919232818
-- =====================================================================
-- Poste requis pour debiter une caisse donnee. NULL = caisse non
-- institutionnelle (aucune autorite identifiable a ce jour), '{}' = chemin
-- serveur uniquement.

CREATE OR REPLACE FUNCTION public.caisse_postes_requis(p_caisse text, p_pays text)
RETURNS text[]
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_suffixe text; r record; v_poste text;
BEGIN
  v_suffixe := regexp_replace(p_caisse, '^' || p_pays || '_', '');

  -- Ministere : le poste EST dans l'identifiant, comme le fait deja
  -- caisse_ministere_mouvement.
  v_poste := substring(v_suffixe from '^gouvernement-(.+)$');
  IF v_poste IS NOT NULL THEN RETURN ARRAY[v_poste]; END IF;

  SELECT * INTO r FROM public.caisses_autorites c
   WHERE (NOT c.est_prefixe AND c.motif = v_suffixe)
      OR (c.est_prefixe AND v_suffixe LIKE c.motif || '%')
   ORDER BY c.est_prefixe LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN r.postes_debit;
END;
$fn$;

REVOKE ALL ON FUNCTION public.caisse_postes_requis(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_postes_requis(text, text) TO authenticated, service_role;


-- =====================================================================
-- 4. LA PORTE CLIENTE — version finale, migration 20260919232818
-- =====================================================================
-- Seule fonction de caisse que le navigateur peut appeler. Elle journalise tout
-- refus dans caisses_mouvements_clients avant de le renvoyer.

CREATE OR REPLACE FUNCTION public.caisse_client_mouvement(
  p_caisse text, p_delta numeric, p_motif text DEFAULT NULL, p_plafonne boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_moi text; v_pays text; v_existe boolean; v_solde numeric; v_verse numeric;
  v_res jsonb; v_raison text; v_postes text[];
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  IF coalesce(btrim(p_caisse),'') = '' OR p_delta IS NULL OR p_delta = 0
     OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF v_pays IS NULL OR p_caisse NOT LIKE v_pays || '\_%' THEN
    v_raison := 'caisse_hors_pays';
  ELSE
    SELECT true, (data->>'solde')::numeric INTO v_existe, v_solde
      FROM public.caisses_batiments WHERE id = p_caisse;
    IF NOT coalesce(v_existe, false) THEN
      v_raison := 'caisse_inexistante';
    ELSIF p_delta < 0 OR p_plafonne THEN
      -- SORTIE D'ARGENT PUBLIC : autorite exigee.
      v_postes := public.caisse_postes_requis(p_caisse, v_pays);
      IF v_postes IS NOT NULL THEN
        IF array_length(v_postes, 1) IS NULL THEN
          v_raison := 'caisse_reservee_au_serveur';
        ELSIF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                           WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays) THEN
          v_raison := 'autorite_insuffisante';
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_raison IS NOT NULL THEN
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, p_delta, p_motif, false, v_raison);
    RETURN jsonb_build_object('ok', false, 'raison', v_raison);
  END IF;

  IF p_plafonne THEN
    v_verse := least(greatest(coalesce(v_solde,0), 0), abs(p_delta));
    IF v_verse <= 0 THEN
      INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
      VALUES (v_moi, p_caisse, p_delta, p_motif, false, 'solde_nul');
      RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', coalesce(v_solde,0));
    END IF;
    v_res := public.caisse_institution_mouvement(p_caisse, -v_verse, true);
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, -v_verse, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
    IF coalesce((v_res->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('ok', true, 'verse', v_verse,
        'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', v_res->>'raison', 'verse', 0);
  END IF;

  v_res := public.caisse_institution_mouvement(p_caisse, p_delta, true);
  INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
  VALUES (v_moi, p_caisse, p_delta, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
  IF coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true,
      'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
  END IF;
  RETURN v_res;
END;
$fn$;

REVOKE ALL ON FUNCTION public.caisse_client_mouvement(text, numeric, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_client_mouvement(text, numeric, text, boolean) TO authenticated, service_role;


-- =====================================================================
-- 5. FERMETURE DES DEUX PRIMITIVES — migration 20260919224608
-- =====================================================================
-- C'EST ICI QUE VIENNENT LES DROITS DU CHANTIER DES CAISSES.
-- migration_20260920_caisses_marqueur_interne.sql ne porte aucun GRANT ni
-- REVOKE : les trois migrations du 20 septembre n'en contiennent pas, parce que
-- CREATE OR REPLACE preserve l'ACL existante -- celle posee ci-dessous. Rejouer
-- le lot du 20 sans ce fichier laisserait donc les deux primitives ouvertes.

REVOKE EXECUTE ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.caisse_institution_mouvement_plafonne(text, numeric)
  FROM PUBLIC, anon, authenticated;
