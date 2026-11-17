# wpsite — Project Memory

## Docker image versions (as of v1.6.0, checked 2026-11-17)
- `mariadb:12.3` (current LTS; `latest` = 13.0, not LTS) + `MARIADB_AUTO_UPGRADE: "1"` — infra compose, `src/cmd_infra.sh`
- `traefik:v3.7` (latest stable minor; v3.8 was rc) — infra compose, `src/cmd_infra.sh`
- `wordpress:7.1-php8.4-apache` — site compose, `src/commands/cmd_create.sh` (was `:latest` = PHP 8.3)
- `phpmyadmin:5.2` (official image; replaced `phpmyadmin/phpmyadmin:latest`) — infra compose
- GitHub Actions: `actions/checkout@v7`, `actions/upload-artifact@v7`, `softprops/action-gh-release@v3`

Policy: pin to minor tags (patch updates still arrive via `docker compose pull` on create).

## Version / release workflow
- Version source of truth: `VERSION` file; bump with `make set-version NEW_VERSION=x.y.z` (updates VERSION, src/lib/config.sh, src/main.sh, README.md, rebuilds `wpsite`).
- Release is automated by pushing a tag `v*` (`.github/workflows/release.yml` → softprops/action-gh-release). Assets: `wpsite` + `wpsite.sha256`.
- `wpsite` in repo root is the built artifact (concatenated from `src/`). Edit `src/`, then `make build`; never hand-edit `wpsite`.

## Testing the boilerplate WITHOUT touching the real env
`SITES_DIR="$HOME/wp-sites"` (src/lib/config.sh) — the real env lives at `~/wp-sites`. To test in isolation:
1. `TESTHOME=$(mktemp -d /tmp/wpsite-test-home.XXXXXX); mkdir -p "$TESTHOME/wp-sites"`
2. Run all wpsite commands with `HOME="$TESTHOME" DOCKER_CONFIG="$REALHOME/.docker"`.
   - `DOCKER_CONFIG` MUST point at the real `~/.docker` because the `docker compose` CLI plugin lives in `~/.docker/cli-plugins`; under a temp `HOME` docker can't find it → error `unknown shorthand flag: 'd' in -d`.
3. Typical test: `infra install` → `infra start` → `create <name> test` → verify → `remove <name>` (pipe `y\n` to confirm) → `infra stop` → `rm -rf "$TESTHOME"`.

## Interactive prompts (non-tty gotchas)
- `create` prompts for domain suffix and `Use HTTPS? (Y/n)` — pipe input or pass suffix as 2nd arg. Use HTTP (`n`) to avoid mkcert CA changes.
- `remove` prompts `Are you sure? (y/N)` — pipe `y\n` or it cancels.
- Verify site without DNS: `curl -s -o /dev/null -w "%{http_code}" -H "Host: <site>.test" http://localhost/` (expect 302 → install.php when fresh).

## Changelog notes
- v1.6.0: WordPress pinned to 7.1/PHP 8.4, official phpmyadmin:5.2, MARIADB_AUTO_UPGRADE, checkout@v7. Tested in isolated HOME: WP 7.1.4, PHP 8.4.27, MariaDB 12.3.3 healthy, site 302 → install.php, pma 200.
- v1.5.0: bumped MariaDB 10.6→12.3 and Traefik v3.3→v3.7; rebuilt `wpsite` (also picked up commit `192747b` "Pull latest Docker images before starting site on create").
- Commit `192747b` (user, previously unpushed) modified `src/commands/cmd_create.sh` to `docker compose pull` before `up -d`.

## Pending / tech debt
- Real env `~/wp-sites` still runs `mariadb:11.4` + `traefik:v3.3` (not upgraded on purpose). Upgrade = backup DBs, `wpsite infra install` (overwrite), `infra start`; auto-upgrade handles 11.4 → 12.3.
- Existing sites keep their old `wordpress:latest` compose; only new sites get the pinned tag.
- `src/main.sh` changelog has no 1.4.0 / 1.5.0 entries.
- Test gotcha: when the suffix is passed as an arg, pipe only `n\n` to `create`; extra input answers the HTTPS prompt.
- Infra compose still uses `MYSQL_*` env names (MariaDB accepts them; `MARIADB_*` are the current names).
- v1.6.0 changes are not committed / tagged yet.
