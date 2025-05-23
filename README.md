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
