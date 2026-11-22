-- Accueil des nouveaux joueurs : interview à la première connexion, six chemins, parcours de trois étapes dans
-- « Mes objectifs », bulle des PA au premier ordre payé (Claude, 23/11/2026).
-- Décisions de Fred du 22/11/2026 (soir) : GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md, partie D, points 23 à 26.
--
-- Le serveur décide de tout. Écrite à partir des définitions de PRODUCTION (pg_get_functiondef du 22/11/2026, projet
-- jxpwoosmmhohoihxpbuc). Rejouable, sans BEGIN/COMMIT. Rien du goulag.
--
--  • accueil_parametres (cle, valeur, libelle) + accueil_param(cle, défaut) ; admin_accueil_parametres_lire /
--    admin_accueil_parametre_fixer (MJ, journalisé dans admin_journal) : ouverture automatique, longueur du mot du
--    joueur, bulle des PA.
--  • accueil_journalistes (pays → journaliste, journal, question) : Jodie Moitout en Républia, Vera Pravdina (nouvelle
--    PNJ, « La Voix de Sovarka ») en Sovarka. Un pays sans ligne n'a pas d'interview d'accueil.
--  • accueil_chemins (6 chemins par pays) et accueil_etapes (3 étapes par chemin et par pays, 12 parcours) : chaque
--    étape nomme le lieu et l'ordre existant (fn de data.js) ; la troisième confie le joueur au PNJ référent.
--  • accueil_personnages : état serveur par personnage (interview, chemin, mot, étapes faites, bulle des PA). Ligne créée
--    à la première lecture (accueil_etat, à la connexion) : AUCUNE donnée de joueur n'est écrite par la migration, et un
--    personnage qui a déjà une interview publiée ou un portrait publié est reconnu « déjà interviewé » (rien ne change
--    pour lui). Tous les autres reçoivent l'interview à leur prochaine connexion (point 25).
--  • interviews_jodie : deux colonnes (accueil, journaliste) ; les interviews existantes restent telles quelles
--    (accueil = false par défaut).
--  • RPC du navigateur (personnage du compte connecté, mon_personnage()) : accueil_etat, accueil_interview_vue,
--    accueil_choisir_chemin, accueil_ignorer, accueil_etape_valider, accueil_bulle_pa_signaler (bulle des PA
--    quand l'ordre a été payé par une commande serveur propre : le serveur garde « une seule fois »).
--  • accueil_ordre_paye_interne(acteur, fn, pa) : appelée par payer_ordre_interne après un prélèvement réussi
--    (remplacement contrôlé, marque accueil_ordre_paye_v1). Valide l'étape dont l'ordre vient d'être payé et, au premier
--    ordre qui coûte des PA, mémorise la bulle et prévient le navigateur (personnage_evenements, clé accueil_bulle_pa).
--    Ne lève jamais d'erreur : un incident d'accueil ne peut pas faire échouer un paiement.
-- Banc : outils/bancs/banc-accueil-interview-pglite-20261123.cjs.

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Paramètres (réglables par un MJ, journalisés)
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.accueil_parametres (
  cle text PRIMARY KEY,
  valeur numeric NOT NULL,
  libelle text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid
);
ALTER TABLE public.accueil_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.accueil_parametres FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.accueil_parametres TO service_role;
INSERT INTO public.accueil_parametres (cle, valeur, libelle) VALUES
  ('interview_ouverture_auto', 1, 'Interview d''accueil ouverte d''elle-même à la connexion (1 = oui, 0 = seulement depuis Mes objectifs)'),
  ('mot_longueur_max', 280, 'Longueur maximale du mot libre du joueur dans l''interview (caractères)'),
  ('bulle_pa_active', 1, 'Bulle d''explication des PA au premier ordre qui en coûte (1 = oui, 0 = non)'),
  ('bulle_pa_max', 20, 'Plus forte dépense de PA acceptée d''un seul ordre pour la bulle signalée par le navigateur')
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.accueil_param(p_cle text, p_defaut numeric)
 RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce((SELECT valeur FROM public.accueil_parametres WHERE cle = p_cle), p_defaut) /* accueil_interview_v1 */ $function$;

CREATE OR REPLACE FUNCTION public.admin_accueil_parametres_lire()
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true, 'parametres', (SELECT coalesce(jsonb_agg(jsonb_build_object('cle', cle, 'valeur', valeur,
    'libelle', libelle, 'maj', updated_at) ORDER BY cle), '[]'::jsonb) FROM public.accueil_parametres)); /* accueil_interview_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.admin_accueil_parametre_fixer(p_cle text, p_valeur numeric)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_avant numeric;
BEGIN
  PERFORM public.admin_exiger();
  IF p_valeur IS NULL OR p_valeur < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide'); END IF;
  SELECT valeur INTO v_avant FROM public.accueil_parametres WHERE cle = p_cle FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametre_inconnu'); END IF;
  UPDATE public.accueil_parametres SET valeur = p_valeur, updated_at = now(), updated_by = auth.uid() WHERE cle = p_cle;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'accueil_parametre_fixer', jsonb_build_object('cle', p_cle, 'valeur', p_valeur), jsonb_build_object('avant', v_avant), true);
  RETURN jsonb_build_object('ok', true, 'cle', p_cle, 'avant', v_avant, 'valeur', p_valeur); /* accueil_interview_v1 */
END $function$;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Journalistes, chemins et étapes (données de jeu, rejouables : la migration les remet à jour)
-- ---------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.accueil_journalistes (
  pays text PRIMARY KEY,
  journaliste text NOT NULL,
  journal text NOT NULL,
  question text NOT NULL
);
ALTER TABLE public.accueil_journalistes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.accueil_journalistes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.accueil_journalistes TO service_role;
INSERT INTO public.accueil_journalistes (pays, journaliste, journal, question) VALUES
  ('republic', 'Jodie Moitout', 'L''Autruche Entravée',
   'Bienvenue parmi nous ! Un nouveau visage, ça ne m''échappe jamais longtemps. Alors, dites-moi : quel chemin comptez-vous prendre ici ?'),
  ('soviet', 'Vera Pravdina', 'La Voix de Sovarka',
   'Bienvenue, camarade. Le Parti aime connaître ses nouveaux citoyens. Dites aux lecteurs de La Voix de Sovarka quelle voie vous comptez suivre au service de la Patrie.')
ON CONFLICT (pays) DO UPDATE SET journaliste = EXCLUDED.journaliste, journal = EXCLUDED.journal, question = EXCLUDED.question;

CREATE TABLE IF NOT EXISTS public.accueil_chemins (
  pays text NOT NULL,
  chemin text NOT NULL CHECK (chemin IN ('politique', 'affaires', 'influence', 'crime', 'uniforme', 'belle_vie')),
  rang integer NOT NULL,
  libelle text NOT NULL,
  PRIMARY KEY (pays, chemin)
);
ALTER TABLE public.accueil_chemins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.accueil_chemins FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.accueil_chemins TO service_role;
INSERT INTO public.accueil_chemins (pays, chemin, rang, libelle)
SELECT p.pays, c.chemin, c.rang, c.libelle
  FROM (VALUES ('republic'), ('soviet')) p(pays)
 CROSS JOIN (VALUES ('politique', 1, 'La politique'), ('affaires', 2, 'Les affaires'),
                    ('influence', 3, 'L''intrigue et l''influence'), ('crime', 4, 'Le crime'),
                    ('uniforme', 5, 'L''uniforme (armée ou police)'), ('belle_vie', 6, 'La belle vie')) c(chemin, rang, libelle)
ON CONFLICT (pays, chemin) DO UPDATE SET rang = EXCLUDED.rang, libelle = EXCLUDED.libelle;

-- validation : 'ordre' = ordre payant : l'étape se coche d'elle-même quand le paiement commun des ordres
-- (payer_ordre_interne) voit passer cet ordre ; 'manuelle' = ordre gratuit ou rencontre d'un PNJ.
-- Dans les deux cas le joueur peut cocher « J'ai fait cette étape » (enregistré au serveur) : plusieurs ordres payants
-- passent par leur propre commande serveur et non par payer_ordre_interne, la coche automatique n'est donc pas garantie.
CREATE TABLE IF NOT EXISTS public.accueil_etapes (
  pays text NOT NULL,
  chemin text NOT NULL,
  n integer NOT NULL CHECK (n BETWEEN 1 AND 3),
  texte text NOT NULL,
  lieu text NOT NULL,
  fn text,
  validation text NOT NULL CHECK (validation IN ('ordre', 'manuelle')),
  pnj text,
  PRIMARY KEY (pays, chemin, n),
  FOREIGN KEY (pays, chemin) REFERENCES public.accueil_chemins (pays, chemin),
  CHECK (validation = 'manuelle' OR fn IS NOT NULL)
);
ALTER TABLE public.accueil_etapes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.accueil_etapes FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.accueil_etapes TO service_role;
INSERT INTO public.accueil_etapes (pays, chemin, n, texte, lieu, fn, validation, pnj) VALUES
  -- RÉPUBLIA (Luthécia, sauf la caserne)
  ('republic', 'politique', 1, 'Consultez le calendrier électoral (ordre « Calendrier électoral »).', 'Luthécia, Hôtel de Ville, Hall d''accueil', 'calendrier_elections', 'manuelle', NULL),
  ('republic', 'politique', 2, 'Postulez à un premier poste (ordre « Postuler à un poste »).', 'Luthécia, Palais du Gouvernement, Hall d''entrée', 'postuler', 'ordre', NULL),
  ('republic', 'politique', 3, 'Allez voir Jean-Lou Zeure, référent des élections : dites-lui que vous voulez faire de la politique.', 'Luthécia, Bureau National de l''Emploi, Accueil', NULL, 'manuelle', 'Jean-Lou Zeure'),
  ('republic', 'affaires', 1, 'Ouvrez votre compte à la banque (ordre « Gérer mon compte / mes placements »).', 'Luthécia, Banque Nationale, Accueil', 'gerer_finances', 'manuelle', NULL),
  ('republic', 'affaires', 2, 'Louez un premier local pour votre commerce (ordre « Louer ce local »).', 'Luthécia, Centre Commercial, Cave / Réserve (ou une autre pièce à louer)', 'louer_local', 'ordre', NULL),
  ('republic', 'affaires', 3, 'Allez voir Marc Hantile, référent des affaires : présentez-lui votre projet.', 'Luthécia, Hôtel-Restaurant La Républia, Bar', NULL, 'manuelle', 'Marc Hantile'),
  ('republic', 'influence', 1, 'Écoutez ce qui se dit aux tables (ordre « Écouter les tables »).', 'Luthécia, Hôtel-Restaurant La Républia, Salle du Restaurant', 'ecouter_rumeurs', 'manuelle', NULL),
  ('republic', 'influence', 2, 'Consultez le lobbyiste de l''Assemblée (ordre « Consulter le Lobbyiste »).', 'Luthécia, Assemblée nationale, Couloirs', 'consulter_lobbyiste', 'ordre', NULL),
  ('republic', 'influence', 3, 'Allez voir Renée Toitout, à l''accueil de l''Assemblée : elle sait qui fréquente les couloirs.', 'Luthécia, Assemblée nationale, Accueil', NULL, 'manuelle', 'Renée Toitout'),
  ('republic', 'crime', 1, 'Faites un tour au marché noir (ordre « Marché Noir »).', 'Luthécia, Armurerie Martinon, Magasin', 'marche_noir', 'ordre', NULL),
  ('republic', 'crime', 2, 'Faites falsifier un document (ordre « Falsifier un document »).', 'Luthécia, Tribunal, Greffe', 'falsifier_document', 'ordre', NULL),
  ('republic', 'crime', 3, 'Allez voir Pat Hounette, référent du milieu : dites-lui que vous cherchez du travail.', 'Luthécia, Place du Formulaire de la Liberté', NULL, 'manuelle', 'Pat Hounette'),
  ('republic', 'uniforme', 1, 'Regardez les postes à pourvoir, police et armée comprises (ordre « Postes à pourvoir »).', 'Luthécia, Bureau National de l''Emploi, Accueil', 'consulter_offres_emploi', 'manuelle', NULL),
  ('republic', 'uniforme', 2, 'Engagez-vous dans l''armée (ordre « S''engager dans l''armée »).', 'Caserne Militaire, Corps de Garde (hors de Luthécia)', 's_engager_armee', 'ordre', NULL),
  ('republic', 'uniforme', 3, 'Présentez-vous à l''Adjudant Gaspard Ferrière, référent de la caserne (pour la police : Raoul Toufaud, Commissariat de Luthécia).', 'Caserne Militaire, Corps de Garde', NULL, 'manuelle', 'Adjudant Gaspard Ferrière'),
  ('republic', 'belle_vie', 1, 'Réservez une chambre (ordre « Réserver une chambre »).', 'Luthécia, Hôtel-Restaurant La Républia, Accueil', 'reserver_chambre_hotel', 'ordre', NULL),
  ('republic', 'belle_vie', 2, 'Offrez une tournée au bar (ordre « Offrir à boire »).', 'Luthécia, Hôtel-Restaurant La Républia, Bar', 'offrir_tournee', 'ordre', NULL),
  ('republic', 'belle_vie', 3, 'Faites connaissance avec Marco, le barman : il connaît tous les habitués.', 'Luthécia, Hôtel-Restaurant La Républia, Bar', NULL, 'manuelle', 'Marco'),
  -- SOVARKA (Novomirsk)
  ('soviet', 'politique', 1, 'Consultez le calendrier électoral (ordre « Calendrier électoral »).', 'Novomirsk, Mairie, Hall d''accueil', 'calendrier_elections', 'manuelle', NULL),
  ('soviet', 'politique', 2, 'Adhérez à un parti (ordre « Partis constitués ») ou créez le vôtre (ordre « Créer un parti »).', 'Novomirsk, Mairie, Salle des partis', 'sovarka_parti_fonder', 'ordre', NULL),
  ('soviet', 'politique', 3, 'Allez voir le Capitaine Igor Balatov, qui tient la Salle des partis : il connaît la procédure.', 'Novomirsk, Mairie, Salle des partis', NULL, 'manuelle', 'Capitaine Igor Balatov'),
  ('soviet', 'affaires', 1, 'Repérez les commerces sans titulaire (ordre « Commerces non attribués »).', 'Novomirsk, Office notarial, Bureau des Contrats', 'sovarka_commerces_libres', 'manuelle', NULL),
  ('soviet', 'affaires', 2, 'Déposez une demande de location de bureau (ordre « Demande de location »).', 'Novomirsk, Centre d''affaires, Bureau de prestige', 'sovarka_demande_location', 'manuelle', NULL),
  ('soviet', 'affaires', 3, 'Allez voir Valery Burov, dans le hall du Centre d''affaires : il connaît la procédure de location.', 'Novomirsk, Centre d''affaires, Hall', NULL, 'manuelle', 'Valery Burov'),
  ('soviet', 'influence', 1, 'Écoutez ce qui se dit aux tables (ordre « Écouter les tables »).', 'Novomirsk, Grand Hôtel de Sovarka, Restaurant', 'ecouter_rumeurs', 'manuelle', NULL),
  ('soviet', 'influence', 2, 'Lancez une rumeur (ordre « Lancer une rumeur »).', 'Novomirsk, Distribution Collective, extérieur du marché', 'lancer_rumeur_cible', 'ordre', NULL),
  ('soviet', 'influence', 3, 'Allez voir Zinaïda Propagandova, ministre de l''Information : l''influence passe par elle.', 'Novomirsk, Palais du Gouvernement, Bureau du ministre de l''Information', NULL, 'manuelle', 'Zinaïda Propagandova'),
  ('soviet', 'crime', 1, 'Faites un tour au marché noir (ordre « Marché Noir »).', 'Novomirsk, Arsenal Collectif, Magasin', 'marche_noir', 'ordre', NULL),
  ('soviet', 'crime', 2, 'Demandez un autre fournisseur au Camarade Kalachnikov (ordre « Demander un autre fournisseur »).', 'Novomirsk, Arsenal Collectif, Magasin', 'demander_fournisseur_kalachnikov', 'ordre', NULL),
  ('soviet', 'crime', 3, 'Allez voir Gleb Lazarev, au bar du Grand Hôtel : il sait qui fait quoi dans l''ombre.', 'Novomirsk, Grand Hôtel de Sovarka, Bar', NULL, 'manuelle', 'Gleb Lazarev'),
  ('soviet', 'uniforme', 1, 'Engagez-vous dans l''armée (ordre « S''engager dans l''armée »).', 'Novomirsk, Caserne centrale, Corps de Garde', 's_engager_armee', 'ordre', NULL),
  ('soviet', 'uniforme', 2, 'Faites un stage à la caserne (ordre « Stage à la Caserne »).', 'Novomirsk, Caserne centrale, Corps de Garde', 'stage_caserne', 'ordre', NULL),
  ('soviet', 'uniforme', 3, 'Présentez-vous à l''Adjudant Piotr Antipov, référent de la caserne (pour la police : Vassili Ostrovski, Commissariat du Peuple).', 'Novomirsk, Caserne centrale, Corps de Garde', NULL, 'manuelle', 'Adjudant Piotr Antipov'),
  ('soviet', 'belle_vie', 1, 'Réservez une chambre (ordre « Réserver une chambre »).', 'Novomirsk, Grand Hôtel de Sovarka, Accueil', 'reserver_chambre_hotel', 'ordre', NULL),
  ('soviet', 'belle_vie', 2, 'Faites-vous couper les cheveux (ordre « Se faire couper les cheveux »).', 'Novomirsk, Salon de coiffure', 'salon_coupe', 'manuelle', NULL),
  ('soviet', 'belle_vie', 3, 'Faites connaissance avec Arkadi Melnikov, le barman du Grand Hôtel.', 'Novomirsk, Grand Hôtel de Sovarka, Bar', NULL, 'manuelle', 'Arkadi Melnikov')
ON CONFLICT (pays, chemin, n) DO UPDATE SET texte = EXCLUDED.texte, lieu = EXCLUDED.lieu, fn = EXCLUDED.fn,
  validation = EXCLUDED.validation, pnj = EXCLUDED.pnj;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. État d'accueil par personnage
-- ---------------------------------------------------------------------------------------------------------------
-- etat_interview : a_faire (jamais faite : ouverte à la connexion puis gardée dans Mes objectifs), article_a_publier
-- (chemin choisi, article pas encore confirmé), faite, ignoree (le joueur l'a écartée), deja_interviewe (interview
-- ou portrait publié avant cette migration), sans_journaliste (pays sans interview d'accueil).
CREATE TABLE IF NOT EXISTS public.accueil_personnages (
  personnage text PRIMARY KEY,
  pays text,
  etat_interview text NOT NULL DEFAULT 'a_faire'
    CHECK (etat_interview IN ('a_faire', 'article_a_publier', 'faite', 'ignoree', 'deja_interviewe', 'sans_journaliste')),
  journaliste text,
  ouverte_auto_le timestamptz,
  chemin text,
  mot text,
  chemin_choisi_le timestamptz,
  interview_id text,
  publiee_le timestamptz,
  etapes_faites jsonb NOT NULL DEFAULT '{}'::jsonb,
  bulle_pa_le timestamptz,
  bulle_pa_pa integer,
  cree_le timestamptz NOT NULL DEFAULT now(),
  maj_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.accueil_personnages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.accueil_personnages FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE ON public.accueil_personnages TO service_role;

ALTER TABLE public.interviews_jodie ADD COLUMN IF NOT EXISTS accueil boolean NOT NULL DEFAULT false;
ALTER TABLE public.interviews_jodie ADD COLUMN IF NOT EXISTS journaliste text;

-- Ligne d'accueil du personnage, créée à la première lecture (jamais par la migration).
CREATE OR REPLACE FUNCTION public.accueil_ligne_interne(p_nom text)
 RETURNS public.accueil_personnages LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.accueil_personnages; v_pays text; v_j text; v_etat text := 'a_faire';
BEGIN
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = p_nom;
  IF FOUND THEN RETURN r; END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_nom;
  SELECT journaliste INTO v_j FROM public.accueil_journalistes WHERE pays = v_pays;
  IF v_j IS NULL THEN v_etat := 'sans_journaliste';
  ELSIF EXISTS (SELECT 1 FROM public.interviews_jodie i WHERE i.personnage = p_nom AND i.publie AND i.article_texte IS NOT NULL)
     OR EXISTS (SELECT 1 FROM public.forum_topics t WHERE t.forum_id = 'presse' AND t.title = 'Un jour, un portrait : ' || p_nom) THEN
    v_etat := 'deja_interviewe';
  END IF;
  INSERT INTO public.accueil_personnages (personnage, pays, etat_interview, journaliste)
  VALUES (p_nom, v_pays, v_etat, v_j) ON CONFLICT (personnage) DO NOTHING;
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = p_nom;
  RETURN r; /* accueil_interview_v1 */
END $function$;

-- Vue complète de l'accueil pour le navigateur (jamais un calcul du navigateur).
CREATE OR REPLACE FUNCTION public.accueil_vue_interne(p_nom text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.accueil_personnages; j record; v_pays text; v_etapes jsonb; v_chemins jsonb; v_lib text;
BEGIN
  r := public.accueil_ligne_interne(p_nom);
  v_pays := coalesce(r.pays, (SELECT country FROM public.personnages_donnees WHERE name = p_nom));
  SELECT * INTO j FROM public.accueil_journalistes WHERE pays = v_pays;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', c.chemin, 'libelle', c.libelle) ORDER BY c.rang), '[]'::jsonb)
    INTO v_chemins FROM public.accueil_chemins c WHERE c.pays = v_pays;
  SELECT libelle INTO v_lib FROM public.accueil_chemins WHERE pays = v_pays AND chemin = r.chemin;
  SELECT coalesce(jsonb_agg(jsonb_build_object('n', e.n, 'texte', e.texte, 'lieu', e.lieu, 'validation', e.validation,
           'pnj', e.pnj, 'faite', r.etapes_faites ? e.n::text, 'faite_le', r.etapes_faites ->> e.n::text) ORDER BY e.n), '[]'::jsonb)
    INTO v_etapes FROM public.accueil_etapes e WHERE e.pays = v_pays AND e.chemin = r.chemin;
  RETURN jsonb_build_object('ok', true, 'personnage', p_nom, 'pays', v_pays,
    'interview', jsonb_build_object('etat', r.etat_interview, 'journaliste', j.journaliste, 'journal', j.journal,
      'question', j.question,
      'ouvrir_auto', r.etat_interview = 'a_faire' AND r.ouverte_auto_le IS NULL
                     AND public.accueil_param('interview_ouverture_auto', 1) >= 1),
    'mot_max', public.accueil_param('mot_longueur_max', 280)::integer,
    'chemins', v_chemins,
    'chemin', CASE WHEN r.chemin IS NULL THEN NULL ELSE jsonb_build_object('id', r.chemin, 'libelle', v_lib) END,
    'mot', r.mot, 'etapes', v_etapes,
    'bulle_pa', jsonb_build_object('vue', r.bulle_pa_le IS NOT NULL, 'pa', r.bulle_pa_pa,
      'active', public.accueil_param('bulle_pa_active', 1) >= 1)); /* accueil_interview_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.accueil_etat()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN public.accueil_vue_interne(a); /* accueil_interview_v1 */
END $function$;

-- L'ouverture automatique n'a lieu qu'une fois : ensuite l'interview attend dans Mes objectifs (point 25).
CREATE OR REPLACE FUNCTION public.accueil_interview_vue()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM public.accueil_ligne_interne(a);
  UPDATE public.accueil_personnages SET ouverte_auto_le = coalesce(ouverte_auto_le, now()), maj_le = now() WHERE personnage = a;
  RETURN jsonb_build_object('ok', true); /* accueil_interview_v1 */
END $function$;

CREATE OR REPLACE FUNCTION public.accueil_choisir_chemin(p_chemin text, p_mot text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); r public.accueil_personnages; v_pays text;
        v_mot text := nullif(btrim(coalesce(p_mot, '')), '');
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM public.accueil_ligne_interne(a);
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = a FOR UPDATE;
  IF r.chemin IS NOT NULL THEN
    IF r.chemin = p_chemin THEN RETURN public.accueil_vue_interne(a); END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'chemin_deja_choisi');
  END IF;
  IF r.etat_interview NOT IN ('a_faire', 'ignoree') THEN RETURN jsonb_build_object('ok', false, 'raison', 'interview_indisponible'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = a;
  IF NOT EXISTS (SELECT 1 FROM public.accueil_chemins WHERE pays = v_pays AND chemin = p_chemin) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chemin_inconnu');
  END IF;
  IF v_mot IS NOT NULL AND length(v_mot) > public.accueil_param('mot_longueur_max', 280) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mot_trop_long');
  END IF;
  UPDATE public.accueil_personnages SET pays = v_pays, chemin = p_chemin, mot = v_mot, chemin_choisi_le = now(),
         etat_interview = 'article_a_publier', ouverte_auto_le = coalesce(ouverte_auto_le, now()), maj_le = now()
   WHERE personnage = a;
  RETURN public.accueil_vue_interne(a); /* accueil_interview_v1 */
END $function$;

-- « Ignorer » : l'interview quitte Mes objectifs (le joueur l'a écartée ; elle n'est plus proposée).
CREATE OR REPLACE FUNCTION public.accueil_ignorer()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM public.accueil_ligne_interne(a);
  UPDATE public.accueil_personnages SET etat_interview = 'ignoree', ouverte_auto_le = coalesce(ouverte_auto_le, now()), maj_le = now()
   WHERE personnage = a AND etat_interview = 'a_faire';
  RETURN public.accueil_vue_interne(a); /* accueil_interview_v1 */
END $function$;

-- Validation manuelle (« J'ai fait cette étape ») : toute étape du parcours du personnage.
CREATE OR REPLACE FUNCTION public.accueil_etape_valider(p_n integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); r public.accueil_personnages; v_val text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = a FOR UPDATE;
  IF NOT FOUND OR r.chemin IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'aucun_parcours'); END IF;
  SELECT validation INTO v_val FROM public.accueil_etapes WHERE pays = r.pays AND chemin = r.chemin AND n = p_n;
  IF v_val IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'etape_inconnue'); END IF;
  IF NOT r.etapes_faites ? p_n::text THEN
    UPDATE public.accueil_personnages SET etapes_faites = etapes_faites || jsonb_build_object(p_n::text, now()), maj_le = now()
     WHERE personnage = a;
  END IF;
  RETURN public.accueil_vue_interne(a); /* accueil_interview_v1 */
END $function$;

-- Bulle des PA signalée par le navigateur (ordre payé par une commande serveur propre, qui ne passe pas par
-- payer_ordre_interne) : le serveur seul décide si c'est la première fois. Une seule fois par personnage.
CREATE OR REPLACE FUNCTION public.accueil_bulle_pa_signaler(p_pa integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a text := public.mon_personnage(); n integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_pa IS NULL OR p_pa < 1 OR p_pa > public.accueil_param('bulle_pa_max', 20) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_invalide');
  END IF;
  PERFORM public.accueil_ligne_interne(a);
  IF public.accueil_param('bulle_pa_active', 1) < 1 THEN RETURN jsonb_build_object('ok', true, 'montrer', false); END IF;
  UPDATE public.accueil_personnages SET bulle_pa_le = now(), bulle_pa_pa = p_pa, maj_le = now()
   WHERE personnage = a AND bulle_pa_le IS NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN jsonb_build_object('ok', true, 'montrer', n = 1, 'pa', p_pa); /* accueil_interview_v1 */
END $function$;

-- Appelée par payer_ordre_interne après un prélèvement réussi. Jamais d'erreur vers l'appelant.
CREATE OR REPLACE FUNCTION public.accueil_ordre_paye_interne(p_acteur text, p_fn text, p_pa integer)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r public.accueil_personnages; e record;
BEGIN
  SELECT * INTO r FROM public.accueil_personnages WHERE personnage = p_acteur FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF r.chemin IS NOT NULL THEN
    FOR e IN SELECT n, texte FROM public.accueil_etapes
              WHERE pays = r.pays AND chemin = r.chemin AND validation = 'ordre' AND fn = p_fn ORDER BY n LOOP
      IF NOT r.etapes_faites ? e.n::text THEN
        r.etapes_faites := r.etapes_faites || jsonb_build_object(e.n::text, now());
        UPDATE public.accueil_personnages SET etapes_faites = r.etapes_faites, maj_le = now() WHERE personnage = p_acteur;
        PERFORM public.personnage_evenement_ajouter_interne(p_acteur, 'accueil_etape',
          'Objectif accompli : ' || e.texte, jsonb_build_object('n', e.n, 'ton', 'bon'));
      END IF;
    END LOOP;
  END IF;
  IF coalesce(p_pa, 0) > 0 AND r.bulle_pa_le IS NULL AND public.accueil_param('bulle_pa_active', 1) >= 1 THEN
    UPDATE public.accueil_personnages SET bulle_pa_le = now(), bulle_pa_pa = p_pa, maj_le = now() WHERE personnage = p_acteur;
    -- Texte vide : la bulle s'affiche à côté de la jauge, rien n'est inscrit au journal.
    PERFORM public.personnage_evenement_ajouter_interne(p_acteur, 'accueil_bulle_pa', '', jsonb_build_object('pa', p_pa));
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'accueil_ordre_paye_interne : % (%)', SQLERRM, p_fn; /* accueil_interview_v1 */
END $function$;

REVOKE ALL ON FUNCTION public.accueil_param(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_ligne_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_vue_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.accueil_ordre_paye_interne(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_accueil_parametres_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_accueil_parametres_lire() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_accueil_parametre_fixer(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_accueil_parametre_fixer(text, numeric) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.accueil_etat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_etat() TO authenticated;
REVOKE ALL ON FUNCTION public.accueil_interview_vue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_interview_vue() TO authenticated;
REVOKE ALL ON FUNCTION public.accueil_choisir_chemin(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_choisir_chemin(text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.accueil_ignorer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_ignorer() TO authenticated;
REVOKE ALL ON FUNCTION public.accueil_bulle_pa_signaler(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_bulle_pa_signaler(integer) TO authenticated;
REVOKE ALL ON FUNCTION public.accueil_etape_valider(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accueil_etape_valider(integer) TO authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Branchement sur le paiement commun des ordres (remplacement contrôlé, texte de production)
-- ---------------------------------------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.payer_ordre_interne(text,text,integer,integer,integer)'::regprocedure,
  $a$  -- FONDS EN TRANSIT (26/10/2026)$a$,
  $b$  -- Accueil (Fred, 22/11/2026, points 24 et 26) : étape du parcours validée par l'ordre payé ; bulle des PA au premier
  -- ordre qui en coûte. Après le prélèvement ; ne lève jamais d'erreur.
  PERFORM public.accueil_ordre_paye_interne(p_acteur, v_fn, coalesce(p_pa, 0)); /* accueil_ordre_paye_v1 */

  -- FONDS EN TRANSIT (26/10/2026)$b$,
  1, 'accueil_ordre_paye_v1');
