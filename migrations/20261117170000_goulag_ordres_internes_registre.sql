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

-- Paramètres NON DÉCIDÉS par le game designer : ils restent NULL et bloquent seulement l'ordre
-- qui en dépend (« Corrompre le gardien »), jamais le reste du camp. Aucune valeur inventée.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_parametres (
  cle text PRIMARY KEY CHECK (cle IN ('corruption_taux_base','corruption_bonus_objet',
    'corruption_objet_perdu_si_echec','corruption_tentatives_jour')),
  valeur numeric,
  description text NOT NULL,
  decide_le timestamptz
);
INSERT INTO public.sovarka_goulag_parametres(cle,valeur,description) VALUES
 ('corruption_taux_base',NULL,'Chance de réussite (en %) d''une corruption sans objet offert.'),
 ('corruption_bonus_objet',NULL,'Points de pourcentage ajoutés quand un objet est proposé au gardien.'),
 ('corruption_objet_perdu_si_echec',NULL,'1 : l''objet proposé est perdu même en cas d''échec ; 0 : il est rendu.'),
 ('corruption_tentatives_jour',NULL,'Nombre maximal de tentatives de corruption par détenu et par jour.')
ON CONFLICT (cle) DO NOTHING;
ALTER TABLE public.sovarka_goulag_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_parametres FROM PUBLIC,anon,authenticated,service_role;

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
  SELECT r.* INTO v_prec FROM public.sovarka_goulag_traversees t
    JOIN public.sovarka_goulag_registre r ON r.detention_id = t.detention_id
   WHERE t.nom = d.nom AND t.nouvelle_detention_id = d.id
   LIMIT 1;
  IF FOUND THEN
    INSERT INTO public.sovarka_goulag_registre(detention_id,nom,jugement_id,tribunal_pays,
      tribunal_ville,juge,detention_precedente_id,jours_restants)
    VALUES (d.id,d.nom,v_prec.jugement_id,v_prec.tribunal_pays,v_prec.tribunal_ville,
      v_prec.juge,v_prec.detention_id,v_prec.jours_restants)
    ON CONFLICT (detention_id) DO NOTHING;
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
  -- Le jugement réel rendu dans la MÊME transaction (même horodatage) ; sinon inconnu.
  SELECT j.id, j.country, j.city, j.juge INTO v_j FROM public.jugements j
   WHERE j.accuse = d.nom AND j.country = 'soviet' AND j.data->>'genre' = 'qhs'
     AND j.created_at = now()
   ORDER BY j.id LIMIT 1;
  INSERT INTO public.sovarka_goulag_registre(detention_id,nom,jugement_id,tribunal_pays,
    tribunal_ville,juge,detention_precedente_id,jours_restants)
  VALUES (d.id,d.nom,v_j.id,v_j.country,v_j.city,v_j.juge,d.detention_precedente_id,v_rest)
  ON CONFLICT (detention_id) DO NOTHING;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS sovarka_goulag_registre_ouverture ON public.detentions;
CREATE CONSTRAINT TRIGGER sovarka_goulag_registre_ouverture
  AFTER INSERT OR UPDATE OF qhs ON public.detentions
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW WHEN (NEW.country = 'soviet' AND NEW.qhs IS TRUE AND NEW.mode_fin IS NULL)
  EXECUTE FUNCTION public.sovarka_goulag_registre_ouvrir();

REVOKE ALL ON FUNCTION public.sovarka_goulag_ordres_refus_interne() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_jour_interne() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_detention_registree_interne(text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_habilite_present_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_incident_interne(text,text,text,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_registre_ouvrir() FROM PUBLIC,anon,authenticated,service_role;
