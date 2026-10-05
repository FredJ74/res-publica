-- =====================================================================
-- LOT 1.5.12 — RESTITUTION DES RELIQUATS A LA LIVRAISON D'UNE CONSTRUCTION
-- RPC transactionnelle : tout ou rien, et rejouable sans jamais payer deux fois
-- 7 septembre 2026
-- =====================================================================
-- ⚠️  NON EXECUTEE. Fournie pour relecture.
--
-- ORDRE DE DEPLOIEMENT IMPERATIF : ce fichier D'ABORD, le code ENSUITE.
-- Le cron est fail-closed : tant que la RPC n'existe pas, sbRpc renvoie null, les reliquats
-- restent marques « a restituer » sur le terrain et la tentative est simplement rejouee la nuit
-- suivante. Rien n'est perdu, rien n'est paye en double.
--
-- POURQUOI UNE RPC. La restitution touche TROIS tables : personnages (l'argent), objets_recus
-- (les materiaux, remis par le canal de reception automatique deja en place depuis le Lot 1.5.4)
-- et terrains_etat (le marqueur qui dit que c'est fait). Via l'API REST ce sont trois ecritures
-- separees : une panne entre deux laisserait un proprietaire paye sans marqueur -- donc repaye la
-- nuit suivante, soit des FR crees -- ou un marqueur pose sans paiement, soit des FR detruits. Le
-- cahier des charges interdit explicitement les deux. Meme doctrine qu'aux Lots 1.4 et 1.5.10 :
-- la RPC est l'autorite transactionnelle unique.
--
-- LES MONTANTS NE SONT JAMAIS FOURNIS PAR L'APPELANT. Ni la somme, ni les quantites ne sont des
-- parametres : la fonction les relit sous verrou dans terrains_etat.data.chantierAcheve.reliquats,
-- c'est-a-dire la ou le cron les a deposes en meme temps qu'il les retirait du chantier. Le cron
-- ne transmet qu'une intention : « restitue ce qui est du sur ce terrain, a ce beneficiaire ».
--
-- IDEMPOTENCE PAR CONSTRUCTION. Le drapeau restitue est lu et pose DANS LA MEME TRANSACTION que
-- les paiements. Un second appel -- cron rejoue, nuit suivante, appel manuel -- voit restitue=true
-- et ne fait rien du tout. Les lignes objets_recus portent en plus un identifiant deterministe et
-- un ON CONFLICT DO NOTHING : meme en cas d'appel concurrent, aucun lot ne peut etre remis deux
-- fois.
--
-- ORDRE DES VERROUS : personnages PUIS terrains_etat, exactement comme vendre_materiaux_chantier
-- (Lot 1.5.10). Deux fonctions qui verrouillent les memes tables dans le meme ordre ne peuvent pas
-- s'interbloquer. C'est la raison pour laquelle le beneficiaire est un PARAMETRE et non une valeur
-- lue d'abord dans le terrain : il faut pouvoir verrouiller personnages en premier. Sa legitimite
-- est verifiee ensuite contre le proprietaire reel du terrain, sous verrou.

CREATE OR REPLACE FUNCTION restituer_reliquats_chantier(
  p_beneficiaire text,
  p_terrain_id   text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pj         personnages%ROWTYPE;
  v_terrain    terrains_etat%ROWTYPE;
  v_data       jsonb;
  v_acheve     jsonb;
  v_reliquats  jsonb;
  v_materiaux  jsonb;
  v_montant    numeric;
  v_matiere    text;
  v_qte        integer;
  v_jour       text;
  v_remis      jsonb := '{}'::jsonb;
  v_libelle    text;
  v_icone      text;
BEGIN
  IF COALESCE(p_beneficiaire, '') = '' OR COALESCE(p_terrain_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM personnages WHERE name = p_beneficiaire FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_absent'); END IF;

  SELECT * INTO v_terrain FROM terrains_etat WHERE id = p_terrain_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'terrain_absent'); END IF;

  -- terrains_etat.data est une colonne TEXT contenant du JSON (meme convention qu'organisations).
  BEGIN
    v_data := v_terrain.data::jsonb;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_illisible');
  END;

  v_acheve := v_data -> 'chantierAcheve';
  IF v_acheve IS NULL OR jsonb_typeof(v_acheve) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_chantier_livre');
  END IF;

  v_reliquats := v_acheve -> 'reliquats';
  IF v_reliquats IS NULL OR jsonb_typeof(v_reliquats) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_reliquat');
  END IF;

  -- DEJA FAIT : reponse positive, aucune ecriture. C'est le cas normal d'un cron rejoue.
  IF COALESCE((v_reliquats ->> 'restitue')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true, 'deja_restitue', true, 'montant', 0);
  END IF;

  -- LE BENEFICIAIRE EST LE PROPRIETAIRE DES MURS AU MOMENT DE LA LIVRAISON, pas celui qui a lance
  -- ni finance le chantier. On verifie que le nom fourni est bien celui inscrit sur le terrain :
  -- s'il ne l'est pas, on ne paie personne et le cron rejouera avec le bon nom.
  IF COALESCE(v_data ->> 'proprietaire', '') <> p_beneficiaire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_incoherent');
  END IF;

  v_montant   := GREATEST(0, COALESCE((v_reliquats ->> 'tresorerie')::numeric, 0));
  v_materiaux := COALESCE(v_reliquats -> 'materiaux', '{}'::jsonb);
  v_jour      := COALESCE(v_acheve ->> 'jourLivraison', 'sansjour');

  -- 1. TRESORERIE. Rien n'est cree : cette somme a ete retiree du chantier par le meme traitement
  --    qui l'a inscrite ici, et elle n'y est plus disponible.
  IF v_montant > 0 THEN
    UPDATE personnages SET arg = COALESCE(arg, 0) + v_montant WHERE name = p_beneficiaire;
  END IF;

  -- 2. MATERIAUX, par le canal de reception AUTOMATIQUE (objets_recus). Ce canal est celui des
  --    objets qu'on n'a pas choisi de prendre : il ignore le plafond de 100 et fait passer son
  --    destinataire en Surcharge, exactement comme prevu au Lot 1.5.4. On n'ecrit surtout pas
  --    directement dans personnages.inventory : un client ouvert reecrit l'inventaire entier a sa
  --    prochaine sauvegarde et ecraserait l'ajout.
  --    L'identifiant est DETERMINISTE (terrain + jour de livraison + matiere) : un rejeu ne peut
  --    pas produire un second lot, meme si la transaction precedente avait echoue apres l'insert.
  FOR v_matiere IN SELECT unnest(ARRAY['bois', 'minerai', 'metal']) LOOP
    v_qte := GREATEST(0, floor(COALESCE((v_materiaux ->> v_matiere)::numeric, 0)))::integer;
    CONTINUE WHEN v_qte <= 0;
    -- Libelle et icone : simple habillage, repris de RESSOURCES_ECONOMIE (data.js). Aucune regle
    -- de jeu ne depend de ces deux chaines ; les quantites, elles, viennent du terrain verrouille.
    v_libelle := CASE v_matiere WHEN 'bois' THEN 'Bois' WHEN 'minerai' THEN 'Minerai' ELSE 'Métal' END;
    v_icone   := CASE v_matiere WHEN 'bois' THEN 'ti-trees' WHEN 'minerai' THEN 'ti-mountain' ELSE 'ti-bolt' END;
    -- Garde ecrite en SQL plutot qu'en ON CONFLICT : la definition d'objets_recus n'est pas
    -- versionnee dans le depot, on ne presume donc d'aucune contrainte d'unicite sur id. Le verrou
    -- deja pris sur terrains_etat serialise de toute facon deux appels concurrents.
    INSERT INTO objets_recus (id, destinataire, expediteur, data)
    SELECT 'reliquat-' || p_terrain_id || '-' || v_jour || '-' || v_matiere,
           p_beneficiaire,
           'Chef de Chantier',
           jsonb_build_object(
             'name', v_libelle, 'icon', v_icone,
             'stackable', true, 'stackKey', v_matiere, 'qty', v_qte,
             'desc', 'Matériaux restitués à la livraison du chantier.'
           )::text
    WHERE NOT EXISTS (
      SELECT 1 FROM objets_recus
      WHERE id = 'reliquat-' || p_terrain_id || '-' || v_jour || '-' || v_matiere
    );
    v_remis := jsonb_set(v_remis, ARRAY[v_matiere], to_jsonb(v_qte));
  END LOOP;

  -- 3. MARQUEUR, dans la MEME transaction que les deux paiements. C'est lui qui rend l'operation
  --    rejouable sans risque : tant qu'il n'est pas pose, rien n'a ete paye ; une fois pose, plus
  --    rien ne le sera.
  v_reliquats := jsonb_set(v_reliquats, '{restitue}', 'true'::jsonb);
  v_reliquats := jsonb_set(v_reliquats, '{dateRestitution}',
                   to_jsonb(to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')));
  v_acheve    := jsonb_set(v_acheve, '{reliquats}', v_reliquats);
  v_data      := jsonb_set(v_data, '{chantierAcheve}', v_acheve);

  UPDATE terrains_etat
    SET data = v_data::text,
        updated_at = now()
    WHERE id = p_terrain_id;

  RETURN jsonb_build_object('ok', true, 'deja_restitue', false,
                            'montant', v_montant, 'materiaux', v_remis,
                            'beneficiaire', p_beneficiaire);
END;
$$;

-- Droits d'execution : appelee par le cron, qui utilise la cle anon comme la plupart des RPC deja
-- en production. L'invariant n'est pas porte par l'appelant mais par la fonction elle-meme, qui
-- relit tout sous verrou, ne paie que ce que le terrain declare du, et ne le paie qu'une fois.
-- service_role est accorde pour que la meme fonction reste appelable depuis une identite serveur.
REVOKE ALL ON FUNCTION restituer_reliquats_chantier(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION restituer_reliquats_chantier(text, text) TO anon;
GRANT EXECUTE ON FUNCTION restituer_reliquats_chantier(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION restituer_reliquats_chantier(text, text) TO service_role;

-- CONTROLE POSTERIEUR — attendu : anon, authenticated, service_role (et le proprietaire).
SELECT grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_name = 'restituer_reliquats_chantier'
ORDER BY grantee;
