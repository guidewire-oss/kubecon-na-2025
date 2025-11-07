"simple-dynamodb": {
    type: "component"
    attributes: {
        workload: definition: {
            apiVersion: "demo.kubecon.io/v1alpha1"
            kind:       "XDynamoDBTable"
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
                message: string | *"Provisioning table..."
                if context.output.status != _|_ {
                    if context.output.status.tableArn != _|_ {
                        message: "Table ARN: " + context.output.status.tableArn
                    }
                }
                """#
        }
    }
}

template: {
    output: {
        apiVersion: "demo.kubecon.io/v1alpha1"
        kind:       "XDynamoDBTable"
        metadata: {
            name:      "tenant-atlantis-" + parameter.name
            namespace: context.namespace
        }
        spec: {
            name:       "tenant-atlantis-" + parameter.name
            region:     parameter.region
            hashKey:    parameter.hashKey
            attributes: parameter.attributes
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
                    name: "dynamodb-table.demo.kubecon.io"
                }
            }
        }
    }

    parameter: {
        // +usage=Name of the DynamoDB table (will be prefixed with tenant-atlantis-)
        name: string
        
        // +usage=AWS region
        region: string
        
        // +usage=Hash key attribute name
        hashKey: string
        
        // +usage=Attribute definitions
        attributes: [...{
            // +usage=Attribute name
            name: string
            // +usage=Attribute type (S=String, N=Number, B=Binary)
            type: "S" | "N" | "B"
        }]
    }
}
