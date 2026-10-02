# Python 3.14

Docker image for python 3.14.

Acts as base Docker image for python apps developed at Lehigh. This docker image is not meant to
be run on its own it is only used as a base `FROM` image for Lehigh python apps.

## Dependencies

Requires `lehighlts/base` docker image to build. Please refer to the
[Base Image README](../base/README.md) for additional information including
additional settings, volumes, ports, etc.

## Ports

| Port | Description |
| :--- | :---------- |
| 8080 | HTTP        |

## Settings


| Environment Variable        | Default                                    | Description                                                       |
| :-------------------------- | :----------------------------------------- | :---------------------------------------------------------------- |
| `PIP_BREAK_SYSTEM_PACKAGES` | `1`                                        | Allow `pip install requirements.txt`                              |
| `FLASK_APP`                 | `application.app:app`                      | WSGI application module path in format `module:app`               |
| `WORKERS`                   | `4`                                        | Number of worker processes for handling requests                  |
| `SCRIPT_NAME`               | `/`                                        | WSGI SCRIPT_NAME for mounting the application at a URL prefix     |

Uses the shared Alpine/s6 base with the official Python 3.14 runtime.
Downstream applications should use Alpine packages when installing OS dependencies.
