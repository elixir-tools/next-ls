# Changelog

## [0.5.1](https://github.com/elixir-tools/next-ls/compare/v0.5.0...v0.5.1) (2023-07-06)


### Bug Fixes

* run compiler in task ([#95](https://github.com/elixir-tools/next-ls/issues/95)) ([96bfc76](https://github.com/elixir-tools/next-ls/commit/96bfc76250a568ea313693586adffd2de5249692)), closes [#60](https://github.com/elixir-tools/next-ls/issues/60)
* start dedicated process for runtime logging ([#94](https://github.com/elixir-tools/next-ls/issues/94)) ([32f8313](https://github.com/elixir-tools/next-ls/commit/32f8313dfd0d279214b999a746aeb10cf1e8dbf3)), closes [#92](https://github.com/elixir-tools/next-ls/issues/92)

## [0.5.0](https://github.com/elixir-tools/next-ls/compare/v0.4.0...v0.5.0) (2023-07-03)


### Features

* **definition:** aliases ([#83](https://github.com/elixir-tools/next-ls/issues/83)) ([6156f11](https://github.com/elixir-tools/next-ls/commit/6156f1176581e5caa7b176528e7b72942943e61c))
* **definition:** go to imported function ([#79](https://github.com/elixir-tools/next-ls/issues/79)) ([afe2990](https://github.com/elixir-tools/next-ls/commit/afe299013ee64ecc5b1477b4ca8bdae51bf0fa76))
* **definition:** local function ([#78](https://github.com/elixir-tools/next-ls/issues/78)) ([57ccc2e](https://github.com/elixir-tools/next-ls/commit/57ccc2eb6d90df5bd652022f5002ade6e0b79605))
* **definition:** remote function definition ([#80](https://github.com/elixir-tools/next-ls/issues/80)) ([adbf009](https://github.com/elixir-tools/next-ls/commit/adbf009ffa8c5347d01b0dbdc418670192c8dec1))
* **definitions:** macros ([#81](https://github.com/elixir-tools/next-ls/issues/81)) ([1d3b022](https://github.com/elixir-tools/next-ls/commit/1d3b022657b09661afc8171428bf021409c3c4a9))

## [0.4.0](https://github.com/elixir-tools/next-ls/compare/v0.3.5...v0.4.0) (2023-06-29)


### Features

* document symbols ([#69](https://github.com/elixir-tools/next-ls/issues/69)) ([bf80999](https://github.com/elixir-tools/next-ls/commit/bf809997bd51bc25b1abec610954e82de4be499d)), closes [#41](https://github.com/elixir-tools/next-ls/issues/41)


### Bug Fixes

* **docs:** typo in mix.exs ([#70](https://github.com/elixir-tools/next-ls/issues/70)) ([db11c1c](https://github.com/elixir-tools/next-ls/commit/db11c1c0449e2513c49576203dc4d2f6ffdfbdf8))

## [0.3.5](https://github.com/elixir-tools/next-ls/compare/v0.3.4...v0.3.5) (2023-06-27)


### Bug Fixes

* add type to workspace symbol ([#67](https://github.com/elixir-tools/next-ls/issues/67)) ([905ff62](https://github.com/elixir-tools/next-ls/commit/905ff6260a868d743702562be29ed3906ad42df0))
* filter out hidden functions from workspace symbols ([#66](https://github.com/elixir-tools/next-ls/issues/66)) ([202a906](https://github.com/elixir-tools/next-ls/commit/202a90699d8e1bcb3c0a25c36fb1785923c80d31)), closes [#39](https://github.com/elixir-tools/next-ls/issues/39)
* properly close the symbol table on shutdown ([#65](https://github.com/elixir-tools/next-ls/issues/65)) ([837d02f](https://github.com/elixir-tools/next-ls/commit/837d02fcfdb3de4e4b440e5f184c04edba69d11f))

## [0.3.4](https://github.com/elixir-tools/next-ls/compare/v0.3.3...v0.3.4) (2023-06-27)


### Bug Fixes

* cancel current progress messages when changing/saving file ([#61](https://github.com/elixir-tools/next-ls/issues/61)) ([dca3b25](https://github.com/elixir-tools/next-ls/commit/dca3b25d420294a4ded8f920fdf9be54022ebc58)), closes [#40](https://github.com/elixir-tools/next-ls/issues/40)

## [0.3.3](https://github.com/elixir-tools/next-ls/compare/v0.3.2...v0.3.3) (2023-06-25)


### Bug Fixes

* correctly set compiler diagnostic columns ([d2bbae8](https://github.com/elixir-tools/next-ls/commit/d2bbae829fafe78d71727235acd6b715397a6cf3))

## [0.3.2](https://github.com/elixir-tools/next-ls/compare/v0.3.1...v0.3.2) (2023-06-25)


### Bug Fixes

* bin/nextls ([2262ad3](https://github.com/elixir-tools/next-ls/commit/2262ad3dea517673a4735c4ad2ddd649450ae092))

## [0.3.1](https://github.com/elixir-tools/next-ls/compare/v0.3.0...v0.3.1) (2023-06-25)


### Bug Fixes

* use correct directory for symbol table ([#34](https://github.com/elixir-tools/next-ls/issues/34)) ([3e83987](https://github.com/elixir-tools/next-ls/commit/3e83987900bbd1d951bc1c7b7af80d566744a022))

## [0.3.0](https://github.com/elixir-tools/next-ls/compare/v0.2.3...v0.3.0) (2023-06-25)


### Features

* basic symbol table ([#30](https://github.com/elixir-tools/next-ls/issues/30)) ([37fc91a](https://github.com/elixir-tools/next-ls/commit/37fc91a2e03f21479f421db5860bbd0901331c20))
* filter workspace symbols using query ([#32](https://github.com/elixir-tools/next-ls/issues/32)) ([65f4ee4](https://github.com/elixir-tools/next-ls/commit/65f4ee4594e102065871c75852f637083e2ca599))
* workspace symbols ([#31](https://github.com/elixir-tools/next-ls/issues/31)) ([c1aa20c](https://github.com/elixir-tools/next-ls/commit/c1aa20c62caf20aa6c9f321cae1329b973f663a8))

## [0.2.3](https://github.com/elixir-tools/next-ls/compare/v0.2.2...v0.2.3) (2023-06-24)


### Bug Fixes

* log next-ls version on start ([c10ab90](https://github.com/elixir-tools/next-ls/commit/c10ab9047449866bf2e446a9891fb46e112efcee))

## [0.2.2](https://github.com/elixir-tools/next-ls/compare/v0.2.1...v0.2.2) (2023-06-24)


### Bug Fixes

* handle formatting files with syntax errors ([#26](https://github.com/elixir-tools/next-ls/issues/26)) ([b124b16](https://github.com/elixir-tools/next-ls/commit/b124b16aedfd234ac365dd3446635721cf4ad38e))

## [0.2.1](https://github.com/elixir-tools/next-ls/compare/v0.2.0...v0.2.1) (2023-06-23)


### Bug Fixes

* bump gen_lsp ([#24](https://github.com/elixir-tools/next-ls/issues/24)) ([721b7da](https://github.com/elixir-tools/next-ls/commit/721b7dac169decff6cfdeb7a57dedb13cbacb6ad))

## [0.2.0](https://github.com/elixir-tools/next-ls/compare/v0.1.1...v0.2.0) (2023-06-23)


### Features

* progress messages ([#20](https://github.com/elixir-tools/next-ls/issues/20)) ([a68203b](https://github.com/elixir-tools/next-ls/commit/a68203b722f78dc4edf58d5a1289ab44865f395e))


### Bug Fixes

* **elixir:** compiler diagnostics have iodata ([#18](https://github.com/elixir-tools/next-ls/issues/18)) ([f28af33](https://github.com/elixir-tools/next-ls/commit/f28af33a31f19da2088d0c3f52beb04f801bac39)), closes [#15](https://github.com/elixir-tools/next-ls/issues/15)
* gracefully handle uninitialized runtime ([#19](https://github.com/elixir-tools/next-ls/issues/19)) ([9975501](https://github.com/elixir-tools/next-ls/commit/997550161e818941fbddd56a587d1d5d93fbfd92))

## [0.1.1](https://github.com/elixir-tools/next-ls/compare/v0.1.0...v0.1.1) (2023-06-20)


### Bug Fixes

* **elixir:** format inside runtime ([#13](https://github.com/elixir-tools/next-ls/issues/13)) ([99965f1](https://github.com/elixir-tools/next-ls/commit/99965f1b17250ead7524143b13246f08553b940a))
* prefix logs with [NextLS] ([#12](https://github.com/elixir-tools/next-ls/issues/12)) ([36d8603](https://github.com/elixir-tools/next-ls/commit/36d86035dbcebbdee288e75221493547fb6afe04))

## [0.1.0](https://github.com/elixir-tools/next-ls/compare/v0.0.1...v0.1.0) (2023-06-20)


### Features

* basic lsp ([#5](https://github.com/elixir-tools/next-ls/issues/5)) ([aabdda0](https://github.com/elixir-tools/next-ls/commit/aabdda0238b56cc9ad65c403a74df6f4754d59c8))
* **elixir:** compiler diagnostics ([#8](https://github.com/elixir-tools/next-ls/issues/8)) ([fafb2ca](https://github.com/elixir-tools/next-ls/commit/fafb2ca1c0d079a9ee4be15a0282fe089243fb82))
* exdoc ([19d8bad](https://github.com/elixir-tools/next-ls/commit/19d8bad3d63d9ceee9081b27beda4e36328c12cd))
* formatting ([#9](https://github.com/elixir-tools/next-ls/issues/9)) ([5f0c73c](https://github.com/elixir-tools/next-ls/commit/5f0c73c4e93131ec97265afb3c6fb3d223ac3d64))

## CHANGELOG
