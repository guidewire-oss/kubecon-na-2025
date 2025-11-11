package main

awsproviderconfig: {
    type: "k8s-objects"
    name: "default-provider-config"
    properties: {
        objects: [{
            apiVersion: "aws.upbound.io/v1beta1"
            kind: "ProviderConfig"
            metadata: {
                name: parameter.defaultProviderConfigName
            }
            spec: {
                credentials: {
                    if parameter.irsaEnabled {
                        source: "IRSA"
                    }
                    if !parameter.irsaEnabled {
                        source: "Secret"
                        secretRef: {
                            namespace: parameter.credentialsNamespace
                            name: parameter.credentialsSecret
                            key: parameter.credentialsKey
                        }
                    }
                }
                
                if parameter.assumeRole != _|_ {
                    assumeRoleChain: [{
                        roleARN: parameter.assumeRole.roleARN
                        if parameter.assumeRole.sessionName != _|_ {
                            sessionName: parameter.assumeRole.sessionName
                        }
                        if parameter.assumeRole.externalID != _|_ {
                            externalID: parameter.assumeRole.externalID
                        }
                        if parameter.assumeRole.tags != _|_ {
                            tags: parameter.assumeRole.tags
                        }
                    }]
                }
            }
        }]
    }
}