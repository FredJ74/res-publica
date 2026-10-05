-- ===========================================================================
-- PRESSE — LOT 0 : LES ROLES, ATTESTES (20 septembre 2026)
--
-- Applique en production le 20/09/2026 sous le nom presse_lot0_roles_attestes.
-- Ce fichier est le reflet fidele de ce qui a ete applique : le depot ne doit
-- pas diverger de la base (defaut constate sur redressement_fiscal_appliquer,
-- appliquee sans trace versionnee).
--
-- OBJET : sortir l'autorite de presse du blob organisations.data, qui ne peut
-- pas porter de droit serveur -- sa table est ouverte en ecriture a anon
-- (policy ALL/public/true) et 41 sites clients la reecrivent en entier.
--
-- PERIMETRE STRICT (lot 0) : groupes, membres, grades, recrutement,
-- nomination, designation volontaire, succession. Aucun journal, aucun
-- article, aucune tresorerie, aucun ecran. Les compteurs 5/15 ne sont PAS
-- fabriques ici : les parutions n'existent pas encore, seul le point
-- d'accrochage est pose (voir presse_nommer_redacteur_chef).
-- ===========================================================================

CREATE TABLE IF NOT EXISTS public.groupes_presse (
  id              text PRIMARY KEY,
  pays            text NOT NULL,
  nom             text NOT NULL,
  -- Lien INDICATIF vers l'organisation du blob. Volontairement sans cle
  -- etrangere : le blob n'est pas une source de verite, et une orga peut
  -- disparaitre par le DELETE dur de dissoudreOrga sans emporter le groupe.
  organisation_id text,
  cree_le         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.presse_membres (
  groupe_id    text NOT NULL REFERENCES public.groupes_presse(id) ON DELETE CASCADE,
  -- CONTRAINTE STRUCTURELLE : un membre est un personnage qui existe reellement.
  -- personnages_donnees.name est UNIQUE, la cle etrangere est donc possible et
  -- rend impossible l'introduction d'un membre au nom forge, meme cote serveur.
  personnage   text NOT NULL REFERENCES public.personnages_donnees(name)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  grade        text NOT NULL
               CHECK (grade IN ('correspondant','journaliste','redacteur_chef','directeur')),
  -- DEUX DATES DISTINCTES, la succession depend de la seconde :
  --   entre_le     = entree dans le GROUPE   (ne bouge jamais)
  --   grade_depuis = entree dans le GRADE courant (remise a now() a chaque changement)
  entre_le     timestamptz NOT NULL DEFAULT now(),
  grade_depuis timestamptz NOT NULL DEFAULT now(),
  -- DEPARTAGE DETERMINISTE. Deux nominations peuvent partager un timestamp ;
  -- l'ordre d'insertion tranche alors, pour qu'une succession ne soit jamais
  -- aleatoire. Jamais reecrit par les promotions.
  rang         bigserial NOT NULL,
  nomme_par    text,
  PRIMARY KEY (groupe_id, personnage)
);

-- UN SEUL DIRECTEUR PAR GROUPE, garanti par la base et non par le code.
CREATE UNIQUE INDEX IF NOT EXISTS presse_membres_un_seul_directeur
  ON public.presse_membres (groupe_id) WHERE grade = 'directeur';

CREATE INDEX IF NOT EXISTS presse_membres_par_personnage
  ON public.presse_membres (personnage);

-- --------------------------------------------------------------------------
-- FERMETURE. RLS active + lecture publique (un groupe de presse et sa
-- redaction sont des faits publics) + AUCUNE politique d'ecriture : toute
-- ecriture passe donc par les RPC SECURITY DEFINER ci-dessous.
-- Le REVOKE est indispensable : les DEFAULT PRIVILEGES du schema public
-- re-accordent tout a anon sur chaque nouvel objet.
-- --------------------------------------------------------------------------
ALTER TABLE public.groupes_presse  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presse_membres  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.groupes_presse  FROM anon, authenticated;
REVOKE ALL ON public.presse_membres  FROM anon, authenticated;
GRANT SELECT ON public.groupes_presse TO anon, authenticated;
GRANT SELECT ON public.presse_membres TO anon, authenticated;
REVOKE ALL ON SEQUENCE public.presse_membres_rang_seq FROM anon, authenticated;

DROP POLICY IF EXISTS groupes_presse_lecture ON public.groupes_presse;
CREATE POLICY groupes_presse_lecture ON public.groupes_presse
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS presse_membres_lecture ON public.presse_membres;
CREATE POLICY presse_membres_lecture ON public.presse_membres
  FOR SELECT TO anon, authenticated USING (true);

-- --------------------------------------------------------------------------
-- SUCCESSION — PROPRIETE DE LA TABLE, PAS D'UNE RPC.
--
-- Portee par un trigger AFTER DELETE plutot que par presse_quitter() : ainsi
-- TOUT retrait du directeur declenche la cascade, y compris la suppression en
-- cascade d'un personnage, et non le seul depart volontaire. Un chemin de
-- retrait ajoute plus tard ne pourra pas oublier la succession.
--
-- Ordre arbitre (GD du 20/09/2026) : redacteur_chef, puis journaliste, puis
-- correspondant ; a grade egal, le plus ancien DANS CE GRADE ; a egalite
-- exacte de timestamp, le rang d'entree.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.presse_succession_apres_depart()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_successeur text;
BEGIN
  IF OLD.grade <> 'directeur' THEN RETURN NULL; END IF;

  SELECT m.personnage INTO v_successeur
    FROM public.presse_membres m
   WHERE m.groupe_id = OLD.groupe_id
   ORDER BY CASE m.grade WHEN 'redacteur_chef' THEN 1
                         WHEN 'journaliste'    THEN 2
                         WHEN 'correspondant'  THEN 3
                         ELSE 9 END,
            m.grade_depuis ASC, m.rang ASC
   LIMIT 1;

  -- Dernier membre : le groupe reste sans directeur. Aucune donnee detruite,
  -- aucune regle inventee -- ce cas rejoindra le traitement general des
  -- organisations vides (arbitrage differe).
  IF v_successeur IS NULL THEN RETURN NULL; END IF;

  UPDATE public.presse_membres
     SET grade = 'directeur', grade_depuis = now(), nomme_par = '(succession)'
   WHERE groupe_id = OLD.groupe_id AND personnage = v_successeur;

  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_presse_succession ON public.presse_membres;
CREATE TRIGGER trg_presse_succession
  AFTER DELETE ON public.presse_membres
  FOR EACH ROW EXECUTE FUNCTION public.presse_succession_apres_depart();

-- --------------------------------------------------------------------------
-- FONDATION. Reservee au serveur : l'ecran de creation d'un groupe appartient
-- a un lot ulterieur, et exposer cette RPC au navigateur ouvrirait une
-- creation sans aucune condition de jeu.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.presse_groupe_fonder(
  p_groupe_id text, p_pays text, p_nom text, p_fondateur text, p_organisation_id text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF coalesce(btrim(p_groupe_id),'') = '' OR coalesce(btrim(p_pays),'') = ''
     OR coalesce(btrim(p_nom),'') = '' OR coalesce(btrim(p_fondateur),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF EXISTS (SELECT 1 FROM public.groupes_presse WHERE id = p_groupe_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'groupe_deja_existant');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_fondateur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fondateur_introuvable');
  END IF;

  INSERT INTO public.groupes_presse (id, pays, nom, organisation_id)
  VALUES (p_groupe_id, p_pays, p_nom, p_organisation_id);

  -- Le fondateur devient Directeur de Publication.
  INSERT INTO public.presse_membres (groupe_id, personnage, grade, nomme_par)
  VALUES (p_groupe_id, p_fondateur, 'directeur', '(fondation)');

  RETURN jsonb_build_object('ok', true, 'groupe', p_groupe_id, 'directeur', p_fondateur);
END;
$function$;

-- --------------------------------------------------------------------------
-- HELPER INTERNE : l'acteur est TOUJOURS relu, jamais annonce par le client.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.presse_acteur_directeur(p_groupe_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.presse_membres
                  WHERE groupe_id = p_groupe_id AND personnage = v_moi AND grade = 'directeur') THEN
    RETURN NULL;
  END IF;
  RETURN v_moi;
END;
$function$;

-- --------------------------------------------------------------------------
-- RECRUTEMENT — directeur du groupe VISE uniquement. Entree au grade
-- correspondant. Un Redacteur en chef ne peut pas faire entrer un pigiste.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.presse_recruter(p_groupe_id text, p_personnage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text;
BEGIN
  IF coalesce(btrim(p_groupe_id),'') = '' OR coalesce(btrim(p_personnage),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  v_directeur := public.presse_acteur_directeur(p_groupe_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;
  IF p_personnage = v_directeur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_membre');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_personnage) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF EXISTS (SELECT 1 FROM public.presse_membres
              WHERE groupe_id = p_groupe_id AND personnage = p_personnage) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_membre');
  END IF;

  INSERT INTO public.presse_membres (groupe_id, personnage, grade, nomme_par)
  VALUES (p_groupe_id, p_personnage, 'correspondant', v_directeur);

  RETURN jsonb_build_object('ok', true, 'grade', 'correspondant');
END;
$function$;

-- --------------------------------------------------------------------------
-- NOMINATION REDACTEUR EN CHEF — directeur seul, cible deja Journaliste.
--
-- L'ELIGIBILITE DES 15 OEUVRES N'EST PAS VERIFIEE ICI : les parutions
-- n'existent pas encore (lot articles). Le point d'accrochage est marque
-- ci-dessous ; aucun compteur n'est fabrique en attendant.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.presse_nommer_redacteur_chef(p_groupe_id text, p_personnage text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text; v_grade text;
BEGIN
  v_directeur := public.presse_acteur_directeur(p_groupe_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;

  SELECT grade INTO v_grade FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND personnage = p_personnage FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre_du_groupe');
  END IF;
  IF v_grade <> 'journaliste' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_source_invalide',
                              'grade_actuel', v_grade, 'requis', 'journaliste');
  END IF;

  -- >>> POINT D'ACCROCHAGE (lot articles) : exiger ici les 15 oeuvres publiees
  -- pendant l'appartenance au groupe, comptees en DISTINCT sur les parutions.

  UPDATE public.presse_membres
     SET grade = 'redacteur_chef', grade_depuis = now(), nomme_par = v_directeur
   WHERE groupe_id = p_groupe_id AND personnage = p_personnage;

  RETURN jsonb_build_object('ok', true, 'grade', 'redacteur_chef');
END;
$function$;

-- --------------------------------------------------------------------------
-- DESIGNATION VOLONTAIRE DU SUCCESSEUR — transfert immediat et atomique.
--
-- Ordre impose : on RETROGRADE d'abord, on PROMEUT ensuite, pour ne jamais
-- heurter l'index unique « un seul directeur ». Aucun etat intermediaire
-- n'est visible hors de la transaction.
--
-- LE JEU N'IMPOSE AUCUN GRADE AU DIRECTEUR SORTANT (arbitrage GD du
-- 20/09/2026, correctif applique sous le nom
-- presse_lot0_passation_grade_sortant_explicite). Ce sont des PJ : ils
-- s'organisent entre eux. Le grade repris est donc FOURNI EXPLICITEMENT a
-- l'action, sans valeur par defaut -- la signature l'exige, le serveur le
-- valide. 'directeur' est exclu de la liste : ce serait soit deux directeurs,
-- soit une passation qui n'en est pas une.
--
-- Le DROP ci-dessous retire la premiere version, a deux arguments, qui
-- portait la regle codee en dur : sans lui, l'ajout d'un parametre en aurait
-- fait une surcharge et l'ancienne serait restee appelable.
-- --------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.presse_designer_successeur(text, text);

CREATE OR REPLACE FUNCTION public.presse_designer_successeur(
  p_groupe_id text, p_personnage text, p_grade_sortant text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_directeur text;
BEGIN
  v_directeur := public.presse_acteur_directeur(p_groupe_id);
  IF v_directeur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_directeur');
  END IF;
  IF p_personnage = v_directeur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'successeur_identique');
  END IF;

  -- GRADE DU SORTANT : exige, valide, sans defaut. 'directeur' est exclu --
  -- ce serait soit deux directeurs, soit une passation qui n'en est pas une.
  IF p_grade_sortant IS NULL
     OR p_grade_sortant NOT IN ('correspondant','journaliste','redacteur_chef') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_sortant_invalide',
                              'recu', p_grade_sortant,
                              'valides', jsonb_build_array('correspondant','journaliste','redacteur_chef'));
  END IF;

  -- Verrou sur les deux lignes, dans un ordre stable, avant toute ecriture.
  PERFORM 1 FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND personnage IN (v_directeur, p_personnage)
   ORDER BY personnage FOR UPDATE;

  IF NOT EXISTS (SELECT 1 FROM public.presse_membres
                  WHERE groupe_id = p_groupe_id AND personnage = p_personnage) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre_du_groupe');
  END IF;

  -- On RETROGRADE d'abord, on PROMEUT ensuite : l'index unique « un seul
  -- directeur » n'est jamais heurte, et aucun etat intermediaire n'est
  -- visible hors de la transaction.
  UPDATE public.presse_membres
     SET grade = p_grade_sortant, grade_depuis = now(), nomme_par = '(passation)'
   WHERE groupe_id = p_groupe_id AND personnage = v_directeur;

  UPDATE public.presse_membres
     SET grade = 'directeur', grade_depuis = now(), nomme_par = v_directeur
   WHERE groupe_id = p_groupe_id AND personnage = p_personnage;

  RETURN jsonb_build_object('ok', true, 'directeur', p_personnage,
                            'ancien_directeur', v_directeur, 'grade_sortant', p_grade_sortant);
END;
$function$;

-- --------------------------------------------------------------------------
-- DEPART VOLONTAIRE. La succession n'est PAS ecrite ici : c'est le trigger
-- AFTER DELETE qui la porte, pour tout chemin de retrait.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.presse_quitter(p_groupe_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_grade text; v_successeur text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT grade INTO v_grade FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND personnage = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_membre_du_groupe');
  END IF;

  DELETE FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND personnage = v_moi;

  SELECT personnage INTO v_successeur FROM public.presse_membres
   WHERE groupe_id = p_groupe_id AND grade = 'directeur';

  RETURN jsonb_build_object('ok', true, 'grade_quitte', v_grade,
                            'nouveau_directeur', v_successeur,
                            'groupe_sans_directeur', (v_successeur IS NULL));
END;
$function$;

-- --------------------------------------------------------------------------
-- DROITS D'EXECUTION.
-- --------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.presse_groupe_fonder(text,text,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.presse_acteur_directeur(text)                  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.presse_succession_apres_depart()               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.presse_recruter(text,text)                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.presse_nommer_redacteur_chef(text,text)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.presse_designer_successeur(text,text,text)     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.presse_quitter(text)                           FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.presse_recruter(text,text)              TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.presse_nommer_redacteur_chef(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.presse_designer_successeur(text,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.presse_quitter(text)                    TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.presse_groupe_fonder(text,text,text,text,text) TO service_role;
