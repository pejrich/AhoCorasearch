defmodule AhoCorasearch.Tree do
  alias __MODULE__
  alias AhoCorasearch.{TreeBuilder, Native}

  defstruct [:ref, :tree_ref, :match_kind, insensitive: true, unique: false, dups: %{}]
  @type match_kind :: :leftmost_longest | :leftmost_first | :standard
  @type t :: %Tree{
          ref: binary(),
          tree_ref: reference(),
          match_kind: match_kind,
          insensitive: boolean(),
          unique: boolean(),
          dups: %{integer => list(integer)}
        }

  defdelegate new(patterns, opts), to: TreeBuilder

  def search(
        %Tree{
          dups: dups,
          tree_ref: tree,
          match_kind: mk,
          unique: unique,
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
    |> fix_dups(unique, dups)
    |> maybe_filter(string, word_search)
  end

  def heap_bytes(%{tree_ref: tree}), do: Native.tree_heap_bytes(tree)

  defp maybe_filter(results, string, true), do: AhoCorasearch.WordSearch.filter(results, string)
  defp maybe_filter(results, _, _), do: results

  defp maybe_downcase(string, true), do: AhoCorasearch.Native.downcase(string)
  defp maybe_downcase(string, _), do: string

  defp fix_dups(res, true, _), do: res

  defp fix_dups(res, false, dups),
    do: Enum.map(res, fn {s, e, id} -> {s, e, [id | dups[id] || []]} end)

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
