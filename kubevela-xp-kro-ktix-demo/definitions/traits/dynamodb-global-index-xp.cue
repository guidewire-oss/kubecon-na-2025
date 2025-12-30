"dynamodb-global-index-xp": {
    annotations: {}
    description: "Add global secondary indexes to DynamoDB table for alternate query patterns (increases costs with additional read/write capacity)"
    annotations: {}
    type: "trait"
}

template: {
    patch: {
        spec: forProvider: {
            globalSecondaryIndex: [
                for idx in parameter.indexes {
                    name: idx.indexName
                    hashKey: idx.keySchema[0].attributeName
                    if len(idx.keySchema) > 1 {
                        rangeKey: idx.keySchema[1].attributeName
                    }
                    projectionType: idx.projection.projectionType
                    if idx.projection.nonKeyAttributes != _|_ {
                        nonKeyAttributes: idx.projection.nonKeyAttributes
                    }
                    if idx.provisionedThroughput != _|_ {
                        readCapacity: idx.provisionedThroughput.readCapacityUnits
                        writeCapacity: idx.provisionedThroughput.writeCapacityUnits
                    }
                }
            ]
        }
    }

    parameter: {
        // +usage=Array of global secondary indexes to create (max 20 per table)
        indexes: [...{
            // +usage=Name of the global secondary index
            indexName: string

            // +usage=Key schema for the index (partition key required, sort key optional)
            keySchema: [...{
                // +usage=Attribute name for the key
                attributeName: string
                // +usage=Key type: HASH (partition) or RANGE (sort)
                keyType: "HASH" | "RANGE"
            }]

            // +usage=Attributes to project into the index: ALL, KEYS_ONLY, or INCLUDE
            projection: {
                // +usage=Projection type
                projectionType: "ALL" | "KEYS_ONLY" | "INCLUDE"
                // +usage=Non-key attributes to include (only for INCLUDE projection type)
                nonKeyAttributes?: [...string]
            }

            // +usage=Provisioned throughput for the index (required if table uses PROVISIONED billing)
            provisionedThroughput?: {
                // +usage=Read capacity units for the index
                readCapacityUnits: int & >0
                // +usage=Write capacity units for the index
                writeCapacityUnits: int & >0
            }
        }]
    }
}
