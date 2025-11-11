package main

parameter: {
	// @description=Namespace to deploy Crossplane
	namespace: *"crossplane-system" | string
	
	// @description=Number of replicas for Crossplane deployment
	replicas: *1 | int
	
	// @description=Container image configuration
	image: {
		// @description=Crossplane image repository
		repository: *"crossplane/crossplane" | string
		// @description=Crossplane image tag
		tag: *"v1.19.3" | string
		// @description=Image pull policy
		pullPolicy: *"IfNotPresent" | "Always" | "Never"
	}
	
	// @description=Resource limits and requests
	resources: {
		limits: {
			// @description=CPU limit
			cpu: *"100m" | string
			// @description=Memory limit
			memory: *"512Mi" | string
		}
		requests: {
			// @description=CPU request
			cpu: *"100m" | string
			// @description=Memory request
			memory: *"256Mi" | string
		}
	}
	
	// @description=Webhook configuration
	webhooks: {
		// @description=Enable admission webhooks (requires TLS certificates)
		enabled: *false | bool
	}
}