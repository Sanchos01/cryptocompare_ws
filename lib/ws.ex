defmodule CryptocompareWs.Ws do
  use GenStage
  require Logger
  @subs Application.get_env(:cryptocompare_ws, :subs)

  def start_link(_), do: GenStage.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    {:ok, pid} = :gun.open('streamer.cryptocompare.com', 443)
    mon = Process.monitor pid
    ref = :gun.ws_upgrade pid, "/socket.io/websocket?transport=websocket", [{"Content-Type", "application/json"}]
    {:producer, %{pid: pid, mon: mon, ref: ref, time_ref: nil, timeout: nil}, demand: :forward}
  end

  def handle_demand(_demand, state), do: {:noreply, [], state}

  def handle_info({:gun_up, _pid, type}, state) do
    Logger.debug "gun up #{type}"
    {:noreply, [], state}
  end

  def handle_info({:gun_ws, _pid, {:text, <<"0", msg::binary>>}}, state = %{pid: pid}) do # connection
    cond do
      msg =~ ~r/sid.*pingInterval/ ->
        %{"timeout" => timeout} = Regex.named_captures(~r/sid\":\"(?<sid>[^\\"]+).*pingInterval\":(?<timeout>[\d]+)/, String.trim_leading(msg, "0"))
        {:ok, body} = Poison.encode ["SubAdd", %{subs: @subs}]
        :gun.ws_send pid, {:text, "42" <> body}
        send self(), :timeout
        {timeout, _} = Integer.parse timeout
        {:noreply, [], %{state | timeout: timeout}}
      true ->
        Logger.debug "connection 0 - error: #{inspect msg}"
        {:noreply, [], state}
    end
  end

  def handle_info({:gun_ws, _pid, {:text, "2"}}, state = %{pid: pid}) do # ping
    :gun.ws_send pid, {:text, "3"}
    {:noreply, [], state}
  end

  def handle_info({:gun_ws, _pid, {:text, "3"}}, state) do # pong
    {:noreply, [], state}
  end

  def handle_info({:gun_ws, _pid, {:text, <<"4", msg::binary>>}}, state) do # msg
    case msg do
      "0" -> {:noreply, [], state}
      <<"2", msg::binary>> ->
        with {:ok, decoded} <- Poison.decode(msg) do
          {:noreply, [decoded], state}
        else
          error ->
            Logger.error "check parsing error: #{inspect error}"
            {:noreply, [], state}
        end
      _ ->
        Logger.warn "unknown 4 - msg: #{inspect msg}"
        {:noreply, [], state}
    end
  end

  def handle_info({:gun_ws, _pid, {:text, msg}}, state) do
    cond do
      true ->
        Logger.debug "unknown msg: #{inspect msg}"
        {:noreply, [], state}
    end
  end

  def handle_info(:timeout, state = %{pid: pid, timeout: timeout, time_ref: ref}) do
    :gun.ws_send pid, {:text, "2"}
    ref && Process.cancel_timer(ref)
    ref = Process.send_after self(), :timeout, timeout
    {:noreply, [], %{state | time_ref: ref}}
  end

  def handle_info({:gun_ws_upgrade, _pid, :ok, _headers}, state) do
    Logger.debug "ws upgraded"
    {:noreply, [], state}
  end

  def handle_info({:gun_down, _pid, :ws, :closed, _, _}, state = %{pid: pid}) do
    Logger.debug "ws down, upgrade again"
    ref = :gun.ws_upgrade pid, "/socket.io/websocket?transport=websocket"
    {:noreply, [], %{state | ref: ref}}
  end

  def handle_info({:DOWN, mon, :process, pid, reason}, state = %{pid: pid, mon: mon}) do
    Logger.error "gun crushed: #{inspect reason}"
    {:noreply, [], state}
  end

  def handle_info(msg, state) do
    Logger.debug "Totally unknown msg: #{inspect msg}"
    {:noreply, [], state}
  end
end