require "spec_helper"

describe Request do
  describe ".send_request" do
    context "when action is present" do
      it "sends a request" do
        result = described_class.send_request(
          action: "index",
          cookie: "the_cookie",
          params: { "extra_param" => "value" },
        )

        expect(result[:code]).to eq 200
        expect(result[:status]).to eq "success"
      end
    end

    context "when a parameter is missing" do
      it "raises an exception" do
        expect {
          described_class.send_request(
            # action "torrentgroup" expects an "id" parameter
            action: "torrentgroup",
            cookie: "the_cookie",
          )
        }.to raise_error("missing parameter(s): id")
      end
    end
  end
end
