package main

"s3-public-access-block": {
	annotations: {}
	labels: {}
	attributes: {
		appliesToWorkloads: ["s3-bucket"]
	}
	description: "Configure public access blocking for S3 bucket"
	type:        "trait"
}

template: {
	patch: {
		spec: forProvider: publicAccessBlockConfiguration: [{
			blockPublicAcls:       parameter.blockPublicAcls
			blockPublicPolicy:     parameter.blockPublicPolicy
			ignorePublicAcls:      parameter.ignorePublicAcls
			restrictPublicBuckets: parameter.restrictPublicBuckets
		}]
	}

	parameter: {
		// Block public ACLs
		blockPublicAcls: bool | *true

		// Block public bucket policies
		blockPublicPolicy: bool | *true

		// Ignore public ACLs
		ignorePublicAcls: bool | *true

		// Restrict public buckets
		restrictPublicBuckets: bool | *true
	}
}