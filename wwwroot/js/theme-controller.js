(() => {
  'use strict';

  const THEME_STYLE_ID = 's360-skyfy-theme-style';
  const THEME_STYLE_URL = '/css/skyfy-nexus.css?v=20261109.01';
  let currentTheme = 'STANDARD';
  let picker;

  const translate = (value) => window.Society360I18n?.t?.(value) || value;

  function announce(message, kind = 'success') {
    let toast = document.getElementById('s360-theme-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 's360-theme-toast';
      toast.className = 's360-theme-toast';
      toast.setAttribute('role', 'status');
      toast.setAttribute('aria-live', 'polite');
      document.body.appendChild(toast);
    }
    toast.dataset.kind = kind;
    toast.textContent = translate(message);
    toast.classList.add('is-visible');
    window.setTimeout(() => toast.classList.remove('is-visible'), 2600);
  }

  function loadSkyfyStylesheet() {
    const existing = document.getElementById(THEME_STYLE_ID);
    if (existing) {
      document.documentElement.dataset.s360Theme = 'skyfy-nexus';
      return Promise.resolve(true);
    }
    return new Promise((resolve) => {
      const link = document.createElement('link');
      link.id = THEME_STYLE_ID;
      link.rel = 'stylesheet';
      link.href = THEME_STYLE_URL;
      link.onload = () => {
        document.documentElement.dataset.s360Theme = 'skyfy-nexus';
        resolve(true);
      };
      link.onerror = () => {
        link.remove();
        document.documentElement.dataset.s360Theme = 'standard';
        resolve(false);
      };
      document.head.appendChild(link);
    });
  }

  async function applyTheme(themeCode) {
    const normalized = String(themeCode || 'STANDARD').toUpperCase();
    if (normalized === 'SKYFY_NEXUS') {
      return await loadSkyfyStylesheet();
    }
    document.documentElement.dataset.s360Theme = 'standard';
    document.getElementById(THEME_STYLE_ID)?.remove();
    return true;
  }

  async function getCsrfToken() {
    const response = await fetch('/api/security/csrf', {
      credentials: 'same-origin',
      cache: 'no-store',
      headers: { Accept: 'application/json' }
    });
    if (!response.ok) throw new Error('csrf');
    const payload = await response.json();
    if (!payload.token) throw new Error('csrf');
    return payload.token;
  }

  function themeLabel(theme) {
    const code = String(theme.themeCode || '').toUpperCase();
    if (code === 'STANDARD') return translate('Standard Theme');
    if (code === 'SKYFY_NEXUS') return translate('SKYFY NEXUS');
    return theme.themeName || code;
  }

  function refreshPickerLanguage() {
    if (!picker) return;
    const wrapper = picker.closest('.s360-theme-picker');
    const label = wrapper?.querySelector('.s360-theme-picker__label');
    if (label) label.textContent = translate('Theme');
    picker.setAttribute('aria-label', translate('Select theme'));
    Array.from(picker.options).forEach((option) => {
      option.textContent = translate(option.value === 'STANDARD' ? 'Standard Theme' :
        option.value === 'SKYFY_NEXUS' ? 'SKYFY NEXUS' : option.textContent);
    });
  }

  function findHost() {
    return document.querySelector('[data-s360-theme-picker]') ||
      document.querySelector('.top-actions') ||
      document.querySelector('.topline') ||
      document.querySelector('.nav-preferences') ||
      document.querySelector('.top') ||
      document.querySelector('.topbar') ||
      document.querySelector('header') ||
      document.body;
  }

  function renderPicker(payload) {
    if (!payload.canChange || !Array.isArray(payload.themes) || payload.themes.length < 2) return;
    const host = findHost();
    if (!host) return;

    const wrapper = document.createElement('div');
    wrapper.className = host === document.body ? 's360-theme-picker s360-theme-picker--floating' : 's360-theme-picker';
    wrapper.setAttribute('data-s360-theme-picker', '');

    const label = document.createElement('label');
    label.className = 's360-theme-picker__label';
    label.htmlFor = 's360-theme-select';
    label.textContent = translate('Theme');

    const select = document.createElement('select');
    select.id = 's360-theme-select';
    select.className = 's360-theme-picker__select';
    select.setAttribute('aria-label', translate('Select theme'));

    payload.themes.forEach((theme) => {
      const option = document.createElement('option');
      option.value = theme.themeCode;
      option.textContent = themeLabel(theme);
      select.appendChild(option);
    });
    select.value = payload.selectedTheme || 'STANDARD';

    select.addEventListener('change', async () => {
      const nextTheme = select.value;
      const previousTheme = currentTheme;
      select.disabled = true;
      const styled = await applyTheme(nextTheme);
      if (!styled) {
        select.value = previousTheme;
        select.disabled = false;
        announce('Could not change theme.', 'error');
        return;
      }

      try {
        const token = await getCsrfToken();
        const response = await fetch('/api/theme/preference', {
          method: 'PUT',
          credentials: 'same-origin',
          cache: 'no-store',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-TOKEN': token,
            Accept: 'application/json'
          },
          body: JSON.stringify({ themeCode: nextTheme, remark: 'User changed application theme' })
        });
        if (!response.ok) throw new Error('save');
        currentTheme = nextTheme;
        announce('Theme updated successfully.');
      } catch {
        await applyTheme(previousTheme);
        select.value = previousTheme;
        announce('Could not change theme.', 'error');
      } finally {
        select.disabled = false;
      }
    });

    wrapper.append(label, select);
    host.appendChild(wrapper);
    picker = select;
    refreshPickerLanguage();
  }

  window.addEventListener('society360-language-changed', refreshPickerLanguage);

  async function initialize() {
    document.documentElement.dataset.s360Theme = 'standard';
    try {
      const response = await fetch('/api/theme/options', {
        credentials: 'same-origin',
        cache: 'no-store',
        headers: { Accept: 'application/json' }
      });
      if (!response.ok) return;
      const payload = await response.json();
      const selected = payload.selectedTheme || 'STANDARD';
      const applied = await applyTheme(selected);
      currentTheme = applied ? selected : 'STANDARD';
      if (applied) renderPicker(payload);
    } catch {
      document.documentElement.dataset.s360Theme = 'standard';
      document.getElementById(THEME_STYLE_ID)?.remove();
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize, { once: true });
  } else {
    initialize();
  }
})();
