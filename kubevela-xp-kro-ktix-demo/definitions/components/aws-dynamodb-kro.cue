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
					if context.output.status.state == "Ready" {
						isHealth: true
					}
				}
				"""#
			customStatus: #"""
				ready: {
					readyReplicas: *0 | int
				} & {
					if context.output.status.state != _|_ {
						if context.output.status.state == "Ready" {
							readyReplicas: 1
						}
					}
				}
				message: *"Provisioning..." | string
				if context.output.status.conditions != _|_ {
					if len(context.output.status.conditions) > 0 {
						message: context.output.status.conditions[0].message
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
			// Table identification
			tableName: parameter.tableName
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

			// Stream configuration (default false, traits can override)
			streamEnabled: false
			if parameter.streamEnabled != _|_ {
				streamEnabled: parameter.streamEnabled
			}
			if parameter.streamViewType != _|_ {
				streamViewType: parameter.streamViewType
			}

			// Point-in-time recovery (default false, traits can override)
			pointInTimeRecoveryEnabled: *false | bool
			if parameter.pointInTimeRecoveryEnabled != _|_ {
				pointInTimeRecoveryEnabled: parameter.pointInTimeRecoveryEnabled
			}

			// Server-side encryption (default false, traits can override)
			sseEnabled: *false | bool
			if parameter.sseEnabled != _|_ {
				sseEnabled: parameter.sseEnabled
			}
			if parameter.sseType != _|_ {
				sseType: parameter.sseType
			}
			if parameter.kmsMasterKeyID != _|_ {
				kmsMasterKeyID: parameter.kmsMasterKeyID
			}

			// Time to live (default false, traits can override)
			ttlEnabled: *false | bool
			if parameter.ttlEnabled != _|_ {
				ttlEnabled: parameter.ttlEnabled
			}
			if parameter.ttlAttributeName != _|_ {
				ttlAttributeName: parameter.ttlAttributeName
			}

			// Deletion protection (default false, traits can override)
			deletionProtectionEnabled: *false | bool
			if parameter.deletionProtectionEnabled != _|_ {
				deletionProtectionEnabled: parameter.deletionProtectionEnabled
			}

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

	outputs: {
		// ResourceGraphDefinition that orchestrates the ACK DynamoDB Table
		"dynamodb-rgd": {
			apiVersion: "kro.run/v1alpha1"
			kind:       "ResourceGraphDefinition"
			metadata: {
				name: "dynamodbtable"
			}
			spec: {
				schema: {
					apiVersion: "v1alpha1"
					kind:       "DynamoDBTable"
					spec: {
						tableName:  "string"
						region:     "string"
						billingMode: "string | default=\"PAY_PER_REQUEST\""

						// Throughput (only for PROVISIONED mode)
						provisionedThroughput: {
							readCapacityUnits:  "integer"
							writeCapacityUnits: "integer"
						}

						// Schema definition
						attributeDefinitions: [{
							attributeName: "string"
							attributeType: "string"
						}]
						keySchema: [{
							attributeName: "string"
							keyType:       "string"
						}]

						// Secondary indexes
						globalSecondaryIndexes: [{
							indexName: "string"
							keySchema: [{
								attributeName: "string"
								keyType:       "string"
							}]
							projection: {
								projectionType:   "string"
								nonKeyAttributes: ["string"]
							}
							provisionedThroughput: {
								readCapacityUnits:  "integer"
								writeCapacityUnits: "integer"
							}
						}]
						localSecondaryIndexes: [{
							indexName: "string"
							keySchema: [{
								attributeName: "string"
								keyType:       "string"
							}]
							projection: {
								projectionType:   "string"
								nonKeyAttributes: ["string"]
							}
						}]

						// Features
						streamEnabled:               "boolean | default=false"
						streamViewType:              "string"
						pointInTimeRecoveryEnabled:  "boolean | default=false"
						sseEnabled:                  "boolean | default=false"
						sseType:                     "string"
						kmsMasterKeyID:              "string"
						ttlEnabled:                  "boolean | default=false"
						ttlAttributeName:            "string"
						deletionProtectionEnabled:   "boolean | default=false"
						tableClass:                  "string"

						// Tags
						tags: [{
							key:   "string"
							value: "string"
						}]

						// Provider and connection
						providerConfigRef: {
							name: "string"
						}
						writeConnectionSecretToRef: {
							name:      "string"
							namespace: "string"
						}
					}
					status: {
						tableArn:          "${table.status.ackResourceMetadata.arn}"
						tableStatus:       "${table.status.tableStatus}"
						tableID:           "${table.status.tableID}"
						latestStreamArn:   "${table.status.latestStreamARN}"
						itemCount:         "${table.status.itemCount}"
						tableSizeBytes:    "${table.status.tableSizeBytes}"
						creationDateTime:  "${table.status.creationDateTime}"
						conditions:        "${table.status.conditions}"
					}
				}

				resources: [
					{
						id: "table"
						template: {
							apiVersion: "dynamodb.services.k8s.aws/v1alpha1"
							kind:       "Table"
							metadata: {
								name: "${schema.spec.tableName}"
								annotations: {
									"kro.run/region": "${schema.spec.region}"
								}
							}
							spec: {
								tableName:  "${schema.spec.tableName}"
								billingMode: "${schema.spec.billingMode}"

								attributeDefinitions: "${schema.spec.attributeDefinitions}"
								keySchema:            "${schema.spec.keySchema}"

								// Conditional fields using includeWhen
								provisionedThroughput: {
									includeWhen: ["${schema.spec.billingMode == \"PROVISIONED\"}"]
									readCapacityUnits:  "${schema.spec.provisionedThroughput.readCapacityUnits}"
									writeCapacityUnits: "${schema.spec.provisionedThroughput.writeCapacityUnits}"
								}

								globalSecondaryIndexes: {
									includeWhen: ["${size(schema.spec.globalSecondaryIndexes) > 0}"]
									value:       "${schema.spec.globalSecondaryIndexes}"
								}

								localSecondaryIndexes: {
									includeWhen: ["${size(schema.spec.localSecondaryIndexes) > 0}"]
									value:       "${schema.spec.localSecondaryIndexes}"
								}

								streamSpecification: {
									includeWhen: ["${schema.spec.streamEnabled}"]
									streamEnabled:  true
									streamViewType: "${schema.spec.streamViewType}"
								}

								pointInTimeRecoverySpecification: {
									includeWhen: ["${schema.spec.pointInTimeRecoveryEnabled}"]
									pointInTimeRecoveryEnabled: true
								}

								sseSpecification: {
									includeWhen: ["${schema.spec.sseEnabled}"]
									enabled:       true
									sseType:       "${schema.spec.sseType}"
									kmsMasterKeyID: "${schema.spec.kmsMasterKeyID}"
								}

								timeToLiveSpecification: {
									includeWhen: ["${schema.spec.ttlEnabled}"]
									enabled:       true
									attributeName: "${schema.spec.ttlAttributeName}"
								}

								deletionProtectionEnabled: "${schema.spec.deletionProtectionEnabled}"

								tableClass: {
									includeWhen: ["${schema.spec.tableClass != \"\"}"]
									value:       "${schema.spec.tableClass}"
								}

								tags: {
									includeWhen: ["${size(schema.spec.tags) > 0}"]
									value:       "${schema.spec.tags}"
								}
							}
						}
					},
				]
			}
		}
	}

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
