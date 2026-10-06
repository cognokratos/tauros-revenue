# Third-party notices and licence exceptions

The root [`LICENSE`](LICENSE) (MIT, Copyright (c) 2026 Victor Nitu) covers the
original code and documentation in this repository. The material below keeps
its own terms.

| Material | Origin | Licence | Notice |
| --- | --- | --- | --- |
| `assets/vendor/topbar.js` | [topbar](https://buunguyen.github.io/topbar) 3.0.0, vendored by the Phoenix generator | MIT | `Copyright (c) 2024 Buu Nguyen`, kept in the file header |
| `assets/vendor/heroicons.js` | Tailwind plugin emitted by `mix phx.new` (Phoenix) | MIT (Phoenix) | — |
| Icons loaded by that plugin | [Heroicons](https://github.com/tailwindlabs/heroicons), fetched as a Mix dependency, not stored here | MIT (Tailwind Labs) | in the dependency |
| Brand images: `priv/static/images/logo.png`, `priv/static/images/bg.png`, `priv/static/favicon/*`, `docs/bg.png` | Tauros / CognoKratos branding | **not covered by the MIT grant** | — |

Other files that `mix phx.new` and the Ash generators produced are part of this
project and covered by the root licence. Dependencies in `mix.lock` and the
asset toolchain are used under their own licences.
