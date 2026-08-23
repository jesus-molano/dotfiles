"use strict";

const HOST = "com.project_atlas.thunderbird_theme";
let reconnectTimer;
let lastPalette;

function themeFor(palette) {
  return {
    colors: {
      frame: palette.mSurfaceVariant,
      frame_inactive: palette.mSurface,
      toolbar: palette.mSurfaceVariant,
      toolbar_text: palette.mOnSurface,
      toolbar_field: palette.mSurface,
      toolbar_field_text: palette.mOnSurface,
      toolbar_field_border: palette.mOutline,
      toolbar_field_focus: palette.mHover,
      toolbar_field_text_focus: palette.mOnSurface,
      toolbar_field_border_focus: palette.mPrimary,
      toolbar_field_highlight: palette.mPrimary,
      toolbar_field_highlight_text: palette.mOnPrimary,
      toolbar_bottom_separator: palette.mOutline,
      toolbar_top_separator: palette.mOutline,
      toolbar_vertical_separator: palette.mOutline,
      icons: palette.mOnSurface,
      icons_attention: palette.mTertiary,
      button_background_hover: palette.mHover,
      button_background_active: palette.mPrimary,
      tab_selected: palette.mSurface,
      tab_text: palette.mOnSurface,
      tab_background_text: palette.mOnSurfaceVariant,
      tab_line: palette.mPrimary,
      tab_loading: palette.mSecondary,
      popup: palette.mSurfaceVariant,
      popup_text: palette.mOnSurface,
      popup_border: palette.mOutline,
      popup_highlight: palette.mHover,
      popup_highlight_text: palette.mOnSurface,
      sidebar: palette.mSurface,
      sidebar_text: palette.mOnSurface,
      sidebar_border: palette.mOutline,
      sidebar_highlight: palette.mPrimary,
      sidebar_highlight_text: palette.mOnPrimary,
      sidebar_highlight_border: palette.mPrimary,
    },
    properties: {
      color_scheme: "dark",
      content_color_scheme: "dark",
    },
  };
}

async function applyMessage(message) {
  if (!message?.ok || !message.palette) {
    console.error("No se pudo leer la paleta de Noctalia", message?.error);
    return;
  }
  const signature = JSON.stringify(message.palette);
  if (signature === lastPalette) {
    return;
  }
  await browser.theme.update(themeFor(message.palette));
  lastPalette = signature;
}

function connect() {
  clearTimeout(reconnectTimer);
  const port = browser.runtime.connectNative(HOST);
  port.onMessage.addListener((message) => {
    applyMessage(message).catch(console.error);
  });
  port.onDisconnect.addListener(() => {
    reconnectTimer = setTimeout(connect, 3000);
  });
}

connect();
