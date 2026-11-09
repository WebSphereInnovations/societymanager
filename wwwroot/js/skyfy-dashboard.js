(() => {
  'use strict';

  const $ = (selector) => document.querySelector(selector);
  const tr = (value) => window.Society360I18n?.translateText?.(value) || value;
  let stage = null;
  let observer = null;
  let syncBuildingOptions = () => {};
  let sourceBuildingSelect = null;
  let sourceChangeHandler = null;

  const metricSources = [
    ['Buildings / wings', '#kpiFlatsDetail'],
    ['Apartments', '#kpiFlats'],
    ['Occupancy', '#heroOccupancy'],
    ['Visitors inside', '#kpiVisitors'],
    ['Open complaints', '#kpiComplaints'],
    ['Collected in period', '#heroCollected']
  ];

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function createBuildingModel() {
    const wrap = el('div', 's360-nexus-building-wrap');
    wrap.setAttribute('aria-hidden', 'true');
    const halo = el('div', 's360-nexus-building-halo');
    const plinth = el('div', 's360-nexus-building-plinth');
    const model = el('div', 's360-nexus-building-model');
    const front = el('div', 's360-nexus-building-face s360-nexus-building-face--front');
    const side = el('div', 's360-nexus-building-face s360-nexus-building-face--side');
    const roof = el('div', 's360-nexus-building-face s360-nexus-building-face--roof');
    for (let floor = 0; floor < 7; floor += 1) {
      const row = el('div', 's360-nexus-building-floor');
      for (let windowIndex = 0; windowIndex < 5; windowIndex += 1) {
        row.appendChild(el('span', 's360-nexus-building-window'));
      }
      front.appendChild(row);
    }
    for (let floor = 0; floor < 7; floor += 1) {
      const row = el('div', 's360-nexus-building-floor s360-nexus-building-floor--side');
      for (let windowIndex = 0; windowIndex < 2; windowIndex += 1) {
        row.appendChild(el('span', 's360-nexus-building-window'));
      }
      side.appendChild(row);
    }
    model.append(front, side, roof);
    plinth.appendChild(model);
    wrap.append(halo, plinth);
    return { wrap, model };
  }

  function buildStage() {
    const section = el('section', 's360-nexus-dashboard-visual');
    section.id = 'skyfyNexusDashboardVisual';
    section.setAttribute('aria-label', tr('Smart Society Overview'));

    const visual = el('div', 's360-nexus-dashboard-visual__scene');
    const sceneKicker = el('span', 's360-nexus-dashboard-visual__kicker', 'SKYFY NEXUS');
    const model = createBuildingModel();
    const selectedName = el('div', 's360-nexus-dashboard-visual__building-name', tr('All buildings'));
    visual.append(sceneKicker, model.wrap, selectedName);

    const dataPanel = el('div', 's360-nexus-dashboard-visual__data');
    const heading = el('div', 's360-nexus-dashboard-visual__heading');
    const title = el('h3', '', tr('Smart Society Overview'));
    const filterWrap = el('label', 's360-nexus-dashboard-visual__filter');
    const filterLabel = el('span', '', tr('Select building'));
    const select = el('select', 's360-nexus-dashboard-visual__select');
    select.id = 'skyfyBuildingSelect';
    select.setAttribute('aria-label', tr('Select building'));
    filterWrap.append(filterLabel, select);
    heading.append(title, filterWrap);

    const metrics = el('div', 's360-nexus-dashboard-visual__metrics');
    metricSources.forEach(([label], index) => {
      const card = el('div', 's360-nexus-dashboard-metric');
      const caption = el('span', '', tr(label));
      const value = el('strong', '', '—');
      value.id = 'skyfyMetric' + index;
      card.append(caption, value);
      metrics.appendChild(card);
    });
    dataPanel.append(heading, metrics);
    section.append(visual, dataPanel);

    const hero = $('.dash-hero');
    if (hero) hero.insertAdjacentElement('afterend', section);

    const source = $('#dashBuilding');
    if (source) {
      sourceBuildingSelect = source;
      syncBuildingOptions = () => {
        const current = source.value;
        select.replaceChildren();
        Array.from(source.options).forEach((sourceOption) => {
          const option = document.createElement('option');
          option.value = sourceOption.value;
          option.textContent = sourceOption.textContent;
          option.disabled = sourceOption.disabled;
          select.appendChild(option);
        });
        select.value = current;
        if (select.selectedIndex < 0 && select.options.length) select.selectedIndex = 0;
        selectedName.textContent = select.selectedOptions[0]?.textContent || tr('All buildings');
      };
      sourceChangeHandler = () => {
        if (select.value !== source.value) select.value = source.value;
        selectedName.textContent = select.selectedOptions[0]?.textContent || tr('All buildings');
      };
      select.addEventListener('change', () => {
        source.value = select.value;
        source.dispatchEvent(new Event('change', { bubbles: true }));
        selectedName.textContent = select.selectedOptions[0]?.textContent || tr('All buildings');
        window.societyDashboard?.load?.();
      });
      source.addEventListener('change', sourceChangeHandler);
      syncBuildingOptions();
    }

    const { model: buildingModel } = model;
    section.addEventListener('pointermove', (event) => {
      if (event.pointerType === 'touch') return;
      const rect = section.getBoundingClientRect();
      const x = (event.clientX - rect.left) / Math.max(1, rect.width) - .5;
      const y = (event.clientY - rect.top) / Math.max(1, rect.height) - .5;
      buildingModel.style.setProperty('--nexus-tilt-x', ( -7 - y * 9) + 'deg');
      buildingModel.style.setProperty('--nexus-tilt-y', (-24 + x * 16) + 'deg');
    });
    section.addEventListener('pointerleave', () => {
      buildingModel.style.setProperty('--nexus-tilt-x', '-7deg');
      buildingModel.style.setProperty('--nexus-tilt-y', '-24deg');
    });

    observer?.disconnect();
    observer = new MutationObserver(() => { syncBuildingOptions(); updateMetrics(); });
    if (sourceBuildingSelect) observer.observe(sourceBuildingSelect, { childList: true, subtree: true });
    metricSources.forEach(([, selector]) => {
      const sourceNode = $(selector);
      if (sourceNode) observer.observe(sourceNode, { childList: true, characterData: true, subtree: true });
    });
    updateMetrics();
    updateLanguage();
    return section;
  }

  function updateMetrics() {
    if (!stage) return;
    metricSources.forEach(([, selector], index) => {
      const source = $(selector);
      const target = $('#skyfyMetric' + index);
      if (target) target.textContent = source?.textContent?.trim() || '—';
    });
  }

  function updateLanguage() {
    if (!stage) return;
    stage.setAttribute('aria-label', tr('Smart Society Overview'));
    const title = stage.querySelector('.s360-nexus-dashboard-visual__heading h3');
    if (title) title.textContent = tr('Smart Society Overview');
    const label = stage.querySelector('.s360-nexus-dashboard-visual__filter span');
    if (label) label.textContent = tr('Select building');
    metricSources.forEach(([caption], index) => {
      const target = stage.querySelector('#skyfyMetric' + index)?.previousElementSibling;
      if (target) target.textContent = tr(caption);
    });
    if (sourceBuildingSelect && stage.querySelector('#skyfyBuildingSelect')) {
      const source = sourceBuildingSelect;
      const select = stage.querySelector('#skyfyBuildingSelect');
      const current = select.value;
      select.replaceChildren();
      Array.from(source.options).forEach((sourceOption) => {
        const option = document.createElement('option');
        option.value = sourceOption.value;
        option.textContent = sourceOption.textContent;
        option.disabled = sourceOption.disabled;
        select.appendChild(option);
      });
      select.value = current;
      stage.querySelector('.s360-nexus-dashboard-visual__building-name').textContent =
        select.selectedOptions[0]?.textContent || tr('All buildings');
    }
  }

  function removeStage() {
    observer?.disconnect();
    observer = null;
    syncBuildingOptions = () => {};
    if (sourceBuildingSelect && sourceChangeHandler) {
      sourceBuildingSelect.removeEventListener('change', sourceChangeHandler);
    }
    sourceBuildingSelect = null;
    sourceChangeHandler = null;
    stage?.remove();
    stage = null;
  }

  function onThemeApplied(event) {
    const code = String(event.detail?.themeCode || 'STANDARD').toUpperCase();
    if (code === 'SKYFY_NEXUS') {
      if (!stage && $('.dash-hero')) stage = buildStage();
      updateMetrics();
    } else {
      removeStage();
    }
  }

  window.addEventListener('s360:theme-applied', onThemeApplied);
  window.addEventListener('society360-language-changed', updateLanguage);
  if (document.documentElement.dataset.s360Theme === 'skyfy-nexus') {
    onThemeApplied({ detail: { themeCode: 'SKYFY_NEXUS' } });
  }
})();
