"dynamodb-local-index-xp": {
    annotations: {}
    description: "Add local secondary indexes to DynamoDB table for alternate sort key queries (max 5 per table, 10GB per partition)"
    type: "trait"
}

template: {
    patch: {
        spec: forProvider: {
            localSecondaryIndexes: parameter.indexes
        }
    }

    parameter: {
        // +usage=Array of local secondary indexes to create (max 5 per table)
        indexes: [...{
            // +usage=Name of the local secondary index
            indexName: string

            // +usage=Key schema for the index (must use same partition key as table, different sort key)
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
        }]
    }
}
