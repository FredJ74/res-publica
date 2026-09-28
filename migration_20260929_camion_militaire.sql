-- ===========================================================================
-- CAMION MILITAIRE — UN VEHICULE REEL, LOCALISE, AVEC UN INTERIEUR
-- 29 septembre 2026
-- ===========================================================================
--
-- CE QUE CE LOT AJOUTE, ET CE QU'IL N'AJOUTE PAS.
--
-- Il n'ajoute NI une geographie militaire, NI un second moteur de personnes
-- presentes, NI une copie du taxi, NI une comptabilite de PA parallele, NI une
-- mecanique de groupe. Il ajoute exactement trois choses :
--   1. un OBJET qui a une position courante et une caserne de rattachement ;
--   2. une PIECE dont la position est celle de cet objet ;
--   3. une TRANSACTION qui deplace l'objet, et avec lui ce qui s'y trouve.
--
-- L'INTERIEUR EST UNE PIECE ORDINAIRE. Le jeu sait deja dire ou se trouve un
-- personnage : (pays, ville, batiment, piece). L'interieur du camion est le
-- couple (batiment = 'camion-militaire', piece = <id du camion>) ; sa VILLE est
-- celle du camion. Deplacer le camion, c'est donc changer la ville de ceux qui
-- sont dedans -- leur batiment et leur piece ne bougent pas, puisqu'ils n'ont
-- pas quitte le camion. Aucune table de position parallele n'est creee.
--
-- LES GROUPES NE SONT PAS RE-IMPLEMENTES. pnj_position_effective() resout deja
-- la position d'un PNJ par celle de son chef. Un Lieutenant qui monte emmene sa
-- section sans qu'une seule ligne soit ecrite sur ses soldats ; un Lieutenant
-- transporte les emmene de meme. Il n'existe donc NI `soldatsDansCamion`, NI
-- localisation individuelle des 24 soldats, NI rendu militaire particulier.
--
-- LE MOTEUR NE CONNAIT AUCUN PAYS NI AUCUNE VILLE. Caserne, image, capacite et
-- destinations sont des DONNEES (camions_militaires, camions_destinations).
-- Ajouter Sovarka demain, c'est inserer des lignes, pas ecrire du code.

-- ---------------------------------------------------------------------------
-- 1. LE BATIMENT SYNTHETIQUE DE L'INTERIEUR
-- ---------------------------------------------------------------------------
-- Un seul endroit nomme cette constante, cote serveur comme cote client. Le
-- precedent est 'rue-centrale' : un identifiant de batiment qui ne designe pas
-- un batiment de la carte mais un CONTEXTE de presence, deja porte tel quel par
-- la table `presences` et par personnages_donnees.current_building.
create or replace function public.camion_batiment_interieur()
returns text
language sql
immutable
as $fn$ select 'camion-militaire'::text $fn$;

comment on function public.camion_batiment_interieur() is
  'Identifiant de batiment synthetique designant l''interieur d''un camion. La PIECE vaut l''identifiant du camion, la VILLE celle du camion. Nomme une seule fois, ici.';

revoke all on function public.camion_batiment_interieur() from public, anon, authenticated;
grant execute on function public.camion_batiment_interieur() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. LE PARC DE CAMIONS
-- ---------------------------------------------------------------------------
-- caserneAttache : le rattachement ADMINISTRATIF, qui ne bouge jamais. C'est la
--                  destination du « retour a vide », et c'est une destination
--                  autorisee pour ce camion et pour lui seul.
-- positionCourante : ou le camion se trouve VRAIMENT, a l'instant present. Un
--                  camion n'est jamais nulle part et jamais a deux endroits.
create table if not exists public.camions_militaires (
  id                text primary key,
  pays              text    not null,
  institution       text    not null default 'militaire',
  perimetre         text,
  libelle           text    not null,
  capacite          integer not null default 25 check (capacite > 0),
  image_url         text,
  -- RATTACHEMENT ADMINISTRATIF (immuable en usage normal)
  caserne_ville     text    not null,
  caserne_building  text    not null,
  caserne_room      text    not null,
  caserne_libelle   text    not null,
  -- POSITION COURANTE
  ville             text    not null,
  building_id       text    not null,
  room_id           text    not null,
  statut            text    not null default 'actif'
                    check (statut in ('actif', 'hors_service')),
  maj_le            timestamptz not null default now()
);

create index if not exists camions_militaires_position_idx
  on public.camions_militaires (pays, ville, building_id, room_id);

alter table public.camions_militaires enable row level security;
revoke all on table public.camions_militaires from public, anon, authenticated;
grant select on table public.camions_militaires to service_role;

comment on table public.camions_militaires is
  'Parc de vehicules de transport de troupe. Position courante ET caserne de rattachement, distinctes. Ferme au client : toute lecture passe par camions_ici/camion_etat, toute ecriture par camion_deplacer.';

-- ---------------------------------------------------------------------------
-- 3. LES DESTINATIONS AUTORISEES — DES DONNEES, PAS DU CODE
-- ---------------------------------------------------------------------------
-- La caserne de rattachement N'EST PAS dans cette table : elle appartient au
-- camion, et deux camions de deux casernes differentes ne doivent pas se voir
-- proposer la caserne de l'autre. Elle est donc ajoutee a la volee, par camion,
-- sous la cle reservee '__caserne__'.
create table if not exists public.camions_destinations (
  pays        text    not null,
  cle         text    not null,
  ville       text    not null,
  building_id text    not null,
  room_id     text    not null,
  libelle     text    not null,
  rang        integer not null default 0,
  primary key (pays, cle)
);

alter table public.camions_destinations enable row level security;
revoke all on table public.camions_destinations from public, anon, authenticated;
grant select on table public.camions_destinations to service_role;

comment on table public.camions_destinations is
  'Destinations ouvertes aux camions d''un pays. La caserne de rattachement n''y figure pas : elle est propre a chaque camion et resolue sous la cle reservee __caserne__.';

-- ---------------------------------------------------------------------------
-- 4. JOURNAL DES ORDRES — IDEMPOTENCE PAR CLE DE REQUETE
-- ---------------------------------------------------------------------------
-- Meme dispositif que ventes_snapshots, productions_references et
-- apports_matieres : la cle est fabriquee par le client a l'ouverture de
-- l'ecran, et la cle primaire fait le reste. Rejouer le meme ordre rend le meme
-- resultat sans second debit ni second deplacement.
create table if not exists public.camions_ordres (
  requete     text primary key,
  cree_le     timestamptz not null default now(),
  camion_id   text not null,
  acteur      text not null,
  action      text not null,
  destination text,
  resultat    jsonb not null
);

create index if not exists camions_ordres_camion_idx
  on public.camions_ordres (camion_id, cree_le desc);

alter table public.camions_ordres enable row level security;
revoke all on table public.camions_ordres from public, anon, authenticated;
grant select on table public.camions_ordres to service_role;

comment on table public.camions_ordres is
  'Journal idempotent des ordres donnes a un camion. Ecrit uniquement par les RPC SECURITY DEFINER ; ferme au client.';

-- ---------------------------------------------------------------------------
-- 5. HORODATAGE D'EMBARQUEMENT
-- ---------------------------------------------------------------------------
-- CE N'EST PAS UNE POSITION, et cette table ne fait jamais autorite sur qui est
-- a bord : la verite reste personnages_donnees / pnj_membres. Elle ne sert qu'a
-- ORDONNER les debarquements quand la priorite militaire oblige a faire de la
-- place : dernier monte, premier debarque. Une ligne perimee est sans effet --
-- on n'ordonne que l'ensemble calcule a partir des positions reelles.
create table if not exists public.camions_embarquements (
  camion_id   text not null,
  personnage  text not null,
  monte_le    timestamptz not null default now(),
  primary key (camion_id, personnage)
);

alter table public.camions_embarquements enable row level security;
revoke all on table public.camions_embarquements from public, anon, authenticated;
grant select on table public.camions_embarquements to service_role;

comment on table public.camions_embarquements is
  'Instant d''embarquement de chaque PJ, utilise UNIQUEMENT pour ordonner les debarquements par priorite militaire (dernier monte, premier debarque). Ne fait jamais autorite sur la presence a bord.';

-- ---------------------------------------------------------------------------
-- 6. OCCUPANTS D'UN CAMION — UNE SEULE DEFINITION
-- ---------------------------------------------------------------------------
-- Toute la mecanique (capacite, priorite, PA, deplacement) repose sur cette
-- definition et sur aucune autre. Deux populations, une seule question posee a
-- chacune : « ta position effective est-elle l'interieur de ce camion ? »
--
--   PJ  : personnages_donnees.(current_city, current_building, current_room)
--   PNJ : pnj_position_effective(id), qui resout deja le suivi d'un chef
--
-- Un soldat qui suit son Lieutenant n'a aucune position propre : il est dans le
-- camion parce que son chef y est. C'est pour cela qu'aucune ligne de soldat
-- n'est jamais ecrite par ce lot.
create or replace function public.camion_occupants(p_camion_id text)
returns table(
  est_pj       boolean,
  ref          text,      -- nom du PJ, ou identifiant du PNJ
  nom          text,
  famille      text,      -- NULL pour un PJ
  classe       text,      -- 'alpha'/'beta'/... pour un PNJ, 'pj' pour un PJ
  pa           integer,
  chef         text,      -- PJ dont depend cet occupant (lui-meme si autonome)
  monte_le     timestamptz
)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  WITH cam AS (SELECT * FROM public.camions_militaires WHERE id = p_camion_id),
  pj AS (
    SELECT d.name, d.pa
      FROM public.personnages_donnees d, cam c
     WHERE d.current_city     = c.ville
       AND d.current_building = public.camion_batiment_interieur()
       AND d.current_room     = c.id
  ),
  pnj AS (
    -- `chef` : le porteur dont depend cet occupant. Un PNJ mene par un PJ depend
    -- de ce PJ ; un PNJ mene par un autre PNJ remonte d'un cran (le modele
    -- n'autorise pas de chaine plus longue : pnj_pas_de_sous_hierarchie).
    SELECT m.id, m.nom, m.famille, m.pa,
           public.pnj_classe_de(m.id) AS classe,
           COALESCE(m.leader_pj,
                    (SELECT l.leader_pj FROM public.pnj_membres l WHERE l.id = m.leader_pnj_id),
                    m.leader_pnj_id, m.id) AS chef
      FROM cam c
      JOIN public.pnj_membres m ON m.statut = 'actif'
      JOIN LATERAL public.pnj_position_effective(m.id) pe ON true
      LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
     WHERE COALESCE(sm.en_reserve, false) = false
       AND pe.ville       IS NOT DISTINCT FROM c.ville
       AND pe.building_id = public.camion_batiment_interieur()
       AND pe.room_id     = c.id
  )
  SELECT true, pj.name, pj.name, NULL::text, 'pj'::text, pj.pa, pj.name,
         (SELECT e.monte_le FROM public.camions_embarquements e
           WHERE e.camion_id = p_camion_id AND e.personnage = pj.name)
    FROM pj
  UNION ALL
  SELECT false, pnj.id, pnj.nom, pnj.famille, pnj.classe, pnj.pa, pnj.chef,
         (SELECT e.monte_le FROM public.camions_embarquements e
           WHERE e.camion_id = p_camion_id AND e.personnage = pnj.chef)
    FROM pnj;
$fn$;

comment on function public.camion_occupants(text) is
  'Qui se trouve dans ce camion, PJ et PNJ confondus, par leur position EFFECTIVE. Definition unique : capacite, priorite, PA et deplacement s''y referent tous.';

revoke all on function public.camion_occupants(text) from public, anon, authenticated;
grant execute on function public.camion_occupants(text) to service_role;

-- ---------------------------------------------------------------------------
-- 7. DESTINATIONS OFFERTES A UN CAMION
-- ---------------------------------------------------------------------------
-- La destination courante n'est jamais proposee : ce n'est pas un trajet.
create or replace function public.camion_destinations(p_camion_id text)
returns table(cle text, ville text, building_id text, room_id text, libelle text, rang integer)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  WITH cam AS (SELECT * FROM public.camions_militaires WHERE id = p_camion_id)
  SELECT d.cle, d.ville, d.building_id, d.room_id, d.libelle, d.rang
    FROM public.camions_destinations d, cam c
   WHERE d.pays = c.pays
     AND NOT (d.ville = c.ville AND d.building_id = c.building_id AND d.room_id = c.room_id)
  UNION ALL
  SELECT '__caserne__', c.caserne_ville, c.caserne_building, c.caserne_room,
         c.caserne_libelle, -1
    FROM cam c
   WHERE NOT (c.caserne_ville = c.ville AND c.caserne_building = c.building_id
              AND c.caserne_room = c.room_id)
   ORDER BY 6, 5;
$fn$;

comment on function public.camion_destinations(text) is
  'Destinations utiles pour CE camion : celles ouvertes a son pays, plus sa propre caserne de rattachement. La position courante est toujours exclue.';

revoke all on function public.camion_destinations(text) from public, anon, authenticated;
grant execute on function public.camion_destinations(text) to service_role;

-- ---------------------------------------------------------------------------
-- 8. QUI PEUT COMMANDER
-- ---------------------------------------------------------------------------
-- L'autorite est un GRADE, lu par militaire_grade_effectif, qui est deja la
-- source unique du jeu. On n'ecrit aucune condition nominative, ni sur un
-- joueur, ni sur une compagnie, ni sur un pays.
create or replace function public.camion_grade_commandant(p_nom text)
returns text
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
  SELECT t.g FROM (SELECT public.militaire_grade_effectif(p_nom) AS g) t
   WHERE t.g IN ('lieutenant', 'capitaine');
$fn$;

comment on function public.camion_grade_commandant(text) is
  'Grade habilite a commander un camion (lieutenant ou capitaine), ou NULL. Aucune condition nominative.';

revoke all on function public.camion_grade_commandant(text) from public, anon, authenticated;
grant execute on function public.camion_grade_commandant(text) to service_role;

-- ---------------------------------------------------------------------------
-- 9. CAMIONS STATIONNES ICI
-- ---------------------------------------------------------------------------
-- Alimente le bouton « Camion militaire ». Un camion n'apparait que la ou il
-- est REELLEMENT : il n'existe aucun camion fantome, parce qu'il n'existe
-- qu'une seule position et qu'elle est lue telle quelle.
create or replace function public.camions_ici(
  p_pays text, p_ville text, p_building text, p_room text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  RETURN jsonb_build_object('ok', true, 'camions', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'id', c.id, 'libelle', c.libelle, 'capacite', c.capacite,
             'image_url', c.image_url, 'caserne', c.caserne_libelle,
             'occupants', (SELECT count(*) FROM public.camion_occupants(c.id))
           ) ORDER BY c.libelle)
      FROM public.camions_militaires c
     WHERE c.statut = 'actif'
       AND c.pays        = p_pays
       AND c.ville       = p_ville
       AND c.building_id = p_building
       AND c.room_id     = p_room
  ), '[]'::jsonb));
END; $fn$;

comment on function public.camions_ici(text,text,text,text) is
  'Camions reellement stationnes dans ce lieu. Le bouton d''acces n''existe que si cette liste n''est pas vide.';

revoke all on function public.camions_ici(text,text,text,text) from public, anon, authenticated;
grant execute on function public.camions_ici(text,text,text,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 10. ETAT D'UN CAMION — LA VUE INTERIEURE ET LA RESYNCHRONISATION
-- ---------------------------------------------------------------------------
-- Une seule lecture sert a trois choses : dessiner l'interieur, decider quels
-- ordres afficher, et permettre a un client de constater qu'il a ete deplace ou
-- debarque pendant qu'il regardait ailleurs. Il n'y a pas de temps reel dans ce
-- jeu ; il y a cette reponse, et un client qui la redemande.
create or replace function public.camion_etat(p_camion_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; c record; a record; v_grade text; v_dedans boolean;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO c FROM public.camions_militaires WHERE id = p_camion_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_introuvable'); END IF;
  SELECT country, current_city, current_building, current_room, pa INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS DISTINCT FROM c.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;

  v_dedans := a.current_city = c.ville
          AND a.current_building = public.camion_batiment_interieur()
          AND a.current_room = c.id;
  v_grade  := public.camion_grade_commandant(v_moi);

  RETURN jsonb_build_object(
    'ok', true,
    'camion', jsonb_build_object(
      'id', c.id, 'libelle', c.libelle, 'capacite', c.capacite,
      'image_url', c.image_url, 'pays', c.pays,
      'ville', c.ville, 'building_id', c.building_id, 'room_id', c.room_id,
      'caserne', jsonb_build_object('ville', c.caserne_ville,
        'building_id', c.caserne_building, 'room_id', c.caserne_room,
        'libelle', c.caserne_libelle)),
    'moi', jsonb_build_object('nom', v_moi, 'pa', a.pa, 'ville', a.current_city,
      'building_id', a.current_building, 'room_id', a.current_room),
    'dedans', v_dedans,
    'grade', v_grade,
    -- « Peut commander » exige d'etre PHYSIQUEMENT dedans. Pas d'ordre a
    -- distance : ni depuis le bureau, ni depuis la caserne, ni d'une autre ville.
    'peut_commander', (v_grade IS NOT NULL AND v_dedans),
    'occupants_total', (SELECT count(*) FROM public.camion_occupants(p_camion_id)),
    'destinations', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('cle', d.cle, 'libelle', d.libelle) ORDER BY d.rang, d.libelle)
        FROM public.camion_destinations(p_camion_id) d), '[]'::jsonb));
END; $fn$;

comment on function public.camion_etat(text) is
  'Etat complet d''un camion pour l''appelant : position du camion, sa propre position, droit de commander, destinations. Sert aussi de mecanisme de resynchronisation, faute de temps reel.';

revoke all on function public.camion_etat(text) from public, anon, authenticated;
grant execute on function public.camion_etat(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 11. MONTER DANS LE CAMION
-- ---------------------------------------------------------------------------
-- Gratuit, ouvert a tout PJ, et SANS AUCUN DEPLACEMENT DU VEHICULE. Entrer dans
-- le camion, c'est entrer dans une piece.
--
-- C'EST ICI QUE LA PRIORITE MILITAIRE S'APPLIQUE. Une section qui embarque est
-- prioritaire sur les occupants opportunistes : si elle ne tient pas, on
-- debarque des opportunistes -- dernier monte, premier debarque -- jusqu'a ce
-- qu'elle tienne. Un occupant debarque reste dans le lieu ou le camion
-- stationne ; il n'est ni puni ni deplace ailleurs.
--
-- Un PJ SANS priorite qui trouve le camion plein est refuse : la capacite vaut
-- contre lui, faute de priorite a lui opposer.
create or replace function public.camion_monter(p_camion_id text, p_cle text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_moi text; c record; a record; v_rejeu jsonb;
  v_grade text; v_ma_troupe integer; v_prioritaire boolean;
  v_occupants integer; v_apres integer; v_place integer;
  v_ejectes text[] := '{}'; u record; v_taille integer;
  v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cle), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cle_requete_absente'); END IF;

  SELECT * INTO c FROM public.camions_militaires WHERE id = p_camion_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_introuvable'); END IF;
  IF c.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_hors_service'); END IF;

  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  IF FOUND THEN RETURN v_rejeu || jsonb_build_object('rejeu', true); END IF;

  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF a.country IS DISTINCT FROM c.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;

  -- Deja dedans : l'ordre est sans objet, et le dire vaut mieux que de rejouer.
  IF a.current_city = c.ville
     AND a.current_building = public.camion_batiment_interieur()
     AND a.current_room = c.id THEN
    RETURN jsonb_build_object('ok', true, 'deja_dedans', true, 'camion_id', c.id);
  END IF;

  -- PRESENCE PHYSIQUE : on ne monte que dans un camion qu'on touche.
  IF NOT (a.current_city = c.ville AND a.current_building = c.building_id
          AND a.current_room = c.room_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  v_grade := public.camion_grade_commandant(v_moi);
  SELECT count(*) INTO v_ma_troupe FROM public.pnj_membres m
    LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE m.statut = 'actif' AND m.leader_pj = v_moi AND m.famille = 'soldat'
     AND COALESCE(sm.en_reserve, false) = false;
  -- Priorite militaire : un officier QUI MENE DES SOLDATS. Un officier seul
  -- n'est qu'un passager de plus, et c'est volontaire.
  v_prioritaire := (v_grade IS NOT NULL AND v_ma_troupe > 0);

  SELECT count(*) INTO v_occupants FROM public.camion_occupants(p_camion_id);
  -- Ma propre unite : moi, plus tout PNJ qui me suit (soldats, mais aussi
  -- escorte ou agent : le camion ne distingue personne).
  SELECT 1 + count(*) INTO v_taille FROM public.pnj_membres m
    LEFT JOIN public.pnj_soldats_metier sm ON sm.pnj_id = m.id
   WHERE m.statut = 'actif' AND m.leader_pj = v_moi
     AND COALESCE(sm.en_reserve, false) = false;
  v_apres := v_occupants + v_taille;

  IF v_apres > c.capacite THEN
    IF NOT v_prioritaire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'camion_complet',
        'capacite', c.capacite, 'occupants', v_occupants, 'demande', v_taille);
    END IF;
    IF v_taille > c.capacite THEN
      -- La section est indivisible : si elle ne tient pas seule, rien ne peut
      -- la faire tenir. On refuse plutot que de la couper.
      RETURN jsonb_build_object('ok', false, 'raison', 'section_trop_nombreuse',
        'capacite', c.capacite, 'section', v_taille);
    END IF;
    v_place := v_apres - c.capacite;
    -- Debarquement des opportunistes, dernier monte d'abord. Un PJ emmene son
    -- groupe en descendant : on ne compte donc que les PJ et leur suite.
    FOR u IN
      SELECT o.ref AS nom,
             (SELECT count(*) FROM public.camion_occupants(p_camion_id) x
               WHERE x.chef = o.ref) AS taille,
             o.monte_le
        FROM public.camion_occupants(p_camion_id) o
       WHERE o.est_pj = true
       ORDER BY o.monte_le DESC NULLS FIRST, o.ref DESC
    LOOP
      EXIT WHEN v_place <= 0;
      UPDATE public.personnages_donnees
         SET current_city = c.ville, current_building = c.building_id,
             current_room = c.room_id, updated_at = now()
       WHERE name = u.nom;
      DELETE FROM public.camions_embarquements
       WHERE camion_id = c.id AND personnage = u.nom;
      v_ejectes := v_ejectes || u.nom;
      v_place := v_place - u.taille;
    END LOOP;
    -- Des PNJ poses seuls dans le camion peuvent encore empecher l'embarquement.
    -- On les repose dans le lieu de stationnement, jamais ailleurs.
    IF v_place > 0 THEN
      UPDATE public.pnj_membres m
         SET ville = c.ville, building_id = c.building_id, room_id = c.room_id,
             rue_noeud_id = NULL, maj_le = now()
       WHERE m.id IN (SELECT o.ref FROM public.camion_occupants(p_camion_id) o
                       WHERE o.est_pj = false AND o.chef = o.ref);
    END IF;
    SELECT count(*) INTO v_occupants FROM public.camion_occupants(p_camion_id);
    IF v_occupants + v_taille > c.capacite THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'capacite_insuffisante',
        'capacite', c.capacite, 'occupants', v_occupants, 'demande', v_taille);
    END IF;
  END IF;

  UPDATE public.personnages_donnees
     SET current_city = c.ville,
         current_building = public.camion_batiment_interieur(),
         current_room = c.id, updated_at = now()
   WHERE name = v_moi;
  INSERT INTO public.camions_embarquements (camion_id, personnage, monte_le)
       VALUES (c.id, v_moi, now())
  ON CONFLICT (camion_id, personnage) DO UPDATE SET monte_le = now();

  v_res := jsonb_build_object('ok', true, 'camion_id', c.id,
    'building_id', public.camion_batiment_interieur(), 'room_id', c.id,
    'ville', c.ville, 'embarques', v_taille, 'debarques', to_jsonb(v_ejectes),
    'occupants', (SELECT count(*) FROM public.camion_occupants(p_camion_id)));

  INSERT INTO public.camions_ordres (requete, camion_id, acteur, action, resultat)
       VALUES (p_cle, c.id, v_moi, 'monter', v_res);
  RETURN v_res;
EXCEPTION WHEN unique_violation THEN
  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  RETURN COALESCE(v_rejeu, '{}'::jsonb) || jsonb_build_object('rejeu', true);
END; $fn$;

comment on function public.camion_monter(text,text) is
  'Monter dans un camion stationne la ou l''on se trouve. Gratuit, ouvert a tout PJ. Applique la priorite militaire : une section qui embarque fait debarquer les opportunistes, dernier monte d''abord.';

revoke all on function public.camion_monter(text,text) from public, anon, authenticated;
grant execute on function public.camion_monter(text,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 12. DESCENDRE DU CAMION
-- ---------------------------------------------------------------------------
-- Gratuit, et sans idempotence a inventer : poser une position deux fois pose
-- la meme position. Le groupe suit son chef sans qu'on l'ecrive.
create or replace function public.camion_descendre(p_camion_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE v_moi text; c record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO c FROM public.camions_militaires WHERE id = p_camion_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_introuvable'); END IF;
  SELECT current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT (a.current_building = public.camion_batiment_interieur()
          AND a.current_room = c.id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_bord');
  END IF;

  UPDATE public.personnages_donnees
     SET current_city = c.ville, current_building = c.building_id,
         current_room = c.room_id, updated_at = now()
   WHERE name = v_moi;
  DELETE FROM public.camions_embarquements
   WHERE camion_id = c.id AND personnage = v_moi;

  RETURN jsonb_build_object('ok', true, 'camion_id', c.id, 'ville', c.ville,
    'building_id', c.building_id, 'room_id', c.room_id);
END; $fn$;

comment on function public.camion_descendre(text) is
  'Descendre d''un camion stationne : on revient dans le lieu ou il se trouve reellement. Gratuit. Les accompagnants suivent par resolution dynamique, sans ecriture.';

revoke all on function public.camion_descendre(text) from public, anon, authenticated;
grant execute on function public.camion_descendre(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 13. DEPLACER LE CAMION — LA TRANSACTION
-- ---------------------------------------------------------------------------
-- p_avec_officier = true  : trajet normal, l'officier voyage.
-- p_avec_officier = false : trajet A VIDE au sens du cahier des charges, qui ne
--   veut PAS dire « camion evacue ». L'officier donne l'ordre au chauffeur et ne
--   part pas ; les autres occupants restent a bord et sont transportes comme
--   dans n'importe quel trajet. Il n'existe aucune mecanique de clandestin : un
--   passager oublie est simplement une personne presente dans une piece.
--
-- LE CHAUFFEUR. Il est FONCTIONNEL : il ne compte pas dans les 25, ne paie
-- aucun PA, n'appartient a aucune section. Il n'a donc aucune existence en base
-- -- lui inventer une ligne de PNJ n'ajouterait rien a la mecanique et
-- creerait un personnage a nourrir, deplacer et faire mourir.
--
-- L'ORDRE DES OPERATIONS EST CELUI DU CAHIER DES CHARGES : on verifie tout, on
-- decide tout, puis seulement on ecrit. Aucun etat partiel ne survit a un echec,
-- et un refus n'ecrit rien du tout.
create or replace function public.camion_deplacer(
  p_camion_id text, p_destination_cle text, p_avec_officier boolean, p_cle text)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $fn$
DECLARE
  v_moi text; c record; a record; d record; v_rejeu jsonb; v_grade text;
  v_cout constant integer := 2;
  v_total integer; v_debarques text[] := '{}'; v_transportes_pj text[] := '{}';
  v_transportes_pnj text[] := '{}'; u record; v_res jsonb; v_compagnie text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cle), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cle_requete_absente'); END IF;

  -- 1. LE CAMION ET SA POSITION
  SELECT * INTO c FROM public.camions_militaires WHERE id = p_camion_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_introuvable'); END IF;
  IF c.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'camion_hors_service'); END IF;

  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  IF FOUND THEN RETURN v_rejeu || jsonb_build_object('rejeu', true); END IF;

  -- 2. L'OFFICIER EST-IL REELLEMENT A L'INTERIEUR
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF a.country IS DISTINCT FROM c.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_mon_pays'); END IF;
  IF NOT (a.current_city = c.ville
          AND a.current_building = public.camion_batiment_interieur()
          AND a.current_room = c.id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'officier_absent_du_camion');
  END IF;

  -- 3. SON AUTORISATION
  v_grade := public.camion_grade_commandant(v_moi);
  IF v_grade IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_insuffisant'); END IF;

  -- 4. LA DESTINATION
  SELECT * INTO d FROM public.camion_destinations(p_camion_id)
   WHERE cle = p_destination_cle;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destination_refusee'); END IF;
  -- Un Lieutenant ne renvoie le camion qu'a SA caserne. Un Capitaine choisit.
  IF NOT p_avec_officier AND v_grade = 'lieutenant' AND p_destination_cle <> '__caserne__' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'envoi_a_vide_hors_caserne');
  END IF;

  -- 5 a 7. LES OCCUPANTS REELS, LA CAPACITE
  SELECT count(*) INTO v_total FROM public.camion_occupants(p_camion_id);
  IF v_total > c.capacite THEN
    -- Fail-closed : la capacite est tenue a l'embarquement, ce cas ne devrait
    -- jamais se produire. S'il se produit, on ne part pas.
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_depassee',
      'occupants', v_total, 'capacite', c.capacite);
  END IF;

  -- 9. LES PA DE L'UNITE PRIORITAIRE — REFUS GLOBAL SI UN SEUL MANQUE
  -- L'unite prioritaire est celle de l'officier, et seulement s'il voyage. Elle
  -- est INDIVISIBLE : on ne part pas sans elle, et on ne la coupe pas.
  IF p_avec_officier THEN
    IF EXISTS (SELECT 1 FROM public.camion_occupants(p_camion_id) o
                WHERE o.chef = v_moi
                  AND (o.est_pj OR o.classe = 'alpha')
                  AND COALESCE(o.pa, 0) < v_cout) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants_section',
        'cout_par_occupant', v_cout,
        'manquants', COALESCE((SELECT jsonb_agg(o.nom) FROM public.camion_occupants(p_camion_id) o
           WHERE o.chef = v_moi AND (o.est_pj OR o.classe = 'alpha')
             AND COALESCE(o.pa, 0) < v_cout), '[]'::jsonb));
    END IF;
  END IF;

  -- 8 et 10. QUI RESTE A QUAI
  -- Une UNITE est un PJ avec ce qu'il mene, ou un PNJ pose seul. Elle voyage si
  -- chacun de ses membres qui doit payer peut payer. On n'ecrete jamais un PA a
  -- zero : on refuse le voyage a qui ne peut pas le payer.
  FOR u IN
    SELECT DISTINCT o.chef,
           (SELECT bool_or((x.est_pj OR x.classe = 'alpha') AND COALESCE(x.pa,0) < v_cout)
              FROM public.camion_occupants(p_camion_id) x WHERE x.chef = o.chef) AS sans_pa,
           (SELECT bool_or(x.est_pj) FROM public.camion_occupants(p_camion_id) x
             WHERE x.chef = o.chef AND x.ref = o.chef) AS est_pj
      FROM public.camion_occupants(p_camion_id) o
  LOOP
    -- L'officier qui n'accompagne pas le camion descend AVANT le depart : il
    -- reste ou le camion stationnait, et sa section reste avec lui.
    IF u.chef = v_moi AND NOT p_avec_officier THEN
      UPDATE public.personnages_donnees
         SET current_city = c.ville, current_building = c.building_id,
             current_room = c.room_id, updated_at = now()
       WHERE name = v_moi;
      DELETE FROM public.camions_embarquements
       WHERE camion_id = c.id AND personnage = v_moi;
      CONTINUE;
    END IF;
    IF u.sans_pa THEN
      IF COALESCE(u.est_pj, false) THEN
        UPDATE public.personnages_donnees
           SET current_city = c.ville, current_building = c.building_id,
               current_room = c.room_id, updated_at = now()
         WHERE name = u.chef;
        DELETE FROM public.camions_embarquements
         WHERE camion_id = c.id AND personnage = u.chef;
      ELSE
        UPDATE public.pnj_membres
           SET ville = c.ville, building_id = c.building_id, room_id = c.room_id,
               rue_noeud_id = NULL, maj_le = now()
         WHERE id = u.chef;
      END IF;
      v_debarques := v_debarques || u.chef;
    END IF;
  END LOOP;

  -- 11. LE DEBIT — CHACUN POUR SOI, JAMAIS LE SEUL CHEF
  -- Les soldats sont des PNJ ALPHA : ils possedent leurs propres PA et les
  -- perdent individuellement. On passe par pnj_pa_debiter, primitive generique
  -- du socle, apres avoir verifie le solde -- son ecretage a zero ne peut donc
  -- jamais s'appliquer ici.
  SELECT COALESCE(array_agg(o.ref), '{}') INTO v_transportes_pj
    FROM public.camion_occupants(p_camion_id) o WHERE o.est_pj;
  SELECT COALESCE(array_agg(o.ref), '{}') INTO v_transportes_pnj
    FROM public.camion_occupants(p_camion_id) o
   WHERE NOT o.est_pj AND o.classe = 'alpha';

  IF array_length(v_transportes_pj, 1) > 0 THEN
    UPDATE public.personnages_donnees
       SET pa = pa - v_cout, updated_at = now()
     WHERE name = ANY(v_transportes_pj);
  END IF;
  IF array_length(v_transportes_pnj, 1) > 0 THEN
    PERFORM public.pnj_pa_debiter(v_transportes_pnj, v_cout);
  END IF;

  -- 12. LE CAMION SE DEPLACE
  UPDATE public.camions_militaires
     SET ville = d.ville, building_id = d.building_id, room_id = d.room_id,
         maj_le = now()
   WHERE id = c.id;

  -- 13. LES TRANSPORTES SONT TOUJOURS DEDANS -- SEULE LEUR VILLE CHANGE
  IF array_length(v_transportes_pj, 1) > 0 THEN
    UPDATE public.personnages_donnees SET current_city = d.ville, updated_at = now()
     WHERE name = ANY(v_transportes_pj);
  END IF;
  -- Un PNJ pose seul dans le camion porte sa propre position : elle suit. Un
  -- PNJ qui suit un chef n'a rien a mettre a jour -- c'est tout l'interet du
  -- modele leader, et c'est pourquoi aucun soldat n'est ecrit ici.
  UPDATE public.pnj_membres
     SET ville = d.ville, maj_le = now()
   WHERE building_id = public.camion_batiment_interieur() AND room_id = c.id;

  -- 14. LE MIROIR METIER DES COMPAGNIES TOUCHEES
  -- Les PA des soldats font autorite au socle, mais le navigateur lit encore le
  -- blob de la compagnie pour les afficher. On projette, comme le font deja les
  -- cinq autres ecrivains de position/PA militaires.
  IF array_length(v_transportes_pnj, 1) > 0 THEN
    FOR v_compagnie IN
      SELECT DISTINCT m.proprietaire_perimetre
        FROM public.pnj_membres m
       WHERE m.id = ANY(v_transportes_pnj) AND m.famille = 'soldat'
         AND m.proprietaire_perimetre IS NOT NULL
    LOOP
      PERFORM public.militaire_blob_projeter(
        regexp_replace(v_compagnie, '-s[0-9]+$', ''));
    END LOOP;
  END IF;

  -- 15. LE RESULTAT, POUR QUE LES CLIENTS CONCERNES SE RESYNCHRONISENT
  v_res := jsonb_build_object('ok', true, 'camion_id', c.id,
    'depart', jsonb_build_object('ville', c.ville, 'building_id', c.building_id,
                                 'room_id', c.room_id),
    'arrivee', jsonb_build_object('ville', d.ville, 'building_id', d.building_id,
                                  'room_id', d.room_id, 'libelle', d.libelle),
    'avec_officier', p_avec_officier, 'grade', v_grade,
    'cout_par_occupant', v_cout,
    'transportes_pj', to_jsonb(v_transportes_pj),
    'transportes_pnj', COALESCE(array_length(v_transportes_pnj, 1), 0),
    'debarques', to_jsonb(v_debarques));

  INSERT INTO public.camions_ordres (requete, camion_id, acteur, action, destination, resultat)
       VALUES (p_cle, c.id, v_moi,
               CASE WHEN p_avec_officier THEN 'trajet' ELSE 'a_vide' END,
               p_destination_cle, v_res);
  RETURN v_res;
EXCEPTION WHEN unique_violation THEN
  SELECT resultat INTO v_rejeu FROM public.camions_ordres WHERE requete = p_cle;
  RETURN COALESCE(v_rejeu, '{}'::jsonb) || jsonb_build_object('rejeu', true);
END; $fn$;

comment on function public.camion_deplacer(text,text,boolean,text) is
  'Deplace un camion et ce qu''il transporte, en une transaction. 0 FR, 2 PA par occupant reellement transporte, chacun sur ses propres PA. Refus global si un membre de la section prioritaire ne peut pas payer ; debarquement des seuls opportunistes insolvables. Idempotent par cle de requete.';

revoke all on function public.camion_deplacer(text,text,boolean,text) from public, anon, authenticated;
grant execute on function public.camion_deplacer(text,text,boolean,text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 14. DONNEES — LE PREMIER CAMION ET LES DESTINATIONS DE REPUBLIA
-- ---------------------------------------------------------------------------
-- Ces lignes sont de la DONNEE de pays. Elles se dupliquent telles quelles pour
-- Sovarka, El Estado, Al-Khalija ou une seconde caserne de Republia, sans
-- qu'une ligne de code change.
insert into public.camions_destinations (pays, cle, ville, building_id, room_id, libelle, rang) values
  ('republic', 'multimodal_capitale', 'capitale', 'centre-multinodal-luthecia',           'hall_gare',           'Centre Multimodal de Luthécia',          1),
  ('republic', 'multimodal_ville_a',  'ville_a',  'centre-multinodal-port-sainte-marie',  'hall_gare_psm',       'Centre Multimodal de Port-Sainte-Marie', 2),
  ('republic', 'multimodal_ville_b',  'ville_b',  'centre-multinodal-montrouge',          'hall_gare_montrouge', 'Centre Multimodal de Montrouge',         3),
  ('republic', 'qhs',                 'qhs',      'qhs-prison',                           'entree_qhs',          'Quartier Haute Sécurité',                4)
on conflict (pays, cle) do nothing;

-- Le premier camion : rattache a la caserne de Luthecia, et stationne chez lui.
-- L'image est une DONNEE : si le fichier n'est pas encore depose, l'interieur
-- s'affiche sur son fond de repli et rien n'est bloque.
insert into public.camions_militaires (
  id, pays, institution, perimetre, libelle, capacite, image_url,
  caserne_ville, caserne_building, caserne_room, caserne_libelle,
  ville, building_id, room_id) values (
  'camion-republic-caserne-luthecia-1', 'republic', 'militaire', 'caserne-luthecia',
  'Camion militaire', 25, 'images/republia-camion-caserne.png',
  'caserne', 'caserne-militaire', 'corps_garde', 'Caserne de Républia',
  'caserne', 'caserne-militaire', 'corps_garde')
on conflict (id) do nothing;
