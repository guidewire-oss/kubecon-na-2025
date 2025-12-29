"dynamodb-encryption-xp": {
    annotations: {}
    description: "Configure server-side encryption with custom KMS key for DynamoDB table (compliance and security requirement)"
    annotations: {}
    type: "trait"
}

template: {
    patch: {
        spec: forProvider: {
            sseSpecification: {
                enabled: parameter.enabled
                if parameter.kmsKeyId != _|_ {
                    kmsMasterKeyID: parameter.kmsKeyId
                }
                if parameter.sseType != _|_ {
                    sseType: parameter.sseType
                }
            }
        }
    }

    parameter: {
        // +usage=Enable server-side encryption
        enabled: *true | bool

        // +usage=KMS key ID or ARN for encryption (if not specified, uses AWS-managed key)
        kmsKeyId?: string

        // +usage=Server-side encryption type: AES256 or KMS
        sseType?: "AES256" | "KMS"
    }
}
