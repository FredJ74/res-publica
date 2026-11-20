-- CRIMINALITÉ — laissez-passer, mécanisme définitif (réponses de Fred du 20/11/2026, GAME-DESIGN-CRIMINALITE.md,
-- « Décisions du 20/11/2026 », point 13 et suivants). Idempotente. Essayée d'abord dans une transaction annulée.
--  • Un registre par lieu (archives d'écoute, QHS ; goulag à son ouverture) : chaque laissez-passer y est inscrit avec un nom.
--  • À l'entrée, le contrôle vérifie que le document présenté est valide au registre, pas que le porteur porte ce nom
--    (un laissez-passer volé fonctionne). Chaque passage est consigné avec le nom inscrit (journal des autorités qui délivrent).
--  • Vrai : permanent tant que l'habilitation n'est pas retirée ; le retrait l'invalide partout (confisqué s'il est dans
--    l'inventaire du titulaire). Faux réussi (greffe ou imprimante) : accepté comme un vrai pour UN SEUL passage, puis consommé ;
--    le faussaire choisit le nom inscrit.
--  • QHS : tout le monde peut s'y rendre (le taxi dépose devant), seuls les porteurs d'un laissez-passer valide entrent.
--    Délivré par le ministre de la Justice ou un juge (pays de son mandat).
BEGIN;

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

-- ── Registre et journal ──────────────────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.crim_laissez_passer (
  id text PRIMARY KEY, lieu text NOT NULL, pays text NOT NULL, nom text NOT NULL, faux boolean NOT NULL DEFAULT false,
  valide boolean NOT NULL DEFAULT true, delivre_par text, delivre_le timestamptz NOT NULL DEFAULT now(),
  retire_le timestamptz, consomme_le timestamptz);
CREATE INDEX IF NOT EXISTS crim_laissez_passer_lieu ON public.crim_laissez_passer (lieu, pays, nom) WHERE valide;
ALTER TABLE public.crim_laissez_passer ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_laissez_passer FROM anon, authenticated;
CREATE TABLE IF NOT EXISTS public.crim_laissez_passer_passages (
  id bigserial PRIMARY KEY, lieu text NOT NULL, pays text NOT NULL, document text NOT NULL, nom_inscrit text NOT NULL,
  le timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS crim_laissez_passer_passages_lieu ON public.crim_laissez_passer_passages (lieu, pays, le DESC);
ALTER TABLE public.crim_laissez_passer_passages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.crim_laissez_passer_passages FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.crim_laissez_passer_passages_id_seq FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.crim_lp_libelle_interne(p_lieu text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_lieu WHEN 'archives_ecoute' THEN 'archives d''écoute' WHEN 'qhs' THEN 'QHS' WHEN 'goulag' THEN 'goulag' END;
$$;
-- Le document : rien n'y distingue un faux d'un vrai (le registre seul le sait).
CREATE OR REPLACE FUNCTION public.crim_lp_objet_interne(p_id text, p_lieu text, p_pays text, p_nom text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('id', p_id, 'type', 'laissez_passer', 'laissez_passer', p_lieu, 'pays', p_pays, 'titulaire', p_nom,
    'name', 'Laissez-passer — ' || public.crim_lp_libelle_interne(p_lieu), 'icon', 'ti-id-badge', 'legal', true, 'stackable', false,
    'desc', 'Au nom de ' || p_nom || '. ' || CASE p_lieu
      WHEN 'archives_ecoute' THEN 'Ouvre les archives des centres d''écoute de Sovarka à qui le présente.'
      WHEN 'qhs' THEN 'Ouvre l''entrée du Quartier de Haute Sécurité à qui le présente.'
      ELSE 'Ouvre l''accès à qui le présente.' END);
$$;
CREATE OR REPLACE FUNCTION public.crim_lp_emettre_interne(p_lieu text, p_pays text, p_nom text, p_par text, p_faux boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_id text := 'lp-' || replace(gen_random_uuid()::text, '-', '');
BEGIN
  IF public.crim_lp_libelle_interne(p_lieu) IS NULL OR coalesce(btrim(p_nom), '') = '' THEN RETURN NULL; END IF;
  INSERT INTO public.crim_laissez_passer (id, lieu, pays, nom, faux, delivre_par) VALUES (v_id, p_lieu, p_pays, btrim(p_nom), p_faux, p_par);
  RETURN public.crim_lp_objet_interne(v_id, p_lieu, p_pays, btrim(p_nom));
END $$;
-- Un vrai laissez-passer remis au titulaire (inventaire, sinon sas de réception).
CREATE OR REPLACE FUNCTION public.crim_lp_delivrer_interne(p_nom text, p_lieu text, p_pays text, p_par text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE o jsonb := public.crim_lp_emettre_interne(p_lieu, p_pays, p_nom, p_par, false); r jsonb;
BEGIN
  IF o IS NULL THEN RETURN NULL; END IF;
  r := public.inventaire_deposer_interne(p_nom, o);
  IF coalesce((r ->> 'ok')::boolean, false) IS NOT TRUE THEN
    INSERT INTO public.objets_recus (id, destinataire, expediteur, data) VALUES (o ->> 'id', p_nom, coalesce(p_par, 'Administration'), o);
  END IF;
  RETURN o;
END $$;
-- Le porteur détient-il un document valide pour ce lieu ? (sans le présenter)
CREATE OR REPLACE FUNCTION public.crim_lp_valide_detenu_interne(p_porteur text, p_lieu text, p_pays text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees d,
                   jsonb_array_elements(CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) e
                   JOIN public.crim_laissez_passer l ON l.id = e ->> 'id'
                  WHERE d.name = p_porteur AND l.lieu = p_lieu AND l.pays = p_pays AND l.valide);
$$;
-- Présentation à l'entrée : un vrai de préférence ; passage consigné au nom inscrit ; un faux est consommé.
CREATE OR REPLACE FUNCTION public.crim_lp_presenter_interne(p_porteur text, p_lieu text, p_pays text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_inv jsonb; v_pos integer; v_id text; v_nom text; v_faux boolean;
BEGIN
  SELECT CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END INTO v_inv
    FROM public.personnages_donnees WHERE name = p_porteur FOR UPDATE;
  SELECT (t.o - 1)::integer, lp.id, lp.nom, lp.faux INTO v_pos, v_id, v_nom, v_faux
    FROM jsonb_array_elements(coalesce(v_inv, '[]'::jsonb)) WITH ORDINALITY t(e, o)
    JOIN public.crim_laissez_passer lp ON lp.id = t.e ->> 'id'
   WHERE lp.lieu = p_lieu AND lp.pays = p_pays AND lp.valide
   ORDER BY lp.faux, t.o LIMIT 1;
  IF v_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'laissez_passer_requis'); END IF;
  INSERT INTO public.crim_laissez_passer_passages (lieu, pays, document, nom_inscrit) VALUES (p_lieu, p_pays, v_id, v_nom);
  IF v_faux THEN
    UPDATE public.crim_laissez_passer SET valide = false, consomme_le = now() WHERE id = v_id;
    UPDATE public.personnages_donnees SET inventory = inventory - v_pos, updated_at = now() WHERE name = p_porteur;
  END IF;
  RETURN jsonb_build_object('ok', true, 'nom', v_nom);
END $$;
-- Retrait de l'habilitation : tous les vrais au nom du titulaire deviennent invalides partout ; confisqués s'ils sont chez lui.
CREATE OR REPLACE FUNCTION public.crim_lp_retirer_interne(p_nom text, p_lieu text, p_pays text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_ids text[];
BEGIN
  WITH r AS (UPDATE public.crim_laissez_passer SET valide = false, retire_le = now()
              WHERE nom = p_nom AND lieu = p_lieu AND pays = p_pays AND NOT faux AND valide RETURNING id)
  SELECT array_agg(id) INTO v_ids FROM r;
  IF v_ids IS NULL THEN RETURN 0; END IF;
  UPDATE public.personnages_donnees d
     SET inventory = coalesce((SELECT jsonb_agg(e ORDER BY o) FROM jsonb_array_elements(d.inventory) WITH ORDINALITY t(e, o)
                                WHERE NOT coalesce(e ->> 'id' = ANY (v_ids), false)), '[]'::jsonb), updated_at = now()
   WHERE d.name = p_nom AND jsonb_typeof(d.inventory) = 'array';
  DELETE FROM public.objets_recus WHERE id = ANY (v_ids);
  RETURN cardinality(v_ids);
END $$;
CREATE OR REPLACE FUNCTION public.crim_lp_journal_interne(p_lieu text, p_pays text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object('nom', nom_inscrit, 'le', le) ORDER BY le DESC), '[]'::jsonb)
    FROM (SELECT nom_inscrit, le FROM public.crim_laissez_passer_passages WHERE lieu = p_lieu AND pays = p_pays ORDER BY le DESC LIMIT 50) s;
$$;

-- ── Anciennes briques (décisions du matin) : même nom, nouveau mécanisme ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_detenu_interne(p_nom text, p_genre text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_lp_valide_detenu_interne(p_nom, p_genre,
    CASE WHEN p_genre = 'archives_ecoute' THEN 'soviet' ELSE (SELECT country FROM public.personnages_donnees WHERE name = p_nom) END);
$$;
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_remettre_interne(p_nom text, p_genre text, p_par text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_lp_delivrer_interne(p_nom, p_genre, 'soviet', p_par) WHERE p_genre = 'archives_ecoute';
$$;
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_confisquer_interne(p_nom text, p_genre text)
RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_lp_retirer_interne(p_nom, p_genre, 'soviet');
$$;
-- crim_laissez_passer_objet_interne (décisions du matin) n'est plus appelée ; laissée en place, sans effet.

-- ── Archives d'écoute : chaque consultation est un passage (un faux sert une fois) ; journal pour le ministre ───────
SELECT pg_temp.rp_raccorder('public.sovarka_ecoute_archives_consulter(text,text)'::regprocedure,
  E'v_paie := public.payer_ordre(a, ''consulter_archives_ecoute'', 1, 0);\n  IF coalesce((v_paie->>''ok'')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;',
  E'v_paie := public.payer_ordre(a, ''consulter_archives_ecoute'', 1, 0);\n  IF coalesce((v_paie->>''ok'')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;\n  PERFORM public.crim_lp_presenter_interne(a, ''archives_ecoute'', ''soviet''); /* crim_lp_passage_v1 */',
  'crim_lp_passage_v1');
SELECT pg_temp.rp_raccorder('public.sovarka_habilitations_lire()'::regprocedure,
  $a$FROM public.sovarka_habilitations_ecoute h), '[]'::jsonb));$a$,
  $b$FROM public.sovarka_habilitations_ecoute h), '[]'::jsonb))
    || jsonb_build_object('passages', public.crim_lp_journal_interne('archives_ecoute', 'soviet')); /* crim_lp_journal_v1 */$b$,
  'crim_lp_journal_v1');

-- ── QHS : le taxi dépose devant ; l'entrée demande un laissez-passer valide ───────────────────────────────────────
SELECT pg_temp.rp_raccorder('public.transport_effectuer(text,text,text,uuid)'::regprocedure,
  $a$IF b IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','arrivee_non_referencee');END IF;$a$,
  $b$IF b IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','arrivee_non_referencee');END IF;
 IF p_mode='taxi_qhs' THEN b:=NULL;piece:=NULL;END IF; /* crim_qhs_acces_v1 : devant le QHS, l'entrée se contrôle à la porte */$b$,
  'crim_qhs_acces_v1');
SELECT pg_temp.rp_raccorder('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure,
  $a$ SELECT * INTO l FROM public.navigation_lieux_regles WHERE pays=p.country AND ville=p.current_city AND batiment=p_batiment;$a$,
  $b$ IF p_batiment='qhs-prison' AND p.current_city='qhs' AND p.current_building IS DISTINCT FROM 'qhs-prison'
    AND jsonb_typeof(p.est_emprisonne) IS DISTINCT FROM 'object'
    AND NOT (jsonb_typeof(p.detention_qhs)='object' AND (p.detention_qhs->>'enQHS')::boolean IS TRUE) THEN /* crim_qhs_acces_v1 */
  IF p_verifier THEN
   IF NOT public.crim_lp_valide_detenu_interne(p_nom,'qhs',p.country) THEN RETURN jsonb_build_object('ok',false,'raison','laissez_passer_requis'); END IF;
  ELSE
   r:=public.crim_lp_presenter_interne(p_nom,'qhs',p.country);
   IF NOT coalesce((r->>'ok')::boolean,false) THEN RETURN r; END IF;
  END IF;
 END IF;
 SELECT * INTO l FROM public.navigation_lieux_regles WHERE pays=p.country AND ville=p.current_city AND batiment=p_batiment;$b$,
  'crim_qhs_acces_v1');

-- Autorité qui délivre au QHS : un juge (pays de son tribunal) ou le ministre de la Justice (pays de son mandat).
CREATE OR REPLACE FUNCTION public.crim_lp_autorite_qhs_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT j.pays FROM public.juge_moi() j LIMIT 1),
                  (SELECT public.crim_qhs_pays_mandat_interne(p_nom) FROM public.personnages_donnees
                    WHERE name = p_nom AND poste ->> 'id' = 'min_just'));
$$;
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_qhs_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_pays text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_pays := public.crim_lp_autorite_qhs_interne(a);
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'valides', coalesce((SELECT jsonb_agg(jsonb_build_object('nom', nom, 'par', delivre_par, 'le', delivre_le) ORDER BY delivre_le DESC)
                           FROM public.crim_laissez_passer WHERE lieu = 'qhs' AND pays = v_pays AND valide AND NOT faux), '[]'::jsonb),
    'passages', public.crim_lp_journal_interne('qhs', v_pays));
END $$;
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_qhs_delivrer(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_pays text; n text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_pays := public.crim_lp_autorite_qhs_interne(a);
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  SELECT name INTO n FROM public.personnages_donnees WHERE lower(name) = lower(btrim(p_nom)) LIMIT 1;
  IF n IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('crim_lp:qhs:' || v_pays || ':' || n, 0));
  IF EXISTS (SELECT 1 FROM public.crim_laissez_passer WHERE lieu = 'qhs' AND pays = v_pays AND nom = n AND valide AND NOT faux) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_habilite'); END IF;
  PERFORM public.crim_lp_delivrer_interne(n, 'qhs', v_pays, a);
  PERFORM public.mail_systeme_poser_interne('Justice', n, 'Laissez-passer du QHS',
    a || ' vous délivre un laissez-passer pour le Quartier de Haute Sécurité. Il ouvre l''entrée à qui le présente ; '
    || 'il reste valable tant qu''il n''est pas retiré.');
  RETURN public.crim_laissez_passer_qhs_lire() || jsonb_build_object('accorde', n);
END $$;
CREATE OR REPLACE FUNCTION public.crim_laissez_passer_qhs_retirer(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_pays text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_pays := public.crim_lp_autorite_qhs_interne(a);
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  IF public.crim_lp_retirer_interne(btrim(p_nom), 'qhs', v_pays) = 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_habilite'); END IF;
  PERFORM public.mail_systeme_poser_interne('Justice', btrim(p_nom), 'Laissez-passer du QHS retiré',
    a || ' vous retire votre laissez-passer du Quartier de Haute Sécurité : il n''ouvre plus rien.');
  RETURN public.crim_laissez_passer_qhs_lire() || jsonb_build_object('retire', btrim(p_nom));
END $$;

-- ── Faux laissez-passer : le faussaire choisit le lieu et le nom (p_doc = 'faux_laissez_passer|lieu|pays|nom') ─────
CREATE OR REPLACE FUNCTION public.faux_lp_parametres_interne(p_doc text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN split_part(p_doc, '|', 1) <> 'faux_laissez_passer' THEN NULL
    WHEN p_doc = 'faux_laissez_passer' THEN jsonb_build_object('lieu', 'archives_ecoute', 'pays', 'soviet', 'nom', NULL)
    WHEN split_part(p_doc, '|', 2) NOT IN ('archives_ecoute', 'qhs') OR split_part(p_doc, '|', 3) !~ '^[a-z]{3,12}$'
      OR length(btrim(split_part(p_doc, '|', 4))) NOT BETWEEN 1 AND 60 THEN NULL
    ELSE jsonb_build_object('lieu', split_part(p_doc, '|', 2),
      'pays', CASE WHEN split_part(p_doc, '|', 2) = 'archives_ecoute' THEN 'soviet' ELSE split_part(p_doc, '|', 3) END,
      'nom', btrim(split_part(p_doc, '|', 4))) END;
$$;
CREATE OR REPLACE FUNCTION public.faux_document_objet_interne(p_doc text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN split_part(p_doc, '|', 1) = 'faux_laissez_passer' THEN
      CASE WHEN public.faux_lp_parametres_interne(p_doc) IS NOT NULL THEN jsonb_build_object(
        'name', 'Laissez-passer — ' || public.crim_lp_libelle_interne(public.faux_lp_parametres_interne(p_doc) ->> 'lieu'),
        'icon', 'ti-id-badge', 'desc', 'Laissez-passer') END
    WHEN p_doc = 'fausse_identite' THEN '{"name":"Fausse identite","icon":"ti-id-badge","desc":"Change votre nom affiche dans le jeu temporairement."}'::jsonb
    WHEN p_doc = 'faux_permis' THEN '{"name":"Faux permis de construire","icon":"ti-building","desc":"Permet de construire sans passer par la mairie."}'::jsonb
    WHEN p_doc = 'faux_contrat' THEN '{"name":"Faux contrat commercial","icon":"ti-file-text","desc":"Legitime une transaction illegale ou un transfert."}'::jsonb
    WHEN p_doc = 'fausse_convocation' THEN '{"name":"Fausse convocation officielle","icon":"ti-mail","desc":"Attire un PJ dans un lieu de votre choix."}'::jsonb
  END; /* crim_faux_lp_v2 */
$$;
-- Faux réussi : inscrit au registre (faux, un passage), document identique à un vrai.
CREATE OR REPLACE FUNCTION public.faux_document_final_interne(p_doc_objet jsonb, p_doc text, p_auteur text)
RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN public.faux_lp_parametres_interne(p_doc) IS NOT NULL THEN
      public.crim_lp_emettre_interne(public.faux_lp_parametres_interne(p_doc) ->> 'lieu', public.faux_lp_parametres_interne(p_doc) ->> 'pays',
        coalesce(public.faux_lp_parametres_interne(p_doc) ->> 'nom', p_auteur), p_auteur, true)
    ELSE p_doc_objet || jsonb_build_object('id', 'faux-' || replace(gen_random_uuid()::text, '-', ''),
           'type', 'document_falsifie', 'docId', p_doc, 'legal', false) END;
$$;

-- ── Droits ───────────────────────────────────────────────────────────────────────────────────────────────────────
DO $$ DECLARE f text; BEGIN
  FOREACH f IN ARRAY ARRAY['crim_lp_emettre_interne(text,text,text,text,boolean)', 'crim_lp_delivrer_interne(text,text,text,text)',
    'crim_lp_valide_detenu_interne(text,text,text)', 'crim_lp_presenter_interne(text,text,text)', 'crim_lp_retirer_interne(text,text,text)',
    'crim_lp_journal_interne(text,text)', 'crim_lp_autorite_qhs_interne(text)', 'crim_lp_objet_interne(text,text,text,text)',
    'crim_lp_libelle_interne(text)', 'faux_lp_parametres_interne(text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
  FOREACH f IN ARRAY ARRAY['crim_laissez_passer_qhs_lire()', 'crim_laissez_passer_qhs_delivrer(text)', 'crim_laissez_passer_qhs_retirer(text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

COMMIT;
