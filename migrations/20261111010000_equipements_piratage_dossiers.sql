-- MATERIELS PAR COMBINAISON, ETAPES 2 ET 3 : PIRATAGE ET DOSSIERS (decisions de Fred du 31/10 et du 10/11/2026,
-- GAME-DESIGN-EQUIPEMENTS.md, decisions 6 a 11 et 16).
--  * Dossiers : ranges sur l'objet ordinateur (20) ou sur le peripherique de stockage (180) installes dans le bureau ;
--    ils suivent l'OBJET (identifiant objet->>'id'), donc l'ordinateur vole emporte les siens. Le proprietaire lit,
--    deplace (sans PA), detruit ses dossiers ; transferer a un PJ = 1 PA, copie par mail (l'original reste).
--  * Piratage depuis son bureau connecte (ordinateur + box) : 3 PA, base 45 % +/- (INT - 10) ; cible protegee par un
--    intranet : seuls 5 % des reussites passent. Echec : rien, alerte une fois sur deux (sans nom), trace toujours.
--    Cibles : banque (PJ ou organisation par son nom : soldes, prets, placements ; Helvetia a chance divisee par deux),
--    registre (ventes d'armes, plaintes, carceral, signalements de Sovarka) d'une ville, caserne (effectif par grade,
--    postes, commandement, preparation, sans noms de soldats), ordinateur d'un PJ (liste des dossiers puis lire, copier
--    ou detruire UN dossier). Les traces d'actes illegaux ne sont pas piratables.
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;

INSERT INTO public.actes_illegaux (fn, type, detect_rate, decouvrable)
VALUES ('pirater', 'delit_mineur', 0, false) ON CONFLICT (fn) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.dossiers_informatiques (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objet_id      text NOT NULL,              -- objet ordinateur ou peripherique de stockage qui porte le dossier
  support       text NOT NULL CHECK (support IN ('ordinateur', 'stockage')),
  type          text NOT NULL,              -- piratage, surveillance, faux_document, plan_3d, copie
  titre         text NOT NULL,
  contenu       text NOT NULL,
  donnees       jsonb NOT NULL DEFAULT '{}'::jsonb,
  auteur        text,
  cree_le       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS dossiers_informatiques_objet ON public.dossiers_informatiques (objet_id);
ALTER TABLE public.dossiers_informatiques ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.dossiers_informatiques FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.piratages_acces (
  acteur     text NOT NULL,
  cible      text NOT NULL,
  ouvert_le  timestamptz NOT NULL DEFAULT now(),
  utilise    boolean NOT NULL DEFAULT false,
  PRIMARY KEY (acteur, cible)
);
ALTER TABLE public.piratages_acces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.piratages_acces FROM anon, authenticated;

-- Equipements installes dans le bureau ou se tient l'acteur, a lui (ou a son organisation, etape 6).
CREATE OR REPLACE FUNCTION public.equipements_bureau_interne(p_acteur text)
RETURNS SETOF public.equipements_installes LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT e.* FROM public.equipements_installes e, public.personnages_donnees pd
   WHERE pd.name = p_acteur AND e.pays = pd.country AND e.ville = pd.current_city
     AND e.batiment = pd.current_building AND e.piece = pd.current_room
     AND public.equipement_a_moi_interne(e.proprietaire, p_acteur)
     AND public.local_jouissance_interne(p_acteur, pd.country, pd.current_city, pd.current_building, pd.current_room);
$$;

-- Connexion : ordinateur ET box dans le bureau de l'acteur.
CREATE OR REPLACE FUNCTION public.equipements_connecte_interne(p_acteur text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT (SELECT count(DISTINCT generique_id) FROM public.equipements_bureau_interne(p_acteur)
           WHERE generique_id IN ('ordinateur-complet', 'box-internet')) = 2;
$$;

-- Ranger un dossier dans le bureau de l'acteur : ordinateur (20), puis peripherique de stockage (180). NULL si plein.
CREATE OR REPLACE FUNCTION public.dossier_ranger_interne(p_acteur text, p_type text, p_titre text, p_contenu text, p_donnees jsonb DEFAULT '{}'::jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e record; v_id uuid;
BEGIN
  FOR e IN SELECT objet->>'id' AS oid, generique_id FROM public.equipements_bureau_interne(p_acteur)
            WHERE generique_id IN ('ordinateur-complet', 'peripherique-stockage') AND coalesce(objet->>'id', '') <> ''
            ORDER BY CASE generique_id WHEN 'ordinateur-complet' THEN 0 ELSE 1 END LOOP
    IF ((SELECT count(*) FROM public.dossiers_informatiques WHERE objet_id = e.oid)
        < (CASE e.generique_id WHEN 'ordinateur-complet' THEN 20 ELSE 180 END)) THEN
      INSERT INTO public.dossiers_informatiques (objet_id, support, type, titre, contenu, donnees, auteur)
      VALUES (e.oid, CASE e.generique_id WHEN 'ordinateur-complet' THEN 'ordinateur' ELSE 'stockage' END,
              p_type, left(p_titre, 120), p_contenu, coalesce(p_donnees, '{}'::jsonb), p_acteur)
      RETURNING id INTO v_id;
      RETURN v_id;
    END IF;
  END LOOP;
  RETURN NULL;
END $$;

-- Mes dossiers (bureau courant).
CREATE OR REPLACE FUNCTION public.dossiers_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  RETURN jsonb_build_object('ok', true, 'connecte', public.equipements_connecte_interne(a),
    'supports', coalesce((SELECT jsonb_agg(jsonb_build_object('generique', generique_id, 'objet', objet->>'id',
                  'capacite', CASE generique_id WHEN 'ordinateur-complet' THEN 20 ELSE 180 END,
                  'nb', (SELECT count(*) FROM public.dossiers_informatiques d WHERE d.objet_id = e.objet->>'id')))
               FROM public.equipements_bureau_interne(a) e WHERE generique_id IN ('ordinateur-complet', 'peripherique-stockage')), '[]'::jsonb),
    'dossiers', coalesce((SELECT jsonb_agg(jsonb_build_object('id', d.id, 'titre', d.titre, 'type', d.type, 'support', d.support,
                  'cree_le', d.cree_le) ORDER BY d.cree_le DESC)
               FROM public.dossiers_informatiques d
              WHERE d.objet_id IN (SELECT objet->>'id' FROM public.equipements_bureau_interne(a)
                                    WHERE generique_id IN ('ordinateur-complet', 'peripherique-stockage'))), '[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.dossiers_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dossiers_lire() TO authenticated;

-- Le dossier est-il dans le bureau de l'acteur ?
CREATE OR REPLACE FUNCTION public.dossier_accessible_interne(p_acteur text, p_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.dossiers_informatiques d WHERE d.id = p_id
                    AND d.objet_id IN (SELECT objet->>'id' FROM public.equipements_bureau_interne(p_acteur)));
$$;

CREATE OR REPLACE FUNCTION public.dossier_ouvrir(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d public.dossiers_informatiques;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.dossier_accessible_interne(a, p_id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'dossier_inaccessible'); END IF;
  SELECT * INTO d FROM public.dossiers_informatiques WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'id', d.id, 'titre', d.titre, 'type', d.type, 'contenu', d.contenu, 'support', d.support, 'cree_le', d.cree_le);
END $$;
REVOKE ALL ON FUNCTION public.dossier_ouvrir(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dossier_ouvrir(uuid) TO authenticated;

-- Deplacer entre l'ordinateur et le peripherique de stockage du meme bureau (sans PA).
CREATE OR REPLACE FUNCTION public.dossier_deplacer(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d public.dossiers_informatiques; v_cible text; v_gen text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.dossier_accessible_interne(a, p_id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'dossier_inaccessible'); END IF;
  SELECT * INTO d FROM public.dossiers_informatiques WHERE id = p_id FOR UPDATE;
  v_gen := CASE d.support WHEN 'ordinateur' THEN 'peripherique-stockage' ELSE 'ordinateur-complet' END;
  SELECT objet->>'id' INTO v_cible FROM public.equipements_bureau_interne(a) WHERE generique_id = v_gen
     AND (SELECT count(*) FROM public.dossiers_informatiques x WHERE x.objet_id = objet->>'id')
         < CASE v_gen WHEN 'ordinateur-complet' THEN 20 ELSE 180 END
   LIMIT 1;
  IF v_cible IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'support_absent_ou_plein'); END IF;
  UPDATE public.dossiers_informatiques SET objet_id = v_cible,
         support = CASE v_gen WHEN 'ordinateur-complet' THEN 'ordinateur' ELSE 'stockage' END WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'support', CASE v_gen WHEN 'ordinateur-complet' THEN 'ordinateur' ELSE 'stockage' END);
END $$;
REVOKE ALL ON FUNCTION public.dossier_deplacer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dossier_deplacer(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.dossier_detruire(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.dossier_accessible_interne(a, p_id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'dossier_inaccessible'); END IF;
  DELETE FROM public.dossiers_informatiques WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE ALL ON FUNCTION public.dossier_detruire(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dossier_detruire(uuid) TO authenticated;

-- Transferer une copie a un PJ (1 PA, par mail ; l'original reste).
CREATE OR REPLACE FUNCTION public.dossier_transferer(p_id uuid, p_destinataire text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d public.dossiers_informatiques; v_pa integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.dossier_accessible_interne(a, p_id) THEN RETURN jsonb_build_object('ok', false, 'raison', 'dossier_inaccessible'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_inconnu'); END IF;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF coalesce(v_pa, 0) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  SELECT * INTO d FROM public.dossiers_informatiques WHERE id = p_id;
  UPDATE public.personnages_donnees SET pa = pa - 1 WHERE name = a;
  PERFORM public.mail_systeme_poser_interne(a, p_destinataire, 'Dossier transmis — ' || d.titre, d.contenu);
  RETURN jsonb_build_object('ok', true, 'pa', v_pa - 1);
END $$;
REVOKE ALL ON FUNCTION public.dossier_transferer(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dossier_transferer(uuid, text) TO authenticated;

-- Textes des rapports de piratage.
CREATE OR REPLACE FUNCTION public.piratage_banque_texte_interne(p_cible text, p_helvetia boolean)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v text := ''; r record; o record;
BEGIN
  SELECT id, data::jsonb AS d INTO o FROM public.organisations WHERE data::jsonb->>'nom' ILIKE p_cible OR id = p_cible LIMIT 1;
  IF o.id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_cible) THEN
    RETURN 'Organisation : ' || coalesce(o.d->>'nom', o.id) || E'\nCaisse : ' || coalesce(o.d->>'caisse', '0');
  END IF;
  FOR r IN SELECT banque, pays, solde FROM public.comptes_bancaires WHERE personnage = p_cible AND (banque <> 'helvetia' OR p_helvetia) ORDER BY banque LOOP
    v := v || E'\n• Compte ' || r.banque || ' (' || r.pays || ') : ' || round(r.solde)::text;
  END LOOP;
  FOR r IN SELECT type_banque, type_pret, montant_restant, statut FROM public.prets WHERE emprunteur = p_cible AND coalesce(montant_restant, 0) > 0
              AND (type_banque <> 'helvetia' OR p_helvetia) LOOP
    v := v || E'\n• Prêt ' || coalesce(r.type_pret, '') || ' (' || r.type_banque || ') : reste ' || round(r.montant_restant)::text || ' — ' || coalesce(r.statut, '');
  END LOOP;
  FOR r IN SELECT banque, coalesce(libelle, type) AS lib, montant, statut FROM public.placements_bancaires WHERE personnage = p_cible
              AND (banque <> 'helvetia' OR p_helvetia) AND coalesce(statut, '') NOT IN ('resolu', 'termine', 'solde') LOOP
    v := v || E'\n• Placement ' || coalesce(r.lib, '') || ' (' || r.banque || ') : ' || round(r.montant)::text;
  END LOOP;
  RETURN 'Comptes de ' || p_cible || CASE WHEN p_helvetia THEN ' (Helvetia comprise)' ELSE ' (Helvetia hors d''atteinte)' END
      || coalesce(nullif(v, ''), E'\nAucun compte, prêt ni placement.');
END $$;

CREATE OR REPLACE FUNCTION public.piratage_registre_texte_interne(p_registre text, p_pays text, p_ville text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v text := ''; r record;
BEGIN
  IF p_registre = 'armes' THEN
    FOR r IN SELECT joueur, arme, prix, jour FROM public.registre_ventes_armes WHERE pays = p_pays AND city = p_ville ORDER BY created_at DESC LIMIT 30 LOOP
      v := v || E'\n• Jour ' || coalesce(r.jour::text, '?') || ' : ' || r.joueur || ' — ' || r.arme || ' (' || coalesce(r.prix::text, '?') || ')';
    END LOOP;
  ELSIF p_registre = 'plaintes' THEN
    FOR r IN SELECT data, created_at FROM public.plaintes_en_cours WHERE country = p_pays AND city = p_ville ORDER BY created_at DESC LIMIT 30 LOOP
      v := v || E'\n• ' || coalesce(r.data->>'plaignant', r.data->>'auteur', '?') || ' contre ' || coalesce(r.data->>'accuse', r.data->>'cible', '?')
             || coalesce(' — ' || (r.data->>'motif'), '');
    END LOOP;
  ELSIF p_registre = 'carceral' THEN
    FOR r IN SELECT nom, raison, jour_debut, jour_fin, qhs FROM public.detentions WHERE country = p_pays AND city = p_ville
                AND mode_fin IS NULL AND date_fin_effective IS NULL ORDER BY jour_debut DESC LIMIT 30 LOOP
      v := v || E'\n• ' || r.nom || ' — ' || coalesce(r.raison, '?') || ', du jour ' || coalesce(r.jour_debut::text, '?')
             || ' au jour ' || coalesce(r.jour_fin::text, '?') || CASE WHEN r.qhs THEN ' (QHS)' ELSE '' END;
    END LOOP;
  ELSIF p_registre = 'signalements' THEN
    FOR r IN SELECT ts, cible, motif FROM public.sovarka_signalements ORDER BY ts DESC LIMIT 30 LOOP
      v := v || E'\n• ' || to_char(r.ts AT TIME ZONE 'Europe/Paris', 'DD/MM') || ' : ' || coalesce(r.cible, '?') || coalesce(' — ' || r.motif, '');
    END LOOP;
  END IF;
  RETURN 'Registre ' || p_registre || ' — ' || p_ville || coalesce(nullif(v, ''), E'\nRegistre vide.');
END $$;

CREATE OR REPLACE FUNCTION public.piratage_caserne_texte_interne(p_pays text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v text := ''; c record; s jsonb; n_sol integer; n_bles integer; postes text;
BEGIN
  FOR c IN SELECT data FROM public.compagnies_militaires WHERE data->>'pays' = p_pays LOOP
    v := v || E'\nCompagnie — capitaine : ' || coalesce(c.data->>'capitaineNom', 'vacant')
           || ', réserve : ' || coalesce(jsonb_array_length(c.data->'reserve'), 0)::text || ' soldats';
    FOR s IN SELECT * FROM jsonb_array_elements(coalesce(c.data->'sections', '[]'::jsonb)) LOOP
      SELECT count(*), count(*) FILTER (WHERE coalesce((so->>'pa')::numeric, 0) <= 0),
             string_agg(DISTINCT coalesce(so->>'ville', 'caserne'), ', ')
        INTO n_sol, n_bles, postes
        FROM jsonb_array_elements(coalesce(s->'soldats', '[]'::jsonb)) so;
      v := v || E'\n  • Section ' || coalesce(s->>'numero', '?') || ' — lieutenant : ' || coalesce(s->>'lieutenantNom', 'vacant')
             || ' ; ' || n_sol || ' soldats (' || n_bles || ' hors de combat) ; postés : ' || coalesce(postes, '—')
             || ' ; armes : ' || coalesce((SELECT string_agg(a || ' ×' || n, ', ') FROM (SELECT so->>'arme' a, count(*) n
                   FROM jsonb_array_elements(coalesce(s->'soldats', '[]'::jsonb)) so GROUP BY 1) x), '—');
    END LOOP;
  END LOOP;
  v := v || E'\nOfficiers en service : ' || coalesce((SELECT string_agg(grade || ' ×' || n, ', ') FROM (SELECT grade, count(*) n FROM public.services_militaires
                WHERE pays = p_pays AND fin_ts IS NULL GROUP BY 1) g), 'aucun');
  RETURN 'Casernes — ' || p_pays || coalesce(nullif(v, ''), E'\nAucune troupe.');
END $$;

-- Titulaire d'un poste dans un pays (alerte d'une institution).
CREATE OR REPLACE FUNCTION public.piratage_titulaire_interne(p_poste text, p_pays text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT name FROM public.personnages_donnees WHERE poste->>'id' = p_poste AND country = p_pays ORDER BY name LIMIT 1;
$$;

-- Le piratage.
CREATE OR REPLACE FUNCTION public.pirater(p_cible text, p_parametre text, p_ville text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); d record; v_mod integer; v_taux integer; v_jet integer; v_intranet boolean := false;
        v_texte text; v_titre text; v_alerte text; v_reussi boolean; v_dossier uuid; v_ville text; v_res jsonb; v_helv boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_cible NOT IN ('banque', 'registre', 'caserne', 'ordinateur') THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('piratage:' || a, 0));
  SELECT name, pa, stats, country, current_city INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF NOT public.equipements_connecte_interne(a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
  v_ville := coalesce(nullif(btrim(p_ville), ''), d.current_city);
  IF p_cible = 'banque' AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_parametre)
     AND NOT EXISTS (SELECT 1 FROM public.organisations WHERE data::jsonb->>'nom' ILIKE p_parametre OR id = p_parametre) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_inconnue'); END IF;
  IF p_cible = 'registre' AND p_parametre NOT IN ('armes', 'plaintes', 'carceral', 'signalements') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'registre_inconnu'); END IF;
  IF p_cible = 'registre' AND p_parametre = 'signalements' AND d.country <> 'soviet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'registre_inconnu'); END IF;
  IF p_cible = 'ordinateur' THEN
    IF p_parametre = a OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_parametre) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_inconnue'); END IF;
    v_intranet := EXISTS (SELECT 1 FROM public.equipements_installes e WHERE e.proprietaire = p_parametre
                            AND e.generique_id = 'peripherique-reseau-intranet');
  END IF;
  IF coalesce(d.pa, 0) < 3 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  UPDATE public.personnages_donnees SET pa = pa - 3 WHERE name = a;
  v_mod := coalesce(CASE WHEN coalesce(d.stats->>'INT', '') ~ '^-?[0-9]+(\.[0-9]+)?$' THEN floor((d.stats->>'INT')::numeric)::integer END, 10) - 10;
  v_taux := greatest(5, least(95, 45 + v_mod));
  v_jet := floor(random() * 100)::integer + 1;
  v_reussi := v_jet <= v_taux AND (NOT v_intranet OR floor(random() * 100)::integer + 1 <= 5);
  PERFORM public.crime_tracer_interne(a, 'pirater', p_cible || ' : ' || coalesce(p_parametre, ''));
  IF NOT v_reussi THEN
    IF random() < 0.5 THEN
      v_alerte := CASE p_cible WHEN 'ordinateur' THEN p_parametre
                    WHEN 'banque' THEN coalesce((SELECT name FROM public.personnages_donnees WHERE name = p_parametre),
                                                public.piratage_titulaire_interne('min_fin', d.country))
                    WHEN 'caserne' THEN public.piratage_titulaire_interne('min_def', d.country)
                    ELSE public.piratage_titulaire_interne('min_int', d.country) END;
      IF v_alerte IS NOT NULL THEN
        PERFORM public.mail_systeme_poser_interne('Sécurité informatique', v_alerte, 'Tentative d''intrusion détectée',
          'Une tentative de piratage (' || p_cible || ') a été repoussée. Son auteur n''a pas pu être identifié.');
      END IF;
    END IF;
    RETURN jsonb_build_object('ok', true, 'reussi', false, 'taux', v_taux, 'jet', v_jet, 'intranet', v_intranet, 'pa', d.pa - 3);
  END IF;
  IF p_cible = 'ordinateur' THEN
    INSERT INTO public.piratages_acces (acteur, cible) VALUES (a, p_parametre)
    ON CONFLICT (acteur, cible) DO UPDATE SET ouvert_le = now(), utilise = false;
    RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet, 'pa', d.pa - 3, 'cible', p_parametre,
      'dossiers', coalesce((SELECT jsonb_agg(jsonb_build_object('id', x.id, 'titre', x.titre, 'type', x.type) ORDER BY x.cree_le DESC)
                   FROM public.dossiers_informatiques x WHERE x.objet_id IN (
                     SELECT e.objet->>'id' FROM public.equipements_installes e WHERE e.proprietaire = p_parametre
                        AND e.generique_id IN ('ordinateur-complet', 'peripherique-stockage'))), '[]'::jsonb));
  END IF;
  IF p_cible = 'banque' THEN
    v_helv := floor(random() * 100)::integer + 1 <= v_taux / 2;
    v_texte := public.piratage_banque_texte_interne(p_parametre, v_helv);
    v_titre := 'Piratage bancaire — ' || p_parametre;
  ELSIF p_cible = 'registre' THEN
    v_texte := public.piratage_registre_texte_interne(p_parametre, d.country, v_ville);
    v_titre := 'Piratage du registre ' || p_parametre || ' — ' || v_ville;
  ELSE
    v_texte := public.piratage_caserne_texte_interne(d.country);
    v_titre := 'Piratage des casernes';
  END IF;
  PERFORM public.mail_systeme_poser_interne('Piratage', a, v_titre, v_texte);
  v_dossier := public.dossier_ranger_interne(a, 'piratage', v_titre, v_texte);
  RETURN jsonb_build_object('ok', true, 'reussi', true, 'taux', v_taux, 'jet', v_jet, 'pa', d.pa - 3, 'titre', v_titre,
                            'texte', v_texte, 'dossier', v_dossier);
END $$;
REVOKE ALL ON FUNCTION public.pirater(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pirater(text, text, text) TO authenticated;

-- Apres un piratage reussi d'ordinateur : lire, copier ou detruire UN dossier (dans l'heure).
CREATE OR REPLACE FUNCTION public.piratage_dossier_agir(p_cible text, p_id uuid, p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); x public.dossiers_informatiques; v_copie uuid;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_action NOT IN ('lire', 'copier', 'detruire') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_invalide'); END IF;
  PERFORM 1 FROM public.piratages_acces WHERE acteur = a AND cible = p_cible AND NOT utilise AND ouvert_le > now() - interval '1 hour' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acces_expire'); END IF;
  SELECT * INTO x FROM public.dossiers_informatiques WHERE id = p_id AND objet_id IN (
    SELECT e.objet->>'id' FROM public.equipements_installes e WHERE e.proprietaire = p_cible
       AND e.generique_id IN ('ordinateur-complet', 'peripherique-stockage'));
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'dossier_inaccessible'); END IF;
  UPDATE public.piratages_acces SET utilise = true WHERE acteur = a AND cible = p_cible;
  IF p_action = 'detruire' THEN
    DELETE FROM public.dossiers_informatiques WHERE id = x.id;
    RETURN jsonb_build_object('ok', true, 'action', 'detruire', 'titre', x.titre);
  END IF;
  IF p_action = 'copier' THEN
    IF NOT public.equipements_connecte_interne(a) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_connexion'); END IF;
    v_copie := public.dossier_ranger_interne(a, 'copie', x.titre, x.contenu, x.donnees);
    PERFORM public.mail_systeme_poser_interne('Piratage', a, 'Dossier copié — ' || x.titre, x.contenu);
  END IF;
  RETURN jsonb_build_object('ok', true, 'action', p_action, 'titre', x.titre, 'contenu', x.contenu, 'copie', v_copie);
END $$;
REVOKE ALL ON FUNCTION public.piratage_dossier_agir(text, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.piratage_dossier_agir(text, uuid, text) TO authenticated;

-- Le materiel informatique s'installe dans le bureau (emplacements : 3 gratuits, 6 premium).
DO $raccord$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.equipement_installer(text)'::regprocedure);
  IF position('peripherique-stockage' IN d) > 0 THEN RETURN; END IF;
  a := $a$p_generique NOT IN ('ordinateur-complet', 'box-internet', 'armoire_souvenirs')$a$;
  b := $b$p_generique NOT IN ('ordinateur-complet', 'box-internet', 'armoire_souvenirs', 'imprimante-papier', 'imprimante-3d', 'peripherique-stockage', 'peripherique-reseau-intranet')$b$;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'equipement_installer : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $raccord$;

DO $raccord$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.equipements_local_lire()'::regprocedure);
  IF position('peripherique-stockage' IN d) > 0 THEN RETURN; END IF;
  a := $a$IN ('ordinateur-complet', 'box-internet', 'armoire_souvenirs')), '[]'::jsonb)$a$;
  b := $b$IN ('ordinateur-complet', 'box-internet', 'armoire_souvenirs', 'imprimante-papier', 'imprimante-3d', 'peripherique-stockage', 'peripherique-reseau-intranet')), '[]'::jsonb)$b$;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'equipements_local_lire : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $raccord$;

COMMIT;
