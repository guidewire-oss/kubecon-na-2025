package main

parameter: {
	// Namespace where the AWS provider will be installed
	namespace: string | *"crossplane-system"
	
	// Version of the AWS provider family to install
	awsFamilyVersion: string | *"v1.23.2"
	awsS3Version: string | *"v1.23.2"
	
	// Create default ProviderConfig
	createDefaultProviderConfig: bool | *true
	defaultProviderConfigName: string | *"default"
	
	// AWS credentials configuration
	credentialsNamespace: string | *"crossplane-system"
	credentialsSecret: string | *"aws-creds"
	credentialsKey: string | *"creds"
	
	// IRSA (IAM Roles for Service Accounts) configuration
	// Default to false to use secret-based authentication
	irsaEnabled: bool | *false
	if irsaEnabled {
		irsaRoleArn: string
	}
	if !irsaEnabled {
		irsaRoleArn?: string
	}
	
	// Optional assume role configuration
	assumeRole?: {
		roleARN: string
		sessionName?: string | *"crossplane-session"
		externalID?: string
		tags?: [string]: string
	}
}