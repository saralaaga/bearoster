# Bearoster website

Static, dependency-free site for `https://bearoster.com`.

- Chinese home: `/`
- English home: `/en/`
- App Store legal URLs: `/privacy` and `/support`

## Cloudflare Pages deploy

Deployment is an external production change. Use the protected GitHub Actions gate; an ordinary agent must not use a Cloudflare browser session or API token directly.

1. Run `scripts/website/configure-deploy-gate.sh` yourself. It creates the
   `website-production` environment, makes your GitHub account the required
   reviewer, and limits it to `main`.
2. Run `scripts/website/bootstrap-production-secrets.sh` yourself. It copies
   only `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from Infisical
   `Bearoster/prod` into GitHub environment secrets. The Cloudflare token must
   be account-scoped to Cloudflare Pages: Edit.
3. Merge the site branch into `main`; pushes that change `website/` or the
   deploy workflow start **Website production deploy** automatically.
4. Approve the `website-production` deployment in GitHub.
5. The final workflow step verifies `/privacy`, `/support`, `/en/privacy`, and
   `/en/support`.

The deploy target is fixed to the Cloudflare Pages project `bearoster` and the
production branch `main`; the workflow does not accept either as an input.

## Local check

```bash
python3 -m http.server 4173 --directory website
```
