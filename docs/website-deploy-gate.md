# Website deployment gate

`bearoster.com` is a production resource. Agents may edit and verify `website/`,
but deployment must run through `.github/workflows/website.yml`. That workflow
uses GitHub environment protection, not chat approval or a local script, as its
human gate.

## One-time setup

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

After the site branch is merged, dispatch **Website production deploy** from
`main`. GitHub asks for approval before running `wrangler pages deploy
website`. The target is hard-coded to Pages project `bearoster`, production
branch `main`, and the checked-out `website/` tree. The workflow finishes by
fetching all four legal URLs and checking their required content.

Rollback is a Cloudflare Pages deployment rollback to the previous production
deployment, followed by HTTP checks of all four legal URLs. If rollback is
unavailable, revert the site commit on `main` and approve a new deployment.
