require 'multi_json'
require 'cobravsmongoose'

module Lita
  module Handlers
    # An XLD parameter
    class XldRestApi
      attr_accessor :url, :user, :password

      def initialize(http, url, user, password)
        @http = http
        @url = url
        @user = user
        @password = password

        @http.basic_auth(@user, @password)
      end
      
      def execute_get(url)
        http_response = @http.get(@url + url)
        if is_error(http_response)
          print("ERROR: HTTP response code " + http_response.status.to_s + " for GET to URL " + url)
        end
        http_response
      end

      def execute_post(url, body = nil)
        http_response = @http.post do |req|
          req.url @url + url
          req.headers['Content-Type'] = 'application/xml'
            req.body = body if body != nil
          end

        if is_error(http_response)
          print("ERROR: HTTP response code " + http_response.status.to_s + " for POST to URL " + url)
        end
        http_response
      end

      def do_get_tasks()
        http_response = execute_get("/task/current/all")

        MultiJson.load(CobraVsMongoose.xml_to_json(http_response.body))
      end

      def is_error(http_response)
        http_response.status < 200 || http_response.status > 299
      end

      def find_application(name, result)
        http_response = execute_get("/repository/query?type=udm.Application&namePattern=#{URI::encode('%' + name + '%')}")

        if is_error(http_response)
          result.error = "Failed to invoke REST client, response code " + http_response.status.to_s
        else
            apps = MultiJson.load(CobraVsMongoose.xml_to_json(http_response.body))
            cis = apps["list"]["ci"]
          if cis.is_a? Array
            ids = cis.map { |x| x["@ref"]}
            result.error = "Which application do you mean? " + ids
          else
            result.value = XldId.new(cis["@ref"])
          end
        end
      end

      def find_version(name, result)
        http_response = execute_get("/repository/query?type=udm.DeploymentPackage&namePattern=#{URI::encode('%' + name + '%')}")

        if is_error(http_response)
          result.error = "Failed to invoke REST client, response code " + http_response.status.to_s
        else
            apps = MultiJson.load(CobraVsMongoose.xml_to_json(http_response.body))
            cis = apps["list"]["ci"]
          if cis.is_a? Array
            ids = cis.map { |x| x["@ref"]}
            result.error = "Which version do you mean? " + ids
          else
            result.value = XldId.new(cis["@ref"])
          end
        end
      end

      def deployment_exists(application, environment)
        http_response = execute_get("/deployment/exists?application=#{URI::encode(application.id)}&environment=#{URI::encode(environment.id)}")

        if is_error(http_response)
          return
        end

        exists = MultiJson.load(CobraVsMongoose.xml_to_json(http_response.body))
        return exists["boolean"]["$"] == "true"
      end

      def prepare_deployment(version, env, mode)
        http_response = execute_get("/deployment/prepare/#{mode}?version=#{URI::encode(version.id)}&environment=#{URI::encode(env.id)}")

        if is_error(http_response)
          nil
        else
          http_response.body
        end
      end

      def prepare_deployeds(deployment)
        http_response = execute_post("/deployment/prepare/deployeds", deployment)

        if is_error(http_response)
          nil
        else
          http_response.body
        end
      end

      def create_deployment(deployment)
        http_response = execute_post("/deployment/", deployment)

        if is_error(http_response)
          nil
        else
          http_response.body
        end
      end

      def abort_task(taskId)
        http_response = execute_post("/task/" + taskId + "/abort")

        if is_error(http_response)
          nil
        end
      end

      def cancel_task(taskId)
        # TO DO: Refactor into separate method
        http_response = @http.delete do |req|
          req.headers['Content-Type'] = 'application/xml'
          req.url @url + "/task/" + taskId
          end

        if is_error(http_response)
          nil
        end
      end

      def archive_task(taskId)
        http_response = execute_post("/task/" + taskId + "/archive")

        if is_error(http_response)
          nil
        end
      end

      def start_task(taskId)
        http_response = execute_post("/task/" + taskId + "/start")
      end

      def describe_task(taskId)
        http_response = execute_get("/task/" + taskId)

        if is_error(http_response)
          nil
          return
        end

        MultiJson.load(CobraVsMongoose.xml_to_json(http_response.body))
      end

      # def find_latest_version(http, applicationId, result)
      #   http_response = execute_get(http, XLD_URL + "/repository/query?parent=#{URI::encode('%' + applicationId.value + '%')}")

      #   if http_response.status != 200
      #     log.debug("error calling XLD REST API")
      #     result.error = "Failed to invoke REST client, response code " + http_response.status
      #   else
      #       apps = MultiJson.load(CobraVsMongoose.xml_to_json(http_response.body))
      #       cis = apps["list"]["ci"]
      #     if cis.is_a? Array
      #       ids = cis.map { |x| x["@ref"]}
      #       result.error = "Which version do you mean? " + ids
      #       log.debug("found multiple matches")
      #     else
      #       result.value = cis["@ref"][/\/[0-9][^\/]*$/][/[^\/]+/]
      #       log.debug("found version match " + result.value)
      #     end
      #   end
      # end

      def find_environment(name, result)
        http_response = execute_get("/repository/query?type=udm.Environment&namePattern=#{URI::encode('%' + name + '%')}")

        if is_error(http_response)
          result.error = "Failed to invoke REST client, response code " + http_response.status.to_s
        else
            apps = MultiJson.load(CobraVsMongoose.xml_to_json(http_response.body))
            cis = apps["list"]["ci"]
          if cis.is_a? Array
            ids = cis.map { |x| x["@ref"]}
            result.error = "Which environment do you mean? " + ids
          else
            result.value = XldId.new(cis["@ref"])
          end
        end
      end

      def get_current_step_log(taskId)
        http_response = execute_get("/task/" + taskId)
        poll = MultiJson.load(CobraVsMongoose.xml_to_json(http_response.body))
        taskState = poll["task"]["@state"]

        stepId = poll["task"]["@currentStep"]
        # TO DO: include If-Modified-Since header
        http_response = execute_get("/task/" + taskId + "/step/" + stepId)
        stepState = MultiJson.load(CobraVsMongoose.xml_to_json(http_response.body))

        stepState["step"]["log"]["$"]
      end

    end
  end
end