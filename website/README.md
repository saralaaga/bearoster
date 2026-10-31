# Bearoster website

Static, dependency-free site for `https://bearoster.com`.
Public source repository: https://github.com/saralaaga/bearoster
Site nav/footer and the download section link there (zh: 源码 / en: Source).


- Chinese home: `/`
- English home: `/en/`
- App Store legal URLs: `/privacy` and `/support`

Design: the blue Apple-style theme from the Kimi demo
(`kimi/website-demo/`, git-ignored), productionized in 2026-09. Differences
from the demo, required by the site's constraints:

- No JavaScript. The CSP in `_headers` is `default-src 'none'`, so the demo's
  `i18n.js` language toggle and `main.js` FAQ animation were dropped: each
  language is a standalone page pair, and FAQ items use native `<details>`.
- The privacy-list checkmark is drawn with CSS borders instead of a `data:`
  mask URL, because `img-src 'self'` blocks data: URLs.
- The hero shows a real app screenshot (`assets/app-contacts.png`, downscaled
  from `AppStore/screenshots/03-contacts.png`, fictional contacts) instead of
  the demo's CSS mockup; the caption pill under it uses the app's actual
  sync-history queue states (待写入 / 冲突 / 失败).
- Nav/footer link to the standalone `/privacy` and `/support` legal routes
  (App Store review fetches them server-side).
- Copy stays within the approved claims: no "no network" wording (1.0 ships a
  loopback agent listener), download CTAs point to support until the Mac App
  Store listing is live, footer carries the legal entity.

## Cloudflare Pages deploy

Deployment is an external production change. Use the protected GitHub Actions gate; an ordinary agent must not use a Cloudflare browser session or API token directly.

1. Run `scripts/website/configure-deploy-gate.sh` yourself. It creates the
   `website-production` environment, makes your GitHub account the required
   reviewer, and limits it to `main`.
2. Run `scripts/website/bootstrap-production-secrets.sh` yourself. It copies
   only `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from Infisical
   `Bearoster/prod` into GitHub environment secrets. The Cloudflare token must
   be account-scoped to Cloudflare Pages: Edit.
3. Merge the site branch into `main`.
4. Dispatch **Website production deploy** from `main`; it is intentionally
   manual, so pushing to `main` cannot deploy by itself.
5. Approve the `website-production` deployment in GitHub.
6. The final workflow step verifies `/privacy`, `/support`, `/en/privacy`, and
   `/en/support`.

The deploy target is fixed to the Cloudflare Pages project `bearoster` and the
production branch `main`; the workflow does not accept either as an input.

## Local check

```bash
python3 -m http.server 4173 --directory website
```
