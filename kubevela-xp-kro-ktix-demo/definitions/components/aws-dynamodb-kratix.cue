// KubeVela ComponentDefinition for DynamoDB using Kratix Promise
// This component generates a Kratix DynamoDBRequest that will be processed
// by the aws-dynamodb-kratix Promise to create an actual DynamoDB table.

"aws-dynamodb-kratix": {
	annotations: {}
	attributes: {
		workload: {
			definition: {
				apiVersion: "dynamodb.kratix.io/v1alpha1"
				kind:       "DynamoDBRequest"
			}
		}
	}
	description: "DynamoDB table created via Kratix Promise"
	type:        "component"
}

template: {
	output: {
		apiVersion: "dynamodb.kratix.io/v1alpha1"
		kind:       "DynamoDBRequest"
		metadata: {
			name:      context.name
			namespace: context.namespace
		}
		spec: {
			name:                  parameter.tableName
			region:                parameter.region
			billingMode:           parameter.billingMode
			attributeDefinitions:  parameter.attributeDefinitions
			keySchema:             parameter.keySchema
			if parameter.billingMode == "PROVISIONED" {
				provisioned: {
					readCapacity:  parameter.provisioned.readCapacity
					writeCapacity: parameter.provisioned.writeCapacity
				}
			}
		}
	}

	parameter: {
		// Required parameters
		tableName: string
		region: "us-east-1" | "us-east-2" | "us-west-1" | "us-west-2" |
		         "eu-west-1" | "eu-central-1" |
		         "ap-southeast-1" | "ap-northeast-1" | "ap-south-1"

		// Billing mode configuration
		billingMode: *"PAY_PER_REQUEST" | "PROVISIONED"

		// Attribute definitions (name and type: S/N/B)
		attributeDefinitions: [...{
			name: string
			type: "S" | "N" | "B"
		}]

		// Key schema (partition and optional sort key)
		keySchema: [...{
			attributeName: string
			keyType:       "HASH" | "RANGE"
		}]

		// Provisioned throughput (only used when billingMode is PROVISIONED)
		provisioned?: {
			readCapacity:  *5 | int & >=1 & <=40000
			writeCapacity: *5 | int & >=1 & <=40000
		}
	}
}
