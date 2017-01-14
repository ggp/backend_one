# BackendOne

##Compile the cloned project
```shell
mix deps.get
mix compile
```


## Run all tests

**Windows**
```shell
SET AMQP_HOST=`<rabbit-ip>`
SET AMQP_USERNAME=`<rabbit-username>`
SET AMQP_PASSWORD=`<rabbit-password>`
mix test
```

**Unix/Linux/macOS**
```shell
AMQP_HOST=`<rabbit-ip>` AMQP_USERNAME=`<rabbit-username>` AMQP_PASSWORD=`<rabbit-password>` mix test
```


## Start in console mode

**Windows**
```shell
SET AMQP_HOST=`<rabbit-ip>`
SET AMQP_USERNAME=`<rabbit-username>`
SET AMQP_PASSWORD=`<rabbit-password>`
iex -S mix
```

**Unix/Linux/macOS**
```shell
AMQP_HOST=`<rabbit-ip>` AMQP_USERNAME=`<rabbit-username>` AMQP_PASSWORD=`<rabbit-password>` iex -S mix
```