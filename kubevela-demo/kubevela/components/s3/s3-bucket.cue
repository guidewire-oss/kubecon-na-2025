"simple-s3": {
    type: "component"
    attributes: {
        workload: definition: {
            apiVersion: "demo.kubecon.io/v1alpha1"
            kind:       "XS3Bucket"
        }
        status: {
            healthPolicy: #"""
                isHealth: bool | *false
                if context.output.status != _|_ {
                    if context.output.status.conditions != _|_ {
                        for c in context.output.status.conditions {
                            if c.type == "Ready" && c.status == "True" {
                                isHealth: true
                            }
                        }
                    }
                }
                """#
            customStatus: #"""
                message: string | *"Provisioning S3 bucket..."
                if context.output.status != _|_ {
                    if context.output.status.bucketArn != _|_ {
                        message: "Bucket ARN: " + context.output.status.bucketArn
                    }
                    if context.output.status.bucketName != _|_ {
                        message: message + " | Name: " + context.output.status.bucketName
                    }
                }
                """#
        }
    }
}

template: {
    output: {
        apiVersion: "demo.kubecon.io/v1alpha1"
        kind:       "XS3Bucket"
        metadata: {
            name:      parameter.name
            namespace: context.namespace
        }
        spec: {
            name:       parameter.name
            region:     parameter.region
            versioning: parameter.versioning
            tags: {
                "gwcp:v1:dept":                            "000"
                "gwcp:v1:provisioned-resource:created-by": "kubecon-demo"
                "gwcp:v1:quadrant:name":                   "dev"
                "gwcp:v1:resource-type:managed-by":        "pod-atlantis"
                "gwcp:v1:resource-type:managed-tool":      "crossplane"
                "gwcp:v1:star-system:name":                "kubecon"
                "gwcp:v1:tenant:name":                     "atlantis"
                "gwcp:v1:tenant:app-name":                 context.appName
            }
            crossplane: {
                compositionRef: {
                    name: "s3-bucket.demo.kubecon.io"
                }
            }
        }
    }

    parameter: {
        // +usage=Name of the S3 bucket (will be prefixed with tenant-atlantis-)
        name: string

        // +usage=AWS region
        region: *"us-west-2" | string

        // +usage=Enable versioning on the bucket
        versioning: *false | bool
    }
}
