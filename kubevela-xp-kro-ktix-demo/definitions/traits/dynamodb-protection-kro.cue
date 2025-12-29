"dynamodb-protection-kro": {
    annotations: {}
	description: "Enable data protection features for DynamoDB table including deletion protection and point-in-time recovery"
    annotations: {}
	type: "trait"
}

template: {
	patch: spec: {
		deletionProtectionEnabled: parameter.deletionProtection
		pointInTimeRecoveryEnabled: parameter.pointInTimeRecovery
	}

	parameter: {
		// +usage=Enable deletion protection to prevent accidental table deletion
		deletionProtection: *true | bool

		// +usage=Enable point-in-time recovery for continuous backups (last 35 days)
		pointInTimeRecovery: *true | bool
	}
}
