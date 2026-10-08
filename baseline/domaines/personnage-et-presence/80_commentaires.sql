-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine personnage et presence -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.escorts_catalogue.escort_id IS 'Identite stable. Ne se renomme jamais, ne se reutilise jamais : un emploi et une memoire en dependent.';
COMMENT ON COLUMN public.escorts_catalogue.pays IS 'Empire proprietaire du personnage. Une escort n''existe QUE dans son empire (regle de socle du 1er octobre 2026).';
COMMENT ON COLUMN public.personnages_donnees.user_id IS 'Compte auth.users proprietaire de ce personnage. NULL = personnage non rattache (heritage pre-authentification).';
COMMENT ON FUNCTION public.contact_organisation_choisir(text,text,jsonb) IS 'STRATEGIE DE SELECTION, isolee pour pouvoir changer seule : quelle organisation du type demande solliciter, en excluant celles deja contactees. Aujourd''hui la plus nombreuse -- non par equite, mais pour maximiser la chance d''une reponse humaine rapide. `p_joueur` est un point d''extension (proximite, reputation) que la strategie actuelle ignore volontairement. N''ecrit rien. Rend NULL s''il n''y a personne a solliciter, ce qui est un etat valide.';
COMMENT ON FUNCTION public.contact_organisation_demander(text,text) IS 'Un passeur envoie un message a l''organisation retenue par contact_organisation_choisir(), jamais encore sollicitee pour ce joueur. Aucun filtrage : tout joueur peut demander. N''A AUCUN PARAMETRE pour le projet du joueur, et c''est la garantie que rien n''en est conserve. Ne choisit pas l''organisation et ne la nomme pas dans sa reponse.';
COMMENT ON FUNCTION public.contact_organisation_etat(text,text) IS 'Ce passeur accepte-t-il une nouvelle demande de ce joueur, et depuis combien de temps ? Lecture seule, sous le jeton du joueur. N''autorise rien : le delai est retranche pour de vrai dans contact_organisation_demander().';
COMMENT ON FUNCTION public.employe_metiers_recrutables() IS 'Metiers que employe_recruter accepte encore. `escort` en a ete retire le 1er octobre 2026 : elle passe par escort_recruter(escort_id). Liste fermee : ajouter un metier ici l''ouvre au chemin generique.';
COMMENT ON FUNCTION public.escort_recruter(text) IS 'Engage une escort du catalogue de l''empire OU SE TROUVE le joueur. Aucun quota par genre : plusieurs escorts par joueur. L''identifiant d''emploi derive de (proprietaire, escort_id), donc deux joueurs peuvent employer la meme personne, et un meme joueur ne peut pas l''employer deux fois. Le libelle de role vient de escorts_agences, jamais d''un litteral.';
COMMENT ON FUNCTION public.escort_sociale_actuelle() IS 'Qui est la confidente du joueur connecte. Rend escort_id NULL s''il n''en a pas encore choisi -- etat normal, pas une erreur.';
COMMENT ON FUNCTION public.escort_sociale_choisir(text) IS 'Designe la confidente du joueur, une seule a la fois, dans l''empire ou il se trouve. Remplace la precedente sans effacer sa relation. Cree la relation vide si elle n''existe pas encore, pour qu''elle puisse croitre.';
COMMENT ON FUNCTION public.escorts_agence() IS 'Le casting d''escorts de l''empire OU SE TROUVE le joueur, et le nom de l''agence qui l''emploie. L''empire est resolu au serveur depuis la position du joueur, jamais transmis par le navigateur. Un empire sans casting rend une liste vide -- etat valide, pas une erreur.';
COMMENT ON FUNCTION public.personnage_pays_declare() IS 'Refuse un personnage dont le pays est absent, vide, ou absent du referentiel `villes`. Republia est le premier empire implemente, jamais le repli implicite de ce qu''on ne sait pas lire. La liste des empires n''est PAS recopiee ici : elle est lue dans villes, seul endroit ou elle vive.';
COMMENT ON FUNCTION public.referent_pedagogie_contexte(text) IS 'Combien de fois ce referent a deja explique des choses au joueur connecte, pour adapter son enseignement. Lecture seule, sous le jeton du joueur.';
COMMENT ON FUNCTION public.referent_pedagogie_noter(text) IS 'Note une consultation aboutie aupres d''un referent. Sans effet pour un PNJ qui n''est pas dans la liste fermee : aucune ligne n''est creee. Ne touche a aucune notion sociale.';
COMMENT ON TABLE public.contacts_organisations IS 'Etat d''une mise en relation : date de la derniere demande (porte le refus de trois jours) et organisations deja sollicitees (porte l''escalade vers la suivante). Ne contient AUCUNE donnee sur le projet du joueur -- la RPC qui ecrit ici n''a aucun parametre pour en recevoir.';
COMMENT ON TABLE public.contacts_organisations_passeurs IS 'Liste FERMEE des PNJ capables de mettre un joueur en relation avec une organisation, et avec quel type. Un passeur appartient a un empire : la regle de socle interdit de partager un personnage entre plusieurs empires.';
COMMENT ON TABLE public.escorts_agences IS 'Nom de l''agence d''escorts, UN PAR EMPIRE. Contenu, jamais mutualise : Sovarka n''aura pas la meme que Republia. Lu par l''ecran d''agence et par le libelle de role pose au recrutement.';
COMMENT ON TABLE public.escorts_catalogue IS 'Les identites d''escorts, une ligne par personnage et par empire. Source unique du nom, du genre et des deux images : plus aucun tirage aleatoire. `escort_id` est stable et porte le recrutement, la relation sociale et les jalons -- le nom affiche peut changer sans rien casser.';
