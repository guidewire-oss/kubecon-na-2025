package main

createappdef: {
	name: "trigger-definition"
	type: "k8s-objects"
	properties: {
		objects: [
			{
				apiVersion: "core.oam.dev/v1alpha1"
				kind: "Definition"
				metadata: {
					name: "trigger-create-tenant-app"
					namespace: "vela-system"
				}
				spec: {
					type: "trigger-action"
					templates: {
						"main.cue": ###"""
							import (
								"vela/kube"
							)

							apply: kube.#Apply & {
								$params: {
									resource: {
										apiVersion: "core.oam.dev/v1beta1"
										kind:       "Application"
										metadata: {
											name:      "tenant-\(context.data.data.name)"
											namespace: context.data.metadata.namespace
											annotations: {
												"config.oam.dev/source-configmap": "\(context.data.metadata.namespace)/\(context.data.metadata.name)"
											}
										}
										spec: {
											components: [
												{
													name: "tenant-namespace"
													type: "k8s-objects"
													properties: {
														objects: [
															{
																apiVersion: "v1"
																kind: "Namespace"
																metadata: {
																	name: "tenant-\(context.data.data.namespace)"
																}
															}
														]
													}
												},
												{
													name: "tenant-s3-bucket"
													type: "s3-bucket"
													properties: {
														bucket: "\(context.data.data.name)-bucket"
														region: "us-west-2"
													}
												}
											]
											workflow: {
												steps: [
													{
														name: "create-namespace"
														type: "apply-component"
														properties: {
															component: "tenant-namespace"
														}
													},
													{
														name: "create-s3-bucket"
														type: "apply-component"
														properties: {
															component: "tenant-s3-bucket"
														}
														dependsOn: ["create-namespace"]
													}
												]
											}
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