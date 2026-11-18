-- Goulag de Sovarka — ordres internes des cinq pièces (décisions de Fred du 17/11/2026).
-- Lot 1/4 : registre administratif, incidents, contrôles de minuit et paramètres à arbitrer.
--
-- DÉPENDANCE : ce lot s'installe APRÈS le moteur préparé par Codex (PR #1020) : il réutilise
-- sovarka_goulag_configuration (verrou d'activation), sovarka_goulag_visites (présence des
-- personnes habilitées) et sovarka_goulag_traversees (reprise de peine). Sans ce moteur, il
-- refuse de s'installer au lieu de créer une copie concurrente. Rien n'est activé ici : toutes
-- les RPC refusent tant que sovarka_goulag_configuration.active est faux.
DO $goulag_ordres_prerequis$
BEGIN
  IF to_regclass('public.sovarka_goulag_configuration') IS NULL
     OR to_regclass('public.sovarka_goulag_visites') IS NULL
     OR to_regclass('public.sovarka_goulag_traversees') IS NULL
     OR to_regprocedure('public.goulag_toundra_demarrer(text)') IS NULL
     OR to_regprocedure('public.sovarka_goulag_role_interne(text)') IS NULL THEN
    RAISE EXCEPTION 'goulag_moteur_1020_requis';
  END IF;
END $goulag_ordres_prerequis$;

-- Une ligne par détention au goulag : elle survit à la libération et à l'évasion (historique).
-- La peine ne diminue QUE par un sommeil valide (jours_restants), jamais par le calendrier.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_registre (
  detention_id text PRIMARY KEY REFERENCES public.detentions(id),
  nom text NOT NULL REFERENCES public.personnages_donnees(name),
  -- Références judiciaires RÉELLES ; NULL quand elles sont inconnues, jamais reconstituées.
  jugement_id text,
  tribunal_pays text,
  tribunal_ville text,
  juge text,
  detention_precedente_id text,
  entree_le timestamptz NOT NULL DEFAULT now(),
  jours_restants integer NOT NULL CHECK (jours_restants >= 0),
  -- Une sanction disciplinaire ne peut jamais dépasser deux nuits.
  cachot_nuits integer NOT NULL DEFAULT 0 CHECK (cachot_nuits BETWEEN 0 AND 2),
  cachot_motif text CHECK (cachot_motif IN ('evasion_echouee','decision_judiciaire')),
  dernier_sommeil date,
  dernier_repas date,
  derniere_tentative date,
  corruption_bonus boolean NOT NULL DEFAULT false,
  interrogatoires integer NOT NULL DEFAULT 0 CHECK (interrogatoires >= 0),
  -- État administratif constaté au dernier contrôle de minuit (distinct de la présence physique).
  statut_controle text NOT NULL DEFAULT 'detenu'
    CHECK (statut_controle IN ('detenu','liberation_en_attente','en_fuite')),
  present_controle boolean,
  controle_jour date,
  liberation_le timestamptz,
  evasion_le timestamptz,
  reincarcere_le timestamptz,
  CHECK (cachot_motif IS NULL OR cachot_nuits > 0),
  CHECK (NOT (liberation_le IS NOT NULL AND evasion_le IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS sovarka_goulag_registre_nom_idx ON public.sovarka_goulag_registre(nom);
ALTER TABLE public.sovarka_goulag_registre ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_registre FROM PUBLIC,anon,authenticated,service_role;

-- Jugements déjà comptés dans un registre : chaque décision de goulag s'ajoute UNE fois au compteur
-- (nouvelle condamnation, peine ajoutée en détention, peine prononcée après réincarcération).
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_registre_jugements (
  jugement_id text PRIMARY KEY,
  detention_id text NOT NULL REFERENCES public.detentions(id),
  jours integer NOT NULL CHECK (jours >= 0),
  ajoute boolean NOT NULL,
  compte_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_goulag_registre_jugements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_registre_jugements FROM PUBLIC,anon,authenticated,service_role;

-- Historique daté des incidents du camp. `cle` rend chaque écriture idempotente.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_incidents (
  id bigserial PRIMARY KEY,
  cle text NOT NULL UNIQUE,
  nature text NOT NULL CHECK (nature IN ('evasion_reussie','evasion_echouee',
    'sanction_disciplinaire','absence_minuit')),
  nom text NOT NULL REFERENCES public.personnages_donnees(name),
  detention_id text REFERENCES public.detentions(id),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  survenu_le timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sovarka_goulag_incidents_date_idx ON public.sovarka_goulag_incidents(survenu_le DESC, id DESC);
ALTER TABLE public.sovarka_goulag_incidents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_incidents FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE public.sovarka_goulag_incidents_id_seq FROM PUBLIC,anon,authenticated,service_role;

-- Une tentative d'évasion par détention et par jour (clé primaire = garde de concurrence).
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_tentatives (
  detention_id text NOT NULL REFERENCES public.detentions(id),
  jour date NOT NULL,
  nom text NOT NULL REFERENCES public.personnages_donnees(name),
  taux integer NOT NULL CHECK (taux IN (80,95)),
  jet integer NOT NULL CHECK (jet BETWEEN 1 AND 100),
  reussi boolean NOT NULL,
  corruption boolean NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (detention_id, jour)
);
ALTER TABLE public.sovarka_goulag_tentatives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_tentatives FROM PUBLIC,anon,authenticated,service_role;

-- Contrôle de minuit : une ligne par jour de référence (idempotence du cron).
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_controles (
  jour date PRIMARY KEY,
  resultat jsonb NOT NULL,
  fait_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_goulag_controles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_controles FROM PUBLIC,anon,authenticated,service_role;

-- ---------------------------------------------------------------------------
-- Primitives internes (jamais exposées aux rôles réseau).
-- ---------------------------------------------------------------------------

-- Refus commun : moteur absent ou non activé. NULL = les ordres peuvent s'exécuter.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_ordres_refus_interne()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
  SELECT CASE WHEN EXISTS (SELECT 1 FROM public.sovarka_goulag_configuration c
                            WHERE c.singleton AND c.active)
         THEN NULL ELSE jsonb_build_object('ok',false,'raison','goulag_non_active') END
$$;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_jour_interne()
RETURNS date LANGUAGE sql STABLE SET search_path TO 'public','pg_temp' AS $$
  SELECT (now() AT TIME ZONE 'Europe/Paris')::date
$$;

-- Ligne du registre de la détention ACTIVE d'un PJ au goulag (NULL si aucune).
CREATE OR REPLACE FUNCTION public.sovarka_goulag_detention_registree_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
  SELECT r.detention_id FROM public.sovarka_goulag_registre r
    JOIN public.detentions d ON d.id = r.detention_id
   WHERE r.nom = p_nom AND d.nom = p_nom AND d.country = 'soviet' AND coalesce(d.qhs,false)
     AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
     AND r.liberation_le IS NULL AND r.evasion_le IS NULL
   ORDER BY d.created_at DESC LIMIT 1
$$;

-- Personne habilitée et physiquement présente dans une pièce du goulag : entrée enregistrée par
-- le transport serveur (sovarka_goulag_visites.present) et AUCUNE détention en cours.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_habilite_present_interne(p_nom text, p_piece text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees d
      JOIN public.sovarka_goulag_visites v ON v.nom = d.name AND v.present
     WHERE d.name = p_nom AND d.country = 'soviet' AND d.current_city = 'qhs'
       AND d.current_building = 'qhs-prison' AND d.current_room = p_piece)
     AND NOT EXISTS (SELECT 1 FROM public.detention_active(p_nom))
$$;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_incident_interne(
  p_cle text, p_nature text, p_nom text, p_detention_id text, p_details jsonb)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_n integer;
BEGIN
  INSERT INTO public.sovarka_goulag_incidents(cle,nature,nom,detention_id,details)
  VALUES (p_cle,p_nature,p_nom,p_detention_id,coalesce(p_details,'{}'::jsonb))
  ON CONFLICT (cle) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n = 1;
END $$;

-- Ouverture du registre à l'admission. Déclencheur DIFFÉRÉ : il s'exécute à la validation de la
-- transaction de condamnation, une fois le jugement, la fiche et la détention définitifs.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_registre_ouvrir()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE d public.detentions%ROWTYPE; v_prec public.sovarka_goulag_registre%ROWTYPE;
        v_j record; v_peine jsonb; v_rest integer; v_secondes numeric;
BEGIN
  SELECT * INTO d FROM public.detentions WHERE id = NEW.id;
  IF NOT FOUND OR d.country IS DISTINCT FROM 'soviet' OR NOT coalesce(d.qhs,false)
     OR d.mode_fin IS NOT NULL OR d.jour_fin_effective IS NOT NULL OR d.nom IS NULL THEN
    RETURN NULL; END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_goulag_registre WHERE detention_id = d.id) THEN
    RETURN NULL; END IF;
  -- Reprise après évasion : le reliquat figé est exactement repris, sans peine ajoutée,
  -- avec les références judiciaires de la condamnation initiale.
  -- Le jugement réel rendu dans la MÊME transaction (même horodatage), s'il n'est pas déjà compté.
  SELECT j.id, j.country, j.city, j.juge,
         CASE WHEN coalesce(j.data->>'jours','') ~ '^[0-9]+$' THEN (j.data->>'jours')::integer ELSE 0 END AS jours
    INTO v_j FROM public.jugements j
   WHERE j.accuse = d.nom AND j.country = 'soviet' AND j.data->>'genre' = 'qhs'
     AND j.created_at = now()
     AND NOT EXISTS (SELECT 1 FROM public.sovarka_goulag_registre_jugements g WHERE g.jugement_id = j.id)
   ORDER BY j.id LIMIT 1;
  SELECT r.* INTO v_prec FROM public.sovarka_goulag_traversees t
    JOIN public.sovarka_goulag_registre r ON r.detention_id = t.detention_id
   WHERE t.nom = d.nom AND t.nouvelle_detention_id = d.id
   LIMIT 1;
  IF FOUND THEN
    -- Reliquat figé + peine nouvellement prononcée (une seule fois), références initiales conservées.
    INSERT INTO public.sovarka_goulag_registre(detention_id,nom,jugement_id,tribunal_pays,
      tribunal_ville,juge,detention_precedente_id,jours_restants)
    VALUES (d.id,d.nom,v_prec.jugement_id,v_prec.tribunal_pays,v_prec.tribunal_ville,
      v_prec.juge,v_prec.detention_id,v_prec.jours_restants + coalesce(v_j.jours,0))
    ON CONFLICT (detention_id) DO NOTHING;
    IF v_j.id IS NOT NULL THEN
      INSERT INTO public.sovarka_goulag_registre_jugements(jugement_id,detention_id,jours,ajoute)
      VALUES (v_j.id,d.id,v_j.jours,true) ON CONFLICT (jugement_id) DO NOTHING;
    END IF;
    UPDATE public.sovarka_goulag_registre SET reincarcere_le = now()
     WHERE detention_id = v_prec.detention_id AND reincarcere_le IS NULL;
    RETURN NULL;
  END IF;
  -- Nouvelle condamnation : la durée prononcée. Prolongation d'une détention existante :
  -- le reste calendaire à l'instant du transfert (aucun jour ne sera plus perdu ensuite).
  IF d.created_at = now() AND d.jour_fin IS NOT NULL AND d.jour_debut IS NOT NULL THEN
    v_rest := greatest(0, d.jour_fin - d.jour_debut);
  ELSE
    SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees WHERE name = d.nom;
    IF coalesce(v_peine->>'debutTs','') ~ '^[0-9]+(\.[0-9]+)?$'
       AND coalesce(v_peine->>'jours','') ~ '^[0-9]+(\.[0-9]+)?$' THEN
      v_secondes := (v_peine->>'debutTs')::numeric/1000 + (v_peine->>'jours')::numeric*86400
                    - extract(epoch FROM now());
      v_rest := ceil(greatest(0, v_secondes - 1) / 86400)::integer;
    ELSE
      v_rest := greatest(0, coalesce(d.jour_fin - d.jour_debut, 0));
    END IF;
  END IF;
  -- Références : le jugement de la même transaction ; sinon inconnues (jamais reconstituées).
  INSERT INTO public.sovarka_goulag_registre(detention_id,nom,jugement_id,tribunal_pays,
    tribunal_ville,juge,detention_precedente_id,jours_restants)
  VALUES (d.id,d.nom,v_j.id,v_j.country,v_j.city,v_j.juge,d.detention_precedente_id,v_rest)
  ON CONFLICT (detention_id) DO NOTHING;
  -- Sa durée est déjà incluse dans le compteur initial : comptée, non ajoutée.
  IF v_j.id IS NOT NULL THEN
    INSERT INTO public.sovarka_goulag_registre_jugements(jugement_id,detention_id,jours,ajoute)
    VALUES (v_j.id,d.id,v_j.jours,false) ON CONFLICT (jugement_id) DO NOTHING;
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS sovarka_goulag_registre_ouverture ON public.detentions;
CREATE CONSTRAINT TRIGGER sovarka_goulag_registre_ouverture
  AFTER INSERT OR UPDATE OF qhs ON public.detentions
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW WHEN (NEW.country = 'soviet' AND NEW.qhs IS TRUE AND NEW.mode_fin IS NULL)
  EXECUTE FUNCTION public.sovarka_goulag_registre_ouvrir();

-- Peine ajoutée pendant une détention au goulag déjà enregistrée (nouveau jugement exécuté par
-- prolongation) : la durée prononcée s'ajoute une fois au compteur. Différé, après l'ouverture
-- éventuelle du registre dans la même transaction (qui compte alors ce jugement elle-même).
CREATE OR REPLACE FUNCTION public.sovarka_goulag_registre_jugement()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE j public.jugements%ROWTYPE; v_det text; v_jours integer;
BEGIN
  SELECT * INTO j FROM public.jugements WHERE id = NEW.id;
  IF NOT FOUND OR j.country IS DISTINCT FROM 'soviet' OR j.data->>'genre' IS DISTINCT FROM 'qhs'
     OR j.executee IS NOT TRUE OR j.accuse IS NULL THEN RETURN NULL; END IF;
  IF EXISTS (SELECT 1 FROM public.sovarka_goulag_registre_jugements WHERE jugement_id = j.id) THEN
    RETURN NULL; END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(j.accuse);
  IF v_det IS NULL THEN RETURN NULL; END IF;
  v_jours := CASE WHEN coalesce(j.data->>'jours','') ~ '^[0-9]+$' THEN (j.data->>'jours')::integer ELSE 0 END;
  INSERT INTO public.sovarka_goulag_registre_jugements(jugement_id,detention_id,jours,ajoute)
  VALUES (j.id, v_det, v_jours, true) ON CONFLICT (jugement_id) DO NOTHING;
  IF FOUND THEN
    UPDATE public.sovarka_goulag_registre SET jours_restants = jours_restants + v_jours
     WHERE detention_id = v_det;
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS sovarka_goulag_registre_jugement ON public.jugements;
CREATE CONSTRAINT TRIGGER sovarka_goulag_registre_jugement
  AFTER INSERT OR UPDATE OF executee ON public.jugements
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW WHEN (NEW.country = 'soviet' AND NEW.executee IS TRUE)
  EXECUTE FUNCTION public.sovarka_goulag_registre_jugement();

REVOKE ALL ON FUNCTION public.sovarka_goulag_ordres_refus_interne() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_jour_interne() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_detention_registree_interne(text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_habilite_present_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_incident_interne(text,text,text,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_registre_ouvrir() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_registre_jugement() FROM PUBLIC,anon,authenticated,service_role;
