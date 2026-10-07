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
-- IDEMPOTENTE. Rejouable sans effet de bord.
-- AUCUN DROIT A PUBLIC NI A anon sur la fonction creee.
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
  'Quel etablissement chaque poste de direction dirige, ou, et pour quel salaire quotidien. Miroir de DIRECTEUR_USINE_INFO, ENTREPOT_PAR_VILLE et SALAIRE_DIRECTEUR (plateau-justice-economie.js). C''est cette table que lit percevoir_salaire_directeur : ni la ville ni le batiment ni le montant ne viennent plus du navigateur.';

ALTER TABLE public.directions_etablissements ENABLE ROW LEVEL SECURITY;
-- Referentiel d'autorite : lu uniquement par des fonctions SECURITY DEFINER. Meme regime que
-- caisses_autorites et villes.
REVOKE ALL ON TABLE public.directions_etablissements FROM PUBLIC;

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
  'Salaire quotidien d''un poste de direction. Le montant, la ville et le batiment viennent de directions_etablissements, JAMAIS des parametres : p_pays, p_ville, p_batiment, p_souscle et p_montant sont ignores et ne subsistent que pour la compatibilite de deploiement. Versement partiel conserve, marqueur du jour, verrou sur les deux lignes.';

REVOKE ALL ON FUNCTION public.percevoir_salaire_directeur(text, text, text, text, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.percevoir_salaire_directeur(text, text, text, text, text, text, numeric) TO authenticated, service_role;

COMMIT;
