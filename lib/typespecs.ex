defmodule Typespecs do
  defmacro __using__(_) do
    quote do
      @type pattern :: binary
      @type start :: integer
      @type stop :: integer
      @type id :: integer
      @type patterns :: [{pattern, id}] | [binary]
      @type match :: {start, stop, id} | {start, stop, list(id)}
      @type matches :: list(match)
      @type tree :: Tree.t()
    end
  end
end
