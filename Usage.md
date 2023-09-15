# Usage

## What is it?

AhoCorasearch is an Elixir wrapping of the Rust library, [Daachorse](https://github.com/daac-tools/daachorse), which is a fast implementation of the Aho-Corasick string searching algorithm, specifically the double-array version of Aho-Corasick.

## Why would I want to use it?

Aho-Corasick is a very fast string searching algorithm provided that the keywords you want to search for in the novel text, are known ahead of time(so that the intial setup can be done at startup, or amortized over multiple searches). For example if you're searching for a fixed list of keywords in multiple documents, then this will be well suited for your needs. If on the other hand you're looking to search a dozen documents, but with a different set of keywords for each document, then Aho-Corasick might not be the best algorithm for what you're looking for.

## Basic Usage

First you must create the tree that will be used for the optimized string searching.

The input is a list of tuples, the first element a string, the second is an integer ID that you can later use to corelate the matches.
```
patterns = [{"is", 0}, {"was", 1}, {"an", 2}, {"am", 3}]

{:ok, tree} = AhoCorasearch.build_tree(patterns)
```

This function returns an opaque handle to a Rust resource. You can store it just like you would with a Ref or PID. It can be stored in ETS, a GenServer, an Agent, etc. But similar to a PID, it can't be stored in module attributes or anything compile time as it's  a reference to a runtime object in memory. To use it, you pass it to the `search/2-3` function.

```
AhoCorasearch.search(tree, "what is this example you're showing me?")

# => [{5, 7, [0]}, {10, 12, [0]}, {15, 17, [3]}]
```

The format of the results is the following: 
```
{
  integer: start_index, 
  integer: end_index, 
  integer | list(integer): ID | IDs
}
```

> #### Unique vs non-unique(default) {: .info}
>
> Passing `unique: true` to `build_tree/3` will give you single integer IDs in the results
> 
> [{5, 7, 0}, ...]
> 
> By default(without passing `unique`, or by passing `unique: false`) you can have a pattern like this `[{"a", 1}, {"a", 2}]`
> 
> The result for "a" would be `[{X, Y, [1, 2]}, ...]`

So we can use it as follows:

```
string = "what is this example you're showing me?"
results = AhoCorasearch.search(tree, "what is this example you're showing me?")
# => [{5, 7, [0]}, {10, 12, [0]}, {15, 17, [3]}]
Enum.map(results, fn {start, stop, _id} ->
  :binary.part(string, start, stop - start)
end)
# => ["is", "is", "am"]
```

`"what [is] th[is] ex[am]ple you're showing me?"`

There are different matching types you can use to vary the results. These are all required to be set during the tree building phase, not the searching phase.

### `standard`

`standard` will return the first match it comes across(not overlapping by default, but can be set to overlapping with a option on the `search/3` function `[overlap: true]`). I know it's confusing, but `standard` is not the default match_kind, `leftmost_longest` is, an explanation for why is further below.

So, `["pine", "cone", "econ"]` against `"pinecone"` would match `"pine"` and `"cone"`, or all 3 when using `overlap: true`.

```
iex(127)> {:ok, tree} = AhoCorasearch.build_tree(Enum.with_index(["pine", "cones", "pinecones"]), match_kind: :standard)
{:ok, "#AhoCorasearch.Tree<0.884206865.3714318337.202303>"}
iex(128)> AhoCorasearch.search(tree, "pinecones")
[{0, 4, [0]}, {4, 9, [1]}]
iex(129)> AhoCorasearch.search(tree, "pinecones", overlap: true)
[{0, 4, [0]}, {0, 9, [2]}, {4, 9, [1]}]
```

### `leftmost_longest`(default match_kind)

`leftmost_longest` will match, you guessed it, the rightmost, shortest. No, it will match whatever it finds first in the string(leftmost) that is the longest(of all matches starting at that location). To demonstrate we'll use the patterns `["pin", "pine", "inecones", "con", "cone", "cones"]`


```
iex(137)> {:ok, tree} = AhoCorasearch.build_tree(Enum.with_index(["pin", "pine", "inecones", "con", "cone", "cones"]))
{:ok, "#AhoCorasearch.Tree<0.884206865.3714318337.204014>"}
iex(128)> AhoCorasearch.search(tree, "pinecones")
[{0, 4, [1]}, {4, 9, [4]}]
iex(140)> |> Enum.map(fn {start, stop, _id} -> :binary.part("pinecones", start, stop - start) end)
["pine", "cones"]
```

So `pine` matched because it was leftmost. `inecones` didn't because although it was longer than `pine`, it was futher right, and overlapping. `con`, `cone`, `cones` started at the same position, but since `cones` is longer, it matched. _If_ the search string _didn't_ have the last `s` in it, then `cone` would have matched.

`leftmost_longest` does not accept an `overlap` option, because an overlapping `leftmost_longest` is really just `stardard` with overlapping turned on.


### `leftmost_first`

`leftmost_first` will match similar to `leftmost_longest`, except instead of length, it prioritizes the order which the pattern appeared in the input patterns when building the tree. So if you wanted to search for `cone`, `con`, and `cones`.

```
iex(144)> {:ok, tree} = AhoCorasearch.build_tree(Enum.with_index(["cone", "con", "cones"]), match_kind: :leftmost_first)
{:ok, "#AhoCorasearch.Tree<0.884206865.3714318337.208411>"}
iex(145)> AhoCorasearch.search(tree, "pinecones")
[{4, 8, [0]}]
```

Here we see `"cone"` as our match, because it was the the "first registered" of all the matches starting at `"c"`. 


## Whole word matching

You may have noticed all the matches so far will match any subsection of the string, regardless of word boundary. This is the default setting and the way that Aho-Corasick works. If what you want is word boundary matching words, so you want to match "pine" if it appears as "pine", or "pine." or "pine,", but not "pinecone", then there is another search function you can use. It works exactly the same as the one above(except it's a bit slower), but it will filter out matches that aren't at word boundaries.

```
iex(146)> {:ok, tree} = AhoCorasearch.build_tree(Enum.with_index(["pine"]), match_kind: :standard)
{:ok, "#AhoCorasearch.Tree<0.884206865.3714318337.209240>"}
iex(147)> AhoCorasearch.word_search(tree, "pine, pine pine. pinecone conepine pine.", overlap: true)
[{0, 4, [0]}, {6, 10, [0]}, {11, 15, [0]}, {35, 39, [0]}]
```
Now we just see matches that happen at word boundaries. 

`"[pine], [pine] [pine]. pinecone conepine [pine]."`

`AhoCorasearch.word_search/3` is just a convienience function for `AhoCorasearch.search(tree, string, word_search: true)`

For `:standard` match_kind, `overlap: true` is still a valid option here, because patterns can be multiple words. Patterns: `car`, `red car`, `red` would return all three when searched against `red car`, with `overlap: true`, because they all start/end at word boundaries.

The `AhoCorasearch.word_search/3`(or using `word_search: true`) function is a bit slower because it does a regex on the search string to find word boundaries, but it's still quite fast, and it should work for any unicode word boundaries, not just space, comma, period, etc.


## Unicode/chars

The searching is optimized to work on unicode characters. Even though the return results are in byte offsets, the following will work totally fine. 

```
patterns = String.split("👨‍👩‍👧‍👦🏯👩🏻‍🎤🇨🇴☮👨🏼‍💻", "", trim: true) |> Enum.with_index()
iex(156)> {:ok, tree} = AhoCorasearch.build_tree(patterns, match_kind: :standard)
{:ok, "#AhoCorasearch.Tree<0.884206865.3714580481.61356>"}
iex(157)> AhoCorasearch.search(tree, "some 👨‍👩‍👧‍👦 more 🏯 text 👩🏻‍🎤 in 🇨🇴 between ☮ here 👨🏼‍💻.")
[
  {5, 30, [0]},
  {36, 40, [1]},
  {46, 61, [2]},
  {65, 73, [3]},
  {82, 85, [4]},
  {91, 106, [5]}
]
```

You'll notice the offsets are much larger now, 25 bytes for the first emoji. So make sure you're always extracting from the string with `:binary.part/3`

> #### Do this {: .tip}
>
> ```
> string = "some 👨‍👩‍👧‍👦 more 🏯 text 👩🏻‍🎤 in 🇨🇴 between ☮ here 👨🏼‍💻."
> results = [
>   {5, 30, [0]},
>   {36, 40, [1]},
>   {46, 61, [2]},
>   {65, 73, [3]},
>   {82, 85, [4]},
>   {91, 106, [5]}
> ]
> iex(161)> Enum.map(results, fn {start, stop, _id} ->
> ...(161)>   :binary.part(string, start, stop - start)
> ...(161)> end)
> ["👨‍👩‍👧‍👦", "🏯", "👩🏻‍🎤", "🇨🇴", "☮",
>  "👨🏼‍💻"]
> ```

Elixir's `String.slice/3` is character based, and will give you totally fine results in ascii text where byte/codepoint/char 1 == 1 == 1, but you'll quickly know something went wrong if you try it for anything where that's not true. For example with the first emoji (byte/codepoint/char) 25 == 7 == 1. The 25 is the number the response results are using.


> #### Don't do this {: .warning}
>
> ```
> iex(164)> Enum.map(results, fn {start, stop, _id} ->
> ...(164)>   String.slice(string, start, stop - start)
> ...(164)> end)
> ["👨‍👩‍👧‍👦 more 🏯 text 👩🏻‍🎤 in 🇨🇴 betw",
>  "here", "", "", "", ""]
> ```

One other note, by default the searching is case insensitive, but this can be changed with the `insensitive` option on `build_tree/2`. This is different from how Aho-Corasick usually works, and is acheived by merely downcasing all input patterns, and downcasing the search text before searching. The downcasing is also done by a Rust NIF for performance reasons. I'm not 100% sure if there are any differences between Rust's `to_lowercase()` and Elixir's `String.downcase/1`, but I did run a test against Unicode's `UnicodeData.txt`, and found no differences(aside from Rust being faster).

The defaults in general are a bit opinionated, mostly because this code was part of a codebase that needed that specific functionality, and when I decided to extract this code into a separate library for releasing as OSS, I didn't want to potentially introduce bugs into the original codebase by changing the default behavior of this code. If you want something that most closely resembles a textbook version of Aho-Corasick, use the following options: `AhoCorasearch.build_tree(patterns, match_kind: :standard, unique: true, insensitive: false)`

## Performance

All benchmarks below can be run with `mix test --include benchmark`.

Because ultimately this code is wrapping a library written in Rust, it's very performant. On short strings(~100 characters), i've seen it hit 1.2M searches per second. The longest text benchmark I did was with a tree of ~150k English words, against the full bible, and Benchee showed IPS of ~27/s. In general, Aho-Corasick scales with the length of the search string, and the number of matches(longer string, and/or more matches in a string == slower execution), not the number of keywords in the tree.

The memory performance is also quite good, because the algorithm uses a dense tree structure, new entries can share nodes with previous entries(if there's character overlap), so the cost of each new entry trends downward as the tree grows. Also repeated keys are nearly free(except the small amount to hold the integer ID), because only one instance of that string gets sent to the Rust code. Below you'll find an assortment of benchmarks. As always with benchmarks, they only test for the exact settings/circumstances they test for, on the exact day/machine they were tested on, which may have nothing in common with your system/requirements/use case, so if performance is a major concern, do some benchmarking that more closesly matches your use case.

Metadata for all performance results:

```
Operating System: macOS
CPU Information: Apple M1 Pro
Number of Available Cores: 10
Available memory: 16 GB
Elixir 1.15.3
Erlang 26.0

Benchmark suite executing with the following configuration:
warmup: 0 ns
time: 5 s
memory time: 0 ns
reduction time: 0 ns
parallel: 1
inputs: none specified
```

#### Testing build_tree with 1000 patterns:

```
Name                                     ips        average  deviation         median         99th %
aho_corasearch_build_tree             204.30        4.89 ms     ±3.06%        4.86 ms        5.43 ms
aho_corasick_erlang_build_tree         10.56       94.70 ms    ±16.19%       88.98 ms      178.38 ms
aho_corasick_elixir_build_tree          2.14      467.53 ms    ±12.60%      445.57 ms      547.47 ms

Comparison:
aho_corasearch_build_tree             204.30
aho_corasick_erlang_build_tree         10.56 - 19.35x slower +89.80 ms
aho_corasick_elixir_build_tree          2.14 - 95.52x slower +462.63 ms
```

#### Testing search this lib vs other erlang/elixir libs, long text. byte_size: 642,000

```
Name                                 ips        average  deviation         median         99th %
aho_corasearch_search             201.03        4.97 ms     ±3.21%        4.93 ms        5.59 ms
aho_corasick_erlang_search          7.29      137.10 ms     ±2.37%      135.72 ms      148.90 ms
aho_corasick_elixir_search          0.70     1433.25 ms     ±1.31%     1435.43 ms     1453.33 ms

Comparison:
aho_corasearch_search             201.03
aho_corasick_erlang_search          7.29 - 27.56x slower +132.13 ms
aho_corasick_elixir_search          0.70 - 288.13x slower +1428.28 ms
```

#### Testing search(this lib vs others), short text. byte_size: 510

```
Name                                 ips        average  deviation         median         99th %
aho_corasearch_search           380.23 K        2.63 μs   ±488.58%        2.54 μs        2.83 μs
aho_corasick_erlang_search       10.32 K       96.89 μs    ±40.05%          95 μs      118.79 μs
aho_corasick_elixir_search        1.27 K      786.02 μs     ±5.04%      776.88 μs      927.89 μs

Comparison:
aho_corasearch_search           380.23 K
aho_corasick_erlang_search       10.32 K - 36.84x slower +94.26 μs
aho_corasick_elixir_search        1.27 K - 298.87x slower +783.39 μs
```

#### Testing search (this lib only) different match kinds + unique/non-unique

```
Name                                           ips        average  deviation         median         99th %
aho_corasearch_standard_uniq              376.73 K        2.65 μs   ±319.76%        2.54 μs        2.88 μs
aho_corasearch_standard_uniq_overlap      370.57 K        2.70 μs   ±322.54%        2.58 μs        2.92 μs
aho_corasearch_left_first_uniq            362.39 K        2.76 μs   ±307.24%        2.67 μs           3 μs
aho_corasearch_standard                   362.29 K        2.76 μs   ±310.07%        2.63 μs        3.08 μs
aho_corasearch_left_long_uniq             361.91 K        2.76 μs   ±312.74%        2.67 μs        2.96 μs
aho_corasearch_standard_overlap           355.19 K        2.82 μs   ±325.55%        2.71 μs        3.13 μs
aho_corasearch_left_first                 345.11 K        2.90 μs   ±302.28%        2.79 μs        3.21 μs
aho_corasearch_left_long                  343.39 K        2.91 μs   ±325.44%        2.79 μs        3.21 μs

Comparison:
aho_corasearch_standard_uniq              376.73 K
aho_corasearch_standard_uniq_overlap      370.57 K - 1.02x slower +0.0441 μs
aho_corasearch_left_first_uniq            362.39 K - 1.04x slower +0.105 μs
aho_corasearch_standard                   362.29 K - 1.04x slower +0.106 μs
aho_corasearch_left_long_uniq             361.91 K - 1.04x slower +0.109 μs
aho_corasearch_standard_overlap           355.19 K - 1.06x slower +0.161 μs
aho_corasearch_left_first                 345.11 K - 1.09x slower +0.24 μs
aho_corasearch_left_long                  343.39 K - 1.10x slower +0.26 μs
```

#### Testing AhoCorasearch.search/3 vs AhoCorasearch.word_search/3 short text byte_size: 510


```
Name                                           ips        average  deviation         median         99th %
aho_corasearch_standard                   366.25 K        2.73 μs   ±351.96%        2.63 μs           3 μs
aho_corasearch_left_long                  345.57 K        2.89 μs   ±374.89%        2.79 μs        3.13 μs
aho_corasearch_standard_word_search        69.25 K       14.44 μs    ±14.76%       14.17 μs       18.54 μs
aho_corasearch_left_long_word_search       68.68 K       14.56 μs    ±18.71%       14.33 μs       19.38 μs

Comparison:
aho_corasearch_standard                   366.25 K
aho_corasearch_left_long                  345.57 K - 1.06x slower +0.163 μs
aho_corasearch_standard_word_search        69.25 K - 5.29x slower +11.71 μs
aho_corasearch_left_long_word_search       68.68 K - 5.33x slower +11.83 μs
```

#### Testing AhoCorasearch.search/3 vs AhoCorasearch.word_search/3 long text byte_size: 642,000

```
Name                                                     ips        average  deviation         median         99th %
aho_corasearch_left_long_long_text                    201.33        4.97 ms     ±2.33%        4.93 ms        5.36 ms
aho_corasearch_standard_long_text                     199.55        5.01 ms     ±1.75%        4.98 ms        5.41 ms
aho_corasearch_word_search_left_long_long_text         63.94       15.64 ms     ±1.29%       15.59 ms       16.55 ms
aho_corasearch_standard_word_search_long_text          63.61       15.72 ms     ±0.72%       15.72 ms       16.13 ms

Comparison:
aho_corasearch_left_long_long_text                    201.33
aho_corasearch_standard_long_text                     199.55 - 1.01x slower +0.0444 ms
aho_corasearch_word_search_left_long_long_text         63.94 - 3.15x slower +10.67 ms
aho_corasearch_standard_word_search_long_text          63.61 - 3.17x slower +10.75 ms
```

### What are the most performant settings?

If you really want to eek out the most performance this library can give, the following settings: `[unique: true, insensitive: false]` will bypass a lot of the additional work that gets done in elixir. These settings will generally only be different by a meaningful amount if you are expecting a lot of matches(because `unique: false` does a map lookup for each match), and don't care about the searching being case insensitive(this allows the lib to skip doing a downcase pass on the search string, which saves time for long search strings).

"Best" case settings:
```
AhoCorasearch.build_tree(patterns, unique: true, insensitive: false, match_kind: :standard)
```

"Worst" case settings:
```
AhoCorasearch.build_tree(patterns, match_kind: :standard)
```

(the `match_kind` doesn't actually matter much for performance generally. I'm using `standard` because along with `overlap: true` it returns the most matches, which does change performance a bit)

#### Testing AhoCorasearch best case vs worst case: long text(byte_size: ~640k, num_matches: ~1M):

```
Name                                          ips        average  deviation         median         99th %
aho_corasearch_best_case_long_text          38.56       25.93 ms    ±24.64%       23.31 ms       35.94 ms
aho_corasearch_worst_case_long_text         20.77       48.15 ms     ±8.50%       47.58 ms       82.42 ms

Comparison:
aho_corasearch_best_case_long_text          38.56
aho_corasearch_worst_case_long_text         20.77 - 1.86x slower +22.21 ms
```

#### Testing AhoCorasearch best case vs worst case: short text(byte_size: 100, num_matches: 166):

```
Name                                           ips        average  deviation         median         99th %
aho_corasearch_best_case_short_text       384.43 K        2.60 μs   ±299.87%        2.50 μs        3.25 μs
aho_corasearch_worst_case_short_text      156.65 K        6.38 μs   ±129.82%        5.13 μs       18.79 μs

Comparison:
aho_corasearch_best_case_short_text       384.43 K
aho_corasearch_worst_case_short_text      156.65 K - 2.45x slower +3.78 μs
```

#### General performance usage

Overall the tree generated by `build_tree/2` is safe and fast to pass between processes, as well as safe to use from multiple procesess concurrently. Because the tree itself is stored in Rust, passing the tree from one process to another does not require copying the underlying Rust memory, only the reference handle which is tiny. The only edge case would be if you had huge numbers of duplicated strings in the tree, then there is some memory stored in the Beam side to hold the mapping of IDs, but this is a `%{integer => list(integer)}` map, so is really not a concern unless the numbers get massive. As always benchmarking your particular use case is the best way to know.

### Oddities / Known bugs

Currently the ability to pass in non-unique patterns is handled purely in Elixir as the underlying Rust lib requires unique patterns, so the Elixir code rolls up any duplicates and passes a single value to Rust in order to build the tree, and then resolves these back into multiple IDs after a search is done. Generally this causes no problems, but be aware that the logic merely aggregates the duplicates under the first key/ID pair, which can cause some unexpected behaviour in the following edge case(note the different return values for the "b" match based on which ID it overlaps with):

```
iex(53)> {:ok, tree} = AhoCorasearch.build_tree([{"a", 0}, {"a", 1}, {"b", 1}])
iex(54)> AhoCorasearch.search(tree, "ab")
[{0, 1, [0, 1]}, {1, 2, [1]}]
```
```
iex(56)> {:ok, tree} = AhoCorasearch.build_tree([{"a", 0}, {"a", 1}, {"b", 0}])
iex(57)> AhoCorasearch.search(tree, "ab")
[{0, 1, [0, 1]}, {1, 2, [0, 1]}]
```

You'll see that in the first example, even though a/1 and b/1 overlapped, because "b" was the first key to have ID: 1(a/1 was rolled into a/0), it returns only [1] in the results. When "b" is changed to 0, it's ID is now the same as the ID being used for "a", so "a" and "b" will have the same IDs([0, 1]). If you want some specific functionality that this conflicts with, you're best bet is passing `unique: true` to `AhoCorasearch.build_tree/2` and managing the ID resolution yourself.


Also, this code was my first foray in the Rust language, and my first time using Rustler to create Elixir NIFs, so there's likely a few things that could be done differently/better with that code. That being said it's fairly short code, with really no complex logic, and has been very stable in the time i've used it. However, if you have any suggestions for improvements, please let me know and I'll be happy to take a look into it.