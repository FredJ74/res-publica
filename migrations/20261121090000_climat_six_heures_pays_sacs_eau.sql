-- CLIMAT — version définitive des décisions de Fred du 21/11/2026 (GAME-DESIGN-CLIMAT-20261121.md, remplace la version du
-- matin : 12 heures → 6 heures, etc.). Complète 20261121070000 (gare jamais inondée, accueil du nouveau personnage).
-- • Crue, orage, canicule, brouillard : 6 heures. Tous leurs effets lisent la fenêtre debut/fin (rien d'autre à raccourcir).
--   Le blizzard (coup ponctuel) ne change pas.
-- • Crue : un lieu protégé par des sacs de sable reste OUVERT et garde ses stocks ; seuls les lieux tirés non protégés sont
--   fermés et perdent 20 %. Un sac suffit, pour une crue (plafond ramené à 1 : la pose n'en consomme plus qu'un).
-- • Un seul événement à la fois par pays : un épisode (un événement propagé de ville en ville, ou un événement isolé) ne
--   commence qu'après la fin du précédent PLUS le préavis de 48 heures, si bien que deux alertes d'événements différents ne
--   coexistent jamais. Un tirage qui tomberait pendant un épisode est reporté (climat_espacer_interne, à chaque passage).
-- • Textes de consigne (point 7) : un seul texte serveur par type et par ville, repris par la presse, le journal des
--   événements, le message du gouvernement, la fenêtre de l'alerte et la fenêtre d'accueil. Lieux de vente vérifiés
--   (climat_lieux_vente) ; le texte cite ceux de la ville, à défaut ceux du pays.
-- • Eau gratuite : points d'eau en configuration (climat_points_eau) ; « Remplir une bouteille d'eau », 0 PA.
--   Premier point : la fontaine de la statue de l'Ours, place de l'Ours, à Krasnov.
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- ── Durées : 6 heures ────────────────────────────────────────────────────────────────────────────
UPDATE public.climat_parametres SET duree_heures = 6 WHERE type IN ('crue', 'orage', 'canicule', 'brouillard');
UPDATE public.climat_evenements SET fin = debut + interval '6 hours'
 WHERE type IN ('crue', 'orage', 'canicule', 'brouillard') AND fin_traitee_le IS NULL AND fin > debut + interval '6 hours';
UPDATE public.equipements_installes g SET objet = jsonb_set(g.objet, '{actif_jusqu}', to_jsonb(e.fin))
  FROM public.climat_evenements e
 WHERE g.generique_id = 'groupe-electrogene' AND e.type = 'orage' AND NOT e.annule AND e.effets_le IS NOT NULL
   AND e.fin_traitee_le IS NULL AND g.pays = e.pays AND g.ville = e.ville
   AND (g.objet->>'actif_jusqu')::timestamptz > e.fin;

-- ── Crue : lieu protégé ouvert, stocks intacts ───────────────────────────────────────────────────
INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('sacs_plafond', 1)
ON CONFLICT (cle) DO UPDATE SET valeur = 1;
-- Protégé : sacs posés avant la crue (rattachés à elle quand ses effets s'appliquent, ou encore en attente avant).
CREATE OR REPLACE FUNCTION public.climat_lieu_protege_interne(e public.climat_evenements, p_batiment text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.climat_protections zp
                  WHERE zp.pays = e.pays AND zp.ville = e.ville AND zp.batiment = p_batiment
                    AND (zp.evenement = e.id OR (zp.evenement IS NULL AND e.effets_le IS NULL)));
$$;
CREATE OR REPLACE FUNCTION public.climat_batiment_inonde_interne(p_pays text, p_ville text, p_batiment text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.climat_evenements e WHERE e.type = 'crue' AND e.pays = p_pays AND e.ville = p_ville AND NOT e.annule
                   AND e.alerte_le IS NOT NULL AND now() >= e.debut AND now() < e.fin
                   AND EXISTS (SELECT 1 FROM jsonb_array_elements(e.lieux) l WHERE l->>'batiment' = p_batiment)
                   AND NOT public.climat_lieu_protege_interne(e, p_batiment) /* climat_sacs_protegent_v1 */);
$$;
SELECT pg_temp.rp_raccorder('public.climat_crue_appliquer_interne(public.climat_evenements)'::regprocedure,
  $a$    v_id := e.pays || '_' || e.ville || '_' || v_bat;$a$,
  $b$    v_pct := CASE WHEN v_prot THEN 0 ELSE public.aliments_param_interne('crue_perte_pct', 20) END; /* climat_sacs_protegent_v1 */
    v_id := e.pays || '_' || e.ville || '_' || v_bat;$b$,
  'climat_sacs_protegent_v1');
SELECT pg_temp.rp_raccorder('public.sacs_sable_poser(uuid)'::regprocedure,
  $a$round(public.aliments_param_interne('crue_perte_pct', 20) * public.climat_sacs_reste_pct_interne(v_deja + v_n) / 100, 2)$a$,
  $b$0 /* climat_sacs_protegent_v1 */$b$,
  'climat_sacs_protegent_v1');

-- ── Un seul événement à la fois par pays ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.climat_nom_type_interne(p_type text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_type WHEN 'crue' THEN 'Crue' WHEN 'orage' THEN 'Orage' WHEN 'canicule' THEN 'Canicule'
                     WHEN 'brouillard' THEN 'Brouillard' WHEN 'blizzard' THEN 'Blizzard' ELSE 'Événement climatique' END;
$$;

-- Épisode : un événement propagé (fréquence « trimestre_propage », même période) ou un événement isolé.
-- Dans l'ordre des débuts, chaque épisode non commencé est décalé de jours entiers jusqu'à commencer après
-- (fin de l'épisode précédent + préavis). Un événement déjà annoncé mais décalé sera annoncé de nouveau à sa date.
CREATE OR REPLACE FUNCTION public.climat_espacer_interne(p_pays text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; v_borne timestamptz := '-infinity'; v_jour_min date; v_delta integer; v_n integer := 0;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('climat_espacer:' || p_pays));
  FOR r IN
    WITH ev AS (
      SELECT e.id, e.debut, e.fin, e.alerte_le, coalesce(c.preavis_heures, 48) AS preavis,
             CASE WHEN c.frequence = 'trimestre_propage' AND e.origine = 'calendrier' THEN e.type || ':' || e.periode ELSE 'ev:' || e.id END AS episode
        FROM public.climat_evenements e LEFT JOIN public.climat_parametres c ON c.type = e.type AND c.pays = e.pays
       WHERE e.pays = p_pays AND NOT e.annule)
    SELECT episode, min(debut) AS d0, max(fin) AS f1, max(preavis) AS preavis, count(*) AS n, min(id) AS id0,
           bool_or(now() >= debut) AS commence
      FROM ev GROUP BY episode HAVING max(fin) > now() - interval '7 days'
     ORDER BY min(debut), count(*) DESC, min(id)
  LOOP
    IF NOT r.commence AND v_borne > '-infinity' THEN
      -- Premier minuit (heure de Paris) à partir de la borne.
      v_jour_min := (v_borne AT TIME ZONE 'Europe/Paris')::date
                    + CASE WHEN (v_borne AT TIME ZONE 'Europe/Paris')::time > time '00:00' THEN 1 ELSE 0 END;
      v_delta := v_jour_min - (r.d0 AT TIME ZONE 'Europe/Paris')::date;
      IF v_delta > 0 THEN
        -- Correction publique si l'événement avait déjà été annoncé.
        INSERT INTO public.evenements_globaux (country, city, texte, jour)
        SELECT e.pays, e.ville, '⚠️ Prévisions corrigées : l''alerte « ' || lower(public.climat_nom_type_interne(e.type)) || ' » du '
               || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'DD/MM') || ' à ' || public.climat_nom_ville_interne(e.pays, e.ville)
               || ' est reportée au ' || to_char((e.debut AT TIME ZONE 'Europe/Paris')::date + v_delta, 'DD/MM')
               || ' : un seul événement climatique à la fois dans le pays. Une nouvelle alerte suivra.', NULL
          FROM public.climat_evenements e
         WHERE e.alerte_le IS NOT NULL AND NOT e.annule AND e.pays = p_pays
           AND (CASE WHEN r.episode LIKE 'ev:%' THEN e.id = r.id0
                     ELSE e.type || ':' || e.periode = r.episode AND e.origine = 'calendrier' END);
        UPDATE public.climat_evenements e
           SET debut = public.climat_minuit_interne((e.debut AT TIME ZONE 'Europe/Paris')::date + v_delta),
               fin = public.climat_minuit_interne((e.debut AT TIME ZONE 'Europe/Paris')::date + v_delta) + (e.fin - e.debut),
               alerte_le = NULL
         WHERE NOT e.annule AND e.pays = p_pays
           AND (CASE WHEN r.episode LIKE 'ev:%' THEN e.id = r.id0
                     ELSE e.type || ':' || e.periode = r.episode AND e.origine = 'calendrier' END);
        r.f1 := r.f1 + make_interval(days => v_delta);
        v_n := v_n + 1;
      END IF;
    END IF;
    v_borne := greatest(v_borne, r.f1 + make_interval(hours => r.preavis));
  END LOOP;
  RETURN v_n;
END $$;

-- Chaque passage : planifier, puis espacer, avant de publier les alertes.
CREATE OR REPLACE FUNCTION public.climat_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_plan integer;
BEGIN
  v_plan := public.climat_planifier_interne() + public.climat_planifier_mandat_interne();
  RETURN jsonb_build_object('ok', true, 'planifies', v_plan,
    'reportes', public.climat_espacer_interne('republic') + public.climat_espacer_interne('soviet') /* climat_un_par_pays_v1 */,
    'alertes', public.climat_alertes_publier_interne(), 'effets', public.climat_effets_passe_interne(),
    'contagion', public.maladies_contagion_passe_interne());
END $$;

-- Un événement reporté est annoncé de nouveau : l'article du journal porte la date de l'événement.
SELECT pg_temp.rp_raccorder('public.climat_alertes_publier_interne()'::regprocedure,
  $a$    VALUES ('climat-' || e.id, e.pays,$a$,
  $b$    VALUES ('climat-' || e.id || '-' || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'YYYYMMDD') /* climat_report_v1 */, e.pays,$b$,
  'climat_report_v1');
SELECT pg_temp.rp_raccorder('public.climat_alertes_publier_interne()'::regprocedure,
  $a$'attente', 'climat', 'importante', 'climat-' || e.id, now())$a$,
  $b$'attente', 'climat', 'importante', 'climat-' || e.id || '-' || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'YYYYMMDD'), now())$b$,
  '''climat-'' || e.id || ''-'' || to_char(e.debut AT TIME ZONE ''Europe/Paris'', ''YYYYMMDD''), now())');

-- ── Lieux de vente des protections (vérifiés dans le code le 21/11/2026) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.climat_lieux_vente (
  cle   text NOT NULL,             -- groupe_electrogene, sac_de_sable, bouteille_eau, sels_rehydratation
  pays  text NOT NULL,
  ville text NOT NULL,
  chez  text NOT NULL,             -- complément prêt à écrire après « en vente » : « à l'Armurerie Martinon, à Luthécia »
  PRIMARY KEY (cle, pays, ville, chez)
);
ALTER TABLE public.climat_lieux_vente ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_lieux_vente FROM anon, authenticated;
INSERT INTO public.climat_lieux_vente (cle, pays, ville, chez) VALUES
  -- Boutique climat (climat_boutiques) : pas de garagiste en Républia, les armureries-quincailleries vendent le groupe.
  ('groupe_electrogene', 'republic', 'capitale', 'à l''Armurerie Martinon, à Luthécia'),
  ('groupe_electrogene', 'republic', 'ville_b',  'à l''Armurerie-Quincaillerie de Montrouge'),
  ('groupe_electrogene', 'soviet',   'capitale', 'au Garage de Novomirsk'),
  ('sac_de_sable', 'republic', 'capitale', 'à l''Armurerie Martinon, à Luthécia'),
  ('sac_de_sable', 'republic', 'ville_b',  'à l''Armurerie-Quincaillerie de Montrouge'),
  ('sac_de_sable', 'republic', 'ville_a',  'à la Maison Le Gall (Chasse et Pêche), à Port-Sainte-Marie'),
  ('bouteille_eau', 'republic', 'capitale', 'au marché de Luthécia'),
  ('bouteille_eau', 'republic', 'ville_a',  'au marché de Port-Sainte-Marie'),
  ('bouteille_eau', 'republic', 'ville_b',  'au marché de Montrouge'),
  -- Points de vente des médicaments (pharmacies_points_vente) : pas de « pharmacie » en Républia.
  ('sels_rehydratation', 'republic', 'capitale', 'à l''usine pharmaceutique Pharmanov ou à l''entrepôt logistique de Luthécia'),
  ('sels_rehydratation', 'republic', 'ville_a',  'à l''entrepôt logistique de Port-Sainte-Marie'),
  ('sels_rehydratation', 'republic', 'ville_b',  'à l''entrepôt logistique de Montrouge'),
  ('sels_rehydratation', 'soviet',   'capitale', 'à la pharmacie d''État de Novomirsk')
ON CONFLICT DO NOTHING;
-- Ceux de la ville, sinon ceux du pays (« ou » entre eux) ; NULL si nulle part.
CREATE OR REPLACE FUNCTION public.climat_vente_interne(p_cle text, p_pays text, p_ville text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(
    (SELECT string_agg(chez, ' ou ' ORDER BY chez) FROM public.climat_lieux_vente WHERE cle = p_cle AND pays = p_pays AND ville = p_ville),
    (SELECT string_agg(chez, ' ou ' ORDER BY ville, chez) FROM public.climat_lieux_vente WHERE cle = p_cle AND pays = p_pays));
$$;

-- ── Points d'eau (configuration : Fred en ajoutera d'autres, avec une image chacun) ──────────────
CREATE TABLE IF NOT EXISTS public.climat_points_eau (
  id     text PRIMARY KEY,
  pays   text NOT NULL,
  ville  text NOT NULL,
  noeud  text NOT NULL,            -- vue de rue où l'on remplit (personnages_donnees.current_street)
  nom    text NOT NULL,            -- complément après « à » : « la fontaine de la statue de l'Ours, place de l'Ours »
  image  text,
  actif  boolean NOT NULL DEFAULT true
);
ALTER TABLE public.climat_points_eau ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_points_eau FROM anon, authenticated;
INSERT INTO public.climat_points_eau (id, pays, ville, noeud, nom) VALUES
  ('krasnov-fontaine-ours', 'soviet', 'ville_b', 'krasnov-place-ours', 'la fontaine de la statue de l''Ours, place de l''Ours')
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.climat_points_eau_lister()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', true, 'points', coalesce(jsonb_agg(jsonb_build_object('id', id, 'pays', pays, 'ville', ville,
           'noeud', noeud, 'nom', nom, 'image', image) ORDER BY id), '[]'::jsonb))
    FROM public.climat_points_eau WHERE actif;
$$;

-- « Remplir une bouteille d'eau » : gratuit, 0 PA, seulement dans la vue de rue d'un point d'eau.
CREATE OR REPLACE FUNCTION public.point_eau_remplir(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; d public.personnages_donnees;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'point_eau_remplir', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF d.current_building IS NOT NULL OR NOT EXISTS (SELECT 1 FROM public.climat_points_eau pe WHERE pe.actif
       AND pe.pays = d.country AND pe.ville = d.current_city AND pe.noeud = d.current_street) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_point_eau');
  END IF;
  v := public.inventaire_deposer_interne(a, public.climat_objet_interne('bouteille_eau', 1));
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'point_eau_remplir', prm, v);
END $$;

-- ── Textes de consigne (point 7), un par type et par ville ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.climat_consigne_interne(p_type text, p_pays text, p_ville text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_eau text; v_vente text; v_agences text;
BEGIN
  IF p_type = 'orage' THEN
    RETURN 'Pendant 6 heures, ordinateurs, box et caméras sont hors service : plus de surveillance, de trading à distance ni de piratage, '
      || 'et les chantiers sont à l''arrêt. Débranchez vos appareils électroniques. Pour garder le courant, équipez-vous d''un groupe électrogène'
      || coalesce(', en vente ' || public.climat_vente_interne('groupe_electrogene', p_pays, p_ville), '')
      || ', avec ' || public.aliments_param_interne('groupe_bidons', 5)::integer || ' bidons de carburant.';
  ELSIF p_type = 'crue' THEN
    RETURN 'Pendant 6 heures, les commerces et entrepôts non protégés de la zone inondable sont fermés et perdent '
      || public.aliments_param_interne('crue_perte_pct', 20)::integer || ' % de leurs stocks, et les chantiers sont à l''arrêt. '
      || 'Sécurisez vos propriétés : posez des sacs de sable'
      || coalesce(', en vente ' || public.climat_vente_interne('sac_de_sable', p_pays, p_ville), '')
      || ' (1 PA, valables pour une crue). Les lieux protégés restent ouverts. La gare et tous les déplacements restent libres.';
  ELSIF p_type = 'canicule' THEN
    SELECT 'Remplissez-la gratuitement à ' || nom || '.' INTO v_eau FROM public.climat_points_eau
     WHERE actif AND pays = p_pays AND ville = p_ville ORDER BY id LIMIT 1;
    IF v_eau IS NULL THEN
      v_vente := public.climat_vente_interne('bouteille_eau', p_pays, p_ville);
      v_eau := CASE WHEN v_vente IS NOT NULL THEN 'En vente ' || v_vente || '.' END;
    END IF;
    RETURN 'Toute personne présente en ville perd 3 PA, et la nourriture portée sur soi devient insalubre. '
      || 'Gardez une bouteille d''eau sur vous et ne transportez pas de nourriture. ' || coalesce(v_eau || ' ', '')
      || 'En cas de coup de chaleur, achetez des sels de réhydratation '
      || coalesce(public.climat_vente_interne('sels_rehydratation', p_pays, p_ville), 'en pharmacie') || '.';
  ELSIF p_type = 'brouillard' THEN
    -- Agences de sécurité ouvertes dans la ville : Grobras (Luthécia) et celles des joueurs (vivier de la ville).
    SELECT string_agg('l''agence ' || regexp_replace(nom, '\s+Sécurité$', ''), ' ou ' ORDER BY cree_le) INTO v_agences
      FROM public.pnj_employeurs
     WHERE actif AND pays = p_pays
       AND ((employeur_id = 'grobras-securite' AND p_pays = 'republic' AND p_ville = 'capitale') OR vivier = 'vivier-securite-' || p_ville);
    RETURN 'Pendant 6 heures, les malfaiteurs agissent plus facilement et échappent plus souvent à la police, à la sécurité et aux caméras. '
      || 'Sécurisez vos propriétés : ne laissez rien de précieux sans surveillance, et pensez à engager un agent de sécurité dans une agence de sécurité'
      || coalesce(' : ' || v_agences, '') || '.';
  ELSIF p_type = 'blizzard' THEN
    RETURN 'Le blizzard fait perdre 3 PA à chacun, et la grippe menace ceux qui n''ont plus de forces. Reposez-vous pour garder vos PA : '
      || 'c''est la meilleure protection. Achetez de la graisse animale : de renne à Starovka, d''ours au marché de Krasnov, '
      || 'de castor chez la poissonnière de Novomirsk, ou dans une pharmacie tenue par un joueur.';
  END IF;
  RETURN NULL;
END $$;

-- Alertes 48 heures avant (presse, journal des événements) : l'annonce, puis la consigne.
CREATE OR REPLACE FUNCTION public.climat_texte_alerte_interne(e public.climat_evenements)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.climat_nom_type_interne(e.type) || ' annoncé' || CASE WHEN e.type IN ('crue', 'canicule') THEN 'e' ELSE '' END
      || ' à ' || public.climat_nom_ville_interne(e.pays, e.ville) || ' le ' || to_char(e.debut AT TIME ZONE 'Europe/Paris', 'DD/MM')
      || CASE WHEN e.type = 'crue' THEN ' (zone inondable menacée : ' || (SELECT string_agg(l->>'nom', ', ') FROM jsonb_array_elements(e.lieux) l) || ')' ELSE '' END
      || '. ' || coalesce(public.climat_consigne_interne(e.type, e.pays, e.ville), '') /* climat_consignes_v1 */;
$$;

-- Événement vu par le client : lieux réellement fermés (non protégés), lieux protégés, consigne de la ville.
CREATE OR REPLACE FUNCTION public.climat_evenement_json_interne(e public.climat_evenements)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('id', e.id, 'type', e.type, 'ville', e.ville, 'debut', e.debut, 'fin', e.fin,
    'en_cours', now() >= e.debut AND now() < e.fin,
    'lieux', (SELECT coalesce(jsonb_agg(l->>'batiment'), '[]'::jsonb) FROM jsonb_array_elements(e.lieux) l
               WHERE NOT public.climat_lieu_protege_interne(e, l->>'batiment')),
    'lieux_proteges', (SELECT coalesce(jsonb_agg(l->>'batiment'), '[]'::jsonb) FROM jsonb_array_elements(e.lieux) l
               WHERE public.climat_lieu_protege_interne(e, l->>'batiment')),
    'consigne', public.climat_consigne_interne(e.type, e.pays, e.ville));
$$;

CREATE OR REPLACE FUNCTION public.climat_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p public.personnages_donnees;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = a;
  RETURN jsonb_build_object('ok', true, 'maintenant', now(), 'evenements', (
    SELECT coalesce(jsonb_agg(public.climat_evenement_json_interne(e) ORDER BY e.debut), '[]'::jsonb)
      FROM public.climat_evenements e WHERE e.pays = p.country AND NOT e.annule AND e.alerte_le IS NOT NULL AND e.fin > now()));
END $$;

SELECT pg_temp.rp_raccorder('public.climat_accueil_interne(text)'::regprocedure,
  $a$'evenement', jsonb_build_object('id', e.id, 'type', e.type,
    'ville', e.ville, 'debut', e.debut, 'fin', e.fin,
    'lieux', (SELECT coalesce(jsonb_agg(l->>'batiment'), '[]'::jsonb) FROM jsonb_array_elements(e.lieux) l)));$a$,
  $b$'evenement', public.climat_evenement_json_interne(e) /* climat_consignes_v1 */);$b$,
  'climat_consignes_v1');

-- ── Mise en conformité du calendrier existant ────────────────────────────────────────────────────
SELECT public.climat_espacer_interne('republic'), public.climat_espacer_interne('soviet');

REVOKE ALL ON FUNCTION public.climat_lieu_protege_interne(public.climat_evenements, text), public.climat_espacer_interne(text),
  public.climat_nom_type_interne(text), public.climat_vente_interne(text, text, text), public.climat_consigne_interne(text, text, text),
  public.climat_evenement_json_interne(public.climat_evenements) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.climat_points_eau_lister(), public.point_eau_remplir(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.climat_points_eau_lister(), public.point_eau_remplir(uuid) TO authenticated;

COMMIT;
