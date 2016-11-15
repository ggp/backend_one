# BackendOne

Compile the cloned project:
```shell
mix deps.get
mix compile
```

Set the following AMQP related environment variables:
* AMQP_HOST=`<rabbit-ip>`
* AMQP_USERNAME=`<rabbit-username>`
* AMQP_PASSWORD=`<rabbit-password>`

Run all tests:
```shell
mix test
```

To start in console mode:
```shell
iex -S mix
```
