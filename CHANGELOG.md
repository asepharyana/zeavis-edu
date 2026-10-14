## [0.2.5](https://github.com/asepharyana/zeavis-edu/compare/v0.2.4...v0.2.5) (2026-10-14)


### Bug Fixes

* **ci:** collapse build_args to one token before normalising it ([f36212f](https://github.com/asepharyana/zeavis-edu/commit/f36212f08ec5c7a7fa04972d0561c8e33f18e420))

## [0.2.4](https://github.com/asepharyana/zeavis-edu/compare/v0.2.3...v0.2.4) (2026-10-14)


### Bug Fixes

* **ci:** make build_args in docker-images.json actually reach the build ([2dee2ef](https://github.com/asepharyana/zeavis-edu/commit/2dee2ef26e1f9563a14af5a47032efcb13357fc5))

## [0.2.3](https://github.com/asepharyana/zeavis-edu/compare/v0.2.2...v0.2.3) (2026-10-14)


### Bug Fixes

* **api:** make the production image resolve its own dependencies ([921f152](https://github.com/asepharyana/zeavis-edu/commit/921f152095c8535881cd424715b0636614d1a11d))
* **web:** serve without the api container already existing ([f97cc8b](https://github.com/asepharyana/zeavis-edu/commit/f97cc8bff85157e4e89aaeaf4f4d73d6ef3f6e59))

## [0.2.2](https://github.com/asepharyana/zeavis-edu/compare/v0.2.1...v0.2.2) (2026-10-14)


### Bug Fixes

* **ci:** cap the release body, which GitHub limits to 125,000 chars ([015c77e](https://github.com/asepharyana/zeavis-edu/commit/015c77e6fb5e77f0000f8e45a983babdc8de1f9f))

## [0.2.1](https://github.com/asepharyana/zeavis-edu/compare/v0.2.0...v0.2.1) (2026-10-14)


### Bug Fixes

* **ci:** stop embedding the release notes in the release commit ([2ce808e](https://github.com/asepharyana/zeavis-edu/commit/2ce808e7608e22dde0980f0b9b269df384a802af))

# [0.2.0](https://github.com/asepharyana/zeavis-edu/compare/v0.1.32...v0.2.0) (2026-10-14)


### Bug Fixes

* auto-fix code quality [skip ci] ([f96ae51](https://github.com/asepharyana/zeavis-edu/commit/f96ae515489c626fa1e83ea5f58e65c2eb921ff9))
* auto-fix code quality [skip ci] ([811652d](https://github.com/asepharyana/zeavis-edu/commit/811652dd7bfe88d96d4df86f15b055ceda07ad93))
* auto-fix code quality [skip ci] ([b494ee9](https://github.com/asepharyana/zeavis-edu/commit/b494ee96ee9f722787bcd317bae6dbdc7751ee9b))
* **dependabot:** use "bun" package-ecosystem for "/" ([7154dc7](https://github.com/asepharyana/zeavis-edu/commit/7154dc72c61e47e4143b6295a6be7b30eb4e0d64))
* **deploy:** point the web live path at apps/web/dist and build shared for api ([4e760ec](https://github.com/asepharyana/zeavis-edu/commit/4e760ec4df2d656ce0211718bb2c26f2e59b1730))
* **deps:** pin @moonrepo/cli to 2.5.6 for Dependabot's release-age gate ([dc38819](https://github.com/asepharyana/zeavis-edu/commit/dc38819e7c475ad4d184181350b15b8292dd4afc))
* **moon:** set vcs.defaultBranch to main ([a561cee](https://github.com/asepharyana/zeavis-edu/commit/a561cee7c6832f0557ab2429dfcf5aebf4925772))
* **nix:** restrict flake to x86_64-linux (nixpkgs 26.11 dropped darwin) ([2eb4e47](https://github.com/asepharyana/zeavis-edu/commit/2eb4e47585f5ee1cbc20550643f30ba4f972907c))
* sync bun.lock to package.json for dependabot ([bc039bb](https://github.com/asepharyana/zeavis-edu/commit/bc039bbbeb6e89fc7032a08cc988352f3d08c1b2))


### Features

* add dependabot auto-merge workflow ([11bf89c](https://github.com/asepharyana/zeavis-edu/commit/11bf89c7587f0720c9e8467b3bbe928dadb21dbc))
* add dependabot config (npm auto-deps) ([ae1585e](https://github.com/asepharyana/zeavis-edu/commit/ae1585e21662558d3b6beb036f6cca1544ea36dd))
* **deploy:** replace the Nix deploy with pnpm + systemd (api, web) ([de98dad](https://github.com/asepharyana/zeavis-edu/commit/de98dad5e45e7643dbfb1cf5127efdf57a98ce0e))
* **ml:** add ml-service to pnpm+systemd deploy (cargo build on VPS, new launcher) ([9c08f20](https://github.com/asepharyana/zeavis-edu/commit/9c08f203b33a6fbb1fc2e9c0ac725d5528916362))
* update dependabot config ([901f0bd](https://github.com/asepharyana/zeavis-edu/commit/901f0bd41becdddf1a89dcc3c215e58a89cdea9f))
* update dependabot config ([ee08b9f](https://github.com/asepharyana/zeavis-edu/commit/ee08b9f0975cfbead3489efbddd254a258c7295d))

# Changelog

All notable changes to zeavis-edu are documented here.
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and are derived automatically from
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
