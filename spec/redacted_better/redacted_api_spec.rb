require "spec_helper"

describe RedactedAPI do
  subject(:api) { create(:redacted_api) }

  describe "#all_snatches" do
    it "gets a list of all snatches" do
      snatches = api.all_snatches

      expect(snatches).to be_an Array
      expect(snatches.count).to eq 15
    end
  end

  describe "#mark_torrent_24bit" do
    it "marks a torrent with the page form" do
      torrent = create(:torrent, group: create(:group))

      result = api.mark_torrent_24bit(torrent.id)

      expect(result).to be true
    end
  end

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
