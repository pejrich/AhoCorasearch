# AhoCorasearch

This lib is an elixir wrapper of the Rust lib Daachorse. 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `aho_corasearch` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aho_corasearch, "~> 0.1.0"}
  ]
end
```

Documentation can be found on [HexDocs](https://hexdocs.pm/aho_corasearch/usage.html).

## Basic Usage

```elixir
patterns = [
  {"search", 0},
  {"keyword", 1},
  {"text", 2},
  {"📚", 2},
  {"🕵️‍♂️", 0},
  {"🗝️", 1}
]
{:ok, tree} = AhoCorasearch.build_tree(patterns)
text = "This is some text(📚) you want to search(🕵️‍♂️) for keywords(🗝️)."
AhoCorasearch.search(tree, text)
```
Result looks like:
```elixir
[
  {13, 17, [2]},
  {18, 22, [3]},
  {36, 42, [0]},
  {43, 59, [4]},
  {65, 72, [1]},
  {74, 81, [5]}
]
```

Could be processed like:
```elixir
keys = %{0 => :search, 1 => :keyword, 2 => :text}
Enum.map(results, fn {start, stop, ids} ->
  %{
    range: start..stop,
    match: :binary.part(text, start, stop - start),
    key: Enum.map(ids, &keys[&1])
  }
end)
```
Which returns:
```elixir
[
  %{match: "text", range: 13..17, key: [:text]},
  %{match: "📚", range: 18..22, key: [:text]},
  %{match: "search", range: 36..42, key: [:search]},
  %{match: "🕵️‍♂️", range: 43..59, key: [:search]},
  %{match: "keyword", range: 65..72, key: [:keyword]},
  %{match: "🗝️", range: 74..81, key: [:keyword]}
]
```

Patterns take the form `[{string: String.t(), id: pos_integer()}, ...]`, where `string` is a string you want to search for, and `id` is any positive integer that you can later use for linking matches. 

More examples and a deeper explanation of settings/options can be found in the HexDocs(or the Usage.md file)

## Credits

The underlying Rust library is Daachorse.

- [Github](https://github.com/daac-tools/daachorse)

- [Crates.io](https://crates.io/crates/daachorse)

- [Docs.rs](https://docs.rs/daachorse/1.0.0/daachorse/)

It cannot be overstated how much of the performance(all of it) and capabilities(all but a few minor things like case insensitivity) of this library are due to the underlying Rust lib, daachorse. So a huge thanks to everyone who worked on that, and for releasing it with a permissive OSS license. This library wouldn't be possible without their hard work. 

Daachorse is released under both Apache 2.0 and MIT license.

Daachorse citation:

```
@article{10.1002/spe.3190,
    author = {Kanda, Shunsuke and Akabe, Koichi and Oda, Yusuke},
    title = {Engineering faster double-array {Aho--Corasick} automata},
    journal = {Software: Practice and Experience},
    volume={53},
    number={6},
    pages={1332--1361},
    year={2023},
    keywords = {Aho–Corasick automata, code optimization, double-array, multiple pattern matching},
    doi = {https://doi.org/10.1002/spe.3190},
    url = {https://onlinelibrary.wiley.com/doi/abs/10.1002/spe.3190},
    eprint = {https://onlinelibrary.wiley.com/doi/pdf/10.1002/spe.3190}
}
```

## License

MIT License

Copyright (c) 2023 Peter Richards

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.