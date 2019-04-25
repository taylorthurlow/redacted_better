require "spec_helper"

describe RedactedAPI do
  subject(:api) { create(:redacted_api) }

  describe "#group_info" do
    it "gets the info successfully" do
      expect(api.group_info(1234)).to be_a Hash
    end

    context "when the request fails" do
      it "returns false" do
        allow(Request).to receive(:send_request_action).and_return(status: "failure")

        expect(api.group_info(1234)).to be false
      end
    end
  end
end
