defmodule AhoCorasearch.WordSearch do
  @moduledoc """
  WordSearch enables a more refined search mechanism that takes into account full words.

  For example "Earphones and pinecones" using the regular(faster) `AhoCorasearch.search/2` function will match(depending on settings and input): `["ear", "phone", "earphone", "and", "pine", "cone", "cones", "pinecone", "pinecones"]`. Which might be what you want. This module will help if what you'd expect to match is `["earphones", "and", "pinecones"]`(assuming all those words are in your tree).

  It's a slower search method than the regular search, by a reasonable factor.
  """
  def filter(results, string) do
    string
    |> word_boundary_indexes()
    # Remove any entry where either it's start / stop are not part of the boundary map
    |> then(
      &Enum.filter(results, fn {b, e, _} -> MapSet.member?(&1, b) && MapSet.member?(&1, e) end)
    )
  end

  @re :re.compile(~c"[[:punct:][:space:]]", [:unicode]) |> then(fn {:ok, re} -> re end)

  defp word_boundary_indexes(string) do
    # Find all indexes of non-word characters
    :re.run(string, @re, [:global, {:capture, :all, :index}])
    |> then(fn
      :nomatch -> []
      {:match, match} -> match
    end)
    # Regex.scan(~r/[[:punct:][:space:]]/u, string, return: :index)
    # Create mapset of start / end of each section of non-word characters
    |> Enum.reduce([0, byte_size(string)], fn [{start, length}], acc ->
      [start + length | [start | acc]]
    end)
    |> MapSet.new()
  end
end
