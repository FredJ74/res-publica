// Comptes inactifs depuis 3 ans (Fred, 28/11/2026) — appelé par le traitement de nuit (api/cron-minuit.js).
// 1. Le serveur (comptes_inactifs_lister) désigne les comptes à avertir (3 ans moins 1 mois sans activité) et ceux à
//    supprimer (3 ans sans activité ET avertis depuis au moins 30 jours). Jamais un administrateur, jamais un compte de test.
// 2. L'e-mail d'avertissement part dans la langue du compte (celle de son dernier accord) ; il n'est noté
//    (comptes_inactifs_avertissement_noter) QUE s'il est réellement parti. Sans e-mail envoyé, pas de suppression.
// 3. La suppression (compte_inactif_supprimer) revérifie tout côté serveur : succession du personnage, forum signé
//    « Ancien joueur », compte effacé.
import { envoyerCourriel } from './_courriel.js';

const SITE = 'https://human-gambit.com';
const TEXTES = {
  fr: { sujet: 'Human Gambit : votre compte sera supprimé faute d’activité',
    corps: 'Bonjour,\n\nVotre compte Human Gambit{perso} n’a pas été utilisé depuis près de trois ans. Conformément à nos conditions d’utilisation, il sera supprimé le {date} : votre personnage disparaîtra par la succession habituelle et vos messages publics du forum resteront, signés « Ancien joueur ».\n\nPour garder votre compte, il suffit de vous connecter avant cette date : {site}\n\nPour toute question : contact@human-gambit.com', perso: ' (personnage : {nom})' },
  en: { sujet: 'Human Gambit: your account will be deleted for inactivity',
    corps: 'Hello,\n\nYour Human Gambit account{perso} has not been used for almost three years. In accordance with our terms of use, it will be deleted on {date}: your character will disappear through the usual succession and your public forum messages will remain, signed “Former player”.\n\nTo keep your account, simply sign in before that date: {site}\n\nAny question: contact@human-gambit.com', perso: ' (character: {nom})' },
  es: { sujet: 'Human Gambit: su cuenta será eliminada por inactividad',
    corps: 'Hola:\n\nSu cuenta de Human Gambit{perso} lleva casi tres años sin usarse. Conforme a nuestras condiciones de uso, será eliminada el {date}: su personaje desaparecerá mediante la sucesión habitual y sus mensajes públicos del foro se conservarán, firmados «Antiguo jugador».\n\nPara conservar su cuenta, basta con iniciar sesión antes de esa fecha: {site}\n\nPara cualquier pregunta: contact@human-gambit.com', perso: ' (personaje: {nom})' },
  de: { sujet: 'Human Gambit: Ihr Konto wird wegen Inaktivität gelöscht',
    corps: 'Hallo,\n\nIhr Human-Gambit-Konto{perso} wurde seit fast drei Jahren nicht genutzt. Gemäß unseren Nutzungsbedingungen wird es am {date} gelöscht: Ihre Figur verschwindet über die übliche Erbfolge, und Ihre öffentlichen Forumsbeiträge bleiben erhalten, unterzeichnet mit „Ehemaliger Spieler“.\n\nUm Ihr Konto zu behalten, melden Sie sich einfach vor diesem Datum an: {site}\n\nBei Fragen: contact@human-gambit.com', perso: ' (Figur: {nom})' },
  ru: { sujet: 'Human Gambit: ваш аккаунт будет удалён из-за неактивности',
    corps: 'Здравствуйте!\n\nВашим аккаунтом Human Gambit{perso} не пользовались почти три года. В соответствии с нашими условиями использования он будет удалён {date}: ваш персонаж исчезнет через обычное наследование, а ваши публичные сообщения на форуме останутся с подписью «Бывший игрок».\n\nЧтобы сохранить аккаунт, достаточно войти в игру до этой даты: {site}\n\nПо любым вопросам: contact@human-gambit.com', perso: ' (персонаж: {nom})' },
  ko: { sujet: 'Human Gambit: 장기 미사용으로 계정이 삭제될 예정입니다',
    corps: '안녕하세요.\n\nHuman Gambit 계정{perso}이(가) 약 3년 동안 사용되지 않았습니다. 이용 약관에 따라 {date}에 삭제됩니다. 캐릭터는 일반 상속 절차로 사라지며, 포럼의 공개 글은 「전 플레이어」 이름으로 남습니다.\n\n계정을 유지하려면 그 전에 로그인하기만 하면 됩니다: {site}\n\n문의: contact@human-gambit.com', perso: ' (캐릭터: {nom})' },
  ar: { sujet: 'Human Gambit: سيُحذف حسابك لعدم النشاط',
    corps: 'مرحبًا،\n\nلم يُستخدم حسابك في Human Gambit{perso} منذ نحو ثلاث سنوات. ووفقًا لشروط الاستخدام، سيُحذف في {date}: ستختفي شخصيتك عبر الإرث المعتاد، وتبقى رسائلك العامة في المنتدى بتوقيع «لاعب سابق».\n\nللاحتفاظ بحسابك، يكفي تسجيل الدخول قبل هذا التاريخ: {site}\n\nلأي سؤال: contact@human-gambit.com', perso: ' (الشخصية: {nom})' },
  'pt-BR': { sujet: 'Human Gambit: sua conta será excluída por inatividade',
    corps: 'Olá,\n\nSua conta do Human Gambit{perso} não é usada há quase três anos. Conforme nossos termos de uso, ela será excluída em {date}: seu personagem desaparecerá pela sucessão habitual e suas mensagens públicas no fórum continuarão, assinadas “Ex-jogador”.\n\nPara manter sua conta, basta entrar antes dessa data: {site}\n\nDúvidas: contact@human-gambit.com', perso: ' (personagem: {nom})' },
  'zh-TW': { sujet: 'Human Gambit：您的帳號將因長期未使用而刪除',
    corps: '您好：\n\n您的 Human Gambit 帳號{perso}已將近三年未使用。依據使用條款，帳號將於 {date} 刪除：您的角色將依一般繼承程序消失，您在論壇的公開訊息仍會保留，署名為「前玩家」。\n\n若要保留帳號，只需在該日期前登入：{site}\n\n如有任何問題：contact@human-gambit.com', perso: '（角色：{nom}）' }
};

export function texteAvertissement(langue, personnage, dateSuppression) {
  const t = TEXTES[langue] || TEXTES.fr;
  let date = String(dateSuppression || '').slice(0, 10);
  try { date = new Date(dateSuppression).toLocaleDateString(TEXTES[langue] ? langue : 'fr', { timeZone: 'Europe/Paris' }); } catch (_) {}
  const perso = personnage ? t.perso.replace('{nom}', personnage) : '';
  return { sujet: t.sujet, texte: t.corps.replace('{perso}', perso).replace('{date}', date).replace('{site}', SITE) };
}

// rpc(fn, params) -> verdict (clé de service) ; envoyer({a, sujet, texte}) -> { ok }.
export async function traiterComptesInactifs({ rpc, envoyer = envoyerCourriel, limite = 50 } = {}) {
  const bilan = { ok: true, avertis: 0, avertissements_non_envoyes: 0, supprimes: 0, echecs: [] };
  const brut = await rpc('comptes_inactifs_lister', { p_limite: limite });
  const liste = Array.isArray(brut) ? brut[0] : brut;
  if (!liste || liste.ok !== true) return { ok: false, raison: 'liste_indisponible' };
  for (const a of liste.avertir || []) {
    const m = texteAvertissement(a.langue, a.personnage, a.suppression_le);
    const r = await envoyer({ a: a.email, sujet: m.sujet, texte: m.texte }).catch(() => ({ ok: false, raison: 'exception' }));
    if (!r || r.ok !== true) { bilan.avertissements_non_envoyes++; if (bilan.echecs.length < 5) bilan.echecs.push('courriel:' + ((r && r.raison) || '?')); continue; }
    const n = await rpc('comptes_inactifs_avertissement_noter', { p_uid: a.user_id, p_activite: a.activite });
    const v = Array.isArray(n) ? n[0] : n;
    if (v && v.ok === true) bilan.avertis++; else bilan.echecs.push('noter:' + a.user_id);
  }
  for (const s of liste.supprimer || []) {
    const r = await rpc('compte_inactif_supprimer', { p_uid: s.user_id });
    const v = Array.isArray(r) ? r[0] : r;
    if (v && v.ok === true) bilan.supprimes++; else bilan.echecs.push('supprimer:' + s.user_id + ':' + ((v && v.raison) || '?'));
  }
  return bilan;
}
