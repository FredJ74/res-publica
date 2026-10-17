-- NON DEPLOYEE. ACTIVATION INTERDITE tant que tous les circuits legacy ne sont pas raccordes.
-- Le refus leve une exception : aucune contrepartie SQL n'est conservee sans son mouvement.
BEGIN;
DO $registre_prive$
DECLARE r record;
BEGIN
 IF to_regclass('public.hg_fin_actes_en_cours') IS NOT NULL THEN
  IF obj_description(to_regclass('public.hg_fin_actes_en_cours'),'pg_class') IS DISTINCT FROM 'HG autorisation financiere transactionnelle v1'
   OR (SELECT relkind FROM pg_class WHERE oid=to_regclass('public.hg_fin_actes_en_cours'))<>'r'
   OR (SELECT count(*) FROM pg_attribute WHERE attrelid=to_regclass('public.hg_fin_actes_en_cours') AND attnum>0 AND NOT attisdropped)<>2 THEN
   RAISE EXCEPTION 'registre financier preexistant inconnu: hg_fin_actes_en_cours';
  END IF;
  FOR r IN SELECT * FROM (VALUES ('transaction_id','bigint'),('personnage','text')) t(col,typ) LOOP
   IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass('public.hg_fin_actes_en_cours') AND attname=r.col AND atttypid=to_regtype(r.typ) AND attnotnull AND NOT attisdropped) THEN
    RAISE EXCEPTION 'colonne de registre financier incompatible: %',r.col;
   END IF;
  END LOOP;
 END IF;
END;
$registre_prive$;
CREATE TABLE IF NOT EXISTS public.hg_fin_actes_en_cours (
 transaction_id bigint NOT NULL, personnage text NOT NULL,
 PRIMARY KEY(transaction_id,personnage)
);
COMMENT ON TABLE public.hg_fin_actes_en_cours IS 'HG autorisation financiere transactionnelle v1';
ALTER TABLE public.hg_fin_actes_en_cours ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.hg_fin_actes_en_cours FROM PUBLIC,anon,authenticated;
DO $droits_registre$
BEGIN
 IF has_table_privilege('authenticated','public.hg_fin_actes_en_cours','SELECT,INSERT,UPDATE,DELETE')
 OR has_any_column_privilege('authenticated','public.hg_fin_actes_en_cours','SELECT,INSERT,UPDATE')
 OR has_table_privilege('anon','public.hg_fin_actes_en_cours','SELECT,INSERT,UPDATE,DELETE') THEN
  RAISE EXCEPTION 'registre financier: droits clients residuels';
 END IF;
END;
$droits_registre$;
DO $garde$
DECLARE p pg_proc%rowtype;
BEGIN
 SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure('public.personnages_vue_modifier()');
 IF NOT FOUND OR md5(p.prosrc) NOT IN ('442089ea9dafd4a7f934d92752f30377','5058813fdfcb9c6c434c5877740ff87b')
 OR NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
  RAISE EXCEPTION 'sauvegarde: trigger serveur different de celui examine';
 END IF;
 IF EXISTS(SELECT 1 FROM information_schema.table_privileges WHERE table_schema='public'
  AND table_name='personnages_donnees' AND grantee IN ('PUBLIC','anon','authenticated')
  AND privilege_type IN ('UPDATE','INSERT','DELETE')) THEN
  RAISE EXCEPTION 'sauvegarde: droits directs sur le canon a examiner';
 END IF;
END;
$garde$;
CREATE OR REPLACE FUNCTION public.personnages_vue_modifier()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_canon public.personnages_donnees%rowtype;
  v_role  text := coalesce(nullif(current_setting('role', true), ''), session_user);
  v_req   text := left(coalesce(current_query(), ''), 500);
  v_verrou boolean;
  v_acte_financier boolean := false;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    IF auth.uid() IS NULL
       OR OLD.user_id IS NULL
       OR OLD.user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'personnage_non_possede' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_canon FROM public.personnages_donnees WHERE id = OLD.id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'personnage_introuvable' USING ERRCODE = '42501';
    END IF;

    -- L'autorisation est une ligne privee de la transaction SQL, pas un GUC
    -- falsifiable ni une valeur que le navigateur peut fournir.
    SELECT EXISTS(SELECT 1 FROM public.hg_fin_actes_en_cours
      WHERE transaction_id=txid_current() AND personnage=v_canon.name)
      INTO v_acte_financier;
    IF NOT v_acte_financier THEN
      IF (NEW.arg,NEW.liquide,NEW.banque) IS DISTINCT FROM (OLD.arg,OLD.liquide,OLD.banque) THEN
        RAISE EXCEPTION 'transaction_financiere_requise' USING ERRCODE='42501';
      END IF;
      -- Meme une vue lue AVANT l'attente d'un verrou reprend les soldes actuels.
      NEW.arg:=v_canon.arg;NEW.liquide:=v_canon.liquide;NEW.banque:=v_canon.banque;
    END IF;
    NEW.user_id := v_canon.user_id;

    IF coalesce(NEW.pa, 0) > coalesce(v_canon.pa, 0) THEN
      NEW.pa := v_canon.pa;
    END IF;

    NEW.stats             := v_canon.stats;
    NEW.free_pts_restants := v_canon.free_pts_restants;
    NEW.qualifications    := v_canon.qualifications;
    NEW.banque            := v_canon.banque;

    v_verrou := NOT v_acte_financier AND public.rp_transition_active('argent_verrou');

    IF coalesce(NEW.arg, 0) > coalesce(v_canon.arg, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'arg', v_canon.arg, NEW.arg, coalesce(NEW.arg,0) - coalesce(v_canon.arg,0), v_role, v_req);
      IF v_verrou THEN NEW.arg := v_canon.arg; END IF;
    END IF;
    IF coalesce(NEW.liquide, 0) > coalesce(v_canon.liquide, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'liquide', v_canon.liquide, NEW.liquide, coalesce(NEW.liquide,0) - coalesce(v_canon.liquide,0), v_role, v_req);
      IF v_verrou THEN NEW.liquide := v_canon.liquide; END IF;
    END IF;
    IF coalesce(NEW.hp, 0) > coalesce(v_canon.hp, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'hp', v_canon.hp, NEW.hp, coalesce(NEW.hp,0) - coalesce(v_canon.hp,0), v_role, v_req);
    END IF;
    IF coalesce(NEW.day, 0) > coalesce(v_canon.day, 0) THEN
      INSERT INTO public.fiche_hausses_observees (personnage, colonne, ancienne, nouvelle, delta, role_sql, requete)
      VALUES (v_canon.name, 'day', v_canon.day, NEW.day, coalesce(NEW.day,0) - coalesce(v_canon.day,0), v_role, v_req);
    END IF;

    NEW.arg       := coalesce(NEW.arg,       v_canon.arg);
    NEW.liquide   := coalesce(NEW.liquide,   v_canon.liquide);
    NEW.inventory := coalesce(NEW.inventory, v_canon.inventory);
  END IF;

  -- PLAFOND DU JOURNAL PERSONNEL : 500 ENTREES (24 septembre 2026, regle validee).
  -- Le journal est empile par la tete (unshift cote client) : on garde donc les 500
  -- PREMIERES, c'est-a-dire les plus recentes, et on abandonne les plus anciennes.
  -- Plafond de RETENTION, applique a toute ecriture, serveur comprise -- ce n'est pas un
  -- controle d'autorite. Aucune fiche reelle n'est concernee (120 entrees au maximum) :
  -- cette migration ne transforme aucune donnee existante.
  IF jsonb_typeof(NEW.journal) = 'array' AND jsonb_array_length(NEW.journal) > 500 THEN
    SELECT jsonb_agg(e ORDER BY ord) INTO NEW.journal
      FROM jsonb_array_elements(NEW.journal) WITH ORDINALITY AS t(e, ord) WHERE ord <= 500;
  END IF;

  UPDATE public.personnages_donnees SET
    name = NEW.name, country = NEW.country, photo_url = NEW.photo_url, bio = NEW.bio,
    archetype = NEW.archetype, career = NEW.career, origin = NEW.origin, school = NEW.school,
    free_pts_restants = NEW.free_pts_restants, stats = NEW.stats, resources = NEW.resources,
    arg = NEW.arg, liquide = NEW.liquide, banque = NEW.banque,
    hp = NEW.hp, pa = NEW.pa, moral = NEW.moral, poste = NEW.poste, poste_depute = NEW.poste_depute,
    current_city = NEW.current_city, current_building = NEW.current_building, current_room = NEW.current_room,
    inventory = NEW.inventory, informateurs = NEW.informateurs, contacts = NEW.contacts,
    historique_crimes = NEW.historique_crimes, enquetes_en_cours = NEW.enquetes_en_cours,
    domicile = NEW.domicile, employes = NEW.employes, escort_active = NEW.escort_active,
    locations_actives = NEW.locations_actives, poison_actif = NEW.poison_actif, day = NEW.day,
    recherche = NEW.recherche, reputation_criminelle = NEW.reputation_criminelle,
    salutations_du_jour = NEW.salutations_du_jour,
    invitation_sociale_en_attente = NEW.invitation_sociale_en_attente,
    convocations = NEW.convocations, est_emprisonne = NEW.est_emprisonne,
    detention_qhs = NEW.detention_qhs, hospitalisation = NEW.hospitalisation,
    stats_affaiblies = NEW.stats_affaiblies, regen_jour = NEW.regen_jour,
    requisition = NEW.requisition, demandeur_emploi = NEW.demandeur_emploi,
    carte_postale_moral_jour = NEW.carte_postale_moral_jour, motto = NEW.motto,
    licence_sportive = NEW.licence_sportive, performance_sportive = NEW.performance_sportive,
    blessure_sportive = NEW.blessure_sportive, signature_html = NEW.signature_html,
    signature_blocks = NEW.signature_blocks, quete_accueil = NEW.quete_accueil,
    enigme1 = NEW.enigme1, maxence = NEW.maxence, succes_maxence = NEW.succes_maxence,
    journal = NEW.journal, excommunie = NEW.excommunie, reservation_hotel = NEW.reservation_hotel,
    qualifications = NEW.qualifications, effets_actifs = NEW.effets_actifs,
    bonus_lobbyiste = NEW.bonus_lobbyiste, dernier_dormir = NEW.dernier_dormir,
    salaire_touche = NEW.salaire_touche, dernier_objet_trouve_jour = NEW.dernier_objet_trouve_jour,
    photo_pos = NEW.photo_pos, user_id = NEW.user_id, updated_at = NEW.updated_at,
    quete_carriere = NEW.quete_carriere
  WHERE id = OLD.id;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.personnages_vue_modifier() FROM PUBLIC,anon,authenticated;
COMMIT;
