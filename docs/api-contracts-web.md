# API Contracts - Web

## Overview
Quick-scan summary of API surface. This scan is pattern-based and does not read source files; routes and payloads require a deeper scan for full accuracy.

## Entry Points and Routing
- Router file present: `lib/tauros_web/router.ex`
- Controllers present under `lib/tauros_web/controllers/`
- LiveViews present under `lib/tauros_web/live/`

## Observed HTTP Areas (by file presence)
- Page controller: `lib/tauros_web/controllers/page_controller.ex`
- User session controller: `lib/tauros_web/controllers/user_session_controller.ex`
- Error controllers: `lib/tauros_web/controllers/error_html.ex`, `lib/tauros_web/controllers/error_json.ex`

## Notes
- This project is Phoenix LiveView-driven; many interactions are LiveView events rather than REST endpoints.
- For concrete routes, methods, and payload schemas, run a deep or exhaustive scan to parse `router.ex` and controller actions.
