defmodule AhoCorasearch.MixProject do
  use Mix.Project

  def project do
    [
      app: :aho_corasearch,
      description:
        "Elixir lib for Aho-Corasick string searching. Uses a Rust-based NIF for greatly improved performance.",
      version: "0.1.0",
      elixir: "~> 1.15",
      name: "AhoCorasearch",
      source_url: "https://github.com/pejrich/AhoCorasearch",
      docs: [
        main: "AhoCorasearch",
        extras: ["Usage.md"]
      ],
      start_permanent: Mix.env() == :prod,
      rustler_crates: rustler_crates(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/benchmark_libs"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :tools]
    ]
  end

  defp rustler_crates do
    [
      aho_corasearch_nif: [
        path: "native/aho_corasearch_nif",
        mode: :release
      ]
    ]
  end

  defp deps do
    [
      {:makeup_html, ">= 0.0.0", only: :dev, runtime: false},
      {:rustler, "~> 0.29"},
      {:benchee, "~> 1.0", only: [:test, :dev]},
      {:aho_corasick, git: "https://github.com/wudeng/aho-corasick", only: [:test]}
    ]
  end
end
