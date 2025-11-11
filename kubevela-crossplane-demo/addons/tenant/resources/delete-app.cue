package main

deleteappdef: {
	name: "trigger-delete-definition"
	type: "k8s-objects"
	properties: {
		objects: [
			{
				apiVersion: "core.oam.dev/v1alpha1"
				kind: "Definition"
				metadata: {
					name: "trigger-delete-tenant-app"
					namespace: "vela-system"
				}
				spec: {
					type: "trigger-action"
					templates: {
						"main.cue": ###"""
							import (
								"vela/kube"
							)

							// Create a Job to delete the application using vela CLI
							deleteJob: kube.#Apply & {
								$params: {
									cluster: ""
									resource: {
										apiVersion: "batch/v1"
										kind:       "Job"
										metadata: {
											name:      "delete-tenant-\(context.data.data.name)-\(context.data.metadata.uid)"
											namespace: context.data.metadata.namespace
										}
										spec: {
											ttlSecondsAfterFinished: 60
											template: {
												spec: {
													restartPolicy: "Never"
													serviceAccountName: "kubevela-vela-core"
													containers: [{
														name:  "vela-delete"
														image: "oamdev/vela-cli:latest"
														command: [
															"vela",
															"delete",
															"tenant-\(context.data.data.name)",
															"-n",
															context.data.metadata.namespace,
															"-y"
														]
													}]
												}
											}
										}
									}
									options: {
										threeWayMergePatch: {
											enabled: true
											annotationPrefix: "resource"
										}
									}
								}
							}
							"""###
					}
				}
			}
		]
	}
}