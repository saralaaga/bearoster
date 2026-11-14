# Website deployment

`bearoster.com` is a production resource. The GitHub-environment approval gate
(`website.yml` + `configure-deploy-gate.sh`) was shelved in 2026-09 because the
free GitHub plan returned 422 for required-reviewers protection rules. The gate
was **re-enabled in 2026-11**: the `website-production` environment now has a
required reviewer and the deployment secrets configured, so automatic
deployment is live. The bootstrap setup below is kept for reference.

Deploy path — a push to `main` that touches `website/**` or
`.github/workflows/website.yml` starts **Website production deploy**
automatically. The workflow verifies the static site, waits for the
`website-production` environment approval, deploys the checked-out `website/`
tree to Pages project `bearoster` on production branch `main`, and then fetches
all four legal URLs to check their required content.

## Shelved: GitHub environment gate (one-time setup if plan is upgraded)

Run these commands yourself:

```bash
scripts/website/configure-deploy-gate.sh
scripts/website/bootstrap-production-secrets.sh
```

The first script creates `website-production`, sets your GitHub identity as the
required reviewer, and permits deployment only from `main`. The second copies
two named values from Infisical `Bearoster/prod` into the GitHub environment:
`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. It never prints either
value.

The Cloudflare token should be scoped only to the Bearoster Cloudflare account
with **Cloudflare Pages: Edit**. If the custom domain still has to be attached,
do that in Cloudflare first with a separately scoped, human-run process; do not
broaden the deploy token to DNS administration.

Because this Infisical instance is currently bound to `http://localhost`, CI
cannot fetch from it over OIDC. The one-time bootstrap therefore performs the
copy while you are present at the terminal. Choose the shortest practical
Cloudflare token expiry; after it expires, deployment fails safely until you run
the bootstrap again with a fresh token.

## Deploy and roll back

After the site branch is merged, changing `website/` or the deploy workflow on
`main` starts **Website production deploy** automatically. GitHub asks for
approval before running `wrangler pages deploy website`. The target is
hard-coded to Pages project `bearoster`, production branch `main`, and the
checked-out `website/` tree. The workflow finishes by fetching all four legal
URLs and checking their required content.

Rollback is a Cloudflare Pages deployment rollback to the previous production
deployment, followed by HTTP checks of all four legal URLs. If rollback is
unavailable, revert the site commit on `main` and approve a new deployment.
