defmodule NextLS.DocsHelpersTest do
  use ExUnit.Case, async: true

  alias NextLS.DocsHelpers

  describe "converts erlang html format to markdown" do
    test "some divs and p and code" do
      html = [
        {:p, [],
         [
           "Suspends the process calling this function for ",
           {:code, [], ["Time"]},
           " milliseconds and then returns ",
           {:code, [], ["ok"]},
           ", or suspends the process forever if ",
           {:code, [], ["Time"]},
           " is the atom ",
           {:code, [], ["infinity"]},
           ". Naturally, this function does ",
           {:em, [], ["not"]},
           " return immediately."
         ]},
        {:div, [class: "note"],
         [
           {:p, [],
            [
              "Before OTP 25, ",
              {:code, [], ["timer:sleep/1"]},
              " did not accept integer timeout values greater than ",
              {:code, [], ["16#ffffffff"]},
              ", that is, ",
              {:code, [], ["2^32-1"]},
              ". Since OTP 25, arbitrarily high integer values are accepted."
            ]}
         ]}
      ]

      actual = DocsHelpers.to_markdown("application/erlang+html", html)

      assert actual ==
               String.trim("""
               Suspends the process calling this function for `Time` milliseconds and then returns `ok`, or suspends the process forever if `Time` is the atom `infinity`. Naturally, this function does _not_ return immediately.

               > Before OTP 25, `timer:sleep/1` did not accept integer timeout values greater than `16#ffffffff`, that is, `2^32-1`. Since OTP 25, arbitrarily high integer values are accepted.
               """)
    end

    test "some p and a and code" do
      html = [
        {:p, [],
         [
           "The same as ",
           {:a,
            [
              href: "erts:erlang#atom_to_binary/2",
              rel: "https://erlang.org/doc/link/seemfa"
            ], [{:code, [], ["atom_to_binary"]}, " "]},
           {:code, [], ["(Atom, utf8)"]},
           "."
         ]}
      ]

      actual = DocsHelpers.to_markdown("application/erlang+html", html)

      assert actual ==
               String.trim("""
               The same as [`atom_to_binary`](erts:erlang#atom_to_binary/2) `(Atom, utf8)`.
               """)
    end

    test "some code" do
      html = [
        {:p, [],
         [
           "Extracts the part of the binary described by ",
           {:code, [], ["PosLen"]},
           "."
         ]},
        {:p, [], ["Negative length can be used to extract bytes at the end of a binary, for example:"]},
        {:pre, [],
         [
           {:code, [],
            ["1> Bin = <<1,2,3,4,5,6,7,8,9,10>>.\n2> binary_part(Bin,{byte_size(Bin), -5}).\n<<6,7,8,9,10>>"]}
         ]},
        {:p, [],
         [
           "Failure: ",
           {:code, [], ["badarg"]},
           " if ",
           {:code, [], ["PosLen"]},
           " in any way references outside the binary."
         ]},
        {:p, [], [{:code, [], ["Start"]}, " is zero-based, that is:"]},
        {:pre, [], [{:code, [], ["1> Bin = <<1,2,3>>\n2> binary_part(Bin,{0,2}).\n<<1,2>>"]}]},
        {:p, [],
         [
           "For details about the ",
           {:code, [], ["PosLen"]},
           " semantics, see ",
           {:a, [href: "stdlib:binary", rel: "https://erlang.org/doc/link/seeerl"], [{:code, [], ["binary(3)"]}]},
           "."
         ]},
        {:p, [], ["Allowed in guard tests."]}
      ]

      actual = DocsHelpers.to_markdown("application/erlang+html", html)

      assert actual ==
               String.trim("""
               Extracts the part of the binary described by `PosLen`.

               Negative length can be used to extract bytes at the end of a binary, for example:

               ```erlang
               1> Bin = <<1,2,3,4,5,6,7,8,9,10>>.
               2> binary_part(Bin,{byte_size(Bin), -5}).
               <<6,7,8,9,10>>
               ```

               Failure: `badarg` if `PosLen` in any way references outside the binary.

               `Start` is zero-based, that is:

               ```erlang
               1> Bin = <<1,2,3>>
               2> binary_part(Bin,{0,2}).
               <<1,2>>
               ```

               For details about the `PosLen` semantics, see [`binary(3)`](stdlib:binary).

               Allowed in guard tests.
               """)
    end

    test "ul and li" do
      html = [
        {:ul, [],
         [
           {:li, [],
            [
              {:p, [],
               [
                 "Find an arbitrary ",
                 {:a,
                  [
                    href: "stdlib:digraph#simple_path",
                    rel: "https://erlang.org/doc/link/seeerl"
                  ], ["simple path"]},
                 " v[1], v[2], ..., v[k] from ",
                 {:code, [], ["V1"]},
                 " to ",
                 {:code, [], ["V2"]},
                 " in ",
                 {:code, [], ["G"]},
                 "."
               ]}
            ]},
           {:li, [],
            [
              {:p, [],
               [
                 "Remove all edges of ",
                 {:code, [], ["G"]},
                 " ",
                 {:a,
                  [
                    href: "stdlib:digraph#emanate",
                    rel: "https://erlang.org/doc/link/seeerl"
                  ], ["emanating"]},
                 " from v[i] and ",
                 {:a,
                  [
                    href: "stdlib:digraph#incident",
                    rel: "https://erlang.org/doc/link/seeerl"
                  ], ["incident"]},
                 " to v[i+1] for 1 <= i < k (including multiple edges)."
               ]}
            ]},
           {:li, [],
            [
              {:p, [],
               [
                 "Repeat until there is no path between ",
                 {:code, [], ["V1"]},
                 " and ",
                 {:code, [], ["V2"]},
                 "."
               ]}
            ]}
         ]}
      ]

      actual = DocsHelpers.to_markdown("application/erlang+html", html)

      assert String.trim(actual) ==
               String.trim("""
               * Find an arbitrary [simple path](stdlib:digraph#simple_path) v[1], v[2], ..., v[k] from `V1` to `V2` in `G`.
               * Remove all edges of `G` [emanating](stdlib:digraph#emanate) from v[i] and [incident](stdlib:digraph#incident) to v[i+1] for 1 <= i < k (including multiple edges).
               * Repeat until there is no path between `V1` and `V2`.
               """)
    end

    test "dl, dt, and dd" do
      html = [
        {:dl, [],
         [
           {:dt, [], [{:code, [], ["root"]}]},
           {:dd, [],
            [
              {:p, [], ["The installation directory of Erlang/OTP, ", {:code, [], ["$ROOT"]}, ":"]},
              {:pre, [],
               [
                 {:code, [],
                  ["2> init:get_argument(root).\n{ok,[[\"/usr/local/otp/releases/otp_beam_solaris8_r10b_patched\"]]}"]}
               ]}
            ]},
           {:dt, [], [{:code, [], ["progname"]}]},
           {:dd, [],
            [
              {:p, [], ["The name of the program which started Erlang:"]},
              {:pre, [], [{:code, [], ["3> init:get_argument(progname).\n{ok,[[\"erl\"]]}"]}]}
            ]},
           {:dt, [], [{:a, [id: "home"], []}, {:code, [], ["home"]}]},
           {:dd, [],
            [
              {:p, [], ["The home directory (on Unix, the value of $HOME):"]},
              {:pre, [], [{:code, [], ["4> init:get_argument(home).\n{ok,[[\"/home/harry\"]]}"]}]}
            ]}
         ]},
        {:p, [], ["Returns ", {:code, [], ["error"]}, " if no value is associated with ", {:code, [], ["Flag"]}, "."]}
      ]

      actual = DocsHelpers.to_markdown("application/erlang+html", html)

      assert String.trim(actual) ==
               String.trim("""
               * `root`
               The installation directory of Erlang/OTP, `$ROOT`:

               ```erlang
               2> init:get_argument(root).
               {ok,[[\"/usr/local/otp/releases/otp_beam_solaris8_r10b_patched\"]]}
               ```
               * `progname`
               The name of the program which started Erlang:

               ```erlang
               3> init:get_argument(progname).
               {ok,[[\"erl\"]]}
               ```
               * []()`home`
               The home directory (on Unix, the value of $HOME):

               ```erlang
               4> init:get_argument(home).
               {ok,[[\"/home/harry\"]]}
               ```

               Returns `error` if no value is associated with `Flag`.
               """)
    end
  end
end
