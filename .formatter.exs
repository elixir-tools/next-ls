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
  plugins: [Styler],
  inputs: [
    ".formatter.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "priv/**/*.ex"
  ]
]
