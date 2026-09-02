[![REUSE status](https://api.reuse.software/badge/github.com/openkcm/build)](https://api.reuse.software/info/github.com/openkcm/build)

# Open Key Chain Manager Build and CI Scripts

## About this project

OpenKCM Build and CI scripts

The scripts that are shared between the different repositories have been moved into this repository, which is intended to be used as a git submodule in the actual operator repositories.

Instead of `make`, we have decided to use the [task](https://taskfile.dev/) tool.

## Requirements

It is strongly recommended to include this submodule under the `hack/common` path in the operator repositories. While most of the coding is designed to work from anywhere within the including repository, there are some workarounds for bugs in `task` which rely on the assumption that this repo is a submodule under `hack/common` in the including repository.

## Setup

To use this repository, first check it out via
```shell
git submodule add https://github.com/openkcm/build.git hack/common
```
and ensure that it is checked-out via
```shell
git submodule init; git submodule update --recursive --remote
```

### Taskfile

To use the generic Taskfile contained in this repository, create a `Taskfile.yaml` in the including repository. It should look something like this:

```yaml
version: 3

vars:
  CODE_DIRS: '{{.ROOT_DIR}}/pkg/...'

includes:
  shared:
    taskfile: hack/common/Taskfile_library.yaml
    flatten: true
```


### CLI release binaries

Service and controller repos (those including `Taskfile_service.yaml` or `Taskfile_controller.yaml`) can
publish cross-compiled CLI binaries as release assets:

```shell
task build:bin:build_cli
```

This cross-compiles each entry in `CLI_COMPONENTS` and packages it into `CLI_DIST_DIR` as
`<name>_<version>_<os>_<arch>.tar.gz` (`.zip` for Windows), containing the binary plus the
`LICENSE` and `README.md`, along with a single `checksums.txt` holding the SHA-256 of every archive.

`CLI_COMPONENTS` is declared in the including repo's `Taskfile.yaml`, the same way `COMPONENTS` is.
Each entry is `<source dir>[:<binary name>]`, where the source directory is relative to the
repository root. Without the `:<binary name>` part, the directory's base name is used:

```yaml
includes:
  shared:
    taskfile: hack/common/Taskfile_service.yaml
    flatten: true
    vars:
      COMPONENTS: 'agent root'
      CLI_COMPONENTS: './cli:kryptonctl'   # builds ./cli, names the binary 'kryptonctl'
```

| Entry | Source directory | Binary name |
| --- | --- | --- |
| `./cli:kryptonctl` | `./cli` | `kryptonctl` |
| `./cli` | `./cli` | `cli` |
| `./cmd/agent:agentctl` | `./cmd/agent` | `agentctl` |

`CLI_COMPONENTS` is **unset by default, which means there is nothing to build** — repos that ship no
CLI need no configuration and the task does nothing. A source directory that does not exist is an
error rather than a silent skip.

| Variable | Default | Purpose |
| --- | --- | --- |
| `CLI_COMPONENTS` | *unset* — nothing to build | Space-separated `<source dir>[:<binary name>]` entries. Set by the including repo. |
| `CLI_DIST_PLATFORMS` | `linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64 windows/arm64` | Space-separated `<os>/<arch>` pairs to cross-compile for. |
| `CLI_DIST_DIR` | `<repo>/dist` | Where the archives and `checksums.txt` are written. |

Note that variables set under `includes.<name>.vars` take precedence over the command line, so a repo
pinning `CLI_DIST_PLATFORMS` there cannot override it with `task ... CLI_DIST_PLATFORMS=...`.

For example, to publish only Linux builds:

```shell
task build:bin:build_cli CLI_DIST_PLATFORMS="linux/amd64 linux/arm64"
```

The binaries themselves are also written to `bin/<binary name>.<os>-<arch>`, matching the naming the
image build and the Dockerfiles use.


### Makefile

This repo contains a dummy Makefile that for any command prints the instructions for installing `task`:
```
This repository uses task (https://taskfile.dev) instead of make.
Run 'go install github.com/go-task/task/v3/cmd/task@latest' to install the latest version.
Then run 'task -l' to list available tasks.
```

To re-use it, simply create a symbolic link from the importing repo:
```shell
ln -s ./hack/common/Makefile Makefile
```

## Support, Feedback, Contributing

This project is open to feature requests/suggestions, bug reports etc. via [GitHub issues](https://github.com/openkcm/<your-project>/issues). Contribution and feedback are encouraged and always welcome. For more information about how to contribute, the project structure, as well as additional contribution information, see our [Contribution Guidelines](CONTRIBUTING.md).

## Security / Disclosure
If you find any bug that may be a security problem, please follow our instructions at [in our security policy](https://github.com/openkcm/<your-project>/security/policy) on how to report it. Please do not create GitHub issues for security-related doubts or problems.

## Code of Conduct

We as members, contributors, and leaders pledge to make participation in our community a harassment-free experience for everyone. By participating in this project, you agree to abide by its [Code of Conduct](https://github.com/openkcm/.github/blob/main/CODE_OF_CONDUCT.md) at all times.

## Licensing

Copyright (20xx-)20xx SAP SE or an SAP affiliate company and <your-project> contributors. Please see our [LICENSE](LICENSE) for copyright and license information. Detailed information including third-party components and their licensing/copyright information is available [via the REUSE tool](https://api.reuse.software/info/github.com/openkcm/<your-project>).

<p align="center"><img alt="Bundesministerium für Wirtschaft und Klimaschutz (BMWK)-EU funding logo" src="https://apeirora.eu/assets/img/BMWK-EU.png" width="400"/></p>
