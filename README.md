# Bite

Bite allows you to deal with byte data in a very comfortable and succinct way.
For example, here's how you'd deal with the 4 byte pattern `b0 00 00 00` in
little endian hexadecimal:

```elixir
iex> import Bite
iex> ~b(b0 00 00 00)hl
~b(b0 00 00 00)hl
iex> ~b(b0 00 00 00) |> Bite.to_integer()
176
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bite` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bite, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/bite](https://hexdocs.pm/bite).

