defmodule AhoCorasearch.TreeBuilder do
  @moduledoc false
  alias AhoCorasearch.{Tree, Native}

  def new(list, _) when length(list) == 0, do: {:error, :empty_list}

  def new(list, opts) do
    insensitive = Keyword.get(opts, :insensitive, true)
    uniq = Keyword.get(opts, :unique, false)
    match_kind = Keyword.get(opts, :match_kind, :standard)

    with list <- downcase_patterns(list, insensitive),
         %{patterns: p, map: map, integer_ids: integer_ids} <- split_patterns(list, unique: uniq),
         {:ok, tree_ref} <- build_tree(p, match_kind) do
      {:ok,
       %Tree{
         ref: make_ref(),
         tree_ref: tree_ref,
         map: map,
         integer_ids: integer_ids,
         match_kind: match_kind,
         insensitive: insensitive,
         unique: uniq
       }}
    end
  end

  defp downcase_patterns(list, false), do: list
  defp downcase_patterns(list, true), do: Enum.map(list, fn {k, v} -> {String.downcase(k), v} end)

  defp build_tree(patterns, match_kind) do
    case Native.build_tree(patterns, match_kind) do
      {:error, _} = err -> err
      res -> {:ok, res}
    end
  end

  defp check_unique(patterns, acc \\ %{})
  defp check_unique([], _), do: true

  defp check_unique([{k, _} | _], acc) when :erlang.map_get(k, acc) == [],
    do: false

  defp check_unique([{k, _} | t], acc), do: check_unique(t, Map.put(acc, k, []))

  defp split_patterns(list, unique: true),
    do: uniq_split_patterns(list, Enum.all?(list, fn {_, v} -> is_integer(v) end))

  # Split patterns will convert a non-unique list into a unique list, plus a duplicate map for lookup.
  # [{"a", 1}, {"b", 2}, {"a", 3}]
  # [{"a", 0}, {"b", 1}] / %{0 => [1, 3], 1 => [2]}
  defp split_patterns(list, unique: false) do
    Enum.reduce(list, {0, %{}, [], %{}}, fn {i, j}, {idx, key_map, keys, acc} ->
      case Map.get(key_map, i) do
        nil -> {idx + 1, Map.put(key_map, i, idx), [{i, idx} | keys], Map.put(acc, idx, [j])}
        id -> {idx, key_map, keys, Map.update!(acc, id, &[j | &1])}
      end
    end)
    |> then(fn {_, _, list, map} ->
      # Fix ordering of {key, id} list
      list = Enum.reverse(list)
      # Fix ordering of the associated value list, and remove duplicates
      map =
        Enum.reject(map, fn {k, v} -> [k] == v end)
        |> Enum.map(fn {k, v} -> {k, Enum.reverse(v) |> Enum.uniq()} end)
        |> Enum.into(%{})

      %{patterns: list, integer_ids: false, map: map}
    end)
  end

  defp uniq_split_patterns(list, true) do
    if check_unique(list),
      do: %{patterns: list, integer_ids: true, map: nil},
      else: {:error, :not_unique}
  end

  defp uniq_split_patterns(list, false) do
    Enum.reduce_while(list, {0, MapSet.new(), [], %{}}, fn {i, j}, {idx, mapset, keys, acc} ->
      if MapSet.member?(mapset, i) do
        {:halt, {:error, :not_unique}}
      else
        {:cont, {idx + 1, MapSet.put(mapset, i), [{i, idx} | keys], Map.put(acc, idx, j)}}
      end
    end)
    |> then(fn
      {_, _, keys, map} ->
        map = Enum.reject(map, fn {a, b} -> a == b end) |> Enum.into(%{})
        %{patterns: Enum.reverse(keys), integer_ids: false, map: map}

      val ->
        val
    end)
  end
end
