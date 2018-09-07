defmodule Bite do
  import Elixir.Kernel, except: [to_string: 1]
  use Private

  @controls [?l]

  defstruct endian: :big, bytes: <<>>, base: 10, opts: [], source: <<>>

  # hexadecimal
  defmacro sigil_b({:<<>>, _, [binary]}, opts) do
    binary
    |> consume(opts)
    |> Macro.escape()
  end

  def consume(binary, flags \\ []) do
    (opts -- @controls)
    |> parse(binary)
    |> restore_source(binary, flags)
    |> give_endian(flags)
  end

  def to_integer(%Bite{endian: :little} = bite) do
    bite
    |> to_big_endian()
    |> to_integer()
  end

  def to_integer(%Bite{bytes: data, base: base}) do
    data
    |> Enum.map(&Integer.parse(&1, base))
    |> Enum.map(fn {int, _rest_of_binary} -> int end)
    |> Enum.reduce(&+/2)
  end

  def to_string(binary) when is_binary(binary), do: binary

  def to_string(%Bite{endian: :little} = bite) do
    bite
    |> to_big_endian()
    |> to_string()
  end

  def to_string(%Bite{bytes: data, base: 10}) do
    Enum.reduce(data, <<>>, fn byte, acc -> <<byte>> <> acc end)
  end

  def to_string(%Bite{} = bite) do
    bite
    |> to_base_10()
    |> to_string()
  end

  @doc """
  Drop `n` bytes from a binary. Results in a binary. Tail recursive.
  """
  def drop(binary, n)
  def drop(<<>>, _n), do: <<>>
  def drop(binary, 0), do: binary
  def drop(<<_h :: size(8), t :: binary>>, n), do: drop(t, n - 1)

  @doc """
  Take `n` bytes from a binary. Results in a ~b() sigil. Not tail recursive.
  """
  def take(binary, n, opts \\ []) when is_binary(binary) do
    take = _take(binary, n)

    consume(take, opts)
  end

  private do
    defp _take(<<>>, _n), do: <<>>
    defp _take(_binary, 0), do: <<>>
    defp _take(<<h :: size(8), t :: binary>>, n), do: <<h>> <> _take(t, n - 1)

    defp to_base_10(%Bite{bytes: data, base: base} = bite) do
      base_ten_bytes =
        data
        |> Enum.map(&Integer.parse(&1, base))
        |> Enum.map(fn {int, _rest} -> int end)

      %Bite{bite | bytes: base_ten_bytes, base: 10}
    end

    # hexadecimals
    defp parse([?h], binary) do
      cond do
        Regex.match?(~r(\s+), binary) ->
          %Bite{bytes: String.split(binary, ~r(\s+), trim: true), base: 16}

        Regex.match?(~r(\\\d{3}), binary) ->
          %Bite{bytes: String.split(binary, "\\", trim: true), base: 16}

        String.valid?(binary) ->
          %Bite{bytes: String.split(binary, "", trim: true), base: 16}

        true ->
          bytes = chunk(binary)

          %Bite{bytes: bytes, base: 16, source: "\\" <> Enum.join(bytes, "\\")}
      end
    end

    defp give_endian(%Bite{} = bite, opts) do
      if ?l in opts do
        %Bite{bite | endian: :little}
      else
        bite
      end
    end
  end

  defp restore_source(%Bite{source: <<>>} = bite, binary, opts) do
    %Bite{bite | source: binary, opts: opts}
  end
  defp restore_source(%Bite{} = bite, _binary, opts) do
    %Bite{bite | opts: opts}
  end

  defp to_big_endian(%Bite{endian: :big} = bite), do: bite
  defp to_big_endian(%Bite{endian: :little, bytes: data} = bite) do
    %Bite{bite | endian: :big, bytes: Enum.reverse(data)}
  end

  defp chunk(binary) do
    for <<chunk  :: size(8) <- binary>>, do: chunk
  end
end

# show the bite sigil as what was passed to the `Bite.sigil_b/2` macro.
defimpl Inspect, for: Bite do
  def inspect(bite, _opts), do: "~b(#{bite.source})#{bite.opts}"
end
