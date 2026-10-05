# Society360 Multilingual Development Rules

**Mandatory production rule for all future development.**

## 1. Centralized localization only
- Every user-facing string must use the existing centralized Society360I18n resources.
- Do not hardcode translated strings inside pages, components, inline handlers, modules, CSS-generated content, or API response display logic.
- Use stable translation keys; backend/database values must remain stable internal codes or IDs.

## 2. Six supported languages
The active application language set is exactly:
- English (en)
- Hindi (hi)
- Marathi (mr)
- Gujarati (gu)
- Kannada (kn)
- Tamil (ta)

Every new key must exist with a non-empty translation in all six resources.

## 3. Dynamic content
Statuses, workflows, roles, permissions, categories, types, notifications, validation messages, API messages, table values, empty/loading states, and other database/API-driven display values must be localized from stable codes/keys.

## 4. Language switching
- `localStorage['society360-language']` and `Society360I18n.currentLanguage()` are the single active language state.
- `Society360I18n.setLanguage()` is the only language mutation path; the shared i18n runtime owns the language-selector change handler for every page, including dynamically loaded authenticated modules.
- Pages must not create their own language store, provider, selector handler, or reload workaround.
- Every authenticated and unauthenticated page must respond immediately to the centralized language-change event. Do not require a page reload to apply a language change. Components that render dynamic content must re-render when the language changes.
- DOM text rendered dynamically must retain a canonical translation source/key so switching between non-English languages cannot treat the previous translation as the new source text.

Required verification for every page:
English -> each supported language -> English, without reload, followed by one reload/persistence check.

## 5. Unicode and encoding
- Source files must remain UTF-8.
- Never replace unsupported Unicode with ?, ???? or replacement characters.
- Preserve UTF-8 through database, backend, JSON, HTTP, JavaScript, HTML, and rendering layers.

## 6. API contract
User-facing API responses should expose stable error/success codes where practical. Frontends translate those codes through Society360I18n; raw technical/database errors must never be shown to users.

## 7. Static/regression checks
Before a multilingual feature is considered complete:
- verify all six language dictionaries contain every new key;
- check for empty/missing translations and Unicode corruption;
- check JavaScript syntax;
- run git diff --check;
- test language switching without reload;
- test dynamic validation/error/success/empty/loading states.

## 8. No duplicate localization systems
Do not introduce a second translation provider, page-specific translation dictionary, language store, or reload-based workaround. Extend the existing localization architecture instead.

## 9. Definition of done
A feature is incomplete until its user-facing strings are localized in all six languages, language switching works in both directions, dynamic content re-renders correctly, and automated/static checks for its translation keys pass.
