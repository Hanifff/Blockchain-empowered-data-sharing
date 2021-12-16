#!/bin/bash

# This file runs the benchmark module with different setups

# Exit on first error
set -e
starttime=$(date +%s)

clean_up()
{
    rm -rf ../test-network/modified_config.json
    rm -rf ../test-network/modified_config.pb
    rm -rf ../test-network/config.pb
    rm -rf ../test-network/config.json
    rm -rf ../test-network/config_update_in_envelope.json
    rm -rf ../test-network/config_update_in_envelope.pb
    rm -rf ../test-network/config_block.json
    rm -rf ../test-network/config_block.pb
} 

declare -a sizes=('data1024B' 'data2kB' 'data3kB' 'data4kB' 'data5kB')
declare -a clients=('2' '10' '20' '50')
declare -a tps=('25' '50' '100' '200')

# reconfigure the network config file with new secret key
python3 -c "import bench_config; bench_config.reconfig_network()"

# 1 - benchmark different combinations of tps, number of clients, and data sizes (takes more than 4 hours).
for i in "${sizes[@]}"; do
    export COLLECTION_TYPE="$i"
    for j in "${clients[@]}"; do
        export NR_OF_CLINETS="$j"
        for h in "${tps[@]}"; do
            export TPS_Caliper="$h"
            echo "Running tests for collection: $i, nr of clients: $j, and tps: $h"
            # rewrite the benchmark configuration 
            python3 -c  "import bench_config; bench_config.reconfig_benchmark()"
            # sleep for 10 second for configuration to be applied
            sleep 10
            # run the caliper cli
            npx caliper launch manager --caliper-workspace ./ --caliper-networkconfig networks/networkConfig.yaml \
            --caliper-benchconfig benchmarks/bench_read.yaml --caliper-flow-only-test --caliper-fabric-gateway-enabled \
            --caliper-report-path results/report_"$i"_"$j"_c_"$h"_tps.html
            # sleep for 5 sec before restarting
            sleep 5
        done
    done
done


# 2 - benchmark for network 3 org

# Totally reset the network and add the third organization and deploy it on the channel  (takes more than 2 hours).
pushd ../my-off-cc
./addOrg.sh
popd

declare -a tps=('25' '50' '100' '200')
export COLLECTION_TYPE="data1024B"
export NR_OF_CLINETS="10"

for h in "${tps[@]}"; do
    export TPS_Caliper="$h"
    echo "Running tests for 3 organisations with tps: $h"
    # rewrite the benchmark configuration 
    python3 -c  "import bench_config; bench_config.reconfig_benchmark()"
    # sleep for 10 second for configuration to be applied
    sleep 5
    # run the caliper cli
    npx caliper launch manager --caliper-workspace ./ --caliper-networkconfig networks/networkConfig.yaml \
    --caliper-benchconfig benchmarks/bench_read.yaml --caliper-flow-only-test --caliper-fabric-gateway-enabled \
    --caliper-report-path results/report_3org_BSc_20_xxx_1024kb_10cli_"$h"_tps.html
    # sleep for 5 sec before restarting
    sleep 5
done

# clean up config files
clean_up


# 3 - benchmark by changing block size by varying batch timeout and batch size  (takes more than 4 hours).
declare -a blockSizes=('10' '100' '250' '500')
declare -a batchTimeOuts=('1s' '2s' '3s' '4s')
export TPS_Caliper='500'
export COLLECTION_TYPE="data1024B"
export NR_OF_CLINETS="50"
python3 -c "import bench_config; bench_config.reconfig_network()"
python3 -c  "import bench_config; bench_config.reconfig_benchmark()"

for i in "${blockSizes[@]}"; do
    export MAX_BLOCKS="$i"
    for j in "${batchTimeOuts[@]}"; do
        clean_up
        export MY_B_TIMEOUT="$j"
        echo "Running tests for 3 organisations with block size: $h"
        echo "Reconfiguering the channel..."
        # rewrite the channel configuration 
        pushd ../my-off-cc
        ./reconf_step1.sh
        popd
        sleep 2
        python3 -c "import bench_config; bench_config.reconfig_channel_blocksize()"
        sleep 2
        pushd ../my-off-cc
        ./reconf_step2.sh
        popd
        
        # sleep for 5 second for configuration to be applied
        sleep 5
        echo "Reconfiguerations done."
        echo "Benchmarking..."
        # run the caliper cli
        npx caliper launch manager --caliper-workspace ./ --caliper-networkconfig networks/networkConfig.yaml \
        --caliper-benchconfig benchmarks/bench_read.yaml --caliper-flow-only-test --caliper-fabric-gateway-enabled \
        --caliper-report-path results_bs/report_3org_1024kb_50cli_"$i"_bsize__"$j"_btimeout.html
        # sleep for 5 sec before restarting
        sleep 5
    done
done



# TODO: For master thesis
# Benchmark by adding peers
# Benchmark by adding orderers
# Benchmark by adding database**
cat <<EOF

    Total setup execution time : $(($(date +%s) - starttime)) secs ...

    Then, to see the results:
        Open the "./results/report_xx.html" file(s).


EOF
