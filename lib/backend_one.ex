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
    {:ok, channel} = AMQP.Channel.open(connection)


    pid = spawn(BackendOne.Accumulator, :run, [channel])
    Process.register(pid, BackendOne.Accumulator)
    Logger.debug("Accumulator registered!!!")

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: BackendOne.Worker.start_link(arg1, arg2, arg3)
      # worker(BackendOne.Worker, [arg1, arg2, arg3]),
      supervisor(BackendOne.AMQPSupervisor, []),
    ]


    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BackendOne.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
