"dynamodb-provisioned-capacity-kro": {
    annotations: {}
	description: "Configure provisioned capacity mode for DynamoDB table with fixed read/write capacity units for predictable performance and cost"
	type: "trait"
}

template: {
	patch: spec: {
		billingMode: "PROVISIONED"
		provisionedThroughput: {
			readCapacityUnits:  parameter.readCapacityUnits
			writeCapacityUnits: parameter.writeCapacityUnits
		}
	}

	parameter: {
		// +usage=Read capacity units (RCU) - each RCU provides 1 strongly consistent read/sec (4KB) or 2 eventually consistent reads/sec
		readCapacityUnits: *5 | int & >0

		// +usage=Write capacity units (WCU) - each WCU provides 1 write/sec (1KB)
		writeCapacityUnits: *5 | int & >0
	}
}
