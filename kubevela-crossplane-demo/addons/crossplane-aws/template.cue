package main

output: {
	apiVersion: "core.oam.dev/v1beta1"
	kind:       "Application"
	spec: {
		components: [
			provideraws,
			providerawss3,
			if parameter.createDefaultProviderConfig {
				awsproviderconfig
			}
		]
		
		// Workflow to ensure providers are ready before creating ProviderConfig
		workflow: {
			steps: [
				{
					name: "install-provider-aws"
					type: "apply-component"
					properties: {
						component: provideraws.name
					}
				},
				{
					name: "install-provider-aws-s3"
					type: "apply-component"
					dependsOn: ["install-provider-aws"]
					properties: {
						component: providerawss3.name
					}
				},
				if parameter.createDefaultProviderConfig {
					{
						name: "create-provider-config"
						type: "apply-component"
						properties: {
							component: awsproviderconfig.name
						}
					}
				}
			]
		}
	}
}
