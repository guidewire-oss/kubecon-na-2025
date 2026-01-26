"dynamodb-streams-xp": {
    annotations: {}
    description: "Enable DynamoDB Streams for change data capture and event-driven architectures (enables Lambda triggers, analytics)"
    type: "trait"
}

template: {
    patch: {
        spec: forProvider: {
            streamSpecification: {
                streamEnabled: parameter.enabled
                if parameter.viewType != _|_ {
                    streamViewType: parameter.viewType
                }
            }
        }
    }

    parameter: {
        // +usage=Enable DynamoDB Streams for change data capture
        enabled: *true | bool

        // +usage=Stream view type: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, or NEW_AND_OLD_IMAGES
        viewType?: *"NEW_AND_OLD_IMAGES" | "KEYS_ONLY" | "NEW_IMAGE" | "OLD_IMAGE" | "NEW_AND_OLD_IMAGES"
    }
}
