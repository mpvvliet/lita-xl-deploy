# lita-xl-deploy

ChatOps bot for [XL Deploy](https://xebialabs.com/products/xl-deploy/).

The lita-xl-deploy bot is a bot based on the [Lita](https://www.lita.io/) chat bot framework written in Ruby.

This bot makes XL Deploy an active part of your DevOps communication. Include XL Deploy in your chat room and collaborate with your team on planning, performing and troubleshooting deployments.

## Installation

Add lita-xl-deploy to your Lita instance's Gemfile:

``` ruby
gem "lita-xl-deploy"
```

## Configuration

### Required attributes

* `xld_url` (String) - The URL to your XL Deploy instance. Default: `nil`.
* `xld_username` (String) - The username to connecto to your XL Deploy instance. Default: `nil`.
* `xld_password` (String) - The password to connect to your XL Deploy instance. Default: `nil`.
* `context_storage_timeout` (int) - The duration for which to keep conversation context, in seconds. Default: `nil`.

### Optional attributes

None.

### Example

``` ruby
Lita.configure do |config|
  config.handlers.xl_deploy.xld_url = "http://localhost:4516/deployit"
  config.handlers.xl_deploy.xld_username = "username"
  config.handlers.xl_deploy.xld_password = "secret"
  config.handlers.xl_deploy.context_storage_timeout = "3600"
end
```

## Usage

```
 [You] applications
[Lita] List of applications:
       - Applications/PetClinic-ear
       - Applications/PetClinic-war
       - Applications/PetZoo

 [You] environments
[Lita] List of environments:
       - Environments/DEV
       - Environments/TEST

 [You] versions petzoo
[Lita] List of PetZoo versions:
       - Applications/PetZoo/1.0

 [You] deployments
[Lita] List of deployments:
       - [STOPPED] PetClinic-war/1.0 to TEST [fd5hr]

 [You] log fd5hr
[Lita] Showing log of task fd5hr
       fd5hr> Uploading file stop-tc.sh to working directory.
       fd5hr> Executing /var/folders/zz/zyxvpxvq6csfxvn_n0000000000000/T/ot-20160312T203457416/generic_plugin.tmp/stop-tc.sh on host Infrastructure/localhost
       fd5hr> [ERROR]: /var/folders/zz/zyxvpxvq6csfxvn_n0000000000000/T/ot-20160312T203457416/generic_plugin.tmp/stop-tc.sh: line 1: cd: /opt/tomcat: No such file or directory
       fd5hr> [ERROR]: /var/folders/zz/zyxvpxvq6csfxvn_n0000000000000/T/ot-20160312T203457416/generic_plugin.tmp/stop-tc.sh: line 2: bin/stop.sh: No such file or directory
       fd5hr> [ERROR]: Execution failed with return code 127

 [You] start
[Lita] (using task fd5hr)
       Starting task fd5hr
       [fd5hr] started
 
 [You] deploy war 1.0 to test
[Lita] Starting deployment of PetClinic-war-1.0 to TEST [i6tj7]
```

## License

[MIT](http://opensource.org/licenses/MIT)
