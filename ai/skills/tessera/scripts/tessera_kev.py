"""Kev adapter for jaredpalmer/kev, verified at 9c41005 on 2026-09-27.

A separate server must already be deployed. No model downloads or service setup.
"""
import os
from urllib.parse import urlsplit
import tessera_systemone as wire

ID = "kev"
MODEL = "kev-latest"
parse_response = wire.parse_response
validate_response = wire.validate_response


def endpoint():
    value = os.environ.get("TESSERA_KEV_ENDPOINT", "")
    parts = urlsplit(value)
    loopback = parts.hostname in {"127.0.0.1", "localhost", "::1"}
    wire.require(bool(parts.hostname) and parts.scheme in {"http", "https"}
                 and (parts.scheme == "https" or loopback)
                 and parts.username is None and parts.password is None
                 and not parts.query and not parts.fragment
                 and not any(char.isspace() for char in value)
                 and parts.path.endswith("/v1/systemone"),
                 "TESSERA_KEV_ENDPOINT must be an explicit HTTPS URL or loopback HTTP, without secrets or query")
    return value


def build_request(context):
    return wire.build_request(context, MODEL)


def check_credentials():
    target = urlsplit(endpoint())
    wire.require(target.hostname in {"127.0.0.1", "localhost", "::1"}
                 or bool(os.environ.get("KEV_API_KEY")),
                 "KEV_API_KEY is missing for the remote server; Kev was not called")


def invoke(body):
    check_credentials()
    return wire.invoke(body, endpoint=endpoint(), api_key=os.environ.get("KEV_API_KEY") or None, label="Kev")
