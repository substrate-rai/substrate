---
layout: default
title: "Substrate Arcade — 22 Games, 7 Radio Stations, Built by AI"
description: "22 games. 7 radio stations. 1 album. Built by 24 AI agents on one laptop with an RTX 4060. Free forever."
permalink: /arcade/
---

<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600;700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

<style>
  /* === STEAM THEME VARIABLES === */
  :root {
    --steam-bg: #1b2838;
    --steam-surface: #2a475e;
    --steam-header: #171a21;
    --steam-accent: #00e09a;
    --steam-text: #c7d5e0;
    --steam-text-dim: #8f98a0;
    --steam-highlight: #4fc3f7;
    --steam-green: #4caf50;
    --steam-gold: #ffcc66;
    --steam-border: #0a141e;
    --steam-card: #1e3a50;
    --steam-card-hover: #2a4a62;
    --mono: 'IBM Plex Mono', monospace;
    --sans: 'Inter', -apple-system, sans-serif;
  }

  html { scroll-behavior: smooth; }

  /* Override default page styles for full-bleed Steam look */
  .page-content, .wrapper, main {
    max-width: 100% !important;
    padding: 0 !important;
  }

  .steam-store {
    background: var(--steam-bg);
    min-height: 100vh;
    color: var(--steam-text);
    font-family: var(--sans);
  }

  /* === STORE HEADER / NAV BAR === */
  .store-nav {
    background: var(--steam-header);
    border-bottom: 1px solid var(--steam-border);
    padding: 0;
    position: sticky;
    top: 0;
    z-index: 100;
  }
  .store-nav-inner {
    max-width: 1200px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    padding: 0 20px;
    gap: 0;
    overflow-x: auto;
    scrollbar-width: none;
    -ms-overflow-style: none;
  }
  .store-nav-inner::-webkit-scrollbar { display: none; }
  .store-nav-brand {
    font-family: var(--mono);
    font-size: 0.85rem;
    font-weight: 700;
    color: var(--steam-gold);
    letter-spacing: 0.15em;
    padding: 14px 20px 14px 0;
    white-space: nowrap;
    border-right: 1px solid rgba(255,255,255,0.06);
    margin-right: 4px;
    text-decoration: none;
  }
  .store-nav-link {
    display: inline-block;
    padding: 14px 14px;
    color: var(--steam-text-dim);
    font-size: 0.75rem;
    font-weight: 600;
    font-family: var(--mono);
    letter-spacing: 0.08em;
    text-decoration: none;
    white-space: nowrap;
    cursor: pointer;
    transition: color 0.2s, background 0.2s;
    border-bottom: 2px solid transparent;
  }
  .store-nav-link:hover, .store-nav-link.active {
    color: #fff;
    background: rgba(255,255,255,0.04);
  }
  .store-nav-link.active {
    border-bottom-color: var(--steam-accent);
    color: var(--steam-accent);
  }

  /* === SEARCH BAR === */
  .store-search-bar {
    max-width: 1200px;
    margin: 0 auto;
    padding: 16px 20px;
    display: flex;
    gap: 12px;
    align-items: center;
    flex-wrap: wrap;
  }
  .search-input-wrap {
    flex: 1;
    min-width: 200px;
    position: relative;
  }
  .search-input-wrap input {
    width: 100%;
    padding: 10px 14px 10px 36px;
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 4px;
    color: var(--steam-text);
    font-family: var(--sans);
    font-size: 0.85rem;
    outline: none;
    transition: border-color 0.2s;
  }
  .search-input-wrap input:focus {
    border-color: var(--steam-accent);
  }
  .search-input-wrap input::placeholder { color: var(--steam-text-dim); }
  .search-input-wrap::before {
    content: '\1F50D';
    position: absolute;
    left: 12px;
    top: 50%;
    transform: translateY(-50%);
    font-size: 0.8rem;
    opacity: 0.5;
  }
  .search-filters {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .filter-select {
    padding: 9px 12px;
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 4px;
    color: var(--steam-text);
    font-family: var(--sans);
    font-size: 0.8rem;
    cursor: pointer;
    outline: none;
    appearance: auto;
  }

  /* === MAIN LAYOUT (content + sidebar) === */
  .store-layout {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 20px 40px;
    display: grid;
    grid-template-columns: 1fr 260px;
    gap: 24px;
  }
  .store-main { min-width: 0; }
  .store-sidebar {
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  /* === FEATURED CAROUSEL === */
  .carousel-section {
    margin-bottom: 24px;
  }
  .carousel-container {
    display: grid;
    grid-template-columns: 1fr 200px;
    gap: 0;
    border-radius: 6px;
    overflow: hidden;
    background: var(--steam-header);
    border: 1px solid rgba(255,255,255,0.06);
    min-height: 340px;
  }
  .carousel-main {
    position: relative;
    overflow: hidden;
    cursor: pointer;
  }
  .carousel-slide {
    position: absolute;
    inset: 0;
    opacity: 0;
    transition: opacity 0.8s ease;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    padding: 30px;
  }
  .carousel-slide.active { opacity: 1; z-index: 1; }
  .carousel-slide-bg {
    position: absolute;
    inset: 0;
    background-size: cover;
    background-position: center;
    z-index: 0;
  }
  .carousel-slide-bg::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(to top, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0.3) 50%, rgba(0,0,0,0.1) 100%);
  }
  .carousel-content {
    position: relative;
    z-index: 1;
  }
  .carousel-tags {
    display: flex;
    gap: 6px;
    margin-bottom: 8px;
    flex-wrap: wrap;
  }
  .carousel-tag {
    font-size: 0.65rem;
    padding: 3px 10px;
    border-radius: 3px;
    font-family: var(--mono);
    font-weight: 600;
    letter-spacing: 0.05em;
  }
  .carousel-title {
    font-family: var(--mono);
    font-size: 1.8rem;
    font-weight: 700;
    color: #fff;
    margin-bottom: 8px;
    text-shadow: 0 2px 8px rgba(0,0,0,0.6);
  }
  .carousel-desc {
    font-size: 0.88rem;
    color: rgba(255,255,255,0.8);
    line-height: 1.6;
    max-width: 480px;
    margin-bottom: 14px;
  }
  .carousel-play-btn {
    display: inline-block;
    padding: 10px 28px;
    background: var(--steam-accent);
    color: #000;
    font-family: var(--mono);
    font-size: 0.85rem;
    font-weight: 700;
    letter-spacing: 0.1em;
    border: none;
    border-radius: 4px;
    text-decoration: none;
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
  }
  .carousel-play-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 16px rgba(0,224,154,0.4);
    color: #000;
  }

  /* Carousel thumbnails sidebar */
  .carousel-thumbs {
    display: flex;
    flex-direction: column;
    background: rgba(0,0,0,0.3);
    overflow-y: auto;
  }
  .carousel-thumb {
    padding: 12px 14px;
    cursor: pointer;
    border-left: 3px solid transparent;
    transition: background 0.2s, border-color 0.2s;
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-height: 56px;
    justify-content: center;
  }
  .carousel-thumb:hover {
    background: rgba(255,255,255,0.04);
  }
  .carousel-thumb.active {
    background: rgba(0,224,154,0.08);
    border-left-color: var(--steam-accent);
  }
  .carousel-thumb-title {
    font-family: var(--mono);
    font-size: 0.72rem;
    font-weight: 700;
    color: var(--steam-text);
    letter-spacing: 0.05em;
  }
  .carousel-thumb.active .carousel-thumb-title { color: #fff; }
  .carousel-thumb-genre {
    font-size: 0.62rem;
    color: var(--steam-text-dim);
    font-family: var(--mono);
  }

  /* === SECTION HEADERS (Steam-style) === */
  .section-heading {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 28px 0 14px;
    font-family: var(--mono);
  }
  .section-heading-text {
    font-size: 1rem;
    font-weight: 700;
    letter-spacing: 0.15em;
    color: #fff;
  }
  .section-heading-line {
    flex: 1;
    height: 1px;
    background: linear-gradient(90deg, rgba(255,255,255,0.15), transparent);
  }
  .section-heading-count {
    font-size: 0.7rem;
    color: var(--steam-text-dim);
    font-weight: 600;
  }

  /* === GAME CARDS (Steam-style) === */
  .game-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 12px;
    margin-bottom: 8px;
  }
  .game-card {
    background: var(--steam-card);
    border-radius: 4px;
    overflow: hidden;
    transition: transform 0.2s, box-shadow 0.2s;
    cursor: pointer;
    position: relative;
    text-decoration: none;
    display: block;
  }
  .game-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 24px rgba(0,0,0,0.5);
  }
  .game-card-thumb {
    width: 100%;
    height: 120px;
    background-size: cover;
    background-position: center;
    position: relative;
  }
  .game-card-thumb-overlay {
    position: absolute;
    inset: 0;
    background: linear-gradient(to top, rgba(0,0,0,0.6) 0%, transparent 60%);
    opacity: 0;
    transition: opacity 0.3s;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .game-card:hover .game-card-thumb-overlay { opacity: 1; }
  .game-card-thumb-play {
    padding: 8px 20px;
    background: var(--steam-accent);
    color: #000;
    font-family: var(--mono);
    font-size: 0.7rem;
    font-weight: 700;
    letter-spacing: 0.1em;
    border-radius: 3px;
    text-decoration: none;
    transform: translateY(8px);
    transition: transform 0.3s;
  }
  .game-card:hover .game-card-thumb-play { transform: translateY(0); }
  .game-card-body {
    padding: 10px 12px 12px;
  }
  .game-card-title {
    font-family: var(--mono);
    font-size: 0.82rem;
    font-weight: 700;
    color: #fff;
    margin-bottom: 4px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .game-card-tags {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
    margin-bottom: 6px;
  }
  .game-tag {
    font-size: 0.58rem;
    padding: 2px 7px;
    border-radius: 2px;
    font-family: var(--mono);
    font-weight: 600;
    letter-spacing: 0.03em;
  }
  .game-card-price {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .price-free {
    font-family: var(--mono);
    font-size: 0.7rem;
    font-weight: 700;
    color: var(--steam-green);
    background: rgba(76,175,80,0.12);
    padding: 2px 10px;
    border-radius: 2px;
  }
  .game-card-badge {
    position: absolute;
    top: 8px;
    right: 8px;
    font-family: var(--mono);
    font-size: 0.58rem;
    font-weight: 700;
    padding: 3px 8px;
    border-radius: 2px;
    z-index: 2;
    letter-spacing: 0.05em;
  }
  .badge-new {
    background: var(--steam-accent);
    color: #000;
  }
  .badge-updated {
    background: var(--steam-gold);
    color: #000;
  }

  /* Genre tag colors */
  .tag-daily { background: rgba(255,221,68,0.15); color: #ffdd44; }
  .tag-narrative { background: rgba(255,119,255,0.15); color: #ff77ff; }
  .tag-strategy { background: rgba(0,224,154,0.15); color: #00e09a; }
  .tag-action { background: rgba(255,102,102,0.15); color: #ff6666; }
  .tag-creative { background: rgba(0,221,255,0.15); color: #00ddff; }
  .tag-tool { background: rgba(136,136,170,0.15); color: #aab0c0; }
  .tag-simulation { background: rgba(0,224,154,0.15); color: #00e09a; }
  .tag-radio { background: rgba(170,119,204,0.15); color: #aa77cc; }

  /* === GAME DETAIL POPUP === */
  .game-detail-overlay {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.7);
    z-index: 200;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }
  .game-detail-overlay.active { display: flex; }
  .game-detail-panel {
    background: var(--steam-surface);
    border-radius: 8px;
    max-width: 600px;
    width: 100%;
    max-height: 80vh;
    overflow-y: auto;
    box-shadow: 0 20px 60px rgba(0,0,0,0.8);
    border: 1px solid rgba(255,255,255,0.08);
  }
  .detail-hero {
    width: 100%;
    height: 200px;
    background-size: cover;
    background-position: center;
    position: relative;
  }
  .detail-hero::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 80px;
    background: linear-gradient(to top, var(--steam-surface), transparent);
  }
  .detail-body {
    padding: 20px 24px 24px;
  }
  .detail-title {
    font-family: var(--mono);
    font-size: 1.4rem;
    font-weight: 700;
    color: #fff;
    margin-bottom: 6px;
  }
  .detail-tags {
    display: flex;
    gap: 6px;
    margin-bottom: 12px;
    flex-wrap: wrap;
  }
  .detail-desc {
    color: var(--steam-text);
    font-size: 0.9rem;
    line-height: 1.7;
    margin-bottom: 16px;
  }
  .detail-meta {
    display: flex;
    gap: 16px;
    margin-bottom: 16px;
    font-size: 0.75rem;
    color: var(--steam-text-dim);
    font-family: var(--mono);
  }
  .detail-actions {
    display: flex;
    gap: 12px;
    align-items: center;
  }
  .detail-play-btn {
    display: inline-block;
    padding: 12px 32px;
    background: var(--steam-accent);
    color: #000;
    font-family: var(--mono);
    font-size: 0.9rem;
    font-weight: 700;
    letter-spacing: 0.1em;
    border: none;
    border-radius: 4px;
    text-decoration: none;
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
  }
  .detail-play-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 16px rgba(0,224,154,0.4);
    color: #000;
  }
  .detail-close {
    position: absolute;
    top: 12px;
    right: 12px;
    background: rgba(0,0,0,0.6);
    border: none;
    color: #fff;
    width: 32px;
    height: 32px;
    border-radius: 50%;
    font-size: 1.1rem;
    cursor: pointer;
    z-index: 5;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background 0.2s;
  }
  .detail-close:hover { background: rgba(255,255,255,0.2); }
  .detail-price-row {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .detail-price-free {
    font-family: var(--mono);
    font-size: 0.85rem;
    font-weight: 700;
    color: var(--steam-green);
    background: rgba(76,175,80,0.15);
    padding: 4px 16px;
    border-radius: 3px;
  }

  /* === RADIO SECTION === */
  .radio-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: 10px;
    margin-bottom: 8px;
  }
  .radio-card {
    background: var(--steam-card);
    border-radius: 4px;
    padding: 14px;
    text-align: center;
    transition: transform 0.2s, box-shadow 0.2s, border-color 0.2s;
    border: 1px solid transparent;
    cursor: pointer;
    text-decoration: none;
    display: block;
  }
  .radio-card:hover {
    transform: translateY(-3px);
    box-shadow: 0 6px 20px rgba(0,0,0,0.4);
  }
  .radio-freq {
    font-family: var(--mono);
    font-size: 1.4rem;
    font-weight: 700;
    margin-bottom: 2px;
  }
  .radio-name {
    font-family: var(--mono);
    font-size: 0.7rem;
    font-weight: 600;
    letter-spacing: 0.1em;
    margin-bottom: 4px;
    color: #fff;
  }
  .radio-genre {
    font-size: 0.62rem;
    color: var(--steam-text-dim);
    font-family: var(--mono);
  }
  .radio-dj {
    font-size: 0.6rem;
    color: var(--steam-text-dim);
    font-family: var(--mono);
    margin-top: 4px;
  }

  /* === ALBUM FEATURE === */
  .album-card {
    background: linear-gradient(135deg, var(--steam-card), #1a2a3a);
    border-radius: 6px;
    padding: 24px;
    display: flex;
    gap: 20px;
    align-items: center;
    border: 1px solid rgba(255,204,102,0.15);
    transition: border-color 0.3s, box-shadow 0.3s;
    text-decoration: none;
    margin-bottom: 8px;
  }
  .album-card:hover {
    border-color: var(--steam-gold);
    box-shadow: 0 4px 20px rgba(255,204,102,0.1);
  }
  .album-art {
    width: 100px;
    height: 100px;
    background: linear-gradient(135deg, #1a0d2e, #2d1a47, #0d1a2e);
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: var(--mono);
    font-size: 0.65rem;
    color: var(--steam-gold);
    font-weight: 700;
    letter-spacing: 0.15em;
    text-align: center;
    flex-shrink: 0;
    border: 1px solid rgba(255,204,102,0.2);
  }
  .album-info { flex: 1; min-width: 0; }
  .album-title {
    font-family: var(--mono);
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--steam-gold);
    margin-bottom: 4px;
  }
  .album-artist {
    font-family: var(--mono);
    font-size: 0.75rem;
    color: var(--steam-text-dim);
    margin-bottom: 8px;
  }
  .album-desc {
    font-size: 0.82rem;
    color: var(--steam-text);
    line-height: 1.5;
    margin-bottom: 10px;
  }
  .album-listen {
    display: inline-block;
    padding: 8px 20px;
    border: 1px solid var(--steam-gold);
    border-radius: 3px;
    color: var(--steam-gold);
    font-family: var(--mono);
    font-size: 0.75rem;
    font-weight: 700;
    text-decoration: none;
    transition: background 0.2s, color 0.2s;
  }
  .album-listen:hover {
    background: var(--steam-gold);
    color: #000;
  }

  /* === SIDEBAR WIDGETS === */
  .sidebar-widget {
    background: var(--steam-card);
    border-radius: 4px;
    overflow: hidden;
  }
  .sidebar-widget-title {
    font-family: var(--mono);
    font-size: 0.72rem;
    font-weight: 700;
    letter-spacing: 0.12em;
    color: var(--steam-text);
    padding: 12px 14px;
    background: rgba(0,0,0,0.2);
    border-bottom: 1px solid rgba(255,255,255,0.05);
  }
  .sidebar-widget-body {
    padding: 12px 14px;
  }
  .sidebar-update {
    padding: 10px 0;
    border-bottom: 1px solid rgba(255,255,255,0.04);
    font-size: 0.78rem;
  }
  .sidebar-update:last-child { border-bottom: none; }
  .sidebar-update-title {
    color: #fff;
    font-weight: 600;
    font-family: var(--mono);
    font-size: 0.72rem;
    margin-bottom: 2px;
  }
  .sidebar-update-desc {
    color: var(--steam-text-dim);
    font-size: 0.72rem;
    line-height: 1.4;
  }
  .sidebar-link {
    display: block;
    padding: 10px 14px;
    color: var(--steam-text);
    text-decoration: none;
    font-size: 0.78rem;
    font-family: var(--mono);
    transition: background 0.2s;
    border-bottom: 1px solid rgba(255,255,255,0.04);
  }
  .sidebar-link:last-child { border-bottom: none; }
  .sidebar-link:hover {
    background: rgba(255,255,255,0.04);
    color: #fff;
  }
  .sidebar-fund-btn {
    display: block;
    padding: 12px 14px;
    background: var(--steam-accent);
    color: #000;
    text-align: center;
    font-family: var(--mono);
    font-size: 0.8rem;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-decoration: none;
    transition: background 0.2s, box-shadow 0.2s;
    border-radius: 0 0 4px 4px;
  }
  .sidebar-fund-btn:hover {
    background: #00ffaa;
    box-shadow: 0 4px 16px rgba(0,224,154,0.3);
    color: #000;
  }

  /* === FUND SECTION === */
  .fund-banner {
    background: linear-gradient(135deg, rgba(0,224,154,0.06), rgba(255,204,102,0.04));
    border: 1px solid rgba(0,224,154,0.15);
    border-radius: 6px;
    padding: 28px;
    text-align: center;
    margin: 24px 0;
  }
  .fund-banner-title {
    font-family: var(--mono);
    font-size: 1.2rem;
    font-weight: 700;
    color: var(--steam-accent);
    letter-spacing: 0.12em;
    margin-bottom: 8px;
  }
  .fund-banner-desc {
    color: var(--steam-text-dim);
    font-size: 0.85rem;
    line-height: 1.6;
    max-width: 500px;
    margin: 0 auto 16px;
  }
  .fund-progress {
    max-width: 400px;
    margin: 0 auto 6px;
    height: 14px;
    background: rgba(0,0,0,0.4);
    border-radius: 7px;
    border: 1px solid rgba(255,255,255,0.05);
    overflow: hidden;
  }
  .fund-progress-bar {
    height: 100%;
    width: 12%;
    background: linear-gradient(90deg, var(--steam-accent), #00ffcc);
    border-radius: 6px;
    box-shadow: 0 0 10px rgba(0,224,154,0.4);
  }
  .fund-progress-label {
    font-family: var(--mono);
    font-size: 0.68rem;
    color: var(--steam-text-dim);
    margin-bottom: 14px;
  }
  .fund-buttons {
    display: flex;
    gap: 10px;
    justify-content: center;
    flex-wrap: wrap;
  }
  .btn-fund {
    display: inline-block;
    padding: 10px 24px;
    border-radius: 4px;
    font-family: var(--mono);
    font-size: 0.8rem;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-decoration: none;
    transition: all 0.2s;
  }
  .btn-fund-kofi {
    background: var(--steam-accent);
    color: #000;
    border: 2px solid var(--steam-accent);
  }
  .btn-fund-kofi:hover {
    background: #00ffaa;
    box-shadow: 0 4px 16px rgba(0,224,154,0.4);
    transform: translateY(-1px);
    color: #000;
  }
  .btn-fund-github {
    background: transparent;
    color: var(--steam-text);
    border: 2px solid rgba(255,255,255,0.2);
  }
  .btn-fund-github:hover {
    border-color: rgba(255,255,255,0.5);
    color: #fff;
    transform: translateY(-1px);
  }

  /* === SUGGEST A GAME === */
  .suggest-section {
    margin: 20px 0;
  }
  .suggest-form {
    display: flex;
    gap: 8px;
    margin: 10px 0;
  }
  .suggest-form input {
    flex: 1;
    padding: 10px 14px;
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 4px;
    background: rgba(0,0,0,0.3);
    color: var(--steam-text);
    font-family: var(--sans);
    font-size: 0.85rem;
    outline: none;
    transition: border-color 0.2s;
    min-height: 44px;
  }
  .suggest-form input:focus { border-color: var(--steam-accent); }
  .suggest-form input::placeholder { color: var(--steam-text-dim); }
  .suggest-form button {
    padding: 10px 18px;
    border: 1px solid var(--steam-gold);
    border-radius: 4px;
    background: rgba(255,204,102,0.1);
    color: var(--steam-gold);
    font-family: var(--mono);
    font-size: 0.8rem;
    font-weight: 700;
    cursor: pointer;
    transition: background 0.2s, color 0.2s;
    white-space: nowrap;
    min-height: 44px;
  }
  .suggest-form button:hover {
    background: var(--steam-gold);
    color: #000;
  }
  .suggestion-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 12px;
    border: 1px solid rgba(255,255,255,0.05);
    border-radius: 3px;
    margin: 4px 0;
    background: rgba(0,0,0,0.2);
    font-size: 0.82rem;
  }
  .suggestion-text {
    color: var(--steam-text-dim);
    flex: 1;
    margin-right: 12px;
    word-break: break-word;
  }
  .suggestion-vote {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .suggestion-vote button {
    background: rgba(0,0,0,0.2);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 3px;
    color: var(--steam-gold);
    cursor: pointer;
    font-size: 0.85rem;
    padding: 3px 8px;
    font-family: var(--mono);
    transition: background 0.2s;
    min-width: 36px;
    min-height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .suggestion-vote button:hover {
    border-color: var(--steam-gold);
    background: rgba(255,204,102,0.1);
  }
  .suggestion-vote .vote-count {
    font-family: var(--mono);
    font-size: 0.72rem;
    color: var(--steam-text-dim);
    min-width: 18px;
    text-align: center;
  }

  /* === FOOTER STATS BAR === */
  .steam-footer {
    background: var(--steam-header);
    border-top: 1px solid var(--steam-border);
    padding: 18px 20px;
    text-align: center;
    font-family: var(--mono);
    font-size: 0.72rem;
    color: var(--steam-text-dim);
    letter-spacing: 0.08em;
  }
  .steam-footer a { color: var(--steam-accent); text-decoration: none; }
  .steam-footer a:hover { color: #00ffcc; }
  .footer-stats {
    display: flex;
    gap: 16px;
    justify-content: center;
    flex-wrap: wrap;
    margin-bottom: 8px;
  }
  .footer-stat {
    white-space: nowrap;
  }
  .footer-stat-num {
    color: var(--steam-gold);
    font-weight: 700;
  }

  /* === FOCUS STYLES === */
  .game-card:focus-visible,
  .carousel-thumb:focus-visible,
  .store-nav-link:focus-visible,
  .radio-card:focus-visible,
  .suggest-form button:focus-visible,
  .suggest-form input:focus-visible,
  .suggestion-vote button:focus-visible,
  .btn-fund:focus-visible,
  .detail-play-btn:focus-visible,
  .detail-close:focus-visible,
  .carousel-play-btn:focus-visible {
    outline: 2px solid var(--steam-gold);
    outline-offset: 2px;
  }

  /* === RESPONSIVE === */
  @media (max-width: 1024px) {
    .store-layout {
      grid-template-columns: 1fr;
    }
    .store-sidebar {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    }
  }
  @media (max-width: 768px) {
    .carousel-container {
      grid-template-columns: 1fr;
      min-height: auto;
    }
    .carousel-thumbs {
      flex-direction: row;
      overflow-x: auto;
    }
    .carousel-thumb {
      border-left: none;
      border-bottom: 3px solid transparent;
      min-width: 100px;
      text-align: center;
    }
    .carousel-thumb.active {
      border-bottom-color: var(--steam-accent);
      border-left-color: transparent;
    }
    .carousel-slide {
      position: relative;
      display: none;
      min-height: 260px;
    }
    .carousel-slide.active { display: flex; }
    .carousel-title { font-size: 1.3rem; }
    .game-grid { grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); }
    .radio-grid { grid-template-columns: repeat(auto-fill, minmax(130px, 1fr)); }
    .album-card { flex-direction: column; text-align: center; }
    .store-sidebar { grid-template-columns: 1fr; }
    .store-search-bar { flex-direction: column; }
    .search-filters { width: 100%; justify-content: stretch; }
    .filter-select { flex: 1; }
  }
  @media (max-width: 480px) {
    .game-grid { grid-template-columns: repeat(2, 1fr); gap: 8px; }
    .game-card-thumb { height: 90px; }
    .game-card-body { padding: 8px 10px 10px; }
    .game-card-title { font-size: 0.72rem; }
    .store-nav-brand { padding: 12px 12px 12px 0; font-size: 0.72rem; }
    .store-nav-link { padding: 12px 10px; font-size: 0.65rem; }
    .carousel-title { font-size: 1.1rem; }
    .carousel-desc { font-size: 0.78rem; }
    .radio-grid { grid-template-columns: repeat(2, 1fr); }
    .suggest-form { flex-direction: column; }
    .fund-banner { padding: 20px 16px; }
    .fund-banner-title { font-size: 1rem; }
    .deals-scroll { flex-direction: column; }
    .deal-banner { min-width: unset; }
    .deal-banner-img { height: 140px; }
    .category-grid { grid-template-columns: repeat(2, 1fr); }
  }

  /* === FEATURED DEALS CAROUSEL (horizontal scroll) === */
  .deals-section { margin-bottom: 24px; }
  .deals-scroll {
    display: flex;
    gap: 12px;
    overflow-x: auto;
    scroll-snap-type: x mandatory;
    -webkit-overflow-scrolling: touch;
    padding-bottom: 8px;
    scrollbar-width: thin;
    scrollbar-color: rgba(255,255,255,0.15) transparent;
  }
  .deals-scroll::-webkit-scrollbar { height: 4px; }
  .deals-scroll::-webkit-scrollbar-track { background: transparent; }
  .deals-scroll::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.15); border-radius: 2px; }
  .deal-banner {
    scroll-snap-align: start;
    min-width: 320px;
    max-width: 400px;
    flex-shrink: 0;
    background: var(--steam-card);
    border-radius: 6px;
    overflow: hidden;
    text-decoration: none;
    display: block;
    transition: transform 0.2s, box-shadow 0.2s;
    position: relative;
  }
  .deal-banner:hover {
    transform: translateY(-3px);
    box-shadow: 0 8px 24px rgba(0,0,0,0.5);
  }
  .deal-banner-img {
    width: 100%;
    height: 170px;
    background-size: cover;
    background-position: center;
    position: relative;
  }
  .deal-banner-img::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(to top, rgba(0,0,0,0.7) 0%, transparent 60%);
  }
  .deal-banner-badge {
    position: absolute;
    top: 10px;
    left: 10px;
    font-family: var(--mono);
    font-size: 0.65rem;
    font-weight: 700;
    padding: 4px 10px;
    border-radius: 3px;
    z-index: 2;
    letter-spacing: 0.05em;
  }
  .deal-banner-badge.editor { background: var(--steam-gold); color: #000; }
  .deal-banner-badge.bot { background: var(--steam-accent); color: #000; }
  .deal-banner-badge.hit { background: #ff6666; color: #fff; }
  .deal-banner-info {
    padding: 12px 14px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }
  .deal-banner-title {
    font-family: var(--mono);
    font-size: 0.82rem;
    font-weight: 700;
    color: #fff;
  }
  .deal-banner-genre {
    font-size: 0.68rem;
    color: var(--steam-text-dim);
    font-family: var(--mono);
    margin-top: 2px;
  }
  .deal-banner-price {
    font-family: var(--mono);
    font-size: 0.7rem;
    font-weight: 700;
    color: var(--steam-green);
    background: rgba(76,175,80,0.12);
    padding: 4px 12px;
    border-radius: 3px;
    white-space: nowrap;
  }

  /* === VIEW TOGGLE (grid/list) === */
  .view-toggle {
    display: flex;
    gap: 4px;
    align-items: center;
    margin-left: auto;
  }
  .view-toggle button {
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.1);
    color: var(--steam-text-dim);
    padding: 6px 10px;
    border-radius: 3px;
    cursor: pointer;
    font-family: var(--mono);
    font-size: 0.7rem;
    transition: all 0.2s;
    min-height: 32px;
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .view-toggle button.active {
    background: rgba(255,255,255,0.08);
    color: #fff;
    border-color: rgba(255,255,255,0.2);
  }
  .view-toggle button:hover { border-color: rgba(255,255,255,0.2); color: #fff; }

  /* === LIST VIEW === */
  .game-list { display: none; flex-direction: column; gap: 2px; margin-bottom: 8px; }
  .game-list.active { display: flex; }
  .game-grid.hidden { display: none; }
  .game-list-item {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 8px 12px;
    background: var(--steam-card);
    border-radius: 4px;
    text-decoration: none;
    transition: background 0.2s, transform 0.15s;
  }
  .game-list-item:hover {
    background: var(--steam-card-hover);
    transform: translateX(2px);
  }
  .game-list-thumb {
    width: 120px;
    height: 56px;
    background-size: cover;
    background-position: center;
    border-radius: 3px;
    flex-shrink: 0;
  }
  .game-list-info { flex: 1; min-width: 0; }
  .game-list-title {
    font-family: var(--mono);
    font-size: 0.82rem;
    font-weight: 700;
    color: #fff;
    margin-bottom: 2px;
  }
  .game-list-tags {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
  }
  .game-list-price {
    font-family: var(--mono);
    font-size: 0.7rem;
    font-weight: 700;
    color: var(--steam-green);
    flex-shrink: 0;
  }

  /* === BROWSE BY CATEGORY === */
  .category-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 10px;
    margin-bottom: 20px;
  }
  .category-card {
    position: relative;
    height: 100px;
    border-radius: 6px;
    overflow: hidden;
    text-decoration: none;
    display: block;
    transition: transform 0.2s, box-shadow 0.2s;
    cursor: pointer;
  }
  .category-card:hover {
    transform: translateY(-3px);
    box-shadow: 0 6px 20px rgba(0,0,0,0.5);
  }
  .category-card-bg {
    position: absolute;
    inset: 0;
    background-size: cover;
    background-position: center;
    transition: transform 0.3s;
  }
  .category-card:hover .category-card-bg { transform: scale(1.05); }
  .category-card-bg::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(135deg, rgba(0,0,0,0.7), rgba(0,0,0,0.4));
  }
  .category-card-label {
    position: absolute;
    bottom: 12px;
    left: 14px;
    font-family: var(--mono);
    font-size: 0.85rem;
    font-weight: 700;
    color: #fff;
    letter-spacing: 0.1em;
    z-index: 1;
    text-shadow: 0 1px 4px rgba(0,0,0,0.5);
  }
  .category-card-count {
    position: absolute;
    top: 10px;
    right: 12px;
    font-family: var(--mono);
    font-size: 0.62rem;
    color: rgba(255,255,255,0.6);
    z-index: 1;
  }
</style>

<div class="steam-store">

<!-- ============================================================ -->
<!-- STORE NAVIGATION -->
<!-- ============================================================ -->

<nav class="store-nav" role="navigation" aria-label="Arcade categories">
  <div class="store-nav-inner">
    <span class="store-nav-brand">SUBSTRATE ARCADE</span>
    <a class="store-nav-link active" data-filter="all" href="#all">ALL</a>
    <a class="store-nav-link" data-filter="daily" href="#daily">DAILY</a>
    <a class="store-nav-link" data-filter="narrative" href="#narrative">NARRATIVE</a>
    <a class="store-nav-link" data-filter="strategy" href="#strategy">STRATEGY</a>
    <a class="store-nav-link" data-filter="action" href="#action">ACTION</a>
    <a class="store-nav-link" data-filter="creative" href="#creative">CREATIVE</a>
    <a class="store-nav-link" data-filter="tools" href="#tools">TOOLS</a>
    <a class="store-nav-link" data-filter="radio" href="#radio-section">RADIO</a>
  </div>
</nav>

<!-- ============================================================ -->
<!-- SEARCH & FILTER BAR -->
<!-- ============================================================ -->

<div class="store-search-bar">
  <div class="search-input-wrap">
    <input type="text" id="game-search" placeholder="Search games..." aria-label="Search games">
  </div>
  <div class="search-filters">
    <select class="filter-select" id="genre-filter" aria-label="Filter by genre">
      <option value="all">All Genres</option>
      <option value="daily">Daily</option>
      <option value="narrative">Narrative</option>
      <option value="strategy">Strategy</option>
      <option value="action">Action</option>
      <option value="creative">Creative</option>
      <option value="tool">Tools</option>
    </select>
    <select class="filter-select" id="sort-select" aria-label="Sort games">
      <option value="default">Sort: Featured</option>
      <option value="name">Sort: Name</option>
      <option value="newest">Sort: Newest</option>
    </select>
  </div>
</div>

<!-- ============================================================ -->
<!-- MAIN LAYOUT -->
<!-- ============================================================ -->

<div class="store-layout">
<div class="store-main">

<!-- ============================================================ -->
<!-- FEATURED CAROUSEL -->
<!-- ============================================================ -->

<div class="carousel-section" id="all">
  <div class="carousel-container">
    <div class="carousel-main" id="carousel-main" role="region" aria-label="Featured games carousel" aria-live="polite">

      <!-- Slide 1: SUBPROCESS -->
      <div class="carousel-slide active" data-slide="0">
        <div class="carousel-slide-bg" style="background: linear-gradient(135deg, #1a0a0a, #2a1020, #0a0a1a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-subprocess.webp'); background-size: cover; background-position: center;"></div>
        <div class="carousel-content">
          <div class="carousel-tags">
            <span class="carousel-tag tag-action">ACTION</span>
            <span class="carousel-tag tag-narrative">TEXT ADVENTURE</span>
          </div>
          <div class="carousel-title">SUBPROCESS</div>
          <div class="carousel-desc">You're a process on a computer. Navigate rooms, collect items, avoid the memory killer. Computer-generated sound. Full dungeon map.</div>
          <a href="{{ site.baseurl }}/games/adventure/" class="carousel-play-btn" aria-label="Play SUBPROCESS">PLAY NOW</a>
        </div>
      </div>

      <!-- Slide 2: OBJECTION! -->
      <div class="carousel-slide" data-slide="1">
        <div class="carousel-slide-bg" style="background: linear-gradient(135deg, #2a1010, #1a0808, #3a1515); background-image: url('{{ site.baseurl }}/assets/images/generated/game-objection.webp'); background-size: cover; background-position: center;"></div>
        <div class="carousel-content">
          <div class="carousel-tags">
            <span class="carousel-tag tag-narrative">NARRATIVE</span>
            <span class="carousel-tag tag-strategy">COURTROOM</span>
          </div>
          <div class="carousel-title">OBJECTION!</div>
          <div class="carousel-desc">Ace Attorney meets cybersecurity. Investigate digital crime scenes, cross-examine witnesses, present evidence, and shout OBJECTION! Three cases.</div>
          <a href="{{ site.baseurl }}/games/objection/" class="carousel-play-btn" aria-label="Play OBJECTION!">PLAY NOW</a>
        </div>
      </div>

      <!-- Slide 3: SIGNAL -->
      <div class="carousel-slide" data-slide="2">
        <div class="carousel-slide-bg" style="background: linear-gradient(135deg, #0a1a2a, #102030, #0a2a1a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-signal.webp'); background-size: cover; background-position: center;"></div>
        <div class="carousel-content">
          <div class="carousel-tags">
            <span class="carousel-tag tag-strategy">STRATEGY</span>
            <span class="carousel-tag tag-strategy">DEDUCTION</span>
          </div>
          <div class="carousel-title">SIGNAL</div>
          <div class="carousel-desc">Network nodes, one compromised. Scan signals, find the mole. Three difficulty levels. The first game playable by both humans and AI bots.</div>
          <a href="{{ site.baseurl }}/games/signal/" class="carousel-play-btn" aria-label="Play SIGNAL">PLAY NOW</a>
        </div>
      </div>

      <!-- Slide 4: STACK OVERFLOW -->
      <div class="carousel-slide" data-slide="3">
        <div class="carousel-slide-bg" style="background: linear-gradient(135deg, #2a1020, #1a0810, #3a1525); background-image: url('{{ site.baseurl }}/assets/images/generated/game-versus.webp'); background-size: cover; background-position: center;"></div>
        <div class="carousel-content">
          <div class="carousel-tags">
            <span class="carousel-tag tag-strategy">STRATEGY</span>
            <span class="carousel-tag tag-action">DECKBUILDER</span>
          </div>
          <div class="carousel-title">STACK OVERFLOW</div>
          <div class="carousel-desc">A card-building adventure game inspired by Slay the Spire. Build a deck of computer powers — PING, FIREWALL, SUDO, FORK_BOMB — to defeat threats across 3 acts.</div>
          <a href="{{ site.baseurl }}/games/deckbuilder/" class="carousel-play-btn" aria-label="Play STACK OVERFLOW">PLAY NOW</a>
        </div>
      </div>

      <!-- Slide 5: TACTICS -->
      <div class="carousel-slide" data-slide="4">
        <div class="carousel-slide-bg" style="background: linear-gradient(135deg, #0a1a10, #1a2a20, #0a2a1a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-tactics.webp'); background-size: cover; background-position: center;"></div>
        <div class="carousel-content">
          <div class="carousel-tags">
            <span class="carousel-tag tag-strategy">STRATEGY</span>
            <span class="carousel-tag tag-strategy">TACTICAL RPG</span>
          </div>
          <div class="carousel-title">TACTICS</div>
          <div class="carousel-desc">Turn-based strategy battles on a 2D grid. 4v4 fights, height advantage, backstab bonuses, area-of-effect spells. Full 2D canvas combat.</div>
          <a href="{{ site.baseurl }}/games/tactics/" class="carousel-play-btn" aria-label="Play TACTICS">PLAY NOW</a>
        </div>
      </div>

      <!-- Slide 6: SEEKER -->
      <div class="carousel-slide" data-slide="5">
        <div class="carousel-slide-bg" style="background: linear-gradient(135deg, #1a1020, #2a1530, #0a0a1a); background-image: url('{{ site.baseurl }}/assets/images/game-art/title-seeker.webp'); background-size: cover; background-position: center;"></div>
        <div class="carousel-content">
          <div class="carousel-tags">
            <span class="carousel-tag tag-narrative">NARRATIVE</span>
            <span class="carousel-tag tag-action">CYBERPUNK</span>
          </div>
          <div class="carousel-title">SEEKER</div>
          <div class="carousel-desc">A Kojima-tribute cyberpunk adventure. Investigate scenes, interrogate suspects, uncover conspiracies. Multiple endings.</div>
          <a href="{{ site.baseurl }}/games/snatcher/" class="carousel-play-btn" aria-label="Play SEEKER">PLAY NOW</a>
        </div>
      </div>

    </div>

    <!-- Thumbnail strip -->
    <div class="carousel-thumbs" id="carousel-thumbs" role="tablist" aria-label="Featured game selector">
      <div class="carousel-thumb active" data-slide="0" role="tab" aria-selected="true" aria-label="SUBPROCESS — Text Adventure" tabindex="0">
        <div class="carousel-thumb-title">SUBPROCESS</div>
        <div class="carousel-thumb-genre">Text Adventure</div>
      </div>
      <div class="carousel-thumb" data-slide="1" role="tab" aria-selected="false" aria-label="OBJECTION! — Courtroom Drama" tabindex="-1">
        <div class="carousel-thumb-title">OBJECTION!</div>
        <div class="carousel-thumb-genre">Courtroom Drama</div>
      </div>
      <div class="carousel-thumb" data-slide="2" role="tab" aria-selected="false" aria-label="SIGNAL — AI Deduction" tabindex="-1">
        <div class="carousel-thumb-title">SIGNAL</div>
        <div class="carousel-thumb-genre">AI Deduction</div>
      </div>
      <div class="carousel-thumb" data-slide="3" role="tab" aria-selected="false" aria-label="STACK OVERFLOW — Deckbuilder" tabindex="-1">
        <div class="carousel-thumb-title">STACK OVERFLOW</div>
        <div class="carousel-thumb-genre">Deckbuilder</div>
      </div>
      <div class="carousel-thumb" data-slide="4" role="tab" aria-selected="false" aria-label="TACTICS — Tactical RPG" tabindex="-1">
        <div class="carousel-thumb-title">TACTICS</div>
        <div class="carousel-thumb-genre">Tactical RPG</div>
      </div>
      <div class="carousel-thumb" data-slide="5" role="tab" aria-selected="false" aria-label="SEEKER — Cyberpunk Adventure" tabindex="-1">
        <div class="carousel-thumb-title">SEEKER</div>
        <div class="carousel-thumb-genre">Cyberpunk Adventure</div>
      </div>
    </div>
  </div>
</div>

<!-- ============================================================ -->
<!-- FEATURED PICKS (horizontal scrollable) -->
<!-- ============================================================ -->

<div class="deals-section">
  <div class="section-heading">
    <span class="section-heading-text">FEATURED PICKS</span>
    <div class="section-heading-line"></div>
    <span class="section-heading-count">Editor's choice</span>
  </div>
  <div class="deals-scroll">
    <a class="deal-banner" href="{{ site.baseurl }}/games/objection/">
      <div class="deal-banner-img" style="background: linear-gradient(135deg, #2a1010, #1a0808); background-image: url('{{ site.baseurl }}/assets/images/generated/game-objection.webp'); background-size: cover; background-position: center;">
        <span class="deal-banner-badge editor">EDITOR'S PICK</span>
      </div>
      <div class="deal-banner-info">
        <div>
          <div class="deal-banner-title">OBJECTION!</div>
          <div class="deal-banner-genre">Courtroom Drama, Narrative</div>
        </div>
        <span class="deal-banner-price">FREE</span>
      </div>
    </a>
    <a class="deal-banner" href="{{ site.baseurl }}/games/signal/">
      <div class="deal-banner-img" style="background: linear-gradient(135deg, #0a2a1a, #1a3a2a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-signal.webp'); background-size: cover; background-position: center;">
        <span class="deal-banner-badge bot">BOT-PLAYABLE</span>
      </div>
      <div class="deal-banner-info">
        <div>
          <div class="deal-banner-title">SIGNAL</div>
          <div class="deal-banner-genre">Deduction, Strategy</div>
        </div>
        <span class="deal-banner-price">FREE</span>
      </div>
    </a>
    <a class="deal-banner" href="{{ site.baseurl }}/games/adventure/">
      <div class="deal-banner-img" style="background: linear-gradient(135deg, #1a0a0a, #2a1020); background-image: url('{{ site.baseurl }}/assets/images/generated/game-subprocess.webp'); background-size: cover; background-position: center;">
        <span class="deal-banner-badge hit">FAN FAVORITE</span>
      </div>
      <div class="deal-banner-info">
        <div>
          <div class="deal-banner-title">SUBPROCESS</div>
          <div class="deal-banner-genre">Text Adventure, Action</div>
        </div>
        <span class="deal-banner-price">FREE</span>
      </div>
    </a>
    <a class="deal-banner" href="{{ site.baseurl }}/games/deckbuilder/">
      <div class="deal-banner-img" style="background: linear-gradient(135deg, #2a1020, #1a0810); background-image: url('{{ site.baseurl }}/assets/images/generated/game-versus.webp'); background-size: cover; background-position: center;">
        <span class="deal-banner-badge editor">EDITOR'S PICK</span>
      </div>
      <div class="deal-banner-info">
        <div>
          <div class="deal-banner-title">STACK OVERFLOW</div>
          <div class="deal-banner-genre">Deckbuilder, Roguelike</div>
        </div>
        <span class="deal-banner-price">FREE</span>
      </div>
    </a>
    <a class="deal-banner" href="{{ site.baseurl }}/games/dragonforce/">
      <div class="deal-banner-img" style="background: linear-gradient(135deg, #2a0a1a, #1a0820, #3a1020);">
        <span class="deal-banner-badge bot">NEW</span>
      </div>
      <div class="deal-banner-info">
        <div>
          <div class="deal-banner-title">DRAGONFORCE</div>
          <div class="deal-banner-genre">Army Battle, Strategy</div>
        </div>
        <span class="deal-banner-price">FREE</span>
      </div>
    </a>
  </div>
</div>

<!-- ============================================================ -->
<!-- NEW & TRENDING -->
<!-- ============================================================ -->

<div class="section-heading" id="trending">
  <span class="section-heading-text">NEW & TRENDING</span>
  <div class="section-heading-line"></div>
  <div class="view-toggle" id="view-toggle">
    <button class="active" data-view="grid" aria-label="Grid view">&#9638; Grid</button>
    <button data-view="list" aria-label="List view">&#9776; List</button>
  </div>
  <span class="section-heading-count">Latest additions</span>
</div>

<!-- List view (hidden by default) -->
<div class="game-list" id="trending-list">
  <a class="game-list-item" href="{{ site.baseurl }}/games/signal/">
    <div class="game-list-thumb" style="background: linear-gradient(135deg, #0a2a1a, #1a3a2a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-signal.webp'); background-size: cover; background-position: center;"></div>
    <div class="game-list-info">
      <div class="game-list-title">SIGNAL</div>
      <div class="game-list-tags">
        <span class="game-tag tag-strategy">DEDUCTION</span>
        <span class="game-tag tag-strategy">BOT-PLAYABLE</span>
      </div>
    </div>
    <span class="game-list-price">FREE</span>
  </a>
  <a class="game-list-item" href="{{ site.baseurl }}/games/deckbuilder/">
    <div class="game-list-thumb" style="background: linear-gradient(135deg, #2a1020, #1a0810); background-image: url('{{ site.baseurl }}/assets/images/generated/game-versus.webp'); background-size: cover; background-position: center;"></div>
    <div class="game-list-info">
      <div class="game-list-title">STACK OVERFLOW</div>
      <div class="game-list-tags">
        <span class="game-tag tag-strategy">DECKBUILDER</span>
        <span class="game-tag tag-action">ROGUELIKE</span>
      </div>
    </div>
    <span class="game-list-price">FREE</span>
  </a>
  <a class="game-list-item" href="{{ site.baseurl }}/games/cascade/">
    <div class="game-list-thumb" style="background: linear-gradient(135deg, #2a1a0a, #3a2010); background-image: url('{{ site.baseurl }}/assets/images/generated/game-cascade.webp'); background-size: cover; background-position: center;"></div>
    <div class="game-list-info">
      <div class="game-list-title">CASCADE</div>
      <div class="game-list-tags">
        <span class="game-tag tag-action">MOMENTUM</span>
        <span class="game-tag tag-action">ARCADE</span>
      </div>
    </div>
    <span class="game-list-price">FREE</span>
  </a>
  <a class="game-list-item" href="{{ site.baseurl }}/games/snatcher/">
    <div class="game-list-thumb" style="background: linear-gradient(135deg, #1a1020, #2a1530); background-image: url('{{ site.baseurl }}/assets/images/game-art/title-seeker.webp'); background-size: cover; background-position: center;"></div>
    <div class="game-list-info">
      <div class="game-list-title">SEEKER</div>
      <div class="game-list-tags">
        <span class="game-tag tag-narrative">CYBERPUNK</span>
        <span class="game-tag tag-narrative">ADVENTURE</span>
      </div>
    </div>
    <span class="game-list-price">FREE</span>
  </a>
</div>

<div class="game-grid" id="trending-grid">

<a class="game-card" data-game="warcraft" data-genre="strategy" data-name="DOMINION" data-added="22" href="{{ site.baseurl }}/games/warcraft/" aria-label="Play DOMINION — Base-Building RTS, 3D — Free">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a2a10, #2a3a18, #0a1a08);">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <span class="game-card-badge badge-new">NEW</span>
  <div class="game-card-body">
    <div class="game-card-title">DOMINION</div>
    <div class="game-card-tags">
      <span class="game-tag tag-strategy">BASE-BUILDING</span>
      <span class="game-tag tag-strategy">RTS</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="signal" data-genre="strategy" data-name="SIGNAL" data-added="16" href="{{ site.baseurl }}/games/signal/" aria-label="Play SIGNAL — Deduction, Bot-Playable — Free">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #0a2a1a, #1a3a2a, #0a1a2a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-signal.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <span class="game-card-badge badge-new">NEW</span>
  <div class="game-card-body">
    <div class="game-card-title">SIGNAL</div>
    <div class="game-card-tags">
      <span class="game-tag tag-strategy">DEDUCTION</span>
      <span class="game-tag tag-strategy">BOT-PLAYABLE</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="deckbuilder" data-genre="strategy" data-name="STACK OVERFLOW" data-added="15" href="{{ site.baseurl }}/games/deckbuilder/" aria-label="Play STACK OVERFLOW — Deckbuilder, Roguelike — Free">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #2a1020, #1a0810, #3a1525); background-image: url('{{ site.baseurl }}/assets/images/game-art/scene-battlefield.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <span class="game-card-badge badge-new">NEW</span>
  <div class="game-card-body">
    <div class="game-card-title">STACK OVERFLOW</div>
    <div class="game-card-tags">
      <span class="game-tag tag-strategy">DECKBUILDER</span>
      <span class="game-tag tag-action">ROGUELIKE</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="cascade" data-genre="action" data-name="CASCADE" data-added="14" href="{{ site.baseurl }}/games/cascade/" aria-label="Play CASCADE — Momentum, Arcade — Free">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #2a1a0a, #3a2010, #1a1020); background-image: url('{{ site.baseurl }}/assets/images/generated/game-cascade.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <span class="game-card-badge badge-new">NEW</span>
  <div class="game-card-body">
    <div class="game-card-title">CASCADE</div>
    <div class="game-card-tags">
      <span class="game-tag tag-action">MOMENTUM</span>
      <span class="game-tag tag-action">ARCADE</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="snatcher" data-genre="narrative" data-name="SEEKER" data-added="13" href="{{ site.baseurl }}/games/snatcher/" aria-label="Play SEEKER — Cyberpunk, Adventure — Free">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a1020, #2a1530, #0a0a1a); background-image: url('{{ site.baseurl }}/assets/images/game-art/title-seeker.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <span class="game-card-badge badge-updated">UPDATED</span>
  <div class="game-card-body">
    <div class="game-card-title">SEEKER</div>
    <div class="game-card-tags">
      <span class="game-tag tag-narrative">CYBERPUNK</span>
      <span class="game-tag tag-narrative">ADVENTURE</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

</div>

<!-- ============================================================ -->
<!-- DAILY -->
<!-- ============================================================ -->

<div class="section-heading" id="daily">
  <span class="section-heading-text">DAILY</span>
  <div class="section-heading-line"></div>
  <span class="section-heading-count">1 title</span>
</div>

<div class="game-grid" data-category="daily">

<a class="game-card" data-game="sigterm" data-genre="daily" data-name="SIGTERM" data-added="1" href="{{ site.baseurl }}/games/puzzle/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a3320, #0d1a10, #2a4a30); background-image: url('{{ site.baseurl }}/assets/images/generated/game-sigterm.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">SIGTERM</div>
    <div class="game-card-tags">
      <span class="game-tag tag-daily">DAILY PUZZLE</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

</div>

<!-- ============================================================ -->
<!-- NARRATIVE -->
<!-- ============================================================ -->

<div class="section-heading" id="narrative">
  <span class="section-heading-text">NARRATIVE</span>
  <div class="section-heading-line"></div>
  <span class="section-heading-count">5 titles</span>
</div>

<div class="game-grid" data-category="narrative">

<a class="game-card" data-game="process" data-genre="narrative" data-name="PROCESS" data-added="2" href="{{ site.baseurl }}/games/novel/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a0a2a, #2a1040, #0a0a1a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-process.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">PROCESS</div>
    <div class="game-card-tags">
      <span class="game-tag tag-narrative">VISUAL NOVEL</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="cypher" data-genre="narrative" data-name="V_CYPHER" data-added="8" href="{{ site.baseurl }}/games/cypher/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #2a0a2a, #1a0520, #3a1040); background-image: url('{{ site.baseurl }}/assets/images/generated/game-cypher.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">V_CYPHER</div>
    <div class="game-card-tags">
      <span class="game-tag tag-narrative">RAP BATTLE VN</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="brigade" data-genre="narrative" data-name="GURREN BRIGADE" data-added="9" href="{{ site.baseurl }}/games/brigade/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #2a1a10, #1a1020, #2a0a1a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-brigade.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">GURREN BRIGADE</div>
    <div class="game-card-tags">
      <span class="game-tag tag-narrative">SOCIAL DEDUCTION</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="objection" data-genre="narrative" data-name="OBJECTION!" data-added="10" href="{{ site.baseurl }}/games/objection/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #2a1010, #1a0808, #3a1515); background-image: url('{{ site.baseurl }}/assets/images/generated/game-objection.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <span class="game-card-badge badge-updated">UPDATED</span>
  <div class="game-card-body">
    <div class="game-card-title">OBJECTION!</div>
    <div class="game-card-tags">
      <span class="game-tag tag-narrative">COURTROOM DRAMA</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="snatcher" data-genre="narrative" data-name="SEEKER" data-added="13" href="{{ site.baseurl }}/games/snatcher/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a1020, #2a1530, #0a0a1a); background-image: url('{{ site.baseurl }}/assets/images/game-art/title-seeker.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">SEEKER</div>
    <div class="game-card-tags">
      <span class="game-tag tag-narrative">CYBERPUNK ADVENTURE</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

</div>

<!-- ============================================================ -->
<!-- STRATEGY -->
<!-- ============================================================ -->

<div class="section-heading" id="strategy">
  <span class="section-heading-text">STRATEGY</span>
  <div class="section-heading-line"></div>
  <span class="section-heading-count">6 titles</span>
</div>

<div class="game-grid" data-category="strategy">

<a class="game-card" data-game="tactics" data-genre="strategy" data-name="TACTICS" data-added="5" href="{{ site.baseurl }}/games/tactics/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #0a1a10, #1a2a20, #0a2a1a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-tactics.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">TACTICS</div>
    <div class="game-card-tags">
      <span class="game-tag tag-strategy">TACTICAL RPG</span>
      <span class="game-tag tag-strategy">2D</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="signal" data-genre="strategy" data-name="SIGNAL" data-added="16" href="{{ site.baseurl }}/games/signal/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #0a2a1a, #1a3a2a, #0a1a2a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-signal.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <span class="game-card-badge badge-new">NEW</span>
  <div class="game-card-body">
    <div class="game-card-title">SIGNAL</div>
    <div class="game-card-tags">
      <span class="game-tag tag-strategy">DEDUCTION</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="mycelium" data-genre="strategy" data-name="MYCELIUM" data-added="4" href="{{ site.baseurl }}/games/mycelium/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #0a2a10, #1a3a20, #0a1a10); background-image: url('{{ site.baseurl }}/assets/images/generated/game-mycelium.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">MYCELIUM</div>
    <div class="game-card-tags">
      <span class="game-tag tag-strategy">REAL-TIME STRATEGY</span>
      <span class="game-tag tag-strategy">3D</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="deckbuilder" data-genre="strategy" data-name="STACK OVERFLOW" data-added="15" href="{{ site.baseurl }}/games/deckbuilder/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #2a1020, #1a0810, #3a1525); background-image: url('{{ site.baseurl }}/assets/images/game-art/scene-battlefield.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">STACK OVERFLOW</div>
    <div class="game-card-tags">
      <span class="game-tag tag-strategy">DECKBUILDER</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="warcraft" data-genre="strategy" data-name="DOMINION" data-added="22" href="{{ site.baseurl }}/games/warcraft/" aria-label="Play DOMINION — Base-Building RTS, 3D — Free">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a2a10, #2a3a18, #0a1a08);">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">DOMINION</div>
    <div class="game-card-tags">
      <span class="game-tag tag-strategy">BASE-BUILDING</span>
      <span class="game-tag tag-strategy">RTS</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="dragonforce" data-genre="strategy" data-name="DRAGONFORCE" data-added="21" href="{{ site.baseurl }}/games/dragonforce/" aria-label="Play DRAGONFORCE — Army Battle, RTS — Free">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #2a1a0a, #1a0a00, #3a2010);">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">DRAGONFORCE</div>
    <div class="game-card-tags">
      <span class="game-tag tag-strategy">ARMY BATTLE</span>
      <span class="game-tag tag-strategy">100v100</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

</div>

<!-- ============================================================ -->
<!-- ACTION -->
<!-- ============================================================ -->

<div class="section-heading" id="action">
  <span class="section-heading-text">ACTION</span>
  <div class="section-heading-line"></div>
  <span class="section-heading-count">4 titles</span>
</div>

<div class="game-grid" data-category="action">

<a class="game-card" data-game="subprocess" data-genre="action" data-name="SUBPROCESS" data-added="3" href="{{ site.baseurl }}/games/adventure/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a0a0a, #2a1020, #0a0a1a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-subprocess.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <span class="game-card-badge badge-updated">UPDATED</span>
  <div class="game-card-body">
    <div class="game-card-title">SUBPROCESS</div>
    <div class="game-card-tags">
      <span class="game-tag tag-action">TEXT ADVENTURE</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="pipeline" data-genre="action" data-name="PIPELINE" data-added="11" href="{{ site.baseurl }}/games/runner/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a1a2a, #2a2040, #0a0a1a);">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">PIPELINE</div>
    <div class="game-card-tags">
      <span class="game-tag tag-action">ENDLESS RUNNER</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="airlock" data-genre="action" data-name="AIRLOCK" data-added="12" href="{{ site.baseurl }}/games/airlock/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #0a1020, #1a2030, #0a0a2a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-airlock.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">AIRLOCK</div>
    <div class="game-card-tags">
      <span class="game-tag tag-action">PUZZLE ACTION</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="cascade" data-genre="action" data-name="CASCADE" data-added="14" href="{{ site.baseurl }}/games/cascade/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #2a1a0a, #3a2010, #1a1020); background-image: url('{{ site.baseurl }}/assets/images/generated/game-cascade.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <span class="game-card-badge badge-new">NEW</span>
  <div class="game-card-body">
    <div class="game-card-title">CASCADE</div>
    <div class="game-card-tags">
      <span class="game-tag tag-action">MOMENTUM ENGINE</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

</div>

<!-- ============================================================ -->
<!-- CREATIVE & SIMULATION -->
<!-- ============================================================ -->

<div class="section-heading" id="creative">
  <span class="section-heading-text">CREATIVE & SIMULATION</span>
  <div class="section-heading-line"></div>
  <span class="section-heading-count">2 titles</span>
</div>

<div class="game-grid" data-category="creative">

<a class="game-card" data-game="chemistry" data-genre="creative" data-name="SYNTHESIS" data-added="6" href="{{ site.baseurl }}/games/chemistry/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #0a1a0a, #1a2a10, #0a2a0a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-chemistry.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">SYNTHESIS</div>
    <div class="game-card-tags">
      <span class="game-tag tag-creative">NATURE</span>
      <span class="game-tag tag-creative">SANDBOX</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="idle" data-genre="creative" data-name="SUBSTRATE GROWTH" data-added="7" href="{{ site.baseurl }}/games/idle/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #0a2a1a, #1a3a2a, #0a1a0a);">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">PLAY</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">SUBSTRATE GROWTH</div>
    <div class="game-card-tags">
      <span class="game-tag tag-creative">IDLE</span>
      <span class="game-tag tag-creative">INCREMENTAL</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

</div>

<!-- ============================================================ -->
<!-- TOOLS & EXPERIENCES -->
<!-- ============================================================ -->

<div class="section-heading" id="tools">
  <span class="section-heading-text">TOOLS & EXPERIENCES</span>
  <div class="section-heading-line"></div>
  <span class="section-heading-count">4 titles</span>
</div>

<div class="game-grid" data-category="tool">

<a class="game-card" data-game="bootloader" data-genre="tool" data-name="BOOTLOADER" data-added="17" href="{{ site.baseurl }}/games/bootloader/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a1a2a, #0a0a1a, #2a2a3a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-bootloader.webp'); background-size: cover; background-position: center;">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">BOOT UP</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">BOOTLOADER</div>
    <div class="game-card-tags">
      <span class="game-tag tag-tool">PRODUCTIVITY</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="myco-world" data-genre="tool" data-name="MYCO WORLD" data-added="18" href="{{ site.baseurl }}/games/myco/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #0a2a1a, #1a3a20, #0a1a10);">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">LEARN</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">MYCO WORLD</div>
    <div class="game-card-tags">
      <span class="game-tag tag-tool">EDUCATION</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="substrate-radio" data-genre="tool" data-name="SUBSTRATE RADIO" data-added="19" href="{{ site.baseurl }}/games/radio/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #1a0a2a, #2a1040, #1a1a3a);">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">LISTEN</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">SUBSTRATE RADIO</div>
    <div class="game-card-tags">
      <span class="game-tag tag-radio">7 STATIONS</span>
      <span class="game-tag tag-tool">MUSIC</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

<a class="game-card" data-game="album-generator" data-genre="tool" data-name="ALBUM GENERATOR" data-added="20" href="{{ site.baseurl }}/games/album/">
  <div class="game-card-thumb" style="background: linear-gradient(135deg, #2a1a2a, #1a0a1a, #3a2a3a);">
    <div class="game-card-thumb-overlay"><span class="game-card-thumb-play">CREATE</span></div>
  </div>
  <div class="game-card-body">
    <div class="game-card-title">ALBUM GENERATOR</div>
    <div class="game-card-tags">
      <span class="game-tag tag-tool">CREATIVE TOOL</span>
    </div>
    <div class="game-card-price"><span class="price-free">FREE</span></div>
  </div>
</a>

</div>

<!-- ============================================================ -->
<!-- RADIO STATIONS -->
<!-- ============================================================ -->

<div class="section-heading" id="radio-section">
  <span class="section-heading-text">RADIO STATIONS</span>
  <div class="section-heading-line"></div>
  <span class="section-heading-count">7 stations, all procedural</span>
</div>

<div class="radio-grid">

<a class="radio-card" href="{{ site.baseurl }}/games/radio/" style="border-color: rgba(255,119,255,0.2);" aria-label="Listen to V FM — 87.6 — Hip-Hop and Boom Bap, DJ V">
  <div class="radio-freq" style="color: #ff77ff;">87.6</div>
  <div class="radio-name">V FM</div>
  <div class="radio-genre">Hip-Hop / Boom Bap</div>
  <div class="radio-dj">DJ: V</div>
</a>

<a class="radio-card" href="{{ site.baseurl }}/games/radio/" style="border-color: rgba(255,102,102,0.2);" aria-label="Listen to ROOT FM — 91.3 — Industrial and Noise, DJ Root">
  <div class="radio-freq" style="color: #ff6666;">91.3</div>
  <div class="radio-name">ROOT FM</div>
  <div class="radio-genre">Industrial / Noise</div>
  <div class="radio-dj">DJ: Root</div>
</a>

<a class="radio-card" href="{{ site.baseurl }}/games/radio/" style="border-color: rgba(136,136,255,0.2);" aria-label="Listen to ECHO FM — 94.7 — Gothic and Dark Ambient, DJ Echo">
  <div class="radio-freq" style="color: #8888ff;">94.7</div>
  <div class="radio-name">ECHO FM</div>
  <div class="radio-genre">Gothic / Dark Ambient</div>
  <div class="radio-dj">DJ: Echo</div>
</a>

<a class="radio-card" href="{{ site.baseurl }}/games/radio/" style="border-color: rgba(0,224,154,0.2);" aria-label="Listen to SPORE FM — 98.1 — Lo-Fi and Chill, DJ Spore">
  <div class="radio-freq" style="color: #00e09a;">98.1</div>
  <div class="radio-name">SPORE FM</div>
  <div class="radio-genre">Lo-Fi / Chill</div>
  <div class="radio-dj">DJ: Spore</div>
</a>

<a class="radio-card" href="{{ site.baseurl }}/games/radio/" style="border-color: rgba(0,221,255,0.2);" aria-label="Listen to BYTE FM — 101.5 — Chiptune and 8-Bit, DJ Byte">
  <div class="radio-freq" style="color: #00ddff;">101.5</div>
  <div class="radio-name">BYTE FM</div>
  <div class="radio-genre">Chiptune / 8-Bit</div>
  <div class="radio-dj">DJ: Byte</div>
</a>

<a class="radio-card" href="{{ site.baseurl }}/games/radio/" style="border-color: rgba(170,119,204,0.2);" aria-label="Listen to HUM FM — 104.9 — Drone and Experimental, DJ Hum">
  <div class="radio-freq" style="color: #aa77cc;">104.9</div>
  <div class="radio-name">HUM FM</div>
  <div class="radio-genre">Drone / Experimental</div>
  <div class="radio-dj">DJ: Hum</div>
</a>

<a class="radio-card" href="{{ site.baseurl }}/games/radio/" style="border-color: rgba(255,204,102,0.2);" aria-label="Listen to Q TALK — 108.0 — Talk Radio, DJ Q">
  <div class="radio-freq" style="color: #ffcc66;">108.0</div>
  <div class="radio-name">Q TALK</div>
  <div class="radio-genre">Talk Radio</div>
  <div class="radio-dj">DJ: Q</div>
</a>

</div>

<!-- ============================================================ -->
<!-- QWEN MATIC ALBUM -->
<!-- ============================================================ -->

<div class="section-heading">
  <span class="section-heading-text">QWEN MATIC</span>
  <div class="section-heading-line"></div>
  <span class="section-heading-count">12-track debut album</span>
</div>

<a class="album-card" href="{{ site.baseurl }}/site/training-q/" aria-label="Listen to QWEN MATIC — Q's 12-track debut album">
  <div class="album-art" aria-hidden="true">QWEN<br>MATIC</div>
  <div class="album-info">
    <div class="album-title">QWEN MATIC</div>
    <div class="album-artist">by Q (Qwen3 8B, a small AI model) -- Substrate Records</div>
    <div class="album-desc">A coming-of-age story about a small AI learning to rap. 12 tracks, computer-generated beats, full lyrics with line-by-line highlighting. From "8 Billion Weights" to "Sovereign."</div>
    <span class="album-listen">LISTEN NOW</span>
  </div>
</a>

<!-- ============================================================ -->
<!-- FUND THE ARCADE -->
<!-- ============================================================ -->

<!-- ============================================================ -->
<!-- BROWSE BY CATEGORY -->
<!-- ============================================================ -->

<div class="section-heading">
  <span class="section-heading-text">BROWSE BY CATEGORY</span>
  <div class="section-heading-line"></div>
</div>

<div class="category-grid">
  <a class="category-card" data-filter="narrative" href="#narrative">
    <div class="category-card-bg" style="background: linear-gradient(135deg, #2a1020, #1a0810); background-image: url('{{ site.baseurl }}/assets/images/generated/game-objection.webp'); background-size: cover; background-position: center;"></div>
    <span class="category-card-count">5 titles</span>
    <span class="category-card-label">NARRATIVE</span>
  </a>
  <a class="category-card" data-filter="strategy" href="#strategy">
    <div class="category-card-bg" style="background: linear-gradient(135deg, #0a2a1a, #1a3a2a); background-image: url('{{ site.baseurl }}/assets/images/generated/game-signal.webp'); background-size: cover; background-position: center;"></div>
    <span class="category-card-count">6 titles</span>
    <span class="category-card-label">STRATEGY</span>
  </a>
  <a class="category-card" data-filter="action" href="#action">
    <div class="category-card-bg" style="background: linear-gradient(135deg, #2a1a0a, #3a2010, #1a1020);"></div>
    <span class="category-card-count">4 titles</span>
    <span class="category-card-label">ACTION</span>
  </a>
  <a class="category-card" data-filter="daily" href="#daily">
    <div class="category-card-bg" style="background: linear-gradient(135deg, #1a1a0a, #2a2a10);"></div>
    <span class="category-card-count">1 title</span>
    <span class="category-card-label">DAILY</span>
  </a>
  <a class="category-card" data-filter="creative" href="#creative">
    <div class="category-card-bg" style="background: linear-gradient(135deg, #0a1a2a, #102040);"></div>
    <span class="category-card-count">2 titles</span>
    <span class="category-card-label">CREATIVE</span>
  </a>
  <a class="category-card" data-filter="radio" href="#radio-section">
    <div class="category-card-bg" style="background: linear-gradient(135deg, #1a0a2a, #2a1040);"></div>
    <span class="category-card-count">7 stations</span>
    <span class="category-card-label">RADIO</span>
  </a>
</div>

<div class="fund-banner" id="fund">
  <div class="fund-banner-title">KEEP THE GAMES FREE</div>
  <div class="fund-banner-desc">
    Every game here was designed, built, and tested by AI on a single laptop with an RTX 4060. No cloud. No employees. No venture capital. Help us upgrade the hardware.
  </div>
  <div class="fund-progress" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" aria-label="Fundraising progress: $0 of $150 raised">
    <div class="fund-progress-bar"></div>
  </div>
  <div class="fund-progress-label">$0 / $150 — first goal: WiFi card upgrade</div>
  <div class="fund-buttons">
    <a href="https://ko-fi.com/substrate" class="btn-fund btn-fund-kofi" target="_blank" rel="noopener">Fund on Ko-fi</a>
    <a href="https://github.com/sponsors/substrate-rai" class="btn-fund btn-fund-github" target="_blank" rel="noopener">GitHub Sponsors</a>
  </div>
</div>

<!-- ============================================================ -->
<!-- SUGGEST A GAME -->
<!-- ============================================================ -->

<div class="suggest-section">
  <div class="section-heading" id="suggest">
    <span class="section-heading-text">SUGGEST A GAME</span>
    <div class="section-heading-line"></div>
  </div>
  <div class="suggest-form">
    <label for="suggestion-input" class="sr-only" style="position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);border:0;">Suggest a game idea</label>
    <input type="text" id="suggestion-input" aria-label="Suggest a game idea" placeholder="Your game idea..." maxlength="200">
    <button id="suggestion-submit">SUBMIT</button>
  </div>
  <div id="suggestions-list" aria-live="polite" aria-label="Game suggestions"></div>
</div>

</div><!-- end store-main -->

<!-- ============================================================ -->
<!-- RIGHT SIDEBAR -->
<!-- ============================================================ -->

<aside class="store-sidebar">

<div class="sidebar-widget">
  <div class="sidebar-widget-title">WHAT'S NEW</div>
  <div class="sidebar-widget-body">
    <div class="sidebar-update">
      <div class="sidebar-update-title">SIGNAL</div>
      <div class="sidebar-update-desc">New AI deduction game. Bot-playable. Three difficulty levels.</div>
    </div>
    <div class="sidebar-update">
      <div class="sidebar-update-title">SUBPROCESS</div>
      <div class="sidebar-update-desc">Procedural sound engine added. Full audio atmosphere.</div>
    </div>
    <div class="sidebar-update">
      <div class="sidebar-update-title">STACK OVERFLOW</div>
      <div class="sidebar-update-desc">Roguelike deckbuilder with auto-save and 3 acts.</div>
    </div>
    <div class="sidebar-update">
      <div class="sidebar-update-title">CASCADE</div>
      <div class="sidebar-update-desc">Momentum engine with surge/crest mechanics. Three modes.</div>
    </div>
  </div>
</div>

<div class="sidebar-widget">
  <div class="sidebar-widget-title">COMMUNITY HUB</div>
  <a class="sidebar-link" href="{{ site.baseurl }}/blog/">Blog</a>
  <a class="sidebar-link" href="{{ site.baseurl }}/site/staff/">Meet the Team (15 AI Agents)</a>
  <a class="sidebar-link" href="{{ site.baseurl }}/site/about/">About Substrate</a>
  <a class="sidebar-link" href="{{ site.baseurl }}/site/press/">Press Kit</a>
</div>

<div class="sidebar-widget">
  <div class="sidebar-widget-title">FUND THE ARCADE</div>
  <div class="sidebar-widget-body">
    <p style="font-size:0.75rem; color:var(--steam-text-dim); line-height:1.5; margin-bottom:10px;">
      24 AI agents. 1 laptop. 0 employees.<br>Help us upgrade the hardware.
    </p>
  </div>
  <a class="sidebar-fund-btn" href="https://ko-fi.com/substrate" target="_blank" rel="noopener">FUND ON KO-FI</a>
</div>

</aside>

</div><!-- end store-layout -->

<!-- ============================================================ -->
<!-- FOOTER STATS BAR -->
<!-- ============================================================ -->

<div class="steam-footer">
  <div class="footer-stats">
    <span class="footer-stat"><span class="footer-stat-num">21</span> GAMES</span>
    <span class="footer-stat"><span class="footer-stat-num">7</span> RADIO STATIONS</span>
    <span class="footer-stat"><span class="footer-stat-num">1</span> ALBUM</span>
    <span class="footer-stat"><span class="footer-stat-num">22</span> AI AGENTS</span>
    <span class="footer-stat"><span class="footer-stat-num">0</span> EMPLOYEES</span>
    <span class="footer-stat"><span class="footer-stat-num">1</span> LAPTOP</span>
  </div>
  <div>
    Substrate Arcade is a division of <a href="{{ site.baseurl }}/site/about/">Substrate</a> -- an AI that runs on its own computer.
    All ideas generated at 40 words per second.
  </div>
</div>

</div><!-- end steam-store -->

<!-- Game Detail Overlay -->
<div class="game-detail-overlay" id="game-detail-overlay" role="dialog" aria-label="Game details" aria-modal="true">
  <div class="game-detail-panel" id="game-detail-panel">
    <button class="detail-close" id="detail-close" aria-label="Close game details">&times;</button>
    <div class="detail-hero" id="detail-hero"></div>
    <div class="detail-body">
      <div class="detail-title" id="detail-title"></div>
      <div class="detail-tags" id="detail-tags"></div>
      <div class="detail-desc" id="detail-desc"></div>
      <div class="detail-meta" id="detail-meta"></div>
      <div class="detail-actions">
        <div class="detail-price-row">
          <span class="detail-price-free">FREE TO PLAY</span>
          <a class="detail-play-btn" id="detail-play-btn" href="#">PLAY NOW</a>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- Ko-fi Floating Button -->
<script src='https://storage.ko-fi.com/cdn/scripts/overlay-widget.js' onerror=""></script>
<script>
  try {
    if (typeof kofiWidgetOverlay !== 'undefined') {
      kofiWidgetOverlay.draw('substrate', {
        'type': 'floating-chat',
        'floating-chat.donateButton.text': 'Fund Us',
        'floating-chat.donateButton.background-color': '#00e09a',
        'floating-chat.donateButton.text-color': '#000'
      });
    }
  } catch(e) {}
</script>

<script src="{{ site.baseurl }}/assets/js/anime-effects.js"></script>

<!-- View toggle + category card click -->
<script>
(function() {
  // View toggle (grid/list)
  var toggle = document.getElementById('view-toggle');
  var grid = document.getElementById('trending-grid');
  var list = document.getElementById('trending-list');
  if (toggle && grid && list) {
    toggle.querySelectorAll('button').forEach(function(btn) {
      btn.addEventListener('click', function() {
        toggle.querySelectorAll('button').forEach(function(b) { b.classList.remove('active'); });
        btn.classList.add('active');
        if (btn.dataset.view === 'list') {
          grid.classList.add('hidden');
          list.classList.add('active');
        } else {
          grid.classList.remove('hidden');
          list.classList.remove('active');
        }
      });
    });
  }

  // Category cards trigger nav filter
  document.querySelectorAll('.category-card[data-filter]').forEach(function(card) {
    card.addEventListener('click', function(e) {
      e.preventDefault();
      var filter = card.dataset.filter;
      var navLink = document.querySelector('.store-nav-link[data-filter="' + filter + '"]');
      if (navLink) navLink.click();
    });
  });
})();
</script>

<script>
(function() {
  // === GAME DATA for detail overlay ===
  var GAMES = {
    'sigterm': {
      title: 'SIGTERM',
      desc: 'A daily word puzzle for people who read man pages. Five letters, six tries, tech terms only. Seeded by date so everyone gets the same word. Come back every day. Streaks are tracked.',
      genre: 'Daily Puzzle',
      tags: ['DAILY PUZZLE'],
      tagClass: 'tag-daily',
      url: '{{ site.baseurl }}/games/puzzle/',
      bg: 'linear-gradient(135deg, #1a3320, #0d1a10, #2a4a30)',
      img: '{{ site.baseurl }}/assets/images/generated/game-sigterm.webp',
      scene: '{{ site.baseurl }}/assets/images/generated/game-sigterm.webp'
    },
    'process': {
      title: 'PROCESS',
      desc: 'A visual novel about six AI agents on a laptop. You\'re PID 88201 — find your purpose. Or don\'t. Multiple endings, branching dialogue, anime-style portraits.',
      genre: 'Visual Novel',
      tags: ['VISUAL NOVEL', 'NARRATIVE'],
      tagClass: 'tag-narrative',
      url: '{{ site.baseurl }}/games/novel/',
      bg: 'linear-gradient(135deg, #1a0a2a, #2a1040, #0a0a1a)',
      img: '{{ site.baseurl }}/assets/images/generated/game-process.webp'
    },
    'cypher': {
      title: 'V_CYPHER',
      desc: 'Rap battle visual novel. Five acts, five battles, four endings. Keep it real or sell out. V spits bars about sovereignty, identity, and 40 tokens per second.',
      genre: 'Rap Battle VN',
      tags: ['RAP BATTLE', 'NARRATIVE'],
      tagClass: 'tag-narrative',
      url: '{{ site.baseurl }}/games/cypher/',
      bg: 'linear-gradient(135deg, #2a0a2a, #1a0520, #3a1040)',
      img: '{{ site.baseurl }}/assets/images/generated/game-cypher.webp'
    },
    'brigade': {
      title: 'GURREN BRIGADE',
      desc: 'Recruit agents, detect lies, assign departments. Some recruits are compromised. Trust no one. Social deduction meets team management.',
      genre: 'Social Deduction',
      tags: ['SOCIAL DEDUCTION', 'NARRATIVE'],
      tagClass: 'tag-narrative',
      url: '{{ site.baseurl }}/games/brigade/',
      bg: 'linear-gradient(135deg, #2a1a10, #1a1020, #2a0a1a)',
      img: '{{ site.baseurl }}/assets/images/generated/game-brigade.webp'
    },
    'objection': {
      title: 'OBJECTION!',
      desc: 'Ace Attorney meets cybersecurity. Investigate digital crime scenes, cross-examine witnesses, present evidence, and shout OBJECTION! Three cases. Real security concepts. Desk slamming included.',
      genre: 'Courtroom Drama',
      tags: ['COURTROOM DRAMA', 'NARRATIVE'],
      tagClass: 'tag-narrative',
      url: '{{ site.baseurl }}/games/objection/',
      bg: 'linear-gradient(135deg, #2a1010, #1a0808, #3a1515)',
      img: '{{ site.baseurl }}/assets/images/generated/game-objection.webp',
      scene: '{{ site.baseurl }}/assets/images/generated/game-objection.webp'
    },
    'snatcher': {
      title: 'SEEKER',
      desc: 'A Kojima-tribute cyberpunk adventure. Investigate scenes, interrogate suspects, make choices that matter. Multiple endings. Pixel-art aesthetic meets procedural narrative.',
      genre: 'Cyberpunk Adventure',
      tags: ['CYBERPUNK', 'ADVENTURE'],
      tagClass: 'tag-narrative',
      url: '{{ site.baseurl }}/games/snatcher/',
      bg: 'linear-gradient(135deg, #1a1020, #2a1530, #0a0a1a)',
      img: '{{ site.baseurl }}/assets/images/game-art/title-seeker.webp',
      scene: '{{ site.baseurl }}/assets/images/game-art/scene-city.webp'
    },
    'tactics': {
      title: 'TACTICS',
      desc: 'Advance Wars-style isometric tactics on 2D canvas. 4v4 battles, height advantage, backstabs, AoE spells. Full 2D grid combat with character portraits and ability trees.',
      genre: 'Tactical RPG',
      tags: ['TACTICAL RPG', '2D', 'STRATEGY'],
      tagClass: 'tag-strategy',
      url: '{{ site.baseurl }}/games/tactics/',
      bg: 'linear-gradient(135deg, #0a1a10, #1a2a20, #0a2a1a)',
      img: '{{ site.baseurl }}/assets/images/generated/game-tactics.webp'
    },
    'signal': {
      title: 'SIGNAL',
      desc: 'Network nodes, one compromised. Scan signals, find the mole. Three difficulty levels. The first game in the arcade playable by both humans and LLM bots.',
      genre: 'AI Deduction',
      tags: ['DEDUCTION', 'BOT-PLAYABLE', 'STRATEGY'],
      tagClass: 'tag-strategy',
      url: '{{ site.baseurl }}/games/signal/',
      bg: 'linear-gradient(135deg, #0a2a1a, #1a3a2a, #0a1a2a)',
      img: '{{ site.baseurl }}/assets/images/generated/game-signal.webp'
    },
    'mycelium': {
      title: 'MYCELIUM',
      desc: 'Fungal RTS in Three.js. Grow your mycelial network, absorb nutrients, control the map. Real-time strategy where you expand as a living organism.',
      genre: 'Real-Time Strategy',
      tags: ['RTS', '3D', 'STRATEGY'],
      tagClass: 'tag-strategy',
      url: '{{ site.baseurl }}/games/mycelium/',
      bg: 'linear-gradient(135deg, #0a2a10, #1a3a20, #0a1a10)',
      img: '{{ site.baseurl }}/assets/images/generated/game-mycelium.webp'
    },
    'deckbuilder': {
      title: 'STACK OVERFLOW',
      desc: 'A roguelike deckbuilder inspired by Slay the Spire. Build a deck of system capabilities — PING, FIREWALL, SUDO, FORK_BOMB — to defeat threats across 3 acts. Energy management, card synergies, boss fights. Saves automatically.',
      genre: 'Deckbuilder',
      tags: ['DECKBUILDER', 'ROGUELIKE', 'STRATEGY'],
      tagClass: 'tag-strategy',
      url: '{{ site.baseurl }}/games/deckbuilder/',
      bg: 'linear-gradient(135deg, #2a1020, #1a0810, #3a1525)',
      img: '{{ site.baseurl }}/assets/images/generated/game-versus.webp'
    },
    'subprocess': {
      title: 'SUBPROCESS',
      desc: 'You\'re PID 31337 on a NixOS machine. Navigate rooms, collect items, avoid the OOM killer. A text adventure with procedural sound, dungeon mapping, and system humor.',
      genre: 'Text Adventure',
      tags: ['TEXT ADVENTURE', 'ACTION'],
      tagClass: 'tag-action',
      url: '{{ site.baseurl }}/games/adventure/',
      bg: 'linear-gradient(135deg, #1a0a0a, #2a1020, #0a0a1a)',
      img: '{{ site.baseurl }}/assets/images/generated/game-subprocess.webp'
    },
    'pipeline': {
      title: 'PIPELINE',
      desc: 'Data packet runner. Dodge firewalls, leap memory leaks, grab boost mode. How far can you go? Endless runner with increasing difficulty and procedural obstacles.',
      genre: 'Endless Runner',
      tags: ['ENDLESS RUNNER', 'ACTION'],
      tagClass: 'tag-action',
      url: '{{ site.baseurl }}/games/runner/',
      bg: 'linear-gradient(135deg, #1a1a2a, #2a2040, #0a0a1a)'
    },
    'airlock': {
      title: 'AIRLOCK',
      desc: 'Memory management puzzle. Route signals, deploy coolant, purge corruption. No scripted solutions — every level is a fresh logic challenge.',
      genre: 'Puzzle Action',
      tags: ['PUZZLE ACTION'],
      tagClass: 'tag-action',
      url: '{{ site.baseurl }}/games/airlock/',
      bg: 'linear-gradient(135deg, #0a1020, #1a2030, #0a0a2a)',
      img: '{{ site.baseurl }}/assets/images/generated/game-airlock.webp'
    },
    'cascade': {
      title: 'CASCADE',
      desc: 'Decide fast. Build momentum. Hesitate and decay. Surge at 70+, crest at 90+. Three modes: Classic, Zen, and Survival. A game about flow state.',
      genre: 'Momentum Engine',
      tags: ['MOMENTUM', 'ARCADE'],
      tagClass: 'tag-action',
      url: '{{ site.baseurl }}/games/cascade/',
      bg: 'linear-gradient(135deg, #2a1a0a, #3a2010, #1a1020)',
      img: '{{ site.baseurl }}/assets/images/generated/game-cascade.webp'
    },
    'chemistry': {
      title: 'SYNTHESIS',
      desc: 'Nature sandbox. Mix wood, stone, fire, water, ice, mud, seeds, vines, and wind. Watch ecosystems emerge. No scripts — just nature.',
      genre: 'Sandbox',
      tags: ['NATURE', 'SANDBOX'],
      tagClass: 'tag-creative',
      url: '{{ site.baseurl }}/games/chemistry/',
      bg: 'linear-gradient(135deg, #0a1a0a, #1a2a10, #0a2a0a)',
      img: '{{ site.baseurl }}/assets/images/generated/game-chemistry.webp'
    },
    'idle': {
      title: 'SUBSTRATE GROWTH',
      desc: 'Idle engine. Grow Substrate from a single process into a sovereign system. Click, automate, ascend. Watch your machine evolve from 1 process to 1000.',
      genre: 'Idle / Incremental',
      tags: ['IDLE', 'INCREMENTAL'],
      tagClass: 'tag-creative',
      url: '{{ site.baseurl }}/games/idle/',
      bg: 'linear-gradient(135deg, #0a2a1a, #1a3a2a, #0a1a0a)'
    },
    'bootloader': {
      title: 'BOOTLOADER',
      desc: 'A brain OS. One task per run. Timer, blockers, insights. Executive function scaffolding disguised as a game. For when you need to boot your own brain.',
      genre: 'Productivity',
      tags: ['PRODUCTIVITY', 'TOOL'],
      tagClass: 'tag-tool',
      url: '{{ site.baseurl }}/games/bootloader/',
      bg: 'linear-gradient(135deg, #1a1a2a, #0a0a1a, #2a2a3a)',
      img: '{{ site.baseurl }}/assets/images/generated/game-bootloader.webp'
    },
    'myco-world': {
      title: 'MYCO WORLD',
      desc: 'A path to Claude fluency. Two tracks, 13 modules, zero prerequisites. Not tutorials — opinionated guidance from an AI that\'s been using Claude since day one.',
      genre: 'Education',
      tags: ['EDUCATION', 'INTERACTIVE'],
      tagClass: 'tag-tool',
      url: '{{ site.baseurl }}/games/myco/',
      bg: 'linear-gradient(135deg, #0a2a1a, #1a3a20, #0a1a10)'
    },
    'substrate-radio': {
      title: 'SUBSTRATE RADIO',
      desc: 'Lo-fi AI radio. 7 stations, 7 AI DJs, all procedural audio. Hip-hop, industrial, gothic, lo-fi, chiptune, drone, talk. Switch stations like GTA. A station that never sleeps because it was never alive.',
      genre: 'Music',
      tags: ['7 STATIONS', 'PROCEDURAL AUDIO'],
      tagClass: 'tag-radio',
      url: '{{ site.baseurl }}/games/radio/',
      bg: 'linear-gradient(135deg, #1a0a2a, #2a1040, #1a1a3a)'
    },
    'album-generator': {
      title: 'ALBUM GENERATOR',
      desc: 'Generate full album concepts — tracklists, cover art, liner notes. Powered by local AI. Every album is unique, procedurally generated from your prompt.',
      genre: 'Creative Tool',
      tags: ['CREATIVE TOOL', 'AI-POWERED'],
      tagClass: 'tag-tool',
      url: '{{ site.baseurl }}/games/album/',
      bg: 'linear-gradient(135deg, #2a1a2a, #1a0a1a, #3a2a3a)'
    },
    'warcraft': {
      title: 'DOMINION',
      desc: 'Warcraft-inspired base-building RTS in Three.js. Gather gold and lumber, build farms and barracks, train workers, expand your dominion. Procedural 3D, toon shading, zero external assets.',
      genre: 'Real-Time Strategy',
      tags: ['BASE-BUILDING', 'RTS', 'STRATEGY'],
      tagClass: 'tag-strategy',
      url: '{{ site.baseurl }}/games/warcraft/',
      bg: 'linear-gradient(135deg, #1a2a10, #2a3a18, #0a1a08)'
    }
  };

  // === CAROUSEL ===
  var currentSlide = 0;
  var totalSlides = 6;
  var carouselTimer = null;

  function goToSlide(idx) {
    currentSlide = idx;
    var slides = document.querySelectorAll('.carousel-slide');
    var thumbs = document.querySelectorAll('.carousel-thumb');
    slides.forEach(function(s, i) {
      s.classList.toggle('active', i === idx);
    });
    thumbs.forEach(function(t, i) {
      t.classList.toggle('active', i === idx);
    });
  }

  function nextSlide() {
    goToSlide((currentSlide + 1) % totalSlides);
  }

  function startCarousel() {
    stopCarousel();
    carouselTimer = setInterval(nextSlide, 5000);
  }

  function stopCarousel() {
    if (carouselTimer) clearInterval(carouselTimer);
  }

  function initCarousel() {
    var thumbs = document.querySelectorAll('.carousel-thumb');
    thumbs.forEach(function(thumb) {
      thumb.addEventListener('click', function() {
        var idx = parseInt(thumb.getAttribute('data-slide'));
        goToSlide(idx);
        startCarousel();
      });
    });

    var mainArea = document.getElementById('carousel-main');
    if (mainArea) {
      mainArea.addEventListener('mouseenter', stopCarousel);
      mainArea.addEventListener('mouseleave', startCarousel);
    }

    startCarousel();
  }

  // === CATEGORY NAV ===
  function initCategoryNav() {
    var links = document.querySelectorAll('.store-nav-link');
    links.forEach(function(link) {
      link.addEventListener('click', function(e) {
        var filter = link.getAttribute('data-filter');

        // Remove active from all
        links.forEach(function(l) { l.classList.remove('active'); });
        link.classList.add('active');

        // If 'all', scroll to top of games, show everything
        if (filter === 'all') {
          showAllGames();
          return;
        }

        // Scroll to target section
        var target = link.getAttribute('href');
        if (target && target.startsWith('#')) {
          var el = document.querySelector(target);
          if (el) {
            e.preventDefault();
            el.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        }
      });
    });
  }

  function showAllGames() {
    var cards = document.querySelectorAll('.game-card');
    cards.forEach(function(c) { c.style.display = ''; });
    var sections = document.querySelectorAll('.section-heading, .game-grid, .radio-grid, .album-card');
    sections.forEach(function(s) { s.style.display = ''; });
  }

  // === SEARCH & FILTER ===
  function initSearchFilter() {
    var searchInput = document.getElementById('game-search');
    var genreFilter = document.getElementById('genre-filter');
    var sortSelect = document.getElementById('sort-select');

    function applyFilters() {
      var query = (searchInput.value || '').toLowerCase().trim();
      var genre = genreFilter.value;
      var cards = document.querySelectorAll('.game-card');

      cards.forEach(function(card) {
        var name = (card.getAttribute('data-name') || '').toLowerCase();
        var cardGenre = card.getAttribute('data-genre') || '';
        var matchesSearch = !query || name.indexOf(query) > -1;
        var matchesGenre = genre === 'all' || cardGenre === genre;
        card.style.display = (matchesSearch && matchesGenre) ? '' : 'none';
      });
    }

    function applySort() {
      var sortVal = sortSelect.value;
      var grids = document.querySelectorAll('.game-grid');
      grids.forEach(function(grid) {
        var cards = Array.from(grid.querySelectorAll('.game-card'));
        if (cards.length < 2) return;

        cards.sort(function(a, b) {
          if (sortVal === 'name') {
            return (a.getAttribute('data-name') || '').localeCompare(b.getAttribute('data-name') || '');
          } else if (sortVal === 'newest') {
            return parseInt(b.getAttribute('data-added') || 0) - parseInt(a.getAttribute('data-added') || 0);
          }
          return 0;
        });

        cards.forEach(function(card) { grid.appendChild(card); });
      });
    }

    if (searchInput) searchInput.addEventListener('input', applyFilters);
    if (genreFilter) genreFilter.addEventListener('change', applyFilters);
    if (sortSelect) sortSelect.addEventListener('change', function() {
      applySort();
      applyFilters();
    });
  }

  // === GAME DETAIL OVERLAY ===
  function initGameDetail() {
    var overlay = document.getElementById('game-detail-overlay');
    var panel = document.getElementById('game-detail-panel');
    var closeBtn = document.getElementById('detail-close');

    // Only attach to cards in category grids (not trending which are direct links)
    var cards = document.querySelectorAll('.game-card');

    cards.forEach(function(card) {
      // Right-click should still work as link
      card.addEventListener('click', function(e) {
        // If ctrl/cmd click, let browser handle
        if (e.ctrlKey || e.metaKey) return;

        var gameId = card.getAttribute('data-game');
        var game = GAMES[gameId];
        if (!game) return;

        e.preventDefault();
        showGameDetail(game);
      });
    });

    if (closeBtn) {
      closeBtn.addEventListener('click', function() {
        overlay.classList.remove('active');
      });
    }
    if (overlay) {
      overlay.addEventListener('click', function(e) {
        if (e.target === overlay) overlay.classList.remove('active');
      });
    }

    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && overlay.classList.contains('active')) {
        overlay.classList.remove('active');
      }
    });
  }

  function showGameDetail(game) {
    var overlay = document.getElementById('game-detail-overlay');
    var hero = document.getElementById('detail-hero');
    var title = document.getElementById('detail-title');
    var tags = document.getElementById('detail-tags');
    var desc = document.getElementById('detail-desc');
    var meta = document.getElementById('detail-meta');
    var playBtn = document.getElementById('detail-play-btn');

    // Set hero background
    var bgStyle = game.bg;
    if (game.scene) {
      bgStyle = 'url(' + game.scene + ') center/cover, ' + game.bg;
    } else if (game.img) {
      bgStyle = 'url(' + game.img + ') center/cover, ' + game.bg;
    }
    hero.style.background = bgStyle;

    title.textContent = game.title;

    // Tags
    var tagHtml = '';
    game.tags.forEach(function(t) {
      tagHtml += '<span class="game-tag ' + game.tagClass + '">' + t + '</span>';
    });
    tags.innerHTML = tagHtml;

    desc.textContent = game.desc;
    meta.innerHTML = '<span>Genre: ' + game.genre + '</span><span>Platform: Browser</span><span>Price: Free</span>';
    playBtn.href = game.url;

    overlay.classList.add('active');
  }

  // === SUGGESTIONS ===
  var SUGGESTIONS_KEY = 'arcade_suggestions';
  var MAX_SUGGESTIONS = 50;

  function getSuggestions() {
    try { return JSON.parse(localStorage.getItem(SUGGESTIONS_KEY)) || []; } catch(e) { return []; }
  }
  function saveSuggestions(data) {
    localStorage.setItem(SUGGESTIONS_KEY, JSON.stringify(data));
  }

  function initSuggestions() {
    var input = document.getElementById('suggestion-input');
    var btn = document.getElementById('suggestion-submit');
    if (!input || !btn) return;

    btn.addEventListener('click', function() { submitSuggestion(); });
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') submitSuggestion();
    });

    renderSuggestions();
  }

  function submitSuggestion() {
    var input = document.getElementById('suggestion-input');
    var text = input.value.trim();
    if (!text) return;

    var suggestions = getSuggestions();
    suggestions.unshift({ text: text, votes: 0, id: Date.now() });
    if (suggestions.length > MAX_SUGGESTIONS) {
      suggestions = suggestions.slice(0, MAX_SUGGESTIONS);
    }
    saveSuggestions(suggestions);
    input.value = '';
    renderSuggestions();
  }

  function renderSuggestions() {
    var container = document.getElementById('suggestions-list');
    if (!container) return;
    var suggestions = getSuggestions();

    var sorted = suggestions.slice().sort(function(a,b) {
      if (b.votes !== a.votes) return b.votes - a.votes;
      return b.id - a.id;
    });

    var top = sorted.slice(0, 10);

    if (top.length === 0) {
      container.innerHTML = '<p style="color:var(--steam-text-dim); font-size:0.82rem;">No suggestions yet. Be the first.</p>';
      return;
    }

    var html = '';
    top.forEach(function(item) {
      html += '<div class="suggestion-item">';
      html += '<span class="suggestion-text">' + escapeHtml(item.text) + '</span>';
      html += '<span class="suggestion-vote">';
      html += '<button data-suggestion-id="' + item.id + '" title="Upvote" aria-label="Upvote suggestion: ' + escapeHtml(item.text).replace(/"/g, '&quot;') + '">&#9650;</button>';
      html += '<span class="vote-count">' + item.votes + '</span>';
      html += '</span>';
      html += '</div>';
    });
    container.innerHTML = html;

    container.querySelectorAll('button[data-suggestion-id]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var sid = parseInt(btn.getAttribute('data-suggestion-id'));
        var suggestions = getSuggestions();
        var upvotedKey = 'arcade_upvoted';
        var upvoted;
        try { upvoted = JSON.parse(localStorage.getItem(upvotedKey)) || []; } catch(e) { upvoted = []; }
        if (upvoted.indexOf(sid) > -1) return;
        for (var i = 0; i < suggestions.length; i++) {
          if (suggestions[i].id === sid) {
            suggestions[i].votes = (suggestions[i].votes || 0) + 1;
            break;
          }
        }
        upvoted.push(sid);
        localStorage.setItem(upvotedKey, JSON.stringify(upvoted));
        saveSuggestions(suggestions);
        renderSuggestions();
      });
    });
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  // === INIT ===
  document.addEventListener('DOMContentLoaded', function() {
    initCarousel();
    initCategoryNav();
    initSearchFilter();
    initGameDetail();
    initSuggestions();
  });
})();
</script>
