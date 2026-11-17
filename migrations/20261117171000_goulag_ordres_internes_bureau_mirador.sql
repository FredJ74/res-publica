-- Goulag de Sovarka — ordres internes, lot 3/4 : entrée, bureau du chef, mirador, minuit.
-- Décisions de Fred du 17/11/2026. Toutes les écritures sont faites ici, sous verrou, avec une
-- clé de requête rejouable : un double clic ou une réponse perdue ne rejoue jamais un effet.
DO $goulag_ordres_prerequis$
BEGIN
  IF to_regprocedure('public.sovarka_goulag_cachot_placer_interne(text,text,integer,text)') IS NULL THEN
    RAISE EXCEPTION 'goulag_ordres_lot2_requis'; END IF;
END $goulag_ordres_prerequis$;

-- Coûts décidés par Fred le 17/11/2026 : 1 PA pour l'interrogateur, 1 PA pour le juge. Déclarés au
-- référentiel que payer_ordre_interne exige (fn, pa, cost exacts) ; prélevés côté serveur uniquement.
INSERT INTO public.ordres_couts(fn,pa,cost)
SELECT x.fn, x.pa, x.cost FROM (VALUES ('sovarka_goulag_interroger',1,0),('sovarka_goulag_sanction',1,0)) AS x(fn,pa,cost)
WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn AND o.pa = x.pa AND o.cost = x.cost);

CREATE TABLE IF NOT EXISTS public.sovarka_goulag_interrogatoires (
  requete uuid PRIMARY KEY,
  interrogateur text NOT NULL REFERENCES public.personnages_donnees(name),
  detenu text NOT NULL REFERENCES public.personnages_donnees(name),
  detention_id text NOT NULL REFERENCES public.detentions(id),
  vol_interrogateur numeric NOT NULL,
  vol_detenu numeric NOT NULL,
  probabilite integer NOT NULL CHECK (probabilite BETWEEN 5 AND 95),
  jet integer NOT NULL CHECK (jet BETWEEN 1 AND 100),
  reussi boolean NOT NULL,
  trace_cle text,
  juge text,
  mail_id text,
  pa_avant integer NOT NULL,
  pa_apres integer NOT NULL CHECK (pa_apres >= 1),
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sovarka_goulag_interrogatoires_detenu_idx ON public.sovarka_goulag_interrogatoires(detenu);
ALTER TABLE public.sovarka_goulag_interrogatoires ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_interrogatoires FROM PUBLIC,anon,authenticated,service_role;

-- Une trace ne peut être révélée qu'une seule fois (clé primaire).
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_traces_revelees (
  nom text NOT NULL REFERENCES public.personnages_donnees(name),
  trace_cle text NOT NULL,
  interrogatoire uuid NOT NULL REFERENCES public.sovarka_goulag_interrogatoires(requete),
  juge text,
  revelee_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (nom, trace_cle)
);
ALTER TABLE public.sovarka_goulag_traces_revelees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_traces_revelees FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE IF NOT EXISTS public.sovarka_goulag_corruptions (
  requete uuid PRIMARY KEY,
  detention_id text NOT NULL REFERENCES public.detentions(id),
  nom text NOT NULL REFERENCES public.personnages_donnees(name),
  jour date NOT NULL,
  objet jsonb NOT NULL,
  objet_perdu boolean NOT NULL DEFAULT true CHECK (objet_perdu),
  taux integer NOT NULL CHECK (taux BETWEEN 0 AND 90),
  jet integer NOT NULL CHECK (jet BETWEEN 1 AND 100),
  reussi boolean NOT NULL,
  resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  CHECK (jsonb_typeof(objet) = 'object')
);
CREATE INDEX IF NOT EXISTS sovarka_goulag_corruptions_jour_idx ON public.sovarka_goulag_corruptions(detention_id, jour);
ALTER TABLE public.sovarka_goulag_corruptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_corruptions FROM PUBLIC,anon,authenticated,service_role;

-- ---------------------------------------------------------------------------
-- Entrée : « Consulter la liste des détenus » (statut constaté au dernier contrôle de minuit).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_goulag_liste_detenus()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); v_refus jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF NOT public.sovarka_goulag_habilite_present_interne(v_nom,'entree_qhs') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_habilite_entree'); END IF;
  RETURN jsonb_build_object('ok',true,'detenus',coalesce((
    SELECT jsonb_agg(jsonb_build_object('nom',r.nom,'jours_restants',r.jours_restants,
             'statut',r.statut_controle,'controle_jour',r.controle_jour)
           ORDER BY r.nom, r.entree_le)
      FROM public.sovarka_goulag_registre r
     WHERE r.liberation_le IS NULL AND r.reincarcere_le IS NULL), '[]'::jsonb));
END $$;

-- ---------------------------------------------------------------------------
-- Bureau du chef administratif.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_goulag_registre_consulter()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); v_refus jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF NOT public.sovarka_goulag_habilite_present_interne(v_nom,'bureau_chef') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_habilite_bureau'); END IF;
  -- Une évasion n'est JAMAIS une sortie effective : deux champs distincts.
  RETURN jsonb_build_object('ok',true,'registre',coalesce((
    SELECT jsonb_agg(jsonb_build_object('nom',r.nom,'detention_id',r.detention_id,
             'jugement_id',r.jugement_id,'tribunal_pays',r.tribunal_pays,'tribunal_ville',r.tribunal_ville,
             'entree_le',r.entree_le,'sortie_le',r.liberation_le,'evasion_le',r.evasion_le,
             'reincarcere_le',r.reincarcere_le,'interrogatoires',r.interrogatoires)
           ORDER BY r.entree_le DESC, r.detention_id)
      FROM (SELECT * FROM public.sovarka_goulag_registre ORDER BY entree_le DESC LIMIT 500) r), '[]'::jsonb));
END $$;

-- Détenus actuellement au camp, pour choisir la personne interrogée ou sanctionnée.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_detenus_choisir()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); v_refus jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF NOT public.sovarka_goulag_habilite_present_interne(v_nom,'bureau_chef') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_habilite_bureau'); END IF;
  RETURN jsonb_build_object('ok',true,'detenus',coalesce((
    SELECT jsonb_agg(jsonb_build_object('nom',r.nom,'cachot_nuits',r.cachot_nuits) ORDER BY r.nom)
      FROM public.sovarka_goulag_registre r JOIN public.detentions d ON d.id = r.detention_id
     WHERE d.mode_fin IS NULL AND d.jour_fin_effective IS NULL
       AND r.liberation_le IS NULL AND r.evasion_le IS NULL), '[]'::jsonb));
END $$;

-- « Interroger un détenu » : −7 PA au détenu (plancher 1), refus à 1 PA ou moins, jet de VOL
-- borné 5–95 %, trace inconnue tirée au hasard et adressée au SEUL juge de la condamnation.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_interroger(p_detenu text, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); v_refus jsonb; v_det text; v_deja jsonb;
        d public.personnages_donnees%ROWTYPE; r public.sovarka_goulag_registre%ROWTYPE;
        v_vol_i numeric; v_vol_d numeric; v_proba integer; v_jet integer; v_reussi boolean;
        v_trace_cle text; v_trace_faits jsonb; v_mail jsonb; v_pa integer; v_res jsonb; v_ville text;
        v_paie jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(btrim(p_detenu),'') = '' THEN
    RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF NOT public.sovarka_goulag_habilite_present_interne(v_nom,'bureau_chef') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_habilite_bureau'); END IF;
  IF btrim(p_detenu) = v_nom THEN RETURN jsonb_build_object('ok',false,'raison','cible_invalide'); END IF;
  -- Verrou du détenu : sérialise deux interrogateurs simultanés et les rejeux.
  SELECT * INTO d FROM public.personnages_donnees WHERE name = btrim(p_detenu) FOR UPDATE;
  IF NOT FOUND OR d.country IS DISTINCT FROM 'soviet' THEN
    RETURN jsonb_build_object('ok',false,'raison','detenu_introuvable'); END IF;
  SELECT resultat INTO v_deja FROM public.sovarka_goulag_interrogatoires WHERE requete = p_requete;
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu',true); END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(d.name);
  SELECT * INTO r FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','detenu_introuvable'); END IF;
  IF coalesce(d.pa,0) <= 1 THEN
    RETURN jsonb_build_object('ok',false,'raison','detenu_epuise'); END IF;
  -- 1 PA pour l'interrogateur, prélevé par le serveur ; un refus n'a aucun autre effet.
  v_paie := public.payer_ordre_interne(v_nom, 'sovarka_goulag_interroger', 1, 0);
  IF coalesce((v_paie->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_pa := greatest(1, coalesce(d.pa,0) - 7);
  UPDATE public.personnages_donnees SET pa = v_pa, updated_at = clock_timestamp() WHERE name = d.name;
  SELECT public.assemblee_stat_base(CASE WHEN jsonb_typeof(stats) = 'object' THEN stats ELSE '{}'::jsonb END,'VOL')
    INTO v_vol_i FROM public.personnages_donnees WHERE name = v_nom;
  v_vol_d := public.assemblee_stat_base(CASE WHEN jsonb_typeof(d.stats) = 'object' THEN d.stats ELSE '{}'::jsonb END,'VOL');
  v_proba := least(95, greatest(5, round(50 + 5 * (v_vol_i - v_vol_d))::integer));
  v_jet := floor(random() * 100)::integer + 1;
  v_reussi := v_jet <= v_proba;
  IF v_reussi THEN
    WITH traces AS (
      SELECT 'historique_crimes:' || md5(d.name || '|' || coalesce(t.value->>'id','') || '|'
               || coalesce(t.value->>'acte','') || '|' || coalesce(t.value->>'cible','') || '|'
               || coalesce(t.value->>'jour','') || '|' || coalesce(t.value->>'ts','')) AS cle,
             jsonb_build_object('acte',t.value->>'acte','victime',t.value->>'cible',
               'jour',t.value->'jour') AS faits
        FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.historique_crimes) = 'array'
               THEN d.historique_crimes ELSE '[]'::jsonb END) t(value)
       WHERE coalesce(t.value->>'acte','') <> ''
      UNION ALL
      SELECT 'actions_tracables:' || a.id,
             jsonb_build_object('acte',a.type_action,'victime',a.cible,'jour',a.jour,'ville',a.city)
        FROM public.actions_tracables a
       WHERE a.auteur = d.name AND coalesce(a.type_action,'') <> '' AND NOT coalesce(a.decouvert,false)
    )
    SELECT tr.cle, tr.faits INTO v_trace_cle, v_trace_faits FROM traces tr
     WHERE NOT EXISTS (SELECT 1 FROM public.sovarka_goulag_traces_revelees x
                        WHERE x.nom = d.name AND x.trace_cle = tr.cle)
     ORDER BY random() LIMIT 1;
  END IF;
  UPDATE public.sovarka_goulag_registre SET interrogatoires = interrogatoires + 1
   WHERE detention_id = r.detention_id;
  v_res := jsonb_build_object('ok',true,'detenu',d.name,'probabilite',v_proba,'jet',v_jet,
    'reussi',v_reussi,'revelation',v_trace_cle IS NOT NULL,
    'transmis_au_juge',false,'pa_detenu',v_pa,'pa',(v_paie->>'pa')::integer);
  INSERT INTO public.sovarka_goulag_interrogatoires(requete,interrogateur,detenu,detention_id,
    vol_interrogateur,vol_detenu,probabilite,jet,reussi,trace_cle,juge,pa_avant,pa_apres,resultat)
  VALUES (p_requete,v_nom,d.name,r.detention_id,v_vol_i,v_vol_d,v_proba,v_jet,v_reussi,
    v_trace_cle,r.juge,d.pa,v_pa,v_res);
  IF v_trace_cle IS NOT NULL THEN
    INSERT INTO public.sovarka_goulag_traces_revelees(nom,trace_cle,interrogatoire,juge)
    VALUES (d.name,v_trace_cle,p_requete,r.juge);
    IF r.juge IS NOT NULL THEN
      v_ville := v_trace_faits->>'ville';
      v_mail := public.mail_systeme_poser_interne('Camp de rééducation de Sovarka', r.juge,
        'Interrogatoire au goulag : ' || d.name,
        'Le détenu ' || d.name || ', condamné au goulag par votre jugement'
        || coalesce(' ' || r.jugement_id, '') || ', a été interrogé par ' || v_nom
        || '. Il a révélé un fait : « ' || coalesce(v_trace_faits->>'acte','?') || ' »'
        || coalesce(', visant ' || nullif(v_trace_faits->>'victime',''), '')
        || coalesce(', jour ' || nullif(v_trace_faits->>'jour',''), '')
        || coalesce(', lieu ' || nullif(v_ville,''), '')
        || '. Ce courrier vous est strictement personnel.');
      IF coalesce((v_mail->>'ok')::boolean,false) THEN
        v_res := v_res || jsonb_build_object('transmis_au_juge',true);
        UPDATE public.sovarka_goulag_interrogatoires SET mail_id = v_mail->>'id', resultat = v_res
         WHERE requete = p_requete;
      END IF;
    END IF;
  END IF;
  RETURN v_res;
END $$;

-- « Prononcer une sanction disciplinaire » : juge de Sovarka physiquement présent au bureau.
-- Le ministre de la Justice n'a pas ce pouvoir du fait de sa fonction.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_sanctionner(p_detenu text, p_nuits integer, p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); v_refus jsonb; v_det text; v_res jsonb;
        d public.personnages_donnees%ROWTYPE; v_cle text; v_paie jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(btrim(p_detenu),'') = '' OR p_nuits NOT IN (1,2) OR p_nuits IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF public.sovarka_goulag_role_interne(v_nom) IS DISTINCT FROM 'juge' THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_juge_sovarka'); END IF;
  IF NOT public.sovarka_goulag_habilite_present_interne(v_nom,'bureau_chef') THEN
    RETURN jsonb_build_object('ok',false,'raison','juge_absent_du_bureau'); END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = btrim(p_detenu) FOR UPDATE;
  IF NOT FOUND OR d.country IS DISTINCT FROM 'soviet' THEN
    RETURN jsonb_build_object('ok',false,'raison','detenu_introuvable'); END IF;
  v_cle := 'sanction:' || p_requete::text;
  IF EXISTS (SELECT 1 FROM public.sovarka_goulag_incidents WHERE cle = v_cle) THEN
    RETURN jsonb_build_object('ok',true,'rejeu',true,'detenu',d.name); END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(d.name);
  IF v_det IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','detenu_introuvable'); END IF;
  PERFORM 1 FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  -- 1 PA pour le juge, prélevé par le serveur ; un refus n'a aucun autre effet.
  v_paie := public.payer_ordre_interne(v_nom, 'sovarka_goulag_sanction', 1, 0);
  IF coalesce((v_paie->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_res := public.sovarka_goulag_cachot_placer_interne(d.name, v_det, p_nuits, 'decision_judiciaire');
  IF coalesce((v_res->>'ok')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'goulag_sanction_impossible'; END IF;
  PERFORM public.sovarka_goulag_incident_interne(v_cle,'sanction_disciplinaire',d.name,v_det,
    jsonb_build_object('nuits',p_nuits,'juge',v_nom,'cachot_nuits',v_res->'cachot_nuits'));
  RETURN jsonb_build_object('ok',true,'detenu',d.name,'nuits',p_nuits,'cachot_nuits',v_res->'cachot_nuits',
    'pa',(v_paie->>'pa')::integer);
END $$;

-- ---------------------------------------------------------------------------
-- Mirador.
-- ---------------------------------------------------------------------------
-- « Corrompre le gardien » (règle définitive de Fred, 17/11/2026) :
--   un cadeau est OBLIGATOIRE à chaque tentative, dès la première ;
--   probabilité = min(90, 70 + 10 + 2 × CHARME) ;
--   le cadeau est un objet réel de l'inventaire SERVEUR (les objets confisqués à l'admission n'y sont plus),
--   transféré définitivement au gardien, réussite ou échec (un seul exemplaire d'une pile) ;
--   plusieurs tentatives par jour, un nouvel objet à chaque fois ;
--   la réussite accorde le bonus d'évasion (95 % au lieu de 80 %), valable pour la prochaine tentative.
-- Pas d'ordre de remise d'objet : l'objet est choisi dans l'inventaire au moment de la tentative.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_corrompre(p_requete uuid, p_index integer DEFAULT NULL, p_signature jsonb DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); v_refus jsonb; v_det text; v_deja jsonb;
        p public.personnages_donnees%ROWTYPE; r public.sovarka_goulag_registre%ROWTYPE;
        v_jour date := public.sovarka_goulag_jour_interne(); v_pos integer; v_objet jsonb; v_cadeau jsonb;
        v_cha numeric; v_taux integer; v_jet integer; v_ok boolean; v_inv jsonb; v_qte integer; v_res jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  -- Verrou du détenu d'abord : deux tentatives simultanées sont sérialisées (inventaire et compteurs).
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_nom AND user_id = auth.uid() FOR UPDATE;
  SELECT resultat INTO v_deja FROM public.sovarka_goulag_corruptions WHERE requete = p_requete AND nom = v_nom;
  IF FOUND THEN RETURN v_deja || jsonb_build_object('rejeu',true); END IF;
  IF (p.country, p.current_city, p.current_building, p.current_room)
     IS DISTINCT FROM ('soviet','qhs','qhs-prison','mirador') THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_mirador'); END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(v_nom);
  SELECT * INTO r FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_detenu_goulag'); END IF;
  IF r.corruption_bonus THEN
    RETURN jsonb_build_object('ok',false,'raison','gardien_deja_corrompu'); END IF;
  -- Aucun jet sans cadeau : refus sans le moindre effet.
  IF p_signature IS NULL OR jsonb_typeof(p_signature) IS DISTINCT FROM 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','cadeau_obligatoire'); END IF;
  v_inv := CASE WHEN jsonb_typeof(p.inventory) = 'array' THEN p.inventory ELSE '[]'::jsonb END;
  v_pos := public.inventaire_localiser(v_inv, coalesce(p_index,-1), p_signature);
  IF v_pos < 0 THEN RETURN jsonb_build_object('ok',false,'raison','objet_introuvable'); END IF;
  v_objet := v_inv -> v_pos;
  IF public.inventaire_objet_protege(p.quete_carriere, v_objet) THEN
    RETURN jsonb_build_object('ok',false,'raison','objet_protege'); END IF;
  v_cha := public.assemblee_stat_base(CASE WHEN jsonb_typeof(p.stats) = 'object' THEN p.stats ELSE '{}'::jsonb END,'CHA');
  v_taux := greatest(0, least(90, floor(70 + 10 + 2 * v_cha)::integer));
  v_jet := floor(random() * 100)::integer + 1;
  v_ok := v_jet <= v_taux;
  -- Transfert définitif au gardien : un exemplaire, quelle que soit l'issue, dans la même transaction.
  v_qte := CASE WHEN coalesce(v_objet->>'qty','') ~ '^[0-9]+$' THEN (v_objet->>'qty')::integer ELSE 1 END;
  v_cadeau := CASE WHEN v_qte > 1 THEN jsonb_set(v_objet, '{qty}', '1'::jsonb) ELSE v_objet END;
  IF v_qte > 1 THEN v_inv := jsonb_set(v_inv, ARRAY[v_pos::text,'qty'], to_jsonb(v_qte - 1));
  ELSE v_inv := public.inventaire_retirer_position(v_inv, v_pos); END IF;
  UPDATE public.personnages_donnees SET inventory = v_inv, updated_at = now() WHERE name = v_nom;
  IF (SELECT inventory FROM public.personnages_donnees WHERE name = v_nom) IS DISTINCT FROM v_inv THEN
    RAISE EXCEPTION 'goulag_cadeau_refuse'; END IF;
  IF v_ok THEN
    UPDATE public.sovarka_goulag_registre SET corruption_bonus = true WHERE detention_id = r.detention_id;
  END IF;
  v_res := jsonb_build_object('ok',true,'reussi',v_ok,'taux',v_taux,'jet',v_jet,
    'cadeau',v_cadeau,'inventory',v_inv);
  INSERT INTO public.sovarka_goulag_corruptions(requete,detention_id,nom,jour,objet,objet_perdu,taux,jet,reussi,resultat)
  VALUES (p_requete,r.detention_id,v_nom,v_jour,v_cadeau,true,v_taux,v_jet,v_ok,v_res);
  RETURN v_res;
END $$;

-- « Consulter les incidents du camp » : seulement le goulag de Sovarka.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_incidents_consulter()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); v_refus jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF NOT public.sovarka_goulag_habilite_present_interne(v_nom,'mirador') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_habilite_mirador'); END IF;
  RETURN jsonb_build_object('ok',true,'incidents',coalesce((
    SELECT jsonb_agg(jsonb_build_object('nature',i.nature,'nom',i.nom,'survenu_le',i.survenu_le,
             'nuits',i.details->'nuits','juge',i.details->>'juge','motif',i.details->>'motif')
           ORDER BY i.survenu_le DESC, i.id DESC)
      FROM (SELECT * FROM public.sovarka_goulag_incidents ORDER BY survenu_le DESC, id DESC LIMIT 200) i),
    '[]'::jsonb));
END $$;

-- ---------------------------------------------------------------------------
-- Contrôle de minuit (cron serveur, rôle service seulement), idempotent par jour.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_goulag_controle_minuit(p_jour date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_n integer; v_res jsonb; x record; v_present boolean;
        v_fuites integer := 0; v_absents integer := 0; v_lib integer := 0; v_detenus integer := 0;
BEGIN
  IF p_jour IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','jour_absent'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.sovarka_goulag_configuration c WHERE c.singleton AND c.active) THEN
    RETURN jsonb_build_object('ok',true,'inactif',true); END IF;
  INSERT INTO public.sovarka_goulag_controles(jour,resultat) VALUES (p_jour,'{}'::jsonb)
  ON CONFLICT (jour) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    SELECT resultat INTO v_res FROM public.sovarka_goulag_controles WHERE jour = p_jour;
    RETURN v_res || jsonb_build_object('deja_fait',true);
  END IF;
  FOR x IN SELECT r.*, d.mode_fin AS d_mode, d.date_fin_effective AS d_fin,
                  pd.country AS p_pays, pd.current_city AS p_ville, pd.current_building AS p_bat
             FROM public.sovarka_goulag_registre r
             JOIN public.detentions d ON d.id = r.detention_id
             LEFT JOIN public.personnages_donnees pd ON pd.name = r.nom
            WHERE r.liberation_le IS NULL AND r.reincarcere_le IS NULL
            ORDER BY r.detention_id FOR UPDATE OF r LOOP
    IF x.evasion_le IS NOT NULL OR x.d_mode = 'evasion' THEN
      -- Absence constatée : le reliquat reste exactement celui figé au départ.
      IF x.statut_controle <> 'en_fuite' THEN
        UPDATE public.sovarka_goulag_registre SET statut_controle = 'en_fuite', present_controle = false,
          controle_jour = p_jour WHERE detention_id = x.detention_id;
        PERFORM public.sovarka_goulag_incident_interne('absence:' || x.detention_id, 'absence_minuit',
          x.nom, x.detention_id, jsonb_build_object('motif','evasion','jour',p_jour));
        v_fuites := v_fuites + 1;
      ELSE
        UPDATE public.sovarka_goulag_registre SET controle_jour = p_jour WHERE detention_id = x.detention_id;
      END IF;
    ELSIF x.d_mode IS NOT NULL THEN
      -- Fin de détention par une autre voie existante (grâce, etc.) : sortie effective réelle.
      UPDATE public.sovarka_goulag_registre SET liberation_le = coalesce(x.d_fin, now()),
        controle_jour = p_jour WHERE detention_id = x.detention_id;
      v_lib := v_lib + 1;
    ELSE
      v_present := (x.p_pays, x.p_ville, x.p_bat) IS NOT DISTINCT FROM ('soviet','qhs','qhs-prison');
      UPDATE public.sovarka_goulag_registre
         SET statut_controle = CASE WHEN x.jours_restants = 0 THEN 'liberation_en_attente' ELSE 'detenu' END,
             present_controle = v_present, controle_jour = p_jour
       WHERE detention_id = x.detention_id;
      IF NOT v_present THEN
        PERFORM public.sovarka_goulag_incident_interne('absence:' || x.detention_id || ':' || p_jour,
          'absence_minuit', x.nom, x.detention_id, jsonb_build_object('motif','hors_du_camp','jour',p_jour));
        v_absents := v_absents + 1;
      END IF;
      v_detenus := v_detenus + 1;
    END IF;
  END LOOP;
  v_res := jsonb_build_object('ok',true,'jour',p_jour,'detenus',v_detenus,'en_fuite',v_fuites,
    'absents',v_absents,'sorties_constatees',v_lib);
  UPDATE public.sovarka_goulag_controles SET resultat = v_res WHERE jour = p_jour;
  RETURN v_res;
END $$;

REVOKE ALL ON FUNCTION public.sovarka_goulag_liste_detenus() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_registre_consulter() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_detenus_choisir() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_interroger(text,uuid) FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_sanctionner(text,integer,uuid) FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_corrompre(uuid,integer,jsonb) FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_incidents_consulter() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_controle_minuit(date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_liste_detenus() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_registre_consulter() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_detenus_choisir() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_interroger(text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_sanctionner(text,integer,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_corrompre(uuid,integer,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_incidents_consulter() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_controle_minuit(date) TO service_role;
