metadata: {
    name: "tenant"
    alias: "Tenant"
    description: "Tenant Configuration"
    sensitive: false
    scope: "system"
}

template: {
    parameter: {
        name: string
        namespace?: string
    }

    outputs: configmap: {
        apiVersion: "v1"
        kind:       "ConfigMap"
        metadata: {
            name: "tenant-\(context.name)"
            namespace: context.namespace
            labels: {
                "config.oam.dev/config-type": "tenant"
                "config.oam.dev/tenant": parameter.name
                if parameter.namespace != _|_ {
                    "config.oam.dev/tenant-namespace": parameter.namespace
                }
                if parameter.namespace == _|_ {
                    "config.oam.dev/tenant-namespace": parameter.name
                }
            }
        }
        data: {
            name: parameter.name
            if parameter.namespace != _|_ {
                namespace: parameter.namespace
            }
            if parameter.namespace == _|_ {
                namespace: parameter.name
            }
        }
    }
}