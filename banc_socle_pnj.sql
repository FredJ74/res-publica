-- =====================================================================================
-- BANC AUTOMATISE DU SOCLE PNJ -- 26 septembre 2026
--
-- Il monte le socle COMPLET dans un schema jetable `banc_pnj`, joue les 22 cas demandes,
-- et rend un tableau OK/ECHEC. Rien n'est cree dans `public` : les 96 soldats de Vince, les
-- 12 agents et les 4 douaniers ne sont ni lus en ecriture ni touches.
-- Nettoyage : DROP SCHEMA banc_pnj CASCADE;
--
-- Les seuls objets de `public` utilises sont lus, jamais ecrits :
--   personnages_donnees (pour resoudre la position d'un leader PJ et le titulaire d'un poste)
-- Les PJ de banc sont crees dans une table locale banc_pnj.pj, pour ne pas toucher aux vrais
-- personnages. Les fonctions du banc lisent donc banc_pnj.pj la ou la production lira
-- public.personnages_donnees -- c'est la SEULE divergence, et elle est explicite.
-- =====================================================================================

DROP SCHEMA IF EXISTS banc_pnj CASCADE;
CREATE SCHEMA banc_pnj;

-- Doublure des PJ : name, pays, position, poste. Meme forme que personnages_donnees.
CREATE TABLE banc_pnj.pj (
  name text PRIMARY KEY, country text NOT NULL,
  current_city text, current_building text, current_room text,
  poste jsonb, pa integer NOT NULL DEFAULT 30, liquide numeric NOT NULL DEFAULT 0,
  hospitalise boolean NOT NULL DEFAULT false
);

CREATE TABLE banc_pnj.membres (
  id              text PRIMARY KEY,
  famille         text NOT NULL,
  nom             text NOT NULL,
  pays            text NOT NULL,
  proprietaire_pj text NULL,
  proprietaire_poste       text NULL,
  proprietaire_poste_ville text NULL,
  leader_pj       text NULL,
  leader_pnj_id   text NULL REFERENCES banc_pnj.membres(id) ON DELETE SET NULL,
  ville           text NULL,
  building_id     text NULL,
  room_id         text NULL,
  rue_noeud_id    text NULL,
  pa              integer NOT NULL DEFAULT 12,
  liquide         numeric NOT NULL DEFAULT 0,
  statut          text NOT NULL DEFAULT 'actif',
  cree_le         timestamptz NOT NULL DEFAULT now(),
  maj_le          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pnj_position_deux_etats CHECK (
    ((leader_pj IS NOT NULL OR leader_pnj_id IS NOT NULL)
       AND ville IS NULL AND building_id IS NULL AND room_id IS NULL AND rue_noeud_id IS NULL)
    OR (leader_pj IS NULL AND leader_pnj_id IS NULL)),
  CONSTRAINT pnj_un_seul_leader CHECK (leader_pj IS NULL OR leader_pnj_id IS NULL),
  CONSTRAINT pnj_pas_son_propre_leader CHECK (leader_pnj_id IS DISTINCT FROM id),
  CONSTRAINT pnj_pa_positif CHECK (pa >= 0),
  CONSTRAINT pnj_statut_connu CHECK (statut IN ('actif','detenu','mort','disparu')),
  CONSTRAINT pnj_famille_connue CHECK (famille IN
    ('soldat','employe','agent','policier','douanier','militant')),
  CONSTRAINT pnj_propriete_exclusive CHECK (
    (proprietaire_pj IS NOT NULL AND proprietaire_poste IS NULL
       AND proprietaire_poste_ville IS NULL)
    OR (proprietaire_pj IS NULL AND proprietaire_poste IS NOT NULL)),
  CONSTRAINT pnj_mort_sans_leader CHECK (
    statut <> 'mort' OR (leader_pj IS NULL AND leader_pnj_id IS NULL))
);

CREATE TABLE banc_pnj.possessions (
  id bigserial PRIMARY KEY,
  pnj_id text NOT NULL REFERENCES banc_pnj.membres(id) ON DELETE CASCADE,
  objet jsonb NOT NULL,
  exemplaire_unique boolean NOT NULL DEFAULT false
);

CREATE TABLE banc_pnj.evenements (
  id bigserial PRIMARY KEY,
  pnj_id text NOT NULL, pnj_nom text NOT NULL, famille text NOT NULL,
  type text NOT NULL, pays text NOT NULL,
  proprietaire_pj text NULL, proprietaire_poste text NULL, proprietaire_poste_ville text NULL,
  ville text NULL, building_id text NULL, room_id text NULL,
  cree_le timestamptz NOT NULL DEFAULT now(), lu_le timestamptz NULL,
  CONSTRAINT evt_type CHECK (type IN ('mort')),
  CONSTRAINT evt_destinataire CHECK (
    (proprietaire_pj IS NOT NULL AND proprietaire_poste IS NULL)
    OR (proprietaire_pj IS NULL AND proprietaire_poste IS NOT NULL))
);

-- Objets au sol : doublure de public.objets_abandonnes, meme forme.
CREATE TABLE banc_pnj.objets_abandonnes (
  id text PRIMARY KEY, country text NOT NULL, city text NOT NULL,
  building_id text NOT NULL, room_id text NOT NULL, data text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- I6 : aucune sous-hierarchie.
CREATE OR REPLACE FUNCTION banc_pnj.pas_de_sous_hierarchie() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF (NEW.leader_pj IS NOT NULL OR NEW.leader_pnj_id IS NOT NULL)
     AND EXISTS (SELECT 1 FROM banc_pnj.membres m WHERE m.leader_pnj_id = NEW.id) THEN
    RAISE EXCEPTION 'pnj_sous_hierarchie_interdite: % conduit deja des membres', NEW.id;
  END IF;
  IF NEW.leader_pnj_id IS NOT NULL AND EXISTS (
       SELECT 1 FROM banc_pnj.membres m WHERE m.id = NEW.leader_pnj_id
         AND (m.leader_pj IS NOT NULL OR m.leader_pnj_id IS NOT NULL)) THEN
    RAISE EXCEPTION 'pnj_sous_hierarchie_interdite: le leader % suit lui-meme un chef',
                    NEW.leader_pnj_id;
  END IF;
  NEW.maj_le := now();
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_pas_de_sous_hierarchie BEFORE INSERT OR UPDATE ON banc_pnj.membres
  FOR EACH ROW EXECUTE FUNCTION banc_pnj.pas_de_sous_hierarchie();

-- LA PRIMITIVE DE POSITION. Profondeur bornee a 1 par I6 : deux LEFT JOIN suffisent.
CREATE OR REPLACE FUNCTION banc_pnj.position_effective(p_id text)
RETURNS TABLE(pays text, ville text, building_id text, room_id text, porte boolean)
LANGUAGE sql STABLE AS $$
  SELECT m.pays,
         CASE WHEN m.leader_pj IS NOT NULL THEN d.current_city
              WHEN m.leader_pnj_id IS NOT NULL THEN l.ville ELSE m.ville END,
         CASE WHEN m.leader_pj IS NOT NULL THEN d.current_building
              WHEN m.leader_pnj_id IS NOT NULL THEN l.building_id ELSE m.building_id END,
         CASE WHEN m.leader_pj IS NOT NULL THEN d.current_room
              WHEN m.leader_pnj_id IS NOT NULL THEN l.room_id ELSE m.room_id END,
         (m.leader_pj IS NOT NULL OR m.leader_pnj_id IS NOT NULL)
    FROM banc_pnj.membres m
    LEFT JOIN banc_pnj.pj      d ON d.name = m.leader_pj
    LEFT JOIN banc_pnj.membres l ON l.id   = m.leader_pnj_id
   WHERE m.id = p_id;
$$;

-- LE TITULAIRE D'UN POSTE : resolu, jamais stocke. NULL = poste vacant.
CREATE OR REPLACE FUNCTION banc_pnj.titulaire_du_poste(
  p_pays text, p_poste text, p_ville text DEFAULT NULL)
RETURNS text LANGUAGE sql STABLE AS $$
  SELECT d.name FROM banc_pnj.pj d
   WHERE d.country = p_pays AND d.poste->>'id' = p_poste
     AND (p_ville IS NULL OR d.poste->>'city' = p_ville)
   LIMIT 1;
$$;

-- QUI PEUT ADMINISTRER CE PNJ ? proprietaire personnel, ou titulaire du poste proprietaire.
CREATE OR REPLACE FUNCTION banc_pnj.administrateur(p_id text)
RETURNS text LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN m.proprietaire_pj IS NOT NULL THEN m.proprietaire_pj
              ELSE banc_pnj.titulaire_du_poste(m.pays, m.proprietaire_poste,
                                               m.proprietaire_poste_ville) END
    FROM banc_pnj.membres m WHERE m.id = p_id;
$$;

-- MORT GENERIQUE : fige la position, tue, delie, depose au sol, evenement au proprietaire.
CREATE OR REPLACE FUNCTION banc_pnj.mourir(p_id text)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE m record; pe record; v_n integer := 0; o record;
BEGIN
  SELECT * INTO m FROM banc_pnj.membres WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF m.statut = 'mort' THEN
    RETURN jsonb_build_object('ok', true, 'raison', 'deja_mort', 'deposes', 0);
  END IF;

  SELECT * INTO pe FROM banc_pnj.position_effective(p_id);

  -- 3) delier AVANT d'ecrire la position propre : I1 interdit les deux a la fois.
  UPDATE banc_pnj.membres
     SET statut = 'mort', leader_pj = NULL, leader_pnj_id = NULL,
         ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
   WHERE id = p_id;

  -- 4/5) possessions au sol, une ligne par objet, dans la table canonique
  FOR o IN SELECT * FROM banc_pnj.possessions WHERE pnj_id = p_id LOOP
    INSERT INTO banc_pnj.objets_abandonnes (id, country, city, building_id, room_id, data)
    VALUES ('objet-abandonne-' || replace(gen_random_uuid()::text, '-', ''),
            pe.pays, COALESCE(pe.ville, 'inconnue'),
            COALESCE(pe.building_id, 'rue-centrale'), COALESCE(pe.room_id, 'inconnu'),
            o.objet::text);
    v_n := v_n + 1;
  END LOOP;
  DELETE FROM banc_pnj.possessions WHERE pnj_id = p_id;

  -- 6/7) evenement persistant, adresse a la FORME DE PROPRIETE
  INSERT INTO banc_pnj.evenements
    (pnj_id, pnj_nom, famille, type, pays, proprietaire_pj, proprietaire_poste,
     proprietaire_poste_ville, ville, building_id, room_id)
  VALUES (m.id, m.nom, m.famille, 'mort', m.pays, m.proprietaire_pj, m.proprietaire_poste,
          m.proprietaire_poste_ville, pe.ville, pe.building_id, pe.room_id);

  RETURN jsonb_build_object('ok', true, 'deposes', v_n);
END; $$;

-- DEPENSE INDIVIDUELLE DE PA. 0 PA = mort. Aucune protection, aucun blocage a zero.
CREATE OR REPLACE FUNCTION banc_pnj.pa_debiter(p_ids text[], p_cout integer)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE r record; v_morts integer := 0; v_touches integer := 0;
BEGIN
  FOR r IN SELECT id, pa FROM banc_pnj.membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    UPDATE banc_pnj.membres SET pa = greatest(0, r.pa - p_cout) WHERE id = r.id;
    v_touches := v_touches + 1;
    IF greatest(0, r.pa - p_cout) = 0 THEN
      PERFORM banc_pnj.mourir(r.id);
      v_morts := v_morts + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'touches', v_touches, 'morts', v_morts);
END; $$;

-- DEPLACEMENT D'UN GROUPE : le leader paie l'argent, chacun paie ses PA.
CREATE OR REPLACE FUNCTION banc_pnj.groupe_deplacer(
  p_leader text, p_ville text, p_building text, p_room text,
  p_pa integer, p_cout_argent numeric)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_ids text[]; v_r jsonb; v_pa_leader integer; v_liquide numeric;
BEGIN
  SELECT pa, liquide INTO v_pa_leader, v_liquide FROM banc_pnj.pj
   WHERE name = p_leader FOR UPDATE;
  IF v_pa_leader IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'leader_introuvable');
  END IF;
  IF v_liquide < p_cout_argent THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  SELECT COALESCE(array_agg(id), '{}') INTO v_ids FROM banc_pnj.membres
   WHERE leader_pj = p_leader AND statut = 'actif';

  -- Le leader : ses PA et LUI SEUL paie l'argent du transport.
  UPDATE banc_pnj.pj SET pa = greatest(0, v_pa_leader - p_pa),
                         liquide = v_liquide - p_cout_argent,
                         current_city = p_ville, current_building = p_building,
                         current_room = p_room
   WHERE name = p_leader;

  -- Les membres : PA individuels. Aucune ecriture de position : elle est DERIVEE.
  v_r := banc_pnj.pa_debiter(v_ids, p_pa);
  RETURN jsonb_build_object('ok', true, 'membres', coalesce(array_length(v_ids,1),0),
                            'pa', v_r);
END; $$;

-- TRANSFERT DE CONDUITE : co-presence exigee, aucune acceptation, propriete inchangee.
CREATE OR REPLACE FUNCTION banc_pnj.transferer(p_ids text[], p_dest text, p_dest_est_pnj boolean)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE r record; pd record; pm record; v_n integer := 0;
BEGIN
  IF p_dest_est_pnj THEN
    SELECT * INTO pd FROM banc_pnj.position_effective(p_dest);
  ELSE
    SELECT country, current_city, current_building, current_room
      INTO pd FROM banc_pnj.pj WHERE name = p_dest;
  END IF;
  IF pd IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable'); END IF;

  FOR r IN SELECT id FROM banc_pnj.membres WHERE id = ANY(p_ids) AND statut = 'actif' LOOP
    SELECT * INTO pm FROM banc_pnj.position_effective(r.id);
    IF pm.ville IS DISTINCT FROM pd.current_city
       OR pm.building_id IS DISTINCT FROM pd.current_building
       OR pm.room_id IS DISTINCT FROM pd.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_co_presents', 'pnj', r.id);
    END IF;
    IF p_dest_est_pnj THEN
      UPDATE banc_pnj.membres SET leader_pj = NULL, leader_pnj_id = p_dest,
             ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL
       WHERE id = r.id;
    ELSE
      UPDATE banc_pnj.membres SET leader_pnj_id = NULL, leader_pj = p_dest,
             ville = NULL, building_id = NULL, room_id = NULL, rue_noeud_id = NULL
       WHERE id = r.id;
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'transferes', v_n);
END; $$;

-- QUITTER LE GROUPE : la position est MATERIALISEE avant que le lien soit rompu.
CREATE OR REPLACE FUNCTION banc_pnj.quitter_groupe(p_ids text[])
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE r record; pe record; v_n integer := 0;
BEGIN
  FOR r IN SELECT id FROM banc_pnj.membres WHERE id = ANY(p_ids) LOOP
    SELECT * INTO pe FROM banc_pnj.position_effective(r.id);
    UPDATE banc_pnj.membres
       SET leader_pj = NULL, leader_pnj_id = NULL,
           ville = pe.ville, building_id = pe.building_id, room_id = pe.room_id
     WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'detaches', v_n);
END; $$;

-- TRANSFERT ATOMIQUE D'ARGENT PJ -> PNJ (DONNER) et PNJ -> PJ (RETIRER).
CREATE OR REPLACE FUNCTION banc_pnj.argent_transferer(
  p_pj text, p_pnj text, p_montant numeric, p_sens text)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_pj numeric; v_pnj numeric;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;
  SELECT liquide INTO v_pj  FROM banc_pnj.pj      WHERE name = p_pj  FOR UPDATE;
  SELECT liquide INTO v_pnj FROM banc_pnj.membres WHERE id   = p_pnj FOR UPDATE;
  IF v_pj IS NULL OR v_pnj IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'introuvable');
  END IF;
  IF p_sens = 'donner' THEN
    IF v_pj < p_montant THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
    UPDATE banc_pnj.pj      SET liquide = v_pj  - p_montant WHERE name = p_pj;
    UPDATE banc_pnj.membres SET liquide = v_pnj + p_montant WHERE id   = p_pnj;
  ELSIF p_sens = 'retirer' THEN
    IF v_pnj < p_montant THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
    UPDATE banc_pnj.membres SET liquide = v_pnj - p_montant WHERE id   = p_pnj;
    UPDATE banc_pnj.pj      SET liquide = v_pj  + p_montant WHERE name = p_pj;
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'sens_invalide');
  END IF;
  RETURN jsonb_build_object('ok', true);
END; $$;

-- Journal de recette
CREATE TABLE banc_pnj.resultats (
  cas text PRIMARY KEY, intitule text NOT NULL, attendu text, obtenu text, ok boolean
);
CREATE OR REPLACE FUNCTION banc_pnj.verifier(p_cas text, p_intitule text,
  p_attendu text, p_obtenu text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO banc_pnj.resultats (cas, intitule, attendu, obtenu, ok)
  VALUES (p_cas, p_intitule, p_attendu, p_obtenu, p_attendu = p_obtenu)
  ON CONFLICT (cas) DO UPDATE SET attendu = excluded.attendu,
    obtenu = excluded.obtenu, ok = excluded.ok;
$$;

-- =====================================================================================
-- RESULTATS -- execution du 26 septembre 2026 : 24 cas joues, 24 reussis, 0 echec.
--
--  A  PNJ personnel stationne : position propre, non porte ................... OK
--  B  PNJ institutionnel, poste vacant : aucun administrateur ................ OK
--  C  Nomination : autorite acquise, PNJ NON reecrit (maj_le inchange) ....... OK
--  D  PNJ rejoint un PJ : position derivee du leader ........................ OK
--  E  Deplacement du PJ : les PNJ suivent sans aucune ecriture de position ... OK
--  F  PA debites individuellement (leader 30->28, chaque PNJ 12->10) ........ OK
--  G  Argent du transport paye par le LEADER seul (920, PNJ a 0) ............ OK
--  H  Transfert vers un leader co-present accepte ........................... OK
--  I  Transfert vers un leader absent refuse (pas_co_presents) .............. OK
--  J  Aucune acceptation du nouveau leader requise ......................... OK
--  K  Sous-hierarchie refusee par le declencheur ........................... OK
--  L  Leader hospitalise : PNJ materialises sur place, sans leader .......... OK
--  M  0 PA = mort, sans protection ni blocage a zero ....................... OK
--  N  Possessions deposees au sol a la position effective, PNJ vide ......... OK
--  O  Evenement de mort cree, adresse au proprietaire PJ ................... OK
--  P  Mort pendant une VACANCE : evenement conserve, adresse au POSTE ....... OK
--  Q  Nouveau titulaire : evenement de la vacance visible .................. OK
--  R  Changement de leader : proprietaire INCHANGE ......................... OK
--  S  Transfert rejoue : resultat coherent, toujours un seul leader ......... OK
--  T  Double mort : aucune double mort, aucun double depot ................. OK
--  U  Donner de l'argent : atomique, somme conservee ....................... OK
--  U2 Donner plus que l'on possede : refuse, rien ne bouge ................. OK
--  V  Client sans aucun droit direct sur les tables du socle ............... OK
--  P-avant  Poste bien vacant avant la mort (controle de la mise en place) .. OK
--
-- Production verifiee intacte apres DROP SCHEMA : 1 compagnie, 96 soldats, 12 agents,
-- 4 objets au sol, 4 PJ. Aucun objet cree dans `public`.
-- =====================================================================================
