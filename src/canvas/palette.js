// 夜景パレット (時間帯プリセット)
// scene.sky_mode = 'sunset' | 'night' | 'dawn' で選択
export const RENDER_PRESETS = {
  sunset: {
    sky: [
      { stop: 0.00, color: '#1a0b2e' },
      { stop: 0.30, color: '#3e1d4f' },
      { stop: 0.55, color: '#8e3559' },
      { stop: 0.78, color: '#d85d4a' },
      { stop: 0.92, color: '#e88840' },
      { stop: 1.00, color: '#ffb866' },
    ],
    water: [
      { stop: 0.00, color: '#4a2548' },
      { stop: 0.35, color: '#1d1224' },
      { stop: 1.00, color: '#050410' },
    ],
    reflection:   'rgba(200, 100, 90, %a)',
    farMountain:  '#0c0714',
    farMountainLit: '#2a1828',
    shoreGlow:    'rgba(255, 140, 70, 0.18)',
  },

  night: {
    sky: [
      { stop: 0.00, color: '#02030a' },
      { stop: 0.50, color: '#060814' },
      { stop: 0.90, color: '#0c0a1a' },
      { stop: 1.00, color: '#140c14' },
    ],
    water: [
      { stop: 0.00, color: '#0c1020' },
      { stop: 0.40, color: '#060814' },
      { stop: 1.00, color: '#020308' },
    ],
    reflection:   'rgba(100, 130, 180, %a)',
    farMountain:  '#020108',
    farMountainLit: '#0a0818',
    shoreGlow:    'rgba(255, 170, 90, 0.14)',
  },

  dawn: {
    sky: [
      { stop: 0.00, color: '#091430' },
      { stop: 0.30, color: '#1a2548' },
      { stop: 0.60, color: '#4b3a5a' },
      { stop: 0.85, color: '#a56864' },
      { stop: 1.00, color: '#f4a878' },
    ],
    water: [
      { stop: 0.00, color: '#3a2b42' },
      { stop: 0.45, color: '#14182c' },
      { stop: 1.00, color: '#030610' },
    ],
    reflection:   'rgba(180, 140, 170, %a)',
    farMountain:  '#08081a',
    farMountainLit: '#2a2438',
    shoreGlow:    'rgba(255, 180, 120, 0.16)',
  },
};

// 共通の要素色
export const COMMON = {
  land:       '#050309',
  foreground: '#020104',
  lights: [
    '#ff9a3d',
    '#ffae5c',
    '#ffbe7a',
    '#ffd096',
    '#ff8030',
    '#ffe4b8',
  ],
  anchors: [
    '#fff2d0',
    '#ffe0a8',
    '#ffd890',
  ],
};

export function getPreset(skyMode) {
  return RENDER_PRESETS[skyMode] || RENDER_PRESETS.sunset;
}
