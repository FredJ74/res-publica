-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.detentions.provenance IS 'NULL = detention d''un PJ (comportement historique). Sinon, systeme PNJ proprietaire de l''etat de la cible, ex. agent_renseignement.';
COMMENT ON COLUMN public.infractions.libelle IS 'Le libelle que rend getPeineParActe. VINGT-TROIS des 39 infractions n''ont PAS de nom propre : elles heritent celui de leur categorie (« Delit mineur », « Crime »), parce que le canon n''en declare pas d''autre. Aucun nom n''a ete invente ici -- l''ecran du juge affiche donc l''identifiant a cote du libelle, et nommer ces 23 infractions est un arbitrage de game design ouvert.';
COMMENT ON FUNCTION public.detention_clore_evasion() IS 'Clot SA PROPRE detention par evasion : mode_fin = evasion, est_emprisonne vide, drapeau QHS
abaisse et ligne du registre du QHS liberee -- en une transaction. jour_fin n''est JAMAIS reecrit :
une evasion n''est pas une liberation. Rend les motifs d''origine, le pays et le reliquat, pour que
l''appelant construise l''avis de recherche. Verdicts : acteur_non_authentifie, non_detenu, puis ok.';
COMMENT ON FUNCTION public.detention_clore_interne(text,text,integer) IS 'MOTEUR de fin de detention : clot la ligne du registre avec son mode de fin, vide est_emprisonne,
abaisse le drapeau QHS en OBJET s''il etait leve et passe la ligne du registre du QHS a libere --
les quatre ecritures, en une transaction. AUCUNE precondition, AUCUN controle d''autorite : c''est
le role de ses cinq portes (detention_clore_purgee, detention_clore_evasion,
detention_reduire_peine, detention_clore_motif_eteint, presidence_gracier). Non appelable depuis
le reseau.';
COMMENT ON FUNCTION public.detention_clore_motif_eteint(text) IS 'Clot SA PROPRE detention quand son motif est administrativement eteint : « poursuites_eteintes »
(demobilisation) ou « incorporation » (transfert a la caserne). Ne libere que si la detention ne
tenait qu''a la desertion -- regle de jeu existante, qui n''etait verifiee que par le navigateur.
Verdicts : acteur_non_authentifie, non_detenu, peine_pas_seulement_desertion, puis ok avec mode.';
COMMENT ON FUNCTION public.detention_clore_purgee() IS 'Clot SA PROPRE peine quand elle est purgee : mode_fin = purgee, est_emprisonne vide, drapeau QHS
abaisse en OBJET et ligne du registre du QHS passee a libere -- en une transaction. Le jour de
reference vient de la fiche, jamais de l''appelant. Idempotente : rejouee, elle rend non_detenu.
Verdicts : acteur_non_authentifie, non_detenu, peine_non_purgee, puis ok.';
COMMENT ON FUNCTION public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb) IS 'PRIMITIVE d''incarceration : ouvre la ligne detentions et pose est_emprisonne dans la meme
transaction, refuse une cible deja detenue, et sait arreter un PNJ comme un PJ. AUCUN controle
d''autorite -- c''est le role de ses portes (justice_executer_condamnation, arrestation_urgence,
enquete_garde_a_vue, fraude_electorale_sanctionner, plainte_instruire_interne,
militaire_bataille_appliquer, detention_ouvrir_soi). p_extras porte les metadonnees judiciaires
optionnelles : ville_condamnation, jour_affaire, detention_precedente_id, reliquat_jours,
retour_ville. Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) IS 'S''incarcerer SOI-MEME : flagrant delit sur soi, placement au QHS, rebellion matee, sentence,
tracts calomnieux. L''identite, le pays et le jour viennent du serveur, jamais de l''appelant.
Verdicts : acteur_non_authentifie, duree_invalide, cible_deja_detenue, puis ok avec detention_id,
jour_debut et jour_fin.';
COMMENT ON FUNCTION public.detention_prolonger_interne(text,jsonb,boolean) IS 'MOTEUR de prolongation de peine : concatene les motifs sous verrou, repousse jour_fin, aligne
est_emprisonne, et pose le drapeau QHS si demande. N''a AUCUN controle d''autorite -- c''est le
role de ses portes : justice_prolonger_peine (un juge, sur un tiers) et detention_prolonger_soi
(le detenu, sur lui-meme). Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.detention_prolonger_soi(jsonb,boolean) IS 'Prolonge SA PROPRE peine : rebellion en cellule, placement au QHS. L''identite vient de
mon_personnage(), jamais d''un parametre. Verdicts : acteur_non_authentifie, motifs_absents,
cible_non_detenue, puis ok avec jours_ajoutes et jour_fin.';
COMMENT ON FUNCTION public.detention_qhs_poser_interne(text,text,text) IS 'SEUL ECRIVAIN du caractere QHS au moment de l''acte : pose detentions.qhs, est_emprisonne.qhs et
detention_qhs -- ce dernier en OBJET et non en chaine, forme que pa_repos_nocturne exige pour
appliquer le plafond de PA -- puis inscrit au registre du QHS une seule fois. Non appelable
depuis le reseau.';
COMMENT ON FUNCTION public.detention_reduire_peine(boolean) IS 'Applique la requete de l''avocat sur SA PROPRE peine, en une transaction : consomme l''avocat
(dans les deux cas, requete acceptee ou refusee), et si elle est acceptee reduit la peine de la
moitie du reliquat arrondie au superieur, en cloturant par anticipee_avocat si le terme est
atteint. Le MONTANT de la reduction est calcule ici, pas recu ; seul le resultat de la plaidoirie
vient de l''appelant, parce qu''il depend de valeurs qui vivent dans l''etat client. Verdicts :
acteur_non_authentifie, non_detenu, avocat_deja_utilise, peine_sans_terme, puis ok.';
COMMENT ON FUNCTION public.detention_transferer_qhs(text,integer,text,jsonb) IS 'Bascule SA PROPRE detention en cours vers le quartier de haute securite : clot l''ancienne ligne
par transfert_qhs, en ouvre une nouvelle qui la cite via detention_precedente_id, et pose le
drapeau QHS -- en une transaction. N''est PAS idempotente a dessein : un second appel est une
seconde rebellion, que le jeu permet. L''invariant tenu est qu''exactement une peine reste en
cours. Verdicts : acteur_non_authentifie, duree_invalide, non_detenu, puis ok.';
COMMENT ON FUNCTION public.infraction_canonique(text) IS 'Resout un identifiant d''infraction vers sa forme canonique, ou NULL. FAIL CLOSED : un identifiant inconnu rend NULL, et un nom de CATEGORIE rend NULL aussi -- on ne condamne pas pour « crime » en general. Les alias sont resolus d''abord.';
COMMENT ON FUNCTION public.infraction_peine_bornes(text) IS 'La peine de reference d''une infraction canonique et sa plage de modulation judiciaire : -50 % a +50 %, calcules au SERVEUR. `plancher_technique` vaut true quand la borne basse EGALE la reference -- cas des huit infractions a 1 jour, ou l''attenuation est inexprimable en jours entiers et ou le juge ne peut donc qu''aggraver. C''est un fait signale, pas un arbitrage rendu.';
COMMENT ON FUNCTION public.infractions_empreinte_reelle() IS 'L''empreinte du contenu COURANT du miroir des infractions, sur la meme chaine et le meme tri COLLATE "C" que outils/generateurs/generer_infractions.py. COLLATE "C" n''est pas decoratif : les identifiants portent des soulignes, que la collation par defaut ignore au poids primaire alors que Python trie par point de code.';
COMMENT ON FUNCTION public.justice_peine_calcul(text,text,text,text) IS 'LA formule de peine du serveur, unique : la plage autorisee pour une infraction canonique et un genre de sanction. Les deux portes du jugement -- celle qui propose au juge et celle qui enregistre -- l''appellent toutes les deux, donc elles ne peuvent pas diverger. Les genres qhs et torture rendent une plage reduite a un POINT : leur valeur est IMPOSEE par le serveur (30 jours, et 3 x (n+1) pour la torture), recopiee des regles validees et non derivee du catalogue.';
COMMENT ON FUNCTION public.justice_peine_proposer(text,text,text) IS 'Ce que le juge PEUT prononcer sur une affaire, pour son ecran : la plage reelle calculee par justice_peine_calcul, apres verification de la competence et de l''etat de l''affaire. Lecture seule. Elle rend aussi le motif ALLEGUE de la plainte, que la qualification du juge peut contredire sans l''effacer.';
COMMENT ON FUNCTION public.justice_rendre_sentence(text,text,text,integer,integer) IS 'La sentence, calculee et bornee AU SERVEUR. Elle ne recoit plus l''affaire mais son identifiant, et relit la ligne elle-meme : le blob client ne peut plus reecrire l''accuse, le motif ni la ville au moment du jugement. La peine est validee contre la plage du catalogue (-50 % / +50 %) par justice_peine_calcul, la meme formule que celle proposee a l''ecran. Le libelle de la peine est COMPOSE par le serveur, jamais recu. L''ancienne surcharge (jsonb, text) est supprimee, pas remplacee.';
COMMENT ON FUNCTION public.plainte_deposer(text,text) IS 'Depot d''une plainte, PAIEMENT COMPRIS et dans la meme transaction. Le cout est lu au miroir ordres_couts (fail closed : zero ou plusieurs declarations pour `plainte_police` et le depot est refuse), preleve par payer_ordre AVANT l''insertion. Un paiement refuse ne laisse aucun dossier -- c''etait le defaut : le navigateur creait le dossier puis tentait de payer, et continuait meme en cas de refus.';
COMMENT ON TABLE public.infractions IS 'Catalogue canonique des infractions, MIROIR de PEINES/PEINES_ACTES/ACTES_ILLEGAUX de plateau-core.js. La peine de reference de chaque ligne est exactement ce que getPeineParActe(id, false) rend cote navigateur : aucune valeur n''est decidee ici. Surveille par infractions_empreinte / infractions_empreinte_reelle().';
COMMENT ON TABLE public.infractions_alias IS 'Resolution des nomenclatures historiques vers un identifiant canonique. VIDE au 12 octobre 2026, et ce n''est pas un oubli : les trois paires de doublons relevees par l''inventaire portent des durees de reference DIFFERENTES de part et d''autre, donc les resoudre changerait une peine. Le mecanisme existe pour accueillir l''arbitrage ; il ne le prejuge pas.';
COMMENT ON TABLE public.infractions_categories IS 'Les quatre categories generiques de PEINES (plateau-core.js) : la peine HERITEE par les actes sans bareme propre. Une categorie est une CLASSE, jamais une charge -- infraction_canonique() refuse un nom de categorie comme qualification.';
COMMENT ON TABLE public.infractions_empreinte IS 'La sentinelle du miroir des infractions, meme patron que villes_empreinte : une seule ligne, l''empreinte POSEE a la derniere generation. infractions_empreinte_reelle() rend celle du contenu courant ; verifier-referentiels.py confronte les deux a celle que le generateur calcule depuis plateau-core.js.';
