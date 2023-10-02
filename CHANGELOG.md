# Changelog

## [0.14.0](https://github.com/elixir-tools/next-ls/compare/v0.13.0...v0.14.0) (2023-10-02)


### Features

* adding/removing workspace folders ([#126](https://github.com/elixir-tools/next-ls/issues/126)) ([d26e29c](https://github.com/elixir-tools/next-ls/commit/d26e29c733ed040c7b7bc941956aa1ffef35726b))
* auto update ([#192](https://github.com/elixir-tools/next-ls/issues/192)) ([d2db88a](https://github.com/elixir-tools/next-ls/commit/d2db88a9d975c13d2b5284b47da15176d60e5878)), closes [#170](https://github.com/elixir-tools/next-ls/issues/170)
* basic lsp ([#5](https://github.com/elixir-tools/next-ls/issues/5)) ([aabdda0](https://github.com/elixir-tools/next-ls/commit/aabdda0238b56cc9ad65c403a74df6f4754d59c8))
* basic symbol table ([#30](https://github.com/elixir-tools/next-ls/issues/30)) ([37fc91a](https://github.com/elixir-tools/next-ls/commit/37fc91a2e03f21479f421db5860bbd0901331c20))
* burrito (aka binary executable) ([#144](https://github.com/elixir-tools/next-ls/issues/144)) ([094fd74](https://github.com/elixir-tools/next-ls/commit/094fd74744dc1c995473bbb8a36c900e8f7b0540))
* **cli:** --help flag ([#194](https://github.com/elixir-tools/next-ls/issues/194)) ([3cdfa18](https://github.com/elixir-tools/next-ls/commit/3cdfa18d841092adedaab93b5226ab1049685dcd))
* **cli:** --version flag ([#193](https://github.com/elixir-tools/next-ls/issues/193)) ([8455ba7](https://github.com/elixir-tools/next-ls/commit/8455ba75dd91299501b5f1e9962fa3a654802177))
* configureable MIX_ENV and MIX_TARGET ([#246](https://github.com/elixir-tools/next-ls/issues/246)) ([c56518a](https://github.com/elixir-tools/next-ls/commit/c56518a297afd4bb3cd3ad86ebc32f3bf5a70ab4))
* **definition,references:** go to definition when aliasing modules ([#152](https://github.com/elixir-tools/next-ls/issues/152)) ([627bb94](https://github.com/elixir-tools/next-ls/commit/627bb9452e2516cd483cb25e690f189dbd604e32))
* **definition,references:** local variables ([#253](https://github.com/elixir-tools/next-ls/issues/253)) ([7099370](https://github.com/elixir-tools/next-ls/commit/7099370f445de3aee48dfc03481f434536b8ae44))
* **definition,references:** module attributes ([#215](https://github.com/elixir-tools/next-ls/issues/215)) ([b14a09d](https://github.com/elixir-tools/next-ls/commit/b14a09d558b0b6e9c40456af7298a7578a1ca6eb))
* **definition:** aliases ([#83](https://github.com/elixir-tools/next-ls/issues/83)) ([6156f11](https://github.com/elixir-tools/next-ls/commit/6156f1176581e5caa7b176528e7b72942943e61c))
* **definition:** go to dependency ([#171](https://github.com/elixir-tools/next-ls/issues/171)) ([ddd28de](https://github.com/elixir-tools/next-ls/commit/ddd28deeb2b9a3a1ff0bede27a512ddd9c51165e))
* **definition:** go to imported function ([#79](https://github.com/elixir-tools/next-ls/issues/79)) ([afe2990](https://github.com/elixir-tools/next-ls/commit/afe299013ee64ecc5b1477b4ca8bdae51bf0fa76))
* **definition:** local function ([#78](https://github.com/elixir-tools/next-ls/issues/78)) ([57ccc2e](https://github.com/elixir-tools/next-ls/commit/57ccc2eb6d90df5bd652022f5002ade6e0b79605))
* **definition:** remote function definition ([#80](https://github.com/elixir-tools/next-ls/issues/80)) ([adbf009](https://github.com/elixir-tools/next-ls/commit/adbf009ffa8c5347d01b0dbdc418670192c8dec1))
* **definitions:** macros ([#81](https://github.com/elixir-tools/next-ls/issues/81)) ([1d3b022](https://github.com/elixir-tools/next-ls/commit/1d3b022657b09661afc8171428bf021409c3c4a9))
* document symbols ([#69](https://github.com/elixir-tools/next-ls/issues/69)) ([bf80999](https://github.com/elixir-tools/next-ls/commit/bf809997bd51bc25b1abec610954e82de4be499d)), closes [#41](https://github.com/elixir-tools/next-ls/issues/41)
* **elixir:** compiler diagnostics ([#8](https://github.com/elixir-tools/next-ls/issues/8)) ([fafb2ca](https://github.com/elixir-tools/next-ls/commit/fafb2ca1c0d079a9ee4be15a0282fe089243fb82))
* exdoc ([19d8bad](https://github.com/elixir-tools/next-ls/commit/19d8bad3d63d9ceee9081b27beda4e36328c12cd))
* **extension:** credo ([#163](https://github.com/elixir-tools/next-ls/issues/163)) ([70d52dc](https://github.com/elixir-tools/next-ls/commit/70d52dcc16a2532b181da60723f9d0d18384505b))
* filter workspace symbols using query ([#32](https://github.com/elixir-tools/next-ls/issues/32)) ([65f4ee4](https://github.com/elixir-tools/next-ls/commit/65f4ee4594e102065871c75852f637083e2ca599))
* find references ([#139](https://github.com/elixir-tools/next-ls/issues/139)) ([5a3b530](https://github.com/elixir-tools/next-ls/commit/5a3b530a7d283014f8fadcaf0feb0765dac68a1c)), closes [#43](https://github.com/elixir-tools/next-ls/issues/43)
* find references, reverts "fix: revert 0.7 ([#142](https://github.com/elixir-tools/next-ls/issues/142))" ([#150](https://github.com/elixir-tools/next-ls/issues/150)) ([1b8f72b](https://github.com/elixir-tools/next-ls/commit/1b8f72b8a1f6efcfa130643e9006d27319bbd738))
* formatting ([#9](https://github.com/elixir-tools/next-ls/issues/9)) ([5f0c73c](https://github.com/elixir-tools/next-ls/commit/5f0c73c4e93131ec97265afb3c6fb3d223ac3d64))
* hover ([#220](https://github.com/elixir-tools/next-ls/issues/220)) ([c5a68df](https://github.com/elixir-tools/next-ls/commit/c5a68dfef268ea64bf499954aede4caeb052a515))
* progress messages ([#20](https://github.com/elixir-tools/next-ls/issues/20)) ([a68203b](https://github.com/elixir-tools/next-ls/commit/a68203b722f78dc4edf58d5a1289ab44865f395e))
* progress messages for workspace indexing ([#179](https://github.com/elixir-tools/next-ls/issues/179)) ([09883bc](https://github.com/elixir-tools/next-ls/commit/09883bc0529076ff492cfd8289128cd340255e13))
* ranked fuzzy match search of workspace symbols ([#212](https://github.com/elixir-tools/next-ls/issues/212)) ([9395744](https://github.com/elixir-tools/next-ls/commit/9395744069537ec1b90dfd652c6b388781bb6795))
* workspace folders on startup ([#117](https://github.com/elixir-tools/next-ls/issues/117)) ([6b5ffaf](https://github.com/elixir-tools/next-ls/commit/6b5ffafda9c754f59548760384387dbe66cf8e3b))
* workspace symbols ([#31](https://github.com/elixir-tools/next-ls/issues/31)) ([c1aa20c](https://github.com/elixir-tools/next-ls/commit/c1aa20c62caf20aa6c9f321cae1329b973f663a8))


### Bug Fixes

* add .gitignore file to .elixir-tools directory ([#113](https://github.com/elixir-tools/next-ls/issues/113)) ([24d9915](https://github.com/elixir-tools/next-ls/commit/24d99158cd616b3d9426e2d21ecfcfcb9d90ec8b))
* add `:crypto` to extra_applications ([480aa01](https://github.com/elixir-tools/next-ls/commit/480aa01d9498c1370dce5d2ed3a3a1c14d7f2a63)), closes [#100](https://github.com/elixir-tools/next-ls/issues/100)
* add LSP var ([#98](https://github.com/elixir-tools/next-ls/issues/98)) ([d8554a8](https://github.com/elixir-tools/next-ls/commit/d8554a864f4f538113d20bb5692968fdf7a39884))
* add type to workspace symbol ([#67](https://github.com/elixir-tools/next-ls/issues/67)) ([905ff62](https://github.com/elixir-tools/next-ls/commit/905ff6260a868d743702562be29ed3906ad42df0))
* better error message when passing invalid flags ([#107](https://github.com/elixir-tools/next-ls/issues/107)) ([5e2f55f](https://github.com/elixir-tools/next-ls/commit/5e2f55f56c7278c1bb37a9e96056190b92fa2bfc)), closes [#103](https://github.com/elixir-tools/next-ls/issues/103)
* bin/nextls ([2262ad3](https://github.com/elixir-tools/next-ls/commit/2262ad3dea517673a4735c4ad2ddd649450ae092))
* bump gen_lsp ([#24](https://github.com/elixir-tools/next-ls/issues/24)) ([721b7da](https://github.com/elixir-tools/next-ls/commit/721b7dac169decff6cfdeb7a57dedb13cbacb6ad))
* cancel current progress messages when changing/saving file ([#61](https://github.com/elixir-tools/next-ls/issues/61)) ([dca3b25](https://github.com/elixir-tools/next-ls/commit/dca3b25d420294a4ded8f920fdf9be54022ebc58)), closes [#40](https://github.com/elixir-tools/next-ls/issues/40)
* cancel previous compile requests ([#242](https://github.com/elixir-tools/next-ls/issues/242)) ([0a2f8fe](https://github.com/elixir-tools/next-ls/commit/0a2f8fe7666f741d9063be4e7d0522f4e7f11fd1))
* clamp diagnostic line number to 0 ([#116](https://github.com/elixir-tools/next-ls/issues/116)) ([e2194c5](https://github.com/elixir-tools/next-ls/commit/e2194c5d78eb042b537f4c0df6f74d9cfa2d6017))
* clear out references when saving a file ([#134](https://github.com/elixir-tools/next-ls/issues/134)) ([d0e0340](https://github.com/elixir-tools/next-ls/commit/d0e0340f0ccd88ec0ecd20f005748ef7f11cb586))
* coalesce nil start line to 1 ([#182](https://github.com/elixir-tools/next-ls/issues/182)) ([9864fc4](https://github.com/elixir-tools/next-ls/commit/9864fc4567c674e1570102c250c74a5f437e8f0a)), closes [#160](https://github.com/elixir-tools/next-ls/issues/160)
* correctly format files ([#128](https://github.com/elixir-tools/next-ls/issues/128)) ([3e20c00](https://github.com/elixir-tools/next-ls/commit/3e20c003daea1bdf551f0c87370f0e8a0319ae51))
* correctly set compiler diagnostic columns ([d2bbae8](https://github.com/elixir-tools/next-ls/commit/d2bbae829fafe78d71727235acd6b715397a6cf3))
* create the symbol table in the workspace path ([#125](https://github.com/elixir-tools/next-ls/issues/125)) ([1103d01](https://github.com/elixir-tools/next-ls/commit/1103d0105faeb60c9b8d90a95aa49f795c44d505))
* **docs:** typo in mix.exs ([#70](https://github.com/elixir-tools/next-ls/issues/70)) ([db11c1c](https://github.com/elixir-tools/next-ls/commit/db11c1c0449e2513c49576203dc4d2f6ffdfbdf8))
* don't timeout when calling functions on the runtime ([#196](https://github.com/elixir-tools/next-ls/issues/196)) ([555b191](https://github.com/elixir-tools/next-ls/commit/555b19162c502838e82f6ecff42383c0da076801))
* **elixir:** compiler diagnostics have iodata ([#18](https://github.com/elixir-tools/next-ls/issues/18)) ([f28af33](https://github.com/elixir-tools/next-ls/commit/f28af33a31f19da2088d0c3f52beb04f801bac39)), closes [#15](https://github.com/elixir-tools/next-ls/issues/15)
* **elixir:** format inside runtime ([#13](https://github.com/elixir-tools/next-ls/issues/13)) ([99965f1](https://github.com/elixir-tools/next-ls/commit/99965f1b17250ead7524143b13246f08553b940a))
* ensure epmd is started ([#221](https://github.com/elixir-tools/next-ls/issues/221)) ([2edfe59](https://github.com/elixir-tools/next-ls/commit/2edfe5904b5505a7276557f7b75dda2fc5c0f96f))
* filter out hidden functions from workspace symbols ([#66](https://github.com/elixir-tools/next-ls/issues/66)) ([202a906](https://github.com/elixir-tools/next-ls/commit/202a90699d8e1bcb3c0a25c36fb1785923c80d31)), closes [#39](https://github.com/elixir-tools/next-ls/issues/39)
* gracefully handle injected attributes ([#235](https://github.com/elixir-tools/next-ls/issues/235)) ([5ff9830](https://github.com/elixir-tools/next-ls/commit/5ff9830629453beb4b5e88ebaa1df2cf7b073185)), closes [#234](https://github.com/elixir-tools/next-ls/issues/234)
* gracefully handle uninitialized runtime ([#19](https://github.com/elixir-tools/next-ls/issues/19)) ([9975501](https://github.com/elixir-tools/next-ls/commit/997550161e818941fbddd56a587d1d5d93fbfd92))
* guard from missing function doc ([#226](https://github.com/elixir-tools/next-ls/issues/226)) ([72c4706](https://github.com/elixir-tools/next-ls/commit/72c4706f097a118f098a4773c126a225eba11ade))
* handle aliases injected by macros ([4ad4855](https://github.com/elixir-tools/next-ls/commit/4ad48559d31496253093ad57eaa60b8b21105de7))
* handle formatting files with syntax errors ([#26](https://github.com/elixir-tools/next-ls/issues/26)) ([b124b16](https://github.com/elixir-tools/next-ls/commit/b124b16aedfd234ac365dd3446635721cf4ad38e))
* improve error handling for compiler diagnostics ([#165](https://github.com/elixir-tools/next-ls/issues/165)) ([e77cebd](https://github.com/elixir-tools/next-ls/commit/e77cebd5f5198ae98e8ae046eefcc04094c68e41))
* log failed db query with arguments ([#166](https://github.com/elixir-tools/next-ls/issues/166)) ([c0d813d](https://github.com/elixir-tools/next-ls/commit/c0d813d37a1859fc43a7b7ad89ae1149acc62332))
* log next-ls version on start ([c10ab90](https://github.com/elixir-tools/next-ls/commit/c10ab9047449866bf2e446a9891fb46e112efcee))
* make priv/cmd executable before release ([c1469ae](https://github.com/elixir-tools/next-ls/commit/c1469ae591b9c7f64d3633430b8885b2db1c36c0))
* nix build ([#247](https://github.com/elixir-tools/next-ls/issues/247)) ([17c41db](https://github.com/elixir-tools/next-ls/commit/17c41dbc33a395f654194bdc956b9eabbddb12f4))
* only fetch most recent reference for that position ([00fbfbf](https://github.com/elixir-tools/next-ls/commit/00fbfbfe9e553cec04f129024b1256030cd6651f))
* only purge references when actually recompiling ([#187](https://github.com/elixir-tools/next-ls/issues/187)) ([481acc4](https://github.com/elixir-tools/next-ls/commit/481acc4203e47ffaa30e9b3127a82953ffe2c121)), closes [#154](https://github.com/elixir-tools/next-ls/issues/154)
* prefix logs with [NextLS] ([#12](https://github.com/elixir-tools/next-ls/issues/12)) ([36d8603](https://github.com/elixir-tools/next-ls/commit/36d86035dbcebbdee288e75221493547fb6afe04))
* properly close the symbol table on shutdown ([#65](https://github.com/elixir-tools/next-ls/issues/65)) ([837d02f](https://github.com/elixir-tools/next-ls/commit/837d02fcfdb3de4e4b440e5f184c04edba69d11f))
* properly decode requests with `none` parameters ([#106](https://github.com/elixir-tools/next-ls/issues/106)) ([b8ccf12](https://github.com/elixir-tools/next-ls/commit/b8ccf12aba542b3494cc5fc3010c678617c29a84))
* reap symbols when file is deleted ([#127](https://github.com/elixir-tools/next-ls/issues/127)) ([9517615](https://github.com/elixir-tools/next-ls/commit/95176151bc368184b85355f3848f234859de8911))
* redirect log messages to stderr ([#208](https://github.com/elixir-tools/next-ls/issues/208)) ([c3ab60f](https://github.com/elixir-tools/next-ls/commit/c3ab60ffb875695f869ced656ffe3f087cd5e8c9))
* **references:** clamp line and column numbers ([55ead79](https://github.com/elixir-tools/next-ls/commit/55ead79adbfdf62c8e59b8163beeb5c324c56126)), closes [#141](https://github.com/elixir-tools/next-ls/issues/141)
* **references:** ignore references to elixir source code ([6ff4c17](https://github.com/elixir-tools/next-ls/commit/6ff4c17d631ad37be4903297873ca6ee7a70a38d))
* remove unused variables from monkey patch ([fec818e](https://github.com/elixir-tools/next-ls/commit/fec818e5dee67cfa5f2cda3de7c05c4325e9cf84))
* remove version from targets ([#148](https://github.com/elixir-tools/next-ls/issues/148)) ([06704bc](https://github.com/elixir-tools/next-ls/commit/06704bcedd34cf7627ea78ab3a9f6a16449270a0))
* revert 0.7 ([#142](https://github.com/elixir-tools/next-ls/issues/142)) ([5a1713c](https://github.com/elixir-tools/next-ls/commit/5a1713c5820c0770464da0e7a75f193280fd55cb))
* run compiler in task ([#95](https://github.com/elixir-tools/next-ls/issues/95)) ([96bfc76](https://github.com/elixir-tools/next-ls/commit/96bfc76250a568ea313693586adffd2de5249692)), closes [#60](https://github.com/elixir-tools/next-ls/issues/60)
* set db timeouts to :infinity ([#168](https://github.com/elixir-tools/next-ls/issues/168)) ([ebe2ea3](https://github.com/elixir-tools/next-ls/commit/ebe2ea3d463266f0963a689978e7d72cd3fa2ff4))
* start dedicated process for runtime logging ([#94](https://github.com/elixir-tools/next-ls/issues/94)) ([32f8313](https://github.com/elixir-tools/next-ls/commit/32f8313dfd0d279214b999a746aeb10cf1e8dbf3)), closes [#92](https://github.com/elixir-tools/next-ls/issues/92)
* start runtime under a supervisor ([#124](https://github.com/elixir-tools/next-ls/issues/124)) ([df331dc](https://github.com/elixir-tools/next-ls/commit/df331dcd3ceca943a513529481bc0acf75cd4acb))
* swap out dets for sqlite3 ([#131](https://github.com/elixir-tools/next-ls/issues/131)) ([422df17](https://github.com/elixir-tools/next-ls/commit/422df17c7512a82392cc1920976d224fb5a7bcb3))
* typo ([2623172](https://github.com/elixir-tools/next-ls/commit/26231720c5d542ce3c21662617d3f1f6d23c7e38))
* typos ([f80b57b](https://github.com/elixir-tools/next-ls/commit/f80b57b35a354a416eca6504396417a177ffe6f2))
* update burrito ([#200](https://github.com/elixir-tools/next-ls/issues/200)) ([11a992b](https://github.com/elixir-tools/next-ls/commit/11a992ba48bde3fb2776df49ad37f498bfa87a1b))
* update db schema version ([#223](https://github.com/elixir-tools/next-ls/issues/223)) ([bd0ae63](https://github.com/elixir-tools/next-ls/commit/bd0ae631c13e54d7f720b6e28664028cf9f3f785))
* use correct directory for symbol table ([#34](https://github.com/elixir-tools/next-ls/issues/34)) ([3e83987](https://github.com/elixir-tools/next-ls/commit/3e83987900bbd1d951bc1c7b7af80d566744a022))
* use different sqlite package ([#156](https://github.com/elixir-tools/next-ls/issues/156)) ([721c9cd](https://github.com/elixir-tools/next-ls/commit/721c9cd29a402b35852bf454dec0d9ed45d3869a))
* use first reference with go to definition ([#137](https://github.com/elixir-tools/next-ls/issues/137)) ([e3ed704](https://github.com/elixir-tools/next-ls/commit/e3ed704525ab78f3feba0d5d38ce832c952e2c77))
* use loadpaths instead of run ([#108](https://github.com/elixir-tools/next-ls/issues/108)) ([97a8fe5](https://github.com/elixir-tools/next-ls/commit/97a8fe5377a4382513a9e60e2ed4da6ac847834a))
* use registry for runtime messaging ([#121](https://github.com/elixir-tools/next-ls/issues/121)) ([639493c](https://github.com/elixir-tools/next-ls/commit/639493c173f2b8f3cdc21ea81fb48290688d40b7))
* version in mix.exs ([c6459ec](https://github.com/elixir-tools/next-ls/commit/c6459ec9f4e2a347f68868cb55544cfdbbde5048))

## [0.12.7](https://github.com/elixir-tools/next-ls/compare/v0.12.6...v0.12.7) (2023-09-30)


### Bug Fixes

* cancel previous compile requests ([#242](https://github.com/elixir-tools/next-ls/issues/242)) ([0a2f8fe](https://github.com/elixir-tools/next-ls/commit/0a2f8fe7666f741d9063be4e7d0522f4e7f11fd1))
* nix build ([#247](https://github.com/elixir-tools/next-ls/issues/247)) ([17c41db](https://github.com/elixir-tools/next-ls/commit/17c41dbc33a395f654194bdc956b9eabbddb12f4))

## [0.12.6](https://github.com/elixir-tools/next-ls/compare/v0.12.5...v0.12.6) (2023-09-21)


### Bug Fixes

* gracefully handle injected attributes ([#235](https://github.com/elixir-tools/next-ls/issues/235)) ([5ff9830](https://github.com/elixir-tools/next-ls/commit/5ff9830629453beb4b5e88ebaa1df2cf7b073185)), closes [#234](https://github.com/elixir-tools/next-ls/issues/234)

## [0.12.5](https://github.com/elixir-tools/next-ls/compare/v0.12.4...v0.12.5) (2023-09-18)


### Bug Fixes

* handle aliases injected by macros ([4ad4855](https://github.com/elixir-tools/next-ls/commit/4ad48559d31496253093ad57eaa60b8b21105de7))

## [0.12.4](https://github.com/elixir-tools/next-ls/compare/v0.12.3...v0.12.4) (2023-09-18)


### Bug Fixes

* guard from missing function doc ([#226](https://github.com/elixir-tools/next-ls/issues/226)) ([72c4706](https://github.com/elixir-tools/next-ls/commit/72c4706f097a118f098a4773c126a225eba11ade))

## [0.12.3](https://github.com/elixir-tools/next-ls/compare/v0.12.2...v0.12.3) (2023-09-18)


### Bug Fixes

* make priv/cmd executable before release ([c1469ae](https://github.com/elixir-tools/next-ls/commit/c1469ae591b9c7f64d3633430b8885b2db1c36c0))

## [0.12.2](https://github.com/elixir-tools/next-ls/compare/v0.12.1...v0.12.2) (2023-09-18)


### Bug Fixes

* update db schema version ([#223](https://github.com/elixir-tools/next-ls/issues/223)) ([bd0ae63](https://github.com/elixir-tools/next-ls/commit/bd0ae631c13e54d7f720b6e28664028cf9f3f785))

## [0.12.1](https://github.com/elixir-tools/next-ls/compare/v0.12.0...v0.12.1) (2023-09-18)


### Bug Fixes

* ensure epmd is started ([#221](https://github.com/elixir-tools/next-ls/issues/221)) ([2edfe59](https://github.com/elixir-tools/next-ls/commit/2edfe5904b5505a7276557f7b75dda2fc5c0f96f))
* remove unused variables from monkey patch ([fec818e](https://github.com/elixir-tools/next-ls/commit/fec818e5dee67cfa5f2cda3de7c05c4325e9cf84))

## [0.12.0](https://github.com/elixir-tools/next-ls/compare/v0.11.0...v0.12.0) (2023-09-18)


### Features

* **definition,references:** go to definition when aliasing modules ([#152](https://github.com/elixir-tools/next-ls/issues/152)) ([627bb94](https://github.com/elixir-tools/next-ls/commit/627bb9452e2516cd483cb25e690f189dbd604e32))
* **definition,references:** module attributes ([#215](https://github.com/elixir-tools/next-ls/issues/215)) ([b14a09d](https://github.com/elixir-tools/next-ls/commit/b14a09d558b0b6e9c40456af7298a7578a1ca6eb))
* hover ([#220](https://github.com/elixir-tools/next-ls/issues/220)) ([c5a68df](https://github.com/elixir-tools/next-ls/commit/c5a68dfef268ea64bf499954aede4caeb052a515))

## [0.11.0](https://github.com/elixir-tools/next-ls/compare/v0.10.4...v0.11.0) (2023-09-12)


### Features

* ranked fuzzy match search of workspace symbols ([#212](https://github.com/elixir-tools/next-ls/issues/212)) ([9395744](https://github.com/elixir-tools/next-ls/commit/9395744069537ec1b90dfd652c6b388781bb6795))

## [0.10.4](https://github.com/elixir-tools/next-ls/compare/v0.10.3...v0.10.4) (2023-08-28)


### Bug Fixes

* redirect log messages to stderr ([#208](https://github.com/elixir-tools/next-ls/issues/208)) ([c3ab60f](https://github.com/elixir-tools/next-ls/commit/c3ab60ffb875695f869ced656ffe3f087cd5e8c9))

## [0.10.3](https://github.com/elixir-tools/next-ls/compare/v0.10.2...v0.10.3) (2023-08-24)


### Bug Fixes

* update burrito ([#200](https://github.com/elixir-tools/next-ls/issues/200)) ([11a992b](https://github.com/elixir-tools/next-ls/commit/11a992ba48bde3fb2776df49ad37f498bfa87a1b))

## [0.10.2](https://github.com/elixir-tools/next-ls/compare/v0.10.1...v0.10.2) (2023-08-22)


### Bug Fixes

* typos ([f80b57b](https://github.com/elixir-tools/next-ls/commit/f80b57b35a354a416eca6504396417a177ffe6f2))

## [0.10.1](https://github.com/elixir-tools/next-ls/compare/v0.10.0...v0.10.1) (2023-08-21)


### Bug Fixes

* don't timeout when calling functions on the runtime ([#196](https://github.com/elixir-tools/next-ls/issues/196)) ([555b191](https://github.com/elixir-tools/next-ls/commit/555b19162c502838e82f6ecff42383c0da076801))

## [0.10.0](https://github.com/elixir-tools/next-ls/compare/v0.9.1...v0.10.0) (2023-08-20)


### Features

* auto update ([#192](https://github.com/elixir-tools/next-ls/issues/192)) ([d2db88a](https://github.com/elixir-tools/next-ls/commit/d2db88a9d975c13d2b5284b47da15176d60e5878)), closes [#170](https://github.com/elixir-tools/next-ls/issues/170)
* **cli:** --help flag ([#194](https://github.com/elixir-tools/next-ls/issues/194)) ([3cdfa18](https://github.com/elixir-tools/next-ls/commit/3cdfa18d841092adedaab93b5226ab1049685dcd))
* **cli:** --version flag ([#193](https://github.com/elixir-tools/next-ls/issues/193)) ([8455ba7](https://github.com/elixir-tools/next-ls/commit/8455ba75dd91299501b5f1e9962fa3a654802177))
* **definition:** go to dependency ([#171](https://github.com/elixir-tools/next-ls/issues/171)) ([ddd28de](https://github.com/elixir-tools/next-ls/commit/ddd28deeb2b9a3a1ff0bede27a512ddd9c51165e))
* **extension:** credo ([#163](https://github.com/elixir-tools/next-ls/issues/163)) ([70d52dc](https://github.com/elixir-tools/next-ls/commit/70d52dcc16a2532b181da60723f9d0d18384505b))
* progress messages for workspace indexing ([#179](https://github.com/elixir-tools/next-ls/issues/179)) ([09883bc](https://github.com/elixir-tools/next-ls/commit/09883bc0529076ff492cfd8289128cd340255e13))


### Bug Fixes

* coalesce nil start line to 1 ([#182](https://github.com/elixir-tools/next-ls/issues/182)) ([9864fc4](https://github.com/elixir-tools/next-ls/commit/9864fc4567c674e1570102c250c74a5f437e8f0a)), closes [#160](https://github.com/elixir-tools/next-ls/issues/160)
* improve error handling for compiler diagnostics ([#165](https://github.com/elixir-tools/next-ls/issues/165)) ([e77cebd](https://github.com/elixir-tools/next-ls/commit/e77cebd5f5198ae98e8ae046eefcc04094c68e41))
* log failed db query with arguments ([#166](https://github.com/elixir-tools/next-ls/issues/166)) ([c0d813d](https://github.com/elixir-tools/next-ls/commit/c0d813d37a1859fc43a7b7ad89ae1149acc62332))
* only purge references when actually recompiling ([#187](https://github.com/elixir-tools/next-ls/issues/187)) ([481acc4](https://github.com/elixir-tools/next-ls/commit/481acc4203e47ffaa30e9b3127a82953ffe2c121)), closes [#154](https://github.com/elixir-tools/next-ls/issues/154)
* set db timeouts to :infinity ([#168](https://github.com/elixir-tools/next-ls/issues/168)) ([ebe2ea3](https://github.com/elixir-tools/next-ls/commit/ebe2ea3d463266f0963a689978e7d72cd3fa2ff4))

## [0.9.1](https://github.com/elixir-tools/next-ls/compare/v0.9.0...v0.9.1) (2023-08-09)


### Bug Fixes

* use different sqlite package ([#156](https://github.com/elixir-tools/next-ls/issues/156)) ([721c9cd](https://github.com/elixir-tools/next-ls/commit/721c9cd29a402b35852bf454dec0d9ed45d3869a))

## [0.9.0](https://github.com/elixir-tools/next-ls/compare/v0.8.0...v0.9.0) (2023-08-09)


### Features

* find references, reverts "fix: revert 0.7 ([#142](https://github.com/elixir-tools/next-ls/issues/142))" ([#150](https://github.com/elixir-tools/next-ls/issues/150)) ([1b8f72b](https://github.com/elixir-tools/next-ls/commit/1b8f72b8a1f6efcfa130643e9006d27319bbd738))


### Bug Fixes

* remove version from targets ([#148](https://github.com/elixir-tools/next-ls/issues/148)) ([06704bc](https://github.com/elixir-tools/next-ls/commit/06704bcedd34cf7627ea78ab3a9f6a16449270a0))

## [0.8.0](https://github.com/elixir-tools/next-ls/compare/v0.7.1...v0.8.0) (2023-08-09)


### Features

* burrito (aka binary executable) ([#144](https://github.com/elixir-tools/next-ls/issues/144)) ([094fd74](https://github.com/elixir-tools/next-ls/commit/094fd74744dc1c995473bbb8a36c900e8f7b0540))


### Bug Fixes

* version in mix.exs ([c6459ec](https://github.com/elixir-tools/next-ls/commit/c6459ec9f4e2a347f68868cb55544cfdbbde5048))

## [0.7.1](https://github.com/elixir-tools/next-ls/compare/v0.7.0...v0.7.1) (2023-08-08)


### Bug Fixes

* revert 0.7 ([#142](https://github.com/elixir-tools/next-ls/issues/142)) ([5a1713c](https://github.com/elixir-tools/next-ls/commit/5a1713c5820c0770464da0e7a75f193280fd55cb))

## [0.7.0](https://github.com/elixir-tools/next-ls/compare/v0.6.5...v0.7.0) (2023-08-08)


### Features

* find references ([#139](https://github.com/elixir-tools/next-ls/issues/139)) ([5a3b530](https://github.com/elixir-tools/next-ls/commit/5a3b530a7d283014f8fadcaf0feb0765dac68a1c)), closes [#43](https://github.com/elixir-tools/next-ls/issues/43)


### Bug Fixes

* **references:** clamp line and column numbers ([55ead79](https://github.com/elixir-tools/next-ls/commit/55ead79adbfdf62c8e59b8163beeb5c324c56126)), closes [#141](https://github.com/elixir-tools/next-ls/issues/141)
* **references:** ignore references to elixir source code ([6ff4c17](https://github.com/elixir-tools/next-ls/commit/6ff4c17d631ad37be4903297873ca6ee7a70a38d))

## [0.6.5](https://github.com/elixir-tools/next-ls/compare/v0.6.4...v0.6.5) (2023-08-01)


### Bug Fixes

* use first reference with go to definition ([#137](https://github.com/elixir-tools/next-ls/issues/137)) ([e3ed704](https://github.com/elixir-tools/next-ls/commit/e3ed704525ab78f3feba0d5d38ce832c952e2c77))

## [0.6.4](https://github.com/elixir-tools/next-ls/compare/v0.6.3...v0.6.4) (2023-07-31)


### Bug Fixes

* clear out references when saving a file ([#134](https://github.com/elixir-tools/next-ls/issues/134)) ([d0e0340](https://github.com/elixir-tools/next-ls/commit/d0e0340f0ccd88ec0ecd20f005748ef7f11cb586))

## [0.6.3](https://github.com/elixir-tools/next-ls/compare/v0.6.2...v0.6.3) (2023-07-31)


### Bug Fixes

* only fetch most recent reference for that position ([00fbfbf](https://github.com/elixir-tools/next-ls/commit/00fbfbfe9e553cec04f129024b1256030cd6651f))

## [0.6.2](https://github.com/elixir-tools/next-ls/compare/v0.6.1...v0.6.2) (2023-07-30)


### Bug Fixes

* swap out dets for sqlite3 ([#131](https://github.com/elixir-tools/next-ls/issues/131)) ([422df17](https://github.com/elixir-tools/next-ls/commit/422df17c7512a82392cc1920976d224fb5a7bcb3))

## [0.6.1](https://github.com/elixir-tools/next-ls/compare/v0.6.0...v0.6.1) (2023-07-28)


### Bug Fixes

* correctly format files ([#128](https://github.com/elixir-tools/next-ls/issues/128)) ([3e20c00](https://github.com/elixir-tools/next-ls/commit/3e20c003daea1bdf551f0c87370f0e8a0319ae51))
* reap symbols when file is deleted ([#127](https://github.com/elixir-tools/next-ls/issues/127)) ([9517615](https://github.com/elixir-tools/next-ls/commit/95176151bc368184b85355f3848f234859de8911))

## [0.6.0](https://github.com/elixir-tools/next-ls/compare/v0.5.5...v0.6.0) (2023-07-24)


### Features

* adding/removing workspace folders ([#126](https://github.com/elixir-tools/next-ls/issues/126)) ([d26e29c](https://github.com/elixir-tools/next-ls/commit/d26e29c733ed040c7b7bc941956aa1ffef35726b))
* workspace folders on startup ([#117](https://github.com/elixir-tools/next-ls/issues/117)) ([6b5ffaf](https://github.com/elixir-tools/next-ls/commit/6b5ffafda9c754f59548760384387dbe66cf8e3b))


### Bug Fixes

* clamp diagnostic line number to 0 ([#116](https://github.com/elixir-tools/next-ls/issues/116)) ([e2194c5](https://github.com/elixir-tools/next-ls/commit/e2194c5d78eb042b537f4c0df6f74d9cfa2d6017))
* create the symbol table in the workspace path ([#125](https://github.com/elixir-tools/next-ls/issues/125)) ([1103d01](https://github.com/elixir-tools/next-ls/commit/1103d0105faeb60c9b8d90a95aa49f795c44d505))
* start runtime under a supervisor ([#124](https://github.com/elixir-tools/next-ls/issues/124)) ([df331dc](https://github.com/elixir-tools/next-ls/commit/df331dcd3ceca943a513529481bc0acf75cd4acb))
* use registry for runtime messaging ([#121](https://github.com/elixir-tools/next-ls/issues/121)) ([639493c](https://github.com/elixir-tools/next-ls/commit/639493c173f2b8f3cdc21ea81fb48290688d40b7))

## [0.5.5](https://github.com/elixir-tools/next-ls/compare/v0.5.4...v0.5.5) (2023-07-20)


### Bug Fixes

* add .gitignore file to .elixir-tools directory ([#113](https://github.com/elixir-tools/next-ls/issues/113)) ([24d9915](https://github.com/elixir-tools/next-ls/commit/24d99158cd616b3d9426e2d21ecfcfcb9d90ec8b))

## [0.5.4](https://github.com/elixir-tools/next-ls/compare/v0.5.3...v0.5.4) (2023-07-13)


### Bug Fixes

* typo ([2623172](https://github.com/elixir-tools/next-ls/commit/26231720c5d542ce3c21662617d3f1f6d23c7e38))

## [0.5.3](https://github.com/elixir-tools/next-ls/compare/v0.5.2...v0.5.3) (2023-07-12)


### Bug Fixes

* add `:crypto` to extra_applications ([480aa01](https://github.com/elixir-tools/next-ls/commit/480aa01d9498c1370dce5d2ed3a3a1c14d7f2a63)), closes [#100](https://github.com/elixir-tools/next-ls/issues/100)
* better error message when passing invalid flags ([#107](https://github.com/elixir-tools/next-ls/issues/107)) ([5e2f55f](https://github.com/elixir-tools/next-ls/commit/5e2f55f56c7278c1bb37a9e96056190b92fa2bfc)), closes [#103](https://github.com/elixir-tools/next-ls/issues/103)
* properly decode requests with `none` parameters ([#106](https://github.com/elixir-tools/next-ls/issues/106)) ([b8ccf12](https://github.com/elixir-tools/next-ls/commit/b8ccf12aba542b3494cc5fc3010c678617c29a84))
* use loadpaths instead of run ([#108](https://github.com/elixir-tools/next-ls/issues/108)) ([97a8fe5](https://github.com/elixir-tools/next-ls/commit/97a8fe5377a4382513a9e60e2ed4da6ac847834a))

## [0.5.2](https://github.com/elixir-tools/next-ls/compare/v0.5.1...v0.5.2) (2023-07-07)


### Bug Fixes

* add LSP var ([#98](https://github.com/elixir-tools/next-ls/issues/98)) ([d8554a8](https://github.com/elixir-tools/next-ls/commit/d8554a864f4f538113d20bb5692968fdf7a39884))

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
