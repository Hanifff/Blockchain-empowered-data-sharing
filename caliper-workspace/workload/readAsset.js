'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');
const { ENOBUFS } = require('constants');
require('dotenv').config();

class MyWorkload extends WorkloadModuleBase {
    constructor(chaindata) {
        super();
        this.chaindata = chaindata;
        const dataType = process.env.COLLECTION_TYPE;
        this.data = chaindata[dataType];
        console.log("data size: ", dataType);
    }


    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        for (let i = 0; i < this.roundArguments.assets; i++) {
            const assetID = `${this.workerIndex}_${i}` + this.data;
            //console.log(`Worker ${this.workerIndex}: Creating asset ${assetID}`);
            const request = {
                contractId: this.roundArguments.contractId,
                contractFunction: 'CreateAsset',
                invokerIdentity: 'User1',
                contractArguments: [assetID, 'owner'],
                readOnly: false
            };

            await this.sutAdapter.sendRequests(request);
        }
    }

    async submitTransaction() {
        const randomId = Math.floor(Math.random() * this.roundArguments.assets);
        const assetID = `${this.workerIndex}_${randomId}` + this.data;
        const myArgs = {
            contractId: this.roundArguments.contractId,
            contractFunction: 'ReadAsset',
            invokerIdentity: 'User1',
            contractArguments: [assetID],
            readOnly: true
        };

        await this.sutAdapter.sendRequests(myArgs);
    }

    async cleanupWorkloadModule() {
        for (let i = 0; i < this.roundArguments.assets; i++) {
            const assetID = `${this.workerIndex}_${i}` + this.data;
            //console.log(`Worker ${this.workerIndex}: Deleting asset ${assetID}`);
            const request = {
                contractId: this.roundArguments.contractId,
                contractFunction: 'DeleteAsset',
                invokerIdentity: 'User1',
                contractArguments: [assetID],
                readOnly: false
            };
            await this.sutAdapter.sendRequests(request);
        }
    }
}

const chaindata = {
    'data1024B': "a".repeat(1024),
    'data2kB': "a".repeat(2048),
    'data3kB': "a".repeat(3056),
    'data4kB': "a".repeat(4128),
    'data5kB': "a".repeat(5120),
};

function createWorkloadModule() {
    return new MyWorkload(chaindata);
}


module.exports.createWorkloadModule = createWorkloadModule;
