"dynamodb-protection-xp": {
    annotations: {}
    description: "Enable deletion protection and point-in-time recovery for DynamoDB table (data protection and compliance)"
    annotations: {}
    type: "trait"
}

template: {
    patch: {
        spec: forProvider: {
            if parameter.deletionProtection != _|_ {
                deletionProtectionEnabled: parameter.deletionProtection
            }
            if parameter.pointInTimeRecovery != _|_ {
                pointInTimeRecoveryEnabled: parameter.pointInTimeRecovery
            }
        }
    }

    parameter: {
        // +usage=Enable deletion protection to prevent accidental table deletion
        deletionProtection?: *true | bool

        // +usage=Enable point-in-time recovery for backup and restore (last 35 days)
        pointInTimeRecovery?: *true | bool
    }
}
