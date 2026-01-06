"webservice": {
	alias: ""
	annotations: {}
	attributes: {
		workload: {
			type: "deployments.apps"
		}
		status: {
			healthPolicy: #"""
				isHealth: *false | bool
				if context.status.readyReplicas != _|_ && context.status.replicas != _|_ {
					isHealth: (context.status.readyReplicas > 0) && (context.status.readyReplicas == context.status.replicas)
				}
				"""#
			customStatus: #"""
				message: *"" | string
				if context.status.conditions != _|_ && len(context.status.conditions) > 0 {
					message: context.status.conditions[0].message
				}
				"""#
		}
	}
	description: "Long-running, scalable, containerized service with stable network endpoint"
	type: "component"
}

template: {
	output: {
		apiVersion: "apps/v1"
		kind: "Deployment"
		metadata: {
			name: context.name
			namespace: context.namespace
			labels: context.labels
		}
		spec: {
			replicas: parameter.replicas
			selector: matchLabels: "app.kubernetes.io/name": context.name
			template: {
				metadata: {
					labels: {
						"app.kubernetes.io/name": context.name
						if parameter.addRevisionLabel {
							"app.kubernetes.io/version": context.revision
						}
					}
					if parameter.annotations != _|_ {
						annotations: parameter.annotations
					}
				}
				spec: {
					containers: [
						{
							name: context.name
							image: parameter.image
							imagePullPolicy: parameter.imagePullPolicy
							if parameter.ports != _|_ {
								ports: parameter.ports
							}
							if parameter.env != _|_ {
								env: parameter.env
							}
							if parameter.resources != _|_ {
								resources: parameter.resources
							}
							if parameter.livenessProbe != _|_ {
								livenessProbe: parameter.livenessProbe
							}
							if parameter.readinessProbe != _|_ {
								readinessProbe: parameter.readinessProbe
							}
						}
					]
				}
			}
		}
	}

	outputs: {
		if parameter.ports != _|_ && len(parameter.ports) > 0 {
			service: {
				apiVersion: "v1"
				kind: "Service"
				metadata: {
					name: context.name
					namespace: context.namespace
					labels: context.labels
				}
				spec: {
					selector: "app.kubernetes.io/name": context.name
					type: parameter.exposeType
					ports: [
						for _, p in parameter.ports {
							if p.expose != _|_ && p.expose {
								{
									name: p.name
									port: p.port
									targetPort: p.containerPort
									protocol: p.protocol
									if p.nodePort != _|_ {
										nodePort: p.nodePort
									}
								}
							}
						}
					]
				}
			}
		}
	}

	parameter: {
		// +usage=Container image
		image: string

		// +usage=Image pull policy
		imagePullPolicy: *"IfNotPresent" | string

		// +usage=Number of replicas
		replicas: *1 | int

		// +usage=Port configuration for the container
		ports?: [...{
			name: *"default" | string
			containerPort: int
			port: *8080 | int
			protocol: *"TCP" | string
			expose: *false | bool
			nodePort?: int
		}]

		// +usage=Environment variables
		env?: [...{
			name: string
			value: string
		}]

		// +usage=Resource requests and limits
		resources?: {
			limits?: {
				cpu?: string
				memory?: string
			}
			requests?: {
				cpu?: string
				memory?: string
			}
		}

		// +usage=Liveness probe configuration
		livenessProbe?: {
			httpGet?: {
				path: string
				port: int
			}
			initialDelaySeconds?: int
			periodSeconds?: int
		}

		// +usage=Readiness probe configuration
		readinessProbe?: {
			httpGet?: {
				path: string
				port: int
			}
			initialDelaySeconds?: int
			periodSeconds?: int
			timeoutSeconds?: int
			failureThreshold?: int
		}

		// +usage=Service type for exposing the deployment
		exposeType: *"ClusterIP" | "NodePort" | "LoadBalancer"

		// +usage=Add revision label to pods
		addRevisionLabel: *false | bool

		// +usage=Pod annotations
		annotations?: [string]: string

		// +usage=Pod labels
		labels?: [string]: string
	}
}
