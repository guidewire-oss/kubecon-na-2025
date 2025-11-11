package main

namespace: {
	name: "crossplane-namespace"
	type: "k8s-objects"
	properties: {
		objects: [{
			apiVersion: "v1"
			kind: "Namespace"
			metadata: {
				name: parameter.namespace
			}
		}]
	}
}