
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='60s';
DO $$ BEGIN
 IF to_regclass('public.sovarka_goulag_configuration') IS NOT NULL THEN
  RAISE EXCEPTION 'goulag_deja_installe_controle_requis';
 END IF;
END $$;
CREATE TEMP TABLE hg_goulag_install_empreintes(nom text PRIMARY KEY,nb bigint,empreinte text) ON COMMIT DROP;
DO $$ DECLARE t text; n bigint; h text; BEGIN
 FOREACH t IN ARRAY ARRAY['personnages_donnees','detentions','jugements','plaintes_en_cours','navigation_lieux_regles','caisses_autorites','caisses_batiments'] LOOP
  EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),'''' ORDER BY md5(to_jsonb(x)::text)),'''')) FROM public.%I x',t) INTO n,h;
  INSERT INTO hg_goulag_install_empreintes VALUES(t,n,h);
 END LOOP;
END $$;
CREATE TEMP TABLE hg_goulag_routes_avant ON COMMIT DROP AS
 SELECT to_jsonb(r) AS valeur FROM public.rue_noeuds_serveur r
 WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-ecole-foret';
INSERT INTO hg_goulag_install_empreintes
 SELECT 'routes_hors_raccord',count(*),md5(coalesce(string_agg(md5(to_jsonb(r)::text),'' ORDER BY md5(to_jsonb(r)::text)),''))
 FROM public.rue_noeuds_serveur r
 WHERE NOT(country='soviet' AND city='ville_b' AND noeud IN ('krasnov-rue-ecole-foret','krasnov-camp-bucherons'));
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-camp-bucherons') THEN
  RAISE EXCEPTION 'camp_deja_reference_a_controler';
 END IF;
END $$;
-- SOURCE 20261116104500_goulag_toundra_etats_serveur.sql
-- Goulag Sovarka : noyau transactionnel de traversée.
-- NON ACTIF tant que l'admission, la confiscation, le gel de peine et la récupération ne
-- sont pas raccordés. AUCUNE fonction publique ne crée de traversée.
-- Tous les verdicts et les PA sont décidés côté serveur ; jamais par le navigateur.

CREATE TABLE IF NOT EXISTS public.sovarka_goulag_traversees (
  nom text PRIMARY KEY REFERENCES public.personnages_donnees(name),
  destination text NOT NULL CHECK (destination IN ('starovka','krasnov')),
  statut text NOT NULL CHECK (statut IN ('detenu','visiteur')),
  progressions integer NOT NULL DEFAULT 0 CHECK (progressions BETWEEN 0 AND 10),
  en_cours boolean NOT NULL DEFAULT true,
  jour_abri date,
  jour_sommeil date,
  jour_progression date,
  bois_trouve integer NOT NULL DEFAULT 0 CHECK (bois_trouve BETWEEN 0 AND 8),
  detention_id text,
  peine_gelee_jours integer,
  debut_le date NOT NULL DEFAULT public.sovarka_jour_paris(),
  arrivee_le date,
  cree_le timestamptz NOT NULL DEFAULT now(),
  actualise_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_goulag_traversees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_traversees FROM PUBLIC,anon,authenticated,service_role;

-- Porte de départ volontairement FERMÉE tant que les habilitations,
-- la confiscation, le gel de peine et le retour en ville ne sont pas raccordés.
-- Aucune entrée de traversée ni débit PA n'est possible via cette RPC.
CREATE OR REPLACE FUNCTION public.goulag_toundra_demarrer(p_destination text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $goulag_demarrer$
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_destination IS NULL OR p_destination NOT IN ('starovka','krasnov') THEN
    RETURN jsonb_build_object('ok',false,'raison','destination_invalide');
  END IF;
  RETURN jsonb_build_object('ok',false,'raison','goulag_non_active');
END;
$goulag_demarrer$;
REVOKE ALL ON FUNCTION public.goulag_toundra_demarrer(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_demarrer(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.goulag_toundra_lire()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_nom text;
  v_t public.sovarka_goulag_traversees%ROWTYPE;
  v_pa integer;
  v_total integer;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','sans_personnage'); END IF;
  SELECT * INTO v_t FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_traversee'); END IF;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() AND country='soviet';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
  v_total := CASE v_t.destination WHEN 'starovka' THEN 7 ELSE 10 END;
  RETURN jsonb_build_object('ok',true,'en_cours',true,'destination',v_t.destination,
    'statut',v_t.statut,'progressions',v_t.progressions,'total',v_total,'pa',v_pa,
    'bois_trouve',v_t.bois_trouve,
    'abri_aujourdhui',v_t.jour_abri=public.sovarka_jour_paris(),
    'dormi_aujourdhui',v_t.jour_sommeil=public.sovarka_jour_paris(),
    'progresse_aujourdhui',v_t.jour_progression=public.sovarka_jour_paris());
END;
$$;

CREATE OR REPLACE FUNCTION public.goulag_toundra_agir(p_action text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE
  v_nom text;
  v_pa integer;
  v_pays text;
  v_t public.sovarka_goulag_traversees%ROWTYPE;
  v_jour date := public.sovarka_jour_paris();
  v_total integer;
  v_gain_bois integer := 0;
  v_arrive boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','sans_personnage'); END IF;
  -- Saisir d'abord le verrou personnage : toutes les actions PA concurrentes suivent ce protocole.
  SELECT pa,country INTO v_pa,v_pays
    FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR v_pays IS DISTINCT FROM 'soviet'
    THEN RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
  SELECT * INTO v_t FROM public.sovarka_goulag_traversees
    WHERE nom=v_nom AND en_cours FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_traversee'); END IF;
  IF v_pa IS NULL OR v_pa < 1 THEN RETURN jsonb_build_object('ok',false,'raison','pa_invalides'); END IF;
  v_total := CASE v_t.destination WHEN 'starovka' THEN 7 ELSE 10 END;
  IF p_action = 'abri' THEN
    IF v_t.jour_abri=v_jour OR v_t.jour_sommeil=v_jour
      THEN RETURN jsonb_build_object('ok',false,'raison','abri_deja_fait'); END IF;
    IF v_pa <= 1 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
    v_pa := v_pa - 1;
    UPDATE public.sovarka_goulag_traversees
      SET jour_abri=v_jour,actualise_le=now() WHERE nom=v_nom;
  ELSIF p_action = 'dormir' THEN
    IF v_t.jour_sommeil=v_jour
      THEN RETURN jsonb_build_object('ok',false,'raison','sommeil_deja_fait'); END IF;
    -- Le malus des champignons n'est pas encore défini ; le déclencheur futur
    -- devra être ajouté avant toute ouverture de la traversée en production.
    v_pa := v_pa + CASE WHEN v_t.jour_abri=v_jour THEN 6 ELSE 3 END;
    UPDATE public.sovarka_goulag_traversees
      SET jour_sommeil=v_jour,actualise_le=now() WHERE nom=v_nom;
  ELSIF p_action = 'progresser' THEN
    IF v_t.jour_progression=v_jour
      THEN RETURN jsonb_build_object('ok',false,'raison','progression_deja_faite'); END IF;
    IF v_pa <= 5 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
    v_pa := v_pa-5;
    IF v_t.progressions+1=v_total-1 THEN v_gain_bois:=5; END IF;
    IF v_t.progressions+1=v_total THEN v_gain_bois:=3; END IF;
    v_arrive:=v_t.progressions+1=v_total;
    UPDATE public.sovarka_goulag_traversees
      SET jour_progression=v_jour,progressions=progressions+1,
          bois_trouve=bois_trouve+v_gain_bois,
          en_cours=NOT v_arrive,
          arrivee_le=CASE WHEN v_arrive THEN v_jour ELSE NULL END,
          actualise_le=now()
      WHERE nom=v_nom;
    IF v_arrive THEN v_pa:=1; END IF;
  ELSE
    RETURN jsonb_build_object('ok',false,'raison','ordre_inconnu');
  END IF;
  -- Pas de déplacement au terme du trajet tant que le repos forcé sécurisé
  -- et les dispositifs judiciaires ne sont pas en place : bloquer la dernière
  -- étape plutôt que laisser sortir un joueur sans contrôle.
  IF v_arrive THEN
    RAISE EXCEPTION 'goulag_arrivee_non_raccordee';
  END IF;
  UPDATE public.personnages_donnees SET pa=v_pa WHERE name=v_nom AND user_id=auth.uid();
  RETURN jsonb_build_object('ok',true,'en_cours',true,'progressions',
    CASE WHEN p_action='progresser' THEN v_t.progressions+1 ELSE v_t.progressions END,
    'pa',v_pa,'bois_gagne',v_gain_bois);
END;
$$;
REVOKE ALL ON FUNCTION public.goulag_toundra_lire() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.goulag_toundra_agir(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_lire() TO authenticated;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_agir(text) TO authenticated;

-- SOURCE 20261116163500_goulag_depots_internes.sql
-- Goulag Sovarka : dépôt de détention, hors accès navigateur.
-- Le module ne déclenche aucune incarcération. Appel interne uniquement depuis
-- une condamnation judiciaire validée ou une sortie régulière.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_depots (
  detention_id text PRIMARY KEY REFERENCES public.detentions(id),
  nom text NOT NULL REFERENCES public.personnages_donnees(name),
  objets jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(objets)='array'),
  etat text NOT NULL DEFAULT 'confisque' CHECK (etat IN ('confisque','restitue','perdu')),
  cree_le timestamptz NOT NULL DEFAULT now(),
  cloture_le timestamptz
);
CREATE INDEX IF NOT EXISTS sovarka_goulag_depots_nom_idx ON public.sovarka_goulag_depots(nom);
ALTER TABLE public.sovarka_goulag_depots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_depots FROM PUBLIC,anon,authenticated,service_role;
-- Les clés vierges et doubles sont les objets avec type canonique du catalogue
-- des serrures. Un bloc serrure_cle ne constitue PAS une clé.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_est_cle_interne(p_objet jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO 'public','pg_temp' AS $$
  SELECT coalesce(p_objet->>'type','') IN ('cle_serrure','cle_vierge')
$$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_est_cle_interne(jsonb)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_confisquer_interne(p_nom text,p_detention_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_d record; v_inv jsonb; v_conserve jsonb; v_depot jsonb; v_etat text;
BEGIN
  IF p_nom IS NULL OR p_detention_id IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','identifiants_absents'); END IF;
  -- Verrou personnage en premier, même ordre que les RPC d'inventaire.
  SELECT d.country,d.current_city,d.inventory INTO v_d
    FROM public.personnages_donnees d WHERE d.name=p_nom FOR UPDATE;
  IF NOT FOUND OR v_d.country IS DISTINCT FROM 'soviet'
      OR v_d.current_city IS DISTINCT FROM 'qhs' THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.detentions d WHERE d.id=p_detention_id
      AND d.nom=p_nom AND d.country='soviet'
      AND d.mode_fin IS NULL AND d.jour_fin_effective IS NULL AND d.qhs) THEN
    RETURN jsonb_build_object('ok',false,'raison','detention_non_validee'); END IF;
  SELECT etat INTO v_etat FROM public.sovarka_goulag_depots WHERE detention_id=p_detention_id FOR UPDATE;
  IF FOUND THEN RETURN jsonb_build_object('ok',v_etat='confisque','raison',
     CASE WHEN v_etat='confisque' THEN 'deja_confisque' ELSE 'depot_clos' END); END IF;
  IF v_d.inventory IS NOT NULL AND jsonb_typeof(v_d.inventory) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'goulag_inventaire_invalide'; END IF;
  v_inv := coalesce(v_d.inventory,'[]'::jsonb);
  SELECT coalesce(jsonb_agg(x.objet ORDER BY x.ord)
        FILTER (WHERE public.sovarka_goulag_est_cle_interne(x.objet)),'[]'::jsonb),
         coalesce(jsonb_agg(x.objet ORDER BY x.ord)
        FILTER (WHERE NOT public.sovarka_goulag_est_cle_interne(x.objet)),'[]'::jsonb)
    INTO v_conserve,v_depot
    FROM jsonb_array_elements(v_inv) WITH ORDINALITY AS x(objet,ord);
  INSERT INTO public.sovarka_goulag_depots(detention_id,nom,objets)
    VALUES(p_detention_id,p_nom,v_depot);
  UPDATE public.personnages_donnees SET inventory=v_conserve,updated_at=now()
    WHERE name=p_nom;
  IF (SELECT inventory FROM public.personnages_donnees WHERE name=p_nom) IS DISTINCT FROM v_conserve THEN
    RAISE EXCEPTION 'goulag_confiscation_refusee'; END IF;
  RETURN jsonb_build_object('ok',true,'detention_id',p_detention_id,
    'confisques',jsonb_array_length(v_depot),'cles_conservees',jsonb_array_length(v_conserve));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_confisquer_interne(text,text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_depot_clore_interne(
  p_nom text,p_detention_id text,p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_etat text; v_objets jsonb; v_inv jsonb; v_tous jsonb;
BEGIN
  IF p_mode NOT IN ('liberation','evasion') OR p_mode IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','mode_invalide'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_absent'); END IF;
  SELECT etat,objets INTO v_etat,v_objets FROM public.sovarka_goulag_depots
    WHERE detention_id=p_detention_id AND nom=p_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','depot_absent'); END IF;
  IF v_etat<>'confisque' THEN
    RETURN jsonb_build_object('ok',v_etat=CASE p_mode WHEN 'liberation' THEN 'restitue' ELSE 'perdu' END,
      'raison','depot_deja_clos','etat',v_etat); END IF;
  IF p_mode='liberation' THEN
    SELECT coalesce(inventory,'[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name=p_nom;
    IF jsonb_typeof(v_inv)<>'array' THEN RAISE EXCEPTION 'goulag_inventaire_invalide'; END IF;
    -- Les identifiants uniques restent identiques. Aucune recompilation d'objets.
    v_tous:=v_inv||v_objets;
    UPDATE public.personnages_donnees SET inventory=v_tous,updated_at=now() WHERE name=p_nom;
    IF (SELECT inventory FROM public.personnages_donnees WHERE name=p_nom) IS DISTINCT FROM v_tous THEN
      RAISE EXCEPTION 'goulag_restitution_refusee'; END IF;
  END IF;
  UPDATE public.sovarka_goulag_depots SET
    etat=CASE p_mode WHEN 'liberation' THEN 'restitue' ELSE 'perdu' END,
    cloture_le=now() WHERE detention_id=p_detention_id;
  RETURN jsonb_build_object('ok',true,'detention_id',p_detention_id,
    'etat',CASE p_mode WHEN 'liberation' THEN 'restitue' ELSE 'perdu' END,
    'objets',jsonb_array_length(v_objets));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_depot_clore_interne(text,text,text)
  FROM PUBLIC,anon,authenticated,service_role;

-- SOURCE 20261116164000_goulag_juge_sentence.sql
-- Goulag Sovarka : un juge prononce une peine QHS dans une affaire valide.
-- AUCUN pouvoir de condamnation n'est accordé au ministre de la Justice.
-- La peine est celle que justice_rendre_sentence a validée dans son barème.
-- Cette migration dépend du dépôt interne de Sovarka.
DO $goulag_juge$
DECLARE
  def text;
  ancre_auth text := E'  v_a := v_brut::jsonb;';
  garde_auth text := E'  v_a := v_brut::jsonb;\n'
    || E'  -- goulag_sovarka_jugement_auth_20261116 : aucune condamnation inopinée tant que le circuit n est pas actif.\n'
    || E'  IF v_pays = ''soviet'' AND p_genre = ''qhs'' THEN\n'
    || E'    IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration c WHERE c.singleton AND c.active)\n'
    || E'       OR current_setting(''rp.goulag_jugement_interne'',true) IS DISTINCT FROM ''valide'' THEN\n'
    || E'      RETURN jsonb_build_object(''ok'',false,''raison'',''goulag_non_active''); END IF;\n'
    || E'  END IF;';
  ancre_suite text := E'  UPDATE public.plaintes_en_cours';
  suite text := E'  -- goulag_sovarka_detention_existante_20261116 : le transfert suit une condamnation réelle.\n'
    || E'  IF v_pays=''soviet'' AND p_genre=''qhs'' AND v_det.id IS NOT NULL THEN\n'
    || E'    v_exec:=public.justice_prolonger_peine(v_a->>''cible'',v_motifs,true);\n'
    || E'    IF coalesce((v_exec->>''ok'')::boolean,false) IS NOT TRUE THEN\n'
    || E'      RAISE EXCEPTION ''goulag_peine_non_prolongee''; END IF;\n'
    || E'    SELECT * INTO v_det FROM public.detention_active(v_a->>''cible'');\n'
    || E'    IF v_det.id IS NULL OR NOT v_det.qhs THEN RAISE EXCEPTION ''goulag_transfert_absent''; END IF;\n'
    || E'    IF coalesce((public.sovarka_goulag_confisquer_interne(v_a->>''cible'',v_det.id)->>''ok'')::boolean,false) IS NOT TRUE THEN\n'
    || E'      RAISE EXCEPTION ''goulag_confiscation_impossible''; END IF;\n'
    || E'    UPDATE public.jugements SET executee=true WHERE id=v_jug;\n'
    || E'    v_executee:=true; v_exec:=v_exec||jsonb_build_object(''detention_id'',v_det.id);\n'
    || E'  END IF;\n'
    || E'  UPDATE public.plaintes_en_cours';
  ancien text := E'        UPDATE public.jugements SET executee = true WHERE id = v_jug;\n        v_executee := true;';
  nouveau text := E'        -- goulag_sovarka_juge_seul_20261116 : même jugement, aucun bouton ministériel.\n'
    || E'        IF v_pays = ''soviet'' AND p_genre = ''qhs'' THEN\n'
    || E'          PERFORM public.detention_qhs_poser_interne(v_a ->> ''cible'',\n'
    || E'            v_exec ->> ''detention_id'', ''Condamnation au goulag de Sovarka'');\n'
    || E'          IF NOT coalesce((public.sovarka_goulag_confisquer_interne(\n'
    || E'               v_a ->> ''cible'', v_exec ->> ''detention_id'') ->> ''ok'')::boolean, false)\n'
    || E'          THEN RAISE EXCEPTION ''goulag_confiscation_impossible''; END IF;\n'
    || E'        END IF;\n'
    || E'        UPDATE public.jugements SET executee = true WHERE id = v_jug;\n'
    || E'        v_executee := true;';
BEGIN
  IF to_regprocedure('public.sovarka_goulag_confisquer_interne(text,text)') IS NULL THEN
    RAISE EXCEPTION 'depot_goulag_non_installe';
  END IF;
  def := pg_get_functiondef('public.justice_rendre_sentence(text,text,text,integer,integer)'::regprocedure);
  IF strpos(def,'goulag_sovarka_juge_seul_20261116') > 0 THEN RETURN; END IF;
  IF (length(def)-length(replace(def,ancien,''))) <> length(ancien) THEN
    RAISE EXCEPTION 'justice_rendre_sentence_signature_non_examinee';
  END IF;
  IF strpos(def,ancre_auth)=0 OR strpos(def,ancre_suite)=0 THEN
    RAISE EXCEPTION 'justice_rendre_sentence_ancre_absente';END IF;
  EXECUTE replace(replace(replace(def,ancien,nouveau),ancre_auth,garde_auth),ancre_suite,suite);
  IF strpos(pg_get_functiondef('public.justice_rendre_sentence(text,text,text,integer,integer)'::regprocedure),
            'goulag_sovarka_juge_seul_20261116') = 0 THEN
    RAISE EXCEPTION 'goulag_juge_raccordement_non_applique';
  END IF;
END $goulag_juge$;

-- SOURCE 20261116164500_goulag_autorisations_ministre.sql
-- Autorisations nominatives de visite au goulag. Le ministre décide de
-- l'autorisation de VISITE, jamais de la condamnation.
-- Décision 6924193788 : permanente, réutilisable et révocable.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_autorisations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nom text NOT NULL REFERENCES public.personnages_donnees(name),
  etat text NOT NULL DEFAULT 'demandee' CHECK (etat IN ('demandee','accordee','refusee','revoquee')),
  demandee_le timestamptz NOT NULL DEFAULT now(),
  decidee_le timestamptz,
  ministre text,
  revoquee_le timestamptz,
  commentaire text
);
CREATE UNIQUE INDEX IF NOT EXISTS sovarka_goulag_autorisation_demande_active
  ON public.sovarka_goulag_autorisations(nom)
  WHERE etat IN ('demandee','accordee');
ALTER TABLE public.sovarka_goulag_autorisations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_autorisations FROM PUBLIC,anon,authenticated,service_role;

-- Ne pas se fier au pays/au poste dans un cache client : acteur_poste_courant
-- et la fonction de titulature nationale sont côté serveur.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_role_interne(p_nom text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_poste text; v_pays text;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=p_nom AND country='soviet')
    THEN RETURN NULL; END IF;
  IF public.sovarka_est_titulaire_interne(p_nom,'min_just') THEN RETURN 'min_just'; END IF;
  IF public.sovarka_est_titulaire_interne(p_nom,'pm') THEN RETURN 'pm'; END IF;
  SELECT a.poste_id,a.pays INTO v_poste,v_pays FROM public.acteur_poste_courant() a
    WHERE a.nom=p_nom AND a.poste_id='juge' AND a.pays='soviet' LIMIT 1;
  IF v_poste='juge' AND v_pays='soviet' THEN RETURN 'juge'; END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_role_interne(text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_visite_demander()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_p record; v_id uuid;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration WHERE singleton AND active) THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT country,current_city,current_building INTO v_p FROM public.personnages_donnees
    WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR v_p.country<>'soviet' OR v_p.current_city NOT IN ('capitale','ville_a','ville_b')
    THEN RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
  IF coalesce(v_p.current_building,'') NOT LIKE 'centre-multinodal-%' THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_terminal'); END IF;
  IF EXISTS(SELECT 1 FROM public.detention_active(v_nom)) THEN
    RETURN jsonb_build_object('ok',false,'raison','detenu_interdit'); END IF;
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_autorisations
        WHERE nom=v_nom AND etat IN ('demandee','accordee')) THEN
    RETURN jsonb_build_object('ok',false,'raison','demande_deja_existante'); END IF;
  INSERT INTO public.sovarka_goulag_autorisations(nom) VALUES(v_nom) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok',true,'demande_id',v_id,'etat','demandee');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_visite_demander() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_visite_demander() TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_visite_decider(p_id uuid,p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); a public.sovarka_goulag_autorisations%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR SHARE;
  PERFORM 1 FROM public.postes_attribues WHERE country='soviet' AND poste_id='min_just' AND titulaire=v_nom FOR SHARE;
  IF NOT public.sovarka_est_titulaire_interne(v_nom,'min_just')
     OR NOT EXISTS(SELECT 1 FROM public.personnages_donnees
       WHERE name=v_nom AND user_id=auth.uid() AND country='soviet') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_ministre_justice_sovarka'); END IF;
  IF p_decision NOT IN ('accorder','refuser','revoquer') OR p_decision IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','decision_invalide'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration WHERE singleton AND active) THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT * INTO a FROM public.sovarka_goulag_autorisations WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','demande_absente'); END IF;
  IF p_decision='revoquer' THEN
    IF a.etat='revoquee' THEN RETURN jsonb_build_object('ok',true,'demande_id',p_id,'etat','revoquee','deja_revoquee',true); END IF;
    IF a.etat<>'accordee' THEN RETURN jsonb_build_object('ok',false,'raison','autorisation_non_accordee'); END IF;
    UPDATE public.sovarka_goulag_autorisations SET etat='revoquee',revoquee_le=now(),ministre=v_nom WHERE id=p_id;
    RETURN jsonb_build_object('ok',true,'demande_id',p_id,'etat','revoquee');
  END IF;
  IF a.etat<>'demandee' THEN
    RETURN jsonb_build_object('ok',false,'raison','demande_deja_traitee'); END IF;
  UPDATE public.sovarka_goulag_autorisations
    SET etat=CASE p_decision WHEN 'accorder' THEN 'accordee' ELSE 'refusee' END,
        ministre=v_nom, decidee_le=now() WHERE id=p_id;
  RETURN jsonb_build_object('ok',true,'demande_id',p_id,
     'etat',CASE p_decision WHEN 'accorder' THEN 'accordee' ELSE 'refusee' END);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_visite_decider(uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_visite_decider(uuid,text) TO authenticated;

-- La lecture rend exclusivement ses propres demandes ou les demandes du
-- ministre. Pas de données nominatives exposées à un autre joueur.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_visite_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_ministre boolean;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_ministre := public.sovarka_est_titulaire_interne(v_nom,'min_just')
   AND EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_nom AND country='soviet' AND user_id=auth.uid());
  RETURN jsonb_build_object('ok',true,'ministre',v_ministre,
    'demandes',coalesce((
      SELECT jsonb_agg(jsonb_build_object('id',a.id,'nom',a.nom,'etat',a.etat,
        'demandee_le',a.demandee_le,'decidee_le',a.decidee_le) ORDER BY a.demandee_le DESC)
      FROM public.sovarka_goulag_autorisations a
      WHERE a.nom=v_nom OR v_ministre
    ),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_visite_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_visite_lire() TO authenticated;

-- SOURCE 20261116165000_goulag_refuge_recuperation.sql
-- Goulag : récupération après la toundra, préparée sans modifier les
-- interactions des habitants. Règles : 1 PA à l'arrivée, trois jours de repos,
-- deux nuits (5 bois puis 3 bois), aucun troisième paiement.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_refuges (
  nom text PRIMARY KEY REFERENCES public.personnages_donnees(name),
  destination text NOT NULL CHECK(destination IN('starovka','krasnov')),
  statut text NOT NULL CHECK(statut IN('detenu','visiteur')),
  arrivee_le date NOT NULL,
  nuits integer NOT NULL DEFAULT 0 CHECK(nuits BETWEEN 0 AND 2),
  derniere_nuit date,
  bois_paye integer NOT NULL DEFAULT 0 CHECK(bois_paye IN(0,5,8)),
  paiements jsonb NOT NULL DEFAULT '[]'::jsonb CHECK(jsonb_typeof(paiements)='array'),
  termine boolean NOT NULL DEFAULT false,
  actualise_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_goulag_refuges ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_refuges FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_creer_interne(
  p_nom text,p_destination text,p_statut text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_ville text;
BEGIN
  v_ville:=CASE p_destination WHEN 'starovka' THEN 'ville_a' WHEN 'krasnov' THEN 'ville_b' END;
  IF v_ville IS NULL OR p_statut NOT IN ('detenu','visiteur') OR p_statut IS NULL
    THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees
      WHERE name=p_nom AND country='soviet' AND current_city=v_ville AND pa=1) THEN
    RETURN jsonb_build_object('ok',false,'raison','arrivee_non_confirmee'); END IF;
  INSERT INTO public.sovarka_goulag_refuges(nom,destination,statut,arrivee_le)
  VALUES(p_nom,p_destination,p_statut,public.sovarka_jour_paris())
  ON CONFLICT(nom) DO UPDATE SET destination=EXCLUDED.destination,
    statut=EXCLUDED.statut,arrivee_le=EXCLUDED.arrivee_le,nuits=0,
    derniere_nuit=NULL,bois_paye=0,paiements='[]'::jsonb,termine=false,actualise_le=now()
    WHERE sovarka_goulag_refuges.termine;
  IF NOT FOUND THEN RAISE EXCEPTION 'goulag_refuge_deja_actif'; END IF;
  RETURN jsonb_build_object('ok',true,'arrivee',p_destination,'repos_jours',3,'pa',1);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_creer_interne(text,text,text)
  FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_cible_interne(p_nuits integer,p_arrivee date,p_derniere date,p_nuit boolean)
RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public','pg_temp' AS $$
 SELECT least(2,greatest(p_nuits,least(2,greatest(0,public.sovarka_jour_paris()-p_arrivee)),
  CASE WHEN p_nuit AND p_derniere IS DISTINCT FROM public.sovarka_jour_paris() THEN p_nuits+1 ELSE p_nuits END))
$$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_cible_interne(integer,date,date,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_r public.sovarka_goulag_refuges%ROWTYPE; v_reglement jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT r.* INTO v_r FROM public.sovarka_goulag_refuges r
    JOIN public.personnages_donnees p ON p.name=r.nom AND p.user_id=auth.uid()
    WHERE r.nom=v_nom;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_refuge'); END IF;
  RETURN jsonb_build_object('ok',true,'destination',v_r.destination,'statut',v_r.statut,
    'nuits',v_r.nuits,'bois_paye',v_r.bois_paye,'arrivee_le',v_r.arrivee_le,
    'jour',public.sovarka_jour_paris(),'repos_jusqu_au',v_r.arrivee_le+3,
    'termine',v_r.termine,'bois_prochain',CASE WHEN v_r.termine OR v_r.nuits>=2 THEN 0 ELSE
    (CASE WHEN v_r.nuits=0 THEN 5 ELSE 0 END)+
    (CASE WHEN public.sovarka_goulag_refuge_cible_interne(v_r.nuits,v_r.arrivee_le,v_r.derniere_nuit,true)=2 THEN 3 ELSE 0 END) END);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_lire() TO authenticated;

-- Rattrapage des deux nuits écoulées : aucune connexion quotidienne n'est requise.
-- Les dates restent celles des nuits du repos initial, jamais une troisième nuit.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_regler_interne(p_nom text,p_nuit boolean,p_max_bois integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_r public.sovarka_goulag_refuges%ROWTYPE; v_p record;
 v_jour date:=public.sovarka_jour_paris(); v_cible integer; v_requis integer;
 v_bois integer; v_total integer:=0; v_ligne jsonb; v_inv jsonb; v_paiements jsonb:='[]';
BEGIN
 SELECT country,current_city,current_building,current_room,inventory INTO v_p
 FROM public.personnages_donnees WHERE name=p_nom FOR UPDATE;
 IF NOT FOUND OR v_p.country IS DISTINCT FROM 'soviet' THEN
  RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
 SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=p_nom FOR UPDATE;
 IF NOT FOUND OR v_r.termine THEN RETURN jsonb_build_object('ok',false,'raison','repos_non_actif'); END IF;
 IF (v_p.current_city,v_p.current_building,v_p.current_room) IS DISTINCT FROM
  (CASE v_r.destination WHEN 'starovka' THEN 'ville_a' ELSE 'ville_b' END,
   CASE v_r.destination WHEN 'starovka' THEN 'maison-starovka' ELSE 'maison-krasnov' END,'piece_maison') THEN
  RETURN jsonb_build_object('ok',false,'raison','habitant_absent'); END IF;
 IF v_jour<v_r.arrivee_le THEN RETURN jsonb_build_object('ok',false,'raison','jour_invalide'); END IF;
 v_cible:=public.sovarka_goulag_refuge_cible_interne(v_r.nuits,v_r.arrivee_le,v_r.derniere_nuit,p_nuit);
 IF v_cible<=v_r.nuits THEN
  RETURN jsonb_build_object('ok',NOT p_nuit,'raison','nuit_deja_prise','nuits',v_r.nuits,'bois_preleves',0); END IF;
 v_requis:=CASE WHEN v_r.nuits=0 THEN 5 ELSE 0 END+CASE WHEN v_cible=2 AND v_r.nuits<2 THEN 3 ELSE 0 END;
 IF p_max_bois IS NULL OR p_max_bois<v_requis THEN
  RETURN jsonb_build_object('ok',false,'raison','bois_a_confirmer','requis',v_requis); END IF;
 v_ligne:=public.sovarka_inventaire_ligne_interne(v_p.inventory,ARRAY['bois']);
 IF coalesce((v_ligne->>'qte')::integer,0)<v_requis THEN
  RETURN jsonb_build_object('ok',false,'raison','bois_insuffisant','requis',v_requis); END IF;
 WHILE v_r.nuits<v_cible LOOP
  v_bois:=CASE WHEN v_r.nuits=0 THEN 5 ELSE 3 END;
  SELECT inventory INTO v_inv FROM public.personnages_donnees WHERE name=p_nom;
  v_ligne:=public.sovarka_inventaire_ligne_interne(v_inv,ARRAY['bois']);
  PERFORM public.sovarka_inventaire_retirer_interne(p_nom,v_ligne,v_bois);
  v_paiements:=v_paiements||jsonb_build_array(jsonb_build_object('nuit',v_r.nuits+1,
    'bois',v_bois,'nuit_le',least(v_jour,v_r.arrivee_le+v_r.nuits),'regle_le',v_jour));
  v_r.nuits:=v_r.nuits+1;v_total:=v_total+v_bois;
 END LOOP;
 UPDATE public.sovarka_goulag_refuges SET nuits=v_r.nuits,
  derniere_nuit=least(v_jour,v_r.arrivee_le+v_r.nuits-1),bois_paye=bois_paye+v_total,
  paiements=paiements||v_paiements,actualise_le=now() WHERE nom=p_nom;
 RETURN jsonb_build_object('ok',true,'nuit',v_r.nuits,'nuits',v_r.nuits,
  'bois_preleves',v_total,'bois_total',v_r.bois_paye+v_total,'paiements',v_paiements)
  ||(SELECT jsonb_build_object('inventory',inventory,'revision',inventory_revision)
    FROM public.personnages_donnees WHERE name=p_nom);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_regler_interne(text,boolean,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_nuit(p_max_bois integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage();
BEGIN
 IF auth.uid() IS NULL OR v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid()) THEN
  RETURN jsonb_build_object('ok',false,'raison','sans_personnage'); END IF;
 RETURN public.sovarka_goulag_refuge_regler_interne(v_nom,true,p_max_bois);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_nuit(integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_nuit(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_terminer(p_max_bois integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_r public.sovarka_goulag_refuges%ROWTYPE; v_reglement jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  PERFORM 1 FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=v_nom FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_refuge'); END IF;
  IF v_r.termine THEN RETURN jsonb_build_object('ok',true,'deja_termine',true); END IF;
  -- Après une déconnexion prolongée, solder les nuits dues au lieu de bloquer le PJ.
  IF public.sovarka_jour_paris()>=v_r.arrivee_le+3 AND v_r.nuits<2 THEN
    v_reglement:=public.sovarka_goulag_refuge_regler_interne(v_nom,false,p_max_bois);
    IF coalesce((v_reglement->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_reglement; END IF;
    SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=v_nom;
  END IF;
  IF public.sovarka_jour_paris() < v_r.arrivee_le+3 OR v_r.nuits<2 THEN
    RETURN jsonb_build_object('ok',false,'raison','recuperation_incomplete',
       'repos_jusqu_au',v_r.arrivee_le+3,'nuits',v_r.nuits); END IF;
  UPDATE public.sovarka_goulag_refuges SET termine=true,actualise_le=now() WHERE nom=v_nom;
  RETURN coalesce(v_reglement,'{}'::jsonb)||jsonb_build_object('ok',true,'termine',true);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_terminer(integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_terminer(integer) TO authenticated;

-- SOURCE 20261116170000_goulag_transport_visiteurs.sql
-- Goulag Sovarka : décisions de Fred du 16/11, commentaires 6924193788 et 6924385758.
-- Aucun trajet n'est ouvert avant la configuration complète et active.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_configuration (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 active boolean NOT NULL DEFAULT false,
 autorisation_usage text NOT NULL DEFAULT 'permanente' CHECK(autorisation_usage='permanente'),
 retour_visiteur text NOT NULL DEFAULT 'choix_ville' CHECK(retour_visiteur='choix_ville'),
 champignons_malus integer NOT NULL DEFAULT 2 CHECK(champignons_malus=2),
 formule_arrestation text NOT NULL DEFAULT '30_par_entree' CHECK(formule_arrestation='30_par_entree'),
 camp_bucherons_noeud text,
 actualise_le timestamptz NOT NULL DEFAULT now()
);
-- La configuration n'est PAS suffisante pour rendre l'évasion sûre :
-- mise en service soumise à contrôle final et autorisation explicite.
-- Même un changement manuel de active=true est interdit par cette garde.
DO $goulag_activation_figee$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='sovarka_goulag_activation_figee') THEN
    ALTER TABLE public.sovarka_goulag_configuration
      ADD CONSTRAINT sovarka_goulag_activation_figee CHECK(active IS FALSE);
  END IF;
END $goulag_activation_figee$;

INSERT INTO public.sovarka_goulag_configuration(singleton,active) VALUES(true,false)
ON CONFLICT(singleton) DO NOTHING;
ALTER TABLE public.sovarka_goulag_configuration ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_configuration FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE IF NOT EXISTS public.sovarka_goulag_visites (
 nom text PRIMARY KEY REFERENCES public.personnages_donnees(name),
 origine text NOT NULL CHECK(origine IN ('capitale','ville_a','ville_b')),
 autorisation uuid REFERENCES public.sovarka_goulag_autorisations(id),
 present boolean NOT NULL DEFAULT true,
 entre_le timestamptz NOT NULL DEFAULT now(),
 sorti_le timestamptz
);
ALTER TABLE public.sovarka_goulag_visites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_visites FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_voyager(p_mode text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_p record;
        v_conf public.sovarka_goulag_configuration%ROWTYPE;
        v_role text; v_aut public.sovarka_goulag_autorisations%ROWTYPE;
        v_tarif record; v_paiement jsonb; v_dispo jsonb; v_fn text;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_mode NOT IN ('train','bus') OR p_mode IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','mode_invalide'); END IF;
  SELECT * INTO v_conf FROM public.sovarka_goulag_configuration WHERE singleton FOR SHARE;
  IF NOT FOUND OR NOT v_conf.active OR v_conf.retour_visiteur IS NULL
    OR v_conf.autorisation_usage IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT country,current_city,current_building,current_room INTO v_p
    FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR v_p.country IS DISTINCT FROM 'soviet'
    OR v_p.current_city NOT IN ('capitale','ville_a','ville_b') THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_sovarka'); END IF;
  IF coalesce(v_p.current_building,'') NOT LIKE 'centre-multinodal-%'
    OR NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles
          WHERE pays='soviet' AND ville=v_p.current_city AND batiment=v_p.current_building
          AND pieces ? v_p.current_room) THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_terminal'); END IF;
  IF EXISTS(SELECT 1 FROM public.detention_active(v_nom)) THEN
    RETURN jsonb_build_object('ok',false,'raison','detenu_transport_interdit'); END IF;
  IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=v_nom OR chef=v_nom)
    THEN RETURN jsonb_build_object('ok',false,'raison','groupe_a_verifier'); END IF;
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_visites WHERE nom=v_nom AND present)
    THEN RETURN jsonb_build_object('ok',false,'raison','visite_deja_ouverte'); END IF;
  v_role:=public.sovarka_goulag_role_interne(v_nom);
  IF v_role IS NULL THEN
    SELECT * INTO v_aut FROM public.sovarka_goulag_autorisations
      WHERE nom=v_nom AND etat='accordee' ORDER BY decidee_le DESC LIMIT 1 FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok',false,'raison','autorisation_goulag_requise'); END IF;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles
       WHERE pays='soviet' AND ville='qhs' AND batiment='qhs-prison' AND pieces ? 'entree_qhs')
    THEN RETURN jsonb_build_object('ok',false,'raison','goulag_entree_absente'); END IF;
  v_dispo:=public.navigation_disponibilite_interne(v_nom);
  IF NOT coalesce((v_dispo->>'ok')::boolean,false) THEN RETURN v_dispo; END IF;
  v_fn:=CASE p_mode WHEN 'train' THEN 'prendre_train' ELSE 'prendre_bus_taxi' END;
  -- Même tarif national que payer_ordre_interne, aucun montant nouveau.
  SELECT fn,pa,cost INTO v_tarif FROM public.ordres_couts_pays
    WHERE fn=v_fn AND pays='soviet';
  IF NOT FOUND THEN
    SELECT fn,pa,cost INTO v_tarif FROM public.ordres_couts WHERE fn=v_fn;
  END IF;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','tarif_absent'); END IF;
  v_paiement:=public.payer_ordre_interne(v_nom,v_fn,v_tarif.pa,v_tarif.cost,1);
  IF NOT coalesce((v_paiement->>'ok')::boolean,false) THEN RETURN v_paiement; END IF;
  UPDATE public.personnages_donnees SET current_city='qhs',current_building='qhs-prison',
    current_room='entree_qhs',current_street=NULL,updated_at=clock_timestamp()
    WHERE name=v_nom AND user_id=auth.uid();
  INSERT INTO public.sovarka_goulag_visites(nom,origine,autorisation,present,entre_le,sorti_le)
    VALUES(v_nom,v_p.current_city,v_aut.id,true,now(),NULL)
  ON CONFLICT(nom) DO UPDATE SET origine=EXCLUDED.origine,autorisation=EXCLUDED.autorisation,
    present=true,entre_le=now(),sorti_le=NULL;
  -- Autorisation permanente : ne jamais consommer le droit au voyage.
  RETURN jsonb_build_object('ok',true,'ville','qhs','building','qhs-prison',
    'room','entree_qhs','tarif',v_paiement,'statut','visiteur');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_voyager(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_voyager(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_visiteur_repartir(p_mode text,p_destination text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); v_p record; v_v public.sovarka_goulag_visites%ROWTYPE;
        v_c public.sovarka_goulag_configuration%ROWTYPE; v_dest text;
        v_bat text; v_piece text; v_paiement jsonb; v_t record; v_fn text;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_mode NOT IN ('train','bus') OR p_mode IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','mode_invalide'); END IF;
  SELECT * INTO v_p FROM public.personnages_donnees WHERE name=v_nom
    AND user_id=auth.uid() FOR UPDATE;
  SELECT * INTO v_v FROM public.sovarka_goulag_visites WHERE nom=v_nom FOR UPDATE;
  SELECT * INTO v_c FROM public.sovarka_goulag_configuration WHERE singleton FOR SHARE;
  IF coalesce(v_c.active,false) IS DISTINCT FROM true OR v_c.retour_visiteur IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  IF coalesce(v_v.present,false) IS DISTINCT FROM true OR v_p.country IS DISTINCT FROM 'soviet'
    OR (v_p.current_city,v_p.current_building,v_p.current_room)
       IS DISTINCT FROM ('qhs','qhs-prison','entree_qhs') THEN
    RETURN jsonb_build_object('ok',false,'raison','visiteur_non_present'); END IF;
  IF EXISTS(SELECT 1 FROM public.detention_active(v_nom)) OR EXISTS(
     SELECT 1 FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours) THEN
    RETURN jsonb_build_object('ok',false,'raison','retour_interdit'); END IF;
  v_dest:=p_destination; -- Libre choix explicite, jamais une ville déduite du client.
  IF v_dest NOT IN ('capitale','ville_a','ville_b') OR v_dest IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','destination_invalide'); END IF;
  SELECT batiment,pieces->>0 INTO v_bat,v_piece
    FROM public.navigation_lieux_regles WHERE pays='soviet' AND ville=v_dest
      AND batiment LIKE 'centre-multinodal-%' ORDER BY batiment LIMIT 1;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','arrivee_non_referencee'); END IF;
  v_fn:=CASE p_mode WHEN 'train' THEN 'prendre_train' ELSE 'prendre_bus_taxi' END;
  -- Même tarif national que payer_ordre_interne, aucun montant nouveau.
  SELECT fn,pa,cost INTO v_t FROM public.ordres_couts_pays
    WHERE fn=v_fn AND pays='soviet';
  IF NOT FOUND THEN
    SELECT fn,pa,cost INTO v_t FROM public.ordres_couts WHERE fn=v_fn;
  END IF;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','tarif_absent'); END IF;
  v_paiement:=public.payer_ordre_interne(v_nom,v_fn,v_t.pa,v_t.cost,1);
  IF NOT coalesce((v_paiement->>'ok')::boolean,false) THEN RETURN v_paiement; END IF;
  UPDATE public.personnages_donnees SET current_city=v_dest,current_building=v_bat,
    current_room=v_piece,current_street=NULL,updated_at=clock_timestamp()
    WHERE name=v_nom AND user_id=auth.uid();
  UPDATE public.sovarka_goulag_visites SET present=false,sorti_le=now() WHERE nom=v_nom;
  RETURN jsonb_build_object('ok',true,'ville',v_dest,'building',v_bat,'room',v_piece,'tarif',v_paiement);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_visiteur_repartir(text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_visiteur_repartir(text,text) TO authenticated;

-- SOURCE 20261116171000_goulag_traversee_transactionnelle.sql
-- Goulag Sovarka : départ, survie et arrivée, version préparée sous
-- verrou de configuration. Non activé avant les décisions manquantes.
-- Dépend des quatre migrations de dépôt, Justice, autorisations et refuge.
-- Ancrage du camp dans la géographie existante : une cour, sans mécanique locale.
DO $camp$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur WHERE country='soviet'
    AND city='ville_b' AND noeud='krasnov-rue-ecole-foret') THEN
    RAISE EXCEPTION 'krasnov_acces_foret_absent'; END IF;
  INSERT INTO public.rue_noeuds_serveur(country,city,noeud,voisins,directions)
  VALUES('soviet','ville_b','krasnov-camp-bucherons',ARRAY['krasnov-rue-ecole-foret'],
    '{"liens":{"arriere":"krasnov-rue-ecole-foret"},"parArrivee":{}}'::jsonb)
  ON CONFLICT(country,city,noeud) DO NOTHING;
  UPDATE public.rue_noeuds_serveur SET
    voisins=CASE WHEN 'krasnov-camp-bucherons'=ANY(voisins) THEN voisins
      ELSE array_append(voisins,'krasnov-camp-bucherons') END,
    directions=jsonb_set(coalesce(directions,'{}'::jsonb),'{liens}',
      coalesce(directions->'liens','{}'::jsonb)||'{"droite":"krasnov-camp-bucherons"}'::jsonb)
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-ecole-foret';
  UPDATE public.sovarka_goulag_configuration SET camp_bucherons_noeud='krasnov-camp-bucherons'
    WHERE singleton AND camp_bucherons_noeud IS NULL;
END $camp$;

ALTER TABLE public.sovarka_goulag_traversees
  ADD COLUMN IF NOT EXISTS champignons_choix text
    CHECK(champignons_choix IN ('manger','refuser')),
  ADD COLUMN IF NOT EXISTS champignons_penalite_en_attente boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS peine_gelee_secondes numeric,
  ADD COLUMN IF NOT EXISTS recherche_id text;

CREATE OR REPLACE FUNCTION public.goulag_toundra_demarrer(p_destination text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        c public.sovarka_goulag_configuration%ROWTYPE;
        v_det record; v_statut text; v_total integer; v_dep text; v_rest numeric;
        v_rech jsonb; v_rech_id text; v_fin numeric; v_debut numeric; v_duree numeric;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF p_destination NOT IN ('starovka','krasnov') OR p_destination IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','destination_invalide'); END IF;
  SELECT * INTO c FROM public.sovarka_goulag_configuration WHERE singleton FOR SHARE;
  IF NOT FOUND OR c.active IS DISTINCT FROM true
    OR c.champignons_malus IS NULL OR c.formule_arrestation IS NULL
    OR c.camp_bucherons_noeud IS NULL
    OR c.retour_visiteur IS NULL OR c.autorisation_usage IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  -- Prérequis géographique strict : ne jamais inventer un camp ni retourner à la gare.
  IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_a' AND noeud='starovka-rue-stade')
    OR NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
    WHERE country='soviet' AND city='ville_b' AND noeud=c.camp_bucherons_noeud)
    THEN RETURN jsonb_build_object('ok',false,'raison','arrivees_non_referencees'); END IF;
  SELECT * INTO p FROM public.personnages_donnees
    WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR (p.country,p.current_city,p.current_building,p.current_room)
    IS DISTINCT FROM ('soviet','qhs','qhs-prison','entree_qhs')
    THEN RETURN jsonb_build_object('ok',false,'raison','pas_entree_goulag'); END IF;
  v_total:=CASE p_destination WHEN 'starovka' THEN 7 ELSE 10 END;
  IF p.pa IS NULL OR p.pa<v_total THEN
    RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants_depart','minimum',v_total); END IF;
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours) THEN
    RETURN jsonb_build_object('ok',false,'raison','traversee_deja_commencee'); END IF;
  -- Une seconde marche ne doit jamais effacer une peine encore gelée.
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees WHERE nom=v_nom
    AND peine_gelee_secondes>0 AND peine_reprise_le IS NULL) THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_gelee_non_reprise'); END IF;
  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges WHERE nom=v_nom AND NOT termine) THEN
    RETURN jsonb_build_object('ok',false,'raison','refuge_encore_actif'); END IF;
  SELECT * INTO v_det FROM public.detention_active(v_nom);
  IF v_det.id IS NOT NULL THEN
    IF v_det.country <> 'soviet' OR NOT v_det.qhs THEN
      RETURN jsonb_build_object('ok',false,'raison','detention_hors_goulag'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.sovarka_goulag_depots
          WHERE detention_id=v_det.id AND nom=v_nom AND etat='confisque') THEN
      RETURN jsonb_build_object('ok',false,'raison','inventaire_non_confisque'); END IF;
    v_statut:='detenu';
    -- Peine restante à l'instant exact : pas de comparaison avec la durée de marche.
    -- Les peines historiques portent debutTs en millisecondes et jours en numérique.
    IF coalesce(p.est_emprisonne->>'debutTs','') !~ '^[0-9]+(\.[0-9]+)?$'
       OR coalesce(p.est_emprisonne->>'jours','') !~ '^[0-9]+(\.[0-9]+)?$' THEN
      RETURN jsonb_build_object('ok',false,'raison','peine_calendaire_invalide'); END IF;
    v_debut:=(p.est_emprisonne->>'debutTs')::numeric;
    v_duree:=(p.est_emprisonne->>'jours')::numeric;
    v_fin:=v_debut+v_duree*86400000;
    v_rest:=greatest(0,(v_fin-extract(epoch from clock_timestamp())*1000)/1000);
    IF v_rest<=0 THEN
      RETURN jsonb_build_object('ok',false,'raison','peine_deja_purgee'); END IF;
    -- Clore avec mode "evasion" (jamais "purgee") pour figer le reliquat.
    PERFORM public.detention_clore_interne(v_nom,'evasion');
    UPDATE public.detentions SET reliquat_jours=ceil(v_rest/86400.0)::integer
      WHERE id=v_det.id;
    UPDATE public.prisonniers_qhs SET statut='evade'
      WHERE data->>'nom'=v_nom AND data->>'pays'='soviet' AND statut='libere';
    IF coalesce((public.sovarka_goulag_depot_clore_interne(v_nom,v_det.id,'evasion')->>'ok')::boolean,false) IS NOT TRUE THEN
      RAISE EXCEPTION 'goulag_perte_inventaire_impossible'; END IF;
    v_rech_id:='goulag-evasion-'||v_det.id;
    v_rech:=public.recherche_inscrire(jsonb_build_object(
      'id',v_rech_id,'type','condamnation','country','soviet',
      'motifs',jsonb_build_array(jsonb_build_object(
        'type','Évasion du goulag','source','goulag','jours',0,
        'detention_id',v_det.id,'reste_secondes',v_rest,
        'date_evenement',to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
      'detention_precedente_id',v_det.id,'reliquat_jours',ceil(v_rest/86400.0)::integer));
    IF coalesce((v_rech->>'ok')::boolean,false) IS NOT TRUE THEN
      RAISE EXCEPTION 'goulag_recherche_impossible'; END IF;
  ELSE
    IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_visites
       WHERE nom=v_nom AND present) THEN
      RETURN jsonb_build_object('ok',false,'raison','visite_non_validee'); END IF;
    v_statut:='visiteur';
    v_rest:=NULL;v_rech_id:=NULL;
    UPDATE public.sovarka_goulag_visites SET present=false,sorti_le=now() WHERE nom=v_nom;
  END IF;
  INSERT INTO public.sovarka_goulag_traversees(nom,destination,statut,
     progressions,en_cours,detention_id,peine_gelee_jours,peine_gelee_secondes,recherche_id,
     jour_abri,jour_sommeil,jour_progression,bois_trouve,
     champignons_choix,champignons_penalite_en_attente,debut_le,arrivee_le)
  VALUES(v_nom,p_destination,v_statut,0,true,v_det.id,
     CASE WHEN v_rest IS NOT NULL THEN ceil(v_rest/86400.0)::integer END,
     v_rest,v_rech_id,NULL,NULL,NULL,0,NULL,false,public.sovarka_jour_paris(),NULL)
  ON CONFLICT(nom) DO UPDATE SET destination=EXCLUDED.destination,
     statut=EXCLUDED.statut,progressions=0,en_cours=true,
     detention_id=EXCLUDED.detention_id,peine_gelee_jours=EXCLUDED.peine_gelee_jours,
     peine_gelee_secondes=EXCLUDED.peine_gelee_secondes,recherche_id=EXCLUDED.recherche_id,
     jour_abri=NULL,jour_sommeil=NULL,jour_progression=NULL,bois_trouve=0,
     champignons_choix=NULL,champignons_penalite_en_attente=false,
     debut_le=EXCLUDED.debut_le,arrivee_le=NULL,
     peine_reprise_le=NULL,nouvelle_detention_id=NULL,actualise_le=now();
  -- La marche est un état serveur isolé, pas une présence dans l’entrée du camp.
  UPDATE public.personnages_donnees SET current_building=NULL,current_room=NULL,
    current_street=NULL,updated_at=clock_timestamp() WHERE name=v_nom AND user_id=auth.uid();
  RETURN jsonb_build_object('ok',true,'en_cours',true,'destination',p_destination,
    'statut',v_statut,'pa',p.pa,'progressions',0,'peine_gelee_secondes',v_rest);
END $$;
REVOKE ALL ON FUNCTION public.goulag_toundra_demarrer(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_demarrer(text) TO authenticated;

-- SOURCE 20261116171001_goulag_actions_transactionnelles.sql
-- Séparation technique du lot 171000 : canal de migration limité à environ 12 500 caractères.
-- Même verrou, aucune activation et aucune nouvelle règle.
CREATE OR REPLACE FUNCTION public.goulag_toundra_agir(p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        c public.sovarka_goulag_configuration%ROWTYPE;
        tr public.sovarka_goulag_traversees%ROWTYPE;
        v_jour date:=public.sovarka_jour_paris(); v_total integer;v_pa integer;
        v_gain integer:=0; v_dernier boolean:=false; v_bois jsonb;v_dest text;v_noeud text;
        v_ref jsonb; v_sommeil integer; v_penalite boolean;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT * INTO c FROM public.sovarka_goulag_configuration WHERE singleton FOR SHARE;
  IF NOT FOUND OR c.active IS DISTINCT FROM true OR c.champignons_malus IS NULL
    OR c.camp_bucherons_noeud IS NULL OR c.formule_arrestation IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR p.country<>'soviet' OR p.current_city<>'qhs' THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
  SELECT * INTO tr FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_traversee'); END IF;
  IF p.pa IS NULL OR p.pa<1 THEN RETURN jsonb_build_object('ok',false,'raison','pa_invalides'); END IF;
  v_pa:=p.pa;
  v_total:=CASE tr.destination WHEN 'starovka' THEN 7 ELSE 10 END;
  IF p_action='abri' THEN
    IF tr.jour_abri>=v_jour OR tr.jour_sommeil>=v_jour OR p.pa_repos_le>=v_jour THEN
      RETURN jsonb_build_object('ok',false,'raison','abri_deja_fait'); END IF;
    IF v_pa<=1 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
    v_pa:=v_pa-1;
    UPDATE public.sovarka_goulag_traversees SET jour_abri=v_jour,actualise_le=now() WHERE nom=v_nom;
  ELSIF p_action='dormir' THEN
    IF tr.jour_sommeil>=v_jour OR p.pa_repos_le>=v_jour THEN
      RETURN jsonb_build_object('ok',false,'raison','sommeil_deja_fait'); END IF;
    v_sommeil:=CASE WHEN tr.jour_abri>=v_jour THEN 6 ELSE 3 END;
    IF tr.champignons_penalite_en_attente THEN
      -- Décision de Fred : deux PA sur le gain du prochain sommeil, une fois.
      v_sommeil:=least(v_pa+v_sommeil,greatest(7,v_pa+v_sommeil-c.champignons_malus))-v_pa;
    END IF;
    v_pa:=v_pa+v_sommeil;
    UPDATE public.sovarka_goulag_traversees
      SET jour_sommeil=v_jour,champignons_penalite_en_attente=false,actualise_le=now()
      WHERE nom=v_nom;
  ELSIF p_action='progresser' THEN
    IF v_jour>=tr.debut_le+4 AND tr.champignons_choix IS NULL THEN
      RETURN jsonb_build_object('ok',false,'raison','champignons_a_decider'); END IF;
    IF tr.jour_progression>=v_jour THEN
      RETURN jsonb_build_object('ok',false,'raison','progression_deja_faite'); END IF;
    IF v_pa<=5 THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
    v_pa:=v_pa-5;
    v_dernier:=tr.progressions+1=v_total;
    v_gain:=CASE WHEN tr.progressions+1=v_total-1 THEN 5
                 WHEN v_dernier THEN 3 ELSE 0 END;
    IF v_gain>0 THEN
      v_bois:=public.inventaire_deposer_interne(v_nom,
        jsonb_build_object('name','Bois','stackKey','bois','stackable',true,'qty',v_gain,
          'desc','Ramassé dans la toundra de Sovarka.'),true);
      IF coalesce((v_bois->>'ok')::boolean,false) IS NOT TRUE OR (v_bois->>'qte')::integer<>v_gain THEN
        RAISE EXCEPTION 'goulag_bois_non_depose'; END IF;
    END IF;
    UPDATE public.sovarka_goulag_traversees SET progressions=progressions+1,
      jour_progression=v_jour,bois_trouve=bois_trouve+v_gain,
      en_cours=NOT v_dernier,arrivee_le=CASE WHEN v_dernier THEN v_jour ELSE arrivee_le END,
      actualise_le=now() WHERE nom=v_nom;
    IF v_dernier THEN
      v_dest:=CASE tr.destination WHEN 'starovka' THEN 'ville_a' ELSE 'ville_b' END;
      v_noeud:=CASE tr.destination WHEN 'starovka' THEN 'starovka-rue-stade'
                   ELSE c.camp_bucherons_noeud END;
      IF NOT EXISTS(SELECT 1 FROM public.rue_noeuds_serveur
          WHERE country='soviet' AND city=v_dest AND noeud=v_noeud) THEN
        RAISE EXCEPTION 'goulag_arrivee_non_referencee'; END IF;
      v_pa:=1;
      UPDATE public.personnages_donnees SET pa=v_pa,pa_repos_le=v_jour,current_city=v_dest,
        current_building=NULL,current_room=NULL,current_street=v_noeud,
        updated_at=clock_timestamp() WHERE name=v_nom;
      v_ref:=public.sovarka_goulag_refuge_creer_interne(v_nom,tr.destination,tr.statut);
      IF coalesce((v_ref->>'ok')::boolean,false) IS NOT TRUE THEN
        RAISE EXCEPTION 'goulag_refuge_non_cree'; END IF;
    END IF;
  ELSIF p_action='champignons_manger' OR p_action='champignons_refuser' THEN
    IF v_jour<tr.debut_le+4 OR tr.champignons_choix IS NOT NULL THEN
      RETURN jsonb_build_object('ok',false,'raison','champignons_indisponibles'); END IF;
    IF p_action='champignons_manger' THEN
      v_pa:=CASE WHEN v_pa>7 THEN 7 ELSE v_pa+1 END;
    END IF;
    UPDATE public.sovarka_goulag_traversees SET
      champignons_choix=CASE p_action WHEN 'champignons_manger' THEN 'manger' ELSE 'refuser' END,
      champignons_penalite_en_attente=(p_action='champignons_refuser' AND v_pa>7),
      actualise_le=now() WHERE nom=v_nom;
  ELSE
    RETURN jsonb_build_object('ok',false,'raison','ordre_inconnu');
  END IF;
  IF NOT v_dernier THEN
    UPDATE public.personnages_donnees SET pa=v_pa,
      pa_repos_le=CASE WHEN p_action='dormir' THEN v_jour ELSE pa_repos_le END
      WHERE name=v_nom AND user_id=auth.uid();
  END IF;
  RETURN jsonb_build_object('ok',true,'en_cours',NOT v_dernier,
    'termine',v_dernier,'arrivee',CASE WHEN v_dernier THEN v_dest END,
    'rue',CASE WHEN v_dernier THEN v_noeud END,
    'progressions',tr.progressions+CASE WHEN p_action='progresser' THEN 1 ELSE 0 END,
    'pa',v_pa,'bois_gagne',v_gain,
    'inventory',CASE WHEN v_gain>0 THEN v_bois->'inventory' ELSE NULL END,
    'revision',CASE WHEN v_gain>0 THEN v_bois->'revision' ELSE NULL END,
    'repos_jours',CASE WHEN v_dernier THEN 3 ELSE 0 END,
    'statut',tr.statut,'recherche',v_dernier AND tr.statut='detenu');
END $$;
REVOKE ALL ON FUNCTION public.goulag_toundra_agir(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_agir(text) TO authenticated;


CREATE OR REPLACE FUNCTION public.goulag_toundra_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage();tr public.sovarka_goulag_traversees%ROWTYPE;
        p record;v_total integer;v_jour date:=public.sovarka_jour_paris();
BEGIN
 IF auth.uid() IS NULL OR v_nom IS NULL THEN
   RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO tr FROM public.sovarka_goulag_traversees WHERE nom=v_nom AND en_cours;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pas_de_traversee');END IF;
 SELECT country,current_city,pa,pa_repos_le INTO p FROM public.personnages_donnees
    WHERE name=v_nom AND user_id=auth.uid();
 IF NOT FOUND OR (p.country,p.current_city) IS DISTINCT FROM ('soviet','qhs') THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_toundra'); END IF;
 v_total:=CASE WHEN tr.destination='starovka' THEN 7 ELSE 10 END;
 RETURN jsonb_build_object('ok',true,'en_cours',true,'destination',tr.destination,'statut',tr.statut,
   'progressions',tr.progressions,'total',v_total,'pa',p.pa,'bois_trouve',tr.bois_trouve,
   'abri_aujourdhui',coalesce(tr.jour_abri>=v_jour,false),
   'dormi_aujourdhui',coalesce(tr.jour_sommeil>=v_jour,false) OR coalesce(p.pa_repos_le>=v_jour,false),
   'progresse_aujourdhui',coalesce(tr.jour_progression>=v_jour,false),
   'champignons_a_decider',v_jour>=tr.debut_le+4 AND tr.champignons_choix IS NULL,
   'champignons_choix',tr.champignons_choix,
   'peine_gelee_secondes',tr.peine_gelee_secondes);
END $$;
REVOKE ALL ON FUNCTION public.goulag_toundra_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.goulag_toundra_lire() TO authenticated;

-- Un joueur en pleine traversée ne peut fuir via des actions de déplacement
-- génériques : garde transversale du moteur de navigation existant.
DO $goulag_navigation$
DECLARE olddef text;old text;newtext text;
BEGIN
  olddef:=pg_get_functiondef('public.navigation_disponibilite_interne(text)'::regprocedure);
  IF strpos(olddef,'goulag_navigation_garde_20261116')>0 THEN RETURN; END IF;
  old:=E' IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=p_nom AND expires_at>now()) THEN';
  newtext:=E' -- goulag_navigation_garde_20261116 : la toundra ne se quitte que par progression serveur.\n'
    ||E' IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees t WHERE t.nom=p_nom AND t.en_cours) THEN\n'
    ||E'   RETURN jsonb_build_object(''ok'',false,''raison'',''traversee_irreversible''); END IF;\n'
    ||E' IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=p_nom AND expires_at>now()) THEN';
  IF (length(olddef)-length(replace(olddef,old,'')))<>length(old) THEN
    RAISE EXCEPTION 'navigation_disponibilite_signature_inattendue'; END IF;
  EXECUTE replace(olddef,old,newtext);
END $goulag_navigation$;

-- SOURCE 20261116171500_goulag_repos_navigation.sql
-- Repos forcé : le fugitif doit rejoindre la maison de la ville d'arrivée.
-- Une fois la première nuit commencée, les déplacements génériques sont bloqués
-- jusqu'au terme des 3 jours et au règlement des deux nuits.
DO $repos_garde$
DECLARE s text; a text; b text;
BEGIN
 s:=pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
 IF strpos(s,'goulag_refuge_acces_20261116')=0 THEN
   a:=E' SELECT * INTO p FROM public.personnages_donnees WHERE name=p_nom;';
   b:=a||E'\n -- goulag_refuge_acces_20261116 : logement d accueil uniquement durant récupération.\n'
     ||E' IF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges r\n'
     ||E'   WHERE r.nom=p_nom AND NOT r.termine\n'
     ||E'     AND p_batiment IS DISTINCT FROM CASE r.destination\n'
     ||E'       WHEN ''starovka'' THEN ''maison-starovka'' ELSE ''maison-krasnov'' END) THEN\n'
     ||E'   RETURN jsonb_build_object(''ok'',false,''raison'',''repos_chez_habitant_requis''); END IF;';
   IF (length(s)-length(replace(s,a,'')))<>length(a) THEN
     RAISE EXCEPTION 'navigation_interieure_refuge_ancre_absente';END IF;
   EXECUTE replace(s,a,b);
 END IF;
 s:=pg_get_functiondef('public.navigation_disponibilite_interne(text)'::regprocedure);
 IF strpos(s,'goulag_refuge_repos_20261116')=0 THEN
   a:=E' IF EXISTS(SELECT 1 FROM public.police_interceptions WHERE personnage=p_nom AND expires_at>now()) THEN';
   b:=E' -- goulag_refuge_repos_20261116 : dès la première nuit, repos complet.\n'
     ||E' IF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges r WHERE r.nom=p_nom\n'
     ||E'   AND NOT r.termine AND r.nuits>=1) THEN\n'
     ||E'  RETURN jsonb_build_object(''ok'',false,''raison'',''repos_force_goulag''); END IF;\n'||a;
   IF (length(s)-length(replace(s,a,'')))<>length(a) THEN
     RAISE EXCEPTION 'navigation_disponibilite_refuge_ancre_absente';END IF;
   EXECUTE replace(s,a,b);
 END IF;
END $repos_garde$;

-- SOURCE 20261116172000_goulag_reprise_peine.sql
-- Reprise de l'exécution de la peine gelée, uniquement à l'incarcération
-- effective d'un évadé, sans peine supplémentaire automatique.
ALTER TABLE public.sovarka_goulag_traversees
 ADD COLUMN IF NOT EXISTS peine_reprise_le timestamptz,
 ADD COLUMN IF NOT EXISTS nouvelle_detention_id text;

DO $reprise$
DECLARE code text; ancre text; ajout text;
BEGIN
 code:=pg_get_functiondef('public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb)'::regprocedure);
 IF strpos(code,'goulag_reprise_peine_gelee_20261116')>0 THEN RETURN; END IF;
 ancre:=E'  RETURN jsonb_build_object(''ok'',true,''detention_id'',v_id,''jour_debut'',v_jour_cible,''jour_fin'',v_jour_cible+p_jours);';
 ajout:=E'  -- goulag_reprise_peine_gelee_20261116 : la condamnation précédente n a pas diminué pendant la fuite.\n'
  ||E'  DECLARE v_goulag_restant numeric; v_goulag_recherche text; v_goulag_supp integer;\n'
  ||E'  BEGIN\n'
  ||E'   IF p_country = ''soviet'' THEN\n'
  ||E'    SELECT t.peine_gelee_secondes,t.recherche_id INTO v_goulag_restant,v_goulag_recherche\n'
  ||E'      FROM public.sovarka_goulag_traversees t\n'
  ||E'      WHERE t.nom=p_nom AND NOT t.en_cours AND t.statut=''detenu''\n'
  ||E'        AND t.peine_gelee_secondes>0 AND t.peine_reprise_le IS NULL FOR UPDATE;\n'
  ||E'    IF FOUND THEN\n'
  ||E'      v_goulag_supp:=ceil(v_goulag_restant::numeric/86400)::integer;\n'
  ||E'      UPDATE public.detentions SET jour_fin=jour_fin+v_goulag_supp,\n'
  ||E'        detention_precedente_id=coalesce(detention_precedente_id,\n'
  ||E'          (SELECT detention_id FROM public.sovarka_goulag_traversees WHERE nom=p_nom)),\n'
  ||E'        reliquat_jours=v_goulag_supp WHERE id=v_id;\n'
  ||E'      UPDATE public.personnages_donnees SET est_emprisonne=\n'
  ||E'        jsonb_set(jsonb_set(est_emprisonne,''{jours}'',\n'
  ||E'          to_jsonb(p_jours::numeric+v_goulag_restant::numeric/86400)),\n'
  ||E'          ''{jourFin}'',to_jsonb(v_jour_cible+p_jours+v_goulag_supp)) WHERE name=p_nom;\n'
  ||E'      UPDATE public.sovarka_goulag_traversees SET peine_reprise_le=now(),\n'
  ||E'        nouvelle_detention_id=v_id,actualise_le=now() WHERE nom=p_nom;\n'
  ||E'      UPDATE public.sovarka_goulag_refuges SET termine=true,actualise_le=now() WHERE nom=p_nom;\n'
  ||E'      IF v_goulag_recherche IS NOT NULL THEN\n'
  ||E'        PERFORM public.recherche_retirer_par_id(p_nom,v_goulag_recherche);\n'
  ||E'      END IF;\n'
  ||E'    END IF;\n'
  ||E'   END IF;\n'
  ||E'  END;\n'
  ||E'  RETURN jsonb_build_object(''ok'',true,''detention_id'',v_id,''jour_debut'',v_jour_cible,\n'
  ||E'     ''jour_fin'',(SELECT jour_fin FROM public.detentions WHERE id=v_id));';
 IF (length(code)-length(replace(code,ancre,'')))<>length(ancre) THEN
  RAISE EXCEPTION 'detention_ouvrir_interne_ancre_inattendue'; END IF;
 EXECUTE replace(code,ancre,ajout);
END $reprise$;

-- SOURCE 20261116172500_goulag_jugement_atomique.sql
-- Entrée judiciaire exclusivement réservée au juge de l'affaire.
-- Débit 2 PA et sentence dans UNE transaction ; refus = aucun débit.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_juger(
  p_affaire_id text,p_infraction text,p_jours integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_moi text:=public.mon_personnage(); v_j record; v_a record;
  v_calc jsonb; v_paiement jsonb; v_res jsonb; v_erreur jsonb;
  v_jours integer;
BEGIN
  IF auth.uid() IS NULL OR v_moi IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  IF coalesce(btrim(p_affaire_id),'')='' OR coalesce(btrim(p_infraction),'')='' THEN
    RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration c
      WHERE c.singleton AND c.active AND c.champignons_malus IS NOT NULL
        AND c.formule_arrestation IS NOT NULL AND c.camp_bucherons_noeud IS NOT NULL) THEN
    RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
  SELECT data,city,country INTO v_a FROM public.plaintes_en_cours WHERE id=p_affaire_id FOR UPDATE;
  IF NOT FOUND OR v_a.country<>'soviet' THEN
    RETURN jsonb_build_object('ok',false,'raison','affaire_hors_sovarka'); END IF;
  SELECT * INTO v_j FROM public.juge_de_la_ville(v_a.city);
  IF NOT FOUND OR v_j.nom IS DISTINCT FROM v_moi OR v_j.pays IS DISTINCT FROM 'soviet'
    OR NOT public.sovarka_est_titulaire_interne(v_moi,'juge') THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_juge_sovarka'); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=v_moi AND country='soviet'
      AND user_id=auth.uid()) THEN
    RETURN jsonb_build_object('ok',false,'raison','reserve_juge_sovarka'); END IF;
  v_calc:=public.justice_peine_proposer(p_affaire_id,p_infraction,'qhs');
  IF coalesce((v_calc->>'ok')::boolean,false) IS NOT TRUE THEN RETURN v_calc; END IF;
  v_jours:=p_jours;
  -- Le juge choisit dans le barème ; ne jamais imposer le minimum à sa place.
  IF v_jours IS NULL OR v_jours<(v_calc->>'jours_min')::integer
    OR v_jours>(v_calc->>'jours_max')::integer THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_hors_bornes'); END IF;
  IF v_jours IS NULL OR v_jours<1 THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_invalide'); END IF;
  BEGIN
    v_paiement:=public.payer_ordre_interne(v_moi,'rendre_sentence',2,0,1);
    IF coalesce((v_paiement->>'ok')::boolean,false) IS NOT TRUE THEN
      v_erreur:=v_paiement;RAISE EXCEPTION USING ERRCODE='P2288',MESSAGE='paiement_refuse'; END IF;
    PERFORM set_config('rp.goulag_jugement_interne','valide',true);
    v_res:=public.justice_rendre_sentence(p_affaire_id,p_infraction,'qhs',v_jours,0);
    PERFORM set_config('rp.goulag_jugement_interne','',true);
    IF coalesce((v_res->>'ok')::boolean,false) IS NOT TRUE THEN
      v_erreur:=v_res;RAISE EXCEPTION USING ERRCODE='P2288',MESSAGE='sentence_refusee'; END IF;
  EXCEPTION WHEN SQLSTATE 'P2288' THEN
    RETURN v_erreur;
  END;
  RETURN v_res||jsonb_build_object('paiement',v_paiement,'lieu_detention','goulag');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_juger(text,text,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_juger(text,text,integer) TO authenticated;

-- SOURCE 20261116173000_goulag_liberation_restitution.sql
-- Libération régulière : restituer entièrement le dépôt et ramener
-- le détenu de Sovarka au centre multimodal de sa ville de condamnation.
DO $liberation$
DECLARE source text;ancre text;ajout text;
BEGIN
  IF to_regprocedure('public.sovarka_goulag_depot_clore_interne(text,text,text)') IS NULL THEN
    RAISE EXCEPTION 'goulag_depot_absent'; END IF;
  source:=pg_get_functiondef('public.detention_clore_interne(text,text,integer)'::regprocedure);
  IF strpos(source,'goulag_liberation_avec_depot_20261116')>0 THEN RETURN; END IF;
  ancre:=E'  -- incorporation_differee_v1';
  ajout:=E'  -- goulag_liberation_avec_depot_20261116 : libération régulière sans perte ni double restitution.\n'
    ||E'  DECLARE v_goulag_res jsonb; v_goulag_retour text; v_goulag_bat text; v_goulag_piece text;\n'
    ||E'  BEGIN\n'
    ||E'   IF v_qhs AND v_det.country=''soviet'' AND p_mode=''purgee'' THEN\n'
    ||E'     IF EXISTS(SELECT 1 FROM public.sovarka_goulag_depots\n'
    ||E'        WHERE nom=p_nom AND detention_id=v_det.id) THEN\n'
    ||E'       v_goulag_res:=public.sovarka_goulag_depot_clore_interne(p_nom,v_det.id,''liberation'');\n'
    ||E'       IF coalesce((v_goulag_res->>''ok'')::boolean,false) IS NOT TRUE THEN\n'
    ||E'         RAISE EXCEPTION ''goulag_restitution_impossible''; END IF;\n'
    ||E'     END IF;\n'
    ||E'     IF (SELECT current_city FROM public.personnages_donnees WHERE name=p_nom)=''qhs'' THEN\n'
    ||E'       v_goulag_retour:=coalesce(nullif(v_peine->>''retourVille'',''''),v_det.city);\n'
    ||E'       IF v_goulag_retour NOT IN (''capitale'',''ville_a'',''ville_b'') OR v_goulag_retour IS NULL THEN\n'
    ||E'         RAISE EXCEPTION ''goulag_retour_ville_invalide'';END IF;\n'
    ||E'       SELECT batiment,pieces->>0 INTO v_goulag_bat,v_goulag_piece\n'
    ||E'         FROM public.navigation_lieux_regles WHERE pays=''soviet'' AND ville=v_goulag_retour\n'
    ||E'           AND batiment LIKE ''centre-multinodal-%'' ORDER BY batiment LIMIT 1;\n'
    ||E'       IF v_goulag_bat IS NULL THEN RAISE EXCEPTION ''goulag_retour_non_reference''; END IF;\n'
    ||E'       UPDATE public.personnages_donnees SET current_city=v_goulag_retour,\n'
    ||E'         current_building=v_goulag_bat,current_room=v_goulag_piece,current_street=NULL,\n'
    ||E'         updated_at=clock_timestamp() WHERE name=p_nom;\n'
    ||E'     END IF;\n'
    ||E'   END IF;\n'
    ||E'  END;\n'
    ||ancre;
  IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
    RAISE EXCEPTION 'liberation_ancre_absente';END IF;
  EXECUTE replace(source,ancre,ajout);
END $liberation$;

-- SOURCE 20261116173500_goulag_refuge_rejoindre.sql
-- Refuge du goulag : rejoindre la maison d'accueil depuis le point d'arrivée,
-- sans inventer de sortie de rue générale ni autoriser un téléporteur libre.
-- Le fugitif arrive réellement sur le noeud de rue prévu, puis frappe à la
-- porte de l'habitant qui l'accueille toujours pendant sa convalescence.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_refuge_rejoindre()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage();
        v_p public.personnages_donnees%ROWTYPE;
        v_r public.sovarka_goulag_refuges%ROWTYPE;
        v_c public.sovarka_goulag_configuration%ROWTYPE;
        v_ville text; v_noeud text; v_maison text;
BEGIN
 IF auth.uid() IS NULL OR v_nom IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_p FROM public.personnages_donnees
  WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT * INTO v_r FROM public.sovarka_goulag_refuges WHERE nom=v_nom FOR UPDATE;
 IF NOT FOUND OR v_r.termine THEN
  RETURN jsonb_build_object('ok',false,'raison','refuge_non_actif'); END IF;
 IF v_r.destination='starovka' THEN
  v_ville:='ville_a';v_noeud:='starovka-rue-stade';v_maison:='maison-starovka';
 ELSIF v_r.destination='krasnov' THEN
  SELECT * INTO v_c FROM public.sovarka_goulag_configuration WHERE singleton;
  IF v_c.camp_bucherons_noeud IS NULL THEN
   RETURN jsonb_build_object('ok',false,'raison','camp_bucherons_non_reference'); END IF;
  v_ville:='ville_b';v_noeud:=v_c.camp_bucherons_noeud;v_maison:='maison-krasnov';
 ELSE
  RETURN jsonb_build_object('ok',false,'raison','destination_inconnue');
 END IF;
 IF (v_p.country,v_p.current_city,v_p.current_building,v_p.current_room)
   IS NOT DISTINCT FROM ('soviet',v_ville,v_maison,'piece_maison') THEN
  RETURN jsonb_build_object('ok',true,'deja_arrive',true,
   'batiment',v_maison,'piece','piece_maison');
 END IF;
 IF (v_p.country,v_p.current_city,v_p.current_building,v_p.current_room,v_p.current_street)
   IS DISTINCT FROM ('soviet',v_ville,NULL,NULL,v_noeud) THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_au_point_arrivee'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles n
   WHERE n.pays='soviet' AND n.ville=v_ville AND n.batiment=v_maison
     AND n.pieces ? 'piece_maison') THEN
  RETURN jsonb_build_object('ok',false,'raison','maison_non_referencee'); END IF;
 UPDATE public.personnages_donnees SET current_building=v_maison,
   current_room='piece_maison',current_street=NULL,updated_at=clock_timestamp()
 WHERE name=v_nom AND user_id=auth.uid();
 RETURN jsonb_build_object('ok',true,'batiment',v_maison,'piece','piece_maison');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_refuge_rejoindre() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_refuge_rejoindre() TO authenticated;

-- SOURCE 20261116174000_goulag_admission_juge_seul.sql
-- La mécanique soviarkienne ne doit jamais hériter d'un transfert QHS
-- républicain : un transfert vers le goulag doit venir de la sentence
-- atomique du juge de Sovarka, même lorsqu'un appel direct à une ancienne
-- fonction de prolongation de peine est tenté.
DO $goulag_admission$
DECLARE source text; ancre text; garde text;
BEGIN
 source := pg_get_functiondef('public.detention_qhs_poser_interne(text,text,text)'::regprocedure);
 IF strpos(source,'goulag_admission_juge_20261116')>0 THEN RETURN; END IF;
 ancre := E'  IF NOT FOUND THEN RETURN; END IF;';
 garde := ancre
   || E'\n  -- goulag_admission_juge_20261116 : Sovarka uniquement, Républia inchangée.\n'
   || E'  IF v_det.country = ''soviet'' AND\n'
   || E'    (NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration c\n'
   || E'      WHERE c.singleton AND c.active)\n'
   || E'     OR (current_setting(''rp.goulag_jugement_interne'',true) IS DISTINCT FROM ''valide''\n'
   || E'       AND NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees t\n'
   || E'         JOIN public.detentions d ON d.id=t.detention_id\n'
   || E'         WHERE t.nom=p_nom AND t.nouvelle_detention_id=p_detention_id\n'
   || E'           AND t.peine_reprise_le IS NOT NULL AND d.qhs AND d.country=''soviet''))) THEN\n'
   || E'    RAISE EXCEPTION ''goulag_transfert_hors_jugement''; END IF;';
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
  RAISE EXCEPTION 'detention_qhs_poser_interne_ancre_absente';END IF;
 EXECUTE replace(source,ancre,garde);
END $goulag_admission$;

-- Fred, commentaire 6924174456 : 30 % par entrée EFFECTIVE, jamais par clic.
-- Le verrou de la ligne personnage sérialise les entrées concurrentes ; une
-- répétition de position ne passe pas le WHEN du déclencheur.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_entrees (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 nom text NOT NULL REFERENCES public.personnages_donnees(name),
 pays text NOT NULL CHECK(pays='soviet'),ville text NOT NULL,batiment text NOT NULL,
 taux integer NOT NULL DEFAULT 30 CHECK(taux=30),arrete boolean NOT NULL,
 transaction_id bigint NOT NULL DEFAULT txid_current(),creee_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_goulag_entrees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_entrees FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX IF NOT EXISTS sovarka_goulag_entrees_transaction ON public.sovarka_goulag_entrees(nom,transaction_id);

CREATE OR REPLACE FUNCTION public.sovarka_goulag_controler_entree()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_t public.sovarka_goulag_traversees%ROWTYPE; v_jet boolean; v_ecrou jsonb; v_depot jsonb;
BEGIN
 IF NEW.country IS DISTINCT FROM 'soviet' OR NEW.current_building IS NULL
  OR NEW.current_building NOT IN ('hotel-republica','hotel-mineur','dispensaire-public','dispensaire-public-v','clinique-privee')
  OR NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration WHERE singleton AND active) THEN RETURN NEW; END IF;
 SELECT * INTO v_t FROM public.sovarka_goulag_traversees WHERE nom=NEW.name
  AND statut='detenu' AND NOT en_cours AND peine_gelee_secondes>0 AND peine_reprise_le IS NULL FOR UPDATE;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM public.detention_active(NEW.name)) THEN RETURN NEW; END IF;
 v_jet:=random()<0.30;
 INSERT INTO public.sovarka_goulag_entrees(nom,pays,ville,batiment,arrete)
  VALUES(NEW.name,NEW.country,NEW.current_city,NEW.current_building,v_jet);
 IF NOT v_jet THEN RETURN NEW; END IF;
 -- Zéro jour supplémentaire : seul le reliquat judiciaire sera repris par le moteur.
 v_ecrou:=public.detention_ouvrir_interne(NEW.name,'Reprise de la peine du goulag',0,
  NEW.current_city,'soviet','[]'::jsonb,'Commissariat','reincarceration');
 IF coalesce((v_ecrou->>'ok')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'goulag_reincarceration_impossible'; END IF;
 -- Réexécution de la décision judiciaire initiale, aucune nouvelle condamnation.
 PERFORM public.detention_qhs_poser_interne(NEW.name,v_ecrou->>'detention_id','Reprise de la peine du goulag');
 v_depot:=public.sovarka_goulag_confisquer_interne(NEW.name,v_ecrou->>'detention_id');
 IF coalesce((v_depot->>'ok')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'goulag_depot_reincarceration_impossible'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_controler_entree() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS goulag_entree_effective ON public.personnages_donnees;
CREATE TRIGGER goulag_entree_effective AFTER UPDATE OF country,current_city,current_building ON public.personnages_donnees
 FOR EACH ROW WHEN ((OLD.country,OLD.current_city,OLD.current_building) IS DISTINCT FROM
 (NEW.country,NEW.current_city,NEW.current_building)) EXECUTE FUNCTION public.sovarka_goulag_controler_entree();

-- Joindre le verdict d'arrestation à la navigation publique, afin que l'écran
-- relise la cellule réelle au lieu d'afficher l'hôtel demandé.
DO $navigation_arrestation$
DECLARE source text;ancre text;ajout text;
BEGIN
 source:=pg_get_functiondef('public.navigation_interieure(text,text)'::regprocedure);
 IF strpos(source,'goulag_navigation_arrestation_20261117')>0 THEN RETURN; END IF;
 ancre:=E'  RETURN v;';
 ajout:=E'  -- goulag_navigation_arrestation_20261117\n'
  ||E'  IF coalesce((v->>''ok'')::boolean,false) AND EXISTS(SELECT 1 FROM public.sovarka_goulag_entrees\n'
  ||E'    WHERE transaction_id=txid_current() AND arrete AND (nom=v_moi OR coalesce(v->''membres'',''[]''::jsonb) ? nom)) THEN\n'
  ||E'   v:=v||jsonb_build_object(''goulag_arrestation'',jsonb_build_object(''ok'',true,''arrete'',\n'
  ||E'    EXISTS(SELECT 1 FROM public.sovarka_goulag_entrees WHERE transaction_id=txid_current() AND arrete AND nom=v_moi))); END IF;\n'||ancre;
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN RAISE EXCEPTION 'navigation_goulag_ancre_absente'; END IF;
 EXECUTE replace(source,ancre,ajout);
END $navigation_arrestation$;

-- SOURCE 20261116174500_goulag_ordres_confinement.sql
-- Verrou transversal des ordres facturés pendant une traversée ou un refuge.
-- Empêche de contourner la survie par un ordre de nourriture, d'hébergement
-- ou de transport ancien, même si le navigateur garde un bouton en cache.
DO $goulag_ordre$
DECLARE source text; ancre text; garde text;
BEGIN
 source:=pg_get_functiondef('public.payer_ordre_interne(text,text,integer,integer,integer)'::regprocedure);
 IF strpos(source,'goulag_ordre_isolement_20261116')>0 THEN RETURN; END IF;
 ancre:=E'  PERFORM public.exiger_acteur(p_acteur);';
 garde:=ancre
   ||E'\n  -- goulag_ordre_isolement_20261116 : aucune dépense générique en toundra ou convalescence.\n'
   ||E'  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees t\n'
   ||E'      WHERE t.nom=p_acteur AND t.en_cours) THEN\n'
   ||E'    RETURN jsonb_build_object(''ok'',false,''raison'',''traversee_irreversible''); END IF;\n'
   ||E'  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges r\n'
   ||E'      WHERE r.nom=p_acteur AND NOT r.termine) THEN\n'
   ||E'    RETURN jsonb_build_object(''ok'',false,''raison'',''repos_force_goulag''); END IF;';
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
   RAISE EXCEPTION 'payer_ordre_interne_ancre_absente'; END IF;
 EXECUTE replace(source,ancre,garde);
END $goulag_ordre$;

-- Le repos civil ne peut créditer +12 PA en plus des seuls +3/+6 de survie.
-- Le personnage est déjà verrouillé par pa_repos_nocturne avant cette garde.
DO $goulag_repos$
DECLARE source text; ancre text; garde text;
BEGIN
 source:=pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure);
 IF strpos(source,'goulag_repos_toundra_20261116')>0 THEN RETURN; END IF;
 ancre:=E'  IF v_deja IS NOT NULL AND v_deja >= v_jour THEN';
 garde:=E'  -- goulag_repos_toundra_20261116 : sommeil explicite, aucun crédit civil supplémentaire.\n'
   ||E'  IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees t\n'
   ||E'    JOIN public.personnages_donnees d ON d.name=t.nom\n'
   ||E'    WHERE t.nom=p_acteur AND t.en_cours AND d.country=''soviet'') THEN\n'
   ||E'    RETURN jsonb_build_object(''ok'',false,''raison'',''sommeil_toundra_explicit'',''pa'',v_pa); END IF;\n'
   ||ancre;
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
   RAISE EXCEPTION 'pa_repos_nocturne_ancre_absente'; END IF;
 EXECUTE replace(source,ancre,garde);
END $goulag_repos$;

-- SOURCE 20261116175000_goulag_sortie_qhs_visiteur.sql
-- Aucun visiteur ne doit quitter le goulag de Sovarka en empruntant la
-- sortie QHS générique de Républia, puis un bus sans décision serveur.
-- Le retour se fait exclusivement par sovarka_goulag_visiteur_repartir.
DO $goulag_sortie$
DECLARE source text;ancre text;garde text;
BEGIN
 source:=pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure);
 IF strpos(source,'goulag_sortie_qhs_20261116')>0 THEN RETURN; END IF;
 ancre:=E' -- navigation_zone_speciale_v1';
 garde:=E' -- goulag_sortie_qhs_20261116 : pas de sortie libre du camp vers le bus du QHS.\n'
   ||E' IF p.country=''soviet'' AND p.current_city=''qhs''\n'
   ||E'    AND p_batiment IS NULL THEN\n'
   ||E'   RETURN jsonb_build_object(''ok'',false,''raison'',''sortie_goulag_reservee''); END IF;\n'
   ||ancre;
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
   RAISE EXCEPTION 'navigation_sortie_qhs_ancre_absente'; END IF;
 EXECUTE replace(source,ancre,garde);
END $goulag_sortie$;

-- SOURCE 20261116175500_goulag_detenu_acces_entree.sql
-- Le prisonnier est placé dans la cellule du goulag par le moteur de
-- détention. Il doit pouvoir rejoindre l'entrée pour choisir « S'enfuir
-- à pied », sans que cette circulation intérieure autorise un transport
-- ordinaire ni contourne le statut de détenu.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_detenu_vers_entree()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text:=public.mon_personnage();
        v_p public.personnages_donnees%ROWTYPE; v_det record;
BEGIN
 IF auth.uid() IS NULL OR v_nom IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration c
     WHERE c.singleton AND c.active) THEN
  RETURN jsonb_build_object('ok',false,'raison','goulag_non_active'); END IF;
 SELECT * INTO v_p FROM public.personnages_donnees
   WHERE name=v_nom AND user_id=auth.uid() FOR UPDATE;
 IF NOT FOUND OR (v_p.country,v_p.current_city,v_p.current_building)
   IS DISTINCT FROM ('soviet','qhs','qhs-prison') THEN
  RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
 SELECT * INTO v_det FROM public.detention_active(v_nom);
 IF NOT FOUND OR v_det.country<>'soviet' OR NOT v_det.qhs THEN
  RETURN jsonb_build_object('ok',false,'raison','non_detenu_goulag'); END IF;
 IF v_p.current_room='entree_qhs' THEN
  RETURN jsonb_build_object('ok',true,'deja_entree',true); END IF;
 IF v_p.current_room IS DISTINCT FROM 'cellules_qhs' THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_dans_les_cellules'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles
   WHERE pays='soviet' AND ville='qhs' AND batiment='qhs-prison'
     AND pieces ? 'entree_qhs') THEN
  RETURN jsonb_build_object('ok',false,'raison','entree_absente'); END IF;
 UPDATE public.personnages_donnees SET current_room='entree_qhs',
    current_street=NULL,updated_at=clock_timestamp()
  WHERE name=v_nom AND user_id=auth.uid();
 RETURN jsonb_build_object('ok',true,'room','entree_qhs');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_detenu_vers_entree() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_detenu_vers_entree() TO authenticated;

-- Fermer aussi les RPC gratuites et les écritures visant le PJ depuis un autre
-- acteur (don d'objets, repas, sommeil, téléportation, sauvegarde périmée).
-- request.path vient de PostgREST, pas des arguments de la fonction cliente.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_fiche_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_chemin text:=coalesce(current_setting('request.path',true),''); v_phase text;
BEGIN
 IF OLD.country IS DISTINCT FROM 'soviet' OR
  coalesce(nullif(current_setting('role',true),'none'),session_user) NOT IN ('anon','authenticated','service_role') THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees WHERE nom=OLD.name AND en_cours) THEN
  v_phase:='traversee_irreversible';
 ELSIF EXISTS(SELECT 1 FROM public.sovarka_goulag_refuges WHERE nom=OLD.name AND NOT termine) THEN
  v_phase:='repos_force_goulag';
 ELSE RETURN NEW; END IF;
 IF (NEW.pa,NEW.inventory,NEW.country,NEW.current_city,NEW.current_building,NEW.current_room,NEW.current_street)
  IS NOT DISTINCT FROM (OLD.pa,OLD.inventory,OLD.country,OLD.current_city,OLD.current_building,OLD.current_room,OLD.current_street) THEN RETURN NEW; END IF;
 IF v_chemin=ANY(ARRAY['/rpc/goulag_toundra_demarrer','/rpc/goulag_toundra_agir',
  '/rpc/sovarka_goulag_refuge_rejoindre','/rpc/sovarka_goulag_refuge_nuit',
  '/rpc/sovarka_goulag_refuge_terminer','/rpc/pa_repos_nocturne'])
  AND (OLD.user_id=auth.uid() OR (v_chemin='/rpc/pa_repos_nocturne'
   AND coalesce(nullif(current_setting('role',true),'none'),session_user)='service_role')) THEN RETURN NEW; END IF;
 RAISE EXCEPTION USING ERRCODE='42501',MESSAGE=v_phase;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_fiche_garder() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS zz_goulag_fiche_garder ON public.personnages_donnees;
CREATE TRIGGER zz_goulag_fiche_garder BEFORE UPDATE ON public.personnages_donnees
 FOR EACH ROW EXECUTE FUNCTION public.sovarka_goulag_fiche_garder();

-- SOURCE 20261116176000_goulag_ouverture_lecture.sql
-- Goulag de Sovarka : lecture de l'ouverture pour le navigateur (décision de Fred du 17/11/2026).
-- Le client du goulag reste entièrement caché tant que cette fonction ne rend pas `true`.
-- Lecture seule ; ne modifie rien. Le verrou CHECK (active IS FALSE) reste en place :
-- tant qu'il existe, cette fonction rend toujours false.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_ouvert()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((SELECT c.active IS TRUE FROM public.sovarka_goulag_configuration c WHERE c.singleton), false);
$$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_ouvert() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_ouvert() TO authenticated, service_role;

-- SOURCE 20261117170000_goulag_ordres_internes_registre.sql
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

-- SOURCE 20261117170500_goulag_ordres_internes_detention.sql
-- Goulag de Sovarka — ordres internes, lot 2/4 : dortoir, cachot, libération, circulation.
-- Décisions de Fred du 17/11/2026 :
--  * Dortoir : « Dormir » +1 PA et une journée de peine purgée ; « Manger » +1 PA, une fois par jour.
--  * Cachot : « Dormir » 0 PA, une journée de peine ET une nuit de sanction (deux nuits au plus).
--  * Le temps qui passe ne réduit jamais la peine ; un sommeil par jour (même marqueur que le repos
--    général pa_repos_le, donc aucune double récupération avec le « Dormir » de la fiche).
--  * Peine achevée par le sommeil : libération automatique devant l'entrée du goulag.
DO $goulag_ordres_prerequis$
BEGIN
  IF to_regclass('public.sovarka_goulag_registre') IS NULL THEN
    RAISE EXCEPTION 'goulag_ordres_lot1_requis'; END IF;
END $goulag_ordres_prerequis$;

-- Placement au cachot : jamais plus de deux nuits, jamais d'addition au-delà.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_cachot_placer_interne(
  p_nom text, p_detention_id text, p_nuits integer, p_motif text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nuits integer;
BEGIN
  IF p_nuits NOT IN (1,2) OR p_nuits IS NULL
     OR p_motif NOT IN ('evasion_echouee','decision_judiciaire') OR p_motif IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','sanction_invalide'); END IF;
  UPDATE public.sovarka_goulag_registre
     SET cachot_nuits = least(2, greatest(cachot_nuits, p_nuits)), cachot_motif = p_motif
   WHERE detention_id = p_detention_id AND nom = p_nom
     AND liberation_le IS NULL AND evasion_le IS NULL
  RETURNING cachot_nuits INTO v_nuits;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','detenu_introuvable'); END IF;
  UPDATE public.personnages_donnees
     SET current_room = 'cachot_disciplinaire', current_street = NULL, updated_at = clock_timestamp()
   WHERE name = p_nom AND country = 'soviet' AND current_city = 'qhs' AND current_building = 'qhs-prison';
  RETURN jsonb_build_object('ok',true,'cachot_nuits',v_nuits);
END $$;

-- Libération régulière : registre, fin de détention (restitution du dépôt par le moteur #1020),
-- puis dépôt devant l'entrée du camp avec une présence enregistrée pour repartir normalement.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_liberer_interne(p_nom text, p_detention_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_peine jsonb; v_ville text; v_clos jsonb; v_n integer;
BEGIN
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  SELECT coalesce(nullif(v_peine->>'retourVille',''), d.city) INTO v_ville
    FROM public.detentions d WHERE d.id = p_detention_id;
  UPDATE public.sovarka_goulag_registre SET liberation_le = now()
   WHERE detention_id = p_detention_id AND nom = p_nom AND jours_restants = 0
     AND liberation_le IS NULL AND evasion_le IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok',false,'raison','liberation_non_due'); END IF;
  v_clos := public.detention_clore_interne(p_nom, 'purgee');
  IF EXISTS (SELECT 1 FROM public.detentions WHERE id = p_detention_id AND mode_fin IS NULL) THEN
    RAISE EXCEPTION 'goulag_liberation_non_close'; END IF;
  -- Décision du 17/11 : le libéré se retrouve DEVANT L'ENTRÉE du goulag.
  UPDATE public.personnages_donnees
     SET country = 'soviet', current_city = 'qhs', current_building = 'qhs-prison',
         current_room = 'entree_qhs', current_street = NULL, updated_at = clock_timestamp()
   WHERE name = p_nom;
  IF v_ville IN ('capitale','ville_a','ville_b') THEN
    INSERT INTO public.sovarka_goulag_visites(nom,origine,present,entre_le,sorti_le)
    VALUES (p_nom, v_ville, true, now(), NULL)
    ON CONFLICT (nom) DO UPDATE SET origine = EXCLUDED.origine, present = true,
      entre_le = now(), sorti_le = NULL;
  END IF;
  PERFORM public.mail_systeme_poser_interne('Camp de rééducation de Sovarka', p_nom,
    'Libération', 'Votre peine est purgée. Vous êtes libéré(e) et conduit(e) devant l''entrée du camp.');
  RETURN jsonb_build_object('ok',true,'libere',true,'detention_id',p_detention_id,
    'room','entree_qhs','fin',v_clos);
END $$;

-- « Dormir » au dortoir ou au cachot : un seul sommeil valide par jour de Paris.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_dormir()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        r public.sovarka_goulag_registre%ROWTYPE; v_refus jsonb; v_det text;
        v_jour date := public.sovarka_goulag_jour_interne(); v_lieu text; v_gain integer;
        v_pa integer; v_lib jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_nom AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND OR (p.country, p.current_city, p.current_building)
     IS DISTINCT FROM ('soviet','qhs','qhs-prison') THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(v_nom);
  SELECT * INTO r FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_detenu_goulag'); END IF;
  IF p.current_room = 'cellules_qhs' THEN
    IF r.cachot_nuits > 0 THEN
      RETURN jsonb_build_object('ok',false,'raison','sanction_cachot_en_cours','cachot_nuits',r.cachot_nuits); END IF;
    v_lieu := 'dortoir'; v_gain := 1;
  ELSIF p.current_room = 'cachot_disciplinaire' THEN
    IF r.cachot_nuits = 0 THEN
      -- Compteur épuisé : jamais d'enfermement indéfini, retour au dortoir sans consommer de nuit.
      UPDATE public.personnages_donnees SET current_room = 'cellules_qhs', current_street = NULL,
        updated_at = clock_timestamp() WHERE name = v_nom;
      RETURN jsonb_build_object('ok',false,'raison','sanction_terminee','room','cellules_qhs'); END IF;
    v_lieu := 'cachot'; v_gain := 0;
  ELSE
    RETURN jsonb_build_object('ok',false,'raison','pas_de_couchette'); END IF;
  IF (p.pa_repos_le IS NOT NULL AND p.pa_repos_le >= v_jour)
     OR (r.dernier_sommeil IS NOT NULL AND r.dernier_sommeil >= v_jour) THEN
    RETURN jsonb_build_object('ok',false,'raison','deja_dormi_aujourdhui','pa',p.pa); END IF;
  UPDATE public.personnages_donnees
     SET pa = least(30, greatest(0, coalesce(pa,0)) + v_gain), pa_repos_le = v_jour,
         updated_at = clock_timestamp()
   WHERE name = v_nom RETURNING pa INTO v_pa;
  UPDATE public.sovarka_goulag_registre
     SET jours_restants = greatest(0, jours_restants - 1), dernier_sommeil = v_jour,
         cachot_nuits = CASE WHEN v_lieu = 'cachot' THEN greatest(0, cachot_nuits - 1) ELSE cachot_nuits END,
         cachot_motif = CASE WHEN v_lieu = 'cachot' AND cachot_nuits <= 1 THEN NULL ELSE cachot_motif END
   WHERE detention_id = r.detention_id
  RETURNING * INTO r;
  IF r.jours_restants = 0 THEN
    v_lib := public.sovarka_goulag_liberer_interne(v_nom, r.detention_id);
    IF coalesce((v_lib->>'ok')::boolean,false) IS NOT TRUE THEN
      RAISE EXCEPTION 'goulag_liberation_impossible'; END IF;
    RETURN jsonb_build_object('ok',true,'lieu',v_lieu,'gain',v_gain,'pa',v_pa,
      'jours_restants',0,'libere',true,'room','entree_qhs');
  END IF;
  IF v_lieu = 'cachot' AND r.cachot_nuits = 0 THEN
    UPDATE public.personnages_donnees SET current_room = 'cellules_qhs', current_street = NULL,
      updated_at = clock_timestamp() WHERE name = v_nom;
  END IF;
  RETURN jsonb_build_object('ok',true,'lieu',v_lieu,'gain',v_gain,'pa',v_pa,
    'jours_restants',r.jours_restants,'cachot_nuits',r.cachot_nuits,'libere',false,
    'room',CASE WHEN v_lieu = 'cachot' AND r.cachot_nuits > 0 THEN 'cachot_disciplinaire' ELSE 'cellules_qhs' END);
END $$;

-- « Manger » : dortoir uniquement, +1 PA, un repas par jour de Paris (même règle que les repas du jeu).
CREATE OR REPLACE FUNCTION public.sovarka_goulag_manger()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        r public.sovarka_goulag_registre%ROWTYPE; v_refus jsonb; v_det text;
        v_jour date := public.sovarka_goulag_jour_interne(); v_pa integer;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_nom AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND OR (p.country, p.current_city, p.current_building, p.current_room)
     IS DISTINCT FROM ('soviet','qhs','qhs-prison','cellules_qhs') THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_dortoir'); END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(v_nom);
  SELECT * INTO r FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_detenu_goulag'); END IF;
  IF r.cachot_nuits > 0 THEN
    RETURN jsonb_build_object('ok',false,'raison','sanction_cachot_en_cours'); END IF;
  IF r.dernier_repas IS NOT NULL AND r.dernier_repas >= v_jour THEN
    RETURN jsonb_build_object('ok',false,'raison','deja_mange','pa',p.pa); END IF;
  UPDATE public.personnages_donnees SET pa = least(30, greatest(0, coalesce(pa,0)) + 1),
    updated_at = clock_timestamp() WHERE name = v_nom RETURNING pa INTO v_pa;
  UPDATE public.sovarka_goulag_registre SET dernier_repas = v_jour WHERE detention_id = r.detention_id;
  RETURN jsonb_build_object('ok',true,'gain',1,'pa',v_pa);
END $$;

-- Circulation intérieure d'un détenu (le moteur général refuse tout déplacement aux détenus) :
-- dortoir, entrée et mirador seulement ; jamais le bureau ; aucune sortie du cachot pendant
-- la sanction. Ce n'est ni une libération ni un transport.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_detenu_aller(p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        r public.sovarka_goulag_registre%ROWTYPE; v_refus jsonb; v_det text;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_piece NOT IN ('cellules_qhs','entree_qhs','mirador') OR p_piece IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','piece_interdite'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_nom AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND OR (p.country, p.current_city, p.current_building)
     IS DISTINCT FROM ('soviet','qhs','qhs-prison') THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(v_nom);
  SELECT * INTO r FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_detenu_goulag'); END IF;
  IF r.cachot_nuits > 0 THEN
    RETURN jsonb_build_object('ok',false,'raison','sanction_cachot_en_cours','cachot_nuits',r.cachot_nuits); END IF;
  IF p.current_room NOT IN ('cellules_qhs','entree_qhs','mirador','cachot_disciplinaire') THEN
    RETURN jsonb_build_object('ok',false,'raison','piece_de_depart_interdite'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'qhs'
       AND batiment = 'qhs-prison' AND pieces ? p_piece) THEN
    RETURN jsonb_build_object('ok',false,'raison','piece_non_referencee'); END IF;
  IF p.current_room = p_piece THEN RETURN jsonb_build_object('ok',true,'room',p_piece,'deja',true); END IF;
  UPDATE public.personnages_donnees SET current_room = p_piece, current_street = NULL,
    updated_at = clock_timestamp() WHERE name = v_nom AND user_id = auth.uid();
  RETURN jsonb_build_object('ok',true,'room',p_piece);
END $$;

-- État de détention lu par l'écran (aucune écriture).
CREATE OR REPLACE FUNCTION public.sovarka_goulag_ma_detention()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); r public.sovarka_goulag_registre%ROWTYPE;
        v_jour date := public.sovarka_goulag_jour_interne(); v_pa_repos date;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT * INTO r FROM public.sovarka_goulag_registre
   WHERE detention_id = public.sovarka_goulag_detention_registree_interne(v_nom);
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'detenu',false); END IF;
  SELECT pa_repos_le INTO v_pa_repos FROM public.personnages_donnees WHERE name = v_nom;
  RETURN jsonb_build_object('ok',true,'detenu',true,'jours_restants',r.jours_restants,
    'cachot_nuits',r.cachot_nuits,'cachot_motif',r.cachot_motif,
    'a_dormi',(coalesce(v_pa_repos,'-infinity'::date) >= v_jour OR coalesce(r.dernier_sommeil,'-infinity'::date) >= v_jour),
    'a_mange',coalesce(r.dernier_repas,'-infinity'::date) >= v_jour,
    'tentative_faite',coalesce(r.derniere_tentative,'-infinity'::date) >= v_jour,
    'corruption_bonus',r.corruption_bonus);
END $$;

-- Le repos général (« Dormir » de la fiche) ne s'applique pas au goulag : sinon +12/+3 PA
-- s'ajouteraient au +1/0 du camp. Garde insérée sans retirer aucune autre garde existante.
DO $goulag_repos_dortoir$
DECLARE source text; ancre text; garde text;
BEGIN
  source := pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure);
  IF strpos(source,'goulag_sommeil_dortoir_20261117') > 0 THEN RETURN; END IF;
  ancre := E'  IF v_deja IS NOT NULL AND v_deja >= v_jour THEN';
  garde := E'  -- goulag_sommeil_dortoir_20261117 : le détenu du goulag dort au dortoir ou au cachot.\n'
    || E'  IF public.sovarka_goulag_detention_registree_interne(p_acteur) IS NOT NULL THEN\n'
    || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''sommeil_goulag_dortoir'', ''pa'', v_pa); END IF;\n'
    || ancre;
  IF (length(source) - length(replace(source, ancre, ''))) <> length(ancre) THEN
    RAISE EXCEPTION 'pa_repos_nocturne_ancre_absente'; END IF;
  EXECUTE replace(source, ancre, garde);
END $goulag_repos_dortoir$;

-- Une peine du goulag ne se purge jamais au calendrier : la libération vient du sommeil.
DO $goulag_purge_calendrier$
DECLARE source text; ancre text; garde text;
BEGIN
  source := pg_get_functiondef('public.detention_clore_purgee()'::regprocedure);
  IF strpos(source,'goulag_peine_au_sommeil_20261117') > 0 THEN RETURN; END IF;
  ancre := E'  SELECT * INTO v_det FROM public.detention_active(v_moi);\n';
  garde := ancre
    || E'  -- goulag_peine_au_sommeil_20261117 : aucun décompte par simple passage du temps.\n'
    || E'  IF EXISTS (SELECT 1 FROM public.sovarka_goulag_registre r WHERE r.detention_id = v_det.id) THEN\n'
    || E'    RETURN jsonb_build_object(''ok'',false,''raison'',''peine_goulag_au_sommeil''); END IF;\n';
  IF (length(source) - length(replace(source, ancre, ''))) <> length(ancre) THEN
    RAISE EXCEPTION 'detention_clore_purgee_ancre_absente'; END IF;
  EXECUTE replace(source, ancre, garde);
END $goulag_purge_calendrier$;

REVOKE ALL ON FUNCTION public.sovarka_goulag_cachot_placer_interne(text,text,integer,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_liberer_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_dormir() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_manger() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_detenu_aller(text) FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_ma_detention() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_dormir() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_manger() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_detenu_aller(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_ma_detention() TO authenticated;

-- SOURCE 20261117171000_goulag_ordres_internes_bureau_mirador.sql
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
  -- Rejeu : seulement pour le même interrogateur et le même détenu ; une clé déjà prise ailleurs est refusée.
  SELECT CASE WHEN interrogateur = v_nom AND detenu = d.name THEN resultat END INTO v_deja
    FROM public.sovarka_goulag_interrogatoires WHERE requete = p_requete;
  IF FOUND THEN
    IF v_deja IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_deja_utilisee'); END IF;
    RETURN v_deja || jsonb_build_object('rejeu',true);
  END IF;
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
  -- Rejeu : seulement pour le même juge, le même détenu et le même nombre de nuits, avant tout paiement.
  SELECT CASE WHEN i.nom = d.name AND i.details->>'juge' = v_nom AND (i.details->>'nuits')::integer = p_nuits
              THEN jsonb_build_object('ok',true,'rejeu',true,'detenu',d.name,'nuits',p_nuits)
              ELSE jsonb_build_object('ok',false,'raison','requete_deja_utilisee') END
    INTO v_res FROM public.sovarka_goulag_incidents i WHERE i.cle = v_cle;
  IF FOUND THEN RETURN v_res; END IF;
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
  -- Rejeu : seulement pour le même détenu ; une clé déjà prise par un autre est refusée.
  SELECT CASE WHEN nom = v_nom THEN resultat END INTO v_deja
    FROM public.sovarka_goulag_corruptions WHERE requete = p_requete;
  IF FOUND THEN
    IF v_deja IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_deja_utilisee'); END IF;
    RETURN v_deja || jsonb_build_object('rejeu',true);
  END IF;
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

-- SOURCE 20261117171500_goulag_ordres_internes_raccord_evasion.sql
-- Goulag de Sovarka — ordres internes, lot 4/4 : raccord avec le départ « S'enfuir à pied »
-- préparé par Codex (PR #1020, goulag_toundra_demarrer). INTÉGRATION ISOLÉE : la fonction de
-- Codex est complétée par remplacement d'ancres exactes, sans réécrire ses autres règles ni
-- toucher à la marche, l'abri, les champignons, le bois, le refuge ou l'arrivée.
--
-- Décisions de Fred du 17/11/2026 :
--  * Jet de SORTIE DU CAMP, distinct de la survie : 80 % sans corruption, 95 % après corruption
--    d'un gardien ; une seule tentative par jour ; jet serveur non rejouable.
--  * Échec : aucun départ, deux nuits de cachot, peine principale conservée, incident enregistré.
--  * Réussite : la traversée existante démarre (7 PA/7 jours Starovka, 10 PA/10 jours Krasnov).
--  * Le reliquat figé est le compteur de jours que seul le sommeil fait baisser.
-- Le visiteur libre n'est pas concerné par le jet : ce n'est pas une évasion.
DO $goulag_ordres_prerequis$
BEGIN
  IF to_regprocedure('public.sovarka_goulag_cachot_placer_interne(text,text,integer,text)') IS NULL THEN
    RAISE EXCEPTION 'goulag_ordres_lot2_requis'; END IF;
END $goulag_ordres_prerequis$;

CREATE OR REPLACE FUNCTION public.sovarka_goulag_sortie_jet_interne(p_nom text, p_detention_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE r public.sovarka_goulag_registre%ROWTYPE; v_jour date := public.sovarka_goulag_jour_interne();
        v_taux integer; v_jet integer; v_ok boolean; v_cachot jsonb; v_n integer;
BEGIN
  SELECT * INTO r FROM public.sovarka_goulag_registre
   WHERE detention_id = p_detention_id AND nom = p_nom FOR UPDATE;
  IF NOT FOUND OR r.liberation_le IS NOT NULL OR r.evasion_le IS NOT NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','registre_goulag_absent'); END IF;
  IF r.jours_restants <= 0 THEN
    RETURN jsonb_build_object('ok',false,'raison','peine_deja_purgee'); END IF;
  IF r.cachot_nuits > 0 THEN
    RETURN jsonb_build_object('ok',false,'raison','sanction_cachot_en_cours'); END IF;
  IF r.derniere_tentative IS NOT NULL AND r.derniere_tentative >= v_jour THEN
    RETURN jsonb_build_object('ok',false,'raison','tentative_deja_faite_aujourdhui'); END IF;
  v_taux := CASE WHEN r.corruption_bonus THEN 95 ELSE 80 END;
  v_jet := floor(random() * 100)::integer + 1;
  v_ok := v_jet <= v_taux;
  -- La clé (détention, jour) interdit physiquement une seconde tentative le même jour.
  INSERT INTO public.sovarka_goulag_tentatives(detention_id,jour,nom,taux,jet,reussi,corruption)
  VALUES (r.detention_id, v_jour, p_nom, v_taux, v_jet, v_ok, r.corruption_bonus)
  ON CONFLICT (detention_id, jour) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok',false,'raison','tentative_deja_faite_aujourdhui'); END IF;
  -- Le bonus de corruption vaut pour LA prochaine tentative, réussie ou non.
  UPDATE public.sovarka_goulag_registre SET derniere_tentative = v_jour, corruption_bonus = false,
    evasion_le = CASE WHEN v_ok THEN now() ELSE NULL END
   WHERE detention_id = r.detention_id;
  IF v_ok THEN
    PERFORM public.sovarka_goulag_incident_interne('evasion:' || r.detention_id || ':' || v_jour,
      'evasion_reussie', p_nom, r.detention_id,
      jsonb_build_object('taux',v_taux,'corruption',r.corruption_bonus,'jours_restants',r.jours_restants));
    RETURN jsonb_build_object('ok',true,'reussi',true,'taux',v_taux,'jet',v_jet);
  END IF;
  v_cachot := public.sovarka_goulag_cachot_placer_interne(p_nom, r.detention_id, 2, 'evasion_echouee');
  IF coalesce((v_cachot->>'ok')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'goulag_cachot_impossible'; END IF;
  PERFORM public.sovarka_goulag_incident_interne('evasion:' || r.detention_id || ':' || v_jour,
    'evasion_echouee', p_nom, r.detention_id,
    jsonb_build_object('taux',v_taux,'corruption',r.corruption_bonus,'nuits',2));
  RETURN jsonb_build_object('ok',false,'raison','evasion_echouee','reussi',false,'taux',v_taux,
    'jet',v_jet,'cachot_nuits',(v_cachot->>'cachot_nuits')::integer,'room','cachot_disciplinaire',
    'jours_restants',r.jours_restants);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_sortie_jet_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;

DO $goulag_raccord_depart$
DECLARE source text; a_jet text; n_jet text; a_rest text; n_rest text;
BEGIN
  source := pg_get_functiondef('public.goulag_toundra_demarrer(text)'::regprocedure);
  IF strpos(source,'goulag_sortie_jet_20261117') > 0 THEN RETURN; END IF;
  -- 1. Jet de sortie, pour le seul détenu, avant tout gel de peine ou perte du dépôt.
  a_jet := E'    v_statut:=''detenu'';\n';
  n_jet := a_jet
    || E'    -- goulag_sortie_jet_20261117 : sortie du camp à 80 % (95 % après corruption), une fois par jour.\n'
    || E'    DECLARE v_sortie jsonb;\n'
    || E'    BEGIN\n'
    || E'      v_sortie := public.sovarka_goulag_sortie_jet_interne(v_nom, v_det.id);\n'
    || E'      IF coalesce((v_sortie->>''reussi'')::boolean,false) IS NOT TRUE THEN RETURN v_sortie; END IF;\n'
    || E'    END;\n';
  -- 2. Reliquat figé = jours que seul le sommeil purge (plus aucun décompte calendaire).
  a_rest := E'    -- Peine restante à l''instant exact : pas de comparaison avec la durée de marche.\n'
    || E'    -- Les peines historiques portent debutTs en millisecondes et jours en numérique.\n'
    || E'    IF coalesce(p.est_emprisonne->>''debutTs'','''') !~ ''^[0-9]+(\\.[0-9]+)?$''\n'
    || E'       OR coalesce(p.est_emprisonne->>''jours'','''') !~ ''^[0-9]+(\\.[0-9]+)?$'' THEN\n'
    || E'      RETURN jsonb_build_object(''ok'',false,''raison'',''peine_calendaire_invalide''); END IF;\n'
    || E'    v_debut:=(p.est_emprisonne->>''debutTs'')::numeric;\n'
    || E'    v_duree:=(p.est_emprisonne->>''jours'')::numeric;\n'
    || E'    v_fin:=v_debut+v_duree*86400000;\n'
    || E'    v_rest:=greatest(0,(v_fin-extract(epoch from clock_timestamp())*1000)/1000);\n';
  n_rest := E'    -- goulag_reliquat_sommeil_20261117 : seul le sommeil valide purge la peine du goulag.\n'
    || E'    SELECT r.jours_restants::numeric*86400 INTO v_rest FROM public.sovarka_goulag_registre r\n'
    || E'      WHERE r.detention_id=v_det.id;\n'
    || E'    v_rest:=coalesce(v_rest,0);\n';
  IF (length(source) - length(replace(source, a_jet, ''))) <> length(a_jet) THEN
    RAISE EXCEPTION 'goulag_depart_ancre_statut_absente'; END IF;
  IF (length(source) - length(replace(source, a_rest, ''))) <> length(a_rest) THEN
    RAISE EXCEPTION 'goulag_depart_ancre_reliquat_absente'; END IF;
  EXECUTE replace(replace(source, a_jet, n_jet), a_rest, n_rest);
  IF strpos(pg_get_functiondef('public.goulag_toundra_demarrer(text)'::regprocedure),
            'goulag_reliquat_sommeil_20261117') = 0 THEN
    RAISE EXCEPTION 'goulag_raccord_depart_non_applique'; END IF;
END $goulag_raccord_depart$;

DO $$ DECLARE r record; n bigint; h text; BEGIN
 IF public.sovarka_goulag_ouvert() IS DISTINCT FROM false THEN RAISE EXCEPTION 'ouverture_interdite'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.sovarka_goulag_configuration'::regclass
  AND conname='sovarka_goulag_activation_figee' AND convalidated) THEN RAISE EXCEPTION 'verrou_absent'; END IF;
 IF EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration WHERE active IS DISTINCT FROM false) THEN RAISE EXCEPTION 'activation_interdite'; END IF;
 FOR r IN SELECT * FROM hg_goulag_install_empreintes WHERE nom<>'routes_hors_raccord' LOOP
  EXECUTE format('SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),'''' ORDER BY md5(to_jsonb(x)::text)),'''')) FROM public.%I x',r.nom) INTO n,h;
  IF n<>r.nb OR h<>r.empreinte THEN RAISE EXCEPTION 'donnees_metier_modifiees:%',r.nom; END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind='r' AND c.relname LIKE 'sovarka_goulag_%' AND NOT c.relrowsecurity) THEN
  RAISE EXCEPTION 'rls_goulag_absente'; END IF;
END $$;
DO $$ DECLARE avant jsonb; attendu jsonb; actuel jsonb; n bigint; h text; r record; BEGIN
 SELECT valeur INTO STRICT avant FROM hg_goulag_routes_avant;
 attendu:=jsonb_set(avant,'{voisins}',CASE WHEN (avant->'voisins') ? 'krasnov-camp-bucherons'
  THEN avant->'voisins' ELSE (avant->'voisins')||'["krasnov-camp-bucherons"]'::jsonb END);
 attendu:=jsonb_set(attendu,'{directions}',jsonb_set(coalesce(avant->'directions','{}'::jsonb),'{liens}',
  coalesce(avant#>'{directions,liens}','{}'::jsonb)||'{"droite":"krasnov-camp-bucherons"}'::jsonb));
 SELECT to_jsonb(x) INTO STRICT actuel FROM public.rue_noeuds_serveur x
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-rue-ecole-foret';
 IF actuel IS DISTINCT FROM attendu THEN RAISE EXCEPTION 'raccord_ecole_non_conforme'; END IF;
 SELECT to_jsonb(x) INTO STRICT actuel FROM public.rue_noeuds_serveur x
  WHERE country='soviet' AND city='ville_b' AND noeud='krasnov-camp-bucherons';
 attendu:='{"country":"soviet","city":"ville_b","noeud":"krasnov-camp-bucherons","voisins":["krasnov-rue-ecole-foret"],"directions":{"liens":{"arriere":"krasnov-rue-ecole-foret"},"parArrivee":{}}}'::jsonb;
 IF actuel IS DISTINCT FROM attendu THEN RAISE EXCEPTION 'camp_non_conforme'; END IF;
 SELECT count(*),md5(coalesce(string_agg(md5(to_jsonb(x)::text),'' ORDER BY md5(to_jsonb(x)::text)),'')) INTO n,h
  FROM public.rue_noeuds_serveur x
  WHERE NOT(country='soviet' AND city='ville_b' AND noeud IN ('krasnov-rue-ecole-foret','krasnov-camp-bucherons'));
 SELECT * INTO STRICT r FROM hg_goulag_install_empreintes WHERE nom='routes_hors_raccord';
 IF n<>r.nb OR h<>r.empreinte THEN RAISE EXCEPTION 'autres_routes_modifiees'; END IF;
END $$;
