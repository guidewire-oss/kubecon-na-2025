package main

output: {
	apiVersion: "core.oam.dev/v1beta1"
	kind:       "Application"
	spec: {
		components: [
			deployment
		]
		
		// Define workflow to ensure proper installation order
		workflow: {
			steps: [
				{
					name: "install-crossplane"
					type: "apply-component"
					properties: {
						component: deployment.name
					}
				}
			]
		}
	}
}
