package main

providerAwsRbac: {
	type: "k8s-objects"
	name: "provider-aws-rbac"
	properties: {
		objects: [
			{
				apiVersion: "rbac.authorization.k8s.io/v1"
				kind: "ClusterRole"
				metadata: {
					name: "provider-aws-system"
				}
				rules: [
					{
						apiGroups: ["aws.upbound.io"]
						resources: ["*"]
						verbs: ["*"]
					}
				]
			},
			{
				apiVersion: "rbac.authorization.k8s.io/v1"
				kind: "ClusterRoleBinding"
				metadata: {
					name: "provider-aws-system"
				}
				roleRef: {
					apiGroup: "rbac.authorization.k8s.io"
					kind: "ClusterRole"
					name: "provider-aws-system"
				}
				subjects: [{
					kind: "ServiceAccount"
					name: "provider-aws"
					namespace: "crossplane-system"
				}]
			}
		]
	}
}

providerAwsS3Rbac: {
	type: "k8s-objects"
	name: "provider-aws-s3-rbac"
	properties: {
		objects: [
			{
				apiVersion: "rbac.authorization.k8s.io/v1"
				kind: "ClusterRole"
				metadata: {
					name: "provider-aws-s3-system"
				}
				rules: [
					{
						apiGroups: ["s3.aws.upbound.io"]
						resources: ["*"]
						verbs: ["*"]
					}
				]
			},
			{
				apiVersion: "rbac.authorization.k8s.io/v1"
				kind: "ClusterRoleBinding"
				metadata: {
					name: "provider-aws-s3-system"
				}
				roleRef: {
					apiGroup: "rbac.authorization.k8s.io"
					kind: "ClusterRole"
					name: "provider-aws-s3-system"
				}
				subjects: [{
					kind: "ServiceAccount"
					name: "provider-aws-s3"
					namespace: "crossplane-system"
				}]
			}
		]
	}
}