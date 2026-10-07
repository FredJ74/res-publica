-- =============================================================================
-- CHANTIER 4E — LE SERVEUR APPREND CE QU'EST UNE VILLE, ET LES CAISSES SE FERMENT
-- 7 octobre 2026
--
-- APPLIQUEE le 8 octobre 2026. Inscrite au registre Supabase sous la version
-- 20261007150217 (le registre horodate a l'APPLICATION ; le nom de ce fichier garde
-- l'horodatage de sa redaction).
--
-- CE QUI A ETE VERIFIE APRES COUP. Les CINQ suppressions de caisses vestigiales ont ete
-- verifiees apres coup : aucune des cinq n'existe plus en base. Les douze villes sont semees, et
-- les trois empreintes du miroir concordent -- data.js, la sentinelle posee et
-- villes_empreinte_reelle() rendent toutes d41051aa8bcafadd.
--
-- UN DEFAUT DE CETTE MIGRATION, TROUVE PAR LA RELECTURE DU DIFF DU BASELINE ET CORRIGE A PART.
-- Ses quatre fonctions neuves -- villes_empreinte_reelle, ville_est_reelle, caisse_territoire
-- et caisse_refus_autorite -- declaraient `REVOKE ALL ... FROM PUBLIC, anon` puis
-- `GRANT ... TO service_role`, mais gardaient en base le GRANT EXECUTE nomme a
-- `authenticated` que l'ALTER DEFAULT PRIVILEGES de Supabase pose sur toute fonction neuve.
-- Ferme par 20261008020000_revoquer_authenticated_cinq_fonctions_serveur. Les REVOKE de ce
-- fichier-ci ont ete completes pour qu'une rejouee soit juste.
-- =============================================================================
--
-- CE QUE CETTE MIGRATION CORRIGE, mesure par mesure, sur la base reelle du
-- 7 octobre 2026 (151 caisses, 16 regles d'autorite).
--
-- 1. LE SERVEUR NE SAVAIT PAS CE QU'EST UNE VILLE. Aucune table ne portait les
--    douze couples (pays, ville) du jeu. caisse_ville_de() devinait la ville en
--    decoupant un identifiant, sans jamais pouvoir verifier que le morceau
--    obtenu etait une ville. C'est ainsi que `republic_mairie_caserne` se
--    resolvait en ville « caserne » -- or la caserne est une zone militaire
--    HORS des villes, elle ne releve d'aucune mairie, et une caisse municipale
--    de caserne n'a aucun sens.
--
-- 2. LE GARDE-FOU TERRITORIAL ETAIT DESARME SUR LA PLUS GROSSE CAISSE
--    MUNICIPALE DU JEU. caisse_ville_de() ne connaissait qu'un separateur, le
--    souligne (`mairie_ville_a`). La caisse de la mairie de la capitale, elle,
--    s'ecrit avec un TIRET (`republic_mairie-capitale`) -- cle historique
--    deliberement conservee pour ne pas orphaner son solde, documentee dans
--    plateau-justice-economie.js. La fonction rendait donc NULL, le controle de
--    ville etait saute, et le maire de Montrouge pouvait debiter la caisse de
--    Luthecia : 105 797 FR en Republia, 126 841 FR sur les quatre empires.
--
-- 3. L'ABSENCE DE REGLE VALAIT AUTORISATION. Les trois fonctions de mouvement
--    ecrivaient toutes `IF v_postes IS NOT NULL THEN <controler> END IF;`.
--    Quand caisse_postes_requis() ne trouvait aucune regle, elle rendait NULL,
--    et le controle etait simplement saute. 61 des 151 caisses sont dans ce
--    cas, pour 25 917 FR : n'importe quel joueur authentifie de l'empire
--    pouvait les vider. Mesure de l'historique complet de
--    caisses_mouvements_clients : 12 credits acceptes, 3 debits refuses, AUCUN
--    debit client jamais accepte. La faille n'a jamais ete exploitee -- elle
--    etait ouverte, c'est tout.
--
--    Desormais : absence de regle = REFUS. Jamais autorisation implicite.
--
-- 4. DEUX DES TROIS FONCTIONS N'AVAIENT AUCUN CONTROLE DE VILLE. Seule la
--    variante plafonnee comparait la ville du poste a celle de la caisse. Les
--    deux autres se contentaient du poste et du pays.
--
-- CE QUI N'EST PAS TOUCHE, ET POURQUOI
--
--   * AUCUN CHEMIN SERVEUR. Les trois blocs d'autorite sont, et restent,
--     enveloppes dans `rp.caisse_interne <> 'on' AND NOT est_appel_serveur()`.
--     Le cron, les 13 fonctions SECURITY DEFINER qui appellent ces primitives,
--     les salaires et le fret passent a cote du controle comme avant. Cette
--     migration ne resserre QUE le navigateur.
--   * AUCUN CREDIT. Les controles ne portent que sur les sorties d'argent
--     (`p_delta < 0` ou plafonne). Les 8 mouvements clients existants sur les
--     caisses sans regle sont tous des CREDITS : ils continuent de passer.
--   * AUCUN POSTE AUTORISE AJOUTE. caisses_autorites n'est pas modifiee. Les
--     chemins legitimes existants sont conserves a l'identique.
--   * LA CLE `mairie-capitale` N'EST PAS RENOMMEE. Renommer aurait deplace
--     126 841 FR et exige de retrouver tous ses lecteurs dans le navigateur ;
--     le resolveur accepte les deux separateurs, ce qui ne multiplie aucune
--     convention et ne touche aucun solde.
--
-- IDEMPOTENTE. Rejouable sans effet de bord.
-- AUCUN DROIT A PUBLIC NI A anon : chaque fonction creee ici est revoquee
-- explicitement de PUBLIC avant tout GRANT. PostgreSQL accorde EXECUTE a PUBLIC
-- par defaut sur toute fonction neuve, et un GRANT nominatif ne l'annule pas --
-- piege rencontre trois fois sur ce depot.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. LE REFERENTIEL DES VILLES
-- -----------------------------------------------------------------------------
-- Seme depuis VILLES (data.js) par outils/generateurs/generer_villes.py.
-- Empreinte du 7 octobre 2026 : d41051aa8bcafadd
--
-- LES ZONES HORS-VILLE N'Y SONT PAS : caserne et QHS existent dans WORLD comme
-- zones speciales, situees hors des villes et hors de toute mairie. Les semer
-- ici donnerait au serveur la preuve du contraire.

CREATE TABLE IF NOT EXISTS public.villes (
  pays         text    NOT NULL,
  ville        text    NOT NULL,
  nom          text    NOT NULL,
  est_capitale boolean NOT NULL DEFAULT false,
  rang         integer NOT NULL,
  PRIMARY KEY (pays, ville)
);

COMMENT ON TABLE public.villes IS
  'Les douze vraies villes du jeu, une ligne par couple (pays, ville). Miroir de VILLES (data.js), seme par outils/generateurs/generer_villes.py. Les zones hors-ville (caserne, QHS) en sont volontairement absentes : elles ne relevent d''aucune mairie.';

ALTER TABLE public.villes ENABLE ROW LEVEL SECURITY;
-- Aucune policy, aucun droit client : c'est un referentiel d'autorite, lu
-- uniquement par des fonctions SECURITY DEFINER. Meme regime que
-- caisses_autorites. Le navigateur a deja VILLES dans data.js.
--
-- LES TROIS REVOKE SONT NECESSAIRES (lecon du 7 octobre 2026, apprise sur
-- directions_etablissements). `FROM PUBLIC` ne retire QUE le droit de PUBLIC ;
-- Supabase accorde SELECT a `anon` et `authenticated` NOMMEMENT sur toute table
-- neuve du schema public, par ALTER DEFAULT PRIVILEGES. Sans les deux lignes
-- suivantes, cette table naitrait avec `anon=r` et `authenticated=r` -- inerte
-- tant qu'aucune policy n'existe, mais contredisant cette declaration.
REVOKE ALL ON TABLE public.villes FROM PUBLIC;
REVOKE ALL ON TABLE public.villes FROM anon;
REVOKE ALL ON TABLE public.villes FROM authenticated;

DELETE FROM public.villes;
INSERT INTO public.villes (pays, ville, nom, est_capitale, rang) VALUES
  ('khalija', 'capitale', 'Al Madina', true, 1),
  ('khalija', 'ville_a', 'Oasis City', false, 2),
  ('khalija', 'ville_b', 'Al-Petrol', false, 3),
  ('narco', 'capitale', 'Ciudad Roja', true, 1),
  ('narco', 'ville_a', 'Puerto Negro', false, 2),
  ('narco', 'ville_b', 'Villa Sangre', false, 3),
  ('republic', 'capitale', 'Luthécia', true, 1),
  ('republic', 'ville_a', 'Port-Sainte-Marie', false, 2),
  ('republic', 'ville_b', 'Montrouge', false, 3),
  ('soviet', 'capitale', 'Novomirsk', true, 1),
  ('soviet', 'ville_a', 'Starovka', false, 2),
  ('soviet', 'ville_b', 'Krasnov', false, 3);

-- -----------------------------------------------------------------------------
-- 2. L'EMPREINTE, pour que la derive soit visible
-- -----------------------------------------------------------------------------
-- Meme patron que les quatre miroirs deja surveilles (ordres_couts,
-- ressources_economie, pa_bonus_differes, postes_nommes_regles) : une table qui
-- porte l'empreinte POSEE le jour de la migration, et une fonction qui calcule
-- l'empreinte REELLE a la demande. Le controle confronte les trois valeurs --
-- data.js, posee, reelle.
--
-- COLLATE "C" EST OBLIGATOIRE. Python trie par point de code ; la collation par
-- defaut de la base ignore la ponctuation au poids primaire. Sans COLLATE "C",
-- `ville_a` et `ville_b` suffiraient a faire diverger les deux formules sur un
-- contenu identique.

CREATE TABLE IF NOT EXISTS public.villes_empreinte (
  seul      boolean PRIMARY KEY DEFAULT true CHECK (seul),
  empreinte text NOT NULL,
  pose_le   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.villes_empreinte ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS villes_empreinte_lecture_publique ON public.villes_empreinte;
CREATE POLICY villes_empreinte_lecture_publique ON public.villes_empreinte
  FOR SELECT USING (true);
REVOKE ALL ON TABLE public.villes_empreinte FROM PUBLIC;
GRANT SELECT ON TABLE public.villes_empreinte TO anon, authenticated;

INSERT INTO public.villes_empreinte (seul, empreinte, pose_le)
VALUES (true, 'd41051aa8bcafadd', now())
ON CONFLICT (seul) DO UPDATE SET empreinte = excluded.empreinte, pose_le = excluded.pose_le;

CREATE OR REPLACE FUNCTION public.villes_empreinte_reelle()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      pays || '|' || ville || '|' || nom
           || '|' || CASE WHEN est_capitale THEN '1' ELSE '0' END
           || '|' || rang::text,
      E'\n' ORDER BY pays COLLATE "C", ville COLLATE "C")), 16)
  FROM public.villes;
$function$;

REVOKE ALL ON FUNCTION public.villes_empreinte_reelle() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.villes_empreinte_reelle() TO service_role;

-- -----------------------------------------------------------------------------
-- 3. LA QUESTION « EST-CE UNE VRAIE VILLE ? »
-- -----------------------------------------------------------------------------
-- C'est la fonction que doit appeler tout code reserve aux villes. Elle refuse
-- caserne, QHS, les pseudo-villes techniques ('national', 'global'), les villes
-- de test ('zzville-cmr') et tout empire inconnu. Elle ne replie sur rien.

CREATE OR REPLACE FUNCTION public.ville_est_reelle(p_pays text, p_ville text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.villes v
                  WHERE v.pays = p_pays AND v.ville = p_ville);
$function$;

COMMENT ON FUNCTION public.ville_est_reelle(text, text) IS
  'Ce couple (pays, ville) designe-t-il une VRAIE ville ? Refuse les zones hors-ville (caserne, QHS), les pseudo-villes techniques et les empires inconnus. Ne replie jamais sur Republia ni sur la capitale.';

REVOKE ALL ON FUNCTION public.ville_est_reelle(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ville_est_reelle(text, text) TO service_role;

-- -----------------------------------------------------------------------------
-- 4. LA PORTEE TERRITORIALE D'UNE CAISSE — trois reponses, jamais deux
-- -----------------------------------------------------------------------------
-- LE DEFAUT DE FOND QUE CECI CORRIGE : caisse_ville_de() rendait NULL dans deux
-- situations qui n'ont rien a voir, et ses appelants ne pouvaient pas les
-- distinguer --
--
--   « cette caisse est NATIONALE, il n'y a pas de ville a verifier »
--   « cette caisse est MUNICIPALE mais je n'ai pas su dire laquelle »
--
-- et le garde-fou lisait les deux comme la premiere. Une caisse municipale dont
-- la ville ne se resolvait pas perdait donc tout controle territorial, au lieu
-- d'etre refusee. C'est le cas de `republic_mairie-capitale`.
--
-- caisse_territoire() rend donc une PORTEE explicite :
--
--   'national'     -- caisse nationale par construction : aucune ville a verifier
--   'ville'        -- caisse territoriale, et la ville est connue (2e colonne)
--   'indetermine'  -- on ne sait pas : c'est un REFUS, jamais un laissez-passer
--
-- COMMENT ELLE DECIDE, sans inventer aucune regle. Tout est deja declare dans
-- caisses_autorites :
--
--   a) `gouvernement-<poste>` : le segment qui suit est un POSTE, pas une ville.
--      caisse_postes_requis() le traite deja exactement ainsi.
--   b) une regle EXACTE (est_prefixe = false) nomme UNE caisse unique :
--      palais-presidentiel, reserve-nationale, assemblee, qhs-prison... Pas de
--      ville dans l'identifiant, donc nationale.
--   c) un motif de prefixe TERMINE PAR UN SEPARATEUR (`agence-`,
--      `gouvernement-`) nomme une famille dont le reste est une identite, pas
--      une ville. Ce tiret final est la declaration : il est dans la donnee.
--   d) tout autre motif de prefixe (`mairie`, `commissariat`, `tribunal`,
--      `entrepot`, `raffinerie`, `usine-pharma`, `pole-tabac-alcools`) est suivi
--      d'un separateur puis d'une VILLE, qui doit exister dans le referentiel.
--
-- LES DEUX SEPARATEURS SONT ACCEPTES, tiret comme souligne. Ce n'est pas une
-- tolerance : c'est la seule facon de couvrir la cle historique
-- `mairie-capitale` sans la renommer et sans ecrire d'exception nommee. Aucun
-- identifiant de caisse ne devient ambigu (verifie sur les 151).
--
-- VOLATILITE : caisse_ville_de etait IMMUTABLE. Elle lit desormais une table,
-- donc STABLE. Aucune de ses utilisations ne la place dans un index ni dans une
-- contrainte (verifie : son seul appelant etait
-- caisse_institution_mouvement_plafonne).

CREATE OR REPLACE FUNCTION public.caisse_territoire(p_caisse text, p_pays text)
RETURNS TABLE (portee text, ville text)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_suffixe text; r record; v_sep text; v_reste text;
BEGIN
  IF coalesce(btrim(p_caisse), '') = '' OR coalesce(btrim(p_pays), '') = '' THEN
    RETURN QUERY SELECT 'indetermine'::text, NULL::text; RETURN;
  END IF;

  v_suffixe := regexp_replace(p_caisse, '^' || p_pays || '_', '');

  -- (a) ministeres : le segment est un poste
  IF v_suffixe LIKE 'gouvernement-%' THEN
    RETURN QUERY SELECT 'national'::text, NULL::text; RETURN;
  END IF;

  SELECT * INTO r FROM public.caisses_autorites c
   WHERE (NOT c.est_prefixe AND c.motif = v_suffixe)
      OR (c.est_prefixe AND v_suffixe LIKE c.motif || '%')
   ORDER BY c.est_prefixe, length(c.motif) DESC
   LIMIT 1;

  -- Aucune regle : on ne sait rien de cette caisse, ni sa portee ni sa ville.
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'indetermine'::text, NULL::text; RETURN;
  END IF;

  -- (b) regle exacte : une caisse unique, nationale
  IF NOT r.est_prefixe THEN
    RETURN QUERY SELECT 'national'::text, NULL::text; RETURN;
  END IF;

  -- (c) famille dont le reste est une identite, pas une ville
  IF right(r.motif, 1) IN ('-', '_') THEN
    RETURN QUERY SELECT 'national'::text, NULL::text; RETURN;
  END IF;

  -- (d) le reste doit etre une ville, derriere un separateur. On decoupe par
  -- position et non par expression reguliere : un motif comme
  -- `pole-tabac-alcools` ne doit pas etre relu comme un motif de regex.
  v_sep   := substr(v_suffixe, length(r.motif) + 1, 1);
  v_reste := substr(v_suffixe, length(r.motif) + 2);
  IF v_sep NOT IN ('-', '_') OR coalesce(v_reste, '') = ''
     OR NOT public.ville_est_reelle(p_pays, v_reste) THEN
    RETURN QUERY SELECT 'indetermine'::text, NULL::text; RETURN;
  END IF;

  RETURN QUERY SELECT 'ville'::text, v_reste;
END;
$function$;

COMMENT ON FUNCTION public.caisse_territoire(text, text) IS
  'Portee territoriale d''une caisse : national (aucune ville a verifier), ville (territoriale, ville connue) ou indetermine (REFUS). Separe deliberement « nationale » de « ville inconnue », que l''ancien caisse_ville_de confondait en un seul NULL.';

REVOKE ALL ON FUNCTION public.caisse_territoire(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.caisse_territoire(text, text) TO service_role;

-- caisse_ville_de reste la question courte « quelle ville ? », et delegue.
-- Conservee parce que son nom est juste et qu'elle se lit bien au point d'appel ;
-- elle ne reimplemente plus rien.
CREATE OR REPLACE FUNCTION public.caisse_ville_de(p_caisse text, p_pays text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT t.ville FROM public.caisse_territoire(p_caisse, p_pays) t;
$function$;

COMMENT ON FUNCTION public.caisse_ville_de(text, text) IS
  'La VRAIE ville d''une caisse territoriale, ou NULL. ATTENTION : NULL ne dit pas « nationale » -- il dit seulement « pas de ville ». Pour decider d''une autorite, interroger caisse_territoire(), qui distingue national de indetermine.';

REVOKE ALL ON FUNCTION public.caisse_ville_de(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_ville_de(text, text) TO service_role;

-- -----------------------------------------------------------------------------
-- 5. LE VERDICT D'AUTORITE, ECRIT UNE FOIS POUR LES TROIS FONCTIONS
-- -----------------------------------------------------------------------------
-- Les trois primitives de mouvement portaient chacune sa propre copie du
-- raisonnement, et elles ne disaient pas la meme chose : deux ignoraient la
-- ville, la troisieme la verifiait. Ecrire le verdict une seule fois est la
-- seule facon d'empecher cette divergence de revenir.
--
-- Rend NULL quand l'acteur a l'autorite ; sinon le motif du refus, tel qu'il
-- doit etre journalise.

CREATE OR REPLACE FUNCTION public.caisse_refus_autorite(p_caisse text, p_pays text)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_postes text[]; v_portee text; v_ville text;
BEGIN
  SELECT t.portee, t.ville INTO v_portee, v_ville
    FROM public.caisse_territoire(p_caisse, p_pays) t;

  -- UNE CAISSE DONT ON NE SAIT RIEN NE S'OUVRE PAS. C'etait le fail-open :
  -- l'ancien code sautait le controle. 61 caisses sur 151 etaient dans ce cas.
  v_postes := public.caisse_postes_requis(p_caisse, p_pays);
  IF v_postes IS NULL THEN
    RETURN 'caisse_sans_regle_autorite';
  END IF;

  -- Regle declaree vide : reservee au serveur, aucun poste client ne l'ouvre.
  IF array_length(v_postes, 1) IS NULL THEN
    RETURN 'caisse_reservee_au_serveur';
  END IF;

  -- Une caisse territoriale dont la ville ne se resout pas garde son controle
  -- territorial : elle refuse. Elle ne devient PAS nationale.
  IF v_portee = 'indetermine' THEN
    RETURN 'caisse_territoire_indetermine';
  END IF;

  -- LE POSTE. Un poste national (poste_city NULL) ouvre une caisse de ville :
  -- c'est le chemin legitime du ministre, conserve tel quel. Un poste de ville
  -- n'ouvre que la caisse de SA ville.
  IF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                  WHERE a.poste_id = ANY (v_postes)
                    AND a.pays = p_pays
                    AND (v_portee <> 'ville' OR a.poste_city IS NULL
                         OR a.poste_city = v_ville)) THEN
    IF v_portee = 'ville' AND EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                                       WHERE a.poste_id = ANY (v_postes) AND a.pays = p_pays) THEN
      RETURN 'autorite_insuffisante_hors_ville';
    END IF;
    RETURN 'autorite_insuffisante';
  END IF;

  RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION public.caisse_refus_autorite(text, text) IS
  'Le verdict d''autorite sur une sortie d''argent d''une caisse, ecrit UNE fois pour les trois primitives de mouvement. Rend NULL si l''acteur a l''autorite, sinon le motif du refus. Absence de regle = REFUS (caisse_sans_regle_autorite), jamais autorisation implicite.';

REVOKE ALL ON FUNCTION public.caisse_refus_autorite(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.caisse_refus_autorite(text, text) TO service_role;

-- -----------------------------------------------------------------------------
-- 6. LES TROIS PRIMITIVES PASSENT AU FAIL-CLOSED
-- -----------------------------------------------------------------------------
-- Seul le bloc d'autorite change dans chacune. Le reste -- verrou FOR UPDATE,
-- test de solde, journalisation, plafonnement, valeurs de retour -- est repris
-- a l'identique, et l'enveloppe `rp.caisse_interne / est_appel_serveur()` reste
-- en place : aucun chemin serveur n'est touche.

CREATE OR REPLACE FUNCTION public.caisse_client_mouvement(p_caisse text, p_delta numeric, p_motif text DEFAULT NULL::text, p_plafonne boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_existe boolean; v_solde numeric; v_verse numeric;
  v_res jsonb; v_raison text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  IF coalesce(btrim(p_caisse),'') = '' OR p_delta IS NULL OR p_delta = 0
     OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF v_pays IS NULL OR p_caisse NOT LIKE v_pays || '\_%' THEN
    v_raison := 'caisse_hors_pays';
  ELSE
    SELECT true, (data->>'solde')::numeric INTO v_existe, v_solde
      FROM public.caisses_batiments WHERE id = p_caisse;
    IF NOT coalesce(v_existe, false) THEN
      v_raison := 'caisse_inexistante';
    ELSIF p_delta < 0 OR p_plafonne THEN
      -- SORTIE D'ARGENT PUBLIC : autorite exigee, et l'absence de regle est un
      -- refus. Le verdict est celui de caisse_refus_autorite, partage avec les
      -- deux primitives heritees.
      v_raison := public.caisse_refus_autorite(p_caisse, v_pays);
    END IF;
  END IF;

  IF v_raison IS NOT NULL THEN
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, p_delta, p_motif, false, v_raison);
    RETURN jsonb_build_object('ok', false, 'raison', v_raison);
  END IF;

  IF p_plafonne THEN
    v_verse := least(greatest(coalesce(v_solde,0), 0), abs(p_delta));
    IF v_verse <= 0 THEN
      INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
      VALUES (v_moi, p_caisse, p_delta, p_motif, false, 'solde_nul');
      RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', coalesce(v_solde,0));
    END IF;
    v_res := public.caisse_institution_mouvement(p_caisse, -v_verse, true);
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, -v_verse, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
    IF coalesce((v_res->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('ok', true, 'verse', v_verse,
        'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', v_res->>'raison', 'verse', 0);
  END IF;

  v_res := public.caisse_institution_mouvement(p_caisse, p_delta, true);
  INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
  VALUES (v_moi, p_caisse, p_delta, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
  IF coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true,
      'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
  END IF;
  RETURN v_res;
END;
$function$;

-- NOTE SUR L'APPEL IMBRIQUE : caisse_client_mouvement delegue l'ecriture a
-- caisse_institution_mouvement, qui refait le controle. Les deux rendent
-- desormais le MEME verdict, puisqu'elles appellent la meme fonction -- avant,
-- elles pouvaient differer. Le double controle est conserve : la primitive
-- heritee est appelable directement depuis un navigateur (droit `authenticated`
-- verifie sur pg_proc.proacl le 7 octobre 2026), elle doit donc se defendre
-- seule.

CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement(p_id text, p_delta numeric, p_exiger_existant boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data jsonb; v_solde numeric; v_existe boolean;
  v_moi text; v_pays text; v_client boolean; v_raison text;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_delta IS NULL OR p_delta = 0
     OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_client := coalesce(current_setting('rp.caisse_interne', true), '') <> 'on'
              AND NOT public.est_appel_serveur();

  IF p_delta < 0 AND v_client THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL OR p_id NOT LIKE v_pays || '\_%' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays');
    END IF;
    v_raison := public.caisse_refus_autorite(p_id, v_pays);
    IF v_raison IS NOT NULL THEN
      INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
      VALUES (v_moi, p_id, p_delta, 'primitive_heritee', false, v_raison);
      RETURN jsonb_build_object('ok', false, 'raison', v_raison);
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  v_existe := FOUND;
  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_solde := CASE WHEN v_existe AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  IF v_solde + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant');
  END IF;

  IF v_existe THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde + p_delta),
           updated_at = now()
     WHERE id = p_id;
  ELSE
    IF v_client THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_inexistante');
    END IF;
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (p_id, jsonb_build_object('solde', v_solde + p_delta), now());
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement_plafonne(p_id text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_data jsonb; v_solde numeric; v_verse numeric;
        v_moi text; v_pays text; v_raison text;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_montant IS NULL OR p_montant <= 0
     OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF coalesce(current_setting('rp.caisse_interne', true), '') <> 'on'
     AND NOT public.est_appel_serveur() THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL OR p_id NOT LIKE v_pays || '\_%' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays');
    END IF;
    v_raison := public.caisse_refus_autorite(p_id, v_pays);
    IF v_raison IS NOT NULL THEN
      INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
      VALUES (v_moi, p_id, -p_montant, 'primitive_heritee_plafonnee', false, v_raison);
      RETURN jsonb_build_object('ok', false, 'raison', v_raison, 'verse', 0);
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', 0);
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(v_solde, 0), p_montant);
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', v_solde);
  END IF;
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'solde', v_solde - v_verse);
END;
$function$;

-- Les droits des trois primitives sont ceux qu'elles avaient : CREATE OR REPLACE
-- ne les remet pas a zero. Reaffirmes ici pour que la migration dise, seule,
-- qui peut les appeler -- et pour qu'aucune ne reparte avec EXECUTE a PUBLIC.
REVOKE ALL ON FUNCTION public.caisse_client_mouvement(text, numeric, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_client_mouvement(text, numeric, text, boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_institution_mouvement(text, numeric, boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.caisse_institution_mouvement_plafonne(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.caisse_institution_mouvement_plafonne(text, numeric) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. LES CINQ CAISSES VESTIGIALES
-- -----------------------------------------------------------------------------
-- PREUVE AVANT SUPPRESSION. Les cinq lignes ci-dessous partagent le meme
-- defaut : un identifiant de caisse territoriale SANS ville valide. Mesure du
-- 7 octobre 2026, caisse par caisse :
--
--   republic_mairie_caserne       solde 0, 0 mouvement client, derniere ecriture
--                                 22 aout 2026. Ville resolue : « caserne » --
--                                 qui n'est pas une ville mais une zone
--                                 militaire hors des villes, ne relevant
--                                 d'aucune mairie. Aucun equivalent dans les
--                                 trois autres empires. Nee de getVillesReelles,
--                                 qui listait les villes en filtrant WORLD.
--   republic_commissariat         solde 0, 0 mouvement, 22 juillet 2026
--   republic_commissariat-local   solde 0, 0 mouvement, 15 aout 2026
--   republic_tribunal             solde 0, 0 mouvement, 22 juillet 2026
--   republic_tribunal-local       solde 0, 0 mouvement, 15 aout 2026
--
-- Les quatre dernieres sont les cles PARTAGEES d'avant le lot « caisses
-- locales » des 16-17 aout 2026, qui a donne a chaque ville sa caisse propre
-- (`commissariat_capitale`, `commissariat_ville_a`, ...). Elles sont
-- remplacees, documentees comme telles dans plateau-justice-economie.js, et
-- plus aucun chemin ne peut les produire : getCaisseLocaleId() suffixe toujours
-- une ville. Verifie aussi qu'aucune n'est referencee par salaires_caisses
-- (qui pointe sur `{pays}_<famille>_{ville}`) ni par dotations_amorcage_caisses.
--
-- Les lignes sont supprimees et non laissees a zero : conservees, elles
-- resteraient indefiniment refusees par le nouveau garde-fou, ce qui ferait
-- croire a un probleme d'autorite la ou il n'y a qu'un reste.
--
-- CE QUI N'EST PAS SUPPRIME : republic_commissariat_zzville-cmr (9 008 FR,
-- ecrite le 4 octobre 2026). C'est une caisse de TEST, dans une ville de test
-- absente du referentiel. Elle sera refusee aux clients comme
-- « caisse_territoire_indetermine », ce qui est correct, et elle n'est pas
-- touchee : effacer des donnees de test actives ne m'appartient pas.

DELETE FROM public.caisses_batiments
 WHERE id IN ('republic_mairie_caserne',
              'republic_commissariat', 'republic_commissariat-local',
              'republic_tribunal', 'republic_tribunal-local')
   AND coalesce((CASE WHEN jsonb_typeof(data->'solde') = 'number'
                      THEN (data->>'solde')::numeric ELSE 0 END), 0) = 0
   AND NOT EXISTS (SELECT 1 FROM public.caisses_mouvements_clients m
                    WHERE m.caisse = public.caisses_batiments.id);

COMMIT;
