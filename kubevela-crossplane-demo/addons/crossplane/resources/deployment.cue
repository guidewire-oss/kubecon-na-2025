package main

deployment: {
	type: "helm"
	name: "crossplane"
	properties: {
		repoType: "helm"
		url: "https://charts.crossplane.io/stable"
		chart: "crossplane"
		version: "1.19.3"
		releaseName: "crossplane"
		targetNamespace: parameter.namespace
		createNamespace: false
		values: {
			replicas: parameter.replicas
			resources: parameter.resources
			rbacManager: {
				deploy: true
			}
			webhooks: {
				enabled: false
			}
			args: []
		}
	}
}