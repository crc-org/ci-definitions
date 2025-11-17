# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6]

- Added quay.io/rhqp/qenvs-tkn:v0.6.1 and credentials as workspaces

## [0.5]

- Use bundle resolver for tasks for dynamic provisioning
- Added debug param control + debug info task to show easily how to connect for debug

## [0.4]  

- Added task for sync internal assets to S3, to allow testing pre release versions within public providers
- Added task url-picker to get the right public url (external vs internal)

## [0.3]  

- Added windows 10 / 11 desktop as possible target. Windows target is on public cloud  
  so internal url will not work. We need to add a mechanism to move assets to target in that case.  

## [0.2]  

- ???  

## [0.1]  

- Test fixed openshift local on a virtualized environment  