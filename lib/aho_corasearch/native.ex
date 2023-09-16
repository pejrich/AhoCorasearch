defmodule AhoCorasearch.Native do
  @moduledoc false
  use Rustler, otp_app: :aho_corasearch, crate: :aho_corasearch_nif

  # @spec build_tree(list())
  def build_tree(_patterns, _match_kind), do: error()

  def leftmost_find_iter(_resource, _string), do: error()

  def find_overlapping_iter(_resource, _string), do: error()

  def find_iter(_resource, _string), do: error()

  def tree_heap_bytes(_resource), do: error()

  def get_match_kind(_resource), do: error()

  def downcase(_string), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
