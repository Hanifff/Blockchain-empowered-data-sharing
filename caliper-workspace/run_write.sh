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

declare -a sizes=('data1024B' 'data2kB' 'data3kB' 'data4kB' 'data5kB' 'data8kB')

# reconfigure the network config file with new secret key
python3 -c "import bench_config; bench_config.reconfig_network()"

# 1 - benchmark different data sizes (takes more than 14937).
for i in "${sizes[@]}"; do
    export COLLECTION_TYPE="$i"
    echo "Running tests for collection: $i, nr of clients: 10, and fixed tps rate: 1000"
    # run the caliper cli
    npx caliper launch manager --caliper-workspace ./ --caliper-networkconfig networks/networkConfig.yaml \
    --caliper-benchconfig benchmarks/bench_write.yaml --caliper-flow-only-test --caliper-fabric-gateway-enabled \
    --caliper-report-path results_write/report_"$i"_write.html
    # sleep for 5 sec before restarting
    sleep 3
done


# 2 - benchmark for network 3 org

# Totally reset the network and add the third organization and deploy it on the channel (takes more than 2 hours).
pushd ../my-off-cc
./addorg.sh
popd

# reconfigure the network config file with new secret key
python3 -c "import bench_config; bench_config.reconfig_network()"

# 1 - benchmark different data sizes.
for i in "${sizes[@]}"; do
    export COLLECTION_TYPE="$i"
    echo "Running tests for collection: $i, nr of clients: 10, and fixed tps rate: 1000"
    # run the caliper cli
    npx caliper launch manager --caliper-workspace ./ --caliper-networkconfig networks/networkConfig.yaml \
    --caliper-benchconfig benchmarks/bench_write.yaml --caliper-flow-only-test --caliper-fabric-gateway-enabled \
    --caliper-report-path results_write/report_3org_"$i"_write.html
    # sleep for 5 sec before restarting
    sleep 3
done

# clean up config files
clean_up


# 3 - benchmark by changing block size by varying batch timeout and batch size (takes normally 15000 seconds).
declare -a blockSizes=('10' '100' '250' '500' '600' '700' '800' '900' '1000')
declare -a batchTimeOuts=('1s' '2s' '3s' '4s')
export COLLECTION_TYPE="data1024B"
python3 -c "import bench_config; bench_config.reconfig_network()"

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
        --caliper-benchconfig benchmarks/bench_write.yaml --caliper-flow-only-test --caliper-fabric-gateway-enabled \
        --caliper-report-path results_write/report_3org_1024kb_write_"$i"_bsize__"$j"_btimeout.html
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
