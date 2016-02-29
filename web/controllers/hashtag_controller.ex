defmodule Kaisuu.HashtagController do
  use Kaisuu.Web, :controller

  def index(conn, _params) do

    {:ok, emoji_data_total_count} = Kaisuu.RedisPool.command ~w(GET emoji_data_count)

    conn
    |> assign(:emoji_data_total_count, emoji_data_total_count)
    |> render("index.html")
  end

  def show(conn, %{"hashtag" => hashtag}) do
    original = hashtag
    hashtag = String.downcase("#{hashtag}")

    {:ok, emoji_data_total_count} = Kaisuu.RedisPool.command ~w(GET emoji_data_count)

    command = ~w(HLEN hashtag:\##{hashtag})
    {:ok, num_entries} = Kaisuu.RedisPool.command(command)

    display = "none"

    if num_entries == 0 do
      hashtag_data = []
      display = "inherit"
    else
      command = ~w(HKEYS hashtag:\##{hashtag})
      {:ok, hashtag_data} = Kaisuu.RedisPool.command(command)

      command = hashtag_data |> Enum.map(fn(key) -> ~w(HGET hashtag:\##{hashtag} #{key}) end)
      {:ok, hashtag_count} = Kaisuu.RedisPool.pipeline(command)

      hashtag_data = Enum.zip(hashtag_data, hashtag_count)
      hashtag_data = Enum.sort(hashtag_data, &(elem(&1, 1) > elem(&2, 1)))      
    end

    conn
    |> assign(:emoji_data_total_count, emoji_data_total_count)
    |> assign(:hashtag, original)
    |> assign(:hashtag_data, hashtag_data)
    |> assign(:display, display)
    |> render("hashtag.html")
  end

  defp transform_hex_to_string(hex_code_point) do
    int_code_point = hex_code_point |> String.to_integer(16)
    <<int_code_point :: utf8>>
  end
end
