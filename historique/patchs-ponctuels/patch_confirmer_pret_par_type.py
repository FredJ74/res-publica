#!/usr/bin/env python3
PATH = "plateau-justice-economie.js"
with open(PATH, "r", encoding="utf-8") as f:
    content = f.read()

old = """async function confirmerPretBancaire(typeBanque) {
  const montant = parseInt(document.getElementById('pret-montant')?.value || 0);
  const duree = parseInt(document.getElementById('pret-duree')?.value || 10);
  const cur = COUNTRIES[state.country]?.cur || 'FR';

  if (!montant || montant < 1000) { showToast('Montant invalide', 'Minimum 1000 ' + cur + '.', false); return; }

  const taux = getTauxPret(typeBanque);
  const montantTotal = Math.round(montant * (1 + taux / 100));
  const mensualite = Math.ceil(montantTotal / duree);

  const pret = {
    id: 'pret-' + Date.now(),
    emprunteur: state.char?.name || 'Anonyme',
    country: state.country,
    building_id: state.currentBuilding || 'non_specifie',
    type_banque: typeBanque || 'nationale',
    montant_initial: montant,
    montant_restant: montantTotal,
    duree_jours: duree,
    mensualite,
    jours_impayes: 0,
    jour_dernier_prelevement: state.day || 1,
    statut: 'en_cours'
  };

  if (typeof sbCreerPret === 'function') {
    await sbCreerPret(pret).catch(() => {});
  }

  state.arg = (state.arg || 0) + montant;
  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Prêt accordé !', '+' + montant.toLocaleString('fr-FR') + ' ' + cur + '. Mensualité : ' + mensualite.toLocaleString('fr-FR') + ' ' + cur + '/jour sur ' + duree + ' jours.', true, true);
  addJournalEntry('Prêt bancaire de ' + montant.toLocaleString('fr-FR') + ' ' + cur + ' contracté (taux ' + taux.toFixed(1) + '%) — ' + (typeBanque === 'privee' ? 'Banque Privée' : 'Banque Nationale') + '.', 'event-info');
}"""

new = """async function confirmerPretBancaire(typeBanque, typePret) {
  const montant = parseInt(document.getElementById('pret-montant')?.value || 0);
  const duree = parseInt(document.getElementById('pret-duree')?.value || 10);
  const cur = COUNTRIES[state.country]?.cur || 'FR';
  const infosType = TYPES_PRET[typePret] || TYPES_PRET.travaux;
  const estConso = typePret === 'consommation';

  if (!montant || montant < 1000) { showToast('Montant invalide', 'Minimum 1000 ' + cur + '.', false); return; }
  if (estConso && montant > infosType.montantMax) {
    showToast('Montant trop élevé', 'Le prêt consommation est plafonné à ' + infosType.montantMax.toLocaleString('fr-FR') + ' ' + cur + '.', false);
    return;
  }
  if (estConso && duree > infosType.dureeMax) {
    showToast('Durée trop longue', 'Le prêt consommation est plafonné à ' + infosType.dureeMax + ' jours.', false);
    return;
  }

  // Un seul pret actif PAR TYPE (pas une limite globale — Travaux et Consommation peuvent
  // coexister, mais pas deux Travaux en meme temps). Bug de spam remonte le 5 aout 2026.
  if (typeof sbGetPretsEnCours === 'function' && state.char?.name) {
    const pretsActifs = await sbGetPretsEnCours(state.char.name).catch(() => []);
    const dejaActif = (pretsActifs || []).some(p => (p.type_pret || 'travaux') === typePret);
    if (dejaActif) {
      showToast('Prêt refusé', 'Vous avez déjà un prêt ' + infosType.label.toLowerCase() + ' en cours. Soldez-le avant d\\'en contracter un nouveau.', false);
      return;
    }
  }

  const taux = estConso ? infosType.tauxFixe : getTauxPret(typeBanque);
  const montantTotal = Math.round(montant * (1 + taux / 100));
  const mensualite = Math.ceil(montantTotal / duree);

  const pret = {
    id: 'pret-' + Date.now(),
    emprunteur: state.char?.name || 'Anonyme',
    country: state.country,
    building_id: state.currentBuilding || 'non_specifie',
    type_banque: typeBanque || 'nationale',
    type_pret: typePret || 'travaux',
    montant_initial: montant,
    montant_restant: montantTotal,
    duree_jours: duree,
    mensualite,
    jours_impayes: 0,
    jour_dernier_prelevement: state.day || 1,
    statut: 'en_cours'
  };

  if (typeof sbCreerPret === 'function') {
    await sbCreerPret(pret).catch(() => {});
  }

  state.arg = (state.arg || 0) + montant;
  document.getElementById('modal-postes').classList.remove('open');
  updateUI();
  showToast('Prêt accordé !', '+' + montant.toLocaleString('fr-FR') + ' ' + cur + '. Mensualité : ' + mensualite.toLocaleString('fr-FR') + ' ' + cur + '/jour sur ' + duree + ' jours.', true, true);
  addJournalEntry('Prêt ' + infosType.label.toLowerCase() + ' de ' + montant.toLocaleString('fr-FR') + ' ' + cur + ' contracté (taux ' + taux.toFixed(1) + '%) — ' + (typeBanque === 'privee' ? 'Banque Privée' : 'Banque Nationale') + '.', 'event-info');
}"""

assert content.count(old) == 1, f"trouvé {content.count(old)} fois (attendu 1)"
content = content.replace(old, new)

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ confirmerPretBancaire mis à jour : plafonds conso, type_pret, limite par type (pas globale).")
