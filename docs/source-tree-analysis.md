# Source Tree Analysis

## Annotated Directory Tree

```
./
├── assets/                 # Frontend assets (JS/CSS) bundled by esbuild/tailwind
│   ├── css/
│   ├── js/
│   └── vendor/
├── config/                 # Environment config (dev/test/prod/runtime)
├── lib/                    # Application source
│   ├── tauros/             # Business logic / contexts
│   ├── tauros_web/         # Web layer (router/controllers/live/components)
│   │   ├── components/     # Layouts + core UI components
│   │   ├── controllers/    # HTTP controllers
│   │   ├── live/           # LiveView UI modules
│   │   └── router.ex       # Route definitions
│   ├── tauros.ex           # Application entry point for domain
│   └── tauros_web.ex       # Web macros/imports
├── priv/                   # Private runtime assets
│   ├── repo/               # Ecto migrations and seeds
│   ├── static/             # Compiled/static assets served by the endpoint
│   └── gettext/            # Localization files
├── test/                   # ExUnit tests
├── mix.exs                 # Project definition + dependencies
└── mix.lock                # Locked dependencies
```

## Entry Points
- Web endpoint: `lib/tauros_web/endpoint.ex`
- Router: `lib/tauros_web/router.ex`
- OTP application: `lib/tauros/application.ex`

## Critical Folders Summary
- `lib/tauros_web/`: Controllers, LiveViews, components, and routing.
- `lib/tauros/`: Domain logic and contexts.
- `priv/repo/`: Database migrations and seed data.
- `assets/`: JS/CSS build inputs for the frontend.
- `config/`: Environment config and runtime settings.
