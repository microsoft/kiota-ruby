# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.23.1](https://github.com/microsoft/kiota-ruby/compare/v0.23.0...v0.23.1) (2026-09-23)


### Bug Fixes

* send a request body that was set from a stream ([74157a4](https://github.com/microsoft/kiota-ruby/commit/74157a494e51e8200223e53b399ed3029b82417d))
* send a request body that was set from a stream ([3dab001](https://github.com/microsoft/kiota-ruby/commit/3dab00157764d74370c3787284b1095730a8f45f))

## [0.23.0](https://github.com/microsoft/kiota-ruby/compare/v0.22.0...v0.23.0) (2026-09-21)


### Features

* add support for the HTTP QUERY verb (RFC 10008) ([8329229](https://github.com/microsoft/kiota-ruby/commit/8329229c330cff8d341c9cbf1560bbf3620513f3))
* Add support for the HTTP QUERY verb (RFC 10008) ([e5f5288](https://github.com/microsoft/kiota-ruby/commit/e5f5288ee31d1555ee3a4baea230a2d253c8408f))

## [0.22.0](https://github.com/microsoft/kiota-ruby/compare/v0.21.0...v0.22.0) (2026-09-18)


### Features

* add the collection, primitive and no-content send methods ([85ee08b](https://github.com/microsoft/kiota-ruby/commit/85ee08b747c437f272a331c14567e8b98657cf7a))
* add the collection, primitive and no-content send methods ([592e28d](https://github.com/microsoft/kiota-ruby/commit/592e28dd9a7aa6d8dd809314b8b20a1855a0a683))
* serialize scalar request bodies and enum collections ([57a4158](https://github.com/microsoft/kiota-ruby/commit/57a4158aea0eb7cc0bc3d97ddbcbf487953fb104))
* serialize scalar request bodies and enum collections ([37ec574](https://github.com/microsoft/kiota-ruby/commit/37ec5746507ec37633d4e34d42a1eba9f985ffd2))

## [0.21.0](https://github.com/microsoft/kiota-ruby/compare/v0.20.0...v0.21.0) (2026-09-17)


### ⚠ BREAKING CHANGES

* leave unset scalars off the wire

### Bug Fixes

* deserialize composed type wrappers instead of raising ([4f65d60](https://github.com/microsoft/kiota-ruby/commit/4f65d60f84191c8bde288b09dcd5e0d130f80524))
* deserialize composed type wrappers instead of raising ([ced3eb5](https://github.com/microsoft/kiota-ruby/commit/ced3eb5a43532eb5b23c83efd0faac934c732140))
* leave unset scalars off the wire ([98ac7c8](https://github.com/microsoft/kiota-ruby/commit/98ac7c85819622afabad551132b3c987befa95d5))
* match the error mapping by string status code ([ae8fdf1](https://github.com/microsoft/kiota-ruby/commit/ae8fdf133f699f1b1a42b25a9a04e78b44207279))
* match the error mapping by string status code ([cd1bdc0](https://github.com/microsoft/kiota-ruby/commit/cd1bdc0bb0ac00a6de139d4fa36892c728e9950d))
* remove misplaced magic comments ([8150e41](https://github.com/microsoft/kiota-ruby/commit/8150e418a6cb8c536fcfda20c5e7e72935810352))

## [0.20.0](https://github.com/microsoft/kiota-ruby/compare/v0.19.0...v0.20.0) (2026-08-27)


### Features

* adds support for wildcard host validation ([fc59c2b](https://github.com/microsoft/kiota-ruby/commit/fc59c2b310937fd79763171d6c619bba31002769))
* adds support for wildcard host validation ([ca42d56](https://github.com/microsoft/kiota-ruby/commit/ca42d5601330777e109f54683d4fc1a20444e82b))

## [0.19.0](https://github.com/microsoft/kiota-ruby/compare/v0.18.0...v0.19.0) (2026-08-27)


### ⚠ BREAKING CHANGES

* read JSON scalars by type instead of coercing

### Bug Fixes

* read JSON scalars by type instead of coercing ([e1ee161](https://github.com/microsoft/kiota-ruby/commit/e1ee16134c9f66f429303a9b0d23fae08f956e36))
* support primitive members in composed types ([2a64b1d](https://github.com/microsoft/kiota-ruby/commit/2a64b1dc07fc15c5433fd6189a08eec7981711fe))

## [0.18.0](https://github.com/microsoft/kiota-ruby/compare/v0.17.0...v0.18.0) (2026-08-24)


### Features

* add composed types support (union/intersection) ([039b8ae](https://github.com/microsoft/kiota-ruby/commit/039b8ae312265200a3038d9bdffc8640b8fb5ccb))
* add composed types support (union/intersection) ([4907000](https://github.com/microsoft/kiota-ruby/commit/4907000b2444deeaff227ca6216ab73bd3e9c428))
* add workflow_dispatch trigger to all workflows ([e7ec34e](https://github.com/microsoft/kiota-ruby/commit/e7ec34e12163689550c84dafe336ead7f37fe3b1))
* move Ruby libraries to a monorepo ([f4cf832](https://github.com/microsoft/kiota-ruby/commit/f4cf832c141df83ed23638cfa2531a976f9fe8c9))
* Switch to monorepo ([d83796d](https://github.com/microsoft/kiota-ruby/commit/d83796d31d67005d96b81295e3181a2ce032475a))
* upgrade ruby CI matrix to 3.3, 3.4 and 4.0 ([b8ae278](https://github.com/microsoft/kiota-ruby/commit/b8ae2789b67ec2f4a8d92af233dea81bdf46b803))
* upgrade ruby CI matrix to 3.3, 3.4 and 4.0 ([2ab5a2e](https://github.com/microsoft/kiota-ruby/commit/2ab5a2e454ac0da738a6e70daf85834a94e281ec))


### Bug Fixes

* anonymous authentication provider did not return a fiber resulting in a failure ([29b9d31](https://github.com/microsoft/kiota-ruby/commit/29b9d31003d787e453c39ec9c039bf575f599463))
* update minimum required ruby version to 3.3.0 ([26e398e](https://github.com/microsoft/kiota-ruby/commit/26e398eb42b82b5ca86fa51088f55e1dd5edfdab))
* update minimum required ruby version to 3.3.0 ([da96f19](https://github.com/microsoft/kiota-ruby/commit/da96f1934b4ae16dac85a8e3ac0a9133da6ef1a0))
* use VERSION constant for abstractions dependency in downstream gemspecs ([dc5c71c](https://github.com/microsoft/kiota-ruby/commit/dc5c71c82adc49b7002b269e9b62e6dc2fdf0103))
* use VERSION constant for abstractions dependency in downstream gemspecs ([3327913](https://github.com/microsoft/kiota-ruby/commit/33279138f3d7a566e676e8d4d92c69b411d209cd))

## [0.16.0](https://github.com/microsoft/kiota-abstractions-ruby/compare/v0.15.1...v0.16.0) (2026-08-19)


### Features

* add composed types support (union/intersection) ([039b8ae](https://github.com/microsoft/kiota-abstractions-ruby/commit/039b8ae312265200a3038d9bdffc8640b8fb5ccb))
* add composed types support (union/intersection) ([4907000](https://github.com/microsoft/kiota-abstractions-ruby/commit/4907000b2444deeaff227ca6216ab73bd3e9c428))

## [0.15.1](https://github.com/microsoft/kiota-abstractions-ruby/compare/v0.15.0...v0.15.1) (2026-04-23)


### Bug Fixes

* update minimum required ruby version to 3.3.0 ([26e398e](https://github.com/microsoft/kiota-abstractions-ruby/commit/26e398eb42b82b5ca86fa51088f55e1dd5edfdab))
* update minimum required ruby version to 3.3.0 ([da96f19](https://github.com/microsoft/kiota-abstractions-ruby/commit/da96f1934b4ae16dac85a8e3ac0a9133da6ef1a0))

## [0.15.0](https://github.com/microsoft/kiota-abstractions-ruby/compare/v0.14.4...v0.15.0) (2026-04-20)


### Features

* add workflow_dispatch trigger to all workflows ([e7ec34e](https://github.com/microsoft/kiota-abstractions-ruby/commit/e7ec34e12163689550c84dafe336ead7f37fe3b1))
* upgrade ruby CI matrix to 3.3, 3.4 and 4.0 ([b8ae278](https://github.com/microsoft/kiota-abstractions-ruby/commit/b8ae2789b67ec2f4a8d92af233dea81bdf46b803))
* upgrade ruby CI matrix to 3.3, 3.4 and 4.0 ([2ab5a2e](https://github.com/microsoft/kiota-abstractions-ruby/commit/2ab5a2e454ac0da738a6e70daf85834a94e281ec))


### Bug Fixes

* anonymous authentication provider did not return a fiber resulting in a failure ([29b9d31](https://github.com/microsoft/kiota-abstractions-ruby/commit/29b9d31003d787e453c39ec9c039bf575f599463))

## [Unreleased]

### Added

### Changed

## [0.14.4] - 2024-01-06

### Changed

- Fixed a bug that was causing the content not to be set in the request information.

## [0.14.3] - 2023-10-11

### Added

- Added a content type parameter to the stream content method of request information.

## [0.14.2] - 2023-10-06

### Added

- Added a try_add method for request headers

## [0.14.1] - 2023-09-06

### Changed

- Switched to std URI template

## [0.14.0] - 2023-03-14

### Added

- Added a base request builder and request configuration class to reduce the amount of generated code.

### Changed

- Bumped minimum required ruby version to 3.0.

## [0.13.0] - 2023-01-10

### Added

- Added a method to convert abstract requests to native requests in the request adapter interface.

## [0.12.0] - 2022-12-30

### Added

- Initial public release of the package.
