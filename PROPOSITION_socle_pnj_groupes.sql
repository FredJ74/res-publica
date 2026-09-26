-- =====================================================================================
-- PROPOSITION D'ARCHITECTURE -- SOCLE GENERIQUE DES GROUPES DE PNJ
-- CE FICHIER N'EST PAS APPLIQUE. AUCUNE LIGNE N'A ETE EXECUTEE EN PRODUCTION.
-- Il est soumis a validation avant toute migration, et en particulier avant de toucher
-- aux 96 soldats reels de la compagnie de Vince Kubrick.
-- 26 septembre 2026
-- =====================================================================================
--
-- PRINCIPE DIRECTEUR
-- Un seul moteur : un PNJ est un MEMBRE. Il a un PROPRIETAIRE (qui l'emploie) et,
-- separement, un LEADER COURANT (qui le porte). Ces deux notions ne se confondent jamais.
-- Le modele generalise celui des AGENTS DE RENSEIGNEMENT, seul systeme du depot qui
-- implemente deja le contrat complet ; il ne generalise PAS celui des employes, qui est
-- le moins avance des cinq (blob JSON prive, propriete et conduite confondues par
-- construction, aucune validation serveur).
--
-- REGLE DE PLACEMENT DES DONNEES -- la discipline qui evite un nouveau blob fourre-tout :
--   1. tout ce qu'une RPC GENERIQUE lit, filtre ou contraint  -> COLONNE TYPEE du socle ;
--   2. tout ce qui est propre a UNE famille                    -> TABLE METIER dediee ;
--   3. tout ce qui est enumerable et doit tomber au sol         -> LIGNES, jamais un blob.
-- Consequence assumee : LE SOCLE N'A AUCUNE COLONNE `data jsonb`. Voir la note finale.

-- -------------------------------------------------------------------------------------
-- 1. LE SOCLE
-- -------------------------------------------------------------------------------------
CREATE TABLE public.pnj_membres (
  id              text PRIMARY KEY,
  famille         text        NOT NULL,
  nom             text        NOT NULL,
  pays            text        NOT NULL,

  -- PROPRIETE -- DEUX FORMES EXCLUSIVES, JAMAIS MELANGEES.
  --
  -- (A) PROPRIETE PERSONNELLE : le PNJ appartient a un PJ nomme.
  proprietaire_pj text        NULL,
  --
  -- (B) PROPRIETE INSTITUTIONNELLE : le PNJ appartient a un POSTE, pas a une personne.
  -- On ne stocke PAS le nom du titulaire : il serait perime des la premiere nomination, et
  -- une vacance le rendrait faux. Le titulaire courant est RESOLU dynamiquement, exactement
  -- comme la position d'un suiveur est resolue depuis son chef. Trois consequences,
  -- toutes voulues :
  --   - un changement de titulaire ne touche AUCUNE ligne de pnj_membres ;
  --   - une vacance ne detruit rien et n'invente rien : plus personne ne peut administrer
  --     ces PNJ, ils restent ou ils sont ;
  --   - le nouveau titulaire herite de l'autorite par le seul fait d'etre nomme.
  -- La portee suit celle du poste : nationale (min_def, chef_douanes) ou municipale
  -- (commissaire), d'ou proprietaire_poste_ville, NULL pour un poste national.
  proprietaire_poste       text NULL,
  proprietaire_poste_ville text NULL,

  -- CONDUITE : qui le porte. Un seul leader a la fois, PJ ou PNJ, jamais les deux.
  leader_pj       text        NULL,
  leader_pnj_id   text        NULL REFERENCES public.pnj_membres(id) ON DELETE SET NULL,

  -- POSITION PROPRE : renseignee seulement s'il ne suit personne.
  ville           text        NULL,
  building_id     text        NULL,
  room_id         text        NULL,
  rue_noeud_id    text        NULL,      -- 5e niveau, aujourd'hui utilise par la police seule

  pa              integer     NOT NULL DEFAULT 12,
  statut          text        NOT NULL DEFAULT 'actif',

  cree_le         timestamptz NOT NULL DEFAULT now(),
  maj_le          timestamptz NOT NULL DEFAULT now(),

  -- I1. CONTRAT A DEUX ETATS. Reprend mot pour mot l'invariant agent_position_deux_etats,
  --     qui se tient deja en production : suivre un chef OU tenir une position, jamais les deux.
  CONSTRAINT pnj_position_deux_etats CHECK (
    ((leader_pj IS NOT NULL OR leader_pnj_id IS NOT NULL)
       AND ville IS NULL AND building_id IS NULL AND room_id IS NULL AND rue_noeud_id IS NULL)
    OR (leader_pj IS NULL AND leader_pnj_id IS NULL)
  ),
  -- I2. UN SEUL LEADER A LA FOIS.
  CONSTRAINT pnj_un_seul_leader CHECK (leader_pj IS NULL OR leader_pnj_id IS NULL),
  -- I3. PAS D'AUTO-CONDUITE.
  CONSTRAINT pnj_pas_son_propre_leader CHECK (leader_pnj_id IS DISTINCT FROM id),
  -- I4. LES PA NE SONT JAMAIS NEGATIFS. La mort est un statut, pas un nombre negatif.
  CONSTRAINT pnj_pa_positif CHECK (pa >= 0),
  CONSTRAINT pnj_statut_connu CHECK (statut IN ('actif','detenu','mort','disparu')),
  -- 'militant' vient de l'audit du 26/09 : militants_recrutes est une table dediee, avec un
  -- proprietaire PJ en colonne, que mon premier jet avait oubliee. 0 ligne en production.
  CONSTRAINT pnj_famille_connue CHECK (famille IN
    ('soldat','employe','agent','policier','douanier','militant')),
  -- I7. UNE SEULE FORME DE PROPRIETE A LA FOIS -- personnelle OU institutionnelle, jamais
  -- les deux, jamais aucune. Un PNJ sans proprietaire du tout n'a personne a informer de sa
  -- mort, ce que la section VI du brief interdit.
  CONSTRAINT pnj_propriete_exclusive CHECK (
    (proprietaire_pj IS NOT NULL AND proprietaire_poste IS NULL
       AND proprietaire_poste_ville IS NULL)
    OR (proprietaire_pj IS NULL AND proprietaire_poste IS NOT NULL)),
  -- I5. UN MORT NE SUIT PLUS PERSONNE.
  CONSTRAINT pnj_mort_sans_leader CHECK (
    statut <> 'mort' OR (leader_pj IS NULL AND leader_pnj_id IS NULL))
);

CREATE INDEX idx_pnj_leader_pj     ON public.pnj_membres(leader_pj)     WHERE leader_pj IS NOT NULL;
CREATE INDEX idx_pnj_leader_pnj    ON public.pnj_membres(leader_pnj_id) WHERE leader_pnj_id IS NOT NULL;
CREATE INDEX idx_pnj_prop_pj       ON public.pnj_membres(proprietaire_pj)
  WHERE proprietaire_pj IS NOT NULL;
CREATE INDEX idx_pnj_prop_poste    ON public.pnj_membres(pays, proprietaire_poste, proprietaire_poste_ville)
  WHERE proprietaire_poste IS NOT NULL;
CREATE INDEX idx_pnj_position      ON public.pnj_membres(pays, ville, building_id, room_id)
  WHERE statut = 'actif';
CREATE INDEX idx_pnj_famille       ON public.pnj_membres(famille, pays) WHERE statut = 'actif';

-- I6. PAS DE SOUS-HIERARCHIE. Un PNJ qui conduit quelqu'un ne peut pas lui-meme suivre un chef.
--     Non exprimable en CHECK (contrainte inter-lignes) : declencheur.
CREATE OR REPLACE FUNCTION public.pnj_pas_de_sous_hierarchie() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF (NEW.leader_pj IS NOT NULL OR NEW.leader_pnj_id IS NOT NULL)
     AND EXISTS (SELECT 1 FROM public.pnj_membres m WHERE m.leader_pnj_id = NEW.id) THEN
    RAISE EXCEPTION 'pnj_sous_hierarchie_interdite: % conduit deja des membres', NEW.id;
  END IF;
  IF NEW.leader_pnj_id IS NOT NULL AND EXISTS (
       SELECT 1 FROM public.pnj_membres m
        WHERE m.id = NEW.leader_pnj_id
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

-- -------------------------------------------------------------------------------------
-- 2. LES POSSESSIONS -- EN LIGNES, PARCE QU'ELLES DOIVENT TOMBER AU SOL
-- -------------------------------------------------------------------------------------
-- A 0 PA le PNJ meurt et ses possessions sont deposees au sol par la mecanique existante
-- (objets_abandonnes). Un depot exige d'ENUMERER les objets : un blob ne le permet pas
-- proprement, une ligne par objet si. Le grain retenu est celui d'objets_abandonnes.data,
-- qui stocke deja un objet du jeu serialise -- la plupart n'ont aucun identifiant propre.
CREATE TABLE public.pnj_possessions (
  id        bigserial PRIMARY KEY,
  pnj_id    text NOT NULL REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  objet     jsonb NOT NULL,
  exemplaire_unique boolean NOT NULL DEFAULT false,  -- correspond a chargeUnique des employes
  depuis    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_pnj_possessions_pnj ON public.pnj_possessions(pnj_id);

-- -------------------------------------------------------------------------------------
-- 2 bis. LES EVENEMENTS DU SOCLE -- « [PNJ] est mort », SANS CONNAITRE SON METIER
-- -------------------------------------------------------------------------------------
-- Le brief impose que TOUT proprietaire puisse apprendre la mort de son PNJ, et que cette
-- information NE SOIT PAS PERDUE si le poste proprietaire est vacant a cet instant.
--
-- C'est exactement le defaut constate en production sur le renseignement :
-- cellule_alerter_ministre resout le destinataire en deux temps (PJ au poste, puis PNJ de
-- titulaires_pnj) et, si les deux echouent, fait un `RETURN` NU -- sans log, sans file
-- d'attente, sans repli. Et titulaires_pnj ne contient AUCUNE ligne min_def, pour aucun
-- pays : le filet est inoperant pour ce poste precis. Toute alerte emise alors qu'aucun PJ
-- n'est min_def est donc jetee definitivement.
--
-- LE REMEDE : l'evenement n'est PAS adresse a une personne, il est adresse a la FORME DE
-- PROPRIETE -- un PJ nomme, ou un couple (poste, pays[, ville]). Il est donc ecrit meme
-- pendant une vacance, et le prochain titulaire habilite le lit en arrivant. La boite mail
-- reste un CONFORT construit par-dessus, jamais le support de verite.
CREATE TABLE public.pnj_evenements (
  id          bigserial PRIMARY KEY,
  pnj_id      text NOT NULL,            -- volontairement PAS de FK : l'evenement doit
                                        -- survivre a la purge eventuelle de la ligne PNJ
  pnj_nom     text NOT NULL,            -- fige au moment des faits, pour rester lisible
  famille     text NOT NULL,
  type        text NOT NULL,            -- 'mort' pour l'instant ; extensible par le socle
  pays        text NOT NULL,
  -- Destinataire, sous la meme forme exclusive que la propriete.
  proprietaire_pj          text NULL,
  proprietaire_poste       text NULL,
  proprietaire_poste_ville text NULL,
  -- Lieu ou la mort a eu lieu, resolu AU MOMENT DES FAITS (la position effective ne sera
  -- plus calculable ensuite : le mort ne suit plus personne).
  ville       text NULL,
  building_id text NULL,
  room_id     text NULL,
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
                                                       proprietaire_poste_ville, lu_le)
  WHERE proprietaire_poste IS NOT NULL;

-- -------------------------------------------------------------------------------------
-- 3. LES TABLES METIER -- UNE PAR FAMILLE, JAMAIS UN BLOB COMMUN
-- -------------------------------------------------------------------------------------
-- Les six axes de caracteristiques PNJ sont un ensemble FERME et verifie sur tout le depot :
-- FOR, CHA, DUP, INT, PER, VOL. Ils meritent donc six colonnes typees, pas un jsonb.
CREATE TABLE public.pnj_employes_metier (
  pnj_id      text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  job         text    NOT NULL,          -- escort, informateur, codetenu, garde, ...
  role_libelle text   NOT NULL,
  cout_jour   integer NOT NULL DEFAULT 0,
  genre       text    NULL,
  photo_url   text    NULL,
  photo_pos   text    NULL,
  car_for     integer NULL, car_cha integer NULL, car_dup integer NULL,
  car_int     integer NULL, car_per integer NULL, car_vol integer NULL,
  loyaute     integer NULL,
  depuis_jour integer NULL,
  CONSTRAINT pnj_emp_bornes CHECK (
    COALESCE(car_for,0) BETWEEN 0 AND 100 AND COALESCE(car_cha,0) BETWEEN 0 AND 100 AND
    COALESCE(car_dup,0) BETWEEN 0 AND 100 AND COALESCE(car_int,0) BETWEEN 0 AND 100 AND
    COALESCE(car_per,0) BETWEEN 0 AND 100 AND COALESCE(car_vol,0) BETWEEN 0 AND 100)
);

-- Policiers ET douaniers : meme forme metier (matricule, type, binome cynophile, PER/VOL),
-- une seule table, la famille du socle les distingue. C'est deja vrai dans le code actuel,
-- ou les deux passent par la meme liste blanche serveur.
CREATE TABLE public.pnj_force_publique_metier (
  pnj_id      text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  matricule   text    NOT NULL,
  type_unite  text    NOT NULL DEFAULT 'standard',
  maitre_nom  text    NULL,
  chien_nom   text    NULL,
  car_per     integer NOT NULL DEFAULT 12,
  car_vol     integer NOT NULL DEFAULT 12,
  recrute_le  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pnj_fp_type CHECK (type_unite IN ('standard','cynophile')),
  CONSTRAINT pnj_fp_bornes CHECK (car_per BETWEEN 0 AND 100 AND car_vol BETWEEN 0 AND 100),
  CONSTRAINT pnj_fp_cyno CHECK (type_unite <> 'cynophile' OR chien_nom IS NOT NULL)
);
CREATE UNIQUE INDEX idx_pnj_fp_matricule ON public.pnj_force_publique_metier(matricule);

-- MILITANTS : famille oubliee de mon premier jet. Metier minuscule -- le grade affiche et
-- le syndicat d'appartenance -- mais il existe, et il ne doit pas remonter dans le socle.
CREATE TABLE public.pnj_militants_metier (
  pnj_id         text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  organisation_id text NOT NULL,
  grade          text NOT NULL DEFAULT 'Militant (PNJ)',
  rejoint_le     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_pnj_militants_orga ON public.pnj_militants_metier(organisation_id);

-- RESOLUTION DU TITULAIRE D'UN POSTE PROPRIETAIRE. Pendant : aucun. C'est la symetrie
-- exacte de pnj_position_effective : on ne stocke pas le titulaire, on le resout.
-- Renvoie NULL quand le poste est vacant -- et un NULL ici veut dire « personne ne peut
-- administrer ces PNJ aujourd'hui », jamais « ces PNJ n'existent plus ».
CREATE OR REPLACE FUNCTION public.pnj_titulaire_du_poste(
  p_pays text, p_poste text, p_ville text DEFAULT NULL)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT d.name FROM public.personnages_donnees d
   WHERE d.country = p_pays
     AND d.poste->>'id' = p_poste
     AND (p_ville IS NULL OR d.poste->>'city' = p_ville)
   LIMIT 1;
$$;

-- SOLDATS : leur metier reste dans compagnies_militaires.data (sections, reserve,
-- lieutenantNom, formation, arme, mission, mutin, compteurs de sommeil/ration/bivouac).
-- On n'y touche pas : 44 fonctions serveur le lisent, dont 22 seulement touchent un axe
-- generique. Le socle devient autoritaire sur ces 22 axes, le blob garde le reste.
-- AGENTS : leur metier reste dans agents_renseignement (cellule_id, role, vrai_nom, dup,
-- pays_couverture, nom_couverture, detention_id, detenu_depuis) -- c'est deja une vraie table.

-- -------------------------------------------------------------------------------------
-- 4. LA PRIMITIVE UNIQUE DE POSITION -- elle remplace 5 recopies SQL et 2 predicats clients
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pnj_position_effective(p_id text)
RETURNS TABLE(pays text, ville text, building_id text, room_id text,
              rue_noeud_id text, porte boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  -- Aucune copie synchronisee a chaque deplacement : le wagon est a la position de sa
  -- locomotive. La profondeur est bornee a 1 par l'invariant I6 (pas de sous-hierarchie),
  -- donc deux LEFT JOIN suffisent et aucune recursion n'est necessaire.
  SELECT m.pays,
         CASE WHEN m.leader_pj IS NOT NULL THEN d.current_city
              WHEN m.leader_pnj_id IS NOT NULL THEN l.ville ELSE m.ville END,
         CASE WHEN m.leader_pj IS NOT NULL THEN d.current_building
              WHEN m.leader_pnj_id IS NOT NULL THEN l.building_id ELSE m.building_id END,
         CASE WHEN m.leader_pj IS NOT NULL THEN d.current_room
              WHEN m.leader_pnj_id IS NOT NULL THEN l.room_id ELSE m.room_id END,
         CASE WHEN m.leader_pj IS NOT NULL THEN NULL
              WHEN m.leader_pnj_id IS NOT NULL THEN l.rue_noeud_id ELSE m.rue_noeud_id END,
         (m.leader_pj IS NOT NULL OR m.leader_pnj_id IS NOT NULL)
    FROM public.pnj_membres m
    LEFT JOIN public.personnages_donnees d ON d.name = m.leader_pj
    LEFT JOIN public.pnj_membres        l ON l.id   = m.leader_pnj_id
   WHERE m.id = p_id;
$$;

-- -------------------------------------------------------------------------------------
-- 5. DROITS -- le client ne touche jamais ces tables, seulement les RPC
-- -------------------------------------------------------------------------------------
ALTER TABLE public.pnj_membres              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_possessions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_employes_metier      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pnj_force_publique_metier ENABLE ROW LEVEL SECURITY;
-- ZERO policy, comme agents_renseignement : aucune lecture ni ecriture directe.
-- Les SECURITY DEFINER appartenant a postgres contournent la RLS ; tout passe par elles.
REVOKE ALL ON public.pnj_membres, public.pnj_possessions,
              public.pnj_employes_metier, public.pnj_force_publique_metier
       FROM PUBLIC, anon, authenticated;
