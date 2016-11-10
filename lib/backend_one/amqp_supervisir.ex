defmodule BackendOne.AMQPSupervisor do
  use Supervisor

  @otp_app Mix.Project.config[:app]

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    amqp_opts = Application.get_env(@otp_app, :amqp) || []
    {:ok, connection} = AMQP.Connection.open(amqp_opts)

    children = [
      worker(BackendOne.FinancialConsumer, [[connection]]),
      worker(BackendOne.DeviceConsumer, [[connection]]),
      # worker(OrbitaNotifications.NotificationConsumer, [[connection]]),
      # worker(OrbitaNotifications.WsProxyConsumer, [[connection]]),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
