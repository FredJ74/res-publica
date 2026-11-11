-- Pavillon diplomatique de Novomirsk. Fred 11/11 : 1 PSK = 1 FR (parité 1, sans frais).
-- Nouvelle mécanique strictement circonscrite au pavillon ; aucun changement global des devises.
CREATE TABLE IF NOT EXISTS public.pavillon_baux (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  piece text NOT NULL CHECK (piece IN ('suite_parti','suite_privee','suite_presidentielle')),
  locataire text NOT NULL, pays_payeur text NOT NULL, poste_payeur text NOT NULL,
  caisse_payeur text NOT NULL, debut date NOT NULL, fin_excl date NOT NULL,
  prix_jour integer NOT NULL CHECK (prix_jour IN (500,650,800)),
  statut text NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif','expire','resilie')),
  signe_le timestamptz NOT NULL DEFAULT now(),
  CHECK (fin_excl > debut)
);
CREATE UNIQUE INDEX IF NOT EXISTS pavillon_suite_active_unique ON public.pavillon_baux(piece) WHERE statut='actif';
CREATE INDEX IF NOT EXISTS pavillon_baux_beneficiaire_idx ON public.pavillon_baux(locataire,statut,fin_excl);
ALTER TABLE public.pavillon_baux ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pavillon_baux FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS public.pavillon_receptions (
  jour date PRIMARY KEY, acteur text NOT NULL, pays_payeur text NOT NULL,
  poste_payeur text NOT NULL, caisse_payeur text NOT NULL,
  montant integer NOT NULL DEFAULT 1500 CHECK (montant=1500),
  cree_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.pavillon_receptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pavillon_receptions FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS public.pavillon_recus (
  acteur text NOT NULL, requete uuid NOT NULL, resultat jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (acteur,requete)
);
ALTER TABLE public.pavillon_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pavillon_recus FROM PUBLIC,anon,authenticated;

-- Le pays du poste vient de son registre, JAMAIS du pays de déplacement du PJ.
-- Pour un ambassadeur, l'institution payeuse est le ministère des Affaires étrangères
-- du pays d'origine ; aucune caisse d'ambassade non déclarée n'est créée.
CREATE OR REPLACE FUNCTION public.pavillon_qualite_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $fn$
DECLARE p record; r record; v_pays text; v_poste text; v_caisse text;
BEGIN
  IF p_acteur IS DISTINCT FROM public.mon_personnage() THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT country,current_city,current_building,current_room,poste,poste_depute
    INTO p FROM public.personnages_donnees WHERE name=p_acteur;
  IF NOT FOUND OR p.country IS DISTINCT FROM 'soviet' OR p.current_city IS DISTINCT FROM 'capitale'
     OR p.current_building IS DISTINCT FROM 'pavillon-ambassadeurs-novomirsk' THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_pavillon');
  END IF;

  SELECT a.empire INTO v_pays FROM public.ambassades_ouvertes a
    WHERE a.pays_hote='soviet' AND a.empire <> 'soviet'
      AND a.data->>'ambassadeur'=p_acteur ORDER BY a.empire LIMIT 1;
  IF v_pays IS NOT NULL THEN v_poste := 'min_ae'; END IF;
  IF v_pays IS NULL AND p.poste IS NOT NULL AND p.poste->>'id' IS NOT NULL THEN
    SELECT a.country,a.poste_id INTO v_pays,v_poste FROM public.postes_attribues a
     WHERE a.titulaire=p_acteur AND a.country <> 'soviet'
       AND a.poste_id=p.poste->>'id'
       AND (a.city IS NULL OR a.city IS NOT DISTINCT FROM p.poste->>'city')
       AND (a.poste_id='president' OR a.poste_id='pm' OR a.poste_id LIKE 'min_%')
     ORDER BY a.updated_at DESC NULLS LAST LIMIT 1;
  END IF;
  -- Le mandat présidentiel est dans cycles_electoraux, parfois sans poste attribué.
  IF v_pays IS NULL THEN
    SELECT split_part(c.id,'_',1) INTO v_pays FROM public.cycles_electoraux c
     WHERE c.id LIKE '%_president' AND c.id NOT LIKE 'soviet_%'
       AND c.data::jsonb->>'eluId'=p_acteur
     ORDER BY c.id LIMIT 1;
    IF v_pays IS NOT NULL THEN v_poste:='president'; END IF;
  END IF;
  IF v_pays IS NULL AND p.poste_depute IS NOT NULL AND
       p.poste_depute->>'country' <> 'soviet' THEN
    v_pays := nullif(p.poste_depute->>'country','');
    v_poste := 'depute';
  END IF;
  IF v_pays IS NULL OR v_poste IS NULL OR v_pays='soviet' THEN
    RETURN jsonb_build_object('ok',false,'raison','dignitaire_etranger_requis');
  END IF;
  v_caisse := public.salaire_caisse_de(v_poste,v_pays,NULL);
  IF v_caisse IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','caisse_institution_absente','poste',v_poste);
  END IF;
  RETURN jsonb_build_object('ok',true,'pays',v_pays,'poste',v_poste,
    'caisse',v_caisse,'piece',p.current_room);
END $fn$;
REVOKE ALL ON FUNCTION public.pavillon_qualite_interne(text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.pavillon_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $fn$
DECLARE moi text := public.mon_personnage(); j date := (now() AT TIME ZONE 'Europe/Paris')::date;
  q jsonb; b record; v_prix integer;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  q:=public.pavillon_qualite_interne(moi);
  IF q->>'raison'='pas_au_pavillon' THEN RETURN q; END IF;
  SELECT b0.* INTO b FROM public.pavillon_baux b0
   WHERE b0.piece=(SELECT current_room FROM public.personnages_donnees WHERE name=moi)
     AND b0.statut='actif' AND b0.fin_excl>j LIMIT 1;
  v_prix := CASE (SELECT current_room FROM public.personnages_donnees WHERE name=moi)
   WHEN 'suite_parti' THEN 500 WHEN 'suite_privee' THEN 650 WHEN 'suite_presidentielle' THEN 800
   ELSE NULL END;
  RETURN jsonb_build_object('ok',true,'autorisation',q->>'ok'='true',
    'raison',q->>'raison','prix_jour',v_prix,'monnaie',CASE WHEN v_prix IS NULL THEN 'PSK' ELSE 'FR' END,
    'reserve',b.id IS NOT NULL,'locataire',CASE WHEN b.locataire=moi THEN true ELSE false END,
    'fin_excl',b.fin_excl,'reception_reservee',EXISTS(SELECT 1 FROM public.pavillon_receptions WHERE jour=j));
END $fn$;
REVOKE ALL ON FUNCTION public.pavillon_etat() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pavillon_etat() TO authenticated;

CREATE OR REPLACE FUNCTION public.pavillon_acte(p_requete uuid,p_action text,p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $fn$
DECLARE moi text := public.mon_personnage(); j date := (now() AT TIME ZONE 'Europe/Paris')::date;
  q jsonb; r jsonb; b public.pavillon_baux%ROWTYPE; prix integer; somme integer;
  caisse text; titulaire text; v_bail uuid;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_action NOT IN ('reserver','renouveler','resilier','reception')
     OR p_piece NOT IN ('suite_parti','suite_privee','suite_presidentielle','salle_reception') THEN
    RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');
  END IF;
  IF (p_action='reception') IS DISTINCT FROM (p_piece='salle_reception') THEN
    RETURN jsonb_build_object('ok',false,'raison','piece_invalide');
  END IF;
  -- Serialise les deux requêtes d'un acteur, puis les demandes sur une même suite/salle.
  PERFORM pg_advisory_xact_lock(hashtext('pavillon:acteur:'||moi));
  SELECT resultat INTO r FROM public.pavillon_recus WHERE acteur=moi AND requete=p_requete;
  IF FOUND THEN RETURN r||jsonb_build_object('rejeu',true); END IF;
  q:=public.pavillon_qualite_interne(moi);
  IF q->>'ok' IS DISTINCT FROM 'true' THEN RETURN q; END IF;
  IF q->>'piece' IS DISTINCT FROM p_piece THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_dans_la_piece');
  END IF;
  caisse:=q->>'caisse';
  IF caisse IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','caisse_institution_absente'); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('pavillon:piece:'||p_piece||':'||CASE WHEN p_action='reception' THEN j::text ELSE 'baux' END));
  IF p_action='reception' THEN
    IF EXISTS(SELECT 1 FROM public.pavillon_receptions WHERE jour=j) THEN
      RETURN jsonb_build_object('ok',false,'raison','reception_deja_reservee');
    END IF;
    somme:=1500;
  ELSE
    prix := CASE p_piece WHEN 'suite_parti' THEN 500 WHEN 'suite_privee' THEN 650 ELSE 800 END;
    -- Les baux expirés sont conservés dans l'historique, mais ne bloquent pas une nouvelle signature.
    UPDATE public.pavillon_baux SET statut='expire' WHERE piece=p_piece AND statut='actif' AND fin_excl<=j;
    SELECT * INTO b FROM public.pavillon_baux WHERE piece=p_piece AND statut='actif' FOR UPDATE;
    IF p_action='reserver' THEN
      IF FOUND THEN RETURN jsonb_build_object('ok',false,'raison','suite_occupee'); END IF;
      somme:=prix*7;
    ELSE
      IF NOT FOUND OR b.locataire IS DISTINCT FROM moi THEN
        RETURN jsonb_build_object('ok',false,'raison','bail_non_titulaire'); END IF;
      IF p_action='renouveler' THEN somme:=prix*7;
      ELSE
        -- Le jour supplémentaire de ménage s'applique une seule fois ; la ligne devient résiliée.
        somme:=CASE WHEN b.fin_excl>j THEN prix ELSE 0 END;
      END IF;
    END IF;
  END IF;
  IF somme>0 THEN
    PERFORM set_config('rp.caisse_interne','on',true);
    r:=public.caisse_institution_mouvement(caisse,-somme,true);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN
      RETURN jsonb_build_object('ok',false,'raison',coalesce(r->>'raison','paiement_refuse'));
    END IF;
    -- Encaissement dans une caisse de Sovarka déjà existante ; les deux mouvements sont atomiques.
    r:=public.caisse_institution_mouvement('soviet_palais-gouvernement',somme,true);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN
      RAISE EXCEPTION 'pavillon_credit_sovarka_refuse: %',r->>'raison';
    END IF;
  END IF;
  IF p_action='reception' THEN
    INSERT INTO public.pavillon_receptions(jour,acteur,pays_payeur,poste_payeur,caisse_payeur)
      VALUES(j,moi,q->>'pays',q->>'poste',caisse);
    r:=jsonb_build_object('ok',true,'action',p_action,'jour',j,'montant',somme,
      'devise','PSK','conversion','1 PSK = 1 FR');
  ELSIF p_action='reserver' THEN
    INSERT INTO public.pavillon_baux(piece,locataire,pays_payeur,poste_payeur,caisse_payeur,
                                     debut,fin_excl,prix_jour)
      VALUES(p_piece,moi,q->>'pays',q->>'poste',caisse,j,j+7,prix) RETURNING id INTO v_bail;
    r:=jsonb_build_object('ok',true,'action',p_action,'bail',v_bail,
      'fin_excl',j+7,'montant',somme,'devise','FR','conversion','1 PSK = 1 FR');
  ELSIF p_action='renouveler' THEN
    UPDATE public.pavillon_baux SET fin_excl=b.fin_excl+7 WHERE id=b.id;
    r:=jsonb_build_object('ok',true,'action',p_action,'bail',b.id,
       'fin_excl',b.fin_excl+7,'montant',somme,'devise','FR');
  ELSE
    UPDATE public.pavillon_baux SET statut='resilie',fin_excl=j WHERE id=b.id;
    r:=jsonb_build_object('ok',true,'action',p_action,'bail',b.id,
      'montant',somme,'devise','FR','menage_jours',1);
  END IF;
  INSERT INTO public.pavillon_recus(acteur,requete,resultat) VALUES(moi,p_requete,r);
  RETURN r;
END $fn$;
REVOKE ALL ON FUNCTION public.pavillon_acte(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.pavillon_acte(uuid,text,text) TO authenticated;

-- Raccorder +3 PA seulement lors d'un sommeil civil réussi, sans toucher à l'hospitalisation ni au QHS.
-- Le verrou du PJ et le marqueur pa_repos_le existants assurent l'unicité du crédit.
DO $mig$
DECLARE ancien text; nouveau text; marqueur text;
BEGIN
  SELECT pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure) INTO ancien;
  IF position('pavillon_baux' in ancien)>0 THEN RETURN; END IF;
  marqueur := E'    v_nouveau := least(c_pa_max, greatest(0, v_pa + v_gain + v_bonus));\n  END IF;\n\n  UPDATE public.personnages_donnees';
  IF position(marqueur IN ancien)=0 THEN
    RAISE EXCEPTION 'pa_repos_nocturne version inconnue : raccordement Pavillon interdit';
  END IF;
  nouveau := replace(ancien,marqueur,
    E'    -- Bail diplomatique actif du Pavillon : bonus au repos autorisé, une seule fois/jour.\n' ||
    E'    IF EXISTS (SELECT 1 FROM public.pavillon_baux pb\n' ||
    E'      WHERE pb.locataire=p_acteur AND pb.statut=''actif'' AND pb.debut<=v_jour AND pb.fin_excl>v_jour)\n' ||
    E'    THEN v_gain := v_gain + 3; END IF;\n' ||
    marqueur);
  EXECUTE nouveau;
END $mig$;
-- Les anciens ordres génériques ne sont plus affichés. Fermer aussi leur porte serveur :
-- la base existante contient encore trois lignes du référentiel, même si aucun bail n'existe.
UPDATE public.locaux_loyers_referentiel
   SET louable=false
 WHERE batiment='pavillon-ambassadeurs-novomirsk'
   AND piece IN ('suite_parti','suite_privee','suite_presidentielle');

-- Fonction de repos : droits conservés par CREATE OR REPLACE, pas de GRANT supplémentaire.
