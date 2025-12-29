"dynamodb-provisioned-capacity-xp": {
    annotations: {}
    description: "Configure provisioned throughput capacity for DynamoDB table (cost control for predictable workloads)"
    annotations: {}
    type: "trait"
}

template: {
    patch: {
        spec: forProvider: {
            // Override billing mode to PROVISIONED
            billingMode: "PROVISIONED"

            // Set provisioned throughput
            provisionedThroughput: {
                readCapacityUnits: parameter.readCapacityUnits
                writeCapacityUnits: parameter.writeCapacityUnits
            }
        }
    }

    parameter: {
        // +usage=Number of read capacity units (RCU) for the table
        readCapacityUnits: int & >0

        // +usage=Number of write capacity units (WCU) for the table
        writeCapacityUnits: int & >0
    }
}
