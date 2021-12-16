package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/hyperledger/fabric-sdk-go/pkg/core/config"
	"github.com/hyperledger/fabric-sdk-go/pkg/gateway"
	//"reflect"
)

func main() {
	db, err := NewOffchainDB("root", "password", "tcp", "127.0.0.1:3306", "offchain")
	if err != nil {
		log.Printf("Something went wrong while connectig to the database.\n%v", err)
		return
	}
	defer db.Conn.Close()

	network, err := configNet()
	contract := network.GetContract("basic")
	//fmt.Println("network type : ",  reflect.TypeOf(contract))

	log.Println("--> Submit Transaction: InitLedger")
	result, err := contract.SubmitTransaction("InitLedger")
	if err != nil {
		log.Fatalf("Failed to Submit transaction: %v", err)
	}
	log.Println(string(result))

	log.Println("--> Evaluate Transaction: GetAllAssets")
	result, err = contract.EvaluateTransaction("GetAllAssets")
	if err != nil {
		log.Fatalf("Failed to evaluate transaction: %v", err)
	}
	log.Println(string(result))
	reader := bufio.NewReader(os.Stdin)
	// start the main idea: take the hash of data, store the hash on chain and data along with its hash in database.
	for i := 0; i < 5; i++ {
		log.Println("Pleae enter:  owner name, data to store")
		userInput, err := reader.ReadString('\n')
		if err != nil {
			return
		}
		// remove the delimeter from the string
		userInput = strings.TrimSuffix(userInput, "\n")
		// store the data along with its hash in the database
		owner, data := intData(userInput)
		ID := hashTxn(data)
		err = db.InsertData(ID, data)
		if err != nil {
			log.Printf("%v\n", err)
			return
		}

		log.Println("--> Submit Transaction to on chain!")
		result, err = contract.SubmitTransaction("CreateAsset", ID, owner)
		if err != nil {
			log.Fatalf("Failed to Submit transaction: %v", err)
		}
		log.Println("Asset is created: ", string(result))

		log.Println("--> Evaluate Transaction on chain!")
		result, err = contract.EvaluateTransaction("ReadAsset", ID)
		if err != nil {
			log.Fatalf("Failed to evaluate transaction: %v", err)
		}
		log.Printf("Transaction %s, is verfied!\n", string(result))
	}

	err = db.ReadAllData()
	if err != nil {
		log.Printf("%v", err)
		return
	}

	log.Println("Verifying data stored in Database and linked to chain;\nPlease provid Transaction ID:")
	txid, err := reader.ReadString('\n')
	if err != nil {
		return
	}
	txid = strings.TrimSuffix(txid, "\n")
	verifyTxn(txid, contract, db)
}

// configNet initalizes and configures the network and identity.
func configNet() (*gateway.Network, error) {
	err := os.Setenv("DISCOVERY_AS_LOCALHOST", "true")
	if err != nil {
		log.Fatalf("Error setting DISCOVERY_AS_LOCALHOST environemnt variable: %v", err)
	}

	wallet, err := gateway.NewFileSystemWallet("wallet")
	if err != nil {
		log.Fatalf("Failed to create wallet: %v", err)
	}

	if !wallet.Exists("appUser") {
		err = populateWallet(wallet)
		if err != nil {
			log.Fatalf("Failed to populate wallet contents: %v", err)
		}
	}

	ccpPath := filepath.Join(
		"..",
		"..",
		"test-network",
		"organizations",
		"peerOrganizations",
		"org1.example.com",
		"connection-org1.yaml",
	)

	gw, err := gateway.Connect(
		gateway.WithConfig(config.FromFile(filepath.Clean(ccpPath))),
		gateway.WithIdentity(wallet, "appUser"),
	)
	if err != nil {
		log.Fatalf("Failed to connect to gateway: %v", err)
	}
	defer gw.Close()

	network, err := gw.GetNetwork("mychannel")
	if err != nil {
		log.Fatalf("Failed to get network: %v", err)
	}
	return network, nil
}

// populateWallet populates a wallet in case it is not configuered already.
func populateWallet(wallet *gateway.Wallet) error {
	credPath := filepath.Join(
		"..",
		"..",
		"test-network",
		"organizations",
		"peerOrganizations",
		"org1.example.com",
		"users",
		"User1@org1.example.com",
		"msp",
	)

	certPath := filepath.Join(credPath, "signcerts", "cert.pem")
	// read the certificate pem
	cert, err := ioutil.ReadFile(filepath.Clean(certPath))
	if err != nil {
		return err
	}

	keyDir := filepath.Join(credPath, "keystore")
	// there's a single file in this dir containing the private key
	files, err := ioutil.ReadDir(keyDir)
	if err != nil {
		return err
	}
	if len(files) != 1 {
		return fmt.Errorf("keystore folder should have contain one file")
	}
	keyPath := filepath.Join(keyDir, files[0].Name())
	key, err := ioutil.ReadFile(filepath.Clean(keyPath))
	if err != nil {
		return err
	}

	identity := gateway.NewX509Identity("Org1MSP", string(cert), string(key))
	return wallet.Put("appUser", identity)
}

// intData splittes the user input data
func intData(userInput string) (string, string) {
	splitData := strings.Split(userInput, ",")
	owner := splitData[0]
	data := splitData[1]
	return owner, data
}

// hashID hashes the data and returns the hash as ID
func hashTxn(data string) string {
	id_bytes := sha256.Sum256([]byte(data))
	ID := hex.EncodeToString(id_bytes[:])
	return ID
}

// verifyTxn verifies connection between a Transaction on chain and its data in database
func verifyTxn(txid string, contract *gateway.Contract, db *OffchainDB) {
	log.Printf("--> Evaluate Transaction!")
	result, err := contract.EvaluateTransaction("ReadAsset", txid)
	if err != nil {
		log.Fatalf("Failed to evaluate transaction: %v", err)
	}
	log.Printf("Transaction %s, is verfied!\n", string(result))
	err = db.ReadData(txid)
	if err != nil {
		log.Printf("%v", err)
		return
	}
	log.Printf("Transaction connection to database is verified!\n")
}
