"kratix-promise-deployer": {
	annotations: {}
	attributes: {
		workload: {
			definition: {
				apiVersion: "platform.kratix.io/v1alpha1"
				kind:       "Promise"
			}
		}
	}
	description: "Deploy individual Kratix promises for platform abstraction"
	type:        "component"
}

template: {
	output: {
		apiVersion: "platform.kratix.io/v1alpha1"
		kind:       "Promise"
		metadata: {
			name:      context.name
			namespace: parameter.namespace
			labels: {
				"kratix.io/promise-version": parameter.version
				"platform":                  parameter.platform
				"service":                   parameter.service
			}
		}
		spec: {
			api: parameter.api
			destinationSelectors: parameter.destinationSelectors
			if parameter.workflowImage != _|_ {
				workflowImage: parameter.workflowImage
			}
		}
	}

	parameter: {
		// Basic promise metadata
		version:   string
		platform:  string
		service:   string
		namespace: *"kratix" | string

		// Promise API definition
		api: {
			apiVersion: string
			kind:       string
			metadata?: {...}
			spec: {...}
		}

		// Destination selector for where to deploy
		destinationSelectors: [...{
			matchLabels?: {...}
		}]

		// Workflow image
		workflowImage?: string
	}
}
