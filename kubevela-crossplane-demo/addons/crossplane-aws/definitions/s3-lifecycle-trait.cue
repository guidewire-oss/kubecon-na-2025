package main

"s3-lifecycle": {
	annotations: {}
	labels: {}
	attributes: {
		appliesToWorkloads: ["s3-bucket"]
	}
	description: "Configure lifecycle rules for S3 bucket"
	type:        "trait"
}

template: {
	patch: {
		spec: forProvider: lifecycleRule: parameter.rules
	}

	parameter: {
		// Lifecycle rules
		rules: [...{
			id:      string
			enabled: bool | *true
			
			// Optional expiration settings
			expiration?: {
				days?:                      int
				date?:                      string
				expiredObjectDeleteMarker?: bool
			}

			// Optional transition settings
			transition?: [...{
				days?:         int
				date?:         string
				storageClass: "STANDARD_IA" | "INTELLIGENT_TIERING" | "ONEZONE_IA" | "GLACIER" | "DEEP_ARCHIVE"
			}]

			// Optional non-current version settings
			noncurrentVersionExpiration?: {
				days: int
			}

			// Optional abort incomplete multipart upload
			abortIncompleteMultipartUpload?: {
				daysAfterInitiation: int
			}
		}]
	}
}