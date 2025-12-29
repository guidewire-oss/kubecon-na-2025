"aws-dynamodb-xp": {
    annotations: {}
    attributes: {
        workload: {
            definition: {
                apiVersion: "dynamodb.aws.upbound.io/v1beta1"
                kind:       "Table"
            }
        }
        status: {
            details: #"""
                // Public fields - exported to Application status
                tableArn: *context.output.status.atProvider.tableArn | ""
                tableStatus: *context.output.status.atProvider.tableStatus | "CREATING"
                itemCount: *context.output.status.atProvider.itemCount | 0
                tableSizeBytes: *context.output.status.atProvider.tableSizeBytes | 0

                // Local fields - for health check logic
                $statusConditions: *context.output.status.conditions | []
                """#

            healthPolicy: #"""
                isHealth: len(context.status.details.$statusConditions) > 0 &&
                          context.status.details.$statusConditions[0].status == "True" &&
                          context.status.details.tableStatus == "ACTIVE"
                """#

            customStatus: #"""
                if context.status.healthy {
                    message: "Table ACTIVE: \(context.status.details.itemCount) items, \(context.status.details.tableSizeBytes) bytes, ARN: \(context.status.details.tableArn)"
                }
                if !context.status.healthy {
                    message: "Table status: \(context.status.details.tableStatus) - waiting for ACTIVE state"
                }
                """#
        }
    }
    description: "AWS DynamoDB table managed by Crossplane for NoSQL database workloads with automatic scaling"
    annotations: {}
    type: "component"
}

template: {
    output: {
        apiVersion: "dynamodb.aws.upbound.io/v1beta1"
        kind:       "Table"
        metadata: {
            name: context.name
        }
        spec: {
            forProvider: {
                region: parameter.region

                attributeDefinitions: parameter.attributeDefinitions
                keySchema: parameter.keySchema

                // Default to PAY_PER_REQUEST, but allow override from parameter or trait
                billingMode: *"PAY_PER_REQUEST" | string
                if parameter.billingMode != _|_ {
                    billingMode: parameter.billingMode
                }

                if parameter.tableClass != _|_ {
                    tableClass: parameter.tableClass
                }

                // Convert tags array to object format for Upbound provider
                if parameter.tags != _|_ {
                    tags: {
                        for tag in parameter.tags {
                            "\(tag.key)": tag.value
                        }
                    }
                }
            }

            providerConfigRef: {
                name: *parameter.providerConfigRef | "default"
            }
        }
    }

    parameter: {
        // +usage=AWS region where the DynamoDB table will be created (e.g., us-east-1, us-west-2)
        region: string

        // +usage=Array of attribute definitions for the table's keys and indexes
        attributeDefinitions: [...{
            // +usage=Name of the attribute
            attributeName: string
            // +usage=Data type of the attribute: S (string), N (number), or B (binary)
            attributeType: "S" | "N" | "B"
        }]

        // +usage=Primary key schema for the table (partition key required, sort key optional)
        keySchema: [...{
            // +usage=Name of the attribute to use as a key
            attributeName: string
            // +usage=Key type: HASH (partition key) or RANGE (sort key)
            keyType: "HASH" | "RANGE"
        }]

        // +usage=Billing mode: PAY_PER_REQUEST (on-demand) or PROVISIONED (requires capacity settings)
        billingMode?: "PAY_PER_REQUEST" | "PROVISIONED"

        // +usage=Table class: STANDARD (default) or STANDARD_INFREQUENT_ACCESS (for rarely accessed data)
        tableClass?: "STANDARD" | "STANDARD_INFREQUENT_ACCESS"

        // +usage=Key-value tags for organizing and managing the table
        tags?: [...{
            // +usage=Tag key
            key: string
            // +usage=Tag value
            value: string
        }]

        // +usage=Crossplane provider config reference name
        providerConfigRef?: string
    }
}
