#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Correctif Bar de l'Hotel Republica :
1) Recruter un informateur -- refonte complete :
   - nouveau fn dedie 'recruter_informateur_pnj' (ne touche pas a l'ancien
     systeme 'recruter_info' / state.informateurs, utilise potentiellement
     ailleurs avec d'autres niveaux)
   - genere un PNJ qui rejoint le groupe (state.employes, inGroupe:true)
   - max 1 informateur a la fois
   - PER aleatoire 12-18, stockee sur le PNJ (utilisee plus tard par
     l'ordre "localiser" via la moyenne de PER du groupe)
   - toujours reussi (pas de jet)
   - salaire 150 FR/jour deja gere automatiquement par payerEmployes()
     (appelee dans doDormir()), rien a coder de ce cote
2) Ecouter le barman : la source de la rumeur etait toujours un PNJ
   generique aleatoire (jamais Marco). Ajout d'un champ sourceOverride
   sur l'ordre, lu par ecouterRumeurs().
"""
import sys

def apply_patch(path, old, new, label):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    count = content.count(old)
    if count == 0:
        print(f"[ECHEC] {label} : ancre introuvable dans {path}")
        return False
    if count > 1:
        print(f"[ECHEC] {label} : ancre trouvee {count} fois dans {path} (doit etre unique)")
        return False
    content = content.replace(old, new, 1)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[OK] {label}")
    return True

ok = True

# ------------------------------------------------------------------
# 1) plateau-multijoueur.js -- nouvelle fonction de recrutement
# ------------------------------------------------------------------
old_multi = """function getEmployes() {
  if (!state.employes) state.employes = [];
  return state.employes;
}"""

new_multi = """function getEmployes() {
  if (!state.employes) state.employes = [];
  return state.employes;
}

async function doRecruterInformateurPNJ() {
  if (!state.employes) state.employes = [];
  if (state.employes.some(e => e.job === 'informateur')) {
    showToast('Déjà en poste', 'Vous employez déjà un informateur. Renvoyez-le avant d\\'en recruter un autre.', false);
    return;
  }
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordre = room?.orders?.find(o => o.fn === 'recruter_informateur_pnj');
  const cout = ordre?.cost || 150;
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  if (state.arg < cout) {
    showToast('Fonds insuffisants', cout + ' ' + cur + ' requis pour la première journée.', false);
    return;
  }
  state.arg -= cout;

  const noms = ['Momo Fouine', 'Lucienne Indic', 'Bernard Filature', 'Rita Tuyau', 'Gaspard Renseigne', 'Nadège Oreille'];
  const nomPnj = noms[Math.floor(Math.random() * noms.length)] + ' (PNJ)';
  const perInformateur = Math.floor(Math.random() * 7) + 12; // 12 a 18

  state.employes.push({
    nom: nomPnj, role: 'Informateur', job: 'informateur',
    photoUrl: '', photoPos: '50% 15%',
    cout, inGroupe: true,
    buildingId: state.currentBuilding,
    roomId: state.currentRoom,
    city: state.currentCity,
    depuis: state.day || 1,
    stats: { PER: perInformateur }
  });

  updateUI();
  showToast('Informateur recruté !', nomPnj + ' rejoint votre groupe (PER ' + perInformateur + '). -' + cout + ' ' + cur + '.', true, true);
  addJournalEntry('Recrutement d\\'un informateur : ' + nomPnj + ' (PER ' + perInformateur + ', ' + cout + ' ' + cur + '/jour).', 'event-good');

  if (room) {
    if (!room.persons) room.persons = [];
    room.persons.unshift({
      name: nomPnj,
      role: 'Informateur recruté (lié à ' + (state.char?.name || 'vous') + ')',
      rel: 'ally',
      job: 'informateur'
    });
    if (typeof renderPersonsList === 'function') renderPersonsList(room.persons);
  }
}"""

ok &= apply_patch('plateau-multijoueur.js', old_multi, new_multi, "plateau-multijoueur.js - doRecruterInformateurPNJ")

# ------------------------------------------------------------------
# 2) plateau-router.js -- route la nouvelle fn
# ------------------------------------------------------------------
old_route = """  if (fn === 'diner_affaires') { ouvrirModalDinerAffaires(pa, cost, successRate); return; }"""
new_route = """  if (fn === 'diner_affaires') { ouvrirModalDinerAffaires(pa, cost, successRate); return; }
  if (fn === 'recruter_informateur_pnj') { doRecruterInformateurPNJ(); return; }"""
ok &= apply_patch('plateau-router.js', old_route, new_route, "plateau-router.js - route recruter_informateur_pnj")

# ------------------------------------------------------------------
# 3) data.js -- ordre du bar mis a jour
# ------------------------------------------------------------------
old_data_bar = """{fn:'recruter_info',   label:'Recruter un informateur N1',pa:1,cost:150, type:'grey',  icon:'ti-user-plus',successRate:75,  desc:'150 FR/jour. Localisation approximative, rumeurs locales.'},"""
new_data_bar = """{fn:'recruter_informateur_pnj', label:'Recruter un informateur', pa:1, cost:150, type:'grey', icon:'ti-user-plus', successRate:100, desc:'150 FR/jour. Un PNJ rejoint votre groupe en permanence tant que vous le payez. Sa PER (12-18) enrichit la moyenne de PER de votre groupe pour les futurs ordres de localisation.'},"""
ok &= apply_patch('data.js', old_data_bar, new_data_bar, "data.js - bar : recruter un informateur (refonte)")

# ------------------------------------------------------------------
# 4) data.js -- Ecouter le barman : source = Marco
# ------------------------------------------------------------------
old_data_ecoute = """{fn:'ecouter_rumeurs', label:'Ecouter le barman',     pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:90,  desc:'Le barman entend tout. Revele une rumeur vraie ou generee selon le contexte.'},"""
new_data_ecoute = """{fn:'ecouter_rumeurs', label:'Ecouter le barman',     pa:0, cost:0,   type:'grey',  icon:'ti-ear',      successRate:90,  desc:'Le barman entend tout. Revele une rumeur vraie ou generee selon le contexte.', sourceOverride:'Marco'},"""
ok &= apply_patch('data.js', old_data_ecoute, new_data_ecoute, "data.js - bar : Ecouter le barman -> source Marco")

# ------------------------------------------------------------------
# 5) plateau-actions-illegales-rumeurs.js -- ecouterRumeurs utilise sourceOverride
# ------------------------------------------------------------------
old_rumeurs = """async function ecouterRumeurs(successRate) {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const char = state.char;
  const pnjPresents = ['Le Commissaire', 'Un député', 'Un journaliste', 'Un commerçant', 'Un inconnu'];
  const source = pnjPresents[Math.floor(Math.random() * pnjPresents.length)];"""

new_rumeurs = """async function ecouterRumeurs(successRate) {
  const ville = WORLD[state.country]?.[state.currentCity]?.name || 'la ville';
  const char = state.char;
  const room = BUILDINGS[state.currentBuilding]?.rooms?.[state.currentRoom];
  const ordreEcoute = room?.orders?.find(o => o.fn === 'ecouter_rumeurs');
  const pnjPresents = ordreEcoute?.sourceOverride ? [ordreEcoute.sourceOverride] : ['Le Commissaire', 'Un député', 'Un journaliste', 'Un commerçant', 'Un inconnu'];
  const source = pnjPresents[Math.floor(Math.random() * pnjPresents.length)];"""

ok &= apply_patch('plateau-actions-illegales-rumeurs.js', old_rumeurs, new_rumeurs, "plateau-actions-illegales-rumeurs.js - ecouterRumeurs utilise sourceOverride")

print()
if ok:
    print("TOUT EST OK.")
else:
    print("ECHEC. Ne rien committer, colle le detail a Claude.")
    sys.exit(1)
