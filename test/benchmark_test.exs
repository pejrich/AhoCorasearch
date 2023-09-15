defmodule BenchmarkTest do
  use ExUnit.Case
  @patterns for _ <- 1..1000, do: :crypto.strong_rand_bytes(20) |> Base.encode16()
  @patterns_with_id Enum.with_index(@patterns)
  @patterns_charlist Enum.map(@patterns, &to_charlist/1)

  @text Enum.reduce(
          @patterns,
          "",
          &(&2 <> " #{&1} #{:crypto.strong_rand_bytes(300) |> Base.encode16()}")
        )

  @short_text Enum.reduce(
                @patterns |> Enum.take(5),
                "",
                &(&2 <> " #{&1} #{:crypto.strong_rand_bytes(30) |> Base.encode16()}")
              )

  @text_charlist to_charlist(@text)
  @short_text_charlist to_charlist(@short_text)

  @tag timeout: :infinity
  @tag :benchmark
  test "speed" do
    {:ok, left_long_tree} = AhoCorasearch.build_tree(@patterns_with_id)
    {:ok, left_long_uniq_tree} = AhoCorasearch.build_tree(@patterns_with_id, unique: true)
    {:ok, standard_tree} = AhoCorasearch.build_tree(@patterns_with_id, match_kind: :standard)

    {:ok, standard_uniq_tree} =
      AhoCorasearch.build_tree(@patterns_with_id, match_kind: :standard, unique: true)

    {:ok, left_first_tree} =
      AhoCorasearch.build_tree(@patterns_with_id, match_type: :leftmost_first)

    {:ok, left_first_uniq_tree} =
      AhoCorasearch.build_tree(@patterns_with_id, match_type: :leftmost_first, unique: true)

    sick = ExAhoCorasick.new(@patterns)
    erl = :aho_corasick.build_tree(@patterns_charlist)

    IO.puts(
      "\n\nTesting build_tree with #{@patterns_with_id |> length} patterns(this lib vs others):\n"
    )

    Benchee.run(
      %{
        aho_corasearch_build_tree: fn ->
          {:ok, _} = AhoCorasearch.build_tree(@patterns_with_id)
        end,
        aho_corasick_elixir_build_tree: fn ->
          %ExAhoCorasick{} = ExAhoCorasick.new(@patterns)
        end,
        aho_corasick_erlang_build_tree: fn ->
          {_, _, _} = :aho_corasick.build_tree(@patterns_charlist)
        end
      },
      warmup: 0,
      time: 5
    )

    IO.puts(
      "\n\nTesting search(this lib vs others), long text. byte_size: #{byte_size(@text)}:\n"
    )

    Benchee.run(
      %{
        aho_corasearch_search: fn ->
          [_ | _] = AhoCorasearch.search(standard_uniq_tree, @text)
        end,
        aho_corasick_elixir_search: fn ->
          %MapSet{} = ExAhoCorasick.search(sick, @text)
        end,
        aho_corasick_erlang_search: fn ->
          [_ | _] = :aho_corasick.match(@text_charlist, erl)
        end
      },
      warmup: 0,
      time: 5
    )

    IO.puts(
      "\n\nTesting search lib vs other erlang/elixir libs, short text. byte_size: #{byte_size(@short_text)}:\n"
    )

    Benchee.run(
      %{
        aho_corasearch_search: fn ->
          [_ | _] = AhoCorasearch.search(standard_uniq_tree, @short_text)
        end,
        aho_corasick_elixir_search: fn ->
          %MapSet{} = ExAhoCorasick.search(sick, @short_text)
        end,
        aho_corasick_erlang_search: fn ->
          [_ | _] = :aho_corasick.match(@short_text_charlist, erl)
        end
      },
      warmup: 0,
      time: 5
    )

    IO.puts("\n\nTesting search libs different match kinds + unique/non-unique:\n")

    Benchee.run(
      %{
        aho_corasearch_left_long: fn ->
          [_ | _] = AhoCorasearch.search(left_long_tree, @short_text)
        end,
        aho_corasearch_left_long_uniq: fn ->
          [_ | _] = AhoCorasearch.search(left_long_uniq_tree, @short_text)
        end,
        aho_corasearch_left_first: fn ->
          [_ | _] = AhoCorasearch.search(left_first_tree, @short_text)
        end,
        aho_corasearch_left_first_uniq: fn ->
          [_ | _] = AhoCorasearch.search(left_first_uniq_tree, @short_text)
        end,
        aho_corasearch_standard: fn ->
          [_ | _] = AhoCorasearch.search(standard_tree, @short_text)
        end,
        aho_corasearch_standard_uniq: fn ->
          [_ | _] = AhoCorasearch.search(standard_uniq_tree, @short_text)
        end,
        aho_corasearch_standard_overlap: fn ->
          [_ | _] = AhoCorasearch.search(standard_tree, @short_text, overlap: true)
        end,
        aho_corasearch_standard_uniq_overlap: fn ->
          [_ | _] = AhoCorasearch.search(standard_uniq_tree, @short_text, overlap: true)
        end
      },
      warmup: 0,
      time: 5
    )

    IO.puts("\n\nTesting AhoCorasearch.search/3 vs AhoCorasearch.word_search/3 short text:\n")

    Benchee.run(
      %{
        aho_corasearch_left_long: fn ->
          [_ | _] = AhoCorasearch.search(left_long_tree, @short_text)
        end,
        aho_corasearch_left_long_word_search: fn ->
          [_ | _] = AhoCorasearch.word_search(left_long_tree, @short_text)
        end,
        aho_corasearch_standard: fn ->
          [_ | _] = AhoCorasearch.search(standard_tree, @short_text)
        end,
        aho_corasearch_standard_word_search: fn ->
          [_ | _] = AhoCorasearch.word_search(standard_tree, @short_text)
        end
      },
      warmup: 0,
      time: 5
    )

    IO.puts("\n\nTesting AhoCorasearch.search/3 vs AhoCorasearch.word_search/3 long text:\n")

    Benchee.run(
      %{
        aho_corasearch_left_long_long_text: fn ->
          [_ | _] = AhoCorasearch.search(left_long_tree, @text)
        end,
        aho_corasearch_word_search_left_long_long_text: fn ->
          [_ | _] = AhoCorasearch.word_search(left_long_tree, @text)
        end,
        aho_corasearch_standard_long_text: fn ->
          [_ | _] = AhoCorasearch.search(standard_tree, @text)
        end,
        aho_corasearch_standard_word_search_long_text: fn ->
          [_ | _] = AhoCorasearch.word_search(standard_tree, @text)
        end
      },
      warmup: 0,
      time: 5
    )

    alphabet =
      ~w(a b c d e f g h i j k l m n o p q r s t u v w x y z)
      |> Enum.flat_map(fn i -> [i, i <> i] end)

    patterns = alphabet |> Enum.with_index()
    ratio = floor(byte_size(@text) / byte_size(Enum.join(alphabet)))
    text = String.duplicate(Enum.join(alphabet), ratio)

    {:ok, best_case_tree} =
      AhoCorasearch.build_tree(patterns, unique: true, insensitive: false, match_kind: :standard)

    {:ok, worst_case_tree} = AhoCorasearch.build_tree(patterns, match_kind: :standard)

    IO.puts(
      "\n\nTesting AhoCorasearch best case vs worst case: long text(byte_size: #{byte_size(text)}, num_matches: #{AhoCorasearch.search(best_case_tree, text, overlap: true) |> length}):\n"
    )

    Benchee.run(
      %{
        aho_corasearch_worst_case_long_text: fn ->
          [_ | _] = AhoCorasearch.search(worst_case_tree, text, overlap: true)
        end,
        aho_corasearch_best_case_long_text: fn ->
          [_ | _] = AhoCorasearch.search(best_case_tree, text, overlap: true)
        end
      },
      warmup: 0,
      time: 5
    )

    text = String.slice(text, 0, 100)

    IO.puts(
      "\n\nTesting AhoCorasearch best case vs worst case: short text(byte_size: #{byte_size(text)}, num_matches: #{AhoCorasearch.search(best_case_tree, text, overlap: true) |> length}):\n"
    )

    Benchee.run(
      %{
        aho_corasearch_worst_case_short_text: fn ->
          [_ | _] = AhoCorasearch.search(worst_case_tree, text, overlap: true)
        end,
        aho_corasearch_best_case_short_text: fn ->
          [_ | _] = AhoCorasearch.search(best_case_tree, text, overlap: true)
        end
      },
      warmup: 0,
      time: 5
    )
  end
end
