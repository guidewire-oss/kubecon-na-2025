package main

"s3-encryption": {
	annotations: {}
	labels: {}
	attributes: {
		appliesToWorkloads: ["s3-bucket"]
	}
	description: "Configure server-side encryption for S3 bucket"
	type:        "trait"
}

template: {
	patch: {
		spec: forProvider: serverSideEncryptionConfiguration: [{
			rules: [{
				applyServerSideEncryptionByDefault: [{
					sseAlgorithm: parameter.algorithm
					if parameter.kmsKeyId != _|_ && parameter.algorithm == "aws:kms" {
						kmsMasterKeyId: parameter.kmsKeyId
					}
				}]
				if parameter.bucketKeyEnabled != _|_ {
					bucketKeyEnabled: parameter.bucketKeyEnabled
				}
			}]
		}]
	}

	parameter: {
		// Encryption algorithm
		algorithm: "AES256" | "aws:kms" | *"AES256"

		// KMS key ID (required if algorithm is aws:kms)
		kmsKeyId?: string

		// Enable bucket key for KMS encryption
		bucketKeyEnabled?: bool
	}
}