"dynamodb-encryption-kro": {
    annotations: {}
	description: "Enable server-side encryption for DynamoDB table data at rest (AES256 or AWS KMS)"
	type: "trait"
}

template: {
	patch: spec: {
		sseEnabled: parameter.enabled
		if parameter.enabled {
			if parameter.sseType != _|_ {
				sseType: parameter.sseType
			}
			if parameter.kmsKeyId != _|_ {
				kmsMasterKeyID: parameter.kmsKeyId
			}
		}
	}

	parameter: {
		// +usage=Enable server-side encryption
		enabled: *true | bool

		// +usage=Encryption type: AES256 (AWS managed) or KMS (customer managed key)
		sseType?: *"AES256" | "KMS"

		// +usage=KMS key ID or ARN (required if sseType is KMS)
		kmsKeyId?: string
	}
}
