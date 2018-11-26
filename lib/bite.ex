defmodule Bite do
  import Elixir.Kernel, except: [to_string: 1]
  use Private

  @moduledoc """
  A byte string convenience library.
  """

  @controls [?l]

  defstruct endian: :big, bytes: <<>>, base: 10, opts: [], source: <<>>

  @type t :: %__MODULE__{
          endian: :big | :little,
          bytes: binary(),
          base: pos_integer(),
          opts: charlist(),
          source: binary()
        }

  @doc """
  Consume a binary as a ~b() using the b sigil.

  Uses `consume/2` under the hood. See `consume/2` for information on flags.

  ## Examples

      iex> import Bite, only: [sigil_b: 2]
      iex> ~b(0a 00 00 00)hl
      ~b(0a 00 00 00)hl
  """
  @spec sigil_b({atom(), any(), [binary()]}, charlist()) :: t()
  defmacro sigil_b({:<<>>, _, [binary]}, opts) do
    binary
    |> consume(opts)
    |> Macro.escape()
  end

  @doc """
  Consumes a binary as a ~b() sigil.

  Allows the flags:

  * ?l - interperate the bytes as little endian; if ?l is not specified, the number is assumed to be big endian
  * ?h - interperate the bytes as hexadecimal

  ## Examples

      iex> Bite.consume("0a 00 00 00", 'lh')
      ~b(0a 00 00 00)lh
      iex> "b0 00 00 00" |> Bite.consume('lh') |> Bite.to_integer()
      176
  """
  @spec consume(binary(), charlist()) :: t()
  def consume(binary, flags \\ []) do
    (flags -- @controls)
    |> parse(binary)
    |> restore_source(binary, flags)
    |> give_endian(flags)
  end

  @doc """
  Convert a bite into an integer.

  ## Examples

      iex> ~b(b0 00 00 00)hl |> Bite.to_integer()
      176
  """
  @spec to_integer(t()) :: integer()
  def to_integer(bite)

  def to_integer(%Bite{endian: :little} = bite) do
    bite
    |> to_big_endian()
    |> to_integer()
  end

  def to_integer(%Bite{bytes: bytes, base: 10}) do
    Enum.reduce(bytes, &+/2)
  end

  def to_integer(%Bite{} = bite) do
    bite
    |> to_base_10()
    |> to_integer()
  end

  @doc """
  Convert a bite to a string.

  ## Examples

      iex> "6d 65 73 73 61 67 65" |> Bite.to_string()
      "6d 65 73 73 61 67 65"
      iex> ~b(6d 65 73 73 61 67 65)h |> Bite.to_string()
      "message"
      iex> ~b(6d 65 73 73 61 67 65)hl |> Bite.to_string()
      "egassem"
  """
  @spec to_string(%__MODULE__{} | String.t()) :: String.t()
  def to_string(binary) when is_binary(binary), do: binary

  def to_string(%Bite{endian: :little} = bite) do
    bite
    |> to_big_endian()
    |> to_string()
  end

  def to_string(%Bite{bytes: data, base: 10}) do
    Enum.reduce(data, <<>>, fn byte, acc -> acc <> <<byte>> end)
  end

  def to_string(%Bite{} = bite) do
    bite
    |> to_base_10()
    |> to_string()
  end

  @doc """
  Drop `n` bytes from a binary. Results in a binary. Tail recursive for
  binary inputs.

  In a bite, drops the `n` highest order bits respecting the endianness.

  ## Examples

      iex> "message" |> Bite.drop(2)
      "ssage"
      iex> "message" |> Bite.drop(20)
      ""
      iex> ~b(6d 65 73 73 61 67 65)h |> Bite.drop(2) |> Bite.to_string()
      "ssage"
  """
  @spec drop(binary(), integer()) :: binary()
  @spec drop(t(), integer()) :: t()
  def drop(binary, n)
  def drop(<<>>, _n), do: <<>>
  def drop(binary, 0), do: binary
  def drop(<<_h::size(8), t::binary>>, n), do: drop(t, n - 1)

  def drop(%Bite{bytes: data, endian: endian} = bite, n) do
    # if little endian, drop from the back, dropping the highest order bytes
    amount = if endian == :little, do: -n, else: n

    %Bite{bite | bytes: Enum.drop(data, amount)}
  end

  @doc """
  Take `n` bytes from a binary and consume it into a bite. Not tail recursive.

  ## Examples

      iex> "ffffffff" |> Bite.take(4, [?h])
      ~b(ffff)h
      iex> "ff" |> Bite.take(4, [?h])
      ~b(ff)h
      iex> "ffff0000" |> Bite.take(4, 'hl')
      ~b(ffff)hl
  """
  @spec take(binary(), integer()) :: t()
  @spec take(binary(), integer(), charlist()) :: t()
  def take(binary, n, opts \\ []) when is_binary(binary) do
    take = _take(binary, n)

    consume(take, opts)
  end

  @doc "Create a byte from an integer"
  def from_integer(n, acc \\ <<>>)
  def from_integer(0, acc), do: acc

  def from_integer(n, acc) when is_integer(n) do
    case Integer.floor_div(n, 256) do
      0 -> acc <> <<Integer.mod(n, 256)::size(8)>>
      m -> from_integer(n - 256 * m, acc <> <<m::size(8)>>)
    end
  end

  @doc "Pad a binary until it's length matches `n`"
  def pad_length(bytes, n, pad \\ <<0>>)

  def pad_length(bytes, n, pad) when is_binary(bytes) do
    case String.length(bytes) do
      m when m < n -> pad_length(pad <> bytes, n, pad)
      _ -> bytes
    end
  end

  @doc "Reverse a binary"
  def reverse(bytes, acc \\ <<>>)
  def reverse(<<>>, acc), do: acc
  def reverse(<<h::size(8), t::binary>>, acc), do: reverse(t, <<h>> <> acc)

  private do
    @spec _take(binary(), integer()) :: binary()
    defp _take(<<>>, _n), do: <<>>
    defp _take(_binary, 0), do: <<>>
    defp _take(<<h::size(8), t::binary>>, n), do: <<h>> <> _take(t, n - 1)

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

    defp parse([], binary) do
      bytes = chunk(binary)

      %Bite{bytes: bytes, base: 10, source: "\\" <> Enum.join(bytes, "\\")}
    end

    defp give_endian(%Bite{} = bite, opts) do
      if ?l in opts do
        %Bite{bite | endian: :little}
      else
        bite
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
      for <<chunk::size(8) <- binary>>, do: chunk
    end
  end
end

# show the bite sigil as what was passed to the `Bite.sigil_b/2` macro.
defimpl Inspect, for: Bite do
  def inspect(bite, _opts), do: "~b(#{bite.source})#{bite.opts}"
end
