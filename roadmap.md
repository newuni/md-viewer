# Roadmap

## Plan de ejecución en cadena (nuevo)

- [x] Añadir personalización de **tema visual** (System/GitHub/Solarized/Dracula).
- [x] Añadir control de **apariencia** (System/Light/Dark).
- [x] Añadir controles de **tipografía** (tamaño cuerpo + tamaño código).
- [x] Mejorar rendimiento con **tiers automáticos por tamaño de archivo** (small/medium/large/huge).
- [x] Conservar control manual de Fast Mode y añadir opción de volver a **Auto**.
- [x] Añadir acción **Open With** desde toolbar.

## Near term

### New minimalist viewer pass

- [x] Add command palette (`Cmd+K`) with core viewer actions.
- [x] Add ultra-clean Reading Mode (`Ctrl+Cmd+R`).
- [x] Add copy-link action for headings in the outline.
- [x] Sync outline highlight with current reading section while scrolling.
- [x] Add quick paste-preview flow from clipboard (`Cmd+Shift+V`).
- [x] Add typography zoom shortcuts (`Cmd+=`, `Cmd+-`, `Cmd+0`).


- [x] Improve syntax highlighting for fenced code blocks.
- [x] Add file change watching for live preview refresh.
- [x] Add richer Quick Look metadata/search support.
- [x] Add find-in-document (`Cmd+F`) with next/previous navigation.
- [x] Add collapsible outline sidebar for heading navigation.
- [x] Add manual fast mode for large files (5MB+).

## Completed after native engine migration

- [x] Migración del motor a ruta de renderizado **nativa** (atribuida) como camino principal en app y Quick Look.
- [x] Mantener fallback HTML/WebView solo para compatibilidad y resiliencia.
- [x] Mantener paridad funcional (tema, apariencia, tipografía, búsqueda, TOC, fast mode tiers, Open With).
- [x] Endurecer pipeline CI/release tras migración hasta volver a verde.

## Later

- [ ] Signed and notarized release pipeline.
- [ ] Optional custom themes.
- [ ] Performance profiling for very large Markdown files (beyond fast mode).
