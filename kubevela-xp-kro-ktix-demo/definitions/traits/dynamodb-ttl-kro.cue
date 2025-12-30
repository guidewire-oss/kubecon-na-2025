"dynamodb-ttl-kro": {
    annotations: {}
	description: "Enable Time To Live (TTL) for automatic expiration and deletion of items based on a timestamp attribute"
	type: "trait"
}

template: {
	patch: spec: {
		ttlEnabled: parameter.enabled
		if parameter.enabled {
			if parameter.attributeName != _|_ {
				ttlAttributeName: parameter.attributeName
			}
		}
	}

	parameter: {
		// +usage=Enable Time To Live for automatic item expiration
		enabled: *true | bool

		// +usage=Attribute name containing Unix timestamp (seconds since epoch) for expiration
		attributeName?: *"expiresAt" | string
	}
}
