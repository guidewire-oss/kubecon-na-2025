// KubeVela ComponentDefinition for Kratix Platform Installer
// This component deploys the Kratix platform framework using Helm

#ComponentDefinition: {
	apiVersion: "core.oam.dev/v1beta1"
	kind:       "ComponentDefinition"
	metadata: {
		name: "kratix-installer"
		annotations: {
			"definition.oam.dev/description": "Deploy Kratix Promise platform framework"
			"definition.oam.dev/user-scope":   "system"
		}
	}
	spec: {
		workload: {
			definition: {
				apiVersion: "helm.toolkit.fluxcd.io/v2"
				kind:       "HelmRelease"
			}
		}
		schematic: {
			cue: {
				template: #"""
					output: {
						apiVersion: "helm.toolkit.fluxcd.io/v2"
						kind:       "HelmRelease"
						metadata: {
							name:      context.name
							namespace: context.namespace
						}
						spec: {
							interval: "5m"
							chart: {
								spec: {
									chart:   "kratix"
									version: parameter.chartVersion
									sourceRef: {
										kind:      "HelmRepository"
										name:      "kratix"
										namespace: "flux-system"
									}
								}
							}
							values: {
								namespace:      parameter.namespace
								installCRDs:    parameter.installCRDs
								replicas:       parameter.replicas
								logLevel:       parameter.logLevel
								image: {
									repository: parameter.imageRepository
									tag:        parameter.imageTag
									pullPolicy: parameter.imagePullPolicy
								}
								resources: {
									requests: {
										cpu:    parameter.resources.requests.cpu
										memory: parameter.resources.requests.memory
									}
									limits: {
										cpu:    parameter.resources.limits.cpu
										memory: parameter.resources.limits.memory
									}
								}
								serviceAccount: {
									create: true
									name:   parameter.serviceAccountName
								}
								rbac: {
									create: true
								}
								if parameter.prometheusEnabled {
									prometheus: {
										enabled: true
										port:    parameter.prometheusPort
									}
								}
							}
							install: {
								crds: "Create"
							}
							upgrade: {
								crds: "CreateReplace"
							}
						}
					}

					status: {
						ready:   output.status.conditions[0].status == "True"
						message: output.status.conditions[0].message
					}

					parameter: {
						// Kratix version and installation
						chartVersion:     *"v1.0.0" | string
						namespace:        *"kratix-platform" | string
						installCRDs:      *true | bool

						// Pod configuration
						replicas:         *1 | int & >=1 & <=5
						logLevel:         *"info" | "debug" | "warn" | "error"

						// Container image configuration
						imageRepository:  *"ghcr.io/syntasso/kratix" | string
						imageTag:         *"latest" | string
						imagePullPolicy:  *"IfNotPresent" | "Always" | "Never"

						// Service account
						serviceAccountName: *"kratix-controller-manager" | string

						// Resource requests and limits
						resources: {
							requests: {
								cpu:    *"100m" | string
								memory: *"64Mi" | string
							}
							limits: {
								cpu:    *"500m" | string
								memory: *"512Mi" | string
							}
						}

						// Monitoring
						prometheusEnabled: *false | bool
						prometheusPort:    *8080 | int

						// Additional helm values can be added here
						helmValues?: {...}
					}
					"""#
			}
		}
	}
}

#ComponentDefinition
