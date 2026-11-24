-- Purge, bloc A, point A.10 (Fred, 24/11/2026) : PNJ guide des nouveaux joueurs. NON APPLIQUÉE. Rejouable. Rien du goulag.
-- Après 20261124100000 (comptes de test), 20261124101000/102000 (calendrier du nouveau venu).
--
-- Deux voix, annoncées comme PNJ dans le chat (badge « PNJ ») et mises en mots par DeepSeek (api/_pnj-guide.js, greffé
-- sur /api/chat?mode=guide : aucune nouvelle fonction Vercel) :
--   a) la journaliste de l'interview (accueil_journalistes : Jodie Moitout en Républia, Vera Pravdina en Sovarka) ;
--   b) un habitant PNJ par ville jouable (pnj_guides_habitants), au marché de sa ville.
-- LE SERVEUR DÉCIDE DE TOUT : qui écrit, quand, quelle piste, quel commerce. DeepSeek ne fait que mettre en mots une piste
-- déjà choisie ; un filtre serveur refuse tout message qui cite un nom de parti ou de joueur (guide_noms_interdits).
--
-- Rythme (guide_reserver) :
--   • seulement pour un personnage du calendrier (créé après la mise en ligne, A.2), pendant les 7 jours qui suivent sa
--     création, après sa première heure de jeu (A.3), et jamais après « Je me débrouille, merci » (guide_arreter) ;
--   • au plus UN message de guide par jour (heure de Paris), les deux voix confondues, et au plus 3 par voix ;
--   • la journaliste au plus tôt le lendemain de l'interview (chemin choisi) ; l'habitant jamais le même jour qu'elle ;
--   • l'écran ne le demande qu'à une connexion, quand aucune fenêtre n'est ouverte ; pas de relance si le joueur se tait.
-- Pistes (guide_pistes) : des TYPES d'activité, un PNJ référent lu dans pnj_referents (motif sur le domaine : les référents
-- ajoutés plus tard y apparaissent d'eux-mêmes), un lieu tenu par un PNJ, ou un commerce de joueur tiré au hasard parmi les
-- commerces ACTIFS qui correspondent au goût (chemin de l'interview) du nouveau : propriétaire connecté dans les 3 derniers
-- jours, stock disponible, jamais un compte de test, jamais deux fois le même pour le même nouveau ; à défaut, le lieu PNJ.
-- Réponses : si le nouveau écrit au PNJ, il répond (même cadre), 5 réponses par jour et par PNJ au plus, hors plafonds.
-- Réglages MJ (accueil_parametres) : guide_jours, guide_max_par_voix, guide_reponses_jour, guide_commerce_actif_jours.

INSERT INTO public.accueil_parametres (cle, valeur, libelle) VALUES
  ('guide_jours', 7, 'PNJ guide : nombre de jours après l''inscription pendant lesquels il peut écrire'),
  ('guide_max_par_voix', 3, 'PNJ guide : messages au plus par voix (journaliste, habitant)'),
  ('guide_reponses_jour', 5, 'PNJ guide : réponses au plus par jour et par PNJ quand le nouveau lui écrit'),
  ('guide_commerce_actif_jours', 3, 'PNJ guide : un commerce est actif si son propriétaire s''est connecté depuis ce nombre de jours')
ON CONFLICT (cle) DO NOTHING;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Les habitants guides (un par ville jouable, au marché de la ville : lieu existant qui a déjà son image)
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pnj_guides_habitants (
  pays text NOT NULL,
  ville text NOT NULL,
  nom text NOT NULL,
  profil text NOT NULL,
  lieu text NOT NULL,
  PRIMARY KEY (pays, ville)
);
ALTER TABLE public.pnj_guides_habitants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pnj_guides_habitants FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.pnj_guides_habitants TO service_role;
INSERT INTO public.pnj_guides_habitants (pays, ville, nom, profil, lieu) VALUES
  ('republic', 'capitale', 'Firmin Badaud', 'guide_firmin_badaud', 'Marché Central de Luthécia'),
  ('republic', 'ville_a', 'Yvonne Bigorneau', 'guide_yvonne_bigorneau', 'Marché de Port-Sainte-Marie'),
  ('republic', 'ville_b', 'Lucien Boulon', 'guide_lucien_boulon', 'Marché de Montrouge'),
  ('soviet', 'capitale', 'Zinaïda Otcheredova', 'guide_zinaida_otcheredova', 'Distribution Collective de Novomirsk'),
  ('soviet', 'ville_a', 'Bair Namsaraev', 'guide_bair_namsaraev', 'Marché de Starovka'),
  ('soviet', 'ville_b', 'Fiodor Medvedkine', 'guide_fiodor_medvedkine', 'Marché de Krasnov')
ON CONFLICT (pays, ville) DO UPDATE SET nom = EXCLUDED.nom, profil = EXCLUDED.profil, lieu = EXCLUDED.lieu;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Les pistes : une seule par message, choisie par le serveur
-- ---------------------------------------------------------------------------------------------------------------
-- critere : le chemin choisi à l'interview (le « goût » du nouveau), ou 'defaut' s'il n'en a pas choisi.
-- type 'referent' : PNJ référent dont le domaine (pnj_referents.domaine) correspond au motif, dans le pays du nouveau ;
-- type 'commerce' : commerce de joueur actif dont un type autorisé figure dans commerce_types ; type 'lieu' : lieu PNJ.
-- Le lieu sert aussi de repli quand aucun référent ou commerce ne correspond.
CREATE TABLE IF NOT EXISTS public.guide_pistes (
  cle text PRIMARY KEY,
  pays text NOT NULL,
  critere text NOT NULL,
  rang integer NOT NULL,
  type text NOT NULL CHECK (type IN ('referent', 'commerce', 'lieu')),
  activite text NOT NULL,
  referent_motif text,
  commerce_types text[],
  lieu text NOT NULL
);
ALTER TABLE public.guide_pistes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guide_pistes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.guide_pistes TO service_role;
INSERT INTO public.guide_pistes (cle, pays, critere, rang, type, activite, referent_motif, commerce_types, lieu) VALUES
  -- RÉPUBLIA
  ('r_pol_1', 'republic', 'politique', 1, 'lieu', 'Intégrer une équipe, un réseau : les partis recrutent, et plus ils ont d''adhérents, plus ils sont puissants.', NULL, NULL, 'la mairie, où la secrétaire explique les démarches'),
  ('r_pol_2', 'republic', 'politique', 2, 'referent', 'Les élections : se présenter, faire campagne, voter.', 'lections|campagne', NULL, 'la mairie'),
  ('r_pol_3', 'republic', 'politique', 3, 'referent', 'Comprendre les institutions : qui décide de quoi dans le pays.', 'institutions|assembl', NULL, 'l''Assemblée nationale'),
  ('r_aff_1', 'republic', 'affaires', 1, 'referent', 'Monter une affaire : louer un local, ouvrir un commerce, bâtir.', 'immobilier|entrepreneuriat|centre d''affaires', NULL, 'le centre d''affaires'),
  ('r_aff_2', 'republic', 'affaires', 2, 'commerce', 'Voir comment tourne un commerce qui marche, et ce qu''on y vend.', NULL, ARRAY['commerce-non-alimentaire','electronique-informatique','vetements','commerce-alimentaire','bar-restauration'], 'le marché'),
  ('r_aff_3', 'republic', 'affaires', 3, 'referent', 'Trouver du travail ou recruter : les postes à pourvoir et les annonces.', 'emploi', NULL, 'le Bureau National de l''Emploi'),
  ('r_inf_1', 'republic', 'influence', 1, 'referent', 'Peser sur l''opinion : la presse, la communication, les sondages.', 'information|communication|presse', NULL, 'la rédaction du journal'),
  ('r_inf_2', 'republic', 'influence', 2, 'lieu', 'Écouter avant de parler : les rumeurs circulent là où tout le monde passe.', NULL, NULL, 'le marché'),
  ('r_inf_3', 'republic', 'influence', 3, 'referent', 'Les réceptions, le protocole et les gens qui comptent.', 'protocole|diplomatie', NULL, 'le palais présidentiel'),
  ('r_cri_1', 'republic', 'crime', 1, 'referent', 'Le milieu a ses règles : mieux vaut les apprendre de quelqu''un qui les connaît.', 'criminel', NULL, 'la place du Formulaire de la Liberté'),
  ('r_cri_2', 'republic', 'crime', 2, 'referent', 'Connaître la police avant qu''elle ne vous connaisse.', 'police', NULL, 'le commissariat'),
  ('r_cri_3', 'republic', 'crime', 3, 'lieu', 'Les bonnes affaires discrètes se font loin des regards.', NULL, NULL, 'l''armurerie'),
  ('r_uni_1', 'republic', 'uniforme', 1, 'referent', 'S''engager dans l''armée : formation, troupe, grades.', 'engagement|formation', NULL, 'la caserne'),
  ('r_uni_2', 'republic', 'uniforme', 2, 'referent', 'Entrer dans la police : enquêtes, ordre public.', 'police', NULL, 'le commissariat'),
  ('r_uni_3', 'republic', 'uniforme', 3, 'referent', 'Le commandement : compagnies, stratégie, opérations.', 'commandement|strat', NULL, 'la caserne'),
  ('r_bel_1', 'republic', 'belle_vie', 1, 'commerce', 'Profiter de la ville : bonnes tables, belles boutiques.', NULL, ARRAY['bar-restauration','commerce-alimentaire','vetements'], 'le marché'),
  ('r_bel_2', 'republic', 'belle_vie', 2, 'referent', 'Le football et la vie du club, au stade.', 'club', NULL, 'le stade'),
  ('r_bel_3', 'republic', 'belle_vie', 3, 'lieu', 'Une chambre, un bon repas et du monde à rencontrer.', NULL, NULL, 'l''hôtel de la ville'),
  ('r_def_1', 'republic', 'defaut', 1, 'referent', 'Trouver un premier travail pour se lancer.', 'emploi', NULL, 'le Bureau National de l''Emploi'),
  ('r_def_2', 'republic', 'defaut', 2, 'lieu', 'Intégrer une équipe, un réseau : les partis recrutent, et plus ils ont d''adhérents, plus ils sont puissants.', NULL, NULL, 'la mairie, où la secrétaire explique les démarches'),
  ('r_def_3', 'republic', 'defaut', 3, 'commerce', 'Faire un tour dans les commerces de la ville.', NULL, ARRAY['bar-restauration','commerce-alimentaire','vetements','commerce-non-alimentaire','electronique-informatique'], 'le marché'),
  -- SOVARKA
  ('s_pol_1', 'soviet', 'politique', 1, 'referent', 'Intégrer une équipe, un réseau : les partis recrutent, et plus ils ont d''adhérents, plus ils sont puissants.', 'partis', NULL, 'la salle des partis de la mairie'),
  ('s_pol_2', 'soviet', 'politique', 2, 'referent', 'Les élections de Sovarka : candidatures, campagne et vote.', 'lections', NULL, 'la mairie'),
  ('s_pol_3', 'soviet', 'politique', 3, 'referent', 'Les démarches de la mairie : état civil, commerces, bons d''État.', 'municipales|mairie', NULL, 'la mairie'),
  ('s_aff_1', 'soviet', 'affaires', 1, 'referent', 'Louer un local et produire pour le Plan.', 'location|entrep', NULL, 'le centre artisanal'),
  ('s_aff_2', 'soviet', 'affaires', 2, 'commerce', 'Voir comment tourne un commerce qui marche, et ce qu''on y vend.', NULL, ARRAY['commerce-non-alimentaire','electronique-informatique','vetements','commerce-alimentaire','bar-restauration'], 'le marché'),
  ('s_aff_3', 'soviet', 'affaires', 3, 'referent', 'Le commerce extérieur, le port et les douanes.', 'commerce ext|douanes', NULL, 'le port'),
  ('s_inf_1', 'soviet', 'influence', 1, 'referent', 'La presse : ce qui s''imprime et ce qui ne s''imprime pas.', 'presse', NULL, 'l''agence de La Voix de Sovarka'),
  ('s_inf_2', 'soviet', 'influence', 2, 'lieu', 'Écouter avant de parler : les rumeurs circulent dans les files d''attente.', NULL, NULL, 'le marché'),
  ('s_inf_3', 'soviet', 'influence', 3, 'referent', 'La mairie et ceux qui la font tourner.', 'maire', NULL, 'la mairie'),
  ('s_cri_1', 'soviet', 'crime', 1, 'lieu', 'Les affaires discrètes se règlent au comptoir, à voix basse.', NULL, NULL, 'le bar de la ville'),
  ('s_cri_2', 'soviet', 'crime', 2, 'referent', 'Connaître la milice avant qu''elle ne vous connaisse.', 'police', NULL, 'le commissariat'),
  ('s_cri_3', 'soviet', 'crime', 3, 'referent', 'La justice du peuple, et comment elle juge.', 'justice', NULL, 'le tribunal'),
  ('s_uni_1', 'soviet', 'uniforme', 1, 'lieu', 'Servir la Patrie sous l''uniforme : l''armée recrute à la caserne.', NULL, NULL, 'la caserne'),
  ('s_uni_2', 'soviet', 'uniforme', 2, 'referent', 'Entrer dans la milice : ordre public et enquêtes.', 'police', NULL, 'le commissariat'),
  ('s_uni_3', 'soviet', 'uniforme', 3, 'referent', 'Les douanes : expéditions, contrôles, déclarations.', 'douanes', NULL, 'le port'),
  ('s_bel_1', 'soviet', 'belle_vie', 1, 'commerce', 'Profiter de la ville : bonnes tables, belles boutiques.', NULL, ARRAY['bar-restauration','commerce-alimentaire','vetements'], 'le marché'),
  ('s_bel_2', 'soviet', 'belle_vie', 2, 'referent', 'Le football et la ferveur du stade.', 'football', NULL, 'le stade'),
  ('s_bel_3', 'soviet', 'belle_vie', 3, 'referent', 'Le kolkhoze : travail en commun et produits de la terre.', 'kolkhoze', NULL, 'le kolkhoze'),
  ('s_def_1', 'soviet', 'defaut', 1, 'referent', 'Les démarches de la mairie pour bien s''installer.', 'municipales|mairie', NULL, 'la mairie'),
  ('s_def_2', 'soviet', 'defaut', 2, 'referent', 'Intégrer une équipe, un réseau : les partis recrutent, et plus ils ont d''adhérents, plus ils sont puissants.', 'partis', NULL, 'la salle des partis de la mairie'),
  ('s_def_3', 'soviet', 'defaut', 3, 'referent', 'Le kolkhoze : travail en commun et produits de la terre.', 'kolkhoze', NULL, 'le kolkhoze')
ON CONFLICT (cle) DO UPDATE SET pays = EXCLUDED.pays, critere = EXCLUDED.critere, rang = EXCLUDED.rang, type = EXCLUDED.type,
  activite = EXCLUDED.activite, referent_motif = EXCLUDED.referent_motif, commerce_types = EXCLUDED.commerce_types, lieu = EXCLUDED.lieu;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. État du guide par personnage, messages et réponses
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.guide_etat (
  personnage text PRIMARY KEY,
  arret_le timestamptz,
  nb_journaliste integer NOT NULL DEFAULT 0,
  nb_habitant integer NOT NULL DEFAULT 0,
  dernier_jour date,
  dernier_journaliste_jour date,
  pistes text[] NOT NULL DEFAULT '{}',
  commerces text[] NOT NULL DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS public.guide_messages (
  id bigserial PRIMARY KEY,
  personnage text NOT NULL,
  voix text NOT NULL CHECK (voix IN ('journaliste', 'habitant')),
  pnj text NOT NULL,
  profil text NOT NULL,
  piste jsonb NOT NULL,
  jour date NOT NULL,
  statut text NOT NULL DEFAULT 'reserve' CHECK (statut IN ('reserve', 'publie')),
  texte text,
  cree_le timestamptz NOT NULL DEFAULT now(),
  publie_le timestamptz
);
CREATE INDEX IF NOT EXISTS guide_messages_perso_idx ON public.guide_messages (personnage, jour);
CREATE TABLE IF NOT EXISTS public.guide_reponses (
  personnage text NOT NULL,
  pnj text NOT NULL,
  jour date NOT NULL,
  n integer NOT NULL DEFAULT 0,
  PRIMARY KEY (personnage, pnj, jour)
);
ALTER TABLE public.guide_etat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guide_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guide_reponses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guide_etat, public.guide_messages, public.guide_reponses FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.guide_etat, public.guide_messages, public.guide_reponses TO service_role;

CREATE OR REPLACE FUNCTION public.guide_jour_interne() RETURNS date LANGUAGE sql STABLE
SET search_path TO 'public', 'pg_temp' AS $$ SELECT (now() AT TIME ZONE 'Europe/Paris')::date $$;

-- Le guide peut-il encore écrire à ce personnage ? (calendrier, 7 jours, première heure, arrêt). Sans effet.
CREATE OR REPLACE FUNCTION public.guide_eligible_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.accueil_personnages; g public.guide_etat; v_cree timestamptz;
BEGIN
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = p_nom;
  IF NOT FOUND OR NOT r.calendrier THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_calendrier'); END IF;
  SELECT * INTO g FROM public.guide_etat WHERE personnage = p_nom;
  IF g.arret_le IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'arrete'); END IF;
  SELECT created_at INTO v_cree FROM public.personnages_donnees WHERE name = p_nom;
  IF v_cree IS NULL OR now() - v_cree > make_interval(days => public.accueil_param('guide_jours', 7)::integer) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'periode_terminee');
  END IF;
  IF r.heure_finie_le IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'premiere_heure'); END IF;
  RETURN jsonb_build_object('ok', true); /* pnj_guide_v1 */
END $function$;

-- Le commerce actif tiré au hasard pour ce nouveau (ou NULL). Comptes de test et commerces inactifs exclus.
CREATE OR REPLACE FUNCTION public.guide_commerce_tirer_interne(p_nom text, p_pays text, p_types text[], p_deja text[])
 RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('id', e.id, 'enseigne', e.data->>'enseigne', 'ville', e.data->'implantation'->>'city',
           'batiment', e.data->'implantation'->>'buildingId')
    FROM public.entreprises e
   WHERE e.data->>'type' = 'fonds_commerce' AND coalesce(e.data->>'statut', 'actif') = 'actif'
     AND e.data->'implantation'->>'country' = p_pays
     AND coalesce(nullif(btrim(e.data->>'enseigne'), ''), NULL) IS NOT NULL
     AND jsonb_typeof(e.data->'typesAutorises') = 'array'
     AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(e.data->'typesAutorises') t WHERE t = ANY (p_types))
     AND e.data->>'proprietaire' IS DISTINCT FROM p_nom
     AND NOT public.est_compte_test(e.data->>'proprietaire')
     -- L'enseigne ne doit pas nommer son propriétaire (le guide ne nomme jamais un joueur).
     AND position(lower(e.data->>'proprietaire') IN lower(e.data->>'enseigne')) = 0
     AND NOT (e.id = ANY (coalesce(p_deja, '{}')))
     -- Actif : propriétaire connecté dans les derniers jours (battement de présence) ET stock disponible.
     AND EXISTS (SELECT 1 FROM public.presences pr WHERE pr.name = e.data->>'proprietaire'
                  AND pr.updated_at > now() - make_interval(days => public.accueil_param('guide_commerce_actif_jours', 3)::integer))
     AND (SELECT coalesce(sum(CASE WHEN jsonb_typeof(s.value) = 'number' THEN (s.value)::text::numeric ELSE 0 END), 0)
            FROM (SELECT value FROM jsonb_each(CASE WHEN jsonb_typeof(e.data->'stockReferences') = 'object' THEN e.data->'stockReferences' ELSE '{}'::jsonb END)
                  UNION ALL
                  SELECT value FROM jsonb_each(CASE WHEN jsonb_typeof(e.data->'stockProduits') = 'object' THEN e.data->'stockProduits' ELSE '{}'::jsonb END)) s) > 0
   ORDER BY random() LIMIT 1 /* pnj_guide_v1 */
$function$;

-- Réserve le message de guide du jour (ou rend celui déjà réservé, pour une nouvelle tentative de mise en mots).
CREATE OR REPLACE FUNCTION public.guide_reserver()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_el jsonb; r public.accueil_personnages; g public.guide_etat; d record;
        v_jour date := public.guide_jour_interne(); v_max integer := public.accueil_param('guide_max_par_voix', 3)::integer;
        v_interview date; v_j_ok boolean; v_h_ok boolean; v_voix text; v_pnj text; v_profil text; h record; jn record;
        v_critere text; p record; v_piste jsonb; v_ref text; v_com jsonb; m public.guide_messages; v_monde jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_el := public.guide_eligible_interne(a);
  IF (v_el->>'ok')::boolean IS NOT TRUE THEN RETURN v_el; END IF;
  -- Déjà réservé aujourd'hui (mise en mots interrompue) : on le rend tel quel.
  SELECT * INTO m FROM public.guide_messages WHERE personnage = a AND jour = v_jour ORDER BY id DESC LIMIT 1;
  IF FOUND AND m.statut = 'publie' THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_ecrit_aujourdhui'); END IF;
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = a;
  SELECT country, current_city, career, archetype, stats INTO d FROM public.personnages_donnees WHERE name = a;
  INSERT INTO public.guide_etat (personnage) VALUES (a) ON CONFLICT (personnage) DO NOTHING;
  SELECT * INTO g FROM public.guide_etat WHERE personnage = a FOR UPDATE;
  IF g.dernier_jour = v_jour THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_ecrit_aujourdhui'); END IF;
  IF m.id IS NULL THEN
    -- Qui écrit ? La journaliste au plus tôt le lendemain de l'interview ; l'habitant de la ville où se trouve le nouveau.
    v_interview := (coalesce(r.publiee_le, r.chemin_choisi_le) AT TIME ZONE 'Europe/Paris')::date;
    SELECT * INTO jn FROM public.accueil_journalistes WHERE pays = coalesce(r.pays, d.country);
    SELECT * INTO h FROM public.pnj_guides_habitants WHERE pays = d.country AND ville = d.current_city;
    v_j_ok := g.nb_journaliste < v_max AND jn.journaliste IS NOT NULL AND v_interview IS NOT NULL AND v_interview < v_jour;
    v_h_ok := g.nb_habitant < v_max AND h.nom IS NOT NULL AND g.dernier_journaliste_jour IS DISTINCT FROM v_jour;
    IF v_j_ok AND (NOT v_h_ok OR g.nb_journaliste <= g.nb_habitant) THEN
      v_voix := 'journaliste'; v_pnj := jn.journaliste;
      v_profil := CASE jn.journaliste WHEN 'Vera Pravdina' THEN 'vera_pravdina' ELSE 'jodie_moitout' END;
    ELSIF v_h_ok THEN
      v_voix := 'habitant'; v_pnj := h.nom; v_profil := h.profil;
    ELSE
      RETURN jsonb_build_object('ok', false, 'raison', 'personne_n_ecrit');
    END IF;
    -- Quelle piste ? Celle du goût (chemin) du nouveau, la première pas encore donnée ; sinon les pistes par défaut.
    v_critere := coalesce(r.chemin, 'defaut');
    SELECT * INTO p FROM public.guide_pistes WHERE pays = d.country AND critere IN (v_critere, 'defaut') AND NOT (cle = ANY (g.pistes))
     ORDER BY (critere = v_critere) DESC, rang LIMIT 1;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'plus_de_piste'); END IF;
    v_piste := jsonb_build_object('cle', p.cle, 'type', p.type, 'activite', p.activite, 'lieu', p.lieu);
    IF p.type = 'referent' THEN
      SELECT referent_id INTO v_ref FROM public.pnj_referents WHERE pays = d.country AND domaine ~* p.referent_motif ORDER BY random() LIMIT 1;
      IF v_ref IS NOT NULL THEN v_piste := v_piste || jsonb_build_object('referent', v_ref);
      ELSE v_piste := v_piste || jsonb_build_object('type', 'lieu'); END IF;
    ELSIF p.type = 'commerce' THEN
      v_com := public.guide_commerce_tirer_interne(a, d.country, p.commerce_types, g.commerces);
      IF v_com IS NOT NULL THEN v_piste := v_piste || jsonb_build_object('commerce', v_com);
      ELSE v_piste := v_piste || jsonb_build_object('type', 'lieu'); END IF;   -- aucun commerce actif : un lieu tenu par un PNJ
    END IF;
    INSERT INTO public.guide_messages (personnage, voix, pnj, profil, piste, jour)
    VALUES (a, v_voix, v_pnj, v_profil, v_piste, v_jour) RETURNING * INTO m;
  END IF;
  -- État réel du monde, sans aucun nom de parti ni de joueur.
  v_monde := jsonb_build_object(
    'elections_en_cours', (SELECT count(*) FROM public.cycles_electoraux c WHERE c.country = d.country AND c.data IS JSON OBJECT
                             AND c.data::jsonb->>'phase' IN ('candidatures', 'campagne', 'vote', 'second_tour', 'vote2')),
    'partis', (SELECT count(*) FROM public.organisations o WHERE o.data IS JSON OBJECT AND o.data::jsonb->>'type' = 'politique'
                 AND coalesce(o.data::jsonb->>'country', o.country_origine) = d.country));
  RETURN jsonb_build_object('ok', true, 'id', m.id, 'voix', m.voix, 'pnj', m.pnj, 'profil', m.profil, 'piste', m.piste,
    'personnage', a, 'pays', d.country, 'ville', d.current_city,
    'nouveau', jsonb_build_object('carriere', d.career, 'archetype', d.archetype, 'caracteristiques', d.stats,
      'chemin', r.chemin, 'mot', r.mot),
    'monde', v_monde); /* pnj_guide_v1 */
END $function$;

-- Le serveur Vercel publie le message mis en mots (clé de service seulement). Échappement du HTML ici.
CREATE OR REPLACE FUNCTION public.guide_publier_service(p_id bigint, p_texte text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m public.guide_messages; v_txt text; v_conv text; v_jour date := public.guide_jour_interne();
BEGIN
  SELECT * INTO m FROM public.guide_messages WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'inconnu'); END IF;
  IF m.statut = 'publie' THEN RETURN jsonb_build_object('ok', true, 'deja', true); END IF;
  IF (public.guide_eligible_interne(m.personnage)->>'ok')::boolean IS NOT TRUE THEN RETURN jsonb_build_object('ok', false, 'raison', 'plus_eligible'); END IF;
  v_txt := left(btrim(coalesce(p_texte, '')), 600);
  IF v_txt = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_vide'); END IF;
  v_txt := replace(replace(replace(v_txt, '&', '&amp;'), '<', '&lt;'), '>', '&gt;');
  v_conv := 'pnj:' || m.pnj || '__' || m.personnage;
  INSERT INTO public.messages_chat (id, conversation_id, auteur, message, salon, created_at)
  VALUES ('guide-' || m.id, v_conv, 'pnj:' || m.pnj, v_txt, false, now()) ON CONFLICT DO NOTHING;
  UPDATE public.guide_messages SET statut = 'publie', texte = v_txt, publie_le = now() WHERE id = m.id;
  UPDATE public.guide_etat SET dernier_jour = v_jour,
         nb_journaliste = nb_journaliste + CASE WHEN m.voix = 'journaliste' THEN 1 ELSE 0 END,
         nb_habitant = nb_habitant + CASE WHEN m.voix = 'habitant' THEN 1 ELSE 0 END,
         dernier_journaliste_jour = CASE WHEN m.voix = 'journaliste' THEN v_jour ELSE dernier_journaliste_jour END,
         pistes = pistes || (m.piste->>'cle'),
         commerces = CASE WHEN m.piste ? 'commerce' THEN commerces || (m.piste->'commerce'->>'id') ELSE commerces END
   WHERE personnage = m.personnage;
  RETURN jsonb_build_object('ok', true, 'conversation', v_conv); /* pnj_guide_v1 */
END $function$;

-- « Je me débrouille, merci » : arrête définitivement les deux voix pour ce joueur.
CREATE OR REPLACE FUNCTION public.guide_arreter()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  INSERT INTO public.guide_etat (personnage, arret_le) VALUES (a, now())
  ON CONFLICT (personnage) DO UPDATE SET arret_le = coalesce(public.guide_etat.arret_le, now());
  DELETE FROM public.guide_messages WHERE personnage = a AND statut = 'reserve';
  RETURN jsonb_build_object('ok', true, 'arrete', true); /* pnj_guide_v1 */
END $function$;

-- L'écran demande s'il y a lieu d'appeler le guide (évite un appel inutile au serveur Vercel).
CREATE OR REPLACE FUNCTION public.guide_etat_lire()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_el jsonb; g public.guide_etat;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_el := public.guide_eligible_interne(a);
  SELECT * INTO g FROM public.guide_etat WHERE personnage = a;
  RETURN jsonb_build_object('ok', true, 'arrete', g.arret_le IS NOT NULL,
    'a_ecrire', (v_el->>'ok')::boolean IS TRUE AND g.dernier_jour IS DISTINCT FROM public.guide_jour_interne()); /* pnj_guide_v1 */
END $function$;

-- Le nouveau écrit à un PNJ guide : son message est posé, et l'autorisation de répondre est donnée (5 par jour et par PNJ).
CREATE OR REPLACE FUNCTION public.guide_reponse_autoriser(p_pnj text, p_message text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); v_el jsonb; m public.guide_messages; v_jour date := public.guide_jour_interne();
        v_n integer; v_msg text := left(btrim(coalesce(p_message, '')), 1000); v_conv text; v_hist jsonb; d record;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_msg = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'message_vide'); END IF;
  v_el := public.guide_eligible_interne(a);
  IF (v_el->>'ok')::boolean IS NOT TRUE THEN RETURN v_el; END IF;
  -- On ne répond que dans une conversation que le guide a ouverte.
  SELECT * INTO m FROM public.guide_messages WHERE personnage = a AND pnj = p_pnj AND statut = 'publie' ORDER BY id DESC LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'conversation_inconnue'); END IF;
  INSERT INTO public.guide_reponses (personnage, pnj, jour, n) VALUES (a, p_pnj, v_jour, 0) ON CONFLICT DO NOTHING;
  SELECT n INTO v_n FROM public.guide_reponses WHERE personnage = a AND pnj = p_pnj AND jour = v_jour FOR UPDATE;
  IF v_n >= public.accueil_param('guide_reponses_jour', 5) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reponses_epuisees'); END IF;
  UPDATE public.guide_reponses SET n = n + 1 WHERE personnage = a AND pnj = p_pnj AND jour = v_jour;
  v_conv := 'pnj:' || p_pnj || '__' || a;
  INSERT INTO public.messages_chat (id, conversation_id, auteur, message, salon, created_at)
  VALUES ('msg-' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint || '-' || substr(md5(random()::text), 1, 5), v_conv, a,
          replace(replace(replace(v_msg, '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), false, now());
  SELECT coalesce(jsonb_agg(jsonb_build_object('pnj', x.auteur LIKE 'pnj:%', 'texte', x.message) ORDER BY x.created_at), '[]'::jsonb) INTO v_hist
    FROM (SELECT * FROM public.messages_chat WHERE conversation_id = v_conv ORDER BY created_at DESC LIMIT 8) x;
  SELECT country, current_city, career, archetype INTO d FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'personnage', a, 'pnj', m.pnj, 'profil', m.profil, 'voix', m.voix, 'pays', d.country,
    'ville', d.current_city, 'piste', m.piste, 'historique', v_hist,
    'nouveau', jsonb_build_object('carriere', d.career, 'archetype', d.archetype)); /* pnj_guide_v1 */
END $function$;

-- La réponse du PNJ, mise en mots et filtrée par le serveur Vercel (clé de service seulement).
CREATE OR REPLACE FUNCTION public.guide_reponse_publier_service(p_personnage text, p_pnj text, p_texte text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_txt text := left(btrim(coalesce(p_texte, '')), 600); v_conv text := 'pnj:' || p_pnj || '__' || p_personnage;
BEGIN
  IF v_txt = '' OR NOT EXISTS (SELECT 1 FROM public.guide_messages WHERE personnage = p_personnage AND pnj = p_pnj AND statut = 'publie') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'refuse');
  END IF;
  INSERT INTO public.messages_chat (id, conversation_id, auteur, message, salon, created_at)
  VALUES ('guiderep-' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint || '-' || substr(md5(random()::text), 1, 5), v_conv, 'pnj:' || p_pnj,
          replace(replace(replace(v_txt, '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), false, now());
  RETURN jsonb_build_object('ok', true); /* pnj_guide_v1 */
END $function$;

-- Noms que le guide ne doit jamais écrire : partis et joueurs (filtre serveur, clé de service seulement).
CREATE OR REPLACE FUNCTION public.guide_noms_interdits()
 RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object(
    'partis', (SELECT coalesce(jsonb_agg(DISTINCT n), '[]'::jsonb) FROM (
                SELECT nullif(btrim(coalesce(o.data::jsonb->>'nom', o.data::jsonb->>'name')), '') n FROM public.organisations o
                 WHERE o.data IS JSON OBJECT AND o.data::jsonb->>'type' = 'politique') x WHERE n IS NOT NULL),
    'joueurs', (SELECT coalesce(jsonb_agg(DISTINCT name), '[]'::jsonb) FROM public.personnages_donnees)) /* pnj_guide_v1 */
$function$;

REVOKE ALL ON FUNCTION public.guide_jour_interne(), public.guide_eligible_interne(text),
  public.guide_commerce_tirer_interne(text, text, text[], text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guide_publier_service(bigint, text), public.guide_reponse_publier_service(text, text, text),
  public.guide_noms_interdits() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.guide_publier_service(bigint, text), public.guide_reponse_publier_service(text, text, text),
  public.guide_noms_interdits() TO service_role;
REVOKE ALL ON FUNCTION public.guide_reserver(), public.guide_arreter(), public.guide_etat_lire(),
  public.guide_reponse_autoriser(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.guide_reserver(), public.guide_arreter(), public.guide_etat_lire(),
  public.guide_reponse_autoriser(text, text) TO authenticated;
