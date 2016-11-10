# BackendOne

Clone the project and the execute:

```shell
$ mix deps.get
$ mix compile
```

If you want start with console you can use this command line:

```shell
$ AMQP_HOST=<rabbit-ip> AMQP_USERNAME=<rabbit-username> AMQP_PASSWORD=<rabbit-password> iex -S mix
```

# Execute test
```shell
$ AMQP_HOST=<rabbit-ip> AMQP_USERNAME=<rabbit-username> AMQP_PASSWORD=<rabbit-password> mix test
```
