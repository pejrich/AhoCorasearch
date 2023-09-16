defmodule AhoCorasearch.Tree do
  @moduledoc false
  alias __MODULE__
  alias AhoCorasearch.{TreeBuilder, Native}

  defstruct [
    :ref,
    :tree_ref,
    :match_kind,
    integer_ids: false,
    insensitive: true,
    unique: false,
    map: %{}
  ]

  @type match_kind :: :standard | :leftmost_longest | :leftmost_first
  @type t :: %Tree{
          ref: binary(),
          tree_ref: reference(),
          match_kind: match_kind,
          insensitive: boolean(),
          integer_ids: boolean(),
          unique: boolean(),
          map: %{integer => term() | list(term())}
        }

  defdelegate new(patterns, opts), to: TreeBuilder

  def search(
        %Tree{
          map: map,
          tree_ref: tree,
          match_kind: mk,
          unique: unique,
          integer_ids: integer_ids,
          insensitive: insensitive
        },
        string,
        opts \\ [overlap: false, word_search: false]
      )
      when is_binary(string) do
    overlap = Keyword.get(opts, :overlap, false)
    word_search = Keyword.get(opts, :word_search, false)
    string = maybe_downcase(string, insensitive)

    do_search(tree, string, mk, overlap)
    |> fix_dups(map, unique: unique, int: integer_ids)
    |> maybe_filter(string, word_search)
  end

  def heap_bytes(%{tree_ref: tree}), do: Native.tree_heap_bytes(tree)

  defp maybe_filter(results, string, true), do: AhoCorasearch.WordSearch.filter(results, string)
  defp maybe_filter(results, _, _), do: results

  defp maybe_downcase(string, true), do: AhoCorasearch.Native.downcase(string)
  defp maybe_downcase(string, _), do: string

  defp fix_dups(res, _, unique: true, int: true), do: res

  defp fix_dups(res, map, unique: true, int: false),
    do: Enum.map(res, fn {s, e, id} -> {s, e, Map.get(map, id, id)} end)

  defp fix_dups(res, map, unique: false, int: false),
    do: Enum.map(res, fn {s, e, id} -> {s, e, Map.get(map, id, [id])} end)

  defp do_search(tree, string, :leftmost_longest, _), do: Native.leftmost_find_iter(tree, string)
  defp do_search(tree, string, :leftmost_first, _), do: Native.leftmost_find_iter(tree, string)
  defp do_search(tree, string, :standard, false), do: Native.find_iter(tree, string)
  defp do_search(tree, string, :standard, true), do: Native.find_overlapping_iter(tree, string)

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{ref: ref, unique: uniq}, opts) do
      id = :erlang.ref_to_list(ref) |> Enum.drop(5) |> to_string()
      name = if uniq, do: "UniqueTree", else: "Tree"
      to_doc("#AhoCorasearch.#{name}<#{id}", opts)
    end
  end
end
