defmodule CryptocompareWs do
  use Application
  @ets :_trades

  def start(_type, _args) do
    :ets.new(@ets, ~w(named_table set public)a)

    children = [
      CryptocompareWs.Ws,
      CryptocompareWs.Handler
    ]
    
    opts = [strategy: :one_for_one, name: __MODULE__.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
