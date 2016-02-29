defmodule Kaisuu.PageController do
  use Kaisuu.Web, :controller

  def index(conn, _params) do

    # redis.sort("emoji_data", :by => "emoji:*->count", :order => "desc") # => ["2", "1"]
    command = ~w(SORT emoji_data BY emoji:*->count DESC GET #)
    {:ok, emoji_data} = Kaisuu.RedisPool.command(command)

    command = emoji_data |> Enum.map(fn(key) -> ~w(HGET emoji:#{key} count) end)
    {:ok, emoji_data_count} = Kaisuu.RedisPool.pipeline(command)

    emoji_data = Enum.zip(emoji_data, emoji_data_count)

    {:ok, emoji_data_total_count} = Kaisuu.RedisPool.command ~w(GET emoji_data_count)

    adjust = fn(x) -> 32 end

    emoji_data = Enum.map(emoji_data, fn {x, y} -> {x, y, adjust.(y)} end)

    conn
    |> assign(:emoji_data, emoji_data)
    |> assign(:emoji_data_total_count, emoji_data_total_count)
    |> render("index.html")
  end

  defp transform_hex_to_string(hex_code_point) do
    int_code_point = hex_code_point |> String.to_integer(16)
    <<int_code_point :: utf8>>
  end
end
