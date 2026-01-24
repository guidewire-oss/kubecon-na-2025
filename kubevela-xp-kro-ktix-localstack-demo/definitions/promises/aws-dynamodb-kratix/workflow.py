#!/usr/bin/env python3
"""
Kratix resource.configure workflow for DynamoDB Promise.

This script reads a DynamoDB request and generates an AWS Controllers for
Kubernetes (ACK) Table resource manifest that will create the actual
DynamoDB table in AWS.

Environment Variables:
  REQUEST_PATH: Path to the request manifest (provided by Kratix)
  ACK_NAMESPACE: Kubernetes namespace where ACK controller runs
"""

import json
import os
import sys
import yaml
from pathlib import Path


# Allowed AWS regions
ALLOWED_REGIONS = {
    "us-east-1", "us-east-2", "us-west-1", "us-west-2",
    "eu-west-1", "eu-central-1",
    "ap-southeast-1", "ap-northeast-1", "ap-south-1"
}

# Attribute type mappings
ATTRIBUTE_TYPES = {"S", "N", "B"}

# Valid key types
KEY_TYPES = {"HASH", "RANGE"}


def validate_request(request: dict) -> tuple[bool, str]:
    """
    Validate the DynamoDB request.

    Returns:
        Tuple of (is_valid, error_message)
    """
    spec = request.get("spec", {})

    # Validate name
    name = spec.get("name", "").strip()
    if not name:
        return False, "name is required"
    if len(name) < 3 or len(name) > 255:
        return False, "name must be between 3 and 255 characters"
    if not all(c.isalnum() or c in "._-" for c in name):
        return False, "name can only contain alphanumeric characters, dots, underscores, and hyphens"

    # Validate region
    region = spec.get("region", "").strip()
    if not region:
        return False, "region is required"
    if region not in ALLOWED_REGIONS:
        return False, f"region must be one of: {', '.join(sorted(ALLOWED_REGIONS))}"

    # Validate attribute definitions
    attr_defs = spec.get("attributeDefinitions", [])
    if not attr_defs:
        return False, "attributeDefinitions is required and must have at least one attribute"

    attr_names = set()
    for attr in attr_defs:
        if not isinstance(attr, dict):
            return False, "each attributeDefinition must be an object"
        attr_name = attr.get("name", "").strip()
        attr_type = attr.get("type", "").strip()
        if not attr_name:
            return False, "each attribute must have a name"
        if attr_type not in ATTRIBUTE_TYPES:
            return False, f"attribute type must be S, N, or B, got {attr_type}"
        attr_names.add(attr_name)

    # Validate key schema
    key_schema = spec.get("keySchema", [])
    if not key_schema:
        return False, "keySchema is required and must have at least one key"
    if len(key_schema) > 2:
        return False, "keySchema can have at most 2 keys (partition + sort)"

    hash_key_count = 0
    range_key_count = 0
    for key in key_schema:
        if not isinstance(key, dict):
            return False, "each key in keySchema must be an object"
        key_attr = key.get("attributeName", "").strip()
        key_type = key.get("keyType", "").strip()

        if not key_attr:
            return False, "each key must have an attributeName"
        if key_attr not in attr_names:
            return False, f"key attribute '{key_attr}' must be defined in attributeDefinitions"
        if key_type not in KEY_TYPES:
            return False, f"keyType must be HASH or RANGE, got {key_type}"

        if key_type == "HASH":
            hash_key_count += 1
        else:
            range_key_count += 1

    if hash_key_count != 1:
        return False, "keySchema must have exactly one HASH (partition) key"
    if range_key_count > 1:
        return False, "keySchema can have at most one RANGE (sort) key"

    # Validate billing mode
    billing_mode = spec.get("billingMode", "PAY_PER_REQUEST").strip()
    if billing_mode not in {"PAY_PER_REQUEST", "PROVISIONED"}:
        return False, f"billingMode must be PAY_PER_REQUEST or PROVISIONED, got {billing_mode}"

    # Validate provisioned settings if in PROVISIONED mode
    if billing_mode == "PROVISIONED":
        provisioned = spec.get("provisioned", {})
        if not isinstance(provisioned, dict):
            return False, "provisioned must be an object when billingMode is PROVISIONED"

        read_cap = provisioned.get("readCapacity", 5)
        write_cap = provisioned.get("writeCapacity", 5)

        if not isinstance(read_cap, int) or read_cap < 1 or read_cap > 40000:
            return False, "readCapacity must be an integer between 1 and 40000"
        if not isinstance(write_cap, int) or write_cap < 1 or write_cap > 40000:
            return False, "writeCapacity must be an integer between 1 and 40000"

    return True, ""


def generate_ack_table_manifest(request: dict) -> dict:
    """
    Generate an ACK Table manifest from the DynamoDB request.

    Returns:
        Dictionary representing the ACK Table resource
    """
    metadata = request.get("metadata", {})
    spec = request.get("spec", {})

    table_name = spec["name"].strip()
    region = spec["region"].strip()
    billing_mode = spec.get("billingMode", "PAY_PER_REQUEST").strip()
    attr_defs = spec.get("attributeDefinitions", [])
    key_schema = spec.get("keySchema", [])

    # Build attribute definitions for ACK
    attributes = []
    for attr in attr_defs:
        attributes.append({
            "attributeName": attr.get("name", ""),
            "attributeType": attr.get("type", "")
        })

    # Build manifest
    manifest = {
        "apiVersion": "dynamodb.services.k8s.aws/v1alpha1",
        "kind": "Table",
        "metadata": {
            "name": table_name.lower(),
            "namespace": metadata.get("namespace", "default"),
            "labels": {
                "kratix.io/request": metadata.get("name", ""),
                "kratix.io/promise": "aws-dynamodb-kratix"
            }
        },
        "spec": {
            "tableName": table_name,
            "attributeDefinitions": attributes,
            "keySchema": key_schema,
            "region": region
        }
    }

    # Add billing mode configuration
    if billing_mode == "PAY_PER_REQUEST":
        manifest["spec"]["billingMode"] = "PAY_PER_REQUEST"
    else:
        provisioned = spec.get("provisioned", {})
        manifest["spec"]["billingMode"] = "PROVISIONED"
        manifest["spec"]["provisionedThroughput"] = {
            "readCapacityUnits": provisioned.get("readCapacity", 5),
            "writeCapacityUnits": provisioned.get("writeCapacity", 5)
        }

    return manifest


def main():
    """Main workflow execution."""
    # Get paths and configuration
    request_path = os.environ.get("REQUEST_PATH")
    state_dir = os.environ.get("OUTPUT_STATE_PATH", "/tmp/kratix-state")
    ack_namespace = os.environ.get("ACK_NAMESPACE", "ack-system")

    if not request_path:
        print("ERROR: REQUEST_PATH environment variable not set", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(request_path):
        print(f"ERROR: Request file not found: {request_path}", file=sys.stderr)
        sys.exit(1)

    # Read request
    try:
        with open(request_path, 'r') as f:
            request = yaml.safe_load(f)
    except Exception as e:
        print(f"ERROR: Failed to read request: {e}", file=sys.stderr)
        sys.exit(1)

    if not request:
        print("ERROR: Request file is empty", file=sys.stderr)
        sys.exit(1)

    # Validate request
    is_valid, error_msg = validate_request(request)
    if not is_valid:
        print(f"ERROR: Invalid request: {error_msg}", file=sys.stderr)
        sys.exit(1)

    # Generate ACK manifest
    try:
        manifest = generate_ack_table_manifest(request)
    except Exception as e:
        print(f"ERROR: Failed to generate manifest: {e}", file=sys.stderr)
        sys.exit(1)

    # Ensure output directory exists
    try:
        Path(state_dir).mkdir(parents=True, exist_ok=True)
    except Exception as e:
        print(f"ERROR: Failed to create state directory: {e}", file=sys.stderr)
        sys.exit(1)

    # Write manifest to state directory
    # Kratix will pick this up and apply it to the cluster
    output_file = os.path.join(state_dir, "table-manifest.yaml")
    try:
        with open(output_file, 'w') as f:
            yaml.dump(manifest, f, default_flow_style=False, sort_keys=False)
    except Exception as e:
        print(f"ERROR: Failed to write manifest: {e}", file=sys.stderr)
        sys.exit(1)

    # Success
    print(f"Successfully generated Table manifest for {request['spec']['name']}")
    print(f"Output written to: {output_file}")
    sys.exit(0)


if __name__ == "__main__":
    main()
