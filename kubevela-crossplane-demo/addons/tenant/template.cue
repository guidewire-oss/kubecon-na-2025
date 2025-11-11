package main
output: {
	apiVersion: "core.oam.dev/v1beta1"
	kind:       "Application"
	spec: {
		components: [
			createappdef,
			deleteappdef,
			triggerService,
			triggerServiceDelete
		]
		policies: []
	}
}
