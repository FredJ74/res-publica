-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261010234412 (UTC), nom `garde_republicaine`.
-- Le registre passe de 638 a 639 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 297e08ced68c1383f8a960195a8f997d, 40136 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA GARDE REPUBLICAINE EXISTE DESORMAIS VRAIMENT
--
-- Trois batiments affichaient un « Garde Republicain (PNJ) » dans room.persons -- Palais
-- presidentiel, Palais du Gouvernement, Assemblee -- et ces gardes n'existaient NULLE PART
-- ailleurs : aucune ligne en base, aucune arme, aucune caracteristique, aucun effet. On pouvait
-- voler dans une piece gardee sans que le garde existe pour s'y opposer.
--
-- CETTE MIGRATION POSE une SEPTIEME famille PNJ (classe beta, caracteristiques d'elite, arme de
-- service volable), une INSTITUTION dont l'autorite est le ministre de la Defense, les TROIS
-- POSTES declares dans une table -- et non codes, c'est ce qui rend la Garde generique --, un
-- garde PERMANENT et gratuit par poste qui revient quatre heures apres etre tombe, et le RENFORT
-- NATIONAL : x2 a x5 pendant 24 h, 50 FR par garde supplementaire preleves sur la caisse de la
-- Defense en une seule transaction.
--
-- L'EFFET DE GROUPE N'A PAS ETE INVENTE. L'audit du Palais avait d'abord conclu que la « logique
-- de groupe existante » n'existait pas hors du moteur de bataille abandonne. C'ETAIT FAUX, et la
-- relecture l'a montre : `Math.min(40, 10 + nombre)` est deja le malus applique au jet de TOUT
-- ordre quand un detachement militaire en mission `securiser` occupe la piece -- pose dans
-- plateau-politique.js, applique dans plateau-router.js. La Garde etant un groupe d'hommes armes
-- dont la mission EST de securiser, la meme formule s'applique au nombre d'hommes reellement
-- presents. Le client additionne donc les HOMMES et applique la formule UNE FOIS : ni empilement
-- de deux malus, ni regle du plus grand des deux, qui auraient tous deux ete des regles neuves.
--
-- DEUX ECUEILS RENCONTRES A L'APPLICATION, tous deux revelateurs :
--   . `pnj_possessions.origine` est une liste fermee a 'socle' et 'blob_accessoires'. Elle nomme
--     L'AXE D'AUTORITE de la possession, pas sa provenance narrative : y ecrire
--     'garde_republicaine' confondait « d'ou vient cet objet » et « qui fait autorite sur lui ».
--   . le poste DECIME est regarni de ses renforts seulement -- deux hommes, pas trois -- parce
--     que le permanent purge ses quatre heures. La regle du permanent et l'exception du poste
--     decime sont deux regles distinctes qui se composent sans s'annuler.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LA GARDE REPUBLICAINE -- UNE FAMILLE PNJ QUI EXISTE VRAIMENT (11 octobre 2026)
-- =================================================================================================
-- CE QUE L'AUDIT AVAIT TROUVE. Trois batiments affichaient un « Garde Republicain (PNJ) » dans
-- room.persons : le Palais presidentiel, le Palais du Gouvernement et l'Assemblee. Ces gardes
-- n'existaient NULLE PART ailleurs -- aucune ligne en base, aucune arme, aucune caracteristique,
-- aucun effet sur quoi que ce soit. On pouvait voler dans une piece gardee sans que le garde
-- existe pour s'y opposer : c'etait du decor peint.
--
-- CE QUE CETTE MIGRATION POSE, et rien de plus :
--   1. une SEPTIEME FAMILLE PNJ, `garde_republicain`, classe beta, avec ses caracteristiques
--      d'elite et son arme de service -- donc volable, et donc reellement neutralisable ;
--   2. une INSTITUTION proprietaire, `garde_republicaine`, dont l'autorite est le ministre de la
--      Defense du pays -- exactement le resolveur du renseignement, recopie sans invention ;
--   3. les TROIS POSTES DE GARDE, declares dans une table et non dans du code : la Garde est
--      generique, et le game design propre de chacun des trois batiments n'est pas touche ;
--   4. UN GARDE PERMANENT ET GRATUIT par poste, qui REVIENT quatre heures apres avoir ete mis
--      hors de combat -- le poste n'est jamais definitivement vide ;
--   5. LE RENFORT NATIONAL : le ministre de la Defense multiplie la Garde par 2 a 5 pendant
--      24 heures, a 50 FR par garde supplementaire, preleves sur la caisse de la Defense en une
--      seule transaction -- tout ou rien ;
--   6. LES PERTES NE SONT PAS REMPLACEES. Un renfort tombe ne revient pas. Seule exception : un
--      poste entierement decime est regarni, et ses gardes neufs expirent a L'HEURE INITIALE du
--      renfort national, jamais 24 h apres leur arrivee -- sinon un attaquant prolongerait la
--      Garde en la tuant.
--
-- L'EFFET DE GROUPE N'EST PAS INVENTE ICI, ET C'EST IMPORTANT. Le jeu possede deja la regle :
-- `Math.min(40, 10 + nombre)` est le malus applique au jet de TOUT ordre quand un detachement
-- militaire en mission `securiser` occupe la piece (plateau-politique.js, applique dans
-- plateau-router.js). La Garde republicaine est un groupe d'hommes armes dont la mission EST de
-- securiser : la meme formule s'applique au nombre d'hommes reellement presents. Aucun parametre
-- neuf, aucun plafond neuf.
--
-- CE QUE CETTE MIGRATION NE FAIT PAS. Elle ne cree aucun moteur de combat -- le combat de groupe
-- appartient au moteur deliberement abandonne. Mettre un garde hors de combat passe par
-- `pnj_mourir`, qui existe depuis le socle : ses possessions tombent au sol en objets abandonnes,
-- et son proprietaire institutionnel en est averti. C'est ce qui rend le vol de l'arme de service
-- possible, et la neutralisation reelle.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 1. LA SEPTIEME FAMILLE
-- -------------------------------------------------------------------------------------------------
-- Le CHECK est remplace et non etendu par un second CHECK : deux contraintes sur la meme colonne
-- se liraient comme deux regles concurrentes, et la liste des familles doit se lire d'un coup.
ALTER TABLE public.pnj_membres DROP CONSTRAINT pnj_famille_connue;
ALTER TABLE public.pnj_membres ADD CONSTRAINT pnj_famille_connue CHECK (
  famille = ANY (ARRAY['soldat'::text, 'employe'::text, 'agent'::text, 'policier'::text,
                       'douanier'::text, 'militant'::text, 'garde_republicain'::text]));

INSERT INTO public.pnj_familles_classes (famille, classe, note) VALUES
  ('garde_republicain', 'beta',
   'Garde republicaine. Famille 100 % SERVEUR, nee au socle le 11 octobre 2026 : elle n a aucun magasin historique, donc aucun axe a basculer -- les cinq axes sont au socle des sa naissance. 12 PA presents et jamais debites (classe beta). Propriete institutionnelle `garde_republicaine`, perimetre = le PAYS, autorite = le ministre de la Defense. Un garde permanent et gratuit par poste, qui revient 4 h apres avoir ete mis hors de combat ; les renforts nationaux sont decides par le ministre, durent 24 h, et ne sont PAS remplaces quand ils tombent.')
ON CONFLICT (famille) DO UPDATE SET classe = EXCLUDED.classe, note = EXCLUDED.note;

-- LES CINQ AXES AU SOCLE, et la raison est la meme pour les cinq : il n'y a pas de concurrent.
-- C'est la difference avec le policier et le douanier, dont la position derive d'un miroir
-- institutionnel -- ici, `pnj_membres` EST le magasin, et le garde ne suit aucun leader.
INSERT INTO public.pnj_axes_autorite (famille, axe, autorite, note) VALUES
  ('garde_republicain', 'pa', 'socle', 'Sans objet en pratique : la classe beta interdit tout debit de PA.'),
  ('garde_republicain', 'argent', 'socle', 'Aucun magasin concurrent : la famille nait au socle.'),
  ('garde_republicain', 'possessions', 'socle', 'L arme de service vit dans pnj_possessions, et c est ce qui la rend volable a la mort du garde.'),
  ('garde_republicain', 'propriete', 'socle', 'Institution `garde_republicaine`, perimetre = pays, autorite = ministre de la Defense.'),
  ('garde_republicain', 'position_leader', 'socle',
   'AU SOCLE, et non a l institution comme pour le policier et le douanier : un garde n a pas d effectif metier dont on derive sa place. Sa piece est ecrite dans pnj_membres par la synchronisation, il ne suit aucun leader, et personne ne le deplace.')
ON CONFLICT (famille, axe) DO UPDATE SET autorite = EXCLUDED.autorite, note = EXCLUDED.note;

-- LES CARACTERISTIQUES D'ELITE. Aucune valeur n'est inventee : chacune existe deja dans le jeu.
-- VOL 16 est le maximum en service (agent de securite Grobras), PER 16 le maximum en service
-- (maitre-chien), ENT 12 le maximum des familles institutionnelles (soldat). INT 10, CHA 8 et
-- DUP 8 sont recopies du profil policier -- un garde n'est ni un espion ni un seducteur. C'est
-- exactement la methode suivie le 5 octobre pour `agent_securite` et `maitre_chien`.
INSERT INTO public.pnj_metiers_profils
  (metier, car_int, car_cha, car_vol, car_per, car_dup, car_ent, note,
   pa_initial, cout_initial, cout_jour, quota_note, classe, role_libelle, recrutable,
   quota_par_joueur, ordre_fn)
VALUES
  ('garde_republicain', 10, 8, 16, 16, 8, 12,
   'Metier de la famille garde_republicain, classe beta. VOL 16 et PER 16 sont les maximums deja en service dans le jeu (agent de securite Grobras, maitre-chien) : la Garde est une unite d elite, et elle est chiffree comme telle sans qu aucune valeur neuve soit creee. INT 10 / CHA 8 / DUP 8 recopies du profil policier.',
   0, 0, NULL,
   'Un garde PERMANENT et GRATUIT par poste de garde : aucune dotation initiale, aucun salaire recurrent. Les RENFORTS coutent 50 FR chacun, une seule fois, preleves sur la caisse de la Defense par le ministre ; ils ne sont jamais payes par un joueur sur sa bourse personnelle.',
   'beta', 'Garde republicain', false, NULL, NULL)
ON CONFLICT (metier) DO UPDATE SET
  car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
  car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
  note = EXCLUDED.note, pa_initial = EXCLUDED.pa_initial, cout_initial = EXCLUDED.cout_initial,
  cout_jour = EXCLUDED.cout_jour, quota_note = EXCLUDED.quota_note, classe = EXCLUDED.classe,
  role_libelle = EXCLUDED.role_libelle, recrutable = EXCLUDED.recrutable;

-- -------------------------------------------------------------------------------------------------
-- 2. L'INSTITUTION ET SON AUTORITE
-- -------------------------------------------------------------------------------------------------
-- RECOPIE EXACTE DU RESOLVEUR DU RENSEIGNEMENT. Le perimetre est le PAYS, l'autorite est le PJ
-- portant min_def dans ce pays, et « personne » reste un etat valide : un poste tenu par un
-- titulaire PNJ ne fait pas de ce PNJ une autorite. La Garde appartient a l'Etat, pas au ministre
-- du moment -- un ministre passe, la Garde reste.
CREATE OR REPLACE FUNCTION public.garde_republicaine_autorite_de_perimetre(p_pays text, p_perimetre text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT pa.titulaire FROM public.postes_attribues pa
   WHERE pa.poste_id = 'min_def' AND pa.country = COALESCE(p_perimetre, p_pays)
     AND pa.titulaire IS NOT NULL
   LIMIT 1;
$function$;

REVOKE ALL ON FUNCTION public.garde_republicaine_autorite_de_perimetre(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_autorite_de_perimetre(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_autorite_de_perimetre(text, text) TO service_role;

INSERT INTO public.pnj_institutions (institution, resolveur, note) VALUES
  ('garde_republicaine', 'garde_republicaine_autorite_de_perimetre',
   'Perimetre = le PAYS. Autorite : le PJ portant le poste min_def de ce pays -- meme resolveur que le renseignement. La Garde appartient a l Etat et non au ministre du moment : il decide des renforts, il ne possede pas les hommes.')
ON CONFLICT (institution) DO UPDATE SET resolveur = EXCLUDED.resolveur, note = EXCLUDED.note;

-- -------------------------------------------------------------------------------------------------
-- 3. LES POSTES DE GARDE, DECLARES ET NON CODES
-- -------------------------------------------------------------------------------------------------
-- POURQUOI UNE TABLE. L'arbitrage demande une Garde GENERIQUE sur trois batiments, sans toucher au
-- game design de chacun. Si les trois pieces etaient ecrites dans le corps des fonctions, ajouter
-- un quatrieme poste -- ou en ouvrir un en Narcovie -- serait une modification de code. Ici c'est
-- une ligne.
CREATE TABLE IF NOT EXISTS public.garde_republicaine_postes (
  pays            text        NOT NULL,
  building_id     text        NOT NULL,
  ville           text        NOT NULL,
  room_id         text        NOT NULL,
  libelle         text        NOT NULL,
  vacant_depuis   timestamptz,
  PRIMARY KEY (pays, building_id)
);

COMMENT ON COLUMN public.garde_republicaine_postes.vacant_depuis IS
  'Instant ou le garde PERMANENT de ce poste est tombe. Il revient quatre heures plus tard, et cette colonne redevient NULL. NULL signifie « le permanent est la, ou il peut arriver tout de suite ».';

-- LES TROIS POSTES DE REPUBLIA, aux pieces exactes ou le decor les montrait deja : on ne deplace
-- aucun garde, on leur donne une existence la ou les joueurs les voient depuis toujours.
INSERT INTO public.garde_republicaine_postes (pays, building_id, ville, room_id, libelle) VALUES
  ('republic', 'palais-presidentiel', 'capitale', 'accueil_elysee',    'Hall d honneur du Palais de l Elysee'),
  ('republic', 'palais-gouvernement', 'capitale', 'hall',              'Hall d entree du Palais du Gouvernement'),
  ('republic', 'assemblee',           'capitale', 'accueil_assemblee', 'Accueil de l Assemblee nationale')
ON CONFLICT (pays, building_id) DO UPDATE
   SET ville = EXCLUDED.ville, room_id = EXCLUDED.room_id, libelle = EXCLUDED.libelle;

-- -------------------------------------------------------------------------------------------------
-- 4. L'ETAT DU RENFORT NATIONAL, ET L'HORLOGE QUI FAIT FOI
-- -------------------------------------------------------------------------------------------------
-- UNE SEULE LIGNE PAR PAYS, ET UNE SEULE HORLOGE. C'est la cle de l'arbitrage sur le poste decime :
-- l'expiration n'est PAS portee par chaque garde mais par le pays. Un garde neuf, arrive pour
-- regarnir un poste vide, trouve donc l'echeance deja posee et expire avec les autres.
CREATE TABLE IF NOT EXISTS public.garde_republicaine_renfort (
  pays        text        PRIMARY KEY,
  facteur     integer     NOT NULL,
  expire_le   timestamptz NOT NULL,
  decide_par  text        NOT NULL,
  decide_le   timestamptz NOT NULL DEFAULT now(),
  cout_paye   numeric     NOT NULL DEFAULT 0,
  CONSTRAINT garde_facteur_borne CHECK (facteur >= 2 AND facteur <= 5)
);

COMMENT ON TABLE public.garde_republicaine_renfort IS
  'Renfort national de la Garde republicaine : un facteur de 2 a 5 et UNE SEULE echeance par pays. L echeance appartient au pays et non aux gardes : c est ce qui empeche de prolonger la Garde en la tuant (arbitrage du 11 octobre 2026).';

-- LE REGISTRE DES EFFECTIFS. Il dit, pour chaque garde, s'il est le PERMANENT de son poste ou un
-- renfort -- une donnee de metier, qui n'a pas sa place dans le socle.
CREATE TABLE IF NOT EXISTS public.garde_republicaine_effectifs (
  pnj_id      text PRIMARY KEY REFERENCES public.pnj_membres(id) ON DELETE CASCADE,
  pays        text NOT NULL,
  building_id text NOT NULL,
  permanent   boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS garde_effectifs_par_poste
  ON public.garde_republicaine_effectifs (pays, building_id);

-- AUCUN ACCES CLIENT DIRECT. Les trois tables se lisent par les portes de lecture ci-dessous :
-- une policy et son GRANT tombent ensemble, donc on ne pose ni l'une ni l'autre.
ALTER TABLE public.garde_republicaine_postes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.garde_republicaine_renfort   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.garde_republicaine_effectifs ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------------------------------
-- 5. LA NAISSANCE D'UN GARDE
-- -------------------------------------------------------------------------------------------------
-- UNE SEULE FONCTION CREE UN GARDE, permanent ou renfort. Elle pose la ligne de socle, le registre
-- de metier, et l'ARME DE SERVICE -- les trois ensemble, parce qu'un garde sans arme serait
-- exactement le decor qu'on est en train de supprimer.
--
-- L'ARME EST `arme_de_poing`, deja connue du jeu (militaire_armes_bonus, mode feu, bonus 8). Elle
-- est posee dans pnj_possessions, donc `militaire_arme_operationnelle` la trouve sans qu'on touche
-- a cette fonction, et `pnj_mourir` la fera tomber au sol.
CREATE OR REPLACE FUNCTION public.garde_republicaine_creer(
  p_pays text, p_building_id text, p_permanent boolean, p_rang integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE po record; v_id text; v_nom text; pr record;
BEGIN
  SELECT * INTO po FROM public.garde_republicaine_postes
   WHERE pays = p_pays AND building_id = p_building_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  SELECT * INTO pr FROM public.pnj_metiers_profils WHERE metier = 'garde_republicain';

  v_id := 'garde-' || p_pays || '-' || p_building_id
       || CASE WHEN p_permanent THEN '-permanent' ELSE '-renfort-' || p_rang::text END;
  -- UN NOM, PAS UN MATRICULE. Le permanent est « le » garde du lieu ; les renforts sont numerotes,
  -- parce qu'ils sont plusieurs et interchangeables -- ce qu'ils sont vraiment.
  v_nom := CASE WHEN p_permanent THEN 'Garde republicain'
                ELSE 'Garde republicain (renfort ' || p_rang::text || ')' END;

  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN v_id;                        -- deja en poste : la synchronisation est idempotente
  END IF;

  -- UN GARDE TOMBE PUIS REVENU REPREND SON IDENTIFIANT. Sa ligne morte est ecartee d'abord : le
  -- declencheur de garde n'interdit que la suppression d'un PNJ VIVANT.
  DELETE FROM public.pnj_membres WHERE id = v_id AND statut <> 'actif';

  INSERT INTO public.pnj_membres
    (id, famille, nom, pays, classe, proprietaire_institution, proprietaire_perimetre,
     ville, building_id, room_id, pa, liquide, statut,
     car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES
    (v_id, 'garde_republicain', v_nom, p_pays, 'beta', 'garde_republicaine', p_pays,
     po.ville, po.building_id, po.room_id, public.pnj_pa_max(), 0, 'actif',
     pr.car_int, pr.car_cha, pr.car_vol, pr.car_per, pr.car_dup, pr.car_ent);

  INSERT INTO public.garde_republicaine_effectifs (pnj_id, pays, building_id, permanent)
  VALUES (v_id, p_pays, p_building_id, p_permanent)
  ON CONFLICT (pnj_id) DO UPDATE SET permanent = EXCLUDED.permanent;

  -- `origine` NOMME L'AXE D'AUTORITE, PAS LA PROVENANCE NARRATIVE : la liste fermee n'admet que
  -- 'socle' et 'blob_accessoires'. Les possessions de la Garde sont au socle -- c'est ce que
  -- pnj_axes_autorite declare juste au-dessus --, donc 'socle'. Y ecrire 'garde_republicaine'
  -- aurait confondu « d'ou vient cet objet » avec « qui fait autorite sur lui ».
  INSERT INTO public.pnj_possessions (pnj_id, objet, exemplaire_unique, origine)
  VALUES (v_id,
          jsonb_build_object('name', 'arme_de_poing', 'type', 'arme',
                             'produitMilitaire', 'arme_de_poing',
                             'libelle', 'Arme de service de la Garde republicaine'),
          false, 'socle');

  RETURN v_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.garde_republicaine_creer(text, text, boolean, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_creer(text, text, boolean, integer) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 6. LA CHUTE D'UN GARDE : L'HORLOGE DES QUATRE HEURES PART TOUTE SEULE
-- -------------------------------------------------------------------------------------------------
-- POURQUOI UN DECLENCHEUR ET NON UN APPEL. `pnj_mourir` est la porte generique du socle : elle ne
-- connait pas la Garde, et lui apprendre la Garde serait mettre du metier dans le socle. Le
-- declencheur observe le changement de statut et horodate la vacance -- quelle que soit la cause de
-- la chute, y compris une cause future qui n'existe pas encore.
CREATE OR REPLACE FUNCTION public.garde_republicaine_vacance()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE e record;
BEGIN
  IF OLD.statut = 'actif' AND NEW.statut <> 'actif'
     AND NEW.famille = 'garde_republicain' THEN
    SELECT * INTO e FROM public.garde_republicaine_effectifs WHERE pnj_id = NEW.id;
    -- SEUL LE PERMANENT OUVRE UNE VACANCE. Un renfort tombe ne declenche rien : les pertes ne
    -- sont pas remplacees, c'est l'arbitrage.
    IF e.permanent THEN
      UPDATE public.garde_republicaine_postes
         SET vacant_depuis = now()
       WHERE pays = e.pays AND building_id = e.building_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS garde_republicaine_vacance_trg ON public.pnj_membres;
CREATE TRIGGER garde_republicaine_vacance_trg
  AFTER UPDATE OF statut ON public.pnj_membres
  FOR EACH ROW EXECUTE FUNCTION public.garde_republicaine_vacance();

-- -------------------------------------------------------------------------------------------------
-- 7. LA SYNCHRONISATION : LE SEUL ENDROIT QUI DECIDE COMBIEN DE GARDES IL Y A
-- -------------------------------------------------------------------------------------------------
-- TROIS REGLES, ET ELLES NE SE RECOUVRENT PAS :
--   (a) LE PERMANENT. Absent et vacance de 4 h ecoulee -- ou jamais ouverte -- : il reprend son
--       poste. C'est la seule reapparition automatique du systeme.
--   (b) LES RENFORTS EXPIRES partent. Ils partent en `disparu` et non par suppression : le
--       declencheur `pnj_garde_suppression` refuse de supprimer un PNJ vivant, et il a raison --
--       un renfort qui rentre a la caserne n'est pas un mort, et ses possessions ne doivent pas
--       tomber au sol.
--   (c) LE POSTE DECIME. Si un poste n'a plus AUCUN garde vivant alors que le renfort national
--       court encore, il est regarni jusqu'au facteur en cours. Les gardes neufs expirent a
--       l'echeance NATIONALE deja posee : tuer la Garde ne la prolonge pas.
-- ET CE QU'ELLE NE FAIT JAMAIS : remplacer un renfort tombe individuellement.
CREATE OR REPLACE FUNCTION public.garde_republicaine_synchroniser(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  po record; r record; v_facteur integer := 1; v_vivants integer; v_rang integer;
  v_nes integer := 0; v_partis integer := 0; v_revenus integer := 0; v_regarnis integer := 0;
BEGIN
  SELECT * INTO r FROM public.garde_republicaine_renfort WHERE pays = p_pays FOR UPDATE;
  IF FOUND AND r.expire_le > now() THEN
    v_facteur := r.facteur;
  END IF;

  -- (b) LES RENFORTS EXPIRES RENTRENT. Fait AVANT le reste : le comptage des vivants doit se faire
  -- sur l'effectif d'apres expiration, sinon un poste paraitrait garni par des gardes partis.
  IF v_facteur = 1 THEN
    FOR po IN SELECT m.id FROM public.pnj_membres m
               JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
              WHERE m.pays = p_pays AND m.statut = 'actif' AND NOT e.permanent
    LOOP
      UPDATE public.pnj_membres SET statut = 'disparu', maj_le = now() WHERE id = po.id;
      DELETE FROM public.pnj_possessions WHERE pnj_id = po.id;
      v_partis := v_partis + 1;
    END LOOP;
    DELETE FROM public.garde_republicaine_renfort WHERE pays = p_pays AND expire_le <= now();
  END IF;

  FOR po IN SELECT * FROM public.garde_republicaine_postes WHERE pays = p_pays ORDER BY building_id
  LOOP
    -- (a) LE PERMANENT REVIENT, quatre heures apres etre tombe.
    IF NOT EXISTS (SELECT 1 FROM public.pnj_membres m
                    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
                   WHERE m.statut = 'actif' AND e.permanent
                     AND e.pays = p_pays AND e.building_id = po.building_id) THEN
      IF po.vacant_depuis IS NULL OR now() - po.vacant_depuis >= interval '4 hours' THEN
        IF public.garde_republicaine_creer(p_pays, po.building_id, true, 0) IS NOT NULL THEN
          UPDATE public.garde_republicaine_postes SET vacant_depuis = NULL
           WHERE pays = p_pays AND building_id = po.building_id;
          IF po.vacant_depuis IS NULL THEN v_nes := v_nes + 1;
          ELSE v_revenus := v_revenus + 1; END IF;
        END IF;
      END IF;
    END IF;

    SELECT count(*) INTO v_vivants FROM public.pnj_membres m
      JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
     WHERE m.statut = 'actif' AND e.pays = p_pays AND e.building_id = po.building_id;

    -- (c) LE POSTE DECIME. La condition est « plus aucun garde vivant », pas « moins que le
    -- facteur » : sans cela, chaque renfort tombe serait remplace, et l'arbitrage dit l'inverse.
    IF v_facteur > 1 AND v_vivants = 0 THEN
      FOR v_rang IN 1 .. (v_facteur - 1) LOOP
        IF public.garde_republicaine_creer(p_pays, po.building_id, false, v_rang) IS NOT NULL THEN
          v_regarnis := v_regarnis + 1;
        END IF;
      END LOOP;
      v_vivants := v_facteur;
    END IF;

    -- LA MONTEE EN PUISSANCE ORDINAIRE : le poste n'est pas decime, il est juste sous-dote parce
    -- que le ministre vient de decider un renfort. On complete jusqu'au facteur.
    IF v_facteur > 1 AND v_vivants < v_facteur AND v_vivants > 0 THEN
      FOR v_rang IN 1 .. (v_facteur - 1) LOOP
        IF NOT EXISTS (SELECT 1 FROM public.pnj_membres
                        WHERE id = 'garde-' || p_pays || '-' || po.building_id || '-renfort-' || v_rang::text
                          AND statut = 'actif') THEN
          -- UN RENFORT TOMBE N'EST PAS REMPLACE : on ne recree un rang que si ce rang n'a JAMAIS
          -- ete pose sous le renfort national en cours. Sa ligne morte, elle, reste la preuve
          -- qu'il est tombe.
          IF NOT EXISTS (SELECT 1 FROM public.pnj_membres
                          WHERE id = 'garde-' || p_pays || '-' || po.building_id || '-renfort-' || v_rang::text) THEN
            IF public.garde_republicaine_creer(p_pays, po.building_id, false, v_rang) IS NOT NULL THEN
              v_nes := v_nes + 1;
            END IF;
          END IF;
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'facteur', v_facteur, 'nes', v_nes,
                            'revenus', v_revenus, 'partis', v_partis, 'regarnis', v_regarnis);
END;
$function$;

REVOKE ALL ON FUNCTION public.garde_republicaine_synchroniser(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_synchroniser(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_synchroniser(text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 8. LA PORTE DU MINISTRE : LE RENFORT NATIONAL
-- -------------------------------------------------------------------------------------------------
-- TOUT OU RIEN. La caisse est lue sous verrou, le refus arrive AVANT le moindre debit, et la
-- creation des gardes se fait dans la meme transaction que le prelevement : il est impossible
-- d'avoir paye sans gardes, ou des gardes sans avoir paye.
--
-- AUCUN COUT EN PA n'est preleve : l'arbitrage a chiffre ce renfort en FR -- 50 FR par garde
-- supplementaire -- et inventer un cout en PA serait ajouter une regle que personne n'a decidee.
CREATE OR REPLACE FUNCTION public.garde_renfort_national(p_facteur integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; a record; v_postes integer; v_sup integer; v_cout numeric;
  v_caisse text; v_data jsonb; v_solde numeric; v_sync jsonb; v_expire timestamptz;
BEGIN
  IF p_facteur IS NULL OR p_facteur < 2 OR p_facteur > 5 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'facteur_hors_bornes',
                              'minimum', 2, 'maximum', 5);
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- L'AUTORITE EST LE MINISTRE DE LA DEFENSE, lue dans le registre des postes et jamais sur la
  -- fiche : acteur_poste_courant() est la porte attestee.
  SELECT * INTO a FROM public.acteur_poste_courant() WHERE poste_id = 'min_def' LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_ministre_de_la_defense');
  END IF;

  SELECT count(*) INTO v_postes FROM public.garde_republicaine_postes WHERE pays = a.pays;
  IF v_postes = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_poste_de_garde', 'pays', a.pays);
  END IF;

  v_sup  := (p_facteur - 1) * v_postes;
  v_cout := v_sup * 50;
  v_caisse := a.pays || '_gouvernement-min_def';

  -- LE REFUS AVANT L'ECRITURE. La caisse est verrouillee ici et le reste jusqu'au bout de la
  -- transaction : personne ne peut la vider entre la verification et le debit.
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  IF v_solde < v_cout THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_defense_insuffisante',
                              'requis', v_cout, 'solde', v_solde);
  END IF;

  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_cout),
         updated_at = now()
   WHERE id = v_caisse;
  INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
  VALUES (v_moi, v_caisse, -v_cout, 'garde_republicaine_renfort', true, NULL);

  -- LES RENFORTS DE LA FOIS PRECEDENTE SONT EFFACES ICI, et nulle part ailleurs. « Les pertes ne
  -- sont pas remplacees » est implemente par la PRESENCE de la ligne morte : tant qu'elle est la,
  -- la synchronisation ne recree pas ce rang. Il faut donc l'oter quand un renfort NEUF est decide,
  -- sinon la deuxieme mobilisation naitrait deja amputee des pertes de la premiere. Ces lignes ne
  -- sont jamais actives -- `pnj_garde_suppression` protege les vivants, pas les morts.
  DELETE FROM public.pnj_membres m
   WHERE m.statut <> 'actif' AND m.famille = 'garde_republicain' AND m.pays = a.pays
     AND EXISTS (SELECT 1 FROM public.garde_republicaine_effectifs e
                  WHERE e.pnj_id = m.id AND NOT e.permanent);

  -- L'HORLOGE EST POSEE UNE FOIS. Un second renfort pendant qu'un premier court REMPLACE le
  -- facteur et REPART pour 24 h : c'est une decision neuve du ministre, qu'il paie en entier.
  v_expire := now() + interval '24 hours';
  INSERT INTO public.garde_republicaine_renfort (pays, facteur, expire_le, decide_par, cout_paye)
  VALUES (a.pays, p_facteur, v_expire, v_moi, v_cout)
  ON CONFLICT (pays) DO UPDATE
     SET facteur = EXCLUDED.facteur, expire_le = EXCLUDED.expire_le,
         decide_par = EXCLUDED.decide_par, decide_le = now(),
         cout_paye = EXCLUDED.cout_paye;

  v_sync := public.garde_republicaine_synchroniser(a.pays);

  RETURN jsonb_build_object('ok', true, 'facteur', p_facteur, 'postes', v_postes,
                            'gardes_supplementaires', v_sup, 'cout', v_cout,
                            'solde_defense', v_solde - v_cout, 'expire_le', v_expire,
                            'synchronisation', v_sync);
END;
$function$;

REVOKE ALL ON FUNCTION public.garde_renfort_national(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.garde_renfort_national(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.garde_renfort_national(integer) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 9. CE QUE LE CLIENT PEUT LIRE : L'ETAT D'UNE PIECE GARDEE
-- -------------------------------------------------------------------------------------------------
-- UNE PROJECTION, PAS UN FILTRE. Elle rend le NOMBRE de gardes et le malus qui en decoule, jamais
-- la liste nominative ni les caracteristiques : un joueur n'a pas besoin de savoir lequel des
-- gardes a 16 de volonte pour comprendre qu'il est surveille.
--
-- LE MALUS EST LA FORMULE EXISTANTE DU JEU -- min(40, 10 + nombre) --, celle du detachement
-- militaire en mission `securiser`. Elle est calculee ici pour que le navigateur n'ait pas a la
-- connaitre deux fois.
CREATE OR REPLACE FUNCTION public.garde_republicaine_piece(
  p_pays text, p_building_id text, p_room_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE po record; r record; v_n integer; v_renfort boolean := false; v_expire timestamptz;
BEGIN
  SELECT * INTO po FROM public.garde_republicaine_postes
   WHERE pays = p_pays AND building_id = p_building_id AND room_id = p_room_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'gardee', false, 'gardes', 0, 'malus', 0);
  END IF;

  SELECT count(*) INTO v_n FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.statut = 'actif' AND e.pays = p_pays AND e.building_id = p_building_id;

  SELECT * INTO r FROM public.garde_republicaine_renfort WHERE pays = p_pays;
  IF FOUND AND r.expire_le > now() THEN
    v_renfort := true; v_expire := r.expire_le;
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'gardee', true, 'gardes', v_n,
    -- UNE PIECE GARDEE PAR PERSONNE NE PESE RIEN : le malus suit les hommes presents, pas le
    -- panneau sur la porte. C'est ce qui rend la neutralisation utile.
    'malus', CASE WHEN v_n > 0 THEN least(40, 10 + v_n) ELSE 0 END,
    'renfort_actif', v_renfort, 'renfort_expire_le', v_expire,
    'libelle', po.libelle);
END;
$function$;

REVOKE ALL ON FUNCTION public.garde_republicaine_piece(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_piece(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_piece(text, text, text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 10. LE CONTROLE A L'ENTREE : LA GARDE RECONNAIT UNE PERSONNE RECHERCHEE
-- -------------------------------------------------------------------------------------------------
-- CE QU'ELLE FAIT, ET CE QU'ELLE NE FAIT PAS. Elle CONSTATE, au serveur, qu'un visiteur sous
-- jugement non execute entre dans une piece ou des gardes sont effectivement presents. Elle
-- n'arrete personne elle-meme : l'arrestation est une mecanique qui existe deja ailleurs, et la
-- dupliquer ici en creerait une seconde, concurrente. Le constat est rendu au client, qui emprunte
-- le chemin d'arrestation existant.
--
-- LA RECHERCHE EST LUE PAR LA PORTE EXISTANTE `justice_recherches`, sous l'identite de l'appelant
-- lui-meme -- qui a toujours le droit de savoir qu'il est recherche. Aucun privilege n'est ajoute,
-- et la Garde ne peut donc pas servir a espionner le casier d'autrui.
CREATE OR REPLACE FUNCTION public.garde_republicaine_controle(
  p_building_id text, p_room_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_etat jsonb; v_motifs integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  v_etat := public.garde_republicaine_piece(v_pays, p_building_id, p_room_id);
  IF coalesce((v_etat->>'gardee')::boolean, false) IS NOT TRUE
     OR coalesce((v_etat->>'gardes')::integer, 0) = 0 THEN
    -- NI POSTE DE GARDE, NI GARDE VIVANT : aucun controle. Un poste decime laisse entrer.
    RETURN jsonb_build_object('ok', true, 'intervention', false, 'gardes',
                              coalesce((v_etat->>'gardes')::integer, 0));
  END IF;

  SELECT count(*) INTO v_motifs FROM public.justice_recherches(v_moi);

  RETURN jsonb_build_object('ok', true, 'intervention', v_motifs > 0,
                            'gardes', (v_etat->>'gardes')::integer,
                            'malus', (v_etat->>'malus')::integer,
                            'libelle', v_etat->>'libelle');
END;
$function$;

REVOKE ALL ON FUNCTION public.garde_republicaine_controle(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_controle(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.garde_republicaine_controle(text, text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- LES TROIS POSTES PERMANENTS PRENNENT LEUR SERVICE
-- -------------------------------------------------------------------------------------------------
-- C'EST UNE DONNEE D'ETAT INITIAL, PAS UN EFFET DE BORD DE BANC : la Garde doit exister des que
-- cette migration est appliquee, sinon les trois halls restent du decor jusqu'au premier appel.
SELECT public.garde_republicaine_synchroniser('republic');

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer; v_c text;
BEGIN
  -- P1 : la septieme famille est admise, et les six anciennes le sont toujours.
  SELECT pg_get_constraintdef(c.oid) INTO v_c FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname = 'pnj_membres' AND c.conname = 'pnj_famille_connue';
  IF v_c IS NULL OR v_c NOT LIKE '%garde_republicain%' OR v_c NOT LIKE '%soldat%'
     OR v_c NOT LIKE '%employe%' OR v_c NOT LIKE '%agent%' OR v_c NOT LIKE '%policier%'
     OR v_c NOT LIKE '%douanier%' OR v_c NOT LIKE '%militant%' THEN
    RAISE EXCEPTION 'P1 : la liste des familles est incorrecte -- %', v_c;
  END IF;

  -- P2 : la famille, son metier et ses cinq axes sont declares.
  SELECT count(*) INTO v_n FROM public.pnj_familles_classes
   WHERE famille = 'garde_republicain' AND classe = 'beta';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2a : la famille n est pas declaree en beta'; END IF;
  SELECT count(*) INTO v_n FROM public.pnj_axes_autorite WHERE famille = 'garde_republicain';
  IF v_n <> 5 THEN RAISE EXCEPTION 'P2b : % axes declares au lieu de 5', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.pnj_metiers_profils
   WHERE metier = 'garde_republicain' AND car_vol = 16 AND car_per = 16 AND car_ent = 12
     AND NOT recrutable;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2c : le profil d elite n est pas pose'; END IF;

  -- P3 : l institution est enregistree et son resolveur existe reellement.
  SELECT count(*) INTO v_n FROM public.pnj_institutions i
    JOIN pg_proc p ON p.proname = i.resolveur
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE i.institution = 'garde_republicaine';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 : l institution ou son resolveur manque'; END IF;

  -- P4 : les trois postes sont declares, et les trois gardes permanents ont pris leur service
  -- avec leur arme.
  SELECT count(*) INTO v_n FROM public.garde_republicaine_postes WHERE pays = 'republic';
  IF v_n <> 3 THEN RAISE EXCEPTION 'P4a : % postes de garde au lieu de 3', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.pnj_membres m
    JOIN public.garde_republicaine_effectifs e ON e.pnj_id = m.id
   WHERE m.famille = 'garde_republicain' AND m.statut = 'actif' AND e.permanent;
  IF v_n <> 3 THEN RAISE EXCEPTION 'P4b : % gardes permanents en service au lieu de 3', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.pnj_membres m
   WHERE m.famille = 'garde_republicain' AND m.statut = 'actif'
     AND public.militaire_arme_operationnelle(m.id) = 'arme_de_poing';
  IF v_n <> 3 THEN RAISE EXCEPTION 'P4c : % gardes armes au lieu de 3', v_n; END IF;

  -- P5 : la propriete institutionnelle est bien posee -- c est elle qui fait que le ministre est
  -- averti quand un garde tombe.
  SELECT count(*) INTO v_n FROM public.pnj_membres
   WHERE famille = 'garde_republicain' AND statut = 'actif'
     AND proprietaire_institution = 'garde_republicaine' AND proprietaire_perimetre = pays
     AND proprietaire_pj IS NULL AND classe = 'beta';
  IF v_n <> 3 THEN RAISE EXCEPTION 'P5 : la propriete des gardes est mal posee (%)', v_n; END IF;

  -- P6 : les quatre portes sont SECURITY DEFINER a search_path fige, et aucune n est ouverte a anon.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('garde_renfort_national', 'garde_republicaine_synchroniser',
                       'garde_republicaine_piece', 'garde_republicaine_controle')
     AND p.prosecdef
     AND array_to_string(coalesce(p.proconfig,'{}'), ',') LIKE '%search_path%'
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 4 THEN RAISE EXCEPTION 'P6 : % portes correctement posees au lieu de 4', v_n; END IF;

  -- P7 : les trois tables de la Garde sont fermees au client -- RLS active, aucune policy.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relrowsecurity
     AND c.relname IN ('garde_republicaine_postes', 'garde_republicaine_renfort',
                       'garde_republicaine_effectifs');
  IF v_n <> 3 THEN RAISE EXCEPTION 'P7a : % tables sous RLS au lieu de 3', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename LIKE 'garde_republicaine%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P7b : % policy sur les tables de la Garde', v_n; END IF;

  -- P8 : le declencheur de vacance est pose sur le socle.
  SELECT count(*) INTO v_n FROM pg_trigger
   WHERE tgname = 'garde_republicaine_vacance_trg' AND NOT tgisinternal;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P8 : le declencheur de vacance manque'; END IF;

  RAISE NOTICE 'Garde republicaine : les 8 preuves structurelles passent.';
END $$;
