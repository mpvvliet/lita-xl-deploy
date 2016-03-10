require_relative './xld_parameter'
require_relative './xld_id'
require_relative './xld_rest'

XLD_URL = "http://Highgarden.local:4516/deployit"

#########
# 
# TO DO:
#
# For first working version:
# - listen to ".xld xxx" commands
# - implement plugin in XLD to output task events
# - error handling when tasks are not found, etc. --> try/catch
# - implement rollback support
#
# Technical improvements:
# - refactor bot id code to separate class
# - configure XLD server(s)
# - use proper un/pw for each user
# - let redis timeout bot ids

module Lita
  module Handlers
    class XlDeploy < Handler

		#########
      	# Events
      	on :loaded, :handler_loaded

		#########
      	# Routes
		route(/^deployments$/i,
            :list_deployments,
            command: false,
            help: { 'deployments' => 'List all current deployments' }
        )

		route(/^deploy(\s([a-z][^\s]+))?(\s([0-9][^\s]+))?(\sto\s([a-z]+))?$/i,
            :start_deployment,
            command: false,
            help: { 'deploy [application] [version] to [environment]' => 'Start a new deployment' }
        )

		route(/^start\s?([a-z0-9]{5})?$/i,
            :start_task,
            command: false,
            help: { 'start [task id]' => 'Start a task' }
        )

		route(/^abort\s?([a-z0-9]{5})?$/i,
            :abort_task,
            command: false,
            help: { 'abort [task id]' => 'Abort a task' }
        )

		route(/^cancel\s?([a-z0-9]{5})?$/i,
            :cancel_task,
            command: false,
            help: { 'cancel [task id]' => 'Cancel a task' }
        )

		route(/^archive\s?([a-z0-9]{5})?$/i,
            :archive_task,
            command: false,
            help: { 'archive [task id]' => 'Archive a task' }
        )

		route(/^log\s?([a-z0-9]{5})?$/i,
            :log_task,
            command: false,
            help: { 'log [task id]' => 'Show a task log' }
        )

		route(/^desc\s?([a-z0-9]{5})?$/i,
            :describe_task,
            command: false,
            help: { 'desc [task id]' => 'Describe a task' }
        )

		##########################
      	# Event Handlers
		def handler_loaded(_payload)
			log.debug('XlDeploy handler loaded')
		end

		#########
      	# XLD REST API
      	def xld_rest_api(http)
			XldRestApi.new(http, XLD_URL, "admin", "admin1")
      	end

		#########
      	# Helpers
		def get_or_create_bot_id(taskId)
			taskToBotKey = "taskId:" + taskId
			botId = redis.get(taskToBotKey)
			if botId == nil
				clash = true
				while clash
					botId = [*('a'..'z'),*('0'..'9')].shuffle[0,5].join
					botToTaskKey = "botId:" + botId
					taskToBotKey = "taskId:" + taskId
					clash = redis.get(botToTaskKey) != nil
					if (!clash)
						redis.set(botToTaskKey, taskId)
						redis.set(taskToBotKey, botId)
						log.debug(taskId + " -> " + botId)
					end
				end
			end
			botId	
		end

		def determine_command_bot_id(message, botId)
			result = XldParameter.new("task")

			if botId == nil
				result.value = get_conversation_context(message, "currentTaskBotId")
				result.defaulted = true
			else
				result.value = botId
			end

			if result.value == nil
				log.debug("unable to find task id")
				result.error = "Which task do you mean?"
			end

			result
		end

		def get_task_id(botId)
			botToTaskKey = "botId:" + botId
			taskId = redis.get(botToTaskKey)
			if taskId == nil
				log.error("ERROR: unable to find task id for bot id " + botId)
			end
			taskId	
		end

		def set_conversation_context(message, key, value)
		  	redis.set(message.user.id + ":" + message.room_object.id + ":" + key, value)
		end

		def get_conversation_context(message, key)
		  	redis.get(message.user.id + ":" + message.room_object.id + ":" + key)
		end

		def clear_conversation_context(message, key)
		  	redis.del(message.user.id + ":" + message.room_object.id + ":" + key)
		end

		def print_task(botId, task)
			"- [" + task["@state"] + "] " + task["metadata"]["application"]["$"] + "/" + task["metadata"]["version"]["$"] + " to " + task["metadata"]["environment"]["$"] + " [" + botId + "] "
		end

		def determine_initial_or_update(http, appId, envId)
			return "update" if xld_rest_api(http).deployment_exists(appId, envId)
			return "initial"
		end

		def determine_application(message, http, appId)
			result = XldParameter.new("application")
			if appId == nil
				result.value = get_conversation_context(message, "currentApplicationId")
				result.defaulted = true
				log.debug("defaulted application to context")
			else
				log.debug("searching XLD for application")
				xld_rest_api(http).find_application(appId, result)
			end

			if result.value == nil
				log.debug("unable to find application")
				result.error = "Which application do you want to deploy?"
			end

			result
		end

		def determine_version(message, http, applicationId, versionId)
			result = XldParameter.new("version")
			if versionId == nil
				result.defaulted = true

				result.value = get_conversation_context(message, "currentVersionId")
				# if result.value == nil
				# 	find_latest_version(http, applicationId, result)
				# end
			else
				xld_rest_api(http).find_version(versionId, result)
			end

			if result.value == nil
				result.error = "Which version do you want to deploy?"
			end

			result
		end

		def determine_environment(message, http, envId)
			result = XldParameter.new("env")
			if envId == nil
				result.value = get_conversation_context(message, "currentEnvironmentId")
				result.defaulted = true
			else
				xld_rest_api(http).find_environment(envId, result)
			end

			if result.value == nil
				result.error = "Which environment do you want to deploy to?"
			end

			result
		end

		def show_log_tail(response, http, botId)
			taskId = get_task_id(botId)

			log = xld_rest_api(http).get_current_step_log(taskId)
			loglines = log.split("\n")

			# Print last 20 lines
			if loglines.length > 20
				loglines = loglines.slice(loglines.length - 20)
			end
			loglines.each { |x| response.reply botId + "> " + x }
		end

		#########
      	# Route handlers
		def list_deployments(response)
			tasks = xld_rest_api(http).do_get_tasks()

			response.reply "List of deployments:"

			if tasks["list"]["task"] == nil
				response.reply("- none")
			else
				tasks = tasks["list"]["task"]
				if tasks.is_a? Hash
					tasks = [ tasks ]
				end

				depls = tasks.select { |x| x["metadata"]["taskType"]["$"] == "INITIAL" } # TO DO: Need to cover updates, too
				if depls.length == 0
					response.reply("- none")
				else
					for task in depls do
						botId = get_or_create_bot_id(task["@id"])
						response.reply(print_task(botId, task))
					end

					message = response.message
					clear_conversation_context(message, "currentTaskBotId")
					clear_conversation_context(message, "currentApplicationId")
					clear_conversation_context(message, "currentVersionId")
					clear_conversation_context(message, "currentEnvironmentId")

				end
			end
		end

		def create_default_message(param1, param2 = nil, param3 = nil)
			defaultedMessage = ""
			[ param1, param2, param3].map { |x| 
				if x != nil && x.defaulted
					defaultedMessage = defaultedMessage + " " + x.name + " " + x.value
				end
			}
			defaultedMessage
		end

		def start_deployment(response)
			message = response.message

			applicationId = determine_application(message, http, response.match_data[2])
			if applicationId.error != nil
				response.reply applicationId.error
				return
			end
	
			versionId = determine_version(message, http, applicationId, response.match_data[4])
			if versionId.error != nil
				response.reply versionId.error
				return
			end

			envId = determine_environment(message, http, response.match_data[6])
			if envId.error != nil
				response.reply envId.error
				return
			end

			defaultedMessage = create_default_message(applicationId, versionId, envId)
			if defaultedMessage != ""
				response.reply "(using" + defaultedMessage + ")"
			end

			set_conversation_context(message, "currentApplicationId", applicationId.value)
			set_conversation_context(message, "currentVersionId", versionId.value)
			set_conversation_context(message, "currentEnvironmentId", envId.value)
			
			response.reply "Starting deployment of " + applicationId.value + "-" + versionId.value + " to " + envId.value
			
			mode = determine_initial_or_update(http, applicationId.value, envId.value)
			preparedDeployment = xld_rest_api(http).prepare_deployment(versionId.value, envId.value, mode)
			deploymentWithDeployeds = xld_rest_api(http).prepare_deployeds(preparedDeployment)
			taskId = xld_rest_api(http).create_deployment(deploymentWithDeployeds)

		  	xld_rest_api(http).start_task(taskId)
		end

		def start_task(response)
			botId = determine_command_bot_id(response.message, response.match_data[1])

			if botId.error != nil
				response.reply botId.error
				return
			end

			defaultedMessage = create_default_message(botId)
			if defaultedMessage != ""
				response.reply "(using" + defaultedMessage + ")"
			end

		  	set_conversation_context(response.message, "currentTaskBotId", botId.value)
		  	taskId = get_task_id(botId.value)
		  	response.reply "Starting task " + botId.value
		  	xld_rest_api(http).start_task(taskId)
		end

		def abort_task(response)
			botId = determine_command_bot_id(response.message, response.match_data[1])

			if botId.error != nil
				response.reply botId.error
				return
			end

			defaultedMessage = create_default_message(botId)
			if defaultedMessage != ""
				response.reply "(using" + defaultedMessage + ")"
			end

		  	set_conversation_context(response.message, "currentTaskBotId", botId.value)
		  	taskId = get_task_id(botId.value)
		  	response.reply "Aborting task " + botId.value
		  	xld_rest_api(http).abort_task(taskId)
		end

		def cancel_task(response)
			botId = determine_command_bot_id(response.message, response.match_data[1])

			if botId.error != nil
				response.reply botId.error
				return
			end

			defaultedMessage = create_default_message(botId)
			if defaultedMessage != ""
				response.reply "(using" + defaultedMessage + ")"
			end

		  	set_conversation_context(response.message, "currentTaskBotId", botId.value)
		  	taskId = get_task_id(botId.value)
		  	response.reply "Cancelling task " + botId.value
		  	xld_rest_api(http).cancel_task(taskId)
		end

		def archive_task(response)
			botId = determine_command_bot_id(response.message, response.match_data[1])

			if botId.error != nil
				response.reply botId.error
				return
			end

			defaultedMessage = create_default_message(botId)
			if defaultedMessage != ""
				response.reply "(using" + defaultedMessage + ")"
			end

		  	set_conversation_context(response.message, "currentTaskBotId", botId.value)
		  	taskId = get_task_id(botId.value)
		  	response.reply "Archiving task " + botId.value
		  	xld_rest_api(http).archive_task(taskId)
		end

		def log_task(response)
			botId = determine_command_bot_id(response.message, response.match_data[1])

			if botId.error != nil
				response.reply botId.error
				return
			end

			defaultedMessage = create_default_message(botId)
			if defaultedMessage != ""
				response.reply "(using" + defaultedMessage + ")"
			end

		  	set_conversation_context(response.message, "currentTaskBotId", botId.value)
		  	response.reply "Showing log of task " + botId.value
		  	show_log_tail(response, http, botId.value)
		end

		def describe_task(response)
			botId = determine_command_bot_id(response.message, response.match_data[1])

			if botId.error != nil
				response.reply botId.error
				return
			end
			
			defaultedMessage = create_default_message(botId)
			if defaultedMessage != ""
				response.reply "(using" + defaultedMessage + ")"
			end

		  	set_conversation_context(response.message, "currentTaskBotId", botId.value)
		  	response.reply "Describing task " + botId.value
		  	
		  	task = xld_rest_api(http).describe_task(get_task_id(botId.value))

		  	response.reply botId.value + "> XLD id: " + task["task"]["@id"]
		  	response.reply botId.value + "> State: " + task["task"]["@state"] + " (" + task["task"]["@state2"] + ")"
		  	response.reply botId.value + "> Owner: " + task["task"]["@owner"]
		  	response.reply botId.value + "> Start date: " + task["task"]["startDate"]["$"]
		  	response.reply botId.value + "> Completion date: " + task["task"]["completionDate"]["$"]
		end

		Lita.register_handler(self)

    end
  end
end
