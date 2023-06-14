[
  locals_without_parens: [
    assert_result: 2,
    assert_notification: 2,
    assert_result: 3,
    assert_notification: 3,
    notify: 2,
    request: 2
  ],
  line_length: 120,
  import_deps: [:gen_lsp],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,}/**/*.{ex,exs}",
    "test/next_ls_test.exs",
    "test/test_helper.exs",
    "test/next_ls/**/*.{ex,exs}",
    "priv/**/*.ex"
  ]
]
