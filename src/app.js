'use strict';

/* Yetties Bank web UI — port of the SwiftUI views (Home, Cards, Transfer,
   Insights, Profile, Goals, Notifications, sign-in gate) as a single-page app. */

import { haptic } from './haptics.js';

/* ---------- UI state ---------- */

const ui = {
  signedInName: localStorage.getItem('signedInName') || '',
  signedInEmail: localStorage.getItem('signedInEmail') || '',
  tab: 'home',
  page: null,
  modal: null,
  flow: null,
  flowContext: 'tab',
  revealedCardID: null,
  allFilterID: null,
  allSearch: '',
  insightsOffset: 0,
  monthlyBudget: parseFloat(localStorage.getItem('monthlyBudget')) || 3000,
  gateMode: null,
  sync: { mode: 'signup', email: '', password: '', name: '' },
  signin: { name: '', email: '', password: '', confirm: '' },
  exportMonth: Date.now()
};

function hapticTap(name) {
  try { haptic(name); } catch (e) { /* haptics unavailable */ }
}

/* ---------- Small helpers ---------- */

function firstName() { return (ui.signedInName || '').split(' ')[0] || 'there'; }

function greetingText() {
  const h = new Date().getHours();
  if (h >= 5 && h < 12) return 'Good morning,';
  if (h >= 12 && h < 18) return 'Good afternoon,';
  return 'Good evening,';
}

function hexToRgb(hex) {
  const h = String(hex || '1C2540').replace('#', '');
  const r = parseInt(h.slice(0, 2), 16) || 0;
  const g = parseInt(h.slice(2, 4), 16) || 0;
  const b = parseInt(h.slice(4, 6), 16) || 0;
  return r + ',' + g + ',' + b;
}

function toISODate(ms) {
  const d = new Date(ms);
  const pad = function (n) { return String(n).padStart(2, '0'); };
  return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
}

function monthShortName(ms) {
  return new Date(ms).toLocaleDateString('en-US', { month: 'long' });
}

let toastTimer = null;
function showToast(message, kind) {
  const t = document.getElementById('toast');
  if (!t) return;
  t.textContent = message;
  t.className = 'toast show' + (kind === 'error' ? ' error' : '');
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(function () { t.className = 'toast'; }, 2600);
}

/* ---------- Render ---------- */

function render() {
  const root = document.getElementById('app');
  if (!ui.signedInName) { root.innerHTML = signInHTML(); return; }
  const body = ui.page ? pageHTML() : tabHTML(ui.tab);
  root.innerHTML = '<div class="phone">' + body + tabbarHTML() + '</div>' +
    (ui.modal ? modalShellHTML() : '');
}

function renderFocusAware() {
  const active = document.activeElement;
  const key = active && active.dataset ? active.dataset.input : null;
  let sel = null;
  if (key && active.selectionStart !== null && active.selectionStart !== undefined) {
    sel = [active.selectionStart, active.selectionEnd];
  }
  render();
  if (key) {
    const el = document.querySelector('[data-input="' + key + '"]');
    if (el) {
      el.focus();
      if (sel) { try { el.setSelectionRange(sel[0], sel[1]); } catch (err) { /* not selectable */ } }
    }
  }
}

function tabHTML(tab) {
  if (tab === 'home') return homeHTML();
  if (tab === 'cards') return cardsHTML();
  if (tab === 'transfer') return transferTabHTML();
  if (tab === 'insights') return insightsHTML();
  return profileHTML();
}

function tabbarHTML() {
  const tabs = [['home', '🏠', 'Home'], ['cards', '💳', 'Cards'], ['transfer', '🔁', 'Transfer'],
    ['insights', '📊', 'Insights'], ['profile', '👤', 'Profile']];
  let html = '<nav class="tabbar">';
  for (const t of tabs) {
    html += '<button class="tabbtn' + (ui.tab === t[0] && !ui.page ? ' active' : '') +
      '" data-action="nav-tab" data-tab="' + t[0] + '">' +
      '<span class="tab-icon">' + t[1] + '</span><span class="tab-label">' + t[2] + '</span></button>';
  }
  return html + '</nav>';
}

/* ---------- Shared components ---------- */

function txRowHTML(tx) {
  const style = categoryStyle(tx.category);
  const neg = tx.amount < 0;
  return '<button class="tx-row" data-action="open-modal" data-type="edit-tx" data-id="' + tx.id + '">' +
    '<span class="tx-icon" style="background:#' + (neg ? 'ECEEF2' : 'E2F3EC') + '">' + style.icon + '</span>' +
    '<span class="tx-main"><span class="tx-merchant">' + esc(tx.merchant) + '</span>' +
    '<span class="tx-cat">' + esc(tx.category) + '</span></span>' +
    '<span class="tx-amt' + (neg ? '' : ' pos') + '">' + currencyString(tx.amount, { showSign: true }) + '</span>' +
    '</button>';
}

function ringHTML(fraction, colorHex) {
  const pct = Math.round(fraction * 100);
  const c = 2 * Math.PI * 30;
  return '<svg class="ring" viewBox="0 0 68 68">' +
    '<circle cx="34" cy="34" r="30" fill="none" stroke="#ECEEF1" stroke-width="9"/>' +
    '<circle cx="34" cy="34" r="30" fill="none" stroke="#' + colorHex + '" stroke-width="9" stroke-linecap="round"' +
    ' stroke-dasharray="' + c + '" stroke-dashoffset="' + (c * (1 - fraction)) + '" transform="rotate(-90 34 34)"/>' +
    '<text x="34" y="39" text-anchor="middle" font-size="15" font-weight="700" fill="#141826">' + pct + '%</text></svg>';
}

function pageHeader(title, rightHTML) {
  return '<div class="page-top"><button class="back-btn" data-action="back">‹ Back</button>' +
    '<div class="page-title">' + esc(title) + '</div>' +
    '<div class="page-right">' + (rightHTML || '') + '</div></div>';
}

function sheetHead(title, sub) {
  return '<div class="sheet-title">' + esc(title) + '</div>' +
    (sub ? '<div class="sheet-sub">' + sub + '</div>' : '');
}

function chipBtn(title, selected, action, id) {
  return '<button class="chip' + (selected ? ' active' : '') + '" data-action="' + action + '"' +
    (id ? ' data-id="' + id + '"' : '') + '>' + esc(title) + '</button>';
}

/* ---------- Home ---------- */

function upcomingItems() {
  const items = [];
  for (const b of store.bills) {
    items.push({ id: b.id, title: b.payee, sub: b.frequency + ' · due ' + dueLabel(b.nextDue),
      amount: b.amount, icon: '🧾', recurring: false, due: b.nextDue });
  }
  for (const r of store.recurringTransfers) {
    items.push({ id: r.id, title: r.title,
      sub: 'Repeats ' + r.frequency.toLowerCase() + ' · next ' + dueLabel(r.nextDue),
      amount: r.amount, icon: r.kind === 'goal' ? '🎯' : '🔁', recurring: true, due: r.nextDue });
  }
  return items.sort(function (a, b) { return a.due - b.due; });
}

function upcomingRowHTML(item) {
  return '<div class="row">' +
    '<span class="row-icon" style="background:#E2F3EC">' + item.icon + '</span>' +
    '<span class="row-main"><span class="row-title">' + esc(item.title) + '</span>' +
    '<span class="row-sub">' + esc(item.sub) + '</span></span>' +
    '<span class="row-value">' + (store.hideBalances ? '••••' : currencyString(item.amount)) + '</span>' +
    (item.recurring ? '<button class="close-x" data-action="remove-recurring" data-id="' + item.id + '">✕</button>' : '') +
    '</div>';
}

function homeHTML() {
  const unread = store.unreadNotificationCount();
  const total = store.totalBalance();
  let html = '<div class="screen-body">';

  html += '<div class="top"><div><div class="greeting">' + greetingText() + '</div>' +
    '<div class="big-name">' + esc(firstName()) + '</div></div>' +
    '<button class="bell" data-action="open-page" data-type="notifications">🔔' +
    (unread > 0 ? '<span class="bell-badge">' + (unread > 9 ? '9+' : unread) + '</span>' : '') + '</button></div>';

  html += '<div class="balance-card">' +
    '<div class="balance-top"><span>Total balance</span>' +
    '<button class="eye" data-action="toggle-hide">' + (store.hideBalances ? '🙈' : '👁️') + '</button></div>' +
    '<div class="balance-amount">' + (store.hideBalances ? '$ ••••••' : currencyString(total)) + '</div>' +
    '<div class="balance-sub">' + store.accounts.length + ' accounts · updated just now</div></div>';

  html += '<div class="qa-grid">' +
    '<button class="qa-btn" data-action="open-modal" data-type="add-tx"><span class="qa-icon">➕</span>Add tx</button>' +
    '<button class="qa-btn" data-action="open-flow" data-mode="send"><span class="qa-icon">↔️</span>Move</button>' +
    '<button class="qa-btn" data-action="open-page" data-type="goals"><span class="qa-icon">🎯</span>Goals</button>' +
    '<button class="qa-btn" data-action="open-page" data-type="all"><span class="qa-icon">🕒</span>History</button></div>';

  html += '<div class="section-h"><h2>Accounts</h2>' +
    '<button class="plus-btn" data-action="open-modal" data-type="add-account">＋</button></div>';
  if (!store.accounts.length) {
    html += '<div class="panel" style="text-align:center;margin-top:0"><div style="font-size:30px">🏦</div>' +
      '<div style="font-weight:700;margin-top:8px">Add your first account</div>' +
      '<div style="font-size:13px;color:var(--subtle);margin-top:4px">A checking account, a credit card, cash — whatever you want to track.</div>' +
      '<button class="btn btn-primary btn-full" data-action="open-modal" data-type="add-account">＋ Add account</button></div>';
  } else {
    html += '<div class="list-card">';
    for (const a of store.accounts) {
      html += '<button class="row" data-action="open-account" data-id="' + a.id + '">' +
        '<span class="avatar" style="background:#' + a.colorHex + '">' + esc(a.name[0]) + '</span>' +
        '<span class="row-main"><span class="row-title">' + esc(a.name) + '</span>' +
        '<span class="row-sub">' + esc(a.kind) + (a.number ? ' · ' + esc(a.number) : '') + '</span></span>' +
        '<span class="row-value">' + (store.hideBalances ? '••••' : currencyString(store.balanceOf(a))) + '</span>' +
        '<span class="chev">›</span></button>';
    }
    html += '</div>';
  }

  if (store.accounts.length) {
    html += '<div class="section-h"><h2>Upcoming payments</h2>' +
      '<button class="plus-btn" data-action="open-modal" data-type="schedule-bill">＋</button></div>';
    const items = upcomingItems();
    if (!items.length) html += '<div class="empty-note">No upcoming payments scheduled</div>';
    else {
      html += '<div class="list-card">';
      for (const item of items) html += upcomingRowHTML(item);
      html += '</div>';
    }
  }

  html += '<div class="section-h"><h2>Recent activity</h2>' +
    '<button class="link-btn" data-action="open-page" data-type="all">See all</button></div>';
  html += '<div class="list-card" style="padding:4px 16px">';
  const recent = store.transactionsFor(null).slice(0, 5);
  if (!recent.length) html += '<div class="empty-note" style="box-shadow:none">No activity yet</div>';
  for (const tx of recent) html += txRowHTML(tx);
  html += '</div></div>';
  return html;
}

/* ---------- Cards ---------- */

function cardVisualHTML(account, revealed) {
  const number = revealed ? formatCardNumber(account.cardNumber) : maskedCardNumber(account.cardNumber);
  const holder = esc((ui.signedInName || 'Card Holder').toUpperCase());
  const master = account.cardNumber.indexOf('5') === 0
    ? '<span class="mc-mark"><span class="mc-red"></span><span class="mc-orange"></span></span>' : '';
  return '<div class="card-visual"' +
    ' style="--card-color:#' + account.colorHex + ';--card-shadow:rgba(' + hexToRgb(account.colorHex) + ',0.35)">' +
    '<span class="deco1"></span><span class="deco2"></span>' +
    '<div class="card-top"><div><div class="card-name">' + esc(account.name) + '</div>' +
    '<div class="card-kind">' + esc(account.kind) + '</div></div>' +
    (account.contactless ? '<span class="card-wave">〰️</span>' : '') + '</div>' +
    '<div class="card-number">' + number + '</div>' +
    '<div class="card-bottom"><span>' + holder + '</span><span class="grow"></span>' +
    '<span>' + esc(account.expiry) + '</span>' + master + '</div>' +
    '</div>';
}

function accountSettingsHTML(account) {
  const rows = [
    ['contactless', 'Contactless payments', '📶'],
    ['onlinePayments', 'Online payments', '🌐'],
    ['atmWithdrawals', 'ATM withdrawals', '🏧']
  ];
  let html = '<div class="card-settings">';
  for (const r of rows) {
    html += '<label class="setting-row"><span class="setting-label">' + r[2] + ' ' + esc(r[1]) + '</span>' +
      '<input type="checkbox" class="switch" data-change="account-setting" data-account="' + account.id +
      '" data-setting="' + r[0] + '"' + (account[r[0]] ? ' checked' : '') + '></label>';
  }
  return html + '</div>';
}

function cardBlockHTML(account) {
  const revealed = ui.revealedCardID === account.id;
  return '<div class="card-block">' +
    cardVisualHTML(account, revealed) +
    '<div class="card-controls" style="grid-template-columns:1fr">' +
    '<button class="btn" data-action="toggle-reveal" data-id="' + account.id + '">' +
    (revealed ? '🙈 Hide number' : '👁️ Reveal number') + '</button></div>' +
    accountSettingsHTML(account) + '</div>';
}

function cardsHTML() {
  const cards = store.accounts.filter(function (a) { return a.isCard; });
  let html = '<div class="screen-body"><div class="page-title-lg">Cards</div>';
  if (!cards.length) {
    html += '<div class="panel" style="text-align:center;margin-top:14px"><div style="font-size:30px">💳</div>' +
      '<div style="font-weight:700;margin-top:8px">No cards yet</div>' +
      '<div style="font-size:13px;color:var(--subtle);margin-top:4px">Add an account with a card on it and it appears here.</div></div>';
  }
  for (const account of cards) html += cardBlockHTML(account);
  html += '</div>';
  return html;
}

/* ---------- Transfer flow ---------- */

function openFlow(mode, context) {
  ui.flowContext = context;
  ui.flow = {
    mode: mode, step: 'amount', amountText: '',
    fromID: store.accounts.length ? store.accounts[0].id : null,
    toAccountID: null, note: '',
    repeatEnabled: false, repeatFrequency: 'Monthly'
  };
}

function resetFlow() {
  const f = ui.flow;
  if (!f) return;
  f.step = 'amount'; f.amountText = ''; f.note = '';
  f.toAccountID = null;
  f.repeatEnabled = false; f.repeatFrequency = 'Monthly';
}

function flowHTML(embedded) {
  const f = ui.flow;
  if (!f) return '';
  if (f.step === 'amount') return flowAmountHTML(embedded);
  if (f.step === 'confirm') return flowConfirmHTML();
  return flowSuccessHTML();
}

function flowHasRecipient() {
  const f = ui.flow;
  return !!f.toAccountID && f.toAccountID !== f.fromID;
}

function flowCanProceed() {
  const f = ui.flow;
  const from = store.accountById(f.fromID);
  const amount = parseFloat(f.amountText) || 0;
  if (!from) return false;
  return amount > 0 && amount <= store.balanceOf(from) && flowHasRecipient();
}

function keypadHTML() {
  const rows = [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['.', '0', '⌫']];
  let html = '';
  for (const row of rows) for (const key of row) {
    html += '<button class="key" data-action="flow-key" data-key="' + key + '">' + key + '</button>';
  }
  return html;
}

function flowAmountHTML(embedded) {
  const f = ui.flow;
  const from = store.accountById(f.fromID);
  const amount = parseFloat(f.amountText) || 0;
  const title = f.mode === 'send' ? 'Move money' : 'Top up';
  let html = '<div class="flow-head"><div class="sheet-title">' + esc(title) + '</div>' +
    (embedded ? '' : '<button class="close-x" data-action="modal-close">✕</button>') + '</div>';

  html += '<div class="flow-amount"><div class="flow-amount-big' + (amount > 0 ? '' : ' muted') + '">$' +
    esc(f.amountText || '0') + '</div>' +
    '<div class="flow-available">Available ' + currencyString(from ? store.balanceOf(from) : 0) + '</div></div>';

  html += '<div class="form-label" style="margin-top:4px">Move to</div>';
  html += '<div class="person-chips">';
  for (const a of store.accounts) {
    if (a.id === f.fromID) continue;
    html += '<button class="chip' + (f.toAccountID === a.id ? ' active' : '') +
      '" data-action="flow-account" data-id="' + a.id + '">💳 ' + esc(a.name) + '</button>';
  }
  html += '</div>';

  html += '<div class="from-row">🏦 <select data-change="flow-from">' +
    store.accounts.map(function (a) {
      return '<option value="' + a.id + '"' + (f.fromID === a.id ? ' selected' : '') + '>' +
        esc(a.name) + ' · ' + currencyString(store.balanceOf(a)) + '</option>';
    }).join('') + '</select></div>';

  if (!flowHasRecipient()) {
    html += '<div class="flow-warning">⚠️ Select the account to move money to</div>';
  }

  html += '<div class="keypad">' + keypadHTML() + '</div>';
  html += '<button class="btn btn-primary btn-full' + (flowCanProceed() ? '' : ' dim') +
    '" data-action="flow-continue">Continue</button>';
  return html;
}

function flowContinue() {
  const f = ui.flow;
  const from = store.accountById(f.fromID);
  const amount = parseFloat(f.amountText) || 0;
  let message = null;
  if (!from) message = 'Choose an account to move from.';
  else if (amount <= 0) message = 'Enter an amount greater than $0.';
  else if (amount > store.balanceOf(from)) message = 'Insufficient balance in ' + from.name + '.';
  else if (!f.toAccountID) message = 'Choose an account.';
  else if (f.toAccountID === f.fromID) message = 'Choose a different account.';
  if (message) { showToast(message, 'error'); hapticTap('error'); return; }
  f.step = 'confirm';
  render();
}

function flowConfirmHTML() {
  const f = ui.flow;
  const from = store.accountById(f.fromID);
  const amount = parseFloat(f.amountText) || 0;
  const to = store.accountById(f.toAccountID);
  const recipientName = to ? to.name : 'an account';

  let html = '<div class="flow-head"><div class="sheet-title">Confirm</div>' +
    '<button class="link-btn" data-action="flow-back">Back</button></div>';

  html += '<div class="confirm-hero"><div class="hero-icon">🔁</div>' +
    '<div class="hero-name">' + esc(recipientName) + '</div>' +
    '<div class="hero-amount">' + currencyString(amount) + '</div></div>';

  html += '<div class="summary-card">';
  html += '<div class="summary-row"><span class="label">From</span><span class="value">' + esc(from ? from.name : '—') + '</span></div>';
  html += '<div class="summary-row"><span class="label">To</span><span class="value">' + esc(recipientName) + '</span></div>';
  html += '<div class="summary-row"><span class="label">Note</span><span class="value">' +
    '<input class="input" style="padding:8px 12px;text-align:right" placeholder="Optional" data-input="flow-note" value="' + esc(f.note) + '"></span></div>';

  html += '<label class="summary-row" style="align-items:center"><span class="label">Remind me again</span>' +
    '<input type="checkbox" class="switch" data-change="flow-repeat"' + (f.repeatEnabled ? ' checked' : '') + '></label>';
  if (f.repeatEnabled) {
    html += '<div><div class="form-label" style="margin-top:0">Frequency</div><div class="seg seg-mint">' +
      ['Weekly', 'Monthly'].map(function (fr) {
        return '<button class="seg-btn' + (f.repeatFrequency === fr ? ' active' : '') +
          '" data-action="flow-freq" data-value="' + fr + '">' + fr + '</button>';
      }).join('') + '</div>' +
      '<div class="sheet-footer-note">You\'ll get a reminder when it\'s due — nothing moves automatically.</div></div>';
  }
  html += '<div class="summary-row"><span class="label">Fee</span><span class="value">No fee</span></div>';
  html += '</div>';

  html += '<button class="btn btn-primary btn-full" data-action="flow-confirm">Confirm & move</button>';
  return html;
}

function flowConfirm() {
  const f = ui.flow;
  const from = store.accountById(f.fromID);
  const amount = parseFloat(f.amountText) || 0;
  if (!from || !f.toAccountID) return;

  f.step = 'success';
  store.performTransfer(from.id, null, f.toAccountID, amount);

  if (f.repeatEnabled) {
    const title = 'To ' + ((store.accountById(f.toAccountID) || { name: 'account' }).name);
    store.addRecurringTransfer('transfer', title, from.id, {
      toAccountID: f.toAccountID, amount: amount, frequency: f.repeatFrequency
    });
  }
  hapticTap('money');
}

function flowSuccessHTML() {
  const f = ui.flow;
  const amount = parseFloat(f.amountText) || 0;
  const recipientName = (store.accountById(f.toAccountID) || { name: 'account' }).name;
  return '<div class="success-wrap"><div class="big-check">✅</div>' +
    '<div class="success-title">Money moved</div>' +
    '<div class="success-sub">' + currencyString(amount) + ' to ' + esc(recipientName) + '</div>' +
    (f.repeatEnabled
      ? '<div class="success-repeat">Reminds you ' + f.repeatFrequency.toLowerCase() + ' from now on</div>' : '') +
    '<button class="btn btn-primary btn-full" data-action="flow-done">Done</button></div>';
}

function flowDone() {
  if (ui.flowContext === 'modal') ui.modal = null;
  else resetFlow();
  hapticTap('success');
  render();
}

function keypadPress(key) {
  const f = ui.flow;
  if (!f) return;
  const text = f.amountText;
  if (key === '⌫') {
    f.amountText = text.slice(0, -1);
  } else if (key === '.') {
    if (text.indexOf('.') === -1) f.amountText = text === '' ? '0.' : text + '.';
  } else {
    const dotIndex = text.indexOf('.');
    if (dotIndex >= 0 && text.length - dotIndex > 2) return;
    if (text === '0') f.amountText = key;
    else if (text.length < 9) f.amountText = text + key;
  }
  hapticTap('key');
  render();
}

function transferTabHTML() {
  return '<div class="screen-body">' + flowHTML(true) + '</div>';
}

/* ---------- Insights ---------- */

function monthSpending(ms) {
  const interval = monthInterval(ms);
  return store.transactions.filter(function (t) {
    return t.amount < 0 && t.category !== 'Internal transfer' &&
      t.date >= interval[0] && t.date < interval[1];
  });
}

function insightsHTML() {
  const monthDate = addMonths(Date.now(), ui.insightsOffset);
  const spending = monthSpending(monthDate);
  const totalSpent = spending.reduce(function (s, t) { return s - t.amount; }, 0);
  const prevSpent = monthSpending(addMonths(monthDate, -1)).reduce(function (s, t) { return s - t.amount; }, 0);
  const percent = (prevSpent > 0 && Math.abs(prevSpent - totalSpent) > 0.005)
    ? Math.round(Math.abs(prevSpent - totalSpent) / prevSpent * 100) : null;

  let html = '<div class="screen-body">';
  html += '<div class="top"><div class="page-title-lg" style="padding:0">Insights</div>' +
    '<div class="stepper"><button data-action="insights-month" data-dir="-1">‹</button>' +
    '<span class="month-name">' + monthShortName(monthDate) + '</span>' +
    '<button data-action="insights-month" data-dir="1"' + (ui.insightsOffset >= 0 ? ' disabled' : '') + '>›</button></div></div>';

  if (!spending.length) {
    html += '<div class="panel" style="text-align:center"><div style="font-size:30px">📊</div>' +
      '<div style="font-weight:600;margin-top:8px">No spending this month</div>' +
      '<div style="font-size:12.5px;color:var(--subtle);margin-top:4px">Payments you make in ' +
      monthShortName(monthDate) + ' will appear here.</div></div></div>';
    return html;
  }

  html += '<div class="total-spent"><div class="ts-label">Total spent</div><div class="ts-row">' +
    '<span class="ts-value">' + currencyString(totalSpent) + '</span>' +
    (percent !== null
      ? '<span class="delta-badge ' + (totalSpent < prevSpent ? 'delta-down' : 'delta-up') + '">' +
        (totalSpent < prevSpent ? '↓' : '↑') + ' ' + percent + '%</span>' : '') +
    '</div>' +
    (percent !== null ? '<div class="ts-caption">' + percent + '% ' +
      (totalSpent < prevSpent ? 'less' : 'more') + ' than ' + monthShortName(addMonths(monthDate, -1)) + '</div>' : '') +
    '</div>';

  const totals = {};
  for (const t of spending) totals[t.category] = (totals[t.category] || 0) - t.amount;
  const cats = Object.keys(totals).map(function (c) { return { name: c, total: totals[c] }; })
    .sort(function (a, b) { return b.total - a.total; });
  const maxTotal = cats.length ? cats[0].total : 1;
  html += '<div class="panel"><h2>Spending by category</h2>';
  for (const c of cats) {
    const style = categoryStyle(c.name);
    html += '<div class="cat-row"><span class="cat-icon" style="background:#' + style.bg + '">' + style.icon + '</span>' +
      '<span class="cat-name">' + esc(c.name) + '</span>' +
      '<span class="cat-bar"><div class="bar"><div class="bar-fill" style="width:' +
      Math.max(Math.round(c.total / maxTotal * 100), 2) + '%;background:#' + style.color + '"></div></div></span>' +
      '<span class="cat-total">' + currencyString(c.total) + '</span></div>';
  }
  html += '</div>';

  const merchants = {};
  for (const t of spending) {
    if (!merchants[t.merchant]) merchants[t.merchant] = { count: 0, total: 0, category: t.category };
    merchants[t.merchant].count++;
    merchants[t.merchant].total -= t.amount;
  }
  const top = Object.keys(merchants).map(function (m) {
    return { merchant: m, count: merchants[m].count, total: merchants[m].total, category: merchants[m].category };
  }).sort(function (a, b) { return b.total - a.total; }).slice(0, 5);
  html += '<div class="panel"><div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">' +
    '<h2 style="margin:0">Top merchants</h2>' +
    '<button class="link-btn" data-action="open-page" data-type="all">See all ›</button></div>';
  for (const m of top) {
    const style = categoryStyle(m.category);
    html += '<div class="merchant-row"><span class="merchant-icon" style="background:#' + style.color + '">' + style.icon + '</span>' +
      '<span class="row-main"><span class="row-title">' + esc(m.merchant) + '</span>' +
      '<span class="row-sub">' + m.count + (m.count === 1 ? ' transaction' : ' transactions') + '</span></span>' +
      '<span class="tx-amt">' + currencyString(m.total) + '</span></div>';
  }
  html += '</div>';

  const fraction = ui.monthlyBudget > 0 ? Math.min(Math.max(totalSpent / ui.monthlyBudget, 0), 1) : 0;
  const remaining = ui.monthlyBudget - totalSpent;
  html += '<div class="panel"><div class="budget-head"><h2 style="margin:0">Monthly budget</h2>' +
    '<button class="budget-pill" data-action="open-modal" data-type="budget">' +
    currencyString(ui.monthlyBudget, { cents: false }) + '</button></div>' +
    '<div class="bar bar-tall"><div class="bar-fill" style="width:' + Math.round(fraction * 100) + '%;background:#1FA97C"></div></div>' +
    '<div class="budget-foot"><span>' + currencyString(totalSpent) + ' spent</span>' +
    (remaining >= 0
      ? '<span class="left">' + currencyString(remaining, { cents: false }) + ' left</span>'
      : '<span class="over">' + currencyString(-remaining) + ' over budget</span>') + '</div></div>';

  html += '</div>';
  return html;
}

/* ---------- Profile ---------- */

function profileHTML() {
  const name = ui.signedInName || '';
  const initials = name.split(' ').slice(0, 2).map(function (p) { return p[0] || ''; }).join('').toUpperCase() || 'MB';
  let html = '<div class="screen-body"><div class="page-title-lg">Profile</div>';

  html += '<div class="list-card"><div class="profile-head">' +
    '<span class="avatar-lg">' + esc(initials) + '</span>' +
    '<span class="row-main"><span class="row-title">' + esc(name) + '</span>' +
    '<span class="row-sub">' + esc(ui.signedInEmail || 'Signed in with email') + '</span></span></div></div>';

  html += '<div class="profile-section-label">Preferences</div>';
  html += '<div class="list-card">' +
    '<label class="setting-row"><span class="setting-label">🙈 Hide balances</span>' +
    '<input type="checkbox" class="switch" data-change="pref-hide-balances"' + (store.hideBalances ? ' checked' : '') + '></label></div>';

  html += '<div class="profile-section-label">App</div>';
  html += '<div class="list-card"><button class="row" data-action="install-app">' +
    '<span class="row-icon" style="background:#E2F3EC">⬇️</span>' +
    '<span class="row-main"><span class="row-title">Install on home screen</span>' +
    '<span class="row-sub">' + (isStandalone()
      ? 'Running as an installed app'
      : 'Add Yetties Bank to your home screen like a native app') + '</span></span>' +
    '<span class="chev">›</span></button></div>';

  html += '<div class="profile-section-label">Cloud sync</div>';
  html += '<div class="list-card">';
  if (syncSignedIn()) {
    const user = syncUser() || {};
    html += '<div class="setting-row"><span class="setting-label">☁️ ' + esc(user.name || '') +
      ' · ' + esc(user.email || '') + '</span></div>';
    html += '<button class="row" data-action="sync-push">' +
      '<span class="row-icon" style="background:#E2F3EC">⬆️</span>' +
      '<span class="row-main"><span class="row-title">Back up now</span>' +
      '<span class="row-sub">' + (lastBackupLabel() || 'Not backed up yet') + '</span></span></button>';
    html += '<button class="row" data-action="sync-pull">' +
      '<span class="row-icon" style="background:#E1E8FA">⬇️</span>' +
      '<span class="row-main"><span class="row-title">Restore from cloud</span>' +
      '<span class="row-sub">Replaces what is on this device</span></span></button>';
    html += '<button class="row" data-action="sync-signout">' +
      '<span class="row-icon" style="background:#ECEEF2">🚪</span>' +
      '<span class="row-main"><span class="row-title">Sign out of cloud</span></span></button>';
  } else {
    html += '<div class="sheet-footer-note" style="padding:12px 16px 0">Connect the sync server you deployed from the backend folder in this project (backend/README.md has the steps). Data backs up to your own server and syncs across your devices.</div>';
    html += '<div class="setting-row"><span class="setting-label">🔗 API URL</span>' +
      '<input class="input" style="flex:1;border:none;background:none;font-weight:600;text-align:right" data-input="sync-api-url" placeholder="https://yetties-api.yourname.workers.dev" value="' + esc(syncApiBase()) + '"></div>';
    html += '<div class="setting-row"><span class="setting-label">📧 Email</span>' +
      '<input class="input" style="flex:1;border:none;background:none;font-weight:600;text-align:right" data-input="sync-email" value="' + esc(ui.sync.email) + '"></div>';
    html += '<div class="setting-row"><span class="setting-label">🔑 Password</span>' +
      '<input type="password" class="input" style="flex:1;border:none;background:none;font-weight:600;text-align:right" data-input="sync-password" value="' + esc(ui.sync.password) + '"></div>';
    if (ui.sync.mode === 'signup') {
      html += '<div class="setting-row"><span class="setting-label">👤 Name</span>' +
        '<input class="input" style="flex:1;border:none;background:none;font-weight:600;text-align:right" data-input="sync-name" value="' + esc(ui.sync.name) + '"></div>';
    }
    html += '<div class="seg seg-mint" style="margin:4px 16px 12px">' +
      '<button class="seg-btn' + (ui.sync.mode === 'signup' ? ' active' : '') + '" data-action="sync-mode" data-value="signup">Create account</button>' +
      '<button class="seg-btn' + (ui.sync.mode === 'login' ? ' active' : '') + '" data-action="sync-mode" data-value="login">Sign in</button>' +
      '</div>';
    html += '<div style="padding:0 16px 16px">' +
      '<button class="btn btn-primary" data-action="sync-auth" data-mode="' + ui.sync.mode + '">' +
      (ui.sync.mode === 'signup' ? 'Create cloud account' : 'Sign in to cloud') + '</button></div>';
  }
  html += '</div>';

  html += '<div class="profile-section-label">Data</div>';
  html += '<div class="list-card"><button class="row" data-action="open-modal" data-type="reset-confirm">' +
    '<span class="row-icon" style="background:#FBE4E4">🗑️</span>' +
    '<span class="row-main"><span class="row-title">Erase all data</span></span><span class="chev">›</span></button></div>';

  html += '<div class="list-card" style="margin-top:20px"><button class="row" data-action="sign-out">' +
    '<span class="row-icon" style="background:#FBE4E4">🚪</span>' +
    '<span class="row-main"><span class="row-title" style="color:#D24E4E">Sign out</span></span></button></div>';

  html += '</div>';
  return html;
}

/* ---------- Pages ---------- */

function pageHTML() {
  const page = ui.page;
  if (page.type === 'all') return allPageHTML();
  if (page.type === 'goals') return goalsPageHTML();
  if (page.type === 'notifications') return notificationsPageHTML();
  if (page.type === 'account') return accountPageHTML(page.id);
  return '';
}

function allPageHTML() {
  const filterID = ui.allFilterID;
  const query = ui.allSearch.trim().toLowerCase();
  let matches = store.transactionsFor(filterID);
  if (query) {
    matches = matches.filter(function (t) {
      return t.merchant.toLowerCase().indexOf(query) !== -1 ||
        t.category.toLowerCase().indexOf(query) !== -1 ||
        Math.abs(t.amount).toFixed(2).indexOf(query) !== -1 ||
        currencyString(Math.abs(t.amount)).toLowerCase().indexOf(query) !== -1;
    });
  }
  let html = pageHeader('All activity', '');
  html += '<div class="chip-row">';
  html += chipBtn('All', filterID === null, 'all-filter', '');
  for (const a of store.accounts) html += chipBtn(a.name, filterID === a.id, 'all-filter', a.id);
  html += '</div>';
  html += '<input class="search-input" placeholder="Search transactions" data-input="all-search" value="' + esc(ui.allSearch) + '">';
  if (!matches.length && query) {
    html += '<div class="search-empty"><div class="se-icon">🔍</div>' +
      '<div class="se-title">No results for "' + esc(ui.allSearch) + '"</div>' +
      '<div class="se-sub">Try a merchant, category or amount</div></div>';
  } else {
    html += '<div style="padding:0 20px 40px">';
    let lastDay = null;
    for (const tx of matches) {
      const label = dayLabel(tx.date);
      if (label !== lastDay) {
        if (lastDay !== null) html += '</div>';
        html += '<div class="day-head">' + label + '</div><div class="list-card" style="padding:4px 16px">';
        lastDay = label;
      }
      html += txRowHTML(tx);
    }
    if (lastDay !== null) html += '</div>';
    html += '</div>';
  }
  return html;
}

function coinsHTML() {
  return '<span class="coin" style="background:#C9EED9;left:8px;top:28px;transform:scale(0.8)"></span>' +
    '<span class="coin" style="background:#A9E3C6;left:38px;top:6px"></span>' +
    '<span class="coin" style="background:#8FD9B4;left:38px;top:24px"></span>' +
    '<span class="coin" style="background:#6BC7A0;left:38px;top:42px"></span>';
}

function goalCardHTML(goal) {
  const reached = goal.saved >= goal.target;
  return '<div class="goal-card">' +
    ringHTML(goal.target > 0 ? Math.min(goal.saved / goal.target, 1) : 0, goal.colorHex) +
    '<div class="goal-main"><div class="goal-name"><span class="goal-emoji">' + esc(goal.emoji) + '</span>' +
    esc(goal.name) + '</div>' +
    '<div class="goal-sub">' + currencyString(goal.saved, { cents: false }) + ' saved of ' +
    currencyString(goal.target, { cents: false }) + '</div>' +
    (reached ? '<div class="goal-reached">Goal reached</div>' : '') + '</div>' +
    '<button class="add-pill' + (reached ? ' done' : '') + '" data-action="open-modal" data-type="contribute" data-id="' +
    goal.id + '"' + (reached ? ' disabled' : '') + '>Add</button></div>';
}

function goalsPageHTML() {
  const totalSaved = store.goals.reduce(function (s, g) { return s + g.saved; }, 0);
  const totalTarget = store.goals.reduce(function (s, g) { return s + g.target; }, 0);
  const overall = totalTarget > 0 ? Math.round(totalSaved / totalTarget * 100) : 0;
  let html = pageHeader('Goals', '<button class="plus-btn" data-action="open-modal" data-type="create-goal">＋</button>');
  html += '<div class="screen-body">';
  html += '<div class="goal-total-card"><div class="gt-main">' +
    '<div class="gt-label">Total saved across goals</div>' +
    '<div class="gt-value">' + currencyString(totalSaved) + '</div>' +
    '<div class="gt-caption">You&#39;re <b>' + overall + '%</b> to your total goal of ' +
    currencyString(totalTarget, { cents: false }) + '</div></div>' +
    '<div class="coins">' + coinsHTML() + '</div></div>';
  for (const goal of store.goals) html += goalCardHTML(goal);
  if (!store.goals.length) {
    html += '<div class="panel" style="text-align:center;margin-top:14px"><div style="font-size:28px">🎯</div>' +
      '<div style="font-weight:700;margin-top:6px">No goals yet</div>' +
      '<div style="color:var(--subtle);font-size:14px;margin-top:2px">Start saving for something you care about.</div></div>';
  }
  html += '<div class="footer-hint">Tap + to start a new goal</div></div>';
  return html;
}

function notificationsPageHTML() {
  const unread = store.unreadNotificationCount();
  let html = pageHeader('Notifications',
    unread > 0 ? '<button class="link-btn" data-action="notif-mark-all">Mark all read</button>' : '');
  html += '<div class="screen-body">';
  if (!store.notifications.length) {
    html += '<div class="search-empty"><div class="se-icon">🔕</div>' +
      '<div class="se-title" style="font-weight:400">No notifications yet</div></div>';
  } else {
    const sorted = store.notifications.slice().sort(function (a, b) { return b.date - a.date; });
    for (const n of sorted) {
      html += '<button class="notif-row' + (n.isRead ? '' : ' unread') + '" data-action="notif-read" data-id="' + n.id + '">' +
        '<span class="notif-icon" style="background:rgba(' + hexToRgb(n.colorHex) + ',0.12);color:#' + n.colorHex + '">' + n.icon + '</span>' +
        '<span class="notif-main"><span class="notif-title' + (n.isRead ? ' read' : '') + '">' + esc(n.title) + '</span>' +
        '<span class="notif-msg">' + esc(n.message) + '</span>' +
        '<span class="notif-time">' + relativeLabel(n.date) + '</span></span>' +
        (n.isRead ? '' : '<span class="unread-dot"></span>') + '</button>';
    }
  }
  html += '</div>';
  return html;
}

function accountPageHTML(id) {
  const account = store.accountById(id);
  if (!account) return pageHeader('Account', '');
  const txs = store.transactionsFor(account.id);
  let html = pageHeader(account.name,
    '<button class="link-btn" data-action="open-modal" data-type="edit-account" data-id="' + account.id + '">Edit</button>');
  html += '<div class="screen-body">';
  html += '<div class="balance-row"><span class="br-label">Balance</span>' +
    '<span class="br-value">' + (store.hideBalances ? '••••' : currencyString(store.balanceOf(account))) + '</span></div>';
  html += '<div class="section-h"><h2>Activity</h2></div>';
  html += '<div class="list-card" style="padding:4px 16px">';
  if (!txs.length) html += '<div class="empty-note" style="box-shadow:none">No activity yet</div>';
  for (const tx of txs) html += txRowHTML(tx);
  html += '</div></div>';
  return html;
}

/* ---------- Modals ---------- */

function openModal(type, data) {
  const m = { type: type, data: data || {} };
  if (type === 'edit-tx') {
    const tx = store.transactions.find(function (t) { return t.id === data.id; });
    if (!tx) return;
    m.data.merchant = tx.merchant;
    m.data.category = tx.category;
    m.data.type = tx.amount < 0 ? 'expense' : 'income';
    m.data.amount = String(Math.abs(tx.amount));
    m.data.date = toISODate(tx.date);
  } else if (type === 'add-tx') {
    m.data = { accountId: store.accounts.length ? store.accounts[0].id : null,
      type: 'expense', amount: '', merchant: '', category: 'Groceries', date: toISODate(Date.now()) };
  } else if (type === 'add-account') {
    m.data = { name: '', kind: 'Checking', number: '', openingBalance: '', isCard: false };
  } else if (type === 'edit-account') {
    const account = store.accountById(data.id);
    if (!account) return;
    m.data = { id: account.id, name: account.name, kind: account.kind, number: account.number,
      openingBalance: String(account.openingBalance !== undefined ? account.openingBalance : account.balance),
      isCard: account.isCard, cardNumber: account.cardNumber, expiry: account.expiry };
  } else if (type === 'delete-account') {
    m.data = { id: data.id };
  } else if (type === 'schedule-bill') {
    m.data = { payeeIndex: -1, newPayee: '', amount: '',
      accountID: store.accounts.length ? store.accounts[0].id : null,
      frequency: 'Monthly', firstDue: toISODate(Date.now() + DAY_MS) };
  } else if (type === 'create-goal') {
    m.data = { name: '', emoji: '✈️', colorHex: '3BB273', target: '' };
  } else if (type === 'contribute') {
    m.data = { goalID: data.id, accountID: store.accounts.length ? store.accounts[0].id : null,
      amount: '', repeat: 'none' };
  } else if (type === 'budget') {
    m.data = { amount: String(ui.monthlyBudget) };
  } else if (type === 'export') {
    m.data = { accountID: data.id };
    ui.exportMonth = Date.now();
  } else if (type === 'transfer-flow') {
    openFlow(data.mode, 'modal');
    ui.modal = m;
    render();
    return;
  }
  ui.modal = m;
  render();
}

function modalShellHTML() {
  const inner = modalBodyHTML();
  if (!inner) return '';
  return '<div class="overlay" data-action="modal-close"><div class="sheet" data-action="noop">' +
    '<div class="sheet-grip"></div>' + inner + '</div></div>';
}

function modalBodyHTML() {
  const m = ui.modal;
  if (!m) return '';
  if (m.type === 'transfer-flow') return flowHTML(false);
  if (m.type === 'edit-tx') return editTxHTML();
  if (m.type === 'schedule-bill') return scheduleBillHTML();
  if (m.type === 'create-goal') return createGoalHTML();
  if (m.type === 'contribute') return contributeHTML();
  if (m.type === 'budget') return budgetHTML();
  if (m.type === 'add-tx') return addTxHTML();
  if (m.type === 'add-account') return addAccountHTML();
  if (m.type === 'edit-account') return editAccountHTML();
  if (m.type === 'delete-account') return deleteAccountHTML();
  if (m.type === 'export') return exportHTML();
  if (m.type === 'install') return installHTML();
  if (m.type === 'reset-confirm') return resetConfirmHTML();
  return '';
}

function editTxHTML() {
  const tx = store.transactions.find(function (t) { return t.id === ui.modal.data.id; });
  if (!tx) return '';
  const d = ui.modal.data;
  const cats = store.editorCategories().slice();
  if (cats.indexOf(d.category) === -1) cats.unshift(d.category);
  const expense = d.type !== 'income';
  return sheetHead('Edit transaction') +
    '<div class="seg seg-mint" style="margin-top:12px">' +
    '<button class="seg-btn' + (expense ? ' active' : '') + '" data-action="tx-type" data-value="expense">Expense</button>' +
    '<button class="seg-btn' + (!expense ? ' active' : '') + '" data-action="tx-type" data-value="income">Income</button></div>' +
    '<label class="form-label">Amount</label>' +
    '<input class="input" type="number" inputmode="decimal" min="0" step="0.01" placeholder="0.00" data-input="tx-amount" value="' + esc(d.amount) + '">' +
    '<label class="form-label">Merchant</label>' +
    '<input class="input" data-input="tx-merchant" value="' + esc(d.merchant) + '">' +
    '<label class="form-label">Category</label>' +
    '<select class="input" data-change="tx-category">' + cats.map(function (c) {
      return '<option' + (c === d.category ? ' selected' : '') + '>' + esc(c) + '</option>';
    }).join('') + '</select>' +
    '<label class="form-label">Date</label>' +
    '<input class="input" type="date" data-input="tx-date" value="' + esc(d.date) + '">' +
    '<button class="btn btn-primary btn-full" data-action="tx-save">Save changes</button>' +
    '<button class="btn btn-danger btn-full" data-action="tx-delete">Delete transaction</button>';
}

function addTxHTML() {
  const d = ui.modal.data;
  return sheetHead('Add transaction') +
    '<label class="form-label">Account</label>' +
    '<select class="input" data-change="tx-account">' + store.accounts.map(function (a) {
      return '<option value="' + a.id + '"' + (d.accountId === a.id ? ' selected' : '') + '>' + esc(a.name) + '</option>';
    }).join('') + '</select>' +
    '<div class="seg seg-mint" style="margin-top:12px">' +
    '<button class="seg-btn' + (d.type !== 'income' ? ' active' : '') + '" data-action="tx-type" data-value="expense">Expense</button>' +
    '<button class="seg-btn' + (d.type === 'income' ? ' active' : '') + '" data-action="tx-type" data-value="income">Income</button></div>' +
    '<label class="form-label">Amount</label>' +
    '<input class="input" type="number" inputmode="decimal" min="0" step="0.01" placeholder="0.00" data-input="tx-amount" value="' + esc(d.amount) + '">' +
    '<label class="form-label">Merchant</label>' +
    '<input class="input" placeholder="e.g. Blue Bottle Coffee" data-input="tx-merchant" value="' + esc(d.merchant) + '">' +
    '<label class="form-label">Category</label>' +
    '<select class="input" data-change="tx-category">' + FIXED_CATEGORIES.map(function (c) {
      return '<option' + (c === d.category ? ' selected' : '') + '>' + esc(c) + '</option>';
    }).join('') + '</select>' +
    '<label class="form-label">Date</label>' +
    '<input class="input" type="date" data-input="tx-date" value="' + esc(d.date) + '">' +
    '<button class="btn btn-primary btn-full" data-action="add-tx-save">Add transaction</button>';
}

function addTxSave() {
  const d = ui.modal.data;
  const merchant = (d.merchant || '').trim();
  const amount = parseFloat(d.amount) || 0;
  if (!d.accountId || !store.accountById(d.accountId)) { showToast('Choose an account.', 'error'); hapticTap('error'); return; }
  if (!(amount > 0)) { showToast('Enter an amount greater than $0.', 'error'); hapticTap('error'); return; }
  ui.modal = null;
  store.addTransaction({ accountId: d.accountId, merchant: merchant,
    category: d.category, amount: amount, type: d.type, date: isoToDate(d.date) });
  hapticTap('success');
  showToast('Transaction added');
}

function txDelete() {
  const d = ui.modal.data;
  ui.modal = null;
  store.deleteTransaction(d.id);
  hapticTap('freeze');
  showToast('Transaction deleted');
}

function txSave() {
  const d = ui.modal.data;
  const merchant = (d.merchant || '').trim();
  if (!merchant) { showToast('Enter a merchant name.', 'error'); hapticTap('error'); return; }
  const amount = parseFloat(d.amount) || 0;
  if (!(amount > 0)) { showToast('Enter an amount greater than $0.', 'error'); hapticTap('error'); return; }
  const signed = d.type === 'income' ? amount : -amount;
  ui.modal = null;
  store.updateTransaction(d.id, merchant, d.category, signed);
}

function scheduleBillHTML() {
  const d = ui.modal.data;
  let html = sheetHead('Schedule payment', 'Pick someone from your contacts, or add a new bill payee.');
  html += '<label class="form-label">Pay to</label>';
  html += '<select class="input" data-change="schedule-payee"><option value="-1"' +
    (d.payeeIndex === -1 ? ' selected' : '') + '>New payee…</option>' +
    store.contacts.map(function (c, i) {
      return '<option value="' + i + '"' + (d.payeeIndex === i ? ' selected' : '') + '>' + esc(c.name) + '</option>';
    }).join('') + '</select>';
  if (d.payeeIndex === -1) {
    html += '<input class="input" placeholder="Payee name" style="margin-top:10px" data-input="schedule-payee-name" value="' + esc(d.newPayee) + '">';
  }
  html += '<label class="form-label">Amount</label>';
  html += '<input class="input" type="number" inputmode="decimal" min="0" step="0.01" placeholder="0.00" data-input="schedule-amount" value="' + esc(d.amount) + '">';
  html += '<label class="form-label">From account</label>';
  html += '<select class="input" data-change="schedule-account">' + store.accounts.map(function (a) {
    return '<option value="' + a.id + '"' + (d.accountID === a.id ? ' selected' : '') + '>' + esc(a.name) + '</option>';
  }).join('') + '</select>';
  html += '<label class="form-label">Frequency</label>';
  html += '<div class="seg seg-mint">' + ['Weekly', 'Monthly'].map(function (f) {
    return '<button class="seg-btn' + (d.frequency === f ? ' active' : '') +
      '" data-action="schedule-frequency" data-value="' + f + '">' + f + '</button>';
  }).join('') + '</div>';
  html += '<label class="form-label">First due</label>';
  html += '<input class="input" type="date" data-input="schedule-due" value="' + d.firstDue + '">';
  html += '<button class="btn btn-primary btn-full" data-action="schedule-submit">Schedule</button>';
  return html;
}

function scheduleSubmit() {
  const d = ui.modal.data;
  const payee = d.payeeIndex === -1 ? (d.newPayee || '').trim()
    : ((store.contacts[d.payeeIndex] || {}).name || '');
  const amount = parseFloat(d.amount) || 0;
  if (!payee) { showToast('Enter a payee name.', 'error'); hapticTap('error'); return; }
  if (!(amount > 0)) { showToast('Enter an amount greater than $0.', 'error'); hapticTap('error'); return; }
  if (!d.accountID || !store.accountById(d.accountID)) { showToast('Choose an account.', 'error'); hapticTap('error'); return; }
  ui.modal = null;
  store.addBill(payee, amount, d.accountID, d.frequency, isoToDate(d.firstDue));
  hapticTap('success');
  showToast('Payment scheduled');
}

function addAccountHTML() {
  const d = ui.modal.data;
  return sheetHead('Add account') +
    '<label class="form-label">Name</label>' +
    '<input class="input" placeholder="e.g. Everyday checking" data-input="account-name" value="' + esc(d.name) + '">' +
    '<label class="form-label">Type</label>' +
    '<select class="input" data-change="account-kind">' +
    ['Checking', 'Savings', 'Prepaid card', 'Credit card', 'Cash', 'Other'].map(function (k) {
      return '<option' + (k === d.kind ? ' selected' : '') + '>' + esc(k) + '</option>';
    }).join('') + '</select>' +
    '<label class="form-label">Account number (optional)</label>' +
    '<input class="input" placeholder="Last 4 digits, e.g. 4821" data-input="account-number" value="' + esc(d.number) + '">' +
    '<label class="form-label">Opening balance</label>' +
    '<input class="input" type="number" inputmode="decimal" step="0.01" placeholder="0.00" data-input="account-opening" value="' + esc(d.openingBalance) + '">' +
    '<label class="setting-row" style="border-bottom:none"><span class="setting-label">💳 Show in Cards</span>' +
    '<input type="checkbox" class="switch" data-change="account-iscard"' + (d.isCard ? ' checked' : '') + '></label>' +
    '<div class="sheet-footer-note">Opening balance is what the account holds today. For credit cards, use a negative number for what you owe. Balance = opening balance + everything you log.</div>' +
    '<button class="btn btn-primary btn-full" data-action="account-save">Add account</button>';
}

function accountSave() {
  const d = ui.modal.data;
  const name = (d.name || '').trim();
  if (!name) { showToast('Give the account a name.', 'error'); hapticTap('error'); return; }
  ui.modal = null;
  if (d.id) {
    store.updateAccount(d.id, { name: name, kind: d.kind, number: d.number,
      openingBalance: parseFloat(d.openingBalance) || 0, isCard: d.isCard });
    showToast('Account updated');
  } else {
    store.addAccount({ name: name, kind: d.kind, number: d.number,
      openingBalance: parseFloat(d.openingBalance) || 0, isCard: d.isCard });
    showToast('Account added');
  }
  hapticTap('success');
}

function editAccountHTML() {
  const d = ui.modal.data;
  const account = store.accountById(d.id);
  if (!account) return '';
  return sheetHead('Edit account', account.name) +
    '<label class="form-label">Name</label>' +
    '<input class="input" data-input="account-name" value="' + esc(d.name) + '">' +
    '<label class="form-label">Type</label>' +
    '<select class="input" data-change="account-kind">' +
    ['Checking', 'Savings', 'Prepaid card', 'Credit card', 'Cash', 'Other'].map(function (k) {
      return '<option' + (k === d.kind ? ' selected' : '') + '>' + esc(k) + '</option>';
    }).join('') + '</select>' +
    '<label class="form-label">Account number</label>' +
    '<input class="input" data-input="account-number" value="' + esc(d.number) + '">' +
    '<label class="form-label">Opening balance</label>' +
    '<input class="input" type="number" inputmode="decimal" step="0.01" data-input="account-opening" value="' + esc(d.openingBalance) + '">' +
    '<label class="setting-row" style="border-bottom:none"><span class="setting-label">💳 Show in Cards</span>' +
    '<input type="checkbox" class="switch" data-change="account-iscard"' + (d.isCard ? ' checked' : '') + '></label>' +
    '<div class="sheet-footer-note">Balance = opening balance + every transaction you log. Fix a back-dated mistake by adjusting the opening balance.</div>' +
    '<button class="btn btn-primary btn-full" data-action="account-save">Save changes</button>' +
    '<button class="btn btn-danger btn-full" data-action="open-modal" data-type="delete-account" data-id="' + d.id + '">Delete account</button>';
}

function deleteAccountHTML() {
  const d = ui.modal.data;
  const account = store.accountById(d.id);
  if (!account) return '';
  const count = store.transactionsFor(account.id).length;
  return sheetHead('Delete "' + account.name + '"?',
    'The account and its ' + count + ' transaction' + (count === 1 ? '' : 's') + ' will be permanently removed.') +
    '<button class="btn btn-danger btn-full" data-action="account-delete">Delete</button>' +
    '<button class="btn btn-full" data-action="modal-close">Cancel</button>';
}

function accountDelete() {
  const d = ui.modal.data;
  ui.modal = null;
  store.deleteAccount(d.id);
  if (ui.page && ui.page.type === 'account' && ui.page.id === d.id) ui.page = null;
  hapticTap('freeze');
  showToast('Account deleted');
}

function createGoalHTML() {
  const d = ui.modal.data;
  const emojis = ['✈️', '💻', '🚨', '🏠', '📱', '🚗', '🎓', '💍', '🏖️', '🎸'];
  const colors = ['3BB273', 'F2762E', '4C8DF5', '8E6FD8', '1FA97C', 'D96A7B', 'D08A3E', '35507B'];
  let html = sheetHead('New goal');
  html += '<label class="form-label">Name</label>';
  html += '<input class="input" placeholder="e.g. Japan trip" data-input="goal-name" value="' + esc(d.name) + '">';
  html += '<label class="form-label">Icon</label><div class="emoji-pick">' +
    emojis.map(function (e) {
      return '<button class="emoji-opt' + (d.emoji === e ? ' selected' : '') +
        '" data-action="goal-emoji" data-value="' + e + '">' + e + '</button>';
    }).join('') + '</div>';
  html += '<label class="form-label">Color</label><div class="color-pick">' +
    colors.map(function (c) {
      return '<button class="color-opt' + (d.colorHex === c ? ' selected' : '') +
        '" style="background:#' + c + '" data-action="goal-color" data-value="' + c + '"></button>';
    }).join('') + '</div>';
  html += '<label class="form-label">Target amount</label>';
  html += '<input class="input" type="number" inputmode="decimal" min="0" step="0.01" placeholder="0.00" data-input="goal-target" value="' + esc(d.target) + '">';
  html += '<button class="btn btn-primary btn-full" data-action="goal-create">Create goal</button>';
  return html;
}

function goalCreate() {
  const d = ui.modal.data;
  const name = (d.name || '').trim();
  const target = parseFloat(d.target) || 0;
  if (!name) { showToast('Enter a name for the goal.', 'error'); hapticTap('error'); return; }
  if (!(target > 0)) { showToast('Enter a target amount greater than $0.', 'error'); hapticTap('error'); return; }
  ui.modal = null;
  store.addGoal(name, d.emoji, d.colorHex, target);
  hapticTap('success');
}

function contributeHTML() {
  const goal = store.goalById(ui.modal.data.goalID);
  if (!goal) return '';
  const d = ui.modal.data;
  if (!d.accountID || !store.accountById(d.accountID)) {
    d.accountID = store.accounts.length ? store.accounts[0].id : null;
  }
  const account = store.accountById(d.accountID);
  const amount = parseFloat(d.amount) || 0;
  const exceeded = account && store.balanceOf(account) < amount;
  const after = goal.saved + Math.max(amount, 0);
  let html = sheetHead('Contribute');
  html += '<div class="goal-card" style="margin-top:10px">' +
    ringHTML(goal.target > 0 ? Math.min(goal.saved / goal.target, 1) : 0, goal.colorHex) +
    '<div class="goal-main"><div class="goal-name"><span class="goal-emoji">' + esc(goal.emoji) + '</span>' +
    esc(goal.name) + '</div>' +
    '<div class="goal-sub">' + currencyString(goal.saved, { cents: false }) + ' of ' +
    currencyString(goal.target, { cents: false }) + ' · ' +
    Math.round((goal.target > 0 ? goal.saved / goal.target : 0) * 100) + '%</div></div></div>';

  html += '<label class="form-label">From account</label><div class="list-card">';
  for (const acc of store.accounts) {
    const selected = d.accountID === acc.id;
    html += '<button class="radio-row" data-action="contribute-account" data-id="' + acc.id + '">' +
      '<span class="avatar avatar-sm" style="background:#' + acc.colorHex + '">' + esc(acc.name[0]) + '</span>' +
      '<span class="row-main"><span class="row-title">' + esc(acc.name) + '</span>' +
      '<span class="row-sub">' + currencyString(store.balanceOf(acc)) + '</span></span>' +
      '<span class="radio-circle' + (selected ? ' on' : '') + '"></span></button>';
  }
  html += '</div>';

  html += '<label class="form-label">Amount</label>';
  html += '<input class="input" type="number" inputmode="decimal" min="0" step="0.01" placeholder="0.00" data-input="contribute-amount" value="' + esc(d.amount) + '">';
  html += '<div class="person-chips" style="padding:10px 0">' +
    [50, 100, 500].map(function (v) {
      return '<button class="chip" data-action="contribute-chip" data-value="' + v + '">+ ' +
        currencyString(v, { cents: false }) + '</button>';
    }).join('') + '</div>';
  html += '<div class="sheet-footer-note">' + (exceeded
    ? '<span style="color:#D24E4E">Amount exceeds the account balance.</span>'
    : 'After this: ' + currencyString(after, { cents: false }) + ' of ' +
      currencyString(goal.target, { cents: false }) + ' saved.') + '</div>';

  html += '<label class="form-label">Repeat</label>';
  html += '<select class="input" data-change="contribute-repeat">' +
    '<option value="none"' + (d.repeat === 'none' ? ' selected' : '') + '>One time</option>' +
    '<option value="Weekly"' + (d.repeat === 'Weekly' ? ' selected' : '') + '>Weekly</option>' +
    '<option value="Monthly"' + (d.repeat === 'Monthly' ? ' selected' : '') + '>Monthly</option></select>';
  if (d.repeat !== 'none') {
    html += '<div class="sheet-footer-note">Today&#39;s contribution goes through now; it repeats ' +
      esc(d.repeat.toLowerCase()) + ' after that. Remove it any time under Upcoming payments on Home.</div>';
  }
  html += '<button class="btn btn-primary btn-full" data-action="contribute-submit">Add to goal</button>';
  return html;
}

function contributeSubmit() {
  const d = ui.modal.data;
  const goal = store.goalById(d.goalID);
  const amount = parseFloat(d.amount) || 0;
  const account = store.accountById(d.accountID);
  if (!goal || !account) return;
  if (!(amount > 0)) { showToast('Enter an amount greater than $0.', 'error'); hapticTap('error'); return; }
  if (store.balanceOf(account) < amount) { showToast('Amount exceeds the account balance.', 'error'); hapticTap('error'); return; }
  if (goal.saved >= goal.target) { showToast('Goal already reached.', 'error'); hapticTap('error'); return; }
  ui.modal = null;
  store.contribute(goal.id, account.id, amount);
  if (d.repeat !== 'none') {
    store.addRecurringTransfer('goal', 'Saving for ' + goal.name, account.id,
      { goalID: goal.id, amount: amount, frequency: d.repeat });
  }
  hapticTap('success');
}

function budgetHTML() {
  const d = ui.modal.data;
  if (d.amount === undefined) d.amount = String(ui.monthlyBudget);
  return sheetHead('Edit budget', 'Your budget powers the progress bar at the bottom of Insights.') +
    '<label class="form-label">Monthly budget</label>' +
    '<input class="input" type="number" inputmode="decimal" min="0" step="0.01" data-input="budget-amount" value="' + esc(d.amount) + '">' +
    '<button class="btn btn-primary btn-full" data-action="budget-save">Done</button>';
}

function budgetSave() {
  ui.monthlyBudget = Math.max(parseFloat(ui.modal.data.amount) || 0, 0);
  localStorage.setItem('monthlyBudget', String(ui.monthlyBudget));
  ui.modal = null;
  render();
}

function exportHTML() {
  const account = store.accountById(ui.modal.data.accountID);
  if (!account) return '';
  const interval = monthInterval(ui.exportMonth);
  const count = store.transactionsFor(account.id).filter(function (t) {
    return t.date >= interval[0] && t.date < interval[1];
  }).length;
  return sheetHead('Export statement', account.name) +
    '<div class="stepper" style="display:flex;justify-content:center;margin-top:16px;width:100%">' +
    '<button data-action="export-month" data-dir="-1">‹</button>' +
    '<span class="month-name">' + new Date(ui.exportMonth).toLocaleDateString('en-US', { month: 'long', year: 'numeric' }) + '</span>' +
    '<button data-action="export-month" data-dir="1"' + (canExportForward() ? '' : ' disabled') + '>›</button></div>' +
    '<div class="sheet-count">' + count + ' transaction' + (count === 1 ? '' : 's') + ' in this month</div>' +
    '<button class="btn btn-primary" data-action="export-download">⬆️ Export statement</button>';
}

function canExportForward() {
  return monthInterval(addMonths(ui.exportMonth, 1))[0] <= monthInterval(Date.now())[0];
}

function exportMonthShift(dir) {
  if (dir > 0 && !canExportForward()) return;
  ui.exportMonth = addMonths(ui.exportMonth, dir);
  render();
}

function exportDownload() {
  const account = store.accountById(ui.modal.data.accountID);
  if (!account) return;
  const csv = store.statementCSV(account.id, ui.exportMonth);
  const title = new Date(ui.exportMonth).toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  const blob = new Blob([csv], { type: 'text/csv' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'Statement - ' + account.name.replace(/\//g, '-') + ' - ' +
    new Date(ui.exportMonth).toISOString().slice(0, 7) + '.csv';
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
  hapticTap('success');
  showToast('Statement for ' + title + ' exported');
}

function resetConfirmHTML() {
  return sheetHead('Erase everything?', 'All accounts, transactions and goals on this device will be permanently deleted. There is no undo — export a statement first if you want to keep a copy. Your cloud backup (if you have one) is not touched — sign in to cloud sync again to restore it.') +
    '<button class="btn btn-danger btn-full" data-action="reset-do">Erase all data</button>' +
    '<button class="btn btn-full" data-action="modal-close">Cancel</button>';
}

/* ---------- Sign in ---------- */

const ACCOUNT_KEY = 'localAccount';

function getLocalAccount() {
  try {
    const raw = localStorage.getItem(ACCOUNT_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch (e) { return null; }
}

function setLocalAccount(account) {
  if (account) localStorage.setItem(ACCOUNT_KEY, JSON.stringify(account));
  else localStorage.removeItem(ACCOUNT_KEY);
}

async function hashPassword(password) {
  if (window.crypto && window.crypto.subtle && window.isSecureContext) {
    const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(password));
    return Array.from(new Uint8Array(buf)).map(function (b) {
      return b.toString(16).padStart(2, '0');
    }).join('');
  }
  let h = 0;
  for (let i = 0; i < password.length; i++) h = ((h * 31 + password.charCodeAt(i)) | 0);
  return 'fb' + (h >>> 0).toString(16);
}

function completeSignIn(name, email) {
  ui.signedInName = name;
  ui.signedInEmail = email;
  localStorage.setItem('signedInName', name);
  localStorage.setItem('signedInEmail', email);
  ui.gateMode = null;
  ui.page = null;
  ui.tab = 'home';
  hapticTap('success');
  render();
}

async function gateSubmit(mode) {
  const s = ui.signin;
  if (mode === 'create') {
    const name = s.name.trim();
    const email = s.email.trim();
    if (!name) { showToast('Please enter your name.', 'error'); hapticTap('error'); return; }
    if (email.indexOf('@') === -1 || email.indexOf('.') === -1) {
      showToast('Please enter a valid email address.', 'error'); hapticTap('error'); return;
    }
    if (s.password.length < 6) { showToast('Password must be at least 6 characters.', 'error'); hapticTap('error'); return; }
    if (s.password !== s.confirm) { showToast('Passwords do not match.', 'error'); hapticTap('error'); return; }
    if (getLocalAccount()) {
      showToast('An account already exists on this device. Sign in instead.', 'error'); hapticTap('error'); return;
    }
    setLocalAccount({ name: name, email: email.toLowerCase(), passwordHash: await hashPassword(s.password) });
    completeSignIn(name, email.toLowerCase());
  } else {
    const account = getLocalAccount();
    const hash = await hashPassword(s.password);
    if (!account || account.email !== s.email.trim().toLowerCase() || account.passwordHash !== hash) {
      showToast('Incorrect email or password.', 'error');
      hapticTap('error');
      return;
    }
    completeSignIn(account.name, account.email);
  }
}

function signInHTML() {
  if (!ui.gateMode) ui.gateMode = getLocalAccount() ? 'signin' : 'create';
  const mode = ui.gateMode;
  let fields = '';
  if (mode === 'create') {
    fields += '<input class="input" placeholder="Full name" data-input="signin-name" value="' + esc(ui.signin.name) + '">';
  }
  fields += '<input class="input" type="email" placeholder="Email" autocapitalize="none" data-input="signin-email" value="' + esc(ui.signin.email) + '">';
  fields += '<input class="input" type="password" placeholder="' +
    (mode === 'create' ? 'Password (at least 6 characters)' : 'Password') +
    '" data-input="signin-password" value="' + esc(ui.signin.password) + '">';
  if (mode === 'create') {
    fields += '<input class="input" type="password" placeholder="Confirm password" data-input="signin-confirm" value="' + esc(ui.signin.confirm) + '">';
  }
  return '<div class="phone"><div class="gate">' +
    '<div class="gate-logo">🏦</div>' +
    '<div class="gate-title">Yetties Bank</div>' +
    '<div class="gate-sub">Your money, beautifully organised. Create an account to view balances, move money and track every payment.</div>' +
    '<div class="gate-form">' + fields +
    '<button class="btn btn-primary" style="margin-top:6px" data-action="gate-submit" data-mode="' + mode + '">' +
    (mode === 'create' ? 'Create account' : 'Sign in') + '</button>' +
    '<button class="gate-toggle" data-action="gate-switch">' +
    (mode === 'create' ? 'Already have an account? Sign in' : 'New here? Create an account') + '</button>' +
    '</div></div></div>';
}

/* ---------- Events ---------- */

const appRoot = document.getElementById('app');

appRoot.addEventListener('click', function (e) {
  const el = e.target.closest('[data-action]');
  if (!el) return;
  const action = el.dataset.action;
  if (action === 'noop') return;
  handleAction(action, el.dataset);
});

appRoot.addEventListener('input', function (e) {
  const el = e.target;
  const key = el.dataset.input;
  if (!key) return;
  setInputValue(key, el.value);
});

appRoot.addEventListener('change', function (e) {
  const el = e.target;
  const key = el.dataset.change;
  if (!key) return;
  handleChange(key, el);
});

function handleAction(action, ds) {
  switch (action) {
    case 'nav-tab':
      ui.page = null;
      ui.tab = ds.tab;
      if (ds.tab === 'transfer' && (!ui.flow || ui.flowContext !== 'tab')) openFlow('send', 'tab');
      hapticTap('tap');
      render();
      break;
    case 'open-page':
      ui.allFilterID = null;
      ui.allSearch = '';
      ui.page = { type: ds.type, id: ds.id || null };
      hapticTap('tap');
      render();
      break;
    case 'open-account':
      ui.page = { type: 'account', id: ds.id };
      hapticTap('tap');
      render();
      break;
    case 'back':
      ui.page = null;
      render();
      break;
    case 'open-flow':
      openFlow(ds.mode, 'modal');
      ui.modal = { type: 'transfer-flow', data: {} };
      hapticTap('tap');
      render();
      break;
    case 'open-modal':
      hapticTap('tap');
      openModal(ds.type, ds);
      break;
    case 'modal-close':
      ui.modal = null;
      render();
      break;
    case 'toggle-hide':
      store.hideBalances = !store.hideBalances;
      store.commit();
      hapticTap('tap');
      break;
    case 'remove-recurring':
      store.removeRecurringTransfer(ds.id);
      break;
    case 'freeze-card':
      store.toggleFreeze(ds.id);
      hapticTap('freeze');
      break;
    case 'toggle-reveal':
      ui.revealedCardID = ui.revealedCardID === ds.id ? null : ds.id;
      hapticTap('tap');
      render();
      break;
    case 'flow-key':
      keypadPress(ds.key);
      break;
    case 'flow-account':
      ui.flow.toAccountID = ds.id;
      hapticTap('tap');
      render();
      break;
    case 'flow-continue':
      flowContinue();
      break;
    case 'flow-back':
      ui.flow.step = 'amount';
      render();
      break;
    case 'flow-freq':
      ui.flow.repeatFrequency = ds.value;
      render();
      break;
    case 'flow-confirm':
      flowConfirm();
      break;
    case 'flow-done':
      flowDone();
      break;
    case 'tx-save':
      txSave();
      break;
    case 'schedule-frequency':
      ui.modal.data.frequency = ds.value;
      hapticTap('tap');
      render();
      break;
    case 'schedule-submit':
      scheduleSubmit();
      break;
    case 'goal-emoji':
      ui.modal.data.emoji = ds.value;
      hapticTap('tap');
      render();
      break;
    case 'goal-color':
      ui.modal.data.colorHex = ds.value;
      hapticTap('tap');
      render();
      break;
    case 'goal-create':
      goalCreate();
      break;
    case 'contribute-account':
      ui.modal.data.accountID = ds.id;
      hapticTap('tap');
      render();
      break;
    case 'contribute-chip':
      ui.modal.data.amount = String((parseFloat(ui.modal.data.amount) || 0) + parseFloat(ds.value));
      hapticTap('tap');
      render();
      break;
    case 'contribute-submit':
      contributeSubmit();
      break;
    case 'budget-save':
      budgetSave();
      break;
    case 'notif-read':
      store.markNotificationRead(ds.id);
      hapticTap('tap');
      break;
    case 'notif-mark-all':
      store.markAllNotificationsRead();
      hapticTap('success');
      break;
    case 'insights-month':
      if (ds.dir === '1' && ui.insightsOffset >= 0) break;
      ui.insightsOffset += parseInt(ds.dir, 10);
      hapticTap('tap');
      render();
      break;
    case 'export-month':
      exportMonthShift(parseInt(ds.dir, 10));
      break;
    case 'export-download':
      exportDownload();
      break;
    case 'reset-do':
      clearSyncAuth();
      ui.modal = null;
      store.resetAllData();
      hapticTap('freeze');
      showToast('All data erased');
      break;
    case 'sign-out':
      ui.signedInName = '';
      ui.signedInEmail = '';
      localStorage.removeItem('signedInName');
      localStorage.removeItem('signedInEmail');
      ui.gateMode = null;
      ui.signin = { name: '', email: '', password: '', confirm: '' };
      ui.page = null;
      render();
      break;
    case 'gate-switch':
      ui.gateMode = ui.gateMode === 'create' ? 'signin' : 'create';
      render();
      break;
    case 'gate-submit':
      gateSubmit(ds.mode);
      break;
    case 'all-filter':
      ui.allFilterID = ds.id || null;
      hapticTap('tap');
      renderFocusAware();
      break;
    case 'install-app':
      installApp();
      break;
    case 'copy-install-link':
      copyInstallLink();
      break;
    case 'tx-type':
      ui.modal.data.type = ds.value;
      hapticTap('tap');
      render();
      break;
    case 'add-tx-save':
      addTxSave();
      break;
    case 'tx-delete':
      txDelete();
      break;
    case 'account-save':
      accountSave();
      break;
    case 'account-delete':
      accountDelete();
      break;
    case 'sync-mode':
      ui.sync.mode = ds.value;
      hapticTap('tap');
      render();
      break;
    case 'sync-auth':
      syncAuthSubmit(ds.mode);
      break;
    case 'sync-push':
      syncPush().then(function (ok) { if (ok) { hapticTap('success'); showToast('Backed up to cloud'); if (ui.signedInName) render(); } });
      break;
    case 'sync-pull':
      syncPull().then(function (ok) { if (ok && ui.signedInName) render(); });
      break;
    case 'sync-signout':
      clearSyncAuth();
      hapticTap('tap');
      showToast('Signed out of cloud');
      render();
      break;
    default:
      break;
  }
}

function setInputValue(key, value) {
  switch (key) {
    case 'signin-name': ui.signin.name = value; break;
    case 'signin-email': ui.signin.email = value; break;
    case 'signin-password': ui.signin.password = value; break;
    case 'signin-confirm': ui.signin.confirm = value; break;
    case 'all-search': ui.allSearch = value; renderFocusAware(); break;
    case 'flow-note': ui.flow.note = value; break;
    case 'tx-merchant': ui.modal.data.merchant = value; break;
    case 'schedule-payee-name': ui.modal.data.newPayee = value; break;
    case 'schedule-amount': ui.modal.data.amount = value; break;
    case 'schedule-due': ui.modal.data.firstDue = value; break;
    case 'goal-name': ui.modal.data.name = value; break;
    case 'goal-target': ui.modal.data.target = value; break;
    case 'contribute-amount': ui.modal.data.amount = value; break;
    case 'budget-amount': ui.modal.data.amount = value; break;
    case 'tx-amount': ui.modal.data.amount = value; break;
    case 'tx-date': ui.modal.data.date = value; break;
    case 'account-name': ui.modal.data.name = value; break;
    case 'account-number': ui.modal.data.number = value; break;
    case 'account-opening': ui.modal.data.openingBalance = value; break;
    case 'sync-api-url': localStorage.setItem('sync-api', value); break;
    case 'sync-email': ui.sync.email = value; break;
    case 'sync-password': ui.sync.password = value; break;
    case 'sync-name': ui.sync.name = value; break;
    default: break;
  }
}

function handleChange(key, el) {
  switch (key) {
    case 'tx-account':
      ui.modal.data.accountId = el.value;
      break;
    case 'account-kind':
      ui.modal.data.kind = el.value;
      break;
    case 'account-iscard':
      ui.modal.data.isCard = el.checked;
      break;
    case 'account-setting': {
      const account = store.accountById(el.dataset.account);
      if (account) {
        account[el.dataset.setting] = el.checked;
        store.commit();
      }
      break;
    }
    case 'tx-category':
      ui.modal.data.category = el.value;
      break;
    case 'schedule-payee':
      ui.modal.data.payeeIndex = parseInt(el.value, 10);
      renderFocusAware();
      break;
    case 'schedule-account':
      ui.modal.data.accountID = el.value;
      break;
    case 'flow-from':
      ui.flow.fromID = el.value;
      renderFocusAware();
      break;
    case 'flow-repeat':
      ui.flow.repeatEnabled = el.checked;
      renderFocusAware();
      break;
    case 'contribute-repeat':
      ui.modal.data.repeat = el.value;
      renderFocusAware();
      break;
    case 'pref-hide-balances':
      store.hideBalances = el.checked;
      store.commit();
      break;
    default:
      break;
  }
}

/* ---------- Install (PWA) ---------- */

let deferredInstallPrompt = null;
window.addEventListener('beforeinstallprompt', function (e) {
  e.preventDefault();
  deferredInstallPrompt = e;
});
window.addEventListener('appinstalled', function () {
  deferredInstallPrompt = null;
  showToast('Yetties Bank installed');
  if (ui.signedInName) render();
});

function isStandalone() {
  return (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) ||
    window.navigator.standalone === true;
}

function installApp() {
  if (deferredInstallPrompt) {
    deferredInstallPrompt.prompt();
    deferredInstallPrompt.userChoice.then(function () { deferredInstallPrompt = null; });
  } else if (isStandalone()) {
    showToast('Yetties Bank is already installed');
  } else {
    ui.modal = { type: 'install', data: {} };
    render();
  }
}

function appURL() {
  if (window.location.protocol !== 'https:') {
    return 'https://yetties-bank.pages.dev';
  }
  return window.location.href.split('#')[0];
}

function appIsLocalOnly() {
  return !window.isSecureContext || (window.location.protocol !== 'https:' && window.location.protocol !== 'http:');
}

function installHTML() {
  let html = sheetHead('Install Yetties Bank', 'Add it to your home screen like a native app.');
  if (appIsLocalOnly()) {
    html += '<div class="flow-warning">⚠️ This copy runs inside the builder app, so its link only works here. Safari needs a hosted https copy — publish the project to GitHub Pages, then this sheet will show that link.</div>';
  }
  html += '<label class="form-label">Step 1 · Copy the app link</label>' +
    '<input class="input" readonly value="' + esc(appURL()) + '">' +
    '<button class="btn btn-primary btn-full" data-action="copy-install-link">📋 Copy link</button>' +
    '<label class="form-label">Step 2 · Open it in Safari</label>' +
    '<div class="sheet-footer-note">Paste the link into Safari on this iPhone.</div>' +
    '<label class="form-label">Step 3 · Add to Home Screen</label>' +
    '<div class="sheet-footer-note">In Safari, tap the Share button, then choose Add to Home Screen.</div>' +
    '<div class="sheet-footer-note">Launch Yetties Bank from your home screen — it runs standalone, keeps your sign-in, and works offline.</div>';
  return html;
}

function copyInstallLink() {
  const url = appURL();
  const done = function () {
    showToast('Link copied — open it in Safari');
    hapticTap('success');
  };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(url).then(done, function () { fallbackCopy(url); done(); });
  } else {
    fallbackCopy(url);
    done();
  }
}

function fallbackCopy(text) {
  const input = document.createElement('textarea');
  input.value = text;
  document.body.appendChild(input);
  input.select();
  try { document.execCommand('copy'); } catch (e) { /* copy not available */ }
  input.remove();
}

/* ---------- Cloud sync (Phase 1 backend) ---------- */

const SYNC_KEYS = { token: 'sync-token', user: 'sync-user', apiUrl: 'sync-api', lastBackup: 'sync-last-backup' };

function syncToken() { return localStorage.getItem(SYNC_KEYS.token) || ''; }

function syncUser() {
  try { return JSON.parse(localStorage.getItem(SYNC_KEYS.user)); }
  catch (e) { return null; }
}

function syncApiBase() {
  return (localStorage.getItem(SYNC_KEYS.apiUrl) || '').trim().replace(/\/+$/, '');
}

function syncSignedIn() { return !!syncToken() && !!syncUser(); }

function setSyncAuth(token, user) {
  localStorage.setItem(SYNC_KEYS.token, token);
  localStorage.setItem(SYNC_KEYS.user, JSON.stringify(user));
}

function clearSyncAuth() {
  localStorage.removeItem(SYNC_KEYS.token);
  localStorage.removeItem(SYNC_KEYS.user);
  localStorage.removeItem(SYNC_KEYS.lastBackup);
}

function lastBackupLabel() {
  const t = Number(localStorage.getItem(SYNC_KEYS.lastBackup));
  if (!t) return null;
  return 'Last backup ' + relativeLabel(t);
}

function snapshotPayload() {
  return {
    accounts: store.accounts,
    transactions: store.transactions,
    goals: store.goals,
    bills: store.bills,
    recurringTransfers: store.recurringTransfers,
    hideBalances: store.hideBalances,
    monthlyBudget: ui.monthlyBudget
  };
}

let syncBusy = false;

async function syncPush() {
  if (!syncSignedIn() || syncBusy) return false;
  const api = syncApiBase();
  if (!api) { showToast('Add your sync server URL in Profile first.', 'error'); hapticTap('error'); return false; }
  syncBusy = true;
  try {
    const res = await fetch(api + '/api/data', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + syncToken() },
      body: JSON.stringify(snapshotPayload())
    });
    const data = await res.json();
    if (!res.ok) { showToast(data.error || 'Backup failed.', 'error'); hapticTap('error'); return false; }
    localStorage.setItem(SYNC_KEYS.lastBackup, String(Date.now()));
    return true;
  } catch (e) {
    showToast('Couldn\'t reach the sync server.', 'error');
    hapticTap('error');
    return false;
  } finally {
    syncBusy = false;
  }
}

async function syncPull() {
  if (!syncSignedIn() || syncBusy) return false;
  const api = syncApiBase();
  if (!api) { showToast('Add your sync server URL in Profile first.', 'error'); hapticTap('error'); return false; }
  syncBusy = true;
  try {
    const res = await fetch(api + '/api/data', { headers: { 'Authorization': 'Bearer ' + syncToken() } });
    const data = await res.json();
    if (!res.ok) { showToast(data.error || 'Restore failed.', 'error'); hapticTap('error'); return false; }
    if (!data.data) { showToast('Nothing backed up yet.'); return false; }
    const s = data.data;
    store.accounts = Array.isArray(s.accounts) ? s.accounts : [];
    store.transactions = Array.isArray(s.transactions) ? s.transactions : [];
    store.goals = Array.isArray(s.goals) ? s.goals : [];
    store.bills = Array.isArray(s.bills) ? s.bills : [];
    store.recurringTransfers = Array.isArray(s.recurringTransfers) ? s.recurringTransfers : [];
    store.hideBalances = !!s.hideBalances;
    if (typeof s.monthlyBudget === 'number') {
      ui.monthlyBudget = s.monthlyBudget;
      localStorage.setItem('monthlyBudget', String(ui.monthlyBudget));
    }
    store.persist();
    store.emit();
    hapticTap('success');
    showToast('Restored from cloud');
    return true;
  } catch (e) {
    showToast('Couldn\'t reach the sync server.', 'error');
    return false;
  } finally {
    syncBusy = false;
  }
}

let syncPushTimer = null;
function scheduleSyncPush() {
  if (!syncSignedIn()) return;
  if (syncPushTimer) clearTimeout(syncPushTimer);
  syncPushTimer = setTimeout(async function () { await syncPush(); }, 2000);
}

async function syncAuthSubmit(mode) {
  const d = ui.sync;
  const email = (d.email || '').trim();
  const password = d.password || '';
  if (!email.includes('@') || !email.includes('.')) { showToast('Please enter a valid email address.', 'error'); hapticTap('error'); return; }
  if (password.length < 6) { showToast('Password must be at least 6 characters.', 'error'); hapticTap('error'); return; }
  const api = syncApiBase();
  if (!api) { showToast('Enter the sync server URL first.', 'error'); hapticTap('error'); return; }
  const payload = mode === 'signup'
    ? { email: email, password: password, name: d.name || '' }
    : { email: email, password: password };
  try {
    const res = await fetch(api + (mode === 'signup' ? '/api/signup' : '/api/login'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (!res.ok) { showToast(data.error || 'Sign in failed.', 'error'); hapticTap('error'); return; }
    setSyncAuth(data.token, data.user);
    d.password = '';
    hapticTap('success');
    showToast('Cloud sync ready — backups are automatic now');
    render();
    scheduleSyncPush();
  } catch (e) {
    showToast('Couldn\'t reach the sync server.', 'error');
    hapticTap('error');
  }
}

/* ---------- Init ---------- */

store.load();
store.onChange(function () { render(); scheduleSyncPush(); });
render();

if ('serviceWorker' in navigator && window.isSecureContext) {
  navigator.serviceWorker.register('./sw.js').catch(function () {
    /* offline support unavailable in this context */
  });
}