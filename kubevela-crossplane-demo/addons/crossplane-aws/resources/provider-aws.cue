package main

provideraws: {
    type: "crossplane-provider"
    name: "provider-aws"
    properties: {
        namespace: parameter.namespace
        package:   "xpkg.upbound.io/upbound/provider-family-aws:" + parameter.awsFamilyVersion
        if parameter.irsaEnabled {
            serviceAccountAnnotations: {
                "eks.amazonaws.com/role-arn": parameter.irsaRoleArn
            }
        }
    }
}