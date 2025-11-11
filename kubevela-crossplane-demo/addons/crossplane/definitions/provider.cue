package main 

"crossplane-provider": {
	alias: "xpp"
	annotations: {}
	attributes: {
		workload: {
			definition: {
				apiVersion: "pkg.crossplane.io/v1"
				kind: "Provider"
			}
		}
        status: {
            details: {
                $conditions: *context.output.status.conditions | []

                $installedCondition: [ for c in $conditions if c.type == "Installed" { c } ]
                $healthyCondition: [ for c in $conditions if c.type == "Healthy" { c } ]

                isInstalled: len($installedCondition) > 0 && $installedCondition[0].status == "True"
                isHealthy: len($healthyCondition) > 0 && $healthyCondition[0].status == "True"
            }

            customStatus: {
                message: string | *"Installing Provider"
                if context.status.details.isInstalled && !context.status.details.isHealthy {
                    message: "Provider Installed. Awaiting Healthy"
                }
                if context.status.details.isInstalled && context.status.details.isHealthy {
                    message: "Provider Installed & Healthy"
                }
            }
            
            healthPolicy: {
                isHealth: *context.status.details.isHealthy | false
            }
        }
	}
	description: "Crossplane Provider"
	labels: {}
	type: "component"
}

template: {
	parameter: {
        namespace: string | *"crossplane-system"
        package: string
        
        // Optional service account annotations (e.g., for IRSA)
        serviceAccountAnnotations?: [string]: string
    }

	output: {
        apiVersion: "pkg.crossplane.io/v1"
        kind: "Provider"
        metadata: {
            name: context.name
            namespace: parameter.namespace
            if parameter.serviceAccountAnnotations != _|_ {
                annotations: parameter.serviceAccountAnnotations
            }
        }
        spec: {
            package: parameter.package
            runtimeConfigRef: {
                apiVersion: "pkg.crossplane.io/v1beta1"
                kind: "DeploymentRuntimeConfig"
                name: context.name
            }
            skipDependencyResolution: true
            ignoreCrossplaneConstraints: true
        }
    }

    outputs: "deployment-runtime-config": {
        apiVersion: "pkg.crossplane.io/v1beta1"
        kind: "DeploymentRuntimeConfig"
        metadata: {
            name: context.name
            namespace: parameter.namespace
            if parameter.serviceAccountAnnotations != _|_ {
                annotations: parameter.serviceAccountAnnotations
            }
        }
        spec: {
            serviceAccountTemplate: {
                metadata: {
                    name: context.name
                    if parameter.serviceAccountAnnotations != _|_ {
                        annotations: parameter.serviceAccountAnnotations
                    }
                }
            }
            deploymentTemplate: {
                metadata: {}
                spec: {
                    selector: {}
                    strategy: {
                        type: "RollingUpdate"
                    }
                    template: {
                        spec: {
                            securityContext: {
                                fsGroup: 2000
                            }
                            serviceAccountName: context.name
                            containers: [{
                                name: "package-runtime"
                                resources: {
                                    requests: {
                                        cpu: "250m"
                                        memory: "256Mi"
                                    }
                                    limits: {
                                        cpu: "500m"
                                        memory: "512Mi"
                                    }
                                }
                            }]
                        }
                    }
                }
            }
        }
    }
}
