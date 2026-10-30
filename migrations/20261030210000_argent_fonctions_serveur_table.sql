-- =====================================================================================
-- ARGENT ÉCRIT PAR LES FONCTIONS SERVEUR : LA TABLE, PAS LA PORTE DE L'ÉCRAN (30/10/2026, Claude).
-- NON APPLIQUÉE. Application par ChatGPT après prévol. Compatible avec l'écran en ligne (aucun
-- contrat client modifié).
--
-- DÉFAUT (signalé par Fred : 150 000 FR empruntés chez Helvetia par Jean Jaaj, disparus au retrait
-- en liquide). Depuis `verrouiller_soldes_lors_sauvegarde_personnage` (14/10), la garde de la vue
-- `personnages` (personnages_vue_modifier) remet `arg` et `liquide` à leur valeur enregistrée pour
-- tout appel qui n'est pas du serveur : est_appel_serveur() regarde le rôle de la requête, qui reste
-- `authenticated` dans une fonction SECURITY DEFINER lancée par un joueur. Les fonctions ci-dessous
-- écrivaient l'argent PAR CETTE VUE : quand un joueur les déclenche, leurs crédits ET leurs débits
-- d'espèces ou de fortune sont silencieusement annulés, le reste de la transaction passe.
--   . retrait Helvetia en liquide : compte débité, espèces jamais créditées (cas de Jean Jaaj,
--     trace fiche_hausses_observees n° 1371) ; prêt Helvetia : fortune non créditée (n° 1370) ;
--   . dépôt et ouverture de compte Helvetia depuis les espèces : compte crédité, espèces jamais
--     débitées (création d'argent ; un seul compte Helvetia en production, aucun abus constaté) ;
--   . vente de matériaux de chantier : matériaux retirés, produit jamais versé ;
--   . Assemblée (dépenses du député, indemnité, solde militaire perçue) : débits et crédits annulés.
-- Les mêmes fonctions lancées par le cron (service_role) n'étaient pas touchées. Les neuf fonctions
-- de la passe de nuit qui écrivaient aussi l'argent par la vue passent à la même règle.
--
-- CORRECTIF. Précédent : prelever_loyer_bail (29/10). Ces fonctions serveur écrivent désormais la
-- table personnages_donnees. Patch en place : seule la cible des UPDATE change, chaque corps est
-- vérifié par son empreinte de production avant modification (refus si le texte a bougé).
-- Les anciennes portes à deux paramètres deposer_helvetia(text,numeric) et
-- retirer_helvetia(text,numeric), que l'écran n'appelle plus (il passe la source/destination),
-- sont retirées aux joueurs : la première permettait de créer de l'argent par le même défaut.
-- =====================================================================================
DO $migration$
DECLARE
  r record;
  d text;
  n text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.creer_pret_helvetia(text,numeric,integer)',                              '37f86e6e9f01eed02bdef23f44e17f8c'),
    ('public.fermer_compte_helvetia(text,text)',                                      'd5f33bb8f583238455cc9be8d1fd0c1f'),
    ('public.ouvrir_compte_helvetia(text)',                                           '066a5d34a72798900294675c6677d03c'),
    ('public.rembourser_pret_helvetia_integral(text,text,jsonb)',                     '33fb77998d878a4fe8be4dfbb73a82cc'),
    ('public.helvetia_crediter_destination(text,numeric,text)',                       '689ade4b40dc76b4f14a347a2d6dccc6'),
    ('public.helvetia_debiter_source(text,numeric,text)',                             'a2f2e2d5161edde4082fc2620082d878'),
    ('public.assemblee_crediter_joueur(text,integer)',                                'f6b050f1db9f4d8a82cfb1060d4d8dec'),
    ('public.assemblee_debiter_joueur(text,integer,integer)',                         'f5b03c64c215507809518855f726fd2a'),
    ('public.compromis_expire_resoudre(text,text)',                                   'ab003f202185ab1a8074fba1153e376a'),
    ('public.vendre_materiaux_chantier(text,text,text,text,integer,integer)',         '35f6f7a12a756e118e6c25ff032075f5'),
    -- Fonctions de la passe de nuit (service_role) : non touchées aujourd'hui, mais le même piège
    -- se refermerait le jour où un joueur les déclencherait. Une seule règle pour toutes.
    ('public.cotisation_renouveler(text,text,integer)',                               'e5a0366ba94b3c387baf911e70ae7f7b'),
    ('public.regler_creances_helvetia_quotidien(text)',                               'b0b0cf7d8b36a563fa3a07b4cf475c65'),
    ('public.resoudre_compromis_helvetia_expire(text)',                               '0a222d11bc2adfb8e2fd5349ad080174'),
    ('public.resoudre_placement_helvetia(text)',                                      'fb15c0a29344914ca918b23795304c37'),
    ('public.resoudre_placement_national(text,numeric)',                              '912a72c669e721eb8dbd50eb7978071d'),
    ('public.restituer_reliquats_chantier(text,text)',                                '17fbaf9f5c57464d21909617ce9a83ac'),
    ('public.succession_regler(text)',                                                'd9a7dadfac1e0fa61033d9f7741b4df8'),
    ('public.taxe_fonciere_prelever(text)',                                           'd42145292864a17d8254b50f9f840969'),
    ('public.traiter_prets_helvetia_quotidien()',                                     'b2bbd5cd3f17ac8ada786e62e7b0c357')
  ) AS t(sig, empreinte) LOOP
    d := pg_get_functiondef(r.sig::regprocedure);
    IF md5(d) <> r.empreinte THEN
      RAISE EXCEPTION '% : corps différent de celui relevé en production le 30/10 (md5 %)', r.sig, md5(d);
    END IF;
    -- \M (fin de mot) : « personnages_donnees » n'est jamais touché.
    n := regexp_replace(d, '\mupdate\s+(public\.)?personnages\M', 'UPDATE public.personnages_donnees', 'gi');
    IF n = d THEN RAISE EXCEPTION '% : aucune écriture par la vue trouvée', r.sig; END IF;
    EXECUTE n;
  END LOOP;

  -- Plus aucune écriture d'argent par la vue dans ces fonctions.
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
              AND p.proname IN ('creer_pret_helvetia','fermer_compte_helvetia','ouvrir_compte_helvetia',
                                'rembourser_pret_helvetia_integral','helvetia_crediter_destination',
                                'helvetia_debiter_source','assemblee_crediter_joueur','assemblee_debiter_joueur',
                                'compromis_expire_resoudre','vendre_materiaux_chantier','cotisation_renouveler',
                                'regler_creances_helvetia_quotidien','resoudre_compromis_helvetia_expire',
                                'resoudre_placement_helvetia','resoudre_placement_national','restituer_reliquats_chantier',
                                'succession_regler','taxe_fonciere_prelever','traiter_prets_helvetia_quotidien')
              AND p.prosrc ~* '\mupdate\s+(public\.)?personnages\M') THEN
    RAISE EXCEPTION 'écriture par la vue restante';
  END IF;
END $migration$;

REVOKE EXECUTE ON FUNCTION public.deposer_helvetia(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.retirer_helvetia(text, numeric) FROM PUBLIC, anon, authenticated;
