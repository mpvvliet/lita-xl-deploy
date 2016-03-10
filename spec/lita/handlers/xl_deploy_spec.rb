require "spec_helper"
require 'multi_json'

describe Lita::Handlers::XlDeploy, lita_handler: true do

	it { is_expected.to route("deployments") }
	it { is_expected.to route("deploy") }
	it { is_expected.to route("deploy petclinic") }
	it { is_expected.to route("deploy petclinic 1.0") }
	it { is_expected.to route("deploy petclinic 1.0 to dev") }
	it { is_expected.to route("deploy petclinic to dev") }
	it { is_expected.to route("deploy to dev") }

	it { is_expected.to route("start") }
	it { is_expected.to route("start ac4df") }

	it { is_expected.to route("cancel") }
	it { is_expected.to route("cancel ac4df") }

	it { is_expected.to route("archive") }
	it { is_expected.to route("archive ac4df") }

	it { is_expected.to route("abort") }
	it { is_expected.to route("abort ac4df") }

	it { is_expected.to route("desc") }
	it { is_expected.to route("desc ac4df") }

	describe "tasks" do

		XLD_TASKS_REST_JSON = '{"list":{"task":{"@id":"6f065290-fafa-4fc4-9aab-3dd14f3e935d","@currentStep":"1","@totalSteps":"4","@failures":"1","@state":"STOPPED","@state2":"FAILED","@owner":"admin","description":{"$":"Initial deployment of Environments/TEST/PetClinic-war"},"startDate":{"$":"2016-03-10T20:49:59.105+0000"},"completionDate":{"$":"2016-03-10T20:49:59.123+0000"},"currentSteps":{"current":{"$":"1"}},"metadata":{"environment":{"$":"TEST"},"taskType":{"$":"INITIAL"},"environment_id":{"$":"Environments/TEST"},"application":{"$":"PetClinic-war"},"version":{"$":"1.0"}}}}}'

		it "can list deployments" do
			restApi = instance_double("XldRestApi", "XLD REST API")
			allow(restApi).to receive(:do_get_tasks).and_return(MultiJson.load(XLD_TASKS_REST_JSON))
			allow(subject).to receive(:xld_rest_api).and_return(restApi)

			response = double("response")
			expect(response).to receive(:reply).with("List of deployments:")
			expect(response).to receive(:reply).with(/\[STOPPED\] PetClinic-war\/1\.0 to TEST/)
			
			message = double("message")
			expect(response).to receive(:message).and_return(message)
			user = double("user")
			expect(message).to receive(:user).at_least(:once).and_return(user)
			expect(user).to receive(:id).at_least(:once).and_return("1")

			room = double("room")
			expect(message).to receive(:room_object).at_least(:once).and_return(room)
			expect(room).to receive(:id).at_least(:once).and_return("1")

			subject.list_deployments(response)
		end

	end

	it "can ask for application" do
		send_message("deploy", from: Lita::Room.new("XlDeploy"))
		expect(replies.last).to eq("Which application do you want to deploy?")
	end

	it "can ask for env" do
		send_message("deploy petclinic 1.0", from: Lita::Room.new("XlDeploy"))
		expect(replies.last).to eq("Which environment do you want to deploy to?")
	end

	it "can create a deployment with a partial version" do
		send_message("deploy petclinic 1. to test", from: Lita::Room.new("XlDeploy"))
		expect(replies.last).to eq("Starting deployment of PetClinic-war-1.0 to TEST")
	end
end
