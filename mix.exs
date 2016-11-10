defmodule BackendOne.Mixfile do
  use Mix.Project

  def project do
    [app: :backend_one,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :amqp, :timex, :edeliver, :logger_file_backend, :poison],
     mod: {BackendOne, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:amqp, "~> 0.1.5"},
      #https://github.com/pma/amqp/issues/28
      {:amqp_client, git: "https://github.com/dsrosario/amqp_client.git", branch: "erlang_otp_19", override: true},
      {:timex, "~> 3.0"},
      {:edeliver, "~> 1.4.0"},
      {:distillery, ">= 0.8.0", warn_missing: false},
      {:logger_file_backend, "~> 0.0.9"},
      {:poison, "~> 3.0"},
    ]
  end
end
