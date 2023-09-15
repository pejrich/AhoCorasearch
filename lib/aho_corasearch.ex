defmodule AhoCorasearch do
  @moduledoc """
  Documentation for `AhoCorasearch`.
  """
  alias AhoCorasearch.Tree

  @type pattern :: binary
  @type start :: integer
  @type stop :: integer
  @type id :: integer
  @type patterns :: [{pattern, id}]
  @type match :: {start, stop, id} | {start, stop, list(id)}
  @type matches :: list(match)
  @type tree :: Tree.t()

  @doc """
  Builds the tree needed for efficient string searching

  ## Examples
  ```elixir
  iex> AhoCorasearch.build_tree([{"abc", 1}, {"abc", 2}, {"def", 36}, {"xyz", 72}])
  {:ok, "#AhoCorasearch.Tree<0.1080113559.418906113.32320>"}

  iex> AhoCorasearch.build_tree([{"abc", 1}, {"def", 2}], unique: true, match_kind: :standard, insensitive: false)
  {:ok, "#AhoCorasearch.UniqueTree<0.1080113559.418906113.32348>"}

  iex> AhoCorasearch.build_tree([{"abc", 1}, {"abc", 2}, {"def", 36}, {"xyz", 72}], unique: true)
  {:error, :not_unique}
  ```

  The options it accepts are:
  * `unique` - Whether the keys in the pattern list are unique or not. This determines what the result tuple will look like. `{integer, integer, integer}` for unique trees, and `{integer, integer, list(integer)}` for non-unique trees. Defaults to `false`.
  * `insensitive` - If the matching should be case insensitive. Insensitivity is acheived by downcasing the patterns, and also downcasing the search text. This has a minor performance impact, but in most cases a negligible one. Defaults to `true`.
  * `match_kind` - There are 3 different matching options, but they must be chosen a tree building time, not at search time. The options are `standard`, `leftmost_longest`, or `leftmost_first`. Defaults to `leftmost_longest`.

  Given the following patterns:
  ```elixir
  [
    {"headphone", 0},
    {"head", 1},
    {"phone", 2},
    {"pine", 3},
    {"cone", 4},
    {"pinecone", 5}
  ]
  ```
  Searching with `AhoCorasearch.search(tree, "headphones and pinecones")`

  * `standard`:
    * will return `[{0, 4, [1]}, {4, 9, [2]}, {15, 19, [3]}, {19, 23, [4]}]`
    * which translates to `["head", "phone", "pine", "cone"]`

  * `leftmost_longest`:
    * will return `[{0, 9, [0]}, {15, 23, [5]}]`
    * which translates to `["headphone", "pinecone"]`

  * `leftmost_first`:
    * will return `[{0, 9, [0]}, {15, 19, [3]}, {19, 23, [4]}]`
    * which translates to `["headphone", "pine", "cone"]`(notice that `first` here is first in the pattern list, not first in the search string).

  The examples above demonstrate the return value for a non-unique tree. The results is `{start_index, end_index, ids}`. Not that the indexes are in bytes, so you'll want to use `:binary.part/3` to extract substrings, not `String.slice/3`. The ID part must be an integer, but it does not need to be unique. Multiple keys can use the same ID. If multiple patterns are given with the same key and ID, the result will be repeated, for example: `[{34, 35, [1, 1]}]`. IDs are returned in the same order they are given, so for patterns: `[{"a", 3}, {"a", 1}, {"a", 2}, {"a", 1}]`, an "a" in the search text would give the result: `{X, Y, [3, 1, 2, 1]}`
  """
  @default_options [unique: false, insensitive: true, match_kind: :leftmost_longest]
  @type match_kind :: :leftmost_longest | :leftmost_first | :standard
  @type options :: [unique: boolean, insensitive: boolean, match_kind: match_kind()]
  @spec build_tree(patterns, options) :: {:ok, tree} | {:error, term}
  def build_tree(patterns, opts \\ @default_options),
    do: Tree.new(patterns, opts)

  @doc """
  Searches the given string, against the given tree. This is one of two available ways to search. This is the faster of the two methods, but also might give more unexpected data. It will return matches anywhere they appear in the string(assuming the rules still abide by the tree's match configuration), but it has no notion of words. So partial and subwords will match. If you're looking for only full word matches, look at the `AhoCorasearch.word_search/3`, or use the option `word_search: true` which will filter out any matches that are not complete words(starting and ending at a word boundary).

  The inputs are:
  * `tree`: `AhoCorasearch.Tree.t()` - The tree that was build with `build_tree/2-3`
  * `string`: `String.t()` - The string that will be searched against the tree
  * `opts`:
    * `overlap: boolean`(default: false) - This argument is ONLY used if the tree type is `standard`. For trees with another `match_kind` it is ignored.
    * `word_search: boolean`(default: false) - Applies an additional filtering step to remove any matches that aren't complete words

  The result is a list of matches, either in the form `{integer, integer, integer}` for unique tree, or `{integer, integer, list(integer)}` for non-unique trees. The values are: `{start_index, end_index, ID}`. ID is whatever you passed in as the pattern(`[{"string", ID}, ...]`).

  The `start_index` and `end_index` are in BYTE values, not character or codepoints, so be sure you operate on the string with them by using `:binary.part/3` rather than `String.slice/3`.

  returns a list of all the matches in the input string.
  leftmost, longest matches
  While this handles unicode optimally, the return start/stop values are
  in bytes. i.e. use `:binary.part/3` rather than `String.slice/3`
  """
  @type search_opts :: [overlap: boolean, word_search: boolean]
  @spec search(Tree.t(), binary, search_opts) :: matches
  def search(%Tree{} = tree, string, opts \\ [overlap: false, word_search: false]),
    do: Tree.search(tree, string, opts)

  @doc """
  This is a convenience function for doing a word based search. Internally it just sets the `word_search` option to true for `search/3`, so either can be used as they're the same.
  """
  @spec search(Tree.t(), binary, overlap: boolean) :: matches
  def word_search(tree, string, opts \\ [overlap: false]),
    do: search(tree, string, Keyword.put(opts, :word_search, true))

  @doc """
  Returns the number of bytes that the tree is using on the native/Rust side.
  This does not account for any memory being stored on the Beam side, which hold the duplicate map
  Total size(beam + native) can be approximated with:
  `:erts_debug.flat_size(tree) + AhoCorasearch.heap_bytes(tree)`

  This function is only intended for use in development/debugging. I don't know the implications(performance or safety) of using it in production.
  """
  @spec heap_bytes(Tree.t()) :: pos_integer()
  def heap_bytes(%Tree{} = tree), do: Tree.heap_bytes(tree)
end
