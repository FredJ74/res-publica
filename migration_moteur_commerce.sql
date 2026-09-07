-- =====================================================================
-- LOT 4.0 — MOTEUR GENERIQUE DES COMMERCES : PERSISTANCE ET TRANSACTIONS
-- 8 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
-- Tous les appels sont fail-closed : tant que ces objets n'existent pas, sbRpc renvoie null,
-- l'action est refusee, et rien n'est ecrit nulle part.
--
-- CE QUE CE FICHIER AJOUTE
--   2 colonnes sur personnages : qualifications, effets_actifs
--   2 tables                   : oeuvres, offres        -- EN LECTURE SEULE pour le navigateur
--   1 rouage interne           : ref_patrimoine_existe  -- non expose
--   5 RPC                      : creer_oeuvre, creer_offre,
--                                acheter_produit_commerce, employer_fonds, repondre_offre
--
-- CE QU'IL NE TOUCHE PAS : les 14 etablissements PNJ historiques d'entreprises, dont aucune ligne
-- n'est migree ni relue. Les fonds v2 gagnent des champs facultatifs (references, salaries,
-- matieresRecherchees, famille) que l'absence rend simplement inertes.
--
-- RLS : le grand chantier securite est separe et ce fichier ne l'ouvre pas. Mais les DEUX tables
-- creees ici naissent en ECRITURE FERMEE -- aucun INSERT, UPDATE ni DELETE direct pour anon et
-- authenticated. Toute ecriture passe par une RPC qui pose elle-meme l'identifiant, les dates et
-- le statut, et qui verifie la qualite du demandeur sur l'actif quand le serveur peut la connaitre.
-- Ces deux tables portent des references typees (auteur, emetteur) : les ouvrir en INSERT direct
-- aurait laisse n'importe quel navigateur ecrire au nom d'un autre PJ. On n'aggrave pas la dette
-- existante, et on n'en cree pas une nouvelle.
--
-- CE QUE CELA NE FAIT PAS : lier une requete a un joueur. Le jeu n'a aucune authentification (voir
-- l'encadre de la section 7) ; ce fichier ferme la fabrication directe, pas l'usurpation par appel.

-- ---------------------------------------------------------------------
-- 1. QUALIFICATIONS PROFESSIONNELLES DURABLES
-- ---------------------------------------------------------------------
-- L'audit du 8 septembre 2026 a etabli que school et career sont persistes depuis toujours mais
-- inertes apres la creation du personnage, et que l'Universite ne delivre qu'un bonus de 24 h.
-- Cette colonne porte les qualifications ACQUISES ; celles du parcours initial restent derivees
-- de career (QUALIFICATIONS_PAR_CARRIERE, plateau-commerce.js) et ne sont donc pas recopiees --
-- une seule verite, pas deux.
--
-- Tableau de chaines, jamais d'objet : une qualification se possede ou non, elle n'a ni niveau ni
-- experience. Le cahier des charges exclut explicitement un arbre de competences.
ALTER TABLE personnages ADD COLUMN IF NOT EXISTS qualifications jsonb NOT NULL DEFAULT '[]'::jsonb;

-- ---------------------------------------------------------------------
-- 2. EFFETS TEMPORAIRES ACTIFS
-- ---------------------------------------------------------------------
-- L'audit a montre la faiblesse de l'existant : bonus purges uniquement au Dormir, cote client,
-- donc conserves indefiniment par un joueur qui ne dort pas ; et deux horloges concurrentes.
--
-- Chaque effet porte ici sa date d'expiration ABSOLUE en millisecondes reelles. Il est mort quand
-- l'heure est passee, que le joueur dorme, se connecte ou non -- aucun balayage n'est necessaire
-- pour que l'expiration soit vraie. Le nettoyage n'est qu'une hygiene, faite a l'ecriture.
ALTER TABLE personnages ADD COLUMN IF NOT EXISTS effets_actifs jsonb NOT NULL DEFAULT '[]'::jsonb;

-- ---------------------------------------------------------------------
-- 3. OEUVRES — LA CREATION, DISTINCTE DE SES EXEMPLAIRES
-- ---------------------------------------------------------------------
-- Un livre n'est pas son texte : mille exemplaires partagent une oeuvre. L'oeuvre vit ici ;
-- l'exemplaire, dans l'inventaire, n'en porte que la REFERENCE. Recopier le contenu dans chaque
-- exemplaire creerait autant de verites divergentes qu'il y a d'objets.
--
-- Vaut pour le livre, la VHS, le tableau, le document, la piece de collection.
CREATE TABLE IF NOT EXISTS oeuvres (
  id          text PRIMARY KEY,
  type        text        NOT NULL,          -- 'livre' | 'audiovisuel' | 'art' | ...
  titre       text        NOT NULL,
  auteur      text,                          -- reference typee 'pj:' / 'orga:' / NULL si PNJ
  country     text,
  jour        integer,                       -- jour de jeu de la creation
  contenu     text,                          -- texte de l'oeuvre, le cas echeant
  data        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS oeuvres_auteur_idx ON oeuvres (auteur);
CREATE INDEX IF NOT EXISTS oeuvres_type_idx   ON oeuvres (type);

ALTER TABLE oeuvres ENABLE ROW LEVEL SECURITY;

-- Une oeuvre est publique par nature -- on la lit pour l'exposer, la citer, la lire. En revanche
-- elle ne se REECRIT pas : une fois publiee, son texte est ce qu'il est. Pas de policy UPDATE ni
-- DELETE, meme doctrine que dossiers_urbanisme et locations_archives.
--
-- PAS DE POLICY INSERT NON PLUS. Le champ auteur est une reference typee : laisser le navigateur
-- inserer directement reviendrait a laisser n'importe qui signer une oeuvre du nom d'un autre PJ.
-- La creation passe donc par creer_oeuvre (section 6), seule voie d'ecriture.
DROP POLICY IF EXISTS oeuvres_select ON oeuvres;
CREATE POLICY oeuvres_select ON oeuvres FOR SELECT USING (true);
DROP POLICY IF EXISTS oeuvres_insert ON oeuvres;

GRANT SELECT ON oeuvres TO anon, authenticated, service_role;
GRANT INSERT ON oeuvres TO service_role;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON oeuvres FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. OFFRES — LE CANAL BILATERAL GENERIQUE
-- ---------------------------------------------------------------------
-- L'audit a identifie ce manque comme structurellement bloquant : chaque mecanique bilaterale a
-- aujourd'hui sa table et sa logique, et l'absence de canal commun empeche a elle seule la vente
-- d'objet entre PJ, la vente de fonds et l'accord amiable -- dont les RPC existent deja mais
-- restent hors de portee du navigateur faute de preuve d'acceptation.
--
-- Une offre est une PROPOSITION datee. Elle ne transfere rien par elle-meme : c'est l'acceptation,
-- executee cote serveur, qui agit. C'est precisement cette preuve qui manquait.
CREATE TABLE IF NOT EXISTS offres (
  id            text PRIMARY KEY,
  type          text        NOT NULL,        -- vente_objet | vente_fonds | resiliation_amiable | prestation
  emetteur      text        NOT NULL,        -- reference typee
  destinataire  text        NOT NULL,        -- reference typee
  actif         text,                        -- ce sur quoi porte l'offre (id d'objet, de fonds, de bail)
  montant       integer     NOT NULL DEFAULT 0,
  statut        text        NOT NULL DEFAULT 'ouverte',
  data          jsonb       NOT NULL DEFAULT '{}'::jsonb,
  expire_a      timestamptz NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  resolu_a      timestamptz,
  CONSTRAINT offres_statut_valide CHECK (statut IN ('ouverte','acceptee','refusee','expiree','annulee')),
  CONSTRAINT offres_type_valide   CHECK (type IN ('vente_objet','vente_fonds','resiliation_amiable','prestation')),
  CONSTRAINT offres_parties       CHECK (emetteur <> destinataire)
);

CREATE INDEX IF NOT EXISTS offres_destinataire_idx ON offres (destinataire, statut);
CREATE INDEX IF NOT EXISTS offres_emetteur_idx     ON offres (emetteur, statut);

ALTER TABLE offres ENABLE ROW LEVEL SECURITY;

-- ECRITURE : AUCUNE. Ni INSERT, ni UPDATE, ni DELETE.
--
-- Une premiere version de ce fichier ouvrait l'INSERT en s'en remettant a la RPC pour verifier
-- l'emetteur -- ce qui ne verifiait rien du tout, puisque la table restait joignable en direct par
-- PostgREST. N'importe quel navigateur pouvait donc fabriquer une ligne en se declarant emetteur au
-- nom d'un autre PJ, avec l'id, la date, l'expiration et le statut de son choix. C'est ferme.
--   creation           -> creer_offre    (section 7)
--   changement d'etat  -> repondre_offre (section 10), sous verrou
--
-- LECTURE : ouverte, et c'est une limite assumee, pas un choix. Restreindre le SELECT aux parties
-- suppose de savoir QUI interroge ; or le jeu n'a aujourd'hui aucune identite par requete -- tous
-- les navigateurs partagent la meme cle anon. Une policy "USING (destinataire = ...)" ne pourrait
-- comparer qu'a une valeur fournie par le client lui-meme, c'est-a-dire a rien. Le cloisonnement
-- en lecture appartient au chantier identite, et le poser ici serait un decor.
DROP POLICY IF EXISTS offres_select ON offres;
CREATE POLICY offres_select ON offres FOR SELECT USING (true);
DROP POLICY IF EXISTS offres_insert ON offres;

GRANT SELECT ON offres TO anon, authenticated, service_role;
GRANT INSERT ON offres TO service_role;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON offres FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. EXISTENCE D'UNE REFERENCE PATRIMONIALE — ROUAGE INTERNE
-- ---------------------------------------------------------------------
-- Meme grammaire de reference que mouvement_titulaire, a la lettre : 'orga:<id>', 'pj:<nom>',
-- un nom nu valant pj, et 'ville:' refuse -- une municipalite n'est pas partie a un accord
-- bilateral de ce canal. Deux lectures de la meme grammaire finiraient par diverger ; celle-ci
-- est donc copiee sur l'autre et doit le rester.
--
-- Constate l'existence SANS poser de verrou : creer_offre n'a aucune raison de bloquer deux
-- patrimoines pour ecrire une proposition qui ne deplace rien.
--
-- NON EXPOSEE : rouage, comme mouvement_titulaire.
CREATE OR REPLACE FUNCTION ref_patrimoine_existe(p_ref text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF COALESCE(p_ref, '') = '' THEN RETURN false; END IF;

  IF left(p_ref, 5) = 'orga:' THEN
    RETURN EXISTS (SELECT 1 FROM organisations WHERE id = substr(p_ref, 6));
  ELSIF left(p_ref, 3) = 'pj:' THEN
    RETURN EXISTS (SELECT 1 FROM personnages WHERE name = substr(p_ref, 4));
  ELSIF left(p_ref, 6) = 'ville:' THEN
    RETURN false;
  END IF;

  RETURN EXISTS (SELECT 1 FROM personnages WHERE name = p_ref);
END;
$$;

-- ---------------------------------------------------------------------
-- 6. CREATION D'UNE OEUVRE — SEULE VOIE D'ECRITURE DANS oeuvres
-- ---------------------------------------------------------------------
-- Signer une oeuvre du nom d'un autre est une usurpation, et c'etait possible tant que l'INSERT
-- restait ouvert. Cette RPC est desormais le seul chemin.
--
-- CE QU'ELLE GARANTIT : l'identifiant, les horodatages et l'immuabilite sont poses par le serveur ;
-- un auteur declare doit exister reellement ; le titre et le contenu sont bornes ; un doublon
-- exact rend l'oeuvre deja publiee au lieu d'en creer une seconde.
--
-- CE QU'ELLE NE GARANTIT PAS, et qu'il faut savoir : que le demandeur EST l'auteur qu'il declare.
-- Cela suppose une identite par requete, que le jeu n'a pas. Voir la note de la section 7.
--
-- Le type n'est PAS restreint a une liste : arreter la nomenclature des oeuvres est une decision
-- de contenu, pas de securite. Seule la FORME est validee -- un identifiant court et sobre.
CREATE OR REPLACE FUNCTION creer_oeuvre(
  p_auteur  text,
  p_type    text,
  p_titre   text,
  p_country text,
  p_jour    integer,
  p_contenu text,
  p_data    jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auteur  text := NULLIF(btrim(COALESCE(p_auteur, '')), '');
  v_type    text := lower(btrim(COALESCE(p_type, '')));
  v_titre   text := btrim(COALESCE(p_titre, ''));
  v_contenu text := COALESCE(p_contenu, '');
  v_data    jsonb;
  v_id      text;
  v_deja    text;
BEGIN
  IF v_titre = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'titre_requis'); END IF;
  IF length(v_titre) > 200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'titre_trop_long'); END IF;
  IF v_type !~ '^[a-z][a-z0-9_]{1,39}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_invalide');
  END IF;
  IF length(v_contenu) > 200000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'contenu_trop_volumineux');
  END IF;

  -- Un auteur absent est licite : c'est une oeuvre anonyme ou d'origine PNJ. Un auteur DECLARE,
  -- lui, doit exister -- on ne signe pas du nom d'un fantome.
  IF v_auteur IS NOT NULL AND NOT ref_patrimoine_existe(v_auteur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auteur_inexistant');
  END IF;

  v_data := COALESCE(p_data, '{}'::jsonb);
  IF jsonb_typeof(v_data) <> 'object' THEN v_data := '{}'::jsonb; END IF;
  v_data := v_data - 'id' - 'auteur' - 'created_at' - 'updated_at';
  IF length(v_data::text) > 8000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'data_trop_volumineux');
  END IF;

  -- Doublon exact : le meme auteur ne republie pas deux fois la meme chose. Rendre l'existante est
  -- plus utile qu'une erreur -- un double-clic ne doit pas produire deux oeuvres.
  SELECT id INTO v_deja FROM oeuvres
   WHERE type = v_type AND titre = v_titre
     AND COALESCE(auteur, '') = COALESCE(v_auteur, '')
   LIMIT 1;
  IF v_deja IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'id', v_deja, 'doublon', true);
  END IF;

  v_id := 'oeuvre-' || extract(epoch from clock_timestamp())::bigint || '-'
          || substr(md5(random()::text || COALESCE(v_auteur, '') || v_titre), 1, 8);

  INSERT INTO oeuvres (id, type, titre, auteur, country, jour, contenu, data)
  VALUES (v_id, v_type, v_titre, v_auteur,
          NULLIF(btrim(COALESCE(p_country, '')), ''), p_jour,
          NULLIF(v_contenu, ''), v_data);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'doublon', false);
END;
$$;

-- ---------------------------------------------------------------------
-- 7. CREATION D'UNE OFFRE — SEULE VOIE D'ECRITURE DANS offres
-- ---------------------------------------------------------------------
-- CE QUE LE CLIENT NE CHOISIT PLUS. Ni l'id, ni la date de creation, ni l'expiration, ni le statut :
-- ces champs ne sont pas des parametres de cette fonction, ils sont poses ici. Une offre nait donc
-- toujours 'ouverte' -- il est desormais impossible de faire apparaitre en base une offre deja
-- acceptee, deja refusee ou anterieure a sa propre creation. La duree est la seule part negociable,
-- et elle est bornee.
--
-- CE QUI EST VERIFIE : que les deux parties existent, qu'elles sont distinctes, que le type
-- appartient au registre, que les termes ont une forme et une taille admissibles, et -- quand
-- l'actif est connu du serveur -- QUE L'EMETTEUR A QUALITE POUR L'OFFRIR.
--
-- ┌─ CE QUI N'EST PAS VERIFIE, ET QU'IL FAUT LIRE AVANT DE S'Y FIER ────────────────────────────┐
-- │ Que le navigateur qui appelle EST bien l'emetteur qu'il declare.                            │
-- │                                                                                             │
-- │ Res Publica n'a aujourd'hui AUCUNE authentification : pas de auth.uid(), pas de session, pas │
-- │ de secret par personnage. Tous les joueurs partagent la meme cle anon, et l'identite du      │
-- │ personnage n'est qu'un nom conserve dans le localStorage du navigateur. Aucune fonction SQL  │
-- │ ne peut donc distinguer le vrai Untel d'un client qui saisit son nom.                        │
-- │                                                                                             │
-- │ Ce que cette RPC apporte malgre cela, et qui n'est pas rien :                                │
-- │  - la fabrication directe de lignes arbitraires est fermee (plus d'INSERT PostgREST) ;       │
-- │  - une offre forgee ne peut plus etre anti-datee, pre-acceptee ni rendue eternelle ;         │
-- │  - sur les deux types dont l'actif est connu du serveur, l'emetteur doit reellement DETENIR  │
-- │    ce qu'il propose : on ne peut plus vendre le fonds d'autrui ni resilier le bail d'autrui, │
-- │    quel que soit le nom que l'on se donne ;                                                  │
-- │  - le volume est borne, ce qui retire l'interet du spam.                                     │
-- │                                                                                             │
-- │ Le residu -- se faire passer pour un autre en l'appelant -- n'est PAS propre aux offres : il │
-- │ vaut identiquement pour acheter_produit_commerce, employer_fonds, retirer_caisse_fonds et    │
-- │ toutes les RPC deja en production. Il se ferme d'un seul coup le jour du chantier identite,  │
-- │ pas table par table. Apres ce correctif, offres n'est plus le maillon faible : elle est au   │
-- │ niveau du reste du projet.                                                                   │
-- └─────────────────────────────────────────────────────────────────────────────────────────────┘
CREATE OR REPLACE FUNCTION creer_offre(
  p_emetteur     text,
  p_destinataire text,
  p_type         text,
  p_actif        text,
  p_montant      integer,
  p_duree_ms     bigint,
  p_data         jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  -- Bornes techniques, volontairement larges : elles bornent l'abus, elles n'arbitrent aucune
  -- regle de jeu. Les changer suppose une migration -- c'est le prix de les tenir cote serveur.
  c_offres_max    constant integer := 20;                    -- offres ouvertes par emetteur
  c_duree_min     constant bigint  := 3600000;               -- 1 heure
  c_duree_max     constant bigint  := 30 * 24 * 3600000;     -- 30 jours
  c_duree_defaut  constant bigint  := 3 * 24 * 3600000;      -- 3 jours (= OFFRE_DUREE_MS_DEFAUT)

  v_em        text    := btrim(COALESCE(p_emetteur, ''));
  v_de        text    := btrim(COALESCE(p_destinataire, ''));
  v_type      text    := btrim(COALESCE(p_type, ''));
  v_actif     text    := NULLIF(btrim(COALESCE(p_actif, '')), '');
  v_montant   integer := GREATEST(0, COALESCE(p_montant, 0));
  v_duree     bigint;
  v_data      jsonb;
  v_id        text;
  v_deja      text;
  v_ouvertes  integer;
  v_fonds     jsonb;
  v_bail      jsonb;
  v_locataire text;
  v_bailleur  text;
BEGIN
  IF v_em = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'emetteur_requis'); END IF;
  IF v_de = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_requis'); END IF;
  IF v_em = v_de THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_identique'); END IF;

  -- Registre ferme. Redonde volontairement la contrainte CHECK de la table : une contrainte
  -- protege la donnee, un verdict explicite protege l'appelant en lui disant pourquoi.
  IF v_type NOT IN ('vente_objet', 'vente_fonds', 'resiliation_amiable', 'prestation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_invalide');
  END IF;

  IF NOT ref_patrimoine_existe(v_em) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'emetteur_inexistant');
  END IF;
  IF NOT ref_patrimoine_existe(v_de) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_inexistant');
  END IF;

  v_duree := COALESCE(NULLIF(p_duree_ms, 0), c_duree_defaut);
  IF v_duree < c_duree_min THEN v_duree := c_duree_min; END IF;
  IF v_duree > c_duree_max THEN v_duree := c_duree_max; END IF;

  v_data := COALESCE(p_data, '{}'::jsonb);
  IF jsonb_typeof(v_data) <> 'object' THEN v_data := '{}'::jsonb; END IF;
  -- Les champs de premiere classe sont retires des termes libres : sans cela, un client pourrait
  -- glisser un 'statut' dans data et tromper une lecture negligente cote interface.
  v_data := v_data - 'id' - 'type' - 'emetteur' - 'destinataire' - 'montant'
                   - 'statut' - 'expire_a' - 'created_at' - 'resolu_a';
  IF length(v_data::text) > 4000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'termes_trop_volumineux');
  END IF;

  -- ---- QUALITE DE L'EMETTEUR SUR L'ACTIF
  -- Deux des quatre types portent sur un actif que le serveur connait : la qualite y est verifiee.
  -- Les deux autres portent sur un objet d'inventaire ou sur un service, que le serveur ne voit
  -- pas -- inventer un controle pour eux donnerait l'illusion d'une garantie. On s'en abstient et
  -- on le dit.
  IF v_type = 'vente_fonds' THEN
    IF v_actif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_requis'); END IF;
    SELECT data INTO v_fonds FROM entreprises WHERE id = v_actif;
    IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
    IF (v_fonds ->> 'proprietaire') IS DISTINCT FROM v_em THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
    END IF;

  ELSIF v_type = 'resiliation_amiable' THEN
    IF v_actif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'bail_requis'); END IF;
    SELECT data INTO v_bail FROM locations_actives WHERE id = v_actif;
    IF v_bail IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'bail_absent'); END IF;

    v_locataire := COALESCE(v_bail ->> 'locataireRef',
                            'pj:' || COALESCE(v_bail ->> 'locataire', ''));
    -- Bailleur = proprietaire ACTUEL des murs, lu sur le terrain porteur (jamais une valeur figee
    -- au bail) -- meme lecture que terminer_bail.
    SELECT (data::jsonb ->> 'proprietaire') INTO v_bailleur FROM terrains_etat
     WHERE id = (v_bail ->> 'country') || '_' || (v_bail ->> 'buildingId');

    -- Un accord amiable se conclut ENTRE LES DEUX PARTIES DU BAIL, dans un sens ou dans l'autre.
    -- Exiger la paire complete ferme d'un coup l'emetteur usurpe ET le destinataire arbitraire.
    IF NOT ((v_em = v_locataire AND v_de = v_bailleur)
         OR (v_em = v_bailleur  AND v_de = v_locataire)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_partie_au_bail');
    END IF;
  END IF;

  -- ---- BORNES DE VOLUME
  SELECT count(*) INTO v_ouvertes FROM offres
   WHERE emetteur = v_em AND statut = 'ouverte' AND expire_a > now();
  IF v_ouvertes >= c_offres_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quota_offres_ouvertes', 'plafond', c_offres_max);
  END IF;

  -- Doublon strict : meme proposition, meme prix, toujours ouverte. Rendre l'existante evite
  -- qu'un double-clic n'encombre la boite du destinataire.
  SELECT id INTO v_deja FROM offres
   WHERE emetteur = v_em AND destinataire = v_de AND type = v_type
     AND COALESCE(actif, '') = COALESCE(v_actif, '') AND montant = v_montant
     AND statut = 'ouverte' AND expire_a > now()
   LIMIT 1;
  IF v_deja IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'id', v_deja, 'doublon', true);
  END IF;

  -- ---- CREATION. id, statut, dates : serveur, et lui seul.
  v_id := 'offre-' || extract(epoch from clock_timestamp())::bigint || '-'
          || substr(md5(random()::text || v_em || v_de), 1, 8);

  INSERT INTO offres (id, type, emetteur, destinataire, actif, montant, statut, data, expire_a)
  VALUES (v_id, v_type, v_em, v_de, v_actif, v_montant, 'ouverte', v_data,
          now() + make_interval(secs => v_duree / 1000.0));

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'doublon', false,
                            'statut', 'ouverte', 'montant', v_montant,
                            'expireDansMs', v_duree);
END;
$$;

-- ---------------------------------------------------------------------
-- 8. ACHAT D'UN PRODUIT — COMMERCE -> INVENTAIRE
-- ---------------------------------------------------------------------
-- ACHETER N'EST PAS UTILISER. Cette fonction ne fait que deplacer : elle ne declenche AUCUN effet.
-- C'est le principe le plus structurant du lot -- l'objet entre dans l'inventaire, et le joueur
-- decidera ensuite de le conserver, l'offrir, le revendre, l'installer, le combiner ou l'utiliser.
--
-- POURQUOI UNE RPC : quatre mouvements indissociables -- debit de l'acheteur, credit de la caisse
-- du fonds, decrement du stock, remise de l'objet. En ecritures REST separees, une panne
-- intermediaire cree ou detruit de la valeur.
--
-- NI LE PRIX NI LA QUANTITE NE SONT CRUS : le prix est relu dans la reference du catalogue sous
-- verrou, la quantite recalculee comme le minimum entre ce qui est demande, ce qui reste en stock
-- et ce que l'acheteur peut payer.
--
-- REMISE PAR objets_recus, et non par une ecriture directe dans personnages.inventory : un client
-- ouvert reecrit l'inventaire entier a sa prochaine sauvegarde et ecraserait l'ajout. Meme canal
-- que les attestations d'urbanisme et les reliquats de chantier.
CREATE OR REPLACE FUNCTION acheter_produit_commerce(
  p_acheteur     text,
  p_fonds_id     text,
  p_reference_id text,
  p_quantite     integer,
  p_objet        jsonb        -- habillage de l'objet remis (nom, icone, regime, effets...) ;
                              -- la quantite et le prix y sont IGNORES et recalcules ici
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fonds    jsonb;
  v_ref      jsonb;
  v_prix     integer;
  v_stock    integer;
  v_veut     integer := GREATEST(0, COALESCE(p_quantite, 0));
  v_qte      integer;
  v_montant  integer;
  v_arg      numeric;
  v_objet    jsonb;
  v_id_recu  text;
BEGIN
  IF COALESCE(p_acheteur, '') = '' OR COALESCE(p_fonds_id, '') = ''
     OR COALESCE(p_reference_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_veut <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  -- Verrou du patrimoine puis du fonds : meme ordre que toutes les RPC patrimoniales du projet.
  IF NOT mouvement_titulaire(p_acheteur, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent');
  END IF;

  SELECT data INTO v_fonds FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF COALESCE(v_fonds ->> 'statut', 'actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;

  v_ref := v_fonds -> 'references' -> p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;
  IF COALESCE((v_ref ->> 'active')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_inactive');
  END IF;

  v_prix  := GREATEST(0, COALESCE((v_ref ->> 'prixVente')::numeric, 0))::integer;
  v_stock := GREATEST(0, COALESCE((v_ref ->> 'stock')::numeric, 0))::integer;
  IF v_prix <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_fixe'); END IF;
  IF v_stock <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rupture_de_stock'); END IF;

  -- Solde reel de l'acheteur, relu sous verrou (mouvement_titulaire l'a deja pose).
  IF left(p_acheteur, 5) = 'orga:' THEN
    SELECT GREATEST(0, COALESCE((data::jsonb ->> 'caisse')::numeric, 0)) INTO v_arg
      FROM organisations WHERE id = substr(p_acheteur, 6);
  ELSE
    SELECT COALESCE(arg, 0) INTO v_arg FROM personnages
      WHERE name = CASE WHEN left(p_acheteur, 3) = 'pj:' THEN substr(p_acheteur, 4) ELSE p_acheteur END;
  END IF;
  IF v_arg IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent'); END IF;

  v_qte := LEAST(v_veut, v_stock, floor(v_arg / v_prix)::integer);
  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'prixUnitaire', v_prix);
  END IF;
  v_montant := v_qte * v_prix;

  -- ---- A partir d'ici, tout est applique ou rien ne l'est.
  IF NOT mouvement_titulaire(p_acheteur, -v_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  v_ref   := jsonb_set(v_ref, '{stock}', to_jsonb(v_stock - v_qte));
  v_fonds := jsonb_set(v_fonds, ARRAY['references', p_reference_id], v_ref);
  v_fonds := jsonb_set(v_fonds, '{caisse}',
               to_jsonb(GREATEST(0, COALESCE((v_fonds ->> 'caisse')::numeric, 0)) + v_montant));
  UPDATE entreprises SET data = v_fonds, updated_at = now() WHERE id = p_fonds_id;

  -- L'objet remis. Sa quantite est celle REELLEMENT achetee, jamais celle annoncee par le client.
  -- Un objet individuel est remis a l'unite, autant de fois que necessaire ; un empilable en une
  -- seule ligne. La provenance porte le commerce d'origine : c'est le debut de son histoire.
  v_objet := COALESCE(p_objet, '{}'::jsonb)
             - 'qty' - 'exemplaire'
             || jsonb_build_object(
                  'provenance', jsonb_build_object(
                    'fondsId', p_fonds_id,
                    'createur', v_fonds ->> 'proprietaire',
                    'etapes', '[]'::jsonb));

  IF COALESCE(v_objet ->> 'regime', 'empilable') = 'individuel' THEN
    FOR i IN 1 .. v_qte LOOP
      v_id_recu := 'achat-' || p_fonds_id || '-' || p_reference_id || '-'
                   || extract(epoch from clock_timestamp())::bigint || '-' || i;
      INSERT INTO objets_recus (id, destinataire, expediteur, data)
      SELECT v_id_recu,
             CASE WHEN left(p_acheteur, 3) = 'pj:' THEN substr(p_acheteur, 4) ELSE p_acheteur END,
             COALESCE(v_fonds ->> 'enseigne', 'Commerce'),
             (v_objet || jsonb_build_object(
                'qty', 1,
                'exemplaire', jsonb_build_object(
                  'id', 'ex-' || extract(epoch from clock_timestamp())::bigint || '-' || i)))::text
      WHERE NOT EXISTS (SELECT 1 FROM objets_recus WHERE id = v_id_recu);
    END LOOP;
  ELSE
    v_id_recu := 'achat-' || p_fonds_id || '-' || p_reference_id || '-'
                 || extract(epoch from clock_timestamp())::bigint;
    INSERT INTO objets_recus (id, destinataire, expediteur, data)
    SELECT v_id_recu,
           CASE WHEN left(p_acheteur, 3) = 'pj:' THEN substr(p_acheteur, 4) ELSE p_acheteur END,
           COALESCE(v_fonds ->> 'enseigne', 'Commerce'),
           (v_objet || jsonb_build_object('qty', v_qte))::text
    WHERE NOT EXISTS (SELECT 1 FROM objets_recus WHERE id = v_id_recu);
  END IF;

  RETURN jsonb_build_object('ok', true, 'quantite', v_qte, 'prixUnitaire', v_prix,
                            'montant', v_montant, 'stockRestant', v_stock - v_qte);
END;
$$;

-- ---------------------------------------------------------------------
-- 9. EMPLOI — UN FONDS EMBAUCHE UN PJ
-- ---------------------------------------------------------------------
-- Seul le proprietaire embauche et licencie. Aucun mouvement d'argent ici : l'embauche cree un
-- CONTRAT, elle ne verse rien. La remuneration sortira de la caisse au moment ou le travail sera
-- reellement effectue.
--
-- Le salarie vit dans le document du fonds : il n'a de sens que rattache a son employeur.
CREATE OR REPLACE FUNCTION employer_fonds(
  p_employeur text,
  p_fonds_id  text,
  p_salarie   text,
  p_role      text,
  p_taux      integer,
  p_actif     boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fonds    jsonb;
  v_salaries jsonb;
  v_trouve   boolean := false;
  v_i        integer;
  v_taux     integer := GREATEST(0, COALESCE(p_taux, 0));
BEGIN
  IF COALESCE(p_employeur, '') = '' OR COALESCE(p_fonds_id, '') = ''
     OR COALESCE(p_salarie, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_employeur = p_salarie THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auto_embauche');
  END IF;

  SELECT data INTO v_fonds FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF (v_fonds ->> 'proprietaire') IS DISTINCT FROM p_employeur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;

  -- Le salarie doit exister reellement : on n'embauche pas un nom.
  IF left(p_salarie, 3) = 'pj:' THEN
    IF NOT EXISTS (SELECT 1 FROM personnages WHERE name = substr(p_salarie, 4)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'salarie_absent');
    END IF;
  END IF;

  v_salaries := COALESCE(v_fonds -> 'salaries', '[]'::jsonb);
  FOR v_i IN 0 .. jsonb_array_length(v_salaries) - 1 LOOP
    IF (v_salaries -> v_i ->> 'ref') = p_salarie THEN
      v_salaries := jsonb_set(v_salaries, ARRAY[v_i::text],
        (v_salaries -> v_i) || jsonb_build_object('role', COALESCE(NULLIF(btrim(COALESCE(p_role,'')),''), 'Employé'),
                                                  'tauxHoraire', v_taux,
                                                  'actif', COALESCE(p_actif, true)));
      v_trouve := true;
    END IF;
  END LOOP;

  IF NOT v_trouve THEN
    IF COALESCE(p_actif, true) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'salarie_inconnu');
    END IF;
    v_salaries := v_salaries || jsonb_build_array(jsonb_build_object(
      'ref', p_salarie, 'role', COALESCE(NULLIF(btrim(COALESCE(p_role,'')),''), 'Employé'),
      'tauxHoraire', v_taux, 'actif', true,
      'depuis', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD')));
  END IF;

  UPDATE entreprises
    SET data = jsonb_set(v_fonds, '{salaries}', v_salaries), updated_at = now()
    WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'salarie', p_salarie, 'actif', COALESCE(p_actif, true),
                            'tauxHoraire', v_taux, 'nouveau', NOT v_trouve);
END;
$$;

-- ---------------------------------------------------------------------
-- 10. REPONSE A UNE OFFRE
-- ---------------------------------------------------------------------
-- L'ACCEPTATION EST AUTORITAIRE COTE SERVEUR. C'est elle, et elle seule, qui prouve le
-- consentement du destinataire -- exactement la preuve qui manquait pour ouvrir au navigateur la
-- vente de fonds et l'accord amiable.
--
-- Cette fonction pose le statut sous verrou et rend le verdict. ELLE N'EXECUTE AUCUN TRANSFERT
-- D'ACTIF : l'enchainement d'une acceptation vers la RPC deja specialisee -- vendre_fonds_commerce
-- pour une vente de fonds, terminer_bail pour un accord amiable, un transfert pour une vente
-- d'objet -- RESTE A BRANCHER, et devra l'etre de facon atomique. On ne recree surtout pas ici une
-- seconde implementation de la vente ou de la resiliation.
--
-- En l'etat, une offre acceptee est donc un ACCORD CONSTATE, pas une operation realisee. C'est
-- volontaire : la preuve de consentement est ce qui manquait, et elle a une valeur propre.
CREATE OR REPLACE FUNCTION repondre_offre(
  p_offre_id  text,
  p_acteur    text,
  p_acceptee  boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_offre offres%ROWTYPE;
BEGIN
  IF COALESCE(p_offre_id, '') = '' OR COALESCE(p_acteur, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_offre FROM offres WHERE id = p_offre_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'offre_absente'); END IF;

  IF v_offre.statut <> 'ouverte' THEN
    -- Idempotence : repondre deux fois n'est pas une erreur, il n'y a simplement plus rien a faire.
    RETURN jsonb_build_object('ok', true, 'deja_resolue', true, 'statut', v_offre.statut);
  END IF;
  IF v_offre.expire_a <= now() THEN
    UPDATE offres SET statut = 'expiree', resolu_a = now() WHERE id = p_offre_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'offre_expiree');
  END IF;

  -- Le destinataire accepte ou refuse ; l'emetteur ne peut qu'annuler la sienne.
  IF p_acteur = v_offre.destinataire THEN
    UPDATE offres SET statut = CASE WHEN COALESCE(p_acceptee, false) THEN 'acceptee' ELSE 'refusee' END,
                      resolu_a = now()
      WHERE id = p_offre_id;
    RETURN jsonb_build_object('ok', true, 'deja_resolue', false,
                              'statut', CASE WHEN COALESCE(p_acceptee, false) THEN 'acceptee' ELSE 'refusee' END,
                              'type', v_offre.type, 'actif', v_offre.actif,
                              'emetteur', v_offre.emetteur, 'destinataire', v_offre.destinataire,
                              'montant', v_offre.montant);
  ELSIF p_acteur = v_offre.emetteur AND COALESCE(p_acceptee, false) IS NOT TRUE THEN
    UPDATE offres SET statut = 'annulee', resolu_a = now() WHERE id = p_offre_id;
    RETURN jsonb_build_object('ok', true, 'deja_resolue', false, 'statut', 'annulee');
  END IF;

  RETURN jsonb_build_object('ok', false, 'raison', 'pas_partie_a_l_offre');
END;
$$;

-- ---------------------------------------------------------------------
-- 11. DROITS
-- ---------------------------------------------------------------------
-- Meme critere que le Lot 3.0 : une fonction n'est ouverte au navigateur que si aucun parametre
-- ne peut la transformer en atteinte a un tiers.
--
-- OUVERTES : les cinq ci-dessous verifient elles-memes la qualite du demandeur -- proprietaire du
-- fonds pour l'emploi, detenteur de l'actif pour la creation d'offre, partie a l'offre pour la
-- reponse -- et recalculent sous verrou tout montant et toute quantite. Un achat ne peut enrichir
-- personne : il debite celui qui achete.
--
-- FERMEE : ref_patrimoine_existe, rouage interne, au meme titre que mouvement_titulaire.
--
-- Rappel du piege corrige au Lot 3.0 : REVOKE ... FROM PUBLIC ne retire PAS les droits accordes
-- nominativement a anon et authenticated. Chaque revocation les nomme donc explicitement.
REVOKE EXECUTE ON FUNCTION ref_patrimoine_existe(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION ref_patrimoine_existe(text) TO service_role;

REVOKE EXECUTE ON FUNCTION creer_oeuvre(text, text, text, text, integer, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION creer_oeuvre(text, text, text, text, integer, text, jsonb) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION creer_offre(text, text, text, text, integer, bigint, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION creer_offre(text, text, text, text, integer, bigint, jsonb) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION acheter_produit_commerce(text, text, text, integer, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION acheter_produit_commerce(text, text, text, integer, jsonb) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION employer_fonds(text, text, text, text, integer, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION employer_fonds(text, text, text, text, integer, boolean) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION repondre_offre(text, text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION repondre_offre(text, text, boolean) TO anon, authenticated, service_role;

-- CONTROLE POSTERIEUR DES DROITS, role par role -- lister les fonctions ne dit rien de qui peut
-- les appeler.
-- ATTENDU : ref_patrimoine_existe        -> f / f / t
--           les cinq autres              -> t / t / t
SELECT p.proname AS fonction,
       has_function_privilege('anon',          p.oid, 'EXECUTE') AS anon,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated,
       has_function_privilege('service_role',  p.oid, 'EXECUTE') AS service_role
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('ref_patrimoine_existe','creer_oeuvre','creer_offre',
                    'acheter_produit_commerce','employer_fonds','repondre_offre')
ORDER BY p.proname;

-- CONTROLE POSTERIEUR DE L'ECRITURE DIRECTE -- c'est LE controle du correctif. Une policy
-- inexistante ne prouve rien si le GRANT de table subsiste : les deux doivent tomber.
-- ATTENDU pour oeuvres ET offres : lecture t, et INSERT / UPDATE / DELETE a f pour les DEUX roles.
SELECT c.relname AS "table",
       has_table_privilege('anon',          c.oid, 'SELECT') AS anon_select,
       has_table_privilege('anon',          c.oid, 'INSERT') AS anon_insert,
       has_table_privilege('anon',          c.oid, 'UPDATE') AS anon_update,
       has_table_privilege('anon',          c.oid, 'DELETE') AS anon_delete,
       has_table_privilege('authenticated', c.oid, 'INSERT') AS auth_insert,
       has_table_privilege('authenticated', c.oid, 'UPDATE') AS auth_update,
       has_table_privilege('authenticated', c.oid, 'DELETE') AS auth_delete
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname IN ('oeuvres','offres')
ORDER BY c.relname;

-- CONTROLE POSTERIEUR DU SCHEMA — attendu : 2 colonnes, 2 tables, et 2 policies SEULEMENT,
-- toutes deux en SELECT (oeuvres_select, offres_select). Toute ligne 'policy' supplementaire,
-- et en particulier une policy INSERT survivante d'une application anterieure, est une anomalie.
SELECT 'colonne' AS objet, column_name AS nom, '' AS commande FROM information_schema.columns
 WHERE table_name = 'personnages' AND column_name IN ('qualifications','effets_actifs')
UNION ALL
SELECT 'table', tablename, '' FROM pg_tables WHERE tablename IN ('oeuvres','offres')
UNION ALL
SELECT 'policy', policyname, cmd FROM pg_policies WHERE tablename IN ('oeuvres','offres')
ORDER BY objet, nom;
