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
  'Transfers':         { icon: '📤', color: '4C8DF5', bg: 'E1E8FA' }
};

function categoryStyle(category) {
  return CATEGORY_STYLE[category] || { icon: '💳', color: '6B7280', bg: 'EDEFF2' };
}

/* ---------- Dates ---------- */

const DAY_MS = 24 * 60 * 60 * 1000;

function hoursAgo(h) { return Date.now() - h * 60 * 60 * 1000; }
function daysAgo(n, hours) { return Date.now() - (n * 24 + (hours || 0)) * 60 * 60 * 1000; }

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

const STORAGE_KEY = 'bank.state.v1';

const store = {
  accounts: [],
  transactions: [],
  contacts: [],
  goals: [],
  bills: [],
  recurringTransfers: [],
  notifications: [],
  virtualCards: [],
  hideBalances: false,
  roundUpEnabled: false,
  roundUpGoalID: null,
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
      this.goals = state.goals || this.seedGoals();
      this.bills = state.bills || this.seedBills();
      this.recurringTransfers = state.recurringTransfers || [];
      this.notifications = state.notifications || this.seedNotifications();
      this.virtualCards = state.virtualCards || [];
      this.hideBalances = !!state.hideBalances;
      this.roundUpEnabled = !!state.roundUpEnabled;
      this.roundUpGoalID = state.roundUpGoalID || null;
      this.processDueBills();
      this.processDueRecurringTransfers();
    } else {
      this.seed();
    }
  },

  /* ----- lookups & derived ----- */

  accountById(id) { return this.accounts.find(a => a.id === id) || null; },
  contactById(id) { return this.contacts.find(c => c.id === id) || null; },
  goalById(id) { return this.goals.find(g => g.id === id) || null; },

  totalBalance() { return this.accounts.reduce((sum, a) => sum + a.balance, 0); },

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

  updateTransaction(id, merchant, category) {
    const tx = this.transactions.find(t => t.id === id);
    if (!tx) return;
    const trimmed = merchant.trim();
    if (!trimmed) return;
    tx.merchant = trimmed;
    tx.category = category;
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
      from.balance -= amount;
      this.transactions.unshift({ id: uid(), accountId: fromID, merchant: contact.name,
        category: 'Transfers', amount: -amount, date: now });
      this.addNotification('Transfer sent', currencyString(amount) + ' to ' + contact.name, '📤', '4C8DF5');
      this.applyRoundUp(fromID, amount, now);
    } else if (toAccountID) {
      const to = this.accountById(toAccountID);
      if (!to) return;
      from.balance -= amount;
      to.balance += amount;
      this.transactions.unshift({ id: uid(), accountId: fromID, merchant: 'To ' + to.name,
        category: 'Internal transfer', amount: -amount, date: now });
      this.transactions.unshift({ id: uid(), accountId: to.id, merchant: 'From ' + from.name,
        category: 'Internal transfer', amount: amount, date: now });
      this.addNotification('Transfer completed', currencyString(amount) + ' moved to ' + to.name, '🔁', '4C8DF5');
    }
    this.commit();
  },

  sendETransfer(fromID, recipientName, handle, amount) {
    if (!(amount > 0)) return;
    const from = this.accountById(fromID);
    if (!from || from.balance < amount) return;
    const name = (recipientName || '').trim();
    const trimmedHandle = (handle || '').trim();
    if (!name || !trimmedHandle) return;

    from.balance -= amount;
    this.transactions.unshift({ id: uid(), accountId: fromID, merchant: name,
      category: 'Transfers', amount: -amount, date: Date.now() });

    const exists = this.contacts.some(c => c.handle.toLowerCase() === trimmedHandle.toLowerCase());
    if (!exists) {
      const palette = ['D96A7B', '5B7BD5', 'D08A3E', '4EA58B', '8E6FD8', 'F2762E'];
      let hash = 0;
      for (const ch of name) hash = (hash + ch.charCodeAt(0)) % 100000;
      this.contacts.push({ id: uid(), name: name, handle: trimmedHandle, colorHex: palette[hash % palette.length] });
    }

    this.addNotification('E-transfer sent',
      currencyString(amount) + ' to ' + name + ' · ' + trimmedHandle, '✈️', '4C8DF5');
    this.applyRoundUp(fromID, amount, Date.now());
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
    if (!goal || !account || account.balance < amount) return;
    account.balance -= amount;
    goal.saved += amount;
    this.transactions.unshift({ id: uid(), accountId: accountID,
      merchant: 'Saving for ' + goal.name, category: 'Internal transfer',
      amount: -amount, date: Date.now() });
    this.addNotification('Goal contribution',
      currencyString(amount) + ' added to ' + goal.name, '🎯', goal.colorHex);
    this.commit();
  },

  applyRoundUp(sourceAccountID, purchaseAmount, date) {
    if (!this.roundUpEnabled || !(purchaseAmount > 0) || !this.roundUpGoalID) return;
    const goal = this.goalById(this.roundUpGoalID);
    const account = this.accountById(sourceAccountID);
    if (!goal || !account || !account.isCard) return;
    const difference = Math.ceil(purchaseAmount) - purchaseAmount;
    if (difference < 0.01) return;
    account.balance -= difference;
    goal.saved += difference;
    this.transactions.unshift({ id: uid(), accountId: sourceAccountID,
      merchant: 'Round up — ' + goal.name, category: 'Round up',
      amount: -difference, date: date || Date.now() });
    this.persist();
  },

  /* ----- virtual cards ----- */

  addVirtualCard(sourceAccountID, limit) {
    const d = new Date();
    d.setFullYear(d.getFullYear() + 3);
    const expiry = String(d.getMonth() + 1).padStart(2, '0') + '/' + String(d.getFullYear() % 100).padStart(2, '0');
    let digits = '4';
    for (let i = 1; i < 16; i++) digits += Math.floor(Math.random() * 10);
    const card = { id: uid(), sourceAccountID: sourceAccountID, cardNumber: digits, expiry: expiry,
      cvc: String(100 + Math.floor(Math.random() * 900)), limit: limit, spent: 0,
      isFrozen: false, createdAt: Date.now() };
    this.virtualCards.unshift(card);
    this.commit();
    return card;
  },

  toggleVirtualCardFreeze(id) {
    const card = this.virtualCards.find(c => c.id === id);
    if (!card) return;
    card.isFrozen = !card.isFrozen;
    this.addNotification(card.isFrozen ? 'Virtual card frozen' : 'Virtual card unfrozen',
      '•••• ' + card.cardNumber.slice(-4), '❄️', '4C8DF5');
    this.commit();
  },

  spendOnVirtualCard(id, amount) {
    if (!(amount > 0)) return false;
    const card = this.virtualCards.find(c => c.id === id);
    if (!card) return false;
    const account = this.accountById(card.sourceAccountID);
    if (!account) return false;
    if (card.isFrozen) return false;
    if (card.limit - card.spent < amount - 0.001) return false;
    card.spent += amount;
    account.balance -= amount;
    this.transactions.unshift({ id: uid(), accountId: account.id,
      merchant: 'Online purchase', category: 'Virtual card', amount: -amount, date: Date.now() });
    this.addNotification('Virtual card purchase',
      currencyString(amount) + ' · •••• ' + card.cardNumber.slice(-4), '✨', '0E7C5A');
    this.commit();
    return true;
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
      const account = this.accountById(bill.accountId);
      if (!account) continue;
      let guard = 0;
      while (bill.nextDue <= now && guard < 60) {
        account.balance -= bill.amount;
        this.transactions.unshift({ id: uid(), accountId: bill.accountId,
          merchant: bill.payee, category: 'Bills', amount: -bill.amount, date: bill.nextDue });
        this.addNotification('Bill paid', currencyString(bill.amount) + ' to ' + bill.payee, '🧾', '4C8DF5');
        this.applyRoundUp(bill.accountId, bill.amount, bill.nextDue);
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
        if (recurring.kind === 'transfer') {
          this.performTransfer(recurring.fromAccountID, recurring.toContactID,
            recurring.toAccountID, recurring.amount);
        } else if (recurring.goalID) {
          this.contribute(recurring.goalID, recurring.fromAccountID, recurring.amount);
        }
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

  resetDemoData() {
    this.seed();
    this.emit();
  },

  /* ----- persistence & seed ----- */

  persist() {
    const state = {
      accounts: this.accounts, transactions: this.transactions, contacts: this.contacts,
      goals: this.goals, bills: this.bills, recurringTransfers: this.recurringTransfers,
      notifications: this.notifications, virtualCards: this.virtualCards,
      hideBalances: this.hideBalances, roundUpEnabled: this.roundUpEnabled,
      roundUpGoalID: this.roundUpGoalID
    };
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (e) { /* storage full */ }
  },

  seed() {
    const checkingID = uid(), savingsID = uid(), travelID = uid(), creditID = uid();
    this.accounts = [
      { id: checkingID, name: 'Everyday', kind: 'Checking', number: '•• 4821', balance: 4820.55,
        colorHex: '1C2540', isCard: true, cardNumber: '4293881045214821', expiry: '04/29',
        isFrozen: false, contactless: true, onlinePayments: true, atmWithdrawals: true },
      { id: savingsID, name: 'High-Yield Savings', kind: 'Savings', number: '•• 9034', balance: 12300.00,
        colorHex: '0E6B4F', isCard: false, cardNumber: '', expiry: '',
        isFrozen: false, contactless: false, onlinePayments: true, atmWithdrawals: false },
      { id: travelID, name: 'Travel', kind: 'Prepaid card', number: '•• 7712', balance: 340.20,
        colorHex: '35507B', isCard: true, cardNumber: '5412751234567712', expiry: '09/28',
        isFrozen: false, contactless: true, onlinePayments: true, atmWithdrawals: true },
      { id: creditID, name: 'Mastercard Credit', kind: 'Credit card', number: '•• 2841', balance: 1250.00,
        colorHex: '802536', isCard: true, cardNumber: '5191286745092841', expiry: '07/29',
        isFrozen: false, contactless: true, onlinePayments: true, atmWithdrawals: true }
    ];

    this.contacts = [
      { id: uid(), name: 'Maya Chen', handle: '@maya', colorHex: 'D96A7B' },
      { id: uid(), name: 'Dev Patel', handle: '@devp', colorHex: '5B7BD5' },
      { id: uid(), name: 'Sofia Rossi', handle: '@sofia', colorHex: 'D08A3E' },
      { id: uid(), name: 'Jonah Blake', handle: '@jonah', colorHex: '4EA58B' }
    ];

    this.transactions = [
      { id: uid(), accountId: checkingID, merchant: 'Blue Bottle Coffee', category: 'Food & drink', amount: -4.80, date: daysAgo(0, 2) },
      { id: uid(), accountId: checkingID, merchant: 'Uber', category: 'Transport', amount: -18.40, date: daysAgo(1, 4) },
      { id: uid(), accountId: travelID, merchant: 'Airbnb', category: 'Travel', amount: -212.00, date: daysAgo(2, 1) },
      { id: uid(), accountId: checkingID, merchant: 'Salary — Meridian Labs', category: 'Income', amount: 3450.00, date: daysAgo(3, 6) },
      { id: uid(), accountId: checkingID, merchant: 'Whole Foods Market', category: 'Groceries', amount: -86.25, date: daysAgo(3, 9) },
      { id: uid(), accountId: travelID, merchant: 'Metro Card Top-up', category: 'Transport', amount: -30.00, date: daysAgo(4, 3) },
      { id: uid(), accountId: checkingID, merchant: 'Spotify', category: 'Subscriptions', amount: -10.99, date: daysAgo(4, 7) },
      { id: uid(), accountId: savingsID, merchant: 'Monthly transfer in', category: 'Internal transfer', amount: 500.00, date: daysAgo(5, 2) },
      { id: uid(), accountId: travelID, merchant: 'Café de Paris', category: 'Food & drink', amount: -14.60, date: daysAgo(5, 5) },
      { id: uid(), accountId: travelID, merchant: 'Refund — Booking.com', category: 'Refund', amount: 45.00, date: daysAgo(6, 2) },
      { id: uid(), accountId: checkingID, merchant: 'Apple Store', category: 'Electronics', amount: -249.00, date: daysAgo(6, 8) },
      { id: uid(), accountId: checkingID, merchant: 'ATM Withdrawal', category: 'Cash', amount: -100.00, date: daysAgo(7, 3) },
      { id: uid(), accountId: savingsID, merchant: 'Interest', category: 'Income', amount: 21.40, date: daysAgo(8, 1) }
    ];

    this.goals = this.seedGoals();
    this.bills = this.seedBills();
    this.notifications = this.seedNotifications();
    this.virtualCards = [];
    this.hideBalances = false;
    this.roundUpEnabled = false;
    this.roundUpGoalID = null;
    this.persist();
  },

  seedGoals() {
    return [
      { id: uid(), name: 'Japan trip', emoji: '✈️', colorHex: '3BB273', target: 5000, saved: 2150 },
      { id: uid(), name: 'New laptop', emoji: '💻', colorHex: 'F2762E', target: 1500, saved: 1000 },
      { id: uid(), name: 'Emergency fund', emoji: '🚨', colorHex: '4C8DF5', target: 2000, saved: 500 },
      { id: uid(), name: 'Home deposit', emoji: '🏠', colorHex: '8E6FD8', target: 2500, saved: 2000 },
      { id: uid(), name: 'New phone', emoji: '📱', colorHex: '1FA97C', target: 700, saved: 700 }
    ];
  },

  seedBills() {
    const checkingID = this.accounts[0].id;
    return [
      { id: uid(), payee: 'Riverside Apartments', amount: 1650.00, accountId: checkingID,
        frequency: 'Monthly', nextDue: Date.now() + 2 * DAY_MS },
      { id: uid(), payee: 'Spotify Premium', amount: 10.99, accountId: checkingID,
        frequency: 'Monthly', nextDue: Date.now() + 5 * DAY_MS },
      { id: uid(), payee: 'City Gym', amount: 12.50, accountId: checkingID,
        frequency: 'Weekly', nextDue: Date.now() + 3 * DAY_MS }
    ];
  },

  seedNotifications() {
    return [
      { id: uid(), title: 'Salary deposited', message: '+ $3,450.00 from Meridian Labs',
        icon: '💰', colorHex: '0E7C5A', date: hoursAgo(20), isRead: false },
      { id: uid(), title: 'Transfer completed', message: '$30.00 moved to Travel',
        icon: '🔁', colorHex: '4C8DF5', date: hoursAgo(52), isRead: true },
      { id: uid(), title: 'Refund received', message: '$45.00 from Booking.com',
        icon: '↩️', colorHex: '0E7C5A', date: hoursAgo(70), isRead: true },
      { id: uid(), title: 'Card frozen', message: 'Everyday · •••• 4821',
        icon: '❄️', colorHex: '4C8DF5', date: hoursAgo(96), isRead: true }
    ];
  }
};

function csvEscaped(field) {
  const value = String(field);
  if (value.indexOf(',') === -1 && value.indexOf('"') === -1 && value.indexOf('\n') === -1) return value;
  return '"' + value.replace(/"/g, '""') + '"';
}