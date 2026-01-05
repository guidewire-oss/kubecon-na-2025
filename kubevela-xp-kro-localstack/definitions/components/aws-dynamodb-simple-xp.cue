"aws-dynamodb-simple-xp": {
	alias: ""
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
	description: "Simple AWS DynamoDB table managed by Crossplane for NoSQL database workloads - basic table with single partition key"
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
					{
						name: "id"
						type: "S"
					}
				]

				// keySchema -> hashKey/rangeKey
				hashKey: "id"

				// Default to PAY_PER_REQUEST billing mode
				billingMode: "PAY_PER_REQUEST"
			}

			providerConfigRef: {
				name: *parameter.providerConfigRef | "default"
			}
		}
	}

	parameter: {
		// +usage=AWS region where the DynamoDB table will be created (e.g., us-east-1, us-west-2)
		region: *"us-west-2" | string

		// +usage=Crossplane provider config reference name
		providerConfigRef?: string
	}
}
