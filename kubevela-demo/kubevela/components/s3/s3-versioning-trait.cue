package main

"s3-versioning": {
	annotations: {}
	labels: {}
	attributes: {
		appliesToWorkloads: ["s3-bucket"]
	}
	description: "Enable versioning for S3 bucket"
	type:        "trait"
}

template: {
	patch: {
		spec: forProvider: versioning: [{
			enabled: parameter.enabled
		}]
	}

	parameter: {
		// Enable or disable versioning
		enabled: bool | *true
	}
}