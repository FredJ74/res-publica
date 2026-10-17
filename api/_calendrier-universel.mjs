// Date civile commune à tous les personnages et empires.
// Aucun compteur individuel ni tranche glissante de 24 heures.
const FORMAT_JOUR = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit'
});

export function jourUniverselISO(instant = new Date()) {
  const p = Object.fromEntries(FORMAT_JOUR.formatToParts(instant).map(x => [x.type, x.value]));
  return p.year + '-' + p.month + '-' + p.day;
}

export function ajouterJoursCivils(jourISO, nombreJours) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(jourISO) || !Number.isSafeInteger(nombreJours)) {
    throw new TypeError('Date civile ou nombre de jours invalide');
  }
  const date = new Date(jourISO + 'T12:00:00Z');
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== jourISO) {
    throw new RangeError('Date civile invalide');
  }
  date.setUTCDate(date.getUTCDate() + nombreJours);
  return date.toISOString().slice(0, 10);
}

export function joursCivilsEcoules(debutISO, finISO) {
  const debut = ajouterJoursCivils(debutISO, 0);
  const fin = ajouterJoursCivils(finISO, 0);
  return Math.round((Date.parse(fin + 'T00:00:00Z') - Date.parse(debut + 'T00:00:00Z')) / 86400000);
}

export function echeanceJoursAtteinte(debutISO, nombreJours, maintenantISO) {
  return maintenantISO >= ajouterJoursCivils(debutISO, nombreJours);
}
