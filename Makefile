# vim: ts=4 st=4 sr noet smartindent:
#
export MANDATORY_VARS= \
	ALERTLOGIC_HOST    \
	ALERTLOGIC_KEY     \
	AMI_PREVIOUS_SOURCES

include packer_includes/make/mandatory_vars/common.mak

# ### CONSTANTS (not user-defineable)
# SSH_PRIVATE_KEY_FILE ... for build this is the AWS dev account's 'eurostar' key
#
GIT_SHA_LEN:=8
PACKER_JSON:=packer.json
PACKER_INCLUDES_GIT_TAG=2.0.3
AMI_PREFIX:=eurostar_monlog
export AMI_DESC_TXT:=yum updates;netdata;alertlogic;collectd;rsyslog;statsite
AMI_SOURCE_OS:=centos
AMI_SOURCE_OS_RELEASE:=6.5
AMI_SOURCE_PREFIX:=eurostar_aws
export AMI_SOURCE_FILTER:=*/$(AMI_SOURCE_PREFIX)-*
export SHELL:=/bin/bash
export SSH_KEYPAIR_NAME:=eurostar
export SSH_PRIVATE_KEY_FILE:=eurostar.pem
export SSH_USERNAME:=ec2-user

# ### VARS (user-defineable)
# AMI_SOURCE_*: used to determine source ami.
#               defaults to latest stable from EurostarDigital (any branch)
# PACKER_LOG: set to 1 for verbose - but the security-conscious be warned:
#             this will log all env var values including aws access creds ...
# PACKER_DEBUG: set to -debug for breakpoint mode. BUT, BUT, BUT ...
#               THERE IS A BUG IN PACKER 0.10.0 - DEBUG WILL HANG
#
export ALERTLOGIC_HOST?=
export ALERTLOGIC_KEY?=
AMI_SOURCE_GIT_REPO?=*
AMI_SOURCE_GIT_BRANCH?=*
AMI_SOURCE_GIT_TAG?=*
AMI_SOURCE_GIT_SHA?=*
AMI_SOURCE_CHANNEL?=stable
export AWS_ACCESS_KEY_ID?=
export AWS_INSTANCE_TYPE?=t2.small
export AWS_REGION?=eu-west-1
export AWS_SECRET_ACCESS_KEY?=
export PACKER_DEBUG?=
export PACKER_LOG?=
export PACKER_DIR?=./

# ### GENERATED VARS: determined by make based on other values.
# AMI_NAME : must be unique in AWS account, so we can locate it unambiguously.
# AMI_SOURCE_ID: ami that this new one builds on, determined by make
# BUILD_GIT_*: used to AWS-tag the built AMI, and generate its unique name
#              so we can trace its providence later.
#
# ... to rebuild using same version of tools, we can't trust the git tag
# but the branch, sha and repo, because git tags are mutable and movable.
export BUILD_GIT_TAG:=$(shell git describe --exact-match HEAD 2>/dev/null)
ifeq ($(BUILD_GIT_TAG),)
	export BUILD_GIT_BRANCH:=$(shell git describe --contains --all HEAD)
else
	export BUILD_GIT_BRANCH:=detached_head
endif
export BUILD_GIT_SHA:=$(shell git rev-parse --short=$(GIT_SHA_LEN) --verify HEAD)
export BUILD_GIT_REPO:=$(shell \
	git remote show -n origin  \
	| grep '^ *Push *'         \
	| awk {'print $$NF'}       \
)
export BUILD_GIT_ORG:=$(shell \
	echo $(BUILD_GIT_REPO)   \
	| sed -e 's!.*[:/]\([^/]\+\)/.*!\1!' \
)

export BUILD_TIME:=$(shell date +%Y%m%d%H%M%S)

AWS_TAG_SOURCE_OS_INFO:=os<$(AMI_SOURCE_OS)>os_release<$(AMI_SOURCE_OS_RELEASE)>
AWS_TAG_SOURCE_GIT_INFO:=repo<$(AMI_SOURCE_GIT_REPO)>branch<$(AMI_SOURCE_GIT_BRANCH)>
AWS_TAG_SOURCE_GIT_REF:=tag<$(AMI_SOURCE_GIT_TAG)>sha<$(AMI_SOURCE_GIT_SHA)>
export AMI_SOURCE_ID?=$(shell                                            \
	aws --cli-read-timeout 10 ec2 describe-images --region $(AWS_REGION) \
	--filters 'Name=manifest-location,Values=$(AMI_SOURCE_FILTER)'       \
	          'Name=tag:os_info,Values=$(AWS_TAG_SOURCE_OS_INFO)'        \
	          'Name=tag:build_git_info,Values=$(AWS_TAG_SOURCE_GIT_INFO)'\
	          'Name=tag:build_git_ref,Values=$(AWS_TAG_SOURCE_GIT_REF)'  \
	          'Name=tag:channel,Values=$(AMI_SOURCE_CHANNEL)'            \
	--query 'Images[*].[ImageId,CreationDate]'                           \
	--output text                                                        \
	| sort -k2 | tail -1 | awk {'print $$1'}                             \
)

# ... value of source ami's ami_sources tag used as prefix for this ami's sources tag
#     to show provenance.
export AMI_PREVIOUS_SOURCES:=$(shell                                     \
	aws --cli-read-timeout 10 ec2 describe-tags --region $(AWS_REGION)   \
	--filters 'Name=resource-id,Values=$(AMI_SOURCE_ID)'                 \
	          'Name=key,Values=ami_sources'                              \
	--query 'Tags[*].Value'                                              \
	--output text                                                        \
)

# ... this ami's os and release num should be the same as it's source
export AMI_OS:=$(AMI_SOURCE_OS)
export AMI_OS_RELEASE:=$(AMI_SOURCE_OS_RELEASE)
export AMI_OS_INFO:=$(AMI_OS)-$(AMI_OS_RELEASE)
export AMI_DESCRIPTION:=$(AMI_OS_INFO): $(AMI_DESC_TXT)
export AMI_NAME:=$(AMI_PREFIX)-$(AMI_OS_INFO)-$(BUILD_GIT_ORG)-$(BUILD_TIME)

export AWS_TAG_AMI_SOURCES:=$(AMI_PREVIOUS_SOURCES)<$(AMI_SOURCE_PREFIX):$(AMI_SOURCE_ID)>
export AWS_TAG_BUILD_GIT_INFO:=repo<$(BUILD_GIT_REPO)>branch<$(BUILD_GIT_BRANCH)>
export AWS_TAG_BUILD_GIT_REF:=tag<$(BUILD_GIT_TAG)>sha<$(BUILD_GIT_SHA)>
export AWS_TAG_OS_INFO:=$(AWS_TAG_SOURCE_OS_INFO)

export PACKER?=$(shell which packer)

# ... run 'make' or 'make help' to see where each recipe is defined
include packer_includes/make/recipes/common.mak

.PHONY: prereqs
prereqs: sshkeyfile ## set up build env

.PHONY: validate
validate: check_vars check_includes check_for_changes valid_packer ## check build env is sane

.PHONY: build
build: prereqs validate ## run prereqs, validate then build.
	@PACKER_LOG=$(PACKER_LOG) packer build $(PACKER_DEBUG) "$(PACKER_JSON)"

