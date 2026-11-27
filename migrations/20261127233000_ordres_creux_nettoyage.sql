-- Mission du 27/11/2026 (soir, Claude), étape 3 — suppressions décidées par Fred le 27/11/2026.
--   • « Participer aux délibérations » (deliberer_loge) : supprimé ; la loge reste un lieu de rencontre RP.
--   • « Placements et optimisation fiscale » (compte_offshore) : doublon de « Gérer mes finances », supprimé.
--   • « Consulter la caisse » / « Consulter le stock » de la scierie : boutons masqués, supprimés.
-- Côté serveur, seules les lignes de ces ordres disparaissent (ordre générique et tarifs) : aucun autre ordre ne s'en sert.
-- « Blanchir des fonds » et « Créer une société écran » restent sans tarif (grisés « Bientôt disponible » à l'écran) ;
-- « Propagande d'État » garde son tarif (il sert encore aux ministères et à Sovarka) ; « Gestion du goulag » n'avait aucune
-- ligne serveur (le ministre garde l'autorisation et le retrait d'accès au goulag).
--
-- Contrôle en lecture après application :
--   SELECT count(*) FROM public.ordres_generiques WHERE fn = 'deliberer_loge';                                      -- 0
--   SELECT count(*) FROM public.ordres_couts WHERE fn IN ('deliberer_loge', 'compte_offshore',
--     'consulter_caisse_usine', 'consulter_stock_usine');                                                          -- 0
BEGIN;
DELETE FROM public.ordres_generiques WHERE fn = 'deliberer_loge';
DELETE FROM public.ordres_couts WHERE fn IN ('deliberer_loge', 'compte_offshore', 'consulter_caisse_usine', 'consulter_stock_usine');
COMMIT;
