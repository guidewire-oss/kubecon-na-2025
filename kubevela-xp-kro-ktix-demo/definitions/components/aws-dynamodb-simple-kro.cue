"aws-dynamodb-simple-kro": {
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
	description: "Simple AWS DynamoDB table managed by KRO (Kube Resource Orchestrator) and ACK - basic table with single partition key"
	type: "component"
}

template: {
	output: {
		apiVersion: "kro.run/v1alpha1"
		kind:       "SimpleDynamoDB"
		metadata: {
			name: context.name
		}
		spec: {
			// Note: The RGD already adds the tenant-atlantis- prefix, so pass the base name
			tableName: parameter.tableName
			region:    parameter.region
		}
	}

	parameter: {
		// +usage=The name of the DynamoDB table (will be prefixed with tenant-atlantis- by KRO RGD)
		tableName: string

		// +usage=AWS region for the table
		region: *"us-west-2" | string
	}
}
