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
        this.randomIds = [];
    }


    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        const assetID = `${this.workerIndex}_${'id'}` + this.data;
        //console.log(`Worker ${this.workerIndex}: Creating asset ${assetID}`);
        const request = {
            contractId: this.roundArguments.contractId,
            contractFunction: 'CreateAsset',
            invokerIdentity: 'User1',
            contractArguments: [assetID, 'owner'],
            readOnly: false,
            timeout: 60
        }
        await this.sutAdapter.sendRequests(request);
    }

    async submitTransaction() {
        var randomId = Math.floor(Math.random() * this.roundArguments.assets);
        while (this.randomIds.includes(randomId)) {
            randomId = Math.floor(Math.random() * this.roundArguments.assets);
        }
        this.randomIds.push(randomId);
        const assetID = `${this.workerIndex}_${randomId}` + this.data;
        //console.log(`Worker ${this.workerIndex}: Creating asset ${assetID}`);
        const myArgs = {
            contractId: this.roundArguments.contractId,
            contractFunction: 'CreateAsset',
            invokerIdentity: 'User1',
            contractArguments: [assetID, 'owner'],
            readOnly: false,
            timeout: 60
        };
        await this.sutAdapter.sendRequests(myArgs);
    }

    async cleanupWorkloadModule() {
        for (let i = 0; i < this.roundArguments.assets; i++) {
            // check if asset exist
            if (this.randomIds.includes(i)) {
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
        const assetID = `${this.workerIndex}_${'id'}` + this.data;
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
const chaindata = {
    'data1024B': "a".repeat(1024),
    'data2kB': "a".repeat(2000),
    'data3kB': "a".repeat(3000),
    'data4kB': "a".repeat(4000),
    'data5kB': "a".repeat(5000),
    'data6kB': "a".repeat(6000),
    'data8kB': "a".repeat(8000),
};

function createWorkloadModule() {
    return new MyWorkload(chaindata);
}


module.exports.createWorkloadModule = createWorkloadModule;
