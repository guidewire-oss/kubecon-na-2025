package main

providerawss3: {
    type: "crossplane-provider"
    name: "provider-aws-s3"
    properties: {
        namespace: parameter.namespace
        package:   "xpkg.upbound.io/upbound/provider-aws-s3:" + parameter.awsS3Version
        if parameter.irsaEnabled {
            serviceAccountAnnotations: {
                "eks.amazonaws.com/role-arn": parameter.irsaRoleArn
            }
        }
    }
}