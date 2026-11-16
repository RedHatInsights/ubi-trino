# ubi-trino

Trino container image built on RHEL UBI.


## Dependency updates

[Renovate via MintMaker](https://konflux-ci.dev/docs/mintmaker/user/) updates the Dockerfile base images and CI dependency references using `renovate.json` and its inherited preset. Review and merge those PRs through the usual Konflux checks. A separate GitHub Actions base-image update workflow is not needed.

The retired workflow also compared installed RPMs in the legacy `quay.io/cloudservices/ubi-trino:latest` image. Renovate's base-image PRs do not replace that RPM-inventory comparison or provide a scheduled rebuild solely for package-repository changes; trigger a Konflux rebuild separately when needed.

The checked-in Renovate configuration does not define custom managers for the `TRINO_VERSION`, `JDK_VERSION`, or `PROMETHEUS_VERSION` build arguments. Review those pins manually, including the [Trino release notes](https://trino.io/docs/current/release.html), Java runtime requirements, JMX Exporter releases, and any affected JVM/server/catalog
configuration. Configuration in `deploy/clowdapp.yaml` overrides image defaults and must be reviewed as well.


## Development workflow

1. Create a branch from `main` and make the required changes.
2. For a Trino upgrade, update `ARG TRINO_VERSION` in `Dockerfile` and verify it with `./scripts/get_trino_version.sh`. Use `./scripts/check_upstream.sh` to compare against the latest upstream numeric release tag; it exits with status 1 when an upgrade is available and accepts `quiet` to suppress output.
3. When incrementing the image build number, run `./scripts/bump-image-tag.sh`. It updates and stages `image_build_num.txt`.
4. Build locally and exercise the affected configuration and queries. For example:
   ```sh
   docker build --build-arg VERSION="$(./scripts/get_image_tag.sh)" \
     -t ubi-trino:local .
   ```
5. Commit, push, and open a PR against `main`. Konflux runs the multi-architecture
   build and configured checks. Review those results before merging.


## Build pipeline and utility scripts

The PipelineRuns in `.tekton/pull_request.yaml` and `.tekton/push.yaml` use `pipeline-build-multiarch`. Its `get-version` task calls `scripts/get_image_tag.sh`, which combines `TRINO_VERSION` with `image_build_num.txt`. The result is passed as the Dockerfile `VERSION` build argument for the image's `version` label. Published image tags are supplied separately by the pipeline using commit identifiers and PR prefixes.

Development/build helpers live in `scripts/` and resolve repository files relative to their own location, so they can be invoked from another directory. Container runtime entrypoints remain in `bin/`, which the Dockerfile installs into the image.

- `check_upstream.sh`: compares the configured Trino version with upstream; retained because Renovate does not track this build argument.
- `get_latest_repo_release_tag.sh`: fetches the latest numeric upstream Trino release tag; used by `check_upstream.sh`.
- `get_trino_version.sh`: reads `TRINO_VERSION` from `Dockerfile`; used by `get_image_tag.sh`.
- `get_image_tag.sh`: returns `<Trino version>-<build number>`; used by Konflux and the local build wrapper.
- `bump-image-tag.sh`: increments and stages the build-number file.
- `docker-build-dev.sh`: local build wrapper using `get_image_tag.sh`; creates local `quay.io/cloudservices/ubi-trino` tags and does not push them.

The `get-version` task definition is maintained in `.tekton/task-get-version.yaml`. The pipeline passes the script path explicitly, so the directory move also works with the installed Task's previous default path. Future changes to the Task body still need to be applied to the Konflux namespace through the usual Task-management process.

