-- CRIMINALITÉ — LOT 9 : CARRIÈRE CRIMINELLE (GAME-DESIGN-CRIMINALITE.md § 15 ; Fred, 19/11/2026, nuit).
-- • Seconde carrière par le socle universitaire existant (universite_cursus / _jalons / _inscriptions, carrieres_acquises,
--   règles du 13/10 : une seule seconde carrière dans la vie, deux mois, gratuit) : nouveau cursus « Droit pénal »
--   (univ_droit_penal) qui délivre la carrière criminal_c. 17 cours à l'amphithéâtre de l'université de Luthécia et 7 stages
--   chez Pat Hounette (Place du Formulaire de la Liberté) — ou au siège d'une organisation criminelle dont l'étudiant est
--   membre (crim_stage_organisation_interne, raccord crim_stage_orga_v1 de universite_valider_etape).
-- • Ouverture contrôlée par le serveur : colonne universite_cursus.ouvert (seul « Droit pénal » est ouvert) ; universite_inscrire
--   refuse un cursus fermé (raccord crim_cursus_ouvert_v1), universite_mon_etat ne propose que les cursus ouverts
--   (raccord crim_cursus_ouvert_v2). Médecine, affaires, justice et armée restent fermés (ils l'étaient de fait : l'ordre
--   « Suivre une formation » était désactivé à l'écran) : à ouvrir par Fred.
-- • Correctif technique : les jalons existants désignaient les villes par leur nom ('luthecia', 'port-sainte-marie') alors que
--   la position des personnages utilise l'identifiant ('capitale', 'ville_a') ; aucun jalon n'était validable. Identifiants rétablis.
-- • Effets de la carrière : UNIQUEMENT les bonus de réussite déjà posés dans les fonctions de taux des lots 2 à 8 (+15 neutraliser,
--   voler, crocheter, empoisonner, explosifs, incendie ; +10 effraction ; +5 au butin du vol ; rien sur la corruption ;
--   +15 au vol aussi pour renseignement et escort). La carrière se lit désormais par crim_carriere_interne(nom), qui tient compte
--   de la carrière initiale ET de la seconde carrière (carriere_possede) : raccords crim_carriere_v1 des actes qui lisaient
--   personnages_donnees.career. Aucun autre avantage ; les achats au marché noir ne sont pas touchés.
BEGIN;

-- ── Ouverture des cursus (le serveur décide) ────────────────────────────────────────────────────────────────────────
ALTER TABLE public.universite_cursus ADD COLUMN IF NOT EXISTS ouvert boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.universite_cursus.ouvert IS
  'Inscriptions ouvertes (refus cursus_ferme sinon ; liste de universite_mon_etat filtrée). Criminalité lot 9, 20/11/2026.';

-- ── Correctif : identifiants de ville des jalons ────────────────────────────────────────────────────────────────────
UPDATE public.universite_cursus_jalons SET ville = 'capitale' WHERE ville = 'luthecia';
UPDATE public.universite_cursus_jalons SET ville = 'ville_a' WHERE ville = 'port-sainte-marie';

-- ── Cursus « Droit pénal » → carrière criminelle ────────────────────────────────────────────────────────────────────
INSERT INTO public.universite_cursus (id, libelle, carriere, semaines_theoriques, cout_pa, cout_fr, prerequis, note, ouvert)
VALUES ('univ_droit_penal', 'Droit pénal — seconde carrière', 'criminal_c', 8, 0, 0, '{}'::jsonb,
        'Formation gratuite : 17 cours et 7 missions de stage chez Pat Hounette ou dans une organisation criminelle', true)
ON CONFLICT (id) DO UPDATE SET libelle = EXCLUDED.libelle, carriere = EXCLUDED.carriere,
  semaines_theoriques = EXCLUDED.semaines_theoriques, cout_pa = 0, cout_fr = 0, note = EXCLUDED.note, ouvert = true;

-- Même grille que les autres cursus (24 jalons ; un stage aux rangs 6, 9, … 24). La « note » d'un stage est l'objectif que
-- l'écran renvoie à universite_valider_etape.
INSERT INTO public.universite_cursus_jalons (id, cursus, rang, libelle, genre, batiment, ville, piece, note)
SELECT 'univ_penal_' || lpad(r::text, 2, '0'), 'univ_droit_penal', r,
       CASE WHEN s.note IS NULL THEN 'Cours ' || c || ' — Droit pénal'
            ELSE 'Stage semaine ' || (r / 3) || ' — chez Pat Hounette ou au siège de votre organisation criminelle — ' || s.note END,
       CASE WHEN s.note IS NULL THEN 'universite' ELSE 'terrain' END,
       CASE WHEN s.note IS NULL THEN 'universite' ELSE 'place-formulaire-liberte' END,
       'capitale',
       CASE WHEN s.note IS NULL THEN 'amphi' ELSE 'place' END,
       coalesce(s.note, 'Séance pédagogique ' || c)
  FROM generate_series(1, 24) r
  LEFT JOIN (VALUES (6, 'Lire le Code pénal à l’envers'), (9, 'Repérer les failles d’une procédure'),
                    (12, 'Mémoriser les délais de prescription'), (15, 'Préparer un alibi crédible'),
                    (18, 'Suivre quelqu’un sans être vu'), (21, 'Distinguer un délit d’un crime, et leurs peines'),
                    (24, 'Soutenir son mémoire devant Pat Hounette')) s(rang, note) ON s.rang = r
  CROSS JOIN LATERAL (SELECT r - (SELECT count(*) FROM (VALUES (6),(9),(12),(15),(18),(21),(24)) t(x) WHERE t.x < r) AS c) k
ON CONFLICT (id) DO UPDATE SET cursus = EXCLUDED.cursus, rang = EXCLUDED.rang, libelle = EXCLUDED.libelle, genre = EXCLUDED.genre,
  batiment = EXCLUDED.batiment, ville = EXCLUDED.ville, piece = EXCLUDED.piece, note = EXCLUDED.note;

-- ── Stage au siège d'une organisation criminelle ────────────────────────────────────────────────────────────────────
-- Un stage (jalon « terrain ») d'un cursus qui mène à la carrière criminelle peut aussi se valider au siège (localId
-- « bâtiment:pièce ») d'une organisation de type criminelle dont l'étudiant est membre. Le maître de stage PNJ garantit la
-- progression sans autre joueur.
CREATE OR REPLACE FUNCTION public.crim_stage_organisation_interne(p_nom text, p_cursus text, p_genre text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT p_genre = 'terrain'
     AND EXISTS (SELECT 1 FROM public.universite_cursus u WHERE u.id = p_cursus AND u.carriere = 'criminal_c')
     AND EXISTS (
       SELECT 1 FROM public.personnages_donnees d, public.organisations o
        WHERE d.name = p_nom AND d.current_building IS NOT NULL
          AND (o.data::jsonb) ->> 'type' = 'criminelle'
          AND (o.data::jsonb) ->> 'localId' IN (d.current_building || ':' || coalesce(d.current_room, ''), d.current_building)
          AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce((o.data::jsonb) -> 'membres', '[]'::jsonb)) m
                       WHERE m ->> 'nom' = p_nom));
$$;

-- ── Carrière effective pour les bonus de réussite ───────────────────────────────────────────────────────────────────
-- Carrière initiale OU seconde carrière (carriere_possede). Priorité à la carrière qui porte un bonus : criminelle, puis
-- renseignement et escort (+15 au vol seulement, dans crim_voler_taux_interne).
CREATE OR REPLACE FUNCTION public.crim_carriere_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN public.carriere_possede(p_nom, 'criminal_c') THEN 'criminal_c'
              WHEN public.carriere_possede(p_nom, 'intel') THEN 'intel'
              WHEN public.carriere_possede(p_nom, 'escort') THEN 'escort'
              ELSE public.carriere_initiale(p_nom) END;
$$;

-- ── Raccords (un ancrage par fonction ; idempotents par marque) ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Université : cursus fermé refusé, liste filtrée, stage en organisation criminelle.
SELECT pg_temp.rp_raccorder('public.universite_inscrire(text,text)'::regprocedure,
  $a$IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cursus_inconnu'); END IF;$a$,
  $b$IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'cursus_inconnu'); END IF;
  IF NOT coalesce(v_cur.ouvert, false) THEN RETURN jsonb_build_object('ok', false, 'raison', 'cursus_ferme'); END IF; /* crim_cursus_ouvert_v1 */$b$,
  'crim_cursus_ouvert_v1');

SELECT pg_temp.rp_raccorder('public.universite_mon_etat()'::regprocedure,
  $a$WHERE NOT public.carriere_possede(v_moi, u.carriere)$a$,
  $b$WHERE NOT public.carriere_possede(v_moi, u.carriere) AND u.ouvert /* crim_cursus_ouvert_v2 */$b$,
  'crim_cursus_ouvert_v2');

SELECT pg_temp.rp_raccorder('public.universite_valider_etape(text,text)'::regprocedure,
  $a$ if v_pos.current_city is distinct from v_step->>'ville'
   or v_pos.current_building is distinct from v_step->>'batiment'
   or (v_step->>'piece' is not null and v_pos.current_room is distinct from v_step->>'piece') then$a$,
  $b$ if (v_pos.current_city is distinct from v_step->>'ville'
   or v_pos.current_building is distinct from v_step->>'batiment'
   or (v_step->>'piece' is not null and v_pos.current_room is distinct from v_step->>'piece'))
   and not public.crim_stage_organisation_interne(v_moi, v_ins.cursus, v_step->>'genre') /* crim_stage_orga_v1 */ then$b$,
  'crim_stage_orga_v1');

-- Actes : la carrière lue est la carrière effective (initiale ou seconde).
SELECT pg_temp.rp_raccorder('public.crime_neutraliser(text,text,uuid)'::regprocedure,
  $a$SELECT name, career, stats, inventory, resources, est_emprisonne, current_building INTO m$a$,
  $b$SELECT name, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */, stats, inventory, resources, est_emprisonne, current_building INTO m$b$,
  'crim_carriere_v1');
SELECT pg_temp.rp_raccorder('public.crime_voler(text,text,text,uuid)'::regprocedure,
  $a$SELECT name, career, country, est_emprisonne INTO m$a$,
  $b$SELECT name, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */, country, est_emprisonne INTO m$b$,
  'crim_carriere_v1');
SELECT pg_temp.rp_raccorder('public.crim_crocheter(text,text,uuid)'::regprocedure,
  $a$SELECT name, career, est_emprisonne, inventory INTO m$a$,
  $b$SELECT name, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */, est_emprisonne, inventory INTO m$b$,
  'crim_carriere_v1');
SELECT pg_temp.rp_raccorder('public.crim_forcer_porte(text,text,uuid)'::regprocedure,
  $a$SELECT name, career, est_emprisonne, inventory INTO m$a$,
  $b$SELECT name, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */, est_emprisonne, inventory INTO m$b$,
  'crim_carriere_v1');
SELECT pg_temp.rp_raccorder('public.crim_cambrioler_interne(text,text,text,uuid)'::regprocedure,
  $a$SELECT name, career, country, current_city, current_building, current_room, est_emprisonne, inventory INTO m$a$,
  $b$SELECT name, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */, country, current_city, current_building, current_room, est_emprisonne, inventory INTO m$b$,
  'crim_carriere_v1');
SELECT pg_temp.rp_raccorder('public.crime_empoisonner(text,uuid)'::regprocedure,
  $a$SELECT name, career, country, inventory, est_emprisonne INTO m$a$,
  $b$SELECT name, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */, country, inventory, est_emprisonne INTO m$b$,
  'crim_carriere_v1');
SELECT pg_temp.rp_raccorder('public.crime_explosifs(text,uuid)'::regprocedure,
  $a$SELECT country, current_city, current_building, current_room, career, inventory, est_emprisonne INTO m$a$,
  $b$SELECT country, current_city, current_building, current_room, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */, inventory, est_emprisonne INTO m$b$,
  'crim_carriere_v1');
SELECT pg_temp.rp_raccorder('public.crime_incendier(text,uuid)'::regprocedure,
  $a$SELECT country, current_city, current_building, career, est_emprisonne INTO m$a$,
  $b$SELECT country, current_city, current_building, public.crim_carriere_interne(name) AS career /* crim_carriere_v1 */, est_emprisonne INTO m$b$,
  'crim_carriere_v1');
SELECT pg_temp.rp_raccorder('public.assemblee_neutraliser_depute(text,text,text,text)'::regprocedure,
  $a$public.assemblee_taux_neutralisation(p_mode, v_perso.stats, v_perso.career)$a$,
  $b$public.assemblee_taux_neutralisation(p_mode, v_perso.stats, public.crim_carriere_interne(v_perso.name) /* crim_carriere_v1 */)$b$,
  'crim_carriere_v1');

-- PA restants renvoyés par le serveur après une étape (l'écran recopie la valeur, sans calcul).
SELECT pg_temp.rp_raccorder('public.universite_valider_etape(text,text)'::regprocedure,
  $a$return jsonb_build_object('ok',true,'jalon',p_jalon,'pa_preleves',(v_step->>'pa')::int);$a$,
  $b$return jsonb_build_object('ok',true,'jalon',p_jalon,'pa_preleves',(v_step->>'pa')::int,
   'pa',(select d.pa from public.personnages_donnees d where d.name=v_moi)); /* crim_univ_pa_v1 */$b$,
  'crim_univ_pa_v1');

COMMIT;
