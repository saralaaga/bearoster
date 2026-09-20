# Bearoster website

Static, dependency-free site for `https://bearoster.com`.

- Chinese home: `/`
- English home: `/en/`
- App Store legal URLs: `/privacy` and `/support`

## Cloudflare Pages deploy

1. Connect this repository to Cloudflare Pages.
2. Set **Build output directory** to `website`.
3. Add custom domain `bearoster.com`.
4. Deploy, then verify `/privacy`, `/support`, `/en/privacy`, and `/en/support` return HTTP 200.

## Local check

```bash
python3 -m http.server 4173 --directory website
```
