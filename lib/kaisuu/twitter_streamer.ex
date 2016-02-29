defmodule Kaisuu.TwitterStreamer do
  use GenServer
  alias Exmoji.Scanner
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(state) do
    send(self, :start_streaming)

    {:ok, state}
  end

  def handle_info(:start_streaming, state) do
    spawn_link fn ->
      # Coordinates for most of Japan
      # japan = "129.484177, 30.923179, 145.985641, 45.799878"
      # params = [locations: japan, language: "ja"]
      usa = "-124.89, 32.48, -114.73, 49.11, -114.73, 31.07, -104.8, 49.08,-104.8, 26.01, -94.34, 49.12,-94.34, 28.45, -85.07, 49.22,-85.07, 24.54, -75.53, 47.6,-75.53, 33.97, -66.92, 47.65"

      stream = ExTwitter.stream_filter([locations: usa, language: "en"], :infinity)
      |> Stream.filter(fn(tweet) -> tweet_is_unique(tweet) end)
      |> Stream.map(fn(tweet) -> tweet.text end)
      |> Stream.flat_map(fn(text) -> extract_kanji(text) end)
      |> Stream.map(fn(kanji) -> write_to_redis(kanji) end)
      |> Stream.map(fn(kanji) -> broadcast(kanji) end)
      Enum.to_list(stream)
    end

    {:noreply, state}
  end

  defp tweet_is_unique(tweet) do
    unique = true
    if tweet.favorited,     do: unique = false
    if tweet.retweeted,     do: unique = false
    if tweet.quoted_status, do: unique = false
    unique
  end

  defp extract_kanji(text) do
    for ht <- Regex.scan(~r/#[A-Za-z0-9]+/, text) do
      # IO.puts "Found hashtag: #{ht}"
      for s <- Exmoji.Scanner.scan(text) do
        # IO.puts "Found emoji: " <> Exmoji.EmojiChar.render(s)
        # {s.name}, #{s.unified}, #{s.variations}, #{s.text}, #{s.short_name}"
        IO.puts Exmoji.EmojiChar.render(s) <> "  --> #{ht}"
        ht = String.downcase("#{ht}")

        incr_hashtag_emoji = ~w(HINCRBY hashtag:#{ht} #{s} 1)
        # Kaisuu.RedisPool.command(incr_hashtag_emoji)
      end
    end

    # String.codepoints(text)
    Exmoji.Scanner.scan(text)
  end

  defp write_to_redis(emoji) do
    emoji = Exmoji.EmojiChar.render(emoji)
    hex_code_point = emoji |> String.to_char_list |> List.first |> Integer.to_string(16)

    add_emoji_to_index = ~w(SADD emoji_data #{hex_code_point})
    increase_emoji_count = ~w(HINCRBY emoji:#{hex_code_point} count 1)
    increase_total_emoji_count = ~w(INCR emoji_data_count)

    commands = [add_emoji_to_index, increase_emoji_count, increase_total_emoji_count]
    
    # Kaisuu.RedisPool.pipeline(commands)

    emoji
  end

  defp broadcast(kanji) do
    hex = kanji |> String.to_char_list |> List.first |> Integer.to_string(16)

    Kaisuu.Endpoint.broadcast! "kanji:all", "new_kanji", %{ kanji: kanji, hex: hex }
    kanji
  end
end
