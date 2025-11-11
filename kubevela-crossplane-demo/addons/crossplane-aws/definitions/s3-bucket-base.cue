package main

"s3-bucket": {
	annotations: {}
	labels: {}
	attributes: {
		workload: definition: {
			apiVersion: "s3.aws.upbound.io/v1beta2"
			kind:       "Bucket"
		}
		status: {
			healthPolicy: {
				isHealth: context.output.status.atProvider.arn != _|_
			}
			details: {
				bucketName: context.output.status.atProvider.id
				bucketArn: context.output.status.atProvider.arn
				region: context.output.status.atProvider.region
				hostedZoneId: context.output.status.atProvider.hostedZoneId
				bucketDomainName: context.output.status.atProvider.bucketDomainName
				bucketRegionalDomainName: context.output.status.atProvider.bucketRegionalDomainName
				syncStatus: context.output.status.conditions[0].type
				syncReason: context.output.status.conditions[0].reason
				lastModified: context.output.status.conditions[0].lastTransitionTime
			}
			customStatus: {
				message: *"Synced: \(context.output.status.atProvider.arn)" | "Syncing S3 Bucket"
			}
		}
	}
	description: "AWS S3 Bucket managed by Crossplane"
	type:        "component"
}

template: {
	output: {
		apiVersion: "s3.aws.upbound.io/v1beta2"
		kind:       "Bucket"
		metadata: {
			name: "\(context.appName)-\(context.name)"
		}
		spec: {
			forProvider: {
				region: parameter.region
				if parameter.bucketName != _|_ {
					bucketPrefix: parameter.bucketName + "-"
				}
				tags: {
					"crossplane-kind":            "bucket.s3.aws.upbound.io"
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
		// Required: AWS region for the bucket (immutable)
		region: string

		// Optional: Bucket name prefix (immutable)
		bucketName?: string

		// Provider configuration reference
		providerConfigRef: string | *"default"
	}
}