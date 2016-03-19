# lita-xl-deploy

ChatOps bot for XL Deploy.

## Installation

Add lita-xl-deploy to your Lita instance's Gemfile:

``` ruby
gem "lita-xl-deploy"
```

## Configuration

### Required attributes

* `xld_url` (String) - The URL to your XL Deploy instance. Default: `nil`.
* `context_storage_timeout` (int) - The duration for which to keep conversation context, in seconds. Default: `nil`.

### Optional attributes

None.

### Example

``` ruby
Lita.configure do |config|
  config.handlers.xl_deploy.xld_url  = "http://localhost:4516/deployit"
  config.handlers.xl_deploy.context_storage_timeout = "3600"
end
```

## Usage

```
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
 
 [You] deploy pet 1.0 to test
[Lita] Starting deployment of PetClinic-war-1.0 to TEST [i6tj7]
```

## License

[MIT](http://opensource.org/licenses/MIT)
