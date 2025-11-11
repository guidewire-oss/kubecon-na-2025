package main

"s3-tags": {
	annotations: {}
	labels: {}
	attributes: {
		appliesToWorkloads: ["s3-bucket"]
	}
	description: "Add custom tags to S3 bucket"
	type:        "trait"
}

template: {
	patch: {
		spec: forProvider: tags: parameter.tags
	}

	parameter: {
		// Custom tags to add to the bucket
		tags: [string]: string
	}
}