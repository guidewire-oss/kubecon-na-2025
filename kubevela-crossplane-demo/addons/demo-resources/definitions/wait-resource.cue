import (
	"vela/op"
)

"wait-resource": {
	type: "workflow-step"
	annotations: {}
	labels: {}
	description: "Wait for a Kubernetes resource to be ready"
}

template: {
	#WaitResource: {
		resource: {
			apiVersion: string
			kind:       string
			name:       string
			namespace?: string
		}
		condition?: string | *"status.phase == 'Running'" // Default condition
		timeout?:   string | *"300s"
		interval?:  string | *"10s"
		...
	}

	parameter: #WaitResource

	// Read the resource and check condition
	read: op.#Read & {
		value: {
			apiVersion: parameter.resource.apiVersion
			kind:       parameter.resource.kind
			metadata: {
				name: parameter.resource.name
				if parameter.resource.namespace != _|_ {
					namespace: parameter.resource.namespace
				}
			}
		}
	}

	// Check if resource is ready based on condition
	wait: op.#ConditionalWait & {
		continue: read.err == _|_ && read.value.status != _|_
		if parameter.condition != _|_ {
			continue: read.err == _|_ && parameter.condition
		}
	}

	// Handle failures with retries
	fail: op.#Steps & {
		if read.err != _|_ {
			breakIf: read.err != _|_
		}
	}
}