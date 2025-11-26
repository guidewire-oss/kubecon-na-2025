// High Availability Trait for Kubernetes Deployments
// Configures HPA, PDB, topology spread, and anti-affinity based on environment level

"high-availability": {
	type: "trait"
	annotations: {}
	labels: {}
	description: "Configure high availability settings based on environment level (dev/staging/prod)"
	attributes: {
		appliesToWorkloads: ["deployments.apps", "statefulsets.apps"]
		podDisruptive: false
	}
}

template: {
	// Get the level parameter with default "dev"
	_level: parameter.level

	// Configuration maps for each level
	_config: {
		dev: {
			hpa: {
				enabled: true
				min:     1
				max:     2
				cpuUtil: 70
			}
			pdb: {
				enabled: false
			}
			topologySpread: {
				enabled: false
			}
			antiAffinity: {
				enabled: false
			}
		}
		staging: {
			hpa: {
				enabled: true
				min:     1
				max:     3
				cpuUtil: 70
			}
			pdb: {
				enabled:      true
				minAvailable: "50%"
			}
			topologySpread: {
				enabled: false
			}
			antiAffinity: {
				enabled: true
				type:    "preferred"
				weight:  100
			}
		}
		prod: {
			hpa: {
				enabled: true
				min:     3
				max:     6
				cpuUtil: 70
			}
			pdb: {
				enabled:        true
				maxUnavailable: 2
			}
			topologySpread: {
				enabled:   true
				maxSkew:   1
				zoneCount: 3
			}
			antiAffinity: {
				enabled: true
				type:    "required"
			}
		}
		"prod-local": {
			hpa: {
				enabled: true
				min:     3
				max:     6
				cpuUtil: 70
			}
			pdb: {
				enabled:        true
				maxUnavailable: 1
			}
			topologySpread: {
				enabled: false
			}
			antiAffinity: {
				enabled: true
				type:    "preferred"
				weight:  100
			}
		}
	}

	// Select configuration based on level
	_selectedConfig: _config[_level]

	// Outputs array to hold all resources
	outputs: {

		// HorizontalPodAutoscaler
		if _selectedConfig.hpa.enabled {
			hpa: {
				apiVersion: "autoscaling/v2"
				kind:       "HorizontalPodAutoscaler"
				metadata: {
					name:      context.name
					namespace: context.namespace
				}
				spec: {
					scaleTargetRef: {
						apiVersion: "apps/v1"
						kind:       context.output.kind
						name:       context.name
					}
					minReplicas: _selectedConfig.hpa.min
					maxReplicas: _selectedConfig.hpa.max
					metrics: [{
						type: "Resource"
						resource: {
							name: "cpu"
							target: {
								type:               "Utilization"
								averageUtilization: _selectedConfig.hpa.cpuUtil
							}
						}
					}]
					behavior: {
						scaleDown: {
							stabilizationWindowSeconds: 300
							policies: [{
								type:          "Percent"
								value:         50
								periodSeconds: 60
							}]
						}
						scaleUp: {
							stabilizationWindowSeconds: 60
							policies: [{
								type:          "Percent"
								value:         100
								periodSeconds: 60
							}]
						}
					}
				}
			}
		}

		// PodDisruptionBudget
		if _selectedConfig.pdb.enabled {
			pdb: {
				apiVersion: "policy/v1"
				kind:       "PodDisruptionBudget"
				metadata: {
					name:      context.name
					namespace: context.namespace
				}
				spec: {
					selector: matchLabels: {
						"app.oam.dev/component": context.name
					}
					if _selectedConfig.pdb.minAvailable != _|_ {
						minAvailable: _selectedConfig.pdb.minAvailable
					}
					if _selectedConfig.pdb.maxUnavailable != _|_ {
						maxUnavailable: _selectedConfig.pdb.maxUnavailable
					}
				}
			}
		}
	}

	// Patch the deployment/statefulset with topology spread and anti-affinity
	patch: {
		spec: template: spec: {

			// Topology Spread Constraints
			if _selectedConfig.topologySpread.enabled {
				topologySpreadConstraints: [{
					maxSkew:           _selectedConfig.topologySpread.maxSkew
					topologyKey:       "topology.kubernetes.io/zone"
					whenUnsatisfiable: "DoNotSchedule"
					labelSelector: matchLabels: {
						"app.oam.dev/component": context.name
					}
				}]
			}

			// Pod Anti-Affinity
			if _selectedConfig.antiAffinity.enabled {
				affinity: {
					podAntiAffinity: {
						if _selectedConfig.antiAffinity.type == "preferred" {
							preferredDuringSchedulingIgnoredDuringExecution: [{
								weight: _selectedConfig.antiAffinity.weight
								podAffinityTerm: {
									topologyKey: "kubernetes.io/hostname"
									labelSelector: matchLabels: {
										"app.oam.dev/component": context.name
									}
								}
							}]
						}
						if _selectedConfig.antiAffinity.type == "required" {
							requiredDuringSchedulingIgnoredDuringExecution: [{
								topologyKey: "kubernetes.io/hostname"
								labelSelector: matchLabels: {
									"app.oam.dev/component": context.name
								}
							}]
						}
					}
				}
			}
		}
	}

	parameter: {
		// level: Environment level (dev, staging, prod, prod-local)
		// +usage=The environment level for high availability configuration
		level: *"dev" | "staging" | "prod" | "prod-local"
	}
}
