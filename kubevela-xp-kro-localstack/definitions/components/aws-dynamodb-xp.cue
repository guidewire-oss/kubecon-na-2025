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
            healthPolicy: #"""
                isHealth: *false | bool
                if context.output.status.conditions != _|_ {
                    // Check if Ready condition exists and is True
                    if len(context.output.status.conditions) > 0 {
                        for i, cond in context.output.status.conditions {
                            if cond.type == "Ready" && cond.status == "True" {
                                isHealth: true
                            }
                        }
                    }
                }
                """#

            customStatus: #"""
                ready: *"Unknown" | string
                synced: *"Unknown" | string
                tableArn: *"" | string
                tableName: *"" | string

                if context.output.status.atProvider.arn != _|_ {
                    tableArn: context.output.status.atProvider.arn
                }
                if context.output.status.atProvider.id != _|_ {
                    tableName: context.output.status.atProvider.id
                }

                if context.output.status.conditions != _|_ {
                    for i, cond in context.output.status.conditions {
                        if cond.type == "Ready" {
                            ready: cond.status
                        }
                        if cond.type == "Synced" {
                            synced: cond.status
                        }
                    }
                }

                if context.status.healthy {
                    message: "Table ACTIVE - ARN: \(tableArn)"
                }
                if !context.status.healthy {
                    message: "Table provisioning - Ready: \(ready), Synced: \(synced)"
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
            annotations: {
                // Crossplane external-name annotation determines the actual AWS table name
                "crossplane.io/external-name": context.name
            }
        }
        spec: {
            forProvider: {
                region: parameter.region

                // Convert AWS API format to Terraform/Upbound format
                // attributeDefinitions -> attribute (with name/type instead of attributeName/attributeType)
                attribute: [
                    for attr in parameter.attributeDefinitions {
                        name: attr.attributeName
                        type: attr.attributeType
                    }
                ]

                // keySchema -> hashKey/rangeKey
                hashKey: parameter.keySchema[0].attributeName
                if len(parameter.keySchema) > 1 {
                    rangeKey: parameter.keySchema[1].attributeName
                }

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
