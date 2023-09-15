defmodule AhoCorasearch.TreeBuilder do
  alias AhoCorasearch.{Tree, Native}

  def new(list, _) when length(list) == 0, do: {:error, :empty_list}

  def new(list, opts) do
    insensitive = Keyword.get(opts, :insensitive, true)
    uniq = Keyword.get(opts, :unique, false)
    match_kind = Keyword.get(opts, :match_kind, :leftmost_longest)

    with list <- downcase_patterns(list, insensitive),
         {:ok, {patterns, dups}} <- check_and_split(list, uniq),
         {:ok, tree_ref} <- build_tree(patterns, match_kind) do
      {:ok,
       %Tree{
         ref: make_ref(),
         tree_ref: tree_ref,
         dups: dups,
         match_kind: match_kind,
         insensitive: insensitive,
         unique: uniq
       }}
    end
  end

  defp downcase_patterns(list, false), do: list
  defp downcase_patterns(list, true), do: Enum.map(list, fn {k, v} -> {String.downcase(k), v} end)

  defp check_and_split(list, true) do
    case check_unique(list) do
      :ok -> {:ok, {list, nil}}
      err -> err
    end
  end

  defp check_and_split(list, false), do: {:ok, split_patterns(list)}

  def build_tree(patterns, match_kind) do
    case Native.build_tree(patterns, match_kind) do
      {:error, _} = err -> err
      res -> {:ok, res}
    end
  end

  def check_unique(patterns, acc \\ %{})
  def check_unique([], _), do: :ok

  def check_unique([{k, _} | _], acc) when :erlang.map_get(k, acc) == [],
    do: {:error, :not_unique}

  def check_unique([{k, _} | t], acc), do: check_unique(t, Map.put(acc, k, []))

  # Split patterns will convert a non-unique list into a unique list, plus a duplicate map for lookup.
  # [{"a", 1}, {"b", 2}, {"a", 3}]
  # [{"a", 1}, {"b", 2}] / %{1 => [3]}
  def split_patterns(list) do
    {list2, dups} =
      Enum.reduce(list, {[], %{}}, fn {k, v}, {acc, dups} ->
        case Map.get(dups, k) do
          nil -> {[{k, v} | acc], Map.put(dups, k, [v])}
          [_ | _] -> {acc, Map.update!(dups, k, &[v | &1])}
        end
      end)

    dups =
      Enum.map(dups, fn {_, v} ->
        [h | t] = Enum.reverse(v)
        {h, t}
      end)
      |> Enum.reject(fn {_, v} -> length(v) == 0 end)
      |> Enum.into(%{})

    {Enum.reverse(list2), dups}
  end
end
