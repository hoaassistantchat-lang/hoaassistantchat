/**
 * HOA Assistant — Embeddable Chat Widget
 *
 * Usage:
 *   <script src="https://your-server.com/chat-widget.js"
 *           data-api-url="https://your-server.com"
 *           data-api-key="wk_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
 *           data-company="Your Company Name"
 *           data-primary-color="#2563eb"
 *           data-position="right">
 *   </script>
 *
 * Configuration attributes:
 *   data-api-url       — Base URL of the HOA Assistant API (required)
 *   data-api-key       — Widget API key issued by the HOA admin (required for /api/public/* calls)
 *   data-company       — Company name displayed in the header (default: "HOA Assistant")
 *   data-primary-color — Widget accent color (default: #2563eb)
 *   data-position      — "right" or "left" (default: right)
 */
(function () {
  'use strict';

  // ─── Configuration ───────────────────────────────────────────
  const script = document.currentScript;
  const CONFIG = {
    apiUrl: (script && script.getAttribute('data-api-url')) || window.location.origin,
    apiKey: (script && script.getAttribute('data-api-key')) || '',
    company: (script && script.getAttribute('data-company')) || 'HOA Assistant',
    primaryColor: (script && script.getAttribute('data-primary-color')) || '#2563eb',
    position: (script && script.getAttribute('data-position')) || 'right',
  };

  const STORAGE_KEY = 'hoa_widget_session';

  // ─── State ───────────────────────────────────────────────────
  let state = {
    open: false,
    step: 'community',      // 'community' | 'chat'
    communities: [],
    selectedCommunity: null,
    sessionId: loadSession()?.sessionId ?? null,
    messages: [],
    loading: false,
    visitorFirstName: '',
    visitorLastName: '',
    visitorAccountNumber: '',
    visitorEmail: '',
    visitorPhone: '',
    visitorQuestion: '',
    collectingContact: false,
    dropdownOpen: false,
    dropdownSearch: '',
    dropdownPickedId: null,
  };

  function loadSession() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEY)); } catch { return null; }
  }
  function saveSession(data) {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(data)); } catch { /* ignore */ }
  }
  function clearSession() {
    try { localStorage.removeItem(STORAGE_KEY); } catch { /* ignore */ }
  }

  // ─── Styles ──────────────────────────────────────────────────
  const css = `
    :host { all: initial; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }

    * { box-sizing: border-box; margin: 0; padding: 0; }

    .hoa-widget-bubble {
      position: fixed; bottom: 24px; ${CONFIG.position}: 24px;
      width: 60px; height: 60px; border-radius: 50%;
      background: ${CONFIG.primaryColor}; color: #fff;
      display: flex; align-items: center; justify-content: center;
      cursor: pointer; box-shadow: 0 4px 20px rgba(0,0,0,.25);
      z-index: 999999; transition: transform .2s, box-shadow .2s;
      border: none;
    }
    .hoa-widget-bubble:hover { transform: scale(1.08); box-shadow: 0 6px 28px rgba(0,0,0,.3); }
    .hoa-widget-bubble svg { width: 28px; height: 28px; fill: #fff; }

    .hoa-widget-panel {
      position: fixed; bottom: 96px; ${CONFIG.position}: 24px;
      width: 380px; max-width: calc(100vw - 32px);
      height: 560px; max-height: calc(100vh - 120px);
      background: #fff; border-radius: 16px;
      box-shadow: 0 8px 40px rgba(0,0,0,.18);
      display: flex; flex-direction: column; overflow: hidden;
      z-index: 999998; animation: hoa-slide-up .25s ease;
    }
    @keyframes hoa-slide-up {
      from { opacity: 0; transform: translateY(16px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    /* Header */
    .hoa-header {
      background: ${CONFIG.primaryColor}; color: #fff;
      padding: 16px 20px; display: flex; align-items: center; gap: 12px;
      min-height: 64px;
    }
    .hoa-header-icon {
      width: 36px; height: 36px; border-radius: 50%; background: rgba(255,255,255,.2);
      display: flex; align-items: center; justify-content: center; flex-shrink: 0;
    }
    .hoa-header-icon svg { width: 20px; height: 20px; fill: #fff; }
    .hoa-header-text { flex: 1; }
    .hoa-header-title { font-size: 15px; font-weight: 600; }
    .hoa-header-sub { font-size: 12px; opacity: .85; margin-top: 2px; }
    .hoa-close {
      background: none; border: none; color: #fff; cursor: pointer;
      width: 32px; height: 32px; border-radius: 50%; display: flex;
      align-items: center; justify-content: center; transition: background .2s;
    }
    .hoa-close:hover { background: rgba(255,255,255,.2); }
    .hoa-close svg { width: 18px; height: 18px; fill: #fff; }

    /* Body */
    .hoa-body { flex: 1; overflow-y: auto; padding: 16px 16px 8px; display: flex; flex-direction: column; gap: 12px; }

    /* Community selector */
    .hoa-community-card {
      text-align: center; padding: 32px 20px;
      display: flex; flex-direction: column; align-items: center; gap: 16px;
    }
    .hoa-community-card h3 { font-size: 18px; color: #1e293b; font-weight: 600; }
    .hoa-community-card p { font-size: 14px; color: #64748b; line-height: 1.5; }

    /* Searchable dropdown */
    .hoa-dropdown { width: 100%; position: relative; }
    .hoa-dropdown-trigger {
      width: 100%; padding: 12px 16px; border-radius: 10px;
      border: 2px solid #e2e8f0; font-size: 14px; color: #1e293b;
      background: #fff; cursor: pointer; text-align: left;
      transition: border-color .2s; display: flex; align-items: center;
      justify-content: space-between; gap: 8px; font-family: inherit;
    }
    .hoa-dropdown-trigger:hover { border-color: #cbd5e1; }
    .hoa-dropdown-trigger.open {
      border-color: ${CONFIG.primaryColor};
      border-bottom-left-radius: 4px; border-bottom-right-radius: 4px;
    }
    .hoa-dropdown-placeholder { color: #94a3b8; }
    .hoa-dropdown-arrow { color: #94a3b8; transition: transform .2s; flex-shrink: 0; }
    .hoa-dropdown-trigger.open .hoa-dropdown-arrow { transform: rotate(180deg); }
    .hoa-dropdown-menu {
      position: absolute; top: 100%; left: 0; right: 0;
      background: #fff; border: 2px solid ${CONFIG.primaryColor};
      border-top: 1px solid #e2e8f0; border-radius: 0 0 10px 10px;
      overflow: hidden; z-index: 100;
      display: flex; flex-direction: column;
      box-shadow: 0 6px 16px rgba(0,0,0,.12);
    }
    .hoa-dropdown-search {
      padding: 10px 14px; border: none; border-bottom: 1px solid #e2e8f0;
      font-size: 13px; width: 100%; outline: none; font-family: inherit; color: #1e293b;
    }
    .hoa-dropdown-search::placeholder { color: #94a3b8; }
    .hoa-dropdown-list { overflow-y: auto; max-height: 180px; }
    .hoa-dropdown-item {
      padding: 10px 16px; font-size: 14px; cursor: pointer; color: #1e293b;
      transition: background .12s;
    }
    .hoa-dropdown-item:hover { background: ${CONFIG.primaryColor}12; }
    .hoa-dropdown-item.selected {
      background: ${CONFIG.primaryColor}18; color: ${CONFIG.primaryColor}; font-weight: 500;
    }
    .hoa-dropdown-empty { padding: 12px 16px; font-size: 13px; color: #94a3b8; text-align: center; }
    .hoa-btn {
      width: 100%; padding: 12px; border-radius: 10px; border: none;
      background: ${CONFIG.primaryColor}; color: #fff; font-size: 14px;
      font-weight: 600; cursor: pointer; transition: opacity .2s;
    }
    .hoa-btn:hover { opacity: .9; }
    .hoa-btn:disabled { opacity: .5; cursor: not-allowed; }

    /* Messages */
    .hoa-msg { display: flex; gap: 8px; max-width: 88%; animation: hoa-fade .2s ease; }
    @keyframes hoa-fade { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: translateY(0); } }
    .hoa-msg-bot { align-self: flex-start; }
    .hoa-msg-user { align-self: flex-end; flex-direction: row-reverse; }
    .hoa-msg-avatar {
      width: 30px; height: 30px; border-radius: 50%; flex-shrink: 0;
      display: flex; align-items: center; justify-content: center;
      font-size: 13px; font-weight: 600;
    }
    .hoa-msg-bot .hoa-msg-avatar { background: ${CONFIG.primaryColor}20; color: ${CONFIG.primaryColor}; }
    .hoa-msg-user .hoa-msg-avatar { background: #e2e8f0; color: #64748b; }
    .hoa-msg-bubble {
      padding: 10px 14px; border-radius: 14px; font-size: 14px;
      line-height: 1.5; word-break: break-word;
    }
    .hoa-msg-bot .hoa-msg-bubble { background: #f1f5f9; color: #1e293b; border-bottom-left-radius: 4px; }
    .hoa-msg-user .hoa-msg-bubble { background: ${CONFIG.primaryColor}; color: #fff; border-bottom-right-radius: 4px; }

    /* Typing indicator */
    .hoa-typing { display: flex; gap: 4px; padding: 10px 14px; background: #f1f5f9; border-radius: 14px; border-bottom-left-radius: 4px; align-self: flex-start; }
    .hoa-typing-dot {
      width: 8px; height: 8px; border-radius: 50%; background: #94a3b8;
      animation: hoa-bounce .6s infinite alternate;
    }
    .hoa-typing-dot:nth-child(2) { animation-delay: .2s; }
    .hoa-typing-dot:nth-child(3) { animation-delay: .4s; }
    @keyframes hoa-bounce { to { transform: translateY(-4px); opacity: .4; } }

    /* Contact form */
    .hoa-contact-form { display: flex; flex-direction: column; gap: 10px; padding: 8px 0; }
    .hoa-contact-label {
      font-size: 11px; font-weight: 600; color: #64748b;
      margin-bottom: 3px; display: block; letter-spacing: .01em;
    }
    .hoa-contact-label .req { color: #dc2626; margin-left: 1px; }
    .hoa-contact-row { display: flex; gap: 8px; }
    .hoa-contact-row > div { flex: 1; min-width: 0; }
    .hoa-contact-form input, .hoa-contact-form textarea {
      width: 100%; padding: 9px 12px; border-radius: 8px;
      border: 1.5px solid #e2e8f0; font-size: 13px;
      transition: border-color .2s; font-family: inherit;
    }
    .hoa-contact-form textarea {
      resize: vertical; min-height: 72px; line-height: 1.4;
    }
    .hoa-contact-form input:focus, .hoa-contact-form textarea:focus {
      outline: none; border-color: ${CONFIG.primaryColor};
    }

    /* Input area */
    .hoa-input-area {
      padding: 12px 16px; border-top: 1px solid #e2e8f0;
      display: flex; gap: 8px; align-items: flex-end; background: #fff;
    }
    .hoa-input {
      flex: 1; padding: 10px 14px; border-radius: 20px;
      border: 1.5px solid #e2e8f0; font-size: 14px; resize: none;
      max-height: 100px; min-height: 40px; line-height: 1.4;
      font-family: inherit; transition: border-color .2s;
    }
    .hoa-input:focus { outline: none; border-color: ${CONFIG.primaryColor}; }
    .hoa-send {
      width: 40px; height: 40px; border-radius: 50%; border: none;
      background: ${CONFIG.primaryColor}; color: #fff; cursor: pointer;
      display: flex; align-items: center; justify-content: center;
      transition: opacity .2s; flex-shrink: 0;
    }
    .hoa-send:hover { opacity: .9; }
    .hoa-send:disabled { opacity: .4; cursor: not-allowed; }
    .hoa-send svg { width: 18px; height: 18px; fill: #fff; }

    /* Quick actions */
    .hoa-quick-actions { display: flex; flex-wrap: wrap; gap: 6px; padding: 4px 0; }
    .hoa-chip {
      padding: 6px 12px; border-radius: 16px; border: 1.5px solid #e2e8f0;
      background: #fff; font-size: 12px; color: #475569; cursor: pointer;
      transition: all .2s; white-space: nowrap;
    }
    .hoa-chip:hover { border-color: ${CONFIG.primaryColor}; color: ${CONFIG.primaryColor}; background: ${CONFIG.primaryColor}08; }

    /* New session */
    .hoa-new-session {
      text-align: center; padding: 4px;
    }
    .hoa-new-session button {
      background: none; border: none; color: #94a3b8; font-size: 11px;
      cursor: pointer; text-decoration: underline;
    }
    .hoa-new-session button:hover { color: #64748b; }

    /* Powered by */
    .hoa-powered { text-align: center; padding: 6px; font-size: 11px; color: #94a3b8; }

    /* Scrollbar */
    .hoa-body::-webkit-scrollbar { width: 5px; }
    .hoa-body::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 4px; }

    @media (max-width: 480px) {
      .hoa-widget-panel {
        bottom: 0; ${CONFIG.position}: 0; width: 100%; max-width: 100%;
        height: 100vh; max-height: 100vh; border-radius: 0;
      }
      .hoa-widget-bubble { bottom: 16px; ${CONFIG.position}: 16px; }
    }
  `;

  // ─── Icons (inline SVG) ──────────────────────────────────────
  const ICONS = {
    chat: '<svg viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H6l-2 2V4h16v12z"/></svg>',
    close: '<svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>',
    send: '<svg viewBox="0 0 24 24"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>',
    home: '<svg viewBox="0 0 24 24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>',
    arrow: '<svg viewBox="0 0 24 24" width="16" height="16"><path d="M7 10l5 5 5-5z" fill="currentColor"/></svg>',
  };

  // ─── Create Widget ───────────────────────────────────────────
  const host = document.createElement('div');
  host.id = 'hoa-chat-widget';
  document.body.appendChild(host);

  const shadow = host.attachShadow({ mode: 'open' });

  // Close dropdown when clicking outside of it
  shadow.addEventListener('mousedown', (e) => {
    if (!state.dropdownOpen) return;
    const dropdown = shadow.querySelector('.hoa-dropdown');
    if (dropdown && !dropdown.contains(e.composedPath()[0])) {
      state.dropdownOpen = false;
      state.dropdownSearch = '';
      render();
    }
  });

  // Stylesheet
  const style = document.createElement('style');
  style.textContent = css;
  shadow.appendChild(style);

  // Container
  const container = document.createElement('div');
  shadow.appendChild(container);

  // ─── Render ──────────────────────────────────────────────────
  function render() {
    container.innerHTML = '';

    // Bubble
    const bubble = el('button', { class: 'hoa-widget-bubble', 'aria-label': 'Open chat' });
    bubble.innerHTML = state.open ? ICONS.close : ICONS.chat;
    bubble.onclick = () => { state.open = !state.open; render(); };
    container.appendChild(bubble);

    if (!state.open) return;

    // Panel
    const panel = el('div', { class: 'hoa-widget-panel' });
    container.appendChild(panel);

    // Header
    const header = el('div', { class: 'hoa-header' });
    header.innerHTML = `
      <div class="hoa-header-icon">${ICONS.home}</div>
      <div class="hoa-header-text">
        <div class="hoa-header-title">${esc(CONFIG.company)}</div>
        <div class="hoa-header-sub">${state.step === 'chat' && state.selectedCommunity ? esc(state.selectedCommunity.name) : 'AI-Powered Community Support'}</div>
      </div>
    `;
    const closeBtn = el('button', { class: 'hoa-close', 'aria-label': 'Close' });
    closeBtn.innerHTML = ICONS.close;
    closeBtn.onclick = () => { state.open = false; render(); };
    header.appendChild(closeBtn);
    panel.appendChild(header);

    // Body
    const body = el('div', { class: 'hoa-body' });
    panel.appendChild(body);

    if (state.step === 'community') {
      renderCommunitySelector(body);
    } else {
      renderChatMessages(body);
    }

    // Footer
    if (state.step === 'chat') {
      renderInputArea(panel);
    }
  }

  // ─── Community Selector ──────────────────────────────────────
  function renderCommunitySelector(body) {
    const card = el('div', { class: 'hoa-community-card' });
    card.innerHTML = `
      <div style="width:60px;height:60px;border-radius:50%;background:${CONFIG.primaryColor}15;display:flex;align-items:center;justify-content:center">
        <svg viewBox="0 0 24 24" width="32" height="32" fill="${CONFIG.primaryColor}"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>
      </div>
      <h3>Welcome!</h3>
      <p>I'm your AI assistant. Select your community to get started.</p>
    `;

    if (state.communities.length === 0) {
      fetchCommunities();
    }

    // ── Searchable dropdown ──────────────────────────────────
    const dropWrap = el('div', { class: 'hoa-dropdown' });

    const pickedCommunity = state.dropdownPickedId
      ? state.communities.find(c => c.id === state.dropdownPickedId) : null;

    const trigger = el('button', { class: 'hoa-dropdown-trigger' });
    if (state.dropdownOpen) trigger.classList.add('open');
    trigger.innerHTML = pickedCommunity
      ? `<span>${esc(pickedCommunity.name)}</span><span class="hoa-dropdown-arrow">${ICONS.arrow}</span>`
      : `<span class="hoa-dropdown-placeholder">${state.communities.length === 0 ? 'Loading communities…' : 'Select your community…'}</span><span class="hoa-dropdown-arrow">${ICONS.arrow}</span>`;
    trigger.disabled = state.communities.length === 0;
    trigger.onclick = () => {
      state.dropdownOpen = !state.dropdownOpen;
      if (!state.dropdownOpen) state.dropdownSearch = '';
      render();
    };
    dropWrap.appendChild(trigger);

    if (state.dropdownOpen && state.communities.length > 0) {
      const menu = el('div', { class: 'hoa-dropdown-menu' });

      const searchInput = el('input', { type: 'text', class: 'hoa-dropdown-search', placeholder: 'Search communities…' });
      searchInput.value = state.dropdownSearch;
      searchInput.oninput = () => {
        state.dropdownSearch = searchInput.value;
        refreshList();
      };
      // Prevent trigger blur when interacting inside the menu
      menu.onmousedown = (e) => e.preventDefault();

      const listEl = el('div', { class: 'hoa-dropdown-list' });

      function refreshList() {
        listEl.innerHTML = '';
        const q = state.dropdownSearch.toLowerCase();
        const filtered = q
          ? state.communities.filter(c => c.name.toLowerCase().includes(q))
          : state.communities;

        if (filtered.length === 0) {
          const empty = el('div', { class: 'hoa-dropdown-empty' });
          empty.textContent = 'No communities found';
          listEl.appendChild(empty);
        } else {
          filtered.forEach(c => {
            const item = el('div', { class: 'hoa-dropdown-item' });
            if (state.dropdownPickedId === c.id) item.classList.add('selected');
            item.textContent = c.name;
            item.onclick = () => {
              state.dropdownPickedId = c.id;
              state.dropdownOpen = false;
              state.dropdownSearch = '';
              render();
            };
            listEl.appendChild(item);
          });
        }
      }

      refreshList();
      menu.appendChild(searchInput);
      menu.appendChild(listEl);
      dropWrap.appendChild(menu);

      requestAnimationFrame(() => searchInput.focus());
    }

    card.appendChild(dropWrap);

    // ── Start Chat button ────────────────────────────────────
    const btn = el('button', { class: 'hoa-btn' });
    btn.textContent = 'Start Chat';
    btn.disabled = !state.dropdownPickedId;
    btn.onclick = () => {
      const community = state.communities.find(c => c.id === state.dropdownPickedId);
      if (!community) return;
      state.selectedCommunity = community;
      state.step = 'chat';
      state.messages = [];
      state.dropdownPickedId = null;
      state.dropdownOpen = false;
      fetchGreeting(community.id);
      render();
    };
    card.appendChild(btn);

    // ── Resume previous session ──────────────────────────────
    const saved = loadSession();
    if (saved && saved.communityId && saved.sessionId) {
      const restoreBtn = el('div', { class: 'hoa-new-session' });
      const rBtn = el('button');
      rBtn.textContent = 'Resume previous conversation';
      rBtn.onclick = () => {
        state.selectedCommunity = { id: saved.communityId, name: saved.communityName || 'Your Community' };
        state.sessionId = saved.sessionId;
        state.step = 'chat';
        state.messages = [{ role: 'bot', text: 'Welcome back! How can I help you today?' }];
        render();
      };
      restoreBtn.appendChild(rBtn);
      card.appendChild(restoreBtn);
    }

    body.appendChild(card);
  }

  // ─── Chat Messages ──────────────────────────────────────────
  function renderChatMessages(body) {
    state.messages.forEach(msg => {
      const wrapper = el('div', { class: `hoa-msg hoa-msg-${msg.role === 'user' ? 'user' : 'bot'}` });

      const avatar = el('div', { class: 'hoa-msg-avatar' });
      avatar.textContent = msg.role === 'user' ? 'You' : 'AI';

      const bubble = el('div', { class: 'hoa-msg-bubble' });
      bubble.innerHTML = formatMessage(msg.text);

      wrapper.appendChild(avatar);
      wrapper.appendChild(bubble);
      body.appendChild(wrapper);
    });

    // Contact form
    if (state.collectingContact) {
      renderContactForm(body);
    }

    // Quick actions (only after first bot message and before user types)
    if (state.messages.length <= 2 && !state.collectingContact) {
      const actions = el('div', { class: 'hoa-quick-actions' });
      const chips = ['HOA Rules', 'Dues & Payments', 'Maintenance Request', 'Office Hours', 'Pool Rules', 'Parking Policy'];
      chips.forEach(text => {
        const chip = el('button', { class: 'hoa-chip' });
        chip.textContent = text;
        chip.onclick = () => sendMessage(text);
        actions.appendChild(chip);
      });
      body.appendChild(actions);
    }

    // Typing indicator
    if (state.loading) {
      const typing = el('div', { class: 'hoa-typing' });
      typing.innerHTML = '<div class="hoa-typing-dot"></div><div class="hoa-typing-dot"></div><div class="hoa-typing-dot"></div>';
      body.appendChild(typing);
    }

    // New session
    const ns = el('div', { class: 'hoa-new-session' });
    const nsBtn = el('button');
    nsBtn.textContent = 'Start new conversation';
    nsBtn.onclick = () => {
      clearSession();
      state.sessionId = null;
      state.messages = [];
      state.step = 'community';
      state.selectedCommunity = null;
      state.collectingContact = false;
      state.visitorFirstName = '';
      state.visitorLastName = '';
      state.visitorAccountNumber = '';
      state.visitorEmail = '';
      state.visitorPhone = '';
      state.visitorQuestion = '';
      render();
    };
    ns.appendChild(nsBtn);
    body.appendChild(ns);

    // Powered by
    const powered = el('div', { class: 'hoa-powered' });
    powered.textContent = 'Powered by HOA Assistant AI';
    body.appendChild(powered);

    // Scroll to bottom
    requestAnimationFrame(() => { body.scrollTop = body.scrollHeight; });
  }

  // ─── Contact Form ────────────────────────────────────────────
  function renderContactForm(body) {
    const form = el('div', { class: 'hoa-contact-form' });

    function lbl(text, required) {
      const l = el('label', { class: 'hoa-contact-label' });
      l.textContent = text;
      if (required) { const r = el('span', { class: 'req' }); r.textContent = ' *'; l.appendChild(r); }
      return l;
    }
    function field(labelText, required, inputEl) {
      const wrap = el('div');
      wrap.appendChild(lbl(labelText, required));
      wrap.appendChild(inputEl);
      return wrap;
    }

    // First Name / Last Name — side by side
    const firstNameInput = el('input', { type: 'text', placeholder: 'Jane' });
    firstNameInput.value = state.visitorFirstName;
    firstNameInput.oninput = () => { state.visitorFirstName = firstNameInput.value; };

    const lastNameInput = el('input', { type: 'text', placeholder: 'Smith' });
    lastNameInput.value = state.visitorLastName;
    lastNameInput.oninput = () => { state.visitorLastName = lastNameInput.value; };

    const nameRow = el('div', { class: 'hoa-contact-row' });
    nameRow.appendChild(field('First Name', true, firstNameInput));
    nameRow.appendChild(field('Last Name', true, lastNameInput));
    form.appendChild(nameRow);

    // Account Number
    const acctInput = el('input', { type: 'text', placeholder: 'e.g. 10042' });
    acctInput.value = state.visitorAccountNumber;
    acctInput.oninput = () => { state.visitorAccountNumber = acctInput.value; };
    form.appendChild(field('Account Number', false, acctInput));

    // Email
    const emailInput = el('input', { type: 'email', placeholder: 'jane@example.com' });
    emailInput.value = state.visitorEmail;
    emailInput.oninput = () => { state.visitorEmail = emailInput.value; };
    form.appendChild(field('Email', true, emailInput));

    // Phone
    const phoneInput = el('input', { type: 'tel', placeholder: '(555) 000-0000' });
    phoneInput.value = state.visitorPhone;
    phoneInput.oninput = () => { state.visitorPhone = phoneInput.value; };
    form.appendChild(field('Phone', false, phoneInput));

    // Question / description
    const questionInput = el('textarea', { placeholder: 'Describe your question or request…', rows: '3' });
    questionInput.value = state.visitorQuestion;
    questionInput.oninput = () => { state.visitorQuestion = questionInput.value; };
    form.appendChild(field('Ask your question here', true, questionInput));

    // Submit
    const submitBtn = el('button', { class: 'hoa-btn' });
    submitBtn.textContent = 'Submit & Create Ticket';
    submitBtn.onclick = () => {
      if (!state.visitorFirstName.trim()) { alert('First name is required.'); return; }
      if (!state.visitorLastName.trim())  { alert('Last name is required.');  return; }
      if (!state.visitorEmail.trim())     { alert('Email is required.');      return; }
      if (!state.visitorQuestion.trim())  { alert('Please describe your question or request.'); return; }
      state.collectingContact = false;
      sendMessage(state.visitorQuestion, true);
    };
    form.appendChild(submitBtn);
    body.appendChild(form);
  }

  // ─── Input Area ──────────────────────────────────────────────
  function renderInputArea(panel) {
    const area = el('div', { class: 'hoa-input-area' });

    const input = el('textarea', { class: 'hoa-input', placeholder: 'Type your message...', rows: '1' });
    input.oninput = () => {
      input.style.height = 'auto';
      input.style.height = Math.min(input.scrollHeight, 100) + 'px';
    };
    input.onkeydown = (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        doSend(input);
      }
    };

    const sendBtn = el('button', { class: 'hoa-send', 'aria-label': 'Send' });
    sendBtn.innerHTML = ICONS.send;
    sendBtn.onclick = () => doSend(input);

    area.appendChild(input);
    area.appendChild(sendBtn);
    panel.appendChild(area);

    // Focus input
    requestAnimationFrame(() => input.focus());
  }

  function doSend(input) {
    const text = input.value.trim();
    if (!text || state.loading) return;
    input.value = '';
    input.style.height = 'auto';
    sendMessage(text);
  }

  // ─── API Calls ───────────────────────────────────────────────
  async function fetchCommunities() {
    try {
      const res = await fetch(`${CONFIG.apiUrl}/api/public/communities`, {
        headers: { 'X-Widget-Key': CONFIG.apiKey },
      });
      if (!res.ok) throw new Error('Failed to load communities');
      state.communities = await res.json();
      render();
    } catch (e) {
      console.error('[HOA Widget] Failed to fetch communities:', e);
    }
  }

  async function fetchGreeting(communityId) {
    try {
      const res = await fetch(`${CONFIG.apiUrl}/api/public/chat/greeting/${communityId}`, {
        headers: { 'X-Widget-Key': CONFIG.apiKey },
      });
      if (res.ok) {
        const data = await res.json();
        state.messages.push({ role: 'bot', text: data.response || 'How can I help you today?' });
        render();
      }
    } catch (e) {
      state.messages.push({ role: 'bot', text: 'Hello! How can I help you today?' });
      render();
    }
  }

  async function sendMessage(text, withContact = false) {
    // Add user message to UI (only if not a retry with contact)
    if (!withContact) {
      state.messages.push({ role: 'user', text });
    }
    state.loading = true;
    render();

    const payload = {
      message: text,
      communityId: state.selectedCommunity.id,
      sessionId: state.sessionId,
    };

    // Attach contact info if provided
    if (withContact || state.visitorFirstName) {
      payload.visitorFirstName    = state.visitorFirstName;
      payload.visitorLastName     = state.visitorLastName;
      payload.visitorName         = (state.visitorFirstName + ' ' + state.visitorLastName).trim();
      payload.visitorAccountNumber = state.visitorAccountNumber || null;
      payload.visitorEmail        = state.visitorEmail;
      payload.visitorPhone        = state.visitorPhone || null;
    }

    try {
      const res = await fetch(`${CONFIG.apiUrl}/api/public/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Widget-Key': CONFIG.apiKey,
        },
        body: JSON.stringify(payload),
      });

      if (!res.ok) throw new Error('Chat request failed');
      const data = await res.json();

      // Save session
      state.sessionId = data.sessionId || state.sessionId;
      saveSession({
        sessionId: state.sessionId,
        communityId: state.selectedCommunity.id,
        communityName: state.selectedCommunity.name,
      });

      // Handle collect_contact action
      if (data.action === 'collect_contact') {
        state.collectingContact = true;
        // Pre-fill the question with what the user just asked so they can elaborate
        if (!state.visitorQuestion) {
          state.visitorQuestion = text;
        }
      }

      // Add bot response
      state.messages.push({ role: 'bot', text: data.response || 'I apologize, I could not process your request.' });

      // Ticket confirmation
      if (data.ticketId) {
        state.messages.push({ role: 'bot', text: `✅ Ticket #${data.ticketId} created! Our team will follow up at ${state.visitorEmail}.` });
      }

    } catch (e) {
      console.error('[HOA Widget] Chat error:', e);
      state.messages.push({ role: 'bot', text: 'Sorry, I encountered an error. Please try again.' });
    }

    state.loading = false;
    render();
  }

  // ─── Helpers ─────────────────────────────────────────────────
  function el(tag, attrs) {
    const e = document.createElement(tag);
    if (attrs) Object.entries(attrs).forEach(([k, v]) => e.setAttribute(k, v));
    return e;
  }

  function esc(s) {
    const d = document.createElement('div');
    d.textContent = s;
    return d.innerHTML;
  }

  function formatMessage(text) {
    if (!text) return '';
    return esc(text)
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      .replace(/\n/g, '<br>');
  }

  // ─── Initialize ──────────────────────────────────────────────
  render();

})();
