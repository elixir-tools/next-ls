defmodule NextLS.Registry do
  @moduledoc """
  This module includes a version of the `Registry.dispatch/4` function included with the standard library that
  does a few of things differently.

  1. It will execute the callback even if the registry contains no processes for the given key.
  2. The function only works with duplicate registries with a single partition.
  3. The value returned by the callback is returned by the function.
  """
  @key_info -2

  def dispatch(registry, key, mfa_or_fun, _opts \\ [])
      when is_atom(registry) and is_function(mfa_or_fun, 1)
      when is_atom(registry) and tuple_size(mfa_or_fun) == 3 do
    case key_info!(registry) do
      {:duplicate, 1, key_ets} ->
        key_ets
        |> safe_lookup_second(key)
        |> apply_non_empty_to_mfa_or_fun(mfa_or_fun)
    end
  end

  defp apply_non_empty_to_mfa_or_fun(entries, {module, function, args}) do
    apply(module, function, [entries | args])
  end

  defp apply_non_empty_to_mfa_or_fun(entries, fun) do
    fun.(entries)
  end

  defp safe_lookup_second(ets, key) do
    :ets.lookup_element(ets, key, 2)
  catch
    :error, :badarg -> []
  end

  defp key_info!(registry) do
    :ets.lookup_element(registry, @key_info, 2)
  catch
    :error, :badarg ->
      raise ArgumentError, "unknown registry: #{inspect(registry)}"
  end
end
