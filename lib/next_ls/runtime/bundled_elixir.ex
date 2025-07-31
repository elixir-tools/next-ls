defmodule NextLS.Runtime.BundledElixir do
  @moduledoc """
  Module to install the bundled Elixir.

  The `@version` attribute corresponds to the last digit in the file name of the zip archive, they need to be incremented in lockstep.
  """
  @version 3
  @base "~/.cache/elixir-tools/nextls"
  @dir "elixir/1-17-#{@version}"

  def binpath(base \\ @base) do
    Path.join([base, @dir, "bin"])
  end

  def mixpath(base \\ @base) do
    Path.join([binpath(base), "mix"])
  end

  def path(base) do
    Path.join([base, @dir])
  end

  def mix_home(base) do
    Path.join(path(base), ".mix")
  end

  def mix_archives(base) do
    Path.join(mix_home(base), "archives")
  end

  def install(base, logger) do
    mixhome = mix_home(base)
    mixarchives = mix_archives(base)
    File.mkdir_p!(mixhome)
    binpath = binpath(base)

    unless File.exists?(binpath) do
      extract_path = path(base)
      File.mkdir_p!(base)

      priv_dir = :code.priv_dir(:next_ls)
      bundled_elixir_path = ~c"#{Path.join(priv_dir, "precompiled-1-17-#{@version}.zip")}"

      :zip.unzip(bundled_elixir_path, cwd: ~c"#{extract_path}")

      for bin <- Path.wildcard(Path.join(binpath, "*")) do
        File.chmod(bin, 0o755)
      end
    end

    new_path = "#{binpath}:#{System.get_env("PATH")}"
    mixbin = mixpath(base)
    env = [{"PATH", new_path}, {"MIX_HOME", mixhome}, {"MIX_ARCHIVES", mixarchives}]

    {_, 0} = System.cmd(mixbin, ["local.rebar", "--force"], env: env, stderr_to_stdout: true)
    {_, 0} = System.cmd(mixbin, ["local.hex", "--force"], env: env, stderr_to_stdout: true)

    :ok
  rescue
    e ->
      NextLS.Logger.warning(logger, """
      Failed to unzip and install the bundled Elixir archive.

      #{Exception.format(:error, e, __STACKTRACE__)}
      """)

      :error
  end
end
