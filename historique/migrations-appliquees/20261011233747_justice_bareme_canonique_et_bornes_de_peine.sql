-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261011233747 (UTC), nom
-- `justice_bareme_canonique_et_bornes_de_peine`.
-- Le registre passe de 669 a 670 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 0ab17723aa9d7c4454d5d7c894095553, 28100 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE CODE PENAL ENTRE EN BASE (1/2)
--
-- LE SERVEUR NE CONNAISSAIT AUCUN BAREME. `justice_rendre_sentence` recevait la peine du
-- navigateur comme une CHAINE LIBRE et l'archivait sans la confronter a rien -- il n'avait rien
-- a quoi la confronter. Le code penal du jeu existait pourtant deja, entier, mais uniquement
-- dans plateau-core.js : PEINES (4 categories), PEINES_ACTES.republic (16 baremes propres) et
-- ACTES_ILLEGAUX (28 actes), resolus par `getPeineParActe`.
--
-- CETTE MIGRATION LE RECOPIE EN BASE, SANS EN CHANGER UNE VALEUR, et c'est un MIROIR SURVEILLE :
-- le generateur outils/generateurs/generer_infractions.py EXTRAIT la vraie fonction de
-- resolution du fichier de production et l'appelle, plutot que d'en reimplementer la regle ;
-- `infractions_empreinte_reelle()` en est le pendant SQL exact. Si plateau-core.js change une
-- duree sans que le miroir soit regenere, verifier-referentiels.py rougit.
--
-- TROIS CHOSES QU'ELLE NE DECIDE PAS, ET C'EST LE POINT :
--   . aucune duree de reference n'est modifiee ;
--   . AUCUN doublon de nomenclature n'est fusionne -- les trois paires relevees par l'inventaire
--     portent des durees DIFFERENTES de part et d'autre (assassinat 2 j contre assassiner_* 8 j,
--     corruption_fonctionnaire 1 j contre corrompre_fonct 2 j, achat_arme_illegal 1 j contre
--     acheter_arme_illegale 2 j), donc les resoudre CHANGERAIT une peine. La table d'alias nait
--     VIDE et la preuve P5 le verifie ;
--   . le bareme n'est pas etendu aux trois autres empires, et la table ne porte pas de colonne
--     de pays (preuve P12).
--
-- ET DEUX CHIFFRES DE L'INVENTAIRE SONT RECTIFIES PAR LA MESURE : il annonce 34 identifiants, il
-- y en a 39 (ses propres tableaux en listent 5 + 23 + 11) ; il annonce 7 infractions a 1 jour de
-- reference, il y en a 8 -- il avait compte les sept baremes sans acte et oublie `vol`.
--
-- LES 13 PREUVES STRUCTURELLES sont passees a l'application. Le COMPORTEMENT est eprouve
-- separement par outils/bancs/banc-justice-peine-serveur.sql (22 epreuves, transaction annulee).
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE BAREME DEVIENT LA LOI -- CATALOGUE CANONIQUE DES INFRACTIONS ET BORNES DE PEINE
-- 12 octobre 2026
--
-- LE DEFAUT QUE CE LOT FERME EST NOMME, ET C'EST LE PLUS GRAVE DE LA JUSTICE.
-- `justice_rendre_sentence(p_affaire jsonb, p_peine text)` accepte DEUX choses du navigateur :
--   . `p_peine`, une CHAINE LIBRE (« Prison 3 jours », « Amende de 500 FR ») qu'elle archive
--     telle quelle, sans jamais la confronter a un bareme ;
--   . `p_affaire`, le BLOB ENTIER de l'affaire, qu'elle fusionne sur la ligne existante
--     (`v_existante || p_affaire`) -- donc l'accuse, le motif, la ville et le pays d'une affaire
--     peuvent etre reecrits par l'appelant au moment du jugement.
-- La duree reellement infligee, elle, est un 3 EN DUR cote navigateur, module par deux drapeaux
-- (`circonstanceAttenuante`, `aggravation`) eux aussi portes par le blob client.
-- CETTE MIGRATION POSE LE SOCLE ; la porte elle-meme est remplacee par la migration suivante.
--
-- LE CODE PENAL EXISTE POURTANT DEJA, ENTIER -- mais uniquement dans le navigateur : PEINES,
-- PEINES_ACTES et ACTES_ILLEGAUX dans plateau-core.js, resolus par `getPeineParActe`. Le serveur
-- ne le connait pas. Cette migration le lui donne, SANS EN CHANGER UNE VALEUR.
--
-- CE QUI N'EST PAS DECIDE ICI, ET QUI NE DEVAIT PAS L'ETRE :
--   . aucune duree de reference n'est modifiee -- les 39 identifiants gardent exactement la peine
--     que `getPeineParActe(id, false)` rend aujourd'hui ;
--   . AUCUN doublon de nomenclature n'est fusionne. Les trois paires relevees par l'inventaire
--     portent des durees DIFFERENTES de part et d'autre (assassinat 2 j contre assassiner_* 8 j,
--     corruption_fonctionnaire 1 j contre corrompre_fonct 2 j, achat_arme_illegal 1 j contre
--     acheter_arme_illegale 2 j) : les resoudre l'une vers l'autre CHANGERAIT une peine. La table
--     d'alias est donc creee VIDE, et les paires sont rapportees comme arbitrages ;
--   . le bareme n'est pas etendu aux trois autres empires -- PEINES_ACTES ne declare que
--     `republic`, et en inventer un pour Novomirsk serait un arbitrage ;
--   . aucun handler n'est invente pour `corrompre_juge` ni pour `crime_etat`, que rien ne
--     declenche aujourd'hui. Ils figurent au catalogue parce qu'ils figurent au canon.
--
-- ET LE CATALOGUE EST UN MIROIR SURVEILLE, pas une copie a la main : le generateur
-- outils/generateurs/generer_infractions.py rejoue la VRAIE fonction de resolution extraite du
-- fichier de production, et `infractions_empreinte_reelle()` est son pendant SQL exact. Si
-- plateau-core.js change une duree sans que le miroir soit regenere,
-- outils/baseline/verifier-referentiels.py rougit.
--
-- DEUX RECTIFICATIONS DE L'INVENTAIRE, TROUVEES EN SEMANT LE CATALOGUE :
--   1. il annonce « 34 identifiants distincts » dans son titre, mais ses propres tableaux en
--      listent 5 + 23 + 11 = 39, et le calcul qu'il donne (28 actes + 16 baremes - 5 communs)
--      vaut bien 39. Le generateur en compte 39. C'est le titre qui etait faux, pas les tableaux.
--   2. il annonce « 7 infractions » a 1 jour de reference. Il y en a HUIT : les sept baremes sans
--      acte de son paragraphe C, PLUS `vol`, qui figure dans son paragraphe A a 1 jour et qui n'a
--      pas ete compte avec les autres. La preuve P10 porte donc sur 8.

-- ============================================================================================
-- 1. LES CATEGORIES -- UNE CLASSE N'EST PAS UNE CHARGE
-- ============================================================================================
-- Declarees en PREMIER : `infractions.categorie` les reference, donc elles doivent exister avant.
-- Elles portent la peine HERITEE des 23 actes qui n'ont pas de bareme propre. Elles sont
-- declarees pour que la derivation soit relisible en base, mais `infraction_canonique` les
-- REFUSE comme qualification : on ne condamne pas quelqu'un pour « crime » en general.
CREATE TABLE IF NOT EXISTS public.infractions_categories (
  id                text PRIMARY KEY,
  libelle           text NOT NULL,
  jours_reference   integer NOT NULL CHECK (jours_reference >= 1),
  amende_reference  integer NOT NULL CHECK (amende_reference >= 0)
);
COMMENT ON TABLE public.infractions_categories IS
  'Les quatre categories generiques de PEINES (plateau-core.js) : la peine HERITEE par les actes sans bareme propre. Une categorie est une CLASSE, jamais une charge -- infraction_canonique() refuse un nom de categorie comme qualification.';

-- ============================================================================================
-- 2. LE CATALOGUE CANONIQUE
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.infractions (
  id                text PRIMARY KEY,
  libelle           text NOT NULL,
  -- NULL pour les 11 baremes qui n'ont pas d'acte correspondant : ils ne retombent sur aucune
  -- categorie parce qu'ils portent leur propre peine.
  categorie         text REFERENCES public.infractions_categories(id),
  jours_reference   integer NOT NULL CHECK (jours_reference >= 1),
  amende_reference  integer NOT NULL CHECK (amende_reference >= 0),
  -- NULL quand l'infraction n'est pas dans ACTES_ILLEGAUX : checkDetection() ne la voit pas,
  -- donc elle ne peut jamais produire un statut « recherche ». C'est un FAIT du canon, pas un
  -- defaut introduit ici.
  detect_rate       integer CHECK (detect_rate IS NULL OR (detect_rate BETWEEN 0 AND 100)),
  bareme_propre     boolean NOT NULL,
  detectable        boolean NOT NULL
);
COMMENT ON TABLE public.infractions IS
  'Catalogue canonique des infractions, MIROIR de PEINES/PEINES_ACTES/ACTES_ILLEGAUX de plateau-core.js. La peine de reference de chaque ligne est exactement ce que getPeineParActe(id, false) rend cote navigateur : aucune valeur n''est decidee ici. Surveille par infractions_empreinte / infractions_empreinte_reelle().';
COMMENT ON COLUMN public.infractions.libelle IS
  'Le libelle que rend getPeineParActe. VINGT-TROIS des 39 infractions n''ont PAS de nom propre : elles heritent celui de leur categorie (« Delit mineur », « Crime »), parce que le canon n''en declare pas d''autre. Aucun nom n''a ete invente ici -- l''ecran du juge affiche donc l''identifiant a cote du libelle, et nommer ces 23 infractions est un arbitrage de game design ouvert.';

-- ============================================================================================
-- 3. LES ALIAS -- VIDE, ET C'EST LE RESULTAT
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.infractions_alias (
  alias      text PRIMARY KEY,
  canonique  text NOT NULL REFERENCES public.infractions(id),
  note       text NOT NULL,
  CONSTRAINT infractions_alias_pas_sur_soi CHECK (alias <> canonique)
);
COMMENT ON TABLE public.infractions_alias IS
  'Resolution des nomenclatures historiques vers un identifiant canonique. VIDE au 12 octobre 2026, et ce n''est pas un oubli : les trois paires de doublons relevees par l''inventaire portent des durees de reference DIFFERENTES de part et d''autre, donc les resoudre changerait une peine. Le mecanisme existe pour accueillir l''arbitrage ; il ne le prejuge pas.';

-- ============================================================================================
-- 4. L'EMPREINTE DU MIROIR
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.infractions_empreinte (
  seul       boolean PRIMARY KEY DEFAULT true CHECK (seul),
  empreinte  text NOT NULL,
  pose_le    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.infractions_empreinte IS
  'La sentinelle du miroir des infractions, meme patron que villes_empreinte : une seule ligne, l''empreinte POSEE a la derniere generation. infractions_empreinte_reelle() rend celle du contenu courant ; verifier-referentiels.py confronte les deux a celle que le generateur calcule depuis plateau-core.js.';

-- ============================================================================================
-- 5. LE SEED -- RECOPIE DU CANON, PAS DECIDE
-- ============================================================================================
INSERT INTO public.infractions_categories (id, libelle, jours_reference, amende_reference) VALUES
  ('crime', 'Crime', 8, 5000),
  ('crime_etat', 'Crime d''Etat', 30, 0),
  ('delit_grave', 'Delit grave', 4, 1500),
  ('delit_mineur', 'Delit mineur', 2, 500)
ON CONFLICT (id) DO UPDATE SET libelle = EXCLUDED.libelle,
  jours_reference = EXCLUDED.jours_reference, amende_reference = EXCLUDED.amende_reference;

INSERT INTO public.infractions
  (id, libelle, categorie, jours_reference, amende_reference, detect_rate, bareme_propre, detectable) VALUES
  ('achat_arme_illegal', 'Achat d''arme non enregistree', NULL, 1, 500, NULL, true, false),
  ('acheter_arme_illegale', 'Delit mineur', 'delit_mineur', 2, 500, 20, false, true),
  ('acheter_bombe_illegale', 'Achat d''explosifs non enregistres', 'crime', 2, 2000, 55, true, true),
  ('arreter', 'Delit grave', 'delit_grave', 4, 1500, 40, false, true),
  ('assassinat', 'Assassinat', NULL, 2, 1500, NULL, true, false),
  ('assassiner_arme', 'Crime', 'crime', 8, 5000, 40, false, true),
  ('assassiner_feu', 'Crime', 'crime', 8, 5000, 60, false, true),
  ('assassiner_mains', 'Crime', 'crime', 8, 5000, 30, false, true),
  ('blanchiment', 'Delit grave', 'delit_grave', 4, 1500, 35, false, true),
  ('contrebande_port', 'Delit mineur', 'delit_mineur', 2, 500, 20, false, true),
  ('corrompre_douanier', 'Delit mineur', 'delit_mineur', 2, 500, 35, false, true),
  ('corrompre_fonct', 'Delit mineur', 'delit_mineur', 2, 500, 30, false, true),
  ('corrompre_gardien', 'Delit mineur', 'delit_mineur', 2, 500, 35, false, true),
  ('corrompre_journaliste', 'Delit mineur', 'delit_mineur', 2, 500, 25, false, true),
  ('corrompre_juge', 'Delit grave', 'delit_grave', 4, 1500, 40, false, true),
  ('corrompre_police', 'Delit mineur', 'delit_mineur', 2, 500, 35, false, true),
  ('corruption_fonctionnaire', 'Corruption de fonctionnaire', NULL, 1, 1000, NULL, true, false),
  ('diffamation', 'Diffamation', NULL, 1, 500, NULL, true, false),
  ('empoisonnement', 'Empoisonnement', 'crime', 2, 2000, 25, true, true),
  ('fabriquer_bombe', 'Crime', 'crime', 8, 5000, 60, false, true),
  ('fabriquer_scandale', 'Delit grave', 'delit_grave', 4, 1500, 45, false, true),
  ('falsifier_document', 'Delit grave', 'delit_grave', 4, 1500, 40, false, true),
  ('fausse_rumeur', 'Delit mineur', 'delit_mineur', 2, 500, 35, false, true),
  ('fuite_info', 'Delit grave', 'delit_grave', 4, 1500, 40, false, true),
  ('hooliganisme', 'Trouble a l''ordre public (hooliganisme)', NULL, 1, 500, NULL, true, false),
  ('imprimer_tracts_calomnieux', 'Delit mineur', 'delit_mineur', 2, 500, 30, false, true),
  ('incendier', 'Incendie volontaire', 'crime', 2, 2000, 70, true, true),
  ('justification_rejetee', 'Justification rejetée (marchandise interdite)', NULL, 1, 0, NULL, true, false),
  ('non_presentation_convocation', 'Non-présentation à convocation', NULL, 2, 0, NULL, true, false),
  ('possession_illegale_douane', 'Possession d''objets prohibes au controle douanier', NULL, 1, 500, NULL, true, false),
  ('se_rebeller', 'Delit mineur', 'delit_mineur', 2, 500, 60, false, true),
  ('societe_ecran', 'Delit mineur', 'delit_mineur', 2, 500, 25, false, true),
  ('tentative_assassinat', 'Tentative d''assassinat', NULL, 2, 1500, NULL, true, false),
  ('tentative_empoisonnement', 'Tentative d''empoisonnement', NULL, 2, 2000, NULL, true, false),
  ('tentative_evasion', 'Crime', 'crime', 8, 5000, 90, false, true),
  ('utiliser_explosifs', 'Usage d''explosifs', 'crime', 2, 2000, 65, true, true),
  ('violation_couvre_feu', 'Violation du couvre-feu', NULL, 1, 200, NULL, true, false),
  ('vol', 'Vol', 'delit_mineur', 1, 500, 30, true, true),
  ('vol_materiel_chantier', 'Delit mineur', 'delit_mineur', 2, 500, 30, false, true)
ON CONFLICT (id) DO UPDATE SET libelle = EXCLUDED.libelle, categorie = EXCLUDED.categorie,
  jours_reference = EXCLUDED.jours_reference, amende_reference = EXCLUDED.amende_reference,
  detect_rate = EXCLUDED.detect_rate, bareme_propre = EXCLUDED.bareme_propre,
  detectable = EXCLUDED.detectable;

INSERT INTO public.infractions_empreinte (seul, empreinte) VALUES (true, '93293c6770c17332')
ON CONFLICT (seul) DO UPDATE SET empreinte = EXCLUDED.empreinte, pose_le = now();

-- ============================================================================================
-- 6. RLS ET DROITS
-- ============================================================================================
ALTER TABLE public.infractions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.infractions_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.infractions_alias      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.infractions_empreinte  ENABLE ROW LEVEL SECURITY;

-- AUCUN DROIT CLIENT SUR LES QUATRE TABLES, ET AUCUNE POLICY : la doctrine du projet dit qu'une
-- policy sans GRANT dort et qu'un GRANT sans policy est ouvert. Le code penal se lit par les
-- portes, jamais par un SELECT direct -- sinon un navigateur pourrait en afficher sa propre
-- version.
REVOKE ALL ON public.infractions            FROM anon, authenticated;
REVOKE ALL ON public.infractions_categories FROM anon, authenticated;
REVOKE ALL ON public.infractions_alias      FROM anon, authenticated;
REVOKE ALL ON public.infractions_empreinte  FROM anon, authenticated;

-- ============================================================================================
-- 7. L'EMPREINTE REELLE -- LE PENDANT SQL DU GENERATEUR
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.infractions_empreinte_reelle()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT left(md5(string_agg(
      id || '|' || libelle || '|' || coalesce(categorie, '')
         || '|' || jours_reference::text || '|' || amende_reference::text
         || '|' || coalesce(detect_rate::text, '')
         || '|' || CASE WHEN bareme_propre THEN '1' ELSE '0' END,
      E'\n' ORDER BY id COLLATE "C")), 16)
  FROM public.infractions;
$$;
COMMENT ON FUNCTION public.infractions_empreinte_reelle() IS
  'L''empreinte du contenu COURANT du miroir des infractions, sur la meme chaine et le meme tri COLLATE "C" que outils/generateurs/generer_infractions.py. COLLATE "C" n''est pas decoratif : les identifiants portent des soulignes, que la collation par defaut ignore au poids primaire alors que Python trie par point de code.';

-- ============================================================================================
-- 8. LA RESOLUTION CANONIQUE
-- ============================================================================================
-- FAIL CLOSED, ET LE REFUS DES CATEGORIES EST DELIBERE. Un identifiant inconnu rend NULL ; un nom
-- de CATEGORIE rend NULL aussi, parce qu'une classe n'est pas une charge. L'alias est resolu
-- avant tout -- la table est vide aujourd'hui, le chemin existe pour demain.
CREATE OR REPLACE FUNCTION public.infraction_canonique(p_id text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id text; v_canon text;
BEGIN
  v_id := nullif(btrim(coalesce(p_id, '')), '');
  IF v_id IS NULL THEN RETURN NULL; END IF;
  SELECT a.canonique INTO v_canon FROM public.infractions_alias a WHERE a.alias = v_id;
  IF v_canon IS NOT NULL THEN v_id := v_canon; END IF;
  IF EXISTS (SELECT 1 FROM public.infractions i WHERE i.id = v_id) THEN RETURN v_id; END IF;
  RETURN NULL;
END;
$$;
COMMENT ON FUNCTION public.infraction_canonique(text) IS
  'Resout un identifiant d''infraction vers sa forme canonique, ou NULL. FAIL CLOSED : un identifiant inconnu rend NULL, et un nom de CATEGORIE rend NULL aussi -- on ne condamne pas pour « crime » en general. Les alias sont resolus d''abord.';

-- ============================================================================================
-- 9. LES BORNES DE LA PEINE -- LE +/- 50 % CALCULE AU SERVEUR
-- ============================================================================================
-- LE CAS DES PEINES DE 1 JOUR EST TRAITE, ET IL N'EST PAS ARBITRE -- MAIS PAS DE LA FACON QUE
-- L'INVENTAIRE ANNONCAIT. Il posait la question comme « 1 jour plancher ou 0 ? ». Mesure faite :
-- la question ne se pose pas en ces termes, parce que `round()` de PostgreSQL arrondit les demis
-- VERS LE HAUT -- round(0.5) = 1. Le -50 % d'une peine de 1 jour rend donc 1 jour tout seul, sans
-- qu'aucun plancher n'ait besoin d'intervenir, et jamais 0.
--
-- LE VRAI FAIT EST AILLEURS, ET IL EST PLUS GENANT : pour les HUIT infractions a 1 jour, la borne
-- BASSE EGALE LA REFERENCE. Le juge ne peut donc QU'AGGRAVER -- la plage est [1, 2] -- et
-- l'attenuation est inexprimable a la granularite du jour entier. C'est ce que signale
-- `plancher_technique` dans la reponse, pour que l'ecran du juge le DISE au lieu de lui laisser
-- croire qu'il a module.
--
-- `greatest(1, ...)` est conserve comme garde-fou de structure, et non comme regle : il ne se
-- declenche sur aucune des 39 infractions actuelles. Il protegerait d'une reference future a 0 ou
-- d'un changement de convention d'arrondi, deux cas ou une peine nulle pourrait naitre sans que
-- personne l'ait decidee.
--
-- Les options possibles (demi-journee, conversion en heures, minimum assume a 1 jour, relevement
-- du bareme) sont documentees au rapport ; AUCUNE n'est choisie ici, et aucun bareme n'est
-- modifie pour contourner le probleme.
CREATE OR REPLACE FUNCTION public.infraction_peine_bornes(p_infraction text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id text; v_i record; v_jmin integer; v_jmax integer; v_amin integer; v_amax integer;
BEGIN
  v_id := public.infraction_canonique(p_infraction);
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'infraction_inconnue',
                              'demande', p_infraction);
  END IF;
  SELECT * INTO v_i FROM public.infractions WHERE id = v_id;

  -- round() de PostgreSQL arrondit au plus proche, les demis vers le haut : round(0.5) = 1 et
  -- round(1.5) = 2. C'est la meme convention que Math.round cote navigateur.
  v_jmin := greatest(1, round(v_i.jours_reference * 0.5)::integer);
  v_jmax := round(v_i.jours_reference * 1.5)::integer;
  v_amin := greatest(0, round(v_i.amende_reference * 0.5)::integer);
  v_amax := round(v_i.amende_reference * 1.5)::integer;

  RETURN jsonb_build_object('ok', true,
    'infraction', v_i.id, 'libelle', v_i.libelle, 'categorie', v_i.categorie,
    'bareme_propre', v_i.bareme_propre, 'detectable', v_i.detectable,
    'jours_reference', v_i.jours_reference, 'jours_min', v_jmin, 'jours_max', v_jmax,
    'amende_reference', v_i.amende_reference, 'amende_min', v_amin, 'amende_max', v_amax,
    -- VRAI quand la borne basse EGALE la reference : l'attenuation est alors inexprimable, le
    -- juge ne peut qu'aggraver. Les huit infractions a 1 jour sont dans ce cas.
    'plancher_technique', (v_jmin >= v_i.jours_reference));
END;
$$;
COMMENT ON FUNCTION public.infraction_peine_bornes(text) IS
  'La peine de reference d''une infraction canonique et sa plage de modulation judiciaire : -50 % a +50 %, calcules au SERVEUR. `plancher_technique` vaut true quand la borne basse EGALE la reference -- cas des huit infractions a 1 jour, ou l''attenuation est inexprimable en jours entiers et ou le juge ne peut donc qu''aggraver. C''est un fait signale, pas un arbitrage rendu.';

-- ============================================================================================
-- 10. DROITS DES FONCTIONS
-- ============================================================================================
REVOKE ALL ON FUNCTION public.infractions_empreinte_reelle()       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.infraction_canonique(text)           FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.infraction_peine_bornes(text)        FROM PUBLIC, anon, authenticated;

-- LE JOUEUR LIT LE CODE PENAL, IL NE L'ECRIT PAS. `infraction_peine_bornes` est accordee a
-- authenticated parce que l'ecran du juge doit AFFICHER la plage reelle -- un juge qui ne voit pas
-- ses bornes ne peut pas moduler. Elle ne rend aucune information privee : le bareme est public.
GRANT EXECUTE ON FUNCTION public.infraction_canonique(text)    TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.infraction_peine_bornes(text) TO authenticated, service_role;
-- L'empreinte est un outil de controle, pas une information de jeu.
GRANT EXECUTE ON FUNCTION public.infractions_empreinte_reelle() TO service_role;

-- ============================================================================================
-- 11. PREUVES STRUCTURELLES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text; v_emp text;
BEGIN
  -- P1 : les quatre tables existent et portent la RLS.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relrowsecurity
     AND c.relname IN ('infractions','infractions_categories','infractions_alias',
                       'infractions_empreinte');
  IF v_n <> 4 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % table(s) sur 4 avec RLS', v_n; END IF;

  -- P2 : AUCUN DROIT CLIENT sur les quatre. Le code penal se lit par les portes.
  SELECT count(*) INTO v_n FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND grantee IN ('anon','authenticated')
     AND table_name IN ('infractions','infractions_categories','infractions_alias',
                        'infractions_empreinte');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % droit(s) client sur le code penal', v_n; END IF;

  -- P3 : LE CATALOGUE EST COMPLET. 39 identifiants, 4 categories -- les comptes du generateur.
  SELECT count(*) INTO v_n FROM public.infractions;
  IF v_n <> 39 THEN RAISE EXCEPTION 'P3 ECHOUEE -- % infraction(s) au lieu de 39', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.infractions_categories;
  IF v_n <> 4 THEN RAISE EXCEPTION 'P3 ECHOUEE -- % categorie(s) au lieu de 4', v_n; END IF;

  -- P4 : L'EMPREINTE POSEE EST CELLE DU CONTENU. Si le seed et la sentinelle divergeaient, le
  --      miroir naitrait deja faux.
  SELECT empreinte INTO v_emp FROM public.infractions_empreinte WHERE seul;
  IF v_emp IS DISTINCT FROM public.infractions_empreinte_reelle() THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- posee % contre reelle %', v_emp,
                    public.infractions_empreinte_reelle();
  END IF;

  -- P5 : AUCUN ALIAS N'A ETE CREE. Les trois paires de doublons portent des durees differentes :
  --      en resoudre une changerait une peine.
  SELECT count(*) INTO v_n FROM public.infractions_alias;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 ECHOUEE -- % alias invente(s)', v_n; END IF;

  -- P6 : LES DOUBLONS SONT TOUJOURS DISTINCTS, et avec leurs durees d'origine. C'est la preuve
  --      qu'aucune fusion silencieuse n'a eu lieu.
  IF (SELECT jours_reference FROM public.infractions WHERE id = 'assassinat') <> 2
     OR (SELECT jours_reference FROM public.infractions WHERE id = 'assassiner_mains') <> 8
     OR (SELECT jours_reference FROM public.infractions WHERE id = 'corruption_fonctionnaire') <> 1
     OR (SELECT jours_reference FROM public.infractions WHERE id = 'corrompre_fonct') <> 2
     OR (SELECT jours_reference FROM public.infractions WHERE id = 'achat_arme_illegal') <> 1
     OR (SELECT jours_reference FROM public.infractions WHERE id = 'acheter_arme_illegale') <> 2 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- une duree de reference a bouge sur une paire de doublons';
  END IF;

  -- P7 : UNE CATEGORIE N'EST PAS UNE CHARGE. Les quatre noms de categorie sont refuses comme
  --      qualification, et les 39 identifiants sont acceptes.
  SELECT count(*) INTO v_n FROM public.infractions_categories c
   WHERE public.infraction_canonique(c.id) IS NOT NULL;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- % categorie(s) acceptee(s) comme qualification', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.infractions i
   WHERE public.infraction_canonique(i.id) IS DISTINCT FROM i.id;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- % infraction(s) non resolue(s) sur elle-meme', v_n; END IF;

  -- P8 : LA RESOLUTION EST FAIL CLOSED.
  IF public.infraction_canonique('zz_infraction_inexistante') IS NOT NULL
     OR public.infraction_canonique(NULL) IS NOT NULL
     OR public.infraction_canonique('') IS NOT NULL THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- un identifiant inconnu est accepte';
  END IF;

  -- P9 : LES BORNES SONT CALCULABLES POUR LES 39, et jamais degenerees.
  SELECT count(*) INTO v_n FROM public.infractions i,
       LATERAL public.infraction_peine_bornes(i.id) b
   WHERE coalesce((b->>'ok')::boolean, false) IS NOT TRUE
      OR (b->>'jours_min')::int < 1
      OR (b->>'jours_min')::int > (b->>'jours_max')::int
      OR (b->>'amende_min')::int < 0
      OR (b->>'amende_min')::int > (b->>'amende_max')::int;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- % infraction(s) aux bornes incoherentes', v_n; END IF;

  -- P10 : L'ATTENUATION INEXPRIMABLE EST SIGNALEE, et sur les HUIT infractions a 1 jour
  --       exactement -- ni plus, ni moins. L'inventaire en annoncait sept : il avait compte les
  --       sept baremes sans acte et oublie `vol`, qui vaut aussi 1 jour. Si le canon change, ce
  --       compte change avec lui et cette preuve le dira.
  SELECT count(*) INTO v_n FROM public.infractions i,
       LATERAL public.infraction_peine_bornes(i.id) b
   WHERE (b->>'plancher_technique')::boolean;
  IF v_n <> 8 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- % infraction(s) signalee(s) au lieu de 8', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.infractions WHERE jours_reference = 1;
  IF v_n <> 8 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- % infraction(s) a 1 jour de reference au lieu de 8', v_n; END IF;
  -- Et le signal porte bien sur CELLES-LA : l'ensemble signale est exactement l'ensemble a 1 jour.
  SELECT count(*) INTO v_n FROM public.infractions i,
       LATERAL public.infraction_peine_bornes(i.id) b
   WHERE ((b->>'plancher_technique')::boolean) <> (i.jours_reference = 1);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- % infraction(s) mal signalee(s)', v_n; END IF;

  -- P11 : AUCUNE BORNE BASSE N'EST NULLE, et aucune n'est negative. C'est la seule chose que le
  --       cahier des charges exigeait sans arbitrage : ne jamais produire une peine incoherente.
  SELECT count(*) INTO v_n FROM public.infractions i,
       LATERAL public.infraction_peine_bornes(i.id) b
   WHERE (b->>'jours_min')::int <= 0;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P11 ECHOUEE -- % peine(s) plancher nulle(s)', v_n; END IF;

  -- P12 : AUCUN BAREME N'A ETE ETENDU AUX AUTRES EMPIRES. Le catalogue est celui de `republic`,
  --       et il ne porte pas de colonne de pays : l'etendre serait un arbitrage.
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'infractions'
     AND column_name IN ('country', 'pays');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P12 ECHOUEE -- le catalogue porte un pays'; END IF;

  -- P13 : LE PENDANT SQL DE L'EMPREINTE TRIE EN COLLATE "C". Sans lui, Python et PostgreSQL
  --       trient differemment des qu'un identifiant porte un souligne -- et ils en portent tous.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'infractions_empreinte_reelle';
  IF position('COLLATE "C"' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P13 ECHOUEE -- l''empreinte SQL ne trie pas en COLLATE "C"';
  END IF;

  RAISE NOTICE 'LES 13 PREUVES SONT VERTES.';
END
$preuves$;
