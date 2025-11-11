import (
	"vela/op"
)

"wait-deployment": {
	annotations: {}
	description: "Wait for a deployment to have ready replicas"
	labels: {}
	type: "workflow-step"
}

template: {
	parameter: {
		// Deployment to wait for
		name:      string
		namespace: string
		
		// Number of replicas to wait for (default 1)
		replicas: *1 | int
		
		// Maximum time to wait (in seconds)
		timeout: *300 | int
	}

	read: op.#Read & {
		value: {
			apiVersion: "apps/v1"
			kind:       "Deployment"
			metadata: {
				name:      parameter.name
				namespace: parameter.namespace
			}
		}
	}

	wait: op.#ConditionalWait & {
		continue: {
			_readyReplicas: *0 | int
			if read.value.status.readyReplicas != _|_ {
				_readyReplicas: read.value.status.readyReplicas
			}
			_readyReplicas >= parameter.replicas
		}
	}
}