-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine finances publiques -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- subvention_citoyen_verser(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subvention_citoyen_verser(p_beneficiaire text, p_montant integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_pays text; v_caisse text; v_data jsonb;
  v_solde numeric; v_verse numeric; v_arg numeric;
BEGIN
  -- 1. AUTORITE. exiger_poste leve si le compte n'a pas de personnage ou n'est pas min_fin.
  v_acteur := public.exiger_poste('min_fin');
  IF v_acteur IS NULL THEN            -- appel serveur (cron) : pas de subvention automatique
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;
  IF coalesce(v_pays, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_indetermine');
  END IF;

  -- 2. MONTANT. Memes bornes que le formulaire : au moins 1, au plus 5000.
  IF p_montant IS NULL OR p_montant < 1 OR p_montant > 5000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  -- 3. BENEFICIAIRE. Il doit exister. La ligne est verrouillee avant tout mouvement.
  SELECT coalesce(arg, 0) INTO v_arg
    FROM public.personnages_donnees WHERE name = p_beneficiaire FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_introuvable');
  END IF;

  -- 4. CAISSE. Verrouillee elle aussi : le solde lu est celui qu'on debite.
  v_caisse := v_pays || '_gouvernement-min_fin';
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'verse', 0);
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data->'solde') = 'number'
                  THEN (v_data->>'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(v_solde, 0), p_montant);   -- versement partiel tolere, comme avant
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'verse', 0);
  END IF;

  -- 5. LES DEUX MOUVEMENTS, ENSEMBLE.
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = v_caisse;

  -- INCREMENT, jamais « solde relu + montant » : c'est ce calcul qui aurait ecrase la fortune.
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) + v_verse
   WHERE name = p_beneficiaire;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'beneficiaire', p_beneficiaire,
                            'acteur', v_acteur, 'caisse', v_caisse);
END; $function$;

-- subvention_entites(text) -> TABLE(id text, nom text, pays text, ville text) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subvention_entites(p_famille text)
 RETURNS TABLE(id text, nom text, pays text, ville text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- BRANCHE 1 SUR 3 POUR UNE NOUVELLE FAMILLE. L'absence de branche n'est pas un silence : une
  -- famille declaree eligible sans branche ici leve, et le trigger de `subventions_familles`
  -- interdit deja d'arriver dans cet etat.
  IF p_famille = 'club_football' THEN
    RETURN QUERY SELECT c.id, c.nom, c.pays, c.ville FROM public.clubs_football c;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM public.subventions_familles f
              WHERE f.famille = p_famille AND f.eligible) THEN
    RAISE EXCEPTION 'famille_sans_branche : % est declaree eligible mais n''a pas de branche '
      'd''enumeration -- etat impossible si le verrou de subventions_familles est en place',
      p_famille;
  END IF;
  RETURN;  -- famille non eligible : aucune entite, et c'est le comportement voulu
END $function$;

-- subvention_enveloppe_lire() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subvention_enveloppe_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_poste text; v_ville text; v_pays text;
  v_caisse text; v_solde numeric; v_reserve numeric; v_jour integer;
  v_part numeric; v_attente jsonb; v_eligibles jsonb;
BEGIN
  -- L'ENVELOPPE VUE PAR SON MAIRE. Reservee a lui : les propositions encore en attente ne sont
  -- pas publiques (seules les issues le sont, arbitrage §5), et le solde comme la reserve n'ont
  -- de sens que pour celui qui engage les fonds.
  SELECT a.nom, a.poste_id, coalesce(a.poste_city, ''), a.pays
    INTO v_moi, v_poste, v_ville, v_pays FROM public.acteur_poste_courant() a LIMIT 1;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'maire' OR v_ville = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', 'maire'); END IF;

  v_caisse := v_pays || '_subventions_' || v_ville;
  SELECT coalesce((b.data->>'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments b WHERE b.id = v_caisse;
  IF v_solde IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'enveloppe_absente', 'caisse', v_caisse); END IF;

  SELECT coalesce(sum(s.montant), 0) INTO v_reserve FROM public.subventions_municipales s
   WHERE s.pays = v_pays AND s.ville = v_ville AND s.statut = 'proposee';

  -- LA PART BUDGETAIRE DE L'ETAGE 1, pour que le maire voie d'un coup d'oeil ce qui alimente
  -- l'enveloppe et ce qu'il en reste.
  SELECT round(r.part_numerateur * 100 / r.part_denominateur, 4) INTO v_part
    FROM public.repartitions_budgetaires r
   WHERE r.pays = v_pays AND r.beneficiaire = 'subventions_' || v_ville
     AND r.part_numerateur IS NOT NULL;

  v_jour := public.jour_de_jeu_pays(v_pays);

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'beneficiaire', s.beneficiaire, 'beneficiaire_nom', s.beneficiaire_nom,
           'famille', s.famille, 'montant', s.montant, 'jour', s.jour,
           'jour_echeance', s.jour_echeance, 'jours_restants', s.jour_echeance - v_jour)
           ORDER BY s.created_at), '[]'::jsonb) INTO v_attente
    FROM public.subventions_municipales s
   WHERE s.pays = v_pays AND s.ville = v_ville AND s.statut = 'proposee';

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'famille', l.famille, 'libelle_famille', l.libelle_famille,
           'id', l.organisation_id, 'nom', l.nom, 'peut_repondre', l.caisse_connue)), '[]'::jsonb)
    INTO v_eligibles
    FROM public.subvention_organisations_locales(v_pays, v_ville) l;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'ville', v_ville, 'jour', v_jour,
    'caisse', v_caisse, 'solde', v_solde, 'reserve', v_reserve,
    'disponible', v_solde - v_reserve, 'part_budgetaire_pct', coalesce(v_part, 0),
    'en_attente', v_attente, 'eligibles', v_eligibles);
END $function$;

-- subvention_familles_resolues() -> SETOF text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.subvention_familles_resolues()
 RETURNS SETOF text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  -- LA LISTE DES FAMILLES QUE LE CODE SAIT TRAITER. Pour en ajouter une, il faut quatre gestes
  -- et pas un de moins : l'ajouter ICI, puis ecrire sa branche de domiciliation dans
  -- `subvention_organisations_locales`, sa branche de gestionnaire dans `subvention_gestionnaire`
  -- et sa branche de credit dans `subvention_caisse_crediter`. Tant que la cle n'est pas ici, le
  -- trigger de `subventions_familles` refuse de la declarer eligible.
  SELECT unnest(ARRAY['club_football']::text[]);
$function$;

-- subvention_gestionnaire(text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subvention_gestionnaire(p_famille text, p_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v text;
BEGIN
  -- BRANCHE 2 SUR 3. QUI PEUT REPONDRE POUR L'ORGANISATION -- et la reponse n'a PAS ete inventee
  -- ici : elle est lue dans l'existant. Pour un club du championnat, l'autorite sur la caisse est
  -- deja le PRESIDENT, et elle l'est partout ailleurs dans le jeu (`gerer_salaires_club` est
  -- « reserve au president »). Aucun grade n'est introduit, aucun titre n'est suppose commun a
  -- toutes les organisations : les `grades` des neuf familles sont des paliers d'anciennete, pas
  -- des fonctions, et aucune famille n'a de grade financier.
  --
  -- CE QUE CELA DONNE AUJOURD'HUI, ET IL FAUT LE DIRE : `presidents_clubs` est VIDE. Aucun club
  -- n'a de president, donc personne ne peut aujourd'hui accepter une subvention, et une
  -- proposition expirerait au bout de trois jours. Ce n'est pas un defaut de la mecanique, c'est
  -- l'etat du monde -- et la mecanique le rend visible au lieu de le masquer.
  --
  -- Le jour ou une famille d'ORGANISATION sera arbitree eligible, sa branche lira
  -- `organisations.data` selon la regle qui existe deja cote jeu : le tresorier s'il est pose,
  -- le chef sinon (arbitrage du 7 septembre 2026, `gestionnaireCaisseOrga`).
  IF p_famille = 'club_football' THEN
    SELECT nullif(trim(p.data->>'president'), '') INTO v
      FROM public.presidents_clubs p WHERE p.id = p_id;
    RETURN v;
  END IF;
  RETURN NULL;  -- pas de gestionnaire resolvable = personne ne peut repondre, fail-closed
END $function$;

-- subvention_organisations_locales(text,text) -> TABLE(famille text, libelle_famille text, organisation_id text, nom text, gestionnaire text, caisse_connue boolean) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subvention_organisations_locales(p_pays text, p_ville text)
 RETURNS TABLE(famille text, libelle_famille text, organisation_id text, nom text, gestionnaire text, caisse_connue boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- LES BENEFICIAIRES POSSIBLES D'UNE COMMUNE. Le navigateur ne choisit pas cette liste, il la
  -- recoit : l'eligibilite vient de la table, la domiciliation des colonnes du miroir, et le
  -- gestionnaire du resolveur. `gestionnaire` peut etre NULL -- l'interface doit alors dire que
  -- personne ne pourrait repondre, plutot que de laisser le maire engager 2 PA pour rien.
  SELECT f.famille, f.libelle, e.id, e.nom,
         public.subvention_gestionnaire(f.famille, e.id),
         public.subvention_gestionnaire(f.famille, e.id) IS NOT NULL
    FROM public.subventions_familles f
    CROSS JOIN LATERAL public.subvention_entites(f.famille) e
   WHERE f.eligible AND e.pays = p_pays AND e.ville = p_ville
   ORDER BY f.famille, e.nom;
$function$;

-- subvention_proposer(text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subvention_proposer(p_famille text, p_beneficiaire text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_poste text; v_ville text; v_pays text;
  v_caisse text; v_solde numeric; v_reserve numeric; v_dispo numeric;
  v_refus text; v_nom text; v_gest text; v_jour integer; v_id text;
  v_paie jsonb; v_n integer;
BEGIN
  -- 1. QUI PARLE, ET DE QUELLE COMMUNE. Lu au serveur, jamais recu du client.
  SELECT a.nom, a.poste_id, coalesce(a.poste_city, ''), a.pays
    INTO v_moi, v_poste, v_ville, v_pays
    FROM public.acteur_poste_courant() a LIMIT 1;
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'maire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', 'maire', 'poste_reel', v_poste); END IF;
  IF v_ville = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_indeterminee'); END IF;

  -- 2. LE MONTANT. Brut, entier, strictement positif. `trunc` refuse les centimes : les recettes
  -- municipales et toutes les caisses du jeu sont en francs entiers.
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide', 'montant', p_montant); END IF;

  -- 3. LE BENEFICIAIRE. Eligible ET domicilie dans MA commune -- un seul verdict, celui que
  -- l'interface a deja vu, pour qu'aucune divergence ne soit possible.
  v_refus := public.subvention_beneficiaire_verdict(v_pays, v_ville, p_famille, p_beneficiaire);
  IF v_refus IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', v_refus, 'famille', p_famille,
                              'beneficiaire', p_beneficiaire, 'ma_commune', v_ville); END IF;

  SELECT e.nom INTO v_nom FROM public.subvention_entites(p_famille) e WHERE e.id = p_beneficiaire;
  v_gest := public.subvention_gestionnaire(p_famille, p_beneficiaire);

  -- 4. L'ENVELOPPE, SOUS VERROU. Le FOR UPDATE serialise les propositions de cette commune.
  v_caisse := v_pays || '_subventions_' || v_ville;
  SELECT coalesce((b.data->>'solde')::numeric, 0) INTO v_solde
    FROM public.caisses_batiments b WHERE b.id = v_caisse FOR UPDATE;
  IF v_solde IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'enveloppe_absente', 'caisse', v_caisse); END IF;

  -- LA RESERVE EST CALCULEE, PAS STOCKEE : la somme des propositions encore en attente.
  SELECT coalesce(sum(s.montant), 0) INTO v_reserve FROM public.subventions_municipales s
   WHERE s.pays = v_pays AND s.ville = v_ville AND s.statut = 'proposee';
  v_dispo := v_solde - v_reserve;

  IF p_montant > v_dispo THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'solde', v_solde, 'reserve', v_reserve, 'disponible', v_dispo,
                              'demande', p_montant); END IF;

  -- 5. LA PROPOSITION. L'id est technique ; la cle LOGIQUE qui refuse le rejeu est portee par
  -- l'index unique partiel. ON CONFLICT DO NOTHING fait du rejeu un refus, pas une erreur.
  v_jour := public.jour_de_jeu_pays(v_pays);
  v_id := 'subv-' || gen_random_uuid()::text;

  INSERT INTO public.subventions_municipales
    (id, pays, ville, maire, famille, beneficiaire, beneficiaire_nom, montant, jour, jour_echeance)
  VALUES (v_id, v_pays, v_ville, v_moi, p_famille, p_beneficiaire,
          coalesce(v_nom, p_beneficiaire), p_montant, v_jour, v_jour + 3)
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_identique_en_attente',
                              'beneficiaire', p_beneficiaire, 'montant', p_montant); END IF;

  -- 6. LES 2 PA, EN DERNIER -- et le refus EFFACE la proposition avant d'etre rendu.
  v_paie := public.payer_ordre(v_moi, 'subvention_proposer', 2, 0);
  IF (v_paie->>'ok')::boolean IS NOT TRUE THEN
    DELETE FROM public.subventions_municipales WHERE id = v_id;
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison', 'paiement_refuse'),
                              'paiement', v_paie); END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'ville', v_ville,
    'beneficiaire', p_beneficiaire, 'beneficiaire_nom', coalesce(v_nom, p_beneficiaire),
    'montant', p_montant, 'jour', v_jour, 'jour_echeance', v_jour + 3,
    'solde', v_solde, 'reserve', v_reserve + p_montant, 'disponible', v_dispo - p_montant,
    'gestionnaire_connu', v_gest IS NOT NULL, 'paiement', v_paie);
END $function$;

-- subvention_repondre(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subvention_repondre(p_id text, p_reponse text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; r record; v_caisse text; v_jour integer; v_gest text;
  v_statut text; v_mvt jsonb; v_solde_orga numeric; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  -- LISTE CLOSE. Le client ne nomme pas le statut qu'il veut ecrire : il choisit un verbe parmi
  -- deux, et le serveur en deduit le statut. Un client modifie ne peut donc pas ecrire 'expiree'
  -- ni inventer une issue.
  IF p_reponse NOT IN ('accepter', 'refuser') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_invalide',
                              'attendu', jsonb_build_array('accepter', 'refuser')); END IF;
  v_statut := CASE p_reponse WHEN 'accepter' THEN 'acceptee' ELSE 'refusee' END;

  SELECT * INTO r FROM public.subventions_municipales WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_introuvable'); END IF;

  -- VERROU 1 : LA CAISSE, dans le meme ordre que la porte de proposition.
  v_caisse := r.pays || '_subventions_' || r.ville;
  PERFORM 1 FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;

  -- VERROU 2 : LA PROPOSITION.
  SELECT * INTO r FROM public.subventions_municipales WHERE id = p_id FOR UPDATE;
  IF r.statut <> 'proposee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_close', 'statut', r.statut,
                              'clos_par', r.clos_par, 'clos_le', r.clos_le); END IF;

  -- L'ECHEANCE, CONSTATEE ET APPLIQUEE. On ne refuse pas en laissant l'argent immobilise.
  v_jour := public.jour_de_jeu_pays(r.pays);
  IF v_jour >= r.jour_echeance THEN
    UPDATE public.subventions_municipales
       SET statut = 'expiree', clos_le = now()
     WHERE id = p_id AND statut = 'proposee';
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_echue',
                              'jour', v_jour, 'jour_echeance', r.jour_echeance,
                              'montant_libere', r.montant); END IF;

  -- QUI REPOND POUR L'ORGANISATION.
  v_gest := public.subvention_gestionnaire(r.famille, r.beneficiaire);
  IF v_gest IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_gestionnaire',
                              'beneficiaire', r.beneficiaire); END IF;
  IF v_gest IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_gestionnaire_caisse',
                              'beneficiaire', r.beneficiaire); END IF;

  -- LE COMPARE-AND-SWAP. Une seule transition peut gagner.
  UPDATE public.subventions_municipales
     SET statut = v_statut, clos_par = v_moi, clos_le = now()
   WHERE id = p_id AND statut = 'proposee';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'course_perdue'); END IF;

  -- UN REFUS NE DEPLACE RIEN. La reserve est liberee par le seul changement de statut : il n'y a
  -- aucune ecriture financiere a faire, donc aucune a rater.
  IF v_statut = 'refusee' THEN
    RETURN jsonb_build_object('ok', true, 'statut', 'refusee', 'id', p_id,
      'montant_libere', r.montant, 'beneficiaire', r.beneficiaire,
      'commune', r.ville, 'maire', r.maire); END IF;

  -- L'ACCEPTATION DEPLACE L'ARGENT, DANS LA MEME TRANSACTION QUE LA TRANSITION.
  --
  -- LE LAISSEZ-PASSER EST REFERME IMMEDIATEMENT. `set_config(..., true)` vaut pour toute la
  -- transaction, pas pour l'instruction : laisse ouvert, il autoriserait n'importe quel debit
  -- ulterieur de la meme transaction. Il est donc ferme des que l'ecriture est faite.
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_mvt := public.caisse_institution_mouvement(v_caisse, -r.montant, true);
  PERFORM set_config('rp.caisse_interne', '', true);

  -- UN DEBIT REFUSE ICI N'EST PAS UN REFUS METIER, C'EST UNE INCOHERENCE : la reserve garantit
  -- que l'enveloppe couvre le montant. On leve donc, pour que TOUTE la transaction soit annulee
  -- -- rendre un refus laisserait la proposition acceptee sans transfert, ce qui est pire.
  IF (v_mvt->>'ok')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'enveloppe_incoherente : le debit de % sur % a ete refuse (%) alors que la '
      'reserve le garantissait -- transaction annulee',
      r.montant, v_caisse, coalesce(v_mvt->>'raison', '?');
  END IF;

  v_solde_orga := public.subvention_caisse_crediter(
    r.famille, r.beneficiaire, r.montant, 'Subvention municipale', v_jour);

  RETURN jsonb_build_object('ok', true, 'statut', 'acceptee', 'id', p_id,
    'montant', r.montant, 'beneficiaire', r.beneficiaire,
    'beneficiaire_nom', r.beneficiaire_nom, 'commune', r.ville, 'maire', r.maire,
    'caisse_organisation', v_solde_orga);
END $function$;

-- subventions_expirer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subventions_expirer(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour integer; v_n integer := 0; v_total numeric := 0;
BEGIN
  v_jour := public.jour_de_jeu_pays(p_pays);
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'jour_indetermine', 'pays', p_pays); END IF;

  WITH closes AS (
    UPDATE public.subventions_municipales
       SET statut = 'expiree', clos_le = now()
     WHERE pays = p_pays AND statut = 'proposee' AND v_jour >= jour_echeance
    RETURNING montant)
  SELECT count(*), coalesce(sum(montant), 0) INTO v_n, v_total FROM closes;

  RETURN jsonb_build_object('ok', true, 'pays', p_pays, 'jour', v_jour,
                            'expirees', v_n, 'montant_libere', v_total);
END $function$;

-- subventions_famille_a_son_resolveur() -> trigger | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.subventions_famille_a_son_resolveur()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.eligible AND NOT EXISTS (
       SELECT 1 FROM public.subvention_familles_resolues() f(x) WHERE f.x = NEW.famille) THEN
    RAISE EXCEPTION 'famille_sans_resolveur : la famille % ne peut pas etre declaree eligible -- '
      'le code ne sait pas resoudre sa domiciliation, son gestionnaire de caisse ni son credit. '
      'Ajoutez-la d''abord a subvention_familles_resolues() et ecrivez ses trois branches.',
      NEW.famille;
  END IF;
  RETURN NEW;
END $function$;

-- subventions_recues_lire() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subventions_recues_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_recues jsonb;
BEGIN
  -- CE QUE JE PEUX ACCEPTER OU REFUSER. La question n'est pas « de quelle organisation suis-je
  -- membre » mais « pour laquelle suis-je GESTIONNAIRE DE CAISSE » -- et c'est le meme resolveur
  -- que la porte de reponse appliquera, donc l'interface ne peut pas montrer un bouton que la
  -- porte refuserait.
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'commune', s.ville, 'pays', s.pays, 'maire', s.maire,
           'famille', s.famille, 'beneficiaire', s.beneficiaire,
           'beneficiaire_nom', s.beneficiaire_nom, 'montant', s.montant,
           'jour', s.jour, 'jour_echeance', s.jour_echeance,
           'jours_restants', s.jour_echeance - public.jour_de_jeu_pays(s.pays))
           ORDER BY s.created_at), '[]'::jsonb) INTO v_recues
    FROM public.subventions_municipales s
   WHERE s.statut = 'proposee'
     AND public.subvention_gestionnaire(s.famille, s.beneficiaire) = v_moi;

  RETURN jsonb_build_object('ok', true, 'gestionnaire', v_moi, 'recues', v_recues);
END $function$;

-- taux_imposition_fixer(text,integer,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.taux_imposition_fixer(p_portee text, p_taux integer, p_fn text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste_requis text; v_cle_champ text; v_nom text; v_pays text; v_ville text;
  v_paie jsonb; v_n integer; v_cle text;
BEGIN
  IF p_portee = 'local' THEN
    v_poste_requis := 'maire'; v_cle_champ := 'tauxLocal';
  ELSIF p_portee = 'national' THEN
    v_poste_requis := 'min_fin'; v_cle_champ := 'tauxNational';
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'portee_inconnue');
  END IF;

  IF p_taux IS NULL OR p_taux < 0 OR p_taux > 40 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'taux_hors_bornes');
  END IF;

  -- L'AUTORITE ET LE TERRITOIRE VIENNENT DU POSTE REEL, JAMAIS DU CLIENT.
  SELECT a.nom, a.pays, a.poste_city INTO v_nom, v_pays, v_ville
    FROM public.acteur_poste_courant() a
   WHERE a.poste_id = v_poste_requis
   LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', v_poste_requis);
  END IF;
  IF p_portee = 'local' AND coalesce(btrim(coalesce(v_ville,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maire_sans_ville');
  END IF;

  -- LE PAIEMENT, DANS CETTE TRANSACTION. Son refus arrete tout ; son echec apres l'ecriture du
  -- taux est impossible puisqu'il la precede dans le meme BEGIN.
  v_paie := public.payer_ordre(v_nom, p_fn, coalesce(p_pa,0), coalesce(p_cost,0));
  IF NOT coalesce((v_paie->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison',
                              coalesce(v_paie->>'raison','paiement_refuse'),
                              'disponible', v_paie->'disponible');
  END IF;

  -- UNE SEULE CLE EST TOUCHEE : aucun autre champ du blob ne peut etre perdu.
  IF p_portee = 'local' THEN
    v_cle := v_pays || '_' || v_ville;
    UPDATE public.budgets_municipaux
       SET data = jsonb_set(coalesce(data, '{}'::jsonb), ARRAY[v_cle_champ],
                            to_jsonb(p_taux), true),
           updated_at = now()
     WHERE id = v_cle;
  ELSE
    v_cle := v_pays;
    UPDATE public.budgets_nationaux
       SET data = jsonb_set(coalesce(data, '{}'::jsonb), ARRAY[v_cle_champ],
                            to_jsonb(p_taux), true),
           updated_at = now()
     WHERE id = v_cle;
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    -- Le budget n'existe pas : on ne l'invente pas, et le paiement est annule avec le reste.
    RAISE EXCEPTION 'budget_introuvable:%', v_cle USING ERRCODE = 'no_data_found';
  END IF;

  RETURN jsonb_build_object('ok', true, 'portee', p_portee, 'taux', p_taux,
    'cle', v_cle, 'ville', v_ville, 'pays', v_pays,
    'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg',
    'solde_national', v_paie->'solde_national',
    'pa_preleves', v_paie->'pa_preleves', 'montant_preleve', v_paie->'montant_preleve');
EXCEPTION WHEN no_data_found THEN
  RETURN jsonb_build_object('ok', false, 'raison', 'budget_introuvable');
END; $function$;

-- taxe_fonciere_prelever(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.taxe_fonciere_prelever(p_terrain_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pays text; v_data jsonb; v_ville text; v_proprio text; v_budget jsonb;
  v_taux numeric; v_taxe numeric; v_valeur numeric; v_arg numeric; v_existe boolean;
  v_dette numeric; v_nouvelle numeric; v_ratio numeric; v_action text; v_rec jsonb;
BEGIN
  SELECT t.country, t.data::jsonb INTO v_pays, v_data
    FROM public.terrains_etat t WHERE t.id = p_terrain_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok',false,'action','terrain_introuvable'); END IF;
  v_ville   := coalesce(nullif(btrim(coalesce(v_data->>'city','')),''), 'capitale');
  v_proprio := nullif(btrim(coalesce(v_data->>'proprietaire','')),'');
  -- HORS ASSIETTE : pas de proprietaire ou pas de surface. Verifie AVANT la revendication, pour
  -- ne pas consommer la journee d'un terrain qu'on n'impose pas.
  IF v_proprio IS NULL OR (v_data->>'surface') IS NULL THEN
    RETURN jsonb_build_object('ok',false,'action','hors_assiette'); END IF;
  SELECT b.data INTO v_budget FROM public.budgets_municipaux b
   WHERE b.id = v_pays || '_' || v_ville;
  IF v_budget IS NULL THEN
    RETURN jsonb_build_object('ok',false,'action','budget_municipal_absent'); END IF;
  SELECT true, coalesce(arg,0) INTO v_existe, v_arg FROM public.personnages
   WHERE name = v_proprio FOR UPDATE;
  IF NOT coalesce(v_existe,false) THEN
    RETURN jsonb_build_object('ok',false,'action','proprietaire_introuvable'); END IF;

  -- LA REVENDICATION, par terrain et par jour, DANS cette transaction.
  IF NOT public.acte_nocturne_revendiquer(v_pays, 'taxe_fonciere', p_terrain_id,
         jsonb_build_object('ville', v_ville, 'proprietaire', v_proprio)) THEN
    RETURN jsonb_build_object('ok',false,'action','deja_prelevee_aujourdhui'); END IF;

  v_taux   := coalesce(nullif(v_budget->>'tauxFoncier','')::numeric, 0.05);
  v_taxe   := round(((v_data->>'surface')::numeric * v_taux)::numeric, 2);
  v_valeur := coalesce(nullif(v_data->>'valeur_totale','')::numeric,
                       (v_data->>'surface')::numeric * 12);

  IF v_arg >= v_taxe THEN
    UPDATE public.personnages SET arg = v_arg - v_taxe WHERE name = v_proprio;
    v_data := jsonb_set(v_data, '{dette_fonciere}', '0'::jsonb, true);
    v_action := 'collectee';
    -- LE CREDIT DE LA MAIRIE EST INSEPARABLE DU DEBIT. Si elle ne peut pas encaisser, on LEVE :
    -- le proprietaire n'est alors pas debite du tout.
    v_rec := public.recette_municipale(v_pays, v_ville, v_taxe, 'taxe_fonciere');
    IF NOT coalesce((v_rec->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'taxe_fonciere_prelever : la mairie de % n''a pas pu encaisser (%)',
            v_ville, coalesce(v_rec->>'raison','verdict_absent');
    END IF;
  ELSE
    v_dette    := coalesce(nullif(v_data->>'dette_fonciere','')::numeric, 0);
    v_nouvelle := v_dette + v_taxe;
    v_ratio    := CASE WHEN v_valeur > 0 THEN v_nouvelle / v_valeur ELSE 0 END;
    IF v_ratio >= 0.25 THEN
      v_data := v_data || jsonb_build_object('proprietaire', NULL, 'coproprietaire', NULL,
                  'enVenteParMairie', true, 'prixVenteMairie', round(v_valeur * 0.7),
                  'dette_fonciere', 0);
      v_action := 'saisie';
      INSERT INTO public.evenements_globaux (country, city, texte, jour)
      VALUES (v_pays, v_ville,
        '🏛️ SAISIE MUNICIPALE : un bien a été saisi pour non-paiement de la taxe foncière et sera remis en vente.',
        NULL);
    ELSE
      v_data := jsonb_set(v_data, '{dette_fonciere}',
        to_jsonb(CASE WHEN v_ratio >= 0.15 THEN round(v_nouvelle * 1.10) ELSE v_nouvelle END), true);
      v_action := 'avertissement';
    END IF;
  END IF;
  UPDATE public.terrains_etat SET data = v_data::text, updated_at = now() WHERE id = p_terrain_id;
  RETURN jsonb_build_object('ok',true,'action',v_action,'montant',v_taxe,
                            'ville',v_ville,'proprietaire',v_proprio);
END; $function$;

-- vente_structure_encaisser(text,integer,integer,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.vente_structure_encaisser(p_fn text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_caisse text DEFAULT NULL::text, p_ville text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_acteur text;
  v_pays text;
  v_ville text;
  v_taxable boolean;
  v_paye jsonb;
  v_taxe jsonb := NULL;
  v_net numeric;
  v_credit jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  v_taxable := CASE p_fn
    WHEN 'reserver_chambre_hotel' THEN true
    WHEN 'consommer_buvette'      THEN true
    WHEN 'faire_don'              THEN false
    ELSE NULL
  END;
  IF v_taxable IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vente_non_declaree', 'fn', p_fn);
  END IF;

  SELECT coalesce(pd.country, 'republic'),
         coalesce(nullif(btrim(coalesce(p_ville, '')), ''), pd.current_city, 'capitale')
    INTO v_pays, v_ville
    FROM public.personnages_donnees pd
   WHERE pd.name = v_acteur;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF coalesce(btrim(coalesce(p_caisse, '')), '') = ''
     OR p_caisse NOT LIKE v_pays || '\_%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_empire', 'caisse', p_caisse);
  END IF;

  v_paye := public.payer_ordre(v_acteur, p_fn, p_pa, p_cost);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RETURN v_paye;
  END IF;

  v_net := coalesce(p_cost, 0);
  IF v_taxable AND v_net > 0 THEN
    v_taxe := public.appliquer_taxe_transaction(v_pays, v_ville, v_net);
    v_net := coalesce((v_taxe->>'net')::numeric, v_net);
  END IF;

  IF v_net > 0 THEN
    v_credit := public.caisse_institution_mouvement(p_caisse, v_net, false);
    IF NOT coalesce((v_credit->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'vente_structure: credit impossible sur % (%)',
        p_caisse, coalesce(v_credit->>'raison', 'motif inconnu');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'pa', v_paye->'pa',
    'liquide', v_paye->'liquide',
    'arg', v_paye->'arg',
    'solde_national', v_paye->'solde_national',
    'pa_preleves', v_paye->'pa_preleves',
    'montant_preleve', v_paye->'montant_preleve',
    'net', v_net,
    'taxe', v_taxe,
    'caisse', p_caisse,
    'ville', v_ville);
END;
$function$;
