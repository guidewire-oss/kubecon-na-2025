"aws-dynamodb-kro": {
	alias: ""
	annotations: {}
	attributes: {
		workload: {
			type: "autodetects.core.oam.dev"
		}
		status: {
			healthPolicy: #"""
				isHealth: *false | bool
				if context.output.status.state != _|_ {
					if context.output.status.state == "ACTIVE" {
						isHealth: true
					}
				}
				"""#
			customStatus: #"""
				tableArn: *"" | string
				tableState: *"Unknown" | string

				if context.output.status.tableArn != _|_ {
					tableArn: context.output.status.tableArn
				}
				if context.output.status.state != _|_ {
					tableState: context.output.status.state
				}

				if context.status.healthy {
					message: "Table ACTIVE - ARN: \(tableArn)"
				}
				if !context.status.healthy {
					message: "Table provisioning - State: \(tableState)"
					if context.output.status.conditions != _|_ {
						if len(context.output.status.conditions) > 0 {
							message: context.output.status.conditions[0].message
						}
					}
				}
				"""#
		}
	}
	description: "AWS DynamoDB table managed by KRO (Kube Resource Orchestrator) and ACK (AWS Controllers for Kubernetes)"
	annotations: {}
	type: "component"
}

template: {
	output: {
		apiVersion: "kro.run/v1alpha1"
		kind:       "DynamoDBTable"
		metadata: {
			name: context.name
		}
		spec: {
			// Table identification - automatically add tenant-atlantis- prefix
			tableName: "tenant-atlantis-\(parameter.tableName)"
			region:    parameter.region

			// Billing configuration
			if parameter.billingMode != _|_ {
				billingMode: parameter.billingMode
			}
			if parameter.billingMode == "PROVISIONED" && parameter.provisionedThroughput != _|_ {
				provisionedThroughput: parameter.provisionedThroughput
			}

			// Key schema and attributes
			attributeDefinitions: parameter.attributeDefinitions
			keySchema:            parameter.keySchema

			// Secondary indexes
			if parameter.globalSecondaryIndexes != _|_ {
				globalSecondaryIndexes: parameter.globalSecondaryIndexes
			}
			if parameter.localSecondaryIndexes != _|_ {
				localSecondaryIndexes: parameter.localSecondaryIndexes
			}

			// Stream configuration (traits can set this, default in RGD schema)
			// Don't set a value here to avoid conflicts with trait patches

			// Point-in-time recovery (traits can set this, default in RGD schema)
			// Don't set a value here to avoid conflicts with trait patches

			// Server-side encryption (traits can set this, default in RGD schema)
			// Don't set a value here to avoid conflicts with trait patches
			if parameter.sseType != _|_ {
				sseType: parameter.sseType
			}
			if parameter.kmsMasterKeyID != _|_ {
				kmsMasterKeyID: parameter.kmsMasterKeyID
			}

			// Time to live (traits can set this, default in RGD schema)
			// Don't set a value here to avoid conflicts with trait patches
			if parameter.ttlAttributeName != _|_ {
				ttlAttributeName: parameter.ttlAttributeName
			}

			// Deletion protection (traits can set this, default in RGD schema)
			// Don't set a value here to avoid conflicts with trait patches

			// Table class
			if parameter.tableClass != _|_ {
				tableClass: parameter.tableClass
			}

			// Tags
			if parameter.tags != _|_ {
				tags: parameter.tags
			}

			// Provider configuration
			if parameter.providerConfigRef != _|_ {
				providerConfigRef: parameter.providerConfigRef
			}

			// Connection secret
			if parameter.writeConnectionSecretToRef != _|_ {
				writeConnectionSecretToRef: parameter.writeConnectionSecretToRef
			}
		}
	}

	// NOTE: The ResourceGraphDefinition (RGD) should be deployed separately,
	// not as part of the component outputs. The RGD is deployed once globally
	// via definitions/kro/dynamodb-rgd.yaml, and this component just creates
	// instances of the DynamoDBTable CRD that the RGD defines.

	parameter: {
		// Required fields
		// +usage=The name of the DynamoDB table
		tableName: string

		// +usage=AWS region for the table
		region: string

		// +usage=Billing mode: PAY_PER_REQUEST or PROVISIONED
		billingMode: *"PAY_PER_REQUEST" | "PROVISIONED"

		// +usage=Array of attribute definitions
		attributeDefinitions: [...{
			attributeName: string
			attributeType: string
		}]

		// +usage=Primary key schema
		keySchema: [...{
			attributeName: string
			keyType:       string
		}]

		// Optional: Provisioned throughput (only for PROVISIONED billing mode)
		provisionedThroughput?: {
			// +usage=Read capacity units
			readCapacityUnits: int
			// +usage=Write capacity units
			writeCapacityUnits: int
		}

		// Optional: Global secondary indexes
		globalSecondaryIndexes?: [...{
			indexName: string
			keySchema: [...{
				attributeName: string
				keyType:       string
			}]
			projection: {
				projectionType:    string
				nonKeyAttributes?: [...string]
			}
			provisionedThroughput?: {
				readCapacityUnits:  int
				writeCapacityUnits: int
			}
		}]

		// Optional: Local secondary indexes
		localSecondaryIndexes?: [...{
			indexName: string
			keySchema: [...{
				attributeName: string
				keyType:       string
			}]
			projection: {
				projectionType:    string
				nonKeyAttributes?: [...string]
			}
		}]

		// Optional: Streams
		// +usage=Enable DynamoDB streams
		streamEnabled?: *false | bool

		// +usage=Stream view type (KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES)
		streamViewType?: string

		// Optional: Point-in-time recovery
		// +usage=Enable point-in-time recovery
		pointInTimeRecoveryEnabled?: *false | bool

		// Optional: Server-side encryption
		// +usage=Enable server-side encryption
		sseEnabled?: *false | bool

		// +usage=Encryption type (AES256 or KMS)
		sseType?: string

		// +usage=KMS master key ID for encryption
		kmsMasterKeyID?: string

		// Optional: Time to live
		// +usage=Enable time to live
		ttlEnabled?: *false | bool

		// +usage=Attribute name for TTL
		ttlAttributeName?: string

		// Optional: Deletion protection
		// +usage=Enable deletion protection
		deletionProtectionEnabled?: *false | bool

		// Optional: Table class
		// +usage=Table class (STANDARD or STANDARD_INFREQUENT_ACCESS)
		tableClass?: string

		// Optional: Tags
		// +usage=Resource tags
		tags?: [...{
			key:   string
			value: string
		}]

		// Optional: Provider configuration
		// +usage=Reference to provider configuration
		providerConfigRef?: {
			name: string
		}

		// Optional: Connection secret
		// +usage=Write connection details to secret
		writeConnectionSecretToRef?: {
			name:      string
			namespace: string
		}
	}
}
