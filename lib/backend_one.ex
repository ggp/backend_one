defmodule BackendOne do
  use Application
  require Logger

  @otp_app Mix.Project.config[:app]

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    amqp_opts = Application.get_env(@otp_app, :amqp) || []
    {:ok, connection} = AMQP.Connection.open(amqp_opts)

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: BackendOne.Worker.start_link(arg1, arg2, arg3)
      # worker(BackendOne.Worker, [arg1, arg2, arg3]),
      supervisor(BackendOne.AMQPSupervisor, [connection]),
    ]


    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BackendOne.Supervisor]
    {:ok, pid } = Supervisor.start_link(children, opts)
    {:ok, pid, %{connection: connection}}
  end

  def stop(state) do
    Logger.debug("Stop application and close connection ...")
    ret = AMQP.Connection.close(state.connection)
    Logger.debug(ret)
  end
end
