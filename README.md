# packer\_mon\_log\_aws

Assets used to take a base ami (see packer_base*) and add some monitoring
and logging tools.

It is *NOT* responsible for the creation of the mon or log info files under
/etc/eurostar used by cloud-init (and startup scripts) to discover things
about this instance or the eurostar ecosystem. That happens in a later
packer layer when we know what type of product and role the apps on here
will serve.

*ADD STUFF TO THIS LAYER TO DO WITH STANDARD MONITORING AND LOGGING CLIENTS*

## BUILD

        # export all user-defined env vars, and then:
        make build

* makefile inherits values from env vars. These are transformed and / or
  passed on to packer which maps them to packer _user_ vars.

* Packer runs a few scripts under the yawn-inducingly-named scripts dir to
  provide the basic ami env.

## CHANGES WORKFLOW

* make a git branch from master.

* make your changes and push to your branch

* build from your branch

* The AMI will have a channel tag, set to _dev_.

* After it passes testing, merge to master.

* *On successful testing, the AMI's channel tag should be set to  _stable_.*

  _Obviously, this should be automated ..._

  It is this stable, tested ami that later ami layers will look for to use
  as a base.

  **See examples of changing tags and discovering appropriate AMIs below.**


## OUTPUT

The resulting AMI is named:

        eurostar_monlog-<os info>-<build time>-<src's git sha>-<src's git branch>

        e.g.

        eurostar_monlog-centos-6.5-20160522105037-0ad9aa7a-master

See generated value $AMI_NAME in Makefile for more details.

## DISCOVERY

        e.g. find ami_id for latest stable centos from a EurostarDigital master branch:

        aws --cli-read-timeout 10 ec2 describe-images --region $AWS_REGION     \
            --filter 'Name=manifest-location,Values=*/eurostar_monlog-centos*' \
            --filter 'Name=tag:build_git_org,Values=EurostarDigital'           \
            --filter 'Name=tag:build_git_branch,Values=master'                 \
            --filter 'Name=tag:channel,Values=stable'                          \
            --query 'Images[*].[ImageId,CreationDate]'                         \
            --output text                                                      \
            | sort -k2 | tail -1 | awk {'print $1'}


## MARKING AS STABLE

        e.g. assumes you know the ami id

        aws ec2 create-tags --region=$AWS_REGION \
        --resources $AMI_ID                      \
        --tags 'Key=channel,Value=stable'

