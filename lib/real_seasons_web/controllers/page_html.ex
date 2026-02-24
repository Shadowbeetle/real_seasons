defmodule RealSeasonsWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use RealSeasonsWeb, :html

  embed_templates "page_html/*"

  @doc """
  Formats a standard deviation value as a Hungarian multiplier with correct
  vowel-harmony suffix, e.g. `1.23` → `"1,23-szorosával"`.

  The suffix is determined by the last digit of the formatted number:
  - 0, 3, 6, 8 → -szorosával (back vowel: nulla, három, hat, nyolc)
  - 1, 2, 4, 7, 9 → -szeresével (front vowel: egy, kettő, négy, hét, kilenc)
  - 5 → -szörösével (rounded front vowel: öt)
  """
  def hungarian_multiplier(value) when is_number(value) do
    formatted = :erlang.float_to_binary(value / 1, decimals: 2)
    formatted_hu = String.replace(formatted, ".", ",")
    last_digit = formatted |> String.last() |> String.to_integer()

    suffix =
      case last_digit do
        d when d in [0, 3, 6, 8] -> "szorosával"
        d when d in [1, 2, 4, 7, 9] -> "szeresével"
        5 -> "szörösével"
      end

    "#{formatted_hu}-#{suffix}"
  end
end
