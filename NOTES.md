## Questions

* Do we need to pull compilation or `mix test` arguments from somewhere?
* Do we need to handle files that aren't in the context of a mix project?
  * Probably not?
* Should we run parallel runtimes, one for test and one for dev? Or just compile with mix_env = :test?
  * Running two compiles at once might introduce considerable overhead for some projects

## TODO

[x] POC to get diagnostics from a test file
[ ] Work out what to do with test warnings
[ ] Figure out if we should warn on `*_test.ex` test files
[ ] Iron out dev vs. test compilation
[ ] Get test coverage
