defmodule CryptocompareWs.Handler do
  use GenStage
  require Logger
  alias CryptocompareWs.Ws
  @rgx ~r/\A(?<Id>.+)~(?<ExchangeName>.+)~(?<First>.+)~(?<Second>.+)~(?<Flag>.+)~(?<TradeId>.+)~(?<Ts>.+)~(?<Quantity>.+)~(?<Price>.+)~(?<Total>.+)~.*/
  @ets :_trades

  def start_link(_), do: GenStage.start_link(__MODULE__, [], name: __MODULE__)

  def init(_), do: {:consumer, %{}, subscribe_to: [{Ws, max_demand: 10}]}

  def handle_events(events, _from, state) do
    parse_events(events)
    {:noreply, [], state}
  end

  defp parse_events([]), do: :ok
  defp parse_events([["m", sub_msg] | rest]) when sub_msg in ~w(3~LOADCOMPLETE), do: parse_events rest
  defp parse_events([["m", <<"0", _::binary>> = sub_msg] | rest]) do
    with %{"First" => first, "Second" => second, "Ts" => ts} = result <- Regex.named_captures(@rgx, sub_msg) do
      key = {first, second, ts}
      :ets.insert @ets, {key, result}
    else
      _ -> Logger.warn "#{__MODULE__} unmatched event: #{sub_msg}"
    end
    parse_events rest
  end
  defp parse_events([event | rest]) do
    Logger.debug "#{__MODULE__} unhandled event: #{inspect event}"
    parse_events rest
  end
end