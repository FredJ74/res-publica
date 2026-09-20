-- =====================================================================
-- SALAIRES PAYES PAR LEUR CAISSE — LOT DU 20 SEPTEMBRE 2026
-- =====================================================================
-- OBJET DU LOT. Chaque poste est paye par la caisse de son institution. Si la
-- caisse ne contient pas assez : LE SALAIRE N'EST PAS VERSE. Pas de creation
-- monetaire, pas de decouvert, pas de dette, pas d'arriere. Le revenu universel
-- de 150 FR reste, lui, une creation ex nihilo assumee, independante de toute
-- caisse. Le meme principe est etendu aux charges religieuses, dont le credit
-- etait jusque-la fait dans le navigateur.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES (toutes du 20/09/2026) :
--   20260920094712  salaires_payes_par_leur_caisse
--   20260920095124  salaires_alias_adjoint_au_maire
--   20260920100447  salaires_vestiges_et_itinerants
--   20260920102437  salaire_religieux_atteste
--   20260920110011  salaire_caisse_ville_du_poste
--
-- AVERTISSEMENT — ETAT FINAL, PAS HISTORIQUE. Ce fichier photographie la base au
-- soir du 20/09/2026. Deux effets nets ont ete calcules plutot que rejoues :
--   * 095124 inserait une ligne 'adj_maire' dans salaires_caisses, que 100447
--     supprime ensuite. Effet net nul : ni l'insertion ni la suppression ne
--     figurent ici, et la ligne est absente du jeu de reference ci-dessous.
--   * 095124 declarait aussi le bareme sous 'adj_maire' dans
--     salaires_civils_declares ; 100447 le supprime. Seule la cle canonique
--     'maire_adjoint' survit, et c'est elle qui est versionnee.
--
-- CHEVAUCHEMENT SIGNALE. Les lignes de salaires_caisses sont dumpees depuis la
-- base : elles portent donc DEJA l'effet de la migration 20260920120926
-- (juges_par_ville_autorite_nationale, versionnee par ailleurs), qui fait
--     UPDATE public.salaires_caisses SET ville_defaut = NULL WHERE poste_id = 'juge';
-- C'est pourquoi 'juge' apparait ici avec ville_defaut NULL alors que 110011 y
-- posait 'capitale'. Ce fichier ne duplique pas cet UPDATE : il en reflete le
-- resultat. Si les deux fichiers sont rejoues dans l'ordre, l'etat est identique.
--
-- DEPENDANCES. Aucun fichier *.sql du depot ne cree les objets prerequis : ils
-- viennent de migrations de production non encore exportees. Doivent etre en
-- place AVANT ce fichier :
--   * tables public.salaires_civils_declares et public.salaires_civils_verses,
--     et la premiere version de salaire_civil_percevoir()
--       -> 20260919232339 salaire_civil_atteste
--   * tables public.caisses_batiments, public.batiments_etat,
--     public.personnages_donnees, public.titulaires_pnj
--   * fonctions public.mon_personnage(), public.militaire_grade_effectif()
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. LE MIROIR DU RATTACHEMENT POSTE -> CAISSE
-- ---------------------------------------------------------------------
-- Commentaire d'origine (20260920094712) :
--
-- MIROIR DU RATTACHEMENT. Les identifiants de caisse du jeu ne sont pas
-- reguliers : la capitale utilise « mairie-capitale » et « commissariat_capitale »
-- (tiret puis souligne), les autres villes « mairie_ville_a ». On ne devine donc
-- pas le nom : on le declare, a partir des 54 caisses reellement presentes.
--
-- La colonne ville_defaut a ete ajoutee le meme jour par 20260920110011 ; elle est
-- integree directement au CREATE TABLE, conformement a la forme finale.

CREATE TABLE IF NOT EXISTS public.salaires_caisses (
  poste_id      text PRIMARY KEY,
  motif         text NOT NULL,         -- gabarit d'identifiant, {pays} et {ville} substitues
  par_ville     boolean NOT NULL DEFAULT false,
  note          text,
  ville_defaut  text                   -- ajoutee par 20260920110011
);
ALTER TABLE public.salaires_caisses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salaires_caisses FROM PUBLIC, anon, authenticated;
-- Aucune policy : RLS active sans policy = table fermee a anon/authenticated.
-- Seuls postgres et service_role y accedent (ACL constatee en production).

-- LIGNES DE REFERENCE — ETAT FINAL EN BASE (13 lignes). Generees depuis la
-- production. 'adj_maire' n'y figure pas (insere puis supprime le meme jour).
INSERT INTO public.salaires_caisses (poste_id, motif, par_ville, note, ville_defaut) VALUES
  ('commissaire',   '{pays}_commissariat_{ville}',  true,  'commissariat de sa ville', NULL),
  ('depute',        '{pays}_assemblee',             false, 'Assemblee nationale', NULL),
  ('juge',          '{pays}_tribunal_{ville}',      false, 'poste de portee nationale : tribunal de la capitale', NULL),
  ('maire',         '{pays}_mairie_{ville}',        true,  'mairie de sa ville', NULL),
  ('maire_adjoint', '{pays}_mairie_{ville}',        true,  'mairie de sa ville', NULL),
  ('min_ae',        '{pays}_gouvernement-min_ae',   false, 'ministere', NULL),
  ('min_def',       '{pays}_gouvernement-min_def',  false, 'ministere', NULL),
  ('min_fin',       '{pays}_gouvernement-min_fin',  false, 'ministere', NULL),
  ('min_info',      '{pays}_gouvernement-min_info', false, 'ministere', NULL),
  ('min_int',       '{pays}_gouvernement-min_int',  false, 'ministere', NULL),
  ('min_just',      '{pays}_gouvernement-min_just', false, 'ministere', NULL),
  ('pm',            '{pays}_gouvernement-pm',       false, 'Palais du Gouvernement — enveloppe du PM', NULL),
  ('president',     '{pays}_palais-presidentiel',   false, 'Palais presidentiel', NULL)
ON CONFLICT (poste_id) DO UPDATE
  SET motif = EXCLUDED.motif, par_ville = EXCLUDED.par_ville,
      note = EXCLUDED.note, ville_defaut = EXCLUDED.ville_defaut;


-- ---------------------------------------------------------------------
-- 2. LA VILLE VIENT DU POSTE, JAMAIS DE LA POSITION
-- ---------------------------------------------------------------------
-- Commentaire d'origine (20260920110011) :
--
-- ARBITRAGE GD DU 20/09/2026 : « chaque juge est payé par la caisse du tribunal
-- de sa propre ville ». Principe general deja valide : le titulaire est paye par
-- l'institution dans laquelle il exerce.
--
-- CE QUE J'AI TROUVE EN APPLIQUANT. Le motif du juge etait fige sur
-- « {pays}_tribunal_capitale ». Ce n'etait pas une negligence : le juge est
-- aujourd'hui declare comme un poste NATIONAL (plateau-politique.js, section
-- « national »), au meme titre que les ministres -- seuls maire, commissaire et
-- directeur d'entrepot sont declares par ville. Un juge ne porte donc AUCUNE
-- ville sur sa fiche. La regle arbitree suppose des juges par ville, ce qui est
-- un changement de structure que je ne decide pas ici : le motif est corrige,
-- et la regle s'appliquera d'elle-meme le jour ou le poste portera une ville.
--
-- LE TROU QUE LE CHANGEMENT AURAIT OUVERT. salaire_civil_percevoir resolvait la
-- ville par « coalesce(poste->>'city', current_city) ». current_city, c'est la
-- ville ou le joueur SE TROUVE, pas celle ou il exerce. Avec un motif contenant
-- {ville}, un titulaire sans ville declaree se serait fait payer par le tribunal
-- de la ville ou il passait -- et aurait pu vider les trois en se deplacant.
-- La ville vient desormais du POSTE, jamais de la position. A defaut, elle vient
-- d'un defaut DECLARE par poste ; sans defaut declare, on refuse de payer plutot
-- que de choisir une caisse au hasard.

CREATE OR REPLACE FUNCTION public.salaire_ville_du_poste(p_poste_id text, p_ville_fiche text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN coalesce(btrim(p_ville_fiche), '') <> '' THEN p_ville_fiche
    ELSE (SELECT s.ville_defaut FROM public.salaires_caisses s WHERE s.poste_id = p_poste_id)
  END;
$function$;
REVOKE ALL ON FUNCTION public.salaire_ville_du_poste(text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.salaire_ville_du_poste(text, text) TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- 3. RESOLUTION DE L'IDENTIFIANT REEL DE LA CAISSE PAYEUSE
-- ---------------------------------------------------------------------
-- Resout l'identifiant reel, en tenant compte de l'irregularite de nommage de
-- la capitale (mairie-capitale, commissariat_capitale...). On ne renvoie que des
-- caisses qui EXISTENT : un nom resolu vers rien n'est pas une caisse.
CREATE OR REPLACE FUNCTION public.salaire_caisse_de(p_poste_id text, p_pays text, p_ville text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_id text; v_alt text;
BEGIN
  SELECT * INTO r FROM public.salaires_caisses s WHERE s.poste_id = p_poste_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  v_id := replace(replace(r.motif, '{pays}', coalesce(p_pays,'')), '{ville}', coalesce(p_ville,''));
  IF EXISTS (SELECT 1 FROM public.caisses_batiments c WHERE c.id = v_id) THEN
    RETURN v_id;
  END IF;

  -- La capitale ecrit « mairie-capitale » la ou les autres villes ecrivent
  -- « mairie_ville_a ». On essaie donc la variante a tiret avant d'abandonner.
  v_alt := replace(v_id, '_' || coalesce(p_ville,''), '-' || coalesce(p_ville,''));
  IF v_alt <> v_id AND EXISTS (SELECT 1 FROM public.caisses_batiments c WHERE c.id = v_alt) THEN
    RETURN v_alt;
  END IF;

  RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION public.salaire_caisse_de(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.salaire_caisse_de(text, text, text) TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- 4. LE SALAIRE CIVIL, PAYE PAR SA CAISSE
-- ---------------------------------------------------------------------
-- ETAT FINAL. 20260920094712 avait pose une version qui resolvait la ville par
-- « coalesce(poste ->> 'city', current_city) ». Le bloc de resolution a ete
-- remplace le meme jour par l'appel a salaire_ville_du_poste (arbitrage de
-- 110011), sans passer par une migration versionnee. C'est le corps ci-dessous,
-- copie depuis pg_proc, qui est en production.
CREATE OR REPLACE FUNCTION public.salaire_civil_percevoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
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
      FROM public.salaires_civils_declares s WHERE s.cle = v_poste AND s.categorie = 'poste';
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
          FROM public.salaires_civils_declares s WHERE s.cle = v_offre AND s.categorie = 'emploi';
      END IF;
    END IF;
  END IF;

  IF v_cle IS NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s WHERE s.cle = 'default';
  END IF;

  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bareme_absent');
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
-- Droits constates en production (poses par 20260919232339, conserves par le
-- CREATE OR REPLACE ; repetes ici pour qu'un rejeu a neuf aboutisse au meme etat).
REVOKE ALL ON FUNCTION public.salaire_civil_percevoir() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.salaire_civil_percevoir() TO authenticated, service_role;


-- ---------------------------------------------------------------------
-- 5. LE FILET DE COHERENCE
-- ---------------------------------------------------------------------
-- Filet : si un bareme de poste reapparait sans caisse payeuse declaree, le
-- salaire est refuse plutot que verse ex nihilo. On le verifie par contrainte
-- plutot que par convention.
CREATE OR REPLACE FUNCTION public.salaires_coherence()
 RETURNS TABLE(probleme text, cles text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT 'bareme de poste sans caisse payeuse', string_agg(s.cle, ', ' ORDER BY s.cle)
    FROM public.salaires_civils_declares s
   WHERE s.categorie = 'poste'
     AND NOT EXISTS (SELECT 1 FROM public.salaires_caisses c WHERE c.poste_id = s.cle)
  HAVING count(*) > 0
  UNION ALL
  SELECT 'caisse payeuse sans bareme', string_agg(c.poste_id, ', ' ORDER BY c.poste_id)
    FROM public.salaires_caisses c
   WHERE NOT EXISTS (SELECT 1 FROM public.salaires_civils_declares s
                      WHERE s.cle = c.poste_id AND s.categorie = 'poste')
  HAVING count(*) > 0;
$function$;
REVOKE ALL ON FUNCTION public.salaires_coherence() FROM PUBLIC, anon, authenticated;


-- ---------------------------------------------------------------------
-- 6. LE SALAIRE RELIGIEUX PASSE AU SERVEUR
-- ---------------------------------------------------------------------
-- Commentaire d'origine (20260920102437) :
--
-- CE QUI SE PASSAIT. verifierSalaireReligieux() (plateau-justice-economie.js)
-- debitait la caisse de l'eglise par une RPC, puis creditait le joueur par un
-- « state.arg += montant » LOCAL. Les deux moitiees etaient donc disjointes : le
-- credit n'etait atteste par rien, et son anti-rejeu tenait dans une valeur du
-- navigateur (state.char.dernierSalaireReligieuxJour) comparee a state.day.
-- Une fois le verrou arg/liquide actif, cette moitie-la serait silencieusement
-- ecrasee : la caisse aurait ete debitee sans que personne ne soit paye.
--
-- REGLES REPRISES A L'IDENTIQUE, rien d'invente ici :
--   * Pretre d'une ville     : 100 FR/jour, payes par la caisse de SON eglise ;
--   * Grand Pretre national  : +100 FR/jour, TOUJOURS par le Grand Tabernacle,
--                              meme s'il est par ailleurs Pretre d'une autre ville ;
--   * versement PLAFONNE par le solde (comportement existant : une caisse a moitie
--     vide paie ce qu'elle peut, ce qui ne cree aucune dette) ;
--   * titulaire lu dans titulaires_pnj, avec repli sur le PNJ par defaut -- un PJ
--     n'est paye que s'il EST le titulaire.
--
-- Le bareme et la carte des eglises sont declares en base, pas passes par l'appel :
-- le client ne choisit ni le montant, ni la caisse, ni le titulaire.

CREATE TABLE IF NOT EXISTS public.salaires_religieux_declares (
  cle       text PRIMARY KEY,
  ville     text,
  caisse    text NOT NULL,
  montant   integer NOT NULL CHECK (montant > 0),
  libelle   text
);
ALTER TABLE public.salaires_religieux_declares ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salaires_religieux_declares FROM anon, authenticated, public;

-- LIGNES DE REFERENCE — ETAT FINAL EN BASE (4 lignes).
INSERT INTO public.salaires_religieux_declares (cle, ville, caisse, montant, libelle) VALUES
  ('grand_pretre',      NULL,       'republic_tabernacle-impots', 100, 'Grand Pretre national'),
  ('pretre:capitale',   'capitale', 'republic_tabernacle-impots', 100, 'Pretre du Grand Tabernacle (Luthecia)'),
  ('pretre:ville_a',    'ville_a',  'republic_notre-dame-mer',    100, 'Pretre de Notre-Dame-de-la-Mer (Port-Sainte-Marie)'),
  ('pretre:ville_b',    'ville_b',  'republic_eglise-montrouge',  100, 'Pretre de l''eglise de Montrouge')
ON CONFLICT (cle) DO UPDATE
  SET ville = EXCLUDED.ville, caisse = EXCLUDED.caisse,
      montant = EXCLUDED.montant, libelle = EXCLUDED.libelle;

-- Anti-rejeu : la cle EST le verrou (personnage + charge + jour reel).
CREATE TABLE IF NOT EXISTS public.salaires_religieux_verses (
  id          text PRIMARY KEY,
  personnage  text NOT NULL,
  cle         text NOT NULL,
  jour        date NOT NULL,
  montant     numeric NOT NULL,
  verse_le    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.salaires_religieux_verses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.salaires_religieux_verses FROM anon, authenticated, public;

CREATE OR REPLACE FUNCTION public.salaire_religieux_percevoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi     text;
  v_pays    text;
  v_jour    date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_total   numeric := 0;
  v_details jsonb := '[]'::jsonb;
  r         record;
  v_titulaire text;
  v_id      text;
  v_solde   numeric;
  v_verse   numeric;
  v_arg     numeric;
  v_liquide numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF coalesce(v_pays, 'republic') <> 'republic' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'carriere_religieuse_republia_uniquement');
  END IF;

  FOR r IN SELECT * FROM public.salaires_religieux_declares ORDER BY cle LOOP
    -- LE TITULAIRE FAIT AUTORITE, PAS L'APPELANT. Le repli PNJ par defaut n'est
    -- jamais le joueur : une charge sans titulaire enregistre ne paie personne.
    SELECT t.nom_pnj INTO v_titulaire
      FROM public.titulaires_pnj t
     WHERE t.country = 'republic'
       AND t.poste_id = split_part(r.cle, ':', 1)
       AND ((r.ville IS NULL AND t.city IS NULL) OR t.city = r.ville)
     LIMIT 1;

    CONTINUE WHEN v_titulaire IS NULL OR v_titulaire <> v_moi;

    v_id := v_moi || ':' || r.cle || ':' || v_jour::text;
    BEGIN
      INSERT INTO public.salaires_religieux_verses (id, personnage, cle, jour, montant)
      VALUES (v_id, v_moi, r.cle, v_jour, r.montant);
    EXCEPTION WHEN unique_violation THEN
      CONTINUE;  -- deja percu aujourd'hui pour CETTE charge
    END;

    SELECT (data->>'solde')::numeric INTO v_solde
      FROM public.caisses_batiments WHERE id = r.caisse FOR UPDATE;

    -- Plafonne : la caisse paie ce qu'elle peut, jamais a decouvert.
    v_verse := least(coalesce(v_solde, 0), r.montant);
    IF v_verse <= 0 THEN
      -- Rien verse : on retire la ligne d'anti-rejeu pour que le titulaire puisse
      -- retenter si sa caisse est realimentee dans la journee.
      DELETE FROM public.salaires_religieux_verses WHERE id = v_id;
      v_details := v_details || jsonb_build_object('cle', r.cle, 'verse', 0, 'raison', 'caisse_vide');
      CONTINUE;
    END IF;

    UPDATE public.caisses_batiments
       SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
           updated_at = now()
     WHERE id = r.caisse;
    UPDATE public.salaires_religieux_verses SET montant = v_verse WHERE id = v_id;

    v_total   := v_total + v_verse;
    v_details := v_details || jsonb_build_object('cle', r.cle, 'verse', v_verse, 'caisse', r.caisse);
  END LOOP;

  IF v_total > 0 THEN
    UPDATE public.personnages_donnees
       SET liquide = coalesce(liquide, 0) + v_total,
           arg     = coalesce(arg, 0)     + v_total,
           updated_at = now()
     WHERE name = v_moi
     RETURNING arg, liquide INTO v_arg, v_liquide;
  ELSE
    SELECT coalesce(arg, 0), coalesce(liquide, 0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
  END IF;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'jour', v_jour,
                            'details', v_details, 'arg', v_arg, 'liquide', v_liquide);
END;
$function$;

REVOKE ALL ON FUNCTION public.salaire_religieux_percevoir() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.salaire_religieux_percevoir() TO authenticated, service_role;


-- =====================================================================
-- REPARATION PONCTUELLE DES DONNEES DU 20 SEPTEMBRE
-- =====================================================================
-- Ces ecritures portent sur salaires_civils_declares, table METIER creee par la
-- migration anterieure 20260919232339 (non versionnee dans le depot). Elles ne
-- sont pas derivables du schema : recopiees depuis les migrations d'origine.

-- 20260920095124 — DEFAUT DETERMINISTE TROUVE AU CALCUL DES DOTATIONS.
-- Le meme poste porte DEUX identifiants selon la source :
--   data.js SALAIRES ............. 'adj_maire'     (500 FR)
--   postes_nommes_regles ......... 'maire_adjoint' (nomme par le maire, scope ville)
-- La fiche d'un adjoint porte l'identifiant atteste, 'maire_adjoint'. Le bareme
-- etant range sous 'adj_maire', son salaire ne se serait JAMAIS resolu.
-- (La migration d'origine declarait le bareme sous LES DEUX cles ; 100447 a
--  ensuite tranche pour 'maire_adjoint'. Seule la cle survivante est versionnee.)
INSERT INTO public.salaires_civils_declares (cle, categorie, montant)
VALUES ('maire_adjoint', 'poste', 500)
ON CONFLICT (cle) DO UPDATE SET categorie=EXCLUDED.categorie, montant=EXCLUDED.montant;

-- 20260920100447 — ARBITRAGES APPLIQUES : VESTIGES, ALIAS, POSTES ITINERANTS
--
-- §4 VESTIGES. senateur (1200), gouverneur (1500), prefet (900) n'existent pas
--    dans Res Publica. Inventaire fait AVANT suppression : ces trois cles
--    n'apparaissaient nulle part ailleurs que dans le tableau SALAIRES de
--    data.js -- ni dans postes_nommes_regles, ni dans une caisse, ni dans un
--    ordre, ni dans une RPC. Seule trace annexe : avatars.js teste la chaine
--    'prefet' dans un LIBELLE de role pour choisir une illustration, ce qui ne
--    depend pas du bareme. Rien ne casse.
--
-- §5 ALIAS. `maire_adjoint` devient canonique. `adj_maire` n'avait qu'UNE seule
--    occurrence dans tout le depot -- sa propre declaration -- contre 45 pour
--    `maire_adjoint`. Aucune compatibilite transitoire n'est donc necessaire :
--    il n'existait aucun consommateur vivant. Le salaire reste 500 FR, paye par
--    la caisse de la mairie de la ville.
--
-- §3 POSTES ITINERANTS. Secretaire administratif, commercant itinerant,
--    conseiller bancaire, hotesse d'accueil diplomatique : aucun employeur ne
--    les represente. Decision GD : aucun salaire. On les retire du miroir, ce
--    qui fait retomber leur titulaire sur le revenu universel -- il reste un
--    citoyen, il touche ce que touche tout citoyen. Leur role fonctionnel et
--    leurs places sont inchanges.
DELETE FROM public.salaires_civils_declares
 WHERE cle IN ('senateur','gouverneur','prefet','adj_maire',
               'secretaire_nationale','commercant_national','banquier_national','hotesse_ambassade');

-- Le DELETE jumeau sur salaires_caisses ('adj_maire') n'est PAS reproduit :
-- l'insertion correspondante de 095124 ne l'est pas non plus. Effet net nul.

-- Etat final attendu de salaires_civils_declares apres ce fichier (17 lignes,
-- verifie le 20/09/2026) : commissaire 1000, default 150 (universel), depute 1200,
-- docker_psm 220 (emploi), hotelier_montrouge 250 (emploi), juge 1800, maire 800,
-- maire_adjoint 500, min_ae/min_def/min_fin/min_info/min_int/min_just 2800,
-- pm 3500, president 5000, serveur_luthecia 200 (emploi).
