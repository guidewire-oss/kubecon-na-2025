"dynamodb-streams-kro": {
    annotations: {}
	description: "Enable DynamoDB Streams for change data capture and event-driven architectures (enables Lambda triggers, analytics, replication)"
    annotations: {}
	type: "trait"
}

template: {
	patch: spec: {
		streamEnabled: parameter.enabled
		if parameter.enabled {
			if parameter.viewType != _|_ {
				streamViewType: parameter.viewType
			}
		}
	}

	parameter: {
		// +usage=Enable DynamoDB Streams for change data capture
		enabled: *true | bool

		// +usage=Stream view type: KEYS_ONLY (only key attributes), NEW_IMAGE (entire item after modification), OLD_IMAGE (entire item before modification), or NEW_AND_OLD_IMAGES (both before and after)
		viewType?: *"NEW_AND_OLD_IMAGES" | "KEYS_ONLY" | "NEW_IMAGE" | "OLD_IMAGE"
	}
}
