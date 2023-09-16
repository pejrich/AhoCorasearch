defmodule AhoCorasearchTest do
  use ExUnit.Case
  alias AhoCorasearch.Tree

  @uniq_pats [{"abc", 1}, {"def", 4}, {"ghi", 7}]
  @dup_pats [{"abc", 1}, {"abc", 2}, {"def", 4}, {"def", 5}, {"ghi", 7}]
  @non_int_pats [{"abc", :abc}, {"def", :def}, {"ghi", :ghi}]
  @non_int_dup_pats [{"abc", :abc}, {"abc", :abc2}, {"def", :def}, {"ghi", :ghi}]

  describe "build_tree" do
    test "it correctly builds a tree" do
      assert {:ok, %Tree{unique: true, integer_ids: true, insensitive: true, map: nil}} =
               AhoCorasearch.build_tree(@uniq_pats, unique: true)

      assert {:ok, %Tree{unique: true, integer_ids: true, insensitive: false, map: nil}} =
               AhoCorasearch.build_tree(@uniq_pats, unique: true, insensitive: false)

      assert {:ok, %Tree{unique: true, integer_ids: false, insensitive: true, map: %{}}} =
               AhoCorasearch.build_tree(@non_int_pats, unique: true)

      assert {:ok, %Tree{unique: false, integer_ids: false, insensitive: false, map: %{}}} =
               AhoCorasearch.build_tree(@non_int_dup_pats, insensitive: false)
    end

    test "it handles duplicate strings" do
      {:ok, %Tree{unique: false, insensitive: true, map: map}} =
        AhoCorasearch.build_tree(@dup_pats)

      assert %{0 => [1, 2], 1 => [4, 5], 2 => [7]} == map
    end

    test "it validates tree uniqueness" do
      {:error, _} = AhoCorasearch.build_tree(@dup_pats, unique: true)
      {:error, _} = AhoCorasearch.build_tree(@non_int_dup_pats, unique: true)
    end

    test "it works with non-int values" do
      assert {:ok, %{map: %{0 => [%{key: :a}, %{key: :a2}]}}} =
               AhoCorasearch.build_tree([{"a", %{key: :a}}, {"a", %{key: :a2}}])

      assert {:ok, %{map: %{0 => %{key: :a}, 1 => %{key: :b}}, integer_ids: false}} =
               AhoCorasearch.build_tree([{"a", %{key: :a}}, {"b", %{key: :b}}], unique: true)
    end
  end

  describe "search" do
    setup do
      {:ok, unique} = AhoCorasearch.build_tree(@uniq_pats, unique: true)
      {:ok, dup} = AhoCorasearch.build_tree(@dup_pats)
      {:ok, non_int} = AhoCorasearch.build_tree(@non_int_pats, unique: true)
      {:ok, non_int_dup} = AhoCorasearch.build_tree(@non_int_dup_pats)
      {:ok, unique: unique, dup: dup, non_int: non_int, non_int_dup: non_int_dup}
    end

    test "it returns the correct unique response", %{unique: tree, non_int: non_int} do
      resp = AhoCorasearch.search(tree, "abababcfedefedghi")
      assert [{4, 7, 1}, {9, 12, 4}, {14, 17, 7}] == resp
      resp = AhoCorasearch.search(non_int, "abababcfedefedghi")
      assert [{4, 7, :abc}, {9, 12, :def}, {14, 17, :ghi}] == resp
    end

    test "it returns the correct dup response", %{dup: tree, non_int_dup: non_int} do
      resp = AhoCorasearch.search(tree, "abababcfedefedghi")
      assert [{4, 7, [1, 2]}, {9, 12, [4, 5]}, {14, 17, [7]}] == resp
      resp = AhoCorasearch.search(non_int, "abababcfedefedghi")
      assert [{4, 7, [:abc, :abc2]}, {9, 12, [:def]}, {14, 17, [:ghi]}] == resp
    end

    test "it find the longest leftmost match" do
      patterns = [{"abcdefg", 1}, {"cdefghijkl", 2}, {"def", 4}, {"xyz", 5}]

      {:ok, tree} =
        AhoCorasearch.build_tree(patterns, unique: true, match_kind: :leftmost_longest)

      assert [{0, 7, 1}] ==
               AhoCorasearch.search(tree, "abcdefghijklmnop")
    end

    test "it works correctly for unicode" do
      patterns = [{"全世界", 3}, {"世界", 2}, {"に", 1}]
      {:ok, tree} = AhoCorasearch.build_tree(patterns, unique: true)
      assert [{0, 9, 3}, {12, 15, 1}] = AhoCorasearch.search(tree, "全世界中に")
    end
  end

  describe "word_search" do
    test "it only returns full word results" do
      patterns = ["red", "car", "red car"] |> Enum.with_index()
      {:ok, tree} = AhoCorasearch.build_tree(patterns, match_kind: :standard)
      results = AhoCorasearch.search(tree, "red car redcar", overlap: true, word_search: true)
      assert Enum.sort([{0, 3, [0]}, {0, 7, [2]}, {4, 7, [1]}]) == Enum.sort(results)
      results = AhoCorasearch.search(tree, "red car redcar", overlap: true, word_search: false)

      assert Enum.sort([{0, 3, [0]}, {0, 7, [2]}, {4, 7, [1]}, {8, 11, [0]}, {11, 14, [1]}]) ==
               Enum.sort(results)
    end
  end

  describe "insensitive" do
    test "setting to false" do
      {:ok, tree} = AhoCorasearch.build_tree([{"AAA", :aaa}, {"bbb", 1}], insensitive: false)
      assert [] == AhoCorasearch.search(tree, "aaaBBB")
      assert [{0, 3, [:aaa]}, {3, 6, [1]}] = AhoCorasearch.search(tree, "AAAbbb")
    end

    test "setting to true" do
      {:ok, tree} = AhoCorasearch.build_tree([{"AAA", :aaa}, {"bbb", 1}], insensitive: true)
      assert [{0, 3, [:aaa]}, {3, 6, [1]}] = AhoCorasearch.search(tree, "aaaBBB")
      assert [{0, 3, [:aaa]}, {3, 6, [1]}] = AhoCorasearch.search(tree, "AAAbbb")
    end
  end

  test "heap_bytes" do
    patterns =
      ~w(aaaaa bbbbbbb cccccccc dddddddd eeeeeee)
      |> List.duplicate(100)
      |> List.flatten()
      |> Enum.with_index()

    {:ok, tree} = AhoCorasearch.build_tree(patterns)
    heap_size = AhoCorasearch.heap_bytes(tree)
    assert heap_size > 0
  end
end
