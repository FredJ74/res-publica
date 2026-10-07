-- =============================================================================
-- CHANTIER 4F — LE SALAIRE DU DIRECTEUR N'EST PLUS DECIDE PAR LE NAVIGATEUR
-- 7 octobre 2026
-- =============================================================================
--
-- TROIS CHOSES QUE LE CLIENT DECIDAIT, ET QU'IL NE DECIDERA PLUS.
--
-- percevoir_salaire_directeur(p_acteur, p_pays, p_ville, p_batiment, p_souscle,
-- p_poste_attendu, p_montant) recevait du navigateur :
--
--   1. LE MONTANT. `v_verse := least(v_solde, greatest(0, coalesce(p_montant,0)))`. Le serveur
--      versait ce qu'on lui demandait, plafonne par le solde. Un client modifie pouvait donc
--      vider la caisse de son etablissement en une fois.
--   2. LA VILLE et 3. LE BATIMENT. La fonction verifiait que l'appelant detenait bien le poste
--      annonce (`v_poste IS DISTINCT FROM p_poste_attendu`), mais JAMAIS que l'etablissement
--      nomme etait le sien. Un directeur d'entrepot de Luthecia pouvait se payer sur la caisse
--      de l'entrepot de Montrouge : il lui suffisait de passer une autre ville.
--
--      Le code du navigateur affirme pourtant l'inverse, a plateau-justice-economie.js:5902 :
--      « DIRECTEUR_USINE_INFO garantit deja qu'un poste de directeur ne correspond qu'a une
--      seule usine precise -- aucune selection d'une autre usine n'est possible ». C'est vrai
--      DANS LE NAVIGATEUR. Ce n'etait pas vrai au serveur, qui seul fait autorite.
--
-- OU VIT DESORMAIS LA VERITE. Une table declarative, directions_etablissements, qui dit pour
-- chaque poste de direction quel etablissement il dirige, dans quelle ville, et quel est son
-- salaire quotidien. Le serveur la lit ; il ne lit plus les parametres.
--
-- LE MONTANT N'EST PAS INVENTE. 500 FR/jour est la valeur canonique du jeu, declaree a
-- plateau-justice-economie.js:6089 (`const SALAIRE_DIRECTEUR = 500`) et appliquee aux quatre
-- postes de direction depuis leur creation. Cette migration la deplace, elle ne la decide pas.
-- Les etablissements et les villes viennent de DIRECTEUR_USINE_INFO (ligne 5893) et de
-- ENTREPOT_PAR_VILLE (ligne 5044), eux aussi inchanges.
--
-- LA SIGNATURE NE CHANGE PAS, ET C'EST DELIBERE. p_ville, p_batiment et p_montant restent dans
-- la signature alors qu'ils ne sont plus lus. Les retirer changerait l'arite, donc l'URL
-- PostgREST, et casserait le salaire des directeurs pendant l'intervalle entre l'application de
-- cette migration et le deploiement du navigateur -- dans un sens comme dans l'autre. Le
-- navigateur actuel fonctionne donc a l'identique avant comme apres. Leur retrait est consigne
-- comme dette : il demande un lot ou les deux cotes partent ensemble.
--
-- SECOND VOLET, AJOUTE LE 7 OCTOBRE 2026 APRES L'ARBITRAGE DU GAME DESIGNER.
--
-- La decision rendue : en REPUBLIA, un PJ directeur cumule le revenu universel (150 FR) et son
-- salaire de direction (500 FR) -- le revenu universel est attache au CITOYEN et n'est pas
-- supprime parce qu'il exerce une fonction remuneree. C'est le comportement actuel : les deux
-- circuits sont distincts, portent chacun son propre marqueur anti-rejeu, et ne se connaissent
-- pas. Rien a changer pour l'obtenir.
--
-- MAIS LA DECISION EST EXPRESSEMENT LIMITEE A REPUBLIA, et la verification demandee a trouve une
-- generalisation qui l'etendait aux trois autres empires. salaires_civils_declares n'a PAS de
-- colonne pays, et salaire_civil_percevoir y cherche son bareme sans aucun filtre : un PJ de
-- Sovarka, d'El Estado ou d'Al-Khalija recevait donc le bareme de Republia -- dont les 150 FR de
-- revenu universel, CREES EX NIHILO puisque l'origine 'universel' n'a pas de caisse payeuse.
--
-- Mesure du 7 octobre 2026 : la fuite est LATENTE, jamais exercee. Les sept PJ de la base sont
-- tous en Republia, un seul a deja percu. Aucune donnee de la beta n'est a reparer.
--
-- Le patron de refus par empire existe deja dans ce depot et n'est pas invente ici :
-- salaire_religieux_percevoir refuse explicitement hors Republia
-- (`carriere_religieuse_republia_uniquement`). On fait pareil, par la donnee plutot que par un
-- test code en dur : la table devient dimensionnee par empire, et un empire sans bareme recoit
-- `bareme_absent` -- un motif de refus qui EXISTAIT DEJA dans la fonction. Aucun parametre
-- economique n'est invente pour les trois autres empires.
--
-- IDEMPOTENTE. Rejouable sans effet de bord.
-- AUCUN DROIT A PUBLIC NI A anon sur la fonction creee.
--
-- APPLIQUEE le 7 octobre 2026. Inscrite au registre Supabase sous la version
-- 20261007140910 (le registre horodate a l'application ; le nom de ce fichier garde l'horodatage
-- d'ecriture, comme les migrations precedentes de ce depot).
--
-- VERIFIE APRES APPLICATION, en lecture seule :
--   . 6 lignes dans directions_etablissements, et les 6 lignes batiments_etat correspondantes
--     existent -- la beta continue de payer ;
--   . 17 baremes portent pays='republic', zero sans empire ;
--   . la cle primaire de salaires_civils_declares est bien (pays, cle) ;
--   . les deux fonctions lisent la table et filtrent le pays ;
--   . AUCUN droit anon sur les trois fonctions ;
--   . salaires_coherence() ne signale aucun probleme ;
--   . 151 caisses, soldes inchanges par cette migration.
-- =============================================================================
--
-- NOTE SUR LES COMMENTAIRES SQL : les textes de COMMENT ci-dessous sont EXACTEMENT ceux qui ont
-- ete appliques. Les versions longues de la premiere redaction ont ete raccourcies au moment de
-- l'application ; le fichier a ete aligne dessus plutot que l'inverse, pour qu'il decrive la base
-- reelle et non une intention.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. QUI DIRIGE QUOI, ET POUR COMBIEN
-- -----------------------------------------------------------------------------
-- UNE LIGNE PAR ETABLISSEMENT REELLEMENT DIRIGE. La resolution est alors uniforme pour les deux
-- familles de postes, sans aucun cas special :
--
--   . directeur_entrepot est de scope VILLE (postes_nommes_regles) : son titulaire porte sa
--     ville, et les trois lignes ci-dessous disent quel entrepot s'y trouve.
--   . les trois directeurs d'usine sont de scope PAYS : leur titulaire ne porte pas de ville, et
--     une seule ligne existe pour chacun -- c'est elle qui dit ou se trouve son usine.
--
-- Dans les deux cas, la requete `poste_id = <le mien> AND (ma ville IS NULL OR ville = ma ville)`
-- rend EXACTEMENT UNE ligne. Si elle en rend zero ou plusieurs, la fonction refuse : on ne paie
-- pas sur une identite ambigue.

CREATE TABLE IF NOT EXISTS public.directions_etablissements (
  pays         text    NOT NULL,
  poste_id     text    NOT NULL,
  ville        text    NOT NULL,
  souscle      text    NOT NULL CHECK (souscle IN ('entrepot', 'usine')),
  building_id  text    NOT NULL,
  salaire_jour integer NOT NULL CHECK (salaire_jour >= 0),
  PRIMARY KEY (pays, poste_id, ville)
);

COMMENT ON TABLE public.directions_etablissements IS
  'Quel etablissement chaque poste de direction dirige, ou, et pour quel salaire quotidien. C''est cette table que lit percevoir_salaire_directeur : ni la ville ni le batiment ni le montant ne viennent plus du navigateur.';

ALTER TABLE public.directions_etablissements ENABLE ROW LEVEL SECURITY;
-- Referentiel d'autorite : lu uniquement par des fonctions SECURITY DEFINER. Meme regime que
-- caisses_autorites et salaires_civils_declares, qui n'accordent rien aux roles clients.
--
-- LES TROIS REVOKE SONT NECESSAIRES, ET LE PREMIER NE SUFFIT PAS. C'est le piege symetrique de
-- celui deja rencontre trois fois sur les fonctions : `FROM PUBLIC` ne retire QUE le droit
-- accorde a PUBLIC, et Supabase accorde SELECT a `anon` et `authenticated` NOMMEMENT sur toute
-- table neuve du schema public, par ALTER DEFAULT PRIVILEGES. La migration du 7 octobre 2026
-- n'avait que la premiere ligne : la table est donc nee avec `anon=r` et `authenticated=r`.
-- La RLS etant active sans aucune policy, aucune ligne ne sortait -- le droit etait inerte --
-- mais il contredisait cette declaration, et une policy ajoutee plus tard l'aurait reveille.
-- Corrige par la migration 20261007150500_directions_etablissements_sans_roles_clients.sql.
REVOKE ALL ON TABLE public.directions_etablissements FROM PUBLIC;
REVOKE ALL ON TABLE public.directions_etablissements FROM anon;
REVOKE ALL ON TABLE public.directions_etablissements FROM authenticated;

DELETE FROM public.directions_etablissements WHERE pays = 'republic';
INSERT INTO public.directions_etablissements (pays, poste_id, ville, souscle, building_id, salaire_jour) VALUES
  ('republic', 'directeur_entrepot',      'capitale', 'entrepot', 'entrepot-logistique-luthecia',  500),
  ('republic', 'directeur_entrepot',      'ville_a',  'entrepot', 'entrepot-logistique-psm',       500),
  ('republic', 'directeur_entrepot',      'ville_b',  'entrepot', 'entrepot-logistique-montrouge', 500),
  ('republic', 'directeur_pharma',        'capitale', 'usine',    'usine-pharmaceutique-luthecia', 500),
  ('republic', 'directeur_tabac_alcools', 'ville_a',  'usine',    'pole-tabac-alcools-psm',        500),
  ('republic', 'directeur_raffinerie',    'ville_b',  'usine',    'raffinerie-montrouge',          500);

-- LES TROIS AUTRES EMPIRES N'Y SONT PAS, ET CE N'EST PAS UN OUBLI. Aucun etablissement de
-- production n'est declare pour Sovarka, El Estado ou Al-Khalija -- ni dans le jeu, ni dans le
-- cron, qui ne connait que Republia sur toute l'economie. En inventer serait fabriquer du game
-- design. Un directeur d'un autre empire recevra donc un refus explicite
-- (`direction_non_declaree`), jamais les valeurs de Republia.

-- -----------------------------------------------------------------------------
-- 2. LA FONCTION LIT LA TABLE, PLUS SES PARAMETRES
-- -----------------------------------------------------------------------------
-- Tout le reste est reprit a l'identique : exiger_acteur, le verrou FOR UPDATE sur les deux
-- lignes, le marqueur du jour dans stats, le versement PARTIEL conserve (la caisse paie ce
-- qu'elle peut -- c'est une regle existante, pas une tolerance), et la forme du retour.

CREATE OR REPLACE FUNCTION public.percevoir_salaire_directeur(p_acteur text, p_pays text, p_ville text, p_batiment text, p_souscle text, p_poste_attendu text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste text; v_poste_city text; v_pays text; v_jour int; v_stats jsonb;
  v_marqueur text; v_id text;
  d record; v_nb int;
  v_etat jsonb; v_sous jsonb; v_solde numeric; v_verse numeric;
  v_arg numeric; v_liquide numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  -- L'IDENTITE VIENT DE LA FICHE, PAS DES PARAMETRES. p_pays, p_ville, p_batiment, p_souscle et
  -- p_montant sont desormais IGNORES (voir l'en-tete : ils restent dans la signature pour ne pas
  -- casser le deploiement). Le poste et sa ville sont lus en base, sous verrou.
  SELECT poste->>'id', poste->>'city', coalesce(country,'republic'),
         coalesce(day,1), coalesce(stats,'{}'::jsonb), coalesce(arg,0), coalesce(liquide,0)
    INTO v_poste, v_poste_city, v_pays, v_jour, v_stats, v_arg, v_liquide
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF v_poste IS DISTINCT FROM p_poste_attendu THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;

  -- L'ETABLISSEMENT DIRIGE. Exactement une ligne, ou rien.
  SELECT count(*) INTO v_nb FROM public.directions_etablissements x
   WHERE x.pays = v_pays AND x.poste_id = v_poste
     AND (coalesce(btrim(v_poste_city), '') = '' OR x.ville = v_poste_city);
  IF v_nb <> 1 THEN
    -- Zero : ce poste ne dirige aucun etablissement declare dans cet empire.
    -- Plusieurs : le poste est territorial et sa fiche ne porte pas de ville -- on ne devine pas
    -- laquelle, et surtout on ne paie pas sur la premiere trouvee.
    RETURN jsonb_build_object('ok', false, 'raison', 'direction_non_declaree',
                              'poste', v_poste, 'ville_du_poste', v_poste_city,
                              'lignes_trouvees', v_nb);
  END IF;
  SELECT * INTO d FROM public.directions_etablissements x
   WHERE x.pays = v_pays AND x.poste_id = v_poste
     AND (coalesce(btrim(v_poste_city), '') = '' OR x.ville = v_poste_city);

  v_marqueur := 'salaireDirecteur_' || d.souscle || '_' || d.building_id;
  IF coalesce((v_stats->>v_marqueur)::int, -1) = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percu_aujourdhui');
  END IF;

  v_id := d.pays || '_' || d.ville || '_' || d.building_id;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etablissement_introuvable', 'id', v_id);
  END IF;
  v_sous  := coalesce(v_etat->d.souscle, '{}'::jsonb);
  v_solde := coalesce((v_sous->>'caisse')::numeric, 0);
  v_verse := least(v_solde, d.salaire_jour);   -- versement partiel conserve
  IF v_verse < 0 THEN v_verse := 0; END IF;

  IF v_verse > 0 THEN
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etat || jsonb_build_object(d.souscle,
             v_sous || jsonb_build_object('caisse', v_solde - v_verse)))::text), updated_at = now()
     WHERE id = v_id;
  END IF;
  UPDATE public.personnages_donnees
     SET arg = v_arg + v_verse, liquide = v_liquide + v_verse,
         stats = jsonb_set(v_stats, ARRAY[v_marqueur], to_jsonb(v_jour))
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse,
    'complet', v_verse >= d.salaire_jour, 'du', d.salaire_jour,
    'etablissement', d.building_id, 'ville', d.ville,
    'arg', v_arg + v_verse, 'liquide', v_liquide + v_verse, 'caisse', v_solde - v_verse);
END; $function$;

COMMENT ON FUNCTION public.percevoir_salaire_directeur(text, text, text, text, text, text, numeric) IS
  'Le montant, la ville et le batiment viennent de directions_etablissements, JAMAIS des parametres : p_pays, p_ville, p_batiment, p_souscle et p_montant sont ignores et ne subsistent que pour la compatibilite de deploiement.';

REVOKE ALL ON FUNCTION public.percevoir_salaire_directeur(text, text, text, text, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.percevoir_salaire_directeur(text, text, text, text, text, text, numeric) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. LES BAREMES CIVILS SONT DIMENSIONNES PAR EMPIRE
-- -----------------------------------------------------------------------------
-- La colonne `pays` est ajoutee avec un defaut 'republic' le temps de la bascule : les dix-sept
-- lignes existantes ont toutes ete semees pour Republia, et c'est le seul empire pour lequel un
-- bareme a jamais ete decide. Le defaut est RETIRE juste apres, pour qu'aucune ligne future ne
-- puisse entrer sans dire a quel empire elle appartient.

ALTER TABLE public.salaires_civils_declares
  ADD COLUMN IF NOT EXISTS pays text NOT NULL DEFAULT 'republic';
ALTER TABLE public.salaires_civils_declares ALTER COLUMN pays DROP DEFAULT;

-- LA CLE PRIMAIRE DEVIENT (pays, cle). Sans cela, Sovarka ne pourrait jamais declarer sa propre
-- ligne 'default' : `cle` etant unique, la ligne de Republia bloquerait la place. C'est
-- exactement ce qui rend l'architecture configurable au lieu d'etre Republia-par-construction.
DO $bascule$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint
              WHERE conrelid = 'public.salaires_civils_declares'::regclass
                AND contype = 'p' AND array_length(conkey, 1) = 1) THEN
    ALTER TABLE public.salaires_civils_declares DROP CONSTRAINT salaires_civils_declares_pkey;
    ALTER TABLE public.salaires_civils_declares ADD PRIMARY KEY (pays, cle);
  END IF;
END $bascule$;

COMMENT ON COLUMN public.salaires_civils_declares.pays IS
  'L''empire pour lequel ce bareme est declare. Un empire sans ligne recoit bareme_absent, jamais les valeurs de Republia.';

-- LA FONCTION FILTRE SUR L'EMPIRE DE L'ACTEUR, dans ses TROIS recherches de bareme.
-- Tout le reste est reprit a l'identique : la ville vient du poste (correctif du 20/09/2026), le
-- militaire est renvoye vers la caserne, la cle d'anti-rejeu est posee AVANT tout mouvement
-- d'argent, le versement est TOUT OU RIEN, et la ligne d'anti-rejeu est retiree si la caisse ne
-- suffit pas.
--
-- LE CUMUL EST PRESERVE, ET C'EST LE POINT DE LA DECISION. Les quatre postes de direction n'ont
-- deliberement AUCUNE ligne de categorie 'poste' ici : ils tombent donc sur la cle 'default'
-- (categorie 'universel', 150 FR), qu'ils percoivent EN PLUS des 500 FR verses par
-- percevoir_salaire_directeur sur la caisse de leur etablissement. Les deux circuits restent
-- distincts -- marqueurs anti-rejeu differents, caisses payeuses differentes -- et ne se
-- connaissent pas. Leur fusion n'est pas souhaitable : le revenu universel est attache au
-- citoyen, le salaire de direction a l'etablissement.
--
-- NE DECLARE JAMAIS directeur_entrepot, directeur_pharma, directeur_tabac_alcools NI
-- directeur_raffinerie en categorie 'poste' dans cette table : cela les sortirait du repli
-- universel et SUPPRIMERAIT le cumul arbitre. salaires_coherence() le refuse desormais.

CREATE OR REPLACE FUNCTION public.salaire_civil_percevoir()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; v_ville text; v_grade text;
  v_jour date; v_id text; v_cle text; v_origine text; v_montant integer;
  v_offres jsonb; v_offre text; v_caisse text; v_solde numeric;
  v_arg numeric; v_liquide numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- LA VILLE VIENT DU POSTE, JAMAIS DE LA POSITION (20/09/2026). current_city est la
  -- ville ou le joueur SE TROUVE : l'employer ici laissait un titulaire se faire payer
  -- par la caisse de la ville ou il passait. A defaut de ville sur le poste, on prend le
  -- defaut DECLARE pour ce poste (salaires_caisses.ville_defaut) ; s'il n'y en a pas,
  -- v_ville reste NULL et salaire_caisse_de ne resoudra aucune caisse -- refus explicite.
  SELECT coalesce(country,'republic'), poste ->> 'id',
         public.salaire_ville_du_poste(poste ->> 'id', poste ->> 'city')
    INTO v_pays, v_poste, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;

  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NOT NULL OR coalesce(v_poste,'') IN ('soldat','lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paye_par_la_caserne');
  END IF;

  IF v_poste IS NOT NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s
     WHERE s.pays = v_pays AND s.cle = v_poste AND s.categorie = 'poste';
  END IF;

  IF v_cle IS NULL THEN
    SELECT coalesce(e.data -> 'offres', e.data -> 'bne' -> 'offres')
      INTO v_offres FROM public.batiments_etat e WHERE e.id = v_pays || '_national_bne';
    IF v_offres IS NOT NULL AND jsonb_typeof(v_offres) = 'object' THEN
      SELECT t.k INTO v_offre
        FROM jsonb_each(v_offres) AS t(k, v)
        WHERE EXISTS (
          SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.v)='array' THEN t.v ELSE '[]'::jsonb END) o
           WHERE o ->> 'pjNom' = v_moi AND coalesce(o ->> 'statut','actif') = 'actif')
        LIMIT 1;
      IF v_offre IS NOT NULL THEN
        SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
          FROM public.salaires_civils_declares s
         WHERE s.pays = v_pays AND s.cle = v_offre AND s.categorie = 'emploi';
      END IF;
    END IF;
  END IF;

  -- LE REVENU UNIVERSEL. Attache au CITOYEN : il n'est pas supprime parce que l'acteur exerce
  -- une fonction remuneree ailleurs (arbitrage du 7 octobre 2026, Republia). Il n'est servi
  -- qu'aux empires qui l'ont DECLARE -- sans ligne, pas de repli sur Republia.
  IF v_cle IS NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s
     WHERE s.pays = v_pays AND s.cle = 'default';
  END IF;

  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bareme_absent', 'pays', v_pays);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;

  -- LA CAISSE PAYEUSE. Seul le revenu universel n'en a pas.
  IF v_origine = 'poste' THEN
    v_caisse := public.salaire_caisse_de(v_poste, v_pays, v_ville);
    IF v_caisse IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_payeuse_non_declaree', 'poste', v_poste);
    END IF;
  END IF;

  -- L'anti-rejeu EST la cle : pose AVANT tout mouvement d'argent.
  BEGIN
    INSERT INTO public.salaires_civils_verses (id, personnage, jour, origine, cle, montant)
    VALUES (v_id, v_moi, v_jour, v_origine, v_cle, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT coalesce(arg,0), coalesce(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percu_aujourdhui',
                              'jour', v_jour, 'arg', v_arg, 'liquide', v_liquide);
  END;

  IF v_caisse IS NOT NULL THEN
    SELECT (data->>'solde')::numeric INTO v_solde
      FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    -- TOUT OU RIEN : pas de versement partiel, pas de dette.
    IF coalesce(v_solde, 0) < v_montant THEN
      -- On retire la ligne d'anti-rejeu : rien n'a ete verse, le titulaire
      -- pourra retenter si sa caisse est realimentee dans la journee.
      DELETE FROM public.salaires_civils_verses WHERE id = v_id;
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                                'caisse', v_caisse, 'solde', coalesce(v_solde,0), 'du', v_montant);
    END IF;
    UPDATE public.caisses_batiments
       SET data = coalesce(data,'{}'::jsonb) || jsonb_build_object('solde', v_solde - v_montant),
           updated_at = now()
     WHERE id = v_caisse;
  END IF;

  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide,0) + v_montant,
         arg     = coalesce(arg,0)     + v_montant,
         updated_at = now()
   WHERE name = v_moi
   RETURNING arg, liquide INTO v_arg, v_liquide;

  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'origine', v_origine,
                            'cle', v_cle, 'jour', v_jour, 'caisse', v_caisse,
                            'arg', v_arg, 'liquide', v_liquide);
END;
$function$;

COMMENT ON FUNCTION public.salaire_civil_percevoir() IS
  'Bareme de poste, puis emploi BNE, puis revenu universel -- chacun cherche DANS L''EMPIRE de l''acteur. Un empire sans bareme recoit bareme_absent, jamais les valeurs de Republia. Le revenu universel est attache au citoyen : il n''est pas supprime parce que l''acteur percoit un salaire de direction (arbitrage du 7 octobre 2026, Republia uniquement).';

REVOKE ALL ON FUNCTION public.salaire_civil_percevoir() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.salaire_civil_percevoir() TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. LE CONTROLE QUI EMPECHE LA REGRESSION
-- -----------------------------------------------------------------------------
-- salaires_coherence() existait deja et verifiait deux choses. Elle en verifie quatre.
-- Les deux nouvelles protegent precisement l'arbitrage du 7 octobre 2026.

CREATE OR REPLACE FUNCTION public.salaires_coherence()
RETURNS TABLE(probleme text, cles text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT 'bareme de poste sans caisse payeuse', string_agg(s.pays || '/' || s.cle, ', ' ORDER BY s.pays, s.cle)
    FROM public.salaires_civils_declares s
   WHERE s.categorie = 'poste'
     AND NOT EXISTS (SELECT 1 FROM public.salaires_caisses c WHERE c.poste_id = s.cle)
  HAVING count(*) > 0
  UNION ALL
  SELECT 'caisse payeuse sans bareme', string_agg(c.poste_id, ', ' ORDER BY c.poste_id)
    FROM public.salaires_caisses c
   WHERE NOT EXISTS (SELECT 1 FROM public.salaires_civils_declares s
                      WHERE s.cle = c.poste_id AND s.categorie = 'poste')
  HAVING count(*) > 0
  UNION ALL
  -- LE CUMUL ARBITRE. Declarer un poste de direction en categorie 'poste' le sortirait du repli
  -- universel : il perdrait les 150 FR attaches au citoyen, et le cumul decide le 7 octobre 2026
  -- serait silencieusement supprime. C'est le SEUL mecanisme par lequel il peut se perdre.
  SELECT 'poste de direction declare en bareme de poste : SUPPRIME le cumul avec le revenu universel',
         string_agg(s.pays || '/' || s.cle, ', ' ORDER BY s.pays, s.cle)
    FROM public.salaires_civils_declares s
   WHERE s.categorie = 'poste'
     AND EXISTS (SELECT 1 FROM public.directions_etablissements d
                  WHERE d.pays = s.pays AND d.poste_id = s.cle)
  HAVING count(*) > 0
  UNION ALL
  -- UN BAREME SANS EMPIRE NE DOIT PLUS EXISTER : c'est par la que les trois autres empires
  -- heritaient de Republia.
  SELECT 'bareme sans empire declare', string_agg(s.cle, ', ' ORDER BY s.cle)
    FROM public.salaires_civils_declares s
   WHERE coalesce(btrim(s.pays), '') = ''
  HAVING count(*) > 0;
$function$;

COMMENT ON FUNCTION public.salaires_coherence() IS
  'Quatre invariants des baremes. Les deux derniers protegent l''arbitrage du 7 octobre 2026 : un poste de direction ne doit jamais etre declare en bareme de poste (il perdrait le revenu universel), et aucun bareme ne doit exister sans empire declare.';

REVOKE ALL ON FUNCTION public.salaires_coherence() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.salaires_coherence() TO service_role;

COMMIT;
