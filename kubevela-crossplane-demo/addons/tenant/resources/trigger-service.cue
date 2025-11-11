package main

triggerService: {
	name: "tenant-trigger-service"
	type: "trigger-service"
	properties: {
		name: "tenant-trigger-service"

		triggers: [{
			source: {
				type: "resource-watcher"
				properties: {
					kind: "ConfigMap"
					events: ["create", "update"]
				}
			}

			filter: """
				context.data.metadata.labels["config.oam.dev/config-type"] == "tenant"
			"""

			action: {
				type: "trigger-create-tenant-app"
			}
		}]
	}
}

triggerServiceDelete: {
	name: "tenant-trigger-delete-service"
	type: "trigger-service"
	properties: {
		name: "tenant-delete-trigger-service"

		triggers: [{
			source: {
				type: "resource-watcher"
				properties: {
					kind: "ConfigMap"
					events: ["delete"]
				}
			}

			filter: """
				context.data.metadata.labels["config.oam.dev/config-type"] == "tenant"
			"""

			action: {
				type: "trigger-delete-tenant-app"
			}
		}]
	}
}