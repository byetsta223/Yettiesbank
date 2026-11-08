'use strict';

/* Data model & store — a port of Models.swift (BankStore) with
   localStorage persistence instead of UserDefaults. Dates are epoch ms. */

/* ---------- Shared helpers ---------- */

function uid() {
  if (window.crypto && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  return 'id-' + Math.random().toString(36).slice(2, 10) + '-' + Date.now().toString(36);
}

function esc(text) {
  return String(text).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  });
}

function currencyString(value, opts) {
  opts = opts || {};
  const showSign = opts.showSign === true;
  const cents = opts.cents !== false;
  const formatter = new Intl.NumberFormat('en-US', {
    style: 'currency', currency: 'USD',
    minimumFractionDigits: cents ? 2 : 0, maximumFractionDigits: cents ? 2 : 0
  });
  const base = formatter.format(Math.abs(value));
  if (showSign) return (value < 0 ? '-' : '+') + base;
  return base;
}

const FIXED_CATEGORIES = [
  'Groceries', 'Food & drink', 'Transport', 'Subscriptions',
  'Electronics', 'Travel', 'Cash', 'Bills', 'Income',
  'Refund', 'Internal transfer'
];

const CATEGORY_STYLE = {
  'Groceries':         { icon: '🛒', color: '2FA36B', bg: 'DFF3E7' },
  'Food & drink':      { icon: '🍽️', color: 'E0784A', bg: 'FBE9DE' },
  'Transport':         { icon: '🚗', color: '3F6BD6', bg: 'E1E8FA' },
  'Subscriptions':     { icon: '📺', color: '8E6FD8', bg: 'ECE6FA' },
  'Electronics':       { icon: '🖥️', color: '6B7280', bg: 'EDEFF2' },
  'Travel':            { icon: '✈️', color: '4EA58B', bg: 'E2F3EC' },
  'Cash':              { icon: '💵', color: 'D08A3E', bg: 'FBEFDF' },
  'Bills':             { icon: '🧾', color: '4C8DF5', bg: 'E1E8FA' },
  'Income':            { icon: '💰', color: '0E7C5A', bg: 'E2F3EC' },
  'Refund':            { icon: '↩️', color: '0E7C5A', bg: 'E2F3EC' },
  'Round up':          { icon: '⬆️', color: '0E7C5A', bg: 'E2F3EC' },
  'Virtual card':      { icon: '✨', color: '0E7C5A', bg: 'E2F3EC' },
  'Internal transfer': { icon: '🔁', color: '4C8DF5', bg: 'E1E8FA' },
  'Transfers':         { icon: '📤', color: '4C8DF5', bg: 'E1E8FA' },
  'E-Transfer':        { icon: '💸', color: '3F6BD6', bg: 'E1E8FA' }
};

function categoryStyle(category) {
  return CATEGORY_STYLE[category] || { icon: '💳', color: '6B7280', bg: 'EDEFF2' };
}

/* ---------- Dates ---------- */

const DAY_MS = 24 * 60 * 60 * 1000;

function startOfDay(ms) { const d = new Date(ms); d.setHours(0, 0, 0, 0); return d.getTime(); }

function dayLabel(ms) {
  const today = startOfDay(Date.now());
  const day = startOfDay(ms);
  if (day === today) return 'Today';
  if (day === today - DAY_MS) return 'Yesterday';
  return new Date(ms).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' });
}

function dueLabel(ms) {
  return new Date(ms).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
}

function relativeLabel(ms) {
  const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });
  const diffMinutes = Math.round((Date.now() - ms) / 60000);
  if (Math.abs(diffMinutes) < 60) return rtf.format(-diffMinutes, 'minute');
  const diffHours = Math.round((Date.now() - ms) / 3600000);
  if (Math.abs(diffHours) < 24) return rtf.format(-diffHours, 'hour');
  const diffDays = Math.round((Date.now() - ms) / DAY_MS);
  if (Math.abs(diffDays) < 30) return rtf.format(-diffDays, 'day');
  return rtf.format(-Math.round(diffDays / 30), 'month');
}

function monthInterval(ms) {
  const d = new Date(ms);
  const start = new Date(d.getFullYear(), d.getMonth(), 1).getTime();
  const end = new Date(d.getFullYear(), d.getMonth() + 1, 1).getTime();
  return [start, end];
}

function addMonths(ms, count) {
  const d = new Date(ms);
  return new Date(d.getFullYear(), d.getMonth() + count, d.getDate()).getTime();
}

function nextDueAfter(ms, frequency) {
  if (frequency === 'Weekly') return ms + 7 * DAY_MS;
  const d = new Date(ms);
  return new Date(d.getFullYear(), d.getMonth() + 1, d.getDate()).getTime();
}

function isoToDate(iso) {
  if (!iso) return Date.now();
  return new Date(iso + 'T12:00:00').getTime();
}

/* ---------- Card helpers ---------- */

function maskedCardNumber(cardNumber) {
  if (!cardNumber || cardNumber.length < 4) return '•••• 0000';
  return '•••• ' + cardNumber.slice(-4);
}

function formatCardNumber(cardNumber) {
  const digits = String(cardNumber || '').slice(0, 16);
  return digits.replace(/(.{4})/g, '$1 ').trim();
}

/* ---------- Store ---------- */

const STORAGE_KEY = 'bank.state.v2';

const store = {
  accounts: [],
  transactions: [],
  contacts: [],
  goals: [],
  bills: [],
  recurringTransfers: [],
  notifications: [],
  hideBalances: false,
  _listeners: [],

  onChange(fn) { this._listeners.push(fn); },
  emit() { for (const fn of this._listeners) fn(); },
  commit() { this.persist(); this.emit(); },

  load() {
    let state = null;
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) state = JSON.parse(raw);
    } catch (e) { state = null; }

    if (state && Array.isArray(state.accounts) && state.accounts.length) {
      this.accounts = state.accounts;
      this.transactions = state.transactions || [];
      this.contacts = state.contacts || [];
      this.goals = state.goals || [];
      this.bills = state.bills || [];
      this.recurringTransfers = state.recurringTransfers || [];
      this.notifications = state.notifications || [];
      this.hideBalances = !!state.hideBalances;
      this.processDueBills();
      this.processDueRecurringTransfers();
    } else {
      this.seed();
    }
    try { localStorage.removeItem('bank.state.v1'); } catch (e) { /* old demo data cleanup */ }
  },

  /* ----- lookups & derived ----- */

  accountById(id) { return this.accounts.find(a => a.id === id) || null; },
  contactById(id) { return this.contacts.find(c => c.id === id) || null; },
  goalById(id) { return this.goals.find(g => g.id === id) || null; },

  balanceOf(account) {
    if (!account) return 0;
    const opening = typeof account.openingBalance === 'number' ? account.openingBalance : account.balance;
    let sum = opening;
    for (const tx of this.transactions) {
      if (tx.accountId === account.id) sum += tx.amount;
    }
    return sum;
  },

  totalBalance() { return this.accounts.reduce((sum, a) => sum + this.balanceOf(a), 0); },

  transactionsFor(accountID) {
    const list = accountID
      ? this.transactions.filter(t => t.accountId === accountID)
      : this.transactions.slice();
    return list.sort((a, b) => b.date - a.date);
  },

  unreadNotificationCount() { return this.notifications.filter(n => !n.isRead).length; },

  editorCategories() {
    const extras = [];
    for (const tx of this.transactions) {
      if (!FIXED_CATEGORIES.includes(tx.category) && !extras.includes(tx.category)) extras.push(tx.category);
    }
    extras.sort();
    return FIXED_CATEGORIES.concat(extras);
  },

  /* ----- transactions ----- */

  updateTransaction(id, merchant, category, amount) {
    const tx = this.transactions.find(t => t.id === id);
    if (!tx) return;
    const trimmed = merchant.trim();
    if (!trimmed) return;
    tx.merchant = trimmed;
    tx.category = category;
    if (typeof amount === 'number' && amount !== 0) tx.amount = amount;
    this.commit();
  },

  /* ----- accounts ----- */

  addAccount(data) {
    const palette = ['1C2540', '0E6B4F', '35507B', '802536', '4EA58B', '8E6FD8', 'D08A3E', 'D96A7B'];
    const account = {
      id: uid(),
      name: (data.name || '').trim() || 'Account',
      kind: data.kind || 'Checking',
      number: data.number || '',
      openingBalance: parseFloat(data.openingBalance) || 0,
      balance: parseFloat(data.openingBalance) || 0,
      colorHex: data.colorHex || palette[this.accounts.length % palette.length],
      isCard: !!data.isCard,
      cardNumber: data.cardNumber || '',
      expiry: data.expiry || '',
      isFrozen: false,
      contactless: !!data.contactless,
      onlinePayments: !!data.onlinePayments,
      atmWithdrawals: !!data.atmWithdrawals
    };
    this.accounts.push(account);
    this.commit();
    return account;
  },

  updateAccount(id, patch) {
    const account = this.accountById(id);
    if (!account) return;
    if (typeof patch.name === 'string' && patch.name.trim()) account.name = patch.name.trim();
    if (patch.kind) account.kind = patch.kind;
    if (typeof patch.number === 'string') account.number = patch.number;
    if (typeof patch.openingBalance === 'number') {
      account.openingBalance = patch.openingBalance;
      account.balance = patch.openingBalance;
    }
    if (typeof patch.isCard === 'boolean') account.isCard = patch.isCard;
    if (typeof patch.cardNumber === 'string') account.cardNumber = patch.cardNumber;
    if (typeof patch.expiry === 'string') account.expiry = patch.expiry;
    this.commit();
  },

  deleteAccount(id) {
    this.accounts = this.accounts.filter(a => a.id !== id);
    this.transactions = this.transactions.filter(t => t.accountId !== id);
    this.bills = this.bills.filter(b => b.accountId !== id);
    this.commit();
  },

  /* ----- transactions ----- */

  addTransaction(data) {
    const account = this.accountById(data.accountId);
    if (!account) return;
    const amount = parseFloat(data.amount);
    if (!(amount > 0)) return;
    const signed = data.type === 'income' ? amount : -amount;
    this.transactions.unshift({
      id: uid(),
      accountId: data.accountId,
      merchant: (data.merchant || '').trim() || 'Untitled',
      category: data.category || 'Uncategorised',
      amount: signed,
      date: data.date || Date.now()
    });
    this.commit();
  },

  deleteTransaction(id) {
    this.transactions = this.transactions.filter(t => t.id !== id);
    this.commit();
  },

  /* ----- accounts / cards ----- */

  toggleFreeze(id) {
    const account = this.accountById(id);
    if (!account) return;
    account.isFrozen = !account.isFrozen;
    this.addNotification(account.isFrozen ? 'Card unfrozen' : 'Card frozen',
      account.name + ' · ' + maskedCardNumber(account.cardNumber),
      '❄️', '4C8DF5');
    this.commit();
  },

  /* ----- transfers ----- */

  performTransfer(fromID, toContactID, toAccountID, amount) {
    if (!(amount > 0)) return;
    const from = this.accountById(fromID);
    if (!from) return;
    const now = Date.now();

    const contact = toContactID ? this.contactById(toContactID) : null;
    if (contact) {
      this.transactions.unshift({ id: uid(), accountId: fromID, merchant: contact.name,
        category: 'Transfers', amount: -amount, date: now });
      this.addNotification('Transfer sent', currencyString(amount) + ' to ' + contact.name, '📤', '4C8DF5');
    } else if (toAccountID) {
      const to = this.accountById(toAccountID);
      if (!to || to.id === from.id) return;
      this.transactions.unshift({ id: uid(), accountId: fromID, merchant: 'To ' + to.name,
        category: 'Internal transfer', amount: -amount, date: now });
      this.transactions.unshift({ id: uid(), accountId: to.id, merchant: 'From ' + from.name,
        category: 'Internal transfer', amount: amount, date: now });
      this.addNotification('Transfer completed', currencyString(amount) + ' moved to ' + to.name, '🔁', '4C8DF5');
    }
    this.commit();
  },

  performETransfer(fromID, recipientName, recipientEmail, amount) {
    if (!(amount > 0)) return;
    const from = this.accountById(fromID);
    if (!from || !recipientName) return;
    const now = Date.now();
    this.transactions.unshift({ id: uid(), accountId: fromID,
      merchant: 'e-Transfer · ' + recipientName,
      category: 'E-Transfer', amount: -amount, date: now });
    if (recipientEmail) {
      const known = this.contacts.some(c => (c.email || '') === recipientEmail);
      if (!known) this.contacts.push({ id: uid(), name: recipientName, email: recipientEmail });
    }
    this.addNotification('E-Transfer sent',
      currencyString(amount) + ' sent to ' + recipientName +
      (recipientEmail ? ' (' + recipientEmail + ')' : '') + '.', '💸', '3F6BD6');
    this.commit();
  },

  /* ----- goals ----- */

  addGoal(name, emoji, colorHex, target) {
    this.goals.push({ id: uid(), name: name, emoji: emoji, colorHex: colorHex, target: target, saved: 0 });
    this.commit();
  },

  contribute(goalID, accountID, amount) {
    if (!(amount > 0)) return;
    const goal = this.goalById(goalID);
    const account = this.accountById(accountID);
    if (!goal || !account || this.balanceOf(account) < amount) return;
    goal.saved += amount;
    this.transactions.unshift({ id: uid(), accountId: accountID,
      merchant: 'Saving for ' + goal.name, category: 'Internal transfer',
      amount: -amount, date: Date.now() });
    this.addNotification('Goal contribution',
      currencyString(amount) + ' added to ' + goal.name, '🎯', goal.colorHex);
    this.commit();
  },

  /* ----- bills ----- */

  addBill(payee, amount, accountID, frequency, firstDue) {
    this.bills.push({ id: uid(), payee: payee, amount: amount, accountId: accountID,
      frequency: frequency, nextDue: firstDue });
    this.commit();
    this.processDueBills();
  },

  removeBill(id) {
    this.bills = this.bills.filter(b => b.id !== id);
    this.commit();
  },

  processDueBills() {
    const now = Date.now();
    let changed = false;
    for (const bill of this.bills) {
      if (!this.accountById(bill.accountId)) continue;
      let guard = 0;
      while (bill.nextDue <= now && guard < 60) {
        this.addNotification('Bill due', currencyString(bill.amount) + ' to ' + bill.payee, '🧾', '4C8DF5');
        bill.nextDue = nextDueAfter(bill.nextDue, bill.frequency);
        guard++;
        changed = true;
      }
    }
    if (changed) this.persist();
  },

  /* ----- recurring transfers ----- */

  addRecurringTransfer(kind, title, fromAccountID, opts) {
    opts = opts || {};
    if (!(opts.amount > 0) || !this.accountById(fromAccountID)) return;
    const trimmed = (title || '').trim();
    if (!trimmed) return;
    const frequency = opts.frequency || 'Monthly';
    this.recurringTransfers.push({ id: uid(), kind: kind, title: trimmed,
      fromAccountID: fromAccountID,
      toContactID: opts.toContactID || null, toAccountID: opts.toAccountID || null,
      goalID: opts.goalID || null, amount: opts.amount, frequency: frequency,
      nextDue: nextDueAfter(Date.now(), frequency) });
    this.commit();
  },

  removeRecurringTransfer(id) {
    this.recurringTransfers = this.recurringTransfers.filter(r => r.id !== id);
    this.commit();
  },

  processDueRecurringTransfers() {
    const now = Date.now();
    let changed = false;
    for (const recurring of this.recurringTransfers) {
      let guard = 0;
      while (recurring.nextDue <= now && guard < 60) {
        const due = recurring.nextDue;
        this.addNotification('Scheduled', recurring.title + ' · ' + currencyString(recurring.amount),
          recurring.kind === 'goal' ? '🎯' : '🔁', '4C8DF5');
        recurring.nextDue = nextDueAfter(due, recurring.frequency);
        guard++;
        changed = true;
      }
    }
    if (changed) this.persist();
  },

  /* ----- notifications ----- */

  markNotificationRead(id) {
    const n = this.notifications.find(x => x.id === id);
    if (n && !n.isRead) { n.isRead = true; this.commit(); }
  },

  markAllNotificationsRead() {
    for (const n of this.notifications) n.isRead = true;
    this.commit();
  },

  addNotification(title, message, icon, colorHex) {
    this.notifications.unshift({ id: uid(), title: title, message: message,
      icon: icon || '🔔', colorHex: colorHex || '1C2540', date: Date.now(), isRead: false });
    if (this.notifications.length > 60) this.notifications.length = 60;
    this.persist();
  },

  /* ----- statement export ----- */

  statementCSV(accountID, monthMs) {
    const interval = monthInterval(monthMs);
    const rows = ['Date,Merchant,Category,Amount'];
    const monthTransactions = this.transactionsFor(accountID)
      .filter(t => t.date >= interval[0] && t.date < interval[1])
      .sort((a, b) => a.date - b.date);
    for (const tx of monthTransactions) {
      rows.push(new Date(tx.date).toISOString().slice(0, 10) + ',' +
        csvEscaped(tx.merchant) + ',' + csvEscaped(tx.category) + ',' + tx.amount.toFixed(2));
    }
    return rows.join('\n');
  },

  resetAllData() {
    this.seed();
    this.emit();
  },

  /* ----- persistence & seed ----- */

  persist() {
    const state = {
      accounts: this.accounts, transactions: this.transactions, contacts: this.contacts,
      goals: this.goals, bills: this.bills, recurringTransfers: this.recurringTransfers,
      notifications: this.notifications,
      hideBalances: this.hideBalances
    };
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (e) { /* storage full */ }
  },

  seed() {
    this.accounts = [];
    this.transactions = [];
    this.contacts = [];
    this.goals = [];
    this.bills = [];
    this.recurringTransfers = [];
    this.notifications = [];
    this.hideBalances = false;
    this.persist();
  }
};

function csvEscaped(field) {
  const value = String(field);
  if (value.indexOf(',') === -1 && value.indexOf('"') === -1 && value.indexOf('\n') === -1) return value;
  return '"' + value.replace(/"/g, '""') + '"';
}