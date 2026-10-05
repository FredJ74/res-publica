-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260926131643
-- Nom original      : socle_pnj_schema
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-26 13:16:43 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 579751a50ac9dea2163d0a956b556a85
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- SOCLE GENERIQUE DES PNJ EMPLOYABLES DE RES PUBLICA -- 26 septembre 2026
-- Feu vert explicite du concepteur. Snapshot militaire pris juste avant.
--
-- PRINCIPE DEFINITIF : SOCLE MINIMAL + COUCHES METIER.
-- Le socle fournit identite, famille, propriete, leader, position, groupe, 12 PA,
-- caracteristiques generiques, possessions, evenements, primitives atomiques, invariants et
-- cycle de mort. Il ne decide JAMAIS comment les PA sont depenses ou recuperes, pourquoi un
-- PNJ se deplace ou est recrute, son prix, son salaire, ses competences, ses ordres metier,
-- ni les consequences metier de sa mort.
-- UNE ABSENCE DE REGLE METIER NE DEVIENT JAMAIS UN COMPORTEMENT GENERIQUE.
--
-- Le modele generalise celui des AGENTS DE RENSEIGNEMENT, seul systeme du depot qui
-- implementait deja le contrat complet ; il ne generalise PAS celui des employes, qui etait
-- le moins avance (blob JSON prive, propriete et conduite confondues, aucune validation).
--
-- REGLE DE PLACEMENT DES DONNEES, la discipline qui evite un nouveau blob fourre-tout :
--   1. ce qu'une RPC GENERIQUE lit, filtre ou contraint  -> COLONNE TYPEE du socle ;
--   2. ce qui est propre a UNE famille                   -> TABLE METIER dediee ;
--   3. ce qui est enumerable et doit tomber au sol        -> LIGNES, jamais un blob.
-- Consequence assumee : AUCUNE colonne `data jsonb` dans le socle.

CREATE TABLE public.pnj_membres (
  id              text PRIMARY KEY,
  famille         text        NOT NULL,
  nom             text        NOT NULL,
  pays            text        NOT NULL,

  -- PROPRIETE -- DEUX FORMES EXCLUSIVES, JAMAIS MELANGEES.
  -- (A) personnelle : le PNJ appartient a un PJ nomme.
  proprietaire_pj text        NULL,
  -- (B) institutionnelle : le PNJ appartient a un POSTE, pas a une personne. On ne stocke
  -- PAS le nom du titulaire : il serait perime des la premiere nomination et faux pendant une
  -- vacance. Il est RESOLU par pnj_titulaire_du_poste(), symetrie exacte de
  -- pnj_position_effective(). Trois consequences voulues : un changement de titulaire ne
  -- touche aucune ligne ; une vacance ne detruit rien et n'invente rien ; le nouveau titulaire
  -- herite de l'autorite par le seul fait d'etre nomme.
  proprietaire_poste       text NULL,
  proprietaire_poste_ville text NULL,

  -- CONDUITE : un seul leader a la fois, PJ ou PNJ, jamais les deux.
  leader_pj       text        NULL,
  leader_pnj_id   text        NULL REFERENCES public.pnj_membres(id) ON DELETE SET NULL,

  -- POSITION PROPRE : renseignee seulement s'il ne suit personne.
  ville           text        NULL,
  building_id     text        NULL,
  room_id         text        NULL,
  rue_noeud_id    text        NULL,   -- 5e niveau, aujourd'hui utilise par la police seule

  pa              integer     NOT NULL DEFAULT 12,
  liquide         numeric     NOT NULL DEFAULT 0,
  statut          text        NOT NULL DEFAULT 'actif',

  -- Les six axes de caracteristiques PNJ forment un ensemble FERME, verifie sur tout le
  -- depot : FOR, CHA, DUP, INT, PER, VOL. Six colonnes typees, pas un jsonb.
  car_for integer NULL, car_cha integer NULL, car_dup integer NULL,
  car_int integer NULL, car_per integer NULL, car_vol integer NULL,

  cree_le         timestamptz NOT NULL DEFAULT now(),
  maj_le          timestamptz NOT NULL DEFAULT now(),

  -- I1. CONTRAT A DEUX ETATS : suivre un chef OU tenir une position, jamais les deux.
  --     Reprend l'invariant agent_position_deux_etats, qui se tient deja en production.
  CONSTRAINT pnj_position_deux_etats CHECK (
    ((leader_pj IS NOT NULL OR leader_pnj_id IS NOT NULL)
       AND ville IS NULL AND building_id IS NULL AND room_id IS NULL AND rue_noeud_id IS NULL)
    OR (leader_pj IS NULL AND leader_pnj_id IS NULL)),
  -- I2. UN SEUL LEADER A LA FOIS.
  CONSTRAINT pnj_un_seul_leader CHECK (leader_pj IS NULL OR leader_pnj_id IS NULL),
  -- I3. PAS D'AUTO-CONDUITE.
  CONSTRAINT pnj_pas_son_propre_leader CHECK (leader_pnj_id IS DISTINCT FROM id),
  -- I4. LES PA NE SONT JAMAIS NEGATIFS. La mort est un statut, pas un nombre negatif.
  CONSTRAINT pnj_pa_positif CHECK (pa >= 0),
  CONSTRAINT pnj_statut_connu CHECK (statut IN ('actif','detenu','mort','disparu')),
  CONSTRAINT pnj_famille_connue CHECK (famille IN
    ('soldat','employe','agent','policier','douanier','militant')),
  -- I7. UNE SEULE FORME DE PROPRIETE. Un PNJ sans proprietaire n'a personne a informer de sa
  --     mort, ce que le socle exige.
  CONSTRAINT pnj_propriete_exclusive CHECK (
    (proprietaire_pj IS NOT NULL AND proprietaire_poste IS NULL
       AND proprietaire_poste_ville IS NULL)
    OR (proprietaire_pj IS NULL AND proprietaire_poste IS NOT NULL)),
  -- I5. UN MORT NE SUIT PLUS PERSONNE.
  CONSTRAINT pnj_mort_sans_leader CHECK (
    statut <> 'mort' OR (leader_pj IS NULL AND leader_pnj_id IS NULL)),
  CONSTRAINT pnj_car_bornes CHECK (
    COALESCE(car_for,0) BETWEEN 0 AND 100 AND COALESCE(car_cha,0) BETWEEN 0 AND 100 AND
    COALESCE(car_dup,0) BETWEEN 0 AND 100 AND COALESCE(car_int,0) BETWEEN 0 AND 100 AND
    COALESCE(car_per,0) BETWEEN 0 AND 100 AND COALESCE(car_vol,0) BETWEEN 0 AND 100)
);

CREATE INDEX idx_pnj_leader_pj    ON public.pnj_membres(leader_pj) WHERE leader_pj IS NOT NULL;
CREATE INDEX idx_pnj_leader_pnj   ON public.pnj_membres(leader_pnj_id) WHERE leader_pnj_id IS NOT NULL;
CREATE INDEX idx_pnj_prop_pj      ON public.pnj_membres(proprietaire_pj) WHERE proprietaire_pj IS NOT NULL;
CREATE INDEX idx_pnj_prop_poste   ON public.pnj_membres(pays, proprietaire_poste, proprietaire_poste_ville)
  WHERE proprietaire_poste IS NOT NULL;
CREATE INDEX idx_pnj_position     ON public.pnj_membres(pays, ville, building_id, room_id)
  WHERE statut = 'actif';
CREATE INDEX idx_pnj_famille      ON public.pnj_membres(famille, pays) WHERE statut = 'actif';

-- I6. PAS DE SOUS-HIERARCHIE : un PNJ qui conduit quelqu'un ne peut pas lui-meme suivre un
--     chef. Contrainte inter-lignes, donc declencheur. Elle borne la profondeur de derivation
--     a 1, ce qui garde pnj_position_effective a deux LEFT JOIN sans recursion.
CREATE OR REPLACE FUNCTION public.pnj_pas_de_sous_hierarchie() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF (NEW.leader_pj IS NOT NULL OR NEW.leader_pnj_id IS NOT NULL)
     AND EXISTS (SELECT 1 FROM public.pnj_membres m WHERE m.leader_pnj_id = NEW.id) THEN
    RAISE EXCEPTION 'pnj_sous_hierarchie_interdite: % conduit deja des membres', NEW.id;
  END IF;
  IF NEW.leader_pnj_id IS NOT NULL AND EXISTS (
       SELECT 1 FROM public.pnj_membres m WHERE m.id = NEW.leader_pnj_id
         AND (m.leader_pj IS NOT NULL OR m.leader_pnj_id IS NOT NULL)) THEN
    RAISE EXCEPTION 'pnj_sous_hierarchie_interdite: le leader % suit lui-meme un chef',
                    NEW.leader_pnj_id;
  END IF;
  NEW.maj_le := now();
  RETURN NEW;
END; $$;
CREATE TRIGGER trg_pnj_pas_de_sous_hierarchie
  BEFORE INSERT OR UPDATE ON public.pnj_membres
  FOR EACH ROW EXECUTE FUNCTION public.pnj_pas_de_sous_hierarchie();

-- POSSESSIONS EN LIGNES, parce qu'elles doivent tomber au sol une par une a la mort.
-- Le grain est celui de objets_abandonnes.data : la plupart des objets du jeu n'ont aucun id.
CREATE TABLE public.pnj_possessions (
  id        bigserial PRIMARY KEY,
  pnj_id    text NOT NULL REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  objet     jsonb NOT NULL,
  exemplaire_unique boolean NOT NULL DEFAULT false,
  depuis    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_pnj_possessions_pnj ON public.pnj_possessions(pnj_id);

-- EVENEMENTS DU SOCLE -- « [PNJ] est mort », sans connaitre son metier.
-- L'evenement est adresse a la FORME DE PROPRIETE, jamais a une personne : il est donc ecrit
-- meme pendant une vacance de poste, et le prochain titulaire le lit en arrivant. C'est le
-- remede au defaut constate en production sur cellule_alerter_ministre, qui fait un RETURN nu
-- quand aucun destinataire n'existe -- et titulaires_pnj ne contient aucune ligne min_def.
CREATE TABLE public.pnj_evenements (
  id          bigserial PRIMARY KEY,
  pnj_id      text NOT NULL,   -- volontairement PAS de FK : l'evenement survit a la ligne PNJ
  pnj_nom     text NOT NULL,
  famille     text NOT NULL,
  type        text NOT NULL,
  pays        text NOT NULL,
  proprietaire_pj          text NULL,
  proprietaire_poste       text NULL,
  proprietaire_poste_ville text NULL,
  ville       text NULL, building_id text NULL, room_id text NULL,
  cree_le     timestamptz NOT NULL DEFAULT now(),
  lu_le       timestamptz NULL,
  lu_par      text NULL,
  CONSTRAINT pnj_evt_type CHECK (type IN ('mort')),
  CONSTRAINT pnj_evt_destinataire CHECK (
    (proprietaire_pj IS NOT NULL AND proprietaire_poste IS NULL)
    OR (proprietaire_pj IS NULL AND proprietaire_poste IS NOT NULL))
);
CREATE INDEX idx_pnj_evt_pj    ON public.pnj_evenements(proprietaire_pj, lu_le)
  WHERE proprietaire_pj IS NOT NULL;
CREATE INDEX idx_pnj_evt_poste ON public.pnj_evenements(pays, proprietaire_poste,
  proprietaire_poste_ville, lu_le) WHERE proprietaire_poste IS NOT NULL;

-- TABLES METIER -- une par famille, jamais un blob commun.
CREATE TABLE public.pnj_soldats_metier (
  pnj_id     text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  matricule  text NOT NULL,
  section_id text NULL,             -- NULL = en reserve
  en_reserve boolean NOT NULL,
  arme       text NULL,
  formation  jsonb NOT NULL DEFAULT '{}'::jsonb,   -- 4 axes militaires, metier pur
  CONSTRAINT soldat_reserve_coherente CHECK (en_reserve = (section_id IS NULL))
);
CREATE UNIQUE INDEX idx_pnj_soldats_matricule ON public.pnj_soldats_metier(matricule);

CREATE TABLE public.pnj_employes_metier (
  pnj_id       text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  job          text NOT NULL,
  role_libelle text NOT NULL,
  cout_jour    integer NOT NULL DEFAULT 0,
  genre        text NULL,
  photo_url    text NULL,
  photo_pos    text NULL,
  loyaute      integer NULL,
  depuis_jour  integer NULL
);

CREATE TABLE public.pnj_force_publique_metier (
  pnj_id      text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  matricule   text NOT NULL,
  type_unite  text NOT NULL DEFAULT 'standard',
  maitre_nom  text NULL,
  chien_nom   text NULL,
  recrute_le  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pnj_fp_type CHECK (type_unite IN ('standard','cynophile')),
  CONSTRAINT pnj_fp_cyno CHECK (type_unite <> 'cynophile' OR chien_nom IS NOT NULL)
);
CREATE UNIQUE INDEX idx_pnj_fp_matricule ON public.pnj_force_publique_metier(matricule);

CREATE TABLE public.pnj_militants_metier (
  pnj_id          text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  organisation_id text NOT NULL,
  grade           text NOT NULL DEFAULT 'Militant (PNJ)',
  rejoint_le      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_pnj_militants_orga ON public.pnj_militants_metier(organisation_id);

-- DROITS : le client ne touche JAMAIS ces tables. RLS activee, ZERO policy, comme
-- agents_renseignement. Les SECURITY DEFINER appartenant a postgres contournent la RLS ;
-- tout passe par elles.
ALTER TABLE public.pnj_membres               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_possessions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_evenements            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_soldats_metier        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_employes_metier       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_force_publique_metier ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_militants_metier      ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.pnj_membres, public.pnj_possessions, public.pnj_evenements,
              public.pnj_soldats_metier, public.pnj_employes_metier,
              public.pnj_force_publique_metier, public.pnj_militants_metier
  FROM PUBLIC, anon, authenticated;