-- ===========================================================================
-- NETTOYAGE DES CONTACTS DEVENUS ORPHELINS
-- 29 septembre 2026
-- ===========================================================================
--
-- Sergent Dubois et Soldat Martin sont retires de la caserne (data.js). Deux
-- figurants poses le 2 juin avec le batiment et jamais branches : aucune fiche
-- de dialogue, aucun ordre, aucune quete, aucune ligne metier en base.
--
-- Il en restait pourtant une trace : le carnet d'adresses d'un joueur. addContact
-- recopie nom/role/rel dans le contact, qui est donc AUTO-PORTANT -- aucun des
-- vingt sites de lecture de state.contacts ne rouvre BUILDINGS pour reconstituer
-- le PNJ. L'entree resterait donc affichee sans rien casser. C'est precisement
-- pour cela qu'on la retire : une donnee orpheline CONNUE, laissee en place,
-- devient un jour une enigme pour celui qui la retrouvera.
--
-- CIBLAGE STRICT. On ne nettoie pas « les contacts » : on retire deux entrees
-- nommees, et seulement elles. Tous les autres contacts du joueur -- y compris
-- l'Adjudant Ferriere, Eve Toahemarch ou le Caporal Lefebvre, qui existent
-- toujours -- sont conserves a l'identique. La clause WHERE finale garantit
-- qu'aucune ligne ne porte le sujet ne soit meme touchee.

update public.personnages_donnees
   set contacts = (
         select coalesce(jsonb_agg(c order by ord), '[]'::jsonb)
           from jsonb_array_elements(coalesce(contacts, '[]'::jsonb))
                with ordinality as t(c, ord)
          where coalesce(c->>'name', '') not in ('Sergent Dubois (PNJ)', 'Soldat Martin (PNJ)')
       ),
       updated_at = now()
 where contacts @> '[{"name": "Sergent Dubois (PNJ)"}]'::jsonb
    or contacts @> '[{"name": "Soldat Martin (PNJ)"}]'::jsonb;
