# EMON - client pkgs for emon monitoring service

## ... depends on ...

Needs:

* cob (modified to honour AWS_* env vars)

* cloud-init - used to modify carbon-c-relay.conf at instance-up time
         
## Included ...

	emon/ 
	├── README.emon.md          # ... um, you're reading this ...
	├── etc
	│   ├── carbon-c-relay.conf # config for local carbon that proxies to remote
    │   │
	│   ├── collectd.conf       # our eurostar default collectd.conf
	│   └── yum.repos.d
	│       └── emon.repo       # additional S3 repos - requires cob yum plugin
	└── usr
		└── local
			└── bin
				└── cloud-init  # scripts to rewrite config on instance-up based on this
                    │             instance's ecosystem - requires cloud-init installed
                    │
					├── 00050-configure_carbon\_c\_relay.sh
					├── README.md
					└── user-data.sh.example

