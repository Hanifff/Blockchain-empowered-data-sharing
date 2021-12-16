# Blockchain empowered data sharing

This project is a demo application for experiment with [Hyperledger](https://www.hyperledger.org/) blockchain technology. We specifically design an off-chain storage model, where we use a [MySql](https://www.mysql.com/) database to store data and submit light-weighted transactions to the blockchain with only the hash of data.<br/>

Please be aware that this project contains a Fabric chaincode, application, and a Caliper benchmark module, but, the main concepts and structure is taken from the [Fabric-samples](https://github.com/hyperledger/fabric-samples), [test-network](https://hyperledger-fabric.readthedocs.io/en/release-2.2/test_network.html), and [caliper-workspace](https://hyperledger.github.io/caliper/v0.4.2/getting-started/) examples and instructions.<br>

## Requirements

---

This project is implemented in [Go](https://golang.org/). In addition, we have implemneted an API to an communicate with a MySql server.<br/>
You need to have a fabric network running with at least two peer organizations and an ordering service.<br/>
However, fabric provides a [test network](https://hyperledger-fabric.readthedocs.io/en/release-2.2/test_network.html) which you can run locally and has all required configurations. In the following, we list the requirements for compiling this application:<br>

- cURL — latest version
- Go — version 1.17.x
- Docker Compose — version 1.29.x
- MySql server — 8.0.2x
- Hyperledger Fabric test network<br/>

## Run our demo application

---

Start the MySql server by `/your-path-to-bin/mysql -u username -p password`, by replacing username and password with yours.<br>
If you are using Fabric's test network, you need to put this project in the `Github/your-user-name/fabric-samples/my-simple-offchain/` directory. Then use the following commands to start the test network, configure a channel, deploy the chaincode, and start the application server:<br/>

```shell
cd fabric-samples/test-network
./network.sh up
./network.sh createChannel -c mychannel -ca
./network.sh deployCC -ccn basic -ccp ../my-simple-offchain/chaincode-go -ccl go
cd fabric-samples/my-simple-offchain/application-go
go build
./application-go
```

Alternatively, you can use the script shell file to setup all configurations mentioned above:<br>

```shell
cd fabric-samples/my-simple-offchain
./start.sh
```

You can shot down the network and delete all its dependencies using the following command:<br>

```shell
./shotdown.sh
```

#### Good luck :-)
