package main

"s3-object": {
	annotations: {}
	labels: {}
	attributes: {
		workload: definition: {
			apiVersion: "s3.aws.upbound.io/v1beta1"
			kind:       "Object"
		}
		status: {
			healthPolicy: {
				isHealth: context.output.status.atProvider.etag != _|_
			}
			customStatus: {
				message: "Object: " + (context.output.status.atProvider.key | "pending")
			}
			details: {
				objectKey: *context.output.status.atProvider.key | "pending"
				etag: *context.output.status.atProvider.etag | "pending"
				bucket: *context.output.status.atProvider.bucket | parameter.bucket
				size: *context.output.status.atProvider.contentLength | "unknown"
				contentType: *context.output.status.atProvider.contentType | parameter.contentType
			}
		}
	}
	description: "AWS S3 Object managed by Crossplane"
	type:        "component"
}

template: {
	output: {
		apiVersion: "s3.aws.upbound.io/v1beta1"
		kind:       "Object"
		metadata: {
			name: "\(context.appName)-\(context.name)"
		}
		spec: {
			forProvider: {
				bucket: parameter.bucket
				key:    parameter.key
				region: parameter.region
				if parameter.content != _|_ {
					content: parameter.content
				}
				if parameter.contentType != _|_ {
					contentType: parameter.contentType
				}
				if parameter.acl != _|_ {
					acl: parameter.acl
				}
				tags: {
					"crossplane-kind":            "object.s3.aws.upbound.io"
					"crossplane-name":            context.name
					"crossplane-providerconfig":  parameter.providerConfigRef
					"managed-by":                 "crossplane"
				}
			}
			deletionPolicy: "Delete"
			providerConfigRef: {
				name: parameter.providerConfigRef
			}
		}
	}

	parameter: {
		// Required: S3 bucket name
		bucket: string

		// Required: Object key/path
		key: string

		// Required: AWS region
		region: string

		// Optional: File content (for small text files)
		content?: string

		// Optional: Content type
		contentType?: string | *"text/plain"

		// Optional: ACL setting
		acl?: "private" | "public-read" | "public-read-write" | *"private"

		// Provider configuration reference
		providerConfigRef: string | *"default"
	}
}