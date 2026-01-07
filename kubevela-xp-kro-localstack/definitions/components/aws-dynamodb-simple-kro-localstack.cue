"aws-dynamodb-simple-kro-localstack": {
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
					if context.output.status.conditions != _|_ && len(context.output.status.conditions) > 0 {
						message: context.output.status.conditions[0].message
					}
					if context.output.status.conditions == _|_ || len(context.output.status.conditions) == 0 {
						message: "Table provisioning - State: \(tableState)"
					}
				}
				"""#
		}
	}
	description: "Simple AWS DynamoDB table for LocalStack managed by KRO - uses Kubernetes Jobs to create tables"
	type: "component"
}

template: {
	output: {
		apiVersion: "kro.run/v1alpha1"
		kind:       "SimpleDynamoDBLocalStack"
		metadata: {
			name: context.name
		}
		spec: {
			// Note: Pass the table name directly (no prefix required for LocalStack)
			tableName: parameter.tableName
			region:    parameter.region
		}
	}

	parameter: {
		// +usage=The name of the DynamoDB table
		tableName: string

		// +usage=AWS region for the table
		region: *"us-west-2" | string
	}
}
