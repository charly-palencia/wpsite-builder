# wpsite — Project Memory

## Docker image versions (as of v1.5.0)
- `mariadb:12.3` (latest stable) — infra compose, `src/cmd_infra.sh`
- `traefik:v3.7` (latest stable) — infra compose, `src/cmd_infra.sh`
- `wordpress:latest` — site compose, `src/commands/cmd_create.sh`
- `phpmyadmin/phpmyadmin:latest` — infra compose, `src/cmd_infra.sh`

`wordpress` and `phpmyadmin` intentionally use `:latest` (auto-updates). The versioned images are `mariadb` and `traefik`.

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
- v1.5.0: bumped MariaDB 10.6→12.3 and Traefik v3.3→v3.7; rebuilt `wpsite` (also picked up commit `192747b` "Pull latest Docker images before starting site on create").
- Commit `192747b` (user, previously unpushed) modified `src/commands/cmd_create.sh` to `docker compose pull` before `up -d`.
