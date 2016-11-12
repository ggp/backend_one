defmodule BackendOne.AMQPSupervisor do
  use Supervisor

  @otp_app Mix.Project.config[:app]

  def start_link(connection) do
    Supervisor.start_link(__MODULE__, [connection])
  end

  def init([connection]) do

    {:ok, channel} = AMQP.Channel.open(connection)
    publisher = fn msg ->
      RabbitMQPublisher.publish_stats(channel, msg)
    end

    children = [
      worker(BackendOne.FinancialConsumer, [[connection]]),
      worker(BackendOne.DeviceConsumer, [[connection]]),
      worker(BackendOne.AccumulatorService, [[publisher]]),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
