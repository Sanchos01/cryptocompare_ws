defmodule CryptocompareWs.Handler do
  use GenServer
  require Logger
  @rgx ~r/(?<SubscriptionId>[^~]+)~(?<ExchangeName>[^~]+)~(?<First>[^~]+)~(?<Second>[^~]+)~(?<Flag>[^~]+)~(?<TradeId>[^~]+)~(?<Ts>[^~]+)~(?<Quantity>[^~]+)~(?<Price>[^~]+)~(?<Total>[^~]+)/
  @ets :_trades

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    {:ok, %{}}
  end

  def handle_info(["m", sub_msg], state) when sub_msg in ~w(3~LOADCOMPLETE) do
    {:noreply, state}
  end

  def handle_info(["m", <<"0", _::binary>> = sub_msg], state) do
    with %{"First" => f, "Second" => s, "TradeId" => t} = result <- Regex.named_captures(@rgx, sub_msg) do
      :ets.insert @ets, {{f, s, t}, result}
    else
      _ -> Logger.warn "unmatched msg: #{inspect sub_msg}"
    end
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug "#{__MODULE__} unhandled msg: #{inspect msg}"
    {:noreply, state}
  end
end